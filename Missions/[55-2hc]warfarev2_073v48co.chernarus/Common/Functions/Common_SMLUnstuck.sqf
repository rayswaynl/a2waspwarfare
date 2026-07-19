//--- SML-5: Surgical Unstuck (GR-2026-07-03a)
//--- PRE-TIER step in the unstuck ladder: nudges only the individually wedged on-foot units.
//--- Called synchronously (Call, not Spawn) from inside the existing UNSTUCK Spawn block.
//--- Args: [_uTeam, _uSide]
//--- Returns: true if a nudge was fired, false if tier escalation should handle it.
//--- Stamp discipline: wfbe_sml_detach_at set on detach, cleared to nil on rejoin.
//--- Flag-gated: WFBE_C_SML_SURGICAL_UNSTUCK default 1 (ON) - see Init_CommonConstants.sqf.
//--- fix(docs): this header previously claimed "default 0", which never matched the shipped
//--- default (1, live) in Init_CommonConstants.sqf. Comment-only correction; no behaviour change.
private ["_uTeam","_uSide","_maxUnits","_posDelta","_nudgeDist",
         "_liveFootUnits","_wedged","_nudged","_wedgedCount",
         "_uX","_prevPos","_curPos","_dx","_dy","_delta2",
         "_bearing","_nudgePos","_orderArr","_dest","_destX","_destY",
         "_startTime","_shortTTL","_elapsed","_reason",
         "_disbanded","_disbandFlag","_leaderDead","_allMoved","_groupChanged",
         "_nX","_startPosX","_startPosY","_uNudge",
         "_capSeq","_ordN","_retasked"];
_uTeam = _this select 0;
_uSide = _this select 1;

//--- Capture initial order-seq for retasked detection (mirrors SML-3/SML-4 idiom).
_capSeq = -1;
_ordN = _uTeam getVariable "wfbe_aicom_order";
if (!isNil "_ordN" && {count _ordN >= 1}) then {_capSeq = _ordN select 0};

_maxUnits  = missionNamespace getVariable ["WFBE_C_SML_UNSTUCK_MAX_UNITS", 2];
_posDelta  = missionNamespace getVariable ["WFBE_C_SML_UNSTUCK_POS_DELTA", 8];
_nudgeDist = missionNamespace getVariable ["WFBE_C_SML_UNSTUCK_NUDGE_DIST", 20];
_shortTTL  = 30;
_startTime = time;

//--- Step 1: Gather live on-foot units (not in a vehicle).
_liveFootUnits = [];
{
    _uX = _x;
    if (alive _uX && {vehicle _uX == _uX}) then {
        _liveFootUnits = _liveFootUnits + [_uX];
    };
} forEach (units _uTeam);

//--- Step 2: Check per-unit position snapshots to find wedged units.
_wedged = [];
{
    _uX = _x;
    _prevPos = _uX getVariable "wfbe_sml_pos_prev";
    _curPos  = [((getPos _uX) select 0), ((getPos _uX) select 1)];
    if (isNil "_prevPos") then {
        //--- First check: stamp position, not yet confirmed stuck.
        _uX setVariable ["wfbe_sml_pos_prev", _curPos];
    } else {
        _dx     = (_curPos select 0) - (_prevPos select 0);
        _dy     = (_curPos select 1) - (_prevPos select 1);
        _delta2 = _dx * _dx + _dy * _dy;
        if (_delta2 < (_posDelta * _posDelta)) then {
            //--- Has not moved enough: wedged.
            _wedged = _wedged + [_uX];
        } else {
            //--- Still moving: update stamp.
            _uX setVariable ["wfbe_sml_pos_prev", _curPos];
        };
    };
} forEach _liveFootUnits;

_wedgedCount = count _wedged;

//--- Step 3: If none wedged or too many, let tier escalation handle it.
if (_wedgedCount == 0 || {_wedgedCount > _maxUnits}) exitWith {false};

//--- Step 4: Read order destination for nudge bearing.
_orderArr = _uTeam getVariable "wfbe_aicom_order";
if (isNil "_orderArr") then {_orderArr = []};
_dest = [];
if (count _orderArr >= 3) then {_dest = _orderArr select 2};

//--- Step 5: Nudge each wedged unit.
_nudged = [];
{
    _uX = _x;
    //--- Skip if already choreographed by another SML feature.
    if (!(isNil {_uX getVariable "wfbe_sml_detach_at"})) then {
        //--- Already stamped; skip.
    } else {
        _uX setVariable ["wfbe_sml_detach_at", time];
        _curPos = getPos _uX;
        if (count _dest >= 2) then {
            _bearing = ((_dest select 0) - (_curPos select 0)) atan2 ((_dest select 1) - (_curPos select 1));
        } else {
            _bearing = getDir (leader _uTeam);
        };
        _nudgePos = [(_curPos select 0) + _nudgeDist * (sin _bearing), (_curPos select 1) + _nudgeDist * (cos _bearing), 0];
        doStop _uX;
        _uX doMove _nudgePos;
        _nudged = _nudged + [[_uX, (_curPos select 0), (_curPos select 1)]];
    };
} forEach _wedged;

if (count _nudged == 0) exitWith {false};

diag_log Format ["SML|v1|SURGICAL_UNSTUCK|side=%1 team=%2 wedged=%3 nudged=%4", _uSide, _uTeam, _wedgedCount, count _nudged];

//--- SHORT WATCHDOG (30s): wait until nudged units have moved or TTL.
_reason = "ttl_30s";
_disbandFlag = "wfbe_aicom_disband";
waitUntil {
    sleep 3;
    _elapsed = time - _startTime;

    //--- (a) Short TTL.
    if (_elapsed >= _shortTTL) then {_reason = "ttl_30s"; true} else {

    //--- (b) Leader death.
    _leaderDead = (!alive (leader _uTeam)) || {isNull (leader _uTeam)};
    if (_leaderDead) then {_reason = "leader_dead"; true} else {

    //--- (c) Team disband flag.
    _disbanded = _uTeam getVariable _disbandFlag;
    if (isNil "_disbanded") then {_disbanded = false};
    if (_disbanded) then {_reason = "disband"; true} else {

    //--- (d) Retask: order seq changed (mirrors SML-3/SML-4 idiom).
    _ordN = _uTeam getVariable "wfbe_aicom_order";
    if (isNil "_ordN") then {_ordN = []};
    _retasked = (count _ordN >= 1) && {(_ordN select 0) != _capSeq};
    if (_retasked) then {_reason = "retasked"; true} else {

    //--- (e) All nudged units have moved enough OR are dead.
    _allMoved = true;
    {
        _uNudge    = _x select 0;
        _startPosX = _x select 1;
        _startPosY = _x select 2;
        if (alive _uNudge) then {
            _dx = ((getPos _uNudge) select 0) - _startPosX;
            _dy = ((getPos _uNudge) select 1) - _startPosY;
            if ((_dx * _dx + _dy * _dy) < (_posDelta * _posDelta)) then {_allMoved = false};
        };
    } forEach _nudged;
    if (_allMoved) then {_reason = "all_moved"; true} else {

    //--- (e) Group change: any nudged unit no longer in team.
    _groupChanged = false;
    {
        _uNudge = _x select 0;
        if (alive _uNudge && {!(_uNudge in (units _uTeam))}) then {_groupChanged = true};
    } forEach _nudged;
    if (_groupChanged) then {_reason = "group_change"; true} else {false}
    }}}}}
};

//--- REJOIN: restore each nudged unit.
{
    _uNudge = _x select 0;
    _uNudge setVariable ["wfbe_sml_detach_at", nil];
    _uNudge setVariable ["wfbe_sml_pos_prev", nil];
    if (alive _uNudge && {_uNudge in (units _uTeam)}) then {
        _uNudge doFollow (leader _uTeam);
    };
} forEach _nudged;

diag_log Format ["SML|v1|SURGICAL_UNSTUCK_DONE|side=%1 team=%2 reason=%3 elapsed=%4", _uSide, _uTeam, _reason, (time - _startTime)];

//--- Return true: nudge fired; tier escalation continues (Call returns here then Spawn resumes).
true
