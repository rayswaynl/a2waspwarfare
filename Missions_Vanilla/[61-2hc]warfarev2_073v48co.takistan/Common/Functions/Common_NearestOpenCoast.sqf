//--- Common_NearestOpenCoast.sqf
//--- Nearest OPEN-sea bearing + distance from a position. Extracted from the proven
//--- feat/drone-saturation-strike naval-launch finder, for reuse by the naval HVTs + SCUD strike.
//--- _this = [_pos, _maxRange (opt, def 12000), _stepDist (opt, def 300)]
//--- Returns [_dir(deg), _dist(m)] of the nearest open coast, or [-1,-1] if none.
//--- "Open" = water that is STILL water 1500m further out on the same bearing (excludes lakes/ponds).
private ["_pos","_maxRange","_step","_dir","_dist","_a","_w","_r"];
_pos      = _this select 0;
_maxRange = if (count _this > 1) then {_this select 1} else {12000};
_step     = if (count _this > 2) then {_this select 2} else {300};
_dir = -1; _dist = 999999;
for "_a" from 0 to 345 step 15 do {
	_w = -1;
	for "_r" from _step to _maxRange step _step do {
		if (surfaceIsWater [(_pos select 0) + _r * sin _a, (_pos select 1) + _r * cos _a]) exitWith {_w = _r};
	};
	if (_w > 0 && {surfaceIsWater [(_pos select 0) + (_w + 1500) * sin _a, (_pos select 1) + (_w + 1500) * cos _a]} && {_w < _dist}) then {
		_dist = _w; _dir = _a;
	};
};
if (_dir < 0) then {[-1, -1]} else {[_dir, _dist]}
