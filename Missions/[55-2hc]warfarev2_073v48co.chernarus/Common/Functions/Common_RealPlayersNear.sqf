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
Private ["_position","_radius","_side","_filter","_useSide","_excludeCivilian","_hcUnits","_count"];

if (count _this < 2) exitWith {0};
_position = _this select 0;
_radius = _this select 1;
if (typeName _position != "ARRAY" || {typeName _radius != "SCALAR"} || {_radius <= 0}) exitWith {0};
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

_hcUnits = [];
{
	if (!isNull _x) then {
		{_hcUnits set [count _hcUnits, _x]} forEach (units _x);
	};
} forEach (missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []]);

_count = 0;
{
	if (alive _x && {isPlayer _x} && {!(_x in _hcUnits)} && {!_excludeCivilian || {(side _x) != civilian}} && {!((name _x) in ["HC-AI-Control-1","HC-AI-Control-2","HC-AI-Control-3","HC"])} && {(_x distance _position) < _radius} && {!_useSide || {side _x == _side}}) then {
		_count = _count + 1;
	};
} forEach playableUnits;

_count
