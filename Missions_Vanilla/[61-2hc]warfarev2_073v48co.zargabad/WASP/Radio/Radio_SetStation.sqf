/*
	WASP Vehicle Radio - select a station on this vehicle.
	Run as an addAction script (local) from Radio_Menu.sqf.
	_this = [target (vehicle), caller, actionId, arguments]; arguments = station index (number).

	Gate: requires >=1 alive Radio Tower on the caller's side (WFBE_C_STRUCTURES_RADIOTOWER).
*/

private ["_veh","_caller","_stIdx"];
_veh = _this select 0;
_caller = _this select 1;
_stIdx = _this select 3;
if (isNull _veh) exitWith {};

if !((side _caller) call WFBE_CO_FNC_HasSideRadioTower) exitWith {};

if (isNil "WASP_RADIO_STATIONS") then {
	call compile preprocessFileLineNumbers "WASP\Radio\Radio_Config.sqf";
};

if (isNil "_stIdx") exitWith {};
if (_stIdx < 0 || {_stIdx >= (count WASP_RADIO_STATIONS)}) exitWith {};

_veh setVariable ["WASP_Radio_Station", _stIdx, true];
_veh setVariable ["WASP_Radio_Index", 0, true];
_veh setVariable ["WASP_Radio_On", true, true];

// Make sure the single client-side manager loop is running.
if (isNil "WASP_Radio_ManagerRunning" || {!WASP_Radio_ManagerRunning}) then {
	[] execVM "WASP\Radio\Radio_Manager.sqf";
};
