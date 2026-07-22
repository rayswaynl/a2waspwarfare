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
        # Original contract, unchanged: the restriction flag must be read LIVE inside the
        # waitUntil condition on every re-check, never snapshotted into a local beforehand.
        self.assertNotIn("_isrestricted =", source)
        waiter = source[source.index("waituntil {") : source.index("\n", source.index("waituntil {"))]
        self.assertIn('_vehicle getVariable ["restricted", false]', waiter)
        # Re-pinned 2026-07-21 (arty-lifecycle): the read is now behind a null/dead guard and uses
        # the 2-arg form. This watcher is a "GetIn" handler that routinely outlives its hull; on a
        # deleted vehicle the old 1-arg read returned Nothing and `Nothing && {...}` threw on every
        # re-check, forever. isNull must be tested FIRST and lazily so the getVariable never runs
        # against a null object (whose 2-arg default is ignored), and the waiter must terminate.
        self.assertTrue(waiter.startswith('waituntil {isNull _vehicle || {!alive _vehicle} || {'), waiter)
        self.assertLess(waiter.index("isNull _vehicle"), waiter.index("getVariable"))
        self.assertIn("if (isNull _vehicle || {!alive _vehicle}) exitWith {};", source)


if __name__ == "__main__":
    unittest.main()
