#!/usr/bin/env python3
"""Contract for stopping commander-lease executors at round end."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)


class CommanderLeaseLifecycleTests(unittest.TestCase):
    def test_per_side_executor_stops_at_game_over_in_every_terrain(self) -> None:
        for mission in MISSIONS:
            source = (mission / "Common/Functions/Common_CommanderLease.sqf").read_text(
                encoding="utf-8-sig"
            )
            start = source.index("WFBE_CO_FNC_CommanderLeaseStandDownExecutor = {")
            executor = source[start:]

            self.assertIn("while {!WFBE_GameOver} do {", executor, mission.name)
            self.assertNotIn("while {true} do {", executor, mission.name)

    def test_terrain_mirrors_share_the_same_lease_lifecycle_contract(self) -> None:
        sources = [
            (mission / "Common/Functions/Common_CommanderLease.sqf").read_bytes()
            for mission in MISSIONS
        ]
        for source in sources:
            self.assertNotIn(b"\n", source.replace(b"\r\n", b""))
        self.assertTrue(all(source == sources[0] for source in sources[1:]))


if __name__ == "__main__":
    unittest.main()
