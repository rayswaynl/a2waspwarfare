/* Client_SpectatorAimFrame.sqf  (spectator v5 P1 - council C8 verdict 2026-08-01, 4/4 APPROVE)
   UNSCHEDULED aim easing, run via onEachFrame every render frame while the spectator is active.
   Position is engine-driven (camera attachTo subject vehicle - see Client_SpectatorEnter.sqf
   follow case); this file owns ONLY the eased camSetTarget for the attached follow mode.
   HARD RULES (unscheduled): no sleep / waitUntil / spawn-heavy work; no Display handles
   (A2 serialization trap); null-guard every dereference; exit cheap when inactive.
   LIVENESS CONTRACT: stamps WFBE_C_VAR_SpectatorAimFrameTick every frame. The scheduled
   movement loop treats a stale stamp (>1s old) as frame-aim-dead and falls back to the v4
   scheduled aim path - so an unavailable/lost onEachFrame degrades gracefully (council
   failure-mode 1) instead of leaving a frozen aim.
   Registered ONLY here (repo-wide grep: no other onEachFrame user). A second registrant
   would silently replace this handler - if you ever add one, stack them (council FM 5). */
Private ["_now","_dt","_goal","_cur","_gain"];
if (!(missionNamespace getVariable ["WFBE_C_VAR_SpectatorActive", false])) exitWith {};
_now = diag_tickTime;
WFBE_C_VAR_SpectatorAimFrameTick = _now;
if (isNull (missionNamespace getVariable ["WFBE_C_VAR_SpectatorCam", objNull])) exitWith {};
//--- v5 P4 (owner: "player controlled camera is still absolute garbage quality to control"):
//--- the free-cam used to be integrated in the SCHEDULED loop - same starvation the council
//--- diagnosed for follow aim (10-30Hz irregular under load) while the mouse writes yaw/pitch
//--- instantly. The free-cam now lives HERE at render rate: velocity ease + position integrate
//--- + aim, all from globals. The scheduled loop skips its own free-cam writes while the
//--- liveness stamp is fresh (same graceful-degrade contract as follow aim).
if ((missionNamespace getVariable ["WFBE_C_VAR_SpectatorMode", "free"]) == "free" && {(missionNamespace getVariable ["WFBE_C_SPECTATOR_FREECAM_FRAME", 1]) > 0}) exitWith {
	Private ["_fdt","_k","_spd","_y","_pt","_cy","_sy","_cp","_sp","_fwd","_right","_wantVel","_accel","_accelF","_vel","_p"];
	_fdt = _now - (missionNamespace getVariable ["WFBE_C_VAR_SpectatorFreeLastT", _now]);
	WFBE_C_VAR_SpectatorFreeLastT = _now;
	_fdt = (_fdt max 0) min 0.2;
	_k = missionNamespace getVariable ["WFBE_C_VAR_SpectatorKeys", []];
	if ((count _k) < 8) exitWith {};
	_spd = missionNamespace getVariable ["WFBE_C_SPECTATOR_SPEED", 15];
	if (_k select 6) then {_spd = _spd * (missionNamespace getVariable ["WFBE_C_SPECTATOR_BOOST", 4])};
	if (_k select 7) then {_spd = _spd * (missionNamespace getVariable ["WFBE_C_SPECTATOR_SLOW", 0.25])};
	_y = WFBE_C_VAR_SpectatorYaw;
	_pt = WFBE_C_VAR_SpectatorPitch;
	_cy = cos _y; _sy = sin _y; _cp = cos _pt; _sp = sin _pt;
	_fwd = [_sy * _cp, _cy * _cp, _sp];
	_right = [_cy, -_sy, 0];
	_wantVel = [0,0,0];
	if (_k select 0) then {_wantVel = [(_wantVel select 0) + (_fwd select 0) * _spd, (_wantVel select 1) + (_fwd select 1) * _spd, (_wantVel select 2) + (_fwd select 2) * _spd]};
	if (_k select 1) then {_wantVel = [(_wantVel select 0) - (_fwd select 0) * _spd, (_wantVel select 1) - (_fwd select 1) * _spd, (_wantVel select 2) - (_fwd select 2) * _spd]};
	if (_k select 3) then {_wantVel = [(_wantVel select 0) + (_right select 0) * _spd, (_wantVel select 1) + (_right select 1) * _spd, _wantVel select 2]};
	if (_k select 2) then {_wantVel = [(_wantVel select 0) - (_right select 0) * _spd, (_wantVel select 1) - (_right select 1) * _spd, _wantVel select 2]};
	if (_k select 4) then {_wantVel set [2, (_wantVel select 2) + _spd]};
	if (_k select 5) then {_wantVel set [2, (_wantVel select 2) - _spd]};
	_accel = missionNamespace getVariable ["WFBE_C_SPECTATOR_ACCEL", 6];
	if ((_wantVel select 0) == 0 && {(_wantVel select 1) == 0} && {(_wantVel select 2) == 0}) then {_accel = missionNamespace getVariable ["WFBE_C_SPECTATOR_BRAKE", 9]};
	_accelF = ((_accel * _fdt) min 1) max 0;
	_vel = missionNamespace getVariable ["WFBE_C_VAR_SpectatorFreeVel", [0,0,0]];
	_vel = [(_vel select 0) + (((_wantVel select 0) - (_vel select 0)) * _accelF), (_vel select 1) + (((_wantVel select 1) - (_vel select 1)) * _accelF), (_vel select 2) + (((_wantVel select 2) - (_vel select 2)) * _accelF)];
	WFBE_C_VAR_SpectatorFreeVel = _vel;
	_p = WFBE_C_VAR_SpectatorPos;
	_p = [(_p select 0) + (_vel select 0) * _fdt, (_p select 1) + (_vel select 1) * _fdt, (_p select 2) + (_vel select 2) * _fdt];
	WFBE_C_VAR_SpectatorPos = _p;
	WFBE_C_VAR_SpectatorCam camSetPos _p;
	WFBE_C_VAR_SpectatorCam camSetTarget [(_p select 0) + (_fwd select 0) * 100, (_p select 1) + (_fwd select 1) * 100, (_p select 2) + (_fwd select 2) * 100];
	WFBE_C_VAR_SpectatorCam camCommit 0;
};
if ((missionNamespace getVariable ["WFBE_C_VAR_SpectatorMode", "free"]) != "follow") exitWith {};
if (isNull (missionNamespace getVariable ["WFBE_C_VAR_SpectatorAttachedTo", objNull])) exitWith {};
_goal = missionNamespace getVariable ["WFBE_C_VAR_SpectatorAimGoal", []];
if ((count _goal) < 3) exitWith {};
//--- engine-seat sign-off condition: explicit per-frame dt capture, clamped so an alt-tab or
//--- load hitch cannot slew the aim in one giant step (frame-rate-independent easing).
_dt = _now - (missionNamespace getVariable ["WFBE_C_VAR_SpectatorAimLastT", _now]);
WFBE_C_VAR_SpectatorAimLastT = _now;
_dt = (_dt max 0) min 0.2;
_cur = missionNamespace getVariable ["WFBE_C_VAR_SpectatorAimCur", []];
if ((count _cur) < 3) then {_cur = _goal};
//--- time-constant ~1/rate s (default 3.5 -> ~0.29s), inside the council 0.25-0.4s aim band.
_gain = (((missionNamespace getVariable ["WFBE_C_SPECTATOR_AIM_RATE", 3.5]) * _dt) min 1) max 0;
_cur = [
	(_cur select 0) + (((_goal select 0) - (_cur select 0)) * _gain),
	(_cur select 1) + (((_goal select 1) - (_cur select 1)) * _gain),
	(_cur select 2) + (((_goal select 2) - (_cur select 2)) * _gain)
];
WFBE_C_VAR_SpectatorAimCur = _cur;
WFBE_C_VAR_SpectatorCam camSetTarget _cur;
WFBE_C_VAR_SpectatorCam camCommit 0;
