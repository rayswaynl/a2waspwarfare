#!/usr/bin/env python3
"""Static contract for the GUER paradrop request-to-creation stale-state guard."""

from pathlib import Path
import unittest

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Server" / "Server_GuerAirDef.sqf"


class GuerAirDefParadropRevalidationTests(unittest.TestCase):
    def test_delayed_paradrop_rechecks_town_state_before_creating_units(self) -> None:
        text = mask_comments(SOURCE.read_text(encoding="utf-8-sig"))
        wait_at = text.index("sleep 20;")
        create_at = text.index("Call WFBE_CO_FNC_CreateUnit", wait_at)
        guard = '''if (isNull _t || {(_t getVariable ["sideID", -1]) != WFBE_C_GUER_ID} || {!(_t getVariable ["wfbe_active", false])}) exitWith {'''
        guard_at = text.index(guard, wait_at)
        self.assertLess(wait_at, guard_at)
        self.assertLess(guard_at, create_at)
        self.assertIn("deleteGroup _g;", text[guard_at:create_at])


if __name__ == "__main__":
    unittest.main()
