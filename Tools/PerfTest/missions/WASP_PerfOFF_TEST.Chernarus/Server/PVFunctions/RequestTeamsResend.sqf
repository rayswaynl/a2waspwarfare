/*
	RequestTeamsResend.sqf  (cmdcon26 JIP TEAMS/STRUCTURE self-heal, Game 2026-06-29)

	WHY THIS EXISTS
	---------------
	A JIP joiner whose own-side side-logic slow-syncs under heavy AI load can end up with NO own-side
	TEAM arrows (the orange player arrow + AI-leader arrows) and NO own-side HQ/factory markers, even
	after the B62/B64/B74.2 reconciliation runs. Root cause (traced from client-main.rpt for "Zwanon",
	EAST, on cmdcon25): the own-side team roster lives on the side-LOGIC object as wfbe_teams, the HQ on
	wfbe_hq and the factories/structures on wfbe_structures, each written with a broadcast (true)
	setVariable. In A2-OA an object setVariable-broadcast is NOT replayed to a client that joined after
	it, and under load it can reach the late joiner slowly or not at all - the SAME failure mode the
	funds self-heal (RequestFundsResend) was written for. The client then reads an empty/stale
	clientTeams (own arrows invisible) and never receives the structure objects to draw the HQ marker.
	A slot-switch "fixes" it only because re-connecting re-pulls the now-settled side logic.

	WHAT THIS DOES
	--------------
	This is the explicit, on-demand mirror of that slot-switch recovery WITHOUT forcing a reconnect.
	The client (Init_Client cmdcon26 teams self-heal) calls this once it detects its own-side clientTeams
	is still empty/stale after the poll. The server re-resolves the requesting player's side and
	re-broadcasts the AUTHORITATIVE side-logic wfbe_teams (and, cheaply, wfbe_hq + wfbe_structures) by
	re-setting those object vars dirty so the engine re-syncs them to the now-present client.

	IDEMPOTENCY (never mutates roster state)
	----------------------------------------
	This handler NEVER adds, removes or reorders teams/structures. It re-broadcasts the EXACT same array
	objects the side logic already holds (a pure same-value re-set), so a stray/duplicate request cannot
	corrupt the roster. If the side logic carries no wfbe_teams yet (genuinely not built), it does
	nothing and the client simply asks again next tick.

	A2-OA-1.64 safe: getPlayerUID / group / side / getVariable / setVariable / typeName /
	WFBE_CO_FNC_GetSideLogic are all core OA commands / existing mission helpers. No isEqualType /
	findIf / pushBack / params.

	 Parameters (from client):
		0: _player  - the requesting player's body (real networked unit)
		1: _side    - the side the client believes it joined (informational / fallback only)
*/

private ["_player","_uid","_team","_clientBody","_sideJoined","_logik","_teams","_hq","_structures"];

_player = _this select 0;

if (isNull _player) exitWith {
	diag_log "[WFBE][cmdcon26 TEAMS-RESEND] BAIL: null player in request.";
};

_uid = getPlayerUID _player;
_team = grpNull;

//--- Resolve the player's slot group the same way RequestFundsResend / Server_OnPlayerConnected do,
//--- preferring the body the client just handed us, then the stored RequestJoin body, then a UID scan of
//--- the playable units. We only accept a group that carries wfbe_side (a real warfare slot).
if (!isNull _player && {alive _player} && {!isNil {(group _player) getVariable "wfbe_side"}}) then {
	_team = group _player;
};

if (isNull _team) then {
	_clientBody = missionNamespace getVariable [Format ["WFBE_JIP_BODY_%1", _uid], objNull];
	if (!isNull _clientBody && {alive _clientBody} && {!isNil {(group _clientBody) getVariable "wfbe_side"}}) then {
		_team = group _clientBody;
	};
};

if (isNull _team) then {
	{
		if (!isNull _x && {(getPlayerUID _x) == _uid} && {!isNil {(group _x) getVariable "wfbe_side"}}) exitWith {_team = group _x};
	} forEach playableUnits;
};

//--- If we still cannot resolve a real warfare team, fall back to the side the client believes it joined
//--- (informational param). The connect-handler enrollment owns first-time resolution; the client retries.
_sideJoined = sideUnknown;
if (!isNull _team) then {
	_sideJoined = _team getVariable "wfbe_side";
};
if (isNil "_sideJoined" || {_sideJoined == sideUnknown}) then {
	_sideJoined = _this select 1;
};

if (isNil "_sideJoined" || {_sideJoined == sideUnknown}) exitWith {
	diag_log Format ["[WFBE][cmdcon26 TEAMS-RESEND] [%1]: side unresolved - deferring (client will retry).", _uid];
};

//--- Re-resolve the side logic and re-broadcast its AUTHORITATIVE roster/structure registries. Same-value
//--- re-set marks the object vars dirty so the engine re-syncs them to the now-present late joiner.
_logik = (_sideJoined) Call WFBE_CO_FNC_GetSideLogic;
if (isNull _logik) exitWith {
	diag_log Format ["[WFBE][cmdcon26 TEAMS-RESEND] [%1] side %2: null side logic - deferring.", _uid, _sideJoined];
};

_teams = _logik getVariable "wfbe_teams";
if (!isNil "_teams" && {typeName _teams == "ARRAY"}) then {
	_logik setVariable ["wfbe_teams", _teams, true];
	diag_log Format ["[WFBE][cmdcon26 TEAMS-RESEND] [%1] side %2: re-broadcast wfbe_teams (count %3).", _uid, _sideJoined, count _teams];
} else {
	diag_log Format ["[WFBE][cmdcon26 TEAMS-RESEND] [%1] side %2: side logic has no wfbe_teams yet - nothing to resend (client will retry).", _uid, _sideJoined];
};

//--- Cheap belt-and-braces: re-broadcast the own HQ + structure registry so the HQ/factory markers heal too.
_hq = _logik getVariable "wfbe_hq";
if (!isNil "_hq" && {!isNull _hq}) then {
	_logik setVariable ["wfbe_hq", _hq, true];
};

_structures = _logik getVariable "wfbe_structures";
if (!isNil "_structures" && {typeName _structures == "ARRAY"}) then {
	_logik setVariable ["wfbe_structures", _structures, true];
	diag_log Format ["[WFBE][cmdcon26 TEAMS-RESEND] [%1] side %2: re-broadcast wfbe_structures (count %3) + wfbe_hq.", _uid, _sideJoined, count _structures];
};
