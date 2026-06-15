/* BankPayout.sqf — client-side PVF handler.
   Pays the local player a bank dividend and shows a quiet group-chat notification.

   Parameters (as received via WFBE_CL_FNC_HandlePVF dispatch):
     0 - payout amount (number)

   The PVF is addressed to the owning side (WFBE_CO_FNC_SendToClients side parameter),
   so only clients on the bank-owning side receive it.
*/
Private ["_amount"];

if (isNil "WFBE_Client_SideID") exitWith {};
//--- E3: the server splits the FIXED 6000 pool among ALIVE side players, but this side-targeted PVF
//--- reaches ALL side clients incl. the dead/respawning -> without an alive gate dead players also draw
//--- a share and the total injected exceeds the pool by share x deadPlayers. Skip when local player dead.
if (!alive player) exitWith {};

_amount = _this select 0;

_amount Call WFBE_CL_FNC_ChangeClientFunds;

Format [Localize "BankDividend", _amount] Call GroupChatMessage;
