/* BankPayout.sqf — client-side PVF handler.
   Pays the local player a bank dividend and shows a quiet group-chat notification.

   Parameters (as received via WFBE_CL_FNC_HandlePVF dispatch):
     0 - payout amount (number)

   The PVF is addressed to the owning side (WFBE_CO_FNC_SendToClients side parameter),
   so only clients on the bank-owning side receive it.
*/
Private ["_amount"];

if (isNil "WFBE_Client_SideID") exitWith {};

_amount = _this select 0;

if (!alive player) exitWith {}; //--- M-3: the pool is divided by ALIVE players only (Server_BankIncome.sqf:39); a dead-at-tick player applying the share makes total payout exceed the 6000 pool
_amount Call WFBE_CL_FNC_ChangeClientFunds;

Format [Localize "BankDividend", _amount] Call GroupChatMessage;
