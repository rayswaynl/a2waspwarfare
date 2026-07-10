"""Regression tests for WASPLAB control/candidate comparisons."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


HERE = Path(__file__).resolve().parent
TOOL_DIR = HERE.parent
sys.path.insert(0, str(TOOL_DIR))

import compare


CONTROL = """\
00:00:00 \"WASPLAB|v1|START|run=old|scenario=wrong|map=Chernarus\"
00:00:01 \"WASPLAB|v1|SAMPLE|fps=1|ai=999|groups=99|hcPct=0|stuck=99\"
00:01:00 \"WASPLAB|v1|START|run=control|scenario=ai-scale|map=Utes|git=abc|source=src|lab=lab|workload=work|mode=path-loop|targetGroups=10|unitsPerGroup=6|busRate=1|expectedHcs=2|duration=2|sampleSec=1|warmupSec=0|minHcFps=25|paramSig=7|baselineAi=0|baselineGroups=0|baselineVehicles=0|performanceAudit=true\"
00:01:01 \"WASPLAB|v1|SAMPLE|fps=40|ai=100|groups=10|hcPct=50|hcs=2|hcFpsMin=40|hcFresh=2|hcImbalancePct=20|stuck=2\"
00:01:02 \"WASPLAB|v1|SAMPLE|fps=20|ai=120|groups=12|hcPct=40|hcs=2|hcFpsMin=38|hcFresh=2|hcImbalancePct=30|stuck=4\"
00:01:03 \"WASPLAB|v1|BUS|sentTotal=10|ackTotal=9|dropTotal=1|latencyMs=10\"
00:01:04 \"WASPLAB|v1|RESULT|run=control|status=PASS|fpsSamples=2|fpsExpected=2|fpsCoveragePct=100|hcsMin=2|hcFpsSamples=2|hcFpsMin=38|hcImbalanceMax=30|hcImbalancedPct=10|stuckPctMax=20|combatCasualties=0|combatMovedPct=0|cleanupObjectsRemaining=0|cleanupGroupsRemaining=0|busLoss=1|busLatencyAvgMs=10|complete=1\"
"""

CANDIDATE = """\
00:02:00 \"WASPLAB|v1|START|run=candidate|scenario=ai-scale|map=Utes|git=abc|source=src|lab=lab|workload=work|mode=path-loop|targetGroups=10|unitsPerGroup=6|busRate=1|expectedHcs=2|duration=2|sampleSec=1|warmupSec=0|minHcFps=25|paramSig=7|baselineAi=0|baselineGroups=0|baselineVehicles=0|performanceAudit=true\"
00:02:01 \"WASPLAB|v1|SAMPLE|fps=45|ai=110|groups=13|hcPct=55|hcs=2|hcFpsMin=44|hcFresh=2|hcImbalancePct=10|stuck=1\"
00:02:02 \"WASPLAB|v1|SAMPLE|fps=25|ai=132|groups=15|hcPct=45|hcs=2|hcFpsMin=42|hcFresh=2|hcImbalancePct=15|stuck=3\"
00:02:03 \"WASPLAB|v1|BUS|sentTotal=10|ackTotal=8|dropTotal=2|latencyMs=8\"
00:02:04 \"WASPLAB|v1|RESULT|run=candidate|status=PASS|fpsSamples=2|fpsExpected=2|fpsCoveragePct=100|hcsMin=2|hcFpsSamples=2|hcFpsMin=42|hcImbalanceMax=15|hcImbalancedPct=0|stuckPctMax=10|combatCasualties=0|combatMovedPct=0|cleanupObjectsRemaining=0|cleanupGroupsRemaining=0|busLoss=2|busLatencyAvgMs=8|complete=1\"
"""


class CompareTests(unittest.TestCase):
    def _write_pair(self, directory, control=CONTROL, candidate=CANDIDATE):
        control_path = Path(directory) / "control.rpt"
        candidate_path = Path(directory) / "candidate.rpt"
        control_path.write_text(control, encoding="utf-8")
        candidate_path.write_text(candidate, encoding="utf-8")
        return control_path, candidate_path

    def test_compares_only_last_run_and_all_required_metrics(self):
        with tempfile.TemporaryDirectory() as directory:
            paths = self._write_pair(directory)
            result = compare.compare_files(str(paths[0]), str(paths[1]))

        self.assertEqual(result["control"]["run"], "control")
        self.assertEqual(result["candidate"]["run"], "candidate")
        expected_keys = {
            "fps_median",
            "fps_min",
            "fps_p5",
            "sample_coverage_pct",
            "ai_peak",
            "groups_peak",
            "hc_pct_median",
            "hc_pct_min",
            "hc_fps_min",
            "hcs_min",
            "hc_imbalance",
            "hc_imbalance_max",
            "hc_imbalanced_pct",
            "hc_group_imbalance",
            "max_stuck",
            "max_stuck_pct",
            "combat_casualties",
            "combat_moved_pct",
            "cleanup_objects",
            "cleanup_groups",
            "bus_loss",
            "bus_latency_ms",
            "bus_attainment_pct",
            "sched_deferred",
            "sched_overruns",
            "sched_elapsed_ms",
        }
        self.assertEqual(set(result["metrics"]), expected_keys)

        self.assertEqual(
            result["metrics"]["fps_median"],
            {
                "label": "FPS median",
                "control": 30,
                "candidate": 35,
                "delta": 5,
                "percent": 16.667,
            },
        )
        self.assertEqual(result["metrics"]["fps_min"]["percent"], 25)
        self.assertEqual(result["metrics"]["fps_p5"]["control"], 21)
        self.assertEqual(result["metrics"]["ai_peak"]["percent"], 10)
        self.assertEqual(result["metrics"]["groups_peak"]["delta"], 3)
        self.assertEqual(result["metrics"]["hc_pct_median"]["delta"], 5)
        self.assertEqual(result["metrics"]["hc_pct_min"]["candidate"], 45)
        self.assertEqual(result["metrics"]["hc_fps_min"]["delta"], 4)
        self.assertEqual(result["metrics"]["hc_imbalance_max"]["delta"], -15)
        self.assertEqual(result["metrics"]["max_stuck_pct"]["delta"], -10)
        self.assertEqual(result["metrics"]["max_stuck"]["delta"], -1)
        self.assertEqual(result["metrics"]["bus_loss"]["percent"], 100)
        self.assertEqual(result["metrics"]["bus_latency_ms"]["percent"], -20)
        self.assertTrue(result["ok"])

    def test_warns_on_mismatch_fatal_and_nonpassing_result(self):
        candidate = CANDIDATE.replace("scenario=ai-scale", "scenario=path-mixed")
        candidate = candidate.replace("map=Utes", "map=Chernarus")
        candidate = candidate.replace(
            '00:02:04 "WASPLAB',
            "00:02:03 Error in expression <_bad>\n00:02:04 \"WASPLAB",
        ).replace("status=PASS", "status=FAIL")
        with tempfile.TemporaryDirectory() as directory:
            paths = self._write_pair(directory, candidate=candidate)
            result = compare.compare_files(str(paths[0]), str(paths[1]))

        codes = {warning["code"] for warning in result["warnings"]}
        self.assertIn("SCENARIO_MISMATCH", codes)
        self.assertIn("MAP_MISMATCH", codes)
        self.assertIn("CANDIDATE_FATAL", codes)
        self.assertIn("CANDIDATE_RESULT_FAIL", codes)
        self.assertFalse(result["ok"])

    def test_missing_metrics_and_zero_control_are_graceful(self):
        control = """\
WASPLAB|v1|START|run=zero|scenario=smoke|map=Utes
WASPLAB|v1|SAMPLE|fps=0
WASPLAB|v1|RESULT|status=PASS
"""
        candidate = """\
WASPLAB|v1|START|run=sparse|scenario=smoke|map=Utes
WASPLAB|v1|SAMPLE|fps=10
WASPLAB|v1|RESULT|status=PASS
"""
        with tempfile.TemporaryDirectory() as directory:
            paths = self._write_pair(directory, control, candidate)
            result = compare.compare_files(str(paths[0]), str(paths[1]))

        self.assertEqual(result["metrics"]["fps_min"]["delta"], 10)
        self.assertIsNone(result["metrics"]["fps_min"]["percent"])
        self.assertIsNone(result["metrics"]["ai_peak"]["control"])
        self.assertIsNone(result["metrics"]["ai_peak"]["delta"])
        self.assertIsNone(result["metrics"]["bus_loss"]["candidate"])

    def test_no_start_is_reported_without_crashing(self):
        with tempfile.TemporaryDirectory() as directory:
            paths = self._write_pair(directory, control="ordinary RPT output\n")
            result = compare.compare_files(str(paths[0]), str(paths[1]))
        self.assertEqual(result["warnings"][0]["code"], "CONTROL_NO_START")
        self.assertFalse(result["control"]["found"])

    def test_recipe_shaping_mismatch_is_not_certified(self):
        control = CONTROL.replace("unitsPerGroup=6", "unitsPerGroup=4")
        candidate = CANDIDATE.replace("targetGroups=10", "targetGroups=100")
        candidate = candidate.replace("unitsPerGroup=6", "unitsPerGroup=12")
        candidate = candidate.replace("expectedHcs=2", "expectedHcs=0")
        candidate = candidate.replace("git=abc", "git=def")
        with tempfile.TemporaryDirectory() as directory:
            paths = self._write_pair(directory, control, candidate)
            result = compare.compare_files(str(paths[0]), str(paths[1]))
        codes = {warning["code"] for warning in result["warnings"]}
        self.assertIn("TARGETGROUPS_MISMATCH", codes)
        self.assertIn("UNITSPERGROUP_MISMATCH", codes)
        self.assertIn("EXPECTEDHCS_MISMATCH", codes)
        self.assertIn("GIT_MISMATCH", codes)
        self.assertFalse(result["ok"])

    def test_missing_result_is_a_warning(self):
        incomplete = CANDIDATE.rsplit("\n", 2)[0] + "\n"
        with tempfile.TemporaryDirectory() as directory:
            paths = self._write_pair(directory, candidate=incomplete)
            result = compare.compare_files(str(paths[0]), str(paths[1]))
        self.assertIn(
            "CANDIDATE_RUN_INCOMPLETE",
            {warning["code"] for warning in result["warnings"]},
        )

    def test_monitor_protocol_failure_cannot_be_false_certified(self):
        candidate = CANDIDATE.replace("run=candidate|status=PASS", "run=wrong")
        with tempfile.TemporaryDirectory() as directory:
            paths = self._write_pair(directory, candidate=candidate)
            result = compare.compare_files(str(paths[0]), str(paths[1]))
        codes = {warning["code"] for warning in result["warnings"]}
        self.assertIn("CANDIDATE_RESULT_STATUS_MISSING", codes)
        self.assertIn("CANDIDATE_RUN_ID_MISMATCH", codes)
        self.assertFalse(result["ok"])

    def test_pass_with_reported_gate_contradiction_is_not_certified(self):
        candidate = CANDIDATE.replace("fpsCoveragePct=100", "fpsCoveragePct=0")
        with tempfile.TemporaryDirectory() as directory:
            paths = self._write_pair(directory, candidate=candidate)
            result = compare.compare_files(str(paths[0]), str(paths[1]))
        codes = {warning["code"] for warning in result["warnings"]}
        self.assertIn("CANDIDATE_RESULT_GATE_CONTRADICTION", codes)
        self.assertIn("CANDIDATE_RESULT_SAMPLE_INCONSISTENT", codes)
        self.assertFalse(result["ok"])

    def test_cli_json_and_human_output(self):
        with tempfile.TemporaryDirectory() as directory:
            control_path, candidate_path = self._write_pair(directory)
            completed = subprocess.run(
                [
                    sys.executable,
                    str(TOOL_DIR / "compare.py"),
                    str(control_path),
                    str(candidate_path),
                    "--json",
                ],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            payload = json.loads(completed.stdout)
            human = subprocess.run(
                [
                    sys.executable,
                    str(TOOL_DIR / "compare.py"),
                    str(control_path),
                    str(candidate_path),
                ],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            ).stdout

        self.assertEqual(payload["metrics"]["fps_median"]["candidate"], 35)
        self.assertIn("FPS median", human)
        self.assertIn("Comparable runs; no warnings", human)


if __name__ == "__main__":
    unittest.main()
