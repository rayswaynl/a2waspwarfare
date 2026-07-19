//--- SML-3: Graceful Retreat (GR-2026-07-03a)
//--- Mauled individual soldiers pull back ~80m from _townCenter while healthy units keep fighting.
//--- Args: [_team, _footInf, _sideID, _side, _townCenter, _capSeq]
//--- Stamp discipline: wfbe_sml_detach_at set on detach, cleared to nil on rejoin.
//--- Flag-gated: WFBE_C_SML_RETREAT default 1 (ON) - see Init_CommonConstants.sqf.
//--- fix(docs): this header previously claimed "default 0", which never matched the shipped
//--- default (1, live) in Init_CommonConstants.sqf. Comment-only correction; no behaviour change.
private ["_team","_footInf","_sideID","_side","_townCenter","_capSeq",
         "_ttl","_thresh","_healthyMin","_stamp","_startTime",
         "_healthyCount","_mauledCount","_mauled","_u","_order","_ordN",
         "_bearing","_retreatPos","_posX","_posY","_elapsed","_reason",
         "_disbandFlag","_disbanded","_allDone","_allHealed","_allDead","_groupChanged",
         "_retasked","_leaderDead","_mX","_detachedBySML3"];
_team       = _this select 0;
_footInf    = _this select 1;
_sideID     = _this select 2;
_side       = _this select 3;
_townCenter = _this select 4;
_capSeq     = _this select 5;

_ttl        = missionNamespace getVariable ["WFBE_C_SML_WATCHDOG_TTL", 240];
_thresh     = missionNamespace getVariable ["WFBE_C_SML_RETREAT_DAMAGE_THRESHOLD", 0.5];
_healthyMin = missionNamespace getVariable ["WFBE_C_SML_RETREAT_HEALTHY_MIN", 4];
_stamp      = time;
_startTime  = time;

//--- Count healthy vs mauled units.
_healthyCount = 0;
_mauledCount  = 0;
_mauled       = [];
{
    if (alive _x) then {
        if ((getDammage _x) >= _thresh) then {
            _mauledCount = _mauledCount + 1;
            _mauled = _mauled + [_x];
        } else {
            _healthyCount = _healthyCount + 1;
        };
    };
} forEach _footInf;

//--- Guard: if whole team is mauled or not enough healthy, do nothing (disband/refit handles it).
if (_healthyCount < _healthyMin) exitWith {
    diag_log Format ["SML|v1|RETREAT_SKIP|side=%1 team=%2 healthy=%3 mauled=%4 (below_healthy_min=%5)", _side, _team, _healthyCount, _mauledCount, _healthyMin];
};

if (count _mauled == 0) exitWith {};

//--- Detach each mauled unit: stamp + pull back 80m away from _townCenter.
//--- Only units SML-3 actually stamps are tracked in _detachedBySML3 for rejoin.
_detachedBySML3 = [];
{
    _mX = _x;
    if (!(isNil {_mX getVariable "wfbe_sml_detach_at"})) then {
        //--- Already choreographed by another SML feature; skip to avoid double-detach.
    } else {
        _mX setVariable ["wfbe_sml_detach_at", time];
        _posX   = (getPos _mX) select 0;
        _posY   = (getPos _mX) select 1;
        _bearing = (_posX - ((_townCenter) select 0)) atan2 (_posY - ((_townCenter) select 1));
        _retreatPos = [_posX + 80 * (sin _bearing), _posY + 80 * (cos _bearing), 0];
        doStop _mX;
        _mX doMove _retreatPos;
        _detachedBySML3 set [count _detachedBySML3, _mX];
    };
} forEach _mauled;

diag_log Format ["SML|v1|RETREAT|side=%1 team=%2 mauled=%3 healthy=%4 ttl=%5", _side, _team, _mauledCount, _healthyCount, _ttl];

//--- WATCHDOG: poll every 3s until TTL or exit condition.
_reason = "ttl";
_disbandFlag = "wfbe_aicom_disband";
waitUntil {
    sleep 3;
    _elapsed = time - _startTime;

    //--- (a) TTL expiry.
    if (_elapsed >= _ttl) then {_reason = "ttl"; true} else {

    //--- (b) Leader death.
    _leaderDead = (!alive (leader _team)) || {isNull (leader _team)};
    if (_leaderDead) then {_reason = "leader_dead"; true} else {

    //--- (c) Team disband flag.
    _disbanded = _team getVariable _disbandFlag;
    if (isNil "_disbanded") then {_disbanded = false};
    if (_disbanded) then {_reason = "disband"; true} else {

    //--- (d) Retask: order seq changed.
    _ordN = _team getVariable "wfbe_aicom_order";
    if (isNil "_ordN") then {_ordN = []};
    _retasked = (count _ordN >= 1) && {(_ordN select 0) != _capSeq};
    if (_retasked) then {_reason = "retasked"; true} else {

    //--- (e) All mauled units dead or healed.
    _allDone = true;
    {
        _mX = _x;
        if (alive _mX && {_mX in (units _team)} && {(getDammage _mX) >= _thresh}) then {
            _allDone = false;
        };
    } forEach _mauled;
    if (_allDone) then {_reason = "all_dead_or_healed"; true} else {

    //--- (f) Group change: any mauled unit no longer in _team.
    _groupChanged = false;
    {
        _mX = _x;
        if (alive _mX && {!(_mX in (units _team))}) then {_groupChanged = true};
    } forEach _mauled;
    if (_groupChanged) then {_reason = "group_change"; true} else {false}
    }}}}}
};

//--- REJOIN: restore only units SML-3 actually detached (not units skipped due to another SML stamp).
{
    _mX = _x;
    _mX setVariable ["wfbe_sml_detach_at", nil];
    if (alive _mX && {_mX in (units _team)}) then {
        _mX setUnitPos "AUTO";
        _mX doFollow (leader _team);
    };
} forEach _detachedBySML3;

diag_log Format ["SML|v1|RETREAT_REJOIN|side=%1 team=%2 reason=%3 elapsed=%4", _side, _team, _reason, (time - _startTime)];
