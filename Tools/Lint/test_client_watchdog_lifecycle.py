#!/usr/bin/env python3
"""Contract for client watchdog termination at mission end."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)


class ClientWatchdogLifecycleTests(unittest.TestCase):
    def test_player_ai_watchdog_stops_and_releases_latch_at_game_over(self) -> None:
        for mission in MISSIONS:
            source = (mission / "Client/Functions/Client_WatchdogPlayerAI.sqf").read_text(
                encoding="utf-8-sig"
            )

            self.assertIn("while {!gameOver} do {", source, mission.name)
            self.assertIn(
                'missionNamespace setVariable ["Player_AI_Watchdog_Running", false];',
                source,
                mission.name,
            )

    def test_command_bar_watchdog_is_the_lifecycle_baseline(self) -> None:
        for mission in MISSIONS:
            source = (mission / "Client/Functions/Client_WatchdogCommandBarDeadUnits.sqf").read_text(
                encoding="utf-8-sig"
            )
            self.assertIn("while {!gameOver} do {", source, mission.name)


if __name__ == "__main__":
    unittest.main()
