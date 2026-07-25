#!/usr/bin/env python3
"""Regression contract for round-3 empty-queue, town-defense locality, and build-marker drift."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
CH = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
TK = ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan"
ZG = ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad"


def raw(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


class Round3SalvageLeakTests(unittest.TestCase):
    def test_empty_vehicle_early_exits_dequeue_the_vehicle(self) -> None:
        text = raw(CH / "Server/Functions/Server_HandleEmptyVehicle.sqf")
        self.assertIn(
            "if (isNull _vehicle) exitWith {emptyQueu = emptyQueu - [_vehicle];};",
            text,
        )
        self.assertIn(
            "if (_timer > _delay) exitWith {emptyQueu = emptyQueu - [_vehicle];",
            text,
        )

    def test_remote_town_defense_gunner_uses_validated_owner_cleanup(self) -> None:
        server = raw(CH / "Server/Functions/Server_OperateTownDefensesUnits.sqf")
        pvf = raw(CH / "Client/Functions/Client_HandlePVF.sqf")
        receiver = raw(CH / "Client/PVFunctions/HandleSpecial.sqf")
        self.assertIn('"cleanup-town-defense-gunner"', server)
        self.assertIn("local _unit", server)
        self.assertIn('"cleanup-town-defense-gunner"', pvf)
        self.assertIn('case "cleanup-town-defense-gunner"', receiver)
        self.assertIn("WFBE_IsTownDefenderAI", receiver)
        self.assertIn("local _gunner", receiver)
        self.assertIn("!isPlayer _gunner", receiver)

    def test_build_91_markers_are_reconciled_across_tracked_sources(self) -> None:
        tracked = [
            CH / "version.sqf.template",
            CH / "initJIPCompatible.sqf",
            CH / "Server/Init/Init_Server.sqf",
            CH / "mission.sqm",
            TK / "mission.sqm",
            ZG / "mission.sqm",
        ]
        contents = "\n".join(raw(path) for path in tracked)
        self.assertNotIn("build89-cmdcon44", contents)
        self.assertIn("build91-cmdcon44", contents)
        for mission in (CH, TK, ZG):
            self.assertIn("Build 91", raw(mission / "mission.sqm"))


if __name__ == "__main__":
    unittest.main()
