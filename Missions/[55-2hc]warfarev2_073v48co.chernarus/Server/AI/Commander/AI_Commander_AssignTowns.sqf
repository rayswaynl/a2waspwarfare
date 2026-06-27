/*
	AI Commander - send idle AI teams at the nearest uncaptured town.
	feat/ai-commander. Server-side worker.
	Parameter: _this = side.

	The "towns" team mode is otherwise dead infrastructure (nothing drives teams to
	towns), so this worker BOTH sets the mode and issues the waypoints itself, via the
	existing arc-approach planner (WFBE_C_AI_COMMANDER_USE_ARC_APPROACH=1) or the proven
	AIMoveTo fallback (=0).
*/

private ["_side","_sideID","_sideText","_logik","_teams","_uncaptured","_assigned","_team","_aliveCount","_mode","_goto","_needs","_avail","_target","_useArc","_humanCmd","_cmdTeam","_autonomous","_modeNow","_canDrive","_explicitMode","_gar","_garDead","_hqG","_ord","_spear","_spearT","_perTown","_concBase","_ownedCount","_bootstrap","_hqObj","_bestBoot","_bestBootScore","_bootScore","_bootDist","_ltBootLog","_mounted","_teamReach","_ldrPos","_reachFoot","_reachMounted","_nearReach","_nearReachD","_tgtDist","_blTowns","_blList","_blKeep","_uncapturedF"];

_side = _this;
_sideID = (_side) Call WFBE_CO_FNC_GetSideID;
_sideText = str _side;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};

_teams = _logik getVariable "wfbe_teams";
if (isNil "_teams") exitWith {};

//--- AICOM v2 (consolidate, Ray): after the fist captures a town the Allocator stamps wfbe_aicom_consolidate_until;
//--- skip this re-task pass while it's live so teams keep their current orders (regroup at the just-taken town)
//--- ~a minute before advancing. Only when the v2 Allocator is live; harmless otherwise.
if ((missionNamespace getVariable ["WFBE_C_AICOM2_ALLOCATE_ENABLE", 0]) > 0 && {time < (_logik getVariable ["wfbe_aicom_consolidate_until", -1e9])}) exitWith {};

//--- Hybrid: when a human commands this side, only auto-assign DELEGATED (autonomous) teams.
_cmdTeam = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
_humanCmd = false;
if (!isNull _cmdTeam) then {
	if (isPlayer (leader _cmdTeam)) then {_humanCmd = true};
};

//--- OA-safe filter: towns not owned by this side.
_uncaptured = [];
{ if ((_x getVariable "sideID") != _sideID) then {_uncaptured set [count _uncaptured, _x]} } forEach towns;
if (count _uncaptured == 0) exitWith {};

_useArc = (missionNamespace getVariable "WFBE_C_AI_COMMANDER_USE_ARC_APPROACH") > 0;
_assigned = [];

//--- V0.8 TRUE CONCENTRATION (claude-gaming 2026-06-14): the per-town cap below must see
//--- teams ALREADY en route on a sticky order, not just teams (re)assigned THIS tick - else
//--- the cap never fills and "concentration" silently degraded to one team per town. Pre-seed
//--- _assigned with the live target of every team currently marching at an enemy town, so the
//--- cap reflects real massed force and rolls freed teams to the NEXT town once one is captured.
{
	_team = _x;
	if (!isNull _team) then {
		if (({alive _x} count (units _team)) > 0) then {
			private ["_curOrd","_curTgt"];
			_curOrd = _team getVariable ["wfbe_aicom_townorder", []];
			if (count _curOrd >= 1) then {
				_curTgt = _curOrd select 0;
				if (typeName _curTgt == "OBJECT" && {!isNull _curTgt}) then {
					//--- Only count it as committed mass if the town is still contestable
					//--- (not ours yet); a captured town frees the team to roll forward.
					if ((_curTgt getVariable "sideID") != _sideID) then {
						_assigned set [count _assigned, _curTgt];
					};
				};
			};
		};
	};
} forEach _teams;

//--- V0.7: bootstrap-bias pre-computation (once per tick, used inside the team loop).
_ownedCount = 0;
{ if ((_x getVariable "sideID") == _sideID) then {_ownedCount = _ownedCount + 1} } forEach towns;
_bootstrap = ((missionNamespace getVariable ["WFBE_C_AICOM_BOOTSTRAP_BIAS", 1]) > 0) && (_ownedCount == 0);

{
	_team = _x;
	//--- V0.6.5: wiped HC teams leave NULL groups in wfbe_teams (index-aligned registry,
	//--- entries must NOT be removed). getVariable on a null group returns nil even with
	//--- a default -> toLower nil threw here every tick and killed town assignment for
	//--- every team after the first null (live-round towns stuck at 0/0). Skip nulls.
	_aliveCount = 0;
	if (!isNull _team) then {_aliveCount = {alive _x} count (units _team)};
	if (_aliveCount > 0) then {
	//--- ASSAULT TELEMETRY (task #48, #2): OUTCOME watcher. Rides this existing forEach _teams
	//--- (fired every WFBE_C_AI_COMMANDER_TOWN_INTERVAL=120s). For each team with an OPEN dispatch
	//--- (Hook A latch), resolve exactly one ARRIVED (leader within arrive-radius of the town) or
	//--- STRANDED (timeout exceeded, still far). Latched by wfbe_aicom_dispatch_open so it fires
	//--- once per dispatch; a re-dispatch in Hook A re-opens the latch. Logging only, no behaviour.
	if (_team getVariable ["wfbe_aicom_dispatch_open", false]) then {
		private ["_dord","_dtgt","_dt0","_dldr","_ddist","_arrR","_toSecs","_elapsed"];
		_dord = _team getVariable ["wfbe_aicom_townorder", []];
		if (count _dord >= 2) then {
			_dtgt = _dord select 0;
			_dt0  = _dord select 1;
			if (typeName _dtgt == "OBJECT" && {!isNull _dtgt}) then {
				_dldr   = leader _team;
				_ddist  = _dldr distance _dtgt;
				_arrR   = missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_ARRIVE_RADIUS", 250];
				_toSecs = missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_TIMEOUT", 420];
				_elapsed = round (time - _dt0);
				if (_ddist <= _arrR) then {
					diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|ASSAULT_ARRIVED|team=" + (str _team) + "|town=" + (_dtgt getVariable ["name","town"]) + "|dist=" + str (round _ddist) + "|elapsed=" + str _elapsed);
					_team setVariable ["wfbe_aicom_dispatch_open", false];
				} else {
					if ((time - _dt0) > _toSecs) then {
						private ["_moved","_stuck"];
						_moved = -1;
						if (count _dord >= 3) then {_moved = _dldr distance (_dord select 2)};
						_stuck = (behaviour _dldr != "COMBAT") && {_moved >= 0} && {_moved < (missionNamespace getVariable ["WFBE_C_AICOM_STUCK_MOVED", 200])};
						diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|ASSAULT_STRANDED|team=" + (str _team) + "|town=" + (_dtgt getVariable ["name","town"]) + "|dist=" + str (round _ddist) + "|elapsed=" + str _elapsed + "|moved=" + str (round _moved) + "|stuck=" + str _stuck);
						_team setVariable ["wfbe_aicom_dispatch_open", false];
					};
				};
			} else {
				//--- Target captured/null (e.g. Strategy cleared the order): close the latch silently.
				_team setVariable ["wfbe_aicom_dispatch_open", false];
			};
		};
	};
	_autonomous = _team getVariable ["wfbe_autonomous", false];
	_modeNow = toLower (_team getVariable ["wfbe_teammode", "towns"]);
	_canDrive = false;
	_explicitMode = false;
	if (_modeNow == "move") then {_explicitMode = true};
	if (_modeNow == "patrol") then {_explicitMode = true};
	if (_modeNow == "defense") then {_explicitMode = true};

	//--- Drive only if AI-controllable (no human, or human delegated this team) AND the executor doesn't own it.
	if (_aliveCount > 0) then {
		if (!isPlayer (leader _team)) then {
			//--- B36 (Ray 2026-06-15) #3b: the AI drives its OWN (non-player-led) HQ teams even while a
			//--- human is commander, so they never sit idle and keep capturing towns. A team the human has
			//--- explicitly ordered (move/patrol/defense) is preserved by the !_explicitMode gate below,
			//--- so this only auto-tasks the teams the human is not actively commanding.
			_canDrive = true;
			if (_autonomous) then {_canDrive = true};
		};
	};

	if (_canDrive) then {
		//--- V0.2: hold one team back as the base garrison (full-auto only) - a captured
		//--- base must not be left open while every team marches at towns.
		//--- Owner call 2026-06-11: OFF by default - everything goes to the front.
		//--- Opt back in via WFBE_C_AI_COMMANDER_GARRISON = 1.
		if (((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_GARRISON", 0]) > 0) && {!_humanCmd} && {!_explicitMode} && {_aliveCount > 0}) then {
			_gar = _logik getVariable ["wfbe_aicom_garrison", grpNull];
			_garDead = true;
			if (!isNull _gar) then {
				if (({alive _x} count (units _gar)) > 0) then {_garDead = false};
			};
			if (_garDead) then {
				_hqG = (_side) Call WFBE_CO_FNC_GetSideHQ;
				if (!isNull _hqG) then {
					[_team, "defense"] Call SetTeamMoveMode;
					[_team, getPos _hqG] Call SetTeamMovePos;
					//--- V0.3: HC-resident teams get their orders via the public order variable.
					if (_team getVariable ["wfbe_aicom_hc", false]) then {
						_team setVariable ["wfbe_aicom_order", [(if (isNil {_team getVariable "wfbe_aicom_order"}) then {-1} else {(_team getVariable "wfbe_aicom_order") select 0}) + 1, "defense", getPos _hqG], true];
					};
					_logik setVariable ["wfbe_aicom_garrison", _team];
					_explicitMode = true; //--- now an explicit order; the executor drives it home
					["INFORMATION", Format ["AI_Commander_AssignTowns.sqf: [%1] team [%2] assigned as base garrison.", _sideText, _team]] Call WFBE_CO_FNC_AICOMLog;
				};
			};
		};
		if (!_explicitMode) then {
			_mode = _team getVariable ["wfbe_teammode", ""];
			_goto = _team getVariable ["wfbe_teamgoto", objNull];

			//--- V0.4.2 churn fix: orders are STICKY. Retarget only when the team has no
			//--- valid enemy-town target, the target resolved (we captured it), or the team
			//--- has been visibly stuck on the same order for 10+ min without progress.
			//--- Distance alone is NOT a reason - en-route teams keep their order.
			_needs = false;
			if (_mode == "towns" || _mode == "") then {
				if (typeName _goto != "OBJECT") then {
					_needs = true;
				} else {
					if (isNull _goto) then {
						_needs = true;
					} else {
						if ((_goto getVariable "sideID") == _sideID) then {
							_needs = true;
						} else {
							_ord = _team getVariable ["wfbe_aicom_townorder", []];
							if (count _ord < 3 || {(_ord select 0) != _goto}) then {
								//--- No bookkeeping yet (legacy order) or goto changed under us: book it
								//--- once without re-issuing waypoints; the stuck check takes over from here.
								_team setVariable ["wfbe_aicom_townorder", [_goto, time, getPos (leader _team)]];
							} else {
								if (time - (_ord select 1) > (missionNamespace getVariable ["WFBE_C_AICOM_STUCK_SECS", 210])) then {
									private ["_ldr","_movedThr","_farThr"];
									_ldr = leader _team;
									_movedThr = missionNamespace getVariable ["WFBE_C_AICOM_STUCK_MOVED", 200];
									_farThr   = missionNamespace getVariable ["WFBE_C_AICOM_STUCK_FAR", 300];
									//--- In-contact teams are legitimately stationary (firefight/bounding); never
									//--- treat as stuck - refresh the breadcrumb so they keep fighting.
									if ((behaviour _ldr != "COMBAT") && {_ldr distance (_ord select 2) < _movedThr} && {_ldr distance _goto > _farThr}) then {
										_needs = true; //--- parked far from target, not in contact: re-issue (unstick)
										//--- REAL UNSTUCK (task #14/#16): the old remedy just re-emitted the same
										//--- un-followable order. Bump a per-team STRIKE counter so the HC executor
										//--- escalates Tier1 (reverse+reposition) -> Tier2 (road re-path) -> Tier3
										//--- (teleport-nudge to nearest clear road node, no player nearby). The strike
										//--- rides on the order broadcast below; the executor reads wfbe_aicom_unstuck.
										private ["_strk"];
										_strk = (_team getVariable ["wfbe_aicom_stuckstrikes", 0]) + 1;
										_team setVariable ["wfbe_aicom_stuckstrikes", _strk];
										diag_log (Format ["STUCKSTAT|v1|%1|%2|stuck|leader=%3|distStart=%4|distTgt=%5|reissue|strike=%6", _sideText, round (time / 60), typeOf _ldr, round (_ldr distance (_ord select 2)), round (_ldr distance _goto), _strk]);
										//--- WAVE-1 CAUSE-2 TARGET-ABANDON: a team grinding one unreachable/unflippable town forever
										//--- (re-issue keeps re-picking the same _goto). Once strikes exceed WFBE_C_AICOM_STUCK_ABANDON,
										//--- BLACKLIST this town for THIS team for a cooldown (stored [town,expiry] on wfbe_aicom_blacklist),
										//--- reset the strike counter, and let the selector below pick the next-best reachable town. The
										//--- selector clears the whole blacklist if it would otherwise leave the team with no candidate
										//--- (GUARDRAIL: a team must always get a target - never idle).
										if (_strk > (missionNamespace getVariable ["WFBE_C_AICOM_STUCK_ABANDON", 4])) then {
											private ["_abCd","_abBl","_abKeep"];
											_abCd = missionNamespace getVariable ["WFBE_C_AICOM_BLACKLIST_COOLDOWN", 600];
											_abBl = _team getVariable ["wfbe_aicom_blacklist", []];
											//--- prune expired entries + drop any prior entry for _goto, then add a fresh one.
											_abKeep = [];
											{ if ((typeName (_x select 0) == "OBJECT") && {!isNull (_x select 0)} && {(_x select 1) > time} && {(_x select 0) != _goto}) then {_abKeep set [count _abKeep, _x]} } forEach _abBl;
											_abKeep set [count _abKeep, [_goto, time + _abCd]];
											_team setVariable ["wfbe_aicom_blacklist", _abKeep];
											_team setVariable ["wfbe_aicom_stuckstrikes", 0];
											diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|TARGET_ABANDON|team=" + (str _team) + "|town=" + (_goto getVariable ["name","town"]) + "|cooldown=" + str _abCd);
										};
									} else {
										//--- progressing, arrived, or in contact: refresh the breadcrumb and
										//--- reset the unstuck strike ladder (the team moved, so it is not stuck).
										_team setVariable ["wfbe_aicom_townorder", [_goto, time, getPos _ldr]];
										_team setVariable ["wfbe_aicom_stuckstrikes", 0];
									};
								};
							};
						};
					};
				};
			};

			if (_needs) then {
				_target = objNull;
				if (_bootstrap) then {
					//--- V0.7 BOOTSTRAP BIAS: side owns 0 towns - pick the nearest-to-HQ,
					//--- lowest-supplyValue uncaptured town so we grab income as fast as possible.
					//--- Score = -(distance to HQ) - (supplyValue * 10): small near towns win.
					_hqObj = (_side) Call WFBE_CO_FNC_GetSideHQ;
					_bestBoot = objNull;
					_bestBootScore = -1e9;
					{
						_bootDist = if (!isNull _hqObj) then {_x distance _hqObj} else {0};
						_bootScore = (0 - _bootDist) - ((_x getVariable ["supplyValue", 0]) * 10);
						if (_bootScore > _bestBootScore) then {_bestBootScore = _bootScore; _bestBoot = _x};
					} forEach _uncaptured;
					if (!isNull _bestBoot) then {_target = _bestBoot};
					//--- Debounced log: at most once per 300 s per side.
					_ltBootLog = _logik getVariable ["wfbe_aicom_bootstrap_lt", -1e9];
					if (time - _ltBootLog > 300) then {
						["INFORMATION", Format ["AI_Commander_AssignTowns.sqf: [%1] BOOTSTRAP targeting active (0 towns owned) - biasing to nearest low-value town.", _sideText]] Call WFBE_CO_FNC_AICOMLog;
						_logik setVariable ["wfbe_aicom_bootstrap_lt", time];
					};
				} else {
					//--- V0.8: MASS force on the strategy worker's spearhead targets first, in
					//--- published priority order (top = primary). Each town's quota now scales
					//--- with its GARRISON SIZE (wfbe_town_type tier) so a HugeTown draws more
					//--- teams than a TinyTown - one squad can't crack a garrisoned city, so we
					//--- pile on until the cap, then the freed/extra teams spill to the next town.
					//--- The cap is checked against _assigned, which now includes EN-ROUTE teams
					//--- (pre-seeded above), so concentration is enforced across ticks, not just
					//--- this pass. Then spill over to the classic nearest-uncaptured pick.
					//--- P0 DISTANCE-AWARE / TRANSPORT-AWARE ONGOING SELECTION (task #48, claude-gaming
					//--- 2026-06-15): the live match showed 256 DISPATCH vs 13 ARRIVED, 63% of dispatches
					//--- aimed at spearheads >6km away (7457m/10893m/12349m) - foot teams marched cross-
					//--- country and died. We now gate spearhead picks by THIS team's REACH: a non-mounted
					//--- team won't be sent at a spearhead farther than REACH_FOOT (3.5km), it takes the
					//--- nearest reachable uncaptured town instead (contiguous front); a MOUNTED team (any
					//--- alive unit in a drivable land vehicle) gets REACH_MOUNTED (9km) so trucks/APCs still
					//--- take the long leg. GUARDRAIL: if NOTHING is in reach the team still gets its nearest
					//--- target (never idles). Bootstrap is exempt above (opening rush unchanged). Cheap: one
					//--- leader pos, one units-scan for mount, distances on the existing town lists.
					_ldrPos = getPos (leader _team);
					_mounted = false;
					{ if (!_mounted && {alive _x} && {(vehicle _x) != _x} && {(vehicle _x) isKindOf "LandVehicle"} && {canMove (vehicle _x)}) then {_mounted = true} } forEach (units _team);
					_reachFoot    = missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_REACH_FOOT", 3500];
					_reachMounted = missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_REACH_MOUNTED", 9000];
					_teamReach = if (_mounted) then {_reachMounted} else {_reachFoot}; private "_teamAir"; _teamAir = false; { if (!_teamAir && {alive _x} && {(vehicle _x) isKindOf "Helicopter"} && {(getNumber (configFile >> "CfgVehicles" >> (typeOf (vehicle _x)) >> "transportSoldier")) > 0}) then {_teamAir = true} } forEach (units _team); //--- B756 (Ray 2026-06-26): does this team carry a TRANSPORT heli? gates naval-HVT targets to air teams only (no ground sea-stranding).
					//--- WAVE-1 CAUSE-2: live (non-expired) blacklist towns for THIS team. Prune expired entries
					//--- back onto the team var, then build _uncapturedF = uncaptured minus blacklisted. GUARDRAIL:
					//--- if excluding the blacklist would leave NO uncaptured town, clear the blacklist and fall back
					//--- to the full list so the team always gets a target (never idle). _blTowns gates the spearhead
					//--- pick too; bootstrap (0-town opening rush) is exempt - it never reaches here.
					_blList = _team getVariable ["wfbe_aicom_blacklist", []];
					_blKeep = [];
					_blTowns = [];
					{ if ((typeName (_x select 0) == "OBJECT") && {!isNull (_x select 0)} && {(_x select 1) > time}) then {_blKeep set [count _blKeep, _x]; _blTowns set [count _blTowns, (_x select 0)]} } forEach _blList;
					_team setVariable ["wfbe_aicom_blacklist", _blKeep];
					_uncapturedF = _uncaptured - _blTowns;
					if (count _uncapturedF == 0) then {
						//--- every uncaptured town is blacklisted: clear it so this team is never left without a target.
						_team setVariable ["wfbe_aicom_blacklist", []];
						_blTowns = [];
						_uncapturedF = _uncaptured;
					};
					//--- AICOM v2 (M1): if the single-authority Allocator assigned THIS team a target this cycle,
					//--- USE it (concentrate on the fist) and skip the legacy spearhead/nearest pick below. Fresh-gated
					//--- (<180s) so a stale assignment (Allocator off / not run) falls through to legacy = instant rollback.
					if (isNull _target && {(missionNamespace getVariable ["WFBE_C_AICOM2_ALLOCATE_ENABLE", 0]) > 0}) then {
						private ["_allocT","_allocTick"];
						_allocT    = _team getVariable "wfbe_aicom_alloc_target";
						_allocTick = _team getVariable "wfbe_aicom_alloc_tick";
						if (!isNil "_allocT" && {!isNull _allocT} && {!isNil "_allocTick"} && {(time - _allocTick) < 180} && {(_allocT getVariable ["sideID", _sideID]) != _sideID}) then {
							_target = _allocT;
						};
					};
					_spear = _logik getVariable ["wfbe_aicom_targets", []];
					_concBase = missionNamespace getVariable ["WFBE_C_AICOM_CONCENTRATION", 3];
					{
						_spearT = _x;
						if (isNull _target && {!isNull _spearT}) then {
							if (((_spearT getVariable "sideID") != _sideID) && {!(_spearT in _blTowns)} && {(_ldrPos distance _spearT) <= _teamReach} && {((missionNamespace getVariable ["WFBE_C_AICOM_NAVAL_AIR_ONLY", 1]) <= 0) || {!(_spearT getVariable ["wfbe_is_naval_hvt", false])} || _teamAir}) then { //--- B756: naval-HVT targets are air-team-only (offshore decks) - a ground team skips them (no sea-stranding) and takes a land target instead.
								//--- Per-target quota = base concentration scaled by garrison tier
								//--- (wfbe_town_type maps to defender group count in
								//--- Server_GetTownGroupsDefender.sqf: Tiny 3, Small 5, Medium 6,
								//--- Large 7, Huge 8 groups). Bigger garrison -> more teams massed.
								//--- One block per case (no fall-through) to match the codebase style.
								_perTown = _concBase;
								switch (_spearT getVariable ["wfbe_town_type", ""]) do {
									case "TinyTown1":   {_perTown = (_concBase - 1) max 1};
									case "SmallTown1":  {_perTown = _concBase};
									case "SmallTown2":  {_perTown = _concBase};
									case "MediumTown1": {_perTown = _concBase + 1};
									case "MediumTown2": {_perTown = _concBase + 1};
									case "LargeTown1":  {_perTown = _concBase + 2};
									case "LargeTown2":  {_perTown = _concBase + 2};
									case "HugeTown1":   {_perTown = _concBase + 2};
									case "HugeTown2":   {_perTown = _concBase + 2};
									default {_perTown = _concBase};
								};
								if (({_x == _spearT} count _assigned) < _perTown) then {_target = _spearT};
							};
						};
					} forEach _spear;
					//--- P0 NEAREST-REACHABLE OVERRIDE: no in-reach spearhead won the quota above (every
					//--- spearhead is full or out of reach). Build a CONTIGUOUS FRONT: pick the nearest
					//--- un-captured town WITHIN this team's reach, preferring towns not already saturated
					//--- (_avail = uncaptured minus en-route mass) so freed teams spread to the next town.
					if (isNull _target) then {
						_avail = _uncapturedF - _assigned;
						if (count _avail == 0) then {_avail = _uncapturedF};
						//--- Nearest town in reach (foot 3.5km / mounted 9km from THIS leader).
						_nearReach = objNull; _nearReachD = 1e9;
						{
							_tgtDist = _ldrPos distance _x;
							if (_tgtDist <= _teamReach && {_tgtDist < _nearReachD} && {((missionNamespace getVariable ["WFBE_C_AICOM_NAVAL_AIR_ONLY", 1]) <= 0) || {!(_x getVariable ["wfbe_is_naval_hvt", false])} || _teamAir}) then {_nearReachD = _tgtDist; _nearReach = _x}; //--- B756: ground teams skip naval HVTs in the nearest-town fallback too.
						} forEach _avail;
						if (!isNull _nearReach) then {
							_target = _nearReach;
						} else {
							//--- GUARDRAIL: nothing in reach (isolated front / island target) - fall back to
							//--- the absolute nearest so the team always has a valid order and never idles.
							_target = [leader _team, _uncapturedF] Call WFBE_CO_FNC_GetClosestEntity; //--- WAVE-1 CAUSE-2: _uncapturedF (blacklist-filtered; guardrail above guarantees non-empty). B36.1 (Ray 2026-06-15): FULL uncaptured list, NOT the _assigned-reduced _avail. A team that just captured its town has dismounted + abandoned its trucks, so it scans on-foot (3500m reach); on a sparse map no town is in reach, this guardrail fires, and the old _avail (minus teammates' targets) sent it to a FARTHER town -> it milled at the just-capped centre. Nearest-of-all advances it to the adjacent town (concentration is fine for an isolated foot team).
						};
					};
				};
				if (!isNil "_target") then {
					if (!isNull _target) then {
						[_team, "towns"] Call SetTeamMoveMode;
						[_team, _target] Call SetTeamMovePos;
						if (_team getVariable ["wfbe_aicom_hc", false]) then {
							//--- V0.3: HC-resident team - the HC driver issues the local waypoints;
							//--- server-side waypoint commands on remote groups are unreliable.
							//--- ROAD-MARCH (task #14/#16): the executor turns a bare wfbe_aicom_order
							//--- into a cross-country MOVE that A2 PFM stalls. Compute a ROAD-NODE chain
							//--- here (server-side, against this HC team's leader pos) and broadcast it in
							//--- wfbe_aicom_route so the executor lays road waypoints + forceFollowRoad on
							//--- the long base->front leg, then COMBAT/WEDGE near the objective. The order
							//--- contract stays 3-element [seq,mode,pos]; the route + unstuck tier ride
							//--- alongside as parallel public vars the executor reads on each seq bump.
							private ["_hcLdr","_hcOrigin","_hcDest","_hcRoute","_hcStrk","_rmHops","_rmI","_rmFrac","_rmGuess","_rmRds","_rmNode"];
							_hcLdr    = leader _team;
							_hcOrigin = getPos _hcLdr;
							_hcDest   = getPos _target;
							_hcStrk   = _team getVariable ["wfbe_aicom_stuckstrikes", 0];
							//--- Build up to N road-snapped waypoints evenly between origin and dest.
							//--- Each guess is the straight-line fraction point; we snap it to the nearest
							//--- real road node (nearRoads) so the convoy follows lanes A2 PFM can drive.
							//--- If no road is near a guess, we skip that hop (the executor still falls back
							//--- to a direct MOVE for that segment). Only build a route on the long leg.
							_hcRoute = [];
							if ((_hcOrigin distance _hcDest) > 700) then {
								_rmHops = 8;  //--- A2-fix 2026-06-14: denser road-node chain (was 4) so convoys hug roads instead of cutting cross-country
									//--- A2-fix 2026-06-14 (owner: teams move INDIVIDUALLY to same town = better speed): base-egress road node so teams escape a boxed/corner base, + per-team lateral lane so concentrated teams don't funnel one road
									_egRds = _hcOrigin nearRoads 300;
									if (count _egRds > 0) then {
										_egNode = [_hcOrigin, _egRds] Call WFBE_CO_FNC_GetClosestEntity;
										if (!isNull _egNode) then {_hcRoute = _hcRoute + [getPos _egNode]};
									};
									_laneDX = (_hcDest select 0) - (_hcOrigin select 0);
									_laneDY = (_hcDest select 1) - (_hcOrigin select 1);
									_laneLEN = sqrt ((_laneDX * _laneDX) + (_laneDY * _laneDY));
									_lanePX = 0; _lanePY = 0;
									if (_laneLEN > 1) then {_lanePX = - _laneDY / _laneLEN; _lanePY = _laneDX / _laneLEN};
									_laneJit = _team getVariable "wfbe_aicom_lanejit";
									if (isNil "_laneJit") then {_laneJit = (random 2) - 1; _team setVariable ["wfbe_aicom_lanejit", _laneJit, true]};
									_laneOff = _laneJit * 120;
								for "_rmI" from 1 to _rmHops do {
									_rmFrac  = _rmI / (_rmHops + 1);
									_rmGuess = [(_hcOrigin select 0) + ((_hcDest select 0) - (_hcOrigin select 0)) * _rmFrac,
									            (_hcOrigin select 1) + ((_hcDest select 1) - (_hcOrigin select 1)) * _rmFrac, 0];
									_rmTaper = sin (_rmFrac * 180);  //--- ~0 at route ends, max at mid: teams diverge into their own lane mid-route, converge at the town
										_rmGuess set [0, (_rmGuess select 0) + (_lanePX * _laneOff * _rmTaper)];
										_rmGuess set [1, (_rmGuess select 1) + (_lanePY * _laneOff * _rmTaper)];
										_rmRds = _rmGuess nearRoads 120;  //--- A2-fix 2026-06-14: tighter snap (was 220) so nodes lie on the line, not far disconnected roads
									if (count _rmRds > 0) then {
										_rmNode = [_rmGuess, _rmRds] Call WFBE_CO_FNC_GetClosestEntity;
										if (!isNull _rmNode) then {_hcRoute = _hcRoute + [getPos _rmNode]};
									};
								};
							};
							_team setVariable ["wfbe_aicom_route", _hcRoute, true];
							_team setVariable ["wfbe_aicom_unstuck", _hcStrk, true];
							//--- B37 (Ray 2026-06-16): INSTRUMENT the unstuck strike so we can VERIFY it triggers + at which
							//--- tier. Pairs with UNSTUCK_FIRED (Common_RunCommanderTeam) + the existing ASSAULT_STRANDED
							//--- moved/stuck line, giving the full strike -> fire -> recover lifecycle in the RPT.
							if (_hcStrk > 0) then { diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|UNSTUCK_STRIKE|team=" + (str _team) + "|tier=" + str _hcStrk); };
							_team setVariable ["wfbe_aicom_order", [(if (isNil {_team getVariable "wfbe_aicom_order"}) then {-1} else {(_team getVariable "wfbe_aicom_order") select 0}) + 1, "towns-target", _hcDest, _hcStrk], true]; //--- UNSTUCK FIX (Ray 2026-06-16): carry the strike tier as order element 3 so it stays in sync with the seq it belongs to (reader: Common_RunCommanderTeam). The wfbe_aicom_unstuck flag (line ~367) is kept for the gear-slow governor + logging.
						} else {
							if (_useArc) then {
								[_team, _target] Call WFBE_SE_FNC_AI_SetTownAttackPath;
							} else {
								[_team, getPos _target, "SAD", 200] Call AIMoveTo;
							};
						};
						_assigned set [count _assigned, _target];
						//--- P0 LATCH-CHURN FIX (task #48, claude-gaming 2026-06-15): a stuck re-issue used to
						//--- rewrite the breadcrumb time AND re-open the latch with a fresh start-time, RESETTING
						//--- the 420s strand clock every stuck pass - so a team grinding at the SAME far town never
						//--- hit STRANDED (only 4 logged despite ~80 lost teams), it just churned and died silent.
						//--- Fix: if the dispatch is ALREADY OPEN and we are re-issuing the SAME target, PRESERVE
						//--- the original dispatch start-time (_dt0) so the strand watcher fires on schedule and the
						//--- failure is logged + the team deliberately re-tasked. A NEW target (front rolled, target
						//--- captured) legitimately resets the clock. The unstuck strike ladder still rides along.
						private ["_priorOrd","_priorOpen","_dispT0","_sameTgt"];
						_priorOrd  = _team getVariable ["wfbe_aicom_townorder", []];
						_priorOpen = _team getVariable ["wfbe_aicom_dispatch_open", false];
						_sameTgt   = (count _priorOrd >= 1) && {(typeName (_priorOrd select 0)) == "OBJECT"} && {(_priorOrd select 0) == _target};
						_dispT0    = if (_priorOpen && _sameTgt && {count _priorOrd >= 2}) then {_priorOrd select 1} else {time};
						_team setVariable ["wfbe_aicom_townorder", [_target, _dispT0, getPos (leader _team)]];
						//--- ASSAULT TELEMETRY (task #48, #2): book a watcher latch on every (re)dispatch and
						//--- log the DISPATCH event. The OUTCOME watcher (Hook B, top of the per-team loop)
						//--- resolves exactly one ARRIVED or STRANDED per dispatch. Logging only - no behaviour
						//--- change. Town center = getPos _target; name via the broadcast "name" var.
						_team setVariable ["wfbe_aicom_dispatch_open", true];
						diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|ASSAULT_DISPATCH|team=" + (str _team) + "|town=" + (_target getVariable ["name","town"]) + "|dist=" + str (round ((leader _team) distance _target)) + "|reissue=" + str (_priorOpen && _sameTgt));
						["INFORMATION", Format ["AI_Commander_AssignTowns.sqf: [%1] team [%2] heading to attack town [%3].", _sideText, _team, _target getVariable ["name", "town"]]] Call WFBE_CO_FNC_AICOMLog;
					};
				};
			};
		};
	};
	}; //--- V0.6.5 null-team guard
} forEach _teams;
