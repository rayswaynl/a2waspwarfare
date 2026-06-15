// Server-side empty-group garbage collector. A2 has a hard ~144 groups/side cap;
// empty groups are not auto-reclaimed, so leaks accumulate until createGroup returns
// grpNull and AI silently stops spawning. This sweeps zero-living-unit, non-persistent
// groups every 60s, making the cap unreachable in normal play.
//
// Group-cap pre-warning (always-on): logs a WARNING to the RPT whenever a side's
// group count crosses >= 130 (approach) or >= 144 (at cap). Debounced: re-fires only
// after 5 minutes per side per threshold so the RPT is not spammed.
if (!isServer) exitWith {};

Private ["_grp","_cntWest","_cntEast","_cntGuer","_now","_warnInterval","_lastWest130","_lastWest144","_lastEast130","_lastEast144","_lastGuer130","_lastGuer144","_zombieTimeout","_orphanedAt","_uidVal","_zombieUnits","_zombieVehicles","_zombieHQ","_reaped","_auditInterval","_lastAudit","_src","_srcCounts","_srcKey","_srcIdx","_auditSide","_auditCnt","_auditStr","_pair","_isPersistent","_activeTowns","_uniWest","_uniEast","_uniGuer","_auditT0","_auditMs","_auditLines","_auditLine","_auditUniCnt","_emptyW","_emptyE","_emptyG","_persEmptyW","_persEmptyE","_persEmptyG","_auditN","_every","_gcReaped","_gcEmptyFound","_guerMax","_guerPct","_guerSoftThreshold","_lastGuerSoft","_leakW","_leakE","_leakG","_leakSamples","_leakStr","_uc","_lastUntagLeak"];

_warnInterval = 300; // 5 minutes between repeated warnings for same side/threshold.
_auditN = 0; // D2 (claude-gaming 2026-06-14): counts elapsed 5-min audit windows; the expensive classification+dump fires only every WFBE_C_GROUPAUDIT_EVERY-th window. Husk-reap GC below is untouched and runs every 60s cycle.

while {!WFBE_GameOver} do {
	sleep 60;

	// --- Empty-group GC sweep ---
	// GCSTAT counters (claude-gaming 2026-06-15): _gcEmptyFound = all zero-unit groups seen this
	// pass (incl. persistent, which are NOT reaped); _gcReaped = non-persistent empties deleted.
	_gcReaped = 0; _gcEmptyFound = 0;
	{
		_grp = _x;
		if (!isNull _grp && {(count (units _grp)) == 0}) then {
			_gcEmptyFound = _gcEmptyFound + 1;
			if (!(_grp getVariable ["wfbe_persistent", false])) then {
				deleteGroup _grp;
				_gcReaped = _gcReaped + 1;
			};
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

	// --- GCSTAT (claude-gaming 2026-06-15): consolidated per-pass GC summary on the 60s sweep
	// cadence. groups reaped THIS pass (non-persistent empties), empties found (incl. persistent),
	// and current per-side group counts incl. GUER. Single cheap diag_log; all values already in
	// hand (counters from the sweep above, per-side counts from the cap-warning pass). t = round min.
	diag_log ("GCSTAT|v1|reaped=" + str _gcReaped + "|emptyFound=" + str _gcEmptyFound + "|west=" + str _cntWest + "|east=" + str _cntEast + "|guer=" + str _cntGuer + "|t=" + str (round (time / 60)));

	// --- GUER soft-cap monitor (claude-gaming 2026-06-15) ---
	// GUER's real ceiling is the SOFT cap WFBE_C_GUER_GROUPS_MAX (=80, raised 60->80), NOT the 144
	// engine cap. At the soft cap, server_town_ai.sqf:62 DEFERS new resistance garrisons, so town
	// defense silently degrades long before the 130/144 engine warning below would ever fire for GUER.
	// GUERCAP feeds the dashboard's GUER gauge (60s cadence); the debounced WARNING is emitted with the
	// other cap warnings further down. Recompute the cap each pass so a live param change is honoured.
	_guerMax = missionNamespace getVariable ["WFBE_C_GUER_GROUPS_MAX", 80];
	if (_guerMax < 1) then { _guerMax = 1 };
	_guerPct = round ((_cntGuer / _guerMax) * 100);
	_guerSoftThreshold = round (_guerMax * 0.9);
	diag_log ("GUERCAP|v1|count=" + str _cntGuer + "|max=" + str _guerMax + "|pct=" + str _guerPct + "|t=" + str (round (time / 60)));

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
	// RESISTANCE - SOFT cap (>= 90% of WFBE_C_GUER_GROUPS_MAX). The operationally meaningful GUER
	// threshold: at the soft cap, server_town_ai.sqf stops spawning new garrisons and town defense
	// degrades. Fires well before the 130 engine-approach warning (the soft cap is 60 by default).
	if (_cntGuer >= _guerSoftThreshold) then {
		_lastGuerSoft = missionNamespace getVariable ["wfbe_groupcap_warn_guersoft", -9999];
		if ((_now - _lastGuerSoft) >= _warnInterval) then {
			missionNamespace setVariable ["wfbe_groupcap_warn_guersoft", _now];
			["WARNING", Format ["server_groupsGC.sqf: [%1] at %2/%3 groups (%4%5) - approaching the GUER soft cap; server_town_ai.sqf will DEFER new town garrisons at %3, degrading resistance town defense.", str resistance, _cntGuer, _guerMax, _guerPct, "%"]] Call WFBE_CO_FNC_AICOMLog;
		};
	};

	// --- Per-side source attribution telemetry (LEVER 1) ---
	// Debounced to once every 5 minutes; always logs (not only near cap).
	_auditInterval = 300;
	_lastAudit = missionNamespace getVariable "wfbe_groupaudit_last";
	if (isNil "_lastAudit") then { _lastAudit = -9999 };
	if ((_now - _lastAudit) >= _auditInterval) then {
		missionNamespace setVariable ["wfbe_groupaudit_last", _now];
		// --- D2 server-FPS throttle (claude-gaming 2026-06-14) ---
		// The 5-min WINDOW bookkeeping above (last-audit timestamp + window counter) keeps
		// advancing every window, but the EXPENSIVE classification + per-faction dump below
		// (auditMs ~2100ms on 276 groups) only runs every WFBE_C_GROUPAUDIT_EVERY-th window.
		// The husk-reap GC, zombie-reap and cap-warning all ran earlier in this 60s cycle,
		// OUTSIDE this branch, so they are completely unaffected by this throttle.
		_auditN = _auditN + 1;
		_every = missionNamespace getVariable ["WFBE_C_GROUPAUDIT_EVERY", 5];
		if (_every < 1) then { _every = 1 };
		if ((_auditN mod _every) == 0) then {
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
		_emptyW = 0; _emptyE = 0; _emptyG = 0; _persEmptyW = 0; _persEmptyE = 0; _persEmptyG = 0; //--- EMPTYGRP tracking (Ray)
		_leakW = 0; _leakE = 0; _leakG = 0; _leakSamples = []; //--- UNTAGLEAK tracking: non-empty untagged (wrapper-bypassed) groups
		_srcCounts = []; // flat: [side0, src0, cnt0, side1, src1, cnt1, ...]

		{
			_auditSide = side _x;
			_uc = count units _x;
			if (_uc == 0) then {
				private "_pe"; _pe = _x getVariable ["wfbe_persistent", false];
				switch (_auditSide) do {
					case west:       { _emptyW = _emptyW + 1; if (_pe) then {_persEmptyW = _persEmptyW + 1} };
					case east:       { _emptyE = _emptyE + 1; if (_pe) then {_persEmptyE = _persEmptyE + 1} };
					case resistance: { _emptyG = _emptyG + 1; if (_pe) then {_persEmptyG = _persEmptyG + 1} };
					default {};
				};
			};
			_src = _x getVariable "wfbe_group_src";
			if (isNil "_src") then {
				_src = "untagged";
				//--- UNTAGLEAK: a NON-empty untagged group is a real leak candidate. Editor player-slots are
				//--- tagged 'editor-player-slot' and every Common_CreateGroup spawn is tagged, so an untagged
				//--- group WITH live units on a combat side is a raw createGroup that escaped the wrapper.
				if (_uc > 0 && {(_auditSide == west) || (_auditSide == east) || (_auditSide == resistance)}) then {
					switch (_auditSide) do {
						case west:       { _leakW = _leakW + 1 };
						case east:       { _leakE = _leakE + 1 };
						case resistance: { _leakG = _leakG + 1 };
						default {};
					};
					if (count _leakSamples < 6) then {
						[_leakSamples, Format ["%1:%2u", _x, _uc]] call WFBE_CO_FNC_ArrayPush;
					};
				};
			};

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

		//--- Delegation split: prove the HC offload is alive. One extra allUnits pass (~300 units, trivial).
		diag_log (Format ["EMPTYGRP|v1|west=%1|east=%2|guer=%3|persW=%4|persE=%5|persG=%6|t=%7", _emptyW, _emptyE, _emptyG, _persEmptyW, _persEmptyE, _persEmptyG, round (time / 60)]); //--- EMPTYGRP tracking (Ray)

		//--- UNTAGLEAK (claude-gaming 2026-06-15): non-empty untagged groups on a combat side = a group
		//--- that bypassed the CreateGroup wrapper. With editor slots + all dynamic spawns now tagged,
		//--- this count should sit at 0; a sustained non-zero is a real dynamic-group leak. Samples list
		//--- up to 6 "group:Nu" ids. WARNING (debounced 5 min, warmup 600s) when any are seen.
		_leakStr = "";
		{ if (_leakStr != "") then { _leakStr = _leakStr + "," }; _leakStr = _leakStr + _x } forEach _leakSamples;
		if (_leakStr == "") then { _leakStr = "none" };
		diag_log (Format ["UNTAGLEAK|v1|west=%1|east=%2|guer=%3|samples=%4|t=%5", _leakW, _leakE, _leakG, _leakStr, round (time / 60)]);
		if ((_leakW + _leakE + _leakG) > 0 && {time > 600}) then {
			_lastUntagLeak = missionNamespace getVariable ["wfbe_untagleak_warn_last", -9999];
			if ((_now - _lastUntagLeak) >= _warnInterval) then {
				missionNamespace setVariable ["wfbe_untagleak_warn_last", _now];
				["WARNING", Format ["server_groupsGC.sqf: UNTAGGED-LEAK - %1 non-empty untagged group(s) bypassed the CreateGroup wrapper (W%2/E%3/G%4): %5", (_leakW + _leakE + _leakG), _leakW, _leakE, _leakG, _leakStr]] Call WFBE_CO_FNC_AICOMLog;
			};
		};
		_delegTotal = count allUnits;
		_delegLocal = {local _x} count allUnits;
		_delegRemote = _delegTotal - _delegLocal;
		_delegPct = 0;
		if (_delegTotal > 0) then {_delegPct = round ((_delegRemote / _delegTotal) * 100)};
		diag_log ("DELEGSTAT|v1|total=" + str _delegTotal + "|srvLocal=" + str _delegLocal + "|remote=" + str _delegRemote + "|remotePct=" + str _delegPct + "|t=" + str (round (time / 60)));
		if ((missionNamespace getVariable ["WFBE_C_AI_DELEGATION", 0]) == 2 && time > 1200 && _delegRemote == 0) then {
			["WARNING", "server_groupsGC.sqf: DELEGATION-DEAD - delegation=2 but 0 HC-owned units at minute " + str (round (time / 60))] Call WFBE_CO_FNC_AICOMLog;
		};

		//--- TOWN CONTROL snapshot (front line). Bounded by town count (~16), once / 5 min.
		//--- sideID: WEST=0 EAST=1 GUER=2 (Init_CommonConstants). No-default getVariable + isNil
		//--- guard (towns are Locations; default-form getVariable is fine but stay explicit).
		_tW = 0; _tE = 0; _tG = 0;
		{
			_tsid = _x getVariable "sideID";
			if (isNil "_tsid") then { _tsid = 2 };
			if (_tsid == 0) then { _tW = _tW + 1 };
			if (_tsid == 1) then { _tE = _tE + 1 };
			if (_tsid == 2) then { _tG = _tG + 1 };
		} forEach towns;
		diag_log ("TOWNSTAT|v1|west=" + str _tW + "|east=" + str _tE + "|guer=" + str _tG + "|total=" + str (count towns) + "|t=" + str (round (time / 60)));

		//--- ORDER OF BATTLE: crewed vehicles by class per side. Bounded by vehicle count,
		//--- once / 5 min. Slots: 0 armor, 1 car, 2 heli, 3 jet. Personnel = unit count above.
		_obW = [0, 0, 0, 0]; _obE = [0, 0, 0, 0];
		{
			if (alive _x && { (count crew _x) > 0 }) then {
				_vside = side ((crew _x) select 0);
				_slot = -1;
				if (_x isKindOf "Helicopter") then { _slot = 2 } else {
					if (_x isKindOf "Plane") then { _slot = 3 } else {
						if (_x isKindOf "Tank") then { _slot = 0 } else {
							if (_x isKindOf "Car") then { _slot = 1 }
						}
					}
				};
				if (_slot >= 0) then {
					if (_vside == west) then { _obW set [_slot, (_obW select _slot) + 1] };
					if (_vside == east) then { _obE set [_slot, (_obE select _slot) + 1] };
				};
			};
		} forEach vehicles;
		diag_log ("ORBATSTAT|v1|WEST|armor=" + str (_obW select 0) + "|car=" + str (_obW select 1) + "|heli=" + str (_obW select 2) + "|jet=" + str (_obW select 3) + "|personnel=" + str _uniWest + "|t=" + str (round (time / 60)));
		diag_log ("ORBATSTAT|v1|EAST|armor=" + str (_obE select 0) + "|car=" + str (_obE select 1) + "|heli=" + str (_obE select 2) + "|jet=" + str (_obE select 3) + "|personnel=" + str _uniEast + "|t=" + str (round (time / 60)));

		// Compute sweep cost; emit all three per-side lines with auditMs appended.
		_auditMs = round ((diag_tickTime - _auditT0) * 1000);
		{
			["INFORMATION", _x + " auditMs=" + str _auditMs] Call WFBE_CO_FNC_AICOMLog;
		} forEach _auditLines;
		}; // --- end D2 modulo gate (WFBE_C_GROUPAUDIT_EVERY) ---
	};
};

