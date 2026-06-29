/*
	Client helper: controls EASA access for the playable GUER faction at town centers.
	GUER Insurgents are base-less (no vehicle service points, no EASA upgrade economy), so the
	aircraft-loadout editor is granted at FRIENDLY town centers instead of at service points.
	GUER-only by construction: the WFBE_C_GUER_PLAYERSIDE + resistance gates mean WEST/EAST never
	reach this predicate. Mirrors Client_CanUseRepairPointEASA.sqf ([unit, vehicle] -> bool).
*/
Private ["_unit","_vehicle","_range","_ok"];

_unit = _this select 0;
_vehicle = _this select 1;

if ((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) <= 0) exitWith {false};	//--- playable GUER faction off -> never
if (side group _unit != resistance) exitWith {false};									//--- GUER-only: WEST/EAST locked out
if (_vehicle == _unit) exitWith {false};
if (driver _vehicle != _unit) exitWith {false};
if !(typeOf _vehicle in (missionNamespace getVariable "WFBE_EASA_Vehicles")) exitWith {false};

_range = missionNamespace getVariable "WFBE_C_UNITS_SUPPORT_RANGE";	//--- same rearm action range as the service-point EASA path
_ok = false;
{
	//--- Friendly town center = GUER-owned OR neutral (not held by WEST, not held by EAST). Same idiom as the GUER respawn pick.
	if (((_x getVariable ["sideID",-1]) != WFBE_C_WEST_ID) && {(_x getVariable ["sideID",-1]) != WFBE_C_EAST_ID}) then {
		if (_unit distance _x < _range) exitWith {_ok = true};
	};
} forEach towns;

_ok
