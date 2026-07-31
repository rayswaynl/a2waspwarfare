/*
	J1 funds authority (2026-07-13): server-side replacement for the side-targeted client wallet
	writes (BankPayout / GuerVbiedBounty toll paths). Credits _amount to the slot group of EVERY
	connected, alive player on _side - one credit per matching PLAYER (players sharing a group get
	one share each, the per-member total that today per-client writes produced).
	HC exclusion: HC-seated bodies are isPlayer on WEST/EAST here (AI_Commander_Allocate.sqf M5
	note) but never ran the client wallet handlers (Client_HandlePVF.sqf:37 hard-exits every
	non-allowlisted PVF on a headless client) - skip them by name for exact parity. The name list is
	WFBE_C_HC_NAMES (Init_CommonConstants.sqf), derived from WFBE_C_HC_SLOTS so a new HC slot cannot
	drift out of this check the way HC-AI-Control-4 did after the 4-HC rollout (#1456).
	Alive gate matches the pool divisors (Server_BankIncome.sqf:39 et al) and BankPayout.sqf:16.
	 Parameters:
		0 - side (SIDE)
		1 - amount per player (SCALAR, > 0; non-positive or non-scalar amounts are ignored)
	 Returns: nothing meaningful. Self-bails off-server (SyncFundsRecord precedent).
	A2-OA-1.64 safe: playableUnits forEach / isPlayer / lazy && {} / name / group. No A3 commands.
*/
Private ["_side","_amount","_count"];

if (!isServer) exitWith {};

_side = _this select 0;
_amount = _this select 1;

if (isNil "_amount" || {typeName _amount != "SCALAR"} || {_amount <= 0}) exitWith {};

_count = 0;
{
	if (([_x, false] Call WFBE_CO_FNC_IsRealPlayer) && {alive _x} && {side _x == _side} && {!((name _x) in WFBE_C_HC_NAMES)}) then {
		[group _x, _amount] Call WFBE_CO_FNC_ChangeTeamFunds;
		_count = _count + 1;
	};
} forEach playableUnits;

["INFORMATION", Format ["Common_CreditSidePlayers.sqf: [%1] credited %2 x %3 players.", str _side, _amount, _count]] Call WFBE_CO_FNC_LogContent;
