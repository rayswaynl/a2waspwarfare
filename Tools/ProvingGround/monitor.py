#!/usr/bin/env python3
"""Parse or follow WASP Proving Ground telemetry in an Arma 2 OA RPT.

The monitor deliberately uses only the Python standard library.  Its input is
the stable, pipe-delimited WASPLAB v1 protocol.  Arma's timestamp prefixes and
the quotes added by ``diag_log`` are ignored.

Examples::

    python monitor.py arma2oaserver.RPT
    python monitor.py arma2oaserver.RPT --json --min-fps 30
    python monitor.py arma2oaserver.RPT --follow --json-lines

The one-shot modes scope themselves to the last START marker, so an RPT which
contains several mission runs cannot contaminate the newest result with old
samples or old SQF errors.
"""

from __future__ import print_function

import argparse
import json
import math
import os
import re
import statistics
import sys
import time


MARKER = "WASPLAB|v1|"
KINDS = (
    "BOOT", "START", "PHASE", "SAMPLE", "BATCH", "REALIZED", "COMPOSITION",
    "BUS", "PATHLEG", "SCHED", "ALERT", "RESULT", "ABORT", "SPAWN_FAIL",
    "BUS_REJECT", "CLEANUP",
)

_MARKER_LINE_RE = re.compile(
    r'^\s*(?:\d{1,3}:\d{2}:\d{2}(?:\.\d+)?\s+)?'
    r'(?:(?:"(WASPLAB\|v1\|[^"\r\n]*)";?)|((?:WASPLAB\|v1\|)[^"\r\n]*);?)\s*$'
)

_INT_RE = re.compile(r"^[+-]?\d+$")
_FLOAT_RE = re.compile(
    r"^[+-]?(?:\d+\.\d*|\.\d+|\d+)(?:[eE][+-]?\d+)?$"
)
_NONFINITE_RE = re.compile(r"^[+-]?(?:nan|inf(?:inity)?)$", re.IGNORECASE)

# These signatures are intentionally limited to errors which can invalidate a
# benchmark.  Routine missing texture/sound warnings are not classified as a
# mission-load failure.
FATAL_PATTERNS = (
    (
        "CANNOT_CREATE_OR_LOAD",
        re.compile(
            r"\bCannot\s+(?:create|load)\b(?!\s+(?:texture|sound|material)\b)",
            re.IGNORECASE,
        ),
    ),
    (
        "MISSINIT_MISSING",
        re.compile(
            r"(?:\bMISSINIT\b.*\b(?:missing|not\s+found|failed|timeout)\b|"
            r"\b(?:missing|not\s+found|failed|timeout)\b.*\bMISSINIT\b)",
            re.IGNORECASE,
        ),
    ),
    (
        "SQF_EXPRESSION_ERROR",
        re.compile(r"\b(?:Error\s+in\s+expression|Error\s+position|Generic\s+error\s+in\s+expression)\b", re.IGNORECASE),
    ),
    (
        "SQF_UNDEFINED_VARIABLE",
        re.compile(r"\bUndefined\s+variable\s+in\s+expression\b", re.IGNORECASE),
    ),
    (
        "SQF_SCRIPT_MISSING",
        re.compile(r"\bScript\s+.+?\s+not\s+found\b", re.IGNORECASE),
    ),
    (
        "INCLUDE_FILE_MISSING",
        re.compile(r"\bInclude\s+file\s+.+?\s+not\s+found\b", re.IGNORECASE),
    ),
    (
        "SQF_PARSE_ERROR",
        re.compile(
            r"(?:\bMissing\s+[;\)\]\}]|\bType\s+\S+\s*,?\s*expected\b|"
            r"\bInvalid\s+number\s+in\s+expression\b)",
            re.IGNORECASE,
        ),
    ),
    (
        "ENGINE_FATAL",
        re.compile(
            r"\b(?:Out\s+of\s+memory|Application\s+terminated|Exception\s+code)\b",
            re.IGNORECASE,
        ),
    ),
)


def _trim_number(value):
    """Make calculated metrics stable and compact in text and JSON output."""
    if value is None:
        return None
    try:
        number = float(value)
    except (TypeError, ValueError, OverflowError):
        return None
    if not math.isfinite(number):
        return None
    rounded = round(number, 3)
    if rounded.is_integer():
        return int(rounded)
    return rounded


def _parse_value(value):
    value = value.strip()
    lower = value.lower()
    if lower == "true":
        return True
    if lower == "false":
        return False
    if lower in ("null", "none"):
        return None
    if _INT_RE.match(value):
        try:
            return int(value)
        except ValueError:
            pass
    if _FLOAT_RE.match(value):
        try:
            number = float(value)
            if math.isfinite(number):
                return number
        except (ValueError, OverflowError):
            pass
    return value


def extract_marker(line):
    """Return a bare WASPLAB marker from an RPT line, or ``None``."""
    match = _MARKER_LINE_RE.match(line)
    if match is None:
        return None
    marker = (match.group(1) or match.group(2)).rstrip()
    if match.group(2) is not None and marker.endswith(";"):
        marker = marker[:-1].rstrip()
    return marker


def parse_marker(line):
    """Normalize one WASPLAB line into ``kind`` and typed key/value fields."""
    marker = extract_marker(line)
    if marker is None:
        return None
    parts = marker.split("|")
    if len(parts) < 3 or parts[0] != "WASPLAB" or parts[1] != "v1":
        return None
    kind = parts[2].upper()
    if kind not in KINDS:
        return None

    fields = {}
    positional = []
    protocol_issues = []
    seen_keys = {}
    for part in parts[3:]:
        if "=" not in part:
            if part:
                positional.append(_parse_value(part))
            continue
        key, value = part.split("=", 1)
        key = key.strip()
        if key:
            folded_key = key.lower()
            if folded_key in seen_keys:
                protocol_issues.append(
                    {
                        "kind": "DUPLICATE_FIELD",
                        "fields": {
                            "eventKind": kind,
                            "field": key,
                            "firstField": seen_keys[folded_key],
                        },
                    }
                )
            else:
                seen_keys[folded_key] = key
            parsed_value = _parse_value(value)
            if (
                _INT_RE.match(value.strip())
                or _FLOAT_RE.match(value.strip())
                or _NONFINITE_RE.match(value.strip())
            ) and _number(
                {"value": parsed_value}, "value"
            ) is None:
                protocol_issues.append(
                    {
                        "kind": "INVALID_NUMERIC_FIELD",
                        "fields": {"eventKind": kind, "field": key},
                    }
                )
            fields[key] = parsed_value
    if positional:
        fields["_positional"] = positional
    event = {"kind": kind, "fields": fields, "marker": marker}
    if protocol_issues:
        event["protocol_issues"] = protocol_issues
    return event


def _field(fields, *names):
    """Case-insensitive field lookup, preserving the protocol's camel case."""
    for name in names:
        if name in fields:
            return fields[name]
    folded = dict((str(key).lower(), value) for key, value in fields.items())
    for name in names:
        if name.lower() in folded:
            return folded[name.lower()]
    return None


def _number(fields, *names):
    value = _field(fields, *names)
    if isinstance(value, bool) or value is None:
        return None
    try:
        number = float(value)
    except (TypeError, ValueError, OverflowError):
        return None
    return number if math.isfinite(number) else None


def _latest_number(records, *names):
    """Return the newest numeric field from a list of stored protocol records."""
    for record in reversed(records):
        value = _number(record["fields"], *names)
        if value is not None:
            return value
    return None


def _run_identity(fields):
    """Resolve run identity aliases only where an event is run-scoped."""
    return _field(fields, "run", "runId", "id")


def _run_alias_conflict(fields, include_id=True):
    aliases = {"run", "runid"}
    if include_id:
        aliases.add("id")
    values = [
        value for key, value in fields.items()
        if str(key).lower() in aliases and value is not None
    ]
    return len(set(str(value) for value in values)) > 1


def _is_partition_start(fields):
    anchors = _number(fields, "spawnAnchors")
    return anchors is not None and anchors > 0


def _sum_numbers(records, *names):
    """Sum a per-record field, while distinguishing no evidence from a zero."""
    values = []
    for record in records:
        value = _number(record["fields"], *names)
        if value is not None:
            values.append(value)
    return sum(values) if values else None


def _is_measurement_phase(value):
    if value is None:
        return False
    return str(value).strip().upper() in ("MEASURE", "MEASUREMENT", "MEASURING")


def _sample_is_benchmark(fields, start):
    """Apply identical phase-first gating in offline and follow modes."""
    phase = _field(fields, "phase", "measurementPhase")
    if phase is not None:
        return _is_measurement_phase(phase)
    sample_time = _number(fields, "t", "elapsed")
    warmup = _number(start, "warmupSec", "warmup") or 0.0
    return sample_time is None or sample_time >= warmup


def _histogram(value):
    """Normalize common compact/SQF histogram encodings to ``{"size": count}``."""
    if value is None:
        return None
    parsed = value
    if isinstance(value, str):
        text = value.strip()
        if not text:
            return None
        try:
            parsed = json.loads(text)
        except (TypeError, ValueError):
            parsed = None
        if parsed is None:
            pairs = re.findall(
                r"([+-]?\d+(?:\.\d+)?)\s*(?::|=|x)\s*([+-]?\d+(?:\.\d+)?)",
                text,
                re.IGNORECASE,
            )
            if pairs:
                parsed = pairs
            else:
                return None

    if isinstance(parsed, dict):
        items = parsed.items()
    elif isinstance(parsed, (list, tuple)):
        items = parsed
    else:
        return None

    normalized = {}
    for item in items:
        if not isinstance(item, (list, tuple)) or len(item) < 2:
            continue
        size = _parse_value(str(item[0]))
        count = _parse_value(str(item[1]))
        if isinstance(size, bool) or not isinstance(size, (int, float)):
            continue
        if isinstance(count, bool) or not isinstance(count, (int, float)):
            continue
        size = _trim_number(size)
        count = _trim_number(count)
        if size is None or count is None:
            continue
        normalized[str(size)] = count
    return normalized or None


def _string_list(value):
    """Normalize a JSON/SQF-style list or compact comma list to strings."""
    if value is None:
        return []
    parsed = value
    if isinstance(value, str):
        text = value.strip()
        if not text or text.lower() == "none":
            return []
        try:
            parsed = json.loads(text)
        except (TypeError, ValueError):
            parsed = [
                item.strip().strip('"\'')
                for item in re.split(r"[;,]", text.strip("[]"))
            ]
    if not isinstance(parsed, (list, tuple)):
        parsed = [parsed]
    return [str(item) for item in parsed if item is not None and str(item)]


def _sample_ai(fields):
    direct = _number(fields, "ai", "aiTotal", "AI_TOT")
    if direct is not None:
        return direct
    pieces = [
        _number(fields, "srvAi", "serverAi"),
        _number(fields, "hcAi"),
        _number(fields, "otherAi"),
    ]
    if any(value is not None for value in pieces):
        return sum(value or 0 for value in pieces)
    return None


def _sample_hc_pct(fields):
    explicit = _number(fields, "hcPct", "hc_pct")
    if explicit is not None:
        return explicit, "hcPct"

    hc_ai = _number(fields, "hcAi")
    ai_total = _sample_ai(fields)
    if hc_ai is not None and ai_total is not None and ai_total > 0:
        return (100.0 * hc_ai / ai_total), "ownerAi"

    # Legacy/fallback probes only know that a unit is remote to the server.
    # Keep this usable, but expose the weaker basis in the summary.
    remote = _number(fields, "remotePct", "remote_pct")
    if remote is not None:
        return remote, "remotePct"
    return None, None


def percentile(values, percent):
    """Linear percentile (same rank interpolation used by common data tools)."""
    if not values:
        return None
    ordered = sorted(float(value) for value in values)
    if len(ordered) == 1:
        return ordered[0]
    rank = (len(ordered) - 1) * (float(percent) / 100.0)
    low = int(rank)
    high = min(low + 1, len(ordered) - 1)
    fraction = rank - low
    return ordered[low] + ((ordered[high] - ordered[low]) * fraction)


def fatal_matches(line):
    return [code for code, pattern in FATAL_PATTERNS if pattern.search(line)]


class RunState(object):
    """All normalized records and derived metrics for one START-delimited run."""

    def __init__(self, start_event, start_line=None):
        self.start = dict(start_event["fields"])
        self.start_line = start_line
        self.events = []
        self.phase_records = []
        self.samples = []
        self.batches = []
        self.realized_records = []
        self.composition_records = []
        self.bus_records = []
        self.pathlegs = []
        self.scheduler_records = []
        self.protocol_alerts = []
        self.cleanup = None
        self.result = None
        self.fatals = {}
        self.post_result_fatal = False
        for issue in start_event.get("protocol_issues", []):
            stored_issue = {
                "kind": issue["kind"],
                "fields": dict(issue.get("fields") or {}),
            }
            if start_line is not None:
                stored_issue["line"] = start_line
            self.protocol_alerts.append(stored_issue)
        if _run_alias_conflict(self.start):
            conflict = {
                "kind": "START_RUN_ALIAS_CONFLICT",
                "fields": {"eventKind": "START"},
            }
            if start_line is not None:
                conflict["line"] = start_line
            self.protocol_alerts.append(conflict)

    def ingest(self, line, event=None, line_number=None):
        """Ingest one post-START RPT line and return new fatal signature codes."""
        new_fatals = []
        if event is None:
            event = parse_marker(line)
        if event is not None and event["kind"] != "START":
            start_run = _run_identity(self.start)
            event_run = (
                _run_identity(event["fields"])
                if event["kind"] == "RESULT"
                else _field(event["fields"], "run", "runId")
            )
            for issue in event.get("protocol_issues", []):
                stored_issue = {
                    "kind": issue["kind"],
                    "fields": dict(issue.get("fields") or {}),
                }
                if line_number is not None:
                    stored_issue["line"] = line_number
                self.protocol_alerts.append(stored_issue)
            if _run_alias_conflict(
                event["fields"], include_id=event["kind"] == "RESULT"
            ):
                conflict = {
                    "kind": "EVENT_RUN_ALIAS_CONFLICT",
                    "fields": {"eventKind": event["kind"]},
                }
                if line_number is not None:
                    conflict["line"] = line_number
                self.protocol_alerts.append(conflict)
            if _is_partition_start(self.start) and event_run is None:
                missing = {
                    "kind": "EVENT_RUN_MISSING",
                    "fields": {"eventKind": event["kind"]},
                }
                if line_number is not None:
                    missing["line"] = line_number
                self.protocol_alerts.append(missing)
            if (
                start_run is not None
                and event_run is not None
                and str(start_run) != str(event_run)
            ):
                mismatch = {
                    "kind": "EVENT_RUN_MISMATCH",
                    "fields": {
                        "eventKind": event["kind"],
                        "eventRun": event_run,
                        "startRun": start_run,
                    },
                }
                if line_number is not None:
                    mismatch["line"] = line_number
                self.protocol_alerts.append(mismatch)
            stored = {
                "kind": event["kind"],
                "fields": dict(event["fields"]),
            }
            if line_number is not None:
                stored["line"] = line_number
            self.events.append(stored)
            if event["kind"] == "PHASE":
                self.phase_records.append(stored)
            elif event["kind"] == "SAMPLE":
                self.samples.append(stored)
            elif event["kind"] == "BATCH":
                self.batches.append(stored)
            elif event["kind"] == "REALIZED":
                self.realized_records.append(stored)
            elif event["kind"] == "COMPOSITION":
                self.composition_records.append(stored)
            elif event["kind"] == "BUS":
                self.bus_records.append(stored)
            elif event["kind"] == "PATHLEG":
                self.pathlegs.append(stored)
            elif event["kind"] == "SCHED":
                self.scheduler_records.append(stored)
            elif event["kind"] in ("ALERT", "ABORT", "SPAWN_FAIL", "BUS_REJECT"):
                self.protocol_alerts.append(stored)
            elif event["kind"] == "CLEANUP":
                self.cleanup = dict(event["fields"])
            elif event["kind"] == "RESULT":
                self.result = dict(event["fields"])

        # Protocol lines are data, not engine diagnostics.  Excluding them also
        # prevents a free-text RESULT reason from spoofing a fatal signature.
        if event is None:
            for code in fatal_matches(line):
                entry = self.fatals.setdefault(code, {"count": 0, "examples": []})
                entry["count"] += 1
                clean = line.strip()
                if len(entry["examples"]) < 3 and clean not in entry["examples"]:
                    entry["examples"].append(clean[:300])
                new_fatals.append(code)
        return new_fatals

    def _observations(self):
        fps_values = []
        ai_values = []
        group_values = []
        hc_values = []
        hc_bases = set()
        hc_imbalance_values = []
        hc_group_imbalance_values = []
        hc_count_values = []
        hc_fps_values = []
        hc_fresh_values = []
        stuck_values = []
        remote_values = []
        boot_fps_values = []
        benchmark_sample_count = 0
        measurement_sample_count = 0
        warmup = _number(self.start, "warmupSec", "warmup") or 0.0

        for sample in self.samples:
            fields = sample["fields"]
            sample_phase = _field(fields, "phase", "measurementPhase")
            post_warmup = _sample_is_benchmark(fields, self.start)
            if sample_phase is not None and post_warmup:
                measurement_sample_count += 1
            fps = _number(fields, "fps", "serverFps", "srvFps")
            if fps is not None and not post_warmup:
                boot_fps_values.append(fps)
            if not post_warmup:
                continue
            benchmark_sample_count += 1
            if fps is not None:
                fps_values.append(fps)
            ai = _sample_ai(fields)
            if ai is not None:
                ai_values.append(ai)
            groups = _number(fields, "groups", "groupCount")
            if groups is not None:
                group_values.append(groups)
            hc_pct, basis = _sample_hc_pct(fields)
            hc_count = _number(fields, "hcs", "hcOwners", "hc_count")
            if hc_count is not None:
                hc_count_values.append(hc_count)
            if hc_pct is not None and (ai is None or ai >= 40):
                hc_values.append(hc_pct)
                if basis:
                    hc_bases.add(basis)
            remote_pct = _number(fields, "remotePct", "remote_pct")
            if remote_pct is not None:
                remote_values.append(remote_pct)
            hc_imbalance = _number(fields, "hcImbalancePct")
            if hc_imbalance is not None and hc_imbalance >= 0:
                hc_imbalance_values.append(hc_imbalance)
            hc_group_imbalance = _number(fields, "hcGroupImbalancePct")
            if hc_group_imbalance is not None and hc_group_imbalance >= 0:
                hc_group_imbalance_values.append(hc_group_imbalance)
            hc_fps = _number(fields, "hcFpsMin")
            if hc_fps is not None and hc_fps >= 0:
                hc_fps_values.append(hc_fps)
            hc_fresh = _number(fields, "hcFresh")
            if hc_fresh is not None:
                hc_fresh_values.append(hc_fresh)
            stuck = _number(fields, "stuck", "stuckUnits")
            if stuck is not None:
                stuck_values.append(stuck)

        # A BATCH can be the exact crest between periodic SAMPLE ticks.
        for batch in self.batches:
            fields = batch["fields"]
            batch_time = _number(fields, "t", "elapsed")
            if batch_time is not None and batch_time < warmup:
                continue
            ai = _sample_ai(fields)
            if ai is not None:
                ai_values.append(ai)
            groups = _number(fields, "groups", "groupCount")
            if groups is not None:
                group_values.append(groups)

        for leg in self.pathlegs:
            leg_time = _number(leg["fields"], "t", "elapsed")
            if leg_time is not None and leg_time < warmup:
                continue
            stuck = _number(leg["fields"], "stuck", "stuckUnits")
            if stuck is not None:
                stuck_values.append(stuck)

        return {
            "fps": fps_values,
            "ai": ai_values,
            "groups": group_values,
            "hc_pct": hc_values,
            "hc_bases": sorted(hc_bases),
            "hc_imbalance": hc_imbalance_values,
            "hc_group_imbalance": hc_group_imbalance_values,
            "hc_count": hc_count_values,
            "hc_fps": hc_fps_values,
            "hc_fresh": hc_fresh_values,
            "remote_pct": remote_values,
            "stuck": stuck_values,
            "boot_fps": boot_fps_values,
            "warmup_sec": warmup,
            "benchmark_sample_count": benchmark_sample_count,
            "measurement_sample_count": measurement_sample_count,
        }

    def _bus_summary(self):
        if not self.bus_records and not self.result:
            return None

        interval = {"sent": 0.0, "ack": 0.0, "loss": 0.0}
        interval_seen = set()
        cumulative = {"sent": None, "ack": None, "loss": None}
        latencies = []

        for record in self.bus_records:
            fields = record["fields"]
            for output, aliases in (
                ("sent", ("sent", "sentDelta")),
                ("ack", ("ack", "ackDelta")),
                ("loss", ("loss", "drop", "lossDelta", "dropDelta")),
            ):
                value = _number(fields, *aliases)
                if value is not None:
                    interval[output] += value
                    interval_seen.add(output)
            for output, aliases in (
                ("sent", ("sentTotal",)),
                ("ack", ("ackTotal",)),
                ("loss", ("dropTotal", "lossTotal")),
            ):
                value = _number(fields, *aliases)
                if value is not None:
                    cumulative[output] = value
            latency = _number(fields, "latencyMs", "latency", "latencyAvgMs")
            if latency is not None:
                latencies.append(latency)

        result = self.result or {}
        reported = {
            "sent": _number(result, "busSentPost", "busSent"),
            "ack": _number(result, "busAckPost", "busAck"),
            "loss": _number(result, "busLoss", "busDrop"),
        }

        summary = {"records": len(self.bus_records)}
        sources = set()
        for key in ("sent", "ack", "loss"):
            if reported[key] is not None:
                summary[key] = _trim_number(reported[key])
                sources.add("result")
            elif cumulative[key] is not None:
                summary[key] = _trim_number(cumulative[key])
                sources.add("cumulative")
            elif key in interval_seen:
                summary[key] = _trim_number(interval[key])
                sources.add("interval")
            else:
                summary[key] = None

        result_latency = _number(result, "busLatencyAvgMs", "busLatencyMs")
        if result_latency is not None:
            summary["latency_ms"] = _trim_number(result_latency)
            sources.add("result")
        elif latencies:
            summary["latency_ms"] = _trim_number(statistics.median(latencies))
        else:
            summary["latency_ms"] = None
        summary["latency_ms_median"] = (
            _trim_number(statistics.median(latencies)) if latencies else None
        )
        summary["latency_ms_max"] = _trim_number(max(latencies)) if latencies else None
        summary["attempt_post"] = _trim_number(_number(result, "busAttemptPost"))
        summary["sent_post"] = _trim_number(_number(result, "busSentPost"))
        summary["expected"] = _trim_number(_number(result, "busExpected"))
        summary["attainment_pct"] = _trim_number(_number(result, "busAttainPct"))
        summary["fresh_endpoints"] = _trim_number(_number(result, "busFreshEndpoints"))
        summary["sent_total"] = _trim_number(_number(result, "busSentTotal"))
        summary["ack_total"] = _trim_number(_number(result, "busAckTotal"))
        summary["source"] = "+".join(sorted(sources)) if sources else None
        return summary

    def _scheduler_summary(self):
        result = self.result or {}
        mode = _field(result, "schedulerMode") or _field(self.start, "schedulerMode")
        if not self.scheduler_records and (mode is None or str(mode).lower() == "off"):
            return None

        elapsed = []
        frame_delta = []
        due = []
        deferred = []
        queued = []
        oldest = []
        overruns = []
        for record in self.scheduler_records:
            fields = record["fields"]
            for target, names in (
                (elapsed, ("elapsedMs", "spentMs")),
                (frame_delta, ("frameDelta",)),
                (due, ("due",)),
                (deferred, ("deferred",)),
                (queued, ("queued",)),
                (oldest, ("oldestMs",)),
                (overruns, ("overruns",)),
            ):
                value = _number(fields, *names)
                if value is not None:
                    target.append(value)

        return {
            "mode": mode,
            "records": len(self.scheduler_records),
            "runs": _trim_number(_number(result, "schedRuns")),
            "deferred_total": _trim_number(_number(result, "schedDeferred")),
            "overruns_total": _trim_number(_number(result, "schedOverruns")),
            "errors_total": _trim_number(_number(result, "schedErrors")),
            "max_elapsed_ms": _trim_number(
                _number(result, "schedMaxElapsedMs")
                if _number(result, "schedMaxElapsedMs") is not None
                else max(elapsed) if elapsed else None
            ),
            "max_frame_delta": _trim_number(max(frame_delta)) if frame_delta else None,
            "max_due": _trim_number(max(due)) if due else None,
            "max_deferred": _trim_number(max(deferred)) if deferred else None,
            "max_queued": _trim_number(max(queued)) if queued else None,
            "max_oldest_ms": _trim_number(max(oldest)) if oldest else None,
            "observed_overruns": _trim_number(max(overruns)) if overruns else None,
        }

    def _phase_summary(self):
        result = self.result or {}
        records = []
        sequence = []
        measure_start = _number(
            result,
            "measurementStart",
            "measurementStartedAt",
            "measureStart",
            "measureStartT",
        )
        measurement_phase = _field(result, "measurementPhase", "measurePhase")
        current = _field(result, "finalPhase", "phase")
        go_at = None
        measurement_started_phase = None

        for record in self.phase_records:
            fields = dict(record["fields"])
            phase = _field(fields, "phase", "state", "name")
            at = _number(fields, "t", "elapsed", "at")
            if phase is not None:
                phase = str(phase).upper()
                sequence.append(phase)
                current = phase
                if phase == "GO" and go_at is None:
                    go_at = at
                    measurement_started_phase = "GO"
                    if measure_start is None:
                        measure_start = _number(
                            fields,
                            "measurementStart",
                            "measurementStartedAt",
                            "measureStart",
                        )
                    if measure_start is None:
                        measure_start = at
                if _is_measurement_phase(phase):
                    measurement_phase = phase
                    if measure_start is None:
                        measure_start = _number(
                            fields,
                            "measurementStart",
                            "measurementStartedAt",
                            "measureStart",
                        )
                    if measure_start is None:
                        measure_start = at
                    if measurement_started_phase is None:
                        measurement_started_phase = phase
            stored = {"fields": fields}
            if "line" in record:
                stored["line"] = record["line"]
            records.append(stored)

        if measurement_phase is None:
            for sample in reversed(self.samples):
                phase = _field(sample["fields"], "phase", "measurementPhase")
                if _is_measurement_phase(phase):
                    measurement_phase = str(phase).upper()
                    break

        measurement_seconds = _number(
            result,
            "measurementSeconds",
            "measurementDuration",
            "measureSeconds",
            "measureDuration",
            "measureT",
        )
        if measurement_seconds is None:
            measurement_seconds = _latest_number(
                self.samples,
                "measurementElapsed",
                "measureElapsed",
                "measureT",
            )

        return {
            "count": len(self.phase_records),
            "current": current,
            "sequence": sequence,
            "go_at": _trim_number(go_at),
            "measurement_phase": measurement_phase,
            "measurement_started_phase": measurement_started_phase,
            "measurement_started_at": _trim_number(measure_start),
            "measurement_seconds": _trim_number(measurement_seconds),
            "records": records,
        }

    def _realized_evidence(self):
        """Aggregate strict per-group evidence without trusting cumulative rows."""
        aliases = (
            ("requested_infantry", ("requestedInfantry", "infantryRequested", "requested")),
            ("created_infantry", ("createdInfantry", "infantryCreated", "created")),
            ("crew", ("crew", "createdCrew", "crewCreated", "createdCrewMembers")),
            ("vehicles", ("vehicles", "createdVehicles", "vehiclesCreated", "vehicleCount")),
            ("final_members", ("finalMembers", "membersFinal", "realizedMembers", "members", "groupSize")),
            ("underfill_groups", ("underfill", "underfills", "underfillGroups", "groupsUnderfilled")),
            ("oversize_groups", ("oversize", "oversizes", "oversizeGroups", "groupsOversize")),
            ("create_failures", ("createFailures", "creationFailures", "createFails", "failures")),
            ("create_failure_groups", ("createFailure", "createFailureGroups", "creationFailureGroups", "failedGroups")),
        )
        totals = dict((name, 0.0) for name, _ in aliases)
        group_ids = []
        histogram = {}
        anchor_requested = {}
        anchor_members = {}
        valid_count = 0
        arm = _number(self.start, "unitsPerGroup")
        arm_valid = arm is not None and arm >= 1 and arm.is_integer()

        for record in self.realized_records:
            fields = record["fields"]
            group_id = _number(fields, "group", "groupId", "groupIndex")
            anchor = _number(fields, "anchor", "anchorId", "spawnAnchor")
            group_valid = (
                group_id is not None and group_id >= 1 and group_id.is_integer()
            )
            anchor_valid = (
                anchor is not None and anchor >= 0 and anchor.is_integer()
            )
            if group_valid:
                group_ids.append(int(group_id))

            values = {}
            row_complete = group_valid and anchor_valid
            for name, names in aliases:
                value = _number(fields, *names)
                values[name] = value
                if value is None or value < 0 or not value.is_integer():
                    row_complete = False
            if not row_complete:
                continue

            for name in totals:
                totals[name] += values[name]
            size_key = str(_trim_number(values["final_members"]))
            histogram[size_key] = histogram.get(size_key, 0) + 1
            anchor_key = str(int(anchor))
            anchor_requested[anchor_key] = (
                anchor_requested.get(anchor_key, 0.0) + values["requested_infantry"]
            )
            anchor_members[anchor_key] = (
                anchor_members.get(anchor_key, 0.0) + values["final_members"]
            )
            row_valid = arm_valid and (
                values["requested_infantry"] == arm
                and values["created_infantry"] == arm
                and values["final_members"] == arm
                and all(
                    values[name] == 0
                    for name in (
                        "crew",
                        "vehicles",
                        "underfill_groups",
                        "oversize_groups",
                        "create_failures",
                        "create_failure_groups",
                    )
                )
            )
            if row_valid:
                valid_count += 1

        evidence = {
            "record_count": len(self.realized_records),
            "valid_count": valid_count,
            "group_ids": sorted(group_ids),
            "histogram": histogram,
            "anchor_requested": dict(
                (key, _trim_number(value)) for key, value in anchor_requested.items()
            ),
            "anchor_members": dict(
                (key, _trim_number(value)) for key, value in anchor_members.items()
            ),
        }
        evidence.update((name, _trim_number(value)) for name, value in totals.items())
        return evidence

    def _sample_evidence(self):
        """Expose counters from phase-scoped measurement samples only."""
        records = [
            sample for sample in self.samples
            if _is_measurement_phase(
                _field(sample["fields"], "phase", "measurementPhase")
            )
        ]
        member_values = []
        group_values = []
        measure_t_values = []
        for record in records:
            member_seconds = _number(
                record["fields"], "memberSeconds", "membersSeconds"
            )
            group_seconds = _number(
                record["fields"], "groupSeconds", "groupsSeconds"
            )
            measure_t = _number(
                record["fields"], "measureT", "measurementElapsed", "measureElapsed"
            )
            if member_seconds is not None:
                member_values.append(member_seconds)
            if group_seconds is not None:
                group_values.append(group_seconds)
            if measure_t is not None:
                measure_t_values.append(measure_t)

        def monotonic(values):
            return all(
                current >= previous
                for previous, current in zip(values, values[1:])
            )

        def strictly_increasing(values):
            return all(
                current > previous
                for previous, current in zip(values, values[1:])
            )

        duration = _number(self.start, "duration")
        sample_sec = _number(self.start, "sampleSec")
        measure_t_in_bounds = None
        terminal_progress_ok = None
        if duration is not None and sample_sec is not None and sample_sec > 0:
            measure_t_in_bounds = (
                len(measure_t_values) == len(records)
                and all(
                    0 <= value <= duration + sample_sec
                    for value in measure_t_values
                )
            )
            terminal_progress_ok = (
                bool(measure_t_values)
                and measure_t_values[-1] >= max(0.0, duration - sample_sec)
            )

        return {
            "record_count": len(records),
            "member_seconds_count": len(member_values),
            "group_seconds_count": len(group_values),
            "latest_member_seconds": (
                _trim_number(member_values[-1]) if member_values else None
            ),
            "latest_group_seconds": (
                _trim_number(group_values[-1]) if group_values else None
            ),
            "member_seconds_monotonic": monotonic(member_values),
            "group_seconds_monotonic": monotonic(group_values),
            "measure_t_count": len(measure_t_values),
            "measure_t_values": [_trim_number(value) for value in measure_t_values],
            "latest_measure_t": (
                _trim_number(measure_t_values[-1]) if measure_t_values else None
            ),
            "measure_t_monotonic": strictly_increasing(measure_t_values),
            "measure_t_unique_count": len(set(measure_t_values)),
            "measure_t_in_bounds": measure_t_in_bounds,
            "terminal_progress_ok": terminal_progress_ok,
        }

    def _composition_summary(self):
        result = self.result or {}
        latest_composition = (
            self.composition_records[-1]["fields"] if self.composition_records else {}
        )
        latest_phase = self.phase_records[-1]["fields"] if self.phase_records else {}
        latest_sample = self.samples[-1]["fields"] if self.samples else {}
        if _field(
            latest_sample,
            "targetSyntheticUnits",
            "requestedInfantry",
            "finalMembers",
        ) is None:
            # Legacy SAMPLE ``vehicles`` is a world total, not realized lab composition.
            latest_sample = {}
        cumulative_sources = (result, latest_sample, latest_composition, latest_phase)

        def aggregate(*names):
            value = None
            for source in cumulative_sources:
                value = _number(source, *names)
                if value is not None:
                    break
            if value is None:
                value = _sum_numbers(self.realized_records, *names)
            return value

        def raw(*names):
            for source in cumulative_sources:
                value = _field(source, *names)
                if value is not None:
                    return value
            return None

        target = None
        for source in cumulative_sources + (self.start,):
            target = _number(
                source,
                "targetSyntheticUnits",
                "syntheticUnitsTarget",
                "targetUnits",
            )
            if target is not None:
                break

        requested_infantry = aggregate(
            "requestedInfantry", "infantryRequested", "requested"
        )
        created_infantry = aggregate(
            "createdInfantry", "infantryCreated", "created"
        )
        crew = aggregate("crew", "createdCrew", "crewCreated", "createdCrewMembers")
        vehicles = aggregate(
            "createdVehicles", "vehiclesCreated", "vehicleCount", "vehicles"
        )
        final_members = aggregate(
            "finalMembers", "membersFinal", "realizedMembers", "members"
        )
        underfill = aggregate(
            "underfill", "underfills", "underfillGroups", "groupsUnderfilled"
        )
        oversize = aggregate(
            "oversize", "oversizes", "oversizeGroups", "groupsOversize"
        )
        create_failures = aggregate(
            "createFailures", "creationFailures", "createFails", "failures"
        )
        create_failure_groups = aggregate(
            "createFailureGroups", "creationFailureGroups", "failedGroups"
        )
        if create_failures is None:
            spawn_failures = sum(
                1 for item in self.protocol_alerts if item["kind"] == "SPAWN_FAIL"
            )
            create_failures = spawn_failures if spawn_failures else None

        histogram_value = raw(
            "finalMemberHistogram",
            "finalMembersHistogram",
            "memberHistogram",
            "groupSizeHistogram",
            "histogram",
            "hist",
        )
        histogram = _histogram(histogram_value)
        if histogram is None:
            histogram = {}
            records = self.realized_records or self.composition_records
            for record in records:
                size = _number(
                    record["fields"],
                    "finalMembers",
                    "membersFinal",
                    "realizedMembers",
                    "members",
                    "groupSize",
                )
                if size is not None:
                    key = str(_trim_number(size))
                    histogram[key] = histogram.get(key, 0) + 1
            if not histogram:
                histogram = None

        realized_groups = aggregate("realizedGroups", "finalGroups", "createdGroups")
        final_groups = realized_groups
        if final_groups is None and histogram:
            final_groups = sum(histogram.values())
        if final_groups is None and self.realized_records:
            final_groups = len(self.realized_records)

        attainment = _number(
            result, "syntheticAttainmentPct", "attainmentPct", "createdPct"
        )
        if attainment is None:
            denominator = target if target is not None and target > 0 else requested_infantry
            if denominator is not None and denominator > 0 and created_infantry is not None:
                attainment = 100.0 * created_infantry / denominator
        final_attainment = None
        if target is not None and target > 0 and final_members is not None:
            final_attainment = 100.0 * final_members / target

        return {
            "target_synthetic_units": _trim_number(target),
            "target_groups": _trim_number(
                aggregate("targetGroups")
                if aggregate("targetGroups") is not None
                else _number(self.start, "targetGroups")
            ),
            "spawn_anchors": raw("spawnAnchors"),
            "anchor_requested": _histogram(raw("anchorRequested")),
            "anchor_members": _histogram(raw("anchorMembers")),
            "realized_groups": _trim_number(realized_groups),
            "requested_infantry": _trim_number(requested_infantry),
            "created_infantry": _trim_number(created_infantry),
            "crew": _trim_number(crew),
            "vehicles": _trim_number(vehicles),
            "final_members": _trim_number(final_members),
            "final_groups": _trim_number(final_groups),
            "histogram": histogram,
            "underfill_groups": _trim_number(underfill),
            "oversize_groups": _trim_number(oversize),
            "create_failures": _trim_number(create_failures),
            "create_failure_groups": _trim_number(create_failure_groups),
            "attainment_pct": _trim_number(attainment),
            "final_member_attainment_pct": _trim_number(final_attainment),
            "realized_record_count": len(self.realized_records),
            "composition_record_count": len(self.composition_records),
            "realized_evidence": self._realized_evidence(),
        }

    def _work_summary(self, phase):
        result = self.result or {}
        member_seconds = _number(
            result, "memberSeconds", "membersSeconds", "syntheticMemberSeconds"
        )
        group_seconds = _number(result, "groupSeconds", "groupsSeconds")
        sources = []
        if member_seconds is not None or group_seconds is not None:
            sources.append("result")
        if member_seconds is None:
            values = [
                _number(item["fields"], "memberSeconds", "membersSeconds")
                for item in self.samples
            ]
            values = [value for value in values if value is not None]
            if values:
                member_seconds = max(values)
                sources.append("sample")
        if group_seconds is None:
            values = [
                _number(item["fields"], "groupSeconds", "groupsSeconds")
                for item in self.samples
            ]
            values = [value for value in values if value is not None]
            if values:
                group_seconds = max(values)
                sources.append("sample")
        fallback_records = self.composition_records + self.phase_records
        if member_seconds is None:
            member_seconds = _latest_number(fallback_records, "memberSeconds", "membersSeconds")
            if member_seconds is not None:
                sources.append("phase")
        if group_seconds is None:
            group_seconds = _latest_number(fallback_records, "groupSeconds", "groupsSeconds")
            if group_seconds is not None:
                sources.append("phase")

        measurement_seconds = _number(phase, "measurement_seconds")
        average_members = None
        average_groups = None
        if measurement_seconds is not None and measurement_seconds > 0:
            if member_seconds is not None:
                average_members = member_seconds / measurement_seconds
            if group_seconds is not None:
                average_groups = group_seconds / measurement_seconds
        return {
            "member_seconds": _trim_number(member_seconds),
            "group_seconds": _trim_number(group_seconds),
            "measurement_seconds": _trim_number(measurement_seconds),
            "average_members": _trim_number(average_members),
            "average_groups": _trim_number(average_groups),
            "source": "+".join(sorted(set(sources))) if sources else None,
            "sample_evidence": self._sample_evidence(),
        }

    def _path_summary(self):
        result = self.result or {}
        status_totals = {}
        routes = {}
        completed_from_records = 0
        arrival_units_from_records = 0.0
        arrival_units_seen = False

        for leg in self.pathlegs:
            fields = leg["fields"]
            status = str(_field(fields, "status") or "UNKNOWN").upper()
            is_started = status == "STARTED"
            is_completed = status in ("ARRIVED", "PASS", "COMPLETE", "COMPLETED")
            status_totals[status] = status_totals.get(status, 0) + 1
            if is_completed:
                completed_from_records += 1
            units = _number(fields, "arrivalUnits", "arrivedUnits", "units")
            if units is not None and is_completed:
                arrival_units_from_records += units
                arrival_units_seen = True

            route_id = _field(fields, "routeId", "routeIdentity", "route")
            if route_id is None:
                from_name = _field(fields, "from", "fromAnchor", "startAnchor")
                to_name = _field(fields, "to", "toAnchor", "targetAnchor")
                if from_name is not None or to_name is not None:
                    route_id = "%s->%s" % (from_name or "?", to_name or "?")
            if route_id is None:
                route_id = _field(fields, "leg")
            if route_id is None:
                continue
            route_id = str(route_id)
            route = routes.setdefault(
                route_id,
                {
                    "records": 0,
                    "started": 0,
                    "completed": 0,
                    "status": {},
                    "arrived": 0.0,
                    "units": 0.0,
                    "elapsed": [],
                },
            )
            route["records"] += 1
            if is_started:
                route["started"] += 1
            if is_completed:
                route["completed"] += 1
            route["status"][status] = route["status"].get(status, 0) + 1
            arrived = _number(fields, "arrived", "arrivals")
            if arrived is None and is_completed:
                arrived = 1
            if arrived is not None and is_completed:
                route["arrived"] += arrived
            if units is not None and is_completed:
                route["units"] += units
            elapsed = _number(fields, "elapsed", "elapsedSec", "duration")
            if elapsed is not None and is_completed:
                route["elapsed"].append(elapsed)

        route_ids_value = _field(result, "routeIds")
        if route_ids_value is None:
            for record in reversed(
                self.samples + self.composition_records + self.phase_records
            ):
                route_ids_value = _field(record["fields"], "routeIds")
                if route_ids_value is not None:
                    break
        declared_route_ids = _string_list(route_ids_value)
        for record in self.realized_records:
            route_id = _field(record["fields"], "routeId", "routeIdentity", "route")
            if route_id is not None and str(route_id) not in declared_route_ids:
                declared_route_ids.append(str(route_id))
        for route_id in declared_route_ids:
            routes.setdefault(
                route_id,
                {
                    "records": 0,
                    "started": 0,
                    "completed": 0,
                    "status": {},
                    "arrived": 0.0,
                    "units": 0.0,
                    "elapsed": [],
                },
            )

        normalized_routes = {}
        for route_id, route in routes.items():
            route_pct = (
                100.0 * route["completed"] / route["started"]
                if route["started"] > 0 else None
            )
            normalized_routes[route_id] = {
                "records": route["records"],
                "started": route["started"],
                "completed": route["completed"],
                "completion_pct": _trim_number(route_pct),
                "arrival_pct": _trim_number(route_pct),
                "status": route["status"],
                "arrived": _trim_number(route["arrived"]),
                "units": _trim_number(route["units"]),
                "elapsed_median": (
                    _trim_number(statistics.median(route["elapsed"]))
                    if route["elapsed"] else None
                ),
            }

        started = _number(
            result, "pathLegsStarted", "routeLegsStarted", "legsStarted"
        )
        if started is None:
            started = _latest_number(
                self.samples + self.composition_records + self.phase_records,
                "pathLegsStarted",
                "routeLegsStarted",
                "legsStarted",
            )
        completed = _number(
            result, "pathLegsCompleted", "routeLegsCompleted", "legsCompleted"
        )
        if completed is None and self.pathlegs:
            completed = completed_from_records
        arrivals = _number(result, "pathArrivals", "arrivals")
        if arrivals is None:
            arrivals = _latest_number(self.samples, "pathArrivals", "arrivals", "arrived")
        if arrivals is None and completed is not None:
            arrivals = completed
        arrival_units = _number(result, "pathArrivalUnits", "arrivalUnits", "arrivedUnits")
        if arrival_units is None and arrival_units_seen:
            arrival_units = arrival_units_from_records

        completion_pct = _number(result, "pathCompletionPct", "completionPct")
        if completion_pct is None and started is not None and started > 0 and completed is not None:
            completion_pct = 100.0 * completed / started
        arrival_pct = _number(
            result, "pathArrivalPct", "arrivalPct", "arrivalRatePct"
        )
        if arrival_pct is None and started is not None and started > 0 and arrivals is not None:
            arrival_pct = 100.0 * arrivals / started
        route_identity = _field(result, "routeId", "routeIdentity", "route")
        if route_identity is None and self.samples:
            route_identity = _field(
                self.samples[-1]["fields"], "routeId", "routeIdentity", "route"
            )
        if route_identity is None and len(declared_route_ids) == 1:
            route_identity = declared_route_ids[0]
        route_rate = _number(
            result,
            "routeRate",
            "pathRate",
            "pathLegsPerGroupSecond",
            "arrivalsPerGroupSecond",
        )

        return {
            "count": len(self.pathlegs),
            "status": status_totals,
            "started": _trim_number(started),
            "completed": _trim_number(completed),
            "completion_pct": _trim_number(completion_pct),
            "arrivals": _trim_number(arrivals),
            "arrival_units": _trim_number(arrival_units),
            "arrival_pct": _trim_number(arrival_pct),
            "route_identity": route_identity,
            "route_ids": sorted(routes),
            "route_rate": _trim_number(route_rate),
            "route_count": len(normalized_routes),
            "routes": normalized_routes,
        }

    def summary(self, min_fps=None, active=False):
        observed = self._observations()
        result = dict(self.result) if self.result is not None else None
        result_fields = result or {}

        fps_values = observed["fps"]
        fps_min = min(fps_values) if fps_values else _number(result_fields, "fpsMin")
        fps_median = statistics.median(fps_values) if fps_values else None
        fps_avg = (
            (sum(fps_values) / len(fps_values))
            if fps_values
            else _number(result_fields, "fpsAvg")
        )
        fps_p5 = percentile(fps_values, 5) if fps_values else fps_min

        ai_peak_values = list(observed["ai"])
        reported_ai_peak = _number(result_fields, "aiPeak")
        if reported_ai_peak is not None:
            ai_peak_values.append(reported_ai_peak)
        group_peak_values = list(observed["groups"])
        reported_groups_peak = _number(result_fields, "groupsPeak")
        if reported_groups_peak is not None:
            group_peak_values.append(reported_groups_peak)

        hc_values = observed["hc_pct"]
        hc_min = min(hc_values) if hc_values else _number(result_fields, "hcPctMin")
        hc_median = statistics.median(hc_values) if hc_values else None

        stuck_values = list(observed["stuck"])
        reported_stuck = _number(result_fields, "stuckMax")
        if reported_stuck is not None:
            stuck_values.append(reported_stuck)

        reported_fps_samples = _number(result_fields, "fpsSamples")
        reported_fps_expected = _number(result_fields, "fpsExpected")
        reported_fps_coverage = _number(result_fields, "fpsCoveragePct")
        hcs_min = _number(result_fields, "hcsMin")
        if hcs_min is not None and hcs_min >= 99:
            hcs_min = None
        if hcs_min is None and observed["hc_count"]:
            hcs_min = min(observed["hc_count"])
        hc_imbalance_max = _number(result_fields, "hcImbalanceMax")
        if hc_imbalance_max is None and observed["hc_imbalance"]:
            hc_imbalance_max = max(observed["hc_imbalance"])
        hc_imbalanced_pct = _number(result_fields, "hcImbalancedPct")
        hc_fps_min = _number(result_fields, "hcFpsMin")
        if (hc_fps_min is None or hc_fps_min < 0) and observed["hc_fps"]:
            hc_fps_min = min(observed["hc_fps"])
        if hc_fps_min is not None and hc_fps_min < 0:
            hc_fps_min = None
        stuck_pct_max = _number(result_fields, "stuckPctMax")
        combat_initial = _number(result_fields, "combatInitial")
        combat_casualties = _number(result_fields, "combatCasualties")
        combat_moved_groups = _number(result_fields, "combatMovedGroups")
        combat_moved_pct = _number(result_fields, "combatMovedPct")

        fatal_summary = []
        for code in sorted(self.fatals):
            entry = self.fatals[code]
            fatal_summary.append(
                {
                    "code": code,
                    "count": entry["count"],
                    "examples": list(entry["examples"]),
                }
            )

        alerts = []
        if min_fps is not None and fps_min is not None and fps_min <= min_fps:
            alerts.append(
                {
                    "code": "FPS_BELOW_MIN",
                    "message": "minimum FPS %s is at or below threshold %s"
                    % (_trim_number(fps_min), _trim_number(min_fps)),
                }
            )
        for fatal in fatal_summary:
            alerts.append(
                {
                    "code": fatal["code"],
                    "message": "%s matching RPT line(s) after START" % fatal["count"],
                }
            )
        if self.post_result_fatal:
            alerts.append(
                {
                    "code": "POST_RESULT_FATAL",
                    "message": "fatal RPT signature appeared after RESULT; a newer failed load may have no START",
                }
            )
        result_status = str(_field(result_fields, "status") or "").upper()
        start_run = _run_identity(self.start)
        if start_run is None:
            alerts.append(
                {
                    "code": "START_RUN_MISSING",
                    "message": "START marker has no run ID",
                }
            )
        if self.result is not None and not result_status:
            alerts.append(
                {
                    "code": "RESULT_STATUS_MISSING",
                    "message": "RESULT marker has no status field",
                }
            )
        elif result_status and result_status not in ("PASS", "OK"):
            alerts.append(
                {
                    "code": "RESULT_%s" % result_status,
                    "message": "harness result status is %s" % result_status,
                }
            )
        if self.result is not None:
            result_run = _run_identity(result_fields)
            if result_run is None:
                alerts.append(
                    {
                        "code": "RESULT_RUN_MISSING",
                        "message": "RESULT marker has no run ID",
                    }
                )
            if _number(result_fields, "complete") != 1:
                alerts.append(
                    {
                        "code": "RESULT_INCOMPLETE",
                        "message": "RESULT marker is missing its final complete=1 field",
                    }
                )
            if result_run is not None and start_run is not None and str(result_run) != str(start_run):
                alerts.append(
                    {
                        "code": "RUN_ID_MISMATCH",
                        "message": "RESULT run %s does not match START run %s" % (result_run, start_run),
                    }
                )
        if self.result is None:
            alerts.append(
                {
                    "code": "RUN_ACTIVE" if active else "RUN_INCOMPLETE",
                    "message": "run has START but no RESULT marker",
                }
            )
        if len(fps_values) < 1:
            alerts.append(
                {
                    "code": "NO_BENCHMARK_SAMPLES",
                    "message": "run has no post-warmup SAMPLE containing FPS",
                }
            )
        cleanup_fields = self.cleanup or result_fields
        cleanup_objects = _number(cleanup_fields, "objectsRemaining", "cleanupObjectsRemaining")
        cleanup_groups = _number(cleanup_fields, "groupsRemaining", "cleanupGroupsRemaining")
        if (cleanup_objects is not None and cleanup_objects > 0) or (cleanup_groups is not None and cleanup_groups > 0):
            alerts.append(
                {
                    "code": "CLEANUP_INCOMPLETE",
                    "message": "lab cleanup left objects or groups alive",
                }
            )
        expected_samples = None
        calculated_coverage = None
        start_duration = _number(self.start, "duration")
        start_sample_sec = _number(self.start, "sampleSec")
        warmup_sec = observed["warmup_sec"]
        phase_scoped_measure = observed["measurement_sample_count"] > 0 or any(
            _is_measurement_phase(_field(record["fields"], "phase", "state", "name"))
            for record in self.phase_records
        )
        if start_duration is not None and start_sample_sec is not None and start_sample_sec > 0:
            measured_duration = (
                start_duration if phase_scoped_measure
                else max(0.0, start_duration - warmup_sec)
            )
            expected_samples = max(1, int(measured_duration // start_sample_sec))
            calculated_coverage = 100.0 * len(fps_values) / expected_samples
            if self.result is not None and calculated_coverage < 80:
                alerts.append(
                    {
                        "code": "SAMPLE_COVERAGE_LOW",
                        "message": "post-warmup FPS sample coverage %.1f%% (%s/%s)" % (calculated_coverage, len(fps_values), expected_samples),
                    }
                )
        if self.result is not None and phase_scoped_measure:
            time_evidence = self._sample_evidence()
            time_problems = []
            if time_evidence["measure_t_count"] != time_evidence["record_count"]:
                time_problems.append("not every MEASURE sample has finite measureT")
            if not time_evidence["measure_t_monotonic"]:
                time_problems.append("measureT is not strictly increasing")
            if time_evidence["measure_t_unique_count"] != time_evidence["measure_t_count"]:
                time_problems.append("measureT contains duplicates")
            if time_evidence["measure_t_in_bounds"] is not True:
                time_problems.append("measureT is outside the measurement window")
            if time_evidence["terminal_progress_ok"] is not True:
                time_problems.append("measureT does not reach the final sample interval")
            if time_problems:
                alerts.append(
                    {
                        "code": "MEASURE_TIME_INVALID",
                        "message": "; ".join(time_problems),
                    }
                )

        if self.result is not None:
            sample_inconsistencies = []
            if reported_fps_samples is not None and reported_fps_samples != len(fps_values):
                sample_inconsistencies.append(
                    "fpsSamples=%s observed=%s"
                    % (_trim_number(reported_fps_samples), len(fps_values))
                )
            if reported_fps_expected is not None and expected_samples is not None and reported_fps_expected != expected_samples:
                sample_inconsistencies.append(
                    "fpsExpected=%s calculated=%s"
                    % (_trim_number(reported_fps_expected), expected_samples)
                )
            if reported_fps_coverage is not None and reported_fps_samples is not None and reported_fps_expected is not None and reported_fps_expected > 0:
                producer_coverage = 100.0 * reported_fps_samples / reported_fps_expected
                if abs(reported_fps_coverage - producer_coverage) > 0.2:
                    sample_inconsistencies.append(
                        "fpsCoveragePct=%s producerCounts=%.1f"
                        % (_trim_number(reported_fps_coverage), producer_coverage)
                    )
            if reported_fps_coverage is not None and calculated_coverage is not None and abs(reported_fps_coverage - calculated_coverage) > 0.2:
                sample_inconsistencies.append(
                    "fpsCoveragePct=%s observed=%.1f"
                    % (_trim_number(reported_fps_coverage), calculated_coverage)
                )
            if sample_inconsistencies:
                alerts.append(
                    {
                        "code": "RESULT_SAMPLE_INCONSISTENT",
                        "message": "; ".join(sample_inconsistencies),
                    }
                )

            if result_status in ("PASS", "OK"):
                gate_contradictions = []
                if reported_fps_samples is not None and reported_fps_samples < 1:
                    gate_contradictions.append("no post-warmup FPS samples")
                if reported_fps_coverage is not None and reported_fps_coverage < 80:
                    gate_contradictions.append("FPS sample coverage below 80%")
                expected_hcs = _number(self.start, "expectedHcs") or 0
                bus_rate = _number(self.start, "busRate") or 0
                min_hc_fps = _number(self.start, "minHcFps")
                ai_peak_for_gate = max(ai_peak_values) if ai_peak_values else None
                if expected_hcs > 0 and ai_peak_for_gate is not None and ai_peak_for_gate >= 40:
                    if hcs_min is None or hcs_min < expected_hcs:
                        gate_contradictions.append("transient HC count below expectedHcs")
                if bus_rate > 0 and expected_hcs > 0:
                    hc_fps_samples = _number(result_fields, "hcFpsSamples")
                    if hc_fps_samples is None or hc_fps_samples < 1:
                        gate_contradictions.append("no fresh per-HC FPS samples")
                    if min_hc_fps is not None and (hc_fps_min is None or hc_fps_min < min_hc_fps):
                        gate_contradictions.append("HC FPS below minHcFps")
                if gate_contradictions:
                    alerts.append(
                        {
                            "code": "RESULT_GATE_CONTRADICTION",
                            "message": "PASS contradicts result evidence: " + "; ".join(gate_contradictions),
                        }
                    )

        for item in self.protocol_alerts:
            kind = item["kind"]
            fields = item["fields"]
            if kind == "ALERT":
                state = str(_field(fields, "state") or "UNKNOWN").upper()
                if state == "OK":
                    continue
                code = "LAB_%s" % state
                message = "lab ownership state changed to %s" % state
            elif kind == "EVENT_RUN_MISMATCH":
                code = kind
                message = "event %s run %s does not match START run %s" % (
                    _field(fields, "eventKind") or "UNKNOWN",
                    _field(fields, "eventRun") or "missing",
                    _field(fields, "startRun") or "missing",
                )
            elif kind in (
                "DUPLICATE_FIELD",
                "INVALID_NUMERIC_FIELD",
                "START_RUN_ALIAS_CONFLICT",
                "EVENT_RUN_ALIAS_CONFLICT",
                "EVENT_RUN_MISSING",
            ):
                code = kind
                message = "protocol %s in %s" % (
                    kind.lower(),
                    _field(fields, "eventKind") or "UNKNOWN",
                )
                field = _field(fields, "field")
                if field is not None:
                    message += " field %s" % field
            else:
                code = "LAB_%s" % kind
                message = "lab emitted %s" % kind
            reason = _field(fields, "reason")
            if reason is not None:
                message += ": %s" % reason
            alerts.append({"code": code, "message": message})

        batch_totals = []
        batch_deltas = []
        for batch in self.batches:
            total = _number(batch["fields"], "spawnedTotal", "spawned")
            delta = _number(batch["fields"], "spawnedDelta")
            if total is not None:
                batch_totals.append(total)
            if delta is not None:
                batch_deltas.append(delta)
        cleanup_summary = dict(self.cleanup) if self.cleanup is not None else {}
        cleanup_summary.update(
            {
                "objects_remaining": _trim_number(cleanup_objects),
                "groups_remaining": _trim_number(cleanup_groups),
            }
        )

        phase_summary = self._phase_summary()
        composition_summary = self._composition_summary()
        work_summary = self._work_summary(phase_summary)
        path_summary = self._path_summary()

        summary = {
            "protocol": "WASPLAB|v1",
            "found": True,
            "run": _run_identity(self.start),
            "start": dict(self.start),
            "start_line": self.start_line,
            "sample_count": len(self.samples),
            "benchmark_sample_count": observed["benchmark_sample_count"],
            "measurement_sample_count": observed["measurement_sample_count"],
            "expected_sample_count": expected_samples,
            "sample_coverage_pct": (
                _trim_number(reported_fps_coverage)
                if reported_fps_coverage is not None
                else _trim_number(calculated_coverage)
            ),
            "sample_coverage": {
                "observed_samples": len(fps_values),
                "expected_samples": expected_samples,
                "calculated_pct": _trim_number(calculated_coverage),
                "reported_samples": _trim_number(reported_fps_samples),
                "reported_expected": _trim_number(reported_fps_expected),
                "reported_pct": _trim_number(reported_fps_coverage),
            },
            "fps": {
                "median": _trim_number(fps_median),
                "avg": _trim_number(fps_avg),
                "min": _trim_number(fps_min),
                "p5": _trim_number(fps_p5),
            },
            "warmup": {
                "seconds": _trim_number(observed["warmup_sec"]),
                "boot_sample_count": len(observed["boot_fps"]),
                "boot_fps_min": (
                    _trim_number(min(observed["boot_fps"]))
                    if observed["boot_fps"] else None
                ),
            },
            "phase": phase_summary,
            "composition": composition_summary,
            "work": work_summary,
            "ai_peak": _trim_number(max(ai_peak_values)) if ai_peak_values else None,
            "groups_peak": (
                _trim_number(max(group_peak_values)) if group_peak_values else None
            ),
            "hc_pct": {
                "median": _trim_number(hc_median),
                "min": _trim_number(hc_min),
                "basis": observed["hc_bases"],
            },
            "hc_fps": {
                "median": (
                    _trim_number(statistics.median(observed["hc_fps"]))
                    if observed["hc_fps"] else None
                ),
                "min": _trim_number(hc_fps_min),
                "fresh_endpoints_min": (
                    _trim_number(min(observed["hc_fresh"]))
                    if observed["hc_fresh"] else None
                ),
                "samples": _trim_number(_number(result_fields, "hcFpsSamples")),
            },
            "hc_balance": {
                "hcs_min": _trim_number(hcs_min),
                "imbalance_median": (
                    _trim_number(statistics.median(observed["hc_imbalance"]))
                    if observed["hc_imbalance"] else None
                ),
                "imbalance_last": _trim_number(
                    _number(result_fields, "hcImbalanceLast")
                    if _number(result_fields, "hcImbalanceLast") is not None
                    else observed["hc_imbalance"][-1] if observed["hc_imbalance"] else None
                ),
                "imbalance_max": _trim_number(hc_imbalance_max),
                "imbalanced_pct": _trim_number(hc_imbalanced_pct),
                "group_imbalance_median": (
                    _trim_number(statistics.median(observed["hc_group_imbalance"]))
                    if observed["hc_group_imbalance"] else None
                ),
                "group_imbalance_last": _trim_number(
                    _number(result_fields, "hcGroupImbalanceLast")
                    if _number(result_fields, "hcGroupImbalanceLast") is not None
                    else observed["hc_group_imbalance"][-1] if observed["hc_group_imbalance"] else None
                ),
            },
            "remote_pct": {
                "median": (
                    _trim_number(statistics.median(observed["remote_pct"]))
                    if observed["remote_pct"]
                    else None
                ),
                "min": (
                    _trim_number(min(observed["remote_pct"]))
                    if observed["remote_pct"]
                    else None
                ),
            },
            "max_stuck": _trim_number(max(stuck_values)) if stuck_values else None,
            "stuck": {
                "max_count": _trim_number(max(stuck_values)) if stuck_values else None,
                "max_pct": _trim_number(stuck_pct_max),
            },
            "combat": {
                "initial": _trim_number(combat_initial),
                "casualties": _trim_number(combat_casualties),
                "moved_groups": _trim_number(combat_moved_groups),
                "moved_pct": _trim_number(combat_moved_pct),
            },
            "batches": {
                "count": len(self.batches),
                "spawned": (
                    _trim_number(max(batch_totals)) if batch_totals
                    else _trim_number(sum(batch_deltas)) if batch_deltas else None
                ),
            },
            "pathlegs": path_summary,
            "scheduler": self._scheduler_summary(),
            "cleanup": cleanup_summary,
            "protocol_alerts": list(self.protocol_alerts),
            "bus": self._bus_summary(),
            "result": result,
            "fatal_signatures": fatal_summary,
            "alerts": alerts,
            "ok": not alerts,
        }
        return summary


def parse_last_run(lines):
    """Parse an iterable and return the state belonging to its last START."""
    state = None
    pending_boot = []
    after_result = False
    for line_number, line in enumerate(lines, 1):
        event = parse_marker(line)
        if event is not None and event["kind"] == "BOOT":
            provisional = {"kind": "START", "fields": dict(event["fields"])}
            provisional["fields"]["phase"] = "BOOT"
            state = RunState(provisional, start_line=line_number)
            for pending_line, pending_number in pending_boot:
                state.ingest(pending_line, line_number=pending_number)
            pending_boot = []
            after_result = False
        elif event is not None and event["kind"] == "START":
            boot_fatals = state.fatals if state is not None and state.start.get("phase") == "BOOT" else {}
            state = RunState(event, start_line=line_number)
            state.fatals = boot_fatals
            for pending_line, pending_number in pending_boot:
                state.ingest(pending_line, line_number=pending_number)
            pending_boot = []
            after_result = False
        elif state is not None:
            if after_result:
                if event is None and fatal_matches(line):
                    pending_boot.append((line, line_number))
            else:
                state.ingest(line, event=event, line_number=line_number)
                if event is not None and event["kind"] == "RESULT":
                    after_result = True
        elif event is None and fatal_matches(line):
            pending_boot.append((line, line_number))
    if state is not None and pending_boot:
        for pending_line, pending_number in pending_boot:
            state.ingest(pending_line, line_number=pending_number)
        state.post_result_fatal = True
    return state


def parse_file(path):
    with open(path, "r", encoding="utf-8", errors="replace") as handle:
        return parse_last_run(handle)


def empty_summary(path):
    fatals = {}
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            for line in handle:
                for code in fatal_matches(line):
                    entry = fatals.setdefault(code, {"count": 0, "examples": []})
                    entry["count"] += 1
                    if len(entry["examples"]) < 3:
                        entry["examples"].append(line.strip()[:300])
    except OSError:
        pass
    fatal_summary = [
        {"code": code, "count": fatals[code]["count"], "examples": fatals[code]["examples"]}
        for code in sorted(fatals)
    ]
    alerts = [
        {
            "code": "NO_START",
            "message": "no WASPLAB|v1|START marker found",
        }
    ]
    for fatal in fatal_summary:
        alerts.append(
            {
                "code": fatal["code"],
                "message": "%s matching RPT line(s) before START" % fatal["count"],
            }
        )
    return {
        "protocol": "WASPLAB|v1",
        "found": False,
        "path": os.path.abspath(path),
        "fatal_signatures": fatal_summary,
        "alerts": alerts,
        "ok": False,
    }


def _human(summary):
    if not summary.get("found"):
        return "WASPLAB: no START marker found"
    fps = summary["fps"]
    hc_pct = summary["hc_pct"]
    bus = summary.get("bus")
    lines = [
        "WASPLAB run=%s scenario=%s map=%s samples=%s"
        % (
            summary.get("run") or "?",
            _field(summary["start"], "scenario") or "?",
            _field(summary["start"], "map") or "?",
            summary["sample_count"],
        ),
        "  FPS median=%s min=%s p5=%s | AI peak=%s groups peak=%s"
        % (
            fps["median"],
            fps["min"],
            fps["p5"],
            summary["ai_peak"],
            summary["groups_peak"],
        ),
        "  HC%% median=%s min=%s basis=%s | max stuck=%s"
        % (
            hc_pct["median"],
            hc_pct["min"],
            ",".join(hc_pct["basis"]) or "?",
            summary["max_stuck"],
        ),
    ]
    if bus is not None:
        lines.append(
            "  BUS sent=%s ack=%s loss=%s latency=%sms records=%s"
            % (
                bus["sent"],
                bus["ack"],
                bus["loss"],
                bus["latency_ms"],
                bus["records"],
            )
        )
    if summary.get("result") is not None:
        lines.append(
            "  RESULT status=%s reason=%s"
            % (
                _field(summary["result"], "status") or "?",
                _field(summary["result"], "reason") or "-",
            )
        )
    if summary["fatal_signatures"]:
        lines.append(
            "  Fatal signatures: %s"
            % ", ".join(
                "%s=%s" % (item["code"], item["count"])
                for item in summary["fatal_signatures"]
            )
        )
    for alert in summary["alerts"]:
        lines.append("  ALERT %s: %s" % (alert["code"], alert["message"]))
    if not summary["alerts"]:
        lines.append("  No monitor alerts")
    return "\n".join(lines)


def emit_summary(summary, mode):
    if mode == "json":
        print(json.dumps(summary, indent=2, sort_keys=True))
    elif mode == "json-lines":
        payload = dict(summary)
        payload["type"] = "summary"
        print(json.dumps(payload, sort_keys=True), flush=True)
    else:
        print(_human(summary), flush=True)


def emit_follow_event(event, mode):
    if mode == "json-lines":
        print(
            json.dumps(
                {"type": "event", "kind": event["kind"], "fields": event["fields"]},
                sort_keys=True,
            ),
            flush=True,
        )
    elif mode == "json":
        # A JSON array cannot be streamed indefinitely.  JSON objects per line
        # are therefore used for live updates even if --json was selected.
        print(
            json.dumps(
                {"type": "event", "kind": event["kind"], "fields": event["fields"]},
                sort_keys=True,
            ),
            flush=True,
        )
    else:
        print("WASPLAB %-7s %s" % (event["kind"], event["fields"]), flush=True)


def emit_live_alert(code, message, mode):
    if mode in ("json", "json-lines"):
        print(
            json.dumps(
                {"type": "alert", "code": code, "message": message},
                sort_keys=True,
            ),
            flush=True,
        )
    else:
        print("ALERT %s: %s" % (code, message), flush=True)


def follow(path, state, min_fps, mode, poll_seconds):
    """Tail only newly appended bytes, resetting safely if the RPT truncates."""
    handle = open(path, "r", encoding="utf-8", errors="replace")
    try:
        handle.seek(0, os.SEEK_END)
        while True:
            line = handle.readline()
            if not line:
                try:
                    size = os.path.getsize(path)
                except OSError:
                    size = handle.tell()
                if size < handle.tell():
                    handle.close()
                    handle = open(path, "r", encoding="utf-8", errors="replace")
                    state = None
                    emit_live_alert("RPT_TRUNCATED", "RPT was truncated; waiting for a new START", mode)
                else:
                    time.sleep(poll_seconds)
                continue

            event = parse_marker(line)
            if event is not None and event["kind"] == "BOOT":
                provisional = {"kind": "START", "fields": dict(event["fields"])}
                provisional["fields"]["phase"] = "BOOT"
                state = RunState(provisional)
                emit_follow_event(event, mode)
                continue
            if event is not None and event["kind"] == "START":
                boot_fatals = state.fatals if state is not None and state.start.get("phase") == "BOOT" else {}
                boot_alerts = state.protocol_alerts if state is not None and state.start.get("phase") == "BOOT" else []
                state = RunState(event)
                state.fatals = boot_fatals
                state.protocol_alerts = boot_alerts
                emit_follow_event(event, mode)
                continue
            if state is None:
                continue

            fatal_codes = state.ingest(line, event=event)
            if event is not None:
                emit_follow_event(event, mode)
                if event["kind"] == "SAMPLE" and min_fps is not None:
                    fps = _number(event["fields"], "fps", "serverFps", "srvFps")
                    if fps is not None and fps <= min_fps and _sample_is_benchmark(
                        event["fields"], state.start
                    ):
                        emit_live_alert(
                            "FPS_BELOW_MIN",
                            "sample FPS %s is at or below threshold %s"
                            % (_trim_number(fps), _trim_number(min_fps)),
                            mode,
                        )
                if event["kind"] == "RESULT":
                    emit_summary(state.summary(min_fps=min_fps), mode)
            for code in fatal_codes:
                emit_live_alert(code, line.strip()[:300], mode)
    finally:
        handle.close()


def build_parser():
    parser = argparse.ArgumentParser(
        description="Summarize or follow WASPLAB v1 telemetry in an Arma RPT."
    )
    parser.add_argument("rpt", help="path to arma2oaserver.RPT")
    output = parser.add_mutually_exclusive_group()
    output.add_argument("--json", action="store_true", help="emit one JSON summary")
    output.add_argument(
        "--json-lines",
        action="store_true",
        help="emit newline-delimited JSON (recommended with --follow)",
    )
    parser.add_argument("--follow", action="store_true", help="tail newly appended RPT lines")
    parser.add_argument(
        "--min-fps",
        type=float,
        default=None,
        metavar="FPS",
        help="alert when server FPS is at or below this floor",
    )
    parser.add_argument(
        "--poll",
        type=float,
        default=0.5,
        metavar="SECONDS",
        help=argparse.SUPPRESS,
    )
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    if not math.isfinite(args.poll) or args.poll <= 0:
        raise SystemExit("--poll must be finite and greater than zero")
    if args.min_fps is not None and (
        not math.isfinite(args.min_fps) or args.min_fps <= 0
    ):
        raise SystemExit("--min-fps must be finite and greater than zero")
    if not os.path.isfile(args.rpt):
        raise SystemExit("RPT not found: %s" % args.rpt)

    state = parse_file(args.rpt)
    summary = state.summary(min_fps=args.min_fps, active=args.follow) if state else empty_summary(args.rpt)
    mode = "json" if args.json else "json-lines" if args.json_lines else "human"
    emit_summary(summary, mode)
    if args.follow:
        try:
            follow(args.rpt, state, args.min_fps, mode, args.poll)
        except KeyboardInterrupt:
            return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
