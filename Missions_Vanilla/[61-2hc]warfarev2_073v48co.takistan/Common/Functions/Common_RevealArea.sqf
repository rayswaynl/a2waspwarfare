/*
	Reveal an entire area for a unit/team.
	 Parameters:
		- Unit/Team
		- Range
		- Center Position
*/

Private ["_pos","_range","_reveal","_team","_unit"];

_unit = _this select 0;
_range = _this select 1;
_pos = _this select 2;

{
	//--- Expand vehicle crew: `_x != vehicle _x` is only true for mounted men, never for the
	//--- vehicle object itself (vehicle of a vehicle is itself). nearEntities returns hulls, and
	//--- Man-typed scans elsewhere in-repo document that mounted men are NOT returned as Man
	//--- (Server_GuerAirDef.sqf hunt fix). Without an isKindOf "Man" branch, crew never entered
	//--- _reveal and only the hull got knowsAbout. Mounted-man branch kept for untyped scans.
	_reveal = [_x];
	if !(_x isKindOf "Man") then {
		_reveal = _reveal + (crew _x);
	} else {
		if (_x != vehicle _x) then {_reveal = _reveal + (crew _x)};
	};
	{_unit reveal _x} forEach _reveal;
} forEach (_pos nearEntities _range);