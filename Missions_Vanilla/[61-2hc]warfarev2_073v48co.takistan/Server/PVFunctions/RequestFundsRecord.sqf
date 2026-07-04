/*
	RequestFundsRecord.sqf  (Ray pick A, funds-record lock-step, 2026-07-03)

	Client -> server mirror of a CLIENT-SIDE funds mutation into the per-player record.

	WHY: ChangeTeamFunds runs WHERE it is called. The bulk of player spends/credits run CLIENT-side
	(Client_ChangePlayerFunds -> clientTeam -> ChangeTeamFunds), which setVariable-broadcasts the new
	wfbe_funds onto the player's own group. That broadcast reaches the server, but the server's
	WFBE_JIP_USER<uid> record is a separate missionNamespace value the client cannot (and must not)
	write. This PVF asks the server to copy the group's now-current AUTHORITATIVE wallet into the
	record, keeping it in LOCK-STEP with the spend. It is the reason a later record-based zero-recovery
	is provably safe (a real spend-to-0 has written 0 into the record via this path).

	NO client-sent amount is trusted: the server re-reads the group's own wfbe_funds (the value the
	client already broadcast), so a spoofed payload cannot inject money - it can only (re)snapshot what
	the group truthfully carries. Idempotent: re-firing writes the same value.

	Resolves the player's slot group the same way Server_OnPlayerConnected / RequestFundsResend do
	(handed body -> stored RequestJoin body -> UID scan of playable units), accepting only a real
	warfare slot (carries wfbe_side). Delegates the actual record write to WFBE_SE_FNC_SyncFundsRecord.

	Parameter (from client): 0 - the requesting player's body.
	A2-OA-1.64 safe: getPlayerUID / group / getVariable / typeName / forEach. No A3 commands.
*/

private ["_player","_uid","_team","_clientBody"];

_player = _this select 0;
if (isNull _player) exitWith {};

_uid = getPlayerUID _player;
_team = grpNull;

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

if (isNull _team) exitWith {};

[_team] Call WFBE_SE_FNC_SyncFundsRecord;
