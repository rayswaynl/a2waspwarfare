//--- SML-5: Surgical Unstuck
//--- HC-local only (called synchronously from the unstuck Spawn in Common_RunCommanderTeam.sqf,
//--- as a PRE-TIER step BEFORE tier 1/2/3 escalation fires).
//--- Gate: caller must already have checked (missionNamespace getVariable ["WFBE_C_SML_SURGICAL_UNSTUCK",0]) > 0.
//---
//--- args: [_uTeam, _uSide]
//---
//--- Behaviour:
//---   When the server-side stuck watcher fires (wfbe_aicom_unstuck > 0), only 1-2 individual
//---   units may actually be wedged. This script checks per-unit position deltas:
//---     - Each alive on-foot unit reads its wfbe_sml_pos_prev stamp (set on PRIOR unstuck call)
//---     - If no stamp: initialise stamp now, skip nudging (first observation)
//---     - If stamp exists and distance from prev pos < WFBE_C_SML_UNSTUCK_POS_DELTA: mark wedged
//---   If wedgedCount == 0 OR wedgedCount > WFBE_C_SML_UNSTUCK_MAX_UNITS:
//---     return without nudging (fall through to tier escalation which handles whole-team or no-op).
//---   For each confirmed-wedged unit (up to max):
//---     - Serialize via stamp: if wfbe_sml_detach_at already set, skip (another SML owns it)
//---     - Stamp wfbe_sml_detach_at = time
//---     - Compute nudge bearing: toward the team's order destination (read wfbe_aicom_order group var)
//---     - doStop + doMove nudge_dist meters in that direction
//---   Short TTL watchdog (30s or until all nudged units moved > pos_delta):
//---     exits early when movement detected; full tier ladder still fires after this Call returns.
//---   REJOIN: for each nudged unit: clear stamp, doFollow if alive.
//---
//--- Critical interplay with tier ladder:
//---   This is a CALL (synchronous), not a Spawn. It runs, then execution returns to the Spawn
//---   and the tier 1/2/3 ladder proceeds as normal regardless of what happened here.
//---   At flag 0 this Call is never reached — tier logic is byte-identical to HEAD.
//---   At flag 1 it inserts a pre-tier step only; tier escalation is never altered or suppressed.
//---   The tier ladder may still reverse/teleport the lead hull — the surgical nudge is additive.
//---
//--- Interplay with SML-1, SML-3, SML-4:
//---   All share wfbe_sml_detach_at. SML-5 checks and skips any unit already stamped by another
//---   feature. The pos-prev stamp (wfbe_sml_pos_prev) is distinct from the choreography stamp.
//---
//--- Exit paths (watchdog only — the Call itself always returns to its caller):
//---   (a) nudge TTL (30s)
//---   (b) all nudged units moved > pos_delta
//---   (c) leader dead
//---   (d) team disband
//---   (e) group change for any nudged unit
//---
//--- TELEMETRY (diag_log, always active on HC):
//---   SML|v1|SURGICAL_UNSTUCK|...      on nudge entry
//---   SML|v1|SURGICAL_UNSTUCK_DONE|... on watchdog exit

Private ["_uTeam","_uSide"];
Private ["_maxUnits","_posDelta","_nudgeDist","_nudgeTtl"];
Private ["_liveFootUnits","_u","_prevPos","_curPos","_dx","_dy","_delta"];
Private ["_wedged","_nudged","_stmp","_stmpChk","_ordN","_orderDest","_nudgeBrg","_nudgePos"];
Private ["_uLdr","_watchDone","_exitReason","_watchStamp","_allMoved","_disbandFlag","_grpChg"];

_uTeam = _this select 0;
_uSide = _this select 1;

_maxUnits  = missionNamespace getVariable ["WFBE_C_SML_UNSTUCK_MAX_UNITS", 2];
_posDelta  = missionNamespace getVariable ["WFBE_C_SML_UNSTUCK_POS_DELTA", 8];
_nudgeDist = missionNamespace getVariable ["WFBE_C_SML_UNSTUCK_NUDGE_DIST", 20];
_nudgeTtl  = 30;

_uLdr = leader _uTeam;
if (isNull _uLdr || {!alive _uLdr}) exitWith {};

//--- Collect alive on-foot units (vehicle _x == _x = on foot; A2-safe).
_liveFootUnits = [];
{
    if (alive _x && {(vehicle _x) == _x}) then {
        _liveFootUnits = _liveFootUnits + [_x];
    };
} forEach (units _uTeam);

if (count _liveFootUnits < 1) exitWith {};

//--- Determine which units are wedged by checking position delta since last call.
_wedged = [];
{
    _u      = _x;
    _curPos = getPos _u;
    _prevPos = _u getVariable "wfbe_sml_pos_prev";
    if (isNil "_prevPos") then {
        //--- First observation: stamp current pos and do not mark as wedged yet.
        _u setVariable ["wfbe_sml_pos_prev", [(_curPos select 0), (_curPos select 1)]];
    } else {
        _dx    = (_curPos select 0) - (_prevPos select 0);
        _dy    = (_curPos select 1) - (_prevPos select 1);
        _delta = sqrt ((_dx * _dx) + (_dy * _dy));
        if (_delta < _posDelta) then {
            _wedged = _wedged + [_u];
        } else {
            //--- Moved: refresh the position stamp so future checks use this new baseline.
            _u setVariable ["wfbe_sml_pos_prev", [(_curPos select 0), (_curPos select 1)]];
        };
    };
} forEach _liveFootUnits;

//--- Zero wedged or too many: fall through to tier escalation.
if (count _wedged < 1 || {count _wedged > _maxUnits}) exitWith {};

//--- Read the team's order destination for the nudge bearing.
_ordN       = _uTeam getVariable "wfbe_aicom_order";
_orderDest  = objNull;
if (!(isNil "_ordN") && {count _ordN >= 3}) then {_orderDest = _ordN select 2};

//--- Nudge confirmed-wedged units.
_nudged = [];
_stmp   = time;
{
    _u = _x;
    //--- Skip if another SML feature already choreographs this unit.
    _stmpChk = _u getVariable "wfbe_sml_detach_at";
    if (isNil "_stmpChk") then {
        //--- Compute bearing toward order dest; fall back to leader direction.
        if (!(isNil "_orderDest") && {typeName _orderDest == "ARRAY"} && {count _orderDest >= 2}) then {
            _nudgeBrg = (((_orderDest select 0) - ((getPos _u) select 0)) atan2 ((_orderDest select 1) - ((getPos _u) select 1)));
        } else {
            _nudgeBrg = getDir _uLdr;
        };
        _nudgePos = [((getPos _u) select 0) + _nudgeDist * (sin _nudgeBrg), ((getPos _u) select 1) + _nudgeDist * (cos _nudgeBrg), 0];
        _u setVariable ["wfbe_sml_detach_at", _stmp];
        _u setVariable ["wfbe_sml_pos_prev", [(_nudgePos select 0), (_nudgePos select 1)]];
        doStop _u;
        _u doMove _nudgePos;
        _nudged = _nudged + [_u];
    };
} forEach _wedged;

if (count _nudged < 1) exitWith {};

diag_log Format ["SML|v1|SURGICAL_UNSTUCK|side=%1 team=%2 wedged=%3 nudged=%4 dist=%5",
    _uSide, _uTeam, count _wedged, count _nudged, _nudgeDist];

//--- ===== SHORT WATCHDOG (30s) =====
//--- The tier ladder fires AFTER this Call returns, so we use a short dwell.
_watchDone  = false;
_exitReason = "ttl";
_watchStamp = time;

while {!_watchDone} do {

    //--- (a) TTL
    if (time > _watchStamp + _nudgeTtl) exitWith {_exitReason = "ttl"};

    //--- (c) leader dead
    if (isNull (leader _uTeam) || {!alive (leader _uTeam)}) exitWith {_exitReason = "leader_dead"};

    //--- (d) team disband
    _disbandFlag = _uTeam getVariable "wfbe_aicom_disband";
    if (!(isNil "_disbandFlag") && {_disbandFlag}) exitWith {_exitReason = "disband"};

    //--- (e) group change
    _grpChg = false;
    {
        if (alive _x && {!(group _x == _uTeam)}) then {_grpChg = true};
    } forEach _nudged;
    if (_grpChg) exitWith {_exitReason = "group_change"};

    //--- (b) all nudged units moved > _posDelta from their nudge origin
    _allMoved = true;
    {
        _u = _x;
        if (alive _u) then {
            _prevPos = _u getVariable "wfbe_sml_pos_prev";
            _curPos  = getPos _u;
            if (!(isNil "_prevPos")) then {
                _dx    = (_curPos select 0) - (_prevPos select 0);
                _dy    = (_curPos select 1) - (_prevPos select 1);
                _delta = sqrt ((_dx * _dx) + (_dy * _dy));
                if (_delta < _posDelta) then {_allMoved = false};
            };
        };
    } forEach _nudged;
    if (_allMoved) exitWith {_exitReason = "all_moved"};

    sleep 3;
};

//--- ===== REJOIN =====
{
    _x setVariable ["wfbe_sml_detach_at", nil];
    if (alive _x) then {_x setUnitPos "AUTO"; _x doFollow (leader _uTeam)};
} forEach _nudged;

diag_log Format ["SML|v1|SURGICAL_UNSTUCK_DONE|side=%1 team=%2 reason=%3 elapsed=%4",
    _uSide, _uTeam, _exitReason, round (time - _watchStamp)];
