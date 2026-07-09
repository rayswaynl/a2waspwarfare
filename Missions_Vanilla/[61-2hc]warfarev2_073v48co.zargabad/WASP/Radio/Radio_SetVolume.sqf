/*
	WASP Vehicle Radio - set client-side playback volume.
	Run as an addAction script (local) from Radio_Menu.sqf.
	_this = [target (vehicle), caller, actionId, arguments]; arguments = volume (number 0..1).

	Persists in a client-side variable (WASP_Radio_Volume) so the choice survives track
	changes and vehicle switches; the manager loop re-applies it via fadeMusic on every
	track start (see Radio_Manager.sqf).
*/

private ["_vol"];
_vol = _this select 3;
if (isNil "_vol") exitWith {};

WASP_Radio_Volume = _vol;
fadeMusic _vol;
