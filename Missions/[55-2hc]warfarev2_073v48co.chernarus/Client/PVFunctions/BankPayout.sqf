/* BankPayout.sqf — client-side PVF handler.
   Shows the quiet group-chat dividend notification (J1 funds authority: the credit itself now lands server-side).

   Parameters (as received via WFBE_CL_FNC_HandlePVF dispatch):
     0 - payout amount (number)

   The PVF is addressed to the owning side (WFBE_CO_FNC_SendToClients side parameter),
   so only clients on the bank-owning side receive it.
*/
Private ["_amount"];

if (isNil "WFBE_Client_SideID") exitWith {};

_amount = _this select 0;

if (!alive player) exitWith {}; //--- M-3: the pool is divided by ALIVE players only (Server_BankIncome.sqf:39); a dead-at-tick player applying the share makes total payout exceed the 6000 pool
//--- J1 funds authority: wallet write removed - the server credits each recipient group (WFBE_SE_FNC_CreditSidePlayers for the pool payouts; group _killer for the bank-raid bonus).

Format [Localize "BankDividend", _amount] Call GroupChatMessage;
