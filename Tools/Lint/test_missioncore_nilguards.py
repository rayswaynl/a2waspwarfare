#!/usr/bin/env python3
"""Regression checks for the mission-core nil-guard fixes (kimi/072020-missioncore-nilguards).

1. Common_GetFriendlyCamps.sqf: a deleted camp logic (null in the town "camps" array, the
   cmdcon44q / #1164 loss class) made `nil == _sideID` error and kill every caller's camp
   lookup for that town; mid-init camps could also lack sideID/wfbe_camp_bunker.
2. Common/Init/Init_Town.sqf: _town_camp_flags grew unconditionally while _towns_camps only
   grew on SV-sync success, misaligning the parallel arrays handed to server_town_camp.sqf.
3. Server/Functions/Server_OnPlayerDisconnected.sqf: 1-arg getVariable "wfbe_teams" on the
   resistance logic (unset when WFBE_C_GUER_PLAYERSIDE=0) -> forEach nil error before the
   graceful null-team bail. All three terrains asserted (LoadoutManager mirrors CH -> TK/ZG).
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

TERRAINS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def test_friendlycamps_null_and_nil_guards() -> None:
    for terrain in TERRAINS:
        source = (ROOT / terrain / "Common/Functions/Common_GetFriendlyCamps.sqf").read_text(encoding="utf-8")
        assert "if (!isNull _x) then {" in source, f"{terrain}: missing deleted-camp isNull guard"
        assert '(_x getVariable ["sideID", -1]) == _sideID' in source, f"{terrain}: missing 2-arg sideID read"
        assert '_bunker = if (isNil "_bunker") then {objNull} else {_bunker};' in source, (
            f"{terrain}: missing nil-bunker heal"
        )
        assert '_camps = if (isNil "_camps") then {[]} else {_camps};' in source, (
            f"{terrain}: missing nil-camps heal"
        )
        assert 'forEach (_town getVariable "camps")' not in source, f"{terrain}: unguarded camps read remains"


def test_init_town_flag_list_stays_parallel() -> None:
    for terrain in TERRAINS:
        source = (ROOT / terrain / "Common/Init/Init_Town.sqf").read_text(encoding="utf-8")
        assert source.count("_town_camp_flags = _town_camp_flags + [_flag];") == 1, (
            f"{terrain}: flag append must exist exactly once"
        )
        camps_idx = source.index("_towns_camps = _towns_camps + [_x];")
        flags_idx = source.index("_town_camp_flags = _town_camp_flags + [_flag];")
        assert 0 < (flags_idx - camps_idx) < 900, (
            f"{terrain}: flag append must sit inside the SV-sync success branch"
        )


def test_disconnect_team_scan_nil_safe() -> None:
    for terrain in TERRAINS:
        source = (ROOT / terrain / "Server/Functions/Server_OnPlayerDisconnected.sqf").read_text(encoding="utf-8")
        assert 'getVariable ["wfbe_teams", []]' in source, f"{terrain}: missing 2-arg wfbe_teams read"
        assert 'GetSideLogic) getVariable "wfbe_teams");' not in source, f"{terrain}: 1-arg wfbe_teams read remains"


def test_connect_re_registers_resolved_team() -> None:
    for terrain in TERRAINS:
        source = (ROOT / terrain / "Server/Functions/Server_OnPlayerConnected.sqf").read_text(encoding="utf-8")
        start = source.index('missionNamespace setVariable [Format ["WFBE_SOD_LASTG_')
        end = source.index("//--- B63", start)
        enrollment = source[start:end]
        assert "if (_sideJoined in [west, east, resistance]) then {" in enrollment, (
            f"{terrain}: missing side-gated roster repair"
        )
        assert '_rrTeams = _rrLogik getVariable ["wfbe_teams", []];' in enrollment, (
            f"{terrain}: missing logic-object roster read"
        )
        assert "_rrTeams = _rrTeams + [_team];" in enrollment, f"{terrain}: missing deduplicated roster append"
        assert '_rrLogik setVariable ["wfbe_teams", _rrTeams, true];' in enrollment, (
            f"{terrain}: missing roster broadcast"
        )
        assert 'if (!isNil {_team getVariable "wfbe_hc_magnet"}) then {' in enrollment, (
            f"{terrain}: missing stale HC-magnet cleanup"
        )


def test_disconnect_filler_classname_guard() -> None:
    for terrain in TERRAINS:
        source = (ROOT / terrain / "Server/Functions/Server_OnPlayerDisconnected.sqf").read_text(encoding="utf-8")
        start = source.index("if (_old_unit_group != _team) then {")
        end = source.index("[_old_unit] joinSilent _team;", start)
        transfer = source[start:end]
        assert '_fillerClass = missionNamespace getVariable Format ["WFBE_%1SOLDIER", _side];' in transfer, (
            f"{terrain}: missing filler classname capture"
        )
        assert '&& {!isNil "_fillerClass"} && {typeName _fillerClass == "STRING"}' in transfer, (
            f"{terrain}: missing nil/string guard before filler creation"
        )
        assert "[_fillerClass, _old_unit_group" in transfer, f"{terrain}: filler create does not use guarded classname"
        assert '[_old_unit_group, [0,0,0], _side] Call WFBE_CO_FNC_CreateUnit' not in transfer, (
            f"{terrain}: direct unguarded filler creation remains"
        )


if __name__ == "__main__":
    test_friendlycamps_null_and_nil_guards()
    test_init_town_flag_list_stays_parallel()
    test_disconnect_team_scan_nil_safe()
    test_connect_re_registers_resolved_team()
    test_disconnect_filler_classname_guard()
    print("mission-core nil-guard regression checks passed")
