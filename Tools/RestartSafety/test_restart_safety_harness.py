#!/usr/bin/env python3
"""Unit tests for Tools/RestartSafety/restart_safety_harness.py"""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

from restart_safety_harness import (
    ROOT,
    SUPERVISOR,
    analyze_loop,
    main,
    run_all,
    run_economy_cases,
    run_groupsgc_cases,
    run_town_cases,
    run_upgrade_cases,
    static_check_supervisor,
)


class TestRestartSafetyHarness(unittest.TestCase):
    def test_repo_root_has_supervisor(self):
        self.assertTrue(SUPERVISOR.is_file(), f"missing {SUPERVISOR}")
        text = SUPERVISOR.read_text(encoding="utf-8")
        self.assertIn("groupsgc", text)
        self.assertIn("WFBE_C_CORELOOP_RESTART_", text)

    def test_supervisor_static_all_ok(self):
        checks = static_check_supervisor()
        bad = [c for c in checks if not c["ok"]]
        self.assertEqual(bad, [], msg=bad)

    def test_economy_detects_double_charge(self):
        cases = run_economy_cases()
        fails = [c for c in cases if c.outcome == "fail"]
        self.assertTrue(fails, "economy model must fail at least one mid-pay crash point")
        # kill after first side pay must overpay that side
        pay_west = next(c for c in cases if c.step == "pay_WEST")
        self.assertEqual(pay_west.outcome, "fail")

    def test_groupsgc_all_pass(self):
        cases = run_groupsgc_cases()
        self.assertTrue(cases)
        self.assertTrue(all(c.outcome == "pass" for c in cases), cases)

    def test_groupsgc_verdict_green(self):
        rep = analyze_loop("groupsgc")
        self.assertEqual(rep.verdict, "GREEN")
        self.assertEqual(rep.arm_recommendation, "keep-auto-restart")

    def test_economy_verdict_red(self):
        rep = analyze_loop("economy")
        self.assertEqual(rep.verdict, "RED")
        self.assertTrue(rep.arm_recommendation.startswith("stay"))

    def test_upgrade_no_double_grant_or_stuck_classified(self):
        cases = run_upgrade_cases()
        self.assertTrue(cases)
        # Must not silently pass a double-start
        for c in cases:
            if c.outcome == "fail":
                self.assertTrue(
                    c.upgrade_starts > 1 or c.funds_delta > 0,
                    c.detail,
                )

    def test_town_no_double_flip(self):
        cases = run_town_cases()
        flips_fail = [c for c in cases if c.outcome == "fail"]
        self.assertEqual(flips_fail, [], flips_fail)

    def test_run_all_shape(self):
        report = run_all()
        self.assertEqual(len(report["loops"]), 4)
        self.assertTrue(report["summary"]["supervisor_static_ok"])
        ids = {r["loop_id"] for r in report["loops"]}
        self.assertEqual(ids, {"town", "economy", "upgrade", "groupsgc"})

    def test_cli_writes_artifacts(self):
        out_dir = ROOT / "docs" / "Proposals" / "wasp-restart-safety-harness-20260722"
        md = out_dir / "EVIDENCE-cli-test.md"
        js = out_dir / "EVIDENCE-cli-test.json"
        if md.exists():
            md.unlink()
        if js.exists():
            js.unlink()
        rc = main(["--md", str(md), "--json", str(js), "--quiet"])
        self.assertEqual(rc, 0)
        self.assertTrue(md.is_file())
        self.assertTrue(js.is_file())
        data = json.loads(js.read_text(encoding="utf-8"))
        self.assertIn("flip_table", data)
        text = md.read_text(encoding="utf-8")
        self.assertIn("Per-loop verdict table", text)
        # cleanup test-only names; leave main EVIDENCE.* for the PR
        md.unlink()
        js.unlink()


if __name__ == "__main__":
    unittest.main()
