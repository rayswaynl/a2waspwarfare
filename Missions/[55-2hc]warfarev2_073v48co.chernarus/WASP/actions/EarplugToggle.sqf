/*
	Author: Marty
	Description:
		Toggles earplugs (reduced sound volume) for the local player.
		fadeSound persists for the session; on respawn AddActions.sqf
		re-registers the action and the title reflects current state via
		the missionNamespace flag WFBE_WASP_EarplugActive.
*/

private ["_active","_newTitle","_footID","_vehRef","_vehID"];

_active = missionNamespace getVariable ["WFBE_WASP_EarplugActive", false];

if (!_active) then {
	//--- Put earplugs IN: lower volume.
	0.25 fadeSound 0.3;
	playSound "autoViewDistanceToggledOn";
	missionNamespace setVariable ["WFBE_WASP_EarplugActive", true];
} else {
	//--- Take earplugs OUT: restore volume.
	1 fadeSound 0.3;
	playSound "autoViewDistanceToggledOff";
	missionNamespace setVariable ["WFBE_WASP_EarplugActive", false];
};

_newTitle = if (missionNamespace getVariable ["WFBE_WASP_EarplugActive", false]) then {"Earplugs OUT"} else {"Earplugs IN"};

//--- Refresh BOTH mirrors via their remembered ids. Never use (_this select 1/2)
//--- for removal here: when fired from the VEHICLE mirror, "caller removeAction id"
//--- would remove an unrelated action from the player object (action ids are
//--- per-object counters), and the on-foot action would then double-add.
_footID = player getVariable ["WFBE_WASP_EarplugFootID", -1];
if (_footID != -1) then {player removeAction _footID};
_footID = player addAction [_newTitle, "WASP\actions\EarplugToggle.sqf", [], 1, false, false, "", ""];
player setVariable ["WFBE_WASP_EarplugFootID", _footID];

//--- Vehicle mirror: flip its title too (lifecycle is owned by the AddActions loop).
if (vehicle player != player) then {
	_vehRef = player getVariable ["WFBE_WASP_EarplugVehRef", objNull];
	_vehID  = player getVariable ["WFBE_WASP_EarplugVehID",  -1];
	if (!isNull _vehRef && _vehID != -1) then {
		_vehRef removeAction _vehID;
		_vehID = _vehRef addAction [_newTitle, "WASP\actions\EarplugToggle.sqf", [], 1, false, false, "", ""];
		player setVariable ["WFBE_WASP_EarplugVehID", _vehID];
	};
};
