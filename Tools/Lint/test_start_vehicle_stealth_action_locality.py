#!/usr/bin/env python3
"""Static regression checks for the starting-vehicle stealth scroll action."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


class StartVehicleStealthActionLocalityTests(unittest.TestCase):
    def test_start_vehicle_stealth_action_is_registered_in_client_init(self):
        server_init = (MISSION / "Server" / "Init" / "Init_Server.sqf").read_text(encoding="utf-8")
        unit_init = (MISSION / "Common" / "Init" / "Init_Unit.sqf").read_text(encoding="utf-8")

        self.assertNotIn('"Client\\Module\\Engines\\Stopengine.sqf"', server_init)
        self.assertNotIn('"Client\\Module\\Engines\\Engine.sqf"', server_init)
        self.assertIn('"wfbe_engine_stealth_action"', server_init)
        self.assertIn('"wfbe_engine_stealth_action"', unit_init)
        self.assertIn('"Client\\Module\\Engines\\Stopengine.sqf"', unit_init)
        self.assertIn('"Client\\Module\\Engines\\Engine.sqf"', unit_init)


if __name__ == "__main__":
    unittest.main()
