/* server_hcreg_heal.sqf -- HCREG|v1 headless-client registration self-heal (wasp-hc-delegation-collapse-20260722).

   WHY: Server_HandleSpecial.sqf "connected-hc" registration DEFERS when the HC's engine owner id is
   still 0 after its 60s retry window, or when the HC's group has not replicated to CIVILIAN inside its
   30s window ("registration deferred until reannounce"). The ONLY reannounce senders are HC-side
   (Init_HC.sqf): a 6x15s cold-start insurance loop (~first 90s of the HC session) and the 15s reseat
   watcher, which re-announces ONLY after it had to re-reseat a re-grabbed HC. An HC whose registration
   deferred past that insurance window while it sat correctly CIV-parked is NEVER re-announced: it keeps
   emitting HCSTAT (Headless\HC_StatLoop.sqf runs unconditionally) but never enters
   WFBE_HEADLESSCLIENTS_ID, so WFBE_CO_FNC_PickLeastLoadedHC can never pick it and 100% of the
   delegation load routes to the surviving HC(s). Live hit wave0722g: HCSTAT units=1/groups=0 flat for
   20+ min on one HC while the other carried 185u/32g and EVERY founding logged "dispatched to HC
   [HC-AI-Control-2]".

   WHAT: every 60s, find connected-but-unregistered HC bodies and re-run the registration path
   server-side. Candidate = playableUnits entry that is alive, isPlayer, engine owner > 2, sits in a
   CIVILIAN group (the post-reseat HC parking state - no human ever plays from a CIV group), has a
   FRESH HCSTAT heartbeat row (WFBE_HCFPS_REG keyed "HC-<netId>", <= 150s old - the same freshness
   join server_deleghealth.sqf uses; humans never emit HCStat, so a human can never match), and whose
   group is NOT in WFBE_HEADLESSCLIENTS_ID. After a candidate has been continuously unregistered for
   WFBE_C_HCREG_HEAL_WAIT s (default 120; also the per-owner retry cooldown), re-invoke the
   registration path directly: ["connected-hc", _unit] Call HandleSpecial - the SAME handler the HC's
   own PVF announce lands in (registration is owner-keyed and idempotent; the case body Spawns
   immediately, so the Call returns fast). The preconditions the handler waits on (owner > 2, CIV
   side) are verified HERE first, so its wait ladders pass immediately instead of re-deferring.

   Wire lines (diag_log so they survive WF_LOG_CONTENT compiled off; HCREG|v1|<event>):
     HCREG|v1|detect|owner=..|netid=..|uid=..                    first sighting of an unregistered live HC
     HCREG|v1|heal-attempt|owner=..|netid=..|uid=..|waited=..    re-invoked the registration path
     HCREG|v1|recovered|owner=..                                 previously-tracked HC is now registered
     HCREG|v1|gone|owner=..                                      previously-tracked HC left / stopped matching

   Cost: one playableUnits pass + an O(candidates x rows) heartbeat join per 60s tick. Spawned from
   Server\Init\Init_Server.sqf only when WFBE_C_HCREG_HEAL > 0 (default 0 = this file never runs;
   runtime behaviour identical to HEAD). Candidates are only sought while WFBE_C_AI_DELEGATION == 2
   (the only mode that consumes the HC registry).
*/
scriptName "Server\FSM\server_hcreg_heal.sqf";

if (!isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_HCREG_HEAL", 0]) <= 0) exitWith {};

private ["_wait","_tracked","_next","_cands","_hcList","_fpsReg","_u","_grp","_key","_fidx","_row","_id","_uid","_entry","_tidx","_first","_last","_stillIds","_tid","_reg"];

["INITIALIZATION", "server_hcreg_heal.sqf: Armed. HC registration self-heal sweep every 60s."] Call WFBE_CO_FNC_LogContent;

while {!WFBE_GameOver} do {
	sleep 60;
	if ((missionNamespace getVariable ["WFBE_C_AI_DELEGATION", 0]) == 2) then {
		_wait = missionNamespace getVariable ["WFBE_C_HCREG_HEAL_WAIT", 120];
		_hcList = missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []];
		_fpsReg = missionNamespace getVariable ["WFBE_HCFPS_REG", []];
		_tracked = missionNamespace getVariable ["WFBE_HCREG_TRACKED", []];

		//--- Collect connected-but-unregistered HC candidates as [ownerId, unit] pairs.
		_cands = [];
		{
			_u = _x; //--- capture before any inner forEach rebinds _x.
			if (!isNull _u && {alive _u} && {isPlayer _u} && {(owner _u) > 2} && {side (group _u) == civilian}) then {
				_grp = group _u;
				if (!(_grp in _hcList)) then {
					//--- Heartbeat freshness join (deleghealth idiom): only a body with a live HCSTAT
					//--- feed keyed to ITS OWN netId is an HC - a human never emits HCStat.
					_key = Format ["HC-%1", netId _u];
					_fidx = -1;
					{ if ((_x select 0) == _key) exitWith {_fidx = _forEachIndex} } forEach _fpsReg;
					if (_fidx >= 0) then {
						_row = _fpsReg select _fidx;
						if ((time - (_row select 2)) <= 150) then {
							_cands = _cands + [[owner _u, _u]];
						};
					};
				};
			};
		} forEach playableUnits;

		//--- Reconcile against the tracked list; fire a heal for candidates past the wait window.
		_next = [];
		_stillIds = [];
		{
			_id  = _x select 0; //--- capture before the inner forEach below rebinds _x.
			_u   = _x select 1;
			_uid = getPlayerUID _u;
			_first = time; _last = -1e9;
			_tidx = -1;
			{ if ((_x select 0) == _id) exitWith {_tidx = _forEachIndex} } forEach _tracked;
			if (_tidx >= 0) then {
				_entry = _tracked select _tidx;
				_first = _entry select 1;
				_last  = _entry select 2;
			} else {
				diag_log ("HCREG|v1|detect|owner=" + str _id + "|netid=" + netId _u + "|uid=" + _uid + "|t=" + str (round (time / 60)));
			};
			if (((time - _first) >= _wait) && {(time - _last) >= _wait}) then {
				_last = time;
				diag_log ("HCREG|v1|heal-attempt|owner=" + str _id + "|netid=" + netId _u + "|uid=" + _uid + "|waited=" + str (round (time - _first)) + "|t=" + str (round (time / 60)));
				["connected-hc", _u] Call HandleSpecial;
			};
			_next = _next + [[_id, _first, _last]];
			_stillIds = _stillIds + [_id];
		} forEach _cands;

		//--- Close out tracked ids that stopped matching: registered now (recovered) or gone.
		{
			_tid = _x select 0; //--- capture before the inner forEach below rebinds _x.
			if (!(_tid in _stillIds)) then {
				_reg = false;
				{ if (!isNull _x && {!isNull leader _x} && {(owner (leader _x)) == _tid}) exitWith {_reg = true} } forEach _hcList;
				if (_reg) then {
					diag_log ("HCREG|v1|recovered|owner=" + str _tid + "|t=" + str (round (time / 60)));
				} else {
					diag_log ("HCREG|v1|gone|owner=" + str _tid + "|t=" + str (round (time / 60)));
				};
			};
		} forEach _tracked;

		missionNamespace setVariable ["WFBE_HCREG_TRACKED", _next];
	};
};
