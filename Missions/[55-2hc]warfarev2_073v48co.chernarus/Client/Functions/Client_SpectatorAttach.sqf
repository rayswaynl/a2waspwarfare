/* Client_SpectatorAttach.sqf
   fable/spectator-v1 (owner request 2026-07-28: spectator mode, owner first)
   -------------------------------------------------------------------------
   Self-healing per-client attach loop for the UID-allowlisted free-camera
   spectator overlay. Spawned ONCE from Init_Client.sqf for EVERY client
   (cheap early-exit for anyone not on the allowlist); only the allowlisted
   owner UID(s) in WFBE_C_SPECTATOR_UIDS ever get the addActions below.
   The UID allowlist gates ACTION VISIBILITY on this client only, under standard
   A2 locality; it is not server-enforced authentication or authorization.

   Re-checks every few seconds instead of a one-shot attach because `player`
   is a FRESH object after every respawn (addAction is object-bound and does
   not survive it). This is a standalone poll loop specifically so this
   feature never has to edit the respawn handler or any enrollment/JIP path
   (owner hard constraint) - contrast the idempotent per-object re-attach
   flags Client_OnRespawnHandler.sqf already uses for other per-life features
   (wfbe_blink_eh_added / wfbe_ied_eh_added): same idempotency idea, but
   entirely out-of-band here.

   A2 OA 1.64: addAction script param must be a STRING file path - a code block
   raises "Type code, expected String" and the action is never added
   (live-proven client RPT 2026-07-30). Same idiom as the working
   MHQ lock/build actions in updateclient.sqf.
   v4 (owner 2026-07-31): WFBE_C_SPECTATOR_AUTOSTART (default 0) makes this loop
   auto-enter spectator + director-auto for the allowlisted UID once the body is
   alive past the deadspawn window - hands-off stream box, self-heals on respawn.

   A2-OA-1.64 safe: getPlayerUID / missionNamespace getVariable / addAction /
   `in` (array membership) / isNil / WFBE_gameover - no A3-only commands.
*/
Private ["_myUID"];

if !((missionNamespace getVariable ["WFBE_C_SPECTATOR", 0]) > 0) exitWith {};

_myUID = getPlayerUID player;
//--- v5 (spec 8, owner 2026-08-01 "normal player slot does still have spectator camera?"): the
//--- UID allowlist alone left the action on an allowlisted player in a COMBAT slot - clutter and
//--- one misclick from parking a live soldier mid-firefight. Require the Caster seat too.
//--- Set 0 to restore UID-only entry for solo testing on missions without caster seats.
if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_CASTER_SEAT_ONLY", 1]) > 0 && {!(player getVariable ["wfbe_caster_slot", false])}) exitWith {};
if !(_myUID in (missionNamespace getVariable ["WFBE_C_SPECTATOR_UIDS", []])) exitWith {};

if (isNil "WFBE_C_VAR_SpectatorActive") then {WFBE_C_VAR_SpectatorActive = false};

diag_log Format ["SPECTATE|v1|allowlisted-client|uid=%1", _myUID];

while {!(missionNamespace getVariable ["WFBE_gameover", false])} do {
	waitUntil {sleep 2; !isNull player || (missionNamespace getVariable ["WFBE_gameover", false])};
	if (missionNamespace getVariable ["WFBE_gameover", false]) exitWith {};
	if !(player getVariable ["wfbe_spectator_actions_added", false]) then {
		player setVariable ["wfbe_spectator_actions_added", true];
		player addAction [
			"<t color='#7fd4ff'>Spectator Camera</t>",
			"Client\Functions\Client_SpectatorEnter.sqf",
			[],
			1.5,
			false,
			true,
			"",
			"!(missionNamespace getVariable ['WFBE_C_VAR_SpectatorActive', false]) && {alive player} && {missionNamespace getVariable ['WFBE_Client_DeadspawnEscaped', false]}"
		];
		player addAction [
			"<t color='#ffcc33'>Exit Spectator</t>",
			"Client\Functions\Client_SpectatorExit.sqf",
			[],
			1.5,
			false,
			true,
			"",
			"missionNamespace getVariable ['WFBE_C_VAR_SpectatorActive', false]"
		];
		diag_log Format ["SPECTATE|v1|actions-attached|uid=%1", _myUID];
	};
	//--- v4 autostart (flag default 0): hands-off director entry for the stream box.
	//--- Same gates as the addAction (alive + past deadspawn window); re-fires after
	//--- respawn because SpectatorActive is false again while this loop keeps polling.
	if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_AUTOSTART", 0]) > 0) then {
		if (!(missionNamespace getVariable ["WFBE_C_VAR_SpectatorActive", false]) && {alive player} && {missionNamespace getVariable ["WFBE_Client_DeadspawnEscaped", false]}) then {
			[] Call WFBE_CL_FNC_SpectatorEnter;
			if ((missionNamespace getVariable ["WFBE_C_VAR_SpectatorActive", false]) && {(missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR", 0]) > 0}) then {
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
				diag_log Format ["SPECTATE|v4|autostart|uid=%1|mode=director-auto", _myUID];
				systemChat "[WASP] Spectator autostart: director auto (G toggles).";
			};
		};
	};
	sleep 3;
};
