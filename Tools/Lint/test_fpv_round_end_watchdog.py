#!/usr/bin/env python3
"""Regression contract for FPV server-worker teardown at round end."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)


class FpvRoundEndWatchdogTests(unittest.TestCase):
    def test_server_worker_stops_when_round_ends(self) -> None:
        for mission in MISSIONS:
            source = (mission / "Server/Support/Support_FPV.sqf").read_text(
                encoding="utf-8-sig"
            )
            self.assertIn("while {!WFBE_GameOver} do {", source, mission.name)


if __name__ == "__main__":
    unittest.main()
