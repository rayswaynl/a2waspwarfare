#!/usr/bin/env python3
"""Regression contract for cancelling client refuel work at mission end."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
MISSION_DIRS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
REFUEL_WORKER = Path("Client/Functions/Client_SupportRefuel.sqf")
ENDGAME_GUARD = "if (gameOver || {WFBE_GameOver}) exitWith {_cts = 0};"


class SupportRefuelTerminalLifecycleTests(unittest.TestCase):
    def test_refuel_aborts_after_wait_before_vehicle_mutation(self) -> None:
        sources = []
        for mission_dir in MISSION_DIRS:
            source = (mission_dir / REFUEL_WORKER).read_text(encoding="utf-8-sig")
            sources.append(source.encode("utf-8"))

            loop = source[source.index("while {true} do {") :]
            self.assertIn(ENDGAME_GUARD, loop, mission_dir.name)
            sleep_pos = loop.index("sleep 1;")
            guard_pos = loop.index(ENDGAME_GUARD)
            support_check_pos = loop.index("//--- Check the distance & alive.")
            vehicle_mutation_pos = source.index("_veh setFuel 1;")
            loop_start = source.index("while {true} do {")

            self.assertLess(sleep_pos, guard_pos, mission_dir.name)
            self.assertLess(guard_pos, support_check_pos, mission_dir.name)
            self.assertGreater(vehicle_mutation_pos, loop_start, mission_dir.name)
            self.assertIn(
                "if (_cts == 0 && {_price > 0}) then {_price Call ChangePlayerFunds;};",
                source,
                mission_dir.name,
            )

        self.assertTrue(all(source == sources[0] for source in sources[1:]))


if __name__ == "__main__":
    unittest.main()
