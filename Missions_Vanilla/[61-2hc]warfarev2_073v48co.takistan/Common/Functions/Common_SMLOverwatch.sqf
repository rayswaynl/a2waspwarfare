//--- SML-4: AT Overwatch
//--- HC-local only (spawned by Common_RunCommanderTeam.sqf before the depot-hold assault begins).
//--- Gate: caller must already have checked (missionNamespace getVariable ["WFBE_C_SML_AT_OVERWATCH",0]) > 0.
//---
//--- args: [_team, _footInf, _sideID, _side, _townCenter, _dest, _capSeq]
//---   _dest      = the order destination (same as the outer _dest, i.e. the town/objective position)
//---
//--- Behaviour:
//---   Before the assault begins, finds the first alive foot infantry unit in _footInf that:
//---     (a) carries a non-empty secondaryWeapon (launcher/AT)
//---     (b) is not already choreographed by another SML feature (wfbe_sml_detach_at stamp is nil)
//---   Scans for hostile armor (Tank class) near _townCenter within WFBE_C_SML_AT_OVERWATCH_ARMOR_R.
//---   If both conditions are met, positions the launcher on the armor approach vector before the
//---   assault starts, using a TTL watchdog. On completion or timeout, it rejoins the team.
//---
//--- Exit paths:
//---   (a) TTL expiry (WFBE_C_SML_WATCHDOG_TTL, default 240s)
//---   (b) launcher dead
//---   (c) leader dead
//---   (d) team disband (wfbe_aicom_disband)
//---   (e) retask: wfbe_aicom_order seq changed from _capSeq
//---   (f) no more hostile armor in range (assault complete / armor withdrawn)
//---   (g) group change: launcher no longer in _team
//---   Sweeper: plant-release in RunCommanderTeam (~L2022) issues doFollow on all _footInf
//---   unconditionally, covering any unit whose stamp is set but watchdog ended early.
//---
//--- Interplay with SML-1 (camp-split) and SML-3 (retreat):
//---   All three share the per-unit wfbe_sml_detach_at stamp for mutual exclusion.
//---   SML-4 fires from the pre-assault window (after camp-first, before depot-hold).
//---   SML-1 fires from camp-first (non-overlapping). SML-3 fires from depot-hold phase.
//---   The stamp check here ensures no unit is double-choreographed.
//---
//--- TELEMETRY (diag_log, always active on HC):
//---   SML|v1|OVERWATCH|...        on entry
//---   SML|v1|OVERWATCH_REJOIN|... on each exit path

Private ["_team","_footInf","_sideID","_side","_townCenter","_dest","_capSeq"];
Private ["_ttl","_armorR","_offset","_stamp","_exitReason"];
Private ["_launcher","_u","_stmp","_hostileArmor","_armorTank","_bearing"];
Private ["_overwatchPos","_watchDone","_aliveCheck","_ordN","_disbandFlag","_grpChg","_noArmor"];

_team       = _this select 0;
_footInf    = _this select 1;
_sideID     = _this select 2;
_side       = _this select 3;
_townCenter = _this select 4;
_dest       = _this select 5;
_capSeq     = _this select 6;

_ttl    = missionNamespace getVariable ["WFBE_C_SML_WATCHDOG_TTL", 240];
_armorR = missionNamespace getVariable ["WFBE_C_SML_AT_OVERWATCH_ARMOR_R", 500];
_offset = missionNamespace getVariable ["WFBE_C_SML_AT_OVERWATCH_OFFSET", 80];

//--- Find the first eligible launcher soldier: alive, has secondaryWeapon, not already stamped.
_launcher = objNull;
{
    _u = _x;
    if (isNull _launcher && {alive _u} && {(secondaryWeapon _u) != ""}) then {
        _stmp = _u getVariable "wfbe_sml_detach_at";
        if (isNil "_stmp") then {_launcher = _u};
    };
} forEach _footInf;

if (isNull _launcher) exitWith {};

//--- Scan for hostile armor near _townCenter.
_hostileArmor = [];
{
    if (alive _x && {(_side getFriend (side _x)) < 0.6}) then {
        _hostileArmor = _hostileArmor + [_x];
    };
} forEach (_townCenter nearEntities [["Tank"], _armorR]);

if (count _hostileArmor < 1) exitWith {};

_armorTank = _hostileArmor select 0;

//--- Overwatch position: on the armor approach vector (bearing from dest toward armor tank),
//--- offset _offset meters from _dest in that direction so the launcher overlooks the approach.
//--- atan2 bearing: delta-X atan2 delta-Y (A2 OA idiom, same as L1582 armor screen).
_bearing = (((getPos _armorTank) select 0) - (_dest select 0)) atan2 (((getPos _armorTank) select 1) - (_dest select 1));
_overwatchPos = [(_dest select 0) + _offset * (sin _bearing), (_dest select 1) + _offset * (cos _bearing), 0];

//--- Stamp and issue overwatch order.
_stamp = time;
_launcher setVariable ["wfbe_sml_detach_at", _stamp];
doStop _launcher;
_launcher doMove _overwatchPos;

diag_log Format ["SML|v1|OVERWATCH|side=%1 team=%2 launcher=%3 armorNear=%4 overwatchBrg=%5 ttl=%6",
    _side, _team, typeOf _launcher, count _hostileArmor, round _bearing, _ttl];

//--- ===== WATCHDOG LOOP =====
_watchDone  = false;
_exitReason = "ttl";

while {!_watchDone} do {

    //--- (a) TTL expiry
    if (time > _stamp + _ttl) exitWith {_exitReason = "ttl"};

    //--- (b) launcher dead
    if (!alive _launcher) exitWith {_exitReason = "launcher_dead"};

    //--- (c) leader dead
    _aliveCheck = !isNull leader _team;
    if (_aliveCheck) then {_aliveCheck = alive (leader _team)};
    if (!_aliveCheck) exitWith {_exitReason = "leader_dead"};

    //--- (d) team disband
    _disbandFlag = _team getVariable "wfbe_aicom_disband";
    if (!(isNil "_disbandFlag") && {_disbandFlag}) exitWith {_exitReason = "disband"};

    //--- (e) retask: seq changed
    _ordN = _team getVariable "wfbe_aicom_order";
    if (isNil "_ordN") then {_ordN = []};
    if (count _ordN >= 1 && {(_ordN select 0) != _capSeq}) exitWith {_exitReason = "retasked"};

    //--- (f) no more hostile armor in range (assault cleared it or armor withdrew)
    _noArmor = true;
    {
        if (alive _x && {(_side getFriend (side _x)) < 0.6}) then {_noArmor = false};
    } forEach (_townCenter nearEntities [["Tank"], _armorR]);
    if (_noArmor) exitWith {_exitReason = "no_armor"};

    //--- (g) group change
    _grpChg = !(group _launcher == _team);
    if (_grpChg) exitWith {_exitReason = "group_change"};

    sleep 3;
};

//--- ===== REJOIN: clear stamp + doFollow =====
_launcher setVariable ["wfbe_sml_detach_at", nil];
if (alive _launcher) then {_launcher setUnitPos "AUTO"; _launcher doFollow (leader _team)};

diag_log Format ["SML|v1|OVERWATCH_REJOIN|side=%1 team=%2 reason=%3 elapsed=%4",
    _side, _team, _exitReason, round (time - _stamp)];
