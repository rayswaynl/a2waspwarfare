#!/usr/bin/env python3
"""Regression contract for empty-vehicle queue cleanup."""

from pathlib import Path
import unittest


MISSION = Path(__file__).resolve().parents[2] / "Missions/[55-2hc]warfarev2_073v48co.chernarus"
SOURCE = MISSION / "Server/Functions/Server_HandleEmptyVehicle.sqf"


class SalvageQueueLeakTests(unittest.TestCase):
    def test_empty_vehicle_early_exits_remove_the_vehicle_from_empty_queue(self) -> None:
        text = SOURCE.read_text(encoding="utf-8-sig")

        self.assertIn(
            "if (isNull _vehicle) exitWith {emptyQueu = emptyQueu - [_vehicle];};",
            text,
        )
        self.assertIn(
            "if (_timer > _delay) exitWith {emptyQueu = emptyQueu - [_vehicle];",
            text,
        )


if __name__ == "__main__":
    unittest.main()
