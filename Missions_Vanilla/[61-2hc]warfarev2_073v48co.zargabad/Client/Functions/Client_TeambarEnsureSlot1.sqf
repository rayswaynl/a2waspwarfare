/*
    TEAMBAR ensure-slot1 (card wasp-teambar-buy-fix-20260724, council fix 2026-07-24;
    RESPAWN-LEG REWORK wasp-squad-renumber-on-death-20260724, player report 07-24 (777)).

    Engine rule (probe-demonstrated, owner client RPT 2026-07-24 build wave0723d + council
    papers): group roster ids are sticky, a joining unit takes the LOWEST FREE id, and rank
    does not drive the bar slot. Death/respawn renumbers the whole bar through two engine
    transitions: (1) the respawned body is seated at the roster TAIL while the corpse still
    holds id 1; (2) the dead-units watchdog (Client_WatchdogCommandBarDeadUnits.sqf) ejects
    the corpse ~1s later, compacting every subordinate one visible slot up. The legacy
    "rejoin the AI behind the player" dance never moved the PLAYER, so it re-seated the AI
    into the freed low ids AHEAD of him every pass - the shifted order persisted across every
    61s heartbeat ("units kept renumbering themselves after I die").

    This is the shared IDEMPOTENT stable-reorder primitive, safe to call on ANY membership
    change; exits O(1) when the bar is already healthy. It RE-SEATS THE PLAYER FIRST (out to
    a temp group and straight back, so he takes the lowest free roster id), then re-joins the
    client-LOCAL AI behind him in STABLE ROSTER ORDER - WFBE_TB_Roster memory: dead/departed
    drop out, new arrivals append at the tail - so existing subordinate F-slots never shuffle
    across respawn, buys, or skin swaps. It moves client-LOCAL units only (joinSilent needs
    locality); a non-local or human member seated ahead of the player is never touched (skip
    + reason-coded probe, instead of re-permuting the locals behind it every pass). Never
    touches other groups (CIV HC bodies unreachable: it only ever operates on
    group player == WFBE_Client_Team while the player is its leader). When no member would
    stay behind (all alive + local), a placeholder temp unit holds the group open through the
    transit (the Common_ChangeUnitGroup.sqf keep-alive pattern - a join that empties a group
    erases it).

    Call shape: _rc = ["<evt>"] Call WFBE_CL_FNC_TeambarEnsureSlot1; returns a reason code:
    "done" / "creategroup-null" / "placeholder-null" / "no-local-others" / "nonlocal-ahead"
    / "healthy" / "skipped-flag" / "skipped-not-alive" / "skipped-not-team" /
    "skipped-not-leader".
    Gated on WFBE_C_PLAYER_TEAMBAR_FIRST (>0, product flag, current default 1); flag 0 = no-op.
    A2-OA-safe: Private-then-assign, set [count], lazy && {}, no A3 commands.
*/

WFBE_CL_FNC_TeambarEnsureSlot1 = {
	Private ["_evt","_grp","_ros","_keep","_actual","_match","_k","_others","_blocked","_past","_stay","_ph","_phClass","_tmp"];
	_evt = _this select 0;
	if (!((missionNamespace getVariable ["WFBE_C_PLAYER_TEAMBAR_FIRST", 0]) > 0)) exitWith {"skipped-flag"};
	if (!alive player) exitWith {"skipped-not-alive"};
	if (group player != (missionNamespace getVariable ["WFBE_Client_Team", grpNull])) exitWith {"skipped-not-team"};
	if (leader (group player) != player) exitWith {"skipped-not-leader"};
	_grp = group player;

	//--- Stable roster memory (client-local, survives respawn by design): the subordinate
	//--- order the bar should show. Reconcile every call - dead/departed/non-local members
	//--- drop out, new arrivals append at the tail in current units order - so respawn
	//--- compaction and buy hole-fills cannot reshuffle EXISTING subordinates.
	_ros = missionNamespace getVariable ["WFBE_TB_Roster", []];
	_keep = [];
	{if (!isNull _x && {alive _x} && {!isPlayer _x} && {local _x} && {_x in (units _grp)}) then {_keep set [count _keep, _x]}} forEach _ros;
	{if (alive _x && {!isPlayer _x} && {local _x} && {!(_x in _keep)}) then {_keep set [count _keep, _x]}} forEach (units _grp);
	missionNamespace setVariable ["WFBE_TB_Roster", _keep];
	_ros = _keep;

	//--- Current moveable order (alive client-local AI) for the health compare.
	_actual = [];
	{if (alive _x && {!isPlayer _x} && {local _x}) then {_actual set [count _actual, _x]}} forEach (units _grp);

	//--- Healthy fast path: player already slot 1 AND subordinates already in roster order.
	_match = (count _actual == count _ros);
	if (_match) then {
		for '_k' from 0 to ((count _actual) - 1) do {
			if ((_actual select _k) != (_ros select _k)) then {_match = false};
		};
	};
	if (((units _grp) select 0) == player && {_match}) exitWith {"healthy"};

	[_evt, "ensure-check"] Call WFBE_CL_FNC_TeambarProbe;

	//--- Re-join list in ROSTER order (not current array order) = the stable order to materialize.
	_others = [];
	{if (alive _x && {!isPlayer _x} && {local _x} && {_x in (units _grp)}) then {_others set [count _others, _x]}} forEach _ros;

	//--- A non-local or human member AHEAD of the player holds a low roster id this client
	//--- cannot free; dancing the locals behind it would re-permute them every 61s heartbeat
	//--- without ever healing - skip with a named reason instead.
	_blocked = false;
	_past = false;
	{
		if (!_past) then {
			if (_x == player) then {
				_past = true;
			} else {
				if (alive _x && {!(_x in _others)}) then {_blocked = true};
			};
		};
	} forEach (units _grp);
	if (_blocked) exitWith {
		[_evt, "ensure-nonlocal-ahead"] Call WFBE_CL_FNC_TeambarProbe;
		"nonlocal-ahead"
	};

	if (count _others > 0) then {
		//--- Keep-alive: when nothing would remain in the group during the transit (every
		//--- member moves out), a placeholder temp unit holds it open; created only in that
		//--- case and deleted before the post-state probe. Abort cleanly if it cannot be made
		//--- (unknown side class or engine unit cap) - emptying the group would erase it.
		_stay = 0;
		{if (!(_x in _others) && {_x != player}) then {_stay = _stay + 1}} forEach (units _grp);
		_ph = objNull;
		if (_stay == 0) then {
			_phClass = missionNamespace getVariable [Format ["WFBE_%1SOLDIER", side _grp], ""];
			if (_phClass != "") then {_ph = [_phClass, _grp, [0,0,0], side _grp, false] Call WFBE_CO_FNC_CreateUnit};
		};
		if (_stay == 0 && {isNull _ph}) then {
			[_evt, "ensure-placeholder-null"] Call WFBE_CL_FNC_TeambarProbe;
			"placeholder-null"
		} else {
			_tmp = createGroup (side _grp);
			if (!isNull _tmp) then {
				_others joinSilent _tmp;
				[player] joinSilent _tmp;
				[player] joinSilent _grp;
				_others joinSilent _grp;
				if (count units _tmp == 0) then {deleteGroup _tmp};
				_grp selectLeader player;
				if (!isNull _ph) then {deleteVehicle _ph};
				diag_log Format ["[WFBE|TEAMBAR] ensure-slot1 (%1): player re-seated at slot 1; %2 AI squadmates re-joined in stable roster order.", _evt, count _others];
				[_evt, "ensure-done"] Call WFBE_CL_FNC_TeambarProbe;
				"done"
			} else {
				if (!isNull _ph) then {deleteVehicle _ph};
				[_evt, "ensure-creategroup-null"] Call WFBE_CL_FNC_TeambarProbe;
				"creategroup-null"
			};
		};
	} else {
		[_evt, "ensure-no-local-others"] Call WFBE_CL_FNC_TeambarProbe;
		"no-local-others"
	};
};
