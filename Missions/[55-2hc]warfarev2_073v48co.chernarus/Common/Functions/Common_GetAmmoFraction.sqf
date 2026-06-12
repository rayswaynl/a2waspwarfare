/*
	Common_GetAmmoFraction.sqf
	Author: Marty (experital task 3)

	Return the current ammo load of a vehicle as a 0..1 fraction of its full complement.

	Parameter:
		_this  - vehicle object

	Returns: SCALAR  0..1  (0 = empty, 1 = full; 0 on degenerate input)

	---
	AMMO-COUNTING APPROACH
	-----------------------
	In A2 OA 1.6x:
	  - `magazines _veh`      returns the hull magazine list (driver / co-axial / [-1] turret path).
	  - `magazinesTurret` IS available and is already used by this codebase
	    (see Common_LoadArtilleryAmmo.sqf line 47).
	  - We therefore count BOTH hull and per-turret magazines for full accuracy.

	Full complement (config):
	  - Hull: getArray(configFile >> "CfgVehicles" >> class >> "magazines")
	  - Each turret: the "magazines" array returned by WFBE_CO_FNC_GetVehicleTurretsGear
	    (which walks Turrets recursively via WFBE_CO_FNC_FindTurretsRecursive).

	Current count:
	  - Hull: count (magazines _veh)
	  - Each turret path: count (_veh magazinesTurret <path>)

	Result: (currentTotal / fullTotal) clamped 0..1.

	Per-class full complements are cached in missionNamespace under the key
	  Format["WFBE_AMMOFULL_%1", typeOf _veh]
	as a single INTEGER so configFile is only walked once per vehicle class per session.

	UNCERTAINTY NOTE: The A2 BIKI states `magazines unitName` returns the list of
	magazines in the unit's inventory.  For vehicles this covers the hull/[-1] path.
	Turret magazines require `vehicleObj magazinesTurret turretPath`.
	This implementation mirrors what WFBE_CO_FNC_LoadArtilleryAmmo already does, so it
	is consistent with codebase precedent.
*/

private ["_cacheKey","_class","_currentHull","_currentTotal","_fullTotal","_turrets","_veh"];

_veh = _this;

if (isNull _veh || !(alive _veh)) exitWith {0};

_class = typeOf _veh;
_cacheKey = Format ["WFBE_AMMOFULL_%1", _class];

//--- Full complement: read from cache or compute once.
_fullTotal = missionNamespace getVariable _cacheKey;

if (isNil "_fullTotal") then {
	private ["_hullMags","_total"];
	_hullMags  = getArray (configFile >> "CfgVehicles" >> _class >> "magazines");
	_total     = count _hullMags;

	_turrets = _veh Call WFBE_CO_FNC_GetVehicleTurretsGear;
	{
		_total = _total + count (_x select 1);
	} forEach _turrets;

	_fullTotal = _total;
	missionNamespace setVariable [_cacheKey, _fullTotal];
};

//--- Degenerate: config unreadable or vehicle has no ammo entries -> return 0 (full price, safe).
if (_fullTotal <= 0) exitWith {0};

//--- Current ammo count (hull + all turret paths).
_currentHull  = count (magazines _veh);
_currentTotal = _currentHull;

_turrets = _veh Call WFBE_CO_FNC_GetVehicleTurretsGear;
{
	_currentTotal = _currentTotal + count (_veh magazinesTurret (_x select 2));
} forEach _turrets;

//--- Fraction, clamped 0..1.
((_currentTotal / _fullTotal) min 1) max 0
