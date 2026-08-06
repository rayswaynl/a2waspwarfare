#!/usr/bin/env python3
"""Contract for terminating the client AutoFlip watcher at round end."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
AUTOFLIP = Path("Client/Module/AutoFlip/AutoFlip.sqf")


class AutoFlipLifecycleTests(unittest.TestCase):
    def test_watcher_stops_after_game_over(self) -> None:
        for mission in MISSIONS:
            source = (mission / AUTOFLIP).read_text(encoding="utf-8-sig")

            self.assertIn("while {!gameOver} do {", source, mission.name)
            self.assertNotIn("while {true} do {", source, mission.name)
            self.assertIn("if (alive player && !gameOver) then {", source, mission.name)

    def test_maintained_mirrors_are_byte_identical_and_crlf_only(self) -> None:
        contents = [(mission / AUTOFLIP).read_bytes() for mission in MISSIONS]

        self.assertEqual(contents[0], contents[1], "Takistan AutoFlip mirror differs")
        self.assertEqual(contents[0], contents[2], "Zargabad AutoFlip mirror differs")
        for content in contents:
            self.assertNotIn(b"\n", content.replace(b"\r\n", b""))


if __name__ == "__main__":
    unittest.main()
