//--- fix/marker-loop-siblings-watchdog: central crash-recovery supervisor for the client marker/HUD
//--- loops that have no per-event registrar of their own to piggyback a respawn check on (unlike
//--- Common_MarkerLoop.sqf, whose Common_MarkerUpdate.sqf/Common_AARadarMarkerUpdate.sqf registrars
//--- already re-arm it on every new registration). A single runtime error inside any ONE of these
//--- one-shot execVM'd/spawned scripts otherwise freezes it (and whatever it draws/updates) for the
//--- rest of the mission, with nothing to notice or recover it - the same failure class fixed for
//--- the consolidated loop by PR #1476 (see Common_MarkerUpdate.sqf:72-81).
//---
//--- Design: ONE supervisor, spawned ONCE from Init_Client.sqf after every watched loop's own launch
//--- site has had the chance to fire. Each registry entry is [handleVarName, relaunchCode, everAlive].
//--- Per tick: skip anything never armed (isNil); if armed and scriptDone AND it was PREVIOUSLY
//--- observed running (everAlive true) AND the round has not ended, relaunch it via the exact same
//--- execVM/spawn expression its own call site in Init_Client.sqf used, and reset everAlive to false
//--- so the fresh copy must prove itself alive again before a further crash is trusted.
//---
//--- The "everAlive" gate (rather than a bare isNil-or-scriptDone check) is deliberate: two of these
//--- eight loops are called UNCONDITIONALLY here but legitimately self-exit in their very first
//--- statement when their own feature flag is off (Client_AmbulanceRedeployCircles.sqf,
//--- Client_ArtyRangeRings.sqf), and a supervisor that cannot tell "disabled by design" apart from
//--- "crashed mid-loop" would busy-respawn a disabled feature forever. Requiring at least one
//--- observed-alive tick before a respawn is armed makes that distinction for free, with no per-loop
//--- flag knowledge duplicated here. (Client_GuerPatrolMarkers.sqf and Client_BookkeepBlinkingIcons.sqf
//--- are already call-site-gated the same way below - isNil alone keeps them quiet when disabled.)
//--- The one accepted blind spot: a crash inside the first tick interval after (re)arm, before this
//--- supervisor ever observed the copy running, reads identically to "disabled" and is not retried.
//---
//--- Terminal condition: gameOver and WFBE_GameOver are always set together (initJIPCompatible.sqf,
//--- Client_FNC_Special.sqf, HandleSpecial.sqf, server_victory_threeway.sqf all assign both in the same
//--- statement pair) but in-flight round-end PRs are not consistent about which one they test (#2211/
//--- #2117/#2197/#2277 test bare gameOver only; #2218/#2217 test gameOver||WFBE_GameOver) - checking
//--- both here is a strict superset of either convention and cannot miss a round end however that
//--- lands. The same OR also ends this supervisor's own loop, so it does not keep ticking past the
//--- round these eight loops already refuse to run past.
Private ["_registry","_entry","_name","_handle","_interval"];

_registry = [
	["WFBE_CL_TownMarkersHandle",       {[] execVM "Client\FSM\updatetownmarkers.sqf"},                                                        false],
	["WFBE_CL_TeamsMarkersHandle",      {[] execVM "Client\FSM\updateteamsmarkers.sqf"},                                                       false],
	["WFBE_CL_AicomMarkersHandle",      {[] execVM "Client\FSM\updateaicommarkers.sqf"},                                                       false],
	["WFBE_CL_PatrolMarkersHandle",     {[] execVM "Client\FSM\updatepatrolmarkers.sqf"},                                                      false],
	["WFBE_CL_AmbulanceCirclesHandle",  {[] spawn Compile preprocessFileLineNumbers "Client\Functions\Client_AmbulanceRedeployCircles.sqf"},   false],
	["WFBE_CL_ArtyRingsHandle",         {[] spawn Compile preprocessFileLineNumbers "Client\Functions\Client_ArtyRangeRings.sqf"},              false],
	["WFBE_CL_GuerPatrolMarkersHandle", {[] execVM "Client\Functions\Client_GuerPatrolMarkers.sqf"},                                           false],
	["WFBE_CL_BlinkingIconsHandle",     {[] execVM "Client\Functions\Client_BookkeepBlinkingIcons.sqf"},                                       false]
];

_interval = missionNamespace getVariable ["WFBE_C_MARKER_WATCHDOG_INTERVAL", 45];
if (isNil "_interval" || {typeName _interval != "SCALAR"} || {_interval < 5}) then {_interval = 45};

sleep 10; //--- short first delay: lets every unconditional call site above have already returned
          //--- (spawning is non-blocking) before the very first liveness observation.

while {!(gameOver || WFBE_GameOver)} do {
	{
		_entry = _x;
		_name = _entry select 0;
		if (!(isNil _name)) then {
			_handle = missionNamespace getVariable _name;
			if (scriptDone _handle) then {
				if ((_entry select 2) && {!(gameOver || WFBE_GameOver)}) then {
					_entry set [2, false];
					missionNamespace setVariable [_name, (call (_entry select 1))];
					diag_log format ["WATCHDOG|marker-siblings|v1|respawned=%1|t=%2", _name, round time];
				};
			} else {
				_entry set [2, true];
			};
		};
	} forEach _registry;

	sleep _interval;
};
