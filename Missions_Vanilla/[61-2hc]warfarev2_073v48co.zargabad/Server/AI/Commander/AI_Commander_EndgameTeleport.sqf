/*
    AI_Commander_EndgameTeleport.sqf - late-round relocation of base-idle AI teams.

    This is the decision side of PR #1464. It runs on the server after the
    reactive-defense and graceful-withdrawal passes, reusing the Strategy tick's
    already-built team and town pools. It never calls setPos: the existing
    Common_RunCommanderTeam driver consumes the broadcast signal on the machine
    that owns the group and performs the physical relocation there.

    All five WFBE_C_AICOM_ENDGAME_TELEPORT_* constants default to 0. Arm the
    feature only as a complete owner-controlled set: ENABLE=1, a match-age
    threshold, a cooldown, a per-tick cap, and a minimum travel distance.
*/
private ["_side","_teams","_attacked","_ownTownObjs","_myHQ","_sideID","_minTime","_cooldown","_maxPerTick","_minDist","_homeRange","_cmdTeam","_sideLogic","_count","_team","_leader","_mode","_relief","_serviceState","_last","_destinationTown","_destination","_bestDistance","_candidateDistance","_candidateTown","_frontPrimary","_bestFrontDistance","_frontDistance","_hcOrder","_hcSeq","_townName"];

if (typeName _this != "ARRAY" || {count _this < 5}) exitWith {};
_side        = _this select 0;
_teams       = _this select 1;
_attacked    = _this select 2;
_ownTownObjs = _this select 3;
_myHQ        = _this select 4;

//--- Flag-off kill switch is deliberately the first executable decision.
if ((missionNamespace getVariable ["WFBE_C_AICOM_ENDGAME_TELEPORT_ENABLE", 0]) <= 0) exitWith {};
if !(_side in [west, east]) exitWith {};
if (typeName _teams != "ARRAY") exitWith {};
if (typeName _attacked != "ARRAY") then {_attacked = []};
if (typeName _ownTownObjs != "ARRAY") then {_ownTownObjs = []};
if (isNil "_myHQ") then {_myHQ = (_side) Call WFBE_CO_FNC_GetSideHQ};
if (isNil "_myHQ" || {typeName _myHQ != "OBJECT"} || {isNull _myHQ}) exitWith {};

_minTime = missionNamespace getVariable ["WFBE_C_AICOM_ENDGAME_TELEPORT_MIN_TIME", 0];
_cooldown = missionNamespace getVariable ["WFBE_C_AICOM_ENDGAME_TELEPORT_COOLDOWN", 0];
_maxPerTick = missionNamespace getVariable ["WFBE_C_AICOM_ENDGAME_TELEPORT_MAX_PER_TICK", 0];
_minDist = missionNamespace getVariable ["WFBE_C_AICOM_ENDGAME_TELEPORT_MIN_DIST", 0];
if (typeName _minTime != "SCALAR" || {typeName _cooldown != "SCALAR"} || {typeName _maxPerTick != "SCALAR"} || {typeName _minDist != "SCALAR"}) exitWith {};
if (time < _minTime || {_maxPerTick <= 0}) exitWith {};
if (_cooldown < 0) then {_cooldown = 0};
if (_minDist < 0) then {_minDist = 0};

//--- A side with an active human command lease is never accelerated by this worker.
if (([_side] Call WFBE_CO_FNC_GetCommanderAuthorityUID) != "") exitWith {};

_sideID = (_side) Call WFBE_CO_FNC_GetSideID;
_homeRange = missionNamespace getVariable ["WFBE_C_AICOM_RETREAT_HOME_RANGE", 800];
if (typeName _homeRange != "SCALAR" || {_homeRange <= 0}) exitWith {};
_sideLogic = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_sideLogic") then {_sideLogic = objNull};
_count = 0;

{
    _team = _x;
    if (_count < _maxPerTick) then {
        if (!isNil "_team" && {!isNull _team} && {({alive _x} count (units _team)) > 0}) then {
            _leader = leader _team;
            if (!isNull _leader && {alive _leader} && {!isPlayer _leader} && {({isPlayer _x} count (units _team)) == 0}) then {
                if (behaviour _leader != "COMBAT") then {
                    if ((_leader distance _myHQ) <= _homeRange) then {
                        _mode = toLower ([_team, "wfbe_teammode", "towns"] Call WFBE_CO_FNC_GroupGetBool);
                        _relief = [_team, "wfbe_aicom_relief", objNull] Call WFBE_CO_FNC_GroupGetBool;
                        _serviceState = _team getVariable "wfbe_aicom_svcstate";
                        if (_mode == "towns" && {isNull _relief} && {!([_team, "wfbe_aicom_strike", false] Call WFBE_CO_FNC_GroupGetBool)} && {!([_team, "wfbe_aicom_rallying", false] Call WFBE_CO_FNC_GroupGetBool)} && {!([_team, "wfbe_aicom_refit", false] Call WFBE_CO_FNC_GroupGetBool)} && {!([_team, "wfbe_aicom_foot_stage", false] Call WFBE_CO_FNC_GroupGetBool)} && {!([_team] Call WFBE_CO_FNC_CapLock)} && {isNil "_serviceState" || {_serviceState != "enroute"}}) then {
                            _last = _team getVariable "wfbe_aicom_endgame_tp_last";
                            if (isNil "_last" || {typeName _last != "SCALAR"}) then {_last = -1e9};
                            if ((time - _last) >= _cooldown) then {
                                _destinationTown = objNull;
                                _bestDistance = 1e9;
                                if (count _attacked > 0) then {
                                    {
                                        _candidateTown = _x;
                                        if (typeName _candidateTown == "OBJECT" && {!isNull _candidateTown} && {(_candidateTown getVariable ["sideID", -1]) == _sideID}) then {
                                            _candidateDistance = _leader distance _candidateTown;
                                            if (_candidateDistance < _bestDistance) then {_bestDistance = _candidateDistance; _destinationTown = _candidateTown};
                                        };
                                    } forEach _attacked;
                                } else {
                                    _frontPrimary = _myHQ;
                                    if (!isNull _sideLogic) then {
                                        _frontPrimary = _sideLogic getVariable "wfbe_aicom_front_prim";
                                        if (isNil "_frontPrimary" || {typeName _frontPrimary != "OBJECT"} || {isNull _frontPrimary}) then {_frontPrimary = _myHQ};
                                    };
                                    _bestFrontDistance = 1e9;
                                    {
                                        _candidateTown = _x;
                                        if (typeName _candidateTown == "OBJECT" && {!isNull _candidateTown} && {(_candidateTown getVariable ["sideID", -1]) == _sideID}) then {
                                            _frontDistance = _candidateTown distance _frontPrimary;
                                            if (_frontDistance < _bestFrontDistance) then {_bestFrontDistance = _frontDistance; _destinationTown = _candidateTown};
                                        };
                                    } forEach _ownTownObjs;
                                };
                                if (!isNull _destinationTown) then {
                                    _destination = getPos _destinationTown;
                                    if (typeName _destination == "ARRAY" && {count _destination >= 2} && {typeName (_destination select 0) == "SCALAR"} && {typeName (_destination select 1) == "SCALAR"} && {!surfaceIsWater _destination} && {(_leader distance _destination) >= _minDist}) then {
                                        //--- Keep server-local state in sync for every team. Only the HC order channel is HC-gated.
                                        [_team, "towns"] Call SetTeamMoveMode;
                                        [_team, _destination] Call SetTeamMovePos;
                                        if ([_team, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool || {local _leader}) then {
                                            _hcOrder = _team getVariable "wfbe_aicom_order";
                                            _hcSeq = -1;
                                            if (!isNil "_hcOrder" && {typeName _hcOrder == "ARRAY"} && {count _hcOrder > 0} && {typeName (_hcOrder select 0) == "SCALAR"}) then {_hcSeq = _hcOrder select 0};
                                            _team setVariable ["wfbe_aicom_route", [], true];
                                            _team setVariable ["wfbe_aicom_route_seq", _hcSeq + 1, true];
                                            _team setVariable ["wfbe_aicom_unstuck", 0, true];
                                            _team setVariable ["wfbe_aicom_order", [_hcSeq + 1, "towns-target", _destination, 0], true];
                                        };
                                        //--- This signal is intentionally outside the HC conditional: the same driver also runs server-local.
                                        _team setVariable ["wfbe_aicom_endgame_tp", [_destination, time], true];
                                        _team setVariable ["wfbe_aicom_endgame_tp_last", time];
                                        _count = _count + 1;
                                        _townName = _destinationTown getVariable ["name", "town"];
                                        ["INFORMATION", Format ["AI_Commander_EndgameTeleport.sqf: [%1] team [%2] ordered %3m -> %4.", _side, _team, round (_leader distance _destination), _townName]] Call WFBE_CO_FNC_AICOMLog;
                                        diag_log ("AICOMSTAT|v2|EVENT|" + str _sideID + "|" + str (round (time / 60)) + "|ENDGAME_TELEPORT_ORDER|team=" + (str _team) + "|dist=" + str (round (_leader distance _destination)));
                                    };
                                };
                            };
                        };
                    };
                };
            };
        };
    };
} forEach _teams;
