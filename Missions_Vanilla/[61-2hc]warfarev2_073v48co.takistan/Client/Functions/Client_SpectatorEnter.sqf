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
     N / B       arm next/previous alive player as watch target (skips self)
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

   A2-OA-1.64 safe commands used: camCreate / camSetPos / camSetTarget /
   camSetFov / camCommit / camCommitted / cameraEffect / camDestroy /
   allowDamage / setCaptive / getPlayerUID / getPos / getDir / setDir /
   setPos / sin / cos / sqrt / atan2 / min / max / mod(% operator) /
   displayAddEventHandler / setMousePosition (OA 1.60+) / eyePos /
   eyeDirection / modelToWorld / isPlayer / allUnits / name / toUpper /
   hintSilent / parseText / switch - no A3-only commands.
*/
Private ["_myUID","_pos0","_yaw0","_disp"];

if (missionNamespace getVariable ["WFBE_C_VAR_SpectatorActive", false]) exitWith {}; //--- already active; ignore a double-click race.
if !(alive player) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_SPECTATOR", 0]) <= 0) exitWith {};

_myUID = getPlayerUID player;
if !(_myUID in (missionNamespace getVariable ["WFBE_C_SPECTATOR_UIDS", []])) exitWith {}; //--- belt-and-braces re-check; the addAction condition already gates this.

WFBE_C_VAR_SpectatorActive = true;
WFBE_C_VAR_SpectatorBody = player; //--- pin the exact body this session belongs to.
WFBE_C_VAR_SpectatorMode = "free";
WFBE_C_VAR_SpectatorTarget = objNull;
WFBE_C_VAR_SpectatorHideHint = false;

_pos0 = getPos player;
_yaw0 = getDir player;

diag_log Format ["SPECTATE|v2|enter|uid=%1|pos=%2", _myUID, _pos0];

//--- Park the body: invulnerable + non-hostile so it cannot be farmed or trip AI aggro while unattended.
player allowDamage false;
player setCaptive true;

WFBE_C_VAR_SpectatorCam = "camera" camCreate _pos0;
WFBE_C_VAR_SpectatorFov = 0.8;
WFBE_C_VAR_SpectatorCam camSetFov 0.8;
WFBE_C_VAR_SpectatorCam cameraEffect ["Internal", "Back"];
WFBE_C_VAR_SpectatorCam camSetPos [_pos0 select 0, _pos0 select 1, (_pos0 select 2) + 2];
WFBE_C_VAR_SpectatorCam camSetTarget [
	(_pos0 select 0) + 10 * (sin _yaw0),
	(_pos0 select 1) + 10 * (cos _yaw0),
	(_pos0 select 2) + 2
];
WFBE_C_VAR_SpectatorCam camCommit 0;
waitUntil {camCommitted WFBE_C_VAR_SpectatorCam};

WFBE_C_VAR_SpectatorPos = [_pos0 select 0, _pos0 select 1, (_pos0 select 2) + 2];
WFBE_C_VAR_SpectatorYaw = _yaw0;
WFBE_C_VAR_SpectatorPitch = 0;
WFBE_C_VAR_SpectatorLastMouseX = 0.5;
WFBE_C_VAR_SpectatorLastMouseY = 0.5;

systemChat "[WASP] Spectator v2: mouse look, wheel zoom, WASD fly, Shift/Alt speed, N/B target, F follow, V eyes, H hide UI, Backspace exit.";

WFBE_C_VAR_SpectatorKeys = [false,false,false,false,false,false,false,false]; //--- W,S,A,D,Space,Ctrl,Shift,Alt

//--- Arms the next (+1) or previous (-1) alive player as the watch target. Skips self,
//--- dead and null units, wraps around the list. Does NOT change mode by itself - F/V engage.
WFBE_CL_FNC_SpectatorCycleTarget = {
	Private ["_step","_list","_cur","_idx","_next","_i"];
	_step = _this;
	_list = [];
	{
		if (!isNil "_x") then {
			if (alive _x && {isPlayer _x} && {!(_x == player)}) then {_list = _list + [_x]};
		};
	} forEach allUnits;
	if (count _list == 0) exitWith {
		WFBE_C_VAR_SpectatorTarget = objNull;
		systemChat "[WASP] Spectator: no other alive players to watch.";
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
	systemChat Format ["[WASP] Spectator target: %1 (F follow, V eyes)", name _next];
};

WFBE_CL_FNC_SpectatorKeyDown = {
	Private ["_dik","_handled"];
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
		case 33: { //--- F: toggle follow-cam on the armed target
			if (WFBE_C_VAR_SpectatorMode == "follow") then {
				WFBE_C_VAR_SpectatorMode = "free";
				systemChat "[WASP] Free camera.";
			} else {
				if (!isNull WFBE_C_VAR_SpectatorTarget && {alive WFBE_C_VAR_SpectatorTarget}) then {
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
					WFBE_C_VAR_SpectatorMode = "eyes";
					systemChat Format ["[WASP] POV: %1 (WASD to detach)", name WFBE_C_VAR_SpectatorTarget];
				} else {
					systemChat "[WASP] No target - press N/B to arm a player first.";
				};
			};
		};
		case 35: { //--- H: hide/show the hint overlay (clean OBS capture)
			WFBE_C_VAR_SpectatorHideHint = !WFBE_C_VAR_SpectatorHideHint;
			if (WFBE_C_VAR_SpectatorHideHint) then {hintSilent ""};
		};
		case 14: {[] Call WFBE_CL_FNC_SpectatorExit}; //--- Backspace: quick exit
		default {_handled = false}; //--- unhandled keys (Esc, chat, etc.) fall through to the game.
	};
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

//--- Mouse look: delta from the last event, then re-center the cursor so the edge of the
//--- screen never stops a swipe. Only drives the camera in free mode (follow/eyes aim from
//--- the target). Sensitivity is WFBE_C_SPECTATOR_SENS (degrees per full UI-width delta).
WFBE_CL_FNC_SpectatorMouseMoving = {
	Private ["_x","_y","_dx","_dy","_sens"];
	_x = _this select 1;
	_y = _this select 2;
	_dx = _x - WFBE_C_VAR_SpectatorLastMouseX;
	_dy = _y - WFBE_C_VAR_SpectatorLastMouseY;
	setMousePosition [0.5, 0.5];
	WFBE_C_VAR_SpectatorLastMouseX = 0.5;
	WFBE_C_VAR_SpectatorLastMouseY = 0.5;
	if (WFBE_C_VAR_SpectatorMode == "free") then {
		_sens = missionNamespace getVariable ["WFBE_C_SPECTATOR_SENS", 300];
		WFBE_C_VAR_SpectatorYaw = WFBE_C_VAR_SpectatorYaw + _dx * _sens;
		WFBE_C_VAR_SpectatorPitch = ((WFBE_C_VAR_SpectatorPitch - _dy * _sens) max -89) min 89;
	};
	false
};

//--- Wheel zoom: multiplicative FOV steps, clamped. Returns true so the wheel does not
//--- also cycle the parked body's weapon.
WFBE_CL_FNC_SpectatorWheel = {
	Private ["_z","_f"];
	_z = _this select 1;
	_f = WFBE_C_VAR_SpectatorFov;
	if (_z > 0) then {_f = _f * 0.85} else {_f = _f * 1.18};
	_f = (_f max (missionNamespace getVariable ["WFBE_C_SPECTATOR_FOV_MIN", 0.05])) min (missionNamespace getVariable ["WFBE_C_SPECTATOR_FOV_MAX", 1.2]);
	WFBE_C_VAR_SpectatorFov = _f;
	true
};

_disp = findDisplay 46;
WFBE_C_VAR_SpectatorKeyDownIdx = _disp displayAddEventHandler ["KeyDown", "_this Call WFBE_CL_FNC_SpectatorKeyDown"];
WFBE_C_VAR_SpectatorKeyUpIdx = _disp displayAddEventHandler ["KeyUp", "_this Call WFBE_CL_FNC_SpectatorKeyUp"];
WFBE_C_VAR_SpectatorMouseMovingIdx = _disp displayAddEventHandler ["MouseMoving", "_this Call WFBE_CL_FNC_SpectatorMouseMoving"];
WFBE_C_VAR_SpectatorWheelIdx = _disp displayAddEventHandler ["MouseZChanged", "_this Call WFBE_CL_FNC_SpectatorWheel"];

[] spawn {
	Private ["_mode","_t","_k","_p","_y","_pt","_cy","_sy","_cp","_sp","_fwd","_right","_spd","_dt","_last","_tx","_ty","_tz","_body","_lockPos","_lockDir","_hd","_tgtTxt","_e","_d"];
	_body = WFBE_C_VAR_SpectatorBody;
	_lockPos = getPos _body;
	_lockDir = getDir _body; //--- direction lock added in v2: the body must not spin under the mouse.
	_last = time;
	while {WFBE_C_VAR_SpectatorActive && {!WFBE_gameover}} do {
		sleep 0.05;
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
				WFBE_C_VAR_SpectatorMode = "free";
				_mode = "free";
			};
		};
		_spd = missionNamespace getVariable ["WFBE_C_SPECTATOR_SPEED", 15];
		if (_k select 6) then {_spd = _spd * (missionNamespace getVariable ["WFBE_C_SPECTATOR_BOOST", 4])};
		if (_k select 7) then {_spd = _spd * (missionNamespace getVariable ["WFBE_C_SPECTATOR_SLOW", 0.25])};
		_p = WFBE_C_VAR_SpectatorPos;
		_y = WFBE_C_VAR_SpectatorYaw;
		_pt = WFBE_C_VAR_SpectatorPitch;
		if !(isNull WFBE_C_VAR_SpectatorCam) then {
			switch (_mode) do {
				case "follow": {
					_p = _t modelToWorld [0, -8, 3];
					_tx = getPos _t select 0;
					_ty = getPos _t select 1;
					_tz = (getPos _t select 2) + 1.5;
					_hd = sqrt (((_tx - (_p select 0)) ^ 2) + ((_ty - (_p select 1)) ^ 2));
					_y = (((_tx - (_p select 0)) atan2 (_ty - (_p select 1))) + 360) % 360;
					_pt = (((_tz - (_p select 2)) atan2 (_hd max 0.01)) max -80) min 80;
					WFBE_C_VAR_SpectatorCam camSetPos _p;
					WFBE_C_VAR_SpectatorCam camSetTarget _t;
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
				default {
					_cy = cos _y; _sy = sin _y; _cp = cos _pt; _sp = sin _pt;
					_fwd = [_sy * _cp, _cy * _cp, _sp];
					_right = [_cy, -_sy, 0];
					if (_k select 0) then {_p = [(_p select 0) + (_fwd select 0) * _spd * _dt, (_p select 1) + (_fwd select 1) * _spd * _dt, (_p select 2) + (_fwd select 2) * _spd * _dt]};
					if (_k select 1) then {_p = [(_p select 0) - (_fwd select 0) * _spd * _dt, (_p select 1) - (_fwd select 1) * _spd * _dt, (_p select 2) - (_fwd select 2) * _spd * _dt]};
					if (_k select 3) then {_p = [(_p select 0) + (_right select 0) * _spd * _dt, (_p select 1) + (_right select 1) * _spd * _dt, _p select 2]};
					if (_k select 2) then {_p = [(_p select 0) - (_right select 0) * _spd * _dt, (_p select 1) - (_right select 1) * _spd * _dt, _p select 2]};
					if (_k select 4) then {_p set [2, (_p select 2) + _spd * _dt]};
					if (_k select 5) then {_p set [2, (_p select 2) - _spd * _dt]};
					_tx = (_p select 0) + (_fwd select 0) * 100;
					_ty = (_p select 1) + (_fwd select 1) * 100;
					_tz = (_p select 2) + (_fwd select 2) * 100;
					WFBE_C_VAR_SpectatorCam camSetPos _p;
					WFBE_C_VAR_SpectatorCam camSetTarget [_tx, _ty, _tz];
				};
			};
			WFBE_C_VAR_SpectatorCam camSetFov WFBE_C_VAR_SpectatorFov;
			WFBE_C_VAR_SpectatorCam camCommit 0;
		};
		WFBE_C_VAR_SpectatorPos = _p;
		WFBE_C_VAR_SpectatorYaw = _y;
		WFBE_C_VAR_SpectatorPitch = _pt;
		if !(WFBE_C_VAR_SpectatorHideHint) then {
			_tgtTxt = "-";
			if (!isNull _t && {alive _t}) then {_tgtTxt = name _t};
			hintSilent parseText Format [
				"<t size='1.1' color='#7fd4ff'>SPECTATOR v2 [%1]</t><br/>Target: %2<br/>Speed: %3 m/s<br/>FOV: %4%5<br/><t color='#aaaaaa'>N/B target | F follow | V eyes | wheel zoom | H hide | Backspace exit</t>",
				toUpper _mode, _tgtTxt, round _spd, round (WFBE_C_VAR_SpectatorFov * 100), "%"
			];
		};
	};
	//--- Fail-clean: while can exit on WFBE_gameover (or Active cleared externally) without the
	//--- death-watchdog exitWith path, leaving cam + display EHs + parked-body invuln/captive latched.
	if (missionNamespace getVariable ["WFBE_C_VAR_SpectatorActive", false]) then {
		[] Call WFBE_CL_FNC_SpectatorExit;
	};
};
