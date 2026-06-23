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

private ["_side","_sideID","_logik","_upgrades","_lvl","_active","_last","_hq","_owned","_home","_tier","_pool","_template","_hcUnit","_delay","_max","_maxSide","_scrubLast","_kept","_changed","_entry","_removed","_aKept"];

waitUntil {townInitServer};
sleep 30;

if (isNil "WFBE_ACTIVE_PATROLS") then {WFBE_ACTIVE_PATROLS = []; publicVariable "WFBE_ACTIVE_PATROLS"};
//--- Commander-team arrow-marker feed (task #3), broadcast like WFBE_ACTIVE_PATROLS. Maintained by
//--- the aicom-team-created / -ended / -heading cases in Server_HandleSpecial.sqf; init once here so
//--- JIP clients see a defined empty array. Entries: [leader, sideID, dir, team].
if (isNil "WFBE_ACTIVE_AICOM_TEAMS") then {WFBE_ACTIVE_AICOM_TEAMS = []; publicVariable "WFBE_ACTIVE_AICOM_TEAMS"};

_delay = missionNamespace getVariable "WFBE_C_PATROLS_DELAY_SPAWN";
//--- B74.2 (Ray 2026-06-23): WEST/EAST side-patrol cap is now POP-TIER aware (was the flat
//--- WFBE_C_SIDE_PATROLS_MAX). Read WFBE_C_SIDE_PATROLS_MAX_BY_TIER select WFBE_PopTier per cycle (the
//--- server publishes WFBE_PopTier 0=LOW/1=MID/2=HIGH/3=FULL, changing ~every 90s) so the concurrent
//--- patrol cap eases off as population rises (BY_TIER = [2,2,2,1]); the EFFECTIVE cap stays level-aware =
//--- min(this, patrol level) at L101. SAME consumer idiom as AI_Commander_Produce/Teams (B74.2). _max is
//--- (re)assigned at the top of every loop cycle below. A2-OA-safe (plain getVariable+select, `max 0`).
_max = (missionNamespace getVariable ["WFBE_C_SIDE_PATROLS_MAX_BY_TIER", [2,2,2,1]]) select (((missionNamespace getVariable ["WFBE_PopTier", 0]) max 0) min 3);
_scrubLast = -999;

while {!WFBE_GameOver} do {
	//--- B74.2 (Ray 2026-06-23): re-read the pop-tier-scaled WEST/EAST cap each cycle so it tracks the live
	//--- WFBE_PopTier (republished ~every 90s) instead of being frozen at the value read once at startup.
	_max = (missionNamespace getVariable ["WFBE_C_SIDE_PATROLS_MAX_BY_TIER", [2,2,2,1]]) select (((missionNamespace getVariable ["WFBE_PopTier", 0]) max 0) min 3);

	//--- PATROL-MARKER SCRUB: every ~20 s, purge dead-unit entries from WFBE_ACTIVE_PATROLS
	//--- so HC-disconnect mid-patrol can't leave stale entries that JIP clients render.
	//--- Uses explicit forEach (A2-safe; no select-with-code-filter).
	if (time - _scrubLast > 20) then {
		_kept = [];
		_changed = false;
		{
			_entry = _x;
			if (alive (_entry select 0)) then {
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
		publicVariable "WFBE_ACTIVE_PATROLS";
		publicVariable "WFBE_ACTIVE_AICOM_TEAMS";

		_scrubLast = time;
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
				if (_active < (_maxSide min _lvl) && {time - _last > _delay}) then {  //--- B36.1 (Ray 2026-06-15): EFFECTIVE patrol cap is level-aware = min(side cap, patrol level). patrol-1 => 1, patrol-2+ => 2 (side cap is 2 for W/E, 2/1 for GUER). HQ teams scale via the curve; patrols stay low.
					_hq = (_side) Call WFBE_CO_FNC_GetSideHQ;
					_owned = [];
					{if ((_x getVariable "sideID") == _sideID) then {_owned = _owned + [_x]}} forEach towns;
					//--- V0.5.1: observability - say WHY a researched patrol is not spawning (once).
					if (count _owned == 0 && {!(_logik getVariable ["wfbe_patrol_waitlog", false])}) then {
						_logik setVariable ["wfbe_patrol_waitlog", true];
						["INFORMATION", Format ["server_side_patrols.sqf: [%1] Patrols %2 researched but NO owned towns yet - waiting for the first capture.", _side, _lvl]] Call WFBE_CO_FNC_AICOMLog;
					};
					if (!isNull _hq && count _owned > 0) then {
						_home = [_hq, _owned] Call WFBE_CO_FNC_GetClosestEntity;
						_tier = switch (_lvl) do {case 1: {"LIGHT"}; case 2: {"MEDIUM"}; default {"HEAVY"}};
						//--- B36 (Ray 2026-06-15): GUER patrols = a MECHANIZED insurgent COMEBACK force. Always mounted
						//--- (min MEDIUM = SPG-9 technical); the FEWER towns GUER holds the BETTER the patrol - at <=2 towns
						//--- they field HEAVY (BRDM-2 armor + AT/AA). Owned-town-count scaled, gated to the defender side.
						if (_side == WFBE_DEFENDER) then {_tier = if (count _owned < 20) then {"HEAVY"} else {"MEDIUM"}};
						_pool = missionNamespace getVariable Format["WFBE_%1_PATROL_%2", _side, _tier];
						if (!isNil "_pool" && {count _pool > 0}) then {
							_template = _pool select floor(random count _pool);
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
								};
							};
						};
					};
				};
			};
		};
	} forEach WFBE_PRESENTSIDES;

	sleep 20;
};
