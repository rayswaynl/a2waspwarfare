/* DashboardAnnounce.sqf — client-side PVF handler (dashboard-link announcer, claude-gaming 2026-06-14).
   Prints the public live-stats dashboard link into every client's general chat, server-driven,
   so players always know where to find live server FPS, AI unit balance / K-D, and per-build
   benchmarks.

   Parameters (via WFBE_CL_FNC_HandlePVF dispatch):
     0 - the fully-formatted announcement string (built server-side)

   Broadcast globally (nil destination) by Server\FSM\server_dashboard_announcer.sqf, so every
   client on every side sees it. Uses systemChat so the line lands in the chat log without a
   titleText takeover (non-intrusive on a recurring 5-minute cadence). Headless clients / the
   dedicated server have no interface and bail.
*/
if (!hasInterface) exitWith {};

Private ["_msg"];

_msg = _this select 0;

systemChat _msg;
