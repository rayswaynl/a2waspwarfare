"""Regression contract for side-patrol remount seat allocation."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"),
)


def test_sidepatrol_remount_distributes_passengers_across_all_live_transports() -> None:
    for root in MISSION_ROOTS:
        patrol = (ROOT / root / "Common/Functions/Common_RunSidePatrol.sqf").read_text(encoding="utf-8-sig")

        assert "_remountPending = +_dismounted;" in patrol
        assert "_remountSeats = _remountVeh emptyPositions \"cargo\";" in patrol
        assert "_remountPending = _remountPending - [_remountUnit];" in patrol
        assert "_veh = _vehicles select 0;" not in patrol


def test_commander_team_force_ejects_before_abandon_or_camp_foot_orders() -> None:
    for root in MISSION_ROOTS:
        commander = (ROOT / root / "Common/Functions/Common_RunCommanderTeam.sqf").read_text(encoding="utf-8-sig")

        for marker in (
            "//--- Defensive dismount: any foot soldier still in cargo walks in on foot",
            "_left = [];",
            "//--- IMMOBILE-ABANDON (task #2): a crewed hull that can no longer move must",
        ):
            start = commander.index(marker)
            block = commander[start : start + 1400]
            assert "unassignVehicle _x;" in block
            assert "[_x] orderGetIn false;" in block
            assert "if (vehicle _x != _x) then {moveOut _x}" in block
