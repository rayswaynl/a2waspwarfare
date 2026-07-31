/*
	AI Commander - send idle AI teams at the nearest uncaptured town.
	feat/ai-commander. Server-side worker.
	Parameter: _this = side.

	The "towns" team mode is otherwise dead infrastructure (nothing drives teams to
	towns), so this worker BOTH sets the mode and issues the waypoints itself, via the
	existing arc-approach planner (WFBE_C_AI_COMMANDER_USE_ARC_APPROACH=1) or the proven
	AIMoveTo fallback (=0).
*/

private ["_side","_sideID","_sideText","_logik","_teams","_uncaptured","_assigned","_team","_aliveCount","_mode","_goto","_needs","_avail","_target","_useArc","_humanCmd","_cmdTeam","_autonomous","_modeNow","_canDrive","_explicitMode","_gar","_garDead","_garAlive","_hqG","_ord","_spear","_spearT","_perTown","_concBase","_ownedCount","_bootstrap","_hqObj","_bestBoot","_bestBootScore","_bootScore","_bootDist","_ltBootLog","_mounted","_teamReach","_ldrPos","_reachFoot","_reachMounted","_nearReach","_nearReachD","_tgtDist","_blTowns","_blList","_blKeep","_uncapturedF","_consolidating","_fistSet","_consolRad","_allocTgt","_pin","_jcOrd","_jcBc","_jcTgt","_jcProg","_jcRecycle","_asltSpeed","_asltDist","_asltToSecs","_strandRecovery","_strandTarget","_footStage","_footStagePos","_stageGoto","_waveDelay","_priorDispT0"]; //--- cmdcon41-w2: journey-commit privates + TK arrivals M3 one-shot recovery state; +_waveDelay: feat/aicom-wave-stagger

_side = _this;
_sideID = (_side) Call WFBE_CO_FNC_GetSideID;
_sideText = str _side;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};

_teams = _logik getVariable "wfbe_teams";
if (isNil "_teams") exitWith {};

//--- AICOM v2 (consolidate, Ray): after the fist captures a town the Allocator stamps wfbe_aicom_consolidate_until.
//--- PER-TEAM SCOPING FIX (Ray): the OLD side-wide exitWith froze EVERY team for the window (harasser + en-route +
//--- relief), violating the never-standing-still-AI rule. Now we only flag it; inside the team loop a team keeps its
//--- current orders (regroup) ONLY if it has ARRIVED at a FIST alloc_target. Harasser (alloc_target = deep enemy town,
//--- not in the fist), en-route teams, relief and human-led teams all re-task normally. A2-OA-safe (plain getVariable).
_consolidating = ((missionNamespace getVariable ["WFBE_C_AICOM2_ALLOCATE_ENABLE", 0]) > 0) && (time < (_logik getVariable ["wfbe_aicom_consolidate_until", -1e9]));
_fistSet = []; if (_consolidating) then {_fistSet = _logik getVariable ["wfbe_aicom_targets", []]; if (isNil "_fistSet") then {_fistSet = []}};
_consolRad = missionNamespace getVariable ["WFBE_C_AICOM2_CONSOLIDATE_RADIUS", 250];

//--- Hybrid: when a human commands this side, only auto-assign DELEGATED (autonomous) teams.
_cmdTeam = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
_humanCmd = false;
if (!isNull _cmdTeam) then {
	if ([leader _cmdTeam, false] Call WFBE_CO_FNC_IsRealPlayer) then {_humanCmd = true};
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
			_curOrd = [_team, "wfbe_aicom_townorder", []] Call WFBE_CO_FNC_GroupGetBool;
			if (count _curOrd >= 1) then {
				_curTgt = _curOrd select 0;
				if (typeName _curTgt == "OBJECT" && {!isNull _curTgt}) then {
					//--- Only count it as committed mass if the town is still contestable
					//--- (not ours yet); a captured town frees the team to roll forward.
					//--- r36 wave/staging: bare getVariable sideID can nil-poison concentration pre-seed
					if ((_curTgt getVariable ["sideID", -1]) != _sideID) then {
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
	if ([_team, "wfbe_aicom_dispatch_open", false] Call WFBE_CO_FNC_GroupGetBool) then {
		private ["_dord","_dtgt","_dt0","_dldr","_ddist","_arrR","_toSecs","_elapsed","_bandKey","_bandVal"];
		_dord = [_team, "wfbe_aicom_townorder", []] Call WFBE_CO_FNC_GroupGetBool;
		if (count _dord >= 2) then {
			_dtgt = _dord select 0;
			_dt0  = _dord select 1;
			if (typeName _dtgt == "OBJECT" && {!isNull _dtgt}) then {
				_dldr   = leader _team;
				_ddist  = _dldr distance _dtgt;
				_arrR   = missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_ARRIVE_RADIUS", 250];
				_toSecs = if (count _dord >= 4) then {_dord select 3} else {missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_TIMEOUT", 420]};   //--- FIX A (fable, GR-2026-07-08a): per-dispatch dyn-timeout if the 4th tuple element is present (WFBE_C_AICOM_ASSAULT_DYNTIMEOUT), else legacy flat default. _dord already declared/guarded count>=2 above.
				_elapsed = round (time - _dt0);
				if (_ddist <= _arrR) then {
					//--- WASPSCALE arrv counter (cmdcon42): bump the cumulative-arrival counter the server-side WASPSCALE emit reads (arrv=). One per successful journey (latched once per dispatch by wfbe_aicom_dispatch_open). Server-local, monotonic.
					missionNamespace setVariable ["wfbe_waspscale_arrv", (missionNamespace getVariable ["wfbe_waspscale_arrv", 0]) + 1];
					//--- Lane 362: bucket successful journey latency for the next supervisor-window histogram.
					_bandKey = "wfbe_aicom_arrival_slow";
					if (_elapsed < 300) then {_bandKey = "wfbe_aicom_arrival_fast"} else {if (_elapsed < 600) then {_bandKey = "wfbe_aicom_arrival_med"}};
					_bandVal = _logik getVariable [_bandKey, 0];
					_logik setVariable [_bandKey, _bandVal + 1];
					diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|ASSAULT_ARRIVED|team=" + (str _team) + "|town=" + (_dtgt getVariable ["name","town"]) + "|dist=" + str (round _ddist) + "|elapsed=" + str _elapsed);
					_team setVariable ["wfbe_aicom_dispatch_open", false];
					//--- r40 intel freshness: arrival proves reachability - clear side-abandon memory for this town.
					if ((missionNamespace getVariable ["WFBE_C_AICOM_SIDE_BLACKLIST", 1]) > 0) then {
						private ["_sbaArr","_sbaArrKeep"];
						_sbaArr = _logik getVariable ["wfbe_aicom_side_abandons", []];
						_sbaArrKeep = [];
						{ if ((typeName (_x select 0) == "OBJECT") && {!isNull (_x select 0)} && {(_x select 0) != _dtgt}) then {_sbaArrKeep set [count _sbaArrKeep, _x]} } forEach _sbaArr;
						if ((count _sbaArrKeep) != (count _sbaArr)) then {_logik setVariable ["wfbe_aicom_side_abandons", _sbaArrKeep]};
					};
					//--- FAILED-JOURNEY RECYCLE (cmdcon41-w2, claude-gaming 2026-07-02): the team reached a town
					//--- this dispatch - a successful journey. Reset its failed-journey counter AND its per-pass
					//--- orbiter watch state so a fresh leg starts clean. A2-OA-safe (plain setVariable).
					_team setVariable ["wfbe_aicom_failedjourneys", 0];
					_team setVariable ["wfbe_aicom_orbitwatchdist", nil];
					_team setVariable ["wfbe_aicom_orbitnoprog", 0];
				} else {
					//--- ORBITER DETECT (cmdcon41-w3-orbiter, claude-gaming 2026-07-02, gate WFBE_C_AICOM_ORBITER_DETECT default 0):
					//--- a team permanently entangled with GUER en route is in behaviour "COMBAT", moves constantly,
					//--- and closes on the target never - it is invisible to the position-stuck ladder below (which
					//--- exempts COMBAT). When WFBE_C_AICOM_ORBITER_DETECT > 0: on each watcher pass, if the leader
					//--- is in COMBAT AND dist-to-target has NOT dropped >= 100m since the last recorded watch dist,
					//--- count it as a no-progress window; after N consecutive such windows (WFBE_C_AICOM_ORBITER_WIN,
					//--- default 4) treat it as stuck (bump the SAME strike ladder + log ORBITER_STUCK). Per-team
					//--- state via plain getVariable + isNil (group [name,default] getVariable is unreliable on groups).
					//--- The COMBAT exempt on the position-stuck telemetry below is KEPT. Flag 0 = feature dark.
					//--- A2-OA-safe: behaviour exact-case string compare, numeric distance, no A3 commands.
					if ((missionNamespace getVariable ["WFBE_C_AICOM_ORBITER_DETECT", 0]) > 0) then {
						private ["_owDistPrev","_owNoProg","_owWin","_owStrk"];
						_owDistPrev = _team getVariable "wfbe_aicom_orbitwatchdist";
						_owNoProg   = _team getVariable "wfbe_aicom_orbitnoprog";
						if (isNil "_owNoProg") then {_owNoProg = 0};
						_owWin = missionNamespace getVariable ["WFBE_C_AICOM_ORBITER_WIN", 4];
						if (behaviour _dldr == "COMBAT") then {
							if (isNil "_owDistPrev") then {
								_owNoProg = 0; //--- first COMBAT window on this dispatch: seed the baseline, no verdict yet.
							} else {
								if ((_owDistPrev - _ddist) >= 100) then {
									_owNoProg = 0; //--- closed >= 100m since last watch: real progress despite the firefight.
								} else {
									_owNoProg = _owNoProg + 1;
								};
							};
							_team setVariable ["wfbe_aicom_orbitwatchdist", _ddist];
							_team setVariable ["wfbe_aicom_orbitnoprog", _owNoProg];
							if (_owNoProg >= _owWin) then {
								_owStrk = _team getVariable "wfbe_aicom_stuckstrikes";
								if (isNil "_owStrk") then {_owStrk = 0};
								_owStrk = _owStrk + 1;
								_team setVariable ["wfbe_aicom_stuckstrikes", _owStrk];
								_team setVariable ["wfbe_aicom_orbitnoprog", 0]; //--- consume the verdict; re-earn a fresh window.
								diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|ORBITER_STUCK|team=" + (str _team) + "|town=" + (_dtgt getVariable ["name","town"]) + "|dist=" + str (round _ddist) + "|strike=" + str _owStrk);
							};
						} else {
							//--- Not in COMBAT this pass: clear the orbiter window so a later COMBAT entanglement earns a clean window.
							_team setVariable ["wfbe_aicom_orbitwatchdist", nil];
							_team setVariable ["wfbe_aicom_orbitnoprog", 0];
						};
					};
					if ((time - _dt0) > _toSecs) then {
						private ["_moved","_stuck"];
						_moved = -1;
						if (count _dord >= 3) then {_moved = _dldr distance (_dord select 2)};
						_stuck = (behaviour _dldr != "COMBAT") && {_moved >= 0} && {_moved < (missionNamespace getVariable ["WFBE_C_AICOM_STUCK_MOVED", 200])};
						diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|ASSAULT_STRANDED|team=" + (str _team) + "|town=" + (_dtgt getVariable ["name","town"]) + "|dist=" + str (round _ddist) + "|elapsed=" + str _elapsed + "|moved=" + str (round _moved) + "|stuck=" + str _stuck);
						if ((missionNamespace getVariable ["WFBE_C_AICOM_STRAND_RECOVERY", 0]) > 0 && {_moved >= 0} && {_moved < 200}) then {
							_team setVariable ["wfbe_aicom_strand_recovery_pending", true];
							_team setVariable ["wfbe_aicom_strand_recovery_target", _dtgt];
						};
						_team setVariable ["wfbe_aicom_dispatch_open", false];
						//--- FAILED-JOURNEY RECYCLE (cmdcon41-w2, F4b): a STRANDED closure is a failed journey.
						//--- Tally it and, at the terminal threshold, latch wfbe_aicom_recycle so the consumer retires
						//--- and refounds this zombie team elsewhere (never here, never near a player). The same
						//--- increment+latch idiom is repeated verbatim on both TARGET_ABANDON paths (kept inline,
						//--- not factored, to stay A2-OA-safe - no code-block passing). A2-OA-safe (plain setVariable).
						private ["_fjS","_fjThrS"];
						_fjS = ([_team, "wfbe_aicom_failedjourneys", 0] Call WFBE_CO_FNC_GroupGetBool) + 1;
						_team setVariable ["wfbe_aicom_failedjourneys", _fjS];
						if ((missionNamespace getVariable ["WFBE_C_AICOM_RETARGET_RECYCLE", 0]) > 0) then {_team setVariable ["wfbe_aicom_journey_failed_counted", true]};
						//--- STRAND FAST-TRACK (wasp-hc-delegation-collapse-20260722, gate WFBE_C_AICOM_STRAND_FASTRECYCLE
						//--- default 0): a team that burned the WHOLE (dyn)timeout while moving under
						//--- WFBE_C_AICOM_STRAND_FAST_MOVED m from its journey start is not slow, it is wedged (live
						//--- wave0722g: distStart=0 teams held slots for hours at up to 2700s DYNTIMEOUT x 6 journeys).
						//--- Count the STRANDED closure DOUBLE so WFBE_C_AICOM_FAILED_JOURNEYS_RECYCLE latches in half
						//--- the journeys. _moved is computed above in this same closure. Flag 0 = byte-identical +1 path.
						if (((missionNamespace getVariable ["WFBE_C_AICOM_STRAND_FASTRECYCLE", 0]) > 0) && {_moved >= 0} && {_moved < (missionNamespace getVariable ["WFBE_C_AICOM_STRAND_FAST_MOVED", 50])}) then {
							_fjS = _fjS + 1;
							_team setVariable ["wfbe_aicom_failedjourneys", _fjS];
							diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|STRAND_FASTTRACK|team=" + (str _team) + "|moved=" + str (round _moved) + "|failedjourneys=" + str _fjS);
						};
						_fjThrS = missionNamespace getVariable ["WFBE_C_AICOM_FAILED_JOURNEYS_RECYCLE", 0];
						if (_fjThrS > 0 && {_fjS >= _fjThrS} && {!([_team, "wfbe_aicom_recycle", false] Call WFBE_CO_FNC_GroupGetBool)}) then {
							_team setVariable ["wfbe_aicom_recycle", true, true];
							diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|RECYCLE_FLAG|team=" + (str _team) + "|failedjourneys=" + str _fjS + "|reason=stranded");
							//--- WASPSCALE aband counter (feat/abandon-telemetry): cumulative abandon/recycle events this match, read by the AI_Commander.sqf WASPSCALE emit (aband=). Counter-only, no behaviour change.
							missionNamespace setVariable ["wfbe_waspscale_aband", (missionNamespace getVariable ["wfbe_waspscale_aband", 0]) + 1];
						};
					};
				};
			} else {
				//--- Target captured/null (e.g. Strategy cleared the order): close the latch silently.
				_team setVariable ["wfbe_aicom_dispatch_open", false];
			};
		};
	};
	_autonomous = [_team, "wfbe_autonomous", false] Call WFBE_CO_FNC_GroupGetBool;
	_modeNow = toLower ([_team, "wfbe_teammode", "towns"] Call WFBE_CO_FNC_GroupGetBool);
	_footStage = [_team, "wfbe_aicom_foot_stage", false] Call WFBE_CO_FNC_GroupGetBool;
	_footStagePos = [_team, "wfbe_aicom_foot_stage_pos", []] Call WFBE_CO_FNC_GroupGetBool;
	_stageGoto = [_team, "wfbe_teamgoto", []] Call WFBE_CO_FNC_GroupGetBool;
	if (_footStage && {(_modeNow != "move") || {typeName _footStagePos != "ARRAY"} || {typeName _stageGoto != "ARRAY"} || {count _footStagePos < 2} || {count _stageGoto < 2} || {(_stageGoto distance _footStagePos) > 5}}) then {
		_footStage = false;
		_team setVariable ["wfbe_aicom_foot_stage", false];
		_team setVariable ["wfbe_aicom_foot_stage_pos", []];
	};

	//--- COMBAT-LOSS RETREAT LATCH (Grok #1, claude/u3-loss-retreat-20260725, gate WFBE_C_AICOM_LOSS_RETREAT
	//--- default 0): an AICOM team grinding an ASSAULT-type order ("towns" mode - the SAME exact-case lowercase
	//--- mode string this file's own sticky-order check reads a few lines below) that bleeds out fast, losing
	//--- >= a configurable FRACTION of its living strength within a sliding sample window, is thrashing the
	//--- same target instead of withdrawing. Piggybacks the alive-count THIS worker pass already computed
	//--- (_aliveCount, L84) against a single stored [count,time] snapshot on the team - no new nearEntities/unit
	//--- scan, one extra getVariable read + one setVariable write per team per pass. On latch: stamp
	//--- wfbe_aicom_wantrally - the SAME broadcast flag Common_RunCommanderTeam's depot-hold BREAKOFF already
	//--- raises (cmdcon41-w2) - so the EXISTING GRACEFUL WITHDRAWAL EVALUATOR in AI_Commander_Strategy.sqf
	//--- (L751-822) picks it up, resolves the nearest friendly HQ/town, and issues the proven "rally" bounding-
	//--- withdrawal order; we do not duplicate that town-selection or the SML retreat/rally machinery. A
	//--- dedicated cooldown stamp (WFBE_C_AICOM_LOSS_RETREAT_COOLDOWN, default 180s) gates RE-arming this
	//--- SPECIFIC trigger per team so a team that just rallied cannot immediately re-latch next pass while still
	//--- under-strength; the consumer's OWN cooldown (WFBE_C_AICOM_WITHDRAW_COOLDOWN, 240s) separately gates
	//--- its shared understrength auto-trigger - the two stamps are independent by design, same pattern as the
	//--- existing wantrally/rallying pair. wfbe_aicom_lossretreat_prevcount/prevtime/cooldown_until are reset to
	//--- nil at team founding in Common_RunCommanderTeam.sqf (A2 recycles group slots - same stack-pass idiom as
	//--- wfbe_aicom_decap/press_on there) so a re-founded team never inherits a stale snapshot.
	//--- Self-gates: flag on, team not player-led, ASSAULT-type ("towns") order only, not already mid-rally or
	//--- already wanting one, cooldown elapsed. Same-scope caveat as the existing BREAKOFF producer: the
	//--- consumer only reads wantrally for HC-resident teams (Strategy.sqf L769 _gwHc gate) - non-HC
	//--- (Produce-driven) teams still stamp the flag (harmless, matches the BREAKOFF contract) but rely on the
	//--- separate Produce retreat/cull path for their own withdrawal, unchanged by this feature.
	//--- A2-OA-safe: plain 1-arg getVariable + isNil (GROUP vars never use the 2-arg [name,default] form here),
	//--- numeric compares only, no A3 commands, no sleeps, no loops beyond the per-team forEach this already
	//--- sits inside. Flag 0 = one cheap missionNamespace getVariable+compare per team per pass (same negligible
	//--- gate idiom every other flag check in this file already pays, e.g. the HELI_CANNON_NUDGE gate in
	//--- Common_RunCommanderTeam.sqf) - no team-var reads/writes, no state mutation, behaviourally inert.
	if ((missionNamespace getVariable ["WFBE_C_AICOM_LOSS_RETREAT", 0]) > 0 && {!([leader _team, false] Call WFBE_CO_FNC_IsRealPlayer)} && {_modeNow == "towns"}) then {
		private ["_lrPrev","_lrPrevT","_lrWindow","_lrThresh","_lrCoolUntil","_lrRallying","_lrWant","_lrFrac"];
		_lrWindow = missionNamespace getVariable ["WFBE_C_AICOM_LOSS_RETREAT_WINDOW", 120];
		_lrThresh = missionNamespace getVariable ["WFBE_C_AICOM_LOSS_RETREAT_FRACTION", 0.5];
		_lrPrev  = _team getVariable "wfbe_aicom_lossretreat_prevcount";
		_lrPrevT = _team getVariable "wfbe_aicom_lossretreat_prevtime";
		if (!isNil "_lrPrev" && {!isNil "_lrPrevT"} && {(time - _lrPrevT) <= _lrWindow} && {_lrPrev > 0} && {_aliveCount < _lrPrev}) then {
			_lrRallying = _team getVariable "wfbe_aicom_rallying"; if (isNil "_lrRallying") then {_lrRallying = false};
			_lrWant = _team getVariable "wfbe_aicom_wantrally"; if (isNil "_lrWant") then {_lrWant = false};
			_lrCoolUntil = _team getVariable "wfbe_aicom_lossretreat_cooldown_until"; if (isNil "_lrCoolUntil") then {_lrCoolUntil = 0};
			_lrFrac = (_lrPrev - _aliveCount) / _lrPrev;
			if (!_lrRallying && {!_lrWant} && {time >= _lrCoolUntil} && {_lrFrac >= _lrThresh}) then {
				_team setVariable ["wfbe_aicom_wantrally", true, true];
				_team setVariable ["wfbe_aicom_lossretreat_cooldown_until", time + (missionNamespace getVariable ["WFBE_C_AICOM_LOSS_RETREAT_COOLDOWN", 180])];
				//--- wfbe_waspscale_aband-style cumulative counter (cmdcon42 pattern, mirrors wfbe_waspscale_arrv at L105): trivially reachable via the same broadcast-namespace idiom the arrival counter already uses.
				missionNamespace setVariable ["wfbe_waspscale_lossretreat", (missionNamespace getVariable ["wfbe_waspscale_lossretreat", 0]) + 1];
				diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|LOSS_RETREAT_LATCH|team=" + (str _team) + "|prev=" + str _lrPrev + "|now=" + str _aliveCount + "|frac=" + str (round (_lrFrac * 100)) + "|window=" + str _lrWindow);
				["INFORMATION", Format ["AI_Commander_AssignTowns.sqf: [%1] team [%2] LOSS_RETREAT latch (%3 -> %4 alive within %5s) - requesting rally.", _sideText, _team, _lrPrev, _aliveCount, _lrWindow]] Call WFBE_CO_FNC_AICOMLog;
			};
		};
		_team setVariable ["wfbe_aicom_lossretreat_prevcount", _aliveCount];
		_team setVariable ["wfbe_aicom_lossretreat_prevtime", time];
	};

	_canDrive = false;
	_explicitMode = false;
	//--- MANUAL-PIN (Build83, claude-gaming 2026-07-01): a team a HUMAN just ordered from the war-room console
	//--- (Move/Defend/Patrol / ALL-HOLD) stamps wfbe_aicom_manualpin=time on the group. While that pin is FRESH
	//--- (< WFBE_C_AICOM_MANUALPIN_TTL, default 600s) treat the team as under an explicit order so this 120s tick
	//--- does NOT re-grab it - killing the console-vs-AI thrash. TTL-bounded so a stale pin from a disconnected
	//--- commander expires and the team is auto-driven again (it still holds its last live waypoint meanwhile;
	//--- never permanently idle). RELEASE / ALL-PUSH clear the pin client-side. A2-OA-safe (plain getVariable, time).
	_pin = _team getVariable "wfbe_aicom_manualpin";
	if (!isNil "_pin" && {(time - _pin) < (missionNamespace getVariable ["WFBE_C_AICOM_MANUALPIN_TTL", 600])}) then {_explicitMode = true};
	if (_modeNow == "move" && {!_footStage}) then {_explicitMode = true};
	if (_modeNow == "patrol") then {_explicitMode = true};
	if (_modeNow == "defense") then {_explicitMode = true};
	//--- r27 ownership: logistics self-service detour owns the group while enroute (Common_AICOMServiceTick).
	//--- Treat as explicit so this worker does not re-book an assault townorder and thrash waypoints.
	private "_svcStateAT";
	_svcStateAT = _team getVariable "wfbe_aicom_svcstate";
	if (!isNil "_svcStateAT" && {_svcStateAT == "enroute"}) then {_explicitMode = true};
	//--- Owner ruling: clear legacy standing defense/garrison posture on each worker pass; active relief and an active capture hold remain explicit below.
	if ((missionNamespace getVariable ["WFBE_C_AICOM_ALWAYS_OFFENSE", 1]) > 0 && {_modeNow == "defense"} && {!_humanCmd}) then {
		private ["_legacyRelief","_legacyHold"];
		_legacyRelief = [_team, "wfbe_aicom_relief", objNull] Call WFBE_CO_FNC_GroupGetBool;
		_legacyHold = _team getVariable "wfbe_aicom_holding_town";
		if (isNull _legacyRelief && {isNil "_legacyHold" || {isNull _legacyHold}}) then {
			[_team, "towns"] Call SetTeamMoveMode;
			_team setVariable ["wfbe_teamgoto", objNull, true];
			_team setVariable ["wfbe_aicom_townorder", [], false];
			_modeNow = "towns";
			_explicitMode = false;
			if ([_team, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool) then {
				_team setVariable ["wfbe_aicom_order", [(if (isNil {_team getVariable "wfbe_aicom_order"}) then {-1} else {(_team getVariable "wfbe_aicom_order") select 0}) + 1, "towns", getPos (leader _team)], true];
			};
		};
	};

	//--- CONSOLIDATE SKIP (per-team, Ray): during the post-capture hold window, a team that has ARRIVED at a FIST
	//--- alloc_target is deliberately regrouping - preserve its current orders (treat as explicit) so it is NOT
	//--- re-tasked this pass. Teams en-route (alloc_target set but not yet within _consolRad), the harasser
	//--- (alloc_target NOT in the fist), relief and human-led teams fall through and re-task normally. A2-OA-safe.
	if (_consolidating && {!isNull _team}) then {
		_allocTgt = _team getVariable "wfbe_aicom_alloc_target";
		if (!isNil "_allocTgt" && {typeName _allocTgt == "OBJECT"} && {!isNull _allocTgt} && {_allocTgt in _fistSet}) then {
			if (!isNull (leader _team) && {((leader _team) distance _allocTgt) <= _consolRad}) then {_explicitMode = true};
		};
	};

	//--- Drive only if AI-controllable (no human, or human delegated this team) AND the executor doesn't own it.
	if (_aliveCount > 0) then {
		if (!([leader _team, false] Call WFBE_CO_FNC_IsRealPlayer)) then {
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
		if (((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_GARRISON", 0]) > 0) && {(missionNamespace getVariable ["WFBE_C_AICOM_ALWAYS_OFFENSE", 1]) <= 0} && {!_humanCmd} && {!_explicitMode} && {_aliveCount > 0}) then {
			_gar = _logik getVariable ["wfbe_aicom_garrison", grpNull];
			_garDead = true;
			_garAlive = 0;
			if (!isNull _gar) then {
				_garAlive = {alive _x} count (units _gar);
				if (_garAlive > 0) then {_garDead = false};
			};
			if (_garDead) then {
				_hqG = (_side) Call WFBE_CO_FNC_GetSideHQ;
				if (!isNull _hqG) then {
					[_team, "defense"] Call SetTeamMoveMode;
					[_team, getPos _hqG] Call SetTeamMovePos;
					//--- V0.3: HC-resident teams get their orders via the public order variable.
					if ([_team, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool) then {
						_team setVariable ["wfbe_aicom_order", [(if (isNil {_team getVariable "wfbe_aicom_order"}) then {-1} else {(_team getVariable "wfbe_aicom_order") select 0}) + 1, "defense", getPos _hqG], true];
					};
					_logik setVariable ["wfbe_aicom_garrison", _team];
					diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|GARRISON_REASSIGN|team=" + (str _team) + "|previous=" + (str _gar) + "|prevAlive=" + str _garAlive + "|hq=" + (str _hqG));
					_explicitMode = true; //--- now an explicit order; the executor drives it home
					["INFORMATION", Format ["AI_Commander_AssignTowns.sqf: [%1] team [%2] assigned as base garrison.", _sideText, _team]] Call WFBE_CO_FNC_AICOMLog;
				};
			};
		};
		//--- HOLD SKIP-RETARGET (cmdcon41, claude-gaming 2026-07-02): the FIRST captor of a town claims a short
		//--- DEFEND hold (latched in Common_RunCommanderTeam on capture: team var wfbe_aicom_holding_town = the
		//--- town, town var wfbe_aicom_hold_until = expiry). While that latch is LIVE - the held town is still
		//--- ours and either the original timer/gate remains live or hostile [active attack] contact persists - treat the team as explicitly
		//--- ordered so this tick does NOT retarget it off the centre mid-fight (stops the see-saw). Once the town flips back, or the quiet
		//--- timer expires, the latch is CLEARED and the team retargets normally. A2-OA-safe (plain getVariable + isNil guard, typeName
		//--- OBJECT test, numeric sideID compare, objNull broadcast clear).
		if ((missionNamespace getVariable ["WFBE_C_AICOM_HOLD_MODE", 1]) > 0) then {
			private ["_ht","_htLive","_htSide","_htUntil","_htEnemyDist","_htUnderAttack"];
			_ht = _team getVariable "wfbe_aicom_holding_town";
			_htLive = false;
			if (!isNil "_ht") then {
				if (typeName _ht == "OBJECT" && {!isNull _ht}) then {
					_htSide = _ht getVariable ["sideID", -1];
					_htUntil = _ht getVariable ["wfbe_aicom_hold_until", 0];
					_htEnemyDist = missionNamespace getVariable [format ["WFBE_C_AICOM_RELIEF_ENEMY_DIST_%1", _side], missionNamespace getVariable ["WFBE_C_AICOM_RELIEF_ENEMY_DIST", 500]];
					_htUnderAttack = false;
					if ((_ht getVariable ["wfbe_active", false]) && {({alive _x && {(side _x) != _side && {(side _x) != civilian}}} count ((getPos _ht) nearEntities [["Man","LandVehicle","Air"], _htEnemyDist])) > 0}) then {_htUnderAttack = true};
					if (_htSide == _sideID && {((time < _htUntil) && {((missionNamespace getVariable ["WFBE_C_AICOM_ALWAYS_OFFENSE", 1]) <= 0) || {_htUnderAttack}}) || {_htUnderAttack}}) then {_htLive = true};
				};
			};
			if (_htLive) then {
				_explicitMode = true;
			} else {
				if (!isNil "_ht") then {
					if (typeName _ht == "OBJECT" && {!isNull _ht}) then {
						if (_htSide != _sideID) then {
							diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|HOLD_TOWN_LOST|team=" + (str _team) + "|town=" + (_ht getVariable ["name","town"]) + "|townSide=" + str _htSide + "|remaining=" + str (round (_htUntil - time)));
						};
					};
				};
				_team setVariable ["wfbe_aicom_holding_town", objNull, true];
				//--- Active-attack holds release immediately when hostile contact is gone, including under a human commander; respect a fresh manual pin.
				if ((missionNamespace getVariable ["WFBE_C_AICOM_ALWAYS_OFFENSE", 1]) > 0 && {_modeNow == "defense"} && {isNull ([_team, "wfbe_aicom_relief", objNull] Call WFBE_CO_FNC_GroupGetBool)} && {isNil "_pin" || {(time - _pin) >= (missionNamespace getVariable ["WFBE_C_AICOM_MANUALPIN_TTL", 600])}}) then {
					[_team, "towns"] Call SetTeamMoveMode;
					_team setVariable ["wfbe_teamgoto", objNull, true];
					_team setVariable ["wfbe_aicom_townorder", [], false];
					_explicitMode = false;
					_modeNow = "towns";
					if ([_team, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool) then {
						_team setVariable ["wfbe_aicom_order", [(if (isNil {_team getVariable "wfbe_aicom_order"}) then {-1} else {(_team getVariable "wfbe_aicom_order") select 0}) + 1, "towns", getPos (leader _team)], true];
					};
				};
			};
		};
		if (!_explicitMode) then {
			_mode = [_team, "wfbe_teammode", ""] Call WFBE_CO_FNC_GroupGetBool;
			_goto = [_team, "wfbe_teamgoto", objNull] Call WFBE_CO_FNC_GroupGetBool;
			if (_footStage) then {_mode = "towns"; _goto = objNull};

			//--- V0.4.2 churn fix: orders are STICKY. Retarget only when the team has no
			//--- valid enemy-town target, the target resolved (we captured it), or the team
			//--- has been visibly stuck on the same order for 10+ min without progress.
			//--- Distance alone is NOT a reason - en-route teams keep their order.
			_needs = false;
			_strandRecovery = false;
			_strandTarget = objNull;
			//--- AI-BEHAVIOR-LOOP-DESIGN.md sec2.2: 4th sibling abandon trigger, structurally BEFORE both ASSAULT-DYNTIMEOUT-DESIGN.md Fix A insertion sites (the _toSecs read + the townorder dispatch-tuple write) and outside the wfbe_aicom_dispatch_open branch entirely - no line overlap, no shared local beyond _needs/_sideText/time this loop already reads. Fires regardless of position-stuck state (a team happily clearing camp-to-camp is never position-stuck, so it would never trip STUCK_ABANDON, yet can still be cumulatively lingering).
			if ((missionNamespace getVariable ["WFBE_C_AICOM_DWELL_ENABLE", 0]) > 0) then {
				private ["_dwArr","_dwTgt","_dwT0","_dwCum"];
				_dwArr = _team getVariable "wfbe_aicom_dwell_town0";
				if (!isNil "_dwArr" && {typeName _dwArr == "ARRAY"} && {count _dwArr >= 2}) then {
					_dwTgt = _dwArr select 0; _dwT0 = _dwArr select 1;
					if (typeName _dwTgt == "OBJECT" && {!isNull _dwTgt} && {(_dwTgt getVariable ["sideID", -1]) != _sideID}) then {
						_dwCum = time - _dwT0;
						if (_dwCum > (missionNamespace getVariable ["WFBE_C_AICOM_DWELL_MAX_SECS", 900])) then {
							_needs = true;
							private ["_dwCd","_dwBl","_dwKeep"];
							_dwCd = missionNamespace getVariable ["WFBE_C_AICOM_BLACKLIST_COOLDOWN", 600];
							_dwBl = [_team, "wfbe_aicom_blacklist", []] Call WFBE_CO_FNC_GroupGetBool;
							_dwKeep = [];
							{ if ((typeName (_x select 0) == "OBJECT") && {!isNull (_x select 0)} && {(_x select 1) > time} && {(_x select 0) != _dwTgt}) then {_dwKeep set [count _dwKeep, _x]} } forEach _dwBl;
							_dwKeep set [count _dwKeep, [_dwTgt, time + _dwCd]];
							_team setVariable ["wfbe_aicom_blacklist", _dwKeep];
							_team setVariable ["wfbe_aicom_stuckstrikes", 0];
							_team setVariable ["wfbe_aicom_dwell_town0", nil];
							diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|DWELL_ABANDON|team=" + (str _team) + "|town=" + (_dwTgt getVariable ["name","town"]) + "|cumDwell=" + str (round _dwCum));
							//--- WASPSCALE aband counter (feat/abandon-telemetry): cumulative abandon/recycle events this match, read by the AI_Commander.sqf WASPSCALE emit (aband=). Counter-only, no behaviour change.
							missionNamespace setVariable ["wfbe_waspscale_aband", (missionNamespace getVariable ["wfbe_waspscale_aband", 0]) + 1];
							//--- FAILED-JOURNEY RECYCLE: same tally+latch idiom already copy-pasted in this file (STUCK_ABANDON/stall-advance/uncapturable blocks) - 5th copy, not a new pipeline. Also closes the design doc's own finding that capture-side releases were previously invisible to this counter.
							private ["_fjD","_fjThrD"];
							_fjD = ([_team, "wfbe_aicom_failedjourneys", 0] Call WFBE_CO_FNC_GroupGetBool) + 1;
							_team setVariable ["wfbe_aicom_failedjourneys", _fjD];
							if ((missionNamespace getVariable ["WFBE_C_AICOM_RETARGET_RECYCLE", 0]) > 0) then {_team setVariable ["wfbe_aicom_journey_failed_counted", true]};
							_fjThrD = missionNamespace getVariable ["WFBE_C_AICOM_FAILED_JOURNEYS_RECYCLE", 0];
							if (_fjThrD > 0 && {_fjD >= _fjThrD} && {!([_team, "wfbe_aicom_recycle", false] Call WFBE_CO_FNC_GroupGetBool)}) then {
								_team setVariable ["wfbe_aicom_recycle", true, true];
								diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|RECYCLE_FLAG|team=" + (str _team) + "|failedjourneys=" + str _fjD + "|reason=dwell");
								//--- WASPSCALE aband counter (feat/abandon-telemetry): cumulative abandon/recycle events this match, read by the AI_Commander.sqf WASPSCALE emit (aband=). Counter-only, no behaviour change.
								missionNamespace setVariable ["wfbe_waspscale_aband", (missionNamespace getVariable ["wfbe_waspscale_aband", 0]) + 1];
							};
						};
					} else {
						_team setVariable ["wfbe_aicom_dwell_town0", nil];
					};
				};
			};
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
							_ord = [_team, "wfbe_aicom_townorder", []] Call WFBE_CO_FNC_GroupGetBool;
							if (count _ord < 3 || {(_ord select 0) != _goto}) then {
								//--- No bookkeeping yet (legacy order) or goto changed under us: book it
								//--- once without re-issuing waypoints; the stuck check takes over from here.
								_team setVariable ["wfbe_aicom_townorder", [_goto, time, getPos (leader _team)]];
								//--- STALL-ADVANCE FLOOR (Build84, claude-gaming 2026-07-02): stamp the "on this goto
								//--- since" clock the moment a NEW/changed goto is booked. The uncap-parked branch below
								//--- reads it to force a prompt retarget when a team parks on an unflippable depot for
								//--- longer than WFBE_C_AICOM_STALL_ADVANCE_SECS even if the strike counter never accrues.
								_team setVariable ["wfbe_aicom_goto_since", time];
							} else {
								if (time - (_ord select 1) > (missionNamespace getVariable ["WFBE_C_AICOM_STUCK_SECS", 210])) then {
									private ["_ldr","_movedThr","_farThr","_airborne","_goalDeltaOn","_notProgressing"]; //--- claude/aicom-west-stuck: +2 privates for the goal-delta stuck test below
									_ldr = leader _team;
									_movedThr = missionNamespace getVariable ["WFBE_C_AICOM_STUCK_MOVED", 200];
									_farThr   = missionNamespace getVariable ["WFBE_C_AICOM_STUCK_FAR", 300];
									//--- cmdcon42-f AIR-MOBILE EXEMPTION: a team FLYING an air-mobile leg is progressing, not
									//--- stuck - its leader rides the transport and may hover/idle near the breadcrumb while boarding
									//--- or on the run-in, which the position-stuck gate below would misread as parked-and-stuck and
									//--- (at the terminal tier) TELEPORT a flying leader. Exempt it: EITHER the leg-runner's broadcast
									//--- wfbe_aicom_airborne_until window is still open, OR the leader is physically inside an aircraft.
									//--- A2-OA-safe: getVariable [name,default] on a GROUP is illegal, so read + isNil-guard; isKindOf "Air".
									_airborne = false;
									private ["_amUntil"]; _amUntil = _team getVariable "wfbe_aicom_airborne_until"; if (isNil "_amUntil") then {_amUntil = 0};
									if (_amUntil > time) then {_airborne = true};
									if (!_airborne && {!isNull _ldr} && {(vehicle _ldr) != _ldr} && {(vehicle _ldr) isKindOf "Air"}) then {_airborne = true};
									//--- In-contact teams are legitimately stationary (firefight/bounding); never
									//--- treat as stuck - refresh the breadcrumb so they keep fighting.
									//--- claude/aicom-west-stuck: GOAL-DELTA stuck test (root-cause fix, flag WFBE_C_AICOM_STUCK_GOALDELTA,
									//--- claude/aicom-west-stuck: default 0 = legacy raw-displacement test, byte-identical). Common_AICOM_HighClimb.sqf
									//--- claude/aicom-west-stuck: setVelocity-boosts a wedged hull every tick on pure kinematics, which alone can
									//--- claude/aicom-west-stuck: manufacture >= _movedThr of RAW leader displacement (jitter/slide) with ZERO net
									//--- claude/aicom-west-stuck: closing on _goto - the legacy test read that as progress and hard-reset
									//--- claude/aicom-west-stuck: wfbe_aicom_stuckstrikes, so RECOVERY_V2 never escalated past Tier-1. When the flag
									//--- claude/aicom-west-stuck: is on, progress instead means how far DISTANCE-TO-TARGET closed since the
									//--- claude/aicom-west-stuck: breadcrumb: (_goto distance breadcrumb) minus (_goto distance _ldr). A slow-but-real
									//--- claude/aicom-west-stuck: climber (10-28 km/h up a long ridge) closes on _goto and is NOT penalised; only
									//--- claude/aicom-west-stuck: motion that never translates into closing distance now fails. Both distance operand
									//--- claude/aicom-west-stuck: orders are already live in this file (object distance breadcrumb, object distance obj).
									//--- claude/aicom-west-stuck: A2-OA-safe: numeric subtraction, no ==/!= on Booleans, no A3 commands, no group 2-arg getVariable.
									_goalDeltaOn = (missionNamespace getVariable ["WFBE_C_AICOM_STUCK_GOALDELTA", 0]) > 0;
									_notProgressing = if (_goalDeltaOn) then {((_goto distance (_ord select 2)) - (_goto distance _ldr)) < _movedThr} else {(_ldr distance (_ord select 2)) < _movedThr};
									if ((!_airborne) && {behaviour _ldr != "COMBAT"} && {_notProgressing} && {_ldr distance _goto > _farThr}) then {
										_needs = true; //--- parked far from target, not in contact: re-issue (unstick)
										//--- REAL UNSTUCK (task #14/#16): the old remedy just re-emitted the same
										//--- un-followable order. Bump a per-team STRIKE counter so the HC executor
										//--- escalates Tier1 (reverse+reposition) -> Tier2 (road re-path) -> Tier3
										//--- (teleport-nudge to nearest clear road node, no player nearby). The strike
										//--- rides on the order broadcast below; the executor reads wfbe_aicom_unstuck.
										private ["_strk"];
										_strk = ([_team, "wfbe_aicom_stuckstrikes", 0] Call WFBE_CO_FNC_GroupGetBool) + 1; //--- fix(hunt): G1-safe (nil+1 threw for stuck-since-spawn teams, so the unstick ladder never started)
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
											_abBl = [_team, "wfbe_aicom_blacklist", []] Call WFBE_CO_FNC_GroupGetBool;
											//--- prune expired entries + drop any prior entry for _goto, then add a fresh one.
											_abKeep = [];
											{ if ((typeName (_x select 0) == "OBJECT") && {!isNull (_x select 0)} && {(_x select 1) > time} && {(_x select 0) != _goto}) then {_abKeep set [count _abKeep, _x]} } forEach _abBl;
											_abKeep set [count _abKeep, [_goto, time + _abCd]];
											_team setVariable ["wfbe_aicom_blacklist", _abKeep];
											_team setVariable ["wfbe_aicom_stuckstrikes", 0];
											diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|TARGET_ABANDON|team=" + (str _team) + "|town=" + (_goto getVariable ["name","town"]) + "|cooldown=" + str _abCd);
											//--- WASPSCALE aband counter (feat/abandon-telemetry): cumulative abandon/recycle events this match, read by the AI_Commander.sqf WASPSCALE emit (aband=). Counter-only, no behaviour change.
											missionNamespace setVariable ["wfbe_waspscale_aband", (missionNamespace getVariable ["wfbe_waspscale_aband", 0]) + 1];
											//--- FAILED-JOURNEY RECYCLE (cmdcon41-w2, F4b): a TARGET_ABANDON is a failed journey - tally + latch.
											if (true) then {
												private ["_fjA","_fjThrA"];
												_fjA = ([_team, "wfbe_aicom_failedjourneys", 0] Call WFBE_CO_FNC_GroupGetBool) + 1;
												_team setVariable ["wfbe_aicom_failedjourneys", _fjA];
												if ((missionNamespace getVariable ["WFBE_C_AICOM_RETARGET_RECYCLE", 0]) > 0) then {_team setVariable ["wfbe_aicom_journey_failed_counted", true]};
												_fjThrA = missionNamespace getVariable ["WFBE_C_AICOM_FAILED_JOURNEYS_RECYCLE", 0];
												if (_fjThrA > 0 && {_fjA >= _fjThrA} && {!([_team, "wfbe_aicom_recycle", false] Call WFBE_CO_FNC_GroupGetBool)}) then {
													_team setVariable ["wfbe_aicom_recycle", true, true];
													diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|RECYCLE_FLAG|team=" + (str _team) + "|failedjourneys=" + str _fjA + "|reason=abandon");
													//--- WASPSCALE aband counter (feat/abandon-telemetry): cumulative abandon/recycle events this match, read by the AI_Commander.sqf WASPSCALE emit (aband=). Counter-only, no behaviour change.
													missionNamespace setVariable ["wfbe_waspscale_aband", (missionNamespace getVariable ["wfbe_waspscale_aband", 0]) + 1];
												};
											};
											//--- D1 (cmdcon28): tally this abandon SIDE-WIDE. After WFBE_C_AICOM_SIDE_ABANDON different-team
											//--- abandons of the SAME town, blacklist it for the WHOLE side (read by the selector above) so no more
											//--- teams are thrown at an A2-unreachable town. A2-safe: lists of [town,count] / [town,expiry] on _logik.
											if ((missionNamespace getVariable ["WFBE_C_AICOM_SIDE_BLACKLIST", 1]) > 0) then {
												private ["_sba","_newSba","_sFound","_sCnt"];
												_sba = _logik getVariable ["wfbe_aicom_side_abandons", []];
												_newSba = []; _sFound = false; _sCnt = 0;
												//--- r40 intel freshness: drop null/deleted town keys while rewriting.
												{ if ((typeName (_x select 0) == "OBJECT") && {!isNull (_x select 0)}) then {
													if ((_x select 0) == _goto) then {_sFound = true; _sCnt = (_x select 1) + 1; _newSba set [count _newSba, [_goto, _sCnt]]} else {_newSba set [count _newSba, _x]};
												} } forEach _sba;
												if (!_sFound) then {_sCnt = 1; _newSba set [count _newSba, [_goto, 1]]};
												_logik setVariable ["wfbe_aicom_side_abandons", _newSba];
												if (_sCnt >= (missionNamespace getVariable ["WFBE_C_AICOM_SIDE_ABANDON", 3])) then {
													private ["_sbl","_sblKeep","_sblCd"];
													_sblCd = missionNamespace getVariable ["WFBE_C_AICOM_SIDE_BLACKLIST_COOLDOWN", 900];
													_sbl = _logik getVariable ["wfbe_aicom_side_blacklist", []];
													_sblKeep = [];
													{ if ((typeName (_x select 0) == "OBJECT") && {!isNull (_x select 0)} && {(_x select 1) > time} && {(_x select 0) != _goto}) then {_sblKeep set [count _sblKeep, _x]} } forEach _sbl;
													_sblKeep set [count _sblKeep, [_goto, time + _sblCd]];
													_logik setVariable ["wfbe_aicom_side_blacklist", _sblKeep];
													diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|SIDE_BLACKLIST|town=" + (_goto getVariable ["name","town"]) + "|abandons=" + str _sCnt + "|cooldown=" + str _sblCd);
													//--- GRUDGE LEDGER (feat/aicom-grudge-ledger, generated by apply_grudge.py): stamp a grudge on this now-side-blacklisted town
													if ((missionNamespace getVariable ["WFBE_C_AICOM_GRUDGE", 0]) > 0) then {
																											private ["_grDecay","_grMax","_grList","_grKeep","_grTrim","_grIdx"];
																											_grDecay = missionNamespace getVariable ["WFBE_C_AICOM_GRUDGE_DECAY", 2400];
																											_grMax   = missionNamespace getVariable ["WFBE_C_AICOM_GRUDGE_MAX_SITES", 3];
																											_grList  = _logik getVariable ["wfbe_aicom_grudge", []];
																											_grKeep  = [];
																											{ if ((typeName (_x select 0) == "OBJECT") && {!isNull (_x select 0)} && {(_x select 1) > time} && {(_x select 0) != _goto}) then {_grKeep set [count _grKeep, _x]} } forEach _grList;
																											if (count _grKeep >= _grMax) then {
																												_grTrim = [];
																												for "_grIdx" from ((count _grKeep) - _grMax + 1) to ((count _grKeep) - 1) do {_grTrim set [count _grTrim, _grKeep select _grIdx]};
																												_grKeep = _grTrim;
																											};
																											_grKeep set [count _grKeep, [_goto, time + _grDecay, false]];
																											_logik setVariable ["wfbe_aicom_grudge", _grKeep];
																											diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|GRUDGE_STAMP|town=" + (_goto getVariable ["name","town"]) + "|source=side_blacklist|decay=" + str _grDecay);
													};
												};
											};
										};
									} else {
										//--- CIRCLING FIX (Build84, claude-gaming 2026-07-01): the old code zeroed the
										//--- unstuck strike ladder on ANY non-position-stuck tick ("progressing, arrived,
										//--- or in contact"). A team PARKED on an UNCAPTURABLE depot is exactly that: it
										//--- is AT the target (within arrive radius) and often flips in/out of COMBAT as
										//--- it fights the un-drainable garrison, so it never trips the position-stuck gate
										//--- above AND its strikes were reset every window -> it NEVER reached STUCK_ABANDON,
										//--- so it orbited the depot forever (0 side-abandons all match; RPT: "did not flip
										//--- (res-near=0)" / "RELEASED uncapturable depot after N empty passes"). We now detect
										//--- "AT target but town NOT ours" and let strikes ACCUMULATE toward ABANDON so an
										//--- uncapturable target gets abandoned + blacklisted for THIS team just like a
										//--- position-stuck one. Real progress (team actually moved toward/away, town not
										//--- reached yet) still resets, unchanged.
										private ["_atTarget","_uncapParked","_capLocked"];
										//--- AT the target: within the assault arrive radius of _goto (same radius the
										//--- dispatch latch uses at the top of this file). Ties the abandon to the SAME
										//--- "did not flip"/"RELEASED uncapturable depot" signal Common_RunCommanderTeam
										//--- computes: wfbe_aicom_cappasses (>0 => at least one res-near==0 non-flip pass
										//--- was logged), OR just being parked on-centre while the town stays enemy-held.
										_atTarget = (_ldr distance _goto) <= (missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_ARRIVE_RADIUS", 250]);
										_uncapParked = _atTarget && {(_goto getVariable ["sideID", -1]) != _sideID};
										if (_uncapParked) then {
											//--- Review reconciliation: read CapLock once before any uncap-parked mutation.
											_capLocked = [_team] Call WFBE_CO_FNC_CapLock;
											//--- Refresh the breadcrumb (so the position-stuck gate does NOT also fire and
											//--- double-count) but do NOT zero strikes; bump the SAME strike counter the
											//--- unstuck ladder uses so an uncapturable depot climbs to ABANDON.
											if (count _ord >= 4) then {_team setVariable ["wfbe_aicom_townorder", [_goto, time, getPos _ldr, _ord select 3]]} else {_team setVariable ["wfbe_aicom_townorder", [_goto, time, getPos _ldr]]};   //--- DEFECT-2 FIX (fable, GR-2026-07-08a, adversarial-verify): preserve the Fix-A 4th tuple element (dyn-timeout budget) across this breadcrumb refresh - a bare 3-element write here truncated it on the first >210s stuck-recheck after every dispatch, silently reverting long-haul teams to the flat 420s legacy timeout. _ord is the SAME fresh read from :308 (mutually-exclusive branches, no intervening write).
											if (!_capLocked) then {
											private ["_strk"];
											_strk = ([_team, "wfbe_aicom_stuckstrikes", 0] Call WFBE_CO_FNC_GroupGetBool) + 1; //--- fix(hunt): G1-safe (nil+1 threw for stuck-since-spawn teams, so the unstick ladder never started)
											_team setVariable ["wfbe_aicom_stuckstrikes", _strk];
											diag_log (Format ["STUCKSTAT|v1|%1|%2|uncap-parked|leader=%3|distTgt=%4|cappasses=%5|strike=%6", _sideText, round (time / 60), typeOf _ldr, round (_ldr distance _goto), ([_team, "wfbe_aicom_cappasses", 0] Call WFBE_CO_FNC_GroupGetBool), _strk]);
											//--- STALL-ADVANCE FLOOR (Build84, claude-gaming 2026-07-02): the strike ladder above only
											//--- reaches STUCK_ABANDON after several full 120s windows, and live RPT showed it almost never
											//--- fires (each fresh order seq reset the phase bookkeeping before the counter accrued) -> a team
											//--- stood at an unflippable res-near=0 depot indefinitely (0 town-captures, TARGET_ABANDON=0).
											//--- TIME-based bypass: if this team has been parked on the SAME _goto with no flip for longer than
											//--- WFBE_C_AICOM_STALL_ADVANCE_SECS (default 240; 0 = off), blacklist _goto for THIS team NOW (same
											//--- [town,expiry] idiom + WFBE_C_AICOM_BLACKLIST_COOLDOWN) and set _needs=true so the nearest-
											//--- reachable selector hands it a DIFFERENT enemy town THIS tick - bypassing the strike count. The
											//--- goto_since clock is stamped when the goto is first booked (above) and cleared on real progress
											//--- (below) / flip, so only a genuine stall trips it. Empty-pool guard below never blacklists the
											//--- last enemy town. The team holds its live waypoint until re-tasked (never idle). A2-OA-safe.
											private ["_stallSecs","_gotoSince"];
											_stallSecs = missionNamespace getVariable ["WFBE_C_AICOM_STALL_ADVANCE_SECS", 240];
											_gotoSince = _team getVariable "wfbe_aicom_goto_since";
											if (isNil "_gotoSince") then {_gotoSince = time; _team setVariable ["wfbe_aicom_goto_since", time]};
											//--- T1.3b FIX (R3-SYNTHESIS 2026-07-20, grok S1): the CapLock check further down this file
											//--- suppresses RE-TARGETING while a team is capture-locked, but this stall-advance floor runs
											//--- BEFORE that check and unconditionally BLACKLISTS _goto below - so a locked team (genuinely
											//--- mid-capture, not actually stalled) still poisons its own target town for every future team,
											//--- even though _needs=true here gets silently overridden back to false moments later.
											//--- Reordering the CHECK alone does not fix this (still races); the real fix is: never MUTATE
											//--- the blacklist for a town this team is currently locked onto.
											if (_stallSecs > 0 && {(time - _gotoSince) > _stallSecs}) then {
												private ["_saCd","_saBl","_saKeep"];
												_saCd = missionNamespace getVariable ["WFBE_C_AICOM_BLACKLIST_COOLDOWN", 600];
												_saBl = [_team, "wfbe_aicom_blacklist", []] Call WFBE_CO_FNC_GroupGetBool;
												_saKeep = [];
												{ if ((typeName (_x select 0) == "OBJECT") && {!isNull (_x select 0)} && {(_x select 1) > time} && {(_x select 0) != _goto}) then {_saKeep set [count _saKeep, _x]} } forEach _saBl;
												_saKeep set [count _saKeep, [_goto, time + _saCd]];
												_team setVariable ["wfbe_aicom_blacklist", _saKeep];
												_team setVariable ["wfbe_aicom_stuckstrikes", 0];
												_team setVariable ["wfbe_aicom_goto_since", time]; //--- clock reset so the fresh target starts a clean stall window.
												_needs = true; //--- retarget THIS tick via the nearest-reachable selector (empty-pool guard protects the last enemy town).
												diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|TARGET_ABANDON|team=" + (str _team) + "|town=" + (_goto getVariable ["name","town"]) + "|reason=stall-advance|onGoto=" + str (round (time - _gotoSince)) + "|cooldown=" + str _saCd);
												//--- WASPSCALE aband counter (feat/abandon-telemetry): cumulative abandon/recycle events this match, read by the AI_Commander.sqf WASPSCALE emit (aband=). Counter-only, no behaviour change.
												missionNamespace setVariable ["wfbe_waspscale_aband", (missionNamespace getVariable ["wfbe_waspscale_aband", 0]) + 1];
													//--- FAILED-JOURNEY RECYCLE (cmdcon41-w2, F4b): stall-advance abandon is a failed journey - tally + latch.
													private ["_fjSA","_fjThrSA"];
													_fjSA = ([_team, "wfbe_aicom_failedjourneys", 0] Call WFBE_CO_FNC_GroupGetBool) + 1;
													_team setVariable ["wfbe_aicom_failedjourneys", _fjSA];
													if ((missionNamespace getVariable ["WFBE_C_AICOM_RETARGET_RECYCLE", 0]) > 0) then {_team setVariable ["wfbe_aicom_journey_failed_counted", true]};
													_fjThrSA = missionNamespace getVariable ["WFBE_C_AICOM_FAILED_JOURNEYS_RECYCLE", 0];
													if (_fjThrSA > 0 && {_fjSA >= _fjThrSA} && {!([_team, "wfbe_aicom_recycle", false] Call WFBE_CO_FNC_GroupGetBool)}) then {
														_team setVariable ["wfbe_aicom_recycle", true, true];
														diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|RECYCLE_FLAG|team=" + (str _team) + "|failedjourneys=" + str _fjSA + "|reason=abandon");
														//--- WASPSCALE aband counter (feat/abandon-telemetry): cumulative abandon/recycle events this match, read by the AI_Commander.sqf WASPSCALE emit (aband=). Counter-only, no behaviour change.
														missionNamespace setVariable ["wfbe_waspscale_aband", (missionNamespace getVariable ["wfbe_waspscale_aband", 0]) + 1];
													};
											};
											//--- T1.3c FIX (R3-SYNTHESIS 2026-07-20; codex review HIGH follow-up): the T1.3b guard on the
											//--- stall-advance floor above did NOT cover this SEPARATE strike-based abandon path (this is
											//--- the uncap-parked-AT-target ladder, where a genuinely-locked mid-capture team CAN reach this
											//--- point) - it was still reachable while CapLocked and could poison the blacklist + bump
											//--- side-abandon state for a town this team is actually still draining. Same fix as T1.3b: never
											//--- mutate the blacklist for a town this team is currently locked onto. (The OTHER STUCK_ABANDON
											//--- site earlier in this file, the en-route position-stuck ladder, is unaffected: a team there is
											//--- by definition parked FAR from _goto and has not yet reached BEGIN_CAPTURE, so it cannot be
											//--- CapLocked at that point - no guard needed there.)
											if (_strk > (missionNamespace getVariable ["WFBE_C_AICOM_STUCK_ABANDON", 4])) then {
												//--- Same ABANDON + per-team blacklist + side-abandon tally as the position-stuck
												//--- ladder below-left; factored to keep both paths identical.
												private ["_abCd","_abBl","_abKeep"];
												_abCd = missionNamespace getVariable ["WFBE_C_AICOM_BLACKLIST_COOLDOWN", 600];
												_abBl = [_team, "wfbe_aicom_blacklist", []] Call WFBE_CO_FNC_GroupGetBool;
												_abKeep = [];
												{ if ((typeName (_x select 0) == "OBJECT") && {!isNull (_x select 0)} && {(_x select 1) > time} && {(_x select 0) != _goto}) then {_abKeep set [count _abKeep, _x]} } forEach _abBl;
												_abKeep set [count _abKeep, [_goto, time + _abCd]];
												_team setVariable ["wfbe_aicom_blacklist", _abKeep];
												_team setVariable ["wfbe_aicom_stuckstrikes", 0];
												diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|TARGET_ABANDON|team=" + (str _team) + "|town=" + (_goto getVariable ["name","town"]) + "|reason=uncapturable|cooldown=" + str _abCd);
												//--- WASPSCALE aband counter (feat/abandon-telemetry): cumulative abandon/recycle events this match, read by the AI_Commander.sqf WASPSCALE emit (aband=). Counter-only, no behaviour change.
												missionNamespace setVariable ["wfbe_waspscale_aband", (missionNamespace getVariable ["wfbe_waspscale_aband", 0]) + 1];
													//--- FAILED-JOURNEY RECYCLE (cmdcon41-w2, F4b): uncapturable abandon is a failed journey - tally + latch.
													private ["_fjUC","_fjThrUC"];
													_fjUC = ([_team, "wfbe_aicom_failedjourneys", 0] Call WFBE_CO_FNC_GroupGetBool) + 1;
													_team setVariable ["wfbe_aicom_failedjourneys", _fjUC];
													if ((missionNamespace getVariable ["WFBE_C_AICOM_RETARGET_RECYCLE", 0]) > 0) then {_team setVariable ["wfbe_aicom_journey_failed_counted", true]};
													_fjThrUC = missionNamespace getVariable ["WFBE_C_AICOM_FAILED_JOURNEYS_RECYCLE", 0];
													if (_fjThrUC > 0 && {_fjUC >= _fjThrUC} && {!([_team, "wfbe_aicom_recycle", false] Call WFBE_CO_FNC_GroupGetBool)}) then {
														_team setVariable ["wfbe_aicom_recycle", true, true];
														diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|RECYCLE_FLAG|team=" + (str _team) + "|failedjourneys=" + str _fjUC + "|reason=abandon");
														//--- WASPSCALE aband counter (feat/abandon-telemetry): cumulative abandon/recycle events this match, read by the AI_Commander.sqf WASPSCALE emit (aband=). Counter-only, no behaviour change.
														missionNamespace setVariable ["wfbe_waspscale_aband", (missionNamespace getVariable ["wfbe_waspscale_aband", 0]) + 1];
													};
												if ((missionNamespace getVariable ["WFBE_C_AICOM_SIDE_BLACKLIST", 1]) > 0) then {
													private ["_sba","_newSba","_sFound","_sCnt"];
													_sba = _logik getVariable ["wfbe_aicom_side_abandons", []];
													_newSba = []; _sFound = false; _sCnt = 0;
													//--- r40 intel freshness: drop null/deleted town keys while rewriting.
													{ if ((typeName (_x select 0) == "OBJECT") && {!isNull (_x select 0)}) then {
														if ((_x select 0) == _goto) then {_sFound = true; _sCnt = (_x select 1) + 1; _newSba set [count _newSba, [_goto, _sCnt]]} else {_newSba set [count _newSba, _x]};
													} } forEach _sba;
													if (!_sFound) then {_sCnt = 1; _newSba set [count _newSba, [_goto, 1]]};
													_logik setVariable ["wfbe_aicom_side_abandons", _newSba];
													if (_sCnt >= (missionNamespace getVariable ["WFBE_C_AICOM_SIDE_ABANDON", 3])) then {
														private ["_sbl","_sblKeep","_sblCd"];
														_sblCd = missionNamespace getVariable ["WFBE_C_AICOM_SIDE_BLACKLIST_COOLDOWN", 900];
														_sbl = _logik getVariable ["wfbe_aicom_side_blacklist", []];
														_sblKeep = [];
														{ if ((typeName (_x select 0) == "OBJECT") && {!isNull (_x select 0)} && {(_x select 1) > time} && {(_x select 0) != _goto}) then {_sblKeep set [count _sblKeep, _x]} } forEach _sbl;
														_sblKeep set [count _sblKeep, [_goto, time + _sblCd]];
														_logik setVariable ["wfbe_aicom_side_blacklist", _sblKeep];
														diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|SIDE_BLACKLIST|town=" + (_goto getVariable ["name","town"]) + "|abandons=" + str _sCnt + "|cooldown=" + str _sblCd);
														//--- GRUDGE LEDGER (feat/aicom-grudge-ledger, generated by apply_grudge.py): stamp a grudge on this now-side-blacklisted town
														if ((missionNamespace getVariable ["WFBE_C_AICOM_GRUDGE", 0]) > 0) then {
																													private ["_grDecay","_grMax","_grList","_grKeep","_grTrim","_grIdx"];
																													_grDecay = missionNamespace getVariable ["WFBE_C_AICOM_GRUDGE_DECAY", 2400];
																													_grMax   = missionNamespace getVariable ["WFBE_C_AICOM_GRUDGE_MAX_SITES", 3];
																													_grList  = _logik getVariable ["wfbe_aicom_grudge", []];
																													_grKeep  = [];
																													{ if ((typeName (_x select 0) == "OBJECT") && {!isNull (_x select 0)} && {(_x select 1) > time} && {(_x select 0) != _goto}) then {_grKeep set [count _grKeep, _x]} } forEach _grList;
																													if (count _grKeep >= _grMax) then {
																														_grTrim = [];
																														for "_grIdx" from ((count _grKeep) - _grMax + 1) to ((count _grKeep) - 1) do {_grTrim set [count _grTrim, _grKeep select _grIdx]};
																														_grKeep = _grTrim;
																													};
																													_grKeep set [count _grKeep, [_goto, time + _grDecay, false]];
																													_logik setVariable ["wfbe_aicom_grudge", _grKeep];
																													diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|GRUDGE_STAMP|town=" + (_goto getVariable ["name","town"]) + "|source=side_blacklist|decay=" + str _grDecay);
														};
													};
												};
											};
											};
										} else {
											//--- Real progress (en-route, actually moving, town not yet reached): refresh the
											//--- breadcrumb and DECAY the unstuck strike ladder (the team moved, so it is not stuck).
											if (count _ord >= 4) then {_team setVariable ["wfbe_aicom_townorder", [_goto, time, getPos _ldr, _ord select 3]]} else {_team setVariable ["wfbe_aicom_townorder", [_goto, time, getPos _ldr]]};   //--- DEFECT-2 FIX (fable, GR-2026-07-08a, adversarial-verify): preserve the Fix-A 4th tuple element (dyn-timeout budget) across this breadcrumb refresh - a bare 3-element write here truncated it on the first >210s stuck-recheck after every dispatch, silently reverting long-haul teams to the flat 420s legacy timeout. _ord is the SAME fresh read from :308 (mutually-exclusive branches, no intervening write).
											//--- STUCK DECAY (cmdcon41-w3-orbiter, claude-gaming 2026-07-02, gate WFBE_C_AICOM_STUCK_DECAY default 0):
											//--- an oscillating wedger that lurches 200m and re-sticks cycles tier-1 forever when the strike counter
											//--- hard-resets to 0 on ANY forward lurch. When WFBE_C_AICOM_STUCK_DECAY > 0: DECAY by 1 ((v-1) max 0)
											//--- instead of zeroing, so a chronic wedger climbs the ladder over time to the terminal tier.
											//--- Flag 0 = legacy hard-reset (byte-identical to pre-LADDER_DECAY behavior). A2-OA-safe (numeric).
											if ((missionNamespace getVariable ["WFBE_C_AICOM_STUCK_DECAY", 0]) > 0) then {
												private ["_decStrk"];
												_decStrk = _team getVariable "wfbe_aicom_stuckstrikes";
												if (isNil "_decStrk") then {_decStrk = 0};
												_decStrk = (_decStrk - 1) max 0;
												_team setVariable ["wfbe_aicom_stuckstrikes", _decStrk];
											} else {
												_team setVariable ["wfbe_aicom_stuckstrikes", 0];
											};
											//--- STALL-ADVANCE FLOOR: the team is making real progress on this goto (moving / draining),
											//--- so restart its stall clock - the time-based bypass only fires on a genuine parked stall.
											_team setVariable ["wfbe_aicom_goto_since", time];
										};
									};
								};
							};
						};
					};
				};
			};

			//--- JOURNEY-COMMIT (cmdcon41-w2, F2, claude-gaming 2026-07-02): 583 dispatches -> 40 arrivals last
			//--- match, largely because a team's target was re-picked mid-leg (spearhead repicks 135, FRONT changes
			//--- 122) faster than a 20-min journey could complete - most journeys died administratively. When
			//--- WFBE_C_AICOM_JOURNEY_COMMIT is on, a team with an OPEN dispatch (wfbe_aicom_dispatch_open) to a
			//--- STILL-ENEMY town that is MAKING PROGRESS - the leader has closed >= 150m toward the target since
			//--- the dispatch breadcrumb (townorder = [target, t0, leaderPosAtDispatch]; progress = breadcrumb-dist
			//--- minus current-dist) - is EXEMPT from retargeting this pass: force _needs=false so the churn paths
			//--- above cannot yank it off a working journey. EXEMPTIONS (never committed, always allowed to retarget):
			//--- the target town flipped to us, wfbe_aicom_recycle is latched (terminal zombie being retired), or an
			//--- explicit console order (already handled - this whole block is under !_explicitMode). A2-OA-safe:
			//--- plain getVariable + isNil, typeName OBJECT test, numeric sideID/distance, boolean if/else (no ==/!=
			//--- on Boolean operands, no isEqualType). Guardrail: only SKIPS a retarget - it never leaves a team
			//--- without its existing live order (the team keeps marching on its current waypoints).
			if (_needs && {(missionNamespace getVariable ["WFBE_C_AICOM_JOURNEY_COMMIT", 1]) > 0}) then {
				_jcRecycle = [_team, "wfbe_aicom_recycle", false] Call WFBE_CO_FNC_GroupGetBool;
				if (!_jcRecycle) then {
					if ([_team, "wfbe_aicom_dispatch_open", false] Call WFBE_CO_FNC_GroupGetBool) then {
						_jcOrd = [_team, "wfbe_aicom_townorder", []] Call WFBE_CO_FNC_GroupGetBool;
						if (count _jcOrd >= 3) then {
							_jcTgt = _jcOrd select 0;
							_jcBc  = _jcOrd select 2;
							if (typeName _jcTgt == "OBJECT" && {!isNull _jcTgt}) then {
								//--- Still-enemy town only (a flipped-to-us target must be allowed to retarget).
								if ((_jcTgt getVariable ["sideID", -1]) != _sideID) then {
									_jcProg = (_jcBc distance _jcTgt) - ((leader _team) distance _jcTgt);
																		private ["_jcBlHit"];
									_jcBlHit = false;
									if ((missionNamespace getVariable ["WFBE_C_AICOM_SMALLMAP_TUNE", 0]) > 0 && {(toLower worldName) == "zargabad"}) then {
										private ["_jcPreBl"];
										_jcPreBl = [_team, "wfbe_aicom_blacklist", []] Call WFBE_CO_FNC_GroupGetBool;
										if (typeName _jcPreBl == "ARRAY") then {
											{if ((typeName (_x select 0) == "OBJECT") && {(_x select 0) == _jcTgt} && {(_x select 1) > time}) then {_jcBlHit = true}} forEach _jcPreBl;
										};
									};
									if (_jcProg >= 150 && {!_jcBlHit}) then {
										if (((missionNamespace getVariable ["WFBE_C_AICOM_RETARGET_GRACE_DISPATCHES", 0]) > 0) || {(missionNamespace getVariable ["WFBE_C_AICOM_RETARGET_RECYCLE", 0]) > 0}) then {_team setVariable ["wfbe_aicom_journey_commit_seen", true]};
										_needs = false; //--- committed + progressing: keep this journey, skip retarget this pass.
										diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|JOURNEY_COMMIT|team=" + (str _team) + "|town=" + (_jcTgt getVariable ["name","town"]) + "|progress=" + str (round _jcProg));
									};
									//--- ZG small-map tune A+B (round-3). HARD-ABANDON EXCLUSION: if the CURRENT target has an
									//--- unexpired entry on this team's abandon blacklist (the TARGET_ABANDON latch at ~L404-410),
									//--- NEITHER suppression may hold the team on it - the terminal retarget away from an
									//--- abandoned town always wins. A2-safe flag scan (no exitWith in forEach).
									Private ["_jcBl","_jcTgtSince","_jcCd"];
									if ((missionNamespace getVariable ["WFBE_C_AICOM_SMALLMAP_TUNE", 0]) > 0 && {(toLower worldName) == "zargabad"}) then {
										_jcBl = [_team, "wfbe_aicom_blacklist", []] Call WFBE_CO_FNC_GroupGetBool;
										if (typeName _jcBl == "ARRAY") then {
										{ if ((typeName (_x select 0) == "OBJECT") && {(_x select 0) == _jcTgt} && {(_x select 1) > time}) then {_jcBlHit = true} } forEach _jcBl;
							};
									};
									//--- A: a team STALLED at a chokepoint shows no 150m progress and lost its exemption - but
									//--- being stuck in a FIREFIGHT en route, or already adjacent to the target, is not "not
									//--- committed". Flag default 0 = byte-identical.
									if (_needs && {!_jcBlHit} && {(missionNamespace getVariable ["WFBE_C_AICOM_COMMIT_COMBAT", 0]) > 0}) then {
										if ((behaviour (leader _team)) == "COMBAT" || {((leader _team) distance _jcTgt) < (missionNamespace getVariable ["WFBE_C_AICOM_COMMIT_NEAR_DIST", 500])}) then {
											_needs = false;
											diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|JOURNEY_COMMIT|team=" + (str _team) + "|town=" + (_jcTgt getVariable ["name","town"]) + "|reason=combat-or-near");
										};
									};
									//--- B: minimum seconds between retargets of the SAME team, measured from the DEDICATED
									//--- target-change stamp wfbe_aicom_tgt_since (round-3: _dispT0 refreshes on same-target
									//--- re-issues, so it is not a stable basis). Param default 0 = legacy = byte-identical.
									_jcCd = missionNamespace getVariable ["WFBE_C_AICOM_RETARGET_COOLDOWN", 0];
									if (_needs && {!_jcBlHit} && {_jcCd > 0}) then {
										_jcTgtSince = _team getVariable "wfbe_aicom_tgt_since"; //--- group var: 1-arg + isNil (G1) // group state key, not a classname
										if (!isNil "_jcTgtSince" && {(time - _jcTgtSince) < _jcCd}) then {
											_needs = false;
											diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|RETARGET_COOLDOWN_HOLD|team=" + (str _team) + "|town=" + (_jcTgt getVariable ["name","town"]) + "|age=" + str (round (time - _jcTgtSince)));
										};
									};
								};
							};
						};
					};
				};
			};
			//--- FOOT_STAGE owns the next selection pass: discard journey bookkeeping before the cap-lock gate.
			if (_footStage) then {
				_needs = true;
				_team setVariable ["wfbe_aicom_dispatch_open", false];
				_team setVariable ["wfbe_aicom_townorder", [], false];
			};

			//--- CAPTURE LOCK (GR-2026-07-03a, capture-churn fix): a team that has fired BEGIN_CAPTURE and is draining a town is IMMUNE to
			//--- re-targeting here (the single AssignTowns re-task choke-point). This is the site the behaviour data proved reaches in-drain
			//--- teams: the ~10-min spearhead REPICK re-orders wfbe_aicom_targets, and this pass then yanks a mid-drain team onto the new
			//--- primary, resetting its progress (62 BEGIN_CAPTURE / 27 teams / ~5 CAPTURED last night). Force _needs=false when locked so the
			//--- team keeps its live capture order until the lock releases (captured / dead / TTL / town-flips-to-us - all in WFBE_CO_FNC_CapLock).
			//--- ALWAYS-ON diag so the next soak can quantify suppressions. A2-OA-safe: helper returns a plain BOOL (if(!bool), no ==/!= on bools).
			if (_needs && {[_team] Call WFBE_CO_FNC_CapLock}) then {
				_needs = false;
				private ["_clOrd","_clTgt","_clAge"];
				_clOrd = _team getVariable "wfbe_aicom_caplock"; if (isNil "_clOrd") then {_clOrd = []};
				_clTgt = if (count _clOrd >= 1 && {typeName (_clOrd select 0) == "OBJECT"} && {!isNull (_clOrd select 0)}) then {(_clOrd select 0) getVariable ["name","town"]} else {"pos"};
				_clAge = if (count _clOrd >= 2 && {typeName (_clOrd select 1) == "SCALAR"}) then {round (time - (_clOrd select 1))} else {-1};
				diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|CAPTURE_LOCK_SUPPRESS|team=" + (str _team) + "|town=" + _clTgt + "|age=" + str _clAge);
			};

			if ((missionNamespace getVariable ["WFBE_C_AICOM_STRAND_RECOVERY", 0]) > 0) then {
				private ["_strandPending","_strandLocked","_strandRecycle"];
				_strandPending = _team getVariable "wfbe_aicom_strand_recovery_pending";
				if (!isNil "_strandPending" && {_strandPending}) then {
					_strandLocked = [_team] Call WFBE_CO_FNC_CapLock;
					_strandRecycle = [_team, "wfbe_aicom_recycle", false] Call WFBE_CO_FNC_GroupGetBool;
					if (!_strandLocked && {!_strandRecycle}) then {
						_strandRecovery = true;
						_strandTarget = _team getVariable "wfbe_aicom_strand_recovery_target";
						_team setVariable ["wfbe_aicom_strand_recovery_pending", false];
						_needs = true;
					} else {
						if (_strandRecycle) then {_team setVariable ["wfbe_aicom_strand_recovery_pending", false]};
					};
				};
			};
			if (_needs) then {
				_target = objNull;
				if (_bootstrap && {!_strandRecovery}) then {
					//--- V0.7 BOOTSTRAP BIAS: side owns 0 towns - pick the nearest-to-HQ,
					//--- lowest-supplyValue uncaptured town so we grab income as fast as possible.
					//--- Score = -(distance to HQ) - (supplyValue * 10): small near towns win.
					_hqObj = (_side) Call WFBE_CO_FNC_GetSideHQ;
					_bestBoot = objNull;
					_bestBootScore = -1e9;
					{
						_bootDist = if (!isNull _hqObj) then {_x distance _hqObj} else {0};
						_bootScore = (0 - _bootDist) - ((_x getVariable ["supplyValue", 0]) * 10);
						if (isNil "_bootScore") then {
							diag_log ("CAPDBG|BOOT|" + (_x getVariable ["name","?"]) + "|residual");
						};
						_bootScore = if (isNil "_bootScore") then {-9999999} else {_bootScore};
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
					//--- T1.2 FIX (R3-SYNTHESIS 2026-07-20; codex review CRITICAL follow-up): the old classifier
					//--- flagged the WHOLE team "mounted" (9000m reach) the instant ANY single unit - even just a
					//--- truck's driver - was embarked, so a lone crew-driver sent a whole walking squad on a 9km
					//--- dispatch the infantry then REFUSE to complete on foot (86% of dispatches exceeded the
					//--- real foot reach). Now delegates to WFBE_CO_FNC_AICOMTeamMounted (leader-or-50pct embarked)
					//--- - the SAME shared helper AI_Commander_Allocate.sqf's target selection now also calls, so
					//--- the two sites cannot silently diverge again (review found Allocate had its own unguarded
					//--- copy of this exact bug at its OWN target-selection site).
					_mounted = [_team] Call WFBE_CO_FNC_AICOMTeamMounted;
					_reachFoot    = missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_REACH_FOOT", 3500];
					_reachMounted = missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_REACH_MOUNTED", 9000];
					_teamReach = if (_mounted) then {_reachMounted} else {_reachFoot}; private "_teamAir"; _teamAir = false; { if (!_teamAir && {alive _x} && {(vehicle _x) isKindOf "Helicopter"} && {(getNumber (configFile >> "CfgVehicles" >> (typeOf (vehicle _x)) >> "transportSoldier")) > 0}) then {_teamAir = true} } forEach (units _team); //--- B756 (Ray 2026-06-26): does this team carry a TRANSPORT heli? gates naval-HVT targets to air teams only (no ground sea-stranding).
//--- r37 water-crossing: amphibious capability + straight-line water-leg gate for land-only teams.
//--- Without this, island/peninsula towns pass pure-distance reach and foot/wheeled teams walk into
//--- the shoreline forever (no surfaceIsWater test at objective pick; BuildRoadRoute only snaps roads).
private ["_teamAmphib","_waterBlocks"];
_teamAmphib = false;
{ if (!_teamAmphib && {alive _x}) then { private "_wv"; _wv = vehicle _x; if (_wv != _x && {alive _wv} && {(getNumber (configFile >> "CfgVehicles" >> (typeOf _wv) >> "canFloat")) > 0}) then {_teamAmphib = true} } } forEach (units _team);
_waterBlocks = {
	private ["_from","_to","_hits","_i","_frac","_px","_py"];
	_from = _this select 0; _to = _this select 1;
	if ((missionNamespace getVariable ["WFBE_C_AICOM_WATER_LEG_GATE", 1]) <= 0) exitWith {false};
	if (_teamAir || {_teamAmphib}) exitWith {false};
	if ((typeName _from) != "ARRAY" || {(typeName _to) != "ARRAY"} || {(count _from) < 2} || {(count _to) < 2}) exitWith {false};
	_hits = 0;
	for "_i" from 1 to 4 do {
		_frac = _i / 5;
		_px = (_from select 0) + (((_to select 0) - (_from select 0)) * _frac);
		_py = (_from select 1) + (((_to select 1) - (_from select 1)) * _frac);
		if (surfaceIsWater [_px, _py, 0]) then {_hits = _hits + 1};
	};
	(_hits >= 2)
};
					//--- WAVE-1 CAUSE-2: live (non-expired) blacklist towns for THIS team. Prune expired entries
					//--- back onto the team var, then build _uncapturedF = uncaptured minus blacklisted. GUARDRAIL:
					//--- if excluding the blacklist would leave NO uncaptured town, clear the blacklist and fall back
					//--- to the full list so the team always gets a target (never idle). _blTowns gates the spearhead
					//--- pick too; bootstrap (0-town opening rush) is exempt - it never reaches here.
					_blList = [_team, "wfbe_aicom_blacklist", []] Call WFBE_CO_FNC_GroupGetBool;
					_blKeep = [];
					_blTowns = [];
					{ if ((typeName (_x select 0) == "OBJECT") && {!isNull (_x select 0)} && {(_x select 1) > time}) then {_blKeep set [count _blKeep, _x]; _blTowns set [count _blTowns, (_x select 0)]} } forEach _blList;
					_team setVariable ["wfbe_aicom_blacklist", _blKeep];
					if (_strandRecovery && {typeName _strandTarget == "OBJECT"} && {!isNull _strandTarget} && {!(_strandTarget in _blTowns)}) then {_blTowns set [count _blTowns, _strandTarget]};
					//--- D1 (cmdcon28, Ray 2026-06-30): PER-SIDE unreachable-town blacklist. The per-team list above
					//--- only stops THIS team re-picking a town it abandoned - but fresh teams kept being thrown at the
					//--- same A2-pathfinder-unreachable town (the overnight soak: Stary Sobor ate 105 dispatches). Once
					//--- WFBE_C_AICOM_SIDE_ABANDON different teams abandon a town (tallied at the TARGET_ABANDON below),
					//--- it lands on the side logic's wfbe_aicom_side_blacklist; merge those into _blTowns so the WHOLE
					//--- side stops sending teams there. The empty-pool guardrail below clears _blTowns (incl these) so a
					//--- team is never left idle. Flag-gated WFBE_C_AICOM_SIDE_BLACKLIST (default on), reversible. A2-safe.
					if ((missionNamespace getVariable ["WFBE_C_AICOM_SIDE_BLACKLIST", 1]) > 0) then {
						private ["_sbl","_sblLive","_sba","_sbaKeep"];
						_sbl = _logik getVariable ["wfbe_aicom_side_blacklist", []];
						_sblLive = [];
						{ if ((typeName (_x select 0) == "OBJECT") && {!isNull (_x select 0)} && {(_x select 1) > time}) then {
							_sblLive set [count _sblLive, (_x select 0)];
							if (!((_x select 0) in _blTowns)) then {_blTowns set [count _blTowns, (_x select 0)]};
						} } forEach _sbl;
						//--- r40 intel freshness: side_abandons is permanent 'unreachable town' contact memory.
						//--- After blacklist cooldown, count stayed >= threshold so ONE abandon re-banned forever.
						//--- Age abandon tallies with the live side blacklist so intelligence expires with the ban.
						_sba = _logik getVariable ["wfbe_aicom_side_abandons", []];
						_sbaKeep = [];
						{ if ((typeName (_x select 0) == "OBJECT") && {!isNull (_x select 0)} && {(_x select 0) in _sblLive}) then {_sbaKeep set [count _sbaKeep, _x]} } forEach _sba;
						if ((count _sbaKeep) != (count _sba)) then {_logik setVariable ["wfbe_aicom_side_abandons", _sbaKeep]};
					};
					_uncapturedF = _uncaptured - _blTowns;
					if (count _uncapturedF == 0) then {
						if (_strandRecovery && {typeName _strandTarget == "OBJECT"} && {!isNull _strandTarget}) then {
							//--- M3: do not restore the failed target merely to satisfy the legacy non-empty guard.
							//--- With no alternate candidate, defer this one-shot recovery instead of re-dispatching a loop.
							_blTowns = _uncaptured;
							_uncapturedF = [];
						} else {
							//--- every uncaptured town is blacklisted: clear it so this team is never left without a target.
							_team setVariable ["wfbe_aicom_blacklist", []];
							_blTowns = [];
							_uncapturedF = _uncaptured;
						};
					};
					//--- RETARGET GRACE (assault-retarget-churn, default 0): a slow team that has not yet earned
					//--- JOURNEY_COMMIT may re-issue its current live enemy town for a bounded number of worker
					//--- passes before a DIFFERENT town is selected. Same-town re-issues preserve the existing
					//--- dispatch clock; the guard is state-only and does not scan units or towns.
					if (isNull _target && {(missionNamespace getVariable ["WFBE_C_AICOM_RETARGET_GRACE_DISPATCHES", 0]) > 0} && {!_bootstrap} && {!_strandRecovery} && {!_footStage} && {typeName _goto == "OBJECT"} && {!isNull _goto} && {(_goto getVariable ["sideID", -1]) != _sideID} && {!(_goto in _blTowns)} && {[_team, "wfbe_aicom_dispatch_open", false] Call WFBE_CO_FNC_GroupGetBool} && {!([_team, "wfbe_aicom_journey_commit_seen", false] Call WFBE_CO_FNC_GroupGetBool)}) then {
						private ["_graceLimit","_graceCount"];
						_graceLimit = missionNamespace getVariable ["WFBE_C_AICOM_RETARGET_GRACE_DISPATCHES", 0];
						_graceCount = [_team, "wfbe_aicom_retarget_grace", 0] Call WFBE_CO_FNC_GroupGetBool;
						if (_graceCount < _graceLimit) then {
							_target = _goto;
							diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|RETARGET_GRACE_HOLD|team=" + (str _team) + "|town=" + (_goto getVariable ["name","town"]) + "|count=" + str _graceCount + "|limit=" + str _graceLimit);
						};
					};

					//--- AICOM v2 (M1): if the single-authority Allocator assigned THIS team a target this cycle,
					//--- USE it (concentrate on the fist) and skip the legacy spearhead/nearest pick below. Fresh-gated
					//--- (WFBE_C_AICOM2_ALLOC_TICK_TTL, default 180s) so a stale assignment (Allocator off / not run) falls through to legacy = instant rollback.
					if (isNull _target && {(missionNamespace getVariable ["WFBE_C_AICOM2_ALLOCATE_ENABLE", 0]) > 0}) then {
						private ["_allocT","_allocTick","_allocTtl","_allocAge"];
						_allocT    = _team getVariable "wfbe_aicom_alloc_target";
						_allocTick = _team getVariable "wfbe_aicom_alloc_tick";
						_allocTtl  = missionNamespace getVariable ["WFBE_C_AICOM2_ALLOC_TICK_TTL", 180];
						if ((missionNamespace getVariable ["WFBE_C_AICOM2_ALLOC_TTL_HARDEN", 0]) > 0) then {if (_allocTtl < 300) then {_allocTtl = 300}};
						if (!isNil "_allocTick") then {_allocAge = time - _allocTick} else {_allocAge = 1e9};
						if (!isNil "_allocT" && {!isNull _allocT} && {!isNil "_allocTick"} && {_allocAge < _allocTtl} && {(_allocT getVariable ["sideID", _sideID]) != _sideID} && {!(_allocT in _blTowns)} && {!((missionNamespace getVariable ["WFBE_C_AICOM_FOOT_STAGE", 0]) > 0) || {_mounted} || {(_ldrPos distance _allocT) <= _teamReach}} && {!([_ldrPos, getPos _allocT] Call _waterBlocks)}) then { //--- review fix FOOT_STAGE + r37 water-leg gate
							_target = _allocT;
						} else {
							if (!isNil "_allocT" && {!isNull _allocT} && {!isNil "_allocTick"} && {_allocAge >= _allocTtl}) then {
								diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|ALLOC_TICK_STALE|team=" + (str _team) + "|town=" + (_allocT getVariable ["name","town"]) + "|age=" + str (round _allocAge) + "|ttl=" + str (round _allocTtl));
								_team setVariable ["wfbe_aicom_alloc_target", nil];
								_team setVariable ["wfbe_aicom_alloc_tick", nil];
							};
						};
					};
					_spear = _logik getVariable ["wfbe_aicom_targets", []];
					_concBase = missionNamespace getVariable ["WFBE_C_AICOM_CONCENTRATION", 3];
					{
						_spearT = _x;
						if (isNull _target && {!isNull _spearT}) then {
							if (((_spearT getVariable ["sideID", -1]) != _sideID) && {!(_spearT in _blTowns)} && {(_ldrPos distance _spearT) <= _teamReach} && {((missionNamespace getVariable ["WFBE_C_AICOM_NAVAL_AIR_ONLY", 1]) <= 0) || {!(_spearT getVariable ["wfbe_is_naval_hvt", false])} || _teamAir} && {!([_ldrPos, getPos _spearT] Call _waterBlocks)}) then { //--- B756 naval-HVT + r37 water-leg gate for land-only teams
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
							if (_tgtDist <= _teamReach && {_tgtDist < _nearReachD} && {((missionNamespace getVariable ["WFBE_C_AICOM_NAVAL_AIR_ONLY", 1]) <= 0) || {!(_x getVariable ["wfbe_is_naval_hvt", false])} || _teamAir} && {!([_ldrPos, getPos _x] Call _waterBlocks)}) then {_nearReachD = _tgtDist; _nearReach = _x}; //--- B756 naval-HVT + r37 water-leg gate
						} forEach _avail;
						if (!isNull _nearReach) then {
							_target = _nearReach;
						} else {
							//--- GUARDRAIL: nothing in reach. M5 offensive staging sends a foot team to the friendly town
							//--- closest to the enemy front, with a MOVE waypoint; the marker makes the next worker pass
							//--- re-enter target selection instead of treating staging as a permanent explicit order.
							if ((missionNamespace getVariable ["WFBE_C_AICOM_FOOT_STAGE", 0]) > 0 && {!_mounted}) then {
								private ["_footStageTown","_footStageD","_footCandidate","_footFrontD"];
								_footStageTown = objNull;
								_footStageD = 1e9;
								{
									_footCandidate = _x;
									if (!isNull _footCandidate && {(_footCandidate getVariable ["sideID", -1]) == _sideID}) then {
										_footFrontD = 1e9;
										{ if (!isNull _x && {(_x getVariable ["sideID", -1]) != _sideID} && {(_footCandidate distance _x) < _footFrontD}) then {_footFrontD = _footCandidate distance _x} } forEach _uncaptured;
										if (_footFrontD < _footStageD) then {_footStageD = _footFrontD; _footStageTown = _footCandidate};
									};
								} forEach towns;
								if (!isNull _footStageTown) then {
									if ((missionNamespace getVariable ["WFBE_C_AICOM_RETARGET_RECYCLE", 0]) > 0) then {
										private ["_fsOrd","_fsTgt","_fsCommit","_fsCounted","_fjR","_fjThrR"];
										_fsOrd = [_team, "wfbe_aicom_townorder", []] Call WFBE_CO_FNC_GroupGetBool;
										_fsTgt = if (count _fsOrd >= 1) then {_fsOrd select 0} else {objNull};
										_fsCommit = [_team, "wfbe_aicom_journey_commit_seen", false] Call WFBE_CO_FNC_GroupGetBool;
										_fsCounted = [_team, "wfbe_aicom_journey_failed_counted", false] Call WFBE_CO_FNC_GroupGetBool;
										if ([_team, "wfbe_aicom_dispatch_open", false] Call WFBE_CO_FNC_GroupGetBool) then {
											if (count _fsOrd >= 3 && {typeName _fsTgt == "OBJECT"} && {!isNull _fsTgt} && {(_fsTgt getVariable ["sideID", -1]) != _sideID} && {!_fsCommit} && {!_fsCounted} && {!(_fsTgt in _blTowns)}) then {
												_fjR = ([_team, "wfbe_aicom_failedjourneys", 0] Call WFBE_CO_FNC_GroupGetBool) + 1;
												_team setVariable ["wfbe_aicom_failedjourneys", _fjR];
												_team setVariable ["wfbe_aicom_journey_failed_counted", true];
												_fjThrR = missionNamespace getVariable ["WFBE_C_AICOM_FAILED_JOURNEYS_RECYCLE", 0];
												if (_fjThrR > 0 && {_fjR >= _fjThrR} && {!([_team, "wfbe_aicom_recycle", false] Call WFBE_CO_FNC_GroupGetBool)}) then {
													_team setVariable ["wfbe_aicom_recycle", true, true];
													diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|RECYCLE_FLAG|team=" + (str _team) + "|failedjourneys=" + str _fjR + "|reason=foot-stage");
												};
												diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|FOOT_STAGE_RECYCLE|team=" + (str _team) + "|failedjourneys=" + str _fjR);
											};
										};
									};
									[_team, "move"] Call SetTeamMoveMode;
									[_team, getPos _footStageTown] Call SetTeamMovePos;
									//--- r36 assault-staging: HC driver reads ONLY wfbe_aicom_order (WAVE-1 A3 pattern from Strategy
									//--- relief). Relying solely on Execute's move-mode dual-write left FOOT_STAGE teams waiting a
									//--- full supervisor tick (or stuck if Execute debounce held) while foot_stage=true excluded
									//--- them from the wedge watchdog - publish the order here.
									if ([_team, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool) then {
										_team setVariable ["wfbe_aicom_order", [(if (isNil {_team getVariable "wfbe_aicom_order"}) then {-1} else {(_team getVariable "wfbe_aicom_order") select 0}) + 1, "move", getPos _footStageTown], true];
									};
									_team setVariable ["wfbe_aicom_foot_stage", true];
									_team setVariable ["wfbe_aicom_foot_stage_pos", getPos _footStageTown];
									_team setVariable ["wfbe_aicom_townorder", [], false];
									_team setVariable ["wfbe_aicom_dispatch_open", false];
									_target = objNull;
									_explicitMode = false;
									diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|FOOT_STAGE|team=" + (str _team) + "|town=" + (_footStageTown getVariable ["name","town"]));
								} else {
									_target = [leader _team, _uncapturedF] Call WFBE_CO_FNC_GetClosestEntity;
								};
							} else {
							_target = [leader _team, _uncapturedF] Call WFBE_CO_FNC_GetClosestEntity; //--- WAVE-1 CAUSE-2: _uncapturedF (blacklist-filtered; guardrail above guarantees non-empty). B36.1 (Ray 2026-06-15): FULL uncaptured list, NOT the _assigned-reduced _avail. A team that just captured its town has dismounted + abandoned its trucks, so it scans on-foot (3500m reach); on a sparse map no town is in reach, this guardrail fires, and the old _avail (minus teammates' targets) sent it to a FARTHER town -> it milled at the just-capped centre. Nearest-of-all advances it to the adjacent town (concentration is fine for an isolated foot team).
							};
						};
					};
				};
				if (!isNil "_target") then {
					if (!isNull _target) then {
						_team setVariable ["wfbe_aicom_foot_stage", false];
						_team setVariable ["wfbe_aicom_foot_stage_pos", []];
						[_team, "towns"] Call SetTeamMoveMode;
						[_team, _target] Call SetTeamMovePos;
						//--- WAVE STAGGER (feat/aicom-wave-stagger, gate WFBE_C_AICOM_WAVE_STAGGER default 0): when
						//--- multiple teams converge on the SAME spearhead/assault town in THIS pass (this team's
						//--- fresh _target is already present in _assigned - an earlier team in this SAME forEach,
						//--- or a pre-seeded en-route team, already claimed it), stagger the actual order re-issue
						//--- by a per-team offset so arrivals spread out instead of piling onto one road at once.
						//--- REUSES the existing persistent lane-jitter var (wfbe_aicom_lanejit, same seed idiom
						//--- the HC road-route builder below already uses) rather than inventing new per-team
						//--- state. Pure order-timing: only the final order broadcast / movement command below is
						//--- delayed via a short spawn+sleep; concentration bookkeeping (_assigned, just below),
						//--- telemetry and dispatch latching stay synchronous and unchanged. Flag 0, or no
						//--- convergence (first team on a target), => _waveDelay stays 0 => both branches below
						//--- run inline exactly as before (byte-identical).
						_waveDelay = 0;
						if (((missionNamespace getVariable ["WFBE_C_AICOM_WAVE_STAGGER", 0]) > 0) && {({_x == _target} count _assigned) > 0}) then {
							private ["_waveJit","_waveMin","_waveMax"];
							_waveJit = _team getVariable "wfbe_aicom_lanejit";
							//--- r36 wave-sync: non-scalar / missing lanejit must not throw in the delay arithmetic
							if (isNil "_waveJit" || {typeName _waveJit != "SCALAR"}) then {_waveJit = (random 2) - 1; _team setVariable ["wfbe_aicom_lanejit", _waveJit, true]};
							_waveMin = missionNamespace getVariable ["WFBE_C_AICOM_WAVE_STAGGER_MIN", 30];
							_waveMax = missionNamespace getVariable ["WFBE_C_AICOM_WAVE_STAGGER_MAX", 90];
							if (typeName _waveMin != "SCALAR" || {_waveMin < 0}) then {_waveMin = 30};
							if (typeName _waveMax != "SCALAR" || {_waveMax < _waveMin}) then {_waveMax = _waveMin + 60};
							_waveDelay = _waveMin + (((_waveJit + 1) / 2) * (_waveMax - _waveMin));
						};
						//--- hc-locality-group-owner: demote HC flag if leader is server-local (HC drop) so this
						//--- branch falls through to AIMoveTo / SetTownAttackPath instead of publishing a dead order.
						if ([_team, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool) then {
							private "_atLdr";
							_atLdr = leader _team;
							if (!isNull _atLdr && {local _atLdr}) then {
								_team setVariable ["wfbe_aicom_hc", false, true];
								if (!([_team, "wfbe_aicom_founded", false] Call WFBE_CO_FNC_GroupGetBool)) then {
									_team setVariable ["wfbe_aicom_founded", true, true];
								};
								diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|HC_LOCALITY_DEMOTE|team=" + (str _team) + "|reason=assigntowns-local-leader");
							};
						};
						if ([_team, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool) then {
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
							_hcStrk   = [_team, "wfbe_aicom_stuckstrikes", 0] Call WFBE_CO_FNC_GroupGetBool;
							//--- Build up to N road-snapped waypoints evenly between origin and dest.
							//--- Each guess is the straight-line fraction point; we snap it to the nearest
							//--- real road node (nearRoads) so the convoy follows lanes A2 PFM can drive.
							//--- If no road is near a guess, we skip that hop (the executor still falls back
							//--- to a direct MOVE for that segment). Only build a route on the long leg.
							_hcRoute = [];
							if ((_hcOrigin distance _hcDest) > 700) then {
								_rmHops = 8 max ((round ((_hcOrigin distance _hcDest) / (missionNamespace getVariable ["WFBE_C_AICOM_ROUTE_HOP_SPACING", 600]))) min (missionNamespace getVariable ["WFBE_C_AICOM_ROUTE_HOP_MAX", 24]));  //--- Build84: scale road-node density with leg length (~1 node/600m, cap 24) so 12.8km legs get ~21 hops (~600m apart) instead of a fixed 8 (~1400m gaps that beeline into path-stalls)
								//--- A2-fix 2026-06-14 (owner: teams move INDIVIDUALLY to same town = better speed): base-egress road node so teams escape a boxed/corner base, + per-team lateral lane so concentrated teams don't funnel one road.
								//--- Road-node chain extracted to WFBE_CO_FNC_BuildRoadRoute (shared with the war-room console path AI_Commander_Execute.sqf) - behaviour-identical to the prior inline builder; this keeps the per-team lane jitter here as the caller owns the persistent wfbe_aicom_lanejit var.
								_laneJit = _team getVariable "wfbe_aicom_lanejit";
								if (_strandRecovery && {!isNil "_mounted"} && {_mounted}) then {_laneJit = (random 2) - 1; _team setVariable ["wfbe_aicom_lanejit", _laneJit, true]} else {if (isNil "_laneJit") then {_laneJit = (random 2) - 1; _team setVariable ["wfbe_aicom_lanejit", _laneJit, true]}};
								_hcRoute = [_hcOrigin, _hcDest, _laneJit * (missionNamespace getVariable ["WFBE_C_AICOM_LANE_OFFSET", 120]), _rmHops] Call WFBE_CO_FNC_BuildRoadRoute; //--- cmdcon42-h: lane amplitude is worldName-aware (CH 120 / TK 60) via WFBE_C_AICOM_LANE_OFFSET.
							};
							//--- B37 (Ray 2026-06-16): INSTRUMENT the unstuck strike so we can VERIFY it triggers + at which
							//--- tier. Pairs with UNSTUCK_FIRED (Common_RunCommanderTeam) + the existing ASSAULT_STRANDED
							//--- moved/stuck line, giving the full strike -> fire -> recover lifecycle in the RPT.
							if (_hcStrk > 0) then { diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|UNSTUCK_STRIKE|team=" + (str _team) + "|tier=" + str _hcStrk); };
							//--- WAVE STAGGER: when converging on a shared target (_waveDelay > 0, computed above), defer
							//--- ONLY the final order broadcast (route/unstuck/order + its ORDER_PUBLISHED log) via a short
							//--- spawn+sleep so this team's march starts later than the team(s) already aimed at the same
							//--- town. Everything above (route build, strike instrumentation) stays synchronous/unchanged.
							if (_waveDelay > 0) then {
								private "_wsSeqSnap0";
								_wsSeqSnap0 = if (isNil {_team getVariable "wfbe_aicom_order"}) then {-1} else {(_team getVariable "wfbe_aicom_order") select 0};
								[_team, _hcRoute, _hcStrk, _hcDest, _sideText, _waveDelay, _wsSeqSnap0] spawn {
									private ["_wsTeam","_wsRoute","_wsStrk","_wsDest","_wsSideText","_wsDelay","_wsSeqSnap","_wsSeqNow"];
									_wsTeam = _this select 0; _wsRoute = _this select 1; _wsStrk = _this select 2; _wsDest = _this select 3; _wsSideText = _this select 4; _wsDelay = _this select 5; _wsSeqSnap = _this select 6;
									sleep _wsDelay;
									_wsSeqNow = if (isNil {_wsTeam getVariable "wfbe_aicom_order"}) then {-1} else {(_wsTeam getVariable "wfbe_aicom_order") select 0};
									//--- ORDER-GENERATION GUARD (codex hold remediation): if a newer order was published for this
									//--- team while this wave-stagger thread slept (seq bumped by a fresher retask), drop this
									//--- stale order silently - the newer order wins. Only publish when the seq is unchanged.
									if (!isNull _wsTeam && {({alive _x} count (units _wsTeam)) > 0} && {_wsSeqNow == _wsSeqSnap}) then {
										_wsTeam setVariable ["wfbe_aicom_route", _wsRoute, true];
										_wsTeam setVariable ["wfbe_aicom_unstuck", _wsStrk, true];
										_wsTeam setVariable ["wfbe_aicom_order", [_wsSeqSnap + 1, "towns-target", _wsDest, _wsStrk], true]; //--- feat/aicom-wave-stagger: same order-broadcast statement as the synchronous else-branch, just deferred; seq guarded above so a stale wave never clobbers a fresher retask.
										diag_log ("AICOMSTAT|v2|EVENT|" + _wsSideText + "|" + str (round (time / 60)) + "|CAPTURE_TRACE|ORDER_PUBLISHED|team=" + (str _wsTeam) + "|mode=towns-target|wave=1|delay=" + str (round _wsDelay));
									};
								};
							} else {
								_team setVariable ["wfbe_aicom_route", _hcRoute, true];
								_team setVariable ["wfbe_aicom_unstuck", _hcStrk, true];
								_team setVariable ["wfbe_aicom_order", [(if (isNil {_team getVariable "wfbe_aicom_order"}) then {-1} else {(_team getVariable "wfbe_aicom_order") select 0}) + 1, "towns-target", _hcDest, _hcStrk], true]; //--- UNSTUCK FIX (Ray 2026-06-16): carry the strike tier as order element 3 so it stays in sync with the seq it belongs to (reader: Common_RunCommanderTeam). The wfbe_aicom_unstuck flag (line ~367) is kept for the gear-slow governor + logging.
								diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|CAPTURE_TRACE|ORDER_PUBLISHED|team=" + (str _team) + "|mode=towns-target|town=" + (_target getVariable ["name","town"]) + "|dist=" + str (round (_hcOrigin distance _hcDest)) + "|route=" + str (count _hcRoute) + "|strike=" + str _hcStrk);
							};
						} else {
							if (_waveDelay > 0) then {
								private "_wsSeqSnap0";
								_wsSeqSnap0 = if (isNil {_team getVariable "wfbe_aicom_order"}) then {-1} else {(_team getVariable "wfbe_aicom_order") select 0};
								[_team, _target, _useArc, _waveDelay, _wsSeqSnap0] spawn {
									private ["_wsTeam","_wsTarget","_wsArc","_wsDelay","_wsSeqSnap","_wsSeqNow"];
									_wsTeam = _this select 0; _wsTarget = _this select 1; _wsArc = _this select 2; _wsDelay = _this select 3; _wsSeqSnap = _this select 4;
									sleep _wsDelay;
									_wsSeqNow = if (isNil {_wsTeam getVariable "wfbe_aicom_order"}) then {-1} else {(_wsTeam getVariable "wfbe_aicom_order") select 0};
									//--- ORDER-GENERATION GUARD (codex delta remediation): if a newer order was published for this
									//--- team while this wave-stagger thread slept (seq bumped by a fresher retask), drop this
									//--- stale direct move silently - the newer order wins. Only issue when the seq is unchanged.
									if (!isNull _wsTeam && {!isNull _wsTarget} && {({alive _x} count (units _wsTeam)) > 0} && {_wsSeqNow == _wsSeqSnap}) then {
										if (_wsArc) then {
											[_wsTeam, _wsTarget] Call WFBE_SE_FNC_AI_SetTownAttackPath;
										} else {
											[_wsTeam, getPos _wsTarget, "SAD", 200] Call AIMoveTo;
										};
									};
								};
							} else {
								if (_useArc) then {
									[_team, _target] Call WFBE_SE_FNC_AI_SetTownAttackPath;
								} else {
									[_team, getPos _target, "SAD", 200] Call AIMoveTo;
								};
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
						private ["_priorOrd","_priorOpen","_dispT0","_priorDispT0","_sameTgt"];
						_priorOrd  = [_team, "wfbe_aicom_townorder", []] Call WFBE_CO_FNC_GroupGetBool;
						_priorOpen = [_team, "wfbe_aicom_dispatch_open", false] Call WFBE_CO_FNC_GroupGetBool;
						_sameTgt   = (count _priorOrd >= 1) && {(typeName (_priorOrd select 0)) == "OBJECT"} && {(_priorOrd select 0) == _target};
						_priorDispT0 = if (count _priorOrd >= 2) then {_priorOrd select 1} else {time};
						//--- r36 wave-sync: WAVE_STAGGER defers the actual MOVE/order by _waveDelay, but the assault
						//--- strand clock used to start at assignment time - second+ teams lost 30-90s of budget while
						//--- sitting still. New dispatches start the clock when the delayed march is due to fire.
						_dispT0    = if (_priorOpen && _sameTgt && {count _priorOrd >= 2}) then {_priorDispT0} else {
							if (!isNil "_waveDelay" && {typeName _waveDelay == "SCALAR"} && {_waveDelay > 0}) then {time + _waveDelay} else {time}
						};
						//--- FIX A: distance/mobility-aware assault timeout (fable, GR-2026-07-08a; design ASSAULT-DYNTIMEOUT-DESIGN.md
						//--- S2.5). _asltSpeed/_asltDist/_asltToSecs are in the top-of-file private list. _mounted/_teamAir are the
						//--- SAME locals the reach gate above already computed this iteration (no re-scan of units _team).
						if ((missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_DYNTIMEOUT", 0]) > 0) then {
							if (_priorOpen && _sameTgt && {count _priorOrd >= 4}) then {
								//--- Re-issue on the SAME target: preserve the ORIGINAL per-dispatch budget, mirroring the existing
								//--- _dispT0 preservation immediately above so a stuck re-issue does not silently grant a fresh clock.
								_asltToSecs = _priorOrd select 3;
							} else {
								//--- DEFECT-1 FIX (fable, GR-2026-07-08a, adversarial-verify): the bootstrap branch (:601-623,
								//--- taken whenever _bootstrap is true - universal at match start since WFBE_C_AICOM_BOOTSTRAP_BIAS
								//--- defaults 1) never assigns _mounted/_teamAir (only the else-branch at :644/:648 does), so on a
								//--- bootstrap-branch dispatch both are still nil here. isNil-guard both reads and fall back to the
								//--- conservative FOOT speed profile (safe: bootstrap dispatches are early-game, short-range, nearest-
								//--- to-HQ picks) instead of throwing "Type Any, expected Bool". Non-bootstrap behaviour is byte-
								//--- identical (both vars are always non-nil booleans there, so !isNil is always true).
								_asltSpeed  = if (!isNil "_teamAir" && {_teamAir}) then {missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_SPEED_AIR", 35]} else {
									if (!isNil "_mounted" && {_mounted}) then {missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_SPEED_MOUNTED", if (worldName == "Takistan") then {3.5} else {7.5}]} else {missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_SPEED_FOOT", if (worldName == "Takistan") then {0.9} else {2.2}]}
								};
								_asltDist   = (leader _team) distance _target;
								_asltToSecs = ((_asltDist / _asltSpeed) * (missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_ROUTE_FACTOR", if (worldName == "Takistan") then {2.5} else {1.25}])) + (missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_SLACK", 120]);
								_asltToSecs = (_asltToSecs max (missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_TIMEOUT_MIN", 420])) min (missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_TIMEOUT_MAX", if (worldName == "Takistan") then {2700} else {1500}]);
							};
						} else {
							_asltToSecs = missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_TIMEOUT", 420];   //--- flag-off: legacy flat value: tuple still gets a 4th element for schema consistency but its VALUE equals the pre-patch default, so the outcome watcher decision is byte-identical.
						};
						if ((missionNamespace getVariable ["WFBE_C_AICOM_RETARGET_RECYCLE", 0]) > 0 && {_priorOpen} && {!_sameTgt} && {count _priorOrd >= 3} && {(typeName (_priorOrd select 0)) == "OBJECT"} && {!isNull (_priorOrd select 0)} && {((_priorOrd select 0) getVariable ["sideID", -1]) != _sideID}) then {
							private ["_priorCommit","_priorCounted","_fjR","_fjThrR"];
							_priorCommit = [_team, "wfbe_aicom_journey_commit_seen", false] Call WFBE_CO_FNC_GroupGetBool;
							_priorCounted = [_team, "wfbe_aicom_journey_failed_counted", false] Call WFBE_CO_FNC_GroupGetBool;
							if (!_priorCommit && {!_priorCounted}) then {
								_fjR = ([_team, "wfbe_aicom_failedjourneys", 0] Call WFBE_CO_FNC_GroupGetBool) + 1;
								_team setVariable ["wfbe_aicom_failedjourneys", _fjR];
								_team setVariable ["wfbe_aicom_journey_failed_counted", true];
								_fjThrR = missionNamespace getVariable ["WFBE_C_AICOM_FAILED_JOURNEYS_RECYCLE", 0];
								if (_fjThrR > 0 && {_fjR >= _fjThrR} && {!([_team, "wfbe_aicom_recycle", false] Call WFBE_CO_FNC_GroupGetBool)}) then {
									_team setVariable ["wfbe_aicom_recycle", true, true];
									diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|RECYCLE_FLAG|team=" + (str _team) + "|failedjourneys=" + str _fjR + "|reason=retarget");
								};
								diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|RETARGET_RECYCLE|team=" + (str _team) + "|failedjourneys=" + str _fjR + "|committed=false");
							};
						};
						//--- fable/assault-retarget-telemetry (2026-07-10): when a team with an OPEN dispatch is re-aimed at a
						//--- DIFFERENT town (_priorOpen && !_sameTgt), the old dispatch's outcome-watcher (Hook B) is silently
						//--- overwritten below and never logs ARRIVED/STRANDED - which is why ~84% of dispatches had no terminal
						//--- outcome (mostly legitimate re-targeting, NOT failed attacks). Log RETARGET so the accounting closes:
						//--- DISPATCH = ARRIVED + STRANDED + RETARGET + (in-flight). Pure telemetry, zero behaviour change.
						if (_priorOpen && {!_sameTgt} && {count _priorOrd >= 1} && {(typeName (_priorOrd select 0)) == "OBJECT"} && {!isNull (_priorOrd select 0)}) then {
							diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|ASSAULT_RETARGET|team=" + (str _team) + "|from=" + ((_priorOrd select 0) getVariable ["name","town"]) + "|to=" + (_target getVariable ["name","town"]) + "|elapsed=" + str (round (time - _priorDispT0)));
						};
						if (((missionNamespace getVariable ["WFBE_C_AICOM_RETARGET_GRACE_DISPATCHES", 0]) > 0) || {(missionNamespace getVariable ["WFBE_C_AICOM_RETARGET_RECYCLE", 0]) > 0}) then {
							if (!_priorOpen || {!_sameTgt}) then {_team setVariable ["wfbe_aicom_journey_commit_seen", false]};
						};
						if ((missionNamespace getVariable ["WFBE_C_AICOM_RETARGET_GRACE_DISPATCHES", 0]) > 0) then {
							private "_nextGraceCount";
							if (_priorOpen && _sameTgt) then {_nextGraceCount = ([_team, "wfbe_aicom_retarget_grace", 0] Call WFBE_CO_FNC_GroupGetBool) + 1} else {_nextGraceCount = 0};
							_team setVariable ["wfbe_aicom_retarget_grace", _nextGraceCount];
						};
						if ((missionNamespace getVariable ["WFBE_C_AICOM_RETARGET_RECYCLE", 0]) > 0) then {_team setVariable ["wfbe_aicom_journey_failed_counted", false]};
						_team setVariable ["wfbe_aicom_townorder", [_target, _dispT0, getPos (leader _team), _asltToSecs]];
						//--- Round-3 review: dedicated TARGET-CHANGE timestamp. _dispT0 refreshes on same-target
						//--- re-issues, so it is NOT a stable "how long has this team been aimed here" basis - the
						//--- retarget cooldown reads wfbe_aicom_tgt_since instead, stamped ONLY when the target
						//--- actually changes (first dispatch or a different town).
						if ((missionNamespace getVariable ["WFBE_C_AICOM_SMALLMAP_TUNE", 0]) > 0 && {(toLower worldName) == "zargabad"} && {!_priorOpen || {!_sameTgt}}) then {_team setVariable ["wfbe_aicom_tgt_since", time]}; // group state key, not a classname
						//--- ASSAULT TELEMETRY (task #48, #2): book a watcher latch on every (re)dispatch and
						//--- log the DISPATCH event. The OUTCOME watcher (Hook B, top of the per-team loop)
						//--- resolves exactly one ARRIVED or STRANDED per dispatch. Logging only - no behaviour
						//--- change. Town center = getPos _target; name via the broadcast "name" var.
						_team setVariable ["wfbe_aicom_dispatch_open", true];
						//--- WASPSCALE disp counter (cmdcon42): bump the cumulative-dispatch counter the server-side WASPSCALE emit reads (disp=). Server-local, monotonic; counts every (re)dispatch, matching the ASSAULT_DISPATCH log below.
						missionNamespace setVariable ["wfbe_waspscale_disp", (missionNamespace getVariable ["wfbe_waspscale_disp", 0]) + 1];
						_logik setVariable ["wfbe_aicom_arrival_dispatched", (_logik getVariable ["wfbe_aicom_arrival_dispatched", 0]) + 1];
						diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|ASSAULT_DISPATCH|team=" + (str _team) + "|town=" + (_target getVariable ["name","town"]) + "|dist=" + str (round ((leader _team) distance _target)) + "|reissue=" + str (_priorOpen && _sameTgt));
						//--- GRUDGE LEDGER (feat/aicom-grudge-ledger, generated by apply_grudge.py): GRUDGE_RETURN telemetry + one-shot barrage-request stamp on dispatch to a live grudge town
						if ((missionNamespace getVariable ["WFBE_C_AICOM_GRUDGE", 0]) > 0) then {
													private ["_grList","_grHit","_grEntry","_grNew"];
													_grList = _logik getVariable ["wfbe_aicom_grudge", []];
													_grHit = -1;
													{ if (!(_grHit >= 0) && {typeName (_x select 0) == "OBJECT"} && {!isNull (_x select 0)} && {(_x select 1) > time} && {(_x select 0) == _target}) then {_grHit = _forEachIndex} } forEach _grList;
													if (_grHit >= 0) then {
														diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|GRUDGE_RETURN|team=" + (str _team) + "|town=" + (_target getVariable ["name","town"]) + "|dist=" + str (round ((leader _team) distance _target)));
														if ((missionNamespace getVariable ["WFBE_C_AICOM_GRUDGE_BARRAGE", 0]) > 0) then {
															_grEntry = _grList select _grHit;
															if (count _grEntry < 3 || {!(_grEntry select 2)}) then {
																_grNew = +_grList;
																_grNew set [_grHit, [_target, _grEntry select 1, true]];
																_logik setVariable ["wfbe_aicom_grudge", _grNew];
																_logik setVariable ["wfbe_aicom_grudge_barrage_request", [getPos _target, time]];
																diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|GRUDGE_BARRAGE_REQUEST|town=" + (_target getVariable ["name","town"]));
															};
														};
													};
						};
						["INFORMATION", Format ["AI_Commander_AssignTowns.sqf: [%1] team [%2] heading to attack town [%3].", _sideText, _team, _target getVariable ["name", "town"]]] Call WFBE_CO_FNC_AICOMLog;
					};
				};
			};
		};
	};
	}; //--- V0.6.5 null-team guard
} forEach _teams;
