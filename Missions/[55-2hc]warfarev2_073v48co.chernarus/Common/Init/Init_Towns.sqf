Private ["_towns","_townReadyCount","_wTownMode","_wTown"];

//--- J6 HANGGUARD: town mode must not stall the entire town census forever.
_wTownMode = 0;
while {(!townModeSet) && (_wTownMode < 240)} do { uiSleep 0.25; _wTownMode = _wTownMode + 1; };
if (!townModeSet) then {
	diag_log "[WFBE (INIT)] HANGGUARD| Init_Towns.sqf: town mode was not ready after 60s - proceeding with town census.";
};

//--- Get all of the city logics.
_towns = [0,0,0] nearEntities [["LocationLogicDepot"], 100000];

//--- TOWNINIT|v1|: only release the server/client startup gate when at least one
//--- authored depot registered in the active towns[] collection. A zero-ready census
//--- must fail closed; otherwise Init_Server.sqf can emit MATCH|START|towns=0 and start
//--- a broken match. wfbe_inactive is a terminal skip state and is not a town[] entry.

//--- Await for a proper initialization.
//--- FIX D6a/D6b (WFBE hang-guard): mirrors the bounded-wait idiom at initJIPCompatible.sqf:366-382 (B56
//--- JIP-HANG FIX). The old D6a loop gave each of ~46 depot logics its own serial 30s wait, so one
//--- failed Init_Town.sqf could make the census spend about 23 minutes checking independent objects.
//--- Poll all depots in one shared 30s window instead. Fallback is SAFE: it writes NOTHING to a stuck
//--- object - it only stops blocking and moves on; the town's own Init_Town.sqf may still complete and
//--- self-register later. Happy path remains a zero-sleep fast path when every depot is already ready.
_wTown = 0;
while {(_wTown < 120) && (({isNil {_x getVariable "sideID"} && {isNil {_x getVariable "wfbe_inactive"}}} count _towns) > 0)} do { uiSleep 0.25; _wTown = _wTown + 1; };
{
	if (isNil {_x getVariable "sideID"} && isNil {_x getVariable "wfbe_inactive"}) then {
		diag_log format ["[WFBE (INIT)] HANGGUARD| Init_Towns.sqf: town depot logic never set sideID/wfbe_inactive after 30s - SKIPPING it (name=%1 type=%2 pos=%3) so the rest of the match can start.", (_x getVariable ["name", "?"]), typeOf _x, mapGridPosition _x];
	};
} forEach _towns;

_townReadyCount = count towns;

if (_townReadyCount > 0) then {
	townInit = true;
	diag_log format ["TOWNINIT|v1|READY|ready=%1|candidates=%2", _townReadyCount, count _towns];
	["INITIALIZATION", "Init_Towns.sqf: Towns initialization is done."] Call WFBE_CO_FNC_LogContent;
} else {
	townInit = false;
	diag_log format ["TOWNINIT|v1|BLOCK|reason=NO_READY_TOWNS|candidates=%1", count _towns];
	["WARNING", "Init_Towns.sqf: Town census blocked startup because no depot initialized."] Call WFBE_CO_FNC_LogContent;
	//--- D6c LATE-RELEASE (2026-08-03): fail-closed must not mean fail-frozen. On a slow dedicated
	//--- boot the shared 30s window above runs on REAL time (uiSleep) while every town's own
	//--- Init_Town.sqf instance is still frozen in the mission-load phase, so the census can expire
	//--- at zero ready towns on a perfectly healthy mission (burned live on wave0802, 2026-08-03:
	//--- two boots wedged, zero RPT errors - Init_Server stalls on townInit and serverInitFull
	//--- never sets). Keep the gate closed while towns[] is genuinely empty - a truly town-less
	//--- mission stays blocked, preserving the zero-town match-start guard - but release it as soon
	//--- as the first town self-registers (Init_Town.sqf:262 towns = towns + [_town]). Heartbeat
	//--- every 60s so a held gate is visible in the RPT instead of silent.
	[] Spawn {
		private ["_wLate"];
		_wLate = 0;
		while {(count towns) < 1} do {
			uiSleep 1;
			_wLate = _wLate + 1;
			if ((_wLate mod 60) == 0) then { diag_log format ["TOWNINIT|v1|WAIT|held=%1s", _wLate] };
		};
		townInit = true;
		diag_log format ["TOWNINIT|v1|LATE_READY|ready=%1|held=%2s", count towns, _wLate];
		["INITIALIZATION", "Init_Towns.sqf: Towns initialization released late (census recovered after load)."] Call WFBE_CO_FNC_LogContent;
	};
};
