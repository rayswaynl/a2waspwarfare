#!/usr/bin/env python3
"""Regression check for the artillery GetIn restriction waiter."""

from pathlib import Path
import unittest


HANDLER = (
    Path(__file__).resolve().parents[2]
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Common"
    / "Functions"
    / "Common_HandleArty.sqf"
)


class HandleArtyLiveRestrictionTests(unittest.TestCase):
    def test_waiter_reads_live_restriction_flag(self) -> None:
        source = HANDLER.read_text(encoding="utf-8-sig")
        self.assertNotIn("_isrestricted =", source)
        self.assertIn('_vehicle getVariable "restricted"', source)
        self.assertIn('waituntil {(_vehicle getVariable "restricted")', source)


if __name__ == "__main__":
    unittest.main()
