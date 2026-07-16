import importlib.util
import json
import os
import tempfile
import unittest


MODULE_PATH = os.path.join(os.path.dirname(__file__), "analyze_client_frame_telemetry.py")
SPEC = importlib.util.spec_from_file_location("client_frame_telemetry", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class ClientFrameTelemetryTests(unittest.TestCase):
    def test_percentiles_and_one_percent_low_proxy(self):
        line = "2026-07-13 12:00:00 CLIENTFRAME|v1|sid=s1|map=Chernarus|frameMs=10,20,30,40,100|mapOpenPct=0.2|gpsOpenPct=0|dialogOpenPct=0|ttPlayable=12.5"
        row = MODULE.parse_frame_line(line)
        summary = MODULE.summarize([row])
        self.assertEqual(summary["frameSamples"], 5)
        self.assertEqual(summary["frameTimeMs"]["p50"], 30.0)
        self.assertEqual(summary["frameTimeMs"]["p99"], 97.6)
        self.assertEqual(summary["fps"]["p01LowProxy"], round(1000.0 / 97.6, 3))
        self.assertEqual(summary["longFrames"]["over100ms"], 1)
        self.assertEqual(summary["timeToPlayableSec"], 12.5)

    def test_runtime_sidecar_matches_timestamped_rpt(self):
        line = "2026-07-13 12:00:00 CLIENTFRAME|v1|sid=s1|map=Takistan|frameMs=16,20|mapOpenPct=1|gpsOpenPct=0|dialogOpenPct=0"
        row = MODULE.parse_frame_line(line)
        runtime = [{
            "wallTime": "2026-07-13T12:00:05",
            "processCpuPct": 42.5,
            "workingSetMb": 1536,
            "hardwareTier": "mid",
        }]
        summary = MODULE.summarize([row], runtime, max_gap_seconds=10)
        self.assertEqual(summary["runtimeCorrelation"]["status"], "matched")
        self.assertEqual(summary["runtimeCorrelation"]["hardwareTier"], "mid")
        self.assertEqual(summary["runtimeCorrelation"]["processCpuPctAvg"], 42.5)

    def test_no_rows_is_explicit(self):
        summary = MODULE.summarize([])
        self.assertEqual(summary["status"], "no_data")
        self.assertIsNone(summary["frameTimeMs"]["p95"])
        self.assertEqual(summary["runtimeCorrelation"]["status"], "not_provided")

    def test_cli_writes_json_and_markdown(self):
        with tempfile.TemporaryDirectory() as directory:
            rpt = os.path.join(directory, "client.rpt")
            output = os.path.join(directory, "summary.json")
            with open(rpt, "w", encoding="utf-8") as handle:
                handle.write("12:00:00 CLIENTFRAME|v1|sid=s1|map=Zargabad|frameMs=20,25|mapOpenPct=0|gpsOpenPct=1|dialogOpenPct=0\n")
            self.assertEqual(MODULE.main([rpt, "--output", output]), 0)
            with open(output, "r", encoding="utf-8") as handle:
                value = json.load(handle)
            self.assertEqual(value["map"], "Zargabad")
            self.assertTrue(os.path.exists(os.path.splitext(output)[0] + ".md"))


if __name__ == "__main__":
    unittest.main()
