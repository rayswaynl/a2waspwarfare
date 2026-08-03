/*
	Common_VectElevationSolve.sqf
	WFBE_CO_FNC_VectElevationSolve

	Ballistic elevation-angle solver (low-arc solution), part of the SQF utility library (card
	#25). No gameplay consumer in this PR - cited by future card #12 (CIWS) and #14 (JTAC) work
	as a shared building block; those wire it up in their own flag-gated PRs.

	Standard projectile-motion elevation formula for a fixed-speed launcher hitting a point at
	horizontal distance _dist and height offset _dz relative to the shooter:

		theta = atan( (v^2 - sqrt(v^4 - g*(g*x^2 + 2*y*v^2))) / (g*x) )

	using the LOW-ARC root (minus sign) - the flatter of the two firing solutions, appropriate
	for direct-fire weapons. SQF trig commands (sin/cos/tan/asin/acos/atan/atan2) operate in
	DEGREES, not radians - this function follows that convention, so its return value is ready
	to feed straight into aiming-pitch math without a radians conversion.

	Params:
		0: _dist  NUMBER, horizontal distance to target in metres, > 0.
		1: _dz    NUMBER, target height minus shooter height in metres (may be negative).
		2: _speed NUMBER, projectile muzzle speed in m/s, > 0.
		3: _g     NUMBER, optional, gravity in m/s^2. Defaults to 9.81.

	Returns: NUMBER, elevation angle in DEGREES above the horizontal (may be negative when the
	         target is below the shooter), or -1 (sentinel, NOT a valid angle) if the target is
	         out of range at the given speed (negative discriminant) or _dist <= 0.
*/

private ["_dist","_dz","_speed","_g","_v2","_disc","_theta"];

_dist = _this select 0;
_dz = _this select 1;
_speed = _this select 2;
_g = if (count _this > 3) then {_this select 3} else {9.81};

_theta = -1;

if (_dist > 0) then {
	_v2 = _speed * _speed;
	_disc = (_v2 * _v2) - (_g * ((_g * _dist * _dist) + (2 * _dz * _v2)));
	if (_disc >= 0) then {
		_theta = atan ((_v2 - sqrt _disc) / (_g * _dist));
	};
};

_theta
