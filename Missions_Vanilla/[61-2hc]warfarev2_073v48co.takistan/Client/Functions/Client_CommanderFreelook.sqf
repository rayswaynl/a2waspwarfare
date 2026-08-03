/*
	Client_CommanderFreelook.sqf

	Commander free-flying recon camera (fable/cmd-troopmon-freelook). This is its OWN module - own
	camera object, own keys, own teardown - independent of the Spectator v8 lane; it never reads or
	calls anything in Client_SpectatorEnter/Director/Attach/Exit.sqf.

	Gate: WFBE_C_COMMANDER_CAM (default 0). Commander-only; re-checked every tick (not just on entry)
	so losing the commander seat mid-flight tears the camera down immediately.

	Movement scheme (deliberately NOT relative to where the mouse is looking - see note below):
	  W/A/S/D  -> move north/west/south/east in FIXED world directions at WFBE_C_COMMANDER_CAM_SPEED
	              (WFBE_C_COMMANDER_CAM_SPEED_FAST while LSHIFT/RSHIFT is held).
	  SPACE    -> climb  |  LCTRL/RCTRL -> descend, clamped to [2m, WFBE_C_COMMANDER_CAM_MAX_ALT] above
	              the terrain directly under the camera at all times. A2 OA has no getTerrainHeightASL
	              (see Common_AICOM_HeliTerrainGuard.sqf's own header) - this feature sidesteps needing
	              that command at all by tracking altitude as a running height-above-ground OFFSET
	              (camSetPos's third element, the same 'height above ground' semantics plain setPos
	              uses) instead of ever sampling the terrain.
	  ESC      -> clean return-to-body (also fires on death, losing commander status, or the flag
	              flipping to 0 mid-flight).
	The KeyDown handler CONSUMES (returns true for) every key it recognises, so the parked player
	body never also walks/jumps under the same WASD/SPACE/CTRL input while the camera flies - the
	same lesson already documented in this repo's Client_SpectatorEnter.sqf header: disableUserInput
	is deliberately NOT used, since a script failure while it is set would leave a player unable to
	act at all (unrecoverable on a live server); per-key consumption degrades safely instead - worst
	case on a stuck handler is a body that can still move/fight, not one that is locked solid.
	Mouse free-look needs no scripting: a camCreate camera with cameraEffect ["internal","back"] and
	no camCommand "MANUAL" already free-looks with the mouse - the same long-standing OFP/A2 'watch'
	camera technique already used repo-wide (GUI_Menu_Tactical.sqf, Client_OnKilled.sqf death camera,
	Client_SpectatorEnter.sqf's own header comment cites the identical cam* command family as A2-OA-
	1.64 safe). WASP has no existing FREE-FLYING (player-steered) camera to point to, though, so BOOT-
	TEST the fly feel before flipping WFBE_C_COMMANDER_CAM past 0 (see PR test plan).

	The player's own body stays fully simulated (not invulnerable, not frozen) while the camera is
	active - this is a look-around tool for a commander sitting somewhere safe, not a god-mode.
*/

if ((missionNamespace getVariable ["WFBE_C_COMMANDER_CAM", 0]) <= 0) exitWith {};
if (!isNil "WFBE_CommanderCam_Active" && {WFBE_CommanderCam_Active}) exitWith {
	hintSilent parseText "<t color='#F8D664'>Recon camera is already active.</t>";
};

private "_ct0"; _ct0 = commanderTeam;
if (isNil "_ct0" || {isNull _ct0} || {_ct0 != group player}) exitWith {
	hintSilent parseText "<t color='#F8D664'>Only the side commander can use the recon camera.</t>";
};

WFBE_CommanderCam_Active = true;
WFBE_FreelookKey_Fwd = false;
WFBE_FreelookKey_Back = false;
WFBE_FreelookKey_Left = false;
WFBE_FreelookKey_Right = false;
WFBE_FreelookKey_Up = false;
WFBE_FreelookKey_Down = false;
WFBE_FreelookKey_Fast = false;
WFBE_FreelookKey_Exit = false;

private ["_startPos","_cam","_disp","_dh1","_dh2","_spd","_spdFast","_maxAlt","_px","_py","_pz"];
_startPos = getPos player;
_px = _startPos select 0;
_py = _startPos select 1;
_pz = 20;

_cam = "camera" camCreate [_px, _py, _pz];
_cam cameraEffect ["Internal", "Back"];
_cam camSetFov 0.700;
_cam camSetDir (getDir player);
_cam camCommit 0;

_disp = findDisplay 46;
_dh1 = _disp displayAddEventHandler ["KeyDown", "
	private ['_k','_used']; _k = _this select 1;
	_used = _k in [17,31,30,32,57,29,157,42,54,1];
	if (_k == 17) then {WFBE_FreelookKey_Fwd = true};
	if (_k == 31) then {WFBE_FreelookKey_Back = true};
	if (_k == 30) then {WFBE_FreelookKey_Left = true};
	if (_k == 32) then {WFBE_FreelookKey_Right = true};
	if (_k == 57) then {WFBE_FreelookKey_Up = true};
	if (_k == 29 || _k == 157) then {WFBE_FreelookKey_Down = true};
	if (_k == 42 || _k == 54) then {WFBE_FreelookKey_Fast = true};
	if (_k == 1) then {WFBE_FreelookKey_Exit = true};
	_used
"];
_dh2 = _disp displayAddEventHandler ["KeyUp", "
	private ['_k']; _k = _this select 1;
	if (_k == 17) then {WFBE_FreelookKey_Fwd = false};
	if (_k == 31) then {WFBE_FreelookKey_Back = false};
	if (_k == 30) then {WFBE_FreelookKey_Left = false};
	if (_k == 32) then {WFBE_FreelookKey_Right = false};
	if (_k == 57) then {WFBE_FreelookKey_Up = false};
	if (_k == 29 || _k == 157) then {WFBE_FreelookKey_Down = false};
	if (_k == 42 || _k == 54) then {WFBE_FreelookKey_Fast = false};
	false
"];

hintSilent parseText "<t color='#A0E060'>Recon camera:</t> WASD fly, SPACE/CTRL climb-descend, SHIFT sprint, ESC to return.";

_spd = missionNamespace getVariable ["WFBE_C_COMMANDER_CAM_SPEED", 25];
_spdFast = missionNamespace getVariable ["WFBE_C_COMMANDER_CAM_SPEED_FAST", 75];
_maxAlt = missionNamespace getVariable ["WFBE_C_COMMANDER_CAM_MAX_ALT", 400];

while {WFBE_CommanderCam_Active} do {
	private ["_ctN","_step","_curSpd","_mvN","_mvE","_mvU"];
	if (!alive player) exitWith {WFBE_CommanderCam_Active = false};
	if ((missionNamespace getVariable ["WFBE_C_COMMANDER_CAM", 0]) <= 0) exitWith {WFBE_CommanderCam_Active = false};
	_ctN = commanderTeam;
	if (isNil "_ctN" || {isNull _ctN} || {_ctN != group player}) exitWith {WFBE_CommanderCam_Active = false};
	if (WFBE_FreelookKey_Exit) exitWith {WFBE_CommanderCam_Active = false};

	_step = 0.05;
	_curSpd = if (WFBE_FreelookKey_Fast) then {_spdFast} else {_spd};
	_mvN = 0; _mvE = 0; _mvU = 0;
	if (WFBE_FreelookKey_Fwd)   then {_mvN = _mvN + 1};
	if (WFBE_FreelookKey_Back)  then {_mvN = _mvN - 1};
	if (WFBE_FreelookKey_Right) then {_mvE = _mvE + 1};
	if (WFBE_FreelookKey_Left)  then {_mvE = _mvE - 1};
	if (WFBE_FreelookKey_Up)    then {_mvU = _mvU + 1};
	if (WFBE_FreelookKey_Down)  then {_mvU = _mvU - 1};

	if (_mvN != 0 || {_mvE != 0} || {_mvU != 0}) then {
		_px = _px + (_mvE * _curSpd * _step);
		_py = _py + (_mvN * _curSpd * _step);
		_pz = _pz + (_mvU * _curSpd * _step);
		if (_pz < 2) then {_pz = 2};
		if (_pz > _maxAlt) then {_pz = _maxAlt};
		_cam camSetPos [_px, _py, _pz];
		_cam camCommit 0;
	};
	sleep _step;
};

//--- Clean teardown: every exit path above (ESC, death, flag-off, lost commander) falls through to here.
WFBE_CommanderCam_Active = false;
_disp displayRemoveEventHandler ["KeyDown", _dh1];
_disp displayRemoveEventHandler ["KeyUp", _dh2];
_cam cameraEffect ["Terminate", "Back"];
camDestroy _cam;
if (alive player) then {((player) Call GetUnitVehicle) switchCamera "Internal"};
hintSilent parseText "<t color='#A0E060'>Recon camera: returned to your body.</t>";
