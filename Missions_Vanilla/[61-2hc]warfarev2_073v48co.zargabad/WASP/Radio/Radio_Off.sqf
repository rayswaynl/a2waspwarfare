/*
	WASP Vehicle Radio - turn this vehicle's radio off (from the Radio menu).
	Run as an addAction script (local) from Radio_Menu.sqf.
	_this = [target (vehicle), caller, actionId, arguments].

	No tower gate on purpose: turning the radio OFF must always be possible, even if the
	side Radio Tower was destroyed/sold after the menu was opened.
*/

private ["_veh"];
_veh = _this select 0;
if (isNull _veh) exitWith {};

_veh setVariable ["WASP_Radio_On", false, true];
