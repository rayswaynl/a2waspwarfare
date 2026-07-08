/*
	WASP Vehicle Radio - skip to the next station on this vehicle.
	Run as an addAction script (local) from Init_Unit.sqf.
	The manager loop picks up the new index on its next tick and switches track.

	Gate: requires >=1 alive Radio Tower on the caller's side (WFBE_C_STRUCTURES_RADIOTOWER).
*/

private ["_veh","_caller","_n","_idx"];
_veh = _this select 0;
_caller = _this select 1;
if (isNull _veh) exitWith {};

if !((side _caller) call WFBE_CO_FNC_HasSideRadioTower) exitWith {};

if (isNil "WASP_RADIO_PLAYLIST") then {
	call compile preprocessFileLineNumbers "WASP\Radio\Radio_Config.sqf";
};

_n = count WASP_RADIO_PLAYLIST;
if (_n == 0) exitWith {};

_idx = ((_veh getVariable ["WASP_Radio_Index", 0]) + 1) % _n;
_veh setVariable ["WASP_Radio_Index", _idx, true];
