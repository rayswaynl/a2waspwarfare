Private ["_towns","_wTownMode"];

//--- J6 HANGGUARD: town mode must not stall the entire town census forever.
_wTownMode = 0;
while {(!townModeSet) && (_wTownMode < 240)} do { uiSleep 0.25; _wTownMode = _wTownMode + 1; };
if (!townModeSet) then {
	diag_log "[WFBE (INIT)] HANGGUARD| Init_Towns.sqf: town mode was not ready after 60s - proceeding with town census.";
};

//--- Get all of the city logics.
_towns = [0,0,0] nearEntities [["LocationLogicDepot"], 100000];

//--- Await for a proper initialization.
//--- FIX D6a (WFBE hang-guard): mirrors the bounded-wait idiom at initJIPCompatible.sqf:366-382 (B56
//--- JIP-HANG FIX). Was unbounded per town, SERIAL across ~46 depot logics - if one town's own Init_Town.sqf
//--- instance never sets sideID or wfbe_inactive, this forEach hung on it FOREVER, starving townInit and
//--- every consumer gated on it (Init_Server.sqf:192, Init_Client.sqf:960/1261, the whole match) - silently.
//--- Bounded per-town to 30s (120 x 0.25s uiSleep, real-time). Fallback is SAFE: it writes NOTHING to the
//--- stuck object - it only stops blocking and moves on; the town's own Init_Town.sqf may still complete and
//--- self-register later. Happy path is byte-identical (the while is false on first check when sideID is
//--- already set - the common case - so zero extra ticks run, exactly like the original waitUntil).
{
	Private ["_wTown"];
	_wTown = 0;
	while {isNil {_x getVariable "sideID"} && isNil {_x getVariable "wfbe_inactive"} && (_wTown < 120)} do { uiSleep 0.25; _wTown = _wTown + 1; };
	if (isNil {_x getVariable "sideID"} && isNil {_x getVariable "wfbe_inactive"}) then {
		diag_log format ["[WFBE (INIT)] HANGGUARD| Init_Towns.sqf: town depot logic never set sideID/wfbe_inactive after 30s - SKIPPING it (name=%1 type=%2 pos=%3) so the rest of the match can start.", (_x getVariable ["name", "?"]), typeOf _x, mapGridPosition _x];
	};
} forEach _towns;

townInit = true;

["INITIALIZATION", "Init_Towns.sqf: Towns initialization is done."] Call WFBE_CO_FNC_LogContent;