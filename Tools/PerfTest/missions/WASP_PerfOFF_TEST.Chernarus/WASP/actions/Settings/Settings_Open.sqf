/*
	Settings_Open.sqf  (v2 - GR-2026-07-03a)
	Opens the unified PLAYER SETTINGS dialog (idd 30000) and runs the controller loop.
	Opened from GUI_Menu.sqf MenuAction 23 (WF-menu "FPS" button) AND MenuAction 24 ("SETUP"/GEAR button):
	both footer entry points now land on this one screen (the old split WFBE_SettingsMenu/WFBE_FPSPickerMenu
	menus are retired). Every button sets the SUB-dialog global WFBE_MenuAction (NOT the host MenuAction);
	this loop polls it, applies the change LIVE, and persists per-click via WFBE_CO_FNC_SetProfileVariable.
	The profile KEYS are unchanged from v1, so existing player profiles carry over 1:1.

	Player-side options (all client-local; never affect other players):
	  VIDEO    : View distance (slider 500..map cap) | Terrain grid (slider 1..map clutter cap) |
	             Auto view distance on/off | Target FPS 30/45/50/60
	  GAMEPLAY : HUD overlay | AAR map markers | Bomb-altitude warning | Ambulance redeploy circles |
	             Kill feed | Auto IR smoke | Auto deploy bipod | High-climbing default
	  AUDIO    : Audio cues

	The terrain-grid slider (setTerrainGrid, key WFBE_PERSISTENT_CONST_TERRAIN_GRID) and the high-climbing
	toggle (WFBE_HighClimbingDefaultEnabled, key WFBE_HIGH_CLIMBING_DEFAULT_ENABLED) share var + key + localized
	strings with their Team-menu controls (GUI_Menu_Team.sqf idc 13005 / idc 13020), which remain in place.

	A2-OA-safe: isNil-defaulted reads; if(_bool) label branching (never == on a Boolean); global
	ctrlSetText/sliderSet* [idc, ...] forms on this idd dialog (never (display displayCtrl) ctrlShow).
	The VD slider is polled each tick (like the Team menu idc 13003), so dragging it applies instantly.
*/

disableSerialization;
private ["_hud","_aar","_bomb","_amb","_kill","_irs","_bip","_acue","_autoOn","_target","_maxVD","_curVD","_sliderVD","_lastSliderVD","_chosenVD","_hc","_maxTG","_curTG","_sliderTG","_lastSliderTG","_chosenTG"];

if (!alive player) exitWith {};
if (dialog) exitWith {};

createDialog "WFBE_PlayerSettingsMenu";
WFBE_MenuAction = -1;

//--- Slider range must respect the per-map ceiling (ZG=3000); floor at 500. Seed the thumb at the live VD.
_maxVD = missionNamespace getVariable ["WFBE_C_ENVIRONMENT_MAX_VIEW", 5000];
if !(typeName _maxVD == "SCALAR") then {_maxVD = 5000};
if (_maxVD < 500) then {_maxVD = 500};
sliderSetRange [30011, 500, _maxVD];
_curVD = round viewDistance;
_curVD = (_curVD max 500) min _maxVD;
sliderSetPosition [30011, _curVD];
_lastSliderVD = _curVD;

//--- Terrain-grid / clutter slider (idc 30018): range 1..per-map clutter cap, thumb seeded at the live currentTG.
//--- Mirrors the Team-menu slider (idc 13005): setTerrainGrid on change, persisted under WFBE_PERSISTENT_CONST_TERRAIN_GRID.
_maxTG = missionNamespace getVariable ["WFBE_C_ENVIRONMENT_MAX_CLUTTER", 50];
if !(typeName _maxTG == "SCALAR") then {_maxTG = 50};
if (_maxTG < 1) then {_maxTG = 1};
sliderSetRange [30018, 1, _maxTG];
_curTG = missionNamespace getVariable ["currentTG", 25];
if !(typeName _curTG == "SCALAR") then {_curTG = 25};
_curTG = (round _curTG) max 1;
_curTG = _curTG min _maxTG;
sliderSetPosition [30018, _curTG];
_lastSliderTG = _curTG;

while {alive player && dialog} do {
	//--- Live label refresh (cheap; only runs while the dialog is open).
	_hud    = missionNamespace getVariable ["RUBHUD", true];
	_aar    = missionNamespace getVariable ["WFBE_CL_ShowAARMarkers", true];
	_bomb   = missionNamespace getVariable ["WFBE_BOMB_WARNING_ENABLED", true];
	_amb    = missionNamespace getVariable ["WFBE_AMBULANCE_CIRCLES_ENABLED", true];
	_kill   = missionNamespace getVariable ["WFBE_KILL_MESSAGES", true];
	_irs    = missionNamespace getVariable ["WFBE_AUTO_IRSMOKE", true];
	_bip    = missionNamespace getVariable ["WFBE_AUTO_BIPOD", true];
	_acue   = missionNamespace getVariable ["WFBE_AUDIO_CUES", false];
	_autoOn = missionNamespace getVariable ["TOOGLE_AUTO_DISTANCE_VIEW", false];
	_target = missionNamespace getVariable ["AUTO_DISTANCE_VIEW_TARGET_FPS", 60];
	_hc     = missionNamespace getVariable ["WFBE_HighClimbingDefaultEnabled", false];

	ctrlSetText [30020, if (_hud)  then {"HUD Overlay: ON"}         else {"HUD Overlay: OFF"}];
	ctrlSetText [30021, if (_aar)  then {"AAR Markers: ON"}         else {"AAR Markers: OFF"}];
	ctrlSetText [30022, if (_bomb) then {"Bomb Warning: ON"}        else {"Bomb Warning: OFF"}];
	ctrlSetText [30023, if (_amb)  then {"Ambulance Rings: ON"}     else {"Ambulance Rings: OFF"}];
	ctrlSetText [30024, if (_kill) then {"Kill Feed: ON"}           else {"Kill Feed: OFF"}];
	ctrlSetText [30025, if (_irs)  then {"Auto IR Smoke: ON"}       else {"Auto IR Smoke: OFF"}];
	ctrlSetText [30026, if (_bip)  then {"Auto Deploy Bipod: ON"}   else {"Auto Deploy Bipod: OFF"}];
	ctrlSetText [30030, if (_acue) then {"Audio Cues: ON"}          else {"Audio Cues: OFF"}];
	ctrlSetText [30012, if (_autoOn) then {"Auto View Distance: ON"} else {"Auto View Distance: OFF"}];
	ctrlSetText [30010, format ["View Distance: %1 m", round viewDistance]];
	ctrlSetText [30017, Format [localize "STR_WF_TEAM_TerrainGridLabel", round (missionNamespace getVariable ["currentTG", 25])]];
	ctrlSetText [30027, if (_hc) then {localize "STR_WF_TEAM_HighClimbingDefaultOn"} else {localize "STR_WF_TEAM_HighClimbingDefaultOff"}];

	//--- VD slider poll (drag = instant apply). Auto-VD is disabled the moment the player takes manual control,
	//--- otherwise the adaptive loop drifts the value back. Mirrors the Team-menu slider persistence.
	_sliderVD = round (sliderPosition 30011);
	if (abs (_sliderVD - _lastSliderVD) >= 1) then {
		_lastSliderVD = _sliderVD;
		_chosenVD = (_sliderVD max 500) min _maxVD;
		if (missionNamespace getVariable ["TOOGLE_AUTO_DISTANCE_VIEW", false]) then {
			missionNamespace setVariable ["TOOGLE_AUTO_DISTANCE_VIEW", false];
			if !(isNil "WFBE_CO_FNC_SetProfileVariable") then {["WFBE_TOOGLE_AUTO_DISTANCE_VIEW", false] Call WFBE_CO_FNC_SetProfileVariable};
		};
		setViewDistance _chosenVD;
		missionNamespace setVariable ["SAVED_VIEW_DISTANCE", _chosenVD];
		if !(isNil "WFBE_CO_FNC_SetProfileVariable") then {["WFBE_PERSISTENT_CONST_VIEW_DISTANCE", _chosenVD] Call WFBE_CO_FNC_SetProfileVariable};
	};

	//--- Terrain-grid slider poll (drag = instant apply). Same idiom as the Team menu: setTerrainGrid + persist currentTG.
	_sliderTG = round (sliderPosition 30018);
	if (abs (_sliderTG - _lastSliderTG) >= 1) then {
		_lastSliderTG = _sliderTG;
		_chosenTG = (_sliderTG max 1) min _maxTG;
		currentTG = _chosenTG;
		missionNamespace setVariable ["currentTG", _chosenTG];
		setTerrainGrid _chosenTG;
		if !(isNil "WFBE_CO_FNC_SetProfileVariable") then {["WFBE_PERSISTENT_CONST_TERRAIN_GRID", _chosenTG] Call WFBE_CO_FNC_SetProfileVariable};
	};

	//--- Ray 2026-07-04b: HUD-Overlay toggle RESTORED (supersedes the 2026-07-04 hard-off; Ray re-enabled the RHUD
	//--- by default). Client_UpdateRHUD.sqf reads RUBHUD each ~1s, so the flip is instant; the pref persists via
	//--- WFBE_RUBHUD_ENABLED (default ON).
	if (WFBE_MenuAction == 1) then {
		WFBE_MenuAction = -1;
		RUBHUD = !(missionNamespace getVariable ["RUBHUD", true]);
		missionNamespace setVariable ["RUBHUD", RUBHUD];
		if !(isNil "WFBE_CO_FNC_SetProfileVariable") then {["WFBE_RUBHUD_ENABLED", RUBHUD] Call WFBE_CO_FNC_SetProfileVariable};
	};

	//--- High-climbing default (WFBE_HighClimbingDefaultEnabled): same var + profile key as the Team-menu control.
	//--- LowGear_Toggle / Init_Unit read it as the per-vehicle default; the flip persists and applies on the next spawn.
	if (WFBE_MenuAction == 10) then {
		WFBE_MenuAction = -1;
		_hc = !(missionNamespace getVariable ["WFBE_HighClimbingDefaultEnabled", false]);
		WFBE_HighClimbingDefaultEnabled = _hc;
		missionNamespace setVariable ["WFBE_HighClimbingDefaultEnabled", _hc];
		if !(isNil "WFBE_CO_FNC_SetProfileVariable") then {["WFBE_HIGH_CLIMBING_DEFAULT_ENABLED", _hc] Call WFBE_CO_FNC_SetProfileVariable};
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

	//--- Ambulance redeploy circles: gate read live by Client_AmbulanceRedeployCircles.sqf. Rings clear within ~5s when OFF.
	if (WFBE_MenuAction == 4) then {
		WFBE_MenuAction = -1;
		_amb = !(missionNamespace getVariable ["WFBE_AMBULANCE_CIRCLES_ENABLED", true]);
		missionNamespace setVariable ["WFBE_AMBULANCE_CIRCLES_ENABLED", _amb];
		if !(isNil "WFBE_CO_FNC_SetProfileVariable") then {["WFBE_AMBULANCE_CIRCLES_ENABLED", _amb] Call WFBE_CO_FNC_SetProfileVariable};
	};

	//--- Kill feed (bounty chat lines): gate read live by AwardBounty/AwardBountyPlayer. Bounty CASH is never gated.
	if (WFBE_MenuAction == 5) then {
		WFBE_MenuAction = -1;
		_kill = !(missionNamespace getVariable ["WFBE_KILL_MESSAGES", true]);
		missionNamespace setVariable ["WFBE_KILL_MESSAGES", _kill];
		if !(isNil "WFBE_CO_FNC_SetProfileVariable") then {["WFBE_KILL_MESSAGES_ENABLED", _kill] Call WFBE_CO_FNC_SetProfileVariable};
	};

	//--- Auto IR smoke (IRS_OnIncomingMissile reads it client-side; nil on server -> AI vehicles unaffected).
	if (WFBE_MenuAction == 6) then {
		WFBE_MenuAction = -1;
		_irs = !(missionNamespace getVariable ["WFBE_AUTO_IRSMOKE", true]);
		missionNamespace setVariable ["WFBE_AUTO_IRSMOKE", _irs];
		if !(isNil "WFBE_CO_FNC_SetProfileVariable") then {["WFBE_AUTO_IRSMOKE", _irs] Call WFBE_CO_FNC_SetProfileVariable};
	};

	//--- Auto deploy bipod (Common_Bipod auto-deploy EH reads it; manual TAB deploy is unaffected).
	if (WFBE_MenuAction == 7) then {
		WFBE_MenuAction = -1;
		_bip = !(missionNamespace getVariable ["WFBE_AUTO_BIPOD", true]);
		missionNamespace setVariable ["WFBE_AUTO_BIPOD", _bip];
		if !(isNil "WFBE_CO_FNC_SetProfileVariable") then {["WFBE_AUTO_BIPOD", _bip] Call WFBE_CO_FNC_SetProfileVariable};
	};

	//--- Audio cues (opt-in factory/build sounds in Client_FNC_Special; default OFF).
	if (WFBE_MenuAction == 8) then {
		WFBE_MenuAction = -1;
		_acue = !(missionNamespace getVariable ["WFBE_AUDIO_CUES", false]);
		missionNamespace setVariable ["WFBE_AUDIO_CUES", _acue];
		if !(isNil "WFBE_CO_FNC_SetProfileVariable") then {["WFBE_AUDIO_CUES", _acue] Call WFBE_CO_FNC_SetProfileVariable};
	};

	//--- Auto view distance on/off. Same behaviour as the old FPS picker: on enable, remember the current VD;
	//--- on disable, restore the saved VD (clamped to the map cap). Persist the toggle.
	if (WFBE_MenuAction == 20) then {
		WFBE_MenuAction = -1;
		_autoOn = !(missionNamespace getVariable ["TOOGLE_AUTO_DISTANCE_VIEW", false]);
		missionNamespace setVariable ["TOOGLE_AUTO_DISTANCE_VIEW", _autoOn];
		if (_autoOn) then {
			missionNamespace setVariable ["SAVED_VIEW_DISTANCE", viewDistance];
		} else {
			private ["_saved"];
			_saved = missionNamespace getVariable ["SAVED_VIEW_DISTANCE", viewDistance];
			if (typeName _saved == "SCALAR") then {
				_saved = (_saved max 500) min _maxVD;
				setViewDistance _saved;
				sliderSetPosition [30011, _saved];
				_lastSliderVD = round _saved;
			};
		};
		if !(isNil "WFBE_CO_FNC_SetProfileVariable") then {["WFBE_TOOGLE_AUTO_DISTANCE_VIEW", _autoOn] Call WFBE_CO_FNC_SetProfileVariable};
	};

	//--- Target FPS presets (30/45/50/60) that auto-VD chases. Same key Common_AdjustViewDistance uses.
	if (WFBE_MenuAction in [30,31,32,33]) then {
		_target = switch (WFBE_MenuAction) do {case 30:{30}; case 31:{45}; case 32:{50}; case 33:{60}; default {60}};
		WFBE_MenuAction = -1;
		missionNamespace setVariable ["AUTO_DISTANCE_VIEW_TARGET_FPS", _target];
		if !(isNil "WFBE_CO_FNC_SetProfileVariable") then {["WFBE_TARGET_FPS", _target] Call WFBE_CO_FNC_SetProfileVariable};
	};

	//--- Close.
	if (WFBE_MenuAction == 9) exitWith {
		WFBE_MenuAction = -1;
		closeDialog 0;
	};

	sleep 0.1;
};
