/*
	File: Common_RealPlayersNear.sqf
	Author: WASP Warfare
	Description: Counts living human players near a position. Registered and known headless-client bodies are excluded.
	Parameters:
		0 - position (ARRAY)
		1 - radius (SCALAR)
		2 - optional side filter (SIDE), or BOOLEAN to exclude CIVILIAN players
	Returns: SCALAR
	A2-OA-1.64 safe: playableUnits / isPlayer / alive / side / name / lazy && {} and || {} only.
*/
Private ["_position","_radius","_side","_filter","_useSide","_excludeCivilian","_count"];

if ((typeName _this) != "ARRAY") exitWith {0};
if (count _this < 2) exitWith {0};
_position = _this select 0;
_radius = _this select 1;
if ((typeName _position) != "ARRAY" || {(count _position) < 2} || {(count _position) > 3}) exitWith {0};
if ((typeName (_position select 0)) != "SCALAR" || {(typeName (_position select 1)) != "SCALAR"}) exitWith {0};
if (count _position > 2 && {(typeName (_position select 2)) != "SCALAR"}) exitWith {0};
if ((typeName _radius) != "SCALAR" || {_radius <= 0}) exitWith {0};
_useSide = false;
_excludeCivilian = false;
if (count _this > 2) then {
	_filter = _this select 2;
	if (typeName _filter == "BOOL") then {
		_excludeCivilian = _filter;
	} else {
		_useSide = true;
		_side = _filter;
	};
};

//--- HC and dedicated-caster exclusion is centralized in Common_IsRealPlayer.sqf.

_count = 0;
{
	if ([_x] Call WFBE_CO_FNC_IsRealPlayer && {alive _x} && {!_excludeCivilian || {(side _x) != civilian}} && {(_x distance _position) < _radius} && {!_useSide || {side _x == _side}}) then {
		_count = _count + 1;
	};
} forEach playableUnits;

_count
