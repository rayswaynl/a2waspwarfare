/*
	FPSPicker_Open.sqf
	Opens the adaptive view-distance / target-FPS picker (idd 28000) and runs the controller loop.
	Opened from GUI_Menu.sqf MenuAction 23 (WF-menu "FPS" button). Mirrors SkinSelector_Open.sqf.

	The picker lets the player:
	  - toggle the adaptive auto-view-distance feature on/off (persisted per-profile), and
	  - pick the target FPS that auto-VD chases: 30 / 45 / 50 / 60 (persisted per-profile via WFBE_TARGET_FPS).
	Default stays OFF (Steff 2026): we only remember the player's explicit choice.
*/

disableSerialization;

Private ["_toggleOn","_target","_saved"];

if (!alive player) exitWith {};
if (dialog) exitWith {};

createDialog "WFBE_FPSPickerMenu";
WFBE_MenuAction = -1;

while {alive player && dialog} do {
	//--- Live label refresh (cheap; only runs while the picker is open).
	_toggleOn = missionNamespace getVariable ["TOOGLE_AUTO_DISTANCE_VIEW", false];
	_target   = missionNamespace getVariable ["AUTO_DISTANCE_VIEW_TARGET_FPS", 60];
	ctrlSetText [28001, if (_toggleOn) then {"Auto-VD: ON"} else {"Auto-VD: OFF"}];
	ctrlSetText [28006, format ["Target %1 FPS    |    VD now: %2 m", _target, round viewDistance]];

	//--- Toggle the feature on/off and persist the choice.
	if (WFBE_MenuAction == 1) then {
		WFBE_MenuAction = -1;
		_toggleOn = !_toggleOn;
		missionNamespace setVariable ["TOOGLE_AUTO_DISTANCE_VIEW", _toggleOn];
		if (_toggleOn) then {
			missionNamespace setVariable ["SAVED_VIEW_DISTANCE", viewDistance];
		} else {
			//--- Restore the saved view distance when turning auto-VD off (mirrors Common_AdjustViewDistance).
			_saved = missionNamespace getVariable ["SAVED_VIEW_DISTANCE", viewDistance];
			if (typeName _saved == "SCALAR") then {setViewDistance (_saved min (missionNamespace getVariable ["WFBE_C_ENVIRONMENT_MAX_VIEW", 10000]))};
		};
		if !(isNil "WFBE_CO_FNC_SetProfileVariable") then {
			["WFBE_TOOGLE_AUTO_DISTANCE_VIEW", _toggleOn] Call WFBE_CO_FNC_SetProfileVariable;
		};
	};

	//--- Pick a target FPS (30 / 45 / 50 / 60) and persist it (same key Common_AdjustViewDistance already uses).
	if (WFBE_MenuAction in [2, 3, 4, 5]) then {
		_target = switch (WFBE_MenuAction) do {case 2: {45}; case 3: {50}; case 5: {30}; default {60}};
		WFBE_MenuAction = -1;
		missionNamespace setVariable ["AUTO_DISTANCE_VIEW_TARGET_FPS", _target];
		if !(isNil "WFBE_CO_FNC_SetProfileVariable") then {
			["WFBE_TARGET_FPS", _target] Call WFBE_CO_FNC_SetProfileVariable;
		};
	};

	//--- Close.
	if (WFBE_MenuAction == 9) exitWith {
		WFBE_MenuAction = -1;
		closeDialog 0;
		createDialog "WF_Menu";
	};

	sleep 0.1;
};
