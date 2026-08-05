#!/usr/bin/env python3
"""Static contract for the incoming-missile range wait.

The incomingMissile event spawns Common_HandleIncomingMissile, so its range
poll must yield instead of re-evaluating the engine distance every frame.
"""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]

MISSILE_FILES = (
    ROOT
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Common"
    / "Functions"
    / "Common_HandleIncomingMissile.sqf",
    ROOT
    / "Missions_Vanilla"
    / "[61-2hc]warfarev2_073v48co.takistan"
    / "Common"
    / "Functions"
    / "Common_HandleIncomingMissile.sqf",
    ROOT
    / "Missions_Vanilla"
    / "[61-2hc]warfarev2_073v48co.zargabad"
    / "Common"
    / "Functions"
    / "Common_HandleIncomingMissile.sqf",
)


class IncomingMissileWaitTests(unittest.TestCase):
    def test_range_wait_yields_before_polling_distance(self) -> None:
        expected_wait = (
            "waitUntil {\n"
            "\tsleep 0.05;\n"
            "\tisNull _missile || {_missile distance _source > _limit}\n"
            "};"
        )

        for path in MISSILE_FILES:
            source = path.read_text(encoding="utf-8-sig")
            with self.subTest(path=path):
                self.assertEqual(source.count("waitUntil"), 1)
                self.assertIn(expected_wait, source)
                self.assertNotIn(
                    "waitUntil {isNull _missile || {_missile distance _source > _limit}};",
                    source,
                )


if __name__ == "__main__":
    unittest.main()
