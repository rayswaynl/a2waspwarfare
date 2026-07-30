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

   A2-OA-1.64 safe: getPlayerUID / missionNamespace getVariable / addAction /
   `in` (array membership) / isNil / WFBE_gameover - no A3-only commands.
*/
Private ["_myUID"];

if !((missionNamespace getVariable ["WFBE_C_SPECTATOR", 0]) > 0) exitWith {};

_myUID = getPlayerUID player;
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
			{[] Call WFBE_CL_FNC_SpectatorEnter},
			[],
			1.5,
			false,
			true,
			"",
			"!(missionNamespace getVariable ['WFBE_C_VAR_SpectatorActive', false]) && {alive player} && {missionNamespace getVariable ['WFBE_Client_DeadspawnEscaped', false]}"
		];
		player addAction [
			"<t color='#ffcc33'>Exit Spectator</t>",
			{[] Call WFBE_CL_FNC_SpectatorExit},
			[],
			1.5,
			false,
			true,
			"",
			"missionNamespace getVariable ['WFBE_C_VAR_SpectatorActive', false]"
		];
		diag_log Format ["SPECTATE|v1|actions-attached|uid=%1", _myUID];
	};
	sleep 3;
};
