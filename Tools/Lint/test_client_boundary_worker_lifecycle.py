#!/usr/bin/env python3
"""Contract for the client boundary worker's mission-end cleanup."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)


class ClientBoundaryWorkerLifecycleTests(unittest.TestCase):
    def test_boundary_worker_stops_and_releases_latch_at_game_over(self) -> None:
        for mission in MISSIONS:
            source = (mission / "Client/Functions/Client_HandleOnMap.sqf").read_text(
                encoding="utf-8-sig"
            )

            self.assertIn("while {!gameOver} do {", source, mission.name)
            self.assertNotIn("while {true} do {", source, mission.name)
            self.assertTrue(
                source.rstrip().endswith("paramBoundariesRunning = false;"),
                mission.name,
            )


if __name__ == "__main__":
    unittest.main()
