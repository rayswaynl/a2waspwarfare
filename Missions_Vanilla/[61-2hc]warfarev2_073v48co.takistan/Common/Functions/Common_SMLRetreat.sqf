//--- SML-3: Graceful Retreats
//--- HC-local only (spawned by Common_RunCommanderTeam.sqf during the depot-hold phase).
//--- Gate: caller must already have checked (missionNamespace getVariable ["WFBE_C_SML_RETREAT",0]) > 0.
//---
//--- args: [_team, _footInf, _sideID, _side, _townCenter, _capSeq]
//---
//--- Behaviour:
//---   Mauled individual soldiers (getDammage >= WFBE_C_SML_RETREAT_DAMAGE_THRESHOLD) pull back
//---   80m in the direction AWAY from _townCenter while healthy units keep fighting.
//---   If fewer than WFBE_C_SML_RETREAT_HEALTHY_MIN healthy units remain the whole team is mauled;
//---   do NOT try to retreat individuals (let the existing disband/refit systems handle it).
//---   Each retreating unit gets a TTL watchdog stamp (wfbe_sml_detach_at).
//---   Stamp serialize: if a unit already carries a stamp from another SML feature, skip it.
//---
//--- Exit paths:
//---   (a) TTL expiry (WFBE_C_SML_WATCHDOG_TTL, default 240s)
//---   (b) leader death
//---   (c) team disband (wfbe_aicom_disband group var)
//---   (d) retask: wfbe_aicom_order seq changed from _capSeq
//---   (e) all mauled units dead or healed (getDammage < threshold)
//---   (f) group change: any mauled unit no longer in _team
//---   Sweeper: the plant-release line (~L2022 RunCommanderTeam) does doFollow on all _footInf
//---   unconditionally, covering any unit whose stamp is set but whose watchdog script ended early.
//---
//--- Interplay with SML-1 (camp-split):
//---   SML-1 stamps all _footInf on entry. If SML-3 fires AFTER camp-split is still active,
//---   mauled units will already carry a stamp and SML-3 skips them (serialize via stamp check).
//---   SML-3 fires from the depot-hold phase; SML-1 fires from camp-first phase (non-overlapping).
//---
//--- TELEMETRY (diag_log, always active on HC):
//---   SML|v1|RETREAT|...       on entry
//---   SML|v1|RETREAT_REJOIN|... on each exit path

Private ["_team","_footInf","_sideID","_side","_townCenter","_capSeq"];
Private ["_ttl","_threshold","_healthyMin","_stamp","_exitReason"];
Private ["_mauled","_healthyCount","_i","_u","_bearing","_retreatPos","_retreatDone"];
Private ["_aliveCheck","_ordN","_disbandFlag","_grpChg","_allGone","_posU"];

_team       = _this select 0;
_footInf    = _this select 1;
_sideID     = _this select 2;
_side       = _this select 3;
_townCenter = _this select 4;
_capSeq     = _this select 5;

_ttl        = missionNamespace getVariable ["WFBE_C_SML_WATCHDOG_TTL", 240];
_threshold  = missionNamespace getVariable ["WFBE_C_SML_RETREAT_DAMAGE_THRESHOLD", 0.5];
_healthyMin = missionNamespace getVariable ["WFBE_C_SML_RETREAT_HEALTHY_MIN", 4];

//--- Count healthy and mauled units; skip already-stamped units.
_mauled       = [];
_healthyCount = 0;

{
    _u = _x;
    if (alive _u) then {
        if ((getDammage _u) >= _threshold) then {
            //--- Only retreat if no other SML feature already owns this unit.
            _i = _u getVariable "wfbe_sml_detach_at";
            if (isNil "_i") then {
                _mauled = _mauled + [_u];
            };
        } else {
            _healthyCount = _healthyCount + 1;
        };
    };
} forEach _footInf;

//--- If fewer than _healthyMin healthy units remain, the whole team is mauled.
//--- Do not retreat individuals; disband/refit systems handle total attrition.
if (_healthyCount < _healthyMin) exitWith {};

//--- No mauled units to retreat.
if (count _mauled < 1) exitWith {};

//--- Stamp and issue retreat orders.
_stamp = time;
{
    _u = _x;
    _u setVariable ["wfbe_sml_detach_at", _stamp];
    //--- Bearing AWAY from town center (reverse of unit->townCenter vector).
    _posU   = getPos _u;
    _bearing = ((_posU select 0) - (_townCenter select 0)) atan2 ((_posU select 1) - (_townCenter select 1));
    _retreatPos = [(_posU select 0) + 80 * (sin _bearing), (_posU select 1) + 80 * (cos _bearing), 0];
    doStop _u;
    _u doMove _retreatPos;
} forEach _mauled;

diag_log Format ["SML|v1|RETREAT|side=%1 team=%2 mauled=%3 healthy=%4 ttl=%5",
    _side, _team, count _mauled, _healthyCount, _ttl];

//--- ===== WATCHDOG LOOP =====
_retreatDone = false;
_exitReason  = "ttl";

while {!_retreatDone} do {

    //--- (a) TTL expiry
    if (time > _stamp + _ttl) exitWith {_exitReason = "ttl"};

    //--- (b) leader death
    _aliveCheck = !isNull leader _team;
    if (_aliveCheck) then {_aliveCheck = alive (leader _team)};
    if (!_aliveCheck) exitWith {_exitReason = "leader_dead"};

    //--- (c) team disband
    _disbandFlag = _team getVariable "wfbe_aicom_disband";
    if (!(isNil "_disbandFlag") && {_disbandFlag}) exitWith {_exitReason = "disband"};

    //--- (d) retask: seq changed
    _ordN = _team getVariable "wfbe_aicom_order";
    if (isNil "_ordN") then {_ordN = []};
    if (count _ordN >= 1 && {(_ordN select 0) != _capSeq}) exitWith {_exitReason = "retasked"};

    //--- (e) all mauled units dead or healed
    _allGone = true;
    {
        if (alive _x && {(getDammage _x) >= _threshold}) then {_allGone = false};
    } forEach _mauled;
    if (_allGone) exitWith {_exitReason = "all_dead_or_healed"};

    //--- (f) group change
    _grpChg = false;
    {
        if (alive _x && {!(group _x == _team)}) then {_grpChg = true};
    } forEach _mauled;
    if (_grpChg) exitWith {_exitReason = "group_change"};

    sleep 3;
};

//--- ===== REJOIN: clear stamps + doFollow for all mauled units =====
{
    _x setVariable ["wfbe_sml_detach_at", nil];
    if (alive _x) then {_x setUnitPos "AUTO"; _x doFollow (leader _team)};
} forEach _mauled;

diag_log Format ["SML|v1|RETREAT_REJOIN|side=%1 team=%2 reason=%3 elapsed=%4",
    _side, _team, _exitReason, round (time - _stamp)];
