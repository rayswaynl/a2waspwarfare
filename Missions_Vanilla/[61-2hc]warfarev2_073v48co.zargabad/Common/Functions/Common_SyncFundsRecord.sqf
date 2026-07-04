/*
	Common_SyncFundsRecord.sqf  (Ray pick A, funds-record lock-step, 2026-07-03)

	SERVER-ONLY. Keeps the per-player JIP cash record WFBE_JIP_USER<uid> in LOCK-STEP with the
	AUTHORITATIVE group wallet, so a JIP zero-latch restore from the record is provably safe: a
	legitimate spend-to-0 has already written 0 into the record here, and only a MISSING (never-set,
	slow-sync) wallet leaves the record's real value standing.

	It reads the group's own broadcast wfbe_funds (the value every mutation path lands there, whether
	the change ran server-side via ChangeTeamFunds / a direct server write, or client-side and was
	mirrored back through the RequestFundsRecord PVF) and copies it into record index 1.

	OWNING-PLAYER key: the group's wfbe_uid, stamped ONLY on a real player slot group by
	Server_OnPlayerConnected (leader's uid) and matched the same way by Server_OnPlayerDisconnected's
	snapshot. AI / commander / GUER-stipend groups never carry wfbe_uid, so they are skipped - the
	record is a human-JIP artifact only. Multiple players sharing one group resolve to the leader's
	uid exactly as the disconnect snapshot does (single record per slot group).

	We NEVER create the record here (Server_OnPlayerConnected owns first-join creation); we only
	update an EXISTING one, so this can never race a wrong record into being.

	Parameter: 0 - the group whose wallet changed.
	A2-OA-1.64 safe: isServer / isNull / getVariable (1-arg + isNil) / typeName == / set. No A3 commands,
	no 3-arg missionNamespace setVariable (2-arg only), no publicVariableServer.
*/

private ["_grp","_uid","_funds","_get"];

if (!isServer) exitWith {};

_grp = _this select 0;
if (isNull _grp) exitWith {};

//--- Owning-player uid: present ONLY on a human slot group (AI teams -> nil -> skip).
_uid = _grp getVariable "wfbe_uid";
if (isNil "_uid" || {typeName _uid != "STRING"} || {_uid == ""}) exitWith {};

//--- Authoritative wallet = the group's own wfbe_funds (broadcast lands here from every path).
_funds = _grp getVariable "wfbe_funds";
if (isNil "_funds" || {typeName _funds != "SCALAR"}) exitWith {};

//--- Update the EXISTING record only; never create it (connect handler owns creation).
_get = missionNamespace getVariable Format ["WFBE_JIP_USER%1", _uid];
if (isNil "_get" || {typeName _get != "ARRAY"} || {count _get < 2}) exitWith {};

_get set [1, _funds];
missionNamespace setVariable [Format ["WFBE_JIP_USER%1", _uid], _get];
