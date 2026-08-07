"""Regression contracts for client-side resource teardown at mission end."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def read(relative_path: str) -> str:
    return (MISSION / relative_path).read_text(encoding="utf-8")


class ClientEndgameTeardownTests(unittest.TestCase):
    def test_patrol_marker_loop_stops_and_cleans_up_at_game_over(self) -> None:
        source = read("Client/FSM/updatepatrolmarkers.sqf")
        self.assertIn("waitUntil {gameOver ||", source)
        self.assertIn("while {!gameOver} do {", source)
        self.assertIn("} forEach _tracked;", source.rsplit("while {!gameOver} do {", 1)[1])
        self.assertIn("} forEach _trackedAir;", source.rsplit("while {!gameOver} do {", 1)[1])

    def test_artillery_rings_stop_and_clear_at_game_over(self) -> None:
        source = read("Client/Functions/Client_ArtyRangeRings.sqf")
        self.assertIn("while {!gameOver} do {", source)
        self.assertIn("{deleteMarkerLocal (_x select 1)} forEach _rings;", source.rsplit("while {!gameOver} do {", 1)[1])

    def test_ambulance_rings_stop_and_clear_at_game_over(self) -> None:
        source = read("Client/Functions/Client_AmbulanceRedeployCircles.sqf")
        self.assertIn("while {!gameOver} do {", source)
        self.assertIn("{deleteMarkerLocal (_x select 1)} forEach _rings;", source.rsplit("while {!gameOver} do {", 1)[1])

    def test_camp_repair_hint_stops_and_clears_at_game_over(self) -> None:
        source = read("Client/Functions/Client_CampRepairReadout.sqf")
        self.assertIn("while {!gameOver} do {", source)
        self.assertTrue(source.rstrip().endswith('hintSilent "";'))

    def test_tip_rotation_does_not_wait_or_post_through_game_over(self) -> None:
        source = read("Client/Functions/Client_TipRotation.sqf")
        self.assertIn("while {!gameOver} do {", source)
        self.assertIn("waitUntil {uiSleep 1; gameOver ||", source)
        self.assertNotIn("uiSleep _initial;", source)
        self.assertNotIn("uiSleep _period;", source)


if __name__ == "__main__":
    unittest.main()
