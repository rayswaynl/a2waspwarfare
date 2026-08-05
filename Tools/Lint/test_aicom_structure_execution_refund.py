#!/usr/bin/env python3
"""Contract for AICOM refunds after asynchronous structure-construction failure."""

from pathlib import Path
import unittest

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
BASE = (
    ROOT
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Server"
    / "AI"
    / "Commander"
    / "AI_Commander_Base.sqf"
)


class AicomStructureExecutionRefundTests(unittest.TestCase):
    def test_async_base_and_forward_builds_observe_worker_failure_before_refund(self) -> None:
        source = mask_comments(BASE.read_text(encoding="utf-8-sig"))

        self.assertGreaterEqual(source.count("wfbe_aicom_build_result_"), 2)
        self.assertGreaterEqual(source.count("_completionResultKey"), 2)
        self.assertIn("missionNamespace getVariable _resultKey", source)
        self.assertGreaterEqual(source.count("Call ChangeSideSupply"), 4)
        self.assertIn("wfbe_aicom_built_%1", source)
        self.assertIn("wfbe_aicom_fwdbuilt_%1", source)
        self.assertIn("AICOM_BUILD_FAIL", source)
        self.assertIn("AICOM_BUILD_TIMEOUT", source)


if __name__ == "__main__":
    unittest.main()
