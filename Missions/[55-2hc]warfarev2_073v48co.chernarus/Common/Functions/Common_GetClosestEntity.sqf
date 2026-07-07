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
if (isNil "_objects" || {typeName _objects != "ARRAY"}) exitWith {objNull}; //--- B754 (Ray 2026-06-25): nil/non-array guard. GUI_RespawnMenu can pass a nil list when GetRespawnAvailable transiently returns nil; the bare forEach below otherwise throws "Undefined variable _x" (83x in the b753 GUER client RPT).

_nearest = objNull;
_distance = 100000;
{if (!isNil "_x" && {(_x distance _object) < _distance}) then {_nearest = _x;_distance = _x distance _object}} forEach _objects; //--- fable/tonight-hotfixes2: nil-hole guard

_nearest