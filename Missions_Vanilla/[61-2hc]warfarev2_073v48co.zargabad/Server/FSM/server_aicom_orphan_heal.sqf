/* server_aicom_orphan_heal.sqf -- HCHEAL|v1 orphaned AICOM-team healer (wasp-hc-delegation-collapse-20260722).

   WHY: an HC-founded commander team lives ENTIRELY inside one Common_RunCommanderTeam.sqf spawn on its
   founding machine (header L190-193): the order driver, the TOPUP consumer (+ its TTL refund) and the
   wfbe_aicom_disband retirement executor are ALL that one thread. When the founding HC drops (or the
   thread dies with it), the engine transfers the units to the server but NOTHING re-drives them: the
   team freezes at its last orders, wfbe_aicom_topup_req charges (AI_Commander_Produce.sqf) are never
   spawned and never TTL-refunded, and the whole recycle chain (AssignTowns failed-journey tally ->
   Produce recycle consumer -> driver disband executor) is dead because its terminal consumer WAS the
   dead thread. server_groupsGC.sqf never re-adopts wfbe_aicom_hc groups (L152) and the disconnect
   handler only prunes the HC registry (read-only team audit, Server_OnPlayerDisconnected.sqf). Live
   hit wave0722g: owner watched frozen squads; STUCKSTAT distStart=0 strike reissues did nothing;
   WASPSCALE disp=276 arrv=31 recov=0.

   WHAT: Common_RunCommanderTeam (armed by the same flag) publishes a driver-liveness heartbeat on its
   group (wfbe_aicom_hb_t, ~60s cadence). Every 60s this sweep walks wfbe_teams of WEST/EAST for
   wfbe_aicom_hc groups whose heartbeat is OLDER than WFBE_C_AICOM_ORPHAN_STALE s (default 180 = 3
   missed beats): that founding thread is dead - no driver, no consumers. Healing, server-side:
     1. STALE TOPUP REFUND: a pending wfbe_aicom_topup_req older than its TTL on an orphan can never
        be consumed; refund the stored charge (element 4) via ChangeAICommanderFunds (this loop IS the
        server) and clear the request ([] sentinel, exactly like the in-thread consumer).
     2. WIPED ORPHAN RELEASE: 0 live units -> the dead thread's own wipe-release never ran; run it here
        (["aicom-team-ended", ..] Call HandleSpecial) so the slot frees, the arrow marker drops and the
        persistent-flag clear lets the groupsGC reap the husk.
     3. NEVER-MOVED FORCE-RECYCLE: leader still within WFBE_C_AICOM_ORPHAN_NEVERMOVED m (default 50) of
        its journey-start pos (wfbe_aicom_townorder slot 2 - the STUCKSTAT distStart source) -> the
        team froze on the pad/at base; delete it NOW bypassing the proximity/combat vetoes (authorized
        for distStart=0 teams: they sit at the rear) and release the slot. Any hull with a player
        aboard is skipped (belt-and-braces).
     4. FIELD ORPHAN RETIRE: moved/unknown-start orphans retire through the SAME player-safe gates the
        B36.1 disband executor applies on the HC (no player within WFBE_C_AICOM_DISBAND_SAFE_DIST, not
        in COMBAT) - never a player-visible vanish; a vetoed orphan is retried every sweep (throttled
        defer line) until the area clears. Slot release then lets the brain re-found on a live HC via
        WFBE_CO_FNC_PickLeastLoadedHC - that is the re-drive: the funded slot moves to a machine that
        can actually run it.
   Locality: deletes only run on units/hulls LOCAL to the server (the HC-drop transfer case). A
   stale-thread team whose units are still remote (HC connected, thread dead) is reported
   (skip-remote, throttled) but never remotely deleted (A2 deleteVehicle is locality-bound).
   Teams with NO heartbeat stamp (founded before the flag was armed, or founded pre-restart) are
   counted (unknownHb) but never healed - a nil stamp cannot be told apart from a just-founded team.

   Wire lines (diag_log so they survive WF_LOG_CONTENT compiled off; HCHEAL|v1|<event>|...):
     topup-refund|team=..|refund=..                    stale charged request refunded server-side
     release-wiped|team=..                             wiped orphan deregistered (slot freed)
     recycle|team=..|reason=never-moved|units=..       force-recycled pad-frozen orphan
     recycle|team=..|reason=stale-thread|units=..      player-safe retired field orphan
     defer|team=..|why=player-near / why=combat        retirement postponed (throttled 600s/team)
     skip-remote|team=..                               stale thread but units not server-local (throttled)
     sweep|checked=..|stale=..|healed=..|deferred=..|unknownHb=..   summary (only on ticks with stale or unknown)

   Cost: one wfbe_teams walk per side per 60s + per-orphan playableUnits proximity scans. Spawned from
   Server\Init\Init_Server.sqf only when WFBE_C_AICOM_ORPHAN_HEAL > 0 (default 0 = this file never
   runs; the heartbeat publisher in Common_RunCommanderTeam.sqf is gated on the same flag -> runtime
   behaviour identical to HEAD).
*/
scriptName "Server\FSM\server_aicom_orphan_heal.sqf";

if (!isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_AICOM_ORPHAN_HEAL", 0]) <= 0) exitWith {};

private ["_stale","_homeR","_safeD","_ttl","_checked","_staleN","_healed","_deferred","_unknown","_side","_sideID","_logik","_teams","_g","_hb","_req","_issued","_charge","_liveN","_ldr","_moved","_tord","_sp","_never","_pNear","_combat","_delN","_hulls","_h","_reason","_dlast","_why"];

["INITIALIZATION", "server_aicom_orphan_heal.sqf: Armed. Orphaned AICOM-team sweep every 60s."] Call WFBE_CO_FNC_LogContent;

while {!WFBE_GameOver} do {
	sleep 60;
	//--- Warmup gate (deleghealth precedent): never race the founding window right after mission start.
	if (time > 300) then {
		_stale = missionNamespace getVariable ["WFBE_C_AICOM_ORPHAN_STALE", 180];
		_homeR = missionNamespace getVariable ["WFBE_C_AICOM_ORPHAN_NEVERMOVED", 50];
		_safeD = missionNamespace getVariable ["WFBE_C_AICOM_DISBAND_SAFE_DIST", 900];
		_ttl = missionNamespace getVariable ["WFBE_C_AICOM_TOPUP_REQ_TTL", 300];
		if ((typeName _ttl) != "SCALAR") then {_ttl = 300};
		_checked = 0; _staleN = 0; _healed = 0; _deferred = 0; _unknown = 0;
		{
			_side = _x; //--- capture before the inner forEach rebinds _x.
			_sideID = (_side) Call WFBE_CO_FNC_GetSideID;
			_logik = _side Call WFBE_CO_FNC_GetSideLogic;
			if (!isNull _logik && {!isNil {_logik getVariable "wfbe_teams"}}) then {
				_teams = _logik getVariable "wfbe_teams";
				{
					_g = _x; //--- capture (and nil-hole guard) before the inner loops rebind _x.
					if (!isNil "_g" && {!isNull _g} && {[_g, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool}) then {
						_checked = _checked + 1;
						//--- A2: groups do not support the [name, default] getVariable form; plain get + isNil.
						_hb = _g getVariable "wfbe_aicom_hb_t";
						if (isNil "_hb") then {
							_unknown = _unknown + 1;
						} else {
							if ((time - _hb) > _stale) then {
								_staleN = _staleN + 1;

								//--- (1) STALE TOPUP REFUND - the dead thread can neither consume nor TTL-refund it.
								_req = _g getVariable "wfbe_aicom_topup_req";
								if (!isNil "_req" && {(typeName _req) == "ARRAY"} && {(count _req) >= 4}) then {
									_issued = _req select 3;
									if ((typeName _issued) == "SCALAR" && {_ttl > 0} && {(time - _issued) > _ttl}) then {
										if ((count _req) > 4) then {
											_charge = _req select 4;
											if ((typeName _charge) == "SCALAR" && {_charge > 0}) then {
												[_side, _charge] Call ChangeAICommanderFunds;
												diag_log ("HCHEAL|v1|topup-refund|team=" + (str _g) + "|refund=" + str _charge + "|t=" + str (round (time / 60)));
											};
										};
										_g setVariable ["wfbe_aicom_topup_req", [], true];
									};
								};

								//--- (2)-(4) retire ladder.
								_liveN = count ((units _g) Call WFBE_CO_FNC_GetLiveUnits);
								if (_liveN == 0) then {
									["aicom-team-ended", _sideID, _g] Call HandleSpecial;
									_healed = _healed + 1;
									diag_log ("HCHEAL|v1|release-wiped|team=" + (str _g) + "|t=" + str (round (time / 60)));
								} else {
									_ldr = leader _g;
									if (!isNull _ldr && {local _ldr}) then {
										//--- moved-from-journey-start (the STUCKSTAT distStart source): townorder slot 2.
										_moved = -1;
										_tord = _g getVariable "wfbe_aicom_townorder";
										if (!isNil "_tord" && {(typeName _tord) == "ARRAY"} && {(count _tord) >= 3}) then {
											_sp = _tord select 2;
											if ((typeName _sp) == "ARRAY" && {(count _sp) >= 2}) then {_moved = _ldr distance _sp};
										};
										_never = (_moved >= 0) && {_moved < _homeR};
										_pNear = false;
										if (!_never) then {
											{ if (isPlayer _x && {alive _x} && {(_x distance _ldr) < _safeD}) exitWith {_pNear = true} } forEach playableUnits;
										};
										_combat = (behaviour _ldr == "COMBAT");
										if (_never || {(!_pNear) && {!_combat}}) then {
											_delN = 0;
											{ if (!isNull _x && {local _x}) then {["hcheal-unit", _x, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _x; _delN = _delN + 1} } forEach (units _g);
											_hulls = [_g, false] Call GetTeamVehicles;
											{ _h = _x; if (!isNull _h && {local _h} && {({isPlayer _x} count (crew _h)) == 0}) then {["hcheal-hull", _h, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _h; _delN = _delN + 1} } forEach _hulls;
											["aicom-team-ended", _sideID, _g] Call HandleSpecial;
											_healed = _healed + 1;
											_reason = "stale-thread"; if (_never) then {_reason = "never-moved"};
											diag_log ("HCHEAL|v1|recycle|team=" + (str _g) + "|reason=" + _reason + "|units=" + str _delN + "|moved=" + str (round _moved) + "|t=" + str (round (time / 60)));
										} else {
											_deferred = _deferred + 1;
											_dlast = _g getVariable "wfbe_hcheal_defer_t";
											if (isNil "_dlast") then {_dlast = -1e9};
											if ((time - _dlast) >= 600) then {
												_g setVariable ["wfbe_hcheal_defer_t", time];
												_why = "combat"; if (_pNear) then {_why = "player-near"};
												diag_log ("HCHEAL|v1|defer|team=" + (str _g) + "|why=" + _why + "|t=" + str (round (time / 60)));
											};
										};
									} else {
										//--- Units not server-local: the HC still owns them (thread dead, machine alive).
										//--- A2 deleteVehicle is locality-bound - report only, never remote-delete.
										_deferred = _deferred + 1;
										_dlast = _g getVariable "wfbe_hcheal_remote_t";
										if (isNil "_dlast") then {_dlast = -1e9};
										if ((time - _dlast) >= 600) then {
											_g setVariable ["wfbe_hcheal_remote_t", time];
											diag_log ("HCHEAL|v1|skip-remote|team=" + (str _g) + "|t=" + str (round (time / 60)));
										};
									};
								};
							};
						};
					};
				} forEach _teams;
			};
		} forEach [west, east];
		if ((_staleN > 0) || {_unknown > 0}) then {
			diag_log ("HCHEAL|v1|sweep|checked=" + str _checked + "|stale=" + str _staleN + "|healed=" + str _healed + "|deferred=" + str _deferred + "|unknownHb=" + str _unknown + "|t=" + str (round (time / 60)));
		};
	};
};
