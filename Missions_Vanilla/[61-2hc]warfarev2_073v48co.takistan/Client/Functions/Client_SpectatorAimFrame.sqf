/* Client_SpectatorAimFrame.sqf  (spectator v8 DEFINITIVE rebuild, owner mandate 2026-08-01)
   THE ONE CAMERA WRITER. Runs via the mission's single onEachFrame slot while the spectator
   is active. This file is the ONLY writer of camSetPos / camSetTarget / camSetFov / camCommit
   in EVERY mode (free / follow / eyes / director). The scheduled loop in
   Client_SpectatorEnter.sqf owns MODE STATE and the parked body only; the 1s director poll in
   Client_SpectatorDirector.sqf owns SCORING and the SHOT SNAPSHOT only. Today's three live
   stomp bugs (position, then yaw, then pitch) were all two-writer conflicts between this
   handler and the scheduled loop - the loop's camera writes are DELETED, not guarded.
   Mouse handler keeps writing yaw/pitch (event-driven, free mode only); keys array is written
   by the KeyDown/KeyUp handlers; this file integrates them at render rate.
   DIRECTOR: consumes the stamped shot snapshot WFBE_C_VAR_SpectShot - a cut is a snapshot
   with a new cutId (hard set), a same-POI update keeps the cutId (eased standoff/aim = the
   continuous push-in / reframe channel). Orbit reveals are computed HERE from the snapshot
   timeline; the poll never drags the live camera.
   HARD RULES (unscheduled): no sleep / waitUntil; no Display handles (A2 serialization trap);
   null-guard every dereference; exit cheap when inactive. O(1) per frame.
   Registered ONLY here (single onEachFrame slot). A second registrant would silently replace
   this handler - if you ever add one, stack them. */
Private ["_now","_cam","_mode","_prev","_fdt","_vd","_hd"];
if (!(missionNamespace getVariable ["WFBE_C_VAR_SpectatorActive", false])) exitWith {};
_now = diag_tickTime;
WFBE_C_VAR_SpectatorAimFrameTick = _now;
_cam = missionNamespace getVariable ["WFBE_C_VAR_SpectatorCam", objNull];
if (isNull _cam) exitWith {};
_fdt = _now - (missionNamespace getVariable ["WFBE_C_VAR_SpectatorFreeLastT", _now]);
WFBE_C_VAR_SpectatorFreeLastT = _now;
_fdt = (_fdt max 0) min 0.2;
_mode = missionNamespace getVariable ["WFBE_C_VAR_SpectatorMode", "free"];
_prev = missionNamespace getVariable ["WFBE_C_VAR_SpectFramePrevMode", "-"];
if (_prev != _mode) then {
	WFBE_C_VAR_SpectFramePrevMode = _mode;
	if (_mode == "free") then {
		//--- hand the free-cam the camera's exact rendered pose - zero-frame seize, no snap.
		WFBE_C_VAR_SpectatorPos = getPos _cam;
		_vd = vectorDir _cam;
		_hd = sqrt (((_vd select 0) ^ 2) + ((_vd select 1) ^ 2));
		WFBE_C_VAR_SpectatorYaw = (((_vd select 0) atan2 (_vd select 1)) + 360) % 360;
		WFBE_C_VAR_SpectatorPitch = ((((_vd select 2) atan2 (_hd max 0.01))) max -80) min 80;
		WFBE_C_VAR_SpectatorFreeVel = [0,0,0];
		WFBE_C_VAR_SpectatorFovTarget = missionNamespace getVariable ["WFBE_C_VAR_SpectatorFov", 0.8];
	};
	if (_mode == "follow") then {WFBE_C_VAR_SpectFollowSeeded = false};
};
if (_mode == "free") then {
	//--- v5 P4 free-cam, render rate: velocity ease + position integrate + aim, all from globals.
	//--- The mouse handler owns yaw/pitch (event-driven); keys arrive via the KeyDown/KeyUp EHs.
	Private ["_k","_spd","_y","_pt","_cy","_sy","_cp","_sp","_fwd","_right","_wantVel","_accel","_accelF","_vel","_p"];
	_k = missionNamespace getVariable ["WFBE_C_VAR_SpectatorKeys", []];
	if ((count _k) >= 8) then {
		_spd = missionNamespace getVariable ["WFBE_C_SPECTATOR_SPEED", 15];
		if (_k select 6) then {_spd = _spd * (missionNamespace getVariable ["WFBE_C_SPECTATOR_BOOST", 4])};
		if (_k select 7) then {_spd = _spd * (missionNamespace getVariable ["WFBE_C_SPECTATOR_SLOW", 0.25])};
		_y = missionNamespace getVariable ["WFBE_C_VAR_SpectatorYaw", 0];
		_pt = missionNamespace getVariable ["WFBE_C_VAR_SpectatorPitch", 0];
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
		_p = missionNamespace getVariable ["WFBE_C_VAR_SpectatorPos", getPos _cam];
		_p = [(_p select 0) + (_vel select 0) * _fdt, (_p select 1) + (_vel select 1) * _fdt, (_p select 2) + (_vel select 2) * _fdt];
		WFBE_C_VAR_SpectatorPos = _p;
		_cam camSetPos _p;
		_cam camSetTarget [(_p select 0) + (_fwd select 0) * 100, (_p select 1) + (_fwd select 1) * 100, (_p select 2) + (_fwd select 2) * 100];
	};
};
if (_mode == "follow") then {
	Private ["_tgt","_kin","_subject","_subjectPos","_lead","_speed","_wantPos","_wantAim","_gk","_gf","_sp2","_sa2","_fovMin"];
	_tgt = missionNamespace getVariable ["WFBE_C_VAR_SpectatorTarget", objNull];
	if (!isNull _tgt && {alive _tgt}) then {
		//--- v8: full kinematic follow at render rate - no attachTo, no scheduled starvation, one writer.
		_kin = [_tgt, _fdt] Call WFBE_CL_FNC_SpectatorKinematics;
		_subject = _kin select 0;
		_subjectPos = _kin select 1;
		_lead = _kin select 2;
		_speed = _kin select 3;
		_wantPos = _subject modelToWorld [0, -8, 3];
		_wantPos = [(_wantPos select 0) + (_lead select 0), (_wantPos select 1) + (_lead select 1), (_wantPos select 2) + (_lead select 2)];
		_wantAim = [(_subjectPos select 0) + (_lead select 0), (_subjectPos select 1) + (_lead select 1), (_subjectPos select 2) + (_lead select 2) + 1.5];
		if (!(missionNamespace getVariable ["WFBE_C_VAR_SpectFollowSeeded", false]) || {(missionNamespace getVariable ["WFBE_C_VAR_SpectFollowTgt", objNull]) != _tgt}) then {
			//--- target switch = a cut: snap, never ease across it.
			WFBE_C_VAR_SpectFollowSeeded = true;
			WFBE_C_VAR_SpectFollowTgt = _tgt;
			WFBE_C_VAR_SpectFollowPos = _wantPos;
			WFBE_C_VAR_SpectFollowAim = _wantAim;
			WFBE_C_VAR_SpectatorVelEma = velocity _subject;
		};
		_gk = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_SMOOTHING", 5];
		if (_speed > 8) then {_gk = _gk * (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_FAST_GAIN_MULT", 2.5])};
		_gf = ((_gk * _fdt) min 1) max 0;
		_sp2 = missionNamespace getVariable ["WFBE_C_VAR_SpectFollowPos", _wantPos];
		_sa2 = missionNamespace getVariable ["WFBE_C_VAR_SpectFollowAim", _wantAim];
		_sp2 = [(_sp2 select 0) + (((_wantPos select 0) - (_sp2 select 0)) * _gf), (_sp2 select 1) + (((_wantPos select 1) - (_sp2 select 1)) * _gf), (_sp2 select 2) + (((_wantPos select 2) - (_sp2 select 2)) * _gf)];
		_sa2 = [(_sa2 select 0) + (((_wantAim select 0) - (_sa2 select 0)) * _gf), (_sa2 select 1) + (((_wantAim select 1) - (_sa2 select 1)) * _gf), (_sa2 select 2) + (((_wantAim select 2) - (_sa2 select 2)) * _gf)];
		WFBE_C_VAR_SpectFollowPos = _sp2;
		WFBE_C_VAR_SpectFollowAim = _sa2;
		_cam camSetPos _sp2;
		_cam camSetTarget _sa2;
		_fovMin = 0;
		if (!(_subject isKindOf "Man")) then {
			_fovMin = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_VEH_FOV_MIN", 0.55];
			if (_subject isKindOf "Air") then {_fovMin = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_AIR_FOV_MIN", 0.45]};
		};
		if (_fovMin > 0) then {
			if ((missionNamespace getVariable ["WFBE_C_VAR_SpectatorFovTarget", 0.8]) < _fovMin) then {WFBE_C_VAR_SpectatorFovTarget = _fovMin};
			if ((missionNamespace getVariable ["WFBE_C_VAR_SpectatorFov", 0.8]) < _fovMin) then {WFBE_C_VAR_SpectatorFov = _fovMin};
		};
	};
};
if (_mode == "eyes") then {
	Private ["_tgt","_e","_d"];
	_tgt = missionNamespace getVariable ["WFBE_C_VAR_SpectatorTarget", objNull];
	if (!isNull _tgt && {alive _tgt}) then {
		_e = eyePos _tgt;
		_d = eyeDirection _tgt;
		_cam camSetPos _e;
		_cam camSetTarget [(_e select 0) + (_d select 0) * 100, (_e select 1) + (_d select 1) * 100, (_e select 2) + (_d select 2) * 100];
	};
};
if (_mode == "director") then {
	Private ["_shot","_cut","_center","_standT","_hgtT","_gain","_stand","_hgt","_aimT","_aim","_agn","_ang","_odir","_ost","_osw","_prog","_pos"];
	_shot = missionNamespace getVariable ["WFBE_C_VAR_SpectShot", []];
	if ((count _shot) >= 16) then {
		_cut = _shot select 0;
		_center = _shot select 2;
		_aimT = _shot select 3;
		_standT = _shot select 4;
		_hgtT = _shot select 5;
		if ((missionNamespace getVariable ["WFBE_C_VAR_SpectFrameCut", -1]) != _cut) then {
			//--- NEW POI = hard cut: snap every eased channel to the stamped values.
			WFBE_C_VAR_SpectFrameCut = _cut;
			WFBE_C_VAR_SpectFrameStand = _standT;
			WFBE_C_VAR_SpectFrameHgt = _hgtT;
			WFBE_C_VAR_SpectFrameAim = [_aimT select 0, _aimT select 1, _aimT select 2];
		};
		//--- same-POI snapshot updates (escalation push-in, 12s reframe) ease in continuously.
		_gain = ((missionNamespace getVariable ["WFBE_C_SPECTATOR_FRAME_STAND_GAIN", 0.6]) * _fdt) min 1;
		_stand = missionNamespace getVariable ["WFBE_C_VAR_SpectFrameStand", _standT];
		_stand = _stand + ((_standT - _stand) * _gain);
		WFBE_C_VAR_SpectFrameStand = _stand;
		_hgt = missionNamespace getVariable ["WFBE_C_VAR_SpectFrameHgt", _hgtT];
		_hgt = _hgt + ((_hgtT - _hgt) * _gain);
		WFBE_C_VAR_SpectFrameHgt = _hgt;
		_agn = ((missionNamespace getVariable ["WFBE_C_SPECTATOR_FRAME_AIM_GAIN", 2.5]) * _fdt) min 1;
		_aim = missionNamespace getVariable ["WFBE_C_VAR_SpectFrameAim", _aimT];
		_aim = [(_aim select 0) + (((_aimT select 0) - (_aim select 0)) * _agn), (_aim select 1) + (((_aimT select 1) - (_aim select 1)) * _agn), (_aim select 2) + (((_aimT select 2) - (_aim select 2)) * _agn)];
		WFBE_C_VAR_SpectFrameAim = _aim;
		//--- orbit reveal: computed from the snapshot timeline - the poll never drags the camera.
		_ang = _shot select 11;
		_odir = _shot select 8;
		if (_odir != 0) then {
			_ost = _shot select 9;
			if (time >= _ost) then {
				_osw = _shot select 10;
				_prog = (time - _ost) * (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_ORBIT_REVEAL_RATE", 6]);
				if (_prog > _osw) then {_prog = _osw};
				_ang = _ang + (_odir * _prog);
			};
		};
		_pos = [(_center select 0) + (_stand * sin _ang), (_center select 1) + (_stand * cos _ang), (_center select 2) + _hgt];
		_cam camSetPos _pos;
		_cam camSetTarget _aim;
	};
};
//--- unified FOV: the director snapshot drives zoom while auto is live (unless the wheel
//--- locked it recently); every other mode eases toward the wheel target.
Private ["_targetFov","_fovRate","_fovStep","_fovDelta","_fov","_dirDrives","_shotF"];
_fov = missionNamespace getVariable ["WFBE_C_VAR_SpectatorFov", 0.8];
_targetFov = missionNamespace getVariable ["WFBE_C_VAR_SpectatorFovTarget", _fov];
_fovRate = missionNamespace getVariable ["WFBE_C_SPECTATOR_ZOOM_RATE", 8];
_dirDrives = false;
if (_mode == "director" && {(time - (missionNamespace getVariable ["WFBE_C_VAR_SpectatorLastManualZoom", 0])) >= (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_MANUAL_ZOOM_LOCK_SEC", 10])}) then {
	_shotF = missionNamespace getVariable ["WFBE_C_VAR_SpectShot", []];
	if ((count _shotF) >= 16) then {
		_targetFov = _shotF select 6;
		_fovRate = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_FOV_RATE", 0.35];
		_dirDrives = true;
	};
};
if (_dirDrives) then {
	WFBE_C_VAR_SpectFovWasDir = true;
} else {
	if (missionNamespace getVariable ["WFBE_C_VAR_SpectFovWasDir", false]) then {
		//--- leaving director-driven zoom: hand manual zoom off from where the director left it.
		WFBE_C_VAR_SpectatorFovTarget = _fov;
		_targetFov = _fov;
	};
	WFBE_C_VAR_SpectFovWasDir = false;
};
_fovStep = _fovRate * _fdt;
_fovDelta = _targetFov - _fov;
if (abs _fovDelta > _fovStep) then {
	if (_fovDelta > 0) then {_fov = _fov + _fovStep} else {_fov = _fov - _fovStep};
} else {
	_fov = _targetFov;
};
WFBE_C_VAR_SpectatorFov = _fov;
_cam camSetFov _fov;
_cam camCommit 0;
