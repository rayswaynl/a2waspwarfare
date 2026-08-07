/*
	Reveal an entire area for a unit/team.
	 Parameters:
		- Unit/Team
		- Range
		- Center Position
*/

Private ["_contacts","_contactsProvided","_pos","_range","_reveal","_team","_unit"];

_unit = _this select 0;
_range = _this select 1;
_pos = _this select 2;
_contactsProvided = count _this > 3;
_contacts = if (count _this > 3) then {_this select 3} else {[]};
if (typeName _contacts != "ARRAY") then {_contacts = []; _contactsProvided = false};

{
	_reveal = [_x];
	if !(_x isKindOf "Man") then {
		_reveal = _reveal + (crew _x);
	} else {
		if (_x != vehicle _x) then {_reveal = _reveal + (crew _x)};
	};
	{_unit reveal _x} forEach _reveal;
} forEach (if (_contactsProvided) then {_contacts} else {_pos nearEntities _range});
