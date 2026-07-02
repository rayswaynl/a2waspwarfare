//--- WASP OA Auto-Countermeasures (opt-in feature, default OFF via WFBE_C_MODULE_AUTO_CM_OA).
//--- Operation Arrowhead aircraft already have native MANUAL flares; this adds AUTOMATIC flare
//--- deployment when an IR-locking missile is incoming, mainly to help AI aircraft survive.
//--- Adapted from Maddmatt's vanilla-A2 CM but model-agnostic: spawns engine FlareCountermeasure
//--- decoys from the vehicle position instead of "flare_launcher" memory points (which OA stock
//--- models lack). No pilot chat spam. Uses the existing FlareCount budget (CM_Set / rearm).
//---
//--- _this = [_vehicle, _ammo, _firer] from the "incomingMissile" event handler.

private ["_vehicle","_ammo","_type","_burst","_i","_pos","_flare","_vvel"];
_vehicle = _this select 0;
_ammo    = _this select 1;

if (!alive _vehicle) exitWith {};
if (((getPos _vehicle) select 2) < 5) exitWith {};                 //--- skip parked / on-ground

//--- Only react to air-locking (IR / radar) ordnance.
_type = getNumber (configFile >> "CfgAmmo" >> _ammo >> "AirLock");
if (_type != 1) exitWith {};

//--- One flare burst at a time per vehicle, and only if we still have a budget.
if (_vehicle getVariable ["FlareActive", false]) exitWith {};
if ((_vehicle getVariable ["FlareCount", 0]) <= 0) exitWith {};

_vehicle setVariable ["FlareActive", true];

_burst = 8;
for "_i" from 1 to _burst do {
	if ((_vehicle getVariable ["FlareCount", 0]) > 0) then {
		_vehicle setVariable ["FlareCount", (_vehicle getVariable ["FlareCount", 0]) - 1];
		_pos   = _vehicle modelToWorld [0, -2, -1.5];             //--- behind & below the aircraft
		_flare = "FlareCountermeasure" createVehicleLocal _pos;
		_vvel  = velocity _vehicle;
		_flare setVelocity [(_vvel select 0) * 0.5, (_vvel select 1) * 0.5, ((_vvel select 2) * 0.5) - 4];
		_flare spawn { sleep (4.5 + random 1); deleteVehicle _this };
	};
	sleep 0.3;
};

_vehicle setVariable ["FlareActive", false];
