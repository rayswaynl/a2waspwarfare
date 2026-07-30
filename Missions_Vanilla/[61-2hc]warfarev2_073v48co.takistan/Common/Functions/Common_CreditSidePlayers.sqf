/*
	J1 funds authority (2026-07-13): server-side replacement for the side-targeted client wallet
	writes (BankPayout / GuerVbiedBounty toll paths). Credits _amount to the slot group of EVERY
	connected, alive player on _side - one credit per matching PLAYER (players sharing a group get
	one share each, the per-member total that today per-client writes produced).
	HC and dedicated-caster bodies are excluded by the shared WFBE_CO_FNC_IsRealPlayer predicate,
	which combines the HC registry/name fallback with the caster slot stamp and flag. The predicate
	keeps this side credit path aligned with Common_RealPlayers and Common_RealPlayersNear.
	Alive gate matches the pool divisors (Server_BankIncome.sqf:39 et al) and BankPayout.sqf:16.
	 Parameters:
		0 - side (SIDE)
		1 - amount per player (SCALAR, > 0; non-positive or non-scalar amounts are ignored)
	 Returns: nothing meaningful. Self-bails off-server (SyncFundsRecord precedent).
	A2-OA-1.64 safe: playableUnits / shared real-player predicate / group. No A3 commands.
*/
Private ["_side","_amount","_count"];

if (!isServer) exitWith {};

_side = _this select 0;
_amount = _this select 1;

if (isNil "_amount" || {typeName _amount != "SCALAR"} || {_amount <= 0}) exitWith {};

_count = 0;
{
	if (side _x == _side) then {
		[group _x, _amount] Call WFBE_CO_FNC_ChangeTeamFunds;
		_count = _count + 1;
	};
} forEach ([_side] Call WFBE_CO_FNC_RealPlayers);

["INFORMATION", Format ["Common_CreditSidePlayers.sqf: [%1] credited %2 x %3 players.", str _side, _amount, _count]] Call WFBE_CO_FNC_LogContent;
