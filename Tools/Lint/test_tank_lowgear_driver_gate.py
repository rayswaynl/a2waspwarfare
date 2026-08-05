#!/usr/bin/env python3
"""Static contract for the driver-only tank low-gear actions.

The low-gear handler starts and services the feature only for the local
vehicle driver.  The tank action conditions must therefore expose the action
to the same actor contract as cars and the AN-2, rather than to every crew
seat through ``vehicle player``.
"""

from pathlib import Path
import unittest

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
INIT_UNIT = MISSION / "Common" / "Init" / "Init_Unit.sqf"


class TankLowGearDriverGateTests(unittest.TestCase):
    def test_tank_low_gear_actions_match_driver_only_handler_contract(self) -> None:
        text = mask_comments(INIT_UNIT.read_text(encoding="utf-8-sig"))
        tank_block = text.split('if (_unit isKindOf "Tank") then {', 1)[1].split(
            'if (_unit isKindOf "Car") then {', 1
        )[0]

        self.assertEqual(tank_block.count("player==driver _target"), 2)
        self.assertNotIn("vehicle player == _target", tank_block)


if __name__ == "__main__":
    unittest.main()
