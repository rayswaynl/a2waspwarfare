from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus"


def read(relative):
    return (MISSION / relative).read_text(encoding="utf-8")


def test_halo_action_rechecks_airframe_occupancy_height_and_cleans_up():
    source = read("Client/Action/Action_HALO.sqf")

    assert 'if !(_vehicle isKindOf "Air") exitWith {};' in source
    assert 'if ((getPos _vehicle select 2) < _minH) exitWith {};' in source
    assert '_caller setVariable ["wfbe_halo_scripted", true];' in source
    assert '_vehicle removeAction _act' in source
    assert '_u allowDamage false;' in source
    assert 'nearEntities ["ParachuteBase", 12]' in source


def test_cargo_eject_routes_high_altitude_players_through_halo_and_keeps_hc_fallback():
    source = read("Client/Action/Action_EjectCargo.sqf")

    assert '_isHigh = (_vehicle isKindOf "Air")' in source
    assert 'if (_isHigh && {isPlayer _x}) then {' in source
    assert '["action-perform", _x, "HALO", _vehicle]' in source
    assert 'Call WFBE_CO_FNC_SendToClient;' in source


def test_remote_action_handler_has_halo_branch_and_liveness_guards():
    source = read("Client/Functions/Client_FNC_Special.sqf")

    assert 'if (isNil "_unit" || {isNull _unit}) exitWith {};' in source
    assert 'if !(alive _unit) exitWith {};' in source
    assert 'if (_action == "HALO") then {' in source
    assert '_unit setVariable ["wfbe_halo_scripted", true];' in source
    assert '[_unit] Exec "ca\\air2\\Halo\\data\\Scripts\\HALO_getout.sqs";' in source


def test_menu_refuses_airborne_unflip_and_headbug_recovery():
    source = read("Client/GUI/GUI_Menu.sqf")

    assert 'if (_vehicle isKindOf "ParachuteBase") exitWith {};' in source
    assert 'if (player == _vehicle && {((getPos player) select 2) > 3}) exitWith {};' in source
    assert 'if (((getPos player) select 2) > 5) exitWith {};' in source


def test_transport_init_limits_halo_to_occupants_and_adds_emergency_getout():
    source = read("Common/Init/Init_Unit.sqf")

    assert 'vehicle _this == _target && alive _this && alive _target' in source
    assert '_unit addEventHandler ["GetOut", {' in source
    assert 'if (_unit getVariable ["wfbe_halo_scripted", false]) exitWith {};' in source
    assert '[_u] Exec "ca\\air2\\Halo\\data\\Scripts\\HALO_getout.sqs";' in source
