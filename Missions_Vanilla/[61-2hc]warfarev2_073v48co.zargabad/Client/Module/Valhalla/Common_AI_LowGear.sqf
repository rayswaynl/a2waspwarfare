/*
	Author: Marty

	Name:
		Common_AI_LowGear.sqf

	Description:
		Applies low gear / climbing assist to AI-driven tanks controlled by the player's group.

		This script is intended to run client-side.
		It only applies the velocity boost if the vehicle is local to this client.

		The script is designed as a climbing assist only:
		- it helps the tank when it is already moving forward but too slowly;
		- it does not limit the vehicle top speed anymore;
		- it does not apply braking above the target assist speed.

	Parameters:
		_vehicle : object - tank to assist
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
	"_driver",
	"_isMovingForward",
	"_hasPlayerCrew",
	"_currentCommand",
	"_canAssist",
	"_highClimbingEnabled",
	"_sleepDelay"
];

_vehicle = _this;

if (isNull _vehicle) exitWith {};
if !(_vehicle isKindOf "Tank") exitWith {};

// The velocity correction must only be applied where the vehicle is local.
if !(local _vehicle) exitWith {};

// Avoid duplicate loops on the same client for the same vehicle.
if (_vehicle getVariable ["AI_LowGear_Running", false]) exitWith {};
_vehicle setVariable ["AI_LowGear_Running", true, false];

_direction = {
	private["_vel", "_veh", "_vdir", "_dir"];

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
// The script will help the tank only while its speed is below this value.
_min = 30;

// Minimum speed required before applying boost.
// This prevents the script from pushing the tank when the player ordered it to stop.
_minBoostSpeed = 3;

// Progressive velocity multiplier applied while the tank is moving forward but too slowly.
// Keeps normal low-speed driving gentle, while giving more help to tanks stuck on steep climbs.
_baseBoostCoef = 1.05;
_maxBoostCoef = 1.30;

while {
	!isNull _vehicle &&
	{alive _vehicle} &&
	{canMove _vehicle} &&
	{local _vehicle}
} do {

	_sleepDelay = 0.5;
	_driver = driver _vehicle;

	if (!isNull _driver) then {

		// Only AI drivers.
		if (!isPlayer _driver && {isEngineOn _vehicle}) then {

				_sleepDelay = 0.1;
				_speed = speed _vehicle;
				_vel = velocity _vehicle;
				_currentCommand = currentCommand _driver;
				_hasPlayerCrew = {isPlayer _x} count crew _vehicle > 0;
				_highClimbingEnabled = if (_hasPlayerCrew) then {
					_vehicle getVariable ["WFBE_HighClimbingEnabled", false]
				} else {
					true
				};

			// Do not let the climbing assist fight explicit stop orders.
			// If the AI driver has been stopped, or is currently processing STOP/WAIT,
			// the tank may still roll downhill, but the script must not boost that roll.
			_canAssist = _highClimbingEnabled && {!(stopped _driver)} && {!(_currentCommand in ["WAIT", "STOP"])};

			if (!_highClimbingEnabled) then {
				_sleepDelay = 0.5;
			};

			_isMovingForward = [_vel, _vehicle] call _direction;

			if (_canAssist && {_isMovingForward}) then {

				// Climbing assist only.
				// Boost only when the tank is already moving forward but is still too slow.
				// No braking is applied above the target assist speed.
				if (_speed > _minBoostSpeed && {_speed < _min}) then {
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
		};
	};

	sleep _sleepDelay;
};

_vehicle setVariable ["AI_LowGear_Running", false, false];
