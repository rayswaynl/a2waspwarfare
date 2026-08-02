/*
	Returns true only when a player-requested factory position is usable.
	The CoIn client preview already shows the same water/flat-footprint result,
	but the server must re-check the submitted payload before reserving a build.
	_this = [side, structure classname, position]
*/
Private ["_flatGrad","_flatRadius","_index","_position","_side","_structureDistances","_structureNames","_structureType"];

_side = _this select 0;
_structureType = _this select 1;
_position = _this select 2;

if ((typeName _position) != "ARRAY" || {count _position < 2}) exitWith {false};
if ((typeName (_position select 0)) != "SCALAR" || {(typeName (_position select 1)) != "SCALAR"}) exitWith {false};
if (surfaceIsWater _position) exitWith {false};

//--- Factory-specific footprint: match the GUER FOB validation instead of using a fixed centre-only radius.
_flatRadius = missionNamespace getVariable ["WFBE_C_STRUCTURES_FLAT_RADIUS", 10];
_structureNames = missionNamespace getVariable [Format ["WFBE_%1STRUCTURENAMES", str _side], []];
_index = _structureNames find _structureType;
_structureDistances = missionNamespace getVariable [Format ["WFBE_%1STRUCTUREDISTANCES", str _side], []];
if (_index >= 0 && {_index < count _structureDistances} && {(typeName (_structureDistances select _index)) == "SCALAR"}) then {
	_flatRadius = _flatRadius max (_structureDistances select _index);
};

if ((missionNamespace getVariable ["WFBE_C_STRUCTURES_FLAT_CHECK", 0]) > 0) then {
	_flatGrad = missionNamespace getVariable ["WFBE_C_STRUCTURES_FLAT_GRAD", 2];
	if (count (_position isFlatEmpty [_flatRadius, 0, _flatGrad, 10, 0, false, objNull]) == 0) exitWith {false};
};

true
