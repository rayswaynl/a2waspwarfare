//--- SML-4: AT Overwatch (GR-2026-07-03a)
//--- Pre-positions the team's launcher soldier on the armor approach vector before the depot assault.
//--- Args: [_team, _footInf, _sideID, _side, _townCenter, _dest, _capSeq]
//--- Stamp discipline: wfbe_sml_detach_at set on detach, cleared to nil on rejoin.
//--- Flag-gated: WFBE_C_SML_AT_OVERWATCH default 1 (ON) - see Init_CommonConstants.sqf.
//--- fix(docs): this header previously claimed "default 0", which never matched the shipped
//--- default (1, live) in Init_CommonConstants.sqf. Comment-only correction; no behaviour change.
private ["_team","_footInf","_sideID","_side","_townCenter","_dest","_capSeq",
         "_ttl","_armorR","_offset","_startTime","_launcher","_found",
         "_nearEntities","_hostile","_hostileArmor","_armorTank",
         "_armorPos","_dx","_dy","_bearing","_overwatchPos","_elapsed","_reason",
         "_disbanded","_disbandFlag","_retasked","_ordN",
         "_leaderDead","_launcherDead","_groupChanged","_noArmor",
         "_scanResult","_hostileCount","_uX"];
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
_startTime = time;

//--- Step 1: Find a launcher soldier (secondaryWeapon != "") not already stamped.
_launcher = objNull;
_found = false;
{
    _uX = _x;
    if (!_found && {alive _uX} && {secondaryWeapon _uX != ""} && {isNil {_uX getVariable "wfbe_sml_detach_at"}}) then {
        _launcher = _uX;
        _found = true;
    };
} forEach _footInf;

if (isNull _launcher || {!_found}) exitWith {
    diag_log Format ["SML|v1|OVERWATCH_SKIP|side=%1 team=%2 reason=no_unstamped_launcher", _side, _team];
};

//--- Step 2: Scan for hostile armor near _townCenter.
_scanResult  = _townCenter nearEntities [["Tank"], _armorR];
_hostileArmor = [];
{
    _uX = _x;
    if (alive _uX && {(_side getFriend (side _uX)) < 0.6}) then {
        _hostileArmor = _hostileArmor + [_uX];
    };
} forEach _scanResult;

if (count _hostileArmor == 0) exitWith {
    diag_log Format ["SML|v1|OVERWATCH_SKIP|side=%1 team=%2 reason=no_hostile_armor", _side, _team];
};

_armorTank = _hostileArmor select 0;

//--- Step 3: Validate the armor/destination geometry before calculating the bearing.
//--- A dying/deleted armor target can return scalar NaN from getPos; A2's atan2 also errors for [0,0].
_armorPos = getPos _armorTank;
if (!((_armorPos select 0) == (_armorPos select 0)) || {!((_armorPos select 1) == (_armorPos select 1))} || {!((_dest select 0) == (_dest select 0))} || {!((_dest select 1) == (_dest select 1))}) exitWith {
	diag_log Format ["SML|v1|OVERWATCH_SKIP|side=%1 team=%2 reason=nan_pos dest=%3 armor=%4", _side, _team, _dest, _armorPos];
};

_dx = (_armorPos select 0) - (_dest select 0);
_dy = (_armorPos select 1) - (_dest select 1);
if (_dx == 0 && {_dy == 0}) exitWith {
	diag_log Format ["SML|v1|OVERWATCH_SKIP|side=%1 team=%2 reason=zero_delta dest=%3 armor=%4", _side, _team, _dest, _armorPos];
};

_bearing = _dx atan2 _dy;
_overwatchPos = [(_dest select 0) + _offset * (sin _bearing), (_dest select 1) + _offset * (cos _bearing), 0];

//--- Step 4: Stamp and detach the launcher.
_launcher setVariable ["wfbe_sml_detach_at", time];
doStop _launcher;
_launcher doMove _overwatchPos;

diag_log Format ["SML|v1|OVERWATCH|side=%1 team=%2 launcher=%3 armorNear=%4 overwatchPos=%5 ttl=%6", _side, _team, _launcher, count _hostileArmor, _overwatchPos, _ttl];

//--- WATCHDOG: poll every 3s until TTL or exit condition.
_reason = "ttl";
_disbandFlag = "wfbe_aicom_disband";
waitUntil {
    sleep 3;
    _elapsed = time - _startTime;

    //--- (a) TTL expiry.
    if (_elapsed >= _ttl) then {_reason = "ttl"; true} else {

    //--- (b) Launcher dead.
    _launcherDead = !alive _launcher;
    if (_launcherDead) then {_reason = "launcher_dead"; true} else {

    //--- (c) Leader dead.
    _leaderDead = (!alive (leader _team)) || {isNull (leader _team)};
    if (_leaderDead) then {_reason = "leader_dead"; true} else {

    //--- (d) Team disband flag.
    _disbanded = _team getVariable _disbandFlag;
    if (isNil "_disbanded") then {_disbanded = false};
    if (_disbanded) then {_reason = "disband"; true} else {

    //--- (e) Retask: order seq changed.
    _ordN = _team getVariable "wfbe_aicom_order";
    if (isNil "_ordN") then {_ordN = []};
    _retasked = (count _ordN >= 1) && {(_ordN select 0) != _capSeq};
    if (_retasked) then {_reason = "retasked"; true} else {

    //--- (f) No more hostile armor in range.
    _scanResult = _townCenter nearEntities [["Tank"], _armorR];
    _hostileCount = 0;
    {
        _uX = _x;
        if (alive _uX && {(_side getFriend (side _uX)) < 0.6}) then {_hostileCount = _hostileCount + 1};
    } forEach _scanResult;
    _noArmor = (_hostileCount == 0);
    if (_noArmor) then {_reason = "no_armor"; true} else {

    //--- (g) Group change: launcher no longer in _team.
    _groupChanged = alive _launcher && {!(_launcher in (units _team))};
    if (_groupChanged) then {_reason = "group_change"; true} else {false}
    }}}}}}
};

//--- REJOIN.
_launcher setVariable ["wfbe_sml_detach_at", nil];
if (alive _launcher) then {
    _launcher setUnitPos "AUTO";
    _launcher doFollow (leader _team);
};

diag_log Format ["SML|v1|OVERWATCH_REJOIN|side=%1 team=%2 reason=%3 elapsed=%4", _side, _team, _reason, (time - _startTime)];
