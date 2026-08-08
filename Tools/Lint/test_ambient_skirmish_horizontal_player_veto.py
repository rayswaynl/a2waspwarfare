"""Regression contract for ambient-spawn player visibility suppression."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
AMBIENT = Path("Server") / "Server_AmbientSkirmish.sqf"


class AmbientSkirmishHorizontalPlayerVetoTests(unittest.TestCase):
    def test_player_veto_uses_horizontal_distance_for_airborne_humans(self) -> None:
        for mission in MISSIONS:
            source = (mission / AMBIENT).read_text(encoding="utf-8-sig")
            start = source.index("if (!_tooClose) then {", source.index("if (surfaceIsWater _candidate)"))
            end = source.index("forEach allUnits;", start)
            veto = source[start:end]

            self.assertIn('"_playerRadius2","_playerPos","_playerDx","_playerDy"', source)
            self.assertIn("_playerRadius2 = _playerRadius * _playerRadius;", source)
            self.assertIn("_playerPos = getPos (vehicle _x);", veto)
            self.assertIn("_playerDx = (_playerPos select 0) - (_candidate select 0);", veto)
            self.assertIn("_playerDy = (_playerPos select 1) - (_candidate select 1);", veto)
            self.assertIn("if ((_playerDx * _playerDx + _playerDy * _playerDy) < _playerRadius2) then {_tooClose = true};", veto)
            self.assertNotIn("(vehicle _x) distance _candidate", veto)


if __name__ == "__main__":
    unittest.main()
