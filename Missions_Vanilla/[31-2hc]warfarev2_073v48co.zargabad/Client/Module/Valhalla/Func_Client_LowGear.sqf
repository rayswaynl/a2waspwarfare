/*
	Script from Valhalla.
	Modified by Marty.

	Description:
		High climbing mode for player-driven vehicles.

		This version works as a climbing assist only:
		- it boosts the vehicle when it is moving forward but too slowly;
		- it does not limit the vehicle top speed anymore;
		- it does not apply braking above the target assist speed;
		- it avoids pushing the vehicle when it is almost stopped.
*/

Private [
	"_vehicle",
	"_direction",
	"_min",
	"_minBoostSpeed",
	"_boostCoef",
	"_baseBoostCoef",
	"_maxBoostCoef",
	"_speed",
	"_vel",
	"_isMovingForward"
];

_vehicle = _this;

if (Local_HighClimbingRunning) exitWith {};
Local_HighClimbingRunning = true;

_direction = {
	private["_vel","_veh","_vdir","_dir"];
	
	_vel = _this select 0;
	_veh = _this select 1;
	
	_vdir = (_vel select 0) atan2 (_vel select 1);
	if (_vdir < 0) then {_vdir = _vdir + 360};

	_dir = getDir _veh;
	if (_dir < 0) then {_dir = _dir + 360};
	
	_vdir = _vdir - _dir;
	
	if (abs(_vdir) < 15) then {true} else {false};
};

// Target assist speed.
// The script boosts only while the vehicle speed is below this value.
_min = 40; // Only for light vehicle. Tanks have another value defined further.

// Minimum speed required before applying boost.
// This prevents the script from pushing the vehicle when the player is trying to stop.
_minBoostSpeed = 1;

// Progressive velocity multiplier applied while the vehicle is moving forward but too slowly.
// Keeps normal low-speed driving gentle, while giving more help on steep climbs.
_baseBoostCoef = 1.05;
_maxBoostCoef = 1.30;

// Tanks use a lower target assist speed.
if (_vehicle isKindOf "Tank") then {
	_min = 30; 
};

while {
	(player == driver _vehicle) &&
	{Local_HighClimbingModeOn} &&
	{_vehicle getVariable ["WFBE_HighClimbingEnabled", false]} &&
	{canMove _vehicle}
} do {

	_speed = speed _vehicle;
	_vel = velocity _vehicle;

	if (
		Local_KeyPressedForward &&
		{isEngineOn _vehicle} &&
		{_speed > _minBoostSpeed} &&
		{_speed < _min}
	) then {

		_isMovingForward = [_vel, _vehicle] call _direction;

		if (_isMovingForward) then {
			_boostCoef = _baseBoostCoef + (((_min - _speed) / _min) * (_maxBoostCoef - _baseBoostCoef));
			if (_boostCoef > _maxBoostCoef) then {_boostCoef = _maxBoostCoef};

			_vel = [
				(_vel select 0) * _boostCoef,
				(_vel select 1) * _boostCoef,
				(_vel select 2)
			];

			_vehicle setVelocity _vel;
		};
	};

	sleep 0.1;
};

Local_HighClimbingModeOn = false;
Local_HighClimbingRunning = false;
