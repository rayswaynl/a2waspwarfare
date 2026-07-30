/* Client_SpectatorEnter.sqf
   fable/spectator-v1 -> v2 -> v3 director (owner 2026-07-30 streaming)
   -------------------------------------------------------------------------
   Enters the UID-allowlisted spectator overlay for the CALLING client only.
   The UID allowlist gates ACTION VISIBILITY on this client only, under standard
   A2 locality; it is not server-enforced authentication or authorization.
   v1 safety model is UNTOUCHED: body parked invulnerable + captive + position-locked,
   death watchdog auto-exits, exit is idempotent, NO disableUserInput.
   addAction scripts remain file-path STRINGS (A2 OA requirement).

   v2: mouse look, wheel zoom, WASD fly, N/B target, F follow, V eyes, H UI, Backspace exit.
   v3 director (flags WFBE_C_SPECTATOR_*):
     G  cycle TARGET CLASS: players -> teams (AICOM roster) -> towns
     O  toggle ORBIT mode (circular orbit of armed target)
     R  toggle DIRECTOR auto-rotation (interest-ranked, dwell time)
   Seagull carrier: EVALUATED, NOT used - keep camCreate (see PR body).

   Modes: free / follow / eyes / orbit.
   A2-OA-1.64 safe commands only - no A3-only.
*/
disableSerialization;
Private ["_myUID","_pos0","_yaw0","_disp"];

if (missionNamespace getVariable ["WFBE_C_VAR_SpectatorActive", false]) exitWith {};
if !(alive player) exitWith {};
if !((missionNamespace getVariable ["WFBE_C_SPECTATOR", 0]) > 0) exitWith {};

_myUID = getPlayerUID player;
if !(_myUID in (missionNamespace getVariable ["WFBE_C_SPECTATOR_UIDS", []])) exitWith {};

WFBE_C_VAR_SpectatorActive = true;
WFBE_C_VAR_SpectatorBody = player;
WFBE_C_VAR_SpectatorMode = "free";
WFBE_C_VAR_SpectatorTarget = objNull;
WFBE_C_VAR_SpectatorHideHint = false;
WFBE_C_VAR_SpectatorMouseBaseline = true;
WFBE_C_VAR_SpectatorTargetClass = "players";
WFBE_C_VAR_SpectatorOrbitAng = 0;
WFBE_C_VAR_SpectatorDirector = false;
WFBE_C_VAR_SpectatorDirectorUntil = 0;

_pos0 = getPos player;
_yaw0 = getDir player;
diag_log Format ["SPECTATE|v3|enter|uid=%1|pos=%2", _myUID, _pos0];

player allowDamage false;
player setCaptive true;

//--- camCreate carrier (live-proven). Seagull mount not used (WFBE_C_SPECTATOR_SEAGULL default 0).
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

systemChat "[WASP] Spectator v3: N/B targets | G class | F follow | O orbit | V eyes | R director | H UI | Backspace exit.";
WFBE_C_VAR_SpectatorKeys = [false,false,false,false,false,false,false,false];

WFBE_CL_FNC_SpectatorBuildList = {
	Private ["_class","_list","_side","_logik","_teams","_grp","_ldr","_town"];
	_class = WFBE_C_VAR_SpectatorTargetClass;
	_list = [];
	if (_class == "teams") then {
		if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_TEAMS", 1]) > 0) then {
			{
				_side = _x;
				_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
				if (!isNull _logik) then {
					_teams = _logik getVariable "wfbe_teams";
					if (!isNil "_teams") then {
						{
							_grp = _x;
							if (!isNull _grp) then {
								_ldr = leader _grp;
								if (!isNull _ldr && {alive _ldr} && {!isPlayer _ldr} && {!(_ldr == player)}) then {
									_list = _list + [_ldr];
								};
							};
						} forEach _teams;
					};
				};
			} forEach [west, east];
		};
	} else {
		if (_class == "towns") then {
			if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_TOWNS", 1]) > 0) then {
				if (!isNil "towns") then {
					{
						_town = _x;
						if (!isNull _town) then {
							if (!(_town getVariable ["wfbe_inactive", false])) then {
								_list = _list + [_town];
							};
						};
					} forEach towns;
				};
			};
		} else {
			{
				if (!isNil "_x") then {
					if (alive _x && {isPlayer _x} && {!(_x == player)}) then {_list = _list + [_x]};
				};
			} forEach allUnits;
		};
	};
	_list
};

WFBE_CL_FNC_SpectatorTargetLabel = {
	Private ["_t","_n"];
	_t = _this;
	if (isNull _t) exitWith {"-"};
	if (WFBE_C_VAR_SpectatorTargetClass == "towns") then {
		_n = _t getVariable "name";
		if (isNil "_n") then {_n = str _t};
		_n
	} else {
		if (isPlayer _t) then {name _t} else {Format ["AI %1", name _t]}
	}
};

WFBE_CL_FNC_SpectatorCycleTarget = {
	Private ["_step","_list","_cur","_idx","_next","_i"];
	_step = _this;
	_list = Call WFBE_CL_FNC_SpectatorBuildList;
	if (count _list == 0) exitWith {
		WFBE_C_VAR_SpectatorTarget = objNull;
		systemChat Format ["[WASP] Spectator: no %1 targets.", WFBE_C_VAR_SpectatorTargetClass];
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
	systemChat Format ["[WASP] Spectator target (%1): %2", WFBE_C_VAR_SpectatorTargetClass, (_next Call WFBE_CL_FNC_SpectatorTargetLabel)];
};

WFBE_CL_FNC_SpectatorScoreTarget = {
	Private ["_t","_sc","_sid","_en","_pos"];
	_t = _this;
	_sc = 0;
	if (isNull _t) exitWith {0};
	if (WFBE_C_VAR_SpectatorTargetClass == "towns") then {
		if (_t getVariable ["wfbe_active", false]) then {_sc = _sc + 500};
		_sid = _t getVariable ["sideID", -1];
		if (_sid == WFBE_C_WEST_ID || {_sid == WFBE_C_EAST_ID}) then {_sc = _sc + 50} else {_sc = _sc + 120};
		_sc = _sc + ((_t getVariable ["supplyValue", 0]) min 200);
	} else {
		if (alive _t) then {
			_sc = _sc + 100;
			if ((behaviour _t) == "COMBAT") then {_sc = _sc + 400};
			if ((behaviour _t) == "AWARE") then {_sc = _sc + 80};
			_pos = getPos _t;
			_en = {alive _x && {(side _x) != (side _t) && {(side _x) != civilian}}} count (_pos nearEntities [["Man","LandVehicle","Air"], 250]);
			_sc = _sc + ((_en min 20) * 25);
			if (isPlayer _t) then {_sc = _sc + 60};
		};
	};
	_sc
};

WFBE_CL_FNC_SpectatorDirectorPick = {
	Private ["_list","_best","_bestSc","_sc","_t","_cur"];
	_list = Call WFBE_CL_FNC_SpectatorBuildList;
	if (count _list == 0) exitWith {objNull};
	_cur = WFBE_C_VAR_SpectatorTarget;
	_best = objNull;
	_bestSc = -1e9;
	{
		_t = _x;
		_sc = _t Call WFBE_CL_FNC_SpectatorScoreTarget;
		if (_t == _cur) then {_sc = _sc - 80};
		if (_sc > _bestSc) then {_bestSc = _sc; _best = _t};
	} forEach _list;
	_best
};

WFBE_CL_FNC_SpectatorKeyDown = {
	Private ["_dik","_handled","_cls"];
	_dik = _this select 1;
	_handled = true;
	switch (_dik) do {
		case 17: {WFBE_C_VAR_SpectatorKeys set [0, true]};
		case 31: {WFBE_C_VAR_SpectatorKeys set [1, true]};
		case 30: {WFBE_C_VAR_SpectatorKeys set [2, true]};
		case 32: {WFBE_C_VAR_SpectatorKeys set [3, true]};
		case 57: {WFBE_C_VAR_SpectatorKeys set [4, true]};
		case 29: {WFBE_C_VAR_SpectatorKeys set [5, true]};
		case 157: {WFBE_C_VAR_SpectatorKeys set [5, true]};
		case 42: {WFBE_C_VAR_SpectatorKeys set [6, true]};
		case 54: {WFBE_C_VAR_SpectatorKeys set [6, true]};
		case 56: {WFBE_C_VAR_SpectatorKeys set [7, true]};
		case 49: {1 Call WFBE_CL_FNC_SpectatorCycleTarget};
		case 48: {-1 Call WFBE_CL_FNC_SpectatorCycleTarget};
		case 34: {
			_cls = WFBE_C_VAR_SpectatorTargetClass;
			if (_cls == "players") then {
				if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_TEAMS", 1]) > 0) then {_cls = "teams"} else {
					if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_TOWNS", 1]) > 0) then {_cls = "towns"} else {_cls = "players"};
				};
			} else {
				if (_cls == "teams") then {
					if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_TOWNS", 1]) > 0) then {_cls = "towns"} else {_cls = "players"};
				} else {
					_cls = "players";
				};
			};
			WFBE_C_VAR_SpectatorTargetClass = _cls;
			WFBE_C_VAR_SpectatorTarget = objNull;
			systemChat Format ["[WASP] Spectator class: %1 (N/B to arm)", _cls];
			1 Call WFBE_CL_FNC_SpectatorCycleTarget;
		};
		case 24: {
			if !((missionNamespace getVariable ["WFBE_C_SPECTATOR_ORBIT", 1]) > 0) then {
				systemChat "[WASP] Orbit mode is dark (WFBE_C_SPECTATOR_ORBIT=0).";
			} else {
				if (WFBE_C_VAR_SpectatorMode == "orbit") then {
					WFBE_C_VAR_SpectatorMode = "free";
					systemChat "[WASP] Free camera.";
				} else {
					if (!isNull WFBE_C_VAR_SpectatorTarget) then {
						WFBE_C_VAR_SpectatorMode = "orbit";
						WFBE_C_VAR_SpectatorOrbitAng = 0;
						systemChat Format ["[WASP] Orbit: %1 (WASD to detach)", (WFBE_C_VAR_SpectatorTarget Call WFBE_CL_FNC_SpectatorTargetLabel)];
					} else {
						systemChat "[WASP] No target - press N/B (or G for class) first.";
					};
				};
			};
		};
		case 19: {
			if !((missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR", 1]) > 0) then {
				systemChat "[WASP] Director is dark (WFBE_C_SPECTATOR_DIRECTOR=0).";
			} else {
				WFBE_C_VAR_SpectatorDirector = !WFBE_C_VAR_SpectatorDirector;
				if (WFBE_C_VAR_SpectatorDirector) then {
					WFBE_C_VAR_SpectatorDirectorUntil = 0;
					systemChat Format ["[WASP] Director ON (dwell %1s). R again to stop.", missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_DWELL", 12]];
				} else {
					systemChat "[WASP] Director OFF.";
				};
			};
		};
		case 33: {
			if (WFBE_C_VAR_SpectatorMode == "follow") then {
				WFBE_C_VAR_SpectatorMode = "free";
				systemChat "[WASP] Free camera.";
			} else {
				if (!isNull WFBE_C_VAR_SpectatorTarget) then {
					if (WFBE_C_VAR_SpectatorTargetClass == "towns" || {alive WFBE_C_VAR_SpectatorTarget}) then {
						WFBE_C_VAR_SpectatorMode = "follow";
						systemChat Format ["[WASP] Follow-cam: %1 (WASD to detach)", (WFBE_C_VAR_SpectatorTarget Call WFBE_CL_FNC_SpectatorTargetLabel)];
					} else {
						systemChat "[WASP] Target is dead - pick another with N/B.";
					};
				} else {
					systemChat "[WASP] No target - press N/B to arm first.";
				};
			};
		};
		case 47: {
			if (WFBE_C_VAR_SpectatorMode == "eyes") then {
				WFBE_C_VAR_SpectatorMode = "free";
				systemChat "[WASP] Free camera.";
			} else {
				if (WFBE_C_VAR_SpectatorTargetClass == "towns") then {
					systemChat "[WASP] Eyes POV needs a unit target (switch class with G).";
				} else {
					if (!isNull WFBE_C_VAR_SpectatorTarget && {alive WFBE_C_VAR_SpectatorTarget}) then {
						WFBE_C_VAR_SpectatorMode = "eyes";
						systemChat Format ["[WASP] POV: %1 (WASD to detach)", (WFBE_C_VAR_SpectatorTarget Call WFBE_CL_FNC_SpectatorTargetLabel)];
					} else {
						systemChat "[WASP] No unit target - press N/B first.";
					};
				};
			};
		};
		case 201: {
			private "_s";
			_s = ((missionNamespace getVariable ["WFBE_C_SPECTATOR_SENS", 45]) + 10) min 400;
			missionNamespace setVariable ["WFBE_C_SPECTATOR_SENS", _s];
			hintSilent Format ["Spectator sensitivity: %1", _s];
			true
		};
		case 209: {
			private "_s";
			_s = ((missionNamespace getVariable ["WFBE_C_SPECTATOR_SENS", 45]) - 10) max 10;
			missionNamespace setVariable ["WFBE_C_SPECTATOR_SENS", _s];
			hintSilent Format ["Spectator sensitivity: %1", _s];
			true
		};
		case 35: {
			WFBE_C_VAR_SpectatorHideHint = !WFBE_C_VAR_SpectatorHideHint;
			if (WFBE_C_VAR_SpectatorHideHint) then {hintSilent ""};
		};
		case 14: {[] Call WFBE_CL_FNC_SpectatorExit};
		default {_handled = false};
	};
	_handled
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

WFBE_CL_FNC_SpectatorMouseMoving = {
	Private ["_x","_y","_dx","_dy","_sens","_cap"];
	_x = _this select 1;
	_y = _this select 2;
	if (WFBE_C_VAR_SpectatorMouseBaseline) then {
		WFBE_C_VAR_SpectatorLastMouseX = _x;
		WFBE_C_VAR_SpectatorLastMouseY = _y;
		WFBE_C_VAR_SpectatorMouseBaseline = false;
		false
	} else {
		_dx = _x - WFBE_C_VAR_SpectatorLastMouseX;
		_dy = _y - WFBE_C_VAR_SpectatorLastMouseY;
		_cap = 0.25;
		_dx = (_dx max -_cap) min _cap;
		_dy = (_dy max -_cap) min _cap;
		setMousePosition [0.5, 0.5];
		WFBE_C_VAR_SpectatorMouseBaseline = true;
		if (WFBE_C_VAR_SpectatorMode == "free") then {
			_sens = missionNamespace getVariable ["WFBE_C_SPECTATOR_SENS", 45];
			WFBE_C_VAR_SpectatorYaw = WFBE_C_VAR_SpectatorYaw + _dx * _sens;
			WFBE_C_VAR_SpectatorPitch = ((WFBE_C_VAR_SpectatorPitch - _dy * _sens) max -89) min 89;
		};
		false
	}
};

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
	Private ["_mode","_t","_k","_p","_y","_pt","_cy","_sy","_cp","_sp","_fwd","_right","_spd","_dt","_last","_tx","_ty","_tz","_body","_lockPos","_lockDir","_hd","_tgtTxt","_e","_d","_rad","_hgt","_rate","_ang","_pick","_dirOn","_cls","_tp"];
	_body = WFBE_C_VAR_SpectatorBody;
	_lockPos = getPos _body;
	_lockDir = getDir _body;
	_last = time;
	while {WFBE_C_VAR_SpectatorActive && {!(missionNamespace getVariable ["WFBE_gameover", false])}} do {
		sleep 0.05;
		if (isNull _body || {!alive _body}) exitWith {[] Call WFBE_CL_FNC_SpectatorExit};
		_body setPos _lockPos;
		_body setDir _lockDir;
		_dt = time - _last;
		_last = time;
		_k = WFBE_C_VAR_SpectatorKeys;
		_mode = WFBE_C_VAR_SpectatorMode;
		_t = WFBE_C_VAR_SpectatorTarget;
		_cls = WFBE_C_VAR_SpectatorTargetClass;

		_dirOn = WFBE_C_VAR_SpectatorDirector && {(missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR", 1]) > 0};
		if (_dirOn && {time >= WFBE_C_VAR_SpectatorDirectorUntil}) then {
			_pick = Call WFBE_CL_FNC_SpectatorDirectorPick;
			if (!isNull _pick) then {
				WFBE_C_VAR_SpectatorTarget = _pick;
				_t = _pick;
				if (_mode == "free" || {_mode == "eyes" && {_cls == "towns"}}) then {
					if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_ORBIT", 1]) > 0) then {
						WFBE_C_VAR_SpectatorMode = "orbit";
						_mode = "orbit";
					} else {
						WFBE_C_VAR_SpectatorMode = "follow";
						_mode = "follow";
					};
				};
				WFBE_C_VAR_SpectatorDirectorUntil = time + (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_DWELL", 12]);
			} else {
				WFBE_C_VAR_SpectatorDirectorUntil = time + 3;
			};
		};

		if (_mode == "follow" || {_mode == "eyes"} || {_mode == "orbit"}) then {
			if (isNull _t) then {
				WFBE_C_VAR_SpectatorMode = "free";
				_mode = "free";
				systemChat "[WASP] Spectator target lost - back to free camera.";
			} else {
				if (_cls != "towns" && {!alive _t}) then {
					WFBE_C_VAR_SpectatorMode = "free";
					_mode = "free";
					systemChat "[WASP] Spectator target lost - back to free camera.";
				};
			};
		};
		if (_mode != "free") then {
			if ((_k select 0) || {(_k select 1)} || {(_k select 2)} || {(_k select 3)} || {(_k select 4)} || {(_k select 5)}) then {
				WFBE_C_VAR_SpectatorMode = "free";
				_mode = "free";
				if (WFBE_C_VAR_SpectatorDirector) then {
					WFBE_C_VAR_SpectatorDirector = false;
					systemChat "[WASP] Director paused (manual fly).";
				};
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
					if (_cls == "towns") then {
						_tp = getPos _t;
						_p = [(_tp select 0), (_tp select 1) - 40, (_tp select 2) + 35];
						_tx = _tp select 0;
						_ty = _tp select 1;
						_tz = (_tp select 2) + 2;
						_hd = sqrt (((_tx - (_p select 0)) ^ 2) + ((_ty - (_p select 1)) ^ 2));
						_y = (((_tx - (_p select 0)) atan2 (_ty - (_p select 1))) + 360) % 360;
						_pt = (((_tz - (_p select 2)) atan2 (_hd max 0.01)) max -80) min 80;
						WFBE_C_VAR_SpectatorCam camSetPos _p;
						WFBE_C_VAR_SpectatorCam camSetTarget _t;
					} else {
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
				};
				case "orbit": {
					_rad = missionNamespace getVariable ["WFBE_C_SPECTATOR_ORBIT_RADIUS", 25];
					_hgt = missionNamespace getVariable ["WFBE_C_SPECTATOR_ORBIT_HEIGHT", 12];
					_rate = missionNamespace getVariable ["WFBE_C_SPECTATOR_ORBIT_RATE", 12];
					_ang = WFBE_C_VAR_SpectatorOrbitAng + (_rate * _dt);
					if (_ang > 360) then {_ang = _ang - 360};
					if (_ang < 0) then {_ang = _ang + 360};
					WFBE_C_VAR_SpectatorOrbitAng = _ang;
					_tp = getPos _t;
					_p = [
						(_tp select 0) + _rad * (sin _ang),
						(_tp select 1) + _rad * (cos _ang),
						(_tp select 2) + _hgt
					];
					_tx = _tp select 0;
					_ty = _tp select 1;
					_tz = (_tp select 2) + 1.5;
					_hd = sqrt (((_tx - (_p select 0)) ^ 2) + ((_ty - (_p select 1)) ^ 2));
					_y = (((_tx - (_p select 0)) atan2 (_ty - (_p select 1))) + 360) % 360;
					_pt = (((_tz - (_p select 2)) atan2 (_hd max 0.01)) max -80) min 80;
					WFBE_C_VAR_SpectatorCam camSetPos _p;
					WFBE_C_VAR_SpectatorCam camSetTarget [_tx, _ty, _tz];
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
			if (!isNull _t) then {
				if (_cls == "towns" || {alive _t}) then {_tgtTxt = _t Call WFBE_CL_FNC_SpectatorTargetLabel};
			};
			hintSilent parseText Format [
				"<t size='1.2' color='#7fd4ff'>SPECTATOR v3</t>  <t color='#ffcc33'>%1</t>  <t color='#aaddff'>%2</t>%3<br/>"
				+ "<t color='#cccccc'>Target</t> %4<br/>"
				+ "<t color='#cccccc'>Speed</t> %5 m/s   <t color='#cccccc'>FOV</t> %6%7   <t color='#cccccc'>Sens</t> %8<br/>"
				+ "<br/><t size='0.9' color='#7fd4ff'>MOVE</t><br/>"
				+ "<t size='0.85' color='#aaaaaa'>Mouse look | W/S fly | A/D strafe | Space/Ctrl up-down<br/>"
				+ "Shift boost | Alt crawl | Wheel zoom</t><br/>"
				+ "<t size='0.9' color='#7fd4ff'>TARGETS</t><br/>"
				+ "<t size='0.85' color='#aaaaaa'>G class (players/teams/towns) | N/B next-prev<br/>"
				+ "F follow | O orbit | V eyes (units) | R director auto</t><br/>"
				+ "<t size='0.9' color='#7fd4ff'>SETUP</t><br/>"
				+ "<t size='0.85' color='#aaaaaa'>PgUp/PgDn sensitivity | H hide card | Backspace exit</t>",
				toUpper _mode,
				WFBE_C_VAR_SpectatorTargetClass,
				(if (WFBE_C_VAR_SpectatorDirector) then {"  <t color='#66ff99'>DIR</t>"} else {""}),
				_tgtTxt,
				round _spd,
				round (WFBE_C_VAR_SpectatorFov * 100),
				"%",
				round (missionNamespace getVariable ["WFBE_C_SPECTATOR_SENS", 45])
			];
		};
	};
};