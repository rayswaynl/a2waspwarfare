/*
	HP-01 Core-Loop Supervisor (fable/loop-supervisor-hp01).

	Generalizes the proven AI_Commander watchdog (Init_Server.sqf B69 block, ~line 1383) to
	the four core FSM loops that previously had no self-healing at all (council finding C-a):
	town, economy, upgrade queue, group GC. Each of those four loops now stamps
	wfbe_coreloop_hb_<id> = time as the FIRST statement of every iteration (see each file);
	this supervisor scans those stamps on a fixed cadence and, for a loop whose stamp has gone
	stale (its worker threw/died and the while-loop silently stopped), bumps that loop's owner
	generation, terminates the stale stored handle, and respawns a fresh instance - the exact
	AICOM recovery mechanism, generalized via a small descriptor table instead of one
	hand-written per-side block.

	Bounded: each loop gets at most WFBE_C_CORELOOP_MAX_RESTARTS restarts for the whole match
	(default 5); past that the supervisor stops touching that loop and logs a single GIVEUP
	line instead of retrying forever (no busy-loop). A per-loop cooldown also bars a second
	restart inside the recovery window, same as the AICOM watchdog.

	Per-loop restart arming (WFBE_C_CORELOOP_RESTART_<ID>, 0=off/1=observe/2=restart):
	town/economy/upgrade default to OBSERVE (1) - a restart mid-iteration can double-fire a
	capture/income/upgrade-transaction event, and the council's HP-01 write-up gates automatic
	restart on separate replay-safety evidence (HP-03) before arming those three. Group GC
	defaults to RESTART (2): every mutation in server_groupsGC.sqf re-checks live object/
	variable state before acting (sweep-based, stamped-timestamp gated), so a restart mid-pass
	just repeats a stale window on the next 60s sweep - no double-delete/double-credit is
	possible. The owner can flip any loop's mode without touching this file.
*/

waitUntil {sleep 1; !(isNil "serverInitFull")};

private ["_scan","_cool","_maxRestarts","_descriptors"];
_scan        = missionNamespace getVariable ["WFBE_C_CORELOOP_SCAN", 15];
_cool        = missionNamespace getVariable ["WFBE_C_CORELOOP_COOLDOWN", 120];
_maxRestarts = missionNamespace getVariable ["WFBE_C_CORELOOP_MAX_RESTARTS", 5];

//--- Descriptor: [id, scriptPath, nominalCadence, defaultRestartMode]. nominalCadence feeds
//--- the stale threshold (3 cycles + 30s margin, same formula as the AICOM watchdog); economy
//--- uses -1 here because its real cadence is the lobby-tunable WFBE_C_ECONOMY_INCOME_INTERVAL,
//--- read live below instead of baked into this table.
_descriptors = [
	["town",     "Server\FSM\server_town.sqf",      5, 1],
	["economy",  "Server\FSM\updateresources.sqf", -1, 1],
	["upgrade",  "Server\FSM\upgradeQueue.sqf",      5, 1],
	["groupsgc", "Server\FSM\server_groupsGC.sqf",  60, 2],
	//--- OILFIELD post-unlock live loop (TK-only; wasp-oilfield-postunlock-dead-20260722). OBSERVE (1)
	//--- ONLY: the script is NOT replay-safe - a restart re-runs from the top and re-spawns the derrick
	//--- composition, so we detect+log a silently-dead loop rather than auto-restart it. The stamp only
	//--- exists on TK post-unlock, so _hb stays <=0 (no fire) on CH/ZG and during the pre-unlock phase.
	["oilfield", "Server\Server_Oilfields.sqf",     -2, 1]
];

["INITIALIZATION", "Server_coreloop_supervisor.sqf: HP-01 core-loop supervisor started."] Call WFBE_CO_FNC_AICOMLog;

while {!WFBE_GameOver} do {
	sleep _scan;
	missionNamespace setVariable ["wfbe_coreloop_supervisor_hb", time]; //--- external soak canary: proves the SCANNER itself is alive.

	{
		private ["_id","_scriptPath","_ownerKey","_hbKey","_handleKey","_restartKey","_giveupKey","_lastRKey","_cadence","_thresh","_hb","_age","_mode","_restarts","_lastR","_ownerSeq","_newOwnerSeq","_oldHandle","_newHandle"];
		_id         = _x select 0;
		_scriptPath = _x select 1;
		_ownerKey   = Format ["wfbe_coreloop_owner_%1", _id];
		_hbKey      = Format ["wfbe_coreloop_hb_%1", _id];
		_handleKey  = Format ["wfbe_coreloop_handle_%1", _id];
		_restartKey = Format ["wfbe_coreloop_restarts_%1", _id];
		_giveupKey  = Format ["wfbe_coreloop_giveup_%1", _id];
		_lastRKey   = Format ["wfbe_coreloop_wd_restart_%1", _id];

		//--- Nominal cadence feeds the stale threshold. >0 = literal; -2 = live oilfield scan interval
		//--- (WFBE_C_OILFIELD_SCAN_INTERVAL, admin-retunable with no ceiling) so a retuned oilfield scan
		//--- never false-trips the OBSERVE alert (this task); any other non-positive = live economy interval.
		_cadence = if ((_x select 2) > 0) then {
			_x select 2
		} else {
			if ((_x select 2) == -2) then {missionNamespace getVariable ["WFBE_C_OILFIELD_SCAN_INTERVAL", 15]} else {missionNamespace getVariable ["WFBE_C_ECONOMY_INCOME_INTERVAL", 60]}
		};
		//--- generous threshold: 3 healthy ticks + 30s margin (matches the AICOM watchdog
		//--- formula exactly). No healthy tick blocks longer than its own cadence, so this
		//--- never false-trips on a normal slow tick.
		_thresh = (3 * _cadence) + 30;
		_hb     = missionNamespace getVariable [_hbKey, -1];

		//--- _hb > 0 means the loop has stamped at least once: never fire during boot / before
		//--- this loop's first tick.
		if (_hb > 0) then {
			_age = time - _hb;
			if (_age > _thresh) then {
				_mode     = missionNamespace getVariable [Format ["WFBE_C_CORELOOP_RESTART_%1", toUpper _id], (_x select 3)];
				_restarts = missionNamespace getVariable [_restartKey, 0];
				_lastR    = missionNamespace getVariable [_lastRKey, -1e9];

				if (_mode > 0) then {
					if (_restarts >= _maxRestarts) then {
						//--- Bounded: exhausted this loop's restart budget. Log ONCE (latched), then
						//--- leave it alone - never busy-loop retrying a loop that keeps dying.
						if ((missionNamespace getVariable [_giveupKey, 0]) < 1) then {
							missionNamespace setVariable [_giveupKey, 1];
							diag_log ("CORELOOP|v1|GIVEUP|id=" + _id + "|attempts=" + str _restarts + "|age=" + str (round _age));
							["WARNING", Format ["Server_coreloop_supervisor.sqf: %1 exhausted %2 restarts - giving up (loop stays down until mission restart).", _id, _restarts]] Call WFBE_CO_FNC_AICOMLog;
						};
					} else {
						if ((time - _lastR) > _cool) then {
							missionNamespace setVariable [_lastRKey, time];
							if (_mode == 1) then {
								//--- OBSERVE: alert only, no restart. Debounced by the same cooldown window.
								diag_log ("CORELOOP|v1|ALERT|id=" + _id + "|age=" + str (round _age) + "|mode=observe");
								["WARNING", Format ["Server_coreloop_supervisor.sqf: %1 heartbeat stale (%2s) - OBSERVE mode, not restarting.", _id, round _age]] Call WFBE_CO_FNC_AICOMLog;
							} else {
								//--- RESTART (mode >= 2): bump owner generation first (so a stale instance
								//--- that somehow resumes sees the newer owner and exits before its next
								//--- tick), terminate the stored handle if it is still running, respawn,
								//--- store the new handle. Mirrors the AICOM watchdog restart exactly.
								_ownerSeq    = missionNamespace getVariable [_ownerKey, 0];
								_newOwnerSeq = _ownerSeq + 1;
								missionNamespace setVariable [_ownerKey, _newOwnerSeq];
								_oldHandle = missionNamespace getVariable _handleKey;
								if (!isNil "_oldHandle") then {
									if !(scriptDone _oldHandle) then {terminate _oldHandle};
								};
								_newHandle = [_newOwnerSeq] execVM _scriptPath;
								missionNamespace setVariable [_handleKey, _newHandle];
								missionNamespace setVariable [_restartKey, _restarts + 1];
								diag_log ("CORELOOP|v1|RESTART|id=" + _id + "|attempt=" + str (_restarts + 1) + "|age=" + str (round _age) + "|oldGen=" + str _ownerSeq + "|newGen=" + str _newOwnerSeq);
								["WARNING", Format ["Server_coreloop_supervisor.sqf: %1 heartbeat stale (%2s) - restarting (attempt %3/%4, owner generation %5).", _id, round _age, _restarts + 1, _maxRestarts, _newOwnerSeq]] Call WFBE_CO_FNC_AICOMLog;
							};
						};
					};
				};
			};
		};
	} forEach _descriptors;
};
