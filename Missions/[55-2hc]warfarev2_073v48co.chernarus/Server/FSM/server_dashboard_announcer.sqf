/* server_dashboard_announcer.sqf — periodic in-game dashboard-link broadcast (claude-gaming 2026-06-14).

   Every WFBE_C_DASHBOARD_ANNOUNCE_INTERVAL seconds, pushes the live-stats dashboard URL (with a
   one-line explanation) to every client's general chat via the DashboardAnnounce PVF, so players
   always know where to find live server performance, AI balance / K-D, and per-build benchmarks.
   The first broadcast is after one full interval (no t=0 boot spam).

   CRITICAL: the SendToClients destination MUST be nil (global broadcast). A literal 0 is a valid
   "machine id" that matches no client, so the message would reach nobody.

   Spawned from Server\Init\Init_Server.sqf, only when WFBE_C_DASHBOARD_ANNOUNCE_ENABLED==1.
*/
scriptName "Server\FSM\server_dashboard_announcer.sqf";

if (!isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_DASHBOARD_ANNOUNCE_ENABLED", 1]) != 1) exitWith {};

Private ["_interval", "_msg"];

_interval = missionNamespace getVariable ["WFBE_C_DASHBOARD_ANNOUNCE_INTERVAL", 300];
_msg      = missionNamespace getVariable ["WFBE_C_DASHBOARD_MSG", "WASP live stats: http://78.46.107.142:8080/"];

if (_interval < 30) then {_interval = 30}; //--- floor: never spam the chat faster than every 30s.

["INITIALIZATION", Format ["server_dashboard_announcer.sqf: Armed. Broadcasting the dashboard link every %1s.", _interval]] Call WFBE_CO_FNC_LogContent;

while {true} do {
	sleep _interval;                                   //--- wait first, so we do not spam at t=0 boot.
	[nil, "DashboardAnnounce", [_msg]] Call WFBE_CO_FNC_SendToClients;
	["INFORMATION", "server_dashboard_announcer.sqf: Broadcast dashboard link to all clients."] Call WFBE_CO_FNC_LogContent;
};
