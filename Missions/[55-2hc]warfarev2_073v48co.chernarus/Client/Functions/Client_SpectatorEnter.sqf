/* Client_SpectatorEnter.sqf
   fable/spectator-v1 -> v2 (owner request 2026-07-29: caster-grade watch tool)
   -------------------------------------------------------------------------
   Enters the UID-allowlisted spectator overlay for the CALLING client only.
   The UID allowlist gates ACTION VISIBILITY on this client only, under standard
   A2 locality; it is not server-enforced authentication or authorization.
   addAction target (see Client_SpectatorAttach.sqf); the addAction condition
   already restricts visibility to the allowlisted UID, an alive body, and past
   the deadspawn-transit invulnerability window (WFBE_Client_DeadspawnEscaped,
   Init_Client.sqf) - the re-checks below are belt-and-braces against a
   stale/duplicated action instance. v1 safety model is unchanged: body parked
   invulnerable + captive + position-locked, death watchdog auto-exits, exit is
   idempotent (see Client_SpectatorExit.sqf), no respawn/JIP/enrollment edits.

   v2 control scheme (design: docs/plans/2026-07-29-spectator-v2-design.md):
     mouse       free-look yaw/pitch (cursor re-centered per event)
     wheel       FOV zoom (WFBE_C_SPECTATOR_FOV_MIN..MAX)
     W/S         fly along view direction (incl. pitch), A/D horizontal strafe
     Space/Ctrl  vertical, Shift boost, Alt precision crawl
     N / B       arm next/previous target within the current director class
     F           toggle follow-cam on armed target (8m behind / 3m above)
     V           toggle through-their-eyes POV (eyePos + eyeDirection)
     H           hide/show the hint overlay (clean OBS capture)
     Backspace   quick exit (same path as the "Exit Spectator" addAction)

   Modes: WFBE_C_VAR_SpectatorMode = "free" (default) / "follow" / "eyes".
   Any movement-key input while in follow/eyes reverts to free at the current
   camera position; yaw/pitch are tracked every tick in ALL modes so the
   handoff back to free has no view snap. A dead/null target auto-reverts to
   free with a chat notice - never a dangling camera (same philosophy as v1's
   death watchdog). Movement keys are CONSUMED (handler returns true) so the
   parked body never walks under camera input; the v1 position re-lock stays
   as pure backup. DELIBERATELY still no disableUserInput (v1 rejection
   stands: unrecoverable-if-script-fails on a live community server).

   v4 streaming pass (design: docs/plans/2026-07-31-spectator-v4-streaming-design.md):
   per-frame camera tick (WFBE_C_SPECTATOR_TICK, was a 20Hz hard cap = judder),
   smoothed follow-cam, EMA subject velocity + speed-scaled lead, adaptive
   director pan (PAN_MIN/MAX/EASE, mid-shot cut 70deg), FOV snaps on target
   cuts, town cams gated to active fights + hot linger (Client_SpectatorDirector.sqf),
   WFBE_C_SPECTATOR_AUTOSTART hands-off entry (Client_SpectatorAttach.sqf).
   v4.1 free-cam pass (owner 2026-07-31): WASD acceleration/inertia (ACCEL/BRAKE),
   zoom-scaled mouse sensitivity + delta EMA (scoped-aim feel), eased wheel zoom
   (ZOOM_RATE toward a wheel target; director-auto FOV logic otherwise unchanged).

   A2-OA-1.64 safe commands used: camCreate / camSetPos / camSetTarget /
   camSetFov / camCommit / camCommitted / cameraEffect / camDestroy /
   allowDamage / setCaptive / getPlayerUID / getPos / getDir / setDir /
   setPos / sin / cos / sqrt / atan2 / min / max / mod(% operator) /
   displayAddEventHandler / setMousePosition (OA 1.60+) / eyePos /
   eyeDirection / modelToWorld / isPlayer / allUnits / name / toUpper /
   parseText / switch - no A3-only commands.
*/
//--- NO disableSerialization here: a script that calls it may never suspend, and this
//--- script suspends (it runs scheduled from addAction). On m0730f it silently died at
//--- the first waitUntil - handler attach and the movement loop never ran (live RPT:
//--- SPECTATE|v2|enter logged, nothing after; camera stayed target-locked to the entry
//--- focus point). The display is never stored in a local (handlers attach inline via
//--- (findDisplay 46)), so serialization never sees a Display ref in the first place.
Private ["_myUID","_pos0","_yaw0"];

if (missionNamespace getVariable ["WFBE_C_VAR_SpectatorActive", false]) exitWith {}; //--- already active; ignore a double-click race.
if !(alive player) exitWith {};
if !((missionNamespace getVariable ["WFBE_C_SPECTATOR", 0]) > 0) exitWith {};

_myUID = getPlayerUID player;
if !(_myUID in (missionNamespace getVariable ["WFBE_C_SPECTATOR_UIDS", []])) exitWith {}; //--- belt-and-braces re-check; the addAction condition already gates this.

WFBE_C_VAR_SpectatorActive = true;
WFBE_C_VAR_SpectatorLastInput = time; //--- v5 hotfix: seed the HUD fade clock so keybinds show on entry.
WFBE_C_VAR_SpectatorBody = player; //--- pin the exact body this session belongs to.
WFBE_C_VAR_SpectatorMode = "free";
WFBE_C_VAR_SpectatorTarget = objNull;
WFBE_C_VAR_SpectatorDirectorClass = "PLAYER";
WFBE_C_VAR_SpectatorDirectorPinned = false;
WFBE_C_VAR_SpectatorDirectorAuto = false;
WFBE_C_VAR_SpectatorOrbit = true;
WFBE_C_VAR_SpectatorOrbitAngle = 0;
WFBE_C_VAR_SpectatorDirectorDwell = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_DWELL", 20];
WFBE_C_VAR_SpectatorDirectorPosFn = WFBE_CL_FNC_DirectorPosObject;
WFBE_C_VAR_SpectatorDirectorTargetLabel = "-";
WFBE_C_VAR_DirectorRecent = [];
WFBE_C_VAR_DirectorLastSwitch = 0;
WFBE_C_VAR_DirectorLastTownPoll = 0;
WFBE_C_VAR_DirectorTownData = [];
WFBE_C_VAR_DirectorTownHot = []; //--- v4: per-town last-contest timestamps for the hot linger.
WFBE_C_VAR_DirectorAutoTime = 0;
WFBE_C_VAR_DirectorLastBaseCheck = 0;
WFBE_C_VAR_DirectorLastEstablish = -120;
WFBE_C_VAR_SpectatorDirectorShotType = "WIDE";
WFBE_C_VAR_SpectatorDirectorShotMinDwell = 1.5;
WFBE_C_VAR_SpectatorDirectorShotMaxDwell = 7;
WFBE_C_VAR_SpectatorDirectorTargetFov = 0.85;
WFBE_C_VAR_DirectorContactTarget = objNull;
WFBE_C_VAR_DirectorLastContactScan = 0;
WFBE_C_VAR_DirectorEngagementActive = false;
WFBE_C_VAR_DirectorAimHardCut = false;
WFBE_C_VAR_DirectorReturnClass = "";
WFBE_C_VAR_DirectorReturnPending = false;
WFBE_C_VAR_SpectatorLastManualZoom = 0;
WFBE_C_VAR_SpectatorHideHint = false;
WFBE_C_VAR_SpectatorHudMode = 2; //--- 2=FULL, 1=MINIMAL, 0=OFF; only read when the broadcast flag is armed.
WFBE_C_VAR_SpectatorMouseBaseline = true; //--- first MouseMoving event only sets the baseline (recentre-bias fix)
WFBE_C_VAR_SpectatorVelEma = [0,0,0]; //--- v4: EMA of the watched subject's velocity; raw networked velocity stair-steps and jittered the feed-forward.
WFBE_C_VAR_SpectatorFreeVel = [0,0,0]; //--- v4.1: free-cam velocity for acceleration/inertia.
WFBE_C_VAR_SpectatorMouseSdx = 0; //--- v4.1: smoothed mouse deltas (EMA), see SpectatorMouseMoving.
WFBE_C_VAR_SpectatorMouseSdy = 0;

_pos0 = getPos player;
_yaw0 = getDir player;

diag_log Format ["SPECTATE|v2|enter|uid=%1|pos=%2", _myUID, _pos0];

//--- Park the body: invulnerable + non-hostile so it cannot be farmed or trip AI aggro while unattended.
player allowDamage false;
player setCaptive true;

WFBE_C_VAR_SpectatorCam = "camera" camCreate _pos0;
WFBE_C_VAR_SpectatorFov = 0.8;
WFBE_C_VAR_SpectatorFovTarget = 0.8; //--- v4.1: wheel-zoom goal; the camera eases toward it (ZOOM_RATE).
WFBE_C_VAR_SpectatorCam camSetFov 0.8;
WFBE_C_VAR_SpectatorCam cameraEffect ["Internal", "Back"];
WFBE_C_VAR_SpectatorCam camSetPos [_pos0 select 0, _pos0 select 1, (_pos0 select 2) + 2];
WFBE_C_VAR_SpectatorCam camSetTarget [
	(_pos0 select 0) + 10 * (sin _yaw0),
	(_pos0 select 1) + 10 * (cos _yaw0),
	(_pos0 select 2) + 2
];
WFBE_C_VAR_SpectatorCam camCommit 0; //--- instant commit; no waitUntil (movement loop re-commits within 50ms anyway)
//--- v5 P1 (council C8): arm the unscheduled aim handler. If onEachFrame is unavailable on this
//--- build the statement fails and execution continues (A2 failed-statement semantics); the
//--- liveness stamp then stays stale and the movement loop keeps the v4 scheduled aim fallback.
WFBE_C_VAR_SpectatorAttachedTo = objNull;
WFBE_C_VAR_SpectatorAimFrameTick = -99;
WFBE_C_VAR_SpectatorAimLastT = diag_tickTime;
WFBE_C_VAR_SpectatorAimGoal = [];
WFBE_C_VAR_SpectatorAimCur = [];
WFBE_C_VAR_SpectatorFrameAimArmed = true;
onEachFrame {Call WFBE_CL_FNC_SpectatorAimFrame};

WFBE_C_VAR_SpectatorPos = [_pos0 select 0, _pos0 select 1, (_pos0 select 2) + 2];
WFBE_C_VAR_SpectatorYaw = _yaw0;
WFBE_C_VAR_SpectatorPitch = 0;
WFBE_C_VAR_SpectatorLastMouseX = 0.5;
WFBE_C_VAR_SpectatorLastMouseY = 0.5;

if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_BROADCAST_HUD", 0]) > 0) then {
	systemChat "[WASP] Spectator v2: mouse look, wheel zoom, WASD fly, Shift/Alt speed, N/B target, F follow, V eyes, H HUD mode, M map, Backspace exit.";
} else {
	systemChat "[WASP] Spectator v2: mouse look, wheel zoom, WASD fly, Shift/Alt speed, N/B target, F follow, V eyes, H hide UI, Backspace exit.";
};
if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR", 0]) > 0) then {
	systemChat "[WASP] Spectator v3 director armed: TAB pins class, G pools action, O orbit, [ ] dwell.";
};

WFBE_C_VAR_SpectatorKeys = [false,false,false,false,false,false,false,false]; //--- W,S,A,D,Space,Ctrl,Shift,Alt

//--- Arms the next (+1) or previous (-1) alive player as the watch target. Skips self,
//--- dead and null units, wraps around the list. Does NOT change mode by itself - F/V engage.
WFBE_CL_FNC_SpectatorCycleTarget = {
	Private ["_step","_list","_cur","_idx","_next","_i"];
	_step = _this;
	if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR", 0]) > 0 && {WFBE_C_VAR_SpectatorDirectorClass != "PLAYER"}) exitWith {
		_step Call WFBE_CL_FNC_DirectorCycleTarget;
	};
	_list = [];
	{
		if (!isNil "_x") then {
			//--- HC bodies are isPlayer-true; never offer them as watch targets (owner 2026-07-30).
			if (alive _x && {isPlayer _x} && {(side _x) != civilian} && {!(_x == player)} && {!((name _x) in (missionNamespace getVariable ["WFBE_C_HC_NAMES", []]))}) then {_list = _list + [_x]}; //--- CIV humans = caster/HC bodies, never watchable (owner 2026-08-01)
			//--- v5 P3 (5b, owner 2026-08-01): GUER is AI-only, so the isPlayer test above excluded the
			//--- ENTIRE insurgency from the watch cycle. Add GUER GROUP LEADERS only - GUER volume is
			//--- deliberately uncapped, one entry per squad keeps the cycle usable.
			if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_TARGET_GUER", 1]) > 0) then {
				//--- owner live repro m0801h/ZG: town population spawns RESISTANCE-side in civilian models -
				//--- side-GUER in code, unarmed locals on screen. An unarmed "squad leader" is population,
				//--- not insurgency: require a weapon to be watchable.
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

//--- v4: shared subject kinematics for follow/director. _this = [target, dt].
//--- Returns [subject, subjectPos, leadOffset, emaSpeed]. Velocity runs through an EMA
//--- (VEL_EMA_RATE per-second blend) because remote-unit velocity arrives in network
//--- stair-steps; the lead scales with smoothed speed up to LEAD_MAX_SEC at
//--- LEAD_FULL_SPEED m/s, so walking infantry get ~no lead (was: flat 0.4s raw).
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

//--- Broadcast HUD renderer. This helper never suspends: display/control references exist
//--- only until the synchronous call returns, so the scheduled spectator workers never
//--- serialize a Display or Control and never need disableSerialization.
WFBE_CL_FNC_SpectatorBroadcastHudUpdate = {
	Private ["_display","_topBg","_topText","_keysBg","_keysText","_hudMode","_mode","_target","_targetText","_shot","_auto","_topHtml","_keysHtml"];
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
	_mode = missionNamespace getVariable ["WFBE_C_VAR_SpectatorMode", "free"];
	_target = missionNamespace getVariable ["WFBE_C_VAR_SpectatorTarget", objNull];
	_targetText = "-";
	if (!isNull _target && {alive _target}) then {_targetText = name _target};
	_shot = "FREE";
	if (_mode == "director") then {_shot = toUpper (missionNamespace getVariable ["WFBE_C_VAR_SpectatorDirectorShotType", "WIDE"])};
	_auto = "OFF";
	if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR", 0]) > 0 && {missionNamespace getVariable ["WFBE_C_VAR_SpectatorDirectorAuto", false]}) then {_auto = "ON"};
	//--- v5 P3b (spec 7a): on a single-PC stream the caster screen IS the stream, so operator
	//--- chrome is split by LIFETIME rather than hidden: one compact status line stays, the
	//--- keybind wall and shot list fade after WFBE_C_SPECTATOR_HUD_FADE_SEC of no input and
	//--- return on the next keypress. A caster who stops touching the controls is left with a
	//--- clean broadcast frame automatically.
	Private ["_idle","_reason","_shotList","_listHtml","_entryS"];
	_idle = time - (missionNamespace getVariable ["WFBE_C_VAR_SpectatorLastInput", 0]);
	_reason = missionNamespace getVariable ["WFBE_C_VAR_DirectorCutReason", ""];
	_topHtml = Format [
		"<t align='left' size='0.85' color='#D8F3FF' shadow='2'>%1 | %2 | AUTO %3%4</t>",
		_shot,
		_targetText,
		_auto,
		if (_reason != "") then {" | " + _reason} else {""}
	];
	_topBg ctrlShow true;
	_topText ctrlShow true;
	_topText ctrlSetStructuredText (parseText _topHtml);
	if (_hudMode > 1 && {_idle < (missionNamespace getVariable ["WFBE_C_SPECTATOR_HUD_FADE_SEC", 6])}) then {
		//--- shot list: the director's runners-up this poll, so the caster can see what is being
		//--- passed over instead of discovering it after the cut.
		_listHtml = "";
		_shotList = missionNamespace getVariable ["WFBE_C_VAR_DirectorShotList", []];
		{
			_entryS = _x;
			_listHtml = _listHtml + Format ["  %1 (%2/%3)", _entryS select 0, _entryS select 1, _entryS select 2];
		} forEach _shotList;
		if (_listHtml != "") then {_listHtml = "<br/><t align='left' size='0.82' color='#9FD8B0' shadow='2'>NEXT:" + _listHtml + "</t>"};
		_keysHtml = "<t align='left' size='0.95' color='#FFFFFF' shadow='2'>H HUD: FULL > MINIMAL > OFF  |  M MAP  |  WASD MOVE  |  SPACE/CTRL ALTITUDE</t><br/><t align='left' size='0.88' color='#D8F3FF' shadow='2'>N/B TARGET  |  F FOLLOW  |  V EYES  |  G DIRECTOR  |  BACKSPACE EXIT</t>" + _listHtml;
		_keysBg ctrlShow true;
		_keysText ctrlShow true;
		_keysText ctrlSetStructuredText (parseText _keysHtml);
	} else {
		_keysBg ctrlShow false;
		_keysText ctrlShow false;
	};
};

//--- Map follow/camera teleport helpers are also non-suspending. The one-second worker
//--- calls them and releases all display/control references before its next sleep.
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
	Private ["_map","_x","_y","_pos","_camPos","_yaw","_pitch","_cy","_sy","_cp","_sp","_aim"];
	if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_BROADCAST_HUD", 0]) <= 0) exitWith {};
	_map = _this select 0;
	_x = _this select 1;
	_y = _this select 2;
	_pos = _map ctrlMapScreenToWorld [_x, _y];
	if (isNil "_pos" || {typeName _pos != "ARRAY"} || {count _pos < 2}) exitWith {};
	_camPos = missionNamespace getVariable ["WFBE_C_VAR_SpectatorPos", [0,0,0]];
	_camPos = [_pos select 0, _pos select 1, _camPos select 2];
	WFBE_C_VAR_SpectatorPos = _camPos;
	WFBE_C_VAR_SpectatorMode = "free";
	WFBE_C_VAR_SpectatorDirectorAuto = false;
	WFBE_C_VAR_SpectatorTarget = objNull;
	_yaw = missionNamespace getVariable ["WFBE_C_VAR_SpectatorYaw", 0];
	_pitch = missionNamespace getVariable ["WFBE_C_VAR_SpectatorPitch", 0];
	_cy = cos _yaw;
	_sy = sin _yaw;
	_cp = cos _pitch;
	_sp = sin _pitch;
	_aim = [
		(_camPos select 0) + (_sy * _cp * 100),
		(_camPos select 1) + (_cy * _cp * 100),
		(_camPos select 2) + (_sp * 100)
	];
	if (!isNull (missionNamespace getVariable ["WFBE_C_VAR_SpectatorCam", objNull])) then {
		WFBE_C_VAR_SpectatorCam camSetPos _camPos;
		WFBE_C_VAR_SpectatorCam camSetTarget _aim;
		WFBE_C_VAR_SpectatorCam camCommit 0;
	};
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
		case 49: {1 Call WFBE_CL_FNC_SpectatorCycleTarget}; //--- N: arm next player
		case 48: {-1 Call WFBE_CL_FNC_SpectatorCycleTarget}; //--- B: arm previous player
		case 15: { //--- TAB: cycle director target class
			if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR", 0]) > 0) then {
				_cls = WFBE_C_VAR_SpectatorDirectorClass;
				if (_cls == "PLAYER") then {_cls = "TEAM"} else {
					if (_cls == "TEAM") then {_cls = "TOWN"} else {
						if (_cls == "TOWN") then {_cls = "HQ"} else {_cls = "PLAYER"};
					};
				};
				WFBE_C_VAR_SpectatorDirectorClass = _cls;
				WFBE_C_VAR_SpectatorDirectorPinned = true;
				WFBE_C_VAR_DirectorReturnPending = false;
				WFBE_C_VAR_SpectatorTarget = objNull;
				WFBE_C_VAR_DirectorLastSwitch = 0;
				diag_log Format ["SPECTATE|v3|class-switch|class=%1", _cls];
				systemChat Format ["[WASP] Director class: %1 (N/B cycle)", _cls];
			} else {_handled = false};
		};
		case 34: { //--- G: toggle director mode and its 1-second auto-switch loop
			if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR", 0]) > 0) then {
				if (WFBE_C_VAR_SpectatorMode == "director") then {
					WFBE_C_VAR_SpectatorMode = "free";
					WFBE_C_VAR_SpectatorDirectorAuto = false;
					diag_log "SPECTATE|v3|mode-off|reason=key";
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
					diag_log Format ["SPECTATE|v3|mode-on|class=%1", WFBE_C_VAR_SpectatorDirectorClass];
					systemChat "[WASP] Director mode on - pooled action auto-switch enabled.";
				};
			} else {_handled = false};
		};
		case 24: { //--- O: toggle orbit sweep / static framing
			if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR", 0]) > 0) then {
				WFBE_C_VAR_SpectatorOrbit = !WFBE_C_VAR_SpectatorOrbit;
				systemChat Format ["[WASP] Director orbit: %1", if (WFBE_C_VAR_SpectatorOrbit) then {"ON"} else {"OFF (static)"}];
			} else {_handled = false};
		};
		case 26: { //--- [: reduce director dwell
			if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR", 0]) > 0) then {
				_step = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_DWELL_STEP", 5];
				_d = ((WFBE_C_VAR_SpectatorDirectorDwell - _step) max (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_DWELL_MIN", 5]));
				WFBE_C_VAR_SpectatorDirectorDwell = _d;
				//--- readout lives on the always-on cutText card (hints do not render under the spectator camera).
			} else {_handled = false};
		};
		case 27: { //--- ]: increase director dwell
			if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR", 0]) > 0) then {
				_step = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_DWELL_STEP", 5];
				_d = ((WFBE_C_VAR_SpectatorDirectorDwell + _step) min (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_DWELL_MAX", 120]));
				WFBE_C_VAR_SpectatorDirectorDwell = _d;
				//--- readout lives on the always-on cutText card (hints do not render under the spectator camera).
			} else {_handled = false};
		};
		case 33: { //--- F: toggle follow-cam on the armed target
			if (WFBE_C_VAR_SpectatorMode == "follow") then {
				WFBE_C_VAR_SpectatorMode = "free";
				systemChat "[WASP] Free camera.";
			} else {
				if (!isNull WFBE_C_VAR_SpectatorTarget && {alive WFBE_C_VAR_SpectatorTarget}) then {
					if (WFBE_C_VAR_SpectatorMode == "director") then {
						WFBE_C_VAR_SpectatorDirectorAuto = false;
						diag_log "SPECTATE|v3|mode-off|reason=follow";
					};
					WFBE_C_VAR_SpectatorMode = "follow";
					systemChat Format ["[WASP] Follow-cam: %1 (WASD to detach)", name WFBE_C_VAR_SpectatorTarget];
				} else {
					systemChat "[WASP] No target - press N/B to arm a player first.";
				};
			};
		};
		case 47: { //--- V: toggle through-their-eyes POV on the armed target
			if (WFBE_C_VAR_SpectatorMode == "eyes") then {
				WFBE_C_VAR_SpectatorMode = "free";
				systemChat "[WASP] Free camera.";
			} else {
				if (!isNull WFBE_C_VAR_SpectatorTarget && {alive WFBE_C_VAR_SpectatorTarget}) then {
					if (WFBE_C_VAR_SpectatorMode == "director") then {
						WFBE_C_VAR_SpectatorDirectorAuto = false;
						diag_log "SPECTATE|v3|mode-off|reason=eyes";
					};
					WFBE_C_VAR_SpectatorMode = "eyes";
					systemChat Format ["[WASP] POV: %1 (WASD to detach)", name WFBE_C_VAR_SpectatorTarget];
				} else {
					systemChat "[WASP] No target - press N/B to arm a player first.";
				};
			};
		};
		case 201: { //--- PgUp: raise mouse sensitivity (live tuning for streaming setups)
			private "_s";
			_s = ((missionNamespace getVariable ["WFBE_C_SPECTATOR_SENS", 25]) + 10) min 400;
			missionNamespace setVariable ["WFBE_C_SPECTATOR_SENS", _s];
			//--- readout lives on the always-on cutText card (hints do not render under the spectator camera).
			true
		};
		case 209: { //--- PgDn: lower mouse sensitivity
			private "_s";
			_s = ((missionNamespace getVariable ["WFBE_C_SPECTATOR_SENS", 25]) - 10) max 10;
			missionNamespace setVariable ["WFBE_C_SPECTATOR_SENS", _s];
			//--- readout lives on the always-on cutText card (hints do not render under the spectator camera).
			true
		};
		case 35: { //--- H: FULL -> MINIMAL -> OFF when broadcast HUD is armed; legacy hide/show otherwise.
			if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_BROADCAST_HUD", 0]) > 0) then {
				WFBE_C_VAR_SpectatorHudMode = (WFBE_C_VAR_SpectatorHudMode + 1) % 3;
				[] Call WFBE_CL_FNC_SpectatorBroadcastHudUpdate;
			} else {
				WFBE_C_VAR_SpectatorHideHint = !WFBE_C_VAR_SpectatorHideHint;
				if (WFBE_C_VAR_SpectatorHideHint) then {12455 cutText ["", "PLAIN", 0]}; WFBE_C_VAR_SpectatorCardLast = ""; //--- reset the card cache either way so the next draw re-cuts (flicker fix, merged)
			};
		};
		case 36: { //--- J: open/close the streamer settings menu (v5 P5); DIK 36 is not used by the spectator key set.
			if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_STREAMER_MENU", 0]) > 0) then {
				if (dialog) then {closeDialog 0} else {
					//--- h6 diag (owner report "no streamer menu"): prove the open path fires and whether
					//--- the engine actually created the dialog.
					diag_log Format ["SPECTATE|v5|streamer-menu|createDialog=%1", createDialog "WFBE_StreamerMenu"];
				};
			} else {
				_handled = false;
			};
		};
		case 50: { //--- M: open/close spectator map dialog; DIK 50 is not used by the spectator key set.
			if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_BROADCAST_HUD", 0]) > 0) then {
				if (dialog) then {closeDialog 0} else {createDialog "WFBE_SpectatorMapDialog"};
			} else {
				_handled = false;
			};
		};
		case 14: {[] Call WFBE_CL_FNC_SpectatorExit}; //--- Backspace: quick exit
		default {_handled = false}; //--- unhandled keys (Esc, chat, etc.) fall through to the game.
	};
	if (_handled) then {WFBE_C_VAR_SpectatorLastInput = time}; //--- v5 P3b: fade-timer reference for operator chrome (spec 7a).
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

//--- Mouse look, edge-recentre model: EVERY event steers at full rate (no alternating
//--- baseline half-rate, no per-event warp). The cursor is only warped home when it nears
//--- the UI edge; the event right after a warp only re-anchors, never steers, so the
//--- anchor is always a real reported position and no recentre bias can accumulate.
//--- Sensitivity is WFBE_C_SPECTATOR_SENS scaled by zoom (v4.1: SENS_REF_FOV anchor, scoped-aim feel).
WFBE_CL_FNC_SpectatorMouseMoving = {
	Private ["_x","_y","_dx","_dy","_sens","_cap","_sm","_sdx","_sdy","_fovFac"];
	_x = _this select 1;
	_y = _this select 2;
	if (WFBE_C_VAR_SpectatorMouseBaseline) then {
		//--- first event after entry or after an edge warp: anchor only.
		WFBE_C_VAR_SpectatorLastMouseX = _x;
		WFBE_C_VAR_SpectatorLastMouseY = _y;
		WFBE_C_VAR_SpectatorMouseBaseline = false;
		//--- v4.2 (owner jank report): do NOT zero the EMA here. Entry already initialises
		//--- Sdx/Sdy to 0; this branch also runs after every EDGE WARP, and zeroing there
		//--- hitched the camera mid-swipe each time the cursor crossed the warp margin.
		//--- Keeping the smoothed momentum across the warp is exactly what makes a long
		//--- continuous swipe feel continuous.
	} else {
		_dx = _x - WFBE_C_VAR_SpectatorLastMouseX;
		_dy = _y - WFBE_C_VAR_SpectatorLastMouseY;
		//--- Clamp one event's travel: a stray jump (alt-tab, cursor warp) must not whip the view.
		_cap = 0.25;
		_dx = (_dx max -_cap) min _cap;
		_dy = (_dy max -_cap) min _cap;
		if (WFBE_C_VAR_SpectatorMode == "free") then {
			//--- v4.1: light delta EMA kills per-event jitter without noticeable lag, and the
			//--- sensitivity scales with zoom (scoped-aim feel): at max zoom the screen shows
			//--- ~3deg, so a flat 25deg-per-swipe sens spun the view way past the subject.
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
		//--- v4.2: margins widened 0.2/0.8 -> 0.1/0.9 - the old band warped every ~0.6 screen
		//--- widths of travel, so long swipes stuttered; the wider band halves warp frequency
		//--- while still keeping the cursor safely away from the real screen edge.
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

//--- Wheel zoom: multiplicative FOV steps, clamped. Returns true so the wheel does not
//--- also cycle the parked body's weapon.
WFBE_CL_FNC_SpectatorWheel = {
	Private ["_z","_f"];
	_z = _this select 1;
	WFBE_C_VAR_SpectatorLastManualZoom = time;
	//--- v4.1: the wheel now sets a TARGET fov; the movement loop eases SpectatorFov
	//--- toward it at ZOOM_RATE/s (was: instant multiplicative jumps = steppy zoom on stream).
	_f = missionNamespace getVariable ["WFBE_C_VAR_SpectatorFovTarget", WFBE_C_VAR_SpectatorFov];
	if (_z > 0) then {_f = _f * 0.85} else {_f = _f * 1.18};
	_f = (_f max (missionNamespace getVariable ["WFBE_C_SPECTATOR_FOV_MIN", 0.05])) min (missionNamespace getVariable ["WFBE_C_SPECTATOR_FOV_MAX", 1.2]);
	WFBE_C_VAR_SpectatorFovTarget = _f;
	true
};

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
diag_log Format ["SPECTATE|v2|handlers-attached|kd=%1|mm=%2", WFBE_C_VAR_SpectatorKeyDownIdx, WFBE_C_VAR_SpectatorMouseMovingIdx];

[] spawn {
	Private ["_vd","_followVeh","_followPiloted","_mode","_t","_k","_p","_y","_pt","_cy","_sy","_cp","_sp","_fwd","_right","_spd","_dt","_last","_tx","_ty","_tz","_body","_lockPos","_lockDir","_hd","_tgtTxt","_e","_d","_center","_radius","_height","_rate","_angle","_dirCard","_wantPos","_wantAim","_smoothPos","_smoothAim","_smoothFactor","_smoothK","_lastDirectorTarget","_lastDirectorShotType","_shotChanged","_shotType","_engaged","_shotRadius","_shotHeight","_shotDir","_targetFov","_fovStep","_fovDelta","_manualZoomLock","_baseRemain","_subject","_leadSec","_subjectPos","_subjectVelocity","_leadOffset","_subjectSpeed","_standoffMult","_subjectFovMin","_lastDirectorStandoffTarget","_lastFollowTarget","_followSmoothPos","_followSmoothAim","_kin","_wantVel","_accel","_accelF","_vel","_fovRate","_fovWasDirector"];
	_body = WFBE_C_VAR_SpectatorBody;
	_lockPos = getPos _body;
	_lockDir = getDir _body; //--- direction lock added in v2: the body must not spin under the mouse.
	_last = time;
	_lastDirectorTarget = objNull;
	_lastDirectorShotType = "";
	_lastDirectorStandoffTarget = objNull;
	_lastFollowTarget = objNull;
	_fovWasDirector = false;
	_followSmoothPos = WFBE_C_VAR_SpectatorPos;
	_followSmoothAim = WFBE_C_VAR_SpectatorPos;
	diag_log "SPECTATE|v2|loop-alive";
	//--- START THE DIRECTOR POLL THREAD **BEFORE** the movement loop below, not after it.
	//--- It used to sit after that loop's closing brace, which is plain sequential SQF: the loop only
	//--- exits once WFBE_C_VAR_SpectatorActive has already gone false, and DirectorLoopStart guards its
	//--- own loop on that exact same variable - so the poll body ran ZERO times in a real session and
	//--- G reported "auto-switch on" while nothing ever auto-switched. DirectorLoopStart opens with its
	//--- own [] spawn {}, so this Call returns immediately and the movement loop still starts on the
	//--- next line; the two threads then run in parallel for the whole session, which is what
	//--- Init_Client.sqf's own registration comment already promised.
	if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR", 0]) > 0) then {
		Call WFBE_CL_FNC_DirectorLoopStart;
	};
	while {WFBE_C_VAR_SpectatorActive && {!(missionNamespace getVariable ["WFBE_gameover", false])}} do {
		sleep (missionNamespace getVariable ["WFBE_C_SPECTATOR_TICK", 0.01]); //--- v4: was sleep 0.05 = 20Hz hard cap - judder on a 60fps capture
		//--- Safety: auto-exit if the parked body died while unattended (allowDamage/setCaptive should
		//--- prevent this outright, but this loop is the last line of defence against a dangling camera).
		if (isNull _body || {!alive _body}) exitWith {[] Call WFBE_CL_FNC_SpectatorExit};
		_body setPos _lockPos;
		_body setDir _lockDir;
		_dt = time - _last;
		_last = time;
		_k = WFBE_C_VAR_SpectatorKeys;
		_mode = WFBE_C_VAR_SpectatorMode;
		_t = WFBE_C_VAR_SpectatorTarget;
		//--- Target safety: dead/null watch target auto-reverts to free - never a dangling camera.
		if ((_mode == "follow" || {_mode == "eyes"}) && {isNull _t || {!alive _t}}) then {
			WFBE_C_VAR_SpectatorMode = "free";
			_mode = "free";
			systemChat "[WASP] Spectator target lost - back to free camera.";
		};
		//--- Any movement-key input detaches from follow/eyes back to free at the current position.
		if (_mode != "free") then {
			if ((_k select 0) || {(_k select 1)} || {(_k select 2)} || {(_k select 3)} || {(_k select 4)} || {(_k select 5)}) then {
				if (_mode == "director") then {
					WFBE_C_VAR_SpectatorDirectorAuto = false;
					diag_log "SPECTATE|v3|mode-off|reason=manual";
				};
				WFBE_C_VAR_SpectatorMode = "free";
				_mode = "free";
			};
		};
		if (_mode != "free") then {WFBE_C_VAR_SpectatorFreeVel = [0,0,0]}; //--- v4.1: the fly-cam stays at rest until WASD actually drives it (no lurch on mode handoff).
		_spd = missionNamespace getVariable ["WFBE_C_SPECTATOR_SPEED", 15];
		if (_k select 6) then {_spd = _spd * (missionNamespace getVariable ["WFBE_C_SPECTATOR_BOOST", 4])};
		if (_k select 7) then {_spd = _spd * (missionNamespace getVariable ["WFBE_C_SPECTATOR_SLOW", 0.25])};
		//--- v5 P1 (council C8): any tick where we are NOT in follow but still attached means we just
		//--- left follow (WASD seize, F toggle-off, target lost, director cut). Detach and hand the
		//--- free-cam the camera's exact rendered pose - a zero-frame seize with no snap.
		if (_mode != "follow" && {!isNull WFBE_C_VAR_SpectatorAttachedTo}) then {
			detach WFBE_C_VAR_SpectatorCam;
			WFBE_C_VAR_SpectatorAttachedTo = objNull;
			WFBE_C_VAR_SpectatorPos = getPos WFBE_C_VAR_SpectatorCam;
			_vd = vectorDir WFBE_C_VAR_SpectatorCam;
			_hd = sqrt (((_vd select 0) ^ 2) + ((_vd select 1) ^ 2));
			WFBE_C_VAR_SpectatorYaw = (((_vd select 0) atan2 (_vd select 1)) + 360) % 360;
			WFBE_C_VAR_SpectatorPitch = ((((_vd select 2) atan2 (_hd max 0.01))) max -80) min 80;
			WFBE_C_VAR_SpectatorAimGoal = [];
		};
		_p = WFBE_C_VAR_SpectatorPos;
		_y = WFBE_C_VAR_SpectatorYaw;
		_pt = WFBE_C_VAR_SpectatorPitch;
		_subjectFovMin = 0;
		if !(isNull WFBE_C_VAR_SpectatorCam) then {
			switch (_mode) do {
				case "follow": {
					_kin = [_t, _dt] Call WFBE_CL_FNC_SpectatorKinematics;
					_subject = _kin select 0;
					_subjectPos = _kin select 1;
					_leadOffset = _kin select 2;
					_subjectSpeed = _kin select 3;
					_wantPos = _subject modelToWorld [0, -8, 3];
					_wantPos = [(_wantPos select 0) + (_leadOffset select 0), (_wantPos select 1) + (_leadOffset select 1), (_wantPos select 2) + (_leadOffset select 2)];
					_wantAim = [(_subjectPos select 0) + (_leadOffset select 0), (_subjectPos select 1) + (_leadOffset select 1), (_subjectPos select 2) + (_leadOffset select 2) + 1.5];
					//--- v4: exponential smoothing on BOTH camera pos and aim (was: raw per-tick snap = the yanky follow-cam). Snaps only on a target switch.
					if (_t != _lastFollowTarget) then {
						_lastFollowTarget = _t;
						_followSmoothPos = _wantPos;
						_followSmoothAim = _wantAim;
					} else {
						_smoothK = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_SMOOTHING", 5];
						if (_subjectSpeed > 8) then {_smoothK = _smoothK * (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_FAST_GAIN_MULT", 2.5])};
						_smoothFactor = ((_smoothK * _dt) min 1) max 0;
						_followSmoothPos = [
							(_followSmoothPos select 0) + (((_wantPos select 0) - (_followSmoothPos select 0)) * _smoothFactor),
							(_followSmoothPos select 1) + (((_wantPos select 1) - (_followSmoothPos select 1)) * _smoothFactor),
							(_followSmoothPos select 2) + (((_wantPos select 2) - (_followSmoothPos select 2)) * _smoothFactor)
						];
						_followSmoothAim = [
							(_followSmoothAim select 0) + (((_wantAim select 0) - (_followSmoothAim select 0)) * _smoothFactor),
							(_followSmoothAim select 1) + (((_wantAim select 1) - (_followSmoothAim select 1)) * _smoothFactor),
							(_followSmoothAim select 2) + (((_wantAim select 2) - (_followSmoothAim select 2)) * _smoothFactor)
						];
					};
					//--- v5 P1 (council C8, 4/4 APPROVE): position is ENGINE-driven via attachTo - immune to
					//--- SQF scheduler starvation, which no scripted per-tick camSetPos cadence can be. Aim is
					//--- eased per render frame by Client_SpectatorAimFrame.sqf (onEachFrame); if its liveness
					//--- stamp goes stale we fall back to the v4 scheduled aim below. Player-piloted subjects
					//--- keep the v4 kinematic follow (council-flagged attach quirk on player-driven vehicles).
					_followVeh = vehicle _subject;
					_followPiloted = isPlayer _followVeh || {!isNull (driver _followVeh) && {isPlayer (driver _followVeh)}};
					if (!_followPiloted) then {
						if (WFBE_C_VAR_SpectatorAttachedTo != _followVeh) then {
							if (!isNull WFBE_C_VAR_SpectatorAttachedTo) then {detach WFBE_C_VAR_SpectatorCam};
							WFBE_C_VAR_SpectatorCam attachTo [_followVeh, [0, -8, 3]];
							WFBE_C_VAR_SpectatorAttachedTo = _followVeh;
							WFBE_C_VAR_SpectatorAimCur = _wantAim; //--- hard cut on switch: no easing across a cut
							_followSmoothAim = _wantAim;
						};
						WFBE_C_VAR_SpectatorAimGoal = _wantAim;
						_p = getPos WFBE_C_VAR_SpectatorCam;
						if ((diag_tickTime - (missionNamespace getVariable ["WFBE_C_VAR_SpectatorAimFrameTick", -99])) > 1) then {
							//--- frame-aim dead or unavailable: v4 scheduled aim keeps the camera usable.
							WFBE_C_VAR_SpectatorCam camSetTarget _followSmoothAim;
							WFBE_C_VAR_SpectatorCam camCommit 0;
						};
					} else {
						if (!isNull WFBE_C_VAR_SpectatorAttachedTo) then {
							detach WFBE_C_VAR_SpectatorCam;
							WFBE_C_VAR_SpectatorAttachedTo = objNull;
						};
						WFBE_C_VAR_SpectatorCam camSetPos _followSmoothPos;
						WFBE_C_VAR_SpectatorCam camSetTarget _followSmoothAim;
						_p = _followSmoothPos;
					};
					_tx = _followSmoothAim select 0;
					_ty = _followSmoothAim select 1;
					_tz = _followSmoothAim select 2;
					_hd = sqrt (((_tx - (_p select 0)) ^ 2) + ((_ty - (_p select 1)) ^ 2));
					_y = (((_tx - (_p select 0)) atan2 (_ty - (_p select 1))) + 360) % 360;
					_pt = (((_tz - (_p select 2)) atan2 (_hd max 0.01)) max -80) min 80;
				};
				case "eyes": {
					_e = eyePos _t;
					_d = eyeDirection _t;
					_p = _e;
					_hd = sqrt (((_d select 0) ^ 2) + ((_d select 1) ^ 2));
					_y = (((_d select 0) atan2 (_d select 1)) + 360) % 360;
					_pt = (((_d select 2) atan2 (_hd max 0.01)) max -80) min 80;
					WFBE_C_VAR_SpectatorCam camSetPos _e;
					WFBE_C_VAR_SpectatorCam camSetTarget [(_e select 0) + (_d select 0) * 100, (_e select 1) + (_d select 1) * 100, (_e select 2) + (_d select 2) * 100];
				};
				case "director": {
					if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR", 0]) > 0 && {!isNull _t}) then {
						_center = _t call WFBE_C_VAR_SpectatorDirectorPosFn;
						//--- v7 POI director (owner ruling 2026-08-01): TOWN/HQ/FIGHT shots orbit the STATIC
						//--- POI point - no kinematics, no velocity lead, no per-frame subject tracking.
						if (WFBE_C_VAR_SpectatorDirectorClass in ["TOWN","HQ","FIGHT"]) then {
							_subject = vehicle _t;
							_subjectPos = _center;
							_leadOffset = [0,0,0];
							_subjectSpeed = 0;
						} else {
							_kin = [_t, _dt] Call WFBE_CL_FNC_SpectatorKinematics;
							_subject = _kin select 0;
							_subjectPos = _kin select 1;
							_leadOffset = _kin select 2;
							_subjectSpeed = _kin select 3;
							_center = [(_subjectPos select 0) + (_leadOffset select 0), (_subjectPos select 1) + (_leadOffset select 1), (_subjectPos select 2) + (_leadOffset select 2)];
						};
						_shotType = WFBE_C_VAR_SpectatorDirectorShotType;
						_wantAim = [_t, WFBE_C_VAR_SpectatorDirectorClass, _center] Call WFBE_CL_FNC_DirectorAimPoint;
						_engaged = WFBE_C_VAR_DirectorEngagementActive;
						//--- fix (v3.2 review): radius/height now derive from _shotType alone (was gated behind
						//--- _engaged, so an idle/non-engaged MEDIUM shot - the common case - fell through to the
						//--- legacy 40/25 ORBIT constants instead of its own 18/12 MEDIUM constants). Orbit sweep
						//--- now applies to any shot that is not the fixed engagement angle (v3.1 parity - was
						//--- narrowed to WIDE/BASE only, freezing the camera on every idle PLAYER/TEAM MEDIUM shot).
						_shotRadius = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_ORBIT_RADIUS", 40];
						_shotHeight = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_ORBIT_HEIGHT", 25];
						switch (_shotType) do {
							case "TIGHT": {
								_shotRadius = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_TIGHT_RADIUS", 8];
								_shotHeight = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_TIGHT_HEIGHT", 4];
							};
							case "MEDIUM": {
								_shotRadius = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_MEDIUM_RADIUS", 18];
								_shotHeight = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_MEDIUM_HEIGHT", 12];
							};
							case "WIDE": {
								_shotRadius = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_WIDE_RADIUS", 180];
								_shotHeight = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_WIDE_HEIGHT", 110];
							};
							case "BASE": {
								_shotRadius = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_WIDE_RADIUS", 180];
								_shotHeight = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_WIDE_HEIGHT", 110];
							};
						};
						//--- v7 POI director: hot cluster = TIGHT FOV band at MEDIUM standoff - zoomed-in
						//--- action from distance, never a close chase (owner ruling 2026-08-01).
						//--- m0801h9: WIDE fight shots (spread battle) keep the WIDE standoff from the
						//--- switch above so the whole engagement fits the frame.
						if (WFBE_C_VAR_SpectatorDirectorClass == "FIGHT" && {_shotType != "WIDE"}) then {
							_shotRadius = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_MEDIUM_RADIUS", 70];
							_shotHeight = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_MEDIUM_HEIGHT", 30];
						};
						_standoffMult = 1;
						_subjectFovMin = 0;
						//--- v7: POI shots frame a place, not the anchor body - never scale standoff by the
						//--- anchor's vehicle class.
						if (!(WFBE_C_VAR_SpectatorDirectorClass in ["TOWN","HQ","FIGHT"]) && {!(_subject isKindOf "Man")}) then {
							_standoffMult = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_VEH_STANDOFF_MULT", 2.5];
							_subjectFovMin = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_VEH_FOV_MIN", 0.55];
							if (_subject isKindOf "Air") then {
								_standoffMult = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_AIR_STANDOFF_MULT", 4.0];
								_subjectFovMin = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_AIR_FOV_MIN", 0.45];
							};
							_shotRadius = _shotRadius * _standoffMult;
							_shotHeight = _shotHeight * _standoffMult;
						};
						if (_t != _lastDirectorStandoffTarget) then {
							_lastDirectorStandoffTarget = _t;
							if (!(_subject isKindOf "Man")) then {diag_log Format ["SPECTATE|v3|veh-standoff|mult=%1", _standoffMult]};
						};
						//--- v5 P3 (owner 2026-08-01): the old engaged branch PINNED the camera static behind the
						//--- subject on TIGHT/MEDIUM - firing exactly when action peaked, and the source of the
						//--- "very close close-ups" complaint. Engaged subjects now orbit like any other; the
						//--- standoff retune (radius x~4, FOV /~3) keeps subject size on screen unchanged.
						//--- Static-behind survives only as the explicit manual orbit-off pose (O toggle).
						if (false) then {
							_shotDir = getDir _t;
							_angle = (_shotDir + 180) % 360;
						} else {
							if (WFBE_C_VAR_SpectatorOrbit) then {
								_rate = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_WIDE_ORBIT_DEG_PER_SEC", 4];
								if (_rate > (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_PAN_DEG_PER_SEC", 8])) then {
									_rate = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_PAN_DEG_PER_SEC", 8];
								};
								_angle = (WFBE_C_VAR_SpectatorOrbitAngle + (_rate * _dt)) % 360;
								WFBE_C_VAR_SpectatorOrbitAngle = _angle;
							} else {
								_angle = WFBE_C_VAR_SpectatorOrbitAngle;
							};
						};
						//--- v5 P3: flatten while TRACKING (orbit off) to see down the line of travel; keep the
						//--- taller angle while ORBITING. Height only - radius/apparent size unchanged.
						if (!WFBE_C_VAR_SpectatorOrbit) then {
							_shotHeight = _shotHeight * (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_TRACK_HEIGHT_MULT", 0.45]);
							if (_shotHeight < 8) then {_shotHeight = 8}; //--- v5 hotfix: floor vs terrain microrelief.
						};
						_wantPos = [(_center select 0) + (_shotRadius * sin _angle), (_center select 1) + (_shotRadius * cos _angle), (_center select 2) + _shotHeight];
						if (_t != _lastDirectorTarget) then {
							WFBE_C_VAR_DirectorAimHardCut = false;
							_smoothPos = _wantPos;
							_smoothAim = _wantAim;
							_lastDirectorTarget = _t;
							_lastDirectorShotType = _shotType;
							WFBE_C_VAR_SpectatorVelEma = velocity _subject; //--- v4: re-seed the EMA at the new subject; stale velocity must not bleed past the cut.
							//--- v4: a target cut snaps FOV with the frame (was: kept easing from the previous shot's FOV = "too slow zoomed in" after every switch).
							if ((time - WFBE_C_VAR_SpectatorLastManualZoom) >= (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_MANUAL_ZOOM_LOCK_SEC", 10])) then {
								WFBE_C_VAR_SpectatorFov = WFBE_C_VAR_SpectatorDirectorTargetFov;
								WFBE_C_VAR_SpectatorFovTarget = WFBE_C_VAR_SpectatorDirectorTargetFov; //--- v4.1: keep the wheel goal in agreement after a director cut.
							};
						} else {
							_shotChanged = _shotType != _lastDirectorShotType;
							_smoothK = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_SMOOTHING", 5];
							if (_subjectSpeed > 8) then {_smoothK = _smoothK * (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_FAST_GAIN_MULT", 2.5])};
							_smoothFactor = ((_smoothK * _dt) min 1) max 0;
							_smoothPos = [
								(_smoothPos select 0) + (((_wantPos select 0) - (_smoothPos select 0)) * _smoothFactor),
								(_smoothPos select 1) + (((_wantPos select 1) - (_smoothPos select 1)) * _smoothFactor),
								(_smoothPos select 2) + (((_wantPos select 2) - (_smoothPos select 2)) * _smoothFactor)
							];
							_smoothAim = [_smoothPos, _smoothAim, _wantAim, _dt, _shotChanged] Call WFBE_CL_FNC_DirectorAimStep;
							if (WFBE_C_VAR_DirectorAimHardCut) then {
								_smoothPos = _wantPos;
								_smoothAim = _wantAim;
							};
							_lastDirectorShotType = _shotType;
						};
						_p = _smoothPos;
						_tx = _smoothAim select 0;
						_ty = _smoothAim select 1;
						_tz = _smoothAim select 2;
						_hd = sqrt (((_tx - (_p select 0)) ^ 2) + ((_ty - (_p select 1)) ^ 2));
						_y = (((_tx - (_p select 0)) atan2 (_ty - (_p select 1))) + 360) % 360;
						_pt = (((_tz - (_p select 2)) atan2 (_hd max 0.01)) max -80) min 80;
						//--- v5 P3b: scheduled first-person window (every Nth cut, Man subjects only). Overrides
						//--- the composed shot for EYES_SEC, then falls back to the normal orbit with no cut -
						//--- _smoothPos/_smoothAim keep tracking underneath, so the return is continuous.
						if (time < (missionNamespace getVariable ["WFBE_C_VAR_DirectorEyesUntil", 0]) && {!isNull _t} && {alive _t} && {_t isKindOf "Man"}) then {
							_e = eyePos _t;
							_d = eyeDirection _t;
							WFBE_C_VAR_SpectatorCam camSetPos _e;
							WFBE_C_VAR_SpectatorCam camSetTarget [(_e select 0) + (_d select 0) * 100, (_e select 1) + (_d select 1) * 100, (_e select 2) + (_d select 2) * 100];
						} else {
							WFBE_C_VAR_SpectatorCam camSetPos _smoothPos;
							WFBE_C_VAR_SpectatorCam camSetTarget _smoothAim;
						};
					};
				};
				default {
					//--- v5 P4: frame handler owns the free-cam while its stamp is fresh; this scheduled
					//--- path is the graceful fallback only (stale >1s = onEachFrame lost).
					if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_FREECAM_FRAME", 1]) > 0 && {(diag_tickTime - (missionNamespace getVariable ["WFBE_C_VAR_SpectatorAimFrameTick", -99])) < 1}) exitWith {};
					_cy = cos _y; _sy = sin _y; _cp = cos _pt; _sp = sin _pt;
					_fwd = [_sy * _cp, _cy * _cp, _sp];
					_right = [_cy, -_sy, 0];
					//--- v4.1: acceleration/inertia - keys set a DESIRED velocity and the camera eases
					//--- toward it (was: instant full speed / instant stop = robotic motion on stream).
					_wantVel = [0,0,0];
					if (_k select 0) then {_wantVel = [(_wantVel select 0) + (_fwd select 0) * _spd, (_wantVel select 1) + (_fwd select 1) * _spd, (_wantVel select 2) + (_fwd select 2) * _spd]};
					if (_k select 1) then {_wantVel = [(_wantVel select 0) - (_fwd select 0) * _spd, (_wantVel select 1) - (_fwd select 1) * _spd, (_wantVel select 2) - (_fwd select 2) * _spd]};
					if (_k select 3) then {_wantVel = [(_wantVel select 0) + (_right select 0) * _spd, (_wantVel select 1) + (_right select 1) * _spd, _wantVel select 2]};
					if (_k select 2) then {_wantVel = [(_wantVel select 0) - (_right select 0) * _spd, (_wantVel select 1) - (_right select 1) * _spd, _wantVel select 2]};
					if (_k select 4) then {_wantVel set [2, (_wantVel select 2) + _spd]};
					if (_k select 5) then {_wantVel set [2, (_wantVel select 2) - _spd]};
					_accel = missionNamespace getVariable ["WFBE_C_SPECTATOR_ACCEL", 6];
					if ((_wantVel select 0) == 0 && {(_wantVel select 1) == 0} && {(_wantVel select 2) == 0}) then {_accel = missionNamespace getVariable ["WFBE_C_SPECTATOR_BRAKE", 9]};
					_accelF = ((_accel * _dt) min 1) max 0;
					_vel = WFBE_C_VAR_SpectatorFreeVel;
					_vel = [
						(_vel select 0) + (((_wantVel select 0) - (_vel select 0)) * _accelF),
						(_vel select 1) + (((_wantVel select 1) - (_vel select 1)) * _accelF),
						(_vel select 2) + (((_wantVel select 2) - (_vel select 2)) * _accelF)
					];
					WFBE_C_VAR_SpectatorFreeVel = _vel;
					_p = [(_p select 0) + (_vel select 0) * _dt, (_p select 1) + (_vel select 1) * _dt, (_p select 2) + (_vel select 2) * _dt];
					_tx = (_p select 0) + (_fwd select 0) * 100;
					_ty = (_p select 1) + (_fwd select 1) * 100;
					_tz = (_p select 2) + (_fwd select 2) * 100;
					WFBE_C_VAR_SpectatorCam camSetPos _p;
					WFBE_C_VAR_SpectatorCam camSetTarget [_tx, _ty, _tz];
				};
			};
			if (_subjectFovMin > 0) then {
				if (WFBE_C_VAR_SpectatorFov < _subjectFovMin) then {WFBE_C_VAR_SpectatorFov = _subjectFovMin};
				if (WFBE_C_VAR_SpectatorDirectorTargetFov < _subjectFovMin) then {WFBE_C_VAR_SpectatorDirectorTargetFov = _subjectFovMin};
				if (WFBE_C_VAR_SpectatorFovTarget < _subjectFovMin) then {WFBE_C_VAR_SpectatorFovTarget = _subjectFovMin}; //--- v4.1: keep the manual zoom goal above the subject floor too.
			};
			//--- v4.1 unified zoom goal: director-auto drives the shot FOV (unless the wheel
			//--- locked zoom recently); every other mode eases toward the wheel target.
			_targetFov = WFBE_C_VAR_SpectatorFovTarget;
			_fovRate = missionNamespace getVariable ["WFBE_C_SPECTATOR_ZOOM_RATE", 8];
			if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR", 0]) > 0 && {_mode == "director"} && {WFBE_C_VAR_SpectatorDirectorAuto} && {(time - WFBE_C_VAR_SpectatorLastManualZoom) >= (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_MANUAL_ZOOM_LOCK_SEC", 10])}) then {
				_targetFov = WFBE_C_VAR_SpectatorDirectorTargetFov;
				_fovRate = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_FOV_RATE", 0.35];
				_fovWasDirector = true;
			} else {
				//--- leaving director-driven zoom without a recent wheel touch: hand manual zoom
				//--- off from where the director left it, not from a stale wheel value.
				if (_fovWasDirector && {(time - WFBE_C_VAR_SpectatorLastManualZoom) >= (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_MANUAL_ZOOM_LOCK_SEC", 10])}) then {
					WFBE_C_VAR_SpectatorFovTarget = WFBE_C_VAR_SpectatorFov;
				};
				_fovWasDirector = false;
			};
			_fovStep = _fovRate * _dt;
			_fovDelta = _targetFov - WFBE_C_VAR_SpectatorFov;
			if (abs _fovDelta > _fovStep) then {
				if (_fovDelta > 0) then {WFBE_C_VAR_SpectatorFov = WFBE_C_VAR_SpectatorFov + _fovStep} else {WFBE_C_VAR_SpectatorFov = WFBE_C_VAR_SpectatorFov - _fovStep};
			} else {
				WFBE_C_VAR_SpectatorFov = _targetFov;
			};
			WFBE_C_VAR_SpectatorCam camSetFov WFBE_C_VAR_SpectatorFov;
			WFBE_C_VAR_SpectatorCam camCommit 0;
		};
		//--- v5 P4 HOTFIX (owner live repro m0801h: "impossible to manually control, pitches very
		//--- hard, no steering"): when the frame handler owns the free-cam, this writeback was
		//--- STOMPING its render-rate position with the loop's stale top-of-iteration _p snapshot
		//--- ~100x/s - two writers fighting = jitter-locked camera. The frame handler is the ONLY
		//--- position writer while alive; yaw/pitch stay loop-written (the mouse handler owns them
		//--- and _y/_pt are pass-through reads, not integrations).
		//--- v5 P4 HOTFIX 2 (owner: "mouse view still impossible"): yaw/pitch writeback was left
		//--- unconditional on the theory they are pass-through - WRONG: the mouse handler updates the
		//--- globals BETWEEN this loop's top-read and this bottom-write, so under scheduler load the
		//--- stale write-back ERASED most mouse input. Same two-writer stomp as position; same guard.
		if (!((_mode == "free") && {(missionNamespace getVariable ["WFBE_C_SPECTATOR_FREECAM_FRAME", 1]) > 0} && {(diag_tickTime - (missionNamespace getVariable ["WFBE_C_VAR_SpectatorAimFrameTick", -99])) < 1})) then {
			WFBE_C_VAR_SpectatorPos = _p;
			WFBE_C_VAR_SpectatorYaw = _y;
			WFBE_C_VAR_SpectatorPitch = _pt;
		};
		if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_BROADCAST_HUD", 0]) > 0) then {
			[] Call WFBE_CL_FNC_SpectatorBroadcastHudUpdate;
		} else {
			if !(WFBE_C_VAR_SpectatorHideHint) then {
			_tgtTxt = "-";
			if (!isNull _t && {alive _t}) then {_tgtTxt = name _t};
			_baseRemain = "--";
			_shotType = "-";
			if (_mode == "director") then {
				_shotType = WFBE_C_VAR_SpectatorDirectorShotType;
				if (WFBE_C_VAR_SpectatorDirectorAuto) then {
					_baseRemain = round (((missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_BASE_CHECK_SEC", 420]) - (WFBE_C_VAR_DirectorAutoTime - WFBE_C_VAR_DirectorLastBaseCheck)) max 0);
				};
			};
			_dirCard = "";
			if (_mode == "director" && {!isNull _t}) then {
				_tgtTxt = Format ["%1: %2", WFBE_C_VAR_SpectatorDirectorClass, WFBE_C_VAR_SpectatorDirectorTargetLabel];
			};
			//--- CUTTEXT, NOT HINT (live-proven 2026-07-30): hints do NOT render while a scripted
			//--- cameraEffect camera is live - PgUp gave no readout and this card never drew in
			//--- spectator, while the SAME client sees normal gameplay hints fine in first person
			//--- (owner-confirmed) and the lobby-lock hold's cutText rendered during the join hold.
			//--- Title layers composite over camera effects; the hint layer does not.
			//--- Layer 12455 (12454 belongs to the lobby-lock hold; 12450-12452/12461 are taken).
			//--- cutText takes a plain STRING; "\n" line breaks are the in-tree proven pattern
			//--- (Client_TitleTextMessage.sqf). The opt-in broadcast HUD now uses the cutRsc path above.
			_dirCard = Format [
				"SPECTATOR [%1]  target %2\nspeed %3 m/s | FOV %4%5 | sens %6",
				toUpper _mode, _tgtTxt, round _spd, round (WFBE_C_VAR_SpectatorFov * 100), "%",
				round (missionNamespace getVariable ["WFBE_C_SPECTATOR_SENS", 45])
			];
			_dirCard = _dirCard + "\nMOVE  mouse look | W/S fly | A/D strafe | Space/Ctrl up-down | Shift boost | Alt crawl | wheel zoom";
			_dirCard = _dirCard + "\nTARGETS  N/B cycle | F follow | V eyes";
			if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR", 0]) > 0) then {
				_dirCard = _dirCard + Format [
					"\nDIRECTOR  TAB pin | G auto %1 | O orbit %2 | shot %3 | base %4s | dwell %5s",
					if (WFBE_C_VAR_SpectatorDirectorAuto) then {"ON"} else {"OFF"},
					if (WFBE_C_VAR_SpectatorOrbit) then {"ON"} else {"OFF"},
					_shotType,
					_baseRemain,
					round WFBE_C_VAR_SpectatorDirectorDwell
				];
			};
			_dirCard = _dirCard + "\nSETUP  PgUp/PgDn sens | H hide card | Backspace exit";
			//--- FLICKER FIX (owner live report 2026-07-31: "H menu just flashed small white text"):
			//--- re-issuing cutText every 0.05s tick makes the engine restart the title each frame,
			//--- which renders as a flash instead of a steady card. Only re-cut when the card STRING
			//--- actually changed (speed/FOV/target update at ~1Hz, not 20Hz).
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
