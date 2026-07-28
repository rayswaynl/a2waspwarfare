/* Client_SpectatorEnter.sqf
   fable/spectator-v1 (owner request 2026-07-28: spectator mode, owner first)
   -------------------------------------------------------------------------
   Enters the UID-allowlisted free-camera spectator overlay for the CALLING
   client only. addAction target (see Client_SpectatorAttach.sqf); the
   addAction condition already restricts visibility to the allowlisted UID,
   an alive body, and past the deadspawn-transit invulnerability window
   (WFBE_Client_DeadspawnEscaped, Init_Client.sqf:49-63) - the re-checks
   below are belt-and-braces in case of a stale/duplicated action instance.

   DEADSPAWN-WATCHDOG INTERACTION (owner constraint #5): the join-time
   deadspawn watchdog (Init_Client.sqf) sets `player allowDamage false` on
   join/JIP and clears it back to `true` exactly once, either when
   WFBE_Client_DeadspawnEscaped goes true or after a hard 120s timeout -
   whichever first. Gating the "Spectator Camera" addAction's condition on
   WFBE_Client_DeadspawnEscaped (see Client_SpectatorAttach.sqf) means the
   action is not even clickable until that watchdog has already resolved, so
   this feature's own `allowDamage false` below can never race the
   watchdog's later `allowDamage true` clear. No respawn/JIP file is
   touched.

   Body safety: allowDamage false + setCaptive true park the body exactly
   like the proven AI-respawn-hold idiom (Server\AI\AI_AdvancedRespawn.sqf,
   Server\AI\AI_SquadRespawn.sqf, Headless\Init\Init_HC.sqf) so it cannot be
   farmed or trip AI aggro while unattended. A light position-lock (re-assert
   the entry position every movement-loop tick below) keeps the body from
   wandering off under the SAME WASD keys that are driving the camera -
   DELIBERATELY WITHOUT disableUserInput: that command's own BI wiki page
   warns the only recovery from a script that fails to clear it is
   restarting the game, an unacceptable failure mode for a live community
   server. The position-lock has no such failure mode (worst case the body
   just does not resnap for one 0.05s tick) - a deliberate safety-over-polish
   tradeoff, noted in the PR body.

   Camera mechanic: camCreate + camSetTarget/camSetPos + camCommit +
   cameraEffect + camDestroy - the SAME idiom already proven live in this
   exact dedicated-MP mission: death camera (Client_OnKilled.sqf +
   GUI_RespawnMenu.sqf), victory camera (Client_EndGame.sqf), tactical-map
   preview (GUI_Menu_Tactical.sqf), construction preview
   (Client_Module/CoIn/coin_interface.sqf). Movement is scripted
   keyboard-follow (WASD move, Q/E turn, Up/Down arrows pitch, Space/Ctrl
   up/down) - the task's own documented fallback once `camera.sqs` could not
   be verified as an A2-OA dedicated-MP-safe mechanism (no in-tree
   precedent anywhere in this mission, and its BI wiki page returned HTTP 403
   so its MP behaviour could not be confirmed). camCreate's family, by
   contrast, is proven live in THIS codebase's dedicated MP server four
   separate times, so only that mechanism is shipped (never both).

   A2-OA-1.64 safe commands used: camCreate / camSetPos / camSetTarget /
   camSetFov / camCommit / camCommitted / cameraEffect / camDestroy /
   allowDamage / setCaptive / getPlayerUID / getPos / getDir / sin / cos /
   min / max / displayAddEventHandler / displayRemoveEventHandler / switch -
   no A3-only commands (no isEqualType / params / pushBack / select{} / etc).
*/
Private ["_myUID","_pos0","_yaw0","_disp"];

if (missionNamespace getVariable ["WFBE_C_VAR_SpectatorActive", false]) exitWith {}; //--- already active; ignore a double-click race.
if !(alive player) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_SPECTATOR", 0]) <= 0) exitWith {};

_myUID = getPlayerUID player;
if !(_myUID in (missionNamespace getVariable ["WFBE_C_SPECTATOR_UIDS", []])) exitWith {}; //--- belt-and-braces re-check; the addAction condition already gates this.

WFBE_C_VAR_SpectatorActive = true;
WFBE_C_VAR_SpectatorBody = player; //--- pin the exact body this session belongs to.

_pos0 = getPos player;
_yaw0 = getDir player;

diag_log Format ["SPECTATE|v1|enter|uid=%1|pos=%2", _myUID, _pos0];

//--- Park the body: invulnerable + non-hostile so it cannot be farmed or trip AI aggro while unattended.
player allowDamage false;
player setCaptive true;

WFBE_C_VAR_SpectatorCam = "camera" camCreate _pos0;
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

systemChat "[WASP] Spectator camera: W/A/S/D move, Q/E turn, Up/Down pitch, Space/Ctrl up-down. Use 'Exit Spectator' to return.";

WFBE_C_VAR_SpectatorKeys = [false,false,false,false,false,false,false,false,false,false]; //--- W,S,A,D,Q,E,Up,Down,Space,Ctrl

WFBE_CL_FNC_SpectatorKeyDown = {
	Private ["_dik"];
	_dik = _this select 1;
	switch (_dik) do {
		case 17: {WFBE_C_VAR_SpectatorKeys set [0, true]}; //--- W
		case 31: {WFBE_C_VAR_SpectatorKeys set [1, true]}; //--- S
		case 30: {WFBE_C_VAR_SpectatorKeys set [2, true]}; //--- A
		case 32: {WFBE_C_VAR_SpectatorKeys set [3, true]}; //--- D
		case 16: {WFBE_C_VAR_SpectatorKeys set [4, true]}; //--- Q
		case 18: {WFBE_C_VAR_SpectatorKeys set [5, true]}; //--- E
		case 200: {WFBE_C_VAR_SpectatorKeys set [6, true]}; //--- Up arrow
		case 208: {WFBE_C_VAR_SpectatorKeys set [7, true]}; //--- Down arrow
		case 57: {WFBE_C_VAR_SpectatorKeys set [8, true]}; //--- Space
		case 29: {WFBE_C_VAR_SpectatorKeys set [9, true]}; //--- LCtrl
		case 157: {WFBE_C_VAR_SpectatorKeys set [9, true]}; //--- RCtrl
	};
	false
};
WFBE_CL_FNC_SpectatorKeyUp = {
	Private ["_dik"];
	_dik = _this select 1;
	switch (_dik) do {
		case 17: {WFBE_C_VAR_SpectatorKeys set [0, false]};
		case 31: {WFBE_C_VAR_SpectatorKeys set [1, false]};
		case 30: {WFBE_C_VAR_SpectatorKeys set [2, false]};
		case 32: {WFBE_C_VAR_SpectatorKeys set [3, false]};
		case 16: {WFBE_C_VAR_SpectatorKeys set [4, false]};
		case 18: {WFBE_C_VAR_SpectatorKeys set [5, false]};
		case 200: {WFBE_C_VAR_SpectatorKeys set [6, false]};
		case 208: {WFBE_C_VAR_SpectatorKeys set [7, false]};
		case 57: {WFBE_C_VAR_SpectatorKeys set [8, false]};
		case 29: {WFBE_C_VAR_SpectatorKeys set [9, false]};
		case 157: {WFBE_C_VAR_SpectatorKeys set [9, false]};
	};
	false
};

_disp = findDisplay 46;
WFBE_C_VAR_SpectatorKeyDownIdx = _disp displayAddEventHandler ["KeyDown", "_this Call WFBE_CL_FNC_SpectatorKeyDown"];
WFBE_C_VAR_SpectatorKeyUpIdx = _disp displayAddEventHandler ["KeyUp", "_this Call WFBE_CL_FNC_SpectatorKeyUp"];

[_pos0, _yaw0] spawn {
	Private ["_p","_y","_pt","_k","_speed","_turnSpeed","_dt","_last","_tx","_ty","_tz","_body","_lockPos"];
	_p = _this select 0;
	_y = _this select 1;
	_pt = 0;
	_speed = 15; //--- m/s
	_turnSpeed = 90; //--- deg/s
	_body = WFBE_C_VAR_SpectatorBody;
	_lockPos = getPos _body; //--- keeps the parked body from drifting under the shared WASD keys; invisible to the spectating player (their view is the camera, not their own body).
	_last = time;
	while {WFBE_C_VAR_SpectatorActive && {!WFBE_gameover}} do {
		sleep 0.05;
		//--- Safety: auto-exit if the parked body died while unattended (allowDamage/setCaptive should
		//--- prevent this outright, but this loop is the last line of defence against a dangling camera).
		if (isNull _body || {!alive _body}) exitWith {[] Call WFBE_CL_FNC_SpectatorExit};
		_body setPos _lockPos;
		_dt = time - _last;
		_last = time;
		_k = WFBE_C_VAR_SpectatorKeys;
		if (_k select 4) then {_y = _y - _turnSpeed * _dt};
		if (_k select 5) then {_y = _y + _turnSpeed * _dt};
		if (_y < 0) then {_y = _y + 360};
		if (_y >= 360) then {_y = _y - 360};
		if (_k select 6) then {_pt = (_pt + _turnSpeed * _dt) min 80};
		if (_k select 7) then {_pt = (_pt - _turnSpeed * _dt) max -80};
		if (_k select 0) then {_p = [(_p select 0) + _speed * _dt * (sin _y), (_p select 1) + _speed * _dt * (cos _y), _p select 2]};
		if (_k select 1) then {_p = [(_p select 0) - _speed * _dt * (sin _y), (_p select 1) - _speed * _dt * (cos _y), _p select 2]};
		if (_k select 2) then {_p = [(_p select 0) - _speed * _dt * (cos _y), (_p select 1) + _speed * _dt * (sin _y), _p select 2]};
		if (_k select 3) then {_p = [(_p select 0) + _speed * _dt * (cos _y), (_p select 1) - _speed * _dt * (sin _y), _p select 2]};
		if (_k select 8) then {_p set [2, (_p select 2) + _speed * _dt]};
		if (_k select 9) then {_p set [2, (_p select 2) - _speed * _dt]};
		if !(isNull WFBE_C_VAR_SpectatorCam) then {
			WFBE_C_VAR_SpectatorCam camSetPos _p;
			_tx = (_p select 0) + 10 * (sin _y) * (cos _pt);
			_ty = (_p select 1) + 10 * (cos _y) * (cos _pt);
			_tz = (_p select 2) + 10 * (sin _pt);
			WFBE_C_VAR_SpectatorCam camSetTarget [_tx, _ty, _tz];
			WFBE_C_VAR_SpectatorCam camCommit 0;
		};
	};
};
