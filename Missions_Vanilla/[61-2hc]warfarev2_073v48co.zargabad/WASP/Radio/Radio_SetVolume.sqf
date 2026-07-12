/*
	WASP Vehicle Radio - set client-side playback volume.
	Run as an addAction script (local) from Radio_Menu.sqf.
	_this = [target (vehicle), caller, actionId, arguments]; arguments = volume (number 0..1).

	Persists in a client-side variable (WASP_Radio_Volume) so the choice survives station
	changes and vehicle switches; the manager loop re-applies it via RADIO,VOLUME on every
	stream (re)start (see Radio_Manager.sqf). Applied immediately here too, via the same
	"a2waspwarfare_Extension" callExtension command, so the change is audible without waiting
	for the manager's next tick.
*/

private ["_vol"];
_vol = _this select 3;
if (isNil "_vol") exitWith {};

WASP_Radio_Volume = _vol;
"a2waspwarfare_Extension" callExtension format ["RADIO,VOLUME,%1", round(_vol * 100)];
