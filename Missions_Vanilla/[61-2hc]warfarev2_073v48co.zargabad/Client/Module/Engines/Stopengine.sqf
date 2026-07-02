private ["_fuel","_vehicle","_ID"];
_vehicle = vehicle (_this select 0);

_ID = _this select 2;
_vehicle setVariable ["ID",_ID];
_vehicle EngineOn false;
if ((missionNamespace getVariable ["WFBE_C_FIX_ENGINE_STEALTH_STATE_PUBLIC", 0]) > 0) then {
	_vehicle setVariable ["stopped",true,true];
} else {
	_vehicle setVariable ["stopped",true];
};
