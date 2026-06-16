/*
	Return the closest airport of the given entitie.
	 Parameters:
		- Object
*/

Private ["_closest","_near","_pos","_range","_hangar","_afSide"];

_closest = objNull;
_pos = _this select 0;
_range = _this select 1;

_near = _pos nearEntities [WFBE_Logic_Airfield, _range];
{_hangar = _x getVariable ["wfbe_hangar", objNull]; if !(isNil {_x getVariable "wfbe_hangar"}) then {if (alive _hangar) then {if (sideJoined == resistance) then {_afSide = _x getVariable ["wfbe_airfield_side", civilian]; if (_afSide == resistance) then {_closest = _x}} else {_closest = _x}}}} forEach _near;

_closest