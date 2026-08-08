"""Regression contract for persistent stationary-defense ownership."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
REAPER = Path("Server/Functions/Server_HandleEmptyVehicle.sqf")
RECEIVER = Path("Client/PVFunctions/HandleSpecial.sqf")


class EmptyVehicleDefenseOwnershipTests(unittest.TestCase):
    def test_empty_fuse_and_remote_receiver_respect_dynamic_ownership_markers(self) -> None:
        for mission in MISSION_ROOTS:
            source = (mission / REAPER).read_text(encoding="utf-8-sig")
            timer_start = source.index("_timer = if (")
            fuse_start = source.index("if (_timer > _delay) then {", timer_start)
            timer_decision = source[timer_start:fuse_start]

            self.assertIn(
                '_vehicle getVariable ["wfbe_defense", false]',
                timer_decision,
                mission,
            )
            self.assertIn(
                '_vehicle getVariable ["keepAlive", false]',
                timer_decision,
                mission,
            )

            receiver = (mission / RECEIVER).read_text(encoding="utf-8-sig")
            case_start = receiver.index('case "cleanup-empty-vehicle": {')
            case_end = receiver.index('case "delegate-townai":', case_start)
            cleanup_case = receiver[case_start:case_end]
            delete_start = cleanup_case.index("deleteVehicle _emptyVehicle")
            delete_guard = cleanup_case[:delete_start]

            for marker in (
                '!(_emptyVehicle getVariable ["wfbe_defense", false])',
                '!(_emptyVehicle getVariable ["keepAlive", false])',
            ):
                self.assertIn(marker, delete_guard, mission)

            for existing_guard in (
                '!(_emptyVehicle getVariable ["wfbe_airlifted", false])',
                '!(_emptyVehicle getVariable ["wfbe_is_guer_fob", false])',
                '!(_emptyVehicle getVariable ["wfbe_is_fob", false])',
                '(_emptyVehicle getVariable ["wfbe_empty_vehicle_reap", false])',
            ):
                self.assertIn(existing_guard, delete_guard, mission)


if __name__ == "__main__":
    unittest.main()
