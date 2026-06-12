// Server-side empty-group garbage collector. A2 has a hard ~144 groups/side cap;
// empty groups are not auto-reclaimed, so leaks accumulate until createGroup returns
// grpNull and AI silently stops spawning. This sweeps zero-living-unit, non-persistent
// groups every 60s, making the cap unreachable in normal play.
//
// Group-cap pre-warning (always-on): logs a WARNING to the RPT whenever a side's
// group count crosses >= 130 (approach) or >= 144 (at cap). Debounced: re-fires only
// after 5 minutes per side per threshold so the RPT is not spammed.
if (!isServer) exitWith {};

Private ["_grp","_cntWest","_cntEast","_cntGuer","_now","_warnInterval","_lastWest130","_lastWest144","_lastEast130","_lastEast144","_lastGuer130","_lastGuer144","_zombieTimeout","_orphanedAt","_uidVal","_zombieUnits","_zombieVehicles","_zombieHQ","_reaped","_auditInterval","_lastAudit","_src","_srcCounts","_srcKey","_srcIdx","_auditSide","_auditCnt","_auditStr","_pair","_isPersistent","_activeTowns","_uniWest","_uniEast","_uniGuer","_auditT0","_auditMs","_auditLines","_auditLine","_auditUniCnt"];

_warnInterval = 300; // 5 minutes between repeated warnings for same side/threshold.

while {!WFBE_GameOver} do {
	sleep 60;

	// --- Empty-group GC sweep ---
	{
		_grp = _x;
		if (!isNull _grp && {!(_grp getVariable ["wfbe_persistent", false])} && {(count (units _grp)) == 0}) then {
			deleteGroup _grp;
		};
	} forEach allGroups;

	// --- Orphaned-team zombie reaper ---
	// Reclaims AI teams whose player disconnected with WFBE_C_AI_TEAMS_JIP_PRESERVE==1
	// and never reconnected within WFBE_C_DISCONNECT_ZOMBIE_TIMEOUT seconds (default 600).
	// Set the param to 0 to disable entirely.
	_zombieTimeout = missionNamespace getVariable ["WFBE_C_DISCONNECT_ZOMBIE_TIMEOUT", 600];
	if (_zombieTimeout > 0) then {
		{
			_grp = _x;
			// A2 OA: the [name, default] form of getVariable is not supported on groups
			// (objects/namespaces only) - it yields nil and the comparison below throws.
			_orphanedAt = _grp getVariable "wfbe_orphaned_at";
			if (isNil "_orphanedAt") then {_orphanedAt = -1};
			if (_orphanedAt >= 0 && {(time - _orphanedAt) >= _zombieTimeout}) then {
				// Confirm the team is still unclaimed (wfbe_uid cleared to nil on disconnect).
				_uidVal = _grp getVariable "wfbe_uid";
				if (isNil "_uidVal") then {
					// Mirror the preserve==0 deletion pattern from Server_OnPlayerDisconnected.sqf,
					// including the explicit side-HQ exclusion (a team member could be crewing the MHQ).
					_zombieHQ       = (side _grp) Call WFBE_CO_FNC_GetSideHQ;
					_zombieUnits    = units _grp;
					_zombieVehicles = [_grp, false] Call GetTeamVehicles;
					_zombieUnits    = (_zombieUnits + _zombieVehicles) - [_zombieHQ];
					_reaped = 0;
					{
						if (!isPlayer _x && !(_x in playableUnits)) then {
							deleteVehicle _x;
							_reaped = _reaped + 1;
						};
					} forEach _zombieUnits;
					_grp setVariable ["wfbe_orphaned_at", nil];
					["INFORMATION", Format ["server_groupsGC.sqf: reaped %1 zombie unit(s) from orphaned team %2 (disconnected %3s ago)", _reaped, _grp, (time - _orphanedAt)]] Call WFBE_CO_FNC_AICOMLog;
				};
			};
		} forEach allGroups;
	};

	// --- Group-cap pre-warning ---
	// Count groups per side (single pass; cheap at 60s cadence).
	_cntWest = 0;
	_cntEast = 0;
	_cntGuer = 0;
	{
		if (side _x == west)       then {_cntWest = _cntWest + 1};
		if (side _x == east)       then {_cntEast = _cntEast + 1};
		if (side _x == resistance) then {_cntGuer = _cntGuer + 1};
	} forEach allGroups;

	_now = time;

	// Helper macro (inlined as code blocks) - warn if count >= threshold and debounce
	// key has either never been set or expired.  Uses missionNamespace so the variable
	// survives for the lifetime of the session.

	// WEST - approach (130)
	if (_cntWest >= 130) then {
		_lastWest130 = missionNamespace getVariable ["wfbe_groupcap_warn_west130", -9999];
		if ((_now - _lastWest130) >= _warnInterval) then {
			missionNamespace setVariable ["wfbe_groupcap_warn_west130", _now];
			["WARNING", Format ["server_groupsGC.sqf: [%1] side at %2/144 groups - approaching cap (>= 130); AI spawns will fail silently at 144.", str west, _cntWest]] Call WFBE_CO_FNC_AICOMLog;
		};
	};
	// WEST - at cap (144)
	if (_cntWest >= 144) then {
		_lastWest144 = missionNamespace getVariable ["wfbe_groupcap_warn_west144", -9999];
		if ((_now - _lastWest144) >= _warnInterval) then {
			missionNamespace setVariable ["wfbe_groupcap_warn_west144", _now];
			["WARNING", Format ["server_groupsGC.sqf: [%1] side at %2/144 groups - AT CAP; createGroup will return grpNull and AI spawns will silently fail.", str west, _cntWest]] Call WFBE_CO_FNC_AICOMLog;
		};
	};

	// EAST - approach (130)
	if (_cntEast >= 130) then {
		_lastEast130 = missionNamespace getVariable ["wfbe_groupcap_warn_east130", -9999];
		if ((_now - _lastEast130) >= _warnInterval) then {
			missionNamespace setVariable ["wfbe_groupcap_warn_east130", _now];
			["WARNING", Format ["server_groupsGC.sqf: [%1] side at %2/144 groups - approaching cap (>= 130); AI spawns will fail silently at 144.", str east, _cntEast]] Call WFBE_CO_FNC_AICOMLog;
		};
	};
	// EAST - at cap (144)
	if (_cntEast >= 144) then {
		_lastEast144 = missionNamespace getVariable ["wfbe_groupcap_warn_east144", -9999];
		if ((_now - _lastEast144) >= _warnInterval) then {
			missionNamespace setVariable ["wfbe_groupcap_warn_east144", _now];
			["WARNING", Format ["server_groupsGC.sqf: [%1] side at %2/144 groups - AT CAP; createGroup will return grpNull and AI spawns will silently fail.", str east, _cntEast]] Call WFBE_CO_FNC_AICOMLog;
		};
	};

	// RESISTANCE - approach (130)
	if (_cntGuer >= 130) then {
		_lastGuer130 = missionNamespace getVariable ["wfbe_groupcap_warn_guer130", -9999];
		if ((_now - _lastGuer130) >= _warnInterval) then {
			missionNamespace setVariable ["wfbe_groupcap_warn_guer130", _now];
			["WARNING", Format ["server_groupsGC.sqf: [%1] side at %2/144 groups - approaching cap (>= 130); AI spawns will fail silently at 144.", str resistance, _cntGuer]] Call WFBE_CO_FNC_AICOMLog;
		};
	};
	// RESISTANCE - at cap (144)
	if (_cntGuer >= 144) then {
		_lastGuer144 = missionNamespace getVariable ["wfbe_groupcap_warn_guer144", -9999];
		if ((_now - _lastGuer144) >= _warnInterval) then {
			missionNamespace setVariable ["wfbe_groupcap_warn_guer144", _now];
			["WARNING", Format ["server_groupsGC.sqf: [%1] side at %2/144 groups - AT CAP; createGroup will return grpNull and AI spawns will silently fail.", str resistance, _cntGuer]] Call WFBE_CO_FNC_AICOMLog;
		};
	};

	// --- Per-side source attribution telemetry (LEVER 1) ---
	// Debounced to once every 5 minutes; always logs (not only near cap).
	_auditInterval = 300;
	_lastAudit = missionNamespace getVariable "wfbe_groupaudit_last";
	if (isNil "_lastAudit") then { _lastAudit = -9999 };
	if ((_now - _lastAudit) >= _auditInterval) then {
		missionNamespace setVariable ["wfbe_groupaudit_last", _now];
		_auditT0 = diag_tickTime;

		// Single allUnits pass: count units per side for audit line + TICK sharing.
		// Stored in missionNamespace so AI_Commander TICK can read them cheaply.
		_uniWest = 0; _uniEast = 0; _uniGuer = 0;
		{
			if (side _x == west)       then { _uniWest = _uniWest + 1 };
			if (side _x == east)       then { _uniEast = _uniEast + 1 };
			if (side _x == resistance) then { _uniGuer = _uniGuer + 1 };
		} forEach allUnits;
		missionNamespace setVariable ["wfbe_units_west", _uniWest];
		missionNamespace setVariable ["wfbe_units_east", _uniEast];
		missionNamespace setVariable ["wfbe_units_guer", _uniGuer];

		// Build per-(side, src) counts in a flat key=value array: [side, src, count, ...]
		// Using a simple parallel-arrays approach to avoid any A3-only constructs.
		_srcCounts = []; // flat: [side0, src0, cnt0, side1, src1, cnt1, ...]

		{
			_auditSide = side _x;
			_src = _x getVariable "wfbe_group_src";
			if (isNil "_src") then { _src = "untagged" };

			// Find existing entry
			_srcIdx = -1;
			_srcKey = 0;
			while { _srcKey < count _srcCounts } do {
				if ((_srcCounts select _srcKey) == _auditSide && { (_srcCounts select (_srcKey + 1)) == _src }) then {
					_srcIdx = _srcKey;
					_srcKey = count _srcCounts; // break
				} else {
					_srcKey = _srcKey + 3;
				};
			};

			if (_srcIdx < 0) then {
				[_srcCounts, _auditSide] call WFBE_CO_FNC_ArrayPush;
				[_srcCounts, _src]       call WFBE_CO_FNC_ArrayPush;
				[_srcCounts, 1]          call WFBE_CO_FNC_ArrayPush;
			} else {
				_srcCounts set [_srcIdx + 2, (_srcCounts select (_srcIdx + 2)) + 1];
			};
		} forEach allGroups;

		// Collect per-side log strings into an array; emit after auditMs is known.
		// _auditLines is a flat array of strings (one per side).
		_auditLines = [];
		_activeTowns = missionNamespace getVariable "wfbe_active_town_count";
		if (isNil "_activeTowns") then { _activeTowns = 0 };

		{
			_auditSide = _x;
			_auditCnt  = switch (_auditSide) do {
				case west:       { _cntWest };
				case east:       { _cntEast };
				case resistance: { _cntGuer };
				default          { 0 };
			};

			// Build breakdown string for this side
			_auditStr = "";
			_srcKey = 0;
			while { _srcKey < count _srcCounts } do {
				if ((_srcCounts select _srcKey) == _auditSide) then {
					if (_auditStr != "") then { _auditStr = _auditStr + " " };
					_auditStr = _auditStr + Format ["%1=%2", _srcCounts select (_srcKey + 1), _srcCounts select (_srcKey + 2)];
				};
				_srcKey = _srcKey + 3;
			};
			if (_auditStr == "") then { _auditStr = "(none)" };

			//--- Resolve unit count for this side from the single allUnits pass above.
			_auditUniCnt = switch (_auditSide) do {
				case west:       { _uniWest };
				case east:       { _uniEast };
				case resistance: { _uniGuer };
				default          { 0 };
			};

			// Build the log string (auditMs appended below when known).
			_auditLine = Format ["server_groupsGC.sqf: group audit [%1] %2/144: %3 srvFps=%4 activeTowns=%5 units=%6",
				str _auditSide, _auditCnt, _auditStr, round diag_fps, _activeTowns, _auditUniCnt];
			[_auditLines, _auditLine] call WFBE_CO_FNC_ArrayPush;
		} forEach [west, east, resistance];

		// Compute sweep cost; emit all three per-side lines with auditMs appended.
		_auditMs = round ((diag_tickTime - _auditT0) * 1000);
		{
			["INFORMATION", _x + " auditMs=" + str _auditMs] Call WFBE_CO_FNC_AICOMLog;
		} forEach _auditLines;
	};
};

