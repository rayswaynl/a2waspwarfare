/*
	Attempt to load variables from the client profileNamespace.
		Note:
			- Do not use "with" as it won't work with the profileNamespace.
			- Sanitize the variable to prevent variable hijacking.
*/

//--- View distance.
_profile_var = profileNamespace getVariable "WFBE_PERSISTENT_CONST_VIEW_DISTANCE";
if !(isNil '_profile_var') then {
	if (typeName _profile_var == "SCALAR") then {
		if (_profile_var <= (missionNamespace getVariable "WFBE_C_ENVIRONMENT_MAX_VIEW")) then {
			setViewDistance _profile_var;
		};
	};
};

//--- Target FPS
_profile_var = profileNamespace getVariable "WFBE_TARGET_FPS";
if !(isNil '_profile_var') then {
	if (typeName _profile_var == "SCALAR") then {
		missionNamespace setVariable ["AUTO_DISTANCE_VIEW_TARGET_FPS", _profile_var];
	};
};

//--- High climbing default.
WFBE_HighClimbingDefaultEnabled = false;
_profile_var = profileNamespace getVariable "WFBE_HIGH_CLIMBING_DEFAULT_ENABLED";
if !(isNil '_profile_var') then {
	if (typeName _profile_var == "BOOL") then {
		WFBE_HighClimbingDefaultEnabled = _profile_var;
	};
};
missionNamespace setVariable ["WFBE_HighClimbingDefaultEnabled", WFBE_HighClimbingDefaultEnabled];
		
//--- Terrain Grid.
_profile_var = profileNamespace getVariable "WFBE_PERSISTENT_CONST_TERRAIN_GRID";
if !(isNil '_profile_var') then {
	if (typeName _profile_var == "SCALAR") then {
		if (_profile_var <= (missionNamespace getVariable "WFBE_C_ENVIRONMENT_MAX_CLUTTER")) then {
			setTerrainGrid _profile_var;
			currentTG = _profile_var;
		};
	};
};
	
//--- Client Gear Templates.
_profile_var = profileNamespace getVariable Format["WFBE_PERSISTENT_%1_GEAR_TEMPLATE", WFBE_Client_SideJoinedText];
if !(isNil '_profile_var') then {
	if (typeName _profile_var == "ARRAY") then {
		(_profile_var) Call Compile preprocessFileLineNumbers "Client\Init\Init_ProfileGear.sqf";
	};
};

//--- B748 Settings menu: per-player client toggle prefs (default ON). typeName=="BOOL" sanitize = A2-OA-safe isEqualType substitute.
//--- HUD overlay (RUBHUD - read each ~1s by Client_UpdateRHUD.sqf).
RUBHUD = true;
_profile_var = profileNamespace getVariable "WFBE_RUBHUD_ENABLED";
if !(isNil '_profile_var') then {if (typeName _profile_var == "BOOL") then {RUBHUD = _profile_var}};
missionNamespace setVariable ["RUBHUD", RUBHUD];

//--- AAR map markers (gated live in Common_MarkerLoop.sqf).
WFBE_CL_ShowAARMarkers = true;
_profile_var = profileNamespace getVariable "WFBE_SHOW_AAR_MARKERS";
if !(isNil '_profile_var') then {if (typeName _profile_var == "BOOL") then {WFBE_CL_ShowAARMarkers = _profile_var}};
missionNamespace setVariable ["WFBE_CL_ShowAARMarkers", WFBE_CL_ShowAARMarkers];

//--- Bomb-altitude warning (cosmetic flash only; does NOT affect server anti-exploit bomb deletion).
WFBE_BOMB_WARNING_ENABLED = true;
_profile_var = profileNamespace getVariable "WFBE_BOMB_WARNING_ENABLED";
if !(isNil '_profile_var') then {if (typeName _profile_var == "BOOL") then {WFBE_BOMB_WARNING_ENABLED = _profile_var}};
missionNamespace setVariable ["WFBE_BOMB_WARNING_ENABLED", WFBE_BOMB_WARNING_ENABLED];

//--- Ambulance redeploy circles (gated live in Client_AmbulanceRedeployCircles.sqf).
WFBE_AMBULANCE_CIRCLES_ENABLED = true;
_profile_var = profileNamespace getVariable "WFBE_AMBULANCE_CIRCLES_ENABLED";
if !(isNil '_profile_var') then {if (typeName _profile_var == "BOOL") then {WFBE_AMBULANCE_CIRCLES_ENABLED = _profile_var}};
missionNamespace setVariable ["WFBE_AMBULANCE_CIRCLES_ENABLED", WFBE_AMBULANCE_CIRCLES_ENABLED];

//--- Kill feed (bounty chat lines; bounty CASH is never gated).
WFBE_KILL_MESSAGES = true;
_profile_var = profileNamespace getVariable "WFBE_KILL_MESSAGES_ENABLED";
if !(isNil '_profile_var') then {if (typeName _profile_var == "BOOL") then {WFBE_KILL_MESSAGES = _profile_var}};
missionNamespace setVariable ["WFBE_KILL_MESSAGES", WFBE_KILL_MESSAGES];

["INITIALIZATION", "Init_ProfileVariables.sqf: Possible profile variables were defined."] Call WFBE_CO_FNC_LogContent;
