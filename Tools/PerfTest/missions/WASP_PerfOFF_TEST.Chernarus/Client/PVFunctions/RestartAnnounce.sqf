/* RestartAnnounce.sqf — client-side PVF handler (work-order item 15).
   Displays the scheduled-restart countdown on each client, server-driven.

   Parameters (as received via WFBE_CL_FNC_HandlePVF dispatch):
     0 - fully-formatted announcement string (server already substituted minutes-remaining)

   Broadcast globally (nil destination) by Server\FSM\server_restart_announcer.sqf,
   so every client — every side — sees the warning. Headless clients / the dedicated
   server have no interface and bail immediately.
*/
if (!hasInterface) exitWith {};

Private ["_msg"];

_msg = _this select 0;

[_msg, "PLAIN DOWN"] Call TitleTextMessage;
_msg Call GroupChatMessage;
