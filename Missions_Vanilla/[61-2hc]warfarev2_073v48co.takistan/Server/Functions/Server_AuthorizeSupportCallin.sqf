/*
	WFBE_SE_FNC_AuthorizeSupportCallin -- server-authoritative funds + rate gate for the
	tactical support call-ins that used to spawn on request with NO server-side check
	(Paratroops / ParaVehi / ParaAmmo / uav -- Server_HandleSpecial.sqf).

	SECURITY (supportgate, 2026-07-24): the client deducts its own fee BEFORE sending the
	request (GUI_Menu_Tactical.sqf:564-565 Paratroops, :892-894 ParaVehi, :903-905 ParaAmmo;
	Client\Module\UAV\uav.sqf:50-52 uav) via ChangePlayerFunds -> Common_ChangeTeamFunds,
	which does `_team setVariable ["wfbe_funds", _cur+_amount, true]` -- a PUBLIC broadcast
	EXECUTED FROM THE CLIENT that A2 OA 1.64 accepts with no authority check. A modified
	client can skip/spoof that deduction and still get the drop, and with no per-team lock
	or cooldown on the server side, it can loop the request to flood free vehicles/troops/
	UAVs. This helper reuses the same pattern Support_ScudStrike.sqf already uses for the
	carrier SCUD: resolve cost/delay server-side, nil-guard the real team wallet, deny +
	WARNING-log on insufficient funds or an active cooldown, else deduct + stamp cooldown
	BEFORE the caller is allowed to spawn the asset.

	GROUPGETVAR-safe: _playerTeam is a GROUP (clientTeam = group player), so every read goes
	through WFBE_CO_FNC_GroupGetBool (1-arg getVariable + isNil) instead of the 2-arg
	`getVariable [name, default]` form, which returns nil (not the default) on a GROUP.

	Params: [_kind (STRING), _payload (ARRAY - the full RequestSpecial payload, select 3 =
	         calling GROUP), _cost (SCALAR), _delay (SCALAR, per-team per-kind cooldown seconds)]
	Returns: true if authorised (funds already deducted, cooldown already stamped), else false.
*/
Private ["_kind","_payload","_cost","_delay","_playerTeam","_cdKey","_now","_next","_funds"];

_kind = _this select 0;
_payload = _this select 1;
_cost = _this select 2;
_delay = _this select 3;

if (count _payload < 4) exitWith {
	["WARNING", Format ["Server_AuthorizeSupportCallin.sqf: %1 denied -- malformed payload (%2 fields).", _kind, count _payload]] Call WFBE_CO_FNC_LogContent;
	false
};

_playerTeam = _payload select 3;
if (isNull _playerTeam) exitWith {
	["WARNING", Format ["Server_AuthorizeSupportCallin.sqf: %1 denied -- null calling team.", _kind]] Call WFBE_CO_FNC_LogContent;
	false
};

_now = time;
_cdKey = Format ["wfbe_support_callin_next_%1", _kind];
_next = [_playerTeam, _cdKey, 0] Call WFBE_CO_FNC_GroupGetBool;
if (typeName _next != "SCALAR") then {_next = 0};
if (_now < _next) exitWith {
	["WARNING", Format ["Server_AuthorizeSupportCallin.sqf: %1 denied -- cooldown (%2s left), team %3.", _kind, round (_next - _now), _playerTeam]] Call WFBE_CO_FNC_LogContent;
	false
};

_funds = [_playerTeam, "wfbe_funds", 0] Call WFBE_CO_FNC_GroupGetBool;
if (typeName _funds != "SCALAR") then {_funds = 0};
if (_funds < _cost) exitWith {
	["WARNING", Format ["Server_AuthorizeSupportCallin.sqf: %1 denied -- insufficient funds (%2 < %3), team %4.", _kind, _funds, _cost, _playerTeam]] Call WFBE_CO_FNC_LogContent;
	false
};

//--- AUTHORISED: deduct + stamp cooldown BEFORE the caller spawns anything (anti double-fire race,
//--- same ordering Support_ScudStrike.sqf uses). The cooldown stamp is a local (non-public) write --
//--- only the server ever reads it -- while the funds write stays public so the client HUD updates.
_playerTeam setVariable ["wfbe_funds", (_funds - _cost), true];
[_playerTeam] Call WFBE_SE_FNC_SyncFundsRecord;
_playerTeam setVariable [_cdKey, (_now + _delay)];

["INFORMATION", Format ["Server_AuthorizeSupportCallin.sqf: %1 AUTHORISED for team %2 (cost %3, next in %4s).", _kind, _playerTeam, _cost, _delay]] Call WFBE_CO_FNC_LogContent;

true
