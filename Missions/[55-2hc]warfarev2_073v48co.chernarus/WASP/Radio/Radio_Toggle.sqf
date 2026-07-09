/*
	WASP Vehicle Radio - toggle this vehicle's radio on/off.
	Run as an addAction script (local) from Init_Unit.sqf.
	_this = [target (vehicle), caller, actionId, arguments].

	State is stored PUBLIC on the vehicle so a future 3D mode (others hear it) needs no change:
	  WASP_Radio_On    : bool  - is this vehicle's radio playing
	  WASP_Radio_Index : int   - current station index into WASP_RADIO_PLAYLIST

	Gate: requires >=1 alive Radio Tower on the caller's side (WFBE_C_STRUCTURES_RADIOTOWER).
	See Common_HasSideRadioTower.sqf.
*/

private ["_veh","_caller","_on"];
_veh = _this select 0;
_caller = _this select 1;
if (isNull _veh) exitWith {};

if !((side _caller) call WFBE_CO_FNC_HasSideRadioTower) exitWith {};

_on = _veh getVariable ["WASP_Radio_On", false];
_veh setVariable ["WASP_Radio_On", !_on, true];

if (!_on) then {
	// Turning ON: make sure the single client-side manager loop is running.
	if (isNil "WASP_Radio_ManagerRunning" || {!WASP_Radio_ManagerRunning}) then {
		[] execVM "WASP\Radio\Radio_Manager.sqf";
	};
};
// Turning OFF: the manager stops playback on its next tick (sees WASP_Radio_On == false).
