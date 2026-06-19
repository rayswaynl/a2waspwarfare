/*
	Retrieve a random position.
	 Parameters:
		- Position
		- Min Radius
		- Max Radius
*/

Private["_position","_radius","_direction","_maxRadius","_minRadius"];

//--- F3 guard: bad/short input would throw on the _this select lines below; bail to a safe [0,0,0].
if (typeName _this != "ARRAY" || {count _this < 3}) exitWith {[0,0,0]};

_position = _this select 0;
_minRadius = _this select 1;
_maxRadius = _this select 2;
_direction = random 360;

//--- F3 guard: clamp nil / non-scalar radii so the (random ...) maths below can't throw (A2-safe).
if (typeName _minRadius != "SCALAR") then {_minRadius = 0};
if (typeName _maxRadius != "SCALAR") then {_maxRadius = 0};

if (typeName _position == "OBJECT") then {_position = getPos _position};
//--- F3 guard: a non-array position (nil/scalar) would throw on the count/set below - fall back to [0,0,0].
if (typeName _position != "ARRAY") then {_position = [0,0,0]};
if (count _position < 3) then {_position set [2, 0]};

_radius = (random (_maxRadius - _minRadius)) + _minRadius;
_position = [(_position select 0)+((sin _direction)*_radius),(_position select 1)+((cos _direction)*_radius),(_position select 2)];
while {surfaceIsWater _position}do {_direction = random 360;_radius = (random (_maxRadius - _minRadius)) + _minRadius;_position = [(_position select 0)+((sin _direction)*_radius),(_position select 1)+((cos _direction)*_radius),(_position select 2)]};

_position