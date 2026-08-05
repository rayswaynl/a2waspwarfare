/*
	Common_VectMagnitude.sqf
	WFBE_CO_FNC_VectMagnitude

	3D vector magnitude (length), part of the SQF utility library (card #25). Manual arithmetic
	via WFBE_CO_FNC_VectDot + sqrt - not a wrapper around a native `vect*` command, same
	verification-pending rationale as Common_VectDot.sqf/Common_VectCross.sqf.

	Params:
		0: _a  ARRAY [x,y,z] (or [x,y], z assumed 0).

	Returns: NUMBER, >= 0.
*/

private ["_a"];

_a = _this select 0;

sqrt ([_a, _a] call WFBE_CO_FNC_VectDot)
