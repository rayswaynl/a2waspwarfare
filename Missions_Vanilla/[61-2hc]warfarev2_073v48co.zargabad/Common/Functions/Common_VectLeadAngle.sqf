/*
	Common_VectLeadAngle.sqf
	WFBE_CO_FNC_VectLeadAngle

	Intercept ("lead angle") solver for a projectile of known constant speed against a target
	moving at constant velocity, part of the SQF utility library (card #25). No gameplay
	consumer in this PR - cited by future card #12 (CIWS) and #14 (JTAC) work.

	Classic constant-velocity intercept: solves for the smallest positive time-to-intercept t
	such that a projectile fired now at speed _speed reaches the target's future position.
	Letting _rel = targetPos - shooterPos and _vT = target velocity:

		a = dot(_vT,_vT) - _speed^2
		b = 2 * dot(_rel,_vT)
		c = dot(_rel,_rel)
		a*t^2 + b*t + c = 0   (falls back to the linear case b*t + c = 0 when a ~ 0, i.e.
		                       target speed equals projectile speed)

	This is a straight-line/no-gravity solve (fine for direct-fire lead; NOT a ballistic-drop
	solve - combine with WFBE_CO_FNC_VectElevationSolve for arcing weapons at the resulting
	distance if both lead and drop matter).

	Params:
		0: _shooterPos  ARRAY [x,y,z] (or [x,y]).
		1: _targetPos   ARRAY [x,y,z] (or [x,y]), target's CURRENT position.
		2: _targetVel   ARRAY [x,y,z] (or [x,y]), target's current velocity vector (m/s per
		                 axis, e.g. `velocity _target`). If _targetVel has FEWER components than
		                 _targetPos, missing trailing components default to 0 (never a silent
		                 array hole in the returned _aimPoint).
		3: _speed       NUMBER, projectile speed in m/s, > 0.

	Returns: ARRAY. On success: [_aimPoint, _t] where _aimPoint is the predicted intercept
	         position (ARRAY, same dimensionality as _targetPos) and _t is the time-to-intercept
	         in seconds (NUMBER, > 0). On failure (no positive real root - target unreachable /
	         outrunning the projectile): an EMPTY ARRAY [] - callers must check
	         `count _result > 0` before indexing it.
*/

private ["_shooterPos","_targetPos","_targetVel","_speed","_rel","_a","_b","_c","_disc","_t","_t1","_t2","_result","_aimPoint","_dim","_i","_velComponent"];

_shooterPos = _this select 0;
_targetPos = _this select 1;
_targetVel = _this select 2;
_speed = _this select 3;

_rel = [(_targetPos select 0) - (_shooterPos select 0), (_targetPos select 1) - (_shooterPos select 1), 0];
if (count _targetPos > 2 && {count _shooterPos > 2}) then {
	_rel set [2, (_targetPos select 2) - (_shooterPos select 2)];
};

_a = ([_targetVel, _targetVel] call WFBE_CO_FNC_VectDot) - (_speed * _speed);
_b = 2 * ([_rel, _targetVel] call WFBE_CO_FNC_VectDot);
_c = [_rel, _rel] call WFBE_CO_FNC_VectDot;

_t = -1;

if (abs _a < 0.0001) then {
	if (abs _b > 0.0001) then {
		_t1 = (-_c) / _b;
		if (_t1 > 0) then {_t = _t1};
	};
} else {
	_disc = (_b * _b) - (4 * _a * _c);
	if (_disc >= 0) then {
		_t1 = ((-_b) + sqrt _disc) / (2 * _a);
		_t2 = ((-_b) - sqrt _disc) / (2 * _a);
		//--- want the SMALLEST positive root.
		if (_t1 > 0) then {_t = _t1};
		if (_t2 > 0 && {_t2 < _t || _t < 0}) then {_t = _t2};
	};
};

_result = [];

if (_t > 0) then {
	_dim = count _targetPos;
	_aimPoint = [];
	_i = 0;
	while {_i < _dim} do {
		_velComponent = 0;
		if (_i < count _targetVel) then {_velComponent = _targetVel select _i};
		_aimPoint set [_i, (_targetPos select _i) + (_velComponent * _t)];
		_i = _i + 1;
	};
	_result = [_aimPoint, _t];
};

_result
