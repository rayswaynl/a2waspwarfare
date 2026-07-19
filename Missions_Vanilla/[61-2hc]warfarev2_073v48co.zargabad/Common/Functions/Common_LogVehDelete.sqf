/*
    Reason-coded vehicle/crew deletion probe (card wasp-vehicle-crew-fast-despawn-20260719).

    Owner live report 2026-07-19: "I got out as driver and vehicle + crew despawned very quickly."
    The independent review of the first diagnosis required deterministic evidence binding the
    incident to a specific cleanup path. This probe logs ONE structured line for every scripted
    cleanup deletion of a vehicle hull or crewed unit, capturing everything needed to name the
    exact source and rule the others out: reason code, class, engine id, position, locality,
    crew composition, nearest-player distance (the "player-visible vanish" test), and the
    player-use/exit stamps written by the Common_CreateVehicle GetIn/GetOut hooks.

    Telemetry-only: no behavior change (C2 authority-telemetry precedent). WFBE_C_VEH_DELETE_PROBE
    default 1 acts as a kill-switch. Works for hulls AND men (crew of a man = []).
*/

WFBE_CO_FNC_LogVehDelete = {
    Private ["_reason","_veh","_extra","_nearD","_d","_crewStr","_used","_exitT","_pos","_useRole","_useUid"];
    _reason = _this select 0;
    _veh = _this select 1;
    _extra = if (count _this > 2) then {_this select 2} else {""};
    //--- Round-2 review: DEFAULT 0 per repo feature-default policy. The capture round arms it
    //--- explicitly (constant or lobby) - see Init_CommonConstants.
    if ((missionNamespace getVariable ["WFBE_C_VEH_DELETE_PROBE", 0]) <= 0) exitWith {};
    if (isNull _veh) exitWith {};

    //--- Round-2 review (cost bound): scan playableUnits, not allUnits - players are playable
    //--- units, and the playable set is 1-2 orders of magnitude smaller than the AI population.
    _nearD = -1;
    {
        if (isPlayer _x && {alive _x}) then {
            _d = _x distance _veh;
            if (_nearD < 0 || {_d < _nearD}) then {_nearD = _d};
        };
    } forEach playableUnits;

    _crewStr = "";
    {_crewStr = _crewStr + Format ["%1/p:%2 ", typeOf _x, isPlayer _x]} forEach (crew _veh);

    _used = _veh getVariable "wfbe_player_used"; if (isNil "_used") then {_used = -1};
    _exitT = _veh getVariable "wfbe_player_exit"; if (isNil "_exitT") then {_exitT = -1};
    _useRole = _veh getVariable "wfbe_player_used_role"; if (isNil "_useRole") then {_useRole = ""};
    _useUid = _veh getVariable "wfbe_player_used_uid"; if (isNil "_useUid") then {_useUid = ""};
    _pos = getPosATL _veh;

    diag_log Format ["VEHDEL|v1|reason=%1|t=%2|class=%3|id=%4|grp=%5|pos=[%6,%7]|local=%8|alive=%9|crew=[%10]|nearPlayerM=%11|lastPlayerUse=%12|lastPlayerExit=%13|useRole=%14|useUid=%15|extra=%16",
        _reason, round time, typeOf _veh, _veh, group _veh,
        round (_pos select 0), round (_pos select 1),
        local _veh, alive _veh, _crewStr,
        (if (_nearD < 0) then {-1} else {round _nearD}), _used, _exitT, _useRole, _useUid, _extra];
};
