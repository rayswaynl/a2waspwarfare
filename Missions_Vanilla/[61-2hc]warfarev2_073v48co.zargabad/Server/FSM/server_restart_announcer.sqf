/* server_restart_announcer.sqf — server-side scheduled-restart countdown (work-order item 15).

   Once mission uptime reaches (WFBE_C_RESTART_AT_MIN - WFBE_C_RESTART_WARN_MIN) minutes,
   broadcasts a single warning per minute for the final WFBE_C_RESTART_WARN_MIN minutes.
   Fires EXACTLY WFBE_C_RESTART_WARN_MIN times (e.g. at T-5, T-4, T-3, T-2, T-1) — there is
   NO extra T-0 broadcast, and a per-minute guard prevents duplicate sends within one minute.

   The message is built server-side (Format substitutes the minutes-remaining into the %1
   placeholder of WFBE_C_RESTART_MSG) and pushed to every client via the RestartAnnounce PVF.

   CRITICAL: the SendToClients destination MUST be nil (global broadcast). A literal 0 is a
   valid "machine id" that matches no client, so the PVF would be addressed to nobody and the
   handler would display nothing — the announcer would appear to do nothing.

   Spawned from Server\Init\Init_Server.sqf after time>0, only when WFBE_C_RESTART_ENABLED==1.
*/
scriptName "Server\FSM\server_restart_announcer.sqf";

if (!isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_RESTART_ENABLED", 1]) != 1) exitWith {};

Private ["_restartAt", "_warnMin", "_msgTpl", "_warnStartMin", "_lastAnnounced", "_minsElapsed", "_minsRemaining"];

_restartAt = missionNamespace getVariable ["WFBE_C_RESTART_AT_MIN", 90];
_warnMin   = missionNamespace getVariable ["WFBE_C_RESTART_WARN_MIN", 5];
_msgTpl    = missionNamespace getVariable ["WFBE_C_RESTART_MSG", "SERVER RESTART IN %1 MINUTE(S)."];

//--- Nothing to do if the warning window is degenerate.
if (_warnMin < 1) exitWith {
	["WARNING", Format ["server_restart_announcer.sqf: WFBE_C_RESTART_WARN_MIN (%1) < 1 — announcer disabled.", _warnMin]] Call WFBE_CO_FNC_LogContent;
};

_warnStartMin  = _restartAt - _warnMin;            //--- Minute-of-uptime at which warnings begin (e.g. 90-5 = 85).
_lastAnnounced = -1;                               //--- Minutes-remaining value of the last broadcast (per-minute guard).

["INITIALIZATION", Format ["server_restart_announcer.sqf: Armed. Restart at %1 min uptime; warnings begin at %2 min (%3 broadcasts).", _restartAt, _warnStartMin, _warnMin]] Call WFBE_CO_FNC_LogContent;

while {true} do {
	_minsElapsed = floor (time / 60);

	if (_minsElapsed >= _warnStartMin) then {
		//--- Whole minutes until the restart. Clamps to the [1.._warnMin] window so we fire
		//--- exactly _warnMin times and never a T-0 (remaining == 0) sixth broadcast.
		_minsRemaining = _restartAt - _minsElapsed;

		if (_minsRemaining >= 1 && _minsRemaining <= _warnMin && _minsRemaining != _lastAnnounced) then {
			_lastAnnounced = _minsRemaining;
			[nil, "RestartAnnounce", [Format [_msgTpl, _minsRemaining]]] Call WFBE_CO_FNC_SendToClients;
			["INFORMATION", Format ["server_restart_announcer.sqf: Broadcast restart warning (T-%1 min).", _minsRemaining]] Call WFBE_CO_FNC_LogContent;
		};

		//--- All warnings sent (we are at or past the final minute) — stop the loop.
		if (_minsRemaining < 1) exitWith {
			["INFORMATION", "server_restart_announcer.sqf: Final warning delivered — announcer loop ended."] Call WFBE_CO_FNC_LogContent;
		};
	};

	sleep 5;
};
