Private ["_amount","_vehicle"];

//--- VOID-ARG GUARD (Fable 2026-07-03): live client RPT (Zwanon skin swap) caught this file firing with
//--- Void _this right after a body/vehicle change - 'Error in expression <..._vehicle = _this select 0;'
//--- - because a vehicle-change/swap event re-ran CM_Set with no argument. `_this select 0` on a nil/empty
//--- _this throws. The four legitimate callers (Common\Init\Init_Unit.sqf) pass `(_unit) ExecVM` = a bare
//--- OBJECT as _this, so accept BOTH shapes: a bare object (use it directly) or an array (take select 0).
//--- Anything else (nil, empty array, non-object) exits with NO side effects - matches the file's existing
//--- `if (isNull _vehicle) exitWith {}` style. A2-OA-1.64 safe: isNil / typeName / count / select / isNull.
if (isNil "_this") exitWith {};
if (typeName _this == "OBJECT") then {
	_vehicle = _this;
} else {
	if (typeName _this == "ARRAY" && {count _this > 0}) then {
		_vehicle = _this select 0;
	} else {
		_vehicle = objNull;
	};
};

if (isNull _vehicle) exitWith {};
waitUntil {commonInitComplete};
sleep 2;
_amount = if (_vehicle isKindOf "Plane") then {missionNamespace getVariable 'WFBE_C_UNITS_COUNTERMEASURE_PLANES'} else {missionNamespace getVariable 'WFBE_C_UNITS_COUNTERMEASURE_CHOPPERS'};
_vehicle setVariable ["FlareCount", _amount];
_vehicle setVariable ["FlareActive", false];
