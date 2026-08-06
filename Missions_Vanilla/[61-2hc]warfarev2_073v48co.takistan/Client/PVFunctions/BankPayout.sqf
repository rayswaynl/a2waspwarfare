/* BankPayout.sqf — client-side PVF handler.
   Shows the quiet group-chat dividend notification (J1 funds authority: the credit itself now lands server-side).

   Parameters (as received via WFBE_CL_FNC_HandlePVF dispatch):
     0 - fixed pool total (or legacy payout amount) (number)
     1 - optional active recipient count for an exact-pool notification

   The PVF is addressed to the owning side (WFBE_CO_FNC_SendToClients side parameter),
   so only clients on the bank-owning side receive it.
*/

//--- Malformed-payload guard: ensure _this is ARRAY with >= 1 element (amount).
if (!((typeName _this) in ["ARRAY"]) || {count _this < 1}) exitWith {};
Private ["_amount","_playerCount"];

if (isNil "WFBE_Client_SideID") exitWith {};

_amount = _this select 0;

if (!alive player) exitWith {}; //--- M-3: the pool is divided by ALIVE players only (Server_BankIncome.sqf:39); a dead-at-tick player applying the share makes total payout exceed the 6000 pool
//--- J1 funds authority: wallet write removed - the server credits each recipient group directly for an exact pool split (or group _killer for the bank-raid bonus).

if (count _this > 1) then {
	_playerCount = _this select 1;
	Format ["Bank dividend: $%1 pool split across %2 active players.", _amount, _playerCount] Call GroupChatMessage;
} else {
	Format [Localize "BankDividend", _amount] Call GroupChatMessage;
};
