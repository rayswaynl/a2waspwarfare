/*
	RequestFundsResend.sqf  (B76 JIP-FUNDS self-heal, Ray 2026-06-29)

	WHY THIS EXISTS
	---------------
	A JIP joiner whose own-side wfbe_teams slow-syncs under heavy AI load can end up with
	NO starting money even after the B62/B64/B74.2 reconciliation back-fills clientTeams.
	Root cause (traced from client-main.rpt for "Zwanon"): the player's funds live on his
	GROUP object as wfbe_funds, written by Server_OnPlayerConnected with a broadcast (true)
	setVariable. In A2-OA an object setVariable-broadcast is NOT replayed to a client that
	joined after it, and under load it can reach the late joiner slowly or not at all - the
	SAME failure mode the team-sync heals were written for. The client then reads
	(group player) getVariable "wfbe_funds" = nil -> GetTeamFunds returns 0 -> "$0" HUD.
	The reconciliation loops only re-pull wfbe_teams / structure markers; NOTHING re-applies
	the player's own-group funds. A slot-switch "fixes" it only because re-connecting re-fires
	the connect handler AFTER sync settled, so the funds broadcast lands.

	WHAT THIS DOES
	--------------
	This is the explicit, on-demand mirror of that slot-switch recovery WITHOUT forcing a
	reconnect. The client (Init_Client B76 funds self-heal) calls this once it detects its
	own group is missing wfbe_funds. The server re-resolves the player's team and re-broadcasts
	the AUTHORITATIVE funds value onto that group, marking the object var dirty so the engine
	re-syncs it to the now-present client.

	IDEMPOTENCY (no money duplication, ever)
	----------------------------------------
	This handler NEVER adds money. It only re-broadcasts an ABSOLUTE value, chosen in this order:
	  1. If the group already carries a numeric wfbe_funds  -> re-broadcast THAT exact value
	     (covers a normal fast join / a real reconnect where funds already landed; pure no-op
	     same-value re-set, so a stray/duplicate request cannot inflate the treasury, and any
	     stipend top-ups already applied are preserved).
	  2. Else if a WFBE_JIP_USER<uid> record exists -> re-broadcast its stored cash (index 1)
	     (this is the value the connect handler computed; matches the slot-switch path exactly).
	  3. Else -> the side START constant (the value the connect handler WOULD set on first join).
	     We deliberately do NOT create the WFBE_JIP_USER<uid> record here; Server_OnPlayerConnected
	     remains the single owner of that record, so this handler can never race it into existence
	     with a wrong value.

	A2-OA-1.64 safe: getPlayerUID / group / side / getVariable / setVariable / typeName are all
	core OA commands. No isEqualType / findIf / pushBack / params.

	 Parameters (from client):
		0: _player  - the requesting player's body (real networked unit)
		1: _side    - the side the client believes it joined (informational / fallback only)
*/

private ["_player","_uid","_team","_clientBody","_funds","_get","_curFunds","_recCash","_sideJoined","_sideText"];

_player = _this select 0;

if (isNull _player) exitWith {
	diag_log "[WFBE][B76 FUNDS-RESEND] BAIL: null player in request.";
};

_uid = getPlayerUID _player;
_team = grpNull;

//--- Resolve the player's slot group the same way Server_OnPlayerConnected does, preferring the
//--- body the client just handed us, then the stored RequestJoin body, then a UID scan of the
//--- side-logic team groups. We only accept a group that carries wfbe_side (a real warfare slot).
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

//--- If we still cannot resolve a real warfare team, do nothing. The connect handler / its
//--- self-heal re-arm owns first-time resolution; the client will simply ask again next tick.
if (isNull _team) exitWith {
	diag_log Format ["[WFBE][B76 FUNDS-RESEND] [%1]: team unresolved - deferring to connect-handler enrollment (client will retry).", _uid];
};

_sideJoined = _team getVariable "wfbe_side";
if (isNil "_sideJoined") exitWith {
	diag_log Format ["[WFBE][B76 FUNDS-RESEND] [%1]: resolved team has nil wfbe_side - deferring.", _uid];
};

//--- Ray pick A (2026-07-03) ZERO-LATCH RECORD RESTORE: the per-player record is now kept in LOCK-STEP
//--- with every wallet change (Common_ChangeTeamFunds / RequestFundsRecord / the ScudStrike direct write),
//--- so WFBE_JIP_USER<uid> cash is the AUTHORITATIVE truth. That makes a record-first recovery provably
//--- safe: a legitimately-spent-to-0 wallet also wrote 0 into the record, so restoring "record when the
//--- group is 0/nil and record > 0" can NEVER re-grant a real spender - only a MISSING / transient-0 wallet
//--- (the JIP zero-latch) has a record that still stands above it. This closes the case-1 hole where a
//--- transient 0 on the group was re-broadcast (and latched by the client) as if it were real.
_curFunds = _team getVariable "wfbe_funds";
_get = missionNamespace getVariable Format ["WFBE_JIP_USER%1", _uid];
_recCash = -1;
if (!isNil "_get" && {typeName _get == "ARRAY"} && {count _get > 1} && {typeName (_get select 1) == "SCALAR"}) then {_recCash = _get select 1};

//--- (1) Record wins whenever the group wallet is nil/0 but the record carries a positive balance.
//--- This IS the zero-latch fix: prefer the lock-step record over a transient/absent group value.
if (_recCash > 0 && {isNil "_curFunds" || {typeName _curFunds != "SCALAR"} || {_curFunds <= 0}}) exitWith {
	_team setVariable ["wfbe_funds", _recCash, true];
	diag_log Format ["FUNDS_RESTORE|%1|from record|%2", _uid, _recCash];
	diag_log Format ["[WFBE][B76 FUNDS-RESEND] [%1] side %2: restored from LOCK-STEP record cash=%3 (group was %4) - JIP zero-latch recovery.", _uid, _sideJoined, _recCash, (if (isNil "_curFunds") then {"nil"} else {_curFunds})];
};

//--- (2) Group already carries a numeric (and, per above, non-zero-or-no-positive-record) value ->
//--- re-broadcast that exact value (idempotent no-op same-value re-sync; covers a healthy fast join and
//--- a real spent-low balance where the record agrees).
if (!isNil "_curFunds" && {typeName _curFunds == "SCALAR"}) exitWith {
	_team setVariable ["wfbe_funds", _curFunds, true];
	diag_log Format ["[WFBE][B76 FUNDS-RESEND] [%1] side %2: re-broadcast EXISTING group funds=%3 (no-op same-value re-sync).", _uid, _sideJoined, _curFunds];
};

//--- (2b) No numeric group value but a record exists (even a legit 0) -> re-broadcast the record cash.
if (_recCash > -1) exitWith {
	_team setVariable ["wfbe_funds", _recCash, true];
	diag_log Format ["[WFBE][B76 FUNDS-RESEND] [%1] side %2: re-broadcast STORED JIP cash=%3.", _uid, _sideJoined, _recCash];
};

//--- (3) No record yet -> stamp the side START funds (the value the connect handler WOULD set on
//--- first join). We do NOT create WFBE_JIP_USER<uid> here; Server_OnPlayerConnected owns it.
_funds = missionNamespace getVariable [Format ["WFBE_C_ECONOMY_FUNDS_START_%1", _sideJoined], 0];
_team setVariable ["wfbe_funds", _funds, true];
diag_log Format ["[WFBE][B76 FUNDS-RESEND] [%1] side %2: stamped START funds=%3 (no JIP record yet; connect handler will reconcile).", _uid, _sideJoined, _funds];
