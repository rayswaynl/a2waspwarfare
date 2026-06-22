/*
	Retrieve a random position.
	 Parameters:
		- Position
		- Min Radius
		- Max Radius
*/

Private["_position","_radius","_direction","_maxRadius","_minRadius","_iter"];

_position = _this select 0;
_minRadius = _this select 1;
_maxRadius = _this select 2;
_direction = random 360;

if (typeName _position == "OBJECT") then {_position = getPos _position};
if (count _position < 3) then {_position set [2, 0]};

_radius = (random (_maxRadius - _minRadius)) + _minRadius;
_position = [(_position select 0)+((sin _direction)*_radius),(_position select 1)+((cos _direction)*_radius),(_position select 2)];
_iter = 0;
while {surfaceIsWater _position && _iter < 50}do {_direction = random 360;_radius = (random (_maxRadius - _minRadius)) + _minRadius;_position = [(_position select 0)+((sin _direction)*_radius),(_position select 1)+((cos _direction)*_radius),(_position select 2)];_iter = _iter + 1};

_position