private ["_caller","_vehicle","_ID"];

//--- The scroll condition is cosmetic; re-check the live driver at activation so a passenger
//--- cannot stop a moving vehicle and a seat swap between menu paint and click fails cleanly.
if (isNil "_this" || {typeName _this != "ARRAY"} || {count _this < 3}) exitWith {};
_vehicle = _this select 0;
_caller = _this select 1;
if (typeName _vehicle != "OBJECT" || {typeName _caller != "OBJECT"}) exitWith {};
if (isNull _vehicle || {isNull _caller} || {driver _vehicle != _caller}) exitWith {};

_ID = _this select 2;
_vehicle setVariable ["ID",_ID];
_vehicle EngineOn false;
if ((missionNamespace getVariable ["WFBE_C_FIX_ENGINE_STEALTH_STATE_PUBLIC", 0]) > 0) then {
	_vehicle setVariable ["stopped",true,true];
} else {
	_vehicle setVariable ["stopped",true];
};
