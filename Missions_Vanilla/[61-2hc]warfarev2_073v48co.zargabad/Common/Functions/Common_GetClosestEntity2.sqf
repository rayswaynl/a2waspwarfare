/*
	Return the closest object among a list
	 Parameters:
		- Entity.
		- List.
*/

Private["_distance","_nearest","_object","_objects"];

_object = _this select 0;
_objects = _this select 1;

if (isNil "_object") exitWith {objNull};
if (isNil "_objects" || {typeName _objects != "ARRAY"}) exitWith {objNull}; //--- fix(bughunt): nil/non-array guard mirroring Common_GetClosestEntity.sqf; callers pass wfbe_basearea, nil when Base Area is disabled -> bare forEach threw

_nearest = objNull;
//--- r52: 2-arg getVariable defaults so nil missionNamespace keys never make _distance nil (comparison throw).
//--- isNull skips deleted list holes; bare isNil does not catch objNull.
_distance = (missionNamespace getVariable ["WFBE_C_BASE_AREA_RANGE", 0]) + (missionNamespace getVariable ["WFBE_C_BASE_HQ_BUILD_RANGE", 0]);
if (_distance <= 0) then {_distance = 100000};
{if (!isNil "_x" && {!isNull _x} && {(_x distance _object) < _distance}) then {_nearest = _x;_distance = _x distance _object}} forEach _objects;

_nearest