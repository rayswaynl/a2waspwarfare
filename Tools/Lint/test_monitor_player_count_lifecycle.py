#!/usr/bin/env python3
"""Contract for stopping the match-win player-count sampler at round end."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)


class MonitorPlayerCountLifecycleTests(unittest.TestCase):
    def test_sampler_stops_after_game_over_in_every_terrain(self) -> None:
        for mission in MISSIONS:
            source = (mission / "Server/MonitorPlayerCount.sqf").read_text(
                encoding="utf-8-sig"
            )

            self.assertIn("while {!WFBE_GameOver} do {", source, mission.name)
            self.assertNotIn("while {true} do {", source, mission.name)

    def test_terrain_mirrors_share_the_same_lifecycle_contract(self) -> None:
        sources = [
            (mission / "Server/MonitorPlayerCount.sqf").read_bytes()
            for mission in MISSIONS
        ]
        for source in sources:
            self.assertNotIn(b"\n", source.replace(b"\r\n", b""))
        self.assertTrue(all(source == sources[0] for source in sources[1:]))


if __name__ == "__main__":
    unittest.main()
