/*
	Common_VectDot.sqf
	WFBE_CO_FNC_VectDot

	3D dot product, part of the SQF utility library (card #25). Written as manual index
	arithmetic, NOT a wrapper around any native `vect*` command - this session could not
	complete a network verification pass (a2oa-verify-command skill, rungs 1/2 both require
	network access) confirming which vector commands A2 OA 1.64 natively exposes, so this is a
	clean-room implementation rather than a call into a possibly-nonexistent or
	possibly-different-semantics engine command. If a later pass confirms an equivalent native
	command, this function can be thinned to a one-line wrapper without changing its calling
	convention - treat this as the open verification item noted against card #25 in this repo's
	mining-review process before any further vector-math adoption.

	Params:
		0: _a  ARRAY [x,y,z] (or [x,y], z assumed 0).
		1: _b  ARRAY [x,y,z] (or [x,y], z assumed 0).

	Returns: NUMBER, the dot product _a . _b.
*/

private ["_a","_b","_az","_bz"];

_a = _this select 0;
_b = _this select 1;
_az = if (count _a > 2) then {_a select 2} else {0};
_bz = if (count _b > 2) then {_b select 2} else {0};

((_a select 0) * (_b select 0)) + ((_a select 1) * (_b select 1)) + (_az * _bz)
