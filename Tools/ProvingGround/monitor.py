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
import os
import re
import statistics
import sys
import time


MARKER = "WASPLAB|v1|"
KINDS = (
    "BOOT", "START", "SAMPLE", "BATCH", "BUS", "PATHLEG", "SCHED", "ALERT", "RESULT",
    "ABORT", "SPAWN_FAIL", "BUS_REJECT", "CLEANUP",
)

_MARKER_LINE_RE = re.compile(
    r'^\s*(?:\d{1,3}:\d{2}:\d{2}(?:\.\d+)?\s+)?'
    r'(?:(?:"(WASPLAB\|v1\|[^"\r\n]*)";?)|((?:WASPLAB\|v1\|)[^"\r\n]*);?)\s*$'
)

_INT_RE = re.compile(r"^[+-]?\d+$")
_FLOAT_RE = re.compile(
    r"^[+-]?(?:\d+\.\d*|\.\d+|\d+)(?:[eE][+-]?\d+)?$"
)

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
    rounded = round(float(value), 3)
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
            return float(value)
        except ValueError:
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
    for part in parts[3:]:
        if "=" not in part:
            if part:
                positional.append(_parse_value(part))
            continue
        key, value = part.split("=", 1)
        key = key.strip()
        if key:
            fields[key] = _parse_value(value)
    if positional:
        fields["_positional"] = positional
    return {"kind": kind, "fields": fields, "marker": marker}


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
    if isinstance(value, (int, float)):
        return float(value)
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


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
        self.samples = []
        self.batches = []
        self.bus_records = []
        self.pathlegs = []
        self.scheduler_records = []
        self.protocol_alerts = []
        self.cleanup = None
        self.result = None
        self.fatals = {}
        self.post_result_fatal = False

    def ingest(self, line, event=None, line_number=None):
        """Ingest one post-START RPT line and return new fatal signature codes."""
        new_fatals = []
        if event is None:
            event = parse_marker(line)
        if event is not None and event["kind"] != "START":
            stored = {
                "kind": event["kind"],
                "fields": dict(event["fields"]),
            }
            if line_number is not None:
                stored["line"] = line_number
            self.events.append(stored)
            if event["kind"] == "SAMPLE":
                self.samples.append(stored)
            elif event["kind"] == "BATCH":
                self.batches.append(stored)
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
        warmup = _number(self.start, "warmupSec", "warmup") or 0.0

        for sample in self.samples:
            fields = sample["fields"]
            sample_time = _number(fields, "t", "elapsed")
            post_warmup = sample_time is None or sample_time >= warmup
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
            start_run = _field(self.start, "run", "id")
            result_run = _field(result_fields, "run", "id")
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
        if start_duration is not None and start_sample_sec is not None and start_sample_sec > 0:
            expected_samples = max(1, int(max(0.0, start_duration - warmup_sec) // start_sample_sec))
            calculated_coverage = 100.0 * len(fps_values) / expected_samples
            if self.result is not None and calculated_coverage < 80:
                alerts.append(
                    {
                        "code": "SAMPLE_COVERAGE_LOW",
                        "message": "post-warmup FPS sample coverage %.1f%% (%s/%s)" % (calculated_coverage, len(fps_values), expected_samples),
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
        path_status = {}
        for leg in self.pathlegs:
            status = str(_field(leg["fields"], "status") or "UNKNOWN").upper()
            path_status[status] = path_status.get(status, 0) + 1

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
            "run": _field(self.start, "run", "id"),
            "start": dict(self.start),
            "start_line": self.start_line,
            "sample_count": len(self.samples),
            "benchmark_sample_count": observed["benchmark_sample_count"],
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
            "pathlegs": {"count": len(self.pathlegs), "status": path_status},
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
                    sample_time = _number(event["fields"], "t", "elapsed")
                    warmup = _number(state.start, "warmupSec", "warmup") or 0
                    if fps is not None and fps <= min_fps and (sample_time is None or sample_time >= warmup):
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
    if args.poll <= 0:
        raise SystemExit("--poll must be greater than zero")
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
