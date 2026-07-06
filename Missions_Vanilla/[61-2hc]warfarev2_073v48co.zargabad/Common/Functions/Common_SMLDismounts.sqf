//--- SML-2: Real Dismounts (GR-2026-07-03a)
//--- HC-local only (spawned by Common_RunCommanderTeam.sqf on the HC that owns the group).
//--- Gate: caller must already have checked (missionNamespace getVariable ["WFBE_C_SML_DISMOUNTS",0]) > 0.
//---
//--- args: [_team, _footInf, _sideID, _side, _capSeq, _campFirstEnd]
//---   _footInf = non-crew foot infantry array (already built by caller; excludes driver/gunner)
//---
//--- Behaviour:
//---   Identifies _footInf units still in cargo of a vehicle (driver/gunner already excluded).
//---   Issues unassignVehicle + orderGetIn false for each cargo unit, forcing them onto their feet.
//---   Vehicle crew (driver/gunner seats) remain mounted for fire support -- they are never in
//---   _footInf by the caller convention, so SML-2 never touches them.
//---   Only units SML-2 actually dismounts are tracked in _detachedBySML2 for rejoin.
//---   Rejoin (doFollow) on: campfirst_end, TTL, leader death, disband, retasked, group_change.
//---
//--- Stamp discipline: wfbe_sml_detach_at set on detach, cleared to nil on rejoin.
//---   Coexistence: checks stamp before setting; skips units already choreographed by SML-1/3/4/5.
//---   SML-2 is CONCURRENT with SML-1 (both Spawn from the same camp-first hook site).
//---   SML-3 and SML-4 Spawn later (depot-center hold entry). SML-5 is a synchronous Call.
//---   No stamp collision possible with SML-3/4 at SML-2 hook time because those have not
//---   fired yet; if a unit is already stamped at this point it must be from SML-1 or a previous
//---   SML-2 on a prior assault leg.
//---
//--- Remount idiom: on rejoin SML-2 uses doFollow (not moveInCargo / assignAsCargo) because:
//---   (a) the vehicle may have moved or been destroyed by rejoin time,
//---   (b) doFollow restores normal group AI behavior and lets the AI decide whether to
//---       re-board on its own, matching SML-1/3/4/5 rejoin pattern.
//---
//--- TTL watchdog exit paths:
//---   ttl           -- WFBE_C_SML_WATCHDOG_TTL expired (shared constant, default 240s)
//---   campfirst_end -- camp-first window closed (_campFirstEnd passed)
//---   leader_dead   -- leader is null or dead
//---   disband       -- wfbe_aicom_disband set on _team
//---   retasked      -- wfbe_aicom_order seq changed
//---   group_change  -- any dismounted unit left _team
//---
//--- TELEMETRY (diag_log, always active on HC):
//---   SML|v1|DISMOUNT|...  on entry (after dismounts issued)
//---   SML|v1|REMOUNT|...   on each exit path

private ["_team","_footInf","_sideID","_side","_capSeq","_campFirstEnd"];
private ["_ttl","_stamp","_exitReason","_detachedBySML2","_dismountCount","_seatedStill"];
private ["_aliveCheck","_disbandFlag","_ordN","_grpChg","_uX"];

_team         = _this select 0;
_footInf      = _this select 1;
_sideID       = _this select 2;
_side         = _this select 3;
_capSeq       = _this select 4;
_campFirstEnd = _this select 5;

_ttl = missionNamespace getVariable ["WFBE_C_SML_WATCHDOG_TTL", 240];

//--- Need at least one foot soldier to act on.
if (count _footInf < 1) exitWith {};

//--- Identify cargo riders: _footInf already excludes driver/gunner by caller convention.
//--- Any _footInf unit whose vehicle != itself is still in cargo and needs dismounting.
//--- Snapshot into _detachedBySML2; only these units are touched on rejoin.
_detachedBySML2 = [];
_dismountCount  = 0;
{
    _uX = _x;
    if (alive _uX && {vehicle _uX != _uX}) then {
        //--- Skip if already choreographed by another SML feature (stamp already set).
        if (!(isNil {_uX getVariable "wfbe_sml_detach_at"})) then {
            //--- Already stamped; let the owning SML manage this unit.
        } else {
            //--- Dismount idiom: unassignVehicle clears the seat reservation; moveOut ejects
            //--- the unit immediately regardless of boarding state (proven in-tree at
            //--- AI_Commander_MHQReloc.sqf:453 `moveOut _drv`). orderGetIn false only cancels
            //--- a PENDING board order and is a silent no-op for already-seated cargo.
            //--- HC locality holds: this script runs on the HC that owns the group.
            unassignVehicle _uX;
            moveOut _uX;
            _uX setVariable ["wfbe_sml_detach_at", time];
            _detachedBySML2 set [count _detachedBySML2, _uX];
            _dismountCount = _dismountCount + 1;
        };
    };
} forEach _footInf;

//--- Nothing to do: all _footInf already on foot or already stamped by another SML.
if (_dismountCount == 0) exitWith {};

//--- Honest telemetry: recount how many are still seated after moveOut (should be 0;
//--- non-zero means a unit was re-seated or moveOut failed for some reason).
_seatedStill = 0;
{
    _uX = _x;
    if (alive _uX && {vehicle _uX != _uX}) then {_seatedStill = _seatedStill + 1};
} forEach _detachedBySML2;

diag_log Format ["SML|v1|DISMOUNT|side=%1 team=%2 dismounted=%3 seated_still=%4 ttl=%5",
    _side, _team, _dismountCount, _seatedStill, _ttl];

//--- ===== WATCHDOG LOOP =====
//--- Poll until any exit condition fires, then clear stamps and doFollow.
//--- exitWith inside while {}-do {} leaves the while only; it does NOT propagate through forEach.
_stamp      = time;
_exitReason = "ttl";

while {true} do {

    //--- (a) TTL expiry
    if (time > _stamp + _ttl) exitWith {_exitReason = "ttl"};

    //--- (b) Camp-first window closed (outer window expired; foot advance phase is over)
    if (time >= _campFirstEnd) exitWith {_exitReason = "campfirst_end"};

    //--- (c) leader death
    _aliveCheck = !isNull leader _team;
    if (_aliveCheck) then {_aliveCheck = alive (leader _team)};
    if (!_aliveCheck) exitWith {_exitReason = "leader_dead"};

    //--- (d) team disband flag (GROUP variable; use 1-arg getVariable + isNil per A2 OA trap)
    _disbandFlag = _team getVariable "wfbe_aicom_disband";
    if (!(isNil "_disbandFlag") && {_disbandFlag}) exitWith {_exitReason = "disband"};

    //--- (e) new commander order (capSeq changed) -- retasked mid-assault
    _ordN = _team getVariable "wfbe_aicom_order";
    if (isNil "_ordN") then {_ordN = []};
    if (count _ordN >= 1 && {(_ordN select 0) != _capSeq}) exitWith {_exitReason = "retasked"};

    //--- (f) unit group change: any live dismounted unit no longer in _team
    //--- Note: exitWith inside forEach exits the forEach scope only, NOT this while loop.
    //--- A flag avoids the A2 OA exitWith-scope trap.
    _grpChg = false;
    {
        _uX = _x;
        if (alive _uX && {!(group _uX == _team)}) then {_grpChg = true};
    } forEach _detachedBySML2;
    if (_grpChg) exitWith {_exitReason = "group_change"};

    sleep 3;
};

//--- ===== REJOIN: clear stamp + doFollow on every dismounted unit =====
//--- doFollow is the only reliable way to clear any sticky doStop/doMove in A2 OA.
//--- setUnitPos "AUTO" restores the default stance hand-off back to the AI.
//--- We use doFollow rather than moveInCargo because the vehicle may have moved or died.
{
    _uX = _x;
    _uX setVariable ["wfbe_sml_detach_at", nil];
    if (alive _uX && {_uX in (units _team)}) then {
        _uX setUnitPos "AUTO";
        //--- W1: guard leader before doFollow, matching SML-3/4 idiom.
        if (!isNull (leader _team) && {alive (leader _team)}) then {
            _uX doFollow (leader _team);
        };
    };
} forEach _detachedBySML2;

diag_log Format ["SML|v1|REMOUNT|side=%1 team=%2 reason=%3 elapsed=%4",
    _side, _team, _exitReason, round (time - _stamp)];
