"""Static contracts for AICOM capture-hold ownership and team-end release."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def code(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def case_block(source: str, start_marker: str, end_marker: str) -> str:
    start = source.index(start_marker)
    end = source.index(end_marker, start)
    return source[start:end]


def test_team_end_releases_only_the_current_holder() -> None:
    for mission_root in MISSION_ROOTS:
        source = code(mission_root / "Server/Functions/Server_HandleSpecial.sqf")
        end_case = case_block(source, 'case "aicom-team-ended":', 'case "aicom-team-heading":')

        assert '_endedHoldTown = _cteam getVariable "wfbe_aicom_holding_town";' in end_case
        assert '_endedHoldOwner = _endedHoldTown getVariable ["wfbe_aicom_hold_team", grpNull];' in end_case
        assert "if (_endedHoldOwner == _cteam) then {" in end_case
        assert '_endedHoldTown setVariable ["wfbe_aicom_hold_until", 0, true];' in end_case
        assert '_endedHoldTown setVariable ["wfbe_aicom_hold_team", grpNull, true];' in end_case
        assert '_cteam setVariable ["wfbe_aicom_holding_town", objNull, true];' in end_case


def test_all_hold_claims_record_their_owner() -> None:
    for mission_root in MISSION_ROOTS:
        commander = code(mission_root / "Common/Functions/Common_RunCommanderTeam.sqf")
        special = code(mission_root / "Server/Functions/Server_HandleSpecial.sqf")

        assert commander.count('_townObj setVariable ["wfbe_aicom_hold_team", _team, true];') == 2
        assert '_hdTown setVariable ["wfbe_aicom_hold_team", _hdTeam, true];' in special


def test_holder_release_clears_owner_before_clearing_team_latch() -> None:
    for mission_root in MISSION_ROOTS:
        source = code(mission_root / "Server/AI/Commander/AI_Commander_AssignTowns.sqf")
        hold_block = source[source.index('if ((missionNamespace getVariable ["WFBE_C_AICOM_HOLD_MODE", 1]) > 0) then {'):]

        clear_owner = 'if ((_ht getVariable ["wfbe_aicom_hold_team", grpNull]) == _team) then {'
        clear_latch = '_team setVariable ["wfbe_aicom_holding_town", objNull, true];'
        assert clear_owner in hold_block
        assert hold_block.index(clear_owner) < hold_block.index(clear_latch)


def test_hold_lifecycle_sources_remain_mirrored() -> None:
    relative_paths = (
        "Common/Functions/Common_RunCommanderTeam.sqf",
        "Server/AI/Commander/AI_Commander_AssignTowns.sqf",
        "Server/Functions/Server_HandleSpecial.sqf",
    )
    for relative_path in relative_paths:
        contents = [(mission_root / relative_path).read_bytes() for mission_root in MISSION_ROOTS]
        assert contents[0] == contents[1] == contents[2]
