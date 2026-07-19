/*
    C1 stable commander UID/side lease.

    The legacy wfbe_commander group remains the derived view consumed by the
    rest of the mission. The lease keeps the human identity and group binding
    stable across leader death, promotion, respawn and a short disconnect.
*/

//--- Review-fix (codex reject 2026-07-19, P1-1): a single authoritative eligibility test the seat
//--- WRITERS call BEFORE publishing wfbe_commander (fail closed), so a CIV / cross-side / HC /
//--- AI-led team can never hold the seat while the lease is enabled. Grant re-runs the same test
//--- (belt-and-braces) but eligibility is now enforced pre-publish, not post-hoc.
WFBE_CO_FNC_CommanderLeaseEligible = {
    Private ["_side","_team","_leader","_ok"];
    _side = _this select 0;
    _team = _this select 1;
    _ok = false;
    if (_side != civilian && {!isNull _team} && {side _team == _side} && {!([_team, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool)}) then {
        _leader = leader _team;
        if (!isNull _leader && {isPlayer _leader} && {(getPlayerUID _leader) != ""}) then {_ok = true};
    };
    _ok
};

WFBE_CO_FNC_GrantCommanderLease = {
    Private ["_side","_team","_source","_logic","_leader","_uid","_lease"];
    _side = _this select 0;
    _team = _this select 1;
    _source = _this select 2;

    if (!([_side, _team] Call WFBE_CO_FNC_CommanderLeaseEligible)) exitWith {};

    _leader = leader _team;
    _uid = getPlayerUID _leader;

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

    //--- Review-fix (codex reject 2026-07-19, P1-2 single-fire): ATOMICALLY claim the stand-down by
    //--- clearing lease + expiry + derived view FIRST, then run the externally-visible effects
    //--- (message, team resets). A concurrent second caller (interleaved grace checker, side-change
    //--- racing an expiry) now hits the null-commander/empty-lease guard above and exits - the
    //--- effects can never run twice. SQF scheduled scripts interleave at statement boundaries, so
    //--- effects-then-invalidate (the old order) was double-fire-prone.
    _logic setVariable ["wfbe_commander_lease", nil, true];
    _logic setVariable ["wfbe_commander_lease_expires", nil];
    _logic setVariable ["wfbe_commander", objNull, true];
    [_side, "LocalizeMessage", ['CommanderDisconnected']] Call WFBE_CO_FNC_SendToClients;
    {[_x,false] Call SetTeamAutonomous;[_x, ""] Call SetTeamRespawn} forEach (_logic getVariable "wfbe_teams");
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
