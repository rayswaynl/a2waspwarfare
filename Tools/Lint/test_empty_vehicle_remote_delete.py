#!/usr/bin/env python3
"""Regression contract for locality-aware empty-vehicle reaping."""

from pathlib import Path
import unittest


MISSION = Path(__file__).resolve().parents[2] / "Missions/[55-2hc]warfarev2_073v48co.chernarus"
REAPER = MISSION / "Server/Functions/Server_HandleEmptyVehicle.sqf"
PVF = MISSION / "Client/Functions/Client_HandlePVF.sqf"
RECEIVER = MISSION / "Client/PVFunctions/HandleSpecial.sqf"


class EmptyVehicleRemoteDeleteTests(unittest.TestCase):
    def test_reaper_keeps_local_delete_direct_and_remote_delete_bounded(self) -> None:
        text = REAPER.read_text(encoding="utf-8-sig")

        self.assertIn("_reapAttempts = 0;", text)
        self.assertIn("_maxReapAttempts = 3;", text)
        self.assertIn("if (local _vehicle) then {", text)
        self.assertIn("deleteVehicle _vehicle;", text)
        self.assertIn("} else {", text)
        self.assertIn(
            '[_vehicle, "HandleSpecial", ["cleanup-empty-vehicle", _vehicle]] Call WFBE_CO_FNC_SendToClient;',
            text,
        )
        self.assertIn("_reapAttempts = _reapAttempts + 1;", text)
        self.assertNotIn(
            'if (_timer > _delay) exitWith {emptyQueu = emptyQueu - [_vehicle];',
            text,
        )

    def test_hc_allowlist_and_receiver_validate_empty_hull_dispatch(self) -> None:
        pvf = PVF.read_text(encoding="utf-8-sig")
        receiver = RECEIVER.read_text(encoding="utf-8-sig")

        self.assertIn('"cleanup-empty-vehicle"', pvf)
        self.assertIn('case "cleanup-empty-vehicle":', receiver)
        self.assertIn('local _emptyVehicle', receiver)
        self.assertIn('{({alive _x} count crew _emptyVehicle) == 0}', receiver)
        self.assertIn('_emptyVehicle getVariable ["wfbe_airlifted", false]', receiver)
        self.assertIn('_emptyVehicle getVariable ["wfbe_is_guer_fob", false]', receiver)
        self.assertIn('_emptyVehicle getVariable ["wfbe_empty_vehicle_reap", false]', receiver)


if __name__ == "__main__":
    unittest.main()
