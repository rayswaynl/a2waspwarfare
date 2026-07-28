/* Client_SpectatorExit.sqf
   fable/spectator-v1 (owner request 2026-07-28: spectator mode, owner first)
   -------------------------------------------------------------------------
   Exits the free-camera spectator overlay and restores everything: camera
   terminated + destroyed, the parked body's allowDamage/setCaptive
   restored, keyboard handlers detached, view returned to the player.
   addAction target (see Client_SpectatorAttach.sqf) - also called
   internally by the movement loop's death watchdog in
   Client_SpectatorEnter.sqf so a mid-session death auto-exits safely
   instead of leaving a dangling camera.

   Idempotent: safe to call more than once (e.g. a player clicking "Exit
   Spectator" right as the death watchdog also fires) - the leading guard
   makes every call after the first a no-op.
*/
Private ["_body"];

if !(missionNamespace getVariable ["WFBE_C_VAR_SpectatorActive", false]) exitWith {}; //--- already exited / never entered.
WFBE_C_VAR_SpectatorActive = false; //--- first: stops the movement loop in Client_SpectatorEnter.sqf on its next tick.

_body = missionNamespace getVariable ["WFBE_C_VAR_SpectatorBody", objNull];

diag_log Format ["SPECTATE|v1|exit|uid=%1", getPlayerUID player];

if (!isNil "WFBE_C_VAR_SpectatorCam" && {!isNull WFBE_C_VAR_SpectatorCam}) then {
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

if (!isNull _body) then {
	if (alive _body) then {_body allowDamage true};
	_body setCaptive false;
};

systemChat "[WASP] Spectator camera: exited.";
