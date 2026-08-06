/*
	GUI_Menu_Streamer.sqf - spectator v5 P5 streamer menu controller (caster QoL).
	Poll-loop controller in the WF_Menu idiom (GUI_Menu.sqf): the dialog's buttons only stamp
	WFBE_StreamerMenuAction = N; this scheduled loop dispatches the number, applies the change
	to the live spectator globals, and re-renders every label with the current value each pass
	so the menu always shows live state (PgUp/PgDn sensitivity changes show up while open).
	NO disableSerialization and no stored Display/Control handles: this script suspends (sleep
	in the poll loop) and on A2 a suspending script that calls disableSerialization silently
	dies at the first suspend - see the Client_SpectatorEnter.sqf header note. Global-form
	ctrlSetText [idc, ...] only.
	Director Auto / Orbit rows mirror the G / O key handlers in Client_SpectatorEnter.sqf
	(same state writes, same chat lines) and need the camera ACTIVE; the config rows (GUER
	targets, eyes-cam cadence, HUD fade, idle dwell, cam speed) write missionNamespace values
	that the director/cam loops read live, so they work from the caster body too.
*/
Private ["_active","_directorOn","_v","_txt"];

WFBE_StreamerMenuAction = -1;

while {alive player && dialog} do {
	if (!dialog) exitWith {};

	_active = missionNamespace getVariable ["WFBE_C_VAR_SpectatorActive", false];

	//--- Live labels: current value in every label, every pass, WF-menu style.
	if (_active) then {
		_directorOn = false;
		if (!isNil "WFBE_C_VAR_SpectatorMode") then {_directorOn = (WFBE_C_VAR_SpectatorMode == "director")};
		ctrlSetText [102644, Format ["Director Auto: %1", if (_directorOn) then {"ON"} else {"OFF"}]];
		_v = true;
		if (!isNil "WFBE_C_VAR_SpectatorOrbit") then {_v = WFBE_C_VAR_SpectatorOrbit};
		ctrlSetText [102645, Format ["Orbit Reveals: %1", if (_v) then {"ON"} else {"OFF (all static)"}]];
	} else {
		ctrlSetText [102644, "Director Auto: - (camera off)"];
		ctrlSetText [102645, "Orbit Reveals: - (camera off)"];
	};
	ctrlSetText [102646, Format ["GUER Targets: %1", if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_TARGET_GUER", 1]) > 0) then {"ON"} else {"OFF"}]];
	ctrlSetText [102647, Format ["Arty Rings: %1", if ((missionNamespace getVariable ["WFBE_C_ARTY_RING", 1]) > 0) then {"ON"} else {"OFF"}]];
	ctrlSetText [102648, Format ["Idle Dwell: %1s", missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_GLANCE_SEC", 3]]];
	ctrlSetText [102650, Format ["Cam Speed: %1 m/s", missionNamespace getVariable ["WFBE_C_SPECTATOR_SPEED", 15]]];
	_v = missionNamespace getVariable ["WFBE_C_SPECTATOR_HUD_FADE_SEC", 6];
	ctrlSetText [102651, Format ["HUD Fade: %1", if (_v >= 9999) then {"NEVER"} else {Format ["%1s", _v]}]];
	ctrlSetText [102652, Format ["Sensitivity: %1 (PgUp/PgDn in camera)", missionNamespace getVariable ["WFBE_C_SPECTATOR_SENS", 25]]];

	//--- Director Auto: mirrors the G key handler (Client_SpectatorEnter.sqf case 34) verbatim.
	if (WFBE_StreamerMenuAction == 1) then {
		WFBE_StreamerMenuAction = -1;
		if (_active && {(missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR", 0]) > 0}) then {
			if (WFBE_C_VAR_SpectatorMode == "director") then {
				WFBE_C_VAR_SpectatorMode = "free";
				WFBE_C_VAR_SpectatorDirectorAuto = false;
				diag_log "SPECTATE|v5|menu|mode-off|reason=menu";
				systemChat "[WASP] Director mode off - free camera.";
			} else {
				WFBE_C_VAR_SpectatorMode = "director";
				WFBE_C_VAR_SpectatorDirectorPinned = false;
				WFBE_C_VAR_SpectatorDirectorAuto = true;
				WFBE_C_VAR_SpectatorOrbit = true;
				WFBE_C_VAR_SpectatorOrbitAngle = 0;
				WFBE_C_VAR_SpectatorTarget = objNull;
				WFBE_C_VAR_DirectorLastSwitch = 0;
				WFBE_C_VAR_DirectorAutoTime = 0;
				WFBE_C_VAR_DirectorLastBaseCheck = 0;
				WFBE_C_VAR_DirectorLastEstablish = -120;
				WFBE_C_VAR_DirectorContactTarget = objNull;
				WFBE_C_VAR_DirectorLastContactScan = 0;
				WFBE_C_VAR_DirectorReturnPending = false;
				diag_log Format ["SPECTATE|v5|menu|mode-on|class=%1", WFBE_C_VAR_SpectatorDirectorClass];
				systemChat "[WASP] Director mode on - pooled action auto-switch enabled.";
			};
		} else {
			systemChat "[WASP] Director toggle needs the spectator camera - use the Spectator Camera action first.";
		};
	};

	//--- Orbit: mirrors the O key handler (case 24).
	if (WFBE_StreamerMenuAction == 2) then {
		WFBE_StreamerMenuAction = -1;
		if (_active && {(missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR", 0]) > 0}) then {
			WFBE_C_VAR_SpectatorOrbit = !WFBE_C_VAR_SpectatorOrbit;
			diag_log Format ["SPECTATE|v5|menu|orbit=%1", WFBE_C_VAR_SpectatorOrbit];
			systemChat Format ["[WASP] Director orbit: %1", if (WFBE_C_VAR_SpectatorOrbit) then {"ON"} else {"OFF (static)"}];
		} else {
			systemChat "[WASP] Orbit toggle needs the spectator camera - use the Spectator Camera action first.";
		};
	};

	//--- GUER watch targets on/off (numeric flag, read per director target-pick).
	if (WFBE_StreamerMenuAction == 3) then {
		WFBE_StreamerMenuAction = -1;
		_v = if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_TARGET_GUER", 1]) > 0) then {0} else {1};
		missionNamespace setVariable ["WFBE_C_SPECTATOR_TARGET_GUER", _v];
		diag_log Format ["SPECTATE|v5|menu|target-guer=%1", _v];
		systemChat Format ["[WASP] GUER watch targets: %1", if (_v > 0) then {"ON"} else {"OFF"}];
	};

	//--- Arty ring overlay toggle (v8): client-local map rings; casters ship OFF by default so
	//--- the broadcast map stays clean - this row opts back in live (Client_ArtyRangeRings.sqf
	//--- re-checks the flag every pass and tears down/redraws accordingly).
	if (WFBE_StreamerMenuAction == 8) then {
		WFBE_StreamerMenuAction = -1;
		_v = if ((missionNamespace getVariable ["WFBE_C_ARTY_RING", 1]) > 0) then {0} else {1};
		missionNamespace setVariable ["WFBE_C_ARTY_RING", _v];
		diag_log Format ["SPECTATE|v8|menu|arty-ring=%1", _v];
		systemChat Format ["[WASP] Artillery range rings: %1", if (_v > 0) then {"ON"} else {"OFF"}];
	};

	//--- HUD fade cycle 6s -> NEVER(9999) -> 3s -> 6s.
	if (WFBE_StreamerMenuAction == 5) then {
		WFBE_StreamerMenuAction = -1;
		_v = missionNamespace getVariable ["WFBE_C_SPECTATOR_HUD_FADE_SEC", 6];
		_v = switch (_v) do {case 3: {6}; case 6: {9999}; default {3}};
		missionNamespace setVariable ["WFBE_C_SPECTATOR_HUD_FADE_SEC", _v];
		diag_log Format ["SPECTATE|v5|menu|hud-fade=%1", _v];
	};

	//--- Idle-shot dwell cycle 3s -> 5s -> 2s -> 3s. fix(bughunt 2026-08-06): write the GLANCE constant the
	//--- v8 director actually reads each pass (Client_SpectatorDirector.sqf ~:793); the old target
	//--- WFBE_C_SPECTATOR_DIRECTOR_IDLE_DWELL_SEC is read by nothing (registration kept per flag policy).
	if (WFBE_StreamerMenuAction == 6) then {
		WFBE_StreamerMenuAction = -1;
		_v = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_GLANCE_SEC", 3];
		_v = switch (_v) do {case 2: {3}; case 3: {5}; default {2}};
		missionNamespace setVariable ["WFBE_C_SPECTATOR_DIRECTOR_GLANCE_SEC", _v];
		diag_log Format ["SPECTATE|v5|menu|idle-dwell=%1", _v];
	};

	//--- Free-cam speed cycle 15 -> 30 -> 8 -> 15 (read every render frame; applies instantly).
	if (WFBE_StreamerMenuAction == 7) then {
		WFBE_StreamerMenuAction = -1;
		_v = missionNamespace getVariable ["WFBE_C_SPECTATOR_SPEED", 15];
		_v = switch (_v) do {case 8: {15}; case 15: {30}; default {8}};
		missionNamespace setVariable ["WFBE_C_SPECTATOR_SPEED", _v];
		diag_log Format ["SPECTATE|v5|menu|cam-speed=%1", _v];
	};

	//--- Close (X, footer button, or a raced action number after closeDialog).
	if (WFBE_StreamerMenuAction == 9) exitWith {
		WFBE_StreamerMenuAction = -1;
		closeDialog 0;
	};

	sleep 0.1;
};
