# Client FPS And State Telemetry Reference

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

Two independent client-side diagnostic loops feed the RPT with framerate and accumulated-state data. **Client_FpsReport** is a lobby-param-gated, player-only loop that samples `diag_fps` and ships an `[uid, name, avgFps, minFps]` packet to the server, which stamps it with day/night context for a staged day-vs-night performance study. **Client_StateAudit** is an always-on per-minute loop that emits one `STATE-AUDIT:` line relating `diag_fps` to script-count proxies and retained-state counters (markers, groups, corpses) so a session's FPS decay can be correlated with what the client is holding. The two share no variables and run on separate cadences; they are documented together because they form the client half of this mission's framerate telemetry surface.

This page owns the param/variable contract, the publish cadence and clamps, the server stamp schema, and the analysis intent. The incidental cross-link in [Marker-Loop-Engine-And-Registries](Marker-Loop-Engine-And-Registries) (the marker loop writing `WFBE_CL_MarkerBudgetLastServiced` that StateAudit reads) covers the marker loop, not these telemetry functions.

## Client_FpsReport — player FPS reporter

The reporter lives in `Client/Functions/Client_FpsReport.sqf:1-38`, spawned from `Client/Init/Init_Client.sqf:1042` as `[] spawn Compile preprocessFileLineNumbers "Client\Functions\Client_FpsReport.sqf"` at the tail of client init (right after `CLIENT_INIT_READY` is published at `Init_Client.sqf:1036-1038`).

| Step | Source | Detail |
|------|--------|--------|
| Interface gate | `Client_FpsReport.sqf:11` | `if (!hasInterface) exitWith {}` — dedicated server and headless clients have no meaningful client FPS and would pollute the dataset. |
| Param gate | `Client_FpsReport.sqf:12` | `if ((missionNamespace getVariable ["WFBE_C_CLIENT_FPS_REPORT", 0]) != 1) exitWith {}` — the lobby param is the single on/off switch (defaults to `0` if absent here). |
| Interval read + clamp | `Client_FpsReport.sqf:16-17` | `_interval = missionNamespace getVariable ["WFBE_C_CLIENT_FPS_REPORT_INTERVAL", 60]`; if `_interval < 15` it is forced to `15`. |
| Sample count | `Client_FpsReport.sqf:18` | `_n = 5` one-second samples averaged per report — smooths single-frame spikes and captures the worst frame. |
| Startup stagger | `Client_FpsReport.sqf:21` | `sleep (5 + random 20)` so N players don't all publish on the same server tick. |
| Sample loop | `Client_FpsReport.sqf:23-32` | While `!WFBE_GameOver`: takes 5 samples of `diag_fps` at 1s spacing, tracks running `_sum` and `_min` (seeded `1e6`), then `_avg = _sum / _n`. |
| Publish | `Client_FpsReport.sqf:34-35` | `WFBE_FPS_REPORT = [getPlayerUID player, name player, round _avg, round _min]; publicVariableServer "WFBE_FPS_REPORT"`. |
| Inter-report sleep | `Client_FpsReport.sqf:37` | `sleep (_interval - _n)` — the 5 sampling seconds are subtracted so each cycle is exactly `_interval` long. |

The packet schema is `[uid, name, round avg, round min]`. The loop terminates when `WFBE_GameOver` becomes true. Because the whole body is gated by `hasInterface`, only player clients ever appear in the published dataset.

## WFBE_C_CLIENT_FPS_REPORT lobby params

Both params are defined in `Rsc/Parameters.hpp` and selectable from the admin lobby; the SQF reads them through `missionNamespace getVariable` with its own fallback defaults rather than from a constants file (no entry in `Common/Init/Init_CommonConstants.sqf`).

| Param | Source | Values | Default | Role |
|-------|--------|--------|---------|------|
| `WFBE_C_CLIENT_FPS_REPORT` | `Rsc/Parameters.hpp:573-578` | `{0,1}` (Disabled/Enabled) | `1` | Master on/off gate; checked identically on client (`Client_FpsReport.sqf:12`) and server (`Init_Server.sqf:708`). |
| `WFBE_C_CLIENT_FPS_REPORT_INTERVAL` | `Rsc/Parameters.hpp:579-584` | `{15,30,60,120,300}` s | `60` | Seconds between reports; client clamps to a `15`s floor at `Client_FpsReport.sqf:17`. |

Note a documentation discrepancy worth flagging: the comment at `Rsc/Parameters.hpp:570-572` says the feature is "Off by default; flip it in the admin lobby for the data-gathering run," but the class sets `default = 1` (`Parameters.hpp:577`). As written the telemetry is ON by default in the lobby. The SQF-side fallback defaults (`0` for the gate, `60` for the interval) only apply if the variable is wholly absent, not when the param simply takes its lobby default.

## Server receiver and FPSREPORT stamp schema

The receiver is armed in `Server/Init/Init_Server.sqf:701-729`, gated by the same param so the event handler is never registered when telemetry is off.

| Element | Source | Detail |
|---------|--------|--------|
| Arm gate | `Init_Server.sqf:708` | Only registers the handler when `WFBE_C_CLIENT_FPS_REPORT == 1`. |
| PV event handler | `Init_Server.sqf:709-711` | `"WFBE_FPS_REPORT" addPublicVariableEventHandler { ... }`; the packet is `_d = _this select 1`. |
| Live player count | `Init_Server.sqf:712` | `_players = { isPlayer _x } count playableUnits`. |
| Live HC count | `Init_Server.sqf:715` | `_hc = { !isNull _x && {!isNull leader _x} && {alive leader _x} } count (missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []])` — counts non-null, alive-leader headless clients so the planned 0-HC/1-HC/2-HC comparison days bucket cleanly across launches. |
| Log emission | `Init_Server.sqf:716-726` | Single `diag_log` of a pipe-delimited `FPSREPORT|v1|...` line (raw `diag_log`, so it lands regardless of `LOG_CONTENT_STATE`). |
| Confirmation | `Init_Server.sqf:728` | `["INITIALIZATION", "...Client FPS telemetry receiver armed..."] Call WFBE_CO_FNC_LogContent`. |

The emitted line (`Init_Server.sqf:716-726`) carries these fields in order:

| Field | Source | Value |
|-------|--------|-------|
| `uid` | `:716` | `_d select 0` (player UID). |
| `fps` | `:717` | `_d select 2` (rounded client avg FPS). |
| `fpsMin` | `:718` | `_d select 3` (rounded client min FPS). |
| `players` | `:719` | live player count. |
| `hc` | `:720` | live headless-client count. |
| `dnMode` | `:721` | `missionNamespace getVariable ["WFBE_DAYNIGHT_ENABLED", 1]` — day/night cycle ON/OFF state (constant default `1`, `Init_CommonConstants.sqf:84`). |
| `daytime` | `:722` | `round (daytime * 100) / 100` — in-game time of day. |
| `sun` | `:723` | `round (sunOrMoon * 100) / 100` — sun/moon elevation factor. |
| `t` | `:725` | `round (time / 60)` — minute-bucketed mission time. |
| `name` | `:726` | `_d select 1`, logged **LAST** so a `|` in a player name cannot corrupt the earlier pipe-delimited fields. |

The server stamps each report with what the client cannot cheaply know — live player count, live HC count, day/night mode, time of day, sun elevation and the server's own `diag_fps` (`srvFps`, `:724`). The stated purpose (`Init_Server.sqf:701-707`, `Client_FpsReport.sqf:1-7`) is to bucket client FPS day-vs-night and day/night-cycle ON-vs-OFF over a staged rollout (2026-06-15, "Net_2 request") to A/B the accelerated day/night cycle.

## Client_StateAudit — per-minute state-vs-FPS audit

The audit loop lives in `Client/Functions/Client_StateAudit.sqf:1-35`, launched from `Client/Init/Init_Client.sqf:389` as `[] execVM "Client\Functions\Client_StateAudit.sqf"`. Unlike the FPS reporter it has no param gate — it runs on every machine that reaches client init. It waits on `commonInitComplete` (`StateAudit.sqf:8`; set true at `Common/Init/Init_Common.sqf:419`) before looping, and runs `while {!WFBE_GameOver}` with a fixed `sleep 60` (`StateAudit.sqf:34`).

Each pass builds one `STATE-AUDIT:` `diag_log` line (`StateAudit.sqf:24-26`) from these fields:

| Field | Source | Value |
|-------|--------|-------|
| `time` | `:25` | `round time`. |
| `fps` | `:25` | `diag_fps`. |
| `activeSQFScripts` | `:16` | hardcoded `-1` — `diag_activeSQFScripts` is Arma 3 (1.44+) only and even a call-compile probe errors on OA 1.64, so the column is kept as a constant for schema stability. |
| `allMapMarkers` | `:25` | hardcoded `-1` (`allMapMarkers` is Arma-3-only, N/A in A2 OA). |
| `markerScripts` | `:18` | `missionNamespace getVariable ["PerformanceAuditMarkerScripts", -1]` — the OA script-count proxy. |
| `aarMarkerScripts` | `:19` | `missionNamespace getVariable ["PerformanceAuditAARMarkerScripts", -1]`. |
| `allGroups` | `:25` | `count allGroups`. |
| `allDead` | `:25` | `count allDead` (retained corpses). |
| `mapOpen` | `:20` | `1` if `visibleMap` else `0`. |
| `markerRegSize` | `:21` | `count WFBE_CL_UnitMarkerRegistry`, or `-1` if nil. |
| `budgetServiced` | `:22` | `missionNamespace getVariable ["WFBE_CL_MarkerBudgetLastServiced", -1]` — the marker-loop tick written at `Marker-Loop` `:525-531`. |

After emitting the line, the loop optionally forwards it to the audit sink (`StateAudit.sqf:28-32`): when `PerformanceAudit_Record` is not nil **and** `PerformanceAuditEnabled` is true, it calls `["state_audit", 0, _line, "CLIENT"] Call PerformanceAudit_Record`. That sink is documented in [Performance-Audit-Writer-Function-Reference](Performance-Audit-Writer-Function-Reference); neither client telemetry loop nor the FPS-report round-trip is covered there.

The analysis intent (`StateAudit.sqf:1-5`): one line per minute lets a busy session show whether FPS decay tracks scheduled-script count or retained state. The header note that Arma save/load **resumes** suspended scheduled scripts — so save/load FPS-recovery tests do not isolate VM count — is why this log plus the `PerformanceAuditMarkerScripts` counters are treated as the real A/B proof.

## Comparison

| | Client_FpsReport | Client_StateAudit |
|---|---|---|
| Launch | `Init_Client.sqf:1042` (`spawn Compile`) | `Init_Client.sqf:389` (`execVM`) |
| Gate | `hasInterface` + `WFBE_C_CLIENT_FPS_REPORT == 1` | `commonInitComplete` only (always runs) |
| Cadence | `WFBE_C_CLIENT_FPS_REPORT_INTERVAL`, floor 15s | fixed 60s |
| Output | PV `WFBE_FPS_REPORT` → server `FPSREPORT\|v1\|` line | local `STATE-AUDIT:` `diag_log` (+ optional sink) |
| Crosses the wire? | Yes (`publicVariableServer`) | No (local diag only) |
| Terminates on | `WFBE_GameOver` | `WFBE_GameOver` |

## Continue Reading

- [Performance-Audit-Writer-Function-Reference](Performance-Audit-Writer-Function-Reference)
- [Marker-Loop-Engine-And-Registries](Marker-Loop-Engine-And-Registries)
- [View-Distance-And-Target-FPS-Auto-Throttle](View-Distance-And-Target-FPS-Auto-Throttle)
- [Day-Night-Cycle-And-Weather-System](Day-Night-Cycle-And-Weather-System)
- [Public-Variable-Channel-Index](Public-Variable-Channel-Index)
