import contextlib
import copy
import importlib.util
import io
import json
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
    started = target_groups * len(route_names)
    completed = target_groups * 2
    route_records = target_groups
    anchor_requested = dict((str(index), 120) for index in range(anchors))
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
            "elapsed_median": (80 + index) if route_completed > 0 else None,
        }
    start = {
        "run": run,
        "scenario": "density-%s" % arm,
        "map": "utes",
        "build": "wasplab-density-%s" % arm,
        "git": "abc123",
        "source": "source-id",
        "lab": "lab-id",
        "config": "config-%s" % arm,
        "workload": "workload-%s" % arm,
        "partition": "partition-shared",
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
        "ok": True,
        "alerts": [],
        "fatal_signatures": [],
        "fps": {
            "median": 40 + (arm / 10.0) + repetition,
            "avg": 39 + (arm / 10.0) + repetition,
            "p5": 31 + (arm / 10.0) + repetition,
            "min": 29 + (arm / 10.0) + repetition,
        },
        "phase": {
            "sequence": ["SPAWN", "SETTLE", "GO", "MEASURE", "CLEANUP"],
            "measurement_started_phase": "GO",
            "measurement_seconds": 900,
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
                "member_seconds_count": 60,
                "group_seconds_count": 60,
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
        },
        "cleanup": {"objects_remaining": 0, "groups_remaining": 0},
        "result": {"run": run, "status": "PASS", "complete": 1, "measureT": 900},
    }


def sync_sample_evidence(summary):
    evidence = summary["work"]["sample_evidence"]
    evidence["latest_member_seconds"] = summary["work"]["member_seconds"]
    evidence["latest_group_seconds"] = summary["work"]["group_seconds"]


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

    def test_config_relevant_start_mismatch_is_invalid(self):
        inputs = campaign()
        inputs[0][1]["start"]["duration"] = 901
        report = group_partition.aggregate_summaries(inputs)
        self.assertEqual("INVALID", report["status"])
        self.assertIn("DURATION_MISMATCH", [issue["code"] for issue in report["comparison_issues"]])

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
        inputs[0][1]["start"]["partition"] = "different-partition"
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
        summary = make_summary(4, 1)
        route = summary["pathlegs"]["routes"]["Strelka>Airfield"]
        route.update(records=15, started=10, completed=5, arrived=5, units=20)
        summary["pathlegs"]["routes"]["Kamenyy>Strelka"].update(started=55, records=55)
        summary["pathlegs"].update(started=125, completed=65, arrival_units=260)
        report = group_partition.aggregate_summaries([summary], minimum_repetitions=3)
        self.assertEqual(1, report["accepted_count"])
        route_report = report["arms"]["4"]["route_normalized"]["routes"]["Strelka>Airfield"]
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

    def test_cross_run_measurement_window_spread_is_bounded(self):
        inputs = campaign()
        inputs[0][1]["work"]["measurement_seconds"] = 886
        inputs[1][1]["work"]["measurement_seconds"] = 914
        report = group_partition.aggregate_summaries(inputs)
        self.assertEqual("INVALID", report["status"])
        self.assertIn("MEASUREMENT_SECONDS_SPREAD", [issue["code"] for issue in report["comparison_issues"]])

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
