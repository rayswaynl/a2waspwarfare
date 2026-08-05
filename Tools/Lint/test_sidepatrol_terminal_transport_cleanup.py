#!/usr/bin/env python3
"""Regression contract for side-patrol terminal transport cleanup."""

from pathlib import Path
import unittest

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
PATROL = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Common" / "Functions" / "Common_RunSidePatrol.sqf"


class SidePatrolTerminalTransportCleanupTests(unittest.TestCase):
    def test_terminal_cleanup_reaps_created_transport_after_ai_units(self) -> None:
        text = mask_comments(PATROL.read_text(encoding="utf-8-sig"))
        terminal = text[text.index('["sidepatrol-ended", _sideID, _ldr]'):]
        unit_cleanup = terminal.index('} forEach (units _team);')
        self.assertIn('} forEach _vehicles;', terminal)
        vehicle_cleanup = terminal.index('} forEach _vehicles;')

        self.assertLess(unit_cleanup, vehicle_cleanup)
        vehicle_block = terminal[unit_cleanup:vehicle_cleanup]
        self.assertIn('private "_cleanupVehicle";', vehicle_block)
        self.assertIn('({isPlayer _x} count (crew _cleanupVehicle)) == 0', vehicle_block)


if __name__ == "__main__":
    unittest.main()
