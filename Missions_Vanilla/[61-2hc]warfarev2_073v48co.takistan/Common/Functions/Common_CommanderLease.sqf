/*
    C1 stable commander UID/side lease.

    The legacy wfbe_commander group remains the derived view consumed by the
    rest of the mission. The lease keeps the human identity and group binding
    stable across leader death, promotion, respawn and a short disconnect.
*/

WFBE_CO_FNC_GrantCommanderLease = {
    Private ["_side","_team","_source","_logic","_leader","_uid","_lease"];
    _side = _this select 0;
    _team = _this select 1;
    _source = _this select 2;

    if (_side == civilian) exitWith {};
    if (isNull _team) exitWith {};
    if ([_team, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool) exitWith {};

    _leader = leader _team;
    if (isNull _leader) exitWith {};
    if (!isPlayer _leader) exitWith {};
    _uid = getPlayerUID _leader;
    if (_uid == "") exitWith {};

    _logic = (_side) Call WFBE_CO_FNC_GetSideLogic;
    if (isNull _logic) exitWith {};

    _lease = [_uid, _side, groupId _team, time, _source];
    _logic setVariable ["wfbe_commander_lease", _lease, true];
    _logic setVariable ["wfbe_commander_lease_expires", nil];
};

WFBE_CO_FNC_InvalidateCommanderLease = {
    Private ["_side","_logic"];
    _side = _this select 0;
    if (_side == civilian) exitWith {};
    _logic = (_side) Call WFBE_CO_FNC_GetSideLogic;
    if (isNull _logic) exitWith {};
    _logic setVariable ["wfbe_commander_lease", nil, true];
    _logic setVariable ["wfbe_commander_lease_expires", nil];
    _logic setVariable ["wfbe_commander", objNull, true];
};

WFBE_CO_FNC_CommanderLeaseHolderPresent = {
    Private ["_side","_logic","_lease","_uid","_groupKey","_present"];
    _side = _this select 0;
    _present = false;
    if (_side == civilian) exitWith {_present};

    _logic = (_side) Call WFBE_CO_FNC_GetSideLogic;
    if (isNull _logic) exitWith {_present};
    _lease = _logic getVariable ["wfbe_commander_lease", []];
    if (typeName _lease != "ARRAY") then {_lease = []};
    if (count _lease < 3) exitWith {_present};
    _uid = _lease select 0;
    _groupKey = _lease select 2;

    {
        if (!isNull _x && {alive _x} && {isPlayer _x} && {(getPlayerUID _x) == _uid} && {(groupId (group _x)) == _groupKey}) then {_present = true};
    } forEach allUnits;
    _present
};

WFBE_CO_FNC_CommanderLeaseStandDown = {
    Private ["_side","_logic","_commander","_lease"];
    _side = _this select 0;
    if (_side == civilian) exitWith {};
    _logic = (_side) Call WFBE_CO_FNC_GetSideLogic;
    if (isNull _logic) exitWith {};

    _commander = _logic getVariable ["wfbe_commander", objNull];
    _lease = _logic getVariable ["wfbe_commander_lease", []];
    if (isNull _commander && {typeName _lease != "ARRAY" || {count _lease == 0}}) exitWith {};

    _logic setVariable ["wfbe_commander", objNull, true];
    [_side, "LocalizeMessage", ['CommanderDisconnected']] Call WFBE_CO_FNC_SendToClients;
    {[_x,false] Call SetTeamAutonomous;[_x, ""] Call SetTeamRespawn} forEach (_logic getVariable "wfbe_teams");
    [_side] Call WFBE_CO_FNC_InvalidateCommanderLease;
};

WFBE_CO_FNC_CommanderLeaseGraceCheck = {
    Private ["_side","_expires","_wait","_logic","_currentExpires"];
    _side = _this select 0;
    _expires = _this select 1;
    _wait = _expires - time;
    if (_wait > 0) then {sleep _wait};

    _logic = (_side) Call WFBE_CO_FNC_GetSideLogic;
    if (isNull _logic) exitWith {};
    _currentExpires = _logic getVariable "wfbe_commander_lease_expires";
    if (isNil "_currentExpires") exitWith {};
    if (_currentExpires != _expires) exitWith {};
    if ([_side] Call WFBE_CO_FNC_CommanderLeaseHolderPresent) exitWith {};
    [_side] Call WFBE_CO_FNC_CommanderLeaseStandDown;
};
