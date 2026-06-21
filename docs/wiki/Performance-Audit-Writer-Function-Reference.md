# Performance Audit Writer Function Reference (Common_PerformanceAudit)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

`Common\Functions\Common_PerformanceAudit.sqf` is a self-contained 241-line local instrumentation framework (author tag "Marty") that produces the `[Performance Audit]` rows in each machine's RPT. It is the *writer* half of the perf-telemetry pipeline; the offline RPT parser that consumes these rows lives in a separate PowerShell tool documented on [PerformanceAuditAnalyzer](PerformanceAuditAnalyzer). There is **no network synchronization** — each client and the server writes only its own RPT (`Common/Functions/Common_PerformanceAudit.sqf:5`).

The file defines eight global code blocks plus a small set of module-state globals. It is loaded once via `Call Compile preprocessFileLineNumbers` at `Common/Init/Init_Common.sqf:47`, so every machine (server, clients, headless client) holds the API. The per-call accumulator (`PerformanceAudit_Record`) is invoked from **44 call sites** across client FSMs, marker loops, cleaners, restorers, and server FSMs.

## Module state and the enable gate

Everything is no-op unless `PerformanceAuditEnabled` is truthy. On load the file derives it from the mission parameter `WFBE_C_PERFORMANCE_AUDIT_ENABLED` (default `0` → disabled), but only if not already set (`Common/Functions/Common_PerformanceAudit.sqf:9`). The server then **force-overrides** the gate ON for itself only — the global param is deliberately left at `0` so clients never run the client audit (`Server/Init/Init_Server.sqf:803-804`, with the rationale comment at `Server/Init/Init_Server.sqf:800-802`).

| Global | Init value | Set at | Meaning |
| --- | --- | --- | --- |
| `PerformanceAuditEnabled` | `(WFBE_C_PERFORMANCE_AUDIT_ENABLED > 0)` | `Common_PerformanceAudit.sqf:9` | Master no-op gate for `_Record`/`_Flush`/`_Run` |
| `PerformanceAuditFlushInterval` | `60` (seconds) | `Common_PerformanceAudit.sqf:10` | `_Run` loop sleep between flushes |
| `PerformanceAuditData_CLIENT` | `[]` | `Common_PerformanceAudit.sqf:11` | Per-call accumulator buffer (CLIENT scope) |
| `PerformanceAuditData_SERVER` | `[]` | `Common_PerformanceAudit.sqf:12` | Per-call accumulator buffer (SERVER scope) |
| `PerformanceAuditMarkerScripts` | `0` | `Common_PerformanceAudit.sqf:13` | Active marker-script counter (snapshot field) |
| `PerformanceAuditAARMarkerScripts` | `0` | `Common_PerformanceAudit.sqf:14` | AAR marker-script counter |
| `PerformanceAuditSessionId` | `Format ["%1_%2_%3", worldName, round diag_tickTime, round (random 1000000)]` | `Common_PerformanceAudit.sqf:16-18` | Per-mission session id so appended RPT files split by game |
| `PerformanceAuditAnchorVersion` | `"20260524"` | `Common_PerformanceAudit.sqf:19` | Schema/anchor version stamped on the session anchor row |

`WFBE_C_PERFORMANCE_AUDIT_ENABLED` is **not** defined in `Init_CommonConstants.sqf`; it is set server-local at `Server/Init/Init_Server.sqf:803` and read defaulted-to-`0` everywhere else. `PerformanceAuditMarkerScripts` is mutated externally by the marker loop (decremented on marker teardown at `Common/Common_MarkerLoop.sqf:152,188`) so the snapshot reflects live marker-script load.

## Function family overview

| Function | Lines | Role |
| --- | --- | --- |
| `PerformanceAudit_Round2` | 21-23 | Helper: round a number to 2 decimals |
| `PerformanceAudit_DataName` | 25-27 | Helper: scope string → `PerformanceAuditData_<scope>` global name |
| `PerformanceAudit_Snapshot` | 29-107 | Build the 22-field environment record for one scope |
| `PerformanceAudit_Log` | 109-149 | Emit one `[Performance Audit]` RPT line from a snapshot + metric tuple |
| `PerformanceAudit_SessionAnchorExtra` | 151-158 | Build the session-anchor EXTRA string (anchor version, diag tick, frame) |
| `PerformanceAudit_Record` | 160-194 | Per-call stopwatch accumulator keyed by metric name |
| `PerformanceAudit_Flush` | 196-220 | Snapshot + emit avg/max-ms rows for the buffer, then clear it |
| `PerformanceAudit_Run` | 222-241 | Per-scope writer loop: session rows, then flush every interval until gameOver |

## PerformanceAudit_Round2 / PerformanceAudit_DataName

| Function | Signature | Returns | Behavior |
| --- | --- | --- | --- |
| `PerformanceAudit_Round2` | `_number call PerformanceAudit_Round2` | Number rounded to 2 decimals | `round ((_this) * 100) / 100` (`Common_PerformanceAudit.sqf:21-23`). Used for daytime/fog/overcast/rain in the snapshot and for ms conversions in the flush. |
| `PerformanceAudit_DataName` | `_scope call PerformanceAudit_DataName` | String | `Format ["PerformanceAuditData_%1", _this]` (`Common_PerformanceAudit.sqf:25-27`). Maps a scope (`"SERVER"`/`"CLIENT"`) to its accumulator-buffer global variable name. |

## PerformanceAudit_Snapshot — the 22-field environment record

Signature: `[_scope] call PerformanceAudit_Snapshot` → returns a 22-element array (`Common_PerformanceAudit.sqf:29-107`). `_scope` is `_this select 0` (`Common_PerformanceAudit.sqf:32`). The snapshot captures lightweight engine/world state so FPS can later be correlated with population, day/night, and weather.

It defaults `_playerName="SERVER"` / `_uid="0"` and overrides them with `name player` / `getPlayerUID player` only when `player` is non-null (`Common_PerformanceAudit.sqf:50-51,57-60`), so client snapshots carry the local player identity while the server snapshot stays anonymous. AI vs player population is split in one `forEach allUnits` pass: `isPlayer` units bump `_players`, otherwise live units bump `_activeAI` (`Common_PerformanceAudit.sqf:67-73`). Active towns are counted only if the `towns` global exists, summing those with `wfbe_active` or `wfbe_active_air` set (`Common_PerformanceAudit.sqf:75-81`).

The returned array, by index (`Common_PerformanceAudit.sqf:83-106`):

| Idx | Field | Source |
| --- | --- | --- |
| 0 | scope | `_scope` (param) |
| 1 | fps | `round diag_fps` |
| 2 | players | `_players` (isPlayer count) |
| 3 | activeAI | `_activeAI` (alive non-player count) |
| 4 | units | `count allUnits` |
| 5 | vehicles | `count vehicles` |
| 6 | teams | `count clientTeams` or `-1` if nil (`Common_PerformanceAudit.sqf:47`) |
| 7 | townsActive | `_townsActive` |
| 8 | markerScripts | `PerformanceAuditMarkerScripts` (`Common_PerformanceAudit.sqf:49`) |
| 9 | playerName | `name player` or `"SERVER"` |
| 10 | uid | `getPlayerUID player` or `"0"` |
| 11 | viewDistance | `viewDistance` (engine) |
| 12 | profileVD | profile `WFBE_PERSISTENT_CONST_VIEW_DISTANCE` def `-1` (`Common_PerformanceAudit.sqf:63`) |
| 13 | targetFPS | profile `WFBE_TARGET_FPS` def `-1` (`Common_PerformanceAudit.sqf:64`) |
| 14 | terrainGrid | profile `WFBE_PERSISTENT_CONST_TERRAIN_GRID` def `-1` (`Common_PerformanceAudit.sqf:65`) |
| 15 | map | `worldName` (`Common_PerformanceAudit.sqf:36`) |
| 16 | dayNightEnabled | `WFBE_DAYNIGHT_ENABLED` def `-1` (`Common_PerformanceAudit.sqf:38`) |
| 17 | daytime | `daytime call PerformanceAudit_Round2` |
| 18 | fog | `fog call PerformanceAudit_Round2` |
| 19 | overcast | `overcast call PerformanceAudit_Round2` |
| 20 | rain | `rain call PerformanceAudit_Round2` |
| 21 | sessionId | `PerformanceAuditSessionId` def `"unknown"` (`Common_PerformanceAudit.sqf:34`) |

## PerformanceAudit_Log — the `[Performance Audit]` RPT line

Signature: `[_snap, _name, _calls, _avgMs, _maxMs, _extra] call PerformanceAudit_Log` (`Common_PerformanceAudit.sqf:109-149`). Takes a snapshot array plus a metric tuple and emits exactly one `diag_log` line. The format string interleaves the 22 snapshot fields with the four metric fields, and the explicit `%N` positional indices in the format pull the snapshot columns out of order so the human-readable line groups session/environment fields first (`Common_PerformanceAudit.sqf:119-148`).

Emitted line shape (`Common_PerformanceAudit.sqf:120`):

```
[Performance Audit] SID=.. MAP=.. DNC=.. DAYTIME=.. FOG=.. OVERCAST=.. RAIN=.. SCOPE=.. PLAYER=".." UID=.. VD=.. PVD=.. TFPS=.. PTG=.. NAME=.. FPS=.. PLAYERS=.. AI=.. UNITS=.. VEHICLES=.. TEAMS=.. TOWNS_ACTIVE=.. MARKERS=.. CALLS=.. AVG_MS=.. MAX_MS=.. EXTRA=..
```

`NAME` is the metric name (e.g. `snapshot`, `session`, `town_activation_scan`); `CALLS`/`AVG_MS`/`MAX_MS`/`EXTRA` are the per-metric stats. This is the line the offline analyzer parses (see [PerformanceAuditAnalyzer](PerformanceAuditAnalyzer)).

## PerformanceAudit_SessionAnchorExtra

Signature: `call PerformanceAudit_SessionAnchorExtra` → returns a string (`Common_PerformanceAudit.sqf:151-158`). Builds the EXTRA payload for the once-per-run session anchor row:

```
state:anchor;anchorVersion:<PerformanceAuditAnchorVersion>;realTime:unavailable_a2oa;diagTick:<diag_tickTime>;frame:<diag_frameno>
```

`realTime` is hard-coded `unavailable_a2oa` because Arma 2 OA exposes no wall-clock; `diagTick` is rounded via `PerformanceAudit_Round2` and `frame` is `diag_frameno` (`Common_PerformanceAudit.sqf:153-156`). Consumed only by `PerformanceAudit_Run` (`Common_PerformanceAudit.sqf:228-229`).

## PerformanceAudit_Record — per-call stopwatch accumulator

Signature: `[_name, _elapsed, _extra, _scope] call PerformanceAudit_Record` (`Common_PerformanceAudit.sqf:160-194`). Exits immediately if the audit is disabled (`Common_PerformanceAudit.sqf:163`). Parameters:

| Param | Idx | Default | Meaning |
| --- | --- | --- | --- |
| `_name` | 0 | (required) | Metric key (one buffer row per distinct name) |
| `_elapsed` | 1 | (required) | Seconds for this call (typically `diag_tickTime - _start`) |
| `_extra` | 2 | `""` | Free-form `key:val;…` annotation string (`Common_PerformanceAudit.sqf:167`) |
| `_scope` | 3 | `if (isServer && !hasInterface) then {"SERVER"} else {"CLIENT"}` | Buffer selector; the default auto-detects a dedicated server / headless client (`Common_PerformanceAudit.sqf:168`) |

It resolves the buffer via `PerformanceAudit_DataName` (`Common_PerformanceAudit.sqf:169-170`), then scans for an existing row with the same `_name`. On a hit it increments `calls`, adds to `total`, raises `max` if this call was slower, and overwrites `extra` only when a non-empty `_extra` is supplied (`Common_PerformanceAudit.sqf:173-187`). On a miss it appends `[_name, 1, _elapsed, _elapsed, _extra]` (`Common_PerformanceAudit.sqf:189-191`). The buffer is written back with `setVariable` (`Common_PerformanceAudit.sqf:193`).

Buffer row shape: `[name, calls, total_seconds, max_seconds, extra]`.

**Canonical call pattern** at sites: capture `_start = diag_tickTime` before the measured work, then `["metric_name", diag_tickTime - _start, "<extra>", "<SCOPE>"] Call PerformanceAudit_Record`. Call sites guard on `!(isNil "PerformanceAudit_Record")` and the enable flag before calling, e.g. `Client/FSM/updateclient.sqf:198-200` (`updateclient_afk`), `Client/FSM/updateclient.sqf:267-269` (`updateclient_total`, timed from `_perfLoopStart` at `Client/FSM/updateclient.sqf:46`), and `Server/FSM/server_town_ai.sqf:124` (`town_activation_scan`). The marker loop records `markerupdate_hq` / `markerupdate_unit` / `markerloop_tick` (`Common/Common_MarkerLoop.sqf:245,350,529`). The server also records an `antistack_state` config row at startup with `_elapsed=0` (`Server/Init/Init_Server.sqf:824`).

## PerformanceAudit_Flush — emit accumulated rows and reset

Signature: `[_scope] call PerformanceAudit_Flush` (`Common_PerformanceAudit.sqf:196-220`). Exits if disabled (`Common_PerformanceAudit.sqf:199`). Steps:

1. Build a fresh snapshot for `_scope` (`Common_PerformanceAudit.sqf:202`) and resolve the buffer (`Common_PerformanceAudit.sqf:203-204`).
2. Emit one `snapshot` row with the EXTRA `"periodic"`, `calls=1`, and zeroed ms metrics (`avgMs=0`, `maxMs=0`) (`Common_PerformanceAudit.sqf:206`: `[_snap, "snapshot", 1, 0, 0, "periodic"] call PerformanceAudit_Log`) — this is the per-flush environment heartbeat.
3. For each buffered metric with `calls > 0`, compute `avgMs = (total/calls)*1000` and `maxMs = max*1000`, both rounded via `PerformanceAudit_Round2`, and emit a row (`Common_PerformanceAudit.sqf:208-217`).
4. **Clear** the buffer back to `[]` (`Common_PerformanceAudit.sqf:219`) so each flush window reports only its own activity.

## PerformanceAudit_Run — the per-scope writer loop

Signature: `[_scope] Spawn PerformanceAudit_Run` (`Common_PerformanceAudit.sqf:222-241`). Exits if disabled (`Common_PerformanceAudit.sqf:225`). On entry it emits two `session` rows: one with the session-anchor EXTRA (`Common_PerformanceAudit.sqf:228-229`) and one with EXTRA `"state:start"` (`Common_PerformanceAudit.sqf:230`). It then loops: `sleep PerformanceAuditFlushInterval` (default 60 s), flush the scope, and break if the `gameOver` global exists and is true (`Common_PerformanceAudit.sqf:232-238`). After the loop it does one final flush so end-of-mission counters are not lost (`Common_PerformanceAudit.sqf:240`).

It is started once per machine inside a `waitUntil {!isNil "PerformanceAudit_Run"}` guard wrapper:

| Scope | Start site |
| --- | --- |
| `SERVER` | `Server/Init/Init_Server.sqf:807-810` (`["SERVER"] Spawn PerformanceAudit_Run`) |
| `CLIENT` | `Client/Init/Init_Client.sqf:383-386` (`["CLIENT"] Spawn PerformanceAudit_Run`) |

Because the server force-enables only its own gate (`Server/Init/Init_Server.sqf:803`) while clients keep the param default `0`, in the live configuration only the server's `_Run` loop actually writes — the client wrapper spawns but `_Run` exits at its disable check (`Common_PerformanceAudit.sqf:225`). Re-enabling the global param would activate the client writer too.

## Notes and hazards

- The disable-check default in `_Record`/`_Flush`/`_Run` is `getVariable ["PerformanceAuditEnabled", true]` (`Common_PerformanceAudit.sqf:163,199,225`) — i.e. if the global were somehow deleted, these would *default to enabled*. In practice the file always sets it on load (`Common_PerformanceAudit.sqf:9`).
- `_scope` auto-detection in `_Record` keys on `isServer && !hasInterface`, so a hosted (listen-server) host counts as CLIENT, and a dedicated server or headless client counts as SERVER (`Common_PerformanceAudit.sqf:168`).
- This writer is purely RPT-side and never touches `publicVariable`/network — it is safe to leave running and cannot create JIP or sync load.

## Continue Reading

- [PerformanceAuditAnalyzer](PerformanceAuditAnalyzer) — the offline PowerShell RPT parser that consumes these `[Performance Audit]` rows.
- [AI-Headless-And-Performance](AI-Headless-And-Performance) — headless-client topology and where the SERVER-scope writer runs.
- [Hosted-Server-FPS-Loop-Sleep](Hosted-Server-FPS-Loop-Sleep) — server-frame budgeting that this audit was built to measure.
- [Function-And-Module-Index](Function-And-Module-Index) — index entry for the `PerformanceAudit_*` writer helpers.
- [Bottleneck-Removal-Queue](Bottleneck-Removal-Queue) — perf findings that drive what gets instrumented with `_Record`.
