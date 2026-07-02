Private ["_amount","_vehicle"];
_vehicle = objNull;
if (typeName _this == "ARRAY") then {
	if (count _this > 0) then {_vehicle = _this select 0};
} else {
	if (typeName _this == "OBJECT") then {_vehicle = _this};
};

if (isNull _vehicle) exitWith {};
waitUntil {commonInitComplete};
sleep 2;
_amount = if (_vehicle isKindOf "Plane") then {missionNamespace getVariable 'WFBE_C_UNITS_COUNTERMEASURE_PLANES'} else {missionNamespace getVariable 'WFBE_C_UNITS_COUNTERMEASURE_CHOPPERS'};
_vehicle setVariable ["FlareCount", _amount];
_vehicle setVariable ["FlareActive", false];
