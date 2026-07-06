//--- SML-1: Camp-Split Captures
//--- HC-local only (spawned by Common_RunCommanderTeam.sqf on the HC that owns the group).
//--- Gate: caller must already have checked (missionNamespace getVariable ["WFBE_C_SML_CAMP_SPLIT",0]) > 0.
//---
//--- args: [_team, _footInf, _unheldCamps, _sideID, _side, _townCenter, _capSeq, _campFirstEnd]
//---   _townCenter = position array [x,y,z] (already resolved by caller)
//---
//--- Behaviour:
//---   When 2+ camps are unheld, split _footInf into two halves:
//---     Group-A -> camp at index 0   (doStop + doMove)
//---     Group-B -> camp at index 1   (doStop + doMove)
//---     Remainder (leader + hold unit) -> near _townCenter (doStop + doMove)
//---   Each detached unit carries a TTL watchdog stamp (wfbe_sml_detach_at).
//---   All exit paths issue doFollow to clear the sticky doStop:
//---     (a) camp captured / sub-TTL passed
//---     (b) TTL expiry (WFBE_C_SML_WATCHDOG_TTL, default 240s)
//---     (c) leader death or unit group change
//---     (d) new commander order (_capSeq changed) / team left town mode
//---     (e) team disband (wfbe_aicom_disband on group)
//---     (f) script-instance death: per-unit stamp sweeper in Common_RunCommanderTeam.sqf
//---         release-plant line (~line 2017) issues doFollow on ALL _footInf unconditionally,
//---         covering any unit whose stamp is set but whose watchdog script ended early.
//---
//--- TELEMETRY (diag_log, always active on HC):
//---   SML|v1|SPLIT|...  on entry
//---   SML|v1|REJOIN|... on each exit path

Private ["_team","_footInf","_unheldCamps","_sideID","_side","_townCenter","_capSeq","_campFirstEnd"];
Private ["_ttl","_splitDone","_groupA","_groupB","_hold","_campA","_campB","_holdPos"];
Private ["_nFoot","_half","_halfTwo","_i","_stamp","_exitReason"];
Private ["_aliveCheck","_ordN","_disbandFlag","_grpChg"];

_team         = _this select 0;
_footInf      = _this select 1;
_unheldCamps  = _this select 2;
_sideID       = _this select 3;
_side         = _this select 4;
_townCenter   = _this select 5;  //--- already a position array [x,y,z]
_capSeq       = _this select 6;
_campFirstEnd = _this select 7;

_ttl = missionNamespace getVariable ["WFBE_C_SML_WATCHDOG_TTL", 240];

//--- Need 2+ unheld camps and 3+ foot infantry for a meaningful split.
if (count _unheldCamps < 2) exitWith {};
_nFoot = count _footInf;
if (_nFoot < 3) exitWith {};

//--- Pick the two target camps (already sorted by caller proximity; index 0 = nearest).
_campA = _unheldCamps select 0;
_campB = _unheldCamps select 1;

//--- Split: indices 0.._half-1 -> campA, _half.._halfTwo-1 -> campB, remainder -> center hold.
_half    = floor (_nFoot / 2);
if (_half < 1) then {_half = 1};
_halfTwo = _half + _half;

_groupA = [];
_groupB = [];
_hold   = [];

_i = 0;
{
    if (_i < _half) then {
        _groupA = _groupA + [_x];
    } else {
        if (_i < _halfTwo) then {
            _groupB = _groupB + [_x];
        } else {
            _hold = _hold + [_x];
        };
    };
    _i = _i + 1;
} forEach _footInf;

//--- Hold position: midpoint between the two camps, biased 2x toward _townCenter.
_holdPos = [
    (((getPos _campA) select 0) + ((getPos _campB) select 0) + (_townCenter select 0) * 2) / 4,
    (((getPos _campA) select 1) + ((getPos _campB) select 1) + (_townCenter select 1) * 2) / 4,
    0
];

//--- Stamp all detached units with the attach time so the sweeper can recover them (exit path f).
_stamp = time;
{ _x setVariable ["wfbe_sml_detach_at", _stamp] } forEach _footInf;

//--- Issue one-shot movement orders (doStop keeps unit in group, doMove sends it).
{ if (alive _x) then {doStop _x; _x doMove (getPos _campA)} } forEach _groupA;
{ if (alive _x) then {doStop _x; _x doMove (getPos _campB)} } forEach _groupB;
{ if (alive _x) then {doStop _x; _x doMove _holdPos} } forEach _hold;

diag_log Format ["SML|v1|SPLIT|side=%1 team=%2 campA=%3 campB=%4 gA=%5 gB=%6 hold=%7 ttl=%8",
    _side, _team,
    if (!isNull _campA) then {_campA getVariable ["name","?"]} else {"null"},
    if (!isNull _campB) then {_campB getVariable ["name","?"]} else {"null"},
    count _groupA, count _groupB, count _hold, _ttl];

//--- ===== WATCHDOG LOOP =====
//--- Poll until any exit condition fires, then issue doFollow for ALL detached units.
//--- exitWith inside a while {}-do {} leaves the while only; it does NOT propagate through forEach.
_splitDone  = false;
_exitReason = "ttl";

while {!_splitDone} do {

    //--- (b) TTL expiry
    if (time > _stamp + _ttl) exitWith {_exitReason = "ttl"};

    //--- (c) leader death
    _aliveCheck = !isNull leader _team;
    if (_aliveCheck) then {_aliveCheck = alive (leader _team)};
    if (!_aliveCheck) exitWith {_exitReason = "leader_dead"};

    //--- (e) team disband flag (GROUP variable; use 1-arg getVariable + isNil local check per A2 OA trap)
    _disbandFlag = _team getVariable "wfbe_aicom_disband";
    if (!(isNil "_disbandFlag") && {_disbandFlag}) exitWith {_exitReason = "disband"};

    //--- (d) new commander order (capSeq changed) — uses 1-arg getVariable which returns nil if unset
    _ordN = _team getVariable "wfbe_aicom_order";
    if (isNil "_ordN") then {_ordN = []};
    if (count _ordN >= 1 && {(_ordN select 0) != _capSeq}) exitWith {_exitReason = "retasked"};

    //--- (d) campFirstEnd expired (outer window closed)
    if (time >= _campFirstEnd) exitWith {_exitReason = "campfirst_end"};

    //--- (a) check if BOTH camps are now held by our side (sideID flipped to _sideID)
    if (!isNull _campA && {!isNull _campB}) then {
        if ((_campA getVariable ["sideID",-1]) == _sideID && {(_campB getVariable ["sideID",-1]) == _sideID}) exitWith {_exitReason = "camps_done"};
    };

    //--- (c) unit group change: any live detached unit no longer in _team -> bail
    //--- Note: exitWith inside forEach exits the forEach scope, NOT this while loop.
    //--- Use a flag instead (A2 OA safe pattern).
    _grpChg = false;
    {
        if (alive _x && {!(group _x == _team)}) then {_grpChg = true};
    } forEach _footInf;
    if (_grpChg) exitWith {_exitReason = "group_change"};

    sleep 3;
};

//--- ===== REJOIN: clear stamp + doFollow on every detached unit =====
//--- doFollow is the ONLY reliable way to clear a sticky doStop in A2 OA.
{
    _x setVariable ["wfbe_sml_detach_at", nil];
    if (alive _x) then {_x setUnitPos "AUTO"; _x doFollow (leader _team)};
} forEach _footInf;

diag_log Format ["SML|v1|REJOIN|side=%1 team=%2 reason=%3 elapsed=%4",
    _side, _team, _exitReason, round (time - _stamp)];
