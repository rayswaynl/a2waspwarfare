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


class CommandLineTests(unittest.TestCase):
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
