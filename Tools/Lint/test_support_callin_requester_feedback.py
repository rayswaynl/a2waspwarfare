from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def read(relative):
    return (MISSION / relative).read_text(encoding="utf-8")


def test_support_requests_carry_the_initiating_player_for_targeted_denials():
    tactical = read("Client/GUI/GUI_Menu_Tactical.sqf")
    uav = read("Client/Module/UAV/uav.sqf")

    assert '["Paratroops",sideJoined,_callPos,clientTeam,0,player]' in tactical
    assert '["ParaVehi",sideJoined,_callPos,clientTeam,player]' in tactical
    assert '["ParaAmmo",sideJoined,_callPos,clientTeam,player]' in tactical
    assert '["uav",sideJoined,clientTeam,player]' in uav


def test_server_routes_support_denials_to_the_initiator_not_the_team_leader():
    handler = read("Server/Functions/Server_HandleSpecial.sqf")

    assert handler.count('_caller = if (count _args > 4) then {_args select 4} else {objNull};') == 2
    assert '_caller = if (count _args > 5) then {_args select 5} else {objNull};' in handler
    assert handler.count('[_caller, "HandleSpecial", ["support-callin-result", false, _denyMsg]] Call WFBE_CO_FNC_SendToClient;') == 4


def test_uav_uses_the_initiator_for_control_and_denial_feedback():
    uav = read("Server/Support/Support_UAV.sqf")
    handler = read("Server/Functions/Server_HandleSpecial.sqf")

    assert '_operator = if (count _args > 3) then {_args select 3} else {objNull};' in uav
    assert '[_caller, "HandleSpecial", ["support-callin-result", false, _denyMsg]] Call WFBE_CO_FNC_SendToClient;' in handler
