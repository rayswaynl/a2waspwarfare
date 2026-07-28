/*
	Casting mode - free-flying observer camera for a caster / streamer.

	Flags: WFBE_C_CASTER_MODE  (default 0)  - master gate.
	       WFBE_C_CASTER_UIDS  (default []) - Steam64 allowlist. Empty = nobody, so arming
	                                          the master flag alone grants nothing.

	NO NEW SLOT, NO ENROLMENT CHANGE. The caster joins a normal slot and enrols through the
	stock Warfare path exactly like any other player, then opts out client-side. Nothing in
	the join / JIP / enrolment flow is touched, mission.sqm is untouched on all three
	terrains, WF_MAXPLAYERS is unchanged, and Tools/Ops/Test-WaspSlotCountConsistency.ps1
	stays green. The cost of that choice is that casting occupies one real player slot.

	NO BODY PROTECTION - DELIBERATE. This never calls allowDamage, setPos, hideObject or
	enableSimulation. A camera that made the body invulnerable would be a press-a-key
	godmode: enter casting under fire, survive, leave. Instead the body is simply left where
	the caster parked it, still mortal, and the caster is told to park in base before
	starting. If the body dies mid-cast the camera keeps running - a caster has nothing to
	lose by dying, so there is no incentive to abuse it either way.

	CAMERA IDIOM. camCreate + cameraEffect only, never switchCamera, so
	limitThirdPersonView.sqf (the 1s "GROUP" anti-cheat poll) is not touched by this feature.

	NO MOUSE-LOOK DEPENDENCY. Aim is keyboard yaw (A/D) driving a computed camSetTarget
	look-at point, because mouse-look on a bare camCreate camera without the vanilla
	construction-camera wrapper is unverified on OA 1.64 and there is no client here to test it.
*/

Private ["_cam","_uids","_uid","_px","_py","_pz","_yaw","_spd","_look","_tgt","_targets","_idx","_lastHud","_hud"];

if ((missionNamespace getVariable ["WFBE_C_CASTER_MODE", 0]) <= 0) exitWith {};

//--- Toggle off if already casting: the loop below owns teardown.
if (!isNil "WFBE_Caster_Active" && {WFBE_Caster_Active}) exitWith {
	WFBE_Caster_Active = false;
};

_uids = missionNamespace getVariable ["WFBE_C_CASTER_UIDS", []];
_uid = getPlayerUID player;
if (!(_uid in _uids)) exitWith {
	hintSilent parseText "<t color='#F8D664'>Casting mode is not enabled for this account.</t>";
	["INFORMATION", Format ["Client_CasterMode.sqf: casting DENIED for uid %1 (not in WFBE_C_CASTER_UIDS).", _uid]] Call WFBE_CO_FNC_LogContent;
};

_cam = "camera" camCreate (getPos player);
if (isNil "_cam") exitWith {
	["WARNING", "Client_CasterMode.sqf: camCreate failed - casting not started."] Call WFBE_CO_FNC_LogContent;
};

WFBE_Caster_Active = true;
WFBE_Caster_Fwd = 0;
WFBE_Caster_Side = 0;
WFBE_Caster_Up = 0;
WFBE_Caster_Turn = 0;
WFBE_Caster_Fast = false;
WFBE_Caster_Follow = objNull;
WFBE_Caster_CycleStep = 0;

_px = (getPos player) select 0;
_py = (getPos player) select 1;
_pz = ((getPos player) select 2) + 25;
_yaw = getDir player;
_lastHud = "";

_cam camSetFov 0.7;
_cam cameraEffect ["Internal", "BACK"];
cameraEffectEnableHUD true;

["INFORMATION", Format ["Client_CasterMode.sqf: casting ENGAGED for uid %1.", _uid]] Call WFBE_CO_FNC_LogContent;
hintSilent parseText "<t size='1.1' color='#D9763C'>CASTING</t><br/><t size='0.8'>W/S fly   A/D turn   Q/E height   Shift boost<br/>Tab follow next   F release follow   F9 exit</t>";

while {WFBE_Caster_Active} do {
	_spd = if (WFBE_Caster_Fast) then {14} else {4};

	//--- Follow-target cycling. Players first, then any live unit already in the roster.
	if (WFBE_Caster_CycleStep != 0) then {
		_targets = [];
		{
			if (alive _x && {isPlayer _x}) then {_targets set [count _targets, _x]};
		} forEach playableUnits;
		if (count _targets > 0) then {
			_idx = _targets find WFBE_Caster_Follow;
			_idx = _idx + WFBE_Caster_CycleStep;
			if (_idx < 0) then {_idx = (count _targets) - 1};
			if (_idx > ((count _targets) - 1)) then {_idx = 0};
			WFBE_Caster_Follow = _targets select _idx;
		};
		WFBE_Caster_CycleStep = 0;
	};

	_tgt = WFBE_Caster_Follow;
	if (!isNull _tgt && {!(alive _tgt)}) then {_tgt = objNull; WFBE_Caster_Follow = objNull};

	if (isNull _tgt) then {
		//--- Free flight: keyboard yaw, computed look-at point ahead of the camera.
		_yaw = _yaw + (WFBE_Caster_Turn * 3);
		if (_yaw < 0) then {_yaw = _yaw + 360};
		if (_yaw >= 360) then {_yaw = _yaw - 360};
		_px = _px + (((sin _yaw) * WFBE_Caster_Fwd) + ((cos _yaw) * WFBE_Caster_Side)) * _spd;
		_py = _py + (((cos _yaw) * WFBE_Caster_Fwd) - ((sin _yaw) * WFBE_Caster_Side)) * _spd;
		_pz = _pz + (WFBE_Caster_Up * _spd);
		if (_pz < 2) then {_pz = 2};
		_look = [_px + ((sin _yaw) * 100), _py + ((cos _yaw) * 100), _pz - 8];
		_cam camSetPos [_px, _py, _pz];
		_cam camSetTarget _look;
		_hud = "free";
	} else {
		//--- Follow: park behind the subject and look at it. Q/E still trims height.
		_pz = _pz + (WFBE_Caster_Up * _spd);
		_yaw = getDir _tgt;
		_px = ((getPos _tgt) select 0) - ((sin _yaw) * 12);
		_py = ((getPos _tgt) select 1) - ((cos _yaw) * 12);
		_cam camSetPos [_px, _py, ((getPos _tgt) select 2) + 4];
		_cam camSetTarget _tgt;
		_hud = Format ["following %1", name _tgt];
	};

	_cam camCommit 0;

	if (_hud != _lastHud) then {
		_lastHud = _hud;
		hintSilent parseText Format ["<t size='1.1' color='#D9763C'>CASTING</t><br/><t size='0.85'>%1</t><br/><t size='0.75'>Tab follow next   F release   F9 exit</t>", _hud];
	};

	sleep 0.05;
};

//--- Teardown: single exit path, so the camera can never outlive the mode.
hintSilent "";
_cam cameraEffect ["Terminate", "BACK"];
camDestroy _cam;
WFBE_Caster_Follow = objNull;
["INFORMATION", "Client_CasterMode.sqf: casting RELEASED."] Call WFBE_CO_FNC_LogContent;
