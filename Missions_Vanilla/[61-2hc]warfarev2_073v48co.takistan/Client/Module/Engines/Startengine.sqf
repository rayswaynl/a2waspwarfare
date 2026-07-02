private ["_fuel","_vehicle","_ID"];
_vehicle = vehicle (_this select 0);
_ID = _this select 2;
_fuel = _vehicle getVariable 'Fuel';
_vehicle setFuel _fuel;
_vehicle removeAction _ID;
if ((missionNamespace getVariable ["WFBE_C_FIX_ENGINE_STEALTH_STATE_PUBLIC", 0]) > 0) then {
	_vehicle setVariable ["stopped",false,true];
} else {
	_vehicle setVariable ["stopped",false];
};
