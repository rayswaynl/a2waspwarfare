import contextlib
import copy
import importlib.util
import io
import json
import statistics
import sys
import tempfile
import unittest
from unittest import mock
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("wasp_lab_group_partition", ROOT / "group_partition.py")
assert SPEC and SPEC.loader
group_partition = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = group_partition
SPEC.loader.exec_module(group_partition)


BATCH_GROUPS = {4: 5, 6: 4, 8: 3, 10: 2, 12: 2}


def make_summary(arm, repetition, target_units=240, member_seconds=None):
    target_groups = target_units // arm
    anchors = target_units // 120
    run = "density-%s-rep-%s-%s" % (arm, repetition, target_units)
    member_seconds = member_seconds if member_seconds is not None else target_units * 900
    group_seconds = target_groups * 900
    route_names = ("Strelka>Airfield", "Airfield>Kamenyy", "Kamenyy>Strelka")
    fps_min = 29 + (arm / 10.0) + repetition
    fps_avg = 39 + (arm / 10.0) + repetition
    fps_rest = ((fps_avg * 60) - fps_min) / 59
    fps_values = [fps_min] + ([fps_rest] * 59)
    started = target_groups * len(route_names)
    completed = target_groups * 2
    route_records = target_groups
    anchor_requested = dict((str(index), 120) for index in range(anchors))
    spawn_event = 1
    realized_event_indices = list(range(2, target_groups + 2))
    settle_event = target_groups + 2
    go_event = target_groups + 3
    path_started_event_indices = list(
        range(target_groups + 4, (2 * target_groups) + 4)
    )
    measure_event = (2 * target_groups) + 4
    sample_event_indices = list(range(measure_event + 1, measure_event + 61))
    transition_evidence = []
    for group_id, event_index in enumerate(path_started_event_indices, 1):
        route_id = route_names[0]
        transition_evidence.append(
            {
                "group": group_id,
                "transition": 1,
                "status": "STARTED",
                "event_index": event_index,
                "units": arm,
                "route_id": route_id,
                "t": 360,
                "measure_t": 0,
                "elapsed": 0,
            }
        )
    next_event = measure_event + 1
    for group_id in range(1, target_groups + 1):
        for transition, status in (
            (1, "ARRIVED"),
            (2, "STARTED"),
            (2, "ARRIVED"),
            (3, "STARTED"),
        ):
            route_id = route_names[transition - 1]
            transition_evidence.append(
                {
                    "group": group_id,
                    "transition": transition,
                    "status": status,
                    "event_index": next_event,
                    "units": arm,
                    "route_id": route_id,
                    "t": 375,
                    "measure_t": 15,
                    "elapsed": (
                        0 if status == "STARTED" else 15 if transition == 1 else 0
                    ),
                }
            )
            next_event += 1
    path_started_event_indices = [
        record["event_index"]
        for record in transition_evidence
        if record["status"] == "STARTED"
    ]
    sample_event_indices = list(range(next_event, next_event + 60))
    cleanup_event = sample_event_indices[-1] + 1
    routes = {}
    for index, route_name in enumerate(route_names):
        route_completed = route_records if index < 2 else 0
        routes[route_name] = {
            "records": route_records + route_completed,
            "started": route_records,
            "completed": route_completed,
            "status": {"STARTED": route_records, "ARRIVED": route_completed},
            "arrived": route_completed,
            "units": target_units if route_completed > 0 else 0,
            "elapsed_median": (
                15 if index == 0 else 0 if index == 1 else None
            ),
        }
    start = {
        "run": run,
        "scenario": "density-%s" % arm,
        "map": "utes",
        "build": "wasplab-density-%s" % arm,
        "git": "abc1234",
        "source": "1111111111111111",
        "lab": "2222222222222222",
        "config": "%016x" % arm,
        "workload": "%016x" % (100 + arm),
        "partition": "ffffffffffffffff",
        "variant": "control",
        "seed": "engine",
        "duration": 900,
        "sampleSec": 15,
        "warmupSec": 300,
        "settleSec": 60,
        "mode": "path-loop",
        "targetGroups": target_groups,
        "targetSyntheticUnits": target_units,
        "unitsPerGroup": arm,
        "spawnAnchors": anchors,
        "batchGroups": BATCH_GROUPS[arm],
        "batchInterval": 20,
        "vehicleEvery": 0,
        "busRate": 0,
        "expectedHcs": 0,
        "minHcFps": 25,
        "schedulerMode": "off",
        "paramSig": 12345,
        "towns": 3,
        "baselineAi": 8,
        "baselineGroups": 6,
        "baselineVehicles": 4,
        "performanceAudit": False,
    }
    return {
        "protocol": "WASPLAB|v1",
        "found": True,
        "run": run,
        "start": start,
        "measurement_sample_count": 60,
        "expected_sample_count": 60,
        "ok": True,
        "alerts": [],
        "fatal_signatures": [],
        "fps": {
            "median": fps_rest,
            "avg": fps_avg,
            "p5": fps_rest,
            "min": fps_min,
        },
        "phase": {
            "sequence": ["SPAWN", "SETTLE", "GO", "MEASURE", "CLEANUP"],
            "measurement_started_phase": "GO",
            "measurement_seconds": 900,
            "records": [
                {"fields": {"phase": "SPAWN", "t": 0}, "event_index": spawn_event},
                {"fields": {"phase": "SETTLE", "t": 300}, "event_index": settle_event},
                {"fields": {"phase": "GO", "t": 360, "measureT": 0}, "event_index": go_event},
                {"fields": {"phase": "MEASURE", "t": 360, "measureT": 0}, "event_index": measure_event},
                {"fields": {"phase": "CLEANUP", "t": 1260, "measureT": 900}, "event_index": cleanup_event},
            ],
        },
        "ai_peak": target_units,
        "groups_peak": target_groups,
        "probe_ms": {
            "count": 60,
            "median": 0.5,
            "p95": 0.5,
            "max": 0.5,
        },
        "composition": {
            "target_synthetic_units": target_units,
            "target_groups": target_groups,
            "spawn_anchors": anchors,
            "anchor_requested": anchor_requested,
            "anchor_members": dict(anchor_requested),
            "realized_groups": target_groups,
            "requested_infantry": target_units,
            "created_infantry": target_units,
            "crew": 0,
            "vehicles": 0,
            "final_members": target_units,
            "final_groups": target_groups,
            "realized_record_count": target_groups,
            "histogram": {str(arm): target_groups},
            "underfill_groups": 0,
            "oversize_groups": 0,
            "create_failures": 0,
            "create_failure_groups": 0,
            "attainment_pct": 100,
            "realized_evidence": {
                "record_count": target_groups,
                "valid_count": target_groups,
                "group_ids": list(range(1, target_groups + 1)),
                "requested_infantry": target_units,
                "created_infantry": target_units,
                "crew": 0,
                "vehicles": 0,
                "final_members": target_units,
                "underfill_groups": 0,
                "oversize_groups": 0,
                "create_failures": 0,
                "create_failure_groups": 0,
                "histogram": {str(arm): target_groups},
                "anchor_requested": dict(anchor_requested),
                "anchor_members": dict(anchor_requested),
                "event_indices": realized_event_indices,
            },
        },
        "work": {
            "member_seconds": member_seconds,
            "group_seconds": group_seconds,
            "measurement_seconds": 900,
            "average_members": target_units,
            "average_groups": target_groups,
            "sample_evidence": {
                "record_count": 60,
                "fps_count": 60,
                "fps_values": fps_values,
                "ai_count": 60,
                "ai_values": [target_units] * 60,
                "groups_count": 60,
                "groups_values": [target_groups] * 60,
                "probe_ms_count": 60,
                "probe_ms_values": [0.5] * 60,
                "member_seconds_count": 60,
                "group_seconds_count": 60,
                "measure_t_count": 60,
                "measure_t_values": list(range(15, 901, 15)),
                "sample_t_count": 60,
                "sample_t_values": list(range(375, 1261, 15)),
                "latest_measure_t": 900,
                "measure_t_monotonic": True,
                "measure_t_unique_count": 60,
                "measure_t_in_bounds": True,
                "terminal_progress_ok": True,
                "event_indices": sample_event_indices,
                "member_seconds_values": [target_units * value for value in range(15, 901, 15)],
                "group_seconds_values": [target_groups * value for value in range(15, 901, 15)],
                "latest_member_seconds": member_seconds,
                "latest_group_seconds": group_seconds,
                "member_seconds_monotonic": True,
                "group_seconds_monotonic": True,
            },
        },
        "pathlegs": {
            "count": started + completed,
            "status": {"STARTED": started, "ARRIVED": completed},
            "started": started,
            "completed": completed,
            "completion_pct": round(100.0 * completed / started, 3),
            "arrivals": completed,
            "arrival_units": target_units * 2,
            "arrival_pct": round(100.0 * completed / started, 3),
            "route_identity": "two-fixed-routes",
            "route_ids": list(routes),
            "route_count": len(routes),
            "routes": routes,
            "started_event_indices": path_started_event_indices,
            "transition_evidence": transition_evidence,
        },
        "cleanup": {"objects_remaining": 0, "groups_remaining": 0},
        "result": {
            "run": run,
            "status": "PASS",
            "complete": 1,
            "measureT": 900,
            "measureDuration": 900,
            "fpsMin": fps_min,
            "fpsAvg": fps_avg,
            "fpsSamples": 60,
            "fpsExpected": 60,
            "fpsCoveragePct": 100,
            "aiPeak": target_units,
            "groupsPeak": target_groups,
            "targetSyntheticUnits": target_units,
            "targetGroups": target_groups,
            "spawnAnchors": anchors,
            "realizedGroups": target_groups,
            "requestedInfantry": target_units,
            "createdInfantry": target_units,
            "crew": 0,
            "createdVehicles": 0,
            "finalMembers": target_units,
            "histogram": {str(arm): target_groups},
            "underfillGroups": 0,
            "oversizeGroups": 0,
            "createFailures": 0,
            "createFailureGroups": 0,
            "anchorRequested": dict(anchor_requested),
            "anchorMembers": dict(anchor_requested),
            "memberSeconds": member_seconds,
            "groupSeconds": group_seconds,
            "pathLegsStarted": started,
        },
    }


def sync_sample_evidence(summary):
    evidence = summary["work"]["sample_evidence"]
    measure_values = evidence["measure_t_values"]
    duration = summary["work"]["measurement_seconds"]
    for work_field, values_field, latest_field, result_field in (
        ("member_seconds", "member_seconds_values", "latest_member_seconds", "memberSeconds"),
        ("group_seconds", "group_seconds_values", "latest_group_seconds", "groupSeconds"),
    ):
        total = summary["work"][work_field]
        evidence[values_field] = [total * value / duration for value in measure_values]
        evidence[latest_field] = total
        summary["result"][result_field] = total


def sync_result_work(summary):
    summary["result"]["memberSeconds"] = summary["work"]["member_seconds"]
    summary["result"]["groupSeconds"] = summary["work"]["group_seconds"]


def campaign(repetitions=3):
    return [
        ("arm-%s-rep-%s.rpt" % (arm, repetition), make_summary(arm, repetition))
        for arm in group_partition.ARMS
        for repetition in range(1, repetitions + 1)
    ]


class GroupPartitionTests(unittest.TestCase):
    def test_minimum_repetitions_cannot_weaken_three_run_floor(self):
        for minimum in (1, 2):
            with self.subTest(minimum=minimum):
                with self.assertRaisesRegex(ValueError, "at least 3"):
                    group_partition.aggregate_summaries([], minimum_repetitions=minimum)

        report = group_partition.aggregate_summaries([], minimum_repetitions=4)
        self.assertEqual(4, report["minimum_repetitions"])

    def test_cli_rejects_minimum_repetitions_below_three(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "summary.json"
            path.write_text(json.dumps({}), encoding="utf-8")
            stderr = io.StringIO()
            stdout = io.StringIO()
            with contextlib.redirect_stderr(stderr), contextlib.redirect_stdout(stdout):
                result = group_partition.main([str(path), "--min-repetitions", "2", "--json"])
        self.assertEqual(2, result)
        self.assertIn("at least 3", stderr.getvalue())

    def test_three_valid_repetitions_per_arm_are_ready(self):
        report = group_partition.aggregate_summaries(campaign())
        self.assertEqual("READY", report["status"])
        self.assertTrue(report["ok"])
        self.assertEqual(15, report["accepted_count"])
        self.assertEqual([], report["insufficient_arms"])
        self.assertEqual(240, report["target_synthetic_units"])
        self.assertEqual(0, report["member_seconds_spread_pct"])
        arm = report["arms"]["8"]
        self.assertEqual(3, arm["fps"]["median"]["n"])
        self.assertEqual(66.666667, arm["route_normalized"]["arrival_pct"]["median"])
        self.assertGreater(arm["route_normalized"]["arrivals_per_1000_group_seconds"]["median"], 0)
        self.assertIn("Strelka>Airfield", arm["route_normalized"]["routes"])
        self.assertEqual(0.5, arm["probe_ms"]["median"]["median"])
        self.assertEqual(0.5, arm["probe_ms"]["max"]["max"])

    def test_one_repetition_is_labeled_insufficient(self):
        report = group_partition.aggregate_summaries(campaign(repetitions=1))
        self.assertEqual("INSUFFICIENT", report["status"])
        self.assertFalse(report["ok"])
        self.assertEqual(list(group_partition.ARMS), report["insufficient_arms"])
        self.assertIn("no_performance_claim", report["claim"])

    def test_one_anchor_120_unit_campaign_is_invalid(self):
        inputs = [
            ("arm-%s-rep-%s-120.rpt" % (arm, repetition), make_summary(arm, repetition, 120))
            for arm in group_partition.ARMS
            for repetition in range(1, 4)
        ]
        report = group_partition.aggregate_summaries(inputs)
        codes = {
            issue["code"]
            for rejected in report["rejected_runs"]
            for issue in rejected["issues"]
        }
        self.assertEqual("INVALID", report["status"])
        self.assertEqual(0, report["accepted_count"])
        self.assertIn("PARTITION_TARGET_UNSUPPORTED", codes)

    def test_campaign_requires_the_exact_utes_three_town_topology(self):
        for field, value, code in (
            ("map", "chernarus", "MAP_RECIPE"),
            ("towns", 2, "TOWNS_RECIPE"),
        ):
            with self.subTest(field=field):
                summary = make_summary(4, 1)
                summary["start"][field] = value
                report = group_partition.aggregate_summaries(
                    [summary], minimum_repetitions=3
                )
                codes = {
                    issue["code"]
                    for rejected in report["rejected_runs"]
                    for issue in rejected["issues"]
                }
                self.assertIn(code, codes)
                self.assertEqual(0, report["accepted_count"])

    def test_cleanup_evidence_must_be_present_and_zero(self):
        cases = {
            "CLEANUP_MISSING": lambda summary: summary.pop("cleanup"),
            "CLEANUP_OBJECTS": lambda summary: summary["cleanup"].pop("objects_remaining"),
            "CLEANUP_GROUPS": lambda summary: summary["cleanup"].update(groups_remaining=-1),
        }
        for expected_code, mutate in cases.items():
            with self.subTest(expected_code=expected_code):
                summary = make_summary(4, 1)
                mutate(summary)
                report = group_partition.aggregate_summaries([summary], minimum_repetitions=3)
                codes = [
                    issue["code"]
                    for rejected in report["rejected_runs"]
                    for issue in rejected["issues"]
                ]
                self.assertIn(expected_code, codes)

    def test_non_finite_numeric_evidence_is_rejected(self):
        for value in (float("nan"), float("inf"), float("-inf"), 10**400):
            with self.subTest(value=value):
                summary = make_summary(4, 1)
                summary["fps"]["median"] = value
                report = group_partition.aggregate_summaries([summary], minimum_repetitions=3)
                codes = [
                    issue["code"]
                    for rejected in report["rejected_runs"]
                    for issue in rejected["issues"]
                ]
                self.assertIn("MEDIAN_MISSING", codes)

    def test_anchor_maps_require_exact_normalized_indices(self):
        cases = {
            "ANCHOR_REQUESTED_KEYS": lambda summary: summary["composition"].update(
                anchor_requested={"1": 120, "2": 120}
            ),
            "ANCHOR_MEMBERS_KEYS": lambda summary: summary["composition"].update(
                anchor_members={"0": 120, "2": 120}
            ),
        }
        for expected_code, mutate in cases.items():
            with self.subTest(expected_code=expected_code):
                summary = make_summary(4, 1)
                mutate(summary)
                report = group_partition.aggregate_summaries([summary], minimum_repetitions=3)
                codes = [
                    issue["code"]
                    for rejected in report["rejected_runs"]
                    for issue in rejected["issues"]
                ]
                self.assertIn(expected_code, codes)

    def test_finite_extreme_fps_is_rejected_before_distribution(self):
        inputs = campaign()
        for _, summary in inputs:
            for field in ("median", "avg", "min", "p5"):
                summary["fps"][field] = 1e308

        report = group_partition.aggregate_summaries(inputs)

        self.assertNotEqual("READY", report["status"])
        self.assertIn(
            "MEDIAN_RANGE",
            [
                issue["code"]
                for rejected in report["rejected_runs"]
                for issue in rejected["issues"]
            ],
        )
        json.dumps(report, allow_nan=False)

    def test_unsupported_anchor_count_does_not_expand_dynamic_key_range(self):
        summary = make_summary(4, 1)
        summary["start"]["spawnAnchors"] = 10**12
        summary["composition"]["spawn_anchors"] = 10**12
        with mock.patch.object(
            group_partition,
            "range",
            side_effect=AssertionError("validator must not expand an input-sized range"),
            create=True,
        ):
            report = group_partition.aggregate_summaries([summary], minimum_repetitions=3)
        codes = [
            issue["code"]
            for rejected in report["rejected_runs"]
            for issue in rejected["issues"]
        ]
        self.assertEqual(0, report["accepted_count"])
        self.assertIn("ANCHOR_LIMIT", codes)

    def test_untrusted_target_group_count_does_not_expand_dynamic_key_range(self):
        summary = make_summary(4, 1)
        summary["start"]["targetGroups"] = 10**12
        summary["composition"]["target_groups"] = 10**12
        summary["result"]["targetGroups"] = 10**12
        with mock.patch.object(
            group_partition,
            "range",
            side_effect=AssertionError("validator must not expand an input-sized range"),
            create=True,
        ):
            report = group_partition.aggregate_summaries([summary], minimum_repetitions=3)
        codes = [
            issue["code"]
            for rejected in report["rejected_runs"]
            for issue in rejected["issues"]
        ]
        self.assertEqual(0, report["accepted_count"])
        self.assertIn("TARGETGROUPS_RANGE", codes)

    def test_config_relevant_start_mismatch_is_invalid(self):
        inputs = campaign()
        inputs[0][1]["start"]["duration"] = 901
        report = group_partition.aggregate_summaries(inputs)
        self.assertEqual("INVALID", report["status"])
        self.assertIn("DURATION_MISMATCH", [issue["code"] for issue in report["comparison_issues"]])

    def test_build_config_and_workload_are_stable_within_each_arm(self):
        for field in ("build", "config", "workload"):
            with self.subTest(field=field):
                inputs = campaign()
                inputs[0][1]["start"][field] = (
                    "different"
                    if field == "build"
                    else "eeeeeeeeeeeeeeee"
                )

                report = group_partition.aggregate_summaries(inputs)

                self.assertEqual("INVALID", report["status"])
                self.assertIn(
                    "%s_WITHIN_ARM_MISMATCH" % field.upper(),
                    [issue["code"] for issue in report["comparison_issues"]],
                )

    def test_run_aliases_match_the_monitor_contract(self):
        summary = make_summary(4, 1)
        summary["start"]["runId"] = summary["start"].pop("run")
        summary["result"]["runId"] = summary["result"].pop("run")

        _, issues = group_partition._validate_run(summary, "alias.json")

        self.assertNotIn("RUN_MISSING", [issue["code"] for issue in issues])
        self.assertNotIn("RUN_ID_MISMATCH", [issue["code"] for issue in issues])

    def test_contradictory_start_and_result_run_aliases_are_rejected(self):
        for section, alias in (
            ("start", "runId"),
            ("start", "id"),
            ("result", "runId"),
            ("result", "id"),
        ):
            with self.subTest(section=section, alias=alias):
                summary = make_summary(4, 1)
                summary[section][alias] = "OTHER"

                _, issues = group_partition._validate_run(summary, "alias-conflict.json")

                self.assertIn(
                    "%s_RUN_ALIAS_CONFLICT" % section.upper(),
                    [issue["code"] for issue in issues],
                )

    def test_top_level_summary_run_must_match_start_identity(self):
        summary = make_summary(4, 1)
        summary["run"] = "OTHER"

        _, issues = group_partition._validate_run(summary, "summary-run-conflict.json")

        self.assertIn(
            "SUMMARY_RUN_ID_MISMATCH",
            [issue["code"] for issue in issues],
        )

        del summary["run"]
        _, issues = group_partition._validate_run(summary, "summary-run-missing.json")
        self.assertIn(
            "SUMMARY_RUN_ID_MISSING",
            [issue["code"] for issue in issues],
        )

    def test_contradictory_partition_aliases_are_rejected(self):
        summary = make_summary(4, 1)
        summary["start"]["partitionId"] = "OTHER"

        _, issues = group_partition._validate_run(summary, "partition-alias.json")

        self.assertIn(
            "PARTITION_ALIAS_CONFLICT",
            [issue["code"] for issue in issues],
        )

        summary["start"]["partitionId"] = summary["start"]["partition"]
        _, issues = group_partition._validate_run(
            summary, "consistent-partition-alias.json"
        )
        self.assertNotIn(
            "PARTITION_ALIAS_CONFLICT",
            [issue["code"] for issue in issues],
        )

    def test_provenance_tokens_must_be_present_and_hash_shaped(self):
        cases = (
            ("BUILD_INVALID", "build", "unknown"),
            ("GIT_INVALID", "git", "unknown"),
            ("SOURCE_INVALID", "source", "source-id"),
            ("LAB_INVALID", "lab", ""),
            ("CONFIG_INVALID", "config", "unknown"),
            ("WORKLOAD_INVALID", "workload", "not-a-digest"),
            ("PARTITION_INVALID", "partition", "unknown"),
            ("SOURCE_INVALID", "source", 1111111111111111),
        )
        for expected, field, value in cases:
            with self.subTest(field=field, value=value):
                summary = make_summary(4, 1)
                summary["start"][field] = value

                _, issues = group_partition._validate_run(
                    summary, "%s-invalid.json" % field
                )

                self.assertIn(
                    expected,
                    [issue["code"] for issue in issues],
                )

        dirty = make_summary(4, 1)
        dirty["start"]["git"] = "abc1234-dirty"
        _, issues = group_partition._validate_run(dirty, "builder-dirty-sha.json")
        self.assertNotIn(
            "GIT_INVALID",
            [issue["code"] for issue in issues],
        )

    def test_start_numeric_evidence_must_be_finite_and_in_range(self):
        cases = {
            "DURATION_MISSING": ("duration", "bogus"),
            "DURATION_RANGE": ("duration", 59),
            "SAMPLESEC_MISSING": ("sampleSec", "bogus"),
            "SAMPLESEC_RANGE": ("sampleSec", 301),
            "WARMUPSEC_MISSING": ("warmupSec", "bogus"),
            "WARMUPSEC_RANGE": ("warmupSec", 3601),
            "SETTLESEC_MISSING": ("settleSec", "bogus"),
            "SETTLESEC_RANGE": ("settleSec", 601),
            "BUSRATE_MISSING": ("busRate", "bogus"),
            "BUSRATE_RANGE": ("busRate", -1),
            "MINHCFPS_MISSING": ("minHcFps", "bogus"),
            "MINHCFPS_RANGE": ("minHcFps", 61),
            "TARGETGROUPS_MISSING": ("targetGroups", "bogus"),
            "TARGETSYNTHETICUNITS_MISSING": ("targetSyntheticUnits", "bogus"),
            "SPAWNANCHORS_MISSING": ("spawnAnchors", "bogus"),
            "BASELINEAI_MISSING": ("baselineAi", "bogus"),
            "BASELINEGROUPS_RANGE": ("baselineGroups", -1),
            "BASELINEVEHICLES_MISSING": ("baselineVehicles", "bogus"),
            "TOWNS_RANGE": ("towns", 0),
            "PARAMSIG_MISSING": ("paramSig", "bogus"),
        }
        for expected_code, (field, value) in cases.items():
            with self.subTest(expected_code=expected_code):
                summary = make_summary(4, 1)
                summary["start"][field] = value
                report = group_partition.aggregate_summaries([summary], minimum_repetitions=3)
                codes = [
                    issue["code"]
                    for rejected in report["rejected_runs"]
                    for issue in rejected["issues"]
                ]
                self.assertIn(expected_code, codes)

    def test_batch_groups_must_match_registered_arm_recipe(self):
        summary = make_summary(4, 1)
        summary["start"]["batchGroups"] = -1
        report = group_partition.aggregate_summaries([summary], minimum_repetitions=3)
        codes = [
            issue["code"]
            for rejected in report["rejected_runs"]
            for issue in rejected["issues"]
        ]
        self.assertIn("BATCH_GROUPS_RECIPE", codes)

    def test_registered_partition_rejects_coupled_bus_or_scheduler_work(self):
        mutations = {
            "BUS_RECIPE": lambda summary: summary["start"].update(busRate=1),
            "SCHEDULER_RECIPE": lambda summary: summary["start"].update(
                schedulerMode="active"
            ),
        }
        for expected_code, mutate in mutations.items():
            with self.subTest(expected_code=expected_code):
                summary = make_summary(4, 1)
                mutate(summary)
                report = group_partition.aggregate_summaries(
                    [summary], minimum_repetitions=3
                )
                codes = [
                    issue["code"]
                    for rejected in report["rejected_runs"]
                    for issue in rejected["issues"]
                ]
                self.assertIn(expected_code, codes)

    def test_registered_360_unit_campaign_is_ready(self):
        inputs = [
            ("arm-%s-rep-%s-360.rpt" % (arm, repetition), make_summary(arm, repetition, 360))
            for arm in group_partition.ARMS
            for repetition in range(1, 4)
        ]
        report = group_partition.aggregate_summaries(inputs)
        self.assertEqual("READY", report["status"])
        self.assertEqual(15, report["accepted_count"])

    def test_partition_identity_is_required_and_must_match(self):
        missing = make_summary(4, 1)
        missing["start"].pop("partition")
        report = group_partition.aggregate_summaries([missing], minimum_repetitions=3)
        codes = [issue["code"] for rejected in report["rejected_runs"] for issue in rejected["issues"]]
        self.assertIn("PARTITION_MISSING", codes)

        inputs = campaign()
        inputs[0][1]["start"]["partition"] = "eeeeeeeeeeeeeeee"
        report = group_partition.aggregate_summaries(inputs)
        self.assertEqual("INVALID", report["status"])
        self.assertIn("PARTITION_ID_MISMATCH", [issue["code"] for issue in report["comparison_issues"]])

    def test_phase_sequence_and_go_boundary_are_required(self):
        summary = make_summary(4, 1)
        summary["phase"]["sequence"] = ["SPAWN", "GO", "MEASURE", "CLEANUP"]
        summary["phase"]["measurement_started_phase"] = "MEASURE"
        report = group_partition.aggregate_summaries([summary], minimum_repetitions=3)
        codes = [issue["code"] for rejected in report["rejected_runs"] for issue in rejected["issues"]]
        self.assertIn("PHASE_SEQUENCE", codes)
        self.assertIn("MEASUREMENT_START_PHASE", codes)

    def test_protocol_and_per_group_realized_evidence_are_required(self):
        mutations = {
            "PROTOCOL_MISMATCH": lambda summary: summary.update(protocol="NOT-WASPLAB"),
            "REALIZED_RECORD_COUNT": lambda summary: summary["composition"].update(realized_record_count=0),
        }
        for expected_code, mutate in mutations.items():
            with self.subTest(expected_code=expected_code):
                summary = make_summary(4, 1)
                mutate(summary)
                report = group_partition.aggregate_summaries([summary], minimum_repetitions=3)
                codes = [issue["code"] for rejected in report["rejected_runs"] for issue in rejected["issues"]]
                self.assertIn(expected_code, codes)

    def test_realized_rows_must_reconcile_with_cumulative_composition(self):
        mutations = {
            "REALIZED_EVIDENCE_MISSING": lambda summary: summary["composition"].pop(
                "realized_evidence"
            ),
            "REALIZED_EVIDENCE_RECORD_COUNT": lambda summary: summary[
                "composition"
            ]["realized_evidence"].update(record_count=59),
            "REALIZED_EVIDENCE_VALID_COUNT": lambda summary: summary[
                "composition"
            ]["realized_evidence"].update(valid_count=59),
            "REALIZED_EVIDENCE_GROUP_IDS": lambda summary: summary["composition"][
                "realized_evidence"
            ].update(group_ids=list(range(1, 60)) + [59]),
            "REALIZED_EVIDENCE_REQUESTED_INFANTRY": lambda summary: summary[
                "composition"
            ]["realized_evidence"].update(requested_infantry=239),
            "REALIZED_EVIDENCE_HISTOGRAM": lambda summary: summary["composition"][
                "realized_evidence"
            ].update(histogram={"4": 59, "5": 1}),
            "REALIZED_EVIDENCE_ANCHOR_REQUESTED": lambda summary: summary[
                "composition"
            ]["realized_evidence"].update(anchor_requested={"0": 119, "1": 120}),
            "REALIZED_EVIDENCE_ANCHOR_MEMBERS": lambda summary: summary[
                "composition"
            ]["realized_evidence"].update(anchor_members={"0": 120, "1": 119}),
        }
        for expected_code, mutate in mutations.items():
            with self.subTest(expected_code=expected_code):
                summary = make_summary(4, 1)
                mutate(summary)
                report = group_partition.aggregate_summaries(
                    [summary], minimum_repetitions=3
                )
                codes = [
                    issue["code"]
                    for rejected in report["rejected_runs"]
                    for issue in rejected["issues"]
                ]
                self.assertIn(expected_code, codes)

    def test_measurement_samples_must_reconcile_with_result_work_totals(self):
        mutations = {
            "SAMPLE_EVIDENCE_MISSING": lambda summary: summary["work"].pop(
                "sample_evidence"
            ),
            "SAMPLE_EVIDENCE_MEMBER_SECONDS_COUNT": lambda summary: summary[
                "work"
            ]["sample_evidence"].update(member_seconds_count=None),
            "SAMPLE_EVIDENCE_COUNT_MISMATCH": lambda summary: summary["work"][
                "sample_evidence"
            ].update(record_count=59),
            "SAMPLE_EVIDENCE_MEASUREMENT_COUNT": lambda summary: summary.update(
                measurement_sample_count=59
            ),
            "SAMPLE_MEMBER_SECONDS_MONOTONIC": lambda summary: summary["work"][
                "sample_evidence"
            ].update(member_seconds_monotonic=False),
            "SAMPLE_GROUP_SECONDS_MONOTONIC": lambda summary: summary["work"][
                "sample_evidence"
            ].update(group_seconds_monotonic=False),
            "SAMPLE_MEMBER_SECONDS_LATEST": lambda summary: summary["work"][
                "sample_evidence"
            ].update(latest_member_seconds=summary["work"]["member_seconds"] + 1),
            "SAMPLE_GROUP_SECONDS_LATEST": lambda summary: summary["work"][
                "sample_evidence"
            ].update(latest_group_seconds=summary["work"]["group_seconds"] + 1),
            "SAMPLE_MEMBER_SECONDS_DELTA": lambda summary: summary["work"][
                "sample_evidence"
            ].update(
                latest_member_seconds=summary["work"]["member_seconds"]
                - summary["start"]["targetSyntheticUnits"]
                * summary["start"]["sampleSec"]
                - 1
            ),
            "SAMPLE_GROUP_SECONDS_DELTA": lambda summary: summary["work"][
                "sample_evidence"
            ].update(
                latest_group_seconds=summary["work"]["group_seconds"]
                - summary["start"]["targetGroups"]
                * summary["start"]["sampleSec"]
                - 1
            ),
        }
        for expected_code, mutate in mutations.items():
            with self.subTest(expected_code=expected_code):
                summary = make_summary(4, 1)
                mutate(summary)
                report = group_partition.aggregate_summaries(
                    [summary], minimum_repetitions=3
                )
                codes = [
                    issue["code"]
                    for rejected in report["rejected_runs"]
                    for issue in rejected["issues"]
                ]
                self.assertIn(expected_code, codes)

    def test_every_realized_metric_sum_is_independently_reconciled(self):
        fields = (
            "requested_infantry",
            "created_infantry",
            "crew",
            "vehicles",
            "final_members",
            "underfill_groups",
            "oversize_groups",
            "create_failures",
            "create_failure_groups",
        )
        for field in fields:
            with self.subTest(field=field):
                summary = make_summary(4, 1)
                evidence = summary["composition"]["realized_evidence"]
                evidence[field] += 1
                report = group_partition.aggregate_summaries(
                    [summary], minimum_repetitions=3
                )
                codes = [
                    issue["code"]
                    for rejected in report["rejected_runs"]
                    for issue in rejected["issues"]
                ]
                self.assertIn("REALIZED_EVIDENCE_%s" % field.upper(), codes)

    def test_all_sample_evidence_counts_are_required(self):
        for field in (
            "record_count",
            "member_seconds_count",
            "group_seconds_count",
        ):
            with self.subTest(field=field):
                summary = make_summary(4, 1)
                summary["work"]["sample_evidence"][field] = None
                report = group_partition.aggregate_summaries(
                    [summary], minimum_repetitions=3
                )
                codes = [
                    issue["code"]
                    for rejected in report["rejected_runs"]
                    for issue in rejected["issues"]
                ]
                self.assertIn("SAMPLE_EVIDENCE_%s" % field.upper(), codes)

    def test_every_measure_sample_requires_fps(self):
        summary = make_summary(4, 1)
        summary["work"]["sample_evidence"]["fps_count"] = 59

        _, issues = group_partition._validate_run(summary, "missing-fps.json")

        self.assertIn(
            "SAMPLE_EVIDENCE_FPS_COUNT",
            [issue["code"] for issue in issues],
        )

    def test_sample_work_counters_are_bounded_at_each_measure_time(self):
        summary = make_summary(4, 1)
        evidence = summary["work"]["sample_evidence"]
        evidence["member_seconds_values"] = [summary["work"]["member_seconds"]] * 60
        evidence["group_seconds_values"] = [summary["work"]["group_seconds"]] * 60

        _, issues = group_partition._validate_run(summary, "frontloaded-work.json")

        self.assertIn(
            "SAMPLE_WORK_BOUNDS",
            [issue["code"] for issue in issues],
        )

    def test_sample_work_arrays_fail_closed_on_null_or_latest_mismatch(self):
        cases = {
            "null-measure": lambda evidence: evidence["measure_t_values"].__setitem__(0, None),
            "latest-mismatch": lambda evidence: evidence[
                "member_seconds_values"
            ].__setitem__(-1, evidence["latest_member_seconds"] - 1),
        }
        for name, mutate in cases.items():
            with self.subTest(name=name):
                summary = make_summary(4, 1)
                mutate(summary["work"]["sample_evidence"])

                _, issues = group_partition._validate_run(summary, name + ".json")

                self.assertTrue(issues)
                self.assertIn(
                    "SAMPLE_WORK_BOUNDS",
                    [issue["code"] for issue in issues],
                )

    def test_partition_result_must_carry_direct_cumulative_evidence(self):
        required_fields = (
            "targetSyntheticUnits",
            "realizedGroups",
            "createdInfantry",
            "histogram",
            "anchorRequested",
            "memberSeconds",
            "groupSeconds",
        )
        for field in required_fields:
            with self.subTest(field=field):
                summary = make_summary(4, 1)
                summary["result"].pop(field)

                _, issues = group_partition._validate_run(summary, "missing-result.json")

                self.assertIn(
                    "RESULT_PARTITION_FIELD_MISSING",
                    [issue["code"] for issue in issues],
                )

    def test_partition_result_must_match_independent_summary_evidence(self):
        summary = make_summary(4, 1)
        summary["result"]["createdInfantry"] = 0

        _, issues = group_partition._validate_run(summary, "result-conflict.json")

        self.assertIn(
            "RESULT_PARTITION_INCONSISTENT",
            [issue["code"] for issue in issues],
        )

    def test_partition_result_maps_must_be_well_formed_and_nonempty(self):
        for field, value in (
            ("histogram", "bogus"),
            ("histogram", {}),
            ("anchorRequested", "bogus"),
            ("anchorMembers", {}),
        ):
            with self.subTest(field=field, value=value):
                summary = make_summary(4, 1)
                summary["result"][field] = value

                _, issues = group_partition._validate_run(summary, "bad-map.json")

                self.assertIn(
                    "RESULT_PARTITION_FIELD_INVALID",
                    [issue["code"] for issue in issues],
                )

    def test_partition_result_numeric_fields_are_typed_ranged_and_reconciled(self):
        invalid_cases = (
            ("fpsSamples", "bogus"),
            ("fpsExpected", 1.5),
            ("fpsCoveragePct", float("inf")),
            ("fpsMin", 1001),
            ("targetGroups", -1),
            ("memberSeconds", -1),
        )
        for field, value in invalid_cases:
            with self.subTest(field=field, value=value):
                summary = make_summary(4, 1)
                summary["result"][field] = value

                _, issues = group_partition._validate_run(summary, "bad-result.json")

                self.assertIn(
                    "RESULT_PARTITION_FIELD_INVALID",
                    [issue["code"] for issue in issues],
                )

        conflicts = (
            ("measureT", 899),
            ("fpsSamples", 59),
            ("fpsExpected", 59),
            ("fpsCoveragePct", 99),
            ("fpsMin", 29),
            ("fpsAvg", 39),
            ("aiPeak", 239),
            ("groupsPeak", 59),
            ("pathLegsStarted", 179),
        )
        for field, value in conflicts:
            with self.subTest(field=field):
                summary = make_summary(4, 1)
                summary["result"][field] = value

                _, issues = group_partition._validate_run(summary, "result-conflict.json")

                self.assertIn(
                    "RESULT_PARTITION_INCONSISTENT",
                    [issue["code"] for issue in issues],
                )

    def test_result_rounding_allows_real_producer_precision(self):
        summary = make_summary(4, 1)
        evidence = summary["work"]["sample_evidence"]
        count = 59
        measure_values = [900.0 * (index + 1) / count for index in range(count)]
        evidence["record_count"] = count
        evidence["fps_count"] = count
        evidence["ai_count"] = count
        evidence["groups_count"] = count
        evidence["probe_ms_count"] = count
        evidence["member_seconds_count"] = count
        evidence["group_seconds_count"] = count
        evidence["measure_t_count"] = count
        evidence["measure_t_unique_count"] = count
        evidence["sample_t_count"] = count
        evidence["measure_t_values"] = measure_values
        evidence["sample_t_values"] = [360 + value for value in measure_values]
        evidence["event_indices"] = evidence["event_indices"][:count]
        evidence["fps_values"] = evidence["fps_values"][:count]
        evidence["ai_values"] = evidence["ai_values"][:count]
        evidence["groups_values"] = evidence["groups_values"][:count]
        evidence["probe_ms_values"] = evidence["probe_ms_values"][:count]
        evidence["member_seconds_values"] = [240 * value for value in measure_values]
        evidence["group_seconds_values"] = [60 * value for value in measure_values]
        evidence["latest_measure_t"] = 900
        evidence["latest_member_seconds"] = 216000
        evidence["latest_group_seconds"] = 54000
        summary["measurement_sample_count"] = count
        summary["probe_ms"]["count"] = count
        fps_values = evidence["fps_values"]
        summary["fps"].update(
            min=min(fps_values),
            avg=sum(fps_values) / count,
            median=statistics.median(fps_values),
            p5=group_partition.monitor.percentile(fps_values, 5),
        )
        summary["result"].update(
            fpsMin=min(fps_values),
            fpsAvg=round((sum(fps_values) / count) * 10) / 10,
            fpsSamples=count,
            fpsExpected=60,
            fpsCoveragePct=98.3,
        )

        _, issues = group_partition._validate_run(summary, "rounded-result.json")

        self.assertEqual([], issues)

    def test_expected_sample_count_is_always_derived_from_start(self):
        summary = make_summary(4, 1)
        summary["expected_sample_count"] = 30
        summary["result"].update(fpsExpected=30, fpsCoveragePct=200)

        _, issues = group_partition._validate_run(summary, "forged-expected.json")

        self.assertIn(
            "EXPECTED_SAMPLE_COUNT_INCONSISTENT",
            [issue["code"] for issue in issues],
        )

    def test_measure_samples_must_cover_the_full_window_at_bounded_cadence(self):
        for name, values in (
            ("clustered-late", list(range(841, 901))),
            ("large-gap", list(range(15, 856, 15)) + [885, 900]),
        ):
            with self.subTest(name=name):
                summary = make_summary(4, 1)
                evidence = summary["work"]["sample_evidence"]
                evidence["measure_t_values"] = values
                evidence["measure_t_count"] = len(values)
                evidence["measure_t_unique_count"] = len(set(values))
                evidence["latest_measure_t"] = values[-1]
                summary["measurement_sample_count"] = len(values)
                evidence["record_count"] = len(values)
                evidence["member_seconds_count"] = len(values)
                evidence["group_seconds_count"] = len(values)

                _, issues = group_partition._validate_run(summary, name + ".json")

                self.assertIn(
                    "SAMPLE_MEASURE_TIME_CADENCE",
                    [issue["code"] for issue in issues],
                )

    def test_measure_samples_must_reconcile_measure_and_wall_clocks(self):
        summary = make_summary(4, 1)
        evidence = summary["work"]["sample_evidence"]
        evidence["sample_t_values"] = list(range(999, 1059))
        evidence["sample_t_count"] = len(evidence["sample_t_values"])

        _, issues = group_partition._validate_run(summary, "forged-clock.json")

        self.assertIn(
            "SAMPLE_MEASURE_TIME_CADENCE",
            [issue["code"] for issue in issues],
        )

    def test_measure_samples_after_configured_window_are_rejected(self):
        summary = make_summary(4, 1)
        evidence = summary["work"]["sample_evidence"]
        evidence["measure_t_values"][-1] = 901
        evidence["sample_t_values"][-1] = 1261
        evidence["latest_measure_t"] = 901
        summary["phase"]["records"][-1]["fields"]["t"] = 1261

        _, issues = group_partition._validate_run(summary, "post-window-sample.json")

        self.assertIn(
            "SAMPLE_MEASURE_TIME_CADENCE",
            [issue["code"] for issue in issues],
        )

    def test_partition_barrier_requires_pre_settle_realization_and_full_settle(self):
        cases = {
            "late-realized": lambda summary: summary["composition"][
                "realized_evidence"
            ]["event_indices"].__setitem__(
                -1,
                summary["phase"]["records"][2]["event_index"] + 1,
            ),
            "short-settle": lambda summary: summary["phase"]["records"][2][
                "fields"
            ].update(t=summary["phase"]["records"][1]["fields"]["t"]),
            "reversed-measure-time": lambda summary: summary["phase"]["records"][
                3
            ]["fields"].update(
                t=summary["phase"]["records"][2]["fields"]["t"] - 1
            ),
            "realized-before-spawn": lambda summary: summary["composition"][
                "realized_evidence"
            ]["event_indices"].__setitem__(
                0,
                summary["phase"]["records"][0]["event_index"],
            ),
        }
        for name, mutate in cases.items():
            with self.subTest(name=name):
                summary = make_summary(4, 1)
                mutate(summary)

                _, issues = group_partition._validate_run(summary, name + ".json")

                self.assertIn(
                    "PARTITION_BARRIER",
                    [issue["code"] for issue in issues],
                )

    def test_partition_phase_clocks_match_settle_and_measure_contracts(self):
        cases = {}

        cleanup_mismatch = make_summary(4, 1)
        cleanup_mismatch["phase"]["records"][-1]["fields"]["t"] = 1260000
        cases["cleanup-clock"] = cleanup_mismatch

        excessive_settle = make_summary(4, 1)
        for phase_record in excessive_settle["phase"]["records"][2:]:
            phase_record["fields"]["t"] += 1000
        excessive_settle["work"]["sample_evidence"]["sample_t_values"] = [
            value + 1000
            for value in excessive_settle["work"]["sample_evidence"]["sample_t_values"]
        ]
        for transition in excessive_settle["pathlegs"]["transition_evidence"]:
            transition["t"] += 1000
        cases["long-settle"] = excessive_settle

        bad_zero = make_summary(4, 1)
        bad_zero["phase"]["records"][2]["fields"]["measureT"] = 5
        cases["bad-zero"] = bad_zero

        sample_after_cleanup = make_summary(4, 1)
        sample_after_cleanup["phase"]["records"][-1]["fields"]["t"] = 1259
        cases["sample-after-cleanup"] = sample_after_cleanup

        for name, summary in cases.items():
            with self.subTest(name=name):
                _, issues = group_partition._validate_run(summary, name + ".json")

                self.assertIn(
                    "PARTITION_BARRIER",
                    [issue["code"] for issue in issues],
                )

        bounded_orders = make_summary(4, 1)
        bounded_orders["phase"]["records"][3]["fields"].update(t=362, measureT=2)
        _, issues = group_partition._validate_run(
            bounded_orders, "bounded-orders.json"
        )
        self.assertEqual([], issues)

        bounded_drain = make_summary(4, 1)
        bounded_drain["phase"]["records"][-1]["fields"]["t"] = 1263
        _, issues = group_partition._validate_run(bounded_drain, "bounded-drain.json")
        self.assertEqual([], issues)

    def test_partition_transition_clocks_follow_event_order(self):
        summary = make_summary(4, 1)
        summary["pathlegs"]["transition_evidence"][64].update(t=370, measure_t=10)
        summary["pathlegs"]["transition_evidence"][65].update(t=370, measure_t=10)

        _, issues = group_partition._validate_run(summary, "reversed-path-clock.json")

        self.assertIn(
            "PATH_TRANSITION_INVALID",
            [issue["code"] for issue in issues],
        )

    def test_histogram_must_match_group_member_and_arm_totals(self):
        histograms = {
            "HISTOGRAM_GROUP_COUNT": {"4": 59},
            "HISTOGRAM_MEMBER_COUNT": {"4": 59, "5": 1},
            "HISTOGRAM_ARM_MISMATCH": {"3": 30, "5": 30},
        }
        for expected_code, histogram in histograms.items():
            with self.subTest(expected_code=expected_code):
                summary = make_summary(4, 1)
                summary["composition"]["histogram"] = histogram
                report = group_partition.aggregate_summaries([summary], minimum_repetitions=3)
                codes = [issue["code"] for rejected in report["rejected_runs"] for issue in rejected["issues"]]
                self.assertIn(expected_code, codes)

    def test_cumulative_and_anchor_totals_must_agree(self):
        mutations = {
            "COMPOSITION_UNDERFILL_GROUPS": lambda summary: summary["composition"].update(underfill_groups=1),
            "REQUESTED_INFANTRY_TARGET_MISMATCH": lambda summary: summary["composition"].update(requested_infantry=239),
            "CREATED_INFANTRY_TARGET_MISMATCH": lambda summary: summary["composition"].update(created_infantry=239),
            "FINAL_MEMBERS_TARGET_MISMATCH": lambda summary: summary["composition"].update(final_members=239),
            "ANCHOR_REQUESTED_TOTAL": lambda summary: summary["composition"].update(anchor_requested={"0": 120}),
            "ANCHOR_MEMBERS_FINAL_MEMBERS": lambda summary: summary["composition"].update(final_members=120, created_infantry=120),
        }
        for expected_code, mutate in mutations.items():
            with self.subTest(expected_code=expected_code):
                summary = make_summary(4, 1)
                mutate(summary)
                report = group_partition.aggregate_summaries([summary], minimum_repetitions=3)
                codes = [issue["code"] for rejected in report["rejected_runs"] for issue in rejected["issues"]]
                self.assertIn(expected_code, codes)

    def test_per_route_arrival_rate_uses_completed_over_started(self):
        route_report = group_partition._route_report(
            [
                {
                    "routes": {
                        "Strelka>Airfield": {
                            "records": 15,
                            "started": 10,
                            "completed": 5,
                            "arrived": 5,
                            "units": 20,
                        }
                    }
                }
            ]
        )["Strelka>Airfield"]
        self.assertEqual(50, route_report["arrival_pct"]["median"])

    def test_route_totals_and_anchor_coverage_must_reconcile(self):
        mutations = {
            "ROUTE_COUNT_MISMATCH": lambda summary: summary["pathlegs"].update(route_count=4),
            "ROUTE_STARTED_TOTAL": lambda summary: summary["pathlegs"].update(started=121),
            "ROUTE_COMPLETED_TOTAL": lambda summary: summary["pathlegs"].update(completed=119),
            "ROUTE_ARRIVAL_UNITS_TOTAL": lambda summary: summary["pathlegs"].update(arrival_units=719),
            "INITIAL_LEGS_MISSING": lambda summary: summary["pathlegs"].update(started=59),
            "ANCHOR_ROUTES_MISSING": lambda summary: summary["pathlegs"].update(route_count=1),
        }
        for expected_code, mutate in mutations.items():
            with self.subTest(expected_code=expected_code):
                summary = make_summary(4, 1)
                mutate(summary)
                report = group_partition.aggregate_summaries([summary], minimum_repetitions=3)
                codes = [issue["code"] for rejected in report["rejected_runs"] for issue in rejected["issues"]]
                self.assertIn(expected_code, codes)

    def test_path_transition_evidence_proves_distinct_ordered_group_work(self):
        cases = {
            "missing": lambda summary: summary["pathlegs"].update(
                transition_evidence=[]
            ),
            "duplicate-index": lambda summary: summary["pathlegs"][
                "transition_evidence"
            ][1].update(
                event_index=summary["pathlegs"]["transition_evidence"][0][
                    "event_index"
                ]
            ),
            "initial-after-measure": lambda summary: summary["pathlegs"][
                "transition_evidence"
            ][0].update(
                event_index=summary["phase"]["records"][3]["event_index"] + 1
            ),
            "wrong-group": lambda summary: summary["pathlegs"][
                "transition_evidence"
            ][0].update(group=2),
        }
        for name, mutate in cases.items():
            with self.subTest(name=name):
                summary = make_summary(4, 1)
                mutate(summary)

                _, issues = group_partition._validate_run(summary, name + ".json")

                self.assertIn(
                    "PATH_TRANSITION_INVALID",
                    [issue["code"] for issue in issues],
                )

    def test_path_transition_evidence_after_measurement_window_is_rejected(self):
        summary = make_summary(4, 1)
        for record in summary["pathlegs"]["transition_evidence"][-2:]:
            record.update(t=1280, measure_t=920)
        summary["phase"]["records"][-1]["fields"]["t"] = 1290

        _, issues = group_partition._validate_run(summary, "post-window-path.json")

        self.assertIn(
            "PATH_TRANSITION_INVALID",
            [issue["code"] for issue in issues],
        )

    def test_path_transition_evidence_reconciles_all_path_summaries(self):
        cases = {
            "started-total": lambda summary: summary["pathlegs"].update(started=181),
            "completed-total": lambda summary: summary["pathlegs"].update(completed=121),
            "arrival-units": lambda summary: summary["pathlegs"].update(arrival_units=479),
            "started-indices": lambda summary: summary["pathlegs"][
                "started_event_indices"
            ].__setitem__(0, 99999),
            "route-total": lambda summary: summary["pathlegs"]["routes"][
                "Strelka>Airfield"
            ].update(started=61),
            "route-id": lambda summary: summary["pathlegs"]["transition_evidence"][
                0
            ].update(route_id="bogus"),
            "path-count": lambda summary: summary["pathlegs"].update(count=299),
            "path-status": lambda summary: summary["pathlegs"]["status"].update(
                STARTED=179
            ),
            "route-records": lambda summary: summary["pathlegs"]["routes"][
                "Strelka>Airfield"
            ].update(records=119),
            "route-status": lambda summary: summary["pathlegs"]["routes"][
                "Strelka>Airfield"
            ]["status"].update(ARRIVED=59),
            "route-elapsed": lambda summary: summary["pathlegs"]["routes"][
                "Strelka>Airfield"
            ].update(elapsed_median=999999),
        }
        for name, mutate in cases.items():
            with self.subTest(name=name):
                summary = make_summary(4, 1)
                mutate(summary)

                _, issues = group_partition._validate_run(summary, name + ".json")

                self.assertIn(
                    "PATH_TRANSITION_INVALID",
                    [issue["code"] for issue in issues],
                )

    def test_path_transition_elapsed_must_reconcile_with_measurement_clocks(self):
        summary = make_summary(4, 1)
        first_arrival = next(
            record
            for record in summary["pathlegs"]["transition_evidence"]
            if record["status"] == "ARRIVED"
        )
        first_arrival["elapsed"] = 999

        _, issues = group_partition._validate_run(summary, "bad-path-elapsed.json")

        self.assertIn(
            "PATH_TRANSITION_INVALID",
            [issue["code"] for issue in issues],
        )

    def test_balanced_route_swaps_cannot_corrupt_pairing_or_continuity(self):
        paired = make_summary(4, 1)
        arrivals = [
            record
            for record in paired["pathlegs"]["transition_evidence"]
            if record["group"] == 1 and record["status"] == "ARRIVED"
        ]
        arrivals[0]["route_id"], arrivals[1]["route_id"] = (
            arrivals[1]["route_id"],
            arrivals[0]["route_id"],
        )

        _, issues = group_partition._validate_run(paired, "balanced-arrival-swap.json")
        self.assertIn(
            "PATH_TRANSITION_INVALID",
            [issue["code"] for issue in issues],
        )

        continuity = make_summary(4, 1)
        starts = [
            record
            for record in continuity["pathlegs"]["transition_evidence"]
            if record["group"] == 1 and record["status"] == "STARTED"
        ]
        starts[1]["route_id"], starts[2]["route_id"] = (
            starts[2]["route_id"],
            starts[1]["route_id"],
        )

        _, issues = group_partition._validate_run(
            continuity, "balanced-continuity-swap.json"
        )
        self.assertIn(
            "PATH_TRANSITION_INVALID",
            [issue["code"] for issue in issues],
        )

    def test_path_routes_require_the_exact_utes_directed_cycle(self):
        summary = make_summary(4, 1)
        replacements = {
            "Strelka>Airfield": "A>B",
            "Airfield>Kamenyy": "B>C",
            "Kamenyy>Strelka": "C>A",
        }
        for record in summary["pathlegs"]["transition_evidence"]:
            record["route_id"] = replacements[record["route_id"]]
        summary["pathlegs"]["route_ids"] = [
            replacements[route_id] for route_id in summary["pathlegs"]["route_ids"]
        ]
        summary["pathlegs"]["routes"] = {
            replacements[route_id]: values
            for route_id, values in summary["pathlegs"]["routes"].items()
        }

        _, issues = group_partition._validate_run(summary, "synthetic-cycle.json")

        self.assertIn(
            "PATH_TRANSITION_INVALID",
            [issue["code"] for issue in issues],
        )

    def test_initial_path_transition_requires_full_realized_arm(self):
        summary = make_summary(4, 1)
        summary["pathlegs"]["transition_evidence"][0]["units"] = 1

        _, issues = group_partition._validate_run(summary, "short-initial.json")

        self.assertIn(
            "PATH_TRANSITION_INVALID",
            [issue["code"] for issue in issues],
        )

    def test_discrete_path_counts_and_minimum_arrival_units_are_required(self):
        cases = {
            "STARTED_MISSING": lambda summary: summary["pathlegs"].update(started=180.5),
            "COMPLETED_MISSING": lambda summary: summary["pathlegs"].update(completed=120.5),
            "ARRIVAL_UNITS_FLOOR": lambda summary: summary["pathlegs"].update(arrival_units=119),
            "ROUTE_COUNT_MISSING": lambda summary: summary["pathlegs"].update(route_count=3.5),
            "ROUTE_ARRIVAL_UNITS_FLOOR": lambda summary: summary["pathlegs"]["routes"][
                "Strelka>Airfield"
            ].update(units=59),
        }
        for expected_code, mutate in cases.items():
            with self.subTest(expected_code=expected_code):
                summary = make_summary(4, 1)
                mutate(summary)

                _, issues = group_partition._validate_run(summary, "discrete-path.json")

                self.assertIn(expected_code, [issue["code"] for issue in issues])

    def test_event_indices_are_strictly_ordered_and_globally_unique(self):
        cases = {
            "duplicate-sample": lambda summary: summary["work"]["sample_evidence"][
                "event_indices"
            ].__setitem__(1, summary["work"]["sample_evidence"]["event_indices"][0]),
            "reversed-sample": lambda summary: summary["work"]["sample_evidence"][
                "event_indices"
            ].__setitem__(
                slice(0, 2),
                list(reversed(summary["work"]["sample_evidence"]["event_indices"][:2])),
            ),
            "sample-phase-collision": lambda summary: summary["work"]["sample_evidence"][
                "event_indices"
            ].__setitem__(0, summary["phase"]["records"][3]["event_index"]),
            "path-sample-collision": lambda summary: summary["pathlegs"][
                "transition_evidence"
            ][-1].update(
                event_index=summary["work"]["sample_evidence"]["event_indices"][0]
            ),
        }
        for name, mutate in cases.items():
            with self.subTest(name=name):
                summary = make_summary(4, 1)
                mutate(summary)

                _, issues = group_partition._validate_run(summary, name + ".json")

                self.assertIn(
                    "PARTITION_BARRIER",
                    [issue["code"] for issue in issues],
                )

    def test_probe_cost_evidence_is_complete_and_finite(self):
        for field, value in (
            ("count", 59),
            ("median", None),
            ("p95", float("inf")),
            ("max", -1),
        ):
            with self.subTest(field=field):
                summary = make_summary(4, 1)
                summary["probe_ms"][field] = value

                _, issues = group_partition._validate_run(summary, "probe.json")

                self.assertIn(
                    "PROBE_MS_INVALID",
                    [issue["code"] for issue in issues],
                )

    def test_work_counter_monotonicity_is_recomputed_from_raw_arrays(self):
        summary = make_summary(4, 1)
        evidence = summary["work"]["sample_evidence"]
        member_values = [3600]
        member_values.extend(3599 + (3600 * (index - 1)) for index in range(1, 60))
        evidence["member_seconds_values"] = member_values
        evidence["latest_member_seconds"] = member_values[-1]
        summary["work"]["member_seconds"] = member_values[-1]
        summary["result"]["memberSeconds"] = member_values[-1]
        evidence["member_seconds_monotonic"] = True

        _, issues = group_partition._validate_run(summary, "forged-monotonic.json")

        self.assertIn("SAMPLE_WORK_BOUNDS", [issue["code"] for issue in issues])

    def test_arrival_units_cannot_exceed_completed_group_capacity(self):
        summary = make_summary(4, 1)
        route = summary["pathlegs"]["routes"]["Strelka>Airfield"]
        route["units"] = (route["completed"] * 4) + 1
        summary["pathlegs"]["arrival_units"] += 1

        report = group_partition.aggregate_summaries([summary], minimum_repetitions=3)
        codes = [
            issue["code"]
            for rejected in report["rejected_runs"]
            for issue in rejected["issues"]
        ]
        self.assertIn("ROUTE_ARRIVAL_UNITS_CAP", codes)
        self.assertIn("ARRIVAL_UNITS_CAP", codes)

        boundary = make_summary(4, 1)
        report = group_partition.aggregate_summaries([boundary], minimum_repetitions=3)
        self.assertEqual(1, report["accepted_count"])

    def test_outstanding_leg_frontier_tracks_realized_groups(self):
        too_few = make_summary(4, 1)
        route = too_few["pathlegs"]["routes"]["Kamenyy>Strelka"]
        route.update(records=62, completed=2, arrived=2, units=8)
        too_few["pathlegs"].update(completed=122, arrival_units=488)

        too_many = make_summary(4, 1)
        too_many["pathlegs"]["routes"]["Kamenyy>Strelka"].update(started=61, records=61)
        too_many["pathlegs"]["started"] = 181

        for summary in (too_few, too_many):
            with self.subTest(outstanding=summary["pathlegs"]["started"] - summary["pathlegs"]["completed"]):
                report = group_partition.aggregate_summaries([summary], minimum_repetitions=3)
                codes = [issue["code"] for rejected in report["rejected_runs"] for issue in rejected["issues"]]
                self.assertIn("OUTSTANDING_LEGS", codes)

    def test_target_units_must_match_across_arms(self):
        inputs = campaign()
        inputs[0] = (inputs[0][0], make_summary(4, 1, target_units=360))
        report = group_partition.aggregate_summaries(inputs)
        self.assertEqual("INVALID", report["status"])
        self.assertIn("TARGET_UNITS_MISMATCH", [issue["code"] for issue in report["comparison_issues"]])

    def test_member_seconds_spread_above_three_percent_is_invalid(self):
        inputs = campaign()
        inputs[0][1]["work"]["member_seconds"] *= 0.98
        inputs[1][1]["work"]["member_seconds"] *= 1.016
        sync_sample_evidence(inputs[0][1])
        sync_result_work(inputs[1][1])
        report = group_partition.aggregate_summaries(inputs)
        self.assertEqual("INVALID", report["status"])
        self.assertIn("MEMBER_SECONDS_MISMATCH", [issue["code"] for issue in report["comparison_issues"]])

    def test_absolute_member_and_group_exposure_floors(self):
        mutations = {
            "MEMBER_SECONDS_ATTAINMENT": lambda summary: summary["work"].update(
                member_seconds=summary["start"]["targetSyntheticUnits"] * 900 * 0.979
            ),
            "GROUP_SECONDS_ATTAINMENT": lambda summary: summary["work"].update(
                group_seconds=summary["start"]["targetGroups"] * 900 * 0.979
            ),
        }
        for expected_code, mutate in mutations.items():
            with self.subTest(expected_code=expected_code):
                summary = make_summary(4, 1)
                mutate(summary)
                report = group_partition.aggregate_summaries([summary], minimum_repetitions=3)
                codes = [issue["code"] for rejected in report["rejected_runs"] for issue in rejected["issues"]]
                self.assertIn(expected_code, codes)

        boundary = make_summary(4, 1)
        boundary["work"]["member_seconds"] *= 0.98
        boundary["work"]["group_seconds"] *= 0.98
        sync_sample_evidence(boundary)
        report = group_partition.aggregate_summaries([boundary], minimum_repetitions=3)
        self.assertEqual(1, report["accepted_count"])

    def test_member_and_group_exposure_overcounts_are_rejected(self):
        mutations = {
            "MEMBER_SECONDS_OVERCOUNT": lambda summary: summary["work"].update(
                member_seconds=summary["start"]["targetSyntheticUnits"]
                * summary["work"]["measurement_seconds"]
                * 2
            ),
            "GROUP_SECONDS_OVERCOUNT": lambda summary: summary["work"].update(
                group_seconds=summary["start"]["targetGroups"]
                * summary["work"]["measurement_seconds"]
                * 2
            ),
        }
        for expected_code, mutate in mutations.items():
            with self.subTest(expected_code=expected_code):
                summary = make_summary(4, 1)
                mutate(summary)
                report = group_partition.aggregate_summaries([summary], minimum_repetitions=3)
                codes = [
                    issue["code"]
                    for rejected in report["rejected_runs"]
                    for issue in rejected["issues"]
                ]
                self.assertIn(expected_code, codes)

        boundary = make_summary(4, 1)
        tolerated_seconds = (
            boundary["work"]["measurement_seconds"] + boundary["start"]["sampleSec"]
        )
        boundary["work"]["member_seconds"] = (
            boundary["start"]["targetSyntheticUnits"] * tolerated_seconds
        )
        boundary["work"]["group_seconds"] = (
            boundary["start"]["targetGroups"] * tolerated_seconds
        )
        sync_result_work(boundary)
        report = group_partition.aggregate_summaries([boundary], minimum_repetitions=3)
        self.assertEqual(1, report["accepted_count"])

    def test_realized_anchor_members_must_be_exact_and_complete(self):
        for anchor_members in ({"0": 120}, {"0": 120, "1": 119}):
            with self.subTest(anchor_members=anchor_members):
                summary = make_summary(4, 1)
                summary["composition"]["anchor_members"] = anchor_members
                report = group_partition.aggregate_summaries([summary], minimum_repetitions=3)
                codes = [issue["code"] for rejected in report["rejected_runs"] for issue in rejected["issues"]]
                self.assertIn("ANCHOR_MEMBERS_UNEQUAL", codes)

    def test_measurement_window_must_match_duration_within_one_sample(self):
        summary = make_summary(4, 1)
        summary["work"]["measurement_seconds"] = 884
        report = group_partition.aggregate_summaries([summary], minimum_repetitions=3)
        codes = [issue["code"] for rejected in report["rejected_runs"] for issue in rejected["issues"]]
        self.assertIn("MEASUREMENT_DURATION", codes)

    def test_cross_run_measurement_drift_is_rejected_per_run_before_comparison(self):
        inputs = campaign()
        inputs[0][1]["work"]["measurement_seconds"] = 886
        inputs[1][1]["work"]["measurement_seconds"] = 914
        report = group_partition.aggregate_summaries(inputs)
        self.assertEqual("INVALID", report["status"])
        self.assertIn(
            "MEASUREMENT_DURATION",
            [
                issue["code"]
                for rejected in report["rejected_runs"]
                for issue in rejected["issues"]
            ],
        )

    def test_incomplete_or_impure_runs_are_rejected(self):
        mutations = {
            "RESULT_NOT_PASS": lambda summary: summary["result"].update(status="FAIL"),
            "RESULT_INCOMPLETE": lambda summary: summary["result"].update(complete=0),
            "MEMBER_ATTAINMENT": lambda summary: summary["composition"].update(attainment_pct=97),
            "COMPOSITION_VEHICLES": lambda summary: summary["composition"].update(vehicles=1),
            "COMPOSITION_OVERSIZE_GROUPS": lambda summary: summary["composition"].update(oversize_groups=1),
            "COMPOSITION_CREATE_FAILURES": lambda summary: summary["composition"].update(create_failures=1),
        }
        for expected_code, mutate in mutations.items():
            with self.subTest(expected_code=expected_code):
                summary = make_summary(4, 1)
                mutate(summary)
                report = group_partition.aggregate_summaries([summary], minimum_repetitions=3)
                codes = [issue["code"] for rejected in report["rejected_runs"] for issue in rejected["issues"]]
                self.assertIn(expected_code, codes)

    def test_monitor_alert_and_fatal_evidence_must_be_explicit_empty_lists(self):
        for field, expected in (
            ("alerts", "MONITOR_ALERTS_INVALID"),
            ("fatal_signatures", "FATAL_SIGNATURES_INVALID"),
        ):
            for value in (None, {}, "", 0):
                with self.subTest(field=field, value=value):
                    summary = make_summary(4, 1)
                    if value is None:
                        del summary[field]
                    else:
                        summary[field] = value

                    _, issues = group_partition._validate_run(
                        summary, "%s-invalid.json" % field
                    )

                    self.assertIn(
                        expected,
                        [issue["code"] for issue in issues],
                    )

    def test_duplicate_run_does_not_count_as_a_repetition(self):
        inputs = campaign()
        duplicate = copy.deepcopy(inputs[0])
        inputs.append(duplicate)
        report = group_partition.aggregate_summaries(inputs)
        self.assertEqual("INVALID", report["status"])
        self.assertIn("DUPLICATE_RUN", [issue["code"] for issue in report["comparison_issues"]])

    def test_any_rejected_input_prevents_a_ready_claim(self):
        inputs = campaign()
        rejected = make_summary(4, 99)
        rejected["result"]["status"] = "FAIL"
        inputs.append(("rejected-extra.rpt", rejected))
        report = group_partition.aggregate_summaries(inputs)
        self.assertEqual(15, report["accepted_count"])
        self.assertEqual(1, report["rejected_count"])
        self.assertEqual("INVALID", report["status"])
        self.assertFalse(report["ok"])


if __name__ == "__main__":
    unittest.main()
