#!/usr/bin/env python3
"""Static regression contracts for the 2026-07-22 residue-sweep fixes.

There is no SQF runtime in CI.  These assertions pin the source-level A2/OA-safe
guards for paradrop cleanup/abort handling and AI-defense refund atomicity.
"""

from pathlib import Path
import unittest

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
PARATROOPERS = MISSION / "Server" / "Support" / "Support_Paratroopers.sqf"
PARA_VEHICLES = MISSION / "Server" / "Support" / "Support_ParaVehicles.sqf"
PARA_AMMO = MISSION / "Server" / "Support" / "Support_ParaAmmo.sqf"
BASE = MISSION / "Server" / "AI" / "Commander" / "AI_Commander_Base.sqf"


def code(path: Path) -> str:
    return mask_comments(path.read_text(encoding="utf-8-sig"))


class ResidueParadropAndAicomRefundTests(unittest.TestCase):
    def test_paratrooper_last_cargo_does_not_select_past_transport_array(self) -> None:
        text = code(PARATROOPERS)
        self.assertIn("_index < ((count _vehicles) - 1)", text)

    def test_paratrooper_cleanup_captures_outer_transporter_before_inner_crew_loop(self) -> None:
        text = code(PARATROOPERS)
        self.assertIn("_transporter = _x;", text)
        self.assertIn("forEach crew _transporter", text)
        self.assertIn("deleteVehicle _transporter", text)

    def test_vehicle_and_ammo_abort_paths_are_gated_before_drop_or_return(self) -> None:
        for path in (PARA_VEHICLES, PARA_AMMO):
            text = code(path)
            self.assertIn("_dropReady = false;", text)
            self.assertIn("exitWith {_dropReady = true}", text)
            self.assertIn("if (_dropReady) then", text)

    def test_ammo_spawn_receives_side_id_explicitly(self) -> None:
        text = code(PARA_AMMO)
        self.assertIn("[_chopper,_ammo,_side,_sideID] Spawn", text)
        self.assertIn("_sideID = _this select 3;", text)

    def test_aicom_refunds_each_failed_defense_construction(self) -> None:
        text = code(BASE)
        self.assertGreaterEqual(text.count("Call ConstructDefense;"), 3)
        self.assertGreaterEqual(text.count("Call ChangeAICommanderFunds;"), 6)
        self.assertIn("isNull _defense", text)
        self.assertIn("isNull _artyObj", text)
        self.assertIn("isNull _fwdDefObj", text)


if __name__ == "__main__":
    unittest.main()
