/*
	HC LOBBY LOCK - server-side readiness authority (feat/hc-lobby-lock, owner request 2026-07-26).

	PROBLEM (live, 4-HC soak box): on every cold start the headless clients race the mission load. HC1
	reliably lands in a BLUFOR player slot instead of a CIV headless slot and the remaining HCs grey out
	with no slot at all. The only working remedy so far is a manual post-start bounce, because an HC that
	JIPs into a LIVE mission seats correctly while one that connects during mission load does not.

	WHY MISSION-SIDE: the two engine-level locks are both unavailable on this box. `password` in server.cfg
	is read at STARTUP only and the running arma2oaserver holds an exclusive lock on the file, so it cannot
	be toggled live; `#lock` / serverCommand requires a logged-in admin or BattlEye, and BattlEye is
	deliberately disabled here (the BE handshake killed the co-located HC clients - see the rc22 revert note
	in server-pr8.cfg). So this publishes a readiness flag and the CLIENT holds itself
	(Client\Init\Init_Client.sqf, just after the existing join gate).

	SEATED SIGNAL: count of WFBE_HEADLESSCLIENTS_ID, filtered to live entries with the exact predicate the
	perf-audit row already uses for its "headless:N" figure (Init_Server.sqf FPSREPORT). That registry is the
	only authoritative record of an HC that actually reached a headless slot - HCSIDE|connect logs the connect
	ATTEMPT, not the final slot, and has been observed reading 4 while the lobby showed 1 seated HC.

	HEADLESS CLIENTS ARE STRUCTURALLY EXEMPT: the gate lives in Init_Client.sqf, which an HC never runs
	(initJIPCompatible.sqf gates client init on !isHeadLessClient and launches Headless\Init\Init_HC.sqf
	instead). The lock therefore cannot starve the very machines it waits for.

	A2-OA-1.64 safety: plain global assignment + publicVariable (never a 3-arg missionNamespace setVariable,
	never publicVariableServer from the server), array-form private, `count` with a code filter, `mod`,
	no A3 commands.
*/

if (!isServer) exitWith {};
if !((missionNamespace getVariable ["WFBE_C_HC_LOBBY_LOCK", 0]) > 0) exitWith {};

private ["_timeout","_expected","_override","_source","_probe","_tries","_seated","_reason","_lastBeatLog","_t0","_anchorWait"];

_timeout = missionNamespace getVariable ["WFBE_C_HC_LOBBY_TIMEOUT", 90];
if (_timeout < 10) then {_timeout = 10}; //--- floor: a sub-10s window cannot cover any real HC seat.

//--- EXPECTED SEATED-HC COUNT. WFBE_C_HC_LOBBY_EXPECTED is the source of truth and ships at the owner's
//--- default of 4 (2026-07-26): the box runs 4 headless clients, and all three terrains carry exactly 4
//--- forceHeadlessClient CIV slots today (mission.sqm, post-#1456). Setting it to -1 opts in to the RUNTIME
//--- DERIVATION below instead: nothing in A2 OA can parse mission.sqm at runtime, so the slot count is read
//--- from its runtime equivalent, the playable CIV units. Every HC slot on every terrain is a playable
//--- civilian (Functionary1, side CIV, forceHeadlessClient=1) and no other playable civilian slot exists, so
//--- the derivation yields the per-terrain count and self-adjusts if a future slot layout ever diverges from
//--- the constant. Bounded retry rides out an empty first read during mission load.
_override = missionNamespace getVariable ["WFBE_C_HC_LOBBY_EXPECTED", 4];
_expected = 0;
_source = "derived";
if (_override >= 0) then {
	_expected = _override;
	_source = "flag";
} else {
	_tries = 0;
	while {_expected <= 0 && {_tries < 20}} do {
		_probe = 0;
		{if (!isNull _x && {side _x == civilian}) then {_probe = _probe + 1}} forEach playableUnits;
		_expected = _probe;
		_tries = _tries + 1;
		if (_expected <= 0) then {uiSleep 0.5};
	};
};

//--- FAIL-OPEN GUARDS. WFBE_HEADLESSCLIENTS_ID is only ever created under full AI delegation
//--- (Init_Server.sqf: WFBE_C_AI_DELEGATION == 2), so on any other delegation mode no HC can ever register
//--- and a lock would hold every player to the timeout on every boot. Same for a derivation that came back
//--- empty. Both cases open immediately and say so in the RPT rather than silently penalising joiners.
if ((missionNamespace getVariable ["WFBE_C_AI_DELEGATION", -1]) != 2) then {
	["WARNING", Format ["Init_HcLobbyLock.sqf: AI delegation is %1 (not 2) - the headless-client registry is never created in this mode, so the lobby lock stays OPEN.", (missionNamespace getVariable ["WFBE_C_AI_DELEGATION", -1])]] Call WFBE_CO_FNC_LogContent;
	_expected = 0;
};
if (_expected <= 0 && {_source == "derived"}) then {
	["WARNING", "Init_HcLobbyLock.sqf: could not derive an expected headless-client count from the playable CIV slots - the lobby lock stays OPEN (set WFBE_C_HC_LOBBY_EXPECTED to a positive count instead of -1)."] Call WFBE_CO_FNC_LogContent;
};

WFBE_HC_LOBBY_READY = (_expected <= 0);
WFBE_HC_LOBBY_STATE = [0, _expected];
publicVariable "WFBE_HC_LOBBY_READY";
publicVariable "WFBE_HC_LOBBY_STATE";

["INFORMATION", Format ["Init_HcLobbyLock.sqf: HC lobby lock armed - expected %1 headless client(s) (%2), timeout %3s, open=%4.", _expected, _source, _timeout, WFBE_HC_LOBBY_READY]] Call WFBE_CO_FNC_LogContent;
diag_log Format ["HCLOBBY|v1|ARMED|expected=%1|source=%2|timeout=%3|delegation=%4|open=%5", _expected, _source, _timeout, (missionNamespace getVariable ["WFBE_C_AI_DELEGATION", -1]), WFBE_HC_LOBBY_READY];

//--- MISSION-LIVE ANCHOR (2026-07-30). WFBE_C_HC_LOBBY_TIMEOUT is a budget for the HEADLESS-CLIENT
//--- BRING-UP, and the HCs are launched by C:\WASP\provision\Start-Wasp-*HC.ps1 only after that script
//--- sees MATCH|v1|START| in the server RPT. Measuring the budget from mission-init instead would make it
//--- silently absorb whatever the ops-side mission-live gate costs, so raising that gate's own timeout
//--- would eat this one. Anchor on the exact condition Init_Server.sqf waits on immediately before it
//--- emits MATCH|v1|START| (both flags are pre-seeded to false in initJIPCompatible.sqf, so this is never
//--- a nil compare) and stamp _t0 there. MEASURED on the live 2-HC box 2026-07-30 (builds m0730e-h): the
//--- mission clock does NOT advance during load - `time` reads 0 from Init_Server start through every HC
//--- connect and only starts running ~2s before MATCH|v1|START| - so on this hardware the anchor moves the
//--- deadline by ~2s. It is still the correct anchor: it is what makes the constant mean "seconds after the
//--- mission went live" on any box, instead of depending on that frozen-clock accident holding.
//--- BOUNDED like every other exit in this file: if the mission never goes live the anchor falls through
//--- anyway rather than parking the lock (and therefore every joiner) forever. uiSleep, not sleep, because
//--- the mission clock this guard exists to survive is exactly the one that is frozen during load.
_anchorWait = 0;
while {!(commonInitComplete && townInit) && {_anchorWait < 900}} do {
	uiSleep 1;
	_anchorWait = _anchorWait + 1;
};
_t0 = time;

//--- PUBLISH THE DEADLINE, never the arithmetic. Client\Init\Init_Client.sqf gates on the same mission
//--- clock, so if it recomputed _t0 + timeout locally the two sides would disagree by however long the
//--- client took to reach its gate. One publisher, one number. Re-published on the heartbeat below for the
//--- same JIP-durability reason as WFBE_HC_LOBBY_READY.
WFBE_HC_LOBBY_DEADLINE = _t0 + _timeout;
publicVariable "WFBE_HC_LOBBY_DEADLINE";
diag_log Format ["HCLOBBY|v1|ANCHOR|t0=%1|deadline=%2|timeout=%3|anchorWait=%4|live=%5", round _t0, round WFBE_HC_LOBBY_DEADLINE, _timeout, _anchorWait, (commonInitComplete && townInit)];

//--- HEARTBEAT. A publicVariable is not JIP-durable in A2-OA: a client that connects after a one-shot
//--- broadcast never receives it. Re-publish every 2s for the whole cold-start window and 30s past it, so
//--- every client whose gate can still be armed (it is armed only while time < WFBE_HC_LOBBY_DEADLINE) is
//--- guaranteed to sit inside a live heartbeat. After that the loop ends for good - two small variables
//--- every 2s for at most ~2 minutes, then silence for the rest of the round.
_reason = "";
_lastBeatLog = -1;
while {time < (WFBE_HC_LOBBY_DEADLINE + 30)} do {
	_seated = {!isNull _x && {!isNull leader _x} && {alive leader _x}} count (missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []]);
	if (!WFBE_HC_LOBBY_READY) then {
		if (_seated >= _expected) then {
			WFBE_HC_LOBBY_READY = true;
			_reason = "seated";
		};
		if (!WFBE_HC_LOBBY_READY && {time >= WFBE_HC_LOBBY_DEADLINE}) then {
			WFBE_HC_LOBBY_READY = true;
			_reason = "timeout";
		};
		if (WFBE_HC_LOBBY_READY) then {
			if (_reason == "timeout") then {
				["WARNING", Format ["Init_HcLobbyLock.sqf: lobby OPENED ON TIMEOUT after %1s with only %2 of %3 headless client(s) seated - players are let in, but an HC never registered.", _timeout, _seated, _expected]] Call WFBE_CO_FNC_LogContent;
			} else {
				["INFORMATION", Format ["Init_HcLobbyLock.sqf: lobby OPENED - %1 of %2 headless client(s) seated at %3s.", _seated, _expected, round time]] Call WFBE_CO_FNC_LogContent;
			};
			diag_log Format ["HCLOBBY|v1|OPEN|reason=%1|seated=%2|expected=%3|at=%4", _reason, _seated, _expected, round time];
		};
	};
	WFBE_HC_LOBBY_STATE = [_seated, _expected];
	publicVariable "WFBE_HC_LOBBY_READY";
	publicVariable "WFBE_HC_LOBBY_STATE";
	publicVariable "WFBE_HC_LOBBY_DEADLINE";
	if ((round time) != _lastBeatLog && {((round time) mod 10) == 0}) then {
		_lastBeatLog = round time;
		diag_log Format ["HCLOBBY|v1|BEAT|ready=%1|seated=%2|expected=%3|at=%4", WFBE_HC_LOBBY_READY, _seated, _expected, _lastBeatLog];
	};
	sleep 2;
};

diag_log Format ["HCLOBBY|v1|HEARTBEAT-END|ready=%1|expected=%2|at=%3", WFBE_HC_LOBBY_READY, _expected, round time];
