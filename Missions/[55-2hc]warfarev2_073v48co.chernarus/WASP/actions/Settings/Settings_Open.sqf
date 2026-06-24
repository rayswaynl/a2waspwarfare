/*
	Settings_Open.sqf
	Opens the per-player Settings menu (idd 29000) and runs the controller loop.
	Opened from GUI_Menu.sqf MenuAction 24 (WF-menu GEAR button, the revived skins-button slot).
	Mirrors FPSPicker_Open.sqf: every button sets the SUB-dialog global WFBE_MenuAction (NOT the host
	MenuAction); this loop polls it, applies the change LIVE, persists per-click via WFBE_CO_FNC_SetProfileVariable.

	v1 client-per-player toggles (all client-local; never affect other players):
	  HUD overlay (RUBHUD) | AAR map markers | Bomb-altitude warning | Ambulance redeploy circles |
	  Kill feed (bounty chat) | View distance (1000-5000m choice; coordinates with the auto-VD/FPS picker).
*/

disableSerialization;
private ["_hud","_aar","_bomb","_amb","_kill","_curVD","_autoOn","_maxVD","_chosenVD"];

if (!alive player) exitWith {};
if (dialog) exitWith {};

createDialog "WFBE_SettingsMenu";
WFBE_MenuAction = -1;

while {alive player && dialog} do {
	//--- Live label refresh (cheap; only runs while the menu is open). A2-OA-safe: isNil-defaulted reads,
	//--- if(_bool) branching for labels (never == on a Boolean).
	_hud  = missionNamespace getVariable ["RUBHUD", true];
	_aar  = missionNamespace getVariable ["WFBE_CL_ShowAARMarkers", true];
	_bomb = missionNamespace getVariable ["WFBE_BOMB_WARNING_ENABLED", true];
	_amb  = missionNamespace getVariable ["WFBE_AMBULANCE_CIRCLES_ENABLED", true];
	_kill = missionNamespace getVariable ["WFBE_KILL_MESSAGES", true];
	ctrlSetText [29010, if (_hud)  then {"HUD Overlay: ON"}        else {"HUD Overlay: OFF"}];
	ctrlSetText [29011, if (_aar)  then {"AAR Map Markers: ON"}    else {"AAR Map Markers: OFF"}];
	ctrlSetText [29012, if (_bomb) then {"Bomb Alt Warning: ON"}   else {"Bomb Alt Warning: OFF"}];
	ctrlSetText [29013, if (_amb)  then {"Ambulance Circles: ON"}  else {"Ambulance Circles: OFF"}];
	ctrlSetText [29014, if (_kill) then {"Kill Feed: ON"}          else {"Kill Feed: OFF"}];
	_curVD  = round viewDistance;
	_autoOn = missionNamespace getVariable ["TOOGLE_AUTO_DISTANCE_VIEW", false];
	ctrlSetText [29020, format ["View Distance: %1 m%2", _curVD, if (_autoOn) then {"   (Auto-VD ON - pick a value to take manual control)"} else {""}]];

	//--- HUD overlay (RUBHUD): Client_UpdateRHUD.sqf reads it each ~1s, so the flip is instant.
	if (WFBE_MenuAction == 1) then {
		WFBE_MenuAction = -1;
		RUBHUD = !(missionNamespace getVariable ["RUBHUD", true]);
		missionNamespace setVariable ["RUBHUD", RUBHUD];
		if !(isNil "WFBE_CO_FNC_SetProfileVariable") then {["WFBE_RUBHUD_ENABLED", RUBHUD] Call WFBE_CO_FNC_SetProfileVariable};
	};

	//--- AAR map markers: gate read live by Common_MarkerLoop.sqf. Hide currently-drawn markers at once when OFF.
	if (WFBE_MenuAction == 2) then {
		WFBE_MenuAction = -1;
		WFBE_CL_ShowAARMarkers = !(missionNamespace getVariable ["WFBE_CL_ShowAARMarkers", true]);
		missionNamespace setVariable ["WFBE_CL_ShowAARMarkers", WFBE_CL_ShowAARMarkers];
		if !(WFBE_CL_ShowAARMarkers) then {
			if (!isNil "WFBE_CL_AARMarkerRegistry") then {
				{
					if (typeName _x == "ARRAY") then {
						if (_x select 4) then {(_x select 1) setMarkerAlphaLocal 0; _x set [4, false]; _x set [8, true]};
					};
				} forEach WFBE_CL_AARMarkerRegistry;
			};
		};
		if !(isNil "WFBE_CO_FNC_SetProfileVariable") then {["WFBE_SHOW_AAR_MARKERS", WFBE_CL_ShowAARMarkers] Call WFBE_CO_FNC_SetProfileVariable};
	};

	//--- Bomb-altitude warning (cosmetic flash only; the bomb loop re-reads the gate every 0.5s).
	if (WFBE_MenuAction == 3) then {
		WFBE_MenuAction = -1;
		_bomb = !(missionNamespace getVariable ["WFBE_BOMB_WARNING_ENABLED", true]);
		missionNamespace setVariable ["WFBE_BOMB_WARNING_ENABLED", _bomb];
		if !(isNil "WFBE_CO_FNC_SetProfileVariable") then {["WFBE_BOMB_WARNING_ENABLED", _bomb] Call WFBE_CO_FNC_SetProfileVariable};
	};

	//--- Ambulance redeploy circles: gate read live by Client_AmbulanceRedeployCircles.sqf. Clear rings now when OFF.
	if (WFBE_MenuAction == 4) then {
		WFBE_MenuAction = -1;
		_amb = !(missionNamespace getVariable ["WFBE_AMBULANCE_CIRCLES_ENABLED", true]);
		missionNamespace setVariable ["WFBE_AMBULANCE_CIRCLES_ENABLED", _amb];
		if (!_amb) then {
			{
				if ((typeName _x == "STRING") && {(_x find "AmbRange_") == 0}) then {deleteMarkerLocal _x};
			} forEach allMapMarkers;
		};
		if !(isNil "WFBE_CO_FNC_SetProfileVariable") then {["WFBE_AMBULANCE_CIRCLES_ENABLED", _amb] Call WFBE_CO_FNC_SetProfileVariable};
	};

	//--- Kill feed (bounty chat lines): gate read live by AwardBounty/AwardBountyPlayer. Bounty CASH is never gated.
	if (WFBE_MenuAction == 5) then {
		WFBE_MenuAction = -1;
		_kill = !(missionNamespace getVariable ["WFBE_KILL_MESSAGES", true]);
		missionNamespace setVariable ["WFBE_KILL_MESSAGES", _kill];
		if !(isNil "WFBE_CO_FNC_SetProfileVariable") then {["WFBE_KILL_MESSAGES_ENABLED", _kill] Call WFBE_CO_FNC_SetProfileVariable};
	};

	//--- View distance manual choice (11=1000 .. 15=5000). Disables auto-VD (else it drifts the value back).
	if (WFBE_MenuAction in [11,12,13,14,15]) then {
		_chosenVD = switch (WFBE_MenuAction) do {case 11:{1000}; case 12:{2000}; case 13:{3000}; case 14:{4000}; case 15:{5000}; default {3000}};
		WFBE_MenuAction = -1;
		_maxVD = missionNamespace getVariable ["WFBE_C_ENVIRONMENT_MAX_VIEW", 5000];
		if (typeName _maxVD == "SCALAR") then {_chosenVD = _chosenVD min _maxVD};
		_chosenVD = _chosenVD max 500;
		if (missionNamespace getVariable ["TOOGLE_AUTO_DISTANCE_VIEW", false]) then {
			missionNamespace setVariable ["TOOGLE_AUTO_DISTANCE_VIEW", false];
			if !(isNil "WFBE_CO_FNC_SetProfileVariable") then {["WFBE_TOOGLE_AUTO_DISTANCE_VIEW", false] Call WFBE_CO_FNC_SetProfileVariable};
		};
		setViewDistance _chosenVD;
		missionNamespace setVariable ["SAVED_VIEW_DISTANCE", _chosenVD];
		if !(isNil "WFBE_CO_FNC_SetProfileVariable") then {["WFBE_PERSISTENT_CONST_VIEW_DISTANCE", _chosenVD] Call WFBE_CO_FNC_SetProfileVariable};
	};

	//--- Close.
	if (WFBE_MenuAction == 9) exitWith {
		WFBE_MenuAction = -1;
		closeDialog 0;
	};

	sleep 0.1;
};
