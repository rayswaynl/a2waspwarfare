# Server Broadcast And Telemetry Loop Reference

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

Three server-only background loops are spawned consecutively from `Server/Init/Init_Server.sqf` and share one idiom: an `isServer` guard, a `WFBE_C_*_ENABLED` feature gate, an interval floored at 30 seconds, and a **wait-first** loop body so nothing fires at `time == 0` boot. Two of them push a one-shot announcement to every client through a paired Client PVF handler; the third emits a structured RPT line for the off-engine dashboard. This page documents those loops, their tunables, the load-bearing nil-destination broadcast contract, the `PLAYERSTAT|v1` wire format, and the two client receivers. This is distinct from the buffered `WASPSTAT|v1` flush path (see `Player-Stats-Branch-Audit.md`) — `server_playerstat_loop` is a separate, always-on emitter and the only telemetry line carrying a player display name.

## Spawn sites and ordering

All three loops are launched after `waitUntil {time > 0}` near the end of server init. Each spawn is double-gated: the same `WFBE_C_*_ENABLED` flag is checked in `Init_Server.sqf` (to avoid even creating the thread) and re-checked inside the spawned script.

| Order | Spawn line | Script | Outer gate | Init log line |
|------|-----------|--------|-----------|--------------|
| 1 | `Server/Init/Init_Server.sqf:780` | `Server\FSM\server_restart_announcer.sqf` | `WFBE_C_RESTART_ENABLED == 1` (`Init_Server.sqf:779`) | "Restart announcer FSM is initialized." (`Init_Server.sqf:781`) |
| 2 | `Server/Init/Init_Server.sqf:787` | `Server\FSM\server_dashboard_announcer.sqf` | `WFBE_C_DASHBOARD_ANNOUNCE_ENABLED == 1` (`Init_Server.sqf:786`) | "Dashboard-link announcer FSM is initialized." (`Init_Server.sqf:788`) |
| 3 | `Server/Init/Init_Server.sqf:795` | `Server\FSM\server_playerstat_loop.sqf` | `WFBE_C_PLAYERSTAT_ENABLED == 1` (`Init_Server.sqf:794`) | "Player-stat leaderboard emitter FSM is initialized." (`Init_Server.sqf:796`) |

Despite the `FSM` directory and the "FSM is initialized" log wording, all three are plain `.sqf` loops launched with `execVM` — there is no `.fsm` here.

## The nil-destination broadcast contract

Both announcers reach clients via `WFBE_CO_FNC_SendToClients` (defined `Common/Init/Init_Common.sqf:158`, body `Common/Functions/Common_SendToClients.sqf`) with the call shape `[nil, "<PVFName>", [args]]`. The first array element is the **destination** and it MUST be `nil`. The reason lives in the client dispatcher:

| Concern | Detail | Citation |
|--------|--------|----------|
| Destination read | `_destination = _publicVar select 0` | `Client/Functions/Client_HandlePVF.sqf:12` |
| nil → run everywhere | `if (isNil '_destination') then {_destination = 0; _exit = false}` — only a genuinely nil destination clears the exit flag, so the PVF runs on every client | `Client/Functions/Client_HandlePVF.sqf:26` |
| literal 0 reaches nobody | If a literal `0` is passed, it is not nil; `_exit` stays `true` (set at `:10`), the SIDE/STRING match arms (`:27-28`) don't fire, and `:30` `exitWith` bails — so the handler runs on no client | `Client/Functions/Client_HandlePVF.sqf:10,26,30` |

Both loops carry this same CRITICAL warning in their file header (`server_dashboard_announcer.sqf:8-9`, `server_restart_announcer.sqf:11-13`): a literal `0` is a valid machine id that matches no client, so the message would be addressed to nobody.

## server_restart_announcer.sqf — scheduled-restart countdown

Server-only countdown (work-order item 15). Once mission uptime reaches `(RESTART_AT_MIN - RESTART_WARN_MIN)` minutes, it broadcasts one warning per minute for the final `RESTART_WARN_MIN` minutes, fires **exactly** `RESTART_WARN_MIN` times, and emits **no** T-0 broadcast.

| Aspect | Detail | Citation |
|--------|--------|----------|
| Guards | `!isServer` exit; `WFBE_C_RESTART_ENABLED != 1` exit | `server_restart_announcer.sqf:19-20` |
| Degenerate window | `WFBE_C_RESTART_WARN_MIN < 1` exits with a WARNING log (announcer disabled) | `server_restart_announcer.sqf:29-31` |
| Warn-start minute | `_warnStartMin = _restartAt - _warnMin` (e.g. 90-5 = 85) | `server_restart_announcer.sqf:33` |
| Per-minute guard | `_lastAnnounced` starts at -1; a send only happens when `_minsRemaining != _lastAnnounced` | `server_restart_announcer.sqf:34,46-47` |
| Elapsed/remaining math | `_minsElapsed = floor (time / 60)`; `_minsRemaining = _restartAt - _minsElapsed` | `server_restart_announcer.sqf:39,44` |
| Fire condition | `_minsRemaining >= 1 && _minsRemaining <= _warnMin && _minsRemaining != _lastAnnounced` — clamps to `[1.._warnMin]`, so no T-0 sixth send | `server_restart_announcer.sqf:46` |
| Broadcast | `[nil, "RestartAnnounce", [Format [_msgTpl, _minsRemaining]]] Call WFBE_CO_FNC_SendToClients` — minutes-remaining substituted server-side into `%1` | `server_restart_announcer.sqf:48` |
| Loop end | `if (_minsRemaining < 1) exitWith {...}` once at/past the final minute | `server_restart_announcer.sqf:53-55` |
| Poll cadence | `sleep 5` per iteration | `server_restart_announcer.sqf:58` |

### Restart tunables

| Variable | Default (config) | Meaning | Citation |
|---------|------------------|---------|----------|
| `WFBE_C_RESTART_ENABLED` | `1` | 0 disables the announcer entirely | `Common/Init/Init_CommonConstants.sqf:558` |
| `WFBE_C_RESTART_AT_MIN` | `90` | Mission-uptime minute at which the scheduled restart occurs | `Common/Init/Init_CommonConstants.sqf:559` |
| `WFBE_C_RESTART_WARN_MIN` | `5` | Warn this many minutes out; fires exactly this many times | `Common/Init/Init_CommonConstants.sqf:560` |
| `WFBE_C_RESTART_MSG` | `"SERVER RESTART IN %1 MINUTE(S) - finish up and find cover."` | Template; `%1` = minutes remaining | `Common/Init/Init_CommonConstants.sqf:561` |

Note: the in-script `getVariable` fallback for the message (`server_restart_announcer.sqf:26`) is the terser `"SERVER RESTART IN %1 MINUTE(S)."`; the richer config-constant default above wins whenever `Init_CommonConstants.sqf` has run (the normal path).

## server_dashboard_announcer.sqf — periodic dashboard-link broadcast

Every `DASHBOARD_ANNOUNCE_INTERVAL` seconds it pushes the public live-stats URL to every client's general chat via the `DashboardAnnounce` PVF. First broadcast is after one full interval (no boot spam).

| Aspect | Detail | Citation |
|--------|--------|----------|
| Guards | `!isServer` exit; `WFBE_C_DASHBOARD_ANNOUNCE_ENABLED != 1` exit | `server_dashboard_announcer.sqf:15-16` |
| Interval floor | `if (_interval < 30) then {_interval = 30}` — never faster than every 30s | `server_dashboard_announcer.sqf:23` |
| Loop body | `sleep _interval;` then `[nil, "DashboardAnnounce", [_msg]] Call WFBE_CO_FNC_SendToClients;` | `server_dashboard_announcer.sqf:28-29` |
| Per-send log | INFORMATION "Broadcast dashboard link to all clients." | `server_dashboard_announcer.sqf:30` |

### Dashboard tunables

| Variable | Default (config) | Meaning | Citation |
|---------|------------------|---------|----------|
| `WFBE_C_DASHBOARD_ANNOUNCE_ENABLED` | `1` | 0 disables the announcer | `Common/Init/Init_CommonConstants.sqf:564` |
| `WFBE_C_DASHBOARD_ANNOUNCE_INTERVAL` | `300` | Seconds between broadcasts (5 min); floored at 30 in the loop | `Common/Init/Init_CommonConstants.sqf:565` |
| `WFBE_C_DASHBOARD_MSG` | `"WASP LIVE STATS  >>  http://78.46.107.142:8080/  <<  ..."` (full live-stats blurb) | The broadcast line | `Common/Init/Init_CommonConstants.sqf:566` |

As with the restart message, the in-script `getVariable` fallback (`server_dashboard_announcer.sqf:21`, `"WASP live stats: http://78.46.107.142:8080/"`) is only used if the config constant is unset.

## server_playerstat_loop.sqf — Top-Players leaderboard emitter

Every `PLAYERSTAT_INTERVAL` seconds, emits one `PLAYERSTAT` RPT line per connected human player. It is the ONLY telemetry carrying the player display name (every other WASPSTAT line is UID-only), so it is what lets the off-engine dashboard map UID → name → score → side for the Top-Players tab. It adds no new server state: kills/deaths are emitted as `0` and folded dashboard-side from the existing `KILL` stream.

| Aspect | Detail | Citation |
|--------|--------|----------|
| Guards | `!isServer` exit; `WFBE_C_PLAYERSTAT_ENABLED != 1` exit; `WFBE_C_STATLOG != 1` exit | `server_playerstat_loop.sqf:26-28` |
| Interval floor | `if (_interval < 30) then {_interval = 30}` | `server_playerstat_loop.sqf:33` |
| Shared sequence | Lazily inits `WFBE_WASPSTAT_SEQ = 0` if nil — shared with the other v1 emitters so records stay ordered | `server_playerstat_loop.sqf:36` |
| Player set | `(call BIS_fnc_listPlayers) - _hcs` where `_hcs = WFBE_HEADLESSCLIENTS_ID` — connected humans minus registered HC leaders | `server_playerstat_loop.sqf:44,49` |
| Per-player guards | `isPlayer _p`; `_uid != ""`; `!((group _p) in _hcs)` (HC/AI return "" UID — second safety net) | `server_playerstat_loop.sqf:56,58` |
| Name sanitisation | Strip `"|"` (ASCII 124) from `name _p` so it can't break the delimiter | `server_playerstat_loop.sqf:59-64` |
| Side encoding | `switch (side _p) do { case west:{1}; case east:{2}; case resistance:{3}; default {0} }` — identical encoding to `Server/Stats/StatsFlush.sqf:25` | `server_playerstat_loop.sqf:65` |
| Score | `score _p` (engine score — authoritative per-player score in WFBE) | `server_playerstat_loop.sqf:67` |
| Emit | `diag_log _line` (an RPT line, not a PVF) | `server_playerstat_loop.sqf:73` |

The `WFBE_C_STATLOG` gate (`:28`) is the always-on structured-telemetry master switch (`WFBE_C_STATLOG = 1` at `Common/Init/Init_CommonConstants.sqf:588`); reusing it lets the loop ship without touching the OFF-by-default `WFBE_C_STATS_ENABLED` buffer path.

### PLAYERSTAT|v1 wire format

Emitted at `server_playerstat_loop.sqf:69` (and the optional 11th field at `:72`):

```
PLAYERSTAT|v1|<seq>|<name>|<uid>|<side>|<score>|<kills>|<deaths>|t=<roundMinutes>[|td=<townsDenied>]
```

| Field | Source | Notes | Citation |
|------|--------|-------|----------|
| `seq` | `WFBE_WASPSTAT_SEQ` (post-increment) | shared monotonic counter | `server_playerstat_loop.sqf:68-69` |
| `name` | `name _p`, `"|"` stripped | display name (the unique value of this line) | `server_playerstat_loop.sqf:59-64,69` |
| `uid` | `getPlayerUID _p` | rows with `""` UID skipped | `server_playerstat_loop.sqf:57-58,69` |
| `side` | switch | 1=WEST, 2=EAST, 3=GUER, 0=other | `server_playerstat_loop.sqf:65,69` |
| `score` | `score _p` | engine score | `server_playerstat_loop.sqf:67,69` |
| `kills` / `deaths` | literal `0` / `0` | folded dashboard-side from KILL stream | `server_playerstat_loop.sqf:8-9,69` |
| `t=` | `round (time / 60)` | round minutes | `server_playerstat_loop.sqf:45,69` |
| `td=` | `_p getVariable ["wfbe_guer_td", 0]` | towns-denied; **11th field present ONLY when `WFBE_C_GUER_PLAYERSIDE > 0`** | `server_playerstat_loop.sqf:72` |

### PLAYERSTAT tunables

| Variable | Default (config) | Meaning | Citation |
|---------|------------------|---------|----------|
| `WFBE_C_PLAYERSTAT_ENABLED` | `1` | 0 disables the per-player emit | `Common/Init/Init_CommonConstants.sqf:572` |
| `WFBE_C_PLAYERSTAT_INTERVAL` | `60` | Seconds between snapshot bursts (floored at 30) | `Common/Init/Init_CommonConstants.sqf:573` |
| `WFBE_C_STATLOG` | `1` | Master structured-telemetry RPT gate | `Common/Init/Init_CommonConstants.sqf:588` |
| `WFBE_C_GUER_PLAYERSIDE` | `0` | >0 enables the GUER faction and the `td=` field | `Common/Init/Init_CommonConstants.sqf:76` |

Because `WFBE_C_GUER_PLAYERSIDE` defaults to `0`, the documented 10-field format is the default; the `td=` 11th field only appears on GUER-enabled deployments.

## Client PVF receivers

Both announcers are delivered through PVFs registered in `Common/Init/Init_PublicVariables.sqf` (the list assembled there is compiled into `CLTFNC<Name>` handlers):

| PVF name | Registration | Handler file |
|---------|-------------|--------------|
| `RestartAnnounce` | `Common/Init/Init_PublicVariables.sqf:49` | `Client/PVFunctions/RestartAnnounce.sqf` |
| `DashboardAnnounce` | `Common/Init/Init_PublicVariables.sqf:50` | `Client/PVFunctions/DashboardAnnounce.sqf` |

### DashboardAnnounce.sqf

| Aspect | Detail | Citation |
|--------|--------|----------|
| Interface bail | `if (!hasInterface) exitWith {}` — HC / dedicated server have no UI | `Client/PVFunctions/DashboardAnnounce.sqf:14` |
| Param | `_msg = _this select 0` (fully-formatted string built server-side) | `Client/PVFunctions/DashboardAnnounce.sqf:18` |
| Display | `systemChat _msg` — non-intrusive chat-log line, no titleText takeover | `Client/PVFunctions/DashboardAnnounce.sqf:20` |

### RestartAnnounce.sqf

| Aspect | Detail | Citation |
|--------|--------|----------|
| Interface bail | `if (!hasInterface) exitWith {}` | `Client/PVFunctions/RestartAnnounce.sqf:11` |
| Param | `_msg = _this select 0` (minutes already substituted server-side) | `Client/PVFunctions/RestartAnnounce.sqf:15` |
| Display | `[_msg, "PLAIN DOWN"] Call TitleTextMessage;` then `_msg Call GroupChatMessage;` — more intrusive than the dashboard line (a titleText plus a chat copy) | `Client/PVFunctions/RestartAnnounce.sqf:17-18` |

The split is deliberate: the dashboard link is a recurring 5-minute reminder (chat-only, quiet), whereas the restart warning is a time-critical, once-per-minute countdown (titleText + chat).

## Continue Reading

- [Player-Stats-Branch-Audit](Player-Stats-Branch-Audit) — the distinct buffered `WASPSTAT|v1` flush path (`StatsFlush.sqf`) and its DiscordBot consumer.
- [Networking-And-Public-Variables](Networking-And-Public-Variables) — how PVFs are registered and dispatched across the wire.
- [PVF-Dispatch-Implementation-Playbook](PVF-Dispatch-Implementation-Playbook) — the `SendToClients`/`HandlePVF` destination-routing contract in depth.
- [Kill-And-Score-Pipeline](Kill-And-Score-Pipeline) — the engine score and KILL telemetry stream the leaderboard folds in.
- [GLOBALGAMESTATS-Extension-Reference](GLOBALGAMESTATS-Extension-Reference) — the off-engine extension/dashboard side of WASP telemetry.
