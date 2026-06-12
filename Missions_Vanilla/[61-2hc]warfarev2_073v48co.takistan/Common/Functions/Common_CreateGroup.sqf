/*
	Central createGroup wrapper with group-cap guard and source attribution.
	Parameters: [_side, _sourceTag (string)]
	Returns:    the new group, or grpNull on failure.

	Behaviour:
	  1. Count groups of _side across allGroups.
	  2. If >= 140, run an immediate emergency GC pass (delete zero-living-unit,
	     non-wfbe_persistent groups of that side) and log one AICOMLog WARNING.
	  3. createGroup _side.
	  4. On grpNull: log AICOMLog WARNING and return grpNull.
	  5. On success: tag the group with wfbe_group_src = _sourceTag and return it.
*/

Private ["_side", "_sourceTag", "_cnt", "_grp", "_isPersistent", "_liveCount", "_gcDone"];

_side      = _this select 0;
_sourceTag = _this select 1;

// --- Count groups for this side ---
_cnt = 0;
{
	if (side _x == _side) then { _cnt = _cnt + 1 };
} forEach allGroups;

// --- Emergency GC if approaching cap ---
if (_cnt >= 140) then {
	_gcDone = 0;
	{
		if (side _x == _side) then {
			_isPersistent = _x getVariable "wfbe_persistent";
			if (isNil "_isPersistent") then { _isPersistent = false };
			_liveCount = { alive _x } count (units _x);
			if (!_isPersistent && { _liveCount == 0 }) then {
				deleteGroup _x;
				_gcDone = _gcDone + 1;
			};
		};
	} forEach allGroups;

	// Recount after sweep
	_cnt = 0;
	{ if (side _x == _side) then { _cnt = _cnt + 1 } } forEach allGroups;

	["WARNING", Format ["Common_CreateGroup.sqf: emergency GC for %1 at %2 groups (source: %3) - reaped %4 empty groups.", str _side, _cnt, _sourceTag, _gcDone]] Call WFBE_CO_FNC_AICOMLog;
};

// --- Create the group ---
_grp = createGroup _side;

if (isNull _grp) then {
	["WARNING", Format ["Common_CreateGroup.sqf: createGroup returned grpNull for %1 (source: %2) - %3 groups on side.", str _side, _sourceTag, _cnt]] Call WFBE_CO_FNC_AICOMLog;
} else {
	_grp setVariable ["wfbe_group_src", _sourceTag];
};

_grp
