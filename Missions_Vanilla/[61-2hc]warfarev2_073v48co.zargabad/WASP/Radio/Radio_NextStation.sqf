/*
	WASP Vehicle Radio - skip to the next station on this vehicle.
	NOT wired to any UI action (kept for internal/future use, see #929's PR body).

	No-op under streaming playback: each station is a single continuous internet stream, not a
	track list (see Radio_Config.sqf), so there is nothing to "advance" to within a station.
	Station-to-station switching already exists via Radio_SetStation.sqf / the Radio menu.

	Gate: requires >=1 alive Radio Tower on the caller's side (WFBE_C_STRUCTURES_RADIOTOWER),
	kept for parity with the other Radio scripts even though this one currently does nothing.
*/

private ["_veh","_caller"];
_veh = _this select 0;
_caller = _this select 1;
if (isNull _veh) exitWith {};

if !((side _caller) call WFBE_CO_FNC_HasSideRadioTower) exitWith {};
