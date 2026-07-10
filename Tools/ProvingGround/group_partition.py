#!/usr/bin/env python3
"""Aggregate strict, equal-work WASPLAB group-partition repetitions.

This tool is intentionally separate from ``compare.py``. Density arms change
scenario, group count, units/group and batch size by design, while every other
identity and configuration field must remain equal. Inputs may be server RPTs
or JSON summaries previously emitted by ``monitor.py --json``.
"""

from __future__ import print_function

import argparse
import glob
import importlib.util
import json
import math
import os
import re
import statistics
import sys


def _load_monitor():
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "monitor.py")
    spec = importlib.util.spec_from_file_location("wasplab_group_partition_monitor", path)
    if spec is None or spec.loader is None:
        raise ImportError("cannot load WASPLAB monitor: %s" % path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


monitor = _load_monitor()


PROTOCOL = "WASPLAB-GROUP-PARTITION|v1"
ARMS = (4, 6, 8, 10, 12)
BATCH_GROUPS_BY_ARM = {4: 5, 6: 4, 8: 3, 10: 2, 12: 2}
DEFAULT_MIN_REPETITIONS = 3
UNITS_PER_ANCHOR = 120
SUPPORTED_TARGET_UNITS = (240, 360)
ANCHOR_KEYS_BY_COUNT = {
    2: frozenset((0, 1)),
    3: frozenset((0, 1, 2)),
}
GROUP_IDS_BY_COUNT = {
    count: tuple(range(1, count + 1)) for count in range(1, 121)
}
PARTITION_START_FIELDS = frozenset(("partition", "partitionId"))

# These are the only START fields which may vary across the density arms. A
# build label defaults to the scenario name, while config/workload are derived
# digests of the intentionally different recipe fields.
ALLOWED_START_DIFFERENCES = frozenset(
    (
        "run",
        "runId",
        "id",
        "scenario",
        "build",
        "config",
        "workload",
        "targetGroups",
        "unitsPerGroup",
        "batchGroups",
    )
)

REQUIRED_START_FIELDS = (
    "run",
    "scenario",
    "map",
    "build",
    "git",
    "source",
    "lab",
    "config",
    "workload",
    "variant",
    "seed",
    "duration",
    "sampleSec",
    "warmupSec",
    "settleSec",
    "mode",
    "targetGroups",
    "targetSyntheticUnits",
    "unitsPerGroup",
    "spawnAnchors",
    "batchGroups",
    "batchInterval",
    "vehicleEvery",
    "busRate",
    "expectedHcs",
    "minHcFps",
    "schedulerMode",
    "paramSig",
    "towns",
    "baselineAi",
    "baselineGroups",
    "baselineVehicles",
    "performanceAudit",
)


def _trim_number(value):
    if value is None:
        return None
    try:
        number = float(value)
    except (TypeError, ValueError, OverflowError):
        return None
    if not math.isfinite(number):
        return None
    rounded = round(number, 6)
    if rounded.is_integer():
        return int(rounded)
    return rounded


def _number(value):
    if value is None or isinstance(value, bool):
        return None
    try:
        number = float(value)
    except (TypeError, ValueError, OverflowError):
        return None
    if not math.isfinite(number):
        return None
    return number


def _integer(value):
    number = _number(value)
    if number is None or not number.is_integer():
        return None
    return int(number)


def _field(mapping, name):
    if not isinstance(mapping, dict):
        return None
    if name in mapping:
        return mapping[name]
    folded = dict((str(key).lower(), value) for key, value in mapping.items())
    return folded.get(name.lower())


def _same_value(left, right):
    left_number = _number(left)
    right_number = _number(right)
    if left_number is not None and right_number is not None:
        return abs(left_number - right_number) <= 1e-9
    if isinstance(left, str) and isinstance(right, str):
        return left.lower() == right.lower()
    return left == right


def _normalized_integer_map(value):
    """Normalize a JSON numeric map without hiding duplicate normalized keys."""
    return monitor._strict_integer_map(value)


def _partition_start_value(start):
    return _field(start, "partition") or _field(start, "partitionId")


def _partition_alias_conflict(start):
    if not isinstance(start, dict):
        return False
    values = [
        value
        for key, value in start.items()
        if str(key).lower() in ("partition", "partitionid") and value is not None
    ]
    return len(set(str(value) for value in values)) > 1


def _run_identity(mapping):
    return _field(mapping, "run") or _field(mapping, "runId") or _field(mapping, "id")


def _run_alias_conflict(mapping):
    if not isinstance(mapping, dict):
        return False
    values = [
        value
        for key, value in mapping.items()
        if str(key).lower() in ("run", "runid", "id") and value is not None
    ]
    return len(set(str(value) for value in values)) > 1


def _safe_label_token(value):
    token = value.strip() if isinstance(value, str) else ""
    return (
        token.lower() not in ("", "unknown", "none", "null", "unset", "missing")
        and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,127}", token) is not None
    )


def _git_token(value):
    token = value.strip() if isinstance(value, str) else ""
    return re.fullmatch(r"[0-9A-Fa-f]{7,64}(?:-dirty)?", token) is not None


def _digest_token(value):
    token = value.strip() if isinstance(value, str) else ""
    return re.fullmatch(r"[0-9A-Fa-f]{16}", token) is not None


def _cadence_limit(sample_sec):
    if sample_sec is None or sample_sec <= 0:
        return None
    return sample_sec + max(1.0, sample_sec * 0.25)


def _path_transition_problems(
    pathlegs, phase_indices, phase_times, target_groups, arm, duration
):
    raw_records = _field(pathlegs, "transition_evidence")
    if not isinstance(raw_records, list) or not raw_records:
        return ["PATHLEG transition evidence is missing"]
    if (
        target_groups is None
        or not isinstance(target_groups, int)
        or target_groups not in GROUP_IDS_BY_COUNT
        or arm not in ARMS
        or duration is None
        or not isinstance(duration, (int, float))
        or not math.isfinite(float(duration))
        or not 0 < duration <= 14400
    ):
        return ["partition path inputs are outside the registered bounds"]
    if len(raw_records) > 1000000:
        return ["PATHLEG transition evidence exceeds its bounded record limit"]
    records = []
    for raw in raw_records:
        if not isinstance(raw, dict):
            return ["PATHLEG transition evidence contains a non-record"]
        record = {
            "group": _integer(_field(raw, "group")),
            "transition": _integer(_field(raw, "transition")),
            "event_index": _integer(_field(raw, "event_index")),
            "units": _integer(_field(raw, "units")),
            "status": str(_field(raw, "status") or "").upper(),
            "route_id": str(_field(raw, "route_id") or _field(raw, "routeId") or "").strip(),
            "t": _number(_field(raw, "t")),
            "measure_t": _number(
                _field(raw, "measure_t")
                if _field(raw, "measure_t") is not None
                else _field(raw, "measureT")
            ),
            "elapsed": _number(_field(raw, "elapsed")),
        }
        if any(
            record[field] is None
            for field in ("group", "transition", "event_index", "units")
        ):
            return ["PATHLEG transition fields must be finite integers"]
        if (
            record["t"] is None
            or record["measure_t"] is None
            or record["elapsed"] is None
            or not record["route_id"]
        ):
            return ["PATHLEG transition lacks clocks or route identity"]
        records.append(record)
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

    by_group = dict((group_id, []) for group_id in GROUP_IDS_BY_COUNT[target_groups])
    for record in records:
        if record["group"] not in by_group:
            return ["PATHLEG group ID is outside 1..targetGroups"]
        if record["transition"] < 1 or not 1 <= record["units"] <= arm:
            return ["PATHLEG transition or unit count is outside its contract"]
        if record["route_id"] not in monitor.UTES_PARTITION_ROUTES:
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
    expected_scalars = {
        "count": len(records),
        "started": len(started_records),
        "completed": len(arrived_records),
        "arrivals": len(arrived_records),
        "arrival_units": sum(record["units"] for record in arrived_records),
    }
    for field, expected in expected_scalars.items():
        if _integer(_field(pathlegs, field)) != expected:
            problems.append("pathlegs.%s differs from transition evidence" % field)
    if expected_scalars["arrival_units"] < expected_scalars["completed"]:
        problems.append("pathlegs.arrival_units are below one live unit per arrival")
    if _field(pathlegs, "started_event_indices") != expected_started_indices:
        problems.append("started_event_indices differ from STARTED transitions")

    status = _field(pathlegs, "status")
    if not isinstance(status, dict):
        problems.append("pathlegs.status is missing")
    else:
        for name, expected in (
            ("STARTED", len(started_records)),
            ("ARRIVED", len(arrived_records)),
        ):
            if _integer(_field(status, name)) != expected:
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
    if _integer(_field(pathlegs, "route_count")) != len(expected_routes):
        problems.append("pathlegs.route_count differs from transition routes")
    route_ids = _field(pathlegs, "route_ids")
    if not isinstance(route_ids, list) or set(str(value) for value in route_ids) != set(expected_routes):
        problems.append("pathlegs.route_ids differ from transition routes")
    routes = _field(pathlegs, "routes")
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
                if _integer(_field(route, field)) != expected_value:
                    problems.append("route %s %s differs from transition evidence" % (route_id, field))
            if _integer(_field(route, "arrived")) != expected["completed"]:
                problems.append("route %s arrived differs from transition evidence" % route_id)
            route_status = _field(route, "status")
            if not isinstance(route_status, dict):
                problems.append("route %s status is missing" % route_id)
            else:
                for name, expected_value in (
                    ("STARTED", expected["started"]),
                    ("ARRIVED", expected["completed"]),
                ):
                    if _integer(_field(route_status, name)) != expected_value:
                        problems.append("route %s status %s differs from transition evidence" % (route_id, name))
            if expected["units"] < expected["completed"]:
                problems.append("route %s arrival units are below live arrivals" % route_id)
            expected_elapsed = (
                statistics.median(expected["elapsed"]) if expected["elapsed"] else None
            )
            actual_elapsed = _number(_field(route, "elapsed_median"))
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


def _issue(code, message, path=None, run=None):
    result = {"code": code, "message": message}
    if path is not None:
        result["path"] = path
    if run is not None:
        result["run"] = run
    return result


def _distribution(values):
    clean = [float(value) for value in values if _number(value) is not None]
    if not clean:
        return {"n": 0, "values": [], "min": None, "p5": None, "median": None,
                "mean": None, "p95": None, "max": None}
    scale = max(abs(value) for value in clean)
    mean = 0.0 if scale == 0 else scale * sum(
        value / scale for value in clean
    ) / len(clean)
    return {
        "n": len(clean),
        "values": [_trim_number(value) for value in clean],
        "min": _trim_number(min(clean)),
        "p5": _trim_number(monitor.percentile(clean, 5)),
        "median": _trim_number(statistics.median(clean)),
        "mean": _trim_number(mean),
        "p95": _trim_number(monitor.percentile(clean, 95)),
        "max": _trim_number(max(clean)),
    }


def load_summary(path):
    """Load one monitor summary from an RPT or a JSON summary file."""
    if str(path).lower().endswith(".json"):
        with open(path, "r", encoding="utf-8") as handle:
            payload = json.load(handle)
        if isinstance(payload, dict) and isinstance(payload.get("summary"), dict):
            payload = payload["summary"]
        if not isinstance(payload, dict):
            raise ValueError("monitor summary JSON must contain an object: %s" % path)
        payload = dict(payload)
        payload.pop("type", None)
        return payload
    state = monitor.parse_file(path)
    return state.summary() if state is not None else monitor.empty_summary(path)


def _require_number(mapping, key, issues, path, run, minimum=None, maximum=None):
    value = _number(_field(mapping, key))
    if value is None:
        issues.append(_issue("%s_MISSING" % key.upper(), "%s is missing or non-numeric" % key, path, run))
        return None
    if minimum is not None and value < minimum:
        issues.append(_issue("%s_RANGE" % key.upper(), "%s=%s is below %s" % (key, _trim_number(value), minimum), path, run))
    if maximum is not None and value > maximum:
        issues.append(_issue("%s_RANGE" % key.upper(), "%s=%s exceeds %s" % (key, _trim_number(value), maximum), path, run))
    return value


def _require_integer(mapping, key, issues, path, run, minimum=None, maximum=None):
    value = _integer(_field(mapping, key))
    if value is None:
        issues.append(_issue("%s_MISSING" % key.upper(), "%s is missing or non-integer" % key, path, run))
        return None
    if minimum is not None and value < minimum:
        issues.append(_issue("%s_RANGE" % key.upper(), "%s=%s is below %s" % (key, value, minimum), path, run))
    if maximum is not None and value > maximum:
        issues.append(_issue("%s_RANGE" % key.upper(), "%s=%s exceeds %s" % (key, value, maximum), path, run))
    return value


def _validate_run(summary, path):
    issues = []
    start = summary.get("start") if isinstance(summary, dict) else None
    start = start if isinstance(start, dict) else {}
    run = _run_identity(start) or (summary.get("run") if isinstance(summary, dict) else None)

    if not isinstance(summary, dict) or not summary.get("found"):
        issues.append(_issue("NO_START", "no complete monitor summary was found", path, run))
        return None, issues
    if summary.get("protocol") != "WASPLAB|v1":
        issues.append(_issue("PROTOCOL_MISMATCH", "summary protocol must equal WASPLAB|v1", path, run))
    if summary.get("ok") is not True:
        issues.append(_issue("MONITOR_NOT_OK", "monitor summary contains alerts or failed gates", path, run))
    monitor_alerts = summary.get("alerts")
    if not isinstance(monitor_alerts, list):
        issues.append(_issue(
            "MONITOR_ALERTS_INVALID",
            "monitor summary alerts must be an explicit list",
            path,
            run,
        ))
    elif monitor_alerts:
        issues.append(_issue("MONITOR_ALERTS", "monitor summary has one or more alerts", path, run))
    fatal_signatures = summary.get("fatal_signatures")
    if not isinstance(fatal_signatures, list):
        issues.append(_issue(
            "FATAL_SIGNATURES_INVALID",
            "monitor summary fatal_signatures must be an explicit list",
            path,
            run,
        ))
    elif fatal_signatures:
        issues.append(_issue("FATAL_SIGNATURES", "run contains fatal RPT signatures", path, run))
    if _run_alias_conflict(start):
        issues.append(_issue(
            "START_RUN_ALIAS_CONFLICT",
            "START run/runId/id aliases disagree",
            path,
            run,
        ))
    if _partition_alias_conflict(start):
        issues.append(_issue(
            "PARTITION_ALIAS_CONFLICT",
            "START partition/partitionId aliases disagree",
            path,
            run,
        ))
    summary_run = summary.get("run")
    if summary_run is None:
        issues.append(_issue(
            "SUMMARY_RUN_ID_MISSING",
            "top-level summary run identity is required",
            path,
            run,
        ))
    elif run is not None and str(run) != str(summary_run):
        issues.append(_issue(
            "SUMMARY_RUN_ID_MISMATCH",
            "top-level summary run differs from START identity",
            path,
            run,
        ))

    result = summary.get("result")
    if not isinstance(result, dict):
        issues.append(_issue("RESULT_MISSING", "run has no RESULT marker", path, run))
    else:
        if _run_alias_conflict(result):
            issues.append(_issue(
                "RESULT_RUN_ALIAS_CONFLICT",
                "RESULT run/runId/id aliases disagree",
                path,
                run,
            ))
        status = str(_field(result, "status") or "").upper()
        if status != "PASS":
            issues.append(_issue("RESULT_NOT_PASS", "RESULT status must be PASS, got %s" % (status or "missing"), path, run))
        if _number(_field(result, "complete")) != 1:
            issues.append(_issue("RESULT_INCOMPLETE", "RESULT complete must equal 1", path, run))
        result_run = _run_identity(result)
        if run is None or result_run is None or str(run) != str(result_run):
            issues.append(_issue("RUN_ID_MISMATCH", "START and RESULT run IDs must match", path, run))

    for field in REQUIRED_START_FIELDS:
        value = _run_identity(start) if field == "run" else _field(start, field)
        if value is None:
            issues.append(_issue("%s_MISSING" % field.upper(), "START field %s is required" % field, path, run))
    partition_id = _partition_start_value(start)
    if partition_id is None:
        issues.append(_issue("PARTITION_MISSING", "START field partition or partitionId is required", path, run))
    provenance_checks = (
        ("build", _field(start, "build"), _safe_label_token),
        ("git", _field(start, "git"), _git_token),
        ("source", _field(start, "source"), _digest_token),
        ("lab", _field(start, "lab"), _digest_token),
        ("config", _field(start, "config"), _digest_token),
        ("workload", _field(start, "workload"), _digest_token),
        ("partition", partition_id, _digest_token),
    )
    for field, value, validator in provenance_checks:
        if not validator(value):
            issues.append(_issue(
                "%s_INVALID" % field.upper(),
                "START %s provenance token is missing, placeholder, or malformed" % field,
                path,
                run,
            ))

    duration = _require_number(start, "duration", issues, path, run, 60, 14400)
    sample_sec = _require_number(start, "sampleSec", issues, path, run, 5, 300)
    _require_number(start, "warmupSec", issues, path, run, 0, 3600)
    settle_sec = _require_number(start, "settleSec", issues, path, run, 0, 600)
    bus_rate = _require_number(start, "busRate", issues, path, run, 0)
    _require_number(start, "minHcFps", issues, path, run, 1, 60)

    arm = _require_integer(start, "unitsPerGroup", issues, path, run, 1, 12)
    target_groups = _require_integer(start, "targetGroups", issues, path, run, 1, 120)
    target_units = _require_integer(start, "targetSyntheticUnits", issues, path, run, 1, 1440)
    spawn_anchors = _require_integer(start, "spawnAnchors", issues, path, run, 1, 3)
    batch_groups = _require_integer(start, "batchGroups", issues, path, run, 1, 10)
    batch_interval = _require_integer(start, "batchInterval", issues, path, run, 5, 600)
    vehicle_every = _require_integer(start, "vehicleEvery", issues, path, run, 0, 20)
    expected_hcs = _require_integer(start, "expectedHcs", issues, path, run, 0, 4)
    _require_integer(start, "baselineAi", issues, path, run, 0)
    _require_integer(start, "baselineGroups", issues, path, run, 0)
    _require_integer(start, "baselineVehicles", issues, path, run, 0)
    towns = _require_integer(start, "towns", issues, path, run, 1)
    _require_integer(start, "paramSig", issues, path, run, 0)

    if str(_field(start, "map") or "").lower() != "utes":
        issues.append(_issue("MAP_RECIPE", "group-partition campaigns require the Utes map", path, run))
    if towns is not None and towns != 3:
        issues.append(_issue("TOWNS_RECIPE", "the Utes partition contract requires exactly three towns", path, run))
    if arm not in ARMS:
        issues.append(_issue("ARM_UNSUPPORTED", "unitsPerGroup must be one of %s" % (ARMS,), path, run))
    elif str(_field(start, "scenario")) != "density-%s" % arm:
        issues.append(_issue("SCENARIO_ARM_MISMATCH", "scenario must match unitsPerGroup arm", path, run))
    if vehicle_every is not None and vehicle_every != 0:
        issues.append(_issue("VEHICLE_RECIPE", "pure-infantry arms require vehicleEvery=0", path, run))
    if expected_hcs is not None and expected_hcs != 0:
        issues.append(_issue("HC_RECIPE", "group-partition arms must be server-local expectedHcs=0", path, run))
    if bus_rate is not None and bus_rate != 0:
        issues.append(_issue("BUS_RECIPE", "group-partition arms require busRate=0", path, run))
    if str(_field(start, "schedulerMode") or "").lower() != "off":
        issues.append(_issue("SCHEDULER_RECIPE", "group-partition arms require schedulerMode=off", path, run))
    if str(_field(start, "mode")).lower() != "path-loop":
        issues.append(_issue("MODE_RECIPE", "group-partition arms require path-loop mode", path, run))
    if batch_interval is not None and batch_interval != 20:
        issues.append(_issue("BATCH_INTERVAL", "group-partition batchInterval must remain 20 seconds", path, run))
    if arm in ARMS and batch_groups is not None and batch_groups != BATCH_GROUPS_BY_ARM[arm]:
        issues.append(_issue(
            "BATCH_GROUPS_RECIPE",
            "batchGroups must equal %s for the density-%s arm" % (BATCH_GROUPS_BY_ARM[arm], arm),
            path,
            run,
        ))
    if arm in ARMS and target_groups is not None and target_units is not None:
        if target_groups * arm != target_units:
            issues.append(_issue("TARGET_PRODUCT", "targetGroups*unitsPerGroup must equal targetSyntheticUnits", path, run))
    if target_units is not None and target_units not in SUPPORTED_TARGET_UNITS:
        issues.append(_issue(
            "PARTITION_TARGET_UNSUPPORTED",
            "targetSyntheticUnits must be exactly 240 or 360 for a registered group-partition campaign",
            path,
            run,
        ))
    if target_units is not None and spawn_anchors is not None:
        if target_units <= 0 or target_units % UNITS_PER_ANCHOR != 0 or spawn_anchors != target_units // UNITS_PER_ANCHOR:
            issues.append(_issue("ANCHOR_TARGET", "spawnAnchors must represent exact 120-member workloads", path, run))
        if spawn_anchors > 3:
            issues.append(_issue("ANCHOR_LIMIT", "Utes exposes at most three fixed group-partition anchors", path, run))
        if target_groups is not None and spawn_anchors > 0 and target_groups % spawn_anchors != 0:
            issues.append(_issue("ANCHOR_GROUPS_UNEQUAL", "whole groups cannot be distributed equally across anchors", path, run))

    phase = summary.get("phase")
    phase = phase if isinstance(phase, dict) else {}
    expected_sequence = ["SPAWN", "SETTLE", "GO", "MEASURE", "CLEANUP"]
    sequence = _field(phase, "sequence")
    normalized_sequence = [str(value).upper() for value in sequence] if isinstance(sequence, list) else None
    if normalized_sequence != expected_sequence:
        issues.append(_issue("PHASE_SEQUENCE", "phase.sequence must be exactly SPAWN,SETTLE,GO,MEASURE,CLEANUP", path, run))
    if str(_field(phase, "measurement_started_phase") or "").upper() != "GO":
        issues.append(_issue("MEASUREMENT_START_PHASE", "measurement must start at the GO phase", path, run))

    composition = summary.get("composition")
    composition = composition if isinstance(composition, dict) else {}

    if isinstance(result, dict):
        required_partition_result_fields = (
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
        missing_result_fields = [
            field
            for field in required_partition_result_fields
            if _field(result, field) is None
        ]
        if missing_result_fields:
            issues.append(_issue(
                "RESULT_PARTITION_FIELD_MISSING",
                "RESULT is missing partition fields: %s"
                % ",".join(missing_result_fields),
                path,
                run,
            ))
        invalid_result_fields = []
        numeric_specs = {
            "measureDuration": (False, 0, 14400),
            "measureT": (False, 0, 14700),
            "fpsMin": (False, 0, 1000),
            "fpsAvg": (False, 0, 1000),
            "fpsSamples": (True, 1, monitor.MAX_EXPECTED_SAMPLES),
            "fpsExpected": (True, 1, monitor.MAX_EXPECTED_SAMPLES),
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
        for field, (integer, minimum, maximum) in numeric_specs.items():
            if field in missing_result_fields:
                continue
            value = _number(_field(result, field))
            if (
                value is None
                or (integer and not value.is_integer())
                or value < minimum
                or value > maximum
            ):
                invalid_result_fields.append(field)
        for field in ("histogram", "anchorRequested", "anchorMembers"):
            if field not in missing_result_fields and _normalized_integer_map(
                _field(result, field)
            ) is None:
                invalid_result_fields.append(field)
        if invalid_result_fields:
            issues.append(_issue(
                "RESULT_PARTITION_FIELD_INVALID",
                "RESULT partition fields are malformed or out of range: %s"
                % ",".join(sorted(set(invalid_result_fields))),
                path,
                run,
            ))
    required_composition = (
        "target_synthetic_units", "target_groups", "spawn_anchors", "anchor_requested",
        "anchor_members", "realized_groups", "requested_infantry", "created_infantry",
        "crew", "vehicles", "final_members", "final_groups", "histogram",
        "underfill_groups", "oversize_groups", "create_failures", "create_failure_groups",
        "attainment_pct",
    )
    for field in required_composition:
        if _field(composition, field) is None:
            issues.append(_issue("COMPOSITION_%s_MISSING" % field.upper(), "composition.%s is required" % field, path, run))

    requested_infantry = _require_number(composition, "requested_infantry", issues, path, run, 0)
    created_infantry = _require_number(composition, "created_infantry", issues, path, run, 0)
    final_members = _require_number(composition, "final_members", issues, path, run, 0)
    attainment = _require_number(composition, "attainment_pct", issues, path, run, 0)
    for field in ("crew", "vehicles", "underfill_groups", "oversize_groups", "create_failures", "create_failure_groups"):
        value = _require_number(composition, field, issues, path, run, 0)
        if value is not None and value != 0:
            issues.append(_issue("COMPOSITION_%s" % field.upper(), "composition.%s must equal zero" % field, path, run))
    if attainment is not None and attainment < 98:
        issues.append(_issue("MEMBER_ATTAINMENT", "realized member attainment %.3f%% is below 98%%" % attainment, path, run))
    if target_units is not None and final_members is not None:
        calculated_attainment = 100.0 * final_members / target_units if target_units > 0 else 0.0
        if calculated_attainment < 98:
            issues.append(_issue("MEMBER_ATTAINMENT_CALCULATED", "finalMembers/targetSyntheticUnits is below 98%", path, run))
        if attainment is not None and abs(calculated_attainment - attainment) > 0.2:
            issues.append(_issue("MEMBER_ATTAINMENT_INCONSISTENT", "reported and calculated member attainment differ", path, run))
    if final_members is not None and created_infantry is not None and final_members != created_infantry:
        issues.append(_issue("PURE_INFANTRY_INCONSISTENT", "final members must equal created infantry when crew is zero", path, run))
    for field, value in (
        ("requested_infantry", requested_infantry),
        ("created_infantry", created_infantry),
        ("final_members", final_members),
    ):
        if target_units is not None and value is not None and value != target_units:
            issues.append(_issue(
                "%s_TARGET_MISMATCH" % field.upper(),
                "composition.%s must equal targetSyntheticUnits" % field,
                path,
                run,
            ))

    for start_key, composition_key in (
        ("targetSyntheticUnits", "target_synthetic_units"),
        ("targetGroups", "target_groups"),
        ("spawnAnchors", "spawn_anchors"),
    ):
        if _field(start, start_key) is not None and _field(composition, composition_key) is not None and not _same_value(
            _field(start, start_key), _field(composition, composition_key)
        ):
            issues.append(_issue("%s_INCONSISTENT" % start_key.upper(), "START and composition %s values differ" % start_key, path, run))

    realized_groups = _require_number(composition, "realized_groups", issues, path, run, 0)
    final_groups = _require_number(composition, "final_groups", issues, path, run, 0)
    realized_record_count = _require_number(
        composition, "realized_record_count", issues, path, run, 0
    )
    if target_groups is not None:
        if realized_groups is not None and realized_groups != target_groups:
            issues.append(_issue("REALIZED_GROUPS", "realized group count must equal targetGroups", path, run))
        if final_groups is not None and final_groups != target_groups:
            issues.append(_issue("FINAL_GROUPS", "final group count must equal targetGroups", path, run))
        if realized_record_count is not None and realized_record_count != target_groups:
            issues.append(_issue(
                "REALIZED_RECORD_COUNT",
                "per-group REALIZED record count must equal targetGroups",
                path,
                run,
            ))

    histogram = _field(composition, "histogram")
    histogram_groups = None
    histogram_members = None
    normalized_histogram = {}
    histogram_invalid = not isinstance(histogram, dict) or not histogram
    if not histogram_invalid:
        for size, count in histogram.items():
            size_value = _integer(size)
            count_value = _integer(count)
            if size_value is None or size_value < 0 or count_value is None or count_value < 0:
                histogram_invalid = True
                break
            normalized_histogram[size_value] = normalized_histogram.get(size_value, 0) + count_value
    if histogram_invalid:
        issues.append(_issue(
            "HISTOGRAM_INVALID",
            "composition.histogram must contain non-negative integer size/count pairs",
            path,
            run,
        ))
    else:
        histogram_groups = sum(normalized_histogram.values())
        histogram_members = sum(size * count for size, count in normalized_histogram.items())
        if final_groups is not None and histogram_groups != final_groups:
            issues.append(_issue(
                "HISTOGRAM_GROUP_COUNT",
                "histogram group count must equal final_groups",
                path,
                run,
            ))
        if final_members is not None and histogram_members != final_members:
            issues.append(_issue(
                "HISTOGRAM_MEMBER_COUNT",
                "histogram weighted members must equal final_members",
                path,
                run,
            ))
        if arm in ARMS and target_groups is not None and normalized_histogram != {arm: target_groups}:
            issues.append(_issue(
                "HISTOGRAM_ARM_MISMATCH",
                "pure-infantry histogram must contain only the declared unitsPerGroup arm",
                path,
                run,
            ))

    anchor_requested = _field(composition, "anchor_requested")
    if not isinstance(anchor_requested, dict):
        issues.append(_issue("ANCHOR_REQUESTED_INVALID", "composition.anchor_requested must be a mapping", path, run))
    elif spawn_anchors is not None:
        anchor_keys = [_integer(key) for key in anchor_requested]
        expected_anchor_keys = ANCHOR_KEYS_BY_COUNT.get(spawn_anchors)
        if expected_anchor_keys is not None and (
            set(anchor_keys) != expected_anchor_keys or len(set(anchor_keys)) != len(anchor_keys)
        ):
            issues.append(_issue("ANCHOR_REQUESTED_KEYS", "anchor_requested keys must normalize to exactly 0..spawnAnchors-1", path, run))
        values = [_number(value) for value in anchor_requested.values()]
        if len(values) != spawn_anchors or any(value != UNITS_PER_ANCHOR for value in values):
            issues.append(_issue("ANCHOR_REQUESTED_UNEQUAL", "every fixed anchor must request exactly 120 members", path, run))
        if all(value is not None for value in values):
            anchor_requested_total = sum(values)
            if requested_infantry is not None and anchor_requested_total != requested_infantry:
                issues.append(_issue(
                    "ANCHOR_REQUESTED_TOTAL",
                    "anchor requested-member sum must equal requested_infantry",
                    path,
                    run,
                ))
    anchor_members = _field(composition, "anchor_members")
    if not isinstance(anchor_members, dict):
        issues.append(_issue("ANCHOR_MEMBERS_INVALID", "composition.anchor_members must be a mapping", path, run))
    elif spawn_anchors is not None:
        anchor_keys = [_integer(key) for key in anchor_members]
        expected_anchor_keys = ANCHOR_KEYS_BY_COUNT.get(spawn_anchors)
        if expected_anchor_keys is not None and (
            set(anchor_keys) != expected_anchor_keys or len(set(anchor_keys)) != len(anchor_keys)
        ):
            issues.append(_issue("ANCHOR_MEMBERS_KEYS", "anchor_members keys must normalize to exactly 0..spawnAnchors-1", path, run))
        values = [_number(value) for value in anchor_members.values()]
        if len(values) != spawn_anchors or any(value != UNITS_PER_ANCHOR for value in values):
            issues.append(_issue("ANCHOR_MEMBERS_UNEQUAL", "every fixed anchor must realize exactly 120 members", path, run))
        if all(value is not None for value in values):
            anchor_member_total = sum(values)
            for field, value in (
                ("created_infantry", created_infantry),
                ("final_members", final_members),
            ):
                if value is not None and anchor_member_total != value:
                    issues.append(_issue(
                        "ANCHOR_MEMBERS_%s" % field.upper(),
                        "anchor realized-member sum must equal %s" % field,
                        path,
                        run,
                    ))

    realized_evidence = _field(composition, "realized_evidence")
    if not isinstance(realized_evidence, dict):
        issues.append(_issue(
            "REALIZED_EVIDENCE_MISSING",
            "composition.realized_evidence derived from REALIZED rows is required",
            path,
            run,
        ))
    else:
        evidence_record_count = _integer(_field(realized_evidence, "record_count"))
        evidence_valid_count = _integer(_field(realized_evidence, "valid_count"))
        safe_target_groups = (
            target_groups
            if target_groups is not None and 1 <= target_groups <= 120
            else None
        )
        if (
            evidence_record_count is None
            or evidence_record_count < 0
            or (
                safe_target_groups is not None
                and evidence_record_count != safe_target_groups
            )
        ):
            issues.append(_issue(
                "REALIZED_EVIDENCE_RECORD_COUNT",
                "REALIZED evidence record_count must equal targetGroups",
                path,
                run,
            ))
        if (
            evidence_valid_count is None
            or evidence_valid_count < 0
            or evidence_valid_count != evidence_record_count
            or (
                safe_target_groups is not None
                and evidence_valid_count != safe_target_groups
            )
        ):
            issues.append(_issue(
                "REALIZED_EVIDENCE_VALID_COUNT",
                "every REALIZED row must be valid and counts must equal targetGroups",
                path,
                run,
            ))

        group_ids = _field(realized_evidence, "group_ids")
        normalized_group_ids = None
        if isinstance(group_ids, list):
            normalized_group_ids = [_integer(group_id) for group_id in group_ids]
        if (
            safe_target_groups is not None
            and tuple(normalized_group_ids or ())
            != GROUP_IDS_BY_COUNT[safe_target_groups]
        ) or (safe_target_groups is None and normalized_group_ids is None):
            issues.append(_issue(
                "REALIZED_EVIDENCE_GROUP_IDS",
                "REALIZED group_ids must be exactly 1..targetGroups with no gaps or duplicates",
                path,
                run,
            ))

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
            evidence_value = _field(realized_evidence, field)
            cumulative_value = _field(composition, field)
            if _number(evidence_value) is None or not _same_value(
                evidence_value, cumulative_value
            ):
                issues.append(_issue(
                    "REALIZED_EVIDENCE_%s" % field.upper(),
                    "REALIZED %s sum must equal cumulative composition.%s"
                    % (field, field),
                    path,
                    run,
                ))

        for field in ("histogram", "anchor_requested", "anchor_members"):
            evidence_map = _normalized_integer_map(
                _field(realized_evidence, field)
            )
            cumulative_map = _normalized_integer_map(_field(composition, field))
            if evidence_map is None or evidence_map != cumulative_map:
                issues.append(_issue(
                    "REALIZED_EVIDENCE_%s" % field.upper(),
                    "REALIZED %s must equal cumulative composition.%s"
                    % (field, field),
                    path,
                    run,
                ))

    work = summary.get("work")
    work = work if isinstance(work, dict) else {}
    member_seconds = _require_number(work, "member_seconds", issues, path, run, 0.000001)
    group_seconds = _require_number(work, "group_seconds", issues, path, run, 0.000001)
    measurement_seconds = _require_number(work, "measurement_seconds", issues, path, run, 0.000001)
    if target_units is not None and measurement_seconds is not None and member_seconds is not None:
        minimum_member_seconds = target_units * measurement_seconds * 0.98
        if member_seconds < minimum_member_seconds:
            issues.append(_issue(
                "MEMBER_SECONDS_ATTAINMENT",
                "member_seconds is below 98% of targetSyntheticUnits*measurement_seconds",
                path,
                run,
            ))
        if sample_sec is not None and member_seconds > target_units * (measurement_seconds + sample_sec):
            issues.append(_issue(
                "MEMBER_SECONDS_OVERCOUNT",
                "member_seconds exceeds targetSyntheticUnits*(measurement_seconds+sampleSec)",
                path,
                run,
            ))
    if target_groups is not None and measurement_seconds is not None and group_seconds is not None:
        minimum_group_seconds = target_groups * measurement_seconds * 0.98
        if group_seconds < minimum_group_seconds:
            issues.append(_issue(
                "GROUP_SECONDS_ATTAINMENT",
                "group_seconds is below 98% of targetGroups*measurement_seconds",
                path,
                run,
            ))
        if sample_sec is not None and group_seconds > target_groups * (measurement_seconds + sample_sec):
            issues.append(_issue(
                "GROUP_SECONDS_OVERCOUNT",
                "group_seconds exceeds targetGroups*(measurement_seconds+sampleSec)",
                path,
                run,
            ))
    if measurement_seconds is not None and duration is not None and sample_sec is not None:
        if abs(measurement_seconds - duration) > 2.0:
            issues.append(_issue("MEASUREMENT_DURATION", "measurement_seconds differs from START duration beyond scheduler/rounding jitter", path, run))

    sample_evidence = _field(work, "sample_evidence")
    if not isinstance(sample_evidence, dict):
        issues.append(_issue(
            "SAMPLE_EVIDENCE_MISSING",
            "work.sample_evidence derived from MEASURE SAMPLE rows is required",
            path,
            run,
        ))
    else:
        evidence_counts = {}
        for field in (
            "record_count",
            "fps_count",
            "ai_count",
            "groups_count",
            "probe_ms_count",
            "member_seconds_count",
            "group_seconds_count",
        ):
            count = _integer(_field(sample_evidence, field))
            evidence_counts[field] = count
            if count is None or count < 1:
                issues.append(_issue(
                    "SAMPLE_EVIDENCE_%s" % field.upper(),
                    "sample evidence %s must be a positive integer" % field,
                    path,
                    run,
                ))
        valid_counts = [
            count for count in evidence_counts.values()
            if count is not None and count >= 1
        ]
        if len(valid_counts) == 7 and len(set(valid_counts)) != 1:
            issues.append(_issue(
                "SAMPLE_EVIDENCE_COUNT_MISMATCH",
                "MEASURE sample, load, probe, and work-counter counts must match",
                path,
                run,
            ))
        if (
            evidence_counts.get("fps_count")
            != evidence_counts.get("record_count")
        ):
            issues.append(_issue(
                "SAMPLE_EVIDENCE_FPS_COUNT",
                "every MEASURE sample must carry one finite FPS value",
                path,
                run,
            ))
        if (
            evidence_counts.get("ai_count") != evidence_counts.get("record_count")
            or evidence_counts.get("groups_count") != evidence_counts.get("record_count")
        ):
            issues.append(_issue(
                "SAMPLE_EVIDENCE_LOAD_COUNT",
                "every MEASURE sample must carry integer AI and group counts",
                path,
                run,
            ))
        if evidence_counts.get("probe_ms_count") != evidence_counts.get("record_count"):
            issues.append(_issue(
                "PROBE_MS_INVALID",
                "every MEASURE sample must carry finite non-negative probeMs",
                path,
                run,
            ))

        sample_series = {}
        for field, integer, minimum, maximum in (
            ("fps_values", False, 0, 1000),
            ("ai_values", True, 0, 10000000),
            ("groups_values", True, 0, 1000000),
            ("probe_ms_values", False, 0, 1000000),
        ):
            raw_values = _field(sample_evidence, field)
            values = (
                [_number(value) for value in raw_values]
                if isinstance(raw_values, list)
                else None
            )
            if (
                values is None
                or len(values) != evidence_counts.get("record_count")
                or any(
                    value is None
                    or (integer and not value.is_integer())
                    or value < minimum
                    or value > maximum
                    for value in values
                )
            ):
                issues.append(_issue(
                    "PROBE_MS_INVALID" if field == "probe_ms_values" else "SAMPLE_%s_INVALID" % field.upper(),
                    "%s must contain one bounded value per MEASURE sample" % field,
                    path,
                    run,
                ))
            else:
                sample_series[field] = values

        def metric_matches(mapping, field, expected, tolerance=0.001):
            actual = _number(_field(mapping, field)) if isinstance(mapping, dict) else None
            return actual is not None and abs(actual - expected) <= tolerance

        fps_series = sample_series.get("fps_values")
        fps_summary_for_samples = summary.get("fps")
        if fps_series:
            calculated_fps = {
                "min": min(fps_series),
                "avg": sum(fps_series) / len(fps_series),
                "median": statistics.median(fps_series),
                "p5": monitor.percentile(fps_series, 5),
            }
            if not all(
                metric_matches(fps_summary_for_samples, field, expected)
                for field, expected in calculated_fps.items()
            ):
                issues.append(_issue(
                    "SAMPLE_FPS_SUMMARY_INCONSISTENT",
                    "fps summary must be recomputed from SAMPLE fps_values",
                    path,
                    run,
                ))
        ai_series = sample_series.get("ai_values")
        if ai_series and not metric_matches(summary, "ai_peak", max(ai_series)):
            issues.append(_issue(
                "SAMPLE_AI_PEAK_INCONSISTENT",
                "ai_peak must equal the SAMPLE ai_values maximum",
                path,
                run,
            ))
        groups_series = sample_series.get("groups_values")
        if groups_series and not metric_matches(summary, "groups_peak", max(groups_series)):
            issues.append(_issue(
                "SAMPLE_GROUPS_PEAK_INCONSISTENT",
                "groups_peak must equal the SAMPLE groups_values maximum",
                path,
                run,
            ))
        probe_series = sample_series.get("probe_ms_values")
        probe_summary = summary.get("probe_ms")
        if probe_series:
            expected_probe = {
                "count": len(probe_series),
                "median": statistics.median(probe_series),
                "p95": monitor.percentile(probe_series, 95),
                "max": max(probe_series),
            }
            if not isinstance(probe_summary, dict) or not all(
                metric_matches(probe_summary, field, expected)
                for field, expected in expected_probe.items()
            ):
                issues.append(_issue(
                    "PROBE_MS_INVALID",
                    "probe_ms count/median/p95/max must be recomputed from SAMPLE values",
                    path,
                    run,
                ))

        measurement_sample_count = _integer(
            _field(summary, "measurement_sample_count")
        )
        if (
            measurement_sample_count is None
            or measurement_sample_count < 1
            or any(
                count != measurement_sample_count
                for count in evidence_counts.values()
            )
        ):
            issues.append(_issue(
                "SAMPLE_EVIDENCE_MEASUREMENT_COUNT",
                "sample evidence counts must equal required measurement_sample_count",
                path,
                run,
            ))

        if _field(sample_evidence, "member_seconds_monotonic") is not True:
            issues.append(_issue(
                "SAMPLE_MEMBER_SECONDS_MONOTONIC",
                "MEASURE memberSeconds counters must be present and monotonic",
                path,
                run,
            ))
        if _field(sample_evidence, "group_seconds_monotonic") is not True:
            issues.append(_issue(
                "SAMPLE_GROUP_SECONDS_MONOTONIC",
                "MEASURE groupSeconds counters must be present and monotonic",
                path,
                run,
            ))

        measure_t_values = _field(sample_evidence, "measure_t_values")
        cadence_values = None
        if isinstance(measure_t_values, list):
            cadence_values = [_number(value) for value in measure_t_values]
        cadence_limit = _cadence_limit(sample_sec)
        sample_t_values = _field(sample_evidence, "sample_t_values")
        wall_values = None
        if isinstance(sample_t_values, list):
            wall_values = [_number(value) for value in sample_t_values]
        go_time = None
        phase_records_for_clock = _field(phase, "records")
        if isinstance(phase_records_for_clock, list):
            for phase_record in phase_records_for_clock:
                phase_fields = _field(phase_record, "fields")
                if (
                    isinstance(phase_fields, dict)
                    and str(_field(phase_fields, "phase") or "").upper() == "GO"
                ):
                    go_time = _number(_field(phase_fields, "t"))
                    break
        cadence_ok = (
            cadence_values is not None
            and all(value is not None for value in cadence_values)
            and len(cadence_values) == evidence_counts.get("record_count")
            and bool(cadence_values)
            and cadence_limit is not None
            and 0 <= cadence_values[0] <= cadence_limit
            and all(
                current > previous and current - previous <= cadence_limit
                for previous, current in zip(cadence_values, cadence_values[1:])
            )
            and (
                duration is None
                or (
                    all(value <= duration for value in cadence_values)
                    and cadence_values[-1] >= max(0.0, duration - sample_sec)
                )
            )
            and _integer(_field(sample_evidence, "measure_t_count"))
            == len(cadence_values)
            and _integer(_field(sample_evidence, "measure_t_unique_count"))
            == len(set(cadence_values))
            and wall_values is not None
            and all(value is not None for value in wall_values)
            and len(wall_values) == evidence_counts.get("record_count")
            and _integer(_field(sample_evidence, "sample_t_count"))
            == len(wall_values)
            and all(
                current > previous and current - previous <= cadence_limit
                for previous, current in zip(wall_values, wall_values[1:])
            )
            and go_time is not None
            and duration is not None
            and all(
                go_time <= sample_t <= go_time + duration
                for sample_t in wall_values
            )
            and all(
                abs((sample_t - go_time) - measure_t) <= 1.0
                for sample_t, measure_t in zip(wall_values, cadence_values)
            )
        )
        if not cadence_ok:
            issues.append(_issue(
                "SAMPLE_MEASURE_TIME_CADENCE",
                "MEASURE samples must cover the full window at sampleSec cadence plus bounded jitter",
                path,
                run,
            ))

        member_series = _field(sample_evidence, "member_seconds_values")
        group_series = _field(sample_evidence, "group_seconds_values")
        member_series = (
            [_number(value) for value in member_series]
            if isinstance(member_series, list)
            else None
        )
        group_series = (
            [_number(value) for value in group_series]
            if isinstance(group_series, list)
            else None
        )

        def work_series_ok(values, target, latest):
            if (
                values is None
                or cadence_values is None
                or target is None
                or latest is None
                or len(values) != len(cadence_values)
                or any(value is None or value < 0 for value in values)
                or any(value is None for value in cadence_values)
                or not values
                or abs(values[-1] - latest) > 1e-9
            ):
                return False
            previous_value = 0.0
            previous_t = 0.0
            for value, measure_t in zip(values, cadence_values):
                elapsed = measure_t - previous_t
                if value + 1e-9 < previous_value:
                    return False
                if value > target * (measure_t + 1.0) + 1e-9:
                    return False
                if value - previous_value > target * (elapsed + 1.0) + 1e-9:
                    return False
                previous_value = value
                previous_t = measure_t
            return True

        if not work_series_ok(
            member_series,
            target_units,
            _number(_field(sample_evidence, "latest_member_seconds")),
        ) or not work_series_ok(
            group_series,
            target_groups,
            _number(_field(sample_evidence, "latest_group_seconds")),
        ):
            issues.append(_issue(
                "SAMPLE_WORK_BOUNDS",
                "MEASURE work counters exceed the physical target*time envelope",
                path,
                run,
            ))

        for label, latest_field, total, target in (
            (
                "MEMBER_SECONDS",
                "latest_member_seconds",
                member_seconds,
                target_units,
            ),
            (
                "GROUP_SECONDS",
                "latest_group_seconds",
                group_seconds,
                target_groups,
            ),
        ):
            latest = _number(_field(sample_evidence, latest_field))
            if latest is None or latest < 0:
                issues.append(_issue(
                    "SAMPLE_%s_LATEST" % label,
                    "%s must be a finite non-negative counter" % latest_field,
                    path,
                    run,
                ))
                continue
            if total is not None and latest > total + 1e-9:
                issues.append(_issue(
                    "SAMPLE_%s_LATEST" % label,
                    "%s cannot exceed the final work total" % latest_field,
                    path,
                    run,
                ))
            elif (
                total is not None
                and target is not None
                and target > 0
                and sample_sec is not None
                and total - latest > target * sample_sec + 1e-9
            ):
                issues.append(_issue(
                    "SAMPLE_%s_DELTA" % label,
                    "final work total may advance by at most one sample interval",
                    path,
                    run,
                ))

    if isinstance(result, dict):
        result_conflicts = []
        cleanup_measure_t = None
        cleanup_wall_t = None
        go_wall_t = None
        phase_records_for_result = _field(phase, "records")
        if isinstance(phase_records_for_result, list):
            for phase_record in phase_records_for_result:
                phase_fields = _field(phase_record, "fields")
                phase_fields = phase_fields if isinstance(phase_fields, dict) else {}
                phase_name = str(_field(phase_fields, "phase") or "").upper()
                if phase_name == "GO":
                    go_wall_t = _number(_field(phase_fields, "t"))
                elif phase_name == "CLEANUP":
                    cleanup_measure_t = _number(_field(phase_fields, "measureT"))
                    cleanup_wall_t = _number(_field(phase_fields, "t"))
        if cleanup_measure_t is None and cleanup_wall_t is not None and go_wall_t is not None:
            cleanup_measure_t = cleanup_wall_t - go_wall_t
        expected_sample_count = None
        if duration is not None and sample_sec is not None and sample_sec > 0:
            ratio = duration / sample_sec
            if math.isfinite(ratio) and 0 < ratio <= monitor.MAX_EXPECTED_SAMPLES:
                expected_sample_count = max(1, int(ratio))
        reported_expected_sample_count = _integer(
            _field(summary, "expected_sample_count")
        )
        if reported_expected_sample_count != expected_sample_count:
            issues.append(_issue(
                "EXPECTED_SAMPLE_COUNT_INCONSISTENT",
                "expected_sample_count must be derived from START duration/sampleSec",
                path,
                run,
            ))
        observed_fps_count = (
            _integer(_field(sample_evidence, "fps_count"))
            if isinstance(sample_evidence, dict)
            else None
        )
        expected_coverage = (
            100.0 * observed_fps_count / expected_sample_count
            if observed_fps_count is not None
            and expected_sample_count is not None
            and expected_sample_count > 0
            else None
        )
        fps_summary = summary.get("fps")
        fps_summary = fps_summary if isinstance(fps_summary, dict) else {}
        path_summary_for_result = summary.get("pathlegs")
        path_summary_for_result = (
            path_summary_for_result
            if isinstance(path_summary_for_result, dict)
            else {}
        )
        for result_field, mapping, summary_field in (
            ("targetSyntheticUnits", composition, "target_synthetic_units"),
            ("targetGroups", composition, "target_groups"),
            ("spawnAnchors", composition, "spawn_anchors"),
            ("realizedGroups", composition, "realized_groups"),
            ("requestedInfantry", composition, "requested_infantry"),
            ("createdInfantry", composition, "created_infantry"),
            ("crew", composition, "crew"),
            ("createdVehicles", composition, "vehicles"),
            ("finalMembers", composition, "final_members"),
            ("underfillGroups", composition, "underfill_groups"),
            ("oversizeGroups", composition, "oversize_groups"),
            ("createFailures", composition, "create_failures"),
            ("createFailureGroups", composition, "create_failure_groups"),
            ("memberSeconds", work, "member_seconds"),
            ("groupSeconds", work, "group_seconds"),
            ("fpsMin", fps_summary, "min"),
            ("fpsAvg", fps_summary, "avg"),
            ("aiPeak", summary, "ai_peak"),
            ("groupsPeak", summary, "groups_peak"),
            ("pathLegsStarted", path_summary_for_result, "started"),
        ):
            direct_value = _field(result, result_field)
            summary_value = _field(mapping, summary_field)
            if direct_value is not None and summary_value is not None:
                direct_number = _number(direct_value)
                summary_number = _number(summary_value)
                if result_field == "fpsAvg" and direct_number is not None and summary_number is not None:
                    differs = abs(direct_number - summary_number) > 0.11
                else:
                    differs = not _same_value(direct_value, summary_value)
                if differs:
                    result_conflicts.append(result_field)
        for result_field, expected_value in (
            ("measureDuration", cleanup_measure_t),
            ("measureT", cleanup_measure_t),
            ("fpsSamples", observed_fps_count),
            ("fpsExpected", expected_sample_count),
            ("fpsCoveragePct", expected_coverage),
        ):
            direct_value = _number(_field(result, result_field))
            if (
                direct_value is not None
                and expected_value is not None
                and abs(direct_value - expected_value)
                > (0.11 if result_field == "fpsCoveragePct" else 0.001)
            ):
                result_conflicts.append(result_field)
        for result_field, summary_field in (
            ("histogram", "histogram"),
            ("anchorRequested", "anchor_requested"),
            ("anchorMembers", "anchor_members"),
        ):
            direct_map = _normalized_integer_map(_field(result, result_field))
            summary_map = _normalized_integer_map(_field(composition, summary_field))
            if direct_map is not None and summary_map is not None and direct_map != summary_map:
                result_conflicts.append(result_field)
        if result_conflicts:
            issues.append(_issue(
                "RESULT_PARTITION_INCONSISTENT",
                "RESULT differs from independently summarized fields: %s"
                % ",".join(result_conflicts),
                path,
                run,
            ))

    fps = summary.get("fps")
    fps = fps if isinstance(fps, dict) else {}
    for field in ("median", "avg", "min", "p5"):
        _require_number(fps, field, issues, path, run, 0, 1000)

    pathlegs = summary.get("pathlegs")
    pathlegs = pathlegs if isinstance(pathlegs, dict) else {}
    started = _require_integer(pathlegs, "started", issues, path, run, 1)
    completed = _require_integer(pathlegs, "completed", issues, path, run, 0)
    arrival_units = _require_integer(pathlegs, "arrival_units", issues, path, run, 0)
    route_count = _require_integer(pathlegs, "route_count", issues, path, run, 1)
    routes = _field(pathlegs, "routes")
    if not isinstance(routes, dict) or not routes:
        issues.append(_issue("ROUTES_MISSING", "pathlegs.routes must contain route-normalized evidence", path, run))
        routes = {}
    if route_count is not None and route_count != len(routes):
        issues.append(_issue("ROUTE_COUNT_MISMATCH", "pathlegs.route_count must equal the number of route summaries", path, run))
    if target_groups is not None and started is not None and started < target_groups:
        issues.append(_issue("INITIAL_LEGS_MISSING", "pathlegs.started must cover every realized group at GO", path, run))
    if spawn_anchors is not None and route_count is not None and route_count < spawn_anchors:
        issues.append(_issue("ANCHOR_ROUTES_MISSING", "route_count must cover every fixed spawn anchor", path, run))
    route_started_total = 0.0
    route_completed_total = 0.0
    route_arrival_units_total = 0.0
    route_totals_valid = True
    for route_id, route in routes.items():
        if not isinstance(route, dict):
            issues.append(_issue("ROUTE_INVALID", "route %s must be a mapping" % route_id, path, run))
            route_totals_valid = False
            continue
        route_records = _integer(_field(route, "records"))
        route_started = _integer(_field(route, "started"))
        route_completed = _integer(_field(route, "completed"))
        route_arrival_units = _integer(_field(route, "units"))
        route_arrived = _integer(_field(route, "arrived"))
        if route_completed is None:
            route_completed = route_arrived
        if route_records is None or route_records < 1:
            issues.append(_issue("ROUTE_RECORDS_MISSING", "route %s must report a positive integer record count" % route_id, path, run))
            route_totals_valid = False
        if route_started is None or route_started <= 0:
            issues.append(_issue("ROUTE_STARTED_MISSING", "route %s must report a positive integer started count" % route_id, path, run))
            route_totals_valid = False
        else:
            route_started_total += route_started
        if route_completed is None or route_completed < 0:
            issues.append(_issue("ROUTE_COMPLETED_MISSING", "route %s must report completed or arrived" % route_id, path, run))
            route_totals_valid = False
        elif route_started is not None and route_completed > route_started:
            issues.append(_issue("ROUTE_COMPLETION_INCONSISTENT", "route %s completed exceeds started" % route_id, path, run))
        else:
            route_completed_total += route_completed
        if route_arrived is None or route_arrived != route_completed:
            issues.append(_issue("ROUTE_ARRIVED_MISSING", "route %s arrived must be an integer equal to completed" % route_id, path, run))
            route_totals_valid = False
        if route_arrival_units is None or route_arrival_units < 0:
            issues.append(_issue("ROUTE_ARRIVAL_UNITS_MISSING", "route %s must report non-negative integer arrival units" % route_id, path, run))
            route_totals_valid = False
        else:
            route_arrival_units_total += route_arrival_units
            if route_completed is not None and route_arrival_units < route_completed:
                issues.append(_issue(
                    "ROUTE_ARRIVAL_UNITS_FLOOR",
                    "route %s arrival units must include at least one live unit per completion" % route_id,
                    path,
                    run,
                ))
            if (
                arm in ARMS
                and route_completed is not None
                and route_completed >= 0
                and route_arrival_units > route_completed * arm
            ):
                issues.append(_issue(
                    "ROUTE_ARRIVAL_UNITS_CAP",
                    "route %s arrival units exceed completed groups times unitsPerGroup" % route_id,
                    path,
                    run,
                ))
    if route_totals_valid and started is not None and route_started_total != started:
        issues.append(_issue("ROUTE_STARTED_TOTAL", "sum of per-route started counts must equal pathlegs.started", path, run))
    if route_totals_valid and completed is not None and route_completed_total != completed:
        issues.append(_issue("ROUTE_COMPLETED_TOTAL", "sum of per-route completed counts must equal pathlegs.completed", path, run))
    if route_totals_valid and arrival_units is not None and route_arrival_units_total != arrival_units:
        issues.append(_issue("ROUTE_ARRIVAL_UNITS_TOTAL", "sum of per-route arrival units must equal pathlegs.arrival_units", path, run))
    if (
        arm in ARMS
        and completed is not None
        and completed >= 0
        and arrival_units is not None
        and arrival_units > completed * arm
    ):
        issues.append(_issue(
            "ARRIVAL_UNITS_CAP",
            "pathlegs.arrival_units exceed completed groups times unitsPerGroup",
            path,
            run,
        ))
    if started is not None and completed is not None and completed > started:
        issues.append(_issue("PATHLEGS_INCONSISTENT", "completed path legs exceed started path legs", path, run))
    if started is not None and completed is not None and target_groups is not None:
        outstanding = started - completed
        if outstanding < (target_groups * 0.98) or outstanding > target_groups:
            issues.append(_issue("OUTSTANDING_LEGS", "started-completed must retain 98-100% of targetGroups as the active leg frontier", path, run))
    if completed is not None and completed < 1:
        issues.append(_issue("NO_ARRIVALS", "a PASS group-partition run must complete at least one path leg", path, run))

    barrier_problems = []
    phase_records = _field(phase, "records")
    phase_records = phase_records if isinstance(phase_records, list) else []
    expected_phases = ("SPAWN", "SETTLE", "GO", "MEASURE", "CLEANUP")
    parsed_phases = []
    for record in phase_records:
        fields = _field(record, "fields")
        fields = fields if isinstance(fields, dict) else {}
        parsed_phases.append(
            (
                str(_field(fields, "phase") or "").upper(),
                _integer(_field(record, "event_index")),
                _number(_field(fields, "t")),
                _number(_field(fields, "measureT")),
            )
        )
    if tuple(item[0] for item in parsed_phases) != expected_phases:
        barrier_problems.append("phase records are not the exact barrier sequence")
    elif any(item[1] is None or item[2] is None for item in parsed_phases):
        barrier_problems.append("phase records lack finite time/order evidence")
    else:
        phase_indices = [item[1] for item in parsed_phases]
        phase_times = dict((item[0], item[2]) for item in parsed_phases)
        phase_measure_times = dict((item[0], item[3]) for item in parsed_phases)
        if any(value <= 0 for value in phase_indices) or any(
            current <= previous
            for previous, current in zip(phase_indices, phase_indices[1:])
        ):
            barrier_problems.append("phase event indices are not strictly increasing")
        ordered_phase_times = [item[2] for item in parsed_phases]
        if any(
            current < previous
            for previous, current in zip(
                ordered_phase_times, ordered_phase_times[1:]
            )
        ):
            barrier_problems.append("phase elapsed times are not monotonic")
        settle_elapsed = phase_times["GO"] - phase_times["SETTLE"]
        if settle_sec is not None and (
            settle_elapsed < max(0.0, settle_sec - 1.0)
            or settle_elapsed > settle_sec + 2.0
        ):
            barrier_problems.append("SETTLE elapsed time differs from settleSec")
        measure_elapsed = phase_times["CLEANUP"] - phase_times["GO"]
        if duration is not None and (
            measure_elapsed < duration - 1.0
            or measure_elapsed > duration + monitor.MAX_PARTITION_DRAIN_SEC
        ):
            barrier_problems.append(
                "CLEANUP wall clock is outside duration plus bounded drain"
            )
        if phase_measure_times["GO"] is None or abs(phase_measure_times["GO"]) > 1.0:
            barrier_problems.append("GO phase measureT must be zero")
        measure_phase_elapsed = phase_times["MEASURE"] - phase_times["GO"]
        measure_phase_limit = _cadence_limit(sample_sec)
        if (
            phase_measure_times["MEASURE"] is None
            or measure_phase_elapsed < 0
            or abs(phase_measure_times["MEASURE"] - measure_phase_elapsed) > 1.0
            or measure_phase_limit is None
            or measure_phase_elapsed > measure_phase_limit
        ):
            barrier_problems.append(
                "MEASURE phase clock is not a bounded continuation of GO"
            )
        cleanup_measure_t = phase_measure_times["CLEANUP"]
        if (
            cleanup_measure_t is None
            or (duration is not None and abs(cleanup_measure_t - duration) > 2.0)
        ):
            barrier_problems.append(
                "CLEANUP measureT differs from configured duration"
            )

        realized_indices = _field(realized_evidence, "event_indices")
        normalized_realized_indices = (
            [_integer(value) for value in realized_indices]
            if isinstance(realized_indices, list)
            else None
        )
        if (
            normalized_realized_indices is None
            or target_groups is None
            or len(normalized_realized_indices) != target_groups
            or any(value is None for value in normalized_realized_indices)
            or any(
                current <= previous
                for previous, current in zip(
                    normalized_realized_indices,
                    normalized_realized_indices[1:],
                )
            )
            or any(
                value <= phase_indices[0] or value >= phase_indices[1]
                for value in normalized_realized_indices
            )
        ):
            barrier_problems.append("REALIZED records are not strictly between SPAWN and SETTLE")

        sample_indices = _field(sample_evidence, "event_indices")
        normalized_sample_indices = (
            [_integer(value) for value in sample_indices]
            if isinstance(sample_indices, list)
            else None
        )
        measurement_sample_count = _integer(
            _field(summary, "measurement_sample_count")
        )
        if (
            not isinstance(sample_indices, list)
            or measurement_sample_count is None
            or len(sample_indices) != measurement_sample_count
            or any(value is None for value in normalized_sample_indices or ())
            or any(
                current <= previous
                for previous, current in zip(
                    normalized_sample_indices or (),
                    (normalized_sample_indices or ())[1:],
                )
            )
            or any(
                value <= phase_indices[3]
                or value >= phase_indices[4]
                for value in normalized_sample_indices or ()
            )
        ):
            barrier_problems.append(
                "MEASURE samples are not bounded by MEASURE and CLEANUP"
            )
        sample_times = _field(sample_evidence, "sample_t_values")
        normalized_sample_times = (
            [_number(value) for value in sample_times]
            if isinstance(sample_times, list)
            else None
        )
        if (
            normalized_sample_times is None
            or measurement_sample_count is None
            or len(normalized_sample_times) != measurement_sample_count
            or any(value is None for value in normalized_sample_times)
            or any(
                value < phase_times["GO"] or value > phase_times["CLEANUP"]
                for value in normalized_sample_times
            )
        ):
            barrier_problems.append(
                "MEASURE sample clocks are outside GO..CLEANUP"
            )

        started_indices = _field(pathlegs, "started_event_indices")
        normalized_started_indices = (
            [_integer(value) for value in started_indices]
            if isinstance(started_indices, list)
            else None
        )
        if (
            not isinstance(started_indices, list)
            or target_groups is None
            or len(started_indices) < target_groups
            or any(value is None for value in normalized_started_indices or ())
            or any(
                current <= previous
                for previous, current in zip(
                    normalized_started_indices or (),
                    (normalized_started_indices or ())[1:],
                )
            )
            or any(
                value <= phase_indices[2]
                or value >= phase_indices[4]
                for value in normalized_started_indices or ()
            )
        ):
            barrier_problems.append(
                "PATHLEG starts are not bounded by GO and CLEANUP"
            )
        transition_records = _field(pathlegs, "transition_evidence")
        transition_indices = (
            [
                _integer(_field(record, "event_index"))
                if isinstance(record, dict)
                else None
                for record in transition_records
            ]
            if isinstance(transition_records, list)
            else None
        )
        event_lists = (
            phase_indices,
            normalized_realized_indices,
            normalized_sample_indices,
            transition_indices,
        )
        if any(values is None or any(value is None for value in values) for values in event_lists):
            barrier_problems.append(
                "phase, REALIZED, PATHLEG, and SAMPLE event indices are incomplete"
            )
        else:
            all_event_indices = []
            for values in event_lists:
                all_event_indices.extend(values)
            if (
                any(value <= 0 for value in all_event_indices)
                or len(all_event_indices) != len(set(all_event_indices))
            ):
                barrier_problems.append(
                    "phase, REALIZED, PATHLEG, and SAMPLE event indices are not globally unique"
                )
        phase_index_map = dict(zip(expected_phases, phase_indices))
        phase_time_map = dict((name, phase_times[name]) for name in expected_phases)
        transition_problems = _path_transition_problems(
            pathlegs, phase_index_map, phase_time_map, target_groups, arm, duration
        )
        if transition_problems:
            issues.append(_issue(
                "PATH_TRANSITION_INVALID",
                "; ".join(transition_problems),
                path,
                run,
            ))
    if barrier_problems:
        issues.append(_issue(
            "PARTITION_BARRIER",
            "; ".join(barrier_problems),
            path,
            run,
        ))
    if completed is not None and arrival_units is not None and arrival_units < completed:
        issues.append(_issue(
            "ARRIVAL_UNITS_FLOOR",
            "pathlegs.arrival_units must include at least one live unit per completion",
            path,
            run,
        ))

    cleanup = summary.get("cleanup")
    if not isinstance(cleanup, dict):
        issues.append(_issue("CLEANUP_MISSING", "summary.cleanup evidence is required", path, run))
    else:
        cleanup_objects = _number(_field(cleanup, "objects_remaining"))
        cleanup_groups = _number(_field(cleanup, "groups_remaining"))
        if cleanup_objects != 0:
            issues.append(_issue("CLEANUP_OBJECTS", "cleanup.objects_remaining must be present and equal zero", path, run))
        if cleanup_groups != 0:
            issues.append(_issue("CLEANUP_GROUPS", "cleanup.groups_remaining must be present and equal zero", path, run))

    if issues:
        return None, issues

    route_arrival_pct = 100.0 * completed / started
    return {
        "path": path,
        "summary": summary,
        "start": start,
        "run": str(run),
        "arm": arm,
        "target_groups": target_groups,
        "target_units": target_units,
        "spawn_anchors": spawn_anchors,
        "partition_id": partition_id,
        "member_seconds": member_seconds,
        "group_seconds": group_seconds,
        "measurement_seconds": measurement_seconds,
        "pathlegs_started": started,
        "pathlegs_completed": completed,
        "arrival_units": arrival_units,
        "route_count": route_count,
        "routes": routes,
        "probe_ms": {
            field: _number(_field(summary.get("probe_ms") or {}, field))
            for field in ("count", "median", "p95", "max")
        },
        "route_arrival_pct": route_arrival_pct,
        "arrivals_per_group_second": completed / group_seconds,
        "arrival_units_per_member_second": arrival_units / member_seconds,
    }, []


def _cross_run_issues(runs):
    issues = []
    if not runs:
        return issues
    seen_runs = set()
    for run in runs:
        if run["run"] in seen_runs:
            issues.append(_issue("DUPLICATE_RUN", "run ID %s was supplied more than once" % run["run"], run["path"], run["run"]))
        seen_runs.add(run["run"])

    starts = [run["start"] for run in runs]
    all_fields = set()
    for start in starts:
        all_fields.update(start.keys())
    for field in sorted(all_fields):
        if field in ALLOWED_START_DIFFERENCES or field in PARTITION_START_FIELDS:
            continue
        values = [_field(start, field) for start in starts]
        if any(value is None for value in values):
            issues.append(_issue("START_FIELD_MISSING", "START field %s is not present in every run" % field))
            continue
        reference = values[0]
        if any(not _same_value(reference, value) for value in values[1:]):
            issues.append(_issue("%s_MISMATCH" % field.upper(), "START field %s differs across arms" % field))

    for field in ("build", "config", "workload"):
        by_arm = {}
        for run in runs:
            by_arm.setdefault(run["arm"], []).append(_field(run["start"], field))
        for arm, values in by_arm.items():
            if any(value is None for value in values) or any(
                not _same_value(values[0], value) for value in values[1:]
            ):
                issues.append(_issue(
                    "%s_WITHIN_ARM_MISMATCH" % field.upper(),
                    "START field %s differs within arm %s repetitions" % (field, arm),
                ))

    targets = sorted(set(run["target_units"] for run in runs))
    if len(targets) != 1:
        issues.append(_issue("TARGET_UNITS_MISMATCH", "targetSyntheticUnits must be identical across every arm"))
    partition_ids = set(str(run["partition_id"]).lower() for run in runs)
    if len(partition_ids) != 1:
        issues.append(_issue("PARTITION_ID_MISMATCH", "partition identity differs across arms"))

    member_seconds = [run["member_seconds"] for run in runs]
    if member_seconds:
        spread_pct = 100.0 * (max(member_seconds) - min(member_seconds)) / min(member_seconds)
        if spread_pct > 3.0:
            issues.append(_issue("MEMBER_SECONDS_MISMATCH", "member-seconds spread %.3f%% exceeds 3%%" % spread_pct))
    measurement_seconds = [run["measurement_seconds"] for run in runs]
    sample_sec = _number(_field(runs[0]["start"], "sampleSec"))
    if measurement_seconds and sample_sec is not None:
        spread = max(measurement_seconds) - min(measurement_seconds)
        if spread > sample_sec:
            issues.append(_issue("MEASUREMENT_SECONDS_SPREAD", "cross-run measurement_seconds spread %s exceeds one sampleSec" % _trim_number(spread)))
    return issues


def _route_report(runs):
    collected = {}
    for run in runs:
        for route_id, values in run["routes"].items():
            if not isinstance(values, dict):
                continue
            item = collected.setdefault(str(route_id), {"records": [], "started": [], "completed": [], "units": [], "elapsed_median": [], "arrival_pct": []})
            started = _number(_field(values, "started"))
            completed = _number(_field(values, "completed"))
            if completed is None:
                completed = _number(_field(values, "arrived"))
            if started is not None:
                item["started"].append(started)
            if completed is not None:
                item["completed"].append(completed)
            if started is not None and started > 0 and completed is not None:
                item["arrival_pct"].append(100.0 * completed / started)
            for source, target in (
                ("records", "records"),
                ("units", "units"),
                ("elapsed_median", "elapsed_median"),
            ):
                number = _number(_field(values, source))
                if number is not None:
                    item[target].append(number)
    result = {}
    for route_id, values in sorted(collected.items()):
        result[route_id] = {
            "records": _distribution(values["records"]),
            "started": _distribution(values["started"]),
            "completed": _distribution(values["completed"]),
            "arrival_units": _distribution(values["units"]),
            "arrival_pct": _distribution(values["arrival_pct"]),
            "elapsed_median": _distribution(values["elapsed_median"]),
        }
    return result


def _arm_report(runs, minimum_repetitions):
    fps_metrics = {}
    for metric in ("median", "avg", "p5", "min"):
        fps_metrics[metric] = _distribution(
            [_field(run["summary"].get("fps") or {}, metric) for run in runs]
        )
    return {
        "repetitions": len(runs),
        "required_repetitions": minimum_repetitions,
        "sufficient": len(runs) >= minimum_repetitions,
        "runs": [
            {
                "run": run["run"],
                "path": run["path"],
                "target_groups": run["target_groups"],
                "target_units": run["target_units"],
                "member_seconds": _trim_number(run["member_seconds"]),
                "group_seconds": _trim_number(run["group_seconds"]),
                "route_arrival_pct": _trim_number(run["route_arrival_pct"]),
                "arrivals_per_group_second": _trim_number(run["arrivals_per_group_second"]),
                "arrival_units_per_member_second": _trim_number(run["arrival_units_per_member_second"]),
            }
            for run in runs
        ],
        "fps": fps_metrics,
        "probe_ms": {
            metric: _distribution([run["probe_ms"][metric] for run in runs])
            for metric in ("median", "p95", "max")
        },
        "work": {
            "member_seconds": _distribution([run["member_seconds"] for run in runs]),
            "group_seconds": _distribution([run["group_seconds"] for run in runs]),
            "measurement_seconds": _distribution([run["measurement_seconds"] for run in runs]),
        },
        "route_normalized": {
            "arrival_pct": _distribution([run["route_arrival_pct"] for run in runs]),
            "arrivals_per_group_second": _distribution([run["arrivals_per_group_second"] for run in runs]),
            "arrivals_per_1000_group_seconds": _distribution([1000.0 * run["arrivals_per_group_second"] for run in runs]),
            "arrival_units_per_member_second": _distribution([run["arrival_units_per_member_second"] for run in runs]),
            "arrival_units_per_1000_member_seconds": _distribution([1000.0 * run["arrival_units_per_member_second"] for run in runs]),
            "routes": _route_report(runs),
        },
    }


def aggregate_summaries(summaries, minimum_repetitions=DEFAULT_MIN_REPETITIONS):
    """Return a stable JSON-ready campaign report from monitor summaries."""
    if (
        not isinstance(minimum_repetitions, int)
        or isinstance(minimum_repetitions, bool)
        or minimum_repetitions < DEFAULT_MIN_REPETITIONS
    ):
        raise ValueError("minimum_repetitions must be an integer of at least 3")

    accepted = []
    rejected = []
    for index, entry in enumerate(summaries):
        if isinstance(entry, tuple) and len(entry) == 2:
            path, summary = entry
        else:
            path, summary = "<summary-%s>" % (index + 1), entry
        run, issues = _validate_run(summary, str(path))
        if issues:
            rejected.append({"path": str(path), "issues": issues})
        else:
            accepted.append(run)

    cross_issues = _cross_run_issues(accepted)
    by_arm = dict((arm, []) for arm in ARMS)
    for run in accepted:
        by_arm[run["arm"]].append(run)
    arms = dict((str(arm), _arm_report(by_arm[arm], minimum_repetitions)) for arm in ARMS)
    insufficient = [arm for arm in ARMS if len(by_arm[arm]) < minimum_repetitions]

    if rejected or cross_issues:
        status = "INVALID"
        claim = "invalid_equal_work_comparison"
    elif insufficient:
        status = "INSUFFICIENT"
        claim = "insufficient_repetitions_no_performance_claim"
    else:
        status = "READY"
        claim = "screening_dataset_ready_no_automatic_winner"

    member_seconds = [run["member_seconds"] for run in accepted]
    spread_pct = None
    if member_seconds:
        spread_pct = 100.0 * (max(member_seconds) - min(member_seconds)) / min(member_seconds)
    targets = sorted(set(run["target_units"] for run in accepted))
    identity = {}
    if accepted:
        first = accepted[0]["start"]
        for field in ("git", "source", "lab", "map", "duration", "sampleSec", "warmupSec", "settleSec", "spawnAnchors", "batchInterval", "vehicleEvery", "mode", "expectedHcs", "paramSig", "baselineAi", "baselineGroups", "baselineVehicles", "performanceAudit"):
            identity[field] = _field(first, field)
        identity["partition"] = _partition_start_value(first)

    return {
        "protocol": PROTOCOL,
        "status": status,
        "ok": status == "READY",
        "claim": claim,
        "required_arms": list(ARMS),
        "minimum_repetitions": minimum_repetitions,
        "input_count": len(summaries),
        "accepted_count": len(accepted),
        "rejected_count": len(rejected),
        "insufficient_arms": insufficient,
        "target_synthetic_units": targets[0] if len(targets) == 1 else None,
        "member_seconds_spread_pct": _trim_number(spread_pct),
        "identity": identity,
        "arms": arms,
        "rejected_runs": rejected,
        "comparison_issues": cross_issues,
        "limits": [
            "server-local synthetic Utes workload",
            "READY means repetition/equal-work gates passed; it does not select a production group size",
        ],
    }


def aggregate_files(paths, minimum_repetitions=DEFAULT_MIN_REPETITIONS):
    return aggregate_summaries(
        [(os.path.abspath(path), load_summary(path)) for path in paths],
        minimum_repetitions=minimum_repetitions,
    )


def format_human(report):
    lines = [
        "WASPLAB group-partition status=%s accepted=%s/%s target=%s"
        % (report["status"], report["accepted_count"], report["input_count"], report["target_synthetic_units"] or "?"),
        "  %s" % report["claim"],
    ]
    for arm in ARMS:
        data = report["arms"][str(arm)]
        fps = data["fps"]
        outcomes = data["route_normalized"]
        lines.append(
            "  arm=%2s reps=%s/%s fps-median=%s fps-p5=%s fps-min=%s route-arrival=%s%% /1000-group-s=%s /1000-member-s=%s"
            % (
                arm,
                data["repetitions"],
                data["required_repetitions"],
                fps["median"]["median"],
                fps["p5"]["median"],
                fps["min"]["median"],
                outcomes["arrival_pct"]["median"],
                outcomes["arrivals_per_1000_group_seconds"]["median"],
                outcomes["arrival_units_per_1000_member_seconds"]["median"],
            )
        )
    if report["insufficient_arms"]:
        lines.append("  INSUFFICIENT arms: %s" % ", ".join(str(arm) for arm in report["insufficient_arms"]))
    for issue in report["comparison_issues"]:
        lines.append("  INVALID %s: %s" % (issue["code"], issue["message"]))
    for rejected in report["rejected_runs"]:
        codes = ",".join(issue["code"] for issue in rejected["issues"])
        lines.append("  REJECT %s: %s" % (rejected["path"], codes))
    return "\n".join(lines)


def _expand_inputs(values):
    paths = []
    for value in values:
        matches = glob.glob(value) if glob.has_magic(value) else [value]
        if not matches:
            raise ValueError("input pattern matched no files: %s" % value)
        for match in matches:
            if os.path.isdir(match):
                for name in sorted(os.listdir(match)):
                    candidate = os.path.join(match, name)
                    if os.path.isfile(candidate) and name.lower().endswith((".rpt", ".json")):
                        paths.append(candidate)
            else:
                paths.append(match)
    unique = []
    seen = set()
    for path in paths:
        absolute = os.path.abspath(path)
        if absolute not in seen:
            seen.add(absolute)
            unique.append(absolute)
    return unique


def build_parser():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("inputs", nargs="+", help="server RPTs, monitor summary JSON files, directories or glob patterns")
    parser.add_argument("--min-repetitions", type=int, default=DEFAULT_MIN_REPETITIONS, help="valid repetitions required for every 4/6/8/10/12 arm; may raise but not lower the 3-run floor")
    parser.add_argument("--json", action="store_true", help="emit JSON")
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    try:
        paths = _expand_inputs(args.inputs)
        if not paths:
            raise ValueError("no RPT or JSON inputs found")
        for path in paths:
            if not os.path.isfile(path):
                raise ValueError("input not found: %s" % path)
        report = aggregate_files(paths, minimum_repetitions=args.min_repetitions)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print("ABORT: %s" % exc, file=sys.stderr)
        return 2
    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        print(format_human(report))
    return 0 if report["ok"] else 2


if __name__ == "__main__":
    sys.exit(main())
