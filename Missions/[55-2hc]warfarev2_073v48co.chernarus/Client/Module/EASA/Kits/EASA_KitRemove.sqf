/*
	EASA_KitRemove.sqf  (EASA_KitRemove)
	Tear down the LOCAL realisation of a vehicle's kit: attached objects, HandleDamage, fire action.
	Input : [_vehicle]. Safe to call when no kit is present (used to make EASA_KitBuild idempotent).
	Arma 2 OA only.
*/
private ["_vehicle","_objs","_eh","_act"];
_vehicle = _this select 0;
if (isNull _vehicle) exitWith {};

_objs = _vehicle getVariable ["WFBE_KIT_LocalObjs", []];
{
	if (!isNull _x) then { detach _x; deleteVehicle _x };
} forEach _objs;
_vehicle setVariable ["WFBE_KIT_LocalObjs", []];

_eh = _vehicle getVariable ["WFBE_KIT_DmgEH", -1];
if (_eh >= 0) then {
	_vehicle removeEventHandler ["HandleDamage", _eh];
	_vehicle setVariable ["WFBE_KIT_DmgEH", -1];
};

_act = _vehicle getVariable ["WFBE_KIT_FireAction", -1];
if (_act >= 0) then {
	_vehicle removeAction _act;
	_vehicle setVariable ["WFBE_KIT_FireAction", -1];
};
