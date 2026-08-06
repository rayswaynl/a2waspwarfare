/* Client_SpectatorExit.sqf
   fable/spectator-v1 -> v2 (owner request 2026-07-29: caster-grade watch tool)
   -------------------------------------------------------------------------
   Exits the spectator overlay and restores everything: camera terminated +
   destroyed, the parked body's allowDamage/setCaptive restored, ALL display
   handlers detached (v2 adds MouseMoving/MouseZChanged to v1's KeyDown/KeyUp),
   the hint overlay cleared, view returned to the player. addAction target (see
   Client_SpectatorAttach.sqf), Backspace quick-exit target, and the internal
   (The UID allowlist controls ACTION VISIBILITY on this client only under standard
   A2 locality; it is not server-enforced authentication or authorization.)
   auto-exit for the movement loop's death watchdog in Client_SpectatorEnter.sqf.

   Idempotent: safe to call more than once (e.g. Backspace right as the death
   watchdog also fires) - the leading guard makes every call after the first a
   no-op.
*/
Private ["_body"];

if !(missionNamespace getVariable ["WFBE_C_VAR_SpectatorActive", false]) exitWith {}; //--- already exited / never entered.
if ((missionNamespace getVariable ["WFBE_C_VAR_SpectatorMode", "free"]) == "director") then {
	diag_log "SPECTATE|v3|mode-off|reason=exit";
};
WFBE_C_VAR_SpectatorActive = false; //--- first: stops the movement loop in Client_SpectatorEnter.sqf on its next tick.

_body = missionNamespace getVariable ["WFBE_C_VAR_SpectatorBody", objNull];

diag_log Format ["SPECTATE|v2|exit|uid=%1", getPlayerUID player];

//--- v5 P1: release the frame-aim handler and the attach BEFORE destroying the camera. The
//--- onEachFrame body self-guards on SpectatorActive, but leaving a dead handler registered
//--- costs a call per frame forever - clear it (guarded: only if we armed it this session).
if (missionNamespace getVariable ["WFBE_C_VAR_SpectatorFrameAimArmed", false]) then {
	onEachFrame {};
	WFBE_C_VAR_SpectatorFrameAimArmed = false;
};
WFBE_C_VAR_SpectatorAttachedTo = objNull;
WFBE_C_VAR_SpectatorAimGoal = [];
WFBE_C_VAR_SpectatorAimCur = [];
if (!isNil "WFBE_C_VAR_SpectatorCam" && {!isNull WFBE_C_VAR_SpectatorCam}) then {
	detach WFBE_C_VAR_SpectatorCam;
	WFBE_C_VAR_SpectatorCam cameraEffect ["TERMINATE", "BACK"];
	camDestroy WFBE_C_VAR_SpectatorCam;
};
WFBE_C_VAR_SpectatorCam = objNull;

if (!isNil "WFBE_C_VAR_SpectatorKeyDownIdx") then {
	(findDisplay 46) displayRemoveEventHandler ["KeyDown", WFBE_C_VAR_SpectatorKeyDownIdx];
	WFBE_C_VAR_SpectatorKeyDownIdx = nil;
};
if (!isNil "WFBE_C_VAR_SpectatorKeyUpIdx") then {
	(findDisplay 46) displayRemoveEventHandler ["KeyUp", WFBE_C_VAR_SpectatorKeyUpIdx];
	WFBE_C_VAR_SpectatorKeyUpIdx = nil;
};
if (!isNil "WFBE_C_VAR_SpectatorMouseMovingIdx") then {
	(findDisplay 46) displayRemoveEventHandler ["MouseMoving", WFBE_C_VAR_SpectatorMouseMovingIdx];
	WFBE_C_VAR_SpectatorMouseMovingIdx = nil;
};
if (!isNil "WFBE_C_VAR_SpectatorWheelIdx") then {
	(findDisplay 46) displayRemoveEventHandler ["MouseZChanged", WFBE_C_VAR_SpectatorWheelIdx];
	WFBE_C_VAR_SpectatorWheelIdx = nil;
};

hintSilent ""; //--- v2: clear the hint overlay even if it was mid-update.
if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_BROADCAST_HUD", 0]) > 0) then {
	if (dialog) then {closeDialog 0};
	12456 cutText ["", "PLAIN", 0];
};
12455 cutText ["", "PLAIN", 0]; //--- clear the legacy cutText card layer; the broadcast path uses 12456.
WFBE_C_VAR_SpectatorCardLast = ""; //--- reset the redraw cache for the next session (flicker fix, merged)

WFBE_C_VAR_SpectatorMode = "free";
WFBE_C_VAR_SpectatorTarget = objNull;
WFBE_C_VAR_SpectatorHideHint = false;
//--- v8: clear the shot snapshot + director track state for the next session.
WFBE_C_VAR_SpectShot = [];
WFBE_C_VAR_DirTracks = [];
WFBE_C_VAR_DirTownEv = [];
WFBE_C_VAR_DirCurKey = "";
WFBE_C_VAR_DirCurKind = "";
WFBE_C_VAR_DirCurTown = objNull;

if (!isNull _body) then {
	if (alive _body) then {_body allowDamage true};
	_body setCaptive false;
};

systemChat "[WASP] Spectator camera: exited.";
