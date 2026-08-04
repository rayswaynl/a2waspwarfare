/*
	Side patrol driver (Patrols upgrade).
	Every ~20s, per present side: if the side has researched Patrols (level 1-3) and
	is under the concurrent cap, spawn one patrol at the friendly town nearest the
	side's HQ. Tier follows the upgrade level (1=LIGHT, 2=MEDIUM, 3=HEAVY pools from
	the faction Root configs - the pools are server-only, so the TEMPLATE is resolved
	here and shipped to the runner). The patrol itself runs on a live headless client
	when one is registered, otherwise on the server (Common_RunSidePatrol.sqf).
	Replaces the old fixed-random-towns patrol system (Init_Towns flagging retired).
*/

scriptName "Server\FSM\server_side_patrols.sqf";

private ["_side","_sideID","_logik","_upgrades","_lvl","_active","_last","_hq","_owned","_home","_tier","_pool","_template","_hcUnit","_delay","_max","_maxSide","_scrubLast","_kept","_changed","_entry","_removed","_aKept",
	"_mpEnabled","_mpMotoPool","_mpEntry","_mpHasVeh","_mpC","_mpRosterChoices","_mpChoice",
	"_escEnabled","_escScore","_escMins","_escPopMax","_escTierIdx","_escBaseIdx","_escTiers","_escVehCap","_escHadVeh","_escEscort","_escSideVeh",
	"_homePool","_spSkipNaval","_hpX",
	"_feedChangeOnly","_feedKeepAlive","_feedSig","_feedLastSig","_feedChanged","_feedDue","_feedLastBroadcast",
	"_perfProbe","_perfCap","_perfReason","_perfPopTier",
	"_rcSide","_rcSideID","_rcLogik","_rcCount","_rcOld","_entryLdr","_entryGrp",
	"_pwEnabled","_pwLastSample","_pwMins","_pwDist","_pwWpDist","_pwMaxStrikes","_pwEntry","_pwLdr","_pwSideID","_pwGrp","_pwVeh","_pwPos","_pwWpPos","_pwLastPos","_pwStrikes","_pwSide","_pwTier","_pwUnits","_pwVehicles","_pwV","_pwFound","_pwWpIdx","_pwSample"];  //--- cmdcon41-w3m: +_homePool/_spSkipNaval/_hpX (naval-HVT-excluded spawn-town pool). fix/alife-leak-hardening: +_rcSide/_rcSideID/_rcLogik/_rcCount/_rcOld (side-patrol slot-leak reconciler); +_entryLdr/_entryGrp (B66-style any-live-member scrub test, review-1254 defect fix). Grok idea #8 (side-patrol stuck watchdog): +_pw* (see WFBE_C_SIDE_PATROL_UNSTUCK block below).

waitUntil {townInitServer};
sleep 30;
//--- Perf phase jitter (2026-07-06): see server_town.sqf. Default 0 = V1.
if ((missionNamespace getVariable ["WFBE_C_LOOP_PHASE_JITTER", 0]) > 0) then {sleep (random 20)};

if (isNil "WFBE_ACTIVE_PATROLS") then {WFBE_ACTIVE_PATROLS = []; publicVariable "WFBE_ACTIVE_PATROLS"};
//--- Commander-team arrow-marker feed (task #3), broadcast like WFBE_ACTIVE_PATROLS. Maintained by
//--- the aicom-team-created / -ended / -heading cases in Server_HandleSpecial.sqf; init once here so
//--- JIP clients see a defined empty array. Entries: [leader, sideID, dir, team].
if (isNil "WFBE_ACTIVE_AICOM_TEAMS") then {WFBE_ACTIVE_AICOM_TEAMS = []; publicVariable "WFBE_ACTIVE_AICOM_TEAMS"};

_delay = missionNamespace getVariable ["WFBE_C_PATROLS_DELAY_SPAWN", 360];  //--- 2-arg default (was 1-arg): matches the Init_Server.sqf value and the sibling reads at L39/L49. Guards the -(_delay) / (time - _last > _delay) reads below from an Undefined-variable throw when the constant has not been published yet (observed under long lab runs), which otherwise spams every cycle and never issues a patrol.
//--- B74.2 (Ray 2026-06-23): WEST/EAST side-patrol cap is now POP-TIER aware (was the flat
//--- WFBE_C_SIDE_PATROLS_MAX). Read WFBE_C_SIDE_PATROLS_MAX_BY_TIER select WFBE_PopTier per cycle (the
//--- server publishes WFBE_PopTier 0=LOW/1=MID/2=HIGH/3=FULL, changing ~every 90s) so the concurrent
//--- patrol cap eases off as population rises (BY_TIER = [2,2,2,1]); the EFFECTIVE cap stays level-aware =
//--- min(this, patrol level) at L101. SAME consumer idiom as AI_Commander_Produce/Teams (B74.2). _max is
//--- (re)assigned at the top of every loop cycle below. A2-OA-safe (plain getVariable+select, `max 0`).
_max = (missionNamespace getVariable ["WFBE_C_SIDE_PATROLS_MAX_BY_TIER", [2,2,2,1]]) select (((missionNamespace getVariable ["WFBE_PopTier", 0]) max 0) min 3);
_scrubLast = -999;
_pwLastSample = -999;
_feedLastSig = "";
_feedLastBroadcast = -999;
_perfProbe = (missionNamespace getVariable ["WFBE_C_PERFORMANCE_AUDIT_SIDE_PATROL_PROBES", 0]) > 0;

while {!WFBE_GameOver} do {
	//--- B74.2 (Ray 2026-06-23): re-read the pop-tier-scaled WEST/EAST cap each cycle so it tracks the live
	//--- WFBE_PopTier (republished ~every 90s) instead of being frozen at the value read once at startup.
	_perfPopTier = (missionNamespace getVariable ["WFBE_PopTier", 0]) max 0;
	_max = (missionNamespace getVariable ["WFBE_C_SIDE_PATROLS_MAX_BY_TIER", [2,2,2,1]]) select ((_perfPopTier) min 3);

	//--- PATROL-MARKER SCRUB: every ~20 s, purge dead-unit entries from WFBE_ACTIVE_PATROLS
	//--- so HC-disconnect mid-patrol can't leave stale entries that JIP clients render.
	//--- Uses explicit forEach (A2-safe; no select-with-code-filter).
	if (time - _scrubLast > 20) then {
		_kept = [];
		_changed = false;
		//--- REVIEW FIX (review-1254 #2): the ORIGINAL scrub test here was leader-only (`alive
		//--- (_entry select 0)`) - WFBE_ACTIVE_PATROLS entries only store the leader unit + sideID
		//--- (no group slot, unlike WFBE_ACTIVE_AICOM_TEAMS below). If the ORIGINAL leader died but
		//--- other patrol members are still alive, the patrol keeps running (Common_RunSidePatrol.sqf's
		//--- own _alive test checks ANY live unit) but this scrub dropped its entry anyway - previously
		//--- a cosmetic early-vanish of the map arrow (same bug class B66 already fixed below for
		//--- WFBE_ACTIVE_AICOM_TEAMS), but now load-bearing: the fix/alife-leak-hardening #2 reconciler
		//--- below counts straight off _kept, so an entry dropped while the patrol is still alive would
		//--- UNDERCOUNT wfbe_side_patrols and let the side over-spawn past its concurrent-patrol cap.
		//--- Derive the group from the (possibly dead) leader and key the keep-test on ANY live member,
		//--- same B66 idiom as the AICOM-team scrub just below.
		{
			_entry = _x;
			_entryLdr = _entry select 0;
			_entryGrp = grpNull;
			if (!isNull _entryLdr) then {_entryGrp = group _entryLdr};
			if (!isNull _entryGrp && {{alive _x} count (units _entryGrp) > 0}) then {
				_kept set [count _kept, _entry];
			} else {
				_changed = true;
			};
		} forEach WFBE_ACTIVE_PATROLS;
		if (_changed) then {
			_removed = (count WFBE_ACTIVE_PATROLS) - (count _kept);
			WFBE_ACTIVE_PATROLS = _kept;
			["INFORMATION", Format["server_side_patrols.sqf: scrub removed %1 dead-unit patrol entries from WFBE_ACTIVE_PATROLS.", _removed]] Call WFBE_CO_FNC_AICOMLog;
		};

		//--- LEAK FIX (fix/alife-leak-hardening #2): wfbe_side_patrols is booked at DISPATCH
		//--- (below, ~L285) and released ONLY by the "sidepatrol-ended" HandleSpecial case, which
		//--- is only ever sent from Common_RunSidePatrol.sqf's own exit code. An HC disconnect, HC
		//--- freeze, or runner-abort mid-patrol never reaches that exit code, so the counter can
		//--- permanently outlive the patrol it was counting - the side then sits at cap and stops
		//--- getting new patrols for the rest of the match. _kept (just above) is the freshly-
		//--- scrubbed, alive-leader-only WFBE_ACTIVE_PATROLS; reconcile each present side's counter
		//--- to that LIVE count every ~20s so a leaked slot self-heals no matter how it leaked,
		//--- instead of depending on catching every individual disconnect/abort path.
		{
			_rcSide = _x;
			_rcSideID = (_rcSide) Call WFBE_CO_FNC_GetSideID;
			_rcLogik = (_rcSide) Call WFBE_CO_FNC_GetSideLogic;
			if (!isNull _rcLogik) then {
				_rcCount = {(_x select 1) == _rcSideID} count _kept;
				_rcOld = _rcLogik getVariable ["wfbe_side_patrols", 0];
				if (_rcOld != _rcCount) then {
					_rcLogik setVariable ["wfbe_side_patrols", _rcCount];
					["WARNING", Format["server_side_patrols.sqf: reconciled wfbe_side_patrols for [%1] %2 -> %3 (live patrol count).", _rcSide, _rcOld, _rcCount]] Call WFBE_CO_FNC_AICOMLog;
				};
			};
		} forEach WFBE_PRESENTSIDES;

		//--- B63 (Ray 2026-06-21): also scrub dead-leader AICOM-team entries. Previously these were
		//--- dropped ONLY on the aicom-team-ended event; a leader killed without that event left a
		//--- stale arrow on every client. Slots: [leader, sideID, dir, team].
		_aKept = [];
		{
			//--- B66 (Ray 2026-06-21): key the keep-test on the TEAM (slot3) having a LIVE member,
			//--- NOT on the original leader being alive. A team whose founding leader died but still has
			//--- live units must keep its arrow (pairs with the aicom-arrows fix); the B63 form
			//--- `alive (_x select 0)` wrongly dropped a live team the instant its first leader fell.
			if (!isNull (_x select 3) && {{alive _x} count (units (_x select 3)) > 0}) then {_aKept set [count _aKept, _x]};
		} forEach WFBE_ACTIVE_AICOM_TEAMS;
		WFBE_ACTIVE_AICOM_TEAMS = _aKept;

		//--- B63 (Ray 2026-06-21) JIP-DURABILITY FIX (THE no-own-markers root cause). In A2-OA a
		//--- `publicVariable` is NOT replayed to a client that JIP-joins AFTER the broadcast (there is
		//--- no JIP PV queue like A3). On a dedicated server EVERY player is a JIP joiner, so each one
		//--- starts with an EMPTY WFBE_ACTIVE_AICOM_TEAMS / WFBE_ACTIVE_PATROLS and the own-side
		//--- commander-team + patrol ARROW loops (updateaicommarkers/updatepatrolmarkers) have nothing
		//--- to paint until the server happens to re-broadcast on a team/heading event. Town & structure
		//--- markers work because they ride setVariable [...,true] (engine-replicated, JIP-durable). Fix:
		//--- re-broadcast BOTH feeds every cycle so any late joiner gets the current lists within ~20s.
		//--- Small arrays at 20s cadence = negligible bandwidth. Server_OnPlayerConnected does an
		//--- instant targeted catch-up on top of this so a fresh joiner doesn't wait the full cycle.
		//--- B74.2 (Ray 2026-06-23): this re-broadcast is INTENTIONALLY UNCONDITIONAL - it is NOT gated on
		//--- patrols/teams existing (it sits in the unconditional ~20s timer block), so a joiner whose
		//--- connect-time catch-up was missed always gets a fresh copy of BOTH feeds within one cycle. The
		//--- WFBE_ReqAicomFeed request handler (Init_Server) provides an instant on-demand path on top of this.
		//--- Lane 111: operators can opt into change-aware broadcasts. Default 0 preserves the exact
		//--- legacy every-cycle rebroadcast; mode 1 publishes on feed changes and keeps a bounded
		//--- heartbeat so missed connect-time catch-up still self-heals.
		_feedChangeOnly = (missionNamespace getVariable ["WFBE_C_SIDE_PATROL_FEED_CHANGE_ONLY", 0]) > 0;
		if (_feedChangeOnly) then {
			_feedKeepAlive = missionNamespace getVariable ["WFBE_C_SIDE_PATROL_FEED_KEEPALIVE", 60];
			if (_feedKeepAlive < 20) then {_feedKeepAlive = 20};
			_feedSig = str [WFBE_ACTIVE_PATROLS, WFBE_ACTIVE_AICOM_TEAMS];
			_feedChanged = false;
			if (!(_feedSig in [_feedLastSig])) then {_feedChanged = true};
			_feedDue = (time - _feedLastBroadcast) >= _feedKeepAlive;
			if (_feedChanged || {_feedDue}) then {
				publicVariable "WFBE_ACTIVE_PATROLS";
				publicVariable "WFBE_ACTIVE_AICOM_TEAMS";
				_feedLastSig = _feedSig;
				_feedLastBroadcast = time;
			};
		} else {
			publicVariable "WFBE_ACTIVE_PATROLS";
			publicVariable "WFBE_ACTIVE_AICOM_TEAMS";
			_feedLastSig = str [WFBE_ACTIVE_PATROLS, WFBE_ACTIVE_AICOM_TEAMS];
			_feedLastBroadcast = time;
		};

		_scrubLast = time;
	};

	//--- SIDE-PATROL STUCK WATCHDOG (Grok idea #8, 2026-07-25): side patrols run their OWN waypoint
	//--- loop and never receive AICOM's global unstuck care (see Common_RunUnstuckRecovery.sqf's own
	//--- header). Common_RunSidePatrol.sqf already carries an INTERNAL en-route stuck detector
	//--- (~90s cadence) - but it lives in the patrol's OWN thread, so it goes silent along with the
	//--- rest of that thread if the owning machine (a delegated HC) hangs or freezes. This is a
	//--- SEPARATE, EXTERNAL backstop: it samples each active patrol's lead-vehicle POSITION ONLY (no
	//--- nearEntities - stays trivial-cost) at a slower ~WFBE_C_SIDE_PATROL_UNSTUCK_MINS-minute
	//--- interval, so it keeps working even if the patrol's own thread stalls. Flag-gated, default OFF.
	_pwEnabled = (missionNamespace getVariable ["WFBE_C_SIDE_PATROL_UNSTUCK", 0]) > 0;
	if (_pwEnabled) then {
		_pwMins = missionNamespace getVariable ["WFBE_C_SIDE_PATROL_UNSTUCK_MINS", 3];
		if (_pwMins < 1) then {_pwMins = 3};
		if (time - _pwLastSample > (_pwMins * 60)) then {
			_pwLastSample = time;
			_pwDist       = missionNamespace getVariable ["WFBE_C_SIDE_PATROL_UNSTUCK_DIST", 20];
			_pwWpDist     = missionNamespace getVariable ["WFBE_C_SIDE_PATROL_UNSTUCK_WP_DIST", 150];
			_pwMaxStrikes = missionNamespace getVariable ["WFBE_C_SIDE_PATROL_UNSTUCK_MAX_STRIKES", 3];
			{
				_pwEntry  = _x;
				_pwLdr    = _pwEntry select 0;
				_pwSideID = _pwEntry select 1;
				//--- fix(alife-stall r34): entry stores founding leader; scrub keeps the entry after that leader dies while the patrol still has live units.
				//--- Gating the external stuck watchdog on alive(_pwLdr) made the HC-hang backstop blind for the rest of the patrol lifetime.
				_pwGrp = grpNull;
				if (!isNull _pwLdr) then {_pwGrp = group _pwLdr};
				_pwSample = objNull;
				if (!isNull _pwGrp) then {
					_pwSample = leader _pwGrp;
					if (isNull _pwSample || {!alive _pwSample}) then {
						{if (isNull _pwSample && {alive _x}) then {_pwSample = _x}} forEach (units _pwGrp);
					};
				};
				if (!isNull _pwSample && {alive _pwSample} && {!isNull _pwGrp}) then {
					_pwLdr = _pwSample;
					if (!isNull _pwGrp) then {
						_pwVeh   = vehicle _pwLdr;
						_pwPos   = getPos _pwVeh;
						//--- currentWaypointPosition is not a real A2-OA command; the resulting parse error ("Error
						//--- Missing ;") killed this WHOLE file at ExecVM compile - no patrol logic ran all match
						//--- (dbg0726e ZG soak). Guarded A2 idiom per Common_GetTeamMarkerDestPos.sqf: currentWaypoint
						//--- returns lastIndex+1 once all waypoints are complete; [0,0,0] = the existing skip path below.
						_pwWpIdx = currentWaypoint _pwGrp;
						_pwWpPos = [0,0,0];
						if (_pwWpIdx < count (waypoints _pwGrp)) then {_pwWpPos = waypointPosition [_pwGrp, _pwWpIdx]};
						//--- Only a patrol with a genuinely DISTANT live waypoint can be "stuck" - a patrol
						//--- that already arrived (camp sweep, town-center hold, convoy payout) sits close
						//--- to its last-laid waypoint and is correctly SKIPPED here, never mistaken for wedged.
						if (!((_pwWpPos select 0) == 0 && {(_pwWpPos select 1) == 0}) && {(_pwPos distance _pwWpPos) > _pwWpDist}) then {
							_pwLastPos = _pwGrp getVariable "wfbe_patrol_watch_pos"; //--- G1: 1-arg + isNil on a GROUP (2-arg [name,default] is unreliable here).
							//--- codex-hold fix: a patrol observed for the FIRST time has no baseline yet. Defaulting
							//--- the baseline to the CURRENT position and then immediately measuring displacement in
							//--- the SAME iteration always read as zero movement, giving every newly-observed distant
							//--- patrol an instant strike. Record the baseline and skip evaluation until the NEXT sample.
							if (isNil "_pwLastPos") then {
								_pwGrp setVariable ["wfbe_patrol_watch_pos", _pwPos];
							} else {
							if ((_pwPos distance _pwLastPos) < _pwDist) then {
								_pwStrikes = _pwGrp getVariable "wfbe_patrol_watch_strikes";
								if (isNil "_pwStrikes") then {_pwStrikes = 0};
								_pwStrikes = _pwStrikes + 1;
								_pwGrp setVariable ["wfbe_patrol_watch_strikes", _pwStrikes];
								_pwSide = (_pwSideID) Call WFBE_CO_FNC_GetSideFromID;
								if (_pwStrikes < _pwMaxStrikes) then {
									//--- Strike ladder REUSES Common_RunUnstuckRecovery's own tiers instead of
									//--- duplicating recovery logic: tier2 = re-issue/rebuild the waypoint,
									//--- tier3 = setPos nudge onto the nearest road (its own player-near guard
									//--- still applies). Only escalate to tier3 once tier2 alone has failed once.
									_pwTier = if (_pwStrikes <= 1) then {2} else {3};
									//--- RunUnstuckRecovery's OWN contract: "the caller must run this where the
									//--- group is local" - this FSM runs server-only, so a delegated (HC-local)
									//--- patrol must be routed to its owning machine via the same established
									//--- SendToClient->HandleSpecial channel the rest of this codebase uses for
									//--- locality-sensitive dispatch (see server_groupsGC.sqf's arty/heli reapers).
									if (local _pwLdr) then {
										[_pwGrp, _pwTier, _pwSide, _pwWpPos, "sidepatrol-watchdog"] Spawn WFBE_CO_FNC_RunUnstuckRecovery;
									} else {
										[_pwLdr, "HandleSpecial", ["sidepatrol-watchdog", _pwLdr, _pwTier, _pwSideID, _pwWpPos]] Call WFBE_CO_FNC_SendToClient;
									};
									diag_log ("AICOMSTAT|v1|EVENT|" + (str _pwSide) + "|" + str (round (time / 60)) + "|SIDEPATROL_WATCHDOG_STRIKE|team=" + (str _pwGrp) + "|strike=" + str _pwStrikes + "|tier=" + str _pwTier);
								} else {
									//--- FINAL STRIKE: recycle the patrol via the SAME crewless-cleanup idiom
									//--- Common_RunSidePatrol.sqf already uses on a failed spawn (delete vehicles,
									//--- delete units, deleteGroup) - no new despawn mechanism. No manual slot
									//--- bookkeeping here either: the scrub block just above (this SAME ~20s pass
									//--- of this loop) already purges the dead-unit WFBE_ACTIVE_PATROLS entry and
									//--- reconciles wfbe_side_patrols to the live count on its very next pass.
									if (local _pwLdr) then {
										_pwUnits = units _pwGrp;
										_pwVehicles = [];
										{
											_pwV = vehicle _x;
											if (_pwV != _x) then {
												_pwFound = false;
												{if (_x == _pwV) then {_pwFound = true}} forEach _pwVehicles;
												if (!_pwFound) then {_pwVehicles = _pwVehicles + [_pwV]};
											};
											//--- fix(alife-stall r34): also reap assigned empty hulls on terminal recycle.
											_pwV = assignedVehicle _x;
											if (!isNull _pwV && {_pwV != _x} && {alive _pwV}) then {
												_pwFound = false;
												{if (_x == _pwV) then {_pwFound = true}} forEach _pwVehicles;
												if (!_pwFound) then {_pwVehicles = _pwVehicles + [_pwV]};
											};
										} forEach _pwUnits;
										//--- VEHDEL probe (fable/veh-delete-probe convention): every server-local
										//--- cleanup delete call below carries a reason-coded probe, same idiom as
										//--- server_groupsGC.sqf's zombie/wreck reapers.
										{if (!isNull _x && {({isPlayer _x} count (crew _x)) == 0}) then {["sidepatrol-watchdog-vehicle", _x, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _x}} forEach _pwVehicles; //--- r128: player-crew guard - a player riding a stuck patrol's hull must not be deleted with it (same guard idiom as GuerAirDef/town-sweep/BASE-GC teardowns)
										{if (!isNull _x) then {["sidepatrol-watchdog-unit", _x, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _x}} forEach _pwUnits;
										if (!isNull _pwGrp) then {deleteGroup _pwGrp};
									} else {
										//--- tier4 = recycle sentinel (not a RunUnstuckRecovery tier).
										[_pwLdr, "HandleSpecial", ["sidepatrol-watchdog", _pwLdr, 4, _pwSideID, _pwWpPos]] Call WFBE_CO_FNC_SendToClient;
									};
									diag_log ("AICOMSTAT|v1|EVENT|" + (str _pwSide) + "|" + str (round (time / 60)) + "|SIDEPATROL_WATCHDOG_RECYCLE|team=" + (str _pwGrp));
								};
							} else {
								//--- moved enough since last sample: clear the streak.
								_pwGrp setVariable ["wfbe_patrol_watch_strikes", 0];
							};
							_pwGrp setVariable ["wfbe_patrol_watch_pos", _pwPos];
						};
					} else {
							//--- arrived / no live waypoint yet: not a wedge candidate - reset baseline+streak.
							_pwGrp setVariable ["wfbe_patrol_watch_strikes", 0];
							_pwGrp setVariable ["wfbe_patrol_watch_pos", _pwPos];
						};
					};
				};
			} forEach WFBE_ACTIVE_PATROLS;
		};
	};

	{
		_side = _x;
		_sideID = (_side) Call WFBE_CO_FNC_GetSideID;
		//--- GUER GROUP-CONDENSE (task #12): defender/resistance gets a lower concurrent patrol cap.
		_maxSide = if (_side == WFBE_DEFENDER) then {if (({(_x getVariable "sideID") == _sideID} count towns) < 20) then {3} else {missionNamespace getVariable ["WFBE_C_SIDE_PATROLS_MAX_DEFENDER", 1]}} else {_max};
		_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
		if (!isNull _logik) then {
			_upgrades = (_side) Call WFBE_CO_FNC_GetSideUpgrades;
			_lvl = if (count _upgrades > WFBE_UP_PATROLS) then {_upgrades select WFBE_UP_PATROLS} else {0};
			//--- Debug-visibility probe (owner ask 2026-07-26): one-shot proof the clearance-7 grant reaches this read.
			if (WF_Debug && {isNil {_logik getVariable "wfbe_patrol_dbgread"}}) then {
				_logik setVariable ["wfbe_patrol_dbgread", true];
				diag_log Format ["[WFBE (DEBUG)] server_side_patrols.sqf: first upgrades read side=%1 lvl=%2 wfbe_upgrades=%3", _side, _lvl, _upgrades];
			};
			//--- B67 (Ray 2026-06-21): GUER players should SEE GUER patrols on the map. Root cause: GUER (resistance,
			//--- = WFBE_DEFENDER) has NO upgrade/HQ system, so _lvl was ALWAYS 0 here -> the dispatch below never ran
			//--- for GUER -> WFBE_ACTIVE_PATROLS never held a resistance entry -> updatepatrolmarkers.sqf (which already
			//--- supports resistance: friendly gate on the stable WFBE_Client_SideID, JIP-durable feed) had nothing to
			//--- paint. Give the defender side a fixed patrol level so the existing, already-tested dispatch runs. The
			//--- effective concurrent cap is still min(_maxSide, _lvl) (see L83/L91), so this stays FPS-light. Gated on
			//--- GUER playable; WFBE_C_GUER_PATROLS_LEVEL=0 fully reverts. (Tier is force-set HEAVY/MEDIUM for GUER at L106.)
			if (_side == WFBE_DEFENDER && {_lvl <= 0} && {(missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0}) then {
				_lvl = missionNamespace getVariable ["WFBE_C_GUER_PATROLS_LEVEL", 2];
			};
			if (_lvl > 0) then {
				_active = _logik getVariable ["wfbe_side_patrols", 0];
				_last = _logik getVariable ["wfbe_side_patrol_last", -(_delay)];
				_perfCap = _maxSide min _lvl;
				if (_perfProbe) then {
					_perfReason = "ready";
					if (_active >= _perfCap) then {
						_perfReason = "cap";
					} else {
						if (time - _last <= _delay) then {_perfReason = "cooldown"};
					};
					if (!(_perfReason in ["ready"])) then {
						if (!isNil "PerformanceAudit_Record") then {
							if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
								["side_patrol_dispatch_state", 0, Format["side:%1;lvl:%2;active:%3;cap:%4;popTier:%5;reason:%6;cooldownLeft:%7", _side, _lvl, _active, _perfCap, _perfPopTier, _perfReason, round ((_delay - (time - _last)) max 0)], "SERVER"] Call PerformanceAudit_Record;
							};
						};
					};
				};
				if (_active < (_maxSide min _lvl) && {time - _last > _delay}) then {  //--- B36.1 (Ray 2026-06-15): EFFECTIVE patrol cap is level-aware = min(side cap, patrol level). patrol-1 => 1, patrol-2+ => 2 (side cap is 2 for W/E, 2/1 for GUER). HQ teams scale via the curve; patrols stay low.
					_hq = (_side) Call WFBE_CO_FNC_GetSideHQ;
					_owned = [];
					{if ((_x getVariable "sideID") == _sideID) then {_owned = _owned + [_x]}} forEach towns;
					//--- V0.5.1: observability - say WHY a researched patrol is not spawning (once).
					if (count _owned == 0 && {!(_logik getVariable ["wfbe_patrol_waitlog", false])}) then {
						_logik setVariable ["wfbe_patrol_waitlog", true];
						["INFORMATION", Format ["server_side_patrols.sqf: [%1] Patrols %2 researched but NO owned towns yet - waiting for the first capture.", _side, _lvl]] Call WFBE_CO_FNC_AICOMLog;
					};
					if (_perfProbe && {count _owned < 1}) then {
						if (!isNil "PerformanceAudit_Record") then {
							if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
								["side_patrol_dispatch_state", 0, Format["side:%1;lvl:%2;active:%3;cap:%4;popTier:%5;reason:noOwned;hq:%6", _side, _lvl, _active, _perfCap, _perfPopTier, !isNull _hq], "SERVER"] Call PerformanceAudit_Record;
							};
						};
					};
					if (!isNull _hq && count _owned > 0) then {
						//--- cmdcon41-w3m (ground-patrol-skip-naval-hvt): _home is the town the patrol SPAWNS at. An owned
						//--- offshore carrier (wfbe_is_naval_hvt / over-water) must NOT be a spawn town - a ground patrol
						//--- would spawn over water. Pick _home from a naval-EXCLUDED pool; fall back to _owned only if EVERY
						//--- owned town is naval (keeps a valid spawn). _owned + its count-based GUER tier logic stay untouched.
						//--- Gated by WFBE_C_PATROLS_SKIP_NAVAL (default 1). 2-arg getVariable + surfaceIsWater: A2-OA-safe.
						_spSkipNaval = (missionNamespace getVariable ["WFBE_C_PATROLS_SKIP_NAVAL", 1]) > 0;
						_homePool = [];
						{_hpX = _x; if (!(_spSkipNaval && {(_hpX getVariable ["wfbe_is_naval_hvt", false]) || {surfaceIsWater (getPos _hpX)}})) then {_homePool = _homePool + [_hpX]}} forEach _owned;
						if (count _homePool == 0) then {_homePool = _owned};
						_home = [_hq, _homePool] Call WFBE_CO_FNC_GetClosestEntity;
						_escTiers  = ["LIGHT","MEDIUM","HEAVY"];
						_escBaseIdx = switch (_lvl) do {case 1: {0}; case 2: {1}; default {2}};
						_tier = _escTiers select _escBaseIdx;
						//--- LATE-GAME THREAT ESCALATION + FPS-AWARE CLAMP (cmdcon41-w3e, Ray 2026-07-02). Behind
						//--- WFBE_C_PATROLS_ESCALATE (default 1). As the match runs longer AND the side's Patrols upgrade
						//--- climbs, an escalation SCORE shifts the TIER DRAW upward so LIGHT fades and MEDIUM/HEAVY dominate
						//--- late game. Score = (upgradeLevel-1) + floor(matchMinutes / WFBE_C_PATROLS_ESCALATE_MINS(45)); each
						//--- +1 of score bumps the tier index one step, capped at HEAVY (idx 2). This is COMPOSITION-at-spawn
						//--- only (heavier template drawn) - it NEVER touches counts (the pop-tier cap at L98 owns those) and
						//--- does NO sim/distance gating. FPS-AWARE: reuse the existing WFBE_PopTier load proxy (published by
						//--- AI_Commander_Teams; higher tier = more humans = more server load). When PopTier exceeds
						//--- WFBE_C_PATROLS_ESCALATE_POPTIER_MAX (default 1 => escalate only at LOW/MID pop) we CLAMP the tier
						//--- draw back to the plain level-derived base index - never spawn a heavier template under load. GUER
						//--- keeps its own owned-town comeback-force scaling below (not upgrade-driven), so escalation is
						//--- WEST/EAST only. A2-OA-1.64-safe: plain getVariable+select, floor, min/max, if/else (no A3 ops).
						_escEnabled = (missionNamespace getVariable ["WFBE_C_PATROLS_ESCALATE", 1]) > 0;
						_escVehCap  = false;
						if (_escEnabled && {_side != WFBE_DEFENDER}) then {
							_escPopMax = missionNamespace getVariable ["WFBE_C_PATROLS_ESCALATE_POPTIER_MAX", 1];
							if (((missionNamespace getVariable ["WFBE_PopTier", 0]) max 0) <= _escPopMax) then {
								_escMins  = missionNamespace getVariable ["WFBE_C_PATROLS_ESCALATE_MINS", 45];
								if (_escMins < 1) then {_escMins = 45};
								_escScore = (_lvl - 1) + floor ((time / 60) / _escMins);
								_escTierIdx = (_escBaseIdx + _escScore) min 2;
								if (_escTierIdx < _escBaseIdx) then {_escTierIdx = _escBaseIdx};
								_tier = _escTiers select _escTierIdx;
								//--- At MAX escalation (already drawing HEAVY via score, not just base level) allow +1 escort
								//--- vehicle to be appended to the chosen template below (still LOW/MID pop only).
								if (_escTierIdx >= 2 && {_escScore >= 1}) then {_escVehCap = true};
							};
						};
						//--- B36 (Ray 2026-06-15): GUER patrols = a MECHANIZED insurgent COMEBACK force. Always mounted
						//--- (min MEDIUM = SPG-9 technical); the FEWER towns GUER holds the BETTER the patrol - at <=2 towns
						//--- they field HEAVY (BRDM-2 armor + AT/AA). Owned-town-count scaled, gated to the defender side.
						if (_side == WFBE_DEFENDER) then {_tier = if (count _owned < 20) then {"HEAVY"} else {"MEDIUM"}};
						_pool = missionNamespace getVariable Format["WFBE_%1_PATROL_%2", _side, _tier];
						if (!isNil "_pool" && {count _pool > 0}) then {
							//--- MOTORIZED ROAD-PATROL PICK (cmdcon41-w3c, Ray pick). When the w3 road-bias is on
							//--- (WFBE_C_PATROLS_ROADBIAS==1) AND WFBE_C_PATROLS_ROADBIAS_MOTORIZED==1 (both default 1),
							//--- prefer pool entries that CONTAIN at least one VEHICLE classname so the resulting patrol
							//--- actually rides the road corridor AI_Patrol.sqf lays (a foot-only entry crawls cross-town
							//--- and never uses the road route). Detect vehicle elements with the codebase-proven,
							//--- A2-OA-1.64-safe classname-literal `!(_c isKindOf "Man")` idiom (same as AI_Commander_Produce/
							//--- Teams; annotated A2-safe there). Collect vehicle-containing entries, pick randomly among them;
							//--- FALL BACK to the full pool when NONE exist (e.g. TKGUE foot-only pools) so a patrol is never
							//--- blocked. Bounded: one pass over the (tiny) pool, once per DISPATCH (not per tick).
							_mpEnabled = ((missionNamespace getVariable ["WFBE_C_PATROLS_ROADBIAS", 1]) > 0) && {(missionNamespace getVariable ["WFBE_C_PATROLS_ROADBIAS_MOTORIZED", 1]) > 0};
							if (_mpEnabled) then {
								_mpMotoPool = [];
								{
									_mpEntry = _x;
									if (typeName _mpEntry == "STRING") then {
										_mpRosterChoices = missionNamespace getVariable [Format["WFBE_%1_GROUPS_%2", str _side, _mpEntry], []];
										{
											_mpChoice = _x;
											if (typeName _mpChoice == "ARRAY") then {
												_mpHasVeh = false;
												{ _mpC = _x; if (!(_mpC isKindOf "Man")) exitWith {_mpHasVeh = true} } forEach _mpChoice;
												if (_mpHasVeh) then {_mpMotoPool set [count _mpMotoPool, _mpChoice]};
											};
										} forEach _mpRosterChoices;
									} else {
										if (typeName _mpEntry == "ARRAY") then {
											_mpHasVeh = false;
											{ _mpC = _x; if (!(_mpC isKindOf "Man")) exitWith {_mpHasVeh = true} } forEach _mpEntry;
											if (_mpHasVeh) then {_mpMotoPool set [count _mpMotoPool, _mpEntry]};
										};
									};
								} forEach _pool;
								if (count _mpMotoPool > 0) then {
									_template = _mpMotoPool select floor(random count _mpMotoPool);
								} else {
									_template = _pool select floor(random count _pool);
								};
							} else {
								_template = _pool select floor(random count _pool);
							};
							//--- TEMPLATE INTEGRITY (g1606): PATROL pools may contain shared-roster STRING keys
							//--- (e.g. "Squad_Advanced" in Root_GUE/Root_TKGUE). Groups_* tables load only under
							//--- isServer, so an unresolved string dispatched to HC always yields [] in
							//--- Common_RunSidePatrol and burns a patrol slot. Resolve on the SERVER here,
							//--- before escVehCap (which forEach's the template) and HC dispatch.
							if (typeName _template == "STRING") then {
								private ["_resChoices","_resPick"];
								_resChoices = missionNamespace getVariable [Format["WFBE_%1_GROUPS_%2", str _side, _template], []];
								if ((typeName _resChoices == "ARRAY") && {(count _resChoices) > 0}) then {
									_resPick = _resChoices select floor(random count _resChoices);
									if ((typeName _resPick == "ARRAY") && {(count _resPick) > 0}) then {
										_template = _resPick;
									} else {
										["WARNING", Format["server_side_patrols.sqf: [%1] patrol key [%2] resolved empty - skip dispatch.", _side, _template]] Call WFBE_CO_FNC_LogContent;
										_template = [];
									};
								} else {
									["WARNING", Format["server_side_patrols.sqf: [%1] unresolved patrol template key [%2] - skip dispatch.", _side, _template]] Call WFBE_CO_FNC_LogContent;
									_template = [];
								};
							};
							if ((typeName _template == "ARRAY") && {(count _template) > 0}) then {
							//--- MAX-ESCALATION +1 ESCORT VEHICLE (cmdcon41-w3e). Only when _escVehCap is set (LOW/MID pop,
							//--- HEAVY-by-score late game) AND the drawn template already CONTAINS a vehicle: append a COPY of
							//--- that template's FIRST vehicle classname so the patrol gains one extra escort hull. We reuse a
							//--- classname that is ALREADY IN THE TEMPLATE (never invent one), and we build a fresh array
							//--- ([] + _template copies) so the shared pool entry is NOT mutated. FPS-safe: gated off under load
							//--- by _escVehCap; counts stay pop-tier-capped elsewhere. A2-OA-safe: isKindOf "Man" literal, array +.
							if (_escVehCap) then {
								_escHadVeh  = false;
								_escSideVeh = "";
								{ if (!(_x isKindOf "Man")) exitWith {_escHadVeh = true; _escSideVeh = _x} } forEach _template;
								if (_escHadVeh) then {
									_escEscort = [] + _template;
									_escEscort set [count _escEscort, _escSideVeh];
									_template = _escEscort;
								};
							};
							//--- Book the slot synchronously; the started/ended events keep the
							//--- public marker list, the ended event re-arms the cooldown.
							_logik setVariable ["wfbe_side_patrols", _active + 1];
							_logik setVariable ["wfbe_side_patrol_last", time];
							//--- Run on the LEAST-LOADED live HC when available (server FPS ~ 0), else locally.
							_hcUnit = Call WFBE_CO_FNC_PickLeastLoadedHC;
							if (!isNull _hcUnit) then {
								[_hcUnit, "HandleSpecial", ['delegate-sidepatrol', _sideID, _template, _home]] Call WFBE_CO_FNC_SendToClient;
							} else {
								[_sideID, _template, _home] Spawn WFBE_CO_FNC_RunSidePatrol;
							};
							_logik setVariable ["wfbe_patrol_waitlog", false];
							["INFORMATION", Format["server_side_patrols.sqf: [%1] %2 patrol dispatched from [%3] (active %4/%5, HC:%6).", _side, _tier, _home getVariable "name", _active + 1, (_maxSide min _lvl), !isNull _hcUnit]] Call WFBE_CO_FNC_AICOMLog;
							if (!isNil "PerformanceAudit_Record") then {
								if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
									["side_patrol_spawn", 0, Format["side:%1;tier:%2;active:%3;hc:%4", _side, _tier, _active + 1, !isNull _hcUnit], "SERVER"] Call PerformanceAudit_Record;
									if (_perfProbe) then {
										["side_patrol_dispatch_state", 0, Format["side:%1;lvl:%2;tier:%3;active:%4;cap:%5;popTier:%6;owned:%7;home:%8;hc:%9;reason:dispatched", _side, _lvl, _tier, _active + 1, _perfCap, _perfPopTier, count _owned, _home getVariable "name", !isNull _hcUnit], "SERVER"] Call PerformanceAudit_Record;
									};
								};
							};
							}; //--- end non-empty template guard (g1606)
						};
					};
				};
			};
		};
	} forEach WFBE_PRESENTSIDES;

	sleep 20;
};
