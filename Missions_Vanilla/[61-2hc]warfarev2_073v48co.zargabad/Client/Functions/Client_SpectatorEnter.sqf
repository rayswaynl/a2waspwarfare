/* Client_SpectatorEnter.sqf
   fable/spectator-v1 -> v8 DEFINITIVE rebuild (owner mandate 2026-08-01)
   -------------------------------------------------------------------------
   Enters the UID-allowlisted spectator overlay for the CALLING client only.
   The UID allowlist gates ACTION VISIBILITY on this client only, under standard
   A2 locality; it is not server-enforced authentication or authorization.
   v1 safety model unchanged: body parked invulnerable + captive + position-locked,
   death watchdog auto-exits, exit is idempotent (Client_SpectatorExit.sqf),
   no respawn/JIP/enrollment edits.

   v8 SINGLE-WRITER LAW (the fix for today's three live stomp bugs, all two-writer
   conflicts): Client_SpectatorAimFrame.sqf (the mission's one onEachFrame slot) is
   the ONLY writer of camSetPos/camSetTarget/camSetFov/camCommit in EVERY mode.
   The scheduled loop below NEVER touches the camera or the pos/yaw/pitch globals -
   it owns the parked body, the death watchdog, mode-state transitions and the HUD
   text. The 1s director poll (Client_SpectatorDirector.sqf) owns scoring and the
   SHOT SNAPSHOT (WFBE_C_VAR_SpectShot) only. The mouse handler owns yaw/pitch
   (event-driven). One writer per piece of state, everywhere.

   Controls: mouse look, wheel zoom, WASD fly, Space/Ctrl vertical, Shift boost,
   Alt crawl, N/B target, F follow, V eyes, TAB class pin (pauses auto), G director
   auto, O orbit reveals, [ ] legacy dwell, H HUD, M map, J streamer menu,
   PgUp/PgDn sensitivity, Backspace exit.

   A2-OA-1.64 safe commands only; no disableSerialization anywhere in the spectator
   stack (this script suspends - the combination is death, live-proven m0730f). */
Private ["_myUID","_pos0","_yaw0"];

if (missionNamespace getVariable ["WFBE_C_VAR_SpectatorActive", false]) exitWith {}; //--- already active; ignore a double-click race.
if !(alive player) exitWith {};
if !((missionNamespace getVariable ["WFBE_C_SPECTATOR", 0]) > 0) exitWith {};

_myUID = getPlayerUID player;
if !(_myUID in (missionNamespace getVariable ["WFBE_C_SPECTATOR_UIDS", []])) exitWith {}; //--- belt-and-braces re-check; the addAction condition already gates this.

WFBE_C_VAR_SpectatorActive = true;
WFBE_C_VAR_SpectatorLastInput = time; //--- HUD fade clock; keybinds show on entry.
WFBE_C_VAR_SpectatorBody = player; //--- pin the exact body this session belongs to.
WFBE_C_VAR_SpectatorMode = "free";
WFBE_C_VAR_SpectatorTarget = objNull;
WFBE_C_VAR_SpectatorDirectorClass = "PLAYER";
WFBE_C_VAR_SpectatorDirectorPinned = false;
WFBE_C_VAR_SpectatorDirectorAuto = false;
WFBE_C_VAR_SpectatorOrbit = true; //--- v8: ORBIT REVEALS preference (static-first shot language).
WFBE_C_VAR_SpectatorDirectorTargetLabel = "-";
WFBE_C_VAR_SpectatorDirectorShotType = "WIDE";
WFBE_C_VAR_SpectatorDirectorDwell = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_DWELL", 20];
WFBE_C_VAR_DirectorLastTownPoll = 0;
WFBE_C_VAR_DirectorTownData = [];
WFBE_C_VAR_DirectorTownHot = [];
WFBE_C_VAR_DirectorCutReason = "";
WFBE_C_VAR_SpectatorLastManualZoom = 0;
WFBE_C_VAR_SpectatorHideHint = false;
WFBE_C_VAR_SpectatorHudMode = 2; //--- 2=FULL, 1=MINIMAL, 0=OFF; only read when the broadcast flag is armed.
WFBE_C_VAR_SpectatorMouseBaseline = true; //--- first MouseMoving event only sets the baseline (recentre-bias fix)
WFBE_C_VAR_SpectatorVelEma = [0,0,0];
WFBE_C_VAR_SpectatorFreeVel = [0,0,0];
WFBE_C_VAR_SpectatorMouseSdx = 0;
WFBE_C_VAR_SpectatorMouseSdy = 0;
//--- v8 director/track state.
WFBE_C_VAR_SpectShot = [];
WFBE_C_VAR_SpectShotCutN = 0;
WFBE_C_VAR_SpectFrameCut = -1;
WFBE_C_VAR_SpectFramePrevMode = "-";
WFBE_C_VAR_SpectFollowSeeded = false;
WFBE_C_VAR_SpectFovWasDir = false;
WFBE_C_VAR_DirTracks = [];
WFBE_C_VAR_DirTrackNextId = 1;
WFBE_C_VAR_DirTownEv = [];
WFBE_C_VAR_DirEvSeq = -1;
WFBE_C_VAR_DirShownRing = [];
WFBE_C_VAR_DirTownCool = [];
WFBE_C_VAR_DirCurKey = "";
WFBE_C_VAR_DirCurKind = "";
WFBE_C_VAR_DirCurStart = -999;
WFBE_C_VAR_DirCurStampScore = 0;
WFBE_C_VAR_DirCurPushed = false;
WFBE_C_VAR_DirCurTown = objNull;
WFBE_C_VAR_DirIntensity = "QUIET";
WFBE_C_VAR_SpectHudLine1 = "";
WFBE_C_VAR_SpectHudLine2 = "";
WFBE_C_VAR_SpectHudCtxT = -99;

_pos0 = getPos player;
_yaw0 = getDir player;

diag_log Format ["SPECTATE|v8|enter|uid=%1|pos=%2", _myUID, _pos0];

//--- Park the body: invulnerable + non-hostile so it cannot be farmed or trip AI aggro while unattended.
player allowDamage false;
player setCaptive true;

//--- Camera + pose globals. The frame handler paints the first frame from these seeds -
//--- no camSet* here (single-writer law; cameraEffect is display plumbing, not a pose write).
WFBE_C_VAR_SpectatorFov = 0.8;
WFBE_C_VAR_SpectatorFovTarget = 0.8;
WFBE_C_VAR_SpectatorPos = [_pos0 select 0, _pos0 select 1, (_pos0 select 2) + 2];
WFBE_C_VAR_SpectatorYaw = _yaw0;
WFBE_C_VAR_SpectatorPitch = 0;
WFBE_C_VAR_SpectatorLastMouseX = 0.5;
WFBE_C_VAR_SpectatorLastMouseY = 0.5;
WFBE_C_VAR_SpectatorKeys = [false,false,false,false,false,false,false,false]; //--- W,S,A,D,Space,Ctrl,Shift,Alt
WFBE_C_VAR_SpectatorFreeLastT = diag_tickTime;
WFBE_C_VAR_SpectatorAimFrameTick = -99;
WFBE_C_VAR_SpectatorCam = "camera" camCreate [_pos0 select 0, _pos0 select 1, (_pos0 select 2) + 2];
WFBE_C_VAR_SpectatorCam cameraEffect ["Internal", "Back"];

if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_BROADCAST_HUD", 0]) > 0) then {
	systemChat "[WASP] Spectator v8: mouse look, wheel zoom, WASD fly, N/B target, F follow, V eyes, G director, J streamer menu, H HUD, M map, Backspace exit.";
} else {
	systemChat "[WASP] Spectator v8: mouse look, wheel zoom, WASD fly, N/B target, F follow, V eyes, G director, H hide UI, Backspace exit.";
};
if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR", 0]) > 0) then {
	systemChat "[WASP] Director v8 armed: G auto (towns + fights), TAB manual class, O orbit reveals.";
};

//--- Arms the next (+1) or previous (-1) watch target. In director mode this delegates to the
//--- class-pool cycler (which stamps a static POI framing and pauses auto); in free/follow it
//--- arms players + GUER squad leaders for F/V.
WFBE_CL_FNC_SpectatorCycleTarget = {
	Private ["_step","_list","_cur","_idx","_next","_i"];
	_step = _this;
	if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR", 0]) > 0 && {(missionNamespace getVariable ["WFBE_C_VAR_SpectatorMode", "free"]) == "director"}) exitWith {
		_step Call WFBE_CL_FNC_DirectorCycleTarget;
	};
	_list = [];
	{
		if (!isNil "_x") then {
			//--- HC bodies are isPlayer-true; never offer them as watch targets (owner 2026-07-30).
			if (alive _x && {isPlayer _x} && {(side _x) != civilian} && {!(_x == player)} && {!((name _x) in (missionNamespace getVariable ["WFBE_C_HC_NAMES", []]))}) then {_list = _list + [_x]}; //--- CIV humans = caster/HC bodies, never watchable (owner 2026-08-01)
			if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_TARGET_GUER", 1]) > 0) then {
				//--- ZG town population is resistance-side in civ models: require a weapon to be watchable.
				if (alive _x && {!(isPlayer _x)} && {(side _x) == resistance} && {_x == (leader (group _x))} && {(count (weapons _x)) > 0}) then {_list = _list + [_x]};
			};
		};
	} forEach allUnits;
	if (count _list == 0) exitWith {
		WFBE_C_VAR_SpectatorTarget = objNull;
		systemChat "[WASP] Spectator: nothing to watch (no other players, no live GUER squads).";
	};
	_cur = WFBE_C_VAR_SpectatorTarget;
	_idx = -1;
	_i = 0;
	{
		if (!isNil "_x") then {if (_x == _cur) then {_idx = _i}};
		_i = _i + 1;
	} forEach _list;
	if (_idx < 0) then {
		_next = _list select 0;
	} else {
		_next = _list select ((_idx + _step + (count _list)) % (count _list));
	};
	WFBE_C_VAR_SpectatorTarget = _next;
	if ((side _next) == resistance) then {
		systemChat Format ["[WASP] Spectator target: GUER squad (%1 alive) (F follow, V eyes)", ({alive _x} count (units (group _next)))];
	} else {
		systemChat Format ["[WASP] Spectator target: %1 (F follow, V eyes)", name _next];
	};
};

//--- Shared subject kinematics for the follow mode (consumed by the FRAME handler).
//--- _this = [target, dt]. Returns [subject, subjectPos, leadOffset, emaSpeed].
WFBE_CL_FNC_SpectatorKinematics = {
	Private ["_t","_dt","_subject","_pos","_vel","_a","_ema","_speed","_leadSec","_leadMax","_fullSpeed"];
	_t = _this select 0;
	_dt = _this select 1;
	_subject = vehicle _t;
	_pos = getPos _subject;
	_vel = velocity _subject;
	_a = ((missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_VEL_EMA_RATE", 8]) * _dt) min 1;
	_ema = missionNamespace getVariable ["WFBE_C_VAR_SpectatorVelEma", [0,0,0]];
	_ema = [
		(_ema select 0) + (((_vel select 0) - (_ema select 0)) * _a),
		(_ema select 1) + (((_vel select 1) - (_ema select 1)) * _a),
		(_ema select 2) + (((_vel select 2) - (_ema select 2)) * _a)
	];
	WFBE_C_VAR_SpectatorVelEma = _ema;
	_speed = sqrt (((_ema select 0) ^ 2) + ((_ema select 1) ^ 2) + ((_ema select 2) ^ 2));
	_leadMax = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_LEAD_MAX_SEC", 0.5];
	_fullSpeed = (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_LEAD_FULL_SPEED", 25]) max 1;
	_leadSec = _leadMax min (_leadMax * (_speed / _fullSpeed));
	[_subject, _pos, [(_ema select 0) * _leadSec, (_ema select 1) * _leadSec, (_ema select 2) * _leadSec], _speed]
};

/* STREAMING OVERLAY (deliverable 3): persistent lower-thirds strip for the stream.
   Line 1: current POI (town name / FIRE FIGHT near X), sides engaged, shot type + cut reason.
   Line 2: war context - town counts per side, match clock, auto state, contact intensity.
   Fade-managed chrome: the keybind wall fades after HUD_FADE_SEC idle, the status strip stays.
   This helper never suspends: display/control refs live only until the call returns, so the
   scheduled workers never serialize a Display and never need disableSerialization.
   Structured text: plain text + <t>/<br/> tags only - A2 has NO numeric entities. */
WFBE_CL_FNC_SpectatorBroadcastHudUpdate = {
	Private ["_display","_topBg","_topText","_keysBg","_keysText","_hudMode","_mode","_shot","_l1","_l2","_idle","_keysHtml","_tw","_te2","_tg","_sid","_h","_m","_ms","_reason","_orbActive","_tgt","_tgtTxt","_auto","_wid","_eid","_gid"];
	if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_BROADCAST_HUD", 0]) <= 0) exitWith {};
	_display = uiNamespace getVariable ["wfbe_spectator_broadcast_display", displayNull];
	if (isNull _display) exitWith {};
	_topBg = _display displayCtrl 124560;
	_topText = _display displayCtrl 124561;
	_keysBg = _display displayCtrl 124562;
	_keysText = _display displayCtrl 124563;
	_hudMode = missionNamespace getVariable ["WFBE_C_VAR_SpectatorHudMode", 2];
	if (_hudMode <= 0) exitWith {
		_topBg ctrlShow false;
		_topText ctrlShow false;
		_keysBg ctrlShow false;
		_keysText ctrlShow false;
	};
	//--- context strings rebuilt at 1Hz (town sweep + clock), rendered every pass.
	if ((time - (missionNamespace getVariable ["WFBE_C_VAR_SpectHudCtxT", -99])) >= 1) then {
		WFBE_C_VAR_SpectHudCtxT = time;
		_mode = missionNamespace getVariable ["WFBE_C_VAR_SpectatorMode", "free"];
		_shot = missionNamespace getVariable ["WFBE_C_VAR_SpectShot", []];
		_l1 = "FREE CAM";
		if (_mode == "follow" || {_mode == "eyes"}) then {
			_tgt = missionNamespace getVariable ["WFBE_C_VAR_SpectatorTarget", objNull];
			_tgtTxt = "-";
			if (!isNull _tgt && {alive _tgt}) then {_tgtTxt = name _tgt};
			_l1 = Format ["%1  -  %2", toUpper _mode, _tgtTxt];
		};
		if (_mode == "director" && {(count _shot) >= 16}) then {
			_reason = _shot select 14;
			_orbActive = false;
			if ((_shot select 8) != 0 && {time >= (_shot select 9)} && {((time - (_shot select 9)) * (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_ORBIT_REVEAL_RATE", 6])) < (_shot select 10)}) then {_orbActive = true};
			if (_orbActive) then {_reason = "REVEAL"};
			_l1 = Format ["%1  -  %2", _shot select 13, _shot select 12];
			if ((_shot select 15) != "") then {_l1 = _l1 + Format ["  -  %1", _shot select 15]};
			_l1 = _l1 + Format ["  -  %1", _reason];
		};
		_tw = 0;
		_te2 = 0;
		_tg = 0;
		_wid = missionNamespace getVariable ["WFBE_C_WEST_ID", 0];
		_eid = missionNamespace getVariable ["WFBE_C_EAST_ID", 1];
		_gid = missionNamespace getVariable ["WFBE_C_GUER_ID", 2];
		{
			if (!isNull _x) then {
				_sid = _x getVariable ["sideID", -1];
				if (_sid == _wid) then {_tw = _tw + 1};
				if (_sid == _eid) then {_te2 = _te2 + 1};
				if (_sid == _gid) then {_tg = _tg + 1};
			};
		} forEach towns;
		_h = floor (time / 3600);
		_m = floor ((time % 3600) / 60);
		_ms = str _m;
		if (_m < 10) then {_ms = "0" + _ms};
		_auto = "OFF";
		if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR", 0]) > 0 && {missionNamespace getVariable ["WFBE_C_VAR_SpectatorDirectorAuto", false]}) then {_auto = "ON"};
		_l2 = Format ["TOWNS  W %1 - E %2 - G %3     T+%4:%5     AUTO %6     %7", _tw, _te2, _tg, _h, _ms, _auto, missionNamespace getVariable ["WFBE_C_VAR_DirIntensity", "QUIET"]];
		WFBE_C_VAR_SpectHudLine1 = _l1;
		WFBE_C_VAR_SpectHudLine2 = _l2;
	};
	_topBg ctrlShow true;
	_topText ctrlShow true;
	_topText ctrlSetStructuredText (parseText (Format [
		"<t align='left' size='0.9' color='#F2F7FA' shadow='2'>%1</t><br/><t align='left' size='0.72' color='#9FC4D8' shadow='2'>%2</t>",
		missionNamespace getVariable ["WFBE_C_VAR_SpectHudLine1", ""],
		missionNamespace getVariable ["WFBE_C_VAR_SpectHudLine2", ""]
	]));
	_idle = time - (missionNamespace getVariable ["WFBE_C_VAR_SpectatorLastInput", 0]);
	if (_hudMode > 1 && {_idle < (missionNamespace getVariable ["WFBE_C_SPECTATOR_HUD_FADE_SEC", 6])}) then {
		_keysHtml = "<t align='left' size='0.95' color='#FFFFFF' shadow='2'>G DIRECTOR AUTO  |  TAB CLASS  |  O ORBIT REVEALS  |  J STREAMER MENU  |  M MAP</t><br/><t align='left' size='0.88' color='#D8F3FF' shadow='2'>N/B TARGET  |  F FOLLOW  |  V EYES  |  WASD MOVE  |  H HUD  |  BACKSPACE EXIT</t>";
		_keysBg ctrlShow true;
		_keysText ctrlShow true;
		_keysText ctrlSetStructuredText (parseText _keysHtml);
	} else {
		_keysBg ctrlShow false;
		_keysText ctrlShow false;
	};
};

//--- Map follow/teleport helpers are also non-suspending.
WFBE_CL_FNC_SpectatorMapFollow = {
	Private ["_display","_map","_pos"];
	if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_BROADCAST_HUD", 0]) <= 0) exitWith {};
	_display = uiNamespace getVariable ["wfbe_spectator_map_display", displayNull];
	if (isNull _display) exitWith {};
	_map = _display displayCtrl 124570;
	_pos = missionNamespace getVariable ["WFBE_C_VAR_SpectatorPos", [0,0,0]];
	_map ctrlMapAnimAdd [0.5, 0.03, _pos];
	ctrlMapAnimCommit _map;
};

WFBE_CL_FNC_SpectatorMapClick = {
	Private ["_map","_x","_y","_pos","_camPos"];
	if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_BROADCAST_HUD", 0]) <= 0) exitWith {};
	_map = _this select 0;
	_x = _this select 1;
	_y = _this select 2;
	_pos = _map ctrlMapScreenToWorld [_x, _y];
	if (isNil "_pos" || {typeName _pos != "ARRAY"} || {count _pos < 2}) exitWith {};
	_camPos = missionNamespace getVariable ["WFBE_C_VAR_SpectatorPos", [0,0,0]];
	_camPos = [_pos select 0, _pos select 1, _camPos select 2];
	//--- v8 single-writer law: teleport = seed the free-cam globals, the frame handler paints it.
	//--- PrevMode is pre-set to free so the frame handler's mode-handoff cannot overwrite the
	//--- teleported position with the old camera pose.
	WFBE_C_VAR_SpectatorPos = _camPos;
	WFBE_C_VAR_SpectatorFreeVel = [0,0,0];
	WFBE_C_VAR_SpectFramePrevMode = "free";
	WFBE_C_VAR_SpectatorMode = "free";
	WFBE_C_VAR_SpectatorDirectorAuto = false;
	WFBE_C_VAR_SpectatorTarget = objNull;
	diag_log Format ["SPECTATE|broadcast-map|teleport|x=%1|y=%2", round (_pos select 0), round (_pos select 1)];
};

WFBE_CL_FNC_SpectatorKeyDown = {
	Private ["_dik","_handled","_cls","_d","_step"];
	_dik = _this select 1;
	_handled = true;
	switch (_dik) do {
		case 17: {WFBE_C_VAR_SpectatorKeys set [0, true]}; //--- W
		case 31: {WFBE_C_VAR_SpectatorKeys set [1, true]}; //--- S
		case 30: {WFBE_C_VAR_SpectatorKeys set [2, true]}; //--- A
		case 32: {WFBE_C_VAR_SpectatorKeys set [3, true]}; //--- D
		case 57: {WFBE_C_VAR_SpectatorKeys set [4, true]}; //--- Space
		case 29: {WFBE_C_VAR_SpectatorKeys set [5, true]}; //--- LCtrl
		case 157: {WFBE_C_VAR_SpectatorKeys set [5, true]}; //--- RCtrl
		case 42: {WFBE_C_VAR_SpectatorKeys set [6, true]}; //--- LShift
		case 54: {WFBE_C_VAR_SpectatorKeys set [6, true]}; //--- RShift
		case 56: {WFBE_C_VAR_SpectatorKeys set [7, true]}; //--- LAlt
		case 49: {1 Call WFBE_CL_FNC_SpectatorCycleTarget}; //--- N: arm next target
		case 48: {-1 Call WFBE_CL_FNC_SpectatorCycleTarget}; //--- B: arm previous target
		case 15: { //--- TAB: pin a manual class for N/B browsing; pauses auto (G resumes).
			if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR", 0]) > 0) then {
				_cls = missionNamespace getVariable ["WFBE_C_VAR_SpectatorDirectorClass", "PLAYER"];
				if (_cls == "PLAYER") then {_cls = "TEAM"} else {
					if (_cls == "TEAM") then {_cls = "TOWN"} else {
						if (_cls == "TOWN") then {_cls = "HQ"} else {_cls = "PLAYER"};
					};
				};
				WFBE_C_VAR_SpectatorDirectorClass = _cls;
				WFBE_C_VAR_SpectatorDirectorPinned = true;
				if (missionNamespace getVariable ["WFBE_C_VAR_SpectatorDirectorAuto", false]) then {
					WFBE_C_VAR_SpectatorDirectorAuto = false;
					systemChat "[WASP] Director auto paused for manual browsing (G resumes).";
				};
				WFBE_C_VAR_SpectatorTarget = objNull;
				diag_log Format ["SPECTATE|v8|class-switch|class=%1", _cls];
				systemChat Format ["[WASP] Director class: %1 (N/B cycle)", _cls];
			} else {_handled = false};
		};
		case 34: { //--- G: toggle the v8 auto director (towns + fight tracks)
			if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR", 0]) > 0) then {
				if ((missionNamespace getVariable ["WFBE_C_VAR_SpectatorMode", "free"]) == "director" && {missionNamespace getVariable ["WFBE_C_VAR_SpectatorDirectorAuto", false]}) then {
					WFBE_C_VAR_SpectatorMode = "free";
					WFBE_C_VAR_SpectatorDirectorAuto = false;
					diag_log "SPECTATE|v8|mode-off|reason=key";
					systemChat "[WASP] Director mode off - free camera.";
				} else {
					WFBE_C_VAR_SpectatorMode = "director";
					WFBE_C_VAR_SpectatorDirectorPinned = false;
					WFBE_C_VAR_SpectatorDirectorAuto = true;
					WFBE_C_VAR_SpectatorTarget = objNull;
					WFBE_C_VAR_DirCurKey = ""; //--- force a fresh pick on the next 1s poll.
					WFBE_C_VAR_DirCurKind = "";
					diag_log "SPECTATE|v8|mode-on|auto=1";
					systemChat "[WASP] Director v8 auto ON - towns + fight tracks.";
				};
			} else {_handled = false};
		};
		case 24: { //--- O: orbit reveals on/off (static-first shot language, owner ruling 14:14)
			if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR", 0]) > 0) then {
				WFBE_C_VAR_SpectatorOrbit = !(missionNamespace getVariable ["WFBE_C_VAR_SpectatorOrbit", true]);
				systemChat Format ["[WASP] Orbit reveals: %1", if (missionNamespace getVariable ["WFBE_C_VAR_SpectatorOrbit", true]) then {"ON"} else {"OFF (all static)"}];
			} else {_handled = false};
		};
		case 26: { //--- [: legacy dwell trim (v8 auto paces itself; kept for the streamer menu readout)
			if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR", 0]) > 0) then {
				_step = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_DWELL_STEP", 5];
				_d = ((WFBE_C_VAR_SpectatorDirectorDwell - _step) max (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_DWELL_MIN", 5]));
				WFBE_C_VAR_SpectatorDirectorDwell = _d;
			} else {_handled = false};
		};
		case 27: { //--- ]: legacy dwell trim
			if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR", 0]) > 0) then {
				_step = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_DWELL_STEP", 5];
				_d = ((WFBE_C_VAR_SpectatorDirectorDwell + _step) min (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_DWELL_MAX", 120]));
				WFBE_C_VAR_SpectatorDirectorDwell = _d;
			} else {_handled = false};
		};
		case 33: { //--- F: toggle follow-cam on the armed target
			if ((missionNamespace getVariable ["WFBE_C_VAR_SpectatorMode", "free"]) == "follow") then {
				WFBE_C_VAR_SpectatorMode = "free";
				systemChat "[WASP] Free camera.";
			} else {
				if (!isNull WFBE_C_VAR_SpectatorTarget && {alive WFBE_C_VAR_SpectatorTarget}) then {
					if ((missionNamespace getVariable ["WFBE_C_VAR_SpectatorMode", "free"]) == "director") then {
						WFBE_C_VAR_SpectatorDirectorAuto = false;
						diag_log "SPECTATE|v8|mode-off|reason=follow";
					};
					WFBE_C_VAR_SpectatorMode = "follow";
					systemChat Format ["[WASP] Follow-cam: %1 (WASD to detach)", name WFBE_C_VAR_SpectatorTarget];
				} else {
					systemChat "[WASP] No target - press N/B to arm a target first.";
				};
			};
		};
		case 47: { //--- V: toggle through-their-eyes POV on the armed target (manual only)
			if ((missionNamespace getVariable ["WFBE_C_VAR_SpectatorMode", "free"]) == "eyes") then {
				WFBE_C_VAR_SpectatorMode = "free";
				systemChat "[WASP] Free camera.";
			} else {
				if (!isNull WFBE_C_VAR_SpectatorTarget && {alive WFBE_C_VAR_SpectatorTarget}) then {
					if ((missionNamespace getVariable ["WFBE_C_VAR_SpectatorMode", "free"]) == "director") then {
						WFBE_C_VAR_SpectatorDirectorAuto = false;
						diag_log "SPECTATE|v8|mode-off|reason=eyes";
					};
					WFBE_C_VAR_SpectatorMode = "eyes";
					systemChat Format ["[WASP] POV: %1 (WASD to detach)", name WFBE_C_VAR_SpectatorTarget];
				} else {
					systemChat "[WASP] No target - press N/B to arm a target first.";
				};
			};
		};
		case 201: { //--- PgUp: raise mouse sensitivity
			private "_s";
			_s = ((missionNamespace getVariable ["WFBE_C_SPECTATOR_SENS", 25]) + 10) min 400;
			missionNamespace setVariable ["WFBE_C_SPECTATOR_SENS", _s];
			true
		};
		case 209: { //--- PgDn: lower mouse sensitivity
			private "_s";
			_s = ((missionNamespace getVariable ["WFBE_C_SPECTATOR_SENS", 25]) - 10) max 10;
			missionNamespace setVariable ["WFBE_C_SPECTATOR_SENS", _s];
			true
		};
		case 35: { //--- H: FULL -> MINIMAL -> OFF when broadcast HUD is armed; legacy hide/show otherwise.
			if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_BROADCAST_HUD", 0]) > 0) then {
				WFBE_C_VAR_SpectatorHudMode = ((missionNamespace getVariable ["WFBE_C_VAR_SpectatorHudMode", 2]) + 1) % 3;
				[] Call WFBE_CL_FNC_SpectatorBroadcastHudUpdate;
			} else {
				WFBE_C_VAR_SpectatorHideHint = !(missionNamespace getVariable ["WFBE_C_VAR_SpectatorHideHint", false]);
				if (WFBE_C_VAR_SpectatorHideHint) then {12455 cutText ["", "PLAIN", 0]}; WFBE_C_VAR_SpectatorCardLast = ""; //--- reset the card cache either way so the next draw re-cuts
			};
		};
		case 36: { //--- J: open/close the streamer settings menu
			if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_STREAMER_MENU", 0]) > 0) then {
				if (dialog) then {closeDialog 0} else {
					diag_log Format ["SPECTATE|v8|streamer-menu|createDialog=%1", createDialog "WFBE_StreamerMenu"];
				};
			} else {
				_handled = false;
			};
		};
		case 50: { //--- M: open/close spectator map dialog
			if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_BROADCAST_HUD", 0]) > 0) then {
				if (dialog) then {closeDialog 0} else {createDialog "WFBE_SpectatorMapDialog"};
			} else {
				_handled = false;
			};
		};
		case 14: {[] Call WFBE_CL_FNC_SpectatorExit}; //--- Backspace: quick exit
		default {_handled = false}; //--- unhandled keys (Esc, chat, etc.) fall through to the game.
	};
	if (_handled) then {WFBE_C_VAR_SpectatorLastInput = time}; //--- fade-timer reference for operator chrome.
	_handled //--- consume handled keys so the parked body never acts on camera input.
};

WFBE_CL_FNC_SpectatorKeyUp = {
	Private ["_dik"];
	_dik = _this select 1;
	switch (_dik) do {
		case 17: {WFBE_C_VAR_SpectatorKeys set [0, false]};
		case 31: {WFBE_C_VAR_SpectatorKeys set [1, false]};
		case 30: {WFBE_C_VAR_SpectatorKeys set [2, false]};
		case 32: {WFBE_C_VAR_SpectatorKeys set [3, false]};
		case 57: {WFBE_C_VAR_SpectatorKeys set [4, false]};
		case 29: {WFBE_C_VAR_SpectatorKeys set [5, false]};
		case 157: {WFBE_C_VAR_SpectatorKeys set [5, false]};
		case 42: {WFBE_C_VAR_SpectatorKeys set [6, false]};
		case 54: {WFBE_C_VAR_SpectatorKeys set [6, false]};
		case 56: {WFBE_C_VAR_SpectatorKeys set [7, false]};
	};
	false
};

//--- Mouse look, edge-recentre model (v4.2, live-proven). The mouse handler is the ONLY writer
//--- of yaw/pitch (event-driven); the frame handler integrates them.
WFBE_CL_FNC_SpectatorMouseMoving = {
	Private ["_x","_y","_dx","_dy","_sens","_cap","_sm","_sdx","_sdy","_fovFac"];
	_x = _this select 1;
	_y = _this select 2;
	if (WFBE_C_VAR_SpectatorMouseBaseline) then {
		//--- first event after entry or after an edge warp: anchor only.
		WFBE_C_VAR_SpectatorLastMouseX = _x;
		WFBE_C_VAR_SpectatorLastMouseY = _y;
		WFBE_C_VAR_SpectatorMouseBaseline = false;
	} else {
		_dx = _x - WFBE_C_VAR_SpectatorLastMouseX;
		_dy = _y - WFBE_C_VAR_SpectatorLastMouseY;
		//--- Clamp one event's travel: a stray jump (alt-tab, cursor warp) must not whip the view.
		_cap = 0.25;
		_dx = (_dx max -_cap) min _cap;
		_dy = (_dy max -_cap) min _cap;
		if (WFBE_C_VAR_SpectatorMode == "free") then {
			_sm = missionNamespace getVariable ["WFBE_C_SPECTATOR_MOUSE_SMOOTH", 0.55];
			_sdx = WFBE_C_VAR_SpectatorMouseSdx + ((_dx - WFBE_C_VAR_SpectatorMouseSdx) * _sm);
			_sdy = WFBE_C_VAR_SpectatorMouseSdy + ((_dy - WFBE_C_VAR_SpectatorMouseSdy) * _sm);
			WFBE_C_VAR_SpectatorMouseSdx = _sdx;
			WFBE_C_VAR_SpectatorMouseSdy = _sdy;
			_fovFac = ((WFBE_C_VAR_SpectatorFov / (missionNamespace getVariable ["WFBE_C_SPECTATOR_SENS_REF_FOV", 0.8])) max (missionNamespace getVariable ["WFBE_C_SPECTATOR_SENS_MIN_FACTOR", 0.05])) min 1.5;
			_sens = (missionNamespace getVariable ["WFBE_C_SPECTATOR_SENS", 45]) * _fovFac;
			WFBE_C_VAR_SpectatorYaw = WFBE_C_VAR_SpectatorYaw + _sdx * _sens;
			WFBE_C_VAR_SpectatorPitch = ((WFBE_C_VAR_SpectatorPitch - _sdy * _sens) max -89) min 89;
		};
		if (_x < 0.1 || {_x > 0.9} || {_y < 0.1} || {_y > 0.9}) then {
			setMousePosition [0.5, 0.5];
			WFBE_C_VAR_SpectatorMouseBaseline = true; //--- next event re-anchors at the warped position
		} else {
			WFBE_C_VAR_SpectatorLastMouseX = _x;
			WFBE_C_VAR_SpectatorLastMouseY = _y;
		};
	};
	false
};

//--- Wheel zoom: sets a TARGET fov; the frame handler eases toward it. Returns true so the
//--- wheel does not also cycle the parked body's weapon.
WFBE_CL_FNC_SpectatorWheel = {
	Private ["_z","_f"];
	_z = _this select 1;
	WFBE_C_VAR_SpectatorLastManualZoom = time;
	_f = missionNamespace getVariable ["WFBE_C_VAR_SpectatorFovTarget", WFBE_C_VAR_SpectatorFov];
	if (_z > 0) then {_f = _f * 0.85} else {_f = _f * 1.18};
	_f = (_f max (missionNamespace getVariable ["WFBE_C_SPECTATOR_FOV_MIN", 0.05])) min (missionNamespace getVariable ["WFBE_C_SPECTATOR_FOV_MAX", 1.2]);
	WFBE_C_VAR_SpectatorFovTarget = _f;
	true
};

//--- v8: arm the ONE camera writer AFTER every function it consumes is defined and every pose
//--- global is seeded. If onEachFrame is unavailable the statement fails and execution continues
//--- (A2 failed-statement semantics) - the camera then simply never paints, and Backspace/exit
//--- still work through the scheduled loop below.
WFBE_C_VAR_SpectatorFrameAimArmed = true;
onEachFrame {Call WFBE_CL_FNC_SpectatorAimFrame};

if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_BROADCAST_HUD", 0]) > 0) then {
	12456 cutRsc ["WFBE_SpectatorBroadcastHud", "PLAIN", 0];
	[] Call WFBE_CL_FNC_SpectatorBroadcastHudUpdate;
	[] spawn {
		while {WFBE_C_VAR_SpectatorActive} do {
			[] Call WFBE_CL_FNC_SpectatorMapFollow;
			sleep 1;
		};
	};
};

WFBE_C_VAR_SpectatorKeyDownIdx = (findDisplay 46) displayAddEventHandler ["KeyDown", "_this Call WFBE_CL_FNC_SpectatorKeyDown"];
WFBE_C_VAR_SpectatorKeyUpIdx = (findDisplay 46) displayAddEventHandler ["KeyUp", "_this Call WFBE_CL_FNC_SpectatorKeyUp"];
WFBE_C_VAR_SpectatorMouseMovingIdx = (findDisplay 46) displayAddEventHandler ["MouseMoving", "_this Call WFBE_CL_FNC_SpectatorMouseMoving"];
WFBE_C_VAR_SpectatorWheelIdx = (findDisplay 46) displayAddEventHandler ["MouseZChanged", "_this Call WFBE_CL_FNC_SpectatorWheel"];
diag_log Format ["SPECTATE|v8|handlers-attached|kd=%1|mm=%2", WFBE_C_VAR_SpectatorKeyDownIdx, WFBE_C_VAR_SpectatorMouseMovingIdx];

//--- HOUSEKEEPING LOOP (v8): the parked body, the death watchdog, key-driven mode transitions
//--- and the HUD text. NO camera writes, NO pos/yaw/pitch writes - single-writer law.
[] spawn {
	Private ["_body","_lockPos","_lockDir","_k","_mode","_t","_tgtTxt","_dirCard","_shotType"];
	_body = WFBE_C_VAR_SpectatorBody;
	_lockPos = getPos _body;
	_lockDir = getDir _body; //--- the body must not spin under the mouse.
	diag_log "SPECTATE|v8|loop-alive";
	//--- START THE DIRECTOR POLL THREAD BEFORE the housekeeping loop (live-burned ordering bug:
	//--- sequential SQF after a while loop runs only once the loop has already exited).
	if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR", 0]) > 0) then {
		Call WFBE_CL_FNC_DirectorLoopStart;
	};
	while {WFBE_C_VAR_SpectatorActive && {!(missionNamespace getVariable ["WFBE_gameover", false])}} do {
		sleep 0.1;
		//--- Safety: auto-exit if the parked body died while unattended.
		if (isNull _body || {!alive _body}) exitWith {[] Call WFBE_CL_FNC_SpectatorExit};
		_body setPos _lockPos;
		_body setDir _lockDir;
		_k = WFBE_C_VAR_SpectatorKeys;
		_mode = WFBE_C_VAR_SpectatorMode;
		_t = WFBE_C_VAR_SpectatorTarget;
		//--- Target safety: dead/null watch target auto-reverts to free - never a dangling camera.
		if ((_mode == "follow" || {_mode == "eyes"}) && {isNull _t || {!alive _t}}) then {
			WFBE_C_VAR_SpectatorMode = "free";
			_mode = "free";
			systemChat "[WASP] Spectator target lost - back to free camera.";
		};
		//--- Any movement-key input detaches from follow/eyes/director back to free.
		if (_mode != "free") then {
			if ((_k select 0) || {(_k select 1)} || {(_k select 2)} || {(_k select 3)} || {(_k select 4)} || {(_k select 5)}) then {
				if (_mode == "director") then {
					WFBE_C_VAR_SpectatorDirectorAuto = false;
					diag_log "SPECTATE|v8|mode-off|reason=manual";
				};
				WFBE_C_VAR_SpectatorMode = "free";
				_mode = "free";
			};
		};
		if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_BROADCAST_HUD", 0]) > 0) then {
			[] Call WFBE_CL_FNC_SpectatorBroadcastHudUpdate;
		} else {
			if !(WFBE_C_VAR_SpectatorHideHint) then {
				_tgtTxt = "-";
				if (!isNull _t && {alive _t}) then {_tgtTxt = name _t};
				_shotType = "-";
				if (_mode == "director") then {
					_shotType = missionNamespace getVariable ["WFBE_C_VAR_SpectatorDirectorShotType", "-"];
					_tgtTxt = missionNamespace getVariable ["WFBE_C_VAR_SpectatorDirectorTargetLabel", "-"];
				};
				//--- CUTTEXT, NOT HINT (live-proven 2026-07-30): hints do NOT render under a scripted
				//--- cameraEffect camera; title layers composite fine. Layer 12455; re-cut only when
				//--- the card STRING changed (flicker fix, live-proven).
				_dirCard = Format [
					"SPECTATOR [%1]  target %2\nFOV %3%4 | sens %5",
					toUpper _mode, _tgtTxt, round ((missionNamespace getVariable ["WFBE_C_VAR_SpectatorFov", 0.8]) * 100), "%",
					round (missionNamespace getVariable ["WFBE_C_SPECTATOR_SENS", 45])
				];
				_dirCard = _dirCard + "\nMOVE  mouse look | WASD | Space/Ctrl | Shift boost | Alt crawl | wheel zoom";
				_dirCard = _dirCard + "\nTARGETS  N/B cycle | F follow | V eyes";
				if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR", 0]) > 0) then {
					_dirCard = _dirCard + Format [
						"\nDIRECTOR  G auto %1 | TAB class | O reveals %2 | shot %3",
						if (missionNamespace getVariable ["WFBE_C_VAR_SpectatorDirectorAuto", false]) then {"ON"} else {"OFF"},
						if (missionNamespace getVariable ["WFBE_C_VAR_SpectatorOrbit", true]) then {"ON"} else {"OFF"},
						_shotType
					];
				};
				_dirCard = _dirCard + "\nSETUP  PgUp/PgDn sens | H hide card | Backspace exit";
				if (_dirCard != (missionNamespace getVariable ["WFBE_C_VAR_SpectatorCardLast", ""])) then {
					WFBE_C_VAR_SpectatorCardLast = _dirCard;
					12455 cutText [_dirCard, "PLAIN DOWN", 0];
				};
			};
		};
	};
	//--- Fail-clean: while can exit on WFBE_gameover (or Active cleared externally) without the
	//--- death-watchdog exitWith path, leaving cam + display EHs + parked-body invuln/captive latched.
	if (missionNamespace getVariable ["WFBE_C_VAR_SpectatorActive", false]) then {
		[] Call WFBE_CL_FNC_SpectatorExit;
	};
};
