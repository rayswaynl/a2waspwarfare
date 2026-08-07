#!/usr/bin/env python3
"""Regression contract for one empty-vehicle reaper worker per object."""

from pathlib import Path
import unittest


MISSION = Path(__file__).resolve().parents[2] / "Missions/[55-2hc]warfarev2_073v48co.chernarus"
SOURCE = MISSION / "Server/Functions/Server_HandleEmptyVehicle.sqf"


class EmptyVehicleWorkerGuardTests(unittest.TestCase):
    def test_reaper_claims_object_before_delay_and_releases_at_terminal_exit(self) -> None:
        text = SOURCE.read_text(encoding="utf-8-sig")
        entry = text.index("_vehicle = _this select 0;")
        first_null_guard = text.index("if (isNull _vehicle) exitWith", entry)
        claim = text.index(
            'if (_vehicle getVariable ["wfbe_empty_vehicle_worker", false]) exitWith {};',
            first_null_guard,
        )
        claim_set = text.index(
            '_vehicle setVariable ["wfbe_empty_vehicle_worker", true];',
            claim,
        )
        delay = text.index("_delay =", claim_set)

        self.assertGreater(claim, first_null_guard)
        self.assertGreater(claim_set, claim)
        self.assertGreater(delay, claim_set)
        self.assertIn(
            '_vehicle setVariable ["wfbe_empty_vehicle_worker", false];',
            text[text.rfind("if (alive _vehicle) then {"):],
        )


if __name__ == "__main__":
    unittest.main()
