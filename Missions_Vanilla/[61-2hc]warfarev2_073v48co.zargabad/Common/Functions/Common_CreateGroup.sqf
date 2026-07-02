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

Private ["_side", "_sourceTag", "_cnt", "_grp", "_isPersistent", "_liveCount", "_gcDone", "_sideKey", "_warnKey", "_warnLast"];

_side      = _this select 0;
_sourceTag = _this select 1;
_sideKey = switch (_side) do {
	case west: {"west"};
	case east: {"east"};
	case resistance: {"guer"};
	case civilian: {"civ"};
	case sideLogic: {"logic"};
	default {"unknown"};
};

// --- Count groups for this side ---
_cnt = 0;
{
	if (side _x == _side) then { _cnt = _cnt + 1 };
} forEach allGroups;

// --- Emergency GC if approaching cap ---
if (_cnt >= 140) then {
	_gcDone = 0;
	//--- Collect deletion candidates into an array first; delete in a second pass to avoid
	//--- modifying allGroups while iterating it (A2 OA 1.64 behaviour is undefined in that case).
	Private ["_gcCands"];
	_gcCands = [];
	{
		if (side _x == _side) then {
			_isPersistent = _x getVariable "wfbe_persistent";
			if (isNil "_isPersistent") then { _isPersistent = false };
			_liveCount = count (units _x); //--- true emptiness only: A2 deleteGroup no-ops on a group still holding (even dead) units; {alive} would flag unreapable corpse-only groups and inflate the reap count
			if (!_isPersistent && { _liveCount == 0 }) then {
				_gcCands = _gcCands + [_x];
			};
		};
	} forEach allGroups;
	{
		deleteGroup _x;
		_gcDone = _gcDone + 1;
	} forEach _gcCands;

	// Recount after sweep
	_cnt = 0;
	{ if (side _x == _side) then { _cnt = _cnt + 1 } } forEach allGroups;

	_warnKey = "wfbe_creategroup_gc_warn_" + _sideKey;
	_warnLast = missionNamespace getVariable [_warnKey, -9999];
	if ((time - _warnLast) >= 300) then {
		missionNamespace setVariable [_warnKey, time];
		["WARNING", Format ["Common_CreateGroup.sqf: emergency GC for %1 at %2 groups (source: %3) - reaped %4 empty groups.", str _side, _cnt, _sourceTag, _gcDone]] Call WFBE_CO_FNC_AICOMLog;
	};
};

// --- Create the group ---
_grp = createGroup _side;

if (isNull _grp) then {
	_warnKey = "wfbe_creategroup_null_warn_" + _sideKey;
	_warnLast = missionNamespace getVariable [_warnKey, -9999];
	if ((time - _warnLast) >= 300) then {
		missionNamespace setVariable [_warnKey, time];
		["WARNING", Format ["Common_CreateGroup.sqf: createGroup returned grpNull for %1 (source: %2) - %3 groups on side.", str _side, _sourceTag, _cnt]] Call WFBE_CO_FNC_AICOMLog;
	};
} else {
	_grp setVariable ["wfbe_group_src", _sourceTag, true];
};

_grp
