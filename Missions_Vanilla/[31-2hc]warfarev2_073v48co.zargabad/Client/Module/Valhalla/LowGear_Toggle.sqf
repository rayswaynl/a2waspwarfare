Private ["_vehicle", "_defaultEnabled", "_enabled"];

_vehicle = _this select 0;

if (isNull _vehicle) exitWith {};

_defaultEnabled = false;
if (_vehicle isKindOf "Tank" || {_vehicle isKindOf "Car"}) then {
	_defaultEnabled = missionNamespace getVariable ["WFBE_HighClimbingDefaultEnabled", false];
};
_enabled = !(_vehicle getVariable ["WFBE_HighClimbingEnabled", _defaultEnabled]);

_vehicle setVariable ["WFBE_HighClimbingEnabled", _enabled, true];

if (player == driver _vehicle) then {
	Local_HighClimbingModeOn = _enabled;

	if (_enabled && {!Local_HighClimbingRunning}) then {
		_vehicle spawn VALHALLA_FNC_LowGear;
	};
};
