#!/usr/bin/env python3
"""Compare the newest WASPLAB run in a control and candidate RPT.

The comparison is deliberately dependency-free and imports the sibling
``monitor.py`` by absolute file path.  It can therefore be run from any
working directory without accidentally importing an unrelated module named
``monitor``.

Examples::

    python compare.py control.rpt candidate.rpt
    python compare.py control.rpt candidate.rpt --json
"""

from __future__ import print_function

import argparse
import importlib.util
import json
import os
import sys


def _load_monitor():
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "monitor.py")
    spec = importlib.util.spec_from_file_location("wasplab_proving_ground_monitor", path)
    if spec is None or spec.loader is None:
        raise ImportError("cannot load WASPLAB monitor: %s" % path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


monitor = _load_monitor()


METRICS = (
    ("fps_median", "FPS median", ("fps", "median")),
    ("fps_min", "FPS min", ("fps", "min")),
    ("fps_p5", "FPS p5", ("fps", "p5")),
    ("sample_coverage_pct", "Sample coverage %", ("sample_coverage_pct",)),
    ("ai_peak", "AI peak", ("ai_peak",)),
    ("groups_peak", "Groups peak", ("groups_peak",)),
    ("hc_pct_median", "HC% median", ("hc_pct", "median")),
    ("hc_pct_min", "HC% min", ("hc_pct", "min")),
    ("hc_fps_min", "HC FPS min", ("hc_fps", "min")),
    ("hcs_min", "HC count min", ("hc_balance", "hcs_min")),
    ("hc_imbalance", "HC imbalance %", ("hc_balance", "imbalance_median")),
    ("hc_imbalance_max", "HC imbalance max %", ("hc_balance", "imbalance_max")),
    ("hc_imbalanced_pct", "HC imbalance breach %", ("hc_balance", "imbalanced_pct")),
    ("hc_group_imbalance", "HC group imbalance %", ("hc_balance", "group_imbalance_median")),
    ("max_stuck", "Max stuck", ("max_stuck",)),
    ("max_stuck_pct", "Max stuck %", ("stuck", "max_pct")),
    ("combat_casualties", "Combat casualties", ("combat", "casualties")),
    ("combat_moved_pct", "Combat moved %", ("combat", "moved_pct")),
    ("cleanup_objects", "Cleanup objects", ("cleanup", "objects_remaining")),
    ("cleanup_groups", "Cleanup groups", ("cleanup", "groups_remaining")),
    ("bus_loss", "Bus loss", ("bus", "loss")),
    ("bus_latency_ms", "Bus latency ms", ("bus", "latency_ms")),
    ("bus_attainment_pct", "Bus attainment %", ("bus", "attainment_pct")),
    ("sched_deferred", "Sched deferred", ("scheduler", "deferred_total")),
    ("sched_overruns", "Sched overruns", ("scheduler", "overruns_total")),
    ("sched_elapsed_ms", "Sched max elapsed ms", ("scheduler", "max_elapsed_ms")),
)

MATCH_FIELDS = (
    "scenario", "map", "git", "source", "lab", "workload", "mode", "targetGroups",
    "unitsPerGroup", "busRate", "expectedHcs", "duration", "sampleSec",
    "warmupSec", "minHcFps", "paramSig", "baselineAi", "baselineGroups", "baselineVehicles",
    "performanceAudit",
)
REQUIRED_MATCH_FIELDS = frozenset(MATCH_FIELDS)


def _trim_number(value):
    if value is None:
        return None
    rounded = round(float(value), 3)
    if rounded.is_integer():
        return int(rounded)
    return rounded


def _number(value):
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _nested(mapping, path):
    current = mapping
    for key in path:
        if not isinstance(current, dict):
            return None
        current = current.get(key)
    return current


def _start_value(summary, name):
    start = summary.get("start") or {}
    if name in start:
        return start[name]
    folded = dict((str(key).lower(), value) for key, value in start.items())
    return folded.get(name.lower())


def load_summary(path):
    """Return the monitor summary for the last run, including empty RPTs."""
    state = monitor.parse_file(path)
    return state.summary() if state is not None else monitor.empty_summary(path)


def _warning(code, message):
    return {"code": code, "message": message}


def _side_warnings(side, summary):
    label = side.capitalize()
    warnings = []
    if not summary.get("found"):
        warnings.append(
            _warning(
                "%s_NO_START" % side.upper(),
                "%s RPT has no WASPLAB START marker" % label,
            )
        )
        return warnings

    fatals = summary.get("fatal_signatures") or []
    if fatals:
        details = ", ".join(
            "%s=%s" % (entry.get("code", "UNKNOWN"), entry.get("count", "?"))
            for entry in fatals
        )
        warnings.append(
            _warning(
                "%s_FATAL" % side.upper(),
                "%s run contains fatal RPT signature(s): %s" % (label, details),
            )
        )

    result = summary.get("result")
    if result is not None:
        status = str(result.get("status") or "").upper()
        if status and status not in ("PASS", "OK"):
            warnings.append(
                _warning(
                    "%s_RESULT_%s" % (side.upper(), status),
                    "%s result status is %s" % (label, status),
                )
            )
    else:
        warnings.append(
            _warning(
                "%s_RUN_INCOMPLETE" % side.upper(),
                "%s run has no RESULT marker" % label,
            )
        )
    for alert in summary.get("alerts") or []:
        code = str(alert.get("code") or "")
        if code:
            warnings.append(
                _warning(
                    "%s_%s" % (side.upper(), code),
                    "%s: %s" % (label, alert.get("message") or code),
                )
            )
    return warnings


def compare_summaries(control, candidate):
    """Build a stable, JSON-ready A/B comparison from two monitor summaries."""
    metrics = {}
    for key, label, path in METRICS:
        control_value = _number(_nested(control, path))
        candidate_value = _number(_nested(candidate, path))
        if control_value is None or candidate_value is None:
            delta = None
            percent = None
        else:
            delta = candidate_value - control_value
            percent = None if control_value == 0 else (100.0 * delta / control_value)
        metrics[key] = {
            "label": label,
            "control": _trim_number(control_value),
            "candidate": _trim_number(candidate_value),
            "delta": _trim_number(delta),
            "percent": _trim_number(percent),
        }

    warnings = []
    warnings.extend(_side_warnings("control", control))
    warnings.extend(_side_warnings("candidate", candidate))

    control_scenario = _start_value(control, "scenario")
    candidate_scenario = _start_value(candidate, "scenario")
    control_map = _start_value(control, "map")
    candidate_map = _start_value(candidate, "map")
    for field in MATCH_FIELDS:
        control_value = _start_value(control, field)
        candidate_value = _start_value(candidate, field)
        if control_value is None or candidate_value is None:
            if field in REQUIRED_MATCH_FIELDS:
                warnings.append(
                    _warning(
                        "%s_MISSING" % field.upper(),
                        "%s missing: control=%s candidate=%s"
                        % (field, control_value, candidate_value),
                    )
                )
            continue
        if str(control_value).lower() != str(candidate_value).lower():
            warnings.append(
                _warning(
                    "%s_MISMATCH" % field.upper(),
                    "%s differs: control=%s candidate=%s"
                    % (field, control_value, candidate_value),
                )
            )

    control_samples = _number(control.get("benchmark_sample_count"))
    candidate_samples = _number(candidate.get("benchmark_sample_count"))
    if control_samples is not None and candidate_samples is not None and abs(control_samples - candidate_samples) > 1:
        warnings.append(
            _warning(
                "SAMPLE_COUNT_MISMATCH",
                "post-warmup sample count differs: control=%s candidate=%s"
                % (_trim_number(control_samples), _trim_number(candidate_samples)),
            )
        )

    control_duration = _number((control.get("result") or {}).get("duration"))
    candidate_duration = _number((candidate.get("result") or {}).get("duration"))
    tolerance = max(
        2.0,
        _number(_start_value(control, "sampleSec")) or 0.0,
        _number(_start_value(candidate, "sampleSec")) or 0.0,
    )
    if control_duration is not None and candidate_duration is not None and abs(control_duration - candidate_duration) > tolerance:
        warnings.append(
            _warning(
                "RESULT_DURATION_MISMATCH",
                "result duration differs: control=%s candidate=%s"
                % (_trim_number(control_duration), _trim_number(candidate_duration)),
            )
        )

    unique_warnings = []
    seen_codes = set()
    for warning in warnings:
        code = warning.get("code")
        if code in seen_codes:
            continue
        seen_codes.add(code)
        unique_warnings.append(warning)
    warnings = unique_warnings

    return {
        "protocol": "WASPLAB-COMPARE|v1",
        "control": {
            "run": control.get("run"),
            "scenario": control_scenario,
            "map": control_map,
            "found": bool(control.get("found")),
        },
        "candidate": {
            "run": candidate.get("run"),
            "scenario": candidate_scenario,
            "map": candidate_map,
            "found": bool(candidate.get("found")),
        },
        "metrics": metrics,
        "warnings": warnings,
        "ok": not warnings,
    }


def compare_files(control_path, candidate_path):
    return compare_summaries(
        load_summary(control_path),
        load_summary(candidate_path),
    )


def _display(value, suffix=""):
    return "-" if value is None else "%s%s" % (value, suffix)


def format_human(comparison):
    control = comparison["control"]
    candidate = comparison["candidate"]
    lines = [
        "WASPLAB control=%s candidate=%s"
        % (control.get("run") or "?", candidate.get("run") or "?"),
        "  scenario %s -> %s | map %s -> %s"
        % (
            control.get("scenario") or "?",
            candidate.get("scenario") or "?",
            control.get("map") or "?",
            candidate.get("map") or "?",
        ),
        "  %-16s %12s %12s %12s %10s"
        % ("Metric", "Control", "Candidate", "Delta", "Delta %"),
    ]
    for key, label, _path in METRICS:
        metric = comparison["metrics"][key]
        lines.append(
            "  %-16s %12s %12s %12s %10s"
            % (
                label,
                _display(metric["control"]),
                _display(metric["candidate"]),
                _display(metric["delta"]),
                _display(metric["percent"], "%"),
            )
        )
    if comparison["warnings"]:
        for warning in comparison["warnings"]:
            lines.append("  WARN %s: %s" % (warning["code"], warning["message"]))
    else:
        lines.append("  Comparable runs; no warnings")
    return "\n".join(lines)


def build_parser():
    parser = argparse.ArgumentParser(
        description="Compare the newest WASPLAB run in control and candidate RPTs."
    )
    parser.add_argument("control", help="control arma2oaserver.RPT")
    parser.add_argument("candidate", help="candidate arma2oaserver.RPT")
    parser.add_argument("--json", action="store_true", help="emit JSON")
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    for path in (args.control, args.candidate):
        if not os.path.isfile(path):
            raise SystemExit("RPT not found: %s" % path)
    comparison = compare_files(args.control, args.candidate)
    if args.json:
        print(json.dumps(comparison, indent=2, sort_keys=True))
    else:
        print(format_human(comparison))
    return 0


if __name__ == "__main__":
    sys.exit(main())
