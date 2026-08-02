/*
	Pick the alive structure of a given class that sits closest to an UNOWNED/enemy town (the most
	FORWARD one) among a supplied structure list, instead of the first match in build order.

	Fix for: HC team founding (AI_Commander_Teams.sqf) always resolved the doctrine/owned-factory
	spawn point via a forEach+exitWith over wfbe_structures, which is APPEND-ONLY build order (oldest
	first) - so every founding kept using the side's very FIRST factory of that type and a later
	player-built FORWARD factory was never reached, however close to the front it stood.

	Falls back to the first alive match when the side owns the whole map (no unowned town exists) or
	when nothing qualifies, so the result stays deterministic and never regresses to objNull when a
	valid candidate exists.

	Parameters:
		0: _facClass   (STRING) - typeOf classname to match (e.g. a side's Light-Factory class).
		1: _structures (ARRAY)  - candidate structures (the side's wfbe_structures snapshot).
		2: _mySideID   (SCALAR) - this side's sideID (town-ownership tag), from WFBE_CO_FNC_GetSideID.

	Returns: OBJECT - the picked factory, or objNull when no alive match exists.
*/
Private ["_facClass","_structures","_mySideID","_cands","_best","_bestD","_cand","_nearD","_tOwn"];
_facClass   = _this select 0;
_structures = _this select 1;
_mySideID   = _this select 2;

_cands = [];
{ if (!isNil "_x" && {typeOf _x == _facClass} && {alive _x}) then {_cands set [count _cands, _x]} } forEach _structures;

if (count _cands == 0) exitWith {objNull};
if (count _cands == 1) exitWith {_cands select 0};

_best  = _cands select 0;
_bestD = 1e18;
{
	_cand  = _x;
	_nearD = 1e18;
	{
		_tOwn = _x getVariable ["sideID", -1];
		if (_tOwn != _mySideID) then {
			if ((_cand distance _x) < _nearD) then {_nearD = _cand distance _x};
		};
	} forEach towns;
	if (_nearD < _bestD) then {_bestD = _nearD; _best = _cand};
} forEach _cands;

_best
