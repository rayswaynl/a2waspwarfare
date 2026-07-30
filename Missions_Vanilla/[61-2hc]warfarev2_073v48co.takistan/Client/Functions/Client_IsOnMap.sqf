Private ['_boundary','_px','_py'];

//--- Square AABB boundary test (WFBE_BOUNDARIESXY is map side length from origin).
//--- Replaces atan(_difx/_dify) + 1/cos ray math which divides by zero on axis-aligned
//--- rays through map centre (NaN border distance -> false OFF-MAP / false kill risk).
_boundary = missionNamespace getVariable ['WFBE_BOUNDARIESXY', 15360];
if (isNil "_boundary" || {typeName _boundary != "SCALAR"} || {_boundary <= 0}) exitWith {true};

_px = getPos player select 0;
_py = getPos player select 1;

if (_px >= 0 && {_px <= _boundary} && {_py >= 0} && {_py <= _boundary}) then {true} else {false}
