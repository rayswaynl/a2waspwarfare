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

//--- D6c REVISED (2026-08-03, second live burn): the zero-REGISTERED census gate deadlocks startup.
//--- Every Init_Town.sqf worker holds a GAME-TIME sleep before it registers, and game time is frozen
//--- until the match starts - but match start was gated on townInit, which waited for registration.
//--- Proven on the dev box: 46/46 workers logged TOWNENTRY+TOWNGATE then parked on the sleep while
//--- the census held the gate for 300s+ (TOWNINIT|v1|WAIT). The pre-guard code never deadlocked
//--- because it released unconditionally and towns registered moments after match start.
//--- So: hard-block ONLY when there are no depot ENTITIES at all (candidates==0 - a genuinely
//--- town-less/broken mission, which is what the zero-town match-start guard was written for).
//--- When depots exist, release startup; registration completes once game time runs. A zero-ready
//--- release logs DEFER plus a watcher that confirms (or alarms) actual registration afterwards.
if ((count _towns) == 0) then {
	townInit = false;
	diag_log format ["TOWNINIT|v1|BLOCK|reason=NO_DEPOT_ENTITIES|candidates=%1", count _towns];
	["WARNING", "Init_Towns.sqf: Town census blocked startup because the mission has no depot logics."] Call WFBE_CO_FNC_LogContent;
} else {
	townInit = true;
	if (_townReadyCount > 0) then {
		diag_log format ["TOWNINIT|v1|READY|ready=%1|candidates=%2", _townReadyCount, count _towns];
	} else {
		diag_log format ["TOWNINIT|v1|DEFER|ready=0|candidates=%1", count _towns];
		//--- Post-release confirmation watcher: real-time heartbeat until the first registration lands,
		//--- so a build whose towns NEVER register (the failure the guard feared) is loud in the RPT
		//--- instead of silently starting a townless match.
		[] Spawn {
			private ["_wLate"];
			_wLate = 0;
			while {(count towns) < 1} do {
				uiSleep 30;
				_wLate = _wLate + 30;
				diag_log format ["TOWNINIT|v1|UNREGISTERED|elapsed=%1s|candidates-still-empty", _wLate];
			};
			diag_log format ["TOWNINIT|v1|LATE_REGISTERED|ready=%1|after=%2s", count towns, _wLate];
		};
	};
	["INITIALIZATION", "Init_Towns.sqf: Towns initialization is done."] Call WFBE_CO_FNC_LogContent;
};
