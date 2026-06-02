/*
	Script from Valhalla.
*/

VALHALLA_FNC_LowGear = compile preprocessFileLineNumbers "Client\Module\Valhalla\Func_Client_LowGear.sqf";

if (isNil "WFBE_HighClimbingDefaultEnabled") then {
	WFBE_HighClimbingDefaultEnabled = profileNamespace getVariable ["WFBE_HIGH_CLIMBING_DEFAULT_ENABLED", false];
	missionNamespace setVariable ["WFBE_HighClimbingDefaultEnabled", WFBE_HighClimbingDefaultEnabled];
};

Local_HighClimbingModeOn = false;
Local_HighClimbingRunning = false;
Local_KeyPressedForward = false;
Local_HighClimbingForwardActionKeys =
	(actionKeys "carForward") +
	(actionKeys "carFastForward") +
	(actionKeys "carSlowForward");
Local_HighClimbingForwardKeys = [];

VALHALLA_FNC_IsLowGearForwardKey = {
	Private ["_key"];

	_key = _this;

	_key in Local_HighClimbingForwardActionKeys
};

VALHALLA_FNC_HandleLowGearKeyDown = {
	Private ["_key"];

	_key = _this select 1;

	if (_key call VALHALLA_FNC_IsLowGearForwardKey) then {
		if (!(_key in Local_HighClimbingForwardKeys)) then {
			Local_HighClimbingForwardKeys set [count Local_HighClimbingForwardKeys, _key];
		};
		Local_KeyPressedForward = true;
	};

	false
};

VALHALLA_FNC_HandleLowGearKeyUp = {
	Private ["_key"];

	_key = _this select 1;

	if (_key call VALHALLA_FNC_IsLowGearForwardKey) then {
		Local_HighClimbingForwardKeys = Local_HighClimbingForwardKeys - [_key];
		Local_KeyPressedForward = count Local_HighClimbingForwardKeys > 0;
	};

	false
};

(findDisplay 46) displayAddEventHandler ["KeyDown", "_this call VALHALLA_FNC_HandleLowGearKeyDown"];
(findDisplay 46) displayAddEventHandler ["KeyUp", "_this call VALHALLA_FNC_HandleLowGearKeyUp"];
