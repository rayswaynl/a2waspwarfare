//============================================================================
//  [CLAUDE FEATURE - REMOVABLE]   Haboob (Sandstorm)  -  Zargabad mechanic #1
//  ---------------------------------------------------------------------------
//  Periodic desert sandstorm: a heavy fog bank + tan overcast rolls in and
//  drops visibility map-wide for a few minutes, then clears. Because Arma 2 OA
//  synchronises weather from the server, this affects every client AND AI sight
//  range at once -> tense low-visibility CQB windows that suit Zargabad's dense
//  urban core. A faint orange ellipse on the map signals an active storm.
//
//  Server-only. Reuses nothing but engine weather + the mission log -> very cheap.
//  Toggle:  WFBE_C_CLAUDE_SANDSTORM_ENABLED  (default 1; set 0 to disable)
//  Remove:  delete this file + its line in Claude_Features_Init.sqf.
//  Arma 2 OA SQF only (no remoteExec / no A3-only weather cmds). ~35 LOC.
//============================================================================
if (!isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_CLAUDE_SANDSTORM_ENABLED", 1]) <= 0) exitWith {};

waitUntil {!isNil "serverInitComplete" && {serverInitComplete}};

//--- A map overlay that fades in while a storm is active (createMarker is global in A2).
private "_mk";
_mk = createMarker ["WFBE_Claude_Sandstorm", [4096,0,4096]];
_mk setMarkerShape "ELLIPSE"; _mk setMarkerBrush "Solid"; _mk setMarkerColor "ColorOrange";
_mk setMarkerSize [0,0]; _mk setMarkerAlpha 0;

sleep (300 + random 300);   //--- first storm 5-10 min in

while {true} do {
	if ((missionNamespace getVariable ["WFBE_C_CLAUDE_SANDSTORM_ENABLED", 1]) > 0) then {
		private "_dur"; _dur = 180 + random 180;   //--- 3-6 min storm
		["INFORMATION", "Claude_Sandstorm.sqf: A haboob is rolling in over Zargabad - visibility dropping."] call WFBE_CO_FNC_LogContent;
		60 setOvercast 0.7; 30 setFog 0.6;          //--- timed transitions sync to all clients + AI
		_mk setMarkerSize [4500,4500]; _mk setMarkerAlpha 0.22;
		sleep _dur;
		["INFORMATION", "Claude_Sandstorm.sqf: The sandstorm is clearing."] call WFBE_CO_FNC_LogContent;
		90 setFog 0.03; 120 setOvercast 0.15;
		_mk setMarkerAlpha 0; _mk setMarkerSize [0,0];
	};
	sleep (900 + random 600);   //--- 15-25 min of calm before the next one
};
