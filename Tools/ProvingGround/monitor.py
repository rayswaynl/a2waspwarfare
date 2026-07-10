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
MAX_EXPECTED_SAMPLES = 1000000
MAX_REASONABLE_FPS = 1000.0
MAX_PARTITION_DRAIN_SEC = 32.0
PARTITION_GROUP_IDS = tuple(range(1, 121))
UTES_PARTITION_ROUTES = (
    "Strelka>Airfield",
    "Airfield>Kamenyy",
    "Kamenyy>Strelka",
)
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
            is_run_identity = folded_key in ("run", "runid") or (
                folded_key == "id" and kind in ("START", "RESULT")
            )
            is_start_provenance = kind == "START" and folded_key in (
                "build",
                "git",
                "source",
                "lab",
                "config",
                "workload",
                "partition",
                "partitionid",
            )
            is_opaque = is_run_identity or is_start_provenance
            parsed_value = value.strip() if is_opaque else _parse_value(value)
            if (
                not is_opaque
                and (
                _INT_RE.match(value.strip())
                or _FLOAT_RE.match(value.strip())
                or _NONFINITE_RE.match(value.strip())
                )
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


def _partition_alias_conflict(fields):
    values = [
        value
        for key, value in fields.items()
        if str(key).lower() in ("partition", "partitionid") and value is not None
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


def _cadence_limit(sample_sec):
    """Allow rounding/scheduler jitter without allowing missing measurement windows."""
    if sample_sec is None or sample_sec <= 0:
        return None
    return sample_sec + max(1.0, sample_sec * 0.25)


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


def _strict_integer_map(value):
    """Parse a non-empty integer map without accepting junk or duplicate keys."""
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
            parts = [part.strip() for part in re.split(r"[,;]", text)]
            if not parts or any(not part for part in parts):
                return None
            parsed = []
            pattern = re.compile(r"^([+-]?\d+)\s*(?::|=|x)\s*([+-]?\d+)$", re.IGNORECASE)
            for part in parts:
                match = pattern.match(part)
                if match is None:
                    return None
                parsed.append((match.group(1), match.group(2)))

    if isinstance(parsed, dict):
        items = list(parsed.items())
    elif isinstance(parsed, (list, tuple)):
        items = list(parsed)
    else:
        return None
    if not items:
        return None

    normalized = {}
    for item in items:
        if not isinstance(item, (list, tuple)) or len(item) != 2:
            return None
        key_number = _number({"value": item[0]}, "value")
        value_number = _number({"value": item[1]}, "value")
        if (
            key_number is None
            or value_number is None
            or not key_number.is_integer()
            or not value_number.is_integer()
            or key_number < 0
            or value_number < 0
        ):
            return None
        key = int(key_number)
        if key in normalized:
            return None
        normalized[key] = int(value_number)
    return normalized


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


def _safe_mean(values):
    """Average finite values without overflowing their intermediate sum."""
    if not values:
        return None
    scale = max(abs(value) for value in values)
    if scale == 0:
        return 0.0
    mean = scale * (sum(value / scale for value in values) / len(values))
    return mean if math.isfinite(mean) else None


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
        if _partition_alias_conflict(self.start):
            conflict = {
                "kind": "START_PARTITION_ALIAS_CONFLICT",
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
                "event_index": len(self.events) + 1,
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
        probe_ms_values = []
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
            probe_ms = _number(fields, "probeMs")
            if probe_ms is not None and probe_ms >= 0:
                probe_ms_values.append(probe_ms)

        # A legacy BATCH can be the exact crest between periodic SAMPLE ticks.
        # Partition BATCH markers are SPAWN-only and must not shape MEASURE peaks.
        for batch in [] if _is_partition_start(self.start) else self.batches:
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
            "probe_ms": probe_ms_values,
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
            if "event_index" in record:
                stored["event_index"] = record["event_index"]
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
        event_indices = []
        histogram = {}
        anchor_requested = {}
        anchor_members = {}
        valid_count = 0
        arm = _number(self.start, "unitsPerGroup")
        arm_valid = arm is not None and arm >= 1 and arm.is_integer()

        for record in self.realized_records:
            fields = record["fields"]
            if "event_index" in record:
                event_indices.append(record["event_index"])
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
            "event_indices": event_indices,
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
        fps_values = []
        ai_values = []
        group_count_values = []
        probe_ms_values = []
        measure_t_values = []
        sample_t_values = []
        event_indices = []
        for record in records:
            if "event_index" in record:
                event_indices.append(record["event_index"])
            member_seconds = _number(
                record["fields"], "memberSeconds", "membersSeconds"
            )
            group_seconds = _number(
                record["fields"], "groupSeconds", "groupsSeconds"
            )
            measure_t = _number(
                record["fields"], "measureT", "measurementElapsed", "measureElapsed"
            )
            sample_t = _number(record["fields"], "t", "elapsed")
            fps = _number(record["fields"], "fps", "serverFps", "srvFps")
            ai = _sample_ai(record["fields"])
            groups = _number(record["fields"], "groups", "groupCount")
            probe_ms = _number(record["fields"], "probeMs")
            if member_seconds is not None:
                member_values.append(member_seconds)
            if group_seconds is not None:
                group_values.append(group_seconds)
            if measure_t is not None:
                measure_t_values.append(measure_t)
            if sample_t is not None:
                sample_t_values.append(sample_t)
            if fps is not None:
                fps_values.append(fps)
            if ai is not None and ai >= 0 and ai.is_integer():
                ai_values.append(ai)
            if groups is not None and groups >= 0 and groups.is_integer():
                group_count_values.append(groups)
            if probe_ms is not None and probe_ms >= 0:
                probe_ms_values.append(probe_ms)

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
        cadence_limit = _cadence_limit(sample_sec)
        first_measure_t_ok = None
        measure_t_gap_ok = None
        sample_t_monotonic = strictly_increasing(sample_t_values)
        sample_t_gap_ok = None
        sample_measure_alignment_ok = None
        go_t = None
        for phase_record in self.phase_records:
            if str(_field(phase_record["fields"], "phase") or "").upper() == "GO":
                go_t = _number(phase_record["fields"], "t", "elapsed")
                break
        if duration is not None and sample_sec is not None and sample_sec > 0:
            measure_t_in_bounds = (
                len(measure_t_values) == len(records)
                and all(
                    0 <= value <= duration
                    for value in measure_t_values
                )
            )
            terminal_progress_ok = (
                bool(measure_t_values)
                and measure_t_values[-1] >= max(0.0, duration - sample_sec)
            )
            first_measure_t_ok = (
                bool(measure_t_values)
                and cadence_limit is not None
                and measure_t_values[0] <= cadence_limit
            )
            measure_t_gap_ok = (
                len(measure_t_values) == len(records)
                and cadence_limit is not None
                and all(
                    current - previous <= cadence_limit
                    for previous, current in zip(
                        measure_t_values, measure_t_values[1:]
                    )
                )
            )
            sample_t_gap_ok = (
                len(sample_t_values) == len(records)
                and cadence_limit is not None
                and sample_t_monotonic
                and all(
                    current - previous <= cadence_limit
                    for previous, current in zip(
                        sample_t_values, sample_t_values[1:]
                    )
                )
            )
            sample_measure_alignment_ok = (
                len(sample_t_values) == len(records)
                and len(measure_t_values) == len(records)
                and go_t is not None
                and all(
                    go_t <= sample_t <= go_t + duration
                    and abs((sample_t - go_t) - measure_t) <= 1.0
                    for sample_t, measure_t in zip(
                        sample_t_values, measure_t_values
                    )
                )
            )

        return {
            "record_count": len(records),
            "event_indices": event_indices,
            "fps_count": len(fps_values),
            "fps_values": [_trim_number(value) for value in fps_values],
            "ai_count": len(ai_values),
            "ai_values": [_trim_number(value) for value in ai_values],
            "groups_count": len(group_count_values),
            "groups_values": [_trim_number(value) for value in group_count_values],
            "probe_ms_count": len(probe_ms_values),
            "probe_ms_values": [_trim_number(value) for value in probe_ms_values],
            "member_seconds_count": len(member_values),
            "group_seconds_count": len(group_values),
            "member_seconds_values": [
                _trim_number(value) for value in member_values
            ],
            "group_seconds_values": [
                _trim_number(value) for value in group_values
            ],
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
            "sample_t_count": len(sample_t_values),
            "sample_t_values": [_trim_number(value) for value in sample_t_values],
            "sample_t_monotonic": sample_t_monotonic,
            "sample_t_gap_ok": sample_t_gap_ok,
            "sample_measure_alignment_ok": sample_measure_alignment_ok,
            "latest_measure_t": (
                _trim_number(measure_t_values[-1]) if measure_t_values else None
            ),
            "measure_t_monotonic": strictly_increasing(measure_t_values),
            "measure_t_unique_count": len(set(measure_t_values)),
            "measure_t_in_bounds": measure_t_in_bounds,
            "terminal_progress_ok": terminal_progress_ok,
            "cadence_limit": _trim_number(cadence_limit),
            "first_measure_t_ok": first_measure_t_ok,
            "measure_t_gap_ok": measure_t_gap_ok,
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

    def _composition_evidence_problems(self, composition):
        """Reconcile cumulative composition with independently aggregated REALIZED rows."""
        if not self.realized_records:
            return (
                ["partition has no REALIZED per-group evidence"]
                if _is_partition_start(self.start)
                else []
            )
        evidence = composition["realized_evidence"]
        problems = []
        target_groups = _number(self.start, "targetGroups")
        if target_groups is not None:
            target_is_integer = target_groups >= 0 and target_groups.is_integer()
            if not target_is_integer or evidence["record_count"] != target_groups:
                problems.append("REALIZED record count differs from targetGroups")
            if not target_is_integer or evidence["valid_count"] != target_groups:
                problems.append("REALIZED valid count differs from targetGroups")
            if (
                not target_is_integer
                or len(evidence["group_ids"]) != target_groups
                or any(
                    group_id != index
                    for index, group_id in enumerate(evidence["group_ids"], 1)
                )
            ):
                problems.append("REALIZED group IDs contain gaps or duplicates")

        for field in (
            "requested_infantry",
            "created_infantry",
            "crew",
            "vehicles",
            "final_members",
            "underfill_groups",
            "oversize_groups",
            "create_failures",
            "create_failure_groups",
        ):
            evidence_value = _number(evidence, field)
            cumulative_value = _number(composition, field)
            if (
                evidence_value is None
                or cumulative_value is None
                or abs(evidence_value - cumulative_value) > 1e-9
            ):
                problems.append("REALIZED %s differs from cumulative composition" % field)

        for field in ("histogram", "anchor_requested", "anchor_members"):
            evidence_map = _histogram(evidence.get(field))
            cumulative_map = _histogram(composition.get(field))
            if evidence_map is None or evidence_map != cumulative_map:
                problems.append("REALIZED %s differs from cumulative composition" % field)
        return problems

    def _work_evidence_problems(self, work):
        """Bound final work totals by the last independently observed MEASURE sample."""
        if self.result is None:
            return []
        evidence = work["sample_evidence"]
        if evidence["record_count"] < 1:
            return (
                ["partition has no MEASURE work-counter evidence"]
                if _is_partition_start(self.start)
                else []
            )
        if (
            not _is_partition_start(self.start)
            and evidence["member_seconds_count"] == 0
            and evidence["group_seconds_count"] == 0
            and _number(work, "member_seconds") is None
            and _number(work, "group_seconds") is None
        ):
            return []
        problems = []
        if (
            evidence["member_seconds_count"] != evidence["record_count"]
            or not evidence["member_seconds_monotonic"]
        ):
            problems.append("memberSeconds samples are incomplete or non-monotonic")
        if (
            evidence["group_seconds_count"] != evidence["record_count"]
            or not evidence["group_seconds_monotonic"]
        ):
            problems.append("groupSeconds samples are incomplete or non-monotonic")

        sample_sec = _number(self.start, "sampleSec")
        measure_values = evidence.get("measure_t_values")
        measure_values = (
            [_number({"value": value}, "value") for value in measure_values]
            if isinstance(measure_values, list)
            else None
        )
        for label, total_field, latest_field, target_field in (
            ("memberSeconds", "member_seconds", "latest_member_seconds", "targetSyntheticUnits"),
            ("groupSeconds", "group_seconds", "latest_group_seconds", "targetGroups"),
        ):
            total = _number(work, total_field)
            latest = _number(evidence, latest_field)
            target = _number(self.start, target_field)
            if total is None or latest is None:
                problems.append("%s final/sample evidence is missing" % label)
                continue
            if total + 1e-9 < latest:
                problems.append("%s final total is below the last sample" % label)
            elif (
                target is not None
                and sample_sec is not None
                and total - latest > target * sample_sec + 1e-9
            ):
                problems.append("%s advances by more than one sample interval" % label)

        for label, values_field, latest_field, target_field in (
            (
                "memberSeconds",
                "member_seconds_values",
                "latest_member_seconds",
                "targetSyntheticUnits",
            ),
            (
                "groupSeconds",
                "group_seconds_values",
                "latest_group_seconds",
                "targetGroups",
            ),
        ):
            raw_values = evidence.get(values_field)
            values = (
                [_number({"value": value}, "value") for value in raw_values]
                if isinstance(raw_values, list)
                else None
            )
            target = _number(self.start, target_field)
            latest = _number(evidence, latest_field)
            if (
                values is None
                or measure_values is None
                or target is None
                or len(values) != len(measure_values)
                or any(value is None or value < 0 for value in values)
                or any(value is None for value in measure_values)
                or latest is None
                or not values
                or abs(values[-1] - latest) > 1e-9
            ):
                problems.append("%s sample series is incomplete" % label)
                continue
            previous_value = 0.0
            previous_t = 0.0
            for value, measure_t in zip(values, measure_values):
                elapsed = measure_t - previous_t
                if (
                    value > target * (measure_t + 1.0) + 1e-9
                    or value - previous_value
                    > target * (elapsed + 1.0) + 1e-9
                ):
                    problems.append("%s exceeds the physical target*time envelope" % label)
                    break
                previous_value = value
                previous_t = measure_t
        return problems

    def _partition_result_problems(
        self, phase, composition, work, path, observed, expected_samples,
        calculated_coverage,
    ):
        if not _is_partition_start(self.start) or self.result is None:
            return [], []
        required = (
            "measureDuration",
            "measureT",
            "fpsMin",
            "fpsAvg",
            "fpsSamples",
            "fpsExpected",
            "fpsCoveragePct",
            "aiPeak",
            "groupsPeak",
            "targetSyntheticUnits",
            "targetGroups",
            "spawnAnchors",
            "realizedGroups",
            "requestedInfantry",
            "createdInfantry",
            "crew",
            "createdVehicles",
            "finalMembers",
            "histogram",
            "underfillGroups",
            "oversizeGroups",
            "createFailures",
            "createFailureGroups",
            "anchorRequested",
            "anchorMembers",
            "memberSeconds",
            "groupSeconds",
            "pathLegsStarted",
        )
        missing = [field for field in required if _field(self.result, field) is None]
        invalid = []
        numeric_specs = {
            "measureDuration": (False, 0, 14400),
            "measureT": (False, 0, 14700),
            "fpsMin": (False, 0, MAX_REASONABLE_FPS),
            "fpsAvg": (False, 0, MAX_REASONABLE_FPS),
            "fpsSamples": (True, 1, MAX_EXPECTED_SAMPLES),
            "fpsExpected": (True, 1, MAX_EXPECTED_SAMPLES),
            "fpsCoveragePct": (False, 0, 200),
            "aiPeak": (True, 0, 10000000),
            "groupsPeak": (True, 0, 1000000),
            "targetSyntheticUnits": (True, 1, 1440),
            "targetGroups": (True, 1, 120),
            "spawnAnchors": (True, 1, 3),
            "realizedGroups": (True, 1, 120),
            "requestedInfantry": (True, 0, 1440),
            "createdInfantry": (True, 0, 1440),
            "crew": (True, 0, 1440),
            "createdVehicles": (True, 0, 1440),
            "finalMembers": (True, 0, 1440),
            "underfillGroups": (True, 0, 120),
            "oversizeGroups": (True, 0, 120),
            "createFailures": (True, 0, 1000000),
            "createFailureGroups": (True, 0, 120),
            "memberSeconds": (False, 0, 1000000000),
            "groupSeconds": (False, 0, 1000000000),
            "pathLegsStarted": (True, 1, 1000000),
        }
        direct_numbers = {}
        for field, (integer, minimum, maximum) in numeric_specs.items():
            if field in missing:
                continue
            number = _number(self.result, field)
            if (
                number is None
                or (integer and not number.is_integer())
                or number < minimum
                or number > maximum
            ):
                invalid.append("RESULT %s is outside its typed range" % field)
            else:
                direct_numbers[field] = number

        direct_maps = {}
        for field in ("histogram", "anchorRequested", "anchorMembers"):
            if field in missing:
                continue
            value = _strict_integer_map(_field(self.result, field))
            if value is None:
                invalid.append("RESULT %s is not a non-empty integer map" % field)
            else:
                direct_maps[field] = value

        sample_evidence = work.get("sample_evidence") or {}
        realized_evidence = composition.get("realized_evidence") or {}
        transition_evidence = path.get("transition_evidence") or []
        cleanup_measure_t = None
        cleanup_wall_t = None
        go_wall_t = None
        for phase_record in phase.get("records") or []:
            fields = phase_record.get("fields") if isinstance(phase_record, dict) else None
            fields = fields if isinstance(fields, dict) else {}
            phase_name = str(_field(fields, "phase") or "").upper()
            if phase_name == "GO":
                go_wall_t = _number(fields, "t", "elapsed")
            elif phase_name == "CLEANUP":
                cleanup_measure_t = _number(fields, "measureT")
                cleanup_wall_t = _number(fields, "t", "elapsed")
        if cleanup_measure_t is None and cleanup_wall_t is not None and go_wall_t is not None:
            cleanup_measure_t = cleanup_wall_t - go_wall_t
        path_starts = sum(
            1
            for record in transition_evidence
            if isinstance(record, dict)
            and str(_field(record, "status") or "").upper() == "STARTED"
        )
        independent = {
            "measureDuration": cleanup_measure_t,
            "measureT": cleanup_measure_t,
            "fpsMin": min(observed["fps"]) if observed["fps"] else None,
            "fpsAvg": _safe_mean(observed["fps"]) if observed["fps"] else None,
            "fpsSamples": len(observed["fps"]),
            "fpsExpected": expected_samples,
            "fpsCoveragePct": calculated_coverage,
            "aiPeak": max(observed["ai"]) if observed["ai"] else None,
            "groupsPeak": max(observed["groups"]) if observed["groups"] else None,
            "targetSyntheticUnits": _number(self.start, "targetSyntheticUnits"),
            "targetGroups": _number(self.start, "targetGroups"),
            "spawnAnchors": _number(self.start, "spawnAnchors"),
            "realizedGroups": _number(realized_evidence, "record_count"),
            "requestedInfantry": _number(realized_evidence, "requested_infantry"),
            "createdInfantry": _number(realized_evidence, "created_infantry"),
            "crew": _number(realized_evidence, "crew"),
            "createdVehicles": _number(realized_evidence, "vehicles"),
            "finalMembers": _number(realized_evidence, "final_members"),
            "underfillGroups": _number(realized_evidence, "underfill_groups"),
            "oversizeGroups": _number(realized_evidence, "oversize_groups"),
            "createFailures": _number(realized_evidence, "create_failures"),
            "createFailureGroups": _number(realized_evidence, "create_failure_groups"),
            "pathLegsStarted": float(path_starts),
        }
        for field, expected in independent.items():
            direct = direct_numbers.get(field)
            if direct is None or expected is None:
                continue
            tolerance = (
                0.11
                if field in ("fpsAvg", "fpsCoveragePct")
                else 1e-9
            )
            if abs(direct - expected) > tolerance:
                invalid.append("RESULT %s differs from independent evidence" % field)

        for field, evidence_field in (
            ("histogram", "histogram"),
            ("anchorRequested", "anchor_requested"),
            ("anchorMembers", "anchor_members"),
        ):
            direct = direct_maps.get(field)
            expected = _strict_integer_map(realized_evidence.get(evidence_field))
            if direct is not None and (expected is None or direct != expected):
                invalid.append("RESULT %s differs from REALIZED evidence" % field)

        missing_problems = (
            ["RESULT is missing partition fields: %s" % ",".join(missing)]
            if missing else []
        )
        return missing_problems, invalid

    def _partition_path_problems(self, phase, path):
        if not _is_partition_start(self.start):
            return []
        target_groups = _number(self.start, "targetGroups")
        arm = _number(self.start, "unitsPerGroup")
        duration = _number(self.start, "duration")
        if (
            target_groups is None
            or not target_groups.is_integer()
            or not 1 <= target_groups <= 120
            or arm is None
            or not arm.is_integer()
            or int(arm) not in (4, 6, 8, 10, 12)
            or duration is None
            or not 0 < duration <= 14400
        ):
            return ["START lacks bounded integer targetGroups/unitsPerGroup"]
        target_groups = int(target_groups)
        arm = int(arm)

        phase_indices = {}
        phase_times = {}
        for record in phase.get("records") or []:
            fields = record.get("fields") if isinstance(record, dict) else None
            fields = fields if isinstance(fields, dict) else {}
            name = str(_field(fields, "phase") or "").upper()
            index = _number(record, "event_index") if isinstance(record, dict) else None
            if index is not None and index.is_integer():
                phase_indices[name] = int(index)
            at = _number(fields, "t", "elapsed")
            if at is not None:
                phase_times[name] = at
        if any(name not in phase_indices for name in ("GO", "MEASURE", "CLEANUP")):
            return ["phase event indices are missing for path validation"]
        if any(name not in phase_times for name in ("GO", "MEASURE", "CLEANUP")):
            return ["phase elapsed times are missing for path validation"]

        raw_records = path.get("transition_evidence")
        if not isinstance(raw_records, list) or not raw_records:
            return ["PATHLEG transition evidence is missing"]
        if len(raw_records) > 1000000:
            return ["PATHLEG transition evidence exceeds its bounded record limit"]
        records = []
        for raw in raw_records:
            if not isinstance(raw, dict):
                return ["PATHLEG transition evidence contains a non-record"]
            group_id = _number(raw, "group")
            transition = _number(raw, "transition")
            event_index = _number(raw, "event_index")
            units = _number(raw, "units")
            wall_t = _number(raw, "t")
            measure_t = _number(raw, "measure_t", "measureT")
            elapsed = _number(raw, "elapsed")
            status = str(_field(raw, "status") or "").upper()
            route_id = str(_field(raw, "route_id", "routeId") or "").strip()
            if any(
                value is None or not value.is_integer()
                for value in (group_id, transition, event_index, units)
            ):
                return ["PATHLEG transition fields must be finite integers"]
            if wall_t is None or measure_t is None or elapsed is None or not route_id:
                return ["PATHLEG transition lacks clocks or route identity"]
            records.append(
                {
                    "group": int(group_id),
                    "transition": int(transition),
                    "event_index": int(event_index),
                    "units": int(units),
                    "status": status,
                    "route_id": route_id,
                    "t": wall_t,
                    "measure_t": measure_t,
                    "elapsed": elapsed,
                }
            )
        indices = [record["event_index"] for record in records]
        if (
            len(indices) != len(set(indices))
            or any(index <= 0 for index in indices)
            or any(current <= previous for previous, current in zip(indices, indices[1:]))
        ):
            return ["PATHLEG event indices must be positive and strictly increasing"]
        if any(
            current["t"] < previous["t"]
            or current["measure_t"] < previous["measure_t"]
            for previous, current in zip(records, records[1:])
        ):
            return ["PATHLEG clocks move backwards in event order"]

        by_group = dict((group_id, []) for group_id in PARTITION_GROUP_IDS[:target_groups])
        for record in records:
            if record["group"] not in by_group:
                return ["PATHLEG group ID is outside 1..targetGroups"]
            if record["transition"] < 1 or not 1 <= record["units"] <= arm:
                return ["PATHLEG transition or unit count is outside its contract"]
            if record["route_id"] not in UTES_PARTITION_ROUTES:
                return ["PATHLEG route is outside the fixed Utes directed cycle"]
            if not phase_indices["GO"] < record["event_index"] < phase_indices["CLEANUP"]:
                return ["PATHLEG record is outside GO..CLEANUP"]
            if not phase_times["GO"] <= record["t"] <= phase_times["CLEANUP"]:
                return ["PATHLEG wall clock is outside GO..CLEANUP"]
            if record["measure_t"] < 0 or record["measure_t"] > duration:
                return ["PATHLEG record is outside the configured measurement window"]
            if abs(
                (record["t"] - phase_times["GO"]) - record["measure_t"]
            ) > 1.0:
                return ["PATHLEG measureT does not reconcile with GO plus wall time"]
            by_group[record["group"]].append(record)

        for group_id, group_records in by_group.items():
            if not group_records or len(group_records) % 2 != 1:
                return ["group %s lacks exactly one active transition frontier" % group_id]
            for position, record in enumerate(group_records):
                expected_status = "STARTED" if position % 2 == 0 else "ARRIVED"
                expected_transition = (position // 2) + 1
                if (
                    record["status"] != expected_status
                    or record["transition"] != expected_transition
                ):
                    return ["group %s PATHLEG transitions are not ordered" % group_id]
                if expected_status == "ARRIVED" and (
                    record["route_id"] != group_records[position - 1]["route_id"]
                ):
                    return ["group %s ARRIVED route differs from its STARTED leg" % group_id]
                if expected_status == "STARTED" and position > 0:
                    previous_destination = group_records[position - 1]["route_id"].split(">", 1)[1]
                    current_origin = record["route_id"].split(">", 1)[0]
                    if previous_destination != current_origin:
                        return ["group %s PATHLEG route continuity is broken" % group_id]
                if not record["elapsed"].is_integer() or not 0 <= record["elapsed"] <= duration:
                    return ["group %s PATHLEG elapsed is outside its contract" % group_id]
                if expected_status == "STARTED" and record["elapsed"] != 0:
                    return ["group %s STARTED elapsed must be zero" % group_id]
                if expected_status == "ARRIVED" and abs(
                    record["elapsed"] - (
                        record["measure_t"] - group_records[position - 1]["measure_t"]
                    )
                ) > 1.0:
                    return ["group %s ARRIVED elapsed does not match transition clocks" % group_id]
                if position == 0:
                    if not (
                        phase_indices["GO"]
                        < record["event_index"]
                        < phase_indices["MEASURE"]
                    ):
                        return ["group %s initial STARTED is not at GO" % group_id]
                    if record["units"] != arm:
                        return ["group %s initial STARTED does not contain the full arm" % group_id]
                elif record["event_index"] <= phase_indices["MEASURE"]:
                    return ["group %s continuation precedes MEASURE" % group_id]

        problems = []
        started_records = [record for record in records if record["status"] == "STARTED"]
        arrived_records = [record for record in records if record["status"] == "ARRIVED"]
        expected_started_indices = [record["event_index"] for record in started_records]

        def path_integer(field):
            value = _number(path, field)
            return int(value) if value is not None and value.is_integer() else None

        expected_scalars = {
            "count": len(records),
            "started": len(started_records),
            "completed": len(arrived_records),
            "arrivals": len(arrived_records),
            "arrival_units": sum(record["units"] for record in arrived_records),
        }
        for field, expected in expected_scalars.items():
            if path_integer(field) != expected:
                problems.append("pathlegs.%s differs from transition evidence" % field)
        if expected_scalars["arrival_units"] < expected_scalars["completed"]:
            problems.append("pathlegs.arrival_units are below one live unit per arrival")
        if path.get("started_event_indices") != expected_started_indices:
            problems.append("started_event_indices differ from STARTED transitions")

        status = path.get("status")
        if not isinstance(status, dict):
            problems.append("pathlegs.status is missing")
        else:
            for name, expected in (
                ("STARTED", len(started_records)),
                ("ARRIVED", len(arrived_records)),
            ):
                value = _number(status, name)
                if value is None or not value.is_integer() or int(value) != expected:
                    problems.append("pathlegs.status %s differs from transition evidence" % name)

        expected_routes = {}
        for record in records:
            route = expected_routes.setdefault(
                record["route_id"],
                {"records": 0, "started": 0, "completed": 0, "units": 0, "elapsed": []},
            )
            route["records"] += 1
            if record["status"] == "STARTED":
                route["started"] += 1
            else:
                route["completed"] += 1
                route["units"] += record["units"]
                route["elapsed"].append(record["elapsed"])
        route_count = path_integer("route_count")
        if route_count != len(expected_routes):
            problems.append("pathlegs.route_count differs from transition routes")
        route_ids = path.get("route_ids")
        if not isinstance(route_ids, list) or set(str(value) for value in route_ids) != set(expected_routes):
            problems.append("pathlegs.route_ids differ from transition routes")
        routes = path.get("routes")
        if not isinstance(routes, dict) or set(str(key) for key in routes) != set(expected_routes):
            problems.append("pathlegs.routes differ from transition routes")
        else:
            for route_id, expected in expected_routes.items():
                route = routes.get(route_id)
                if not isinstance(route, dict):
                    problems.append("route %s summary is missing" % route_id)
                    continue
                for field in ("records", "started", "completed", "units"):
                    expected_value = expected[field]
                    actual = _number(route, field)
                    if actual is None or not actual.is_integer() or int(actual) != expected_value:
                        problems.append("route %s %s differs from transition evidence" % (route_id, field))
                arrived = _number(route, "arrived")
                if arrived is None or not arrived.is_integer() or int(arrived) != expected["completed"]:
                    problems.append("route %s arrived differs from transition evidence" % route_id)
                route_status = route.get("status")
                if not isinstance(route_status, dict):
                    problems.append("route %s status is missing" % route_id)
                else:
                    for name, expected_value in (
                        ("STARTED", expected["started"]),
                        ("ARRIVED", expected["completed"]),
                    ):
                        value = _number(route_status, name)
                        if value is None or not value.is_integer() or int(value) != expected_value:
                            problems.append("route %s status %s differs from transition evidence" % (route_id, name))
                if expected["units"] < expected["completed"]:
                    problems.append("route %s arrival units are below live arrivals" % route_id)
                expected_elapsed = (
                    statistics.median(expected["elapsed"]) if expected["elapsed"] else None
                )
                actual_elapsed = _number(route, "elapsed_median")
                if (
                    (expected_elapsed is None and actual_elapsed is not None)
                    or (expected_elapsed is not None and actual_elapsed is None)
                    or (
                        expected_elapsed is not None
                        and actual_elapsed is not None
                        and abs(actual_elapsed - expected_elapsed) > 1e-9
                    )
                ):
                    problems.append(
                        "route %s elapsed_median differs from transition evidence" % route_id
                    )
        return problems

    def _partition_barrier_problems(self, phase, composition, work, path):
        """Prove event order and elapsed-time barriers for registered partitions."""
        if not _is_partition_start(self.start):
            return []
        problems = []
        expected = ("SPAWN", "SETTLE", "GO", "MEASURE", "CLEANUP")
        records = phase.get("records")
        records = records if isinstance(records, list) else []
        parsed = []
        for record in records:
            fields = record.get("fields") if isinstance(record, dict) else None
            fields = fields if isinstance(fields, dict) else {}
            name = str(_field(fields, "phase") or "").upper()
            event_index = _number(record, "event_index") if isinstance(record, dict) else None
            at = _number(fields, "t", "elapsed", "at")
            measure_at = _number(fields, "measureT")
            parsed.append((name, event_index, at, measure_at))
        if tuple(item[0] for item in parsed) != expected:
            problems.append("phase records are not the exact barrier sequence")
            return problems
        if any(item[1] is None or not item[1].is_integer() for item in parsed):
            problems.append("phase records lack integer event indices")
            return problems
        indices = [int(item[1]) for item in parsed]
        if any(value <= 0 for value in indices) or any(
            current <= previous for previous, current in zip(indices, indices[1:])
        ):
            problems.append("phase event indices are not strictly increasing")
        if any(item[2] is None for item in parsed):
            problems.append("phase records lack finite elapsed times")
            return problems

        times = dict((item[0], item[2]) for item in parsed)
        measure_times = dict((item[0], item[3]) for item in parsed)
        ordered_times = [item[2] for item in parsed]
        if any(
            current < previous
            for previous, current in zip(ordered_times, ordered_times[1:])
        ):
            problems.append("phase elapsed times are not monotonic")
        settle_sec = _number(self.start, "settleSec") or 0.0
        duration = _number(self.start, "duration")
        settle_elapsed = times["GO"] - times["SETTLE"]
        if (
            settle_elapsed < max(0.0, settle_sec - 1.0)
            or settle_elapsed > settle_sec + 2.0
        ):
            problems.append("SETTLE elapsed time differs from settleSec")
        measure_elapsed = times["CLEANUP"] - times["GO"]
        if duration is not None and (
            measure_elapsed < duration - 1.0
            or measure_elapsed > duration + MAX_PARTITION_DRAIN_SEC
        ):
            problems.append("CLEANUP wall clock is outside duration plus bounded drain")
        if measure_times["GO"] is None or abs(measure_times["GO"]) > 1.0:
            problems.append("GO phase measureT must be zero")
        measure_phase_elapsed = times["MEASURE"] - times["GO"]
        measure_phase_limit = _cadence_limit(_number(self.start, "sampleSec"))
        if (
            measure_times["MEASURE"] is None
            or measure_phase_elapsed < 0
            or abs(measure_times["MEASURE"] - measure_phase_elapsed) > 1.0
            or measure_phase_limit is None
            or measure_phase_elapsed > measure_phase_limit
        ):
            problems.append("MEASURE phase clock is not a bounded continuation of GO")
        cleanup_measure_t = measure_times["CLEANUP"]
        if (
            cleanup_measure_t is None
            or (duration is not None and abs(cleanup_measure_t - duration) > 2.0)
        ):
            problems.append("CLEANUP measureT differs from configured duration")

        realized_indices = composition["realized_evidence"].get("event_indices")
        target_groups = _number(self.start, "targetGroups")
        target_group_count = (
            int(target_groups)
            if target_groups is not None
            and 1 <= target_groups <= 120
            and target_groups.is_integer()
            else None
        )
        realized_ordered = (
            isinstance(realized_indices, list)
            and all(isinstance(value, int) for value in realized_indices)
            and all(
                current > previous
                for previous, current in zip(realized_indices, realized_indices[1:])
            )
        )
        if (
            not isinstance(realized_indices, list)
            or target_group_count is None
            or len(realized_indices) != target_group_count
            or not realized_ordered
            or any(
                not isinstance(value, int)
                or value <= indices[0]
                or value >= indices[1]
                for value in realized_indices
            )
        ):
            problems.append("REALIZED records are not strictly between SPAWN and SETTLE")

        sample_indices = work["sample_evidence"].get("event_indices")
        samples_ordered = (
            isinstance(sample_indices, list)
            and all(isinstance(value, int) for value in sample_indices)
            and all(
                current > previous
                for previous, current in zip(sample_indices, sample_indices[1:])
            )
        )
        if (
            not isinstance(sample_indices, list)
            or len(sample_indices) != work["sample_evidence"]["record_count"]
            or not samples_ordered
            or any(
                not isinstance(value, int)
                or value <= indices[3]
                or value >= indices[4]
                for value in sample_indices
            )
        ):
            problems.append("MEASURE samples are not bounded by MEASURE and CLEANUP")
        sample_times = work["sample_evidence"].get("sample_t_values")
        normalized_sample_times = (
            [_number({"value": value}, "value") for value in sample_times]
            if isinstance(sample_times, list)
            else None
        )
        if (
            normalized_sample_times is None
            or len(normalized_sample_times) != work["sample_evidence"]["record_count"]
            or any(value is None for value in normalized_sample_times)
            or any(
                value < times["GO"] or value > times["CLEANUP"]
                for value in normalized_sample_times
            )
        ):
            problems.append("MEASURE sample clocks are outside GO..CLEANUP")

        started_indices = path.get("started_event_indices")
        starts_ordered = (
            isinstance(started_indices, list)
            and all(isinstance(value, int) for value in started_indices)
            and all(
                current > previous
                for previous, current in zip(started_indices, started_indices[1:])
            )
        )
        if (
            not isinstance(started_indices, list)
            or not starts_ordered
            or any(
                not isinstance(value, int)
                or value <= indices[2]
                or value >= indices[4]
                for value in started_indices
            )
        ):
            problems.append("PATHLEG starts are not bounded by GO and CLEANUP")

        transition_indices = []
        raw_transitions = path.get("transition_evidence")
        if isinstance(raw_transitions, list):
            for record in raw_transitions:
                value = _field(record, "event_index") if isinstance(record, dict) else None
                if not isinstance(value, int):
                    transition_indices = []
                    break
                transition_indices.append(value)
        all_event_indices = []
        event_lists_valid = all(
            isinstance(values, list)
            for values in (indices, realized_indices, sample_indices, transition_indices)
        )
        if event_lists_valid:
            for values in (indices, realized_indices, sample_indices, transition_indices):
                all_event_indices.extend(values)
        if (
            not event_lists_valid
            or not all_event_indices
            or any(value <= 0 for value in all_event_indices)
            or len(all_event_indices) != len(set(all_event_indices))
        ):
            problems.append("phase, REALIZED, PATHLEG, and SAMPLE event indices are not globally unique")
        return problems

    def _path_summary(self):
        result = self.result or {}
        status_totals = {}
        routes = {}
        completed_from_records = 0
        arrival_units_from_records = 0.0
        arrival_units_seen = False
        started_event_indices = []
        transition_evidence = []

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
            transition_evidence.append(
                {
                    "group": _trim_number(_number(fields, "group", "groupId")),
                    "transition": _trim_number(
                        _number(fields, "transition", "transitionId")
                    ),
                    "status": status,
                    "event_index": leg.get("event_index"),
                    "measure_t": _trim_number(_number(fields, "measureT")),
                    "t": _trim_number(_number(fields, "t", "elapsed")),
                    "elapsed": _trim_number(_number(fields, "elapsed")),
                    "units": _trim_number(_number(fields, "units")),
                    "route_id": _field(fields, "routeId", "routeIdentity", "route"),
                }
            )

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
                if "event_index" in leg:
                    started_event_indices.append(leg["event_index"])
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
            normalized_status = dict(route["status"])
            normalized_status.setdefault("STARTED", 0)
            normalized_status.setdefault("ARRIVED", 0)
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
                "status": normalized_status,
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
            "started_event_indices": started_event_indices,
            "transition_evidence": transition_evidence,
        }

    def summary(self, min_fps=None, active=False):
        observed = self._observations()
        result = dict(self.result) if self.result is not None else None
        result_fields = result or {}
        phase_summary = self._phase_summary()
        composition_summary = self._composition_summary()
        work_summary = self._work_summary(phase_summary)
        path_summary = self._path_summary()

        fps_values = observed["fps"]
        fps_min = min(fps_values) if fps_values else _number(result_fields, "fpsMin")
        fps_median = statistics.median(fps_values) if fps_values else None
        fps_avg = (
            _safe_mean(fps_values)
            if fps_values
            else _number(result_fields, "fpsAvg")
        )
        fps_p5 = percentile(fps_values, 5) if fps_values else fps_min

        ai_peak_values = list(observed["ai"])
        reported_ai_peak = _number(result_fields, "aiPeak")
        if reported_ai_peak is not None and not _is_partition_start(self.start):
            ai_peak_values.append(reported_ai_peak)
        group_peak_values = list(observed["groups"])
        reported_groups_peak = _number(result_fields, "groupsPeak")
        if reported_groups_peak is not None and not _is_partition_start(self.start):
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
        reported_fps_values = [
            _number(result_fields, name)
            for name in ("fpsMin", "fpsAvg", "fpsP5")
        ]
        if any(
            value < 0 or value > MAX_REASONABLE_FPS
            for value in fps_values + [
                value for value in reported_fps_values if value is not None
            ]
        ):
            alerts.append(
                {
                    "code": "FPS_OUT_OF_RANGE",
                    "message": "FPS evidence is outside the bounded 0..%s range"
                    % _trim_number(MAX_REASONABLE_FPS),
                }
            )
        if _is_partition_start(self.start):
            peak_problems = []
            if (
                reported_ai_peak is not None
                and observed["ai"]
                and abs(reported_ai_peak - max(observed["ai"])) > 1e-9
            ):
                peak_problems.append("aiPeak differs from MEASURE SAMPLE maximum")
            if (
                reported_groups_peak is not None
                and observed["groups"]
                and abs(reported_groups_peak - max(observed["groups"])) > 1e-9
            ):
                peak_problems.append("groupsPeak differs from MEASURE SAMPLE maximum")
            if peak_problems:
                alerts.append(
                    {
                        "code": "RESULT_PEAK_INCONSISTENT",
                        "message": "; ".join(peak_problems),
                    }
                )
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
        phase_scoped_measure = _is_partition_start(self.start) or observed["measurement_sample_count"] > 0 or any(
            _is_measurement_phase(_field(record["fields"], "phase", "state", "name"))
            for record in self.phase_records
        )
        if start_duration is not None and start_sample_sec is not None and start_sample_sec > 0:
            measured_duration = (
                start_duration if phase_scoped_measure
                else max(0.0, start_duration - warmup_sec)
            )
            sample_ratio = measured_duration / start_sample_sec
            if (
                not math.isfinite(sample_ratio)
                or sample_ratio < 0
                or sample_ratio > MAX_EXPECTED_SAMPLES
            ):
                alerts.append(
                    {
                        "code": "INVALID_SAMPLE_WINDOW",
                        "message": "duration/sampleSec does not define a bounded finite sample window",
                    }
                )
            else:
                expected_samples = max(1, int(sample_ratio))
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
            if time_evidence["first_measure_t_ok"] is not True:
                time_problems.append("first measureT exceeds the cadence plus jitter limit")
            if time_evidence["measure_t_gap_ok"] is not True:
                time_problems.append("measureT contains a gap above the cadence plus jitter limit")
            if _is_partition_start(self.start):
                if time_evidence["sample_t_count"] != time_evidence["record_count"]:
                    time_problems.append("not every MEASURE sample has finite wall-clock t")
                if time_evidence["sample_t_monotonic"] is not True:
                    time_problems.append("SAMPLE wall-clock t is not strictly increasing")
                if time_evidence["sample_t_gap_ok"] is not True:
                    time_problems.append("SAMPLE wall-clock t exceeds the cadence plus jitter limit")
                if time_evidence["sample_measure_alignment_ok"] is not True:
                    time_problems.append("SAMPLE wall-clock t does not reconcile with GO plus measureT")
            if time_problems:
                alerts.append(
                    {
                        "code": "MEASURE_TIME_INVALID",
                        "message": "; ".join(time_problems),
                    }
                )
            if (
                _is_partition_start(self.start)
                and time_evidence["fps_count"] != time_evidence["record_count"]
            ):
                alerts.append(
                    {
                        "code": "MEASURE_FPS_INCOMPLETE",
                        "message": "every partition MEASURE sample must carry finite FPS",
                    }
                )
            if _is_partition_start(self.start) and (
                time_evidence["ai_count"] != time_evidence["record_count"]
                or time_evidence["groups_count"] != time_evidence["record_count"]
            ):
                alerts.append(
                    {
                        "code": "MEASURE_LOAD_INCOMPLETE",
                        "message": "every partition MEASURE sample must carry integer AI and group counts",
                    }
                )
            if (
                _is_partition_start(self.start)
                and time_evidence["probe_ms_count"] != time_evidence["record_count"]
            ):
                alerts.append(
                    {
                        "code": "MEASURE_PROBE_INCOMPLETE",
                        "message": "every partition MEASURE sample must carry finite non-negative probeMs",
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

        composition_problems = self._composition_evidence_problems(
            composition_summary
        )
        if composition_problems:
            alerts.append(
                {
                    "code": "REALIZED_EVIDENCE_INCONSISTENT",
                    "message": "; ".join(composition_problems),
                }
            )
        work_problems = self._work_evidence_problems(work_summary)
        if work_problems:
            alerts.append(
                {
                    "code": "RESULT_WORK_INCONSISTENT",
                    "message": "; ".join(work_problems),
                }
            )
        barrier_problems = self._partition_barrier_problems(
            phase_summary, composition_summary, work_summary, path_summary
        )
        if barrier_problems:
            alerts.append(
                {
                    "code": "PARTITION_BARRIER_INVALID",
                    "message": "; ".join(barrier_problems),
                }
            )
        result_missing, result_invalid = self._partition_result_problems(
            phase_summary,
            composition_summary,
            work_summary,
            path_summary,
            observed,
            expected_samples,
            calculated_coverage,
        )
        if result_missing:
            alerts.append(
                {
                    "code": "RESULT_PARTITION_FIELDS_MISSING",
                    "message": "; ".join(result_missing),
                }
            )
        if result_invalid:
            alerts.append(
                {
                    "code": "RESULT_PARTITION_INVALID",
                    "message": "; ".join(result_invalid),
                }
            )
        path_problems = self._partition_path_problems(phase_summary, path_summary)
        if path_problems:
            alerts.append(
                {
                    "code": "PATH_TRANSITION_INVALID",
                    "message": "; ".join(path_problems),
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
                "START_PARTITION_ALIAS_CONFLICT",
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
            "probe_ms": {
                "count": len(observed["probe_ms"]),
                "median": (
                    _trim_number(statistics.median(observed["probe_ms"]))
                    if observed["probe_ms"] else None
                ),
                "p95": (
                    _trim_number(percentile(observed["probe_ms"], 95))
                    if observed["probe_ms"] else None
                ),
                "max": (
                    _trim_number(max(observed["probe_ms"]))
                    if observed["probe_ms"] else None
                ),
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
