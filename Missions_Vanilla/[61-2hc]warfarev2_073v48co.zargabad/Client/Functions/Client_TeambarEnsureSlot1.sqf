/*
    TEAMBAR ensure-slot1 (card wasp-teambar-buy-fix-20260724, council fix 2026-07-24).

    Root cause (grok+codex independent papers vs live TEAMBAR|v2|PROBE data, owner client RPT
    2026-07-24, build wave0723d): buying units (Client_BuildUnit) creates AI into the player's
    group where the engine can seat them at units[0]; that path only received the rank-to-PRIVATE
    half of the TEAMBAR-FIRST treatment, and the live probe PROVES rank does not control the bar
    slot (a PRIVATE rendered ahead of the COLONEL player, isLeader=true throughout, persisting
    across every 60s heartbeat). All pre-existing slot1-rejoins (init / respawn / skin-swap /
    server connect) are lifecycle one-shots that never re-fire on a later membership change.

    This is the shared IDEMPOTENT renumber primitive: the proven temp-group rejoin dance, safe
    to call on ANY membership change; exits O(1) when the player is already slot 1. It moves
    client-LOCAL AI only (joinSilent needs locality); a non-local or human occupant of slot 0 is
    never touched (skip + probe). Never touches other groups (CIV HC bodies unreachable: it only
    ever operates on group player == WFBE_Client_Team while the player is its leader).

    Call shape: ["<evt>"] Call WFBE_CL_FNC_TeambarEnsureSlot1;
    Gated on WFBE_C_PLAYER_TEAMBAR_FIRST (>0, product flag, current default 1); flag 0 = no-op.
    A2-OA-safe: Private-then-assign, set [count], lazy && {}, no A3 commands.
*/

WFBE_CL_FNC_TeambarEnsureSlot1 = {
	Private ["_evt","_others","_tmp"];
	_evt = _this select 0;
	if (!((missionNamespace getVariable ["WFBE_C_PLAYER_TEAMBAR_FIRST", 0]) > 0)) exitWith {};
	if (!alive player) exitWith {};
	if (group player != (missionNamespace getVariable ["WFBE_Client_Team", grpNull])) exitWith {};
	if (leader (group player) != player) exitWith {};
	if (((units group player) select 0) == player) exitWith {};
	[_evt, "ensure-check"] Call WFBE_CL_FNC_TeambarProbe;
	_others = [];
	{if (alive _x && {!isPlayer _x} && {local _x}) then {_others set [count _others, _x]}} forEach ((units group player) - [player]);
	if (count _others > 0) then {
		_tmp = createGroup (side group player);
		if (!isNull _tmp) then {
			_others joinSilent _tmp;
			_others joinSilent (group player);
			if (count units _tmp == 0) then {deleteGroup _tmp};
			(group player) selectLeader player;
			diag_log Format ["[WFBE|TEAMBAR] ensure-slot1 (%1): %2 AI squadmates re-joined behind the player.", _evt, count _others];
			[_evt, "ensure-done"] Call WFBE_CL_FNC_TeambarProbe;
		} else {
			[_evt, "ensure-creategroup-null"] Call WFBE_CL_FNC_TeambarProbe;
		};
	} else {
		[_evt, "ensure-no-local-others"] Call WFBE_CL_FNC_TeambarProbe;
	};
};
