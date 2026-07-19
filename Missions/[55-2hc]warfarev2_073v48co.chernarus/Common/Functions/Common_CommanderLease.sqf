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

//--- Review-fix round 2 (codex reject 2026-07-19, P1-2 interleaving): stand-down is now
//--- SINGLE-OWNER BY CONSTRUCTION instead of clear-ordering-by-convention. Callers (grace expiry,
//--- side-change) never run the effects themselves - they only set a request stamp. Exactly ONE
//--- per-side executor loop (spawned once from Init_Server when WFBE_C_CMD_LEASE is on) consumes
//--- requests and performs the stand-down, so two racing callers can never both reach the
//--- message/team-reset effects: there is only one effects-runner per side, and a second request
//--- arriving mid-execution is absorbed by the executor's own guard on its next iteration
//--- (commander already null + lease already empty = nothing to do).
WFBE_CO_FNC_CommanderLeaseRequestStandDown = {
    Private ["_side","_logic"];
    _side = _this select 0;
    if (_side == civilian) exitWith {};
    _logic = (_side) Call WFBE_CO_FNC_GetSideLogic;
    if (isNull _logic) exitWith {};
    _logic setVariable ["wfbe_commander_lease_sd_req", time]; // side-logic state key, not a classname // noqa: CLASSREF
};

//--- Executor-internal ONLY. The single legitimate Call site is the executor loop below; a source
//--- contract test pins that no other file Calls this directly.
WFBE_CO_FNC_CommanderLeaseStandDown = {
    Private ["_side","_logic","_commander","_lease"];
    _side = _this select 0;
    if (_side == civilian) exitWith {};
    _logic = (_side) Call WFBE_CO_FNC_GetSideLogic;
    if (isNull _logic) exitWith {};

    _commander = _logic getVariable ["wfbe_commander", objNull];
    _lease = _logic getVariable ["wfbe_commander_lease", []];
    if (isNull _commander && {typeName _lease != "ARRAY" || {count _lease == 0}}) exitWith {};

    //--- Clear state before effects (defense in depth on top of the single-owner executor).
    _logic setVariable ["wfbe_commander_lease", nil, true];
    _logic setVariable ["wfbe_commander_lease_expires", nil];
    _logic setVariable ["wfbe_commander", objNull, true];
    [_side, "LocalizeMessage", ['CommanderDisconnected']] Call WFBE_CO_FNC_SendToClients;
    {[_x,false] Call SetTeamAutonomous;[_x, ""] Call SetTeamRespawn} forEach (_logic getVariable "wfbe_teams");
};

//--- The single per-side stand-down executor. Spawned ONCE per side from Init_Server when the
//--- lease flag is on (flag off = never spawned = byte-identical). Consumes request stamps; a
//--- reclaim that lands between request and consumption wins automatically because the reclaim
//--- clears the expiry AND the executor re-validates holder-absence before acting.
WFBE_CO_FNC_CommanderLeaseStandDownExecutor = {
    Private ["_side","_logic","_req"];
    _side = _this select 0;
    if (_side == civilian) exitWith {};
    _logic = (_side) Call WFBE_CO_FNC_GetSideLogic;
    if (isNull _logic) exitWith {};
    while {true} do {
        sleep 2;
        _req = _logic getVariable "wfbe_commander_lease_sd_req"; // side-logic state key, not a classname // noqa: CLASSREF
        if (!isNil "_req") then {
            _logic setVariable ["wfbe_commander_lease_sd_req", nil]; // side-logic state key, not a classname // noqa: CLASSREF
            //--- Re-validate at consumption time: a reclaim since the request means the holder is
            //--- back - do nothing. Only a still-absent holder stands the side down.
            if (!([_side] Call WFBE_CO_FNC_CommanderLeaseHolderPresent)) then {
                [_side] Call WFBE_CO_FNC_CommanderLeaseStandDown;
            };
        };
    };
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
    [_side] Call WFBE_CO_FNC_CommanderLeaseRequestStandDown; //--- request only; the single per-side executor performs the effects
};

