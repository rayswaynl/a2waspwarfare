/*
	Client helper: returns nearby service points that were built from a repair truck.
*/
Private ["_points","_range","_unit"];

_unit = _this select 0;
_range = missionNamespace getVariable "WFBE_C_UNITS_SUPPORT_RANGE";
_points = [];

{
	if (alive _x && (_x getVariable ["WFBE_RepairTruckServicePoint", false])) then {
		_points = _points + [_x];
	};
} forEach (nearestObjects [getPos _unit, ["Base_WarfareBVehicleServicePoint"], _range]);	//--- FIX: nearEntities never finds the service point (it is a static BUILDING, not an entity) -> EASA button never enabled. nearestObjects scans all object types.

_points
