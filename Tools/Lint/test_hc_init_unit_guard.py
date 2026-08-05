"""Regression contract for HC-safe unit initialization ordering."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Common" / "Init" / "Init_Unit.sqf"


class HcInitUnitGuardTests(unittest.TestCase):
    def test_hc_guard_precedes_all_initialization_waits(self):
        source = SOURCE.read_text(encoding="utf-8-sig")
        guard = 'if (!isNil "isHeadLessClient" && {isHeadLessClient}) exitWith {};'

        self.assertIn(guard, source)
        guard_at = source.index(guard)
        self.assertLess(guard_at, source.index("waitUntil {commonInitComplete};"))
        self.assertLess(guard_at, source.index('waitUntil {!isNil {_logik getVariable "wfbe_upgrades"}};'))


if __name__ == "__main__":
    unittest.main()
