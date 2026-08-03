/*
	Common_VectCross.sqf
	WFBE_CO_FNC_VectCross

	3D cross product, part of the SQF utility library (card #25). Manual index arithmetic, not
	a wrapper around a native `vect*` command - see Common_VectDot.sqf's header for why (this
	session could not complete the network verification pass for which vector primitives A2 OA
	1.64 natively exposes; treat this as a documented placeholder pending that pass, not proof
	no native equivalent exists).

	Params:
		0: _a  ARRAY [x,y,z] (or [x,y], z assumed 0).
		1: _b  ARRAY [x,y,z] (or [x,y], z assumed 0).

	Returns: ARRAY [x,y,z], the cross product _a x _b.
*/

private ["_a","_b","_ax","_ay","_az","_bx","_by","_bz"];

_a = _this select 0;
_b = _this select 1;
_ax = _a select 0;
_ay = _a select 1;
_az = if (count _a > 2) then {_a select 2} else {0};
_bx = _b select 0;
_by = _b select 1;
_bz = if (count _b > 2) then {_b select 2} else {0};

[
	(_ay * _bz) - (_az * _by),
	(_az * _bx) - (_ax * _bz),
	(_ax * _by) - (_ay * _bx)
]
