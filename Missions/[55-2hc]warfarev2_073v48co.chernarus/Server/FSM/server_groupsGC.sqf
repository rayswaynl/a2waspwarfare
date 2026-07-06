// Server-side empty-group garbage collector. A2 has a hard ~144 groups/side cap;
// empty groups are not auto-reclaimed, so leaks accumulate until createGroup returns
// grpNull and AI silently stops spawning. This sweeps zero-living-unit, non-persistent
// groups every 60s, making the cap unreachable in normal play.
//
// Group-cap pre-warning (always-on): logs a WARNING to the RPT whenever a side's
// group count crosses >= 130 (approach) or >= 144 (at cap). Debounced: re-fires only
// after 5 minutes per side per threshold so the RPT is not spammed.
if (!isServer) exitWith {};

Private ["_grp","_cntWest","_cntEast","_cntGuer","_now","_warnInterval","_lastWest130","_lastWest144","_lastEast130","_lastEast144","_lastGuer130","_lastGuer144","_zombieTimeout","_orphanedAt","_uidVal","_zombieUnits","_zombieVehicles","_zombieHQ","_reaped","_auditInterval","_lastAudit","_src","_srcCounts","_srcKeys","_srcKey","_srcIdx","_auditSide","_auditCnt","_auditStr","_pair","_isPersistent","_activeTowns","_uniWest","_uniEast","_uniGuer","_auditT0","_auditMs","_auditLines","_auditLine","_auditUniCnt","_emptyW","_emptyE","_emptyG","_persEmptyW","_persEmptyE","_persEmptyG","_auditN","_every","_gcReaped","_gcEmptyFound","_guerMax","_guerPct","_guerSoftThreshold","_lastGuerSoft","_leakW","_leakE","_leakG","_leakSamples","_leakStr","_uc","_lastUntagLeak","_untW","_untE","_untG","_gsrc","_baseSide","_baseEnable","_baseRange","_baseTimeout","_baseIdleSpeed","_basePlayerGuard","_basePlayers","_basePcN","_baseHcN","_baseHQ","_baseHQPos","_baseSideID","_baseLogik","_baseTeams","_baseCap","_baseFounded","_baseCandGrps","_baseG","_baseIsTownTeam","_baseIsPers","_baseLdr","_baseSeen","_baseDmgNow","_baseDmgPrev","_baseInCombat","_baseEnemyNear","_basePlayerNear","_baseFrontPos","_baseUncap","_baseFrontTown","_baseSeq","_baseVeh","_baseVcrew","_baseVside","_baseReadopted","_baseDeletedAir","_baseRetasked","_contestedTowns"];

_warnInterval = 300; // 5 minutes between repeated warnings for same side/threshold.
_auditN = 0; // D2 (claude-gaming 2026-06-14): counts elapsed 5-min audit windows; the expensive classification+dump fires only every WFBE_C_GROUPAUDIT_EVERY-th window. Husk-reap GC below is untouched and runs every 60s cycle.

while {!WFBE_GameOver} do {
	sleep 60;

	// --- Empty-group GC sweep ---
	// GCSTAT counters (claude-gaming 2026-06-15): _gcEmptyFound = all zero-unit groups seen this
	// pass (incl. persistent, which are NOT reaped); _gcReaped = non-persistent empties deleted.
	_gcReaped = 0; _gcEmptyFound = 0;
	//--- cmdcon41-w3c: TWO-PASS collect-then-delete. The old single pass called deleteGroup INLINE
	//--- while iterating allGroups; A2 OA 1.64 leaves forEach behaviour UNDEFINED when the collection
	//--- is mutated mid-iteration (same trap already avoided in Common_CreateGroup.sqf:36-54), which
	//--- can skip the element after each reap -> empties survive an extra 60s sweep (a contributor to
	//--- the observed transient empty-group pile-up). Collect candidates first, delete in a 2nd pass.
	private "_gcCands"; _gcCands = [];
	{
		_grp = _x;
		if (!isNull _grp && {(count (units _grp)) == 0}) then {
			_gcEmptyFound = _gcEmptyFound + 1;
			// A2 OA: the [name,default] getVariable form is unreliable on GROUP objects (yields nil, not the
			// default) - same trap fixed in the zombie-reaper at line ~46. Use single-arg + isNil guard.
			private "_isPers"; _isPers = _grp getVariable "wfbe_persistent";
			if (isNil "_isPers") then {_isPers = false};
			if (!_isPers) then {
				_gcCands set [count _gcCands, _grp]; //--- defer delete out of the allGroups iteration
			};
		};
	} forEach allGroups;
	{
		deleteGroup _x;
		_gcReaped = _gcReaped + 1;
	} forEach _gcCands;

	// --- B61 (Ray 2026-06-21) BASE-GC / RE-ADOPT pass ---
	// The legacy GC above reaps ONLY empty groups. The BASE fills with units the commander neither
	// counts, re-tasks, nor reaps: (i) untracked NON-EMPTY side groups loitering at their own HQ, and
	// (ii) crewed-idle helis/armor whose Server_HandleEmptyVehicle delete timer is reset while the crew
	// is alive (immortal hulls). This per-side pass runs on the SAME 60s cadence. A candidate must sit
	// CONTINUOUSLY idle-at-base for WFBE_C_BASEGC_IDLE_TIMEOUT before we ACT (first-seen stamp reset on
	// leave/wake). ACTION: prefer RE-ADOPT untracked INFANTRY into the commander (re-task + register +
	// count); DELETE only idle crewed AIR + abandoned hulls (mirrors the fly-off/deleteVehicle pattern in
	// Common_RunCommanderTeam.sqf:318-320). NEVER deleteVehicle infantry. The combat guard + idle-timer
	// ALWAYS apply; the player-proximity guard is tunable (default 0 = does NOT block cleanup).
	_baseEnable = missionNamespace getVariable ["WFBE_C_BASEGC_ENABLE", 1];
	if (_baseEnable > 0) then {
		_baseRange       = missionNamespace getVariable ["WFBE_C_BASEGC_RANGE",        800];
		_baseTimeout     = missionNamespace getVariable ["WFBE_C_BASEGC_IDLE_TIMEOUT", 300];
		_baseIdleSpeed   = missionNamespace getVariable ["WFBE_C_BASEGC_IDLE_SPEED",   5];
		_basePlayerGuard = missionNamespace getVariable ["WFBE_C_BASEGC_PLAYER_GUARD", 0];
		_baseReadopted = 0; _baseRetasked = 0; _baseDeletedAir = 0;
		//--- Build one live-player snapshot for the BASE-GC pass; reuse it for cap math and optional guards.
		_basePcN = 0;
		_basePlayers = [];
		{
			if (isPlayer _x) then {
				_basePcN = _basePcN + 1;
				if (_basePlayerGuard > 0 && {alive _x}) then {_basePlayers set [count _basePlayers, _x]};
			};
		} forEach allUnits;
		_baseHcN = {!isNull _x && {!isNull leader _x} && {alive leader _x}} count (missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []]);
		_basePcN = (_basePcN - _baseHcN) max 0;

		{
			_baseSide = _x;
			_baseHQ   = _baseSide Call WFBE_CO_FNC_GetSideHQ;
			//--- getPos on a non-object throws in A2 OA: always !isNull guard before getPos.
			if (!isNull _baseHQ) then {
				_baseHQPos = getPos _baseHQ;
				_baseSideID = _baseSide Call WFBE_CO_FNC_GetSideID;
				_baseLogik  = _baseSide Call WFBE_CO_FNC_GetSideLogic;

				//--- Live side TEAM CAP (mirror AI_Commander_Teams' PC-bucket base). Re-adopt only while
				//--- UNDER cap; at/over cap we still re-task the group toward the front (never idle), but do
				//--- NOT register/count it (would bloat the side past its budget).
				_baseFounded = 0;
				_baseTeams = [];
				if (!isNull _baseLogik) then {
					_baseTeams = _baseLogik getVariable "wfbe_teams";
					if (isNil "_baseTeams") then {_baseTeams = []};
					{
						if (!isNull _x) then {
							if (([_x, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool) || {[_x, "wfbe_aicom_founded", false] Call WFBE_CO_FNC_GroupGetBool}) then {
								_baseFounded = _baseFounded + 1;
							};
						};
					} forEach _baseTeams;
				};
				_baseCap = switch (true) do {
					case (_basePcN <= 2): {missionNamespace getVariable ["WFBE_C_AICOM_TEAMS_PC_LOW",  15]};
					case (_basePcN <= 5): {missionNamespace getVariable ["WFBE_C_AICOM_TEAMS_PC_MID",  5]};
					case (_basePcN <= 9): {missionNamespace getVariable ["WFBE_C_AICOM_TEAMS_PC_HIGH", 3]};
					default              {missionNamespace getVariable ["WFBE_C_AICOM_TEAMS_PC_FULL", 2]};
				};
				//--- cmdcon42-k: the re-adoption ceiling honours the same team-target delta+floor the founding
				//--- loop applies (Ray: -3 teams/commander) so GC cannot re-adopt teams the founding lane retires.
				_baseCap = (_baseCap + (missionNamespace getVariable ["WFBE_C_AICOM_TEAMS_DELTA", -1])) max (missionNamespace getVariable ["WFBE_C_AICOM_TEAMS_FLOOR", 3]);

				//--- Nearest uncaptured town to the HQ = the front objective for re-task (same OA-safe
				//--- sideID filter as AI_Commander_AssignTowns:32). Fallback: enemy HQ direction is implicit
				//--- in "nearest not-ours"; if NOTHING is uncaptured we fall back to the HQ pos (harmless MOVE).
				_baseUncap = [];
				{ if ((_x getVariable "sideID") != _baseSideID) then {_baseUncap set [count _baseUncap, _x]} } forEach towns;
				_baseFrontTown = objNull;
				if (count _baseUncap > 0) then {_baseFrontTown = [_baseHQ, _baseUncap] Call WFBE_CO_FNC_GetClosestEntity};
				_baseFrontPos = _baseHQPos;
				if (!isNull _baseFrontTown) then {_baseFrontPos = getPos _baseFrontTown};

				// ============ (i) UNTRACKED NON-EMPTY GROUPS AT BASE ============
				{
					_baseG = _x;
					//--- B66 (Ray 2026-06-21): NEVER re-adopt an HC-local / remote group from the server.
					//--- deleteVehicle + most setVariable retasking are locality-sensitive in A2 OA, and an
					//--- HC-owned patrol/team re-adopted here would be mis-counted and its units orphaned.
					//--- Gate the whole re-adopt block on the group's leader being SERVER-LOCAL.
					if (!isNull _baseG && {(side _baseG) == _baseSide} && {(count (units _baseG)) > 0} && {local (leader _baseG)}) then {
						_baseLdr = leader _baseG;
						if (!isNull _baseLdr && {alive _baseLdr} && {!isPlayer _baseLdr}) then {
							//--- within range of own HQ?
							if ((_baseLdr distance _baseHQ) <= _baseRange) then {
								//--- NOT commander-owned + NOT town/patrol-owned = "untracked". wfbe_persistent covers
								//--- town garrisons AND founded server-local teams (skip wfbe_persistent); wfbe_aicom_hc /
								//--- wfbe_aicom_founded mark commanded teams. GroupGetBool = A2-safe bool read on a GROUP.
								_baseIsPers     = [_baseG, "wfbe_persistent",    false] Call WFBE_CO_FNC_GroupGetBool;
								_baseIsTownTeam = ([_baseG, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool) || {[_baseG, "wfbe_aicom_founded", false] Call WFBE_CO_FNC_GroupGetBool};
								//--- B66 (Ray 2026-06-21): also skip side-patrol groups. Common_RunSidePatrol now
								//--- broadcasts WFBE_SidePatrol (broadcast=true) so the server can see it here; a patrol
								//--- transiting/home at base must never be re-adopted/re-tasked by the BASE-GC.
								private "_baseIsPatrol"; _baseIsPatrol = [_baseG, "WFBE_SidePatrol", false] Call WFBE_CO_FNC_GroupGetBool;
								if (!_baseIsPers && {!_baseIsTownTeam} && {!_baseIsPatrol}) then {
									//--- COMBAT GUARD (always): skip if the group is fighting OR took damage / fired
									//--- since the last pass. We detect "fired/took damage in last ~30s" via a stamped
									//--- damage sum: any rise vs the stored value (or an active COMBAT behaviour / enemy
									//--- within idle-speed* sense range) means it is engaged -> reset the idle stamp.
									_baseInCombat = (behaviour _baseLdr == "COMBAT");
									//--- enemy = any near entity whose side is NEITHER ours NOR civilian (explicit side
									//--- compare, same A2-safe idiom as Common_AICOMServiceTick.sqf:95 - no getFriend).
									_baseEnemyNear = {alive _x && {(side _x) != _baseSide} && {(side _x) != civilian}} count ((getPos _baseLdr) nearEntities [["Man","LandVehicle","Air"], 300]);
									_baseDmgNow = 0; { _baseDmgNow = _baseDmgNow + (damage _x) } forEach (units _baseG);
									_baseDmgPrev = _baseG getVariable "wfbe_basegc_dmg";
									if (isNil "_baseDmgPrev") then {_baseDmgPrev = _baseDmgNow};
									_baseG setVariable ["wfbe_basegc_dmg", _baseDmgNow];

									//--- PLAYER-PROXIMITY guard (tunable; 0 = does NOT block).
									_basePlayerNear = false;
									if (_basePlayerGuard > 0) then {
										{ if ((_x distance _baseLdr) <= _basePlayerGuard) exitWith {_basePlayerNear = true} } forEach _basePlayers;
									};

									if (_baseInCombat || {_baseEnemyNear > 0} || {_baseDmgNow > _baseDmgPrev} || {_basePlayerNear}) then {
										//--- engaged / woke / damaged -> reset the first-seen stamp; do not act this pass.
										_baseG setVariable ["wfbe_basegc_at", nil];
									} else {
										//--- idle-at-base: stamp first-seen, only ACT after the continuous timeout.
										_baseSeen = _baseG getVariable "wfbe_basegc_at";
										if (isNil "_baseSeen") then {
											_baseG setVariable ["wfbe_basegc_at", time];
										} else {
											if ((time - _baseSeen) >= _baseTimeout) then {
												//--- RE-TASK toward the front (always; never leave it idle).
												_baseSeq = (([_baseG, "wfbe_aicom_order", [-1]] Call WFBE_CO_FNC_GroupGetBool) select 0) + 1;
												_baseG setVariable ["wfbe_aicom_order", [_baseSeq, "towns-target", _baseFrontPos], true];
												//--- RE-ADOPT into the commander only while UNDER the side cap (else just re-task).
												if (!isNull _baseLogik && {_baseFounded < _baseCap} && {!(_baseG in _baseTeams)}) then {
													_baseG setVariable ["wfbe_aicom_founded", true];
													_baseG setVariable ["wfbe_persistent", true];
													_baseG setVariable ["wfbe_side", _baseSide];
													//--- B62 (Ray 2026-06-21): a re-adopted team must also carry a teammode + a VALID
													//--- teamtype, or it cannot refill. AI_Commander_Produce skips production when
													//--- wfbe_teamtype < 0 (default -1) or >= count templates (Produce.sqf:60,64-65); template
													//--- index 0 (the basic rifle squad) is ALWAYS present, so it is the safe always-buildable
													//--- value. wfbe_teammode "towns" lets AI_Commander_Strategy re-dispatch it like a normal
													//--- town team (Strategy/AssignTowns default-read it as "towns").
													_baseG setVariable ["wfbe_teammode", "towns"];
													_baseG setVariable ["wfbe_teamtype", 0];
													_baseLogik setVariable ["wfbe_teams", _baseTeams + [_baseG], true];
													_baseTeams = _baseTeams + [_baseG];
													_baseFounded = _baseFounded + 1;
													_baseReadopted = _baseReadopted + 1;
													["INFORMATION", Format ["server_groupsGC.sqf: B61 BASE-GC re-adopted untracked %1 group %2 into the commander (founded->%3/%4), re-tasked to front.", str _baseSide, _baseG, _baseFounded, _baseCap]] Call WFBE_CO_FNC_AICOMLog;
												} else {
													_baseRetasked = _baseRetasked + 1;
												};
												//--- clear the stamp so it is re-evaluated fresh after it moves out.
												_baseG setVariable ["wfbe_basegc_at", nil];
											};
										};
									};
								};
							} else {
								//--- left the base radius -> clear any stale stamp.
								if (!isNil {_baseG getVariable "wfbe_basegc_at"}) then {_baseG setVariable ["wfbe_basegc_at", nil]};
							};
						};
					};
				} forEach allGroups;

				// ============ (ii) IDLE CREWED HELI/ARMOR AT BASE (delete only) ============
				//--- These hulls keep crew alive so Server_HandleEmptyVehicle never reaps them; they idle at
				//--- base forever. DELETE (not re-adopt) idle crewed AIR + immobile armor, mirroring the
				//--- fly-off + deleteVehicle pattern in Common_RunCommanderTeam.sqf:318-320 (crew first, then hull).
				{
					_baseVeh = _x;
					//--- B66 (Ray 2026-06-21): deleteVehicle is locality-sensitive in A2 OA. Only delete a
					//--- hull the SERVER owns; never reap a remote/HC-local vehicle (the delete would either
					//--- no-op or desync). Gate the whole idle-hull delete pass on the hull being server-local.
					if (!isNull _baseVeh && {local _baseVeh} && {alive _baseVeh} && {(_baseVeh isKindOf "Air") || {_baseVeh isKindOf "Tank"} || {_baseVeh isKindOf "APC"}}) then {
						_baseVcrew = crew _baseVeh;
						if (count _baseVcrew > 0) then {
							_baseVside = side ((_baseVcrew select 0));
							//--- OWNERSHIP GUARD: never touch a hull whose crew belongs to a COMMANDER or TOWN/patrol
							//--- group (a just-produced founded armor/air team idling at base, or a garrison vehicle).
							//--- Only genuinely UNTRACKED crewed hulls are reapable. GroupGetBool = A2-safe on a GROUP.
							private ["_baseVgrp","_baseVowned"];
							_baseVgrp = group (_baseVcrew select 0);
							_baseVowned = ([_baseVgrp, "wfbe_persistent", false] Call WFBE_CO_FNC_GroupGetBool) || {[_baseVgrp, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool} || {[_baseVgrp, "wfbe_aicom_founded", false] Call WFBE_CO_FNC_GroupGetBool};
							//--- own side, idle (speed < threshold OR immobile hull), within base radius, no player aboard.
							private ["_baseHasPlayer"];
							_baseHasPlayer = false;
							{ if (isPlayer _x) exitWith {_baseHasPlayer = true} } forEach _baseVcrew;
							if (_baseVside == _baseSide && {!_baseHasPlayer} && {!_baseVowned} && {(_baseVeh distance _baseHQ) <= _baseRange} && {((abs (speed _baseVeh)) < _baseIdleSpeed) || {!canMove _baseVeh}}) then {
								//--- COMBAT GUARD (always): skip if the crew is fighting OR the hull took damage since
								//--- last pass OR enemies are near.
								_baseLdr = _baseVcrew select 0;
								_baseInCombat  = (behaviour _baseLdr == "COMBAT");
								_baseEnemyNear = {alive _x && {(side _x) != _baseSide} && {(side _x) != civilian}} count ((getPos _baseVeh) nearEntities [["Man","LandVehicle","Air"], 300]);
								_baseDmgNow  = damage _baseVeh;
								_baseDmgPrev = _baseVeh getVariable "wfbe_basegc_dmg";
								if (isNil "_baseDmgPrev") then {_baseDmgPrev = _baseDmgNow};
								_baseVeh setVariable ["wfbe_basegc_dmg", _baseDmgNow];

								_basePlayerNear = false;
								if (_basePlayerGuard > 0) then {
									{ if ((_x distance _baseVeh) <= _basePlayerGuard) exitWith {_basePlayerNear = true} } forEach _basePlayers;
								};

								if (_baseInCombat || {_baseEnemyNear > 0} || {_baseDmgNow > _baseDmgPrev} || {_basePlayerNear}) then {
									_baseVeh setVariable ["wfbe_basegc_at", nil];
								} else {
									_baseSeen = _baseVeh getVariable "wfbe_basegc_at";
									if (isNil "_baseSeen") then {
										_baseVeh setVariable ["wfbe_basegc_at", time];
									} else {
										if ((time - _baseSeen) >= _baseTimeout) then {
											//--- DELETE: crew first, then hull (mirror Common_RunCommanderTeam.sqf:318-320).
											{ if (!isPlayer _x) then {deleteVehicle _x} } forEach _baseVcrew;
											deleteVehicle _baseVeh;
											_baseDeletedAir = _baseDeletedAir + 1;
											["INFORMATION", Format ["server_groupsGC.sqf: B61 BASE-GC deleted idle crewed %1 hull at base (%2).", str _baseSide, _baseVeh]] Call WFBE_CO_FNC_AICOMLog;
										};
									};
								};
							} else {
								//--- moved / left base / boarded by player -> clear stamp.
								if (!isNil {_baseVeh getVariable "wfbe_basegc_at"}) then {_baseVeh setVariable ["wfbe_basegc_at", nil]};
							};
						};
					} else {
						if (!isNull _baseVeh && {!local _baseVeh} && {alive _baseVeh} && {(_baseVeh isKindOf "Air") || {_baseVeh isKindOf "Tank"} || {_baseVeh isKindOf "APC"}}) then {
							//--- locality may transfer back later; restart the idle timer on the next server-local pass.
							if (!isNil {_baseVeh getVariable "wfbe_basegc_at"}) then {_baseVeh setVariable ["wfbe_basegc_at", nil, false]};
						};
					};
				} forEach vehicles;
			};
		} forEach [west, east, resistance];

		if ((_baseReadopted + _baseRetasked + _baseDeletedAir) > 0) then {
			diag_log ("BASEGC|v1|readopted=" + str _baseReadopted + "|retasked=" + str _baseRetasked + "|deletedHulls=" + str _baseDeletedAir + "|t=" + str (round (time / 60)));
		};
	};

	// --- Orphaned-team zombie reaper ---
	// Reclaims AI teams whose player disconnected with WFBE_C_AI_TEAMS_JIP_PRESERVE==1
	// and never reconnected within WFBE_C_DISCONNECT_ZOMBIE_TIMEOUT seconds (default 600).
	// Set the param to 0 to disable entirely.
	_zombieTimeout = missionNamespace getVariable ["WFBE_C_DISCONNECT_ZOMBIE_TIMEOUT", 600];
	if (_zombieTimeout > 0) then {
		{
			_grp = _x;
			// Single-arg getVariable + isNil guard (works on groups in A2 OA). NOTE: the two-arg
			// [name, default] form ALSO works on groups in this build (see the husk-reap at the top
			// of this file and the persEmpty audit below, both live in production); this single-arg
			// style is kept only for the explicit -1 sentinel the orphan-age math below relies on.
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
	// untagged = groups with no wfbe_group_src (created outside the WFBE_CO_FNC_CreateGroup wrapper).
	// Counted here on the cheap 60s pass so the dashboard gets a responsive untagged gauge (the full
	// per-source breakdown only ships on the ~25-min GROUPAUDIT line). On a build where editor slots
	// are tagged, a rising untagged count is a wrapper-bypass leak signal; UNTAGLEAK below isolates the
	// NON-empty subset.
	_untW = 0; _untE = 0; _untG = 0;
	{
		_gsrc = _x getVariable "wfbe_group_src";
		if (side _x == west)       then {_cntWest = _cntWest + 1; if (isNil "_gsrc") then {_untW = _untW + 1}};
		if (side _x == east)       then {_cntEast = _cntEast + 1; if (isNil "_gsrc") then {_untE = _untE + 1}};
		if (side _x == resistance) then {_cntGuer = _cntGuer + 1; if (isNil "_gsrc") then {_untG = _untG + 1}};
	} forEach allGroups;

	//--- B7 efficiency (review 2026-06-15): publish per-side group counts so server_town_ai.sqf and
	//--- AI_Commander.sqf can read this cache instead of each re-scanning allGroups every sweep/tick.
	missionNamespace setVariable ["wfbe_grpcnt_west", _cntWest];
	missionNamespace setVariable ["wfbe_grpcnt_east", _cntEast];
	missionNamespace setVariable ["wfbe_grpcnt_guer", _cntGuer];
	missionNamespace setVariable ["wfbe_grpcnt_t", time];

	_now = time;

	// --- GCSTAT (claude-gaming 2026-06-15): consolidated per-pass GC summary on the 60s sweep
	// cadence. groups reaped THIS pass (non-persistent empties), empties found (incl. persistent),
	// and current per-side group counts incl. GUER. Single cheap diag_log; all values already in
	// hand (counters from the sweep above, per-side counts from the cap-warning pass). t = round min.
	diag_log ("GCSTAT|v1|reaped=" + str _gcReaped + "|emptyFound=" + str _gcEmptyFound + "|west=" + str _cntWest + "|east=" + str _cntEast + "|guer=" + str _cntGuer + "|untW=" + str _untW + "|untE=" + str _untE + "|untG=" + str _untG + "|t=" + str (round (time / 60)));

	// --- Public /wasp dashboard - SAFE live telemetry (wasp-dash-safe-telemetry, claude-gaming 2026-06-21).
	// Competitive-integrity rule (Steff 2026-06-21): the public dashboard/JSON must NEVER expose
	// win-advantage intel (base/town ownership, positions, per-side force/economy, AICOM targets). Only
	// MUTUAL-KNOWLEDGE that both sides already see in-game is allowed live. Two such extras on the 60s
	// cadence, next to GCSTAT:
	//   1) SCORE     - the mutual kill-score both sides read off the in-game scoreboard (scoreSide).
	//   2) CONTESTED - an ANONYMIZED aggregate COUNT of towns in conflict (no names/sides/positions);
	//                  stamped per-town by server_town.sqf's existing capture scan (wfbe_contested).
	// A2 OA 1.64: build strings with + / str only (no joinString); towns are Locations so the [name,
	// default] getVariable form is valid (the nil-default trap is GROUPS only).
	diag_log ("SCORE|v1|west=" + str (scoreSide west) + "|east=" + str (scoreSide east) + "|t=" + str (round (time / 60)));
	_contestedTowns = 0;
	{ if (_x getVariable ["wfbe_contested", false]) then {_contestedTowns = _contestedTowns + 1} } forEach towns;
	diag_log ("CONTESTED|v1|count=" + str _contestedTowns + "|t=" + str (round (time / 60)));

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

		// Single allUnits pass: count units per side for audit line + TICK sharing,
		// AND the delegation split (total/server-local) used by DELEGSTAT below.
		// B6: this folds the three former allUnits passes (per-side counts here + the
		// two delegation passes that used to run near DELEGSTAT) into ONE iteration.
		// Stored in missionNamespace so AI_Commander TICK can read them cheaply.
		_uniWest = 0; _uniEast = 0; _uniGuer = 0;
		_delegTotal = 0; _delegLocal = 0;
		{
			_delegTotal = _delegTotal + 1;
			if (local _x) then { _delegLocal = _delegLocal + 1 };
			if (side _x == west)       then { _uniWest = _uniWest + 1 };
			if (side _x == east)       then { _uniEast = _uniEast + 1 };
			if (side _x == resistance) then { _uniGuer = _uniGuer + 1 };
		} forEach allUnits;
		missionNamespace setVariable ["wfbe_units_west", _uniWest];
		missionNamespace setVariable ["wfbe_units_east", _uniEast];
		missionNamespace setVariable ["wfbe_units_guer", _uniGuer];

		// Build per-(side, src) counts in a flat key=value array: [side, src, count, ...]
		// Using a simple parallel-arrays approach to avoid any A3-only constructs.
		// B6: the old inner `while` stride-scan over _srcCounts was O(groups * distinctKeys)
		// (~2100ms/276 groups). Replace it with a parallel _srcKeys string array and a single
		// native `find` per group — distinct (side,src) pairs are few, so find is effectively
		// O(groups). _srcCounts keeps the identical flat [side, src, count, ...] layout so the
		// downstream per-side breakdown loop is unchanged.
		_emptyW = 0; _emptyE = 0; _emptyG = 0; _persEmptyW = 0; _persEmptyE = 0; _persEmptyG = 0; //--- EMPTYGRP tracking (Ray)
		_srcCounts = []; // flat: [side0, src0, cnt0, side1, src1, cnt1, ...]
		_srcKeys = [];   // parallel: one "sideStr|src" key per _srcCounts triple (entry N -> _srcCounts index N*3)

		{
			_auditSide = side _x;
			if ((count units _x) == 0) then {
				private "_pe"; _pe = _x getVariable "wfbe_persistent"; if (isNil "_pe") then {_pe = false}; //--- A2 group getVariable has no default form
				switch (_auditSide) do {
					case west:       { _emptyW = _emptyW + 1; if (_pe) then {_persEmptyW = _persEmptyW + 1} };
					case east:       { _emptyE = _emptyE + 1; if (_pe) then {_persEmptyE = _persEmptyE + 1} };
					case resistance: { _emptyG = _emptyG + 1; if (_pe) then {_persEmptyG = _persEmptyG + 1} };
					default {};
				};
			};
			_src = _x getVariable "wfbe_group_src";
			if (isNil "_src") then { _src = "untagged" };

			// Keyed accumulation: single native `find` instead of the per-group stride scan.
			_srcKey = Format ["%1|%2", str _auditSide, _src];
			_srcIdx = _srcKeys find _srcKey;
			if (_srcIdx < 0) then {
				[_srcKeys, _srcKey]      call WFBE_CO_FNC_ArrayPush;
				[_srcCounts, _auditSide] call WFBE_CO_FNC_ArrayPush;
				[_srcCounts, _src]       call WFBE_CO_FNC_ArrayPush;
				[_srcCounts, 1]          call WFBE_CO_FNC_ArrayPush;
			} else {
				//--- _srcKeys entry N maps to _srcCounts triple starting at N*3; +2 = the count slot.
				_srcCounts set [(_srcIdx * 3) + 2, (_srcCounts select ((_srcIdx * 3) + 2)) + 1];
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

		//--- Delegation split: prove the HC offload is alive. B6: _delegTotal/_delegLocal are
		//--- now accumulated in the single allUnits pass above (no extra allUnits scans here).
		diag_log (Format ["EMPTYGRP|v1|west=%1|east=%2|guer=%3|persW=%4|persE=%5|persG=%6|t=%7", _emptyW, _emptyE, _emptyG, _persEmptyW, _persEmptyE, _persEmptyG, round (time / 60)]); //--- EMPTYGRP tracking (Ray)
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

		//--- TELEM HOST V2 (tp4, 2026-07-06): GRPBUDGET + SRVPERF new host.
		//--- Only active when WFBE_C_TELEM_HOST_V2 > 0 (default 0 = inert).
		//--- Runs inside the existing 5-min (_lastAudit) gate - same 300s cadence,
		//--- no extra throttle variable. Format is BYTE-IDENTICAL to the original
		//--- emitters in AI_Commander.sqf (same field order + separators).
		if ((missionNamespace getVariable ["WFBE_C_TELEM_HOST_V2", 0]) > 0) then {

			//--- SRVPERF: server-global perf snapshot (was AI_Commander.sqf:901).
			//--- Reads: towns wfbe_active flag, diag_fps, allUnits, allGroups, vehicles, allDead.
			//--- All are engine globals or missionNamespace - accessible here without semantic change.
			private ["_spActive"];
			_spActive = 0;
			{ if (_x getVariable ["wfbe_active", false]) then {_spActive = _spActive + 1} } forEach towns;
			diag_log ("SRVPERF|v1|" + str (round (time / 60)) + "|fps=" + str (round (diag_fps)) + "|units=" + str (count allUnits) + "|groups=" + str (count allGroups) + "|veh=" + str (count vehicles) + "|dead=" + str (count allDead) + "|activeTowns=" + str _spActive);

			//--- GRPBUDGET: per-side group count vs 144 hard cap (was AI_Commander.sqf:1010-1022).
			//--- Reads wfbe_grpcnt_* from the cache this file already maintains (its own allGroups pass);
			//--- fallback to a fresh count when the cache is missing (same fallback as the original).
			//--- WARN/RECOVER latch (wfbe_grpbudget_warn_active) is missionNamespace - shared with
			//--- AI_Commander when flag=0; when flag=1 only this host writes/reads it (no contention).
			private ["_gbW","_gbE","_gbG","_gbMax","_gbWarn"];
			_gbW = missionNamespace getVariable ["wfbe_grpcnt_west", -1]; if (_gbW < 0) then { _gbW = {side _x == west} count allGroups; };
			_gbE = missionNamespace getVariable ["wfbe_grpcnt_east", -1]; if (_gbE < 0) then { _gbE = {side _x == east} count allGroups; };
			_gbG = missionNamespace getVariable ["wfbe_grpcnt_guer", -1]; if (_gbG < 0) then { _gbG = {side _x == resistance} count allGroups; };
			_gbMax = _gbW max _gbE max _gbG;
			diag_log ("GRPBUDGET|v1|" + str (round (time / 60)) + "|west=" + str _gbW + "|east=" + str _gbE + "|guer=" + str _gbG + "|cap=144");
			_gbWarn = missionNamespace getVariable ["WFBE_C_GROUP_BUDGET_WARN", 125];
			if (_gbMax >= _gbWarn) then {
				if ((missionNamespace getVariable ["wfbe_grpbudget_warn_active", 0]) < 1) then {
					missionNamespace setVariable ["wfbe_grpbudget_warn_active", 1];
					diag_log ("GRPBUDGET|v1|WARN|" + str (round (time / 60)) + "|near-cap max=" + str _gbMax + "/144 warn=" + str _gbWarn + " (west=" + str _gbW + " east=" + str _gbE + " guer=" + str _gbG + ")");
				};
			} else {
				if ((missionNamespace getVariable ["wfbe_grpbudget_warn_active", 0]) > 0) then {
					missionNamespace setVariable ["wfbe_grpbudget_warn_active", 0];
					diag_log ("GRPBUDGET|v1|RECOVER|" + str (round (time / 60)) + "|max=" + str _gbMax + "/144 warn=" + str _gbWarn + " (west=" + str _gbW + " east=" + str _gbE + " guer=" + str _gbG + ")");
				};
			};

		}; //--- end WFBE_C_TELEM_HOST_V2 block
		}; // --- end D2 modulo gate (WFBE_C_GROUPAUDIT_EVERY) ---
	};
};

