"""Regression tests for the dependency-free WASPLAB RPT monitor."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


HERE = Path(__file__).resolve().parent
TOOL_DIR = HERE.parent
sys.path.insert(0, str(TOOL_DIR))

import monitor


SAMPLE = HERE / "sample.rpt"


class MarkerParsingTests(unittest.TestCase):
    def test_arma_prefix_quotes_and_trailing_semicolon(self):
        line = '12:34:56 "WASPLAB|v1|RESULT|run=x|status=PASS|fpsMin=31.5";\n'
        event = monitor.parse_marker(line)
        self.assertEqual(event["kind"], "RESULT")
        self.assertEqual(event["fields"]["run"], "x")
        self.assertEqual(event["fields"]["status"], "PASS")
        self.assertEqual(event["fields"]["fpsMin"], 31.5)

    def test_unknown_and_non_marker_lines_are_ignored(self):
        self.assertIsNone(monitor.parse_marker("ordinary RPT output"))
        self.assertIsNone(monitor.parse_marker("WASPLAB|v2|SAMPLE|fps=50"))
        self.assertIsNone(monitor.parse_marker("WASPLAB|v1|UNKNOWN|fps=50"))

    def test_alert_and_abort_markers_are_parsed(self):
        self.assertEqual(
            monitor.parse_marker("WASPLAB|v1|ALERT|state=COLLAPSED")["kind"],
            "ALERT",
        )
        self.assertEqual(
            monitor.parse_marker("WASPLAB|v1|ABORT|reason=towns_empty")["kind"],
            "ABORT",
        )

    def test_phase_realized_and_composition_markers_are_parsed(self):
        for kind in ("PHASE", "REALIZED", "COMPOSITION"):
            event = monitor.parse_marker(
                "WASPLAB|v1|%s|phase=GO|targetSyntheticUnits=240" % kind
            )
            self.assertEqual(event["kind"], kind)
            self.assertEqual(event["fields"]["targetSyntheticUnits"], 240)

    def test_sample_world_and_created_vehicle_counts_remain_distinct(self):
        marker = (
            "WASPLAB|v1|SAMPLE|phase=MEASURE|targetSyntheticUnits=240"
            "|requestedInfantry=240|createdInfantry=240|finalMembers=240"
            "|vehicles=17|createdVehicles=2|fps=40"
        )
        event = monitor.parse_marker(marker)
        self.assertEqual(event["fields"]["vehicles"], 17)
        self.assertEqual(event["fields"]["createdVehicles"], 2)

        state = monitor.parse_last_run([
            "WASPLAB|v1|START|run=vehicle-fields|targetSyntheticUnits=240\n",
            marker + "\n",
        ])
        self.assertEqual(state.summary()["composition"]["vehicles"], 2)

    def test_non_finite_fps_cannot_produce_an_ok_summary(self):
        for value in ("nan", "inf", "-inf"):
            with self.subTest(value=value):
                state = monitor.parse_last_run([
                    "WASPLAB|v1|START|run=non-finite|duration=60|sampleSec=60|warmupSec=0\n",
                    "WASPLAB|v1|SAMPLE|run=non-finite|t=60|fps=%s\n" % value,
                    "WASPLAB|v1|RESULT|run=non-finite|status=PASS|complete=1|fpsSamples=1|fpsExpected=1|fpsCoveragePct=100\n",
                ])
                summary = state.summary()
                self.assertFalse(summary["ok"])
                self.assertIn(
                    "NO_BENCHMARK_SAMPLES",
                    [item["code"] for item in summary["alerts"]],
                )

    def test_huge_integer_fps_is_rejected_without_crashing(self):
        huge = "1" + ("0" * 400)
        state = monitor.parse_last_run([
            "WASPLAB|v1|START|run=huge|duration=60|sampleSec=60|warmupSec=0\n",
            "WASPLAB|v1|SAMPLE|run=huge|t=60|fps=%s\n" % huge,
            "WASPLAB|v1|RESULT|run=huge|status=PASS|complete=1|fpsSamples=1|fpsExpected=1|fpsCoveragePct=100\n",
        ])
        summary = state.summary()
        self.assertFalse(summary["ok"])
        self.assertIn(
            "NO_BENCHMARK_SAMPLES",
            [item["code"] for item in summary["alerts"]],
        )

    def test_non_finite_numeric_tokens_remain_json_safe(self):
        for value in ("1e400", "nan", "inf", "-infinity"):
            with self.subTest(value=value):
                event = monitor.parse_marker(
                    "WASPLAB|v1|RESULT|run=x|status=PASS|measureDuration=%s"
                    % value
                )
                self.assertEqual(event["fields"]["measureDuration"], value)
                self.assertIn(
                    "INVALID_NUMERIC_FIELD",
                    [item["kind"] for item in event["protocol_issues"]],
                )
                json.dumps(event, allow_nan=False)

    def test_huge_histogram_key_is_ignored_without_crashing(self):
        huge = "1" + ("0" * 400)
        state = monitor.parse_last_run([
            "WASPLAB|v1|START|run=huge-hist|duration=60|sampleSec=60|warmupSec=0\n",
            "WASPLAB|v1|SAMPLE|run=huge-hist|t=60|fps=40\n",
            "WASPLAB|v1|RESULT|run=huge-hist|status=PASS|complete=1|fpsSamples=1|fpsExpected=1|fpsCoveragePct=100|histogram=[[{} ,1]]\n".format(huge),
        ])
        self.assertIsNone(state.summary()["composition"]["histogram"])

    def test_phase_sample_gate_matches_offline_and_follow_semantics(self):
        start = {"warmupSec": 60}
        self.assertFalse(
            monitor._sample_is_benchmark({"phase": "SETTLE", "t": 120}, start)
        )
        self.assertTrue(
            monitor._sample_is_benchmark({"phase": "MEASURE", "t": 1}, start)
        )
        self.assertFalse(monitor._sample_is_benchmark({"t": 59}, start))
        self.assertTrue(monitor._sample_is_benchmark({"t": 60}, start))

    def test_positional_fields_are_preserved(self):
        event = monitor.parse_marker("WASPLAB|v1|PATHLEG|road-1|status=PASS")
        self.assertEqual(event["fields"]["_positional"], ["road-1"])

    def test_sqf_error_text_cannot_spoof_start_marker(self):
        line = '12:00:00 Error in expression <diag_log ("WASPLAB|v1|START|run=spoof")>\n'
        self.assertIsNone(monitor.parse_marker(line))

    def test_partial_quoted_marker_is_not_accepted(self):
        self.assertIsNone(
            monitor.parse_marker('12:00:00 "WASPLAB|v1|RESULT|run=x|status=PASS')
        )

    def test_bare_marker_trailing_semicolon_is_stripped(self):
        event = monitor.parse_marker("WASPLAB|v1|RESULT|run=x|status=PASS;")
        self.assertEqual(event["fields"]["status"], "PASS")


class LastRunSummaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.state = monitor.parse_file(str(SAMPLE))
        cls.summary = cls.state.summary(min_fps=35)

    def test_only_last_start_block_is_used(self):
        self.assertEqual(self.summary["run"], "utes-path-001")
        self.assertEqual(self.summary["sample_count"], 2)
        self.assertEqual(self.summary["ai_peak"], 110)
        self.assertEqual(self.summary["groups_peak"], 25)
        self.assertNotIn("old run error", json.dumps(self.summary))

    def test_fps_statistics(self):
        self.assertEqual(self.summary["fps"]["median"], 38.75)
        self.assertEqual(self.summary["fps"]["min"], 30)
        self.assertEqual(self.summary["fps"]["p5"], 30.875)

    def test_owner_aware_hc_percentages(self):
        # SAMPLE 1: 20 / 100; SAMPLE 2: 10 / 100.
        self.assertEqual(self.summary["hc_pct"]["median"], 15)
        self.assertEqual(self.summary["hc_pct"]["min"], 10)
        self.assertEqual(self.summary["hc_pct"]["basis"], ["ownerAi"])
        # remotePct remains visible but does not masquerade as HC-owned AI.
        self.assertEqual(self.summary["remote_pct"]["median"], 18.5)

    def test_path_and_stuck_metrics(self):
        self.assertEqual(self.summary["max_stuck"], 4)
        self.assertEqual(self.summary["pathlegs"]["count"], 1)
        self.assertEqual(self.summary["pathlegs"]["status"], {"PARTIAL": 1})

    def test_result_fields_are_retained(self):
        self.assertEqual(self.summary["result"]["status"], "WARN")
        self.assertEqual(self.summary["result"]["reason"], "path_partial")
        self.assertEqual(self.summary["result"]["duration"], 63)

    def test_result_bus_totals_override_cumulative_observations(self):
        bus = self.summary["bus"]
        self.assertEqual(bus["sent"], 20)
        self.assertEqual(bus["ack"], 18)
        self.assertEqual(bus["loss"], 2)
        self.assertEqual(bus["latency_ms"], 55)
        self.assertEqual(bus["latency_ms_median"], 50)
        self.assertEqual(bus["latency_ms_max"], 60)
        self.assertIn("result", bus["source"])

    def test_fatals_are_scoped_and_benign_texture_warning_is_excluded(self):
        fatals = dict(
            (entry["code"], entry["count"])
            for entry in self.summary["fatal_signatures"]
        )
        self.assertEqual(fatals["SQF_EXPRESSION_ERROR"], 1)
        self.assertEqual(fatals["SQF_UNDEFINED_VARIABLE"], 1)
        self.assertNotIn("CANNOT_CREATE_OR_LOAD", fatals)

    def test_threshold_and_result_alerts(self):
        codes = [alert["code"] for alert in self.summary["alerts"]]
        self.assertIn("FPS_BELOW_MIN", codes)
        self.assertIn("RESULT_WARN", codes)
        self.assertFalse(self.summary["ok"])

    def test_cumulative_bus_without_result(self):
        lines = [
            "WASPLAB|v1|START|run=bus-only\n",
            "WASPLAB|v1|BUS|sentTotal=4|ackTotal=3|dropTotal=0|latencyMs=10\n",
            "WASPLAB|v1|BUS|sentTotal=8|ackTotal=7|dropTotal=1|latencyMs=20\n",
        ]
        bus = monitor.parse_last_run(lines).summary()["bus"]
        self.assertEqual((bus["sent"], bus["ack"], bus["loss"]), (8, 7, 1))
        self.assertEqual(bus["latency_ms"], 15)
        self.assertEqual(bus["source"], "cumulative")

    def test_interval_bus_is_summed(self):
        lines = [
            "WASPLAB|v1|START|run=bus-interval\n",
            "WASPLAB|v1|BUS|sent=4|ack=3|loss=0|latencyMs=10\n",
            "WASPLAB|v1|BUS|sent=5|ack=5|loss=1|latencyMs=20\n",
        ]
        bus = monitor.parse_last_run(lines).summary()["bus"]
        self.assertEqual((bus["sent"], bus["ack"], bus["loss"]), (9, 8, 1))
        self.assertEqual(bus["source"], "interval")

    def test_protocol_alerts_make_summary_fail_loudly(self):
        lines = [
            "WASPLAB|v1|START|run=collapse\n",
            "WASPLAB|v1|ALERT|state=COLLAPSED|hcPct=7\n",
            "WASPLAB|v1|SPAWN_FAIL|reason=grpNull\n",
        ]
        summary = monitor.parse_last_run(lines).summary()
        codes = [alert["code"] for alert in summary["alerts"]]
        self.assertIn("LAB_COLLAPSED", codes)
        self.assertIn("LAB_SPAWN_FAIL", codes)
        self.assertFalse(summary["ok"])

    def test_warmup_samples_are_excluded_from_benchmark_metrics(self):
        lines = [
            "WASPLAB|v1|START|run=warm|warmupSec=60\n",
            "WASPLAB|v1|SAMPLE|t=10|fps=5|ai=100|hcAi=0|srvAi=100|hcs=2\n",
            "WASPLAB|v1|SAMPLE|t=70|fps=40|ai=100|hcAi=80|srvAi=20|hcs=2\n",
            "WASPLAB|v1|RESULT|status=PASS|fpsMin=40|fpsAvg=40|hcPctMin=80\n",
        ]
        summary = monitor.parse_last_run(lines).summary()
        self.assertEqual(summary["fps"]["min"], 40)
        self.assertEqual(summary["fps"]["median"], 40)
        self.assertEqual(summary["hc_pct"]["min"], 80)
        self.assertEqual(summary["warmup"]["boot_fps_min"], 5)

    def test_phase_scoped_duration_does_not_subtract_legacy_warmup(self):
        lines = [
            "WASPLAB|v1|START|run=phase-coverage|duration=900|sampleSec=15|warmupSec=300|settleSec=300\n",
            "WASPLAB|v1|PHASE|t=0|phase=SPAWN|phaseSeq=1\n",
            "WASPLAB|v1|PHASE|t=300|phase=GO|phaseSeq=3|measureT=0\n",
            "WASPLAB|v1|PHASE|t=300|phase=MEASURE|phaseSeq=4|measureT=0\n",
        ]
        lines.extend(
            "WASPLAB|v1|SAMPLE|t=%s|phase=MEASURE|measureT=%s|fps=40\n"
            % (300 + (index * 15), index * 15)
            for index in range(1, 61)
        )
        lines.append(
            "WASPLAB|v1|RESULT|run=phase-coverage|status=PASS|phase=CLEANUP|measureDuration=900|measureT=900|fpsSamples=60|fpsExpected=60|fpsCoveragePct=100|complete=1\n"
        )

        summary = monitor.parse_last_run(lines).summary()
        self.assertEqual(summary["benchmark_sample_count"], 60)
        self.assertEqual(summary["expected_sample_count"], 60)
        self.assertEqual(summary["sample_coverage_pct"], 100)
        self.assertNotIn(
            "RESULT_SAMPLE_INCONSISTENT",
            [item["code"] for item in summary["alerts"]],
        )

    def test_legacy_expected_samples_still_subtract_warmup(self):
        lines = [
            "WASPLAB|v1|START|run=legacy-coverage|duration=900|sampleSec=15|warmupSec=300\n"
        ]
        lines.extend(
            "WASPLAB|v1|SAMPLE|t=%s|fps=40\n" % (300 + (index * 15))
            for index in range(1, 41)
        )
        lines.append(
            "WASPLAB|v1|RESULT|run=legacy-coverage|status=PASS|fpsSamples=40|fpsExpected=40|fpsCoveragePct=100|complete=1\n"
        )

        summary = monitor.parse_last_run(lines).summary()
        self.assertEqual(summary["benchmark_sample_count"], 40)
        self.assertEqual(summary["expected_sample_count"], 40)
        self.assertNotIn(
            "RESULT_SAMPLE_INCONSISTENT",
            [item["code"] for item in summary["alerts"]],
        )

    def test_missing_result_is_incomplete_not_ok(self):
        summary = monitor.parse_last_run(
            ["WASPLAB|v1|START|run=incomplete\n", "WASPLAB|v1|SAMPLE|t=1|fps=45\n"]
        ).summary()
        self.assertIn("RUN_INCOMPLETE", [item["code"] for item in summary["alerts"]])
        self.assertFalse(summary["ok"])

    def test_pass_result_without_samples_is_not_ok(self):
        summary = monitor.parse_last_run(
            ["WASPLAB|v1|START|run=empty-pass\n", "WASPLAB|v1|RESULT|status=PASS\n"]
        ).summary()
        self.assertIn("NO_BENCHMARK_SAMPLES", [item["code"] for item in summary["alerts"]])
        self.assertFalse(summary["ok"])

    def test_result_must_have_status_and_matching_run_id(self):
        missing = monitor.parse_last_run(
            ["WASPLAB|v1|START|run=x\n", "WASPLAB|v1|SAMPLE|fps=40\n", "WASPLAB|v1|RESULT|run=x\n"]
        ).summary()
        self.assertIn("RESULT_STATUS_MISSING", [item["code"] for item in missing["alerts"]])
        mismatch = monitor.parse_last_run(
            ["WASPLAB|v1|START|run=x\n", "WASPLAB|v1|SAMPLE|fps=40\n", "WASPLAB|v1|RESULT|run=y|status=PASS\n"]
        ).summary()
        self.assertIn("RUN_ID_MISMATCH", [item["code"] for item in mismatch["alerts"]])

    def test_start_and_result_identity_aliases_are_consistent(self):
        for start_alias, result_alias in (
            ("run", "runId"),
            ("runId", "id"),
            ("id", "run"),
        ):
            with self.subTest(start_alias=start_alias, result_alias=result_alias):
                summary = monitor.parse_last_run([
                    "WASPLAB|v1|START|%s=x|duration=60|sampleSec=60|warmupSec=0\n" % start_alias,
                    "WASPLAB|v1|SAMPLE|t=60|fps=40\n",
                    "WASPLAB|v1|RESULT|%s=x|status=PASS|complete=1|fpsSamples=1|fpsExpected=1|fpsCoveragePct=100\n" % result_alias,
                ]).summary()
                self.assertEqual(summary["run"], "x")
                self.assertTrue(summary["ok"], summary["alerts"])

    def test_missing_start_identity_is_not_ok(self):
        summary = monitor.parse_last_run([
            "WASPLAB|v1|START|duration=60|sampleSec=60|warmupSec=0\n",
            "WASPLAB|v1|SAMPLE|t=60|fps=40\n",
            "WASPLAB|v1|RESULT|run=x|status=PASS|complete=1|fpsSamples=1|fpsExpected=1|fpsCoveragePct=100\n",
        ]).summary()
        self.assertIsNone(summary["run"])
        self.assertIn("START_RUN_MISSING", [item["code"] for item in summary["alerts"]])
        self.assertFalse(summary["ok"])

    def test_duplicate_fields_and_conflicting_identity_aliases_are_not_ok(self):
        duplicate = monitor.parse_last_run([
            "WASPLAB|v1|START|run=current|duration=60|sampleSec=60|warmupSec=0\n",
            "WASPLAB|v1|SAMPLE|run=stale|run=current|t=60|fps=-1|FPS=40\n",
            "WASPLAB|v1|RESULT|run=stale|run=current|status=FAIL|status=PASS|complete=0|complete=1|fpsSamples=1|fpsExpected=1|fpsCoveragePct=100\n",
        ]).summary()
        self.assertFalse(duplicate["ok"])
        self.assertIn("DUPLICATE_FIELD", [item["code"] for item in duplicate["alerts"]])

        for marker, expected_code in (
            (
                "WASPLAB|v1|START|run=current|runId=stale|duration=60|sampleSec=60|warmupSec=0",
                "START_RUN_ALIAS_CONFLICT",
            ),
            (
                "WASPLAB|v1|RESULT|run=current|runId=stale|status=PASS|complete=1|fpsSamples=1|fpsExpected=1|fpsCoveragePct=100",
                "EVENT_RUN_ALIAS_CONFLICT",
            ),
        ):
            with self.subTest(expected_code=expected_code):
                start = marker if "|START|" in marker else "WASPLAB|v1|START|run=current|duration=60|sampleSec=60|warmupSec=0"
                result = marker if "|RESULT|" in marker else "WASPLAB|v1|RESULT|run=current|status=PASS|complete=1|fpsSamples=1|fpsExpected=1|fpsCoveragePct=100"
                summary = monitor.parse_last_run([
                    start + "\n",
                    "WASPLAB|v1|SAMPLE|run=current|t=60|fps=40\n",
                    result + "\n",
                ]).summary()
                self.assertFalse(summary["ok"])
                self.assertIn(expected_code, [item["code"] for item in summary["alerts"]])

    def test_partition_records_require_run_identity_but_legacy_records_do_not(self):
        partition = monitor.parse_last_run([
            "WASPLAB|v1|START|run=partition|spawnAnchors=2|duration=60|sampleSec=60|warmupSec=0\n",
            "WASPLAB|v1|SAMPLE|phase=MEASURE|measureT=60|fps=40\n",
            "WASPLAB|v1|RESULT|run=partition|status=PASS|complete=1|fpsSamples=1|fpsExpected=1|fpsCoveragePct=100\n",
        ]).summary()
        self.assertFalse(partition["ok"])
        self.assertIn("EVENT_RUN_MISSING", [item["code"] for item in partition["alerts"]])

        legacy = monitor.parse_last_run([
            "WASPLAB|v1|START|run=legacy|duration=60|sampleSec=60|warmupSec=0\n",
            "WASPLAB|v1|SAMPLE|t=60|fps=40\n",
            "WASPLAB|v1|RESULT|run=legacy|status=PASS|complete=1|fpsSamples=1|fpsExpected=1|fpsCoveragePct=100\n",
        ]).summary()
        self.assertNotIn("EVENT_RUN_MISSING", [item["code"] for item in legacy["alerts"]])

    def test_non_result_event_run_mismatch_is_alerted_but_legacy_event_is_accepted(self):
        for run_field in ("run", "runId"):
            with self.subTest(run_field=run_field):
                mismatch = monitor.parse_last_run(
                    [
                        "WASPLAB|v1|START|run=current\n",
                        "WASPLAB|v1|SAMPLE|%s=stale|fps=40\n" % run_field,
                        "WASPLAB|v1|RESULT|run=current|status=PASS|complete=1\n",
                    ]
                ).summary()
                self.assertFalse(mismatch["ok"])
                self.assertIn(
                    "EVENT_RUN_MISMATCH",
                    [item["code"] for item in mismatch["alerts"]],
                )
                self.assertEqual(
                    "SAMPLE",
                    mismatch["protocol_alerts"][0]["fields"]["eventKind"],
                )

        legacy = monitor.parse_last_run(
            [
                "WASPLAB|v1|START|run=current\n",
                "WASPLAB|v1|SAMPLE|id=event-local|fps=40\n",
                "WASPLAB|v1|RESULT|run=current|status=PASS|complete=1\n",
            ]
        ).summary()
        self.assertTrue(legacy["ok"])
        self.assertNotIn(
            "EVENT_RUN_MISMATCH",
            [item["code"] for item in legacy["alerts"]],
        )

    def test_scheduler_records_are_summarized(self):
        lines = [
            "WASPLAB|v1|START|run=s|schedulerMode=active\n",
            "WASPLAB|v1|SCHED|elapsedMs=1.2|frameDelta=0|due=3|deferred=1|queued=3|oldestMs=4|overruns=0\n",
            "WASPLAB|v1|RESULT|status=PASS|schedulerMode=active|schedRuns=9|schedDeferred=2|schedOverruns=0|schedErrors=0|schedMaxElapsedMs=1.2\n",
        ]
        scheduler = monitor.parse_last_run(lines).summary()["scheduler"]
        self.assertEqual(scheduler["mode"], "active")
        self.assertEqual(scheduler["max_deferred"], 1)
        self.assertEqual(scheduler["runs"], 9)

    def test_new_boot_invalidates_previous_completed_run(self):
        lines = [
            "WASPLAB|v1|START|run=old\n",
            "WASPLAB|v1|RESULT|status=PASS\n",
            "WASPLAB|v1|BOOT|run=boot-new|phase=preinit\n",
            "WASPLAB|v1|ABORT|reason=init_timeout\n",
        ]
        summary = monitor.parse_last_run(lines).summary()
        self.assertEqual(summary["run"], "boot-new")
        codes = [item["code"] for item in summary["alerts"]]
        self.assertIn("RUN_INCOMPLETE", codes)
        self.assertIn("LAB_ABORT", codes)
        self.assertFalse(summary["ok"])

    def test_fatal_after_result_prevents_stale_pass(self):
        lines = [
            "WASPLAB|v1|START|run=old\n",
            "WASPLAB|v1|SAMPLE|t=1|fps=45\n",
            "WASPLAB|v1|RESULT|status=PASS\n",
            "Include file version.sqf not found\n",
        ]
        summary = monitor.parse_last_run(lines).summary()
        codes = [item["code"] for item in summary["alerts"]]
        self.assertIn("POST_RESULT_FATAL", codes)
        self.assertIn("INCLUDE_FILE_MISSING", codes)
        self.assertFalse(summary["ok"])

    def test_active_run_does_not_fail_coverage_before_result(self):
        lines = [
            "WASPLAB|v1|START|run=live|duration=600|sampleSec=10|warmupSec=60\n",
            "WASPLAB|v1|SAMPLE|t=70|fps=45\n",
        ]
        summary = monitor.parse_last_run(lines).summary(active=True)
        codes = [item["code"] for item in summary["alerts"]]
        self.assertIn("RUN_ACTIVE", codes)
        self.assertNotIn("SAMPLE_COVERAGE_LOW", codes)

    def test_result_gate_evidence_is_promoted(self):
        lines = [
            "WASPLAB|v1|START|run=gates|duration=20|sampleSec=10|warmupSec=0\n",
            "WASPLAB|v1|SAMPLE|t=10|fps=40|hcs=2|hcFpsMin=35|hcFresh=2\n",
            "WASPLAB|v1|SAMPLE|t=20|fps=38|hcs=2|hcFpsMin=34|hcFresh=2\n",
            "WASPLAB|v1|CLEANUP|objectsRemaining=0|groupsRemaining=0\n",
            "WASPLAB|v1|RESULT|run=gates|status=PASS|fpsSamples=2|fpsExpected=2|fpsCoveragePct=100|hcsMin=2|hcImbalanceMax=44|hcImbalancedPct=12.5|hcFpsSamples=2|hcFpsMin=34|stuckMax=3|stuckPctMax=15|combatInitial=20|combatCasualties=4|combatMovedGroups=3|combatMovedPct=75|cleanupObjectsRemaining=0|cleanupGroupsRemaining=0|complete=1\n",
        ]
        summary = monitor.parse_last_run(lines).summary()
        self.assertEqual(summary["sample_coverage_pct"], 100)
        self.assertEqual(summary["hc_balance"]["hcs_min"], 2)
        self.assertEqual(summary["hc_balance"]["imbalance_max"], 44)
        self.assertEqual(summary["hc_balance"]["imbalanced_pct"], 12.5)
        self.assertEqual(summary["hc_fps"]["min"], 34)
        self.assertEqual(summary["stuck"]["max_pct"], 15)
        self.assertEqual(summary["combat"]["casualties"], 4)
        self.assertEqual(summary["combat"]["moved_pct"], 75)
        self.assertEqual(summary["cleanup"]["objects_remaining"], 0)

    def test_pass_cannot_contradict_reported_coverage_or_hc_gates(self):
        lines = [
            "WASPLAB|v1|START|run=bad-pass|duration=20|sampleSec=10|warmupSec=0|busRate=1|expectedHcs=2|minHcFps=25\n",
            "WASPLAB|v1|SAMPLE|t=10|fps=40|ai=100|hcs=2\n",
            "WASPLAB|v1|SAMPLE|t=20|fps=40|ai=100|hcs=2\n",
            "WASPLAB|v1|RESULT|run=bad-pass|status=PASS|fpsSamples=2|fpsExpected=2|fpsCoveragePct=0|aiPeak=100|hcsMin=1|hcFpsSamples=0|hcFpsMin=-1|complete=1\n",
        ]
        summary = monitor.parse_last_run(lines).summary()
        codes = [item["code"] for item in summary["alerts"]]
        self.assertIn("RESULT_SAMPLE_INCONSISTENT", codes)
        self.assertIn("RESULT_GATE_CONTRADICTION", codes)
        self.assertFalse(summary["ok"])

    def test_unmeasured_hc_count_sentinel_is_not_reported_as_99_hcs(self):
        lines = [
            "WASPLAB|v1|START|run=low-ai\n",
            "WASPLAB|v1|SAMPLE|t=1|fps=45\n",
            "WASPLAB|v1|RESULT|run=low-ai|status=PASS|hcsMin=99|complete=1\n",
        ]
        summary = monitor.parse_last_run(lines).summary()
        self.assertIsNone(summary["hc_balance"]["hcs_min"])

    def test_phased_realization_work_and_routes_are_summarized(self):
        lines = [
            "WASPLAB|v1|START|run=old|targetSyntheticUnits=999\n",
            "WASPLAB|v1|COMPOSITION|finalMembers=999|histogram=999:1\n",
            "WASPLAB|v1|RESULT|run=old|status=PASS|complete=1\n",
            "WASPLAB|v1|START|run=partition|duration=20|sampleSec=10|warmupSec=0|targetSyntheticUnits=8|targetGroups=2|unitsPerGroup=4\n",
            "WASPLAB|v1|PHASE|t=0|phaseSeq=1|phase=SPAWN|targetSyntheticUnits=8|spawnAnchors=2\n",
            "WASPLAB|v1|REALIZED|group=1|anchor=0|routeId=Strelka>Airfield|requestedInfantry=4|createdInfantry=4|crew=0|vehicles=0|finalMembers=4|underfill=0|oversize=0|createFailures=0|createFailure=0\n",
            "WASPLAB|v1|REALIZED|group=2|anchor=1|routeId=Airfield>Kamenyy|requestedInfantry=4|createdInfantry=4|crew=0|vehicles=0|finalMembers=4|underfill=0|oversize=0|createFailures=0|createFailure=0\n",
            "WASPLAB|v1|COMPOSITION|t=10|phase=SETTLE|targetSyntheticUnits=8|realizedGroups=2|requestedInfantry=8|createdInfantry=8|crew=0|vehicles=0|finalMembers=8|histogram=4:2|underfillGroups=0|oversizeGroups=0|createFailures=0|createFailureGroups=0|anchorRequested=0:4,1:4|anchorMembers=0:4,1:4\n",
            "WASPLAB|v1|SAMPLE|t=15|phase=SETTLE|fps=1|memberSeconds=0|groupSeconds=0\n",
            "WASPLAB|v1|PHASE|t=20|phaseSeq=3|phase=GO|measureT=0|pathLegsStarted=2|routeIds=Strelka>Airfield;Airfield>Kamenyy\n",
            "WASPLAB|v1|PHASE|t=20|phaseSeq=4|phase=MEASURE|measureT=0\n",
            "WASPLAB|v1|PATHLEG|t=20|measureT=0|routeId=Strelka>Airfield|units=4|arrived=0|elapsed=0|status=STARTED\n",
            "WASPLAB|v1|PATHLEG|t=20|measureT=0|routeId=Airfield>Kamenyy|units=4|arrived=0|elapsed=0|status=STARTED\n",
            "WASPLAB|v1|SAMPLE|t=30|phase=MEASURE|measureT=10|fps=40|memberSeconds=80|groupSeconds=20|pathLegsStarted=2|routeIds=Strelka>Airfield;Airfield>Kamenyy\n",
            "WASPLAB|v1|PATHLEG|t=35|routeId=Strelka>Airfield|units=4|arrived=1|elapsed=15|status=ARRIVED\n",
            "WASPLAB|v1|SAMPLE|t=40|phase=MEASURE|measureT=20|fps=38|memberSeconds=160|groupSeconds=40|pathLegsStarted=2|arrivals=1\n",
            "WASPLAB|v1|PHASE|t=40|phaseSeq=5|phase=CLEANUP|measureT=20|memberSeconds=160|groupSeconds=40\n",
            "WASPLAB|v1|RESULT|run=partition|status=PASS|complete=1|fpsSamples=2|fpsExpected=2|fpsCoveragePct=100|targetSyntheticUnits=8|realizedGroups=2|requestedInfantry=8|createdInfantry=8|crew=0|vehicles=0|finalMembers=8|histogram=4:2|underfillGroups=0|oversizeGroups=0|createFailures=0|createFailureGroups=0|memberSeconds=160|groupSeconds=40|measureT=20|pathLegsStarted=2|arrivals=1|routeIds=Strelka>Airfield;Airfield>Kamenyy\n",
        ]
        state = monitor.parse_last_run(lines)
        summary = state.summary()

        self.assertEqual(len(state.phase_records), 4)
        self.assertEqual(len(state.realized_records), 2)
        self.assertEqual(len(state.composition_records), 1)
        self.assertEqual(summary["run"], "partition")
        self.assertEqual(summary["sample_count"], 3)
        self.assertEqual(summary["benchmark_sample_count"], 2)
        self.assertEqual(summary["measurement_sample_count"], 2)
        self.assertEqual(summary["fps"]["min"], 38)

        phase = summary["phase"]
        self.assertEqual(phase["sequence"], ["SPAWN", "GO", "MEASURE", "CLEANUP"])
        self.assertEqual(phase["current"], "CLEANUP")
        self.assertEqual(phase["measurement_started_phase"], "GO")
        self.assertEqual(phase["measurement_started_at"], 20)
        self.assertEqual(phase["measurement_phase"], "MEASURE")
        self.assertEqual(phase["measurement_seconds"], 20)

        composition = summary["composition"]
        self.assertEqual(composition["target_synthetic_units"], 8)
        self.assertEqual(composition["realized_groups"], 2)
        self.assertEqual(composition["requested_infantry"], 8)
        self.assertEqual(composition["created_infantry"], 8)
        self.assertEqual(composition["crew"], 0)
        self.assertEqual(composition["vehicles"], 0)
        self.assertEqual(composition["final_members"], 8)
        self.assertEqual(composition["histogram"], {"4": 2})
        self.assertEqual(composition["anchor_requested"], {"0": 4, "1": 4})
        self.assertEqual(composition["anchor_members"], {"0": 4, "1": 4})
        self.assertEqual(composition["underfill_groups"], 0)
        self.assertEqual(composition["oversize_groups"], 0)
        self.assertEqual(composition["create_failures"], 0)
        self.assertEqual(composition["create_failure_groups"], 0)
        self.assertEqual(composition["attainment_pct"], 100)

        realized = composition["realized_evidence"]
        self.assertEqual(realized["record_count"], 2)
        self.assertEqual(realized["valid_count"], 2)
        self.assertEqual(realized["group_ids"], [1, 2])
        self.assertEqual(realized["requested_infantry"], 8)
        self.assertEqual(realized["created_infantry"], 8)
        self.assertEqual(realized["crew"], 0)
        self.assertEqual(realized["vehicles"], 0)
        self.assertEqual(realized["final_members"], 8)
        self.assertEqual(realized["underfill_groups"], 0)
        self.assertEqual(realized["oversize_groups"], 0)
        self.assertEqual(realized["create_failures"], 0)
        self.assertEqual(realized["create_failure_groups"], 0)
        self.assertEqual(realized["histogram"], {"4": 2})
        self.assertEqual(realized["anchor_requested"], {"0": 4, "1": 4})
        self.assertEqual(realized["anchor_members"], {"0": 4, "1": 4})

        self.assertEqual(summary["work"]["member_seconds"], 160)
        self.assertEqual(summary["work"]["group_seconds"], 40)
        self.assertEqual(summary["work"]["average_members"], 8)
        self.assertEqual(summary["work"]["average_groups"], 2)
        sample_evidence = summary["work"]["sample_evidence"]
        self.assertEqual(sample_evidence["record_count"], 2)
        self.assertEqual(sample_evidence["member_seconds_count"], 2)
        self.assertEqual(sample_evidence["group_seconds_count"], 2)
        self.assertEqual(sample_evidence["latest_member_seconds"], 160)
        self.assertEqual(sample_evidence["latest_group_seconds"], 40)
        self.assertTrue(sample_evidence["member_seconds_monotonic"])
        self.assertTrue(sample_evidence["group_seconds_monotonic"])

        pathlegs = summary["pathlegs"]
        self.assertEqual(pathlegs["count"], 3)
        self.assertEqual(pathlegs["status"], {"STARTED": 2, "ARRIVED": 1})
        self.assertEqual(pathlegs["started"], 2)
        self.assertEqual(pathlegs["completed"], 1)
        self.assertEqual(pathlegs["completion_pct"], 50)
        self.assertEqual(pathlegs["arrival_units"], 4)
        self.assertEqual(pathlegs["arrival_pct"], 50)
        self.assertEqual(pathlegs["route_count"], 2)
        strelka_route = pathlegs["routes"]["Strelka>Airfield"]
        self.assertEqual(strelka_route["records"], 2)
        self.assertEqual(strelka_route["started"], 1)
        self.assertEqual(strelka_route["completed"], 1)
        self.assertEqual(strelka_route["arrival_pct"], 100)
        self.assertEqual(strelka_route["units"], 4)
        self.assertEqual(strelka_route["elapsed_median"], 15)
        kamenyy_route = pathlegs["routes"]["Airfield>Kamenyy"]
        self.assertEqual(kamenyy_route["records"], 1)
        self.assertEqual(kamenyy_route["started"], 1)
        self.assertEqual(kamenyy_route["completed"], 0)
        self.assertEqual(kamenyy_route["arrival_pct"], 0)
        self.assertEqual(kamenyy_route["units"], 0)
        self.assertIsNone(kamenyy_route["elapsed_median"])
        self.assertEqual(summary["result"]["targetSyntheticUnits"], 8)

    def test_realized_evidence_exposes_duplicate_and_malformed_rows(self):
        lines = [
            "WASPLAB|v1|START|run=bad-realized|targetSyntheticUnits=8|targetGroups=2|unitsPerGroup=4\n",
            "WASPLAB|v1|REALIZED|group=1|anchor=0|requestedInfantry=4|createdInfantry=4|crew=0|vehicles=0|finalMembers=4|underfill=0|oversize=0|createFailures=0|createFailure=0\n",
            "WASPLAB|v1|REALIZED|group=1|anchor=1|requestedInfantry=4|createdInfantry=4|crew=0|vehicles=0|underfill=0|oversize=0|createFailures=0|createFailure=0\n",
            "WASPLAB|v1|SAMPLE|phase=MEASURE|fps=40\n",
            "WASPLAB|v1|RESULT|run=bad-realized|status=PASS|complete=1\n",
        ]
        evidence = monitor.parse_last_run(lines).summary()["composition"]["realized_evidence"]
        self.assertEqual(evidence["record_count"], 2)
        self.assertEqual(evidence["valid_count"], 1)
        self.assertEqual(evidence["group_ids"], [1, 1])
        self.assertEqual(evidence["requested_infantry"], 4)
        self.assertEqual(evidence["histogram"], {"4": 1})
        self.assertEqual(evidence["anchor_requested"], {"0": 4})

    def test_realized_valid_count_rejects_sum_balanced_wrong_arm_rows(self):
        lines = [
            "WASPLAB|v1|START|run=balanced|targetSyntheticUnits=8|targetGroups=2|unitsPerGroup=4\n",
            "WASPLAB|v1|REALIZED|group=1|anchor=0|requestedInfantry=4|createdInfantry=3|crew=0|vehicles=0|finalMembers=3|underfill=0|oversize=0|createFailures=0|createFailure=0\n",
            "WASPLAB|v1|REALIZED|group=2|anchor=1|requestedInfantry=4|createdInfantry=5|crew=0|vehicles=0|finalMembers=5|underfill=0|oversize=0|createFailures=0|createFailure=0\n",
            "WASPLAB|v1|SAMPLE|phase=MEASURE|fps=40\n",
            "WASPLAB|v1|RESULT|run=balanced|status=PASS|complete=1|requestedInfantry=8|createdInfantry=8|finalMembers=8|histogram=4:2\n",
        ]
        evidence = monitor.parse_last_run(lines).summary()["composition"]["realized_evidence"]
        self.assertEqual(evidence["valid_count"], 0)
        self.assertEqual(evidence["requested_infantry"], 8)
        self.assertEqual(evidence["created_infantry"], 8)
        self.assertEqual(evidence["final_members"], 8)
        self.assertEqual(evidence["histogram"], {"3": 1, "5": 1})

    def test_sample_evidence_reports_missing_and_non_monotonic_counters(self):
        lines = [
            "WASPLAB|v1|START|run=bad-work\n",
            "WASPLAB|v1|SAMPLE|phase=MEASURE|measureT=10|fps=40|memberSeconds=90|groupSeconds=20\n",
            "WASPLAB|v1|SAMPLE|phase=MEASURE|measureT=20|fps=40|memberSeconds=80\n",
            "WASPLAB|v1|RESULT|run=bad-work|status=PASS|complete=1\n",
        ]
        evidence = monitor.parse_last_run(lines).summary()["work"]["sample_evidence"]
        self.assertEqual(evidence["record_count"], 2)
        self.assertEqual(evidence["member_seconds_count"], 2)
        self.assertEqual(evidence["group_seconds_count"], 1)
        self.assertEqual(evidence["latest_member_seconds"], 80)
        self.assertEqual(evidence["latest_group_seconds"], 20)
        self.assertFalse(evidence["member_seconds_monotonic"])
        self.assertTrue(evidence["group_seconds_monotonic"])

    def test_phase_measure_time_coverage_rejects_duplicate_unbounded_or_short_samples(self):
        cases = {
            "duplicate": [15, 15, 15, 15],
            "unbounded": [15, 30, 45, 90],
            "short": [1, 2, 3, 4],
            "missing": [15, 30, 45, None],
        }
        for name, values in cases.items():
            with self.subTest(name=name):
                lines = [
                    "WASPLAB|v1|START|run=measure-%s|duration=60|sampleSec=15|warmupSec=0\n" % name
                ]
                for index, value in enumerate(values, 1):
                    measure = "" if value is None else "|measureT=%s" % value
                    lines.append(
                        "WASPLAB|v1|SAMPLE|run=measure-%s|phase=MEASURE%s|fps=40|memberSeconds=%s|groupSeconds=%s\n"
                        % (name, measure, index * 10, index * 2)
                    )
                lines.append(
                    "WASPLAB|v1|RESULT|run=measure-%s|status=PASS|complete=1|fpsSamples=4|fpsExpected=4|fpsCoveragePct=100\n"
                    % name
                )
                summary = monitor.parse_last_run(lines).summary()
                self.assertFalse(summary["ok"])
                self.assertIn(
                    "MEASURE_TIME_INVALID",
                    [item["code"] for item in summary["alerts"]],
                )

    def test_per_attempt_realized_records_are_a_cumulative_fallback(self):
        lines = [
            "WASPLAB|v1|START|run=fallback|targetSyntheticUnits=8|targetGroups=2\n",
            "WASPLAB|v1|REALIZED|group=0|requestedInfantry=4|createdInfantry=4|crew=0|vehicles=0|finalMembers=4|underfill=0|oversize=0|createFailures=0\n",
            "WASPLAB|v1|REALIZED|group=1|requestedInfantry=4|createdInfantry=3|crew=2|vehicles=1|finalMembers=5|underfill=1|oversize=1|createFailures=1\n",
            "WASPLAB|v1|SAMPLE|phase=MEASURE|fps=40\n",
            "WASPLAB|v1|RESULT|run=fallback|status=PASS|complete=1\n",
        ]
        composition = monitor.parse_last_run(lines).summary()["composition"]
        self.assertEqual(composition["requested_infantry"], 8)
        self.assertEqual(composition["created_infantry"], 7)
        self.assertEqual(composition["crew"], 2)
        self.assertEqual(composition["vehicles"], 1)
        self.assertEqual(composition["final_members"], 9)
        self.assertEqual(composition["histogram"], {"4": 1, "5": 1})
        self.assertEqual(composition["underfill_groups"], 1)
        self.assertEqual(composition["oversize_groups"], 1)
        self.assertEqual(composition["create_failures"], 1)


class CommandLineTests(unittest.TestCase):
    def test_non_finite_or_non_positive_cli_thresholds_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "sample.rpt"
            path.write_text(
                "WASPLAB|v1|START|run=cli\n"
                "WASPLAB|v1|SAMPLE|fps=40\n"
                "WASPLAB|v1|RESULT|run=cli|status=PASS|complete=1\n",
                encoding="utf-8",
            )
            for option, value, message in (
                ("--min-fps", "nan", "--min-fps must be finite and greater than zero"),
                ("--min-fps", "0", "--min-fps must be finite and greater than zero"),
                ("--poll", "inf", "--poll must be finite and greater than zero"),
                ("--poll", "0", "--poll must be finite and greater than zero"),
            ):
                with self.subTest(option=option, value=value):
                    completed = subprocess.run(
                        [sys.executable, str(TOOL_DIR / "monitor.py"), str(path), option, value],
                        capture_output=True,
                        text=True,
                        check=False,
                    )
                    self.assertNotEqual(completed.returncode, 0)
                    self.assertIn(message, completed.stderr)

    def test_json_mode_is_agent_readable(self):
        completed = subprocess.run(
            [
                sys.executable,
                str(TOOL_DIR / "monitor.py"),
                str(SAMPLE),
                "--json",
                "--min-fps",
                "35",
            ],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        payload = json.loads(completed.stdout)
        self.assertEqual(payload["run"], "utes-path-001")
        self.assertEqual(payload["fps"]["min"], 30)

    def test_json_lines_offline_emits_one_summary_object(self):
        completed = subprocess.run(
            [
                sys.executable,
                str(TOOL_DIR / "monitor.py"),
                str(SAMPLE),
                "--json-lines",
            ],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        lines = completed.stdout.splitlines()
        self.assertEqual(len(lines), 1)
        payload = json.loads(lines[0])
        self.assertEqual(payload["type"], "summary")
        self.assertEqual(payload["run"], "utes-path-001")

    def test_empty_rpt_is_graceful(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "empty.rpt"
            path.write_text("unrelated line\n", encoding="utf-8")
            completed = subprocess.run(
                [sys.executable, str(TOOL_DIR / "monitor.py"), str(path), "--json"],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
        payload = json.loads(completed.stdout)
        self.assertFalse(payload["found"])
        self.assertEqual(payload["alerts"][0]["code"], "NO_START")

    def test_no_start_preserves_include_failure(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "failed.rpt"
            path.write_text('Include file version.sqf not found\n', encoding="utf-8")
            payload = monitor.empty_summary(str(path))
        codes = [item["code"] for item in payload["alerts"]]
        self.assertIn("NO_START", codes)
        self.assertIn("INCLUDE_FILE_MISSING", codes)


if __name__ == "__main__":
    unittest.main()
