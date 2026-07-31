/*
	Basic check between two points.
	 Parameters:
		- Position 1
		- Position 2
		- Steps

	r78b: fail-clean short/malformed args, non-array positions, and steps <= 0
	(would otherwise hang the scheduler in while {_current < _distance} forever).
*/

Private ["_current","_dir_to","_distance","_pos","_posa","_posb","_steps","_safe"];

//--- r78b: arg arity + type. Path planner can race a culled team/town; callers also pass
//--- nodes that were compacted with `false` tombstones in rare reorder bugs. Returning false
//--- (unsafe) is the conservative fail: caller stops hopping and falls through to depot SAD.
if (isNil "_this" || {typeName _this != "ARRAY"} || {count _this < 3}) exitWith {false};

_posa = _this select 0;
_posb = _this select 1;
_steps = _this select 2;

if (isNil "_posa" || {typeName _posa != "ARRAY"} || {count _posa < 2}) exitWith {false};
if (isNil "_posb" || {typeName _posb != "ARRAY"} || {count _posb < 2}) exitWith {false};
if (isNil "_steps" || {typeName _steps != "SCALAR"} || {_steps <= 0}) exitWith {false};

_distance = (_posa distance _posb) - _steps;
_dir_to = [_posa, _posb] Call WFBE_CO_FNC_GetDirTo;

_safe = true;
_current = _steps;
while {_current < _distance} do {
	_pos = [(_posa select 0) + _current * sin(_dir_to),(_posa select 1) + _current * cos(_dir_to), 0];
	if (surfaceIsWater(_pos)) exitWith {_safe = false};
	_current = _current + _steps;
};

_safe
