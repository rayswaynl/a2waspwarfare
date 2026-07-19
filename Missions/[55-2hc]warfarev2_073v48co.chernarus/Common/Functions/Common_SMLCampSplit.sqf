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
//---   SML-1 claims only unowned foot infantry, ejects its owned seated units,
//---   then splits that owned set for the on-foot camp scan.  Its TTL watchdog
//---   receipt uses the shared wfbe_sml_detach_at stamp.
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
Private ["_ttl","_splitDone","_groupA","_groupB","_hold","_campA","_campB","_holdPos","_detachedBySML1"];
Private ["_nFoot","_half","_halfTwo","_i","_stamp","_exitReason"];
Private ["_aliveCheck","_ordN","_disbandFlag","_grpChg","_campsDone"];

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

//--- Claim only unowned units.  SML-1 and SML-2 are independent spawned workers;
//--- preserving an existing stamp leaves its watchdog/rejoin lifecycle with the
//--- worker that already owns it.  The owned receipt also bounds every SML-1
//--- movement and cleanup below, so a foreign watchdog cannot release a split unit.
_stamp = time;
_detachedBySML1 = [];
{
    if (isNil {_x getVariable "wfbe_sml_detach_at"}) then {
        _x setVariable ["wfbe_sml_detach_at", _stamp];
        _detachedBySML1 set [count _detachedBySML1, _x];
    };
} forEach _footInf;

_nFoot = count _detachedBySML1;
if (_nFoot < 3) exitWith {
    //--- No meaningful owned split: release the fresh claim after making any
    //--- owned cargo walkable for the caller's normal camp sweep.
    {
        if (alive _x && {vehicle _x != _x}) then {
            unassignVehicle _x;
            moveOut _x;
        };
        _x setVariable ["wfbe_sml_detach_at", nil];
    } forEach _detachedBySML1;
};

//--- Pick the two target camps (already sorted by caller proximity; index 0 = nearest).
_campA = _unheldCamps select 0;
_campB = _unheldCamps select 1;

//--- Split only the units whose stamp/watchdog SML-1 owns.
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
} forEach _detachedBySML1;

//--- Hold position: midpoint between the two camps, biased 2x toward _townCenter.
_holdPos = [
    (((getPos _campA) select 0) + ((getPos _campB) select 0) + (_townCenter select 0) * 2) / 4,
    (((getPos _campA) select 1) + ((getPos _campB) select 1) + (_townCenter select 1) * 2) / 4,
    0
];

//--- Eject only SML-1-owned seated foot infantry.  SML-2 has the same idiom for
//--- the alternate scheduling order, and foreign-stamped units remain untouched.
{
    if (alive _x && {vehicle _x != _x}) then {
        unassignVehicle _x;
        moveOut _x;
    };
} forEach _detachedBySML1;

//--- Issue one-shot movement orders (doStop keeps unit in group, doMove sends it).
{ if (alive _x) then {doStop _x; _x doMove (getPos _campA)} } forEach _groupA;
{ if (alive _x) then {doStop _x; _x doMove (getPos _campB)} } forEach _groupB;
{ if (alive _x) then {doStop _x; _x doMove _holdPos} } forEach _hold;

diag_log Format ["SML|v1|SPLIT|side=%1 team=%2 campA=%3 campB=%4 gA=%5 gB=%6 hold=%7 ttl=%8",
    _side, _team,
    if (!isNull _campA) then {str (getPos _campA)} else {"null"}, //--- fable/sml-overwatch-nan: camp logics carry no name var (log read "?" forever); position is distinct + mappable
    if (!isNull _campB) then {str (getPos _campB)} else {"null"},
    count _groupA, count _groupB, count _hold, _ttl];

//--- ===== WATCHDOG LOOP =====
//--- Poll until any exit condition fires, then issue doFollow for SML-1-owned detached units.
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
    //--- A2 OA rule: exitWith exits the scope of its direct if - must sit directly in the
    //--- while-loop body, not inside a nested then-block. Use a flag variable instead.
    _campsDone = (!isNull _campA && {!isNull _campB}
        && {(_campA getVariable ["sideID",-1]) == _sideID}
        && {(_campB getVariable ["sideID",-1]) == _sideID});
    if (_campsDone) exitWith {_exitReason = "camps_done"};

    //--- (c) unit group change: any live detached unit no longer in _team -> bail
    //--- Note: exitWith inside forEach exits the forEach scope, NOT this while loop.
    //--- Use a flag instead (A2 OA safe pattern).
    _grpChg = false;
    {
        if (alive _x && {!(group _x == _team)}) then {_grpChg = true};
    } forEach _detachedBySML1;
    if (_grpChg) exitWith {_exitReason = "group_change"};

    sleep 3;
};

//--- ===== REJOIN: clear stamp + doFollow only SML-1-owned detached units =====
//--- doFollow is the ONLY reliable way to clear a sticky doStop in A2 OA.
{
    _x setVariable ["wfbe_sml_detach_at", nil];
    if (alive _x) then {_x setUnitPos "AUTO"; _x doFollow (leader _team)};
} forEach _detachedBySML1;

diag_log Format ["SML|v1|REJOIN|side=%1 team=%2 reason=%3 elapsed=%4",
    _side, _team, _exitReason, round (time - _stamp)];
