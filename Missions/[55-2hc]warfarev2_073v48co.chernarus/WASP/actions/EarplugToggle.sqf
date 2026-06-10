/*
	Author: Marty
	Description:
		Toggles earplugs (reduced sound volume) for the local player.
		fadeSound persists for the session; on respawn AddActions.sqf
		re-registers the action and the title reflects current state via
		the missionNamespace flag WFBE_WASP_EarplugActive.
*/

private ["_active"];

_active = missionNamespace getVariable ["WFBE_WASP_EarplugActive", false];

if (!_active) then {
	//--- Put earplugs IN: lower volume.
	0.25 fadeSound 0.3;
	playSound "autoViewDistanceToggledOn";
	missionNamespace setVariable ["WFBE_WASP_EarplugActive", true];
	(_this select 1) removeAction (_this select 2);
	player addAction ["Earplugs OUT", "WASP\actions\EarplugToggle.sqf", [], 1, false, false, "", ""];
} else {
	//--- Take earplugs OUT: restore volume.
	1 fadeSound 0.3;
	playSound "autoViewDistanceToggledOff";
	missionNamespace setVariable ["WFBE_WASP_EarplugActive", false];
	(_this select 1) removeAction (_this select 2);
	player addAction ["Earplugs IN", "WASP\actions\EarplugToggle.sqf", [], 1, false, false, "", ""];
};
