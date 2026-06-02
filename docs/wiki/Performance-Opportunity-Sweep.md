# Performance Opportunity Sweep

This page ranks source-backed performance opportunities found in the Chernarus source mission. It separates quick low-risk wins from higher-value fixes that are already bundled with security, correctness or gameplay behavior.

## Ranked Opportunities

| Priority | Opportunity | Source evidence | Why it matters | Implementation shape |
| --- | --- | --- | --- | --- |
| P0 | PVF dispatcher lookup | `Server/Functions/Server_HandlePVF.sqf:14`, `Client/Functions/Client_HandlePVF.sqf:22`, `Common/Init/Init_PublicVariables.sqf:43-50` | Every PVF dispatch recompiles the sender-chosen function string even though init already compiles `CLTFNC*` and `SRVFNC*`. This is also DR-1 security hardening. | Use the [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook): validated namespace/allowlist lookup, keep `Spawn`, log rejects. |
| P1 | Hosted server FPS loop sleep/consolidation | Server/GUI/serverFpsGUI.sqf:1-9, Server/Module/serverFPS/monitorServerFPS.sqf:1-7, Server/Init/Init_Server.sqf:577-595 | Source Chernarus and maintained Vanilla Takistan patched: both publishers now exit immediately when !isDedicated, preserving dedicated 8-second publishing without hosted/listen busy-spin. Arma smoke remains pending. | Smoke dedicated RHUD FPS updates and hosted/listen no-spin behavior. See [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep). |
| P1 | Supply mission command-center scan narrowing | `Server/Module/supplyMission/supplyMissionStarted.sqf:25-28` | Source Chernarus and maintained Vanilla Takistan patched: the 80-meter command-center scan now filters `nearestObjects` to `["Base_WarfareBUAVterminal"]` while preserving the separate 8-meter nearby-player scan. Arma smoke remains pending. | Smoke truck/heli delivery at command centers and no-completion near unrelated objects. See [Supply mission scan narrowing](Supply-Mission-Scan-Narrowing). |
| P2 | Duplicate `Skill_Init` and non-idempotent Soldier AI cap | `Client/Init/Init_Client.sqf:547`, former duplicate `:571`, `Client/Module/Skill/Skill_Init.sqf:39-49` | Patched in source Chernarus and maintained Vanilla Takistan: client init now runs `Skill_Init.sqf` once before class default gear selection, then calls `WFBE_SK_FNC_Apply` without rerunning init. Arma smoke remains pending. | Smoke Soldier/non-Soldier caps and respawn skill reapply. See [Client skill init idempotency](Client-Skill-Init-Idempotency). |
| P2 | Factory queue broadcast churn and soft-lock | `Client/Functions/Client_BuildUnit.sqf:167-172`, `Client/Functions/Client_BuildUnit.sqf:365-369`, `Client/Functions/Client_BuildUnit.sqf:467-469` | Current source still has the random queue token and empty-vehicle counter leak. Public `queu` broadcasts also remain on queue mutations. | Smoke repeated crewless buys, normal crewed/infantry buys, concurrent buyers and factory-dead cleanup. Broadcast reduction remains a follow-up. See [Factory queue cleanup](Factory-Queue-Counter-Token-Cleanup). |
| P2 | WASP marker dialog busy-spin | `WASP/global_marking_monitor.sqf:57-73`, `WASP/global_marking_monitor.sqf:80-81` | Current source still has the short display-54 busy wait; patch with a throttled wait and preserve input re-enable behavior. | Smoke map double-click marker naming, Enter prefixing, Escape cleanup and timeout/no-dialog input re-enable. See [WASP marker wait cleanup](WASP-Marker-Wait-Cleanup). |
| P3 | Cleaner/restorer wide scans | `Server/FSM/cleaners/crater_cleaner.sqf:14-49`, `Server/FSM/cleaners/droppeditems_cleaner.sqf:14-45`, `Server/FSM/cleaners/ruins_cleaner.sqf:9-28`, `Server/FSM/restorers/buildings_restorer.sqf:10-26` | These use very wide class-filtered `nearestObjects` scans, but run on long timers, sleep between per-item work, and already emit PerformanceAudit records. | Do not patch first. Use RPT audit rows to prove actual cost, then consider smaller terrain-aware centers/radii or tracked-object lists. |

## What Was Read

Source files:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/GUI/serverFpsGUI.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Module/serverFPS/monitorServerFPS.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_Server.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Module/supplyMission/supplyMissionStarted.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/WASP/global_marking_monitor.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_BuildUnit.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_HandlePVF.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_HandlePVF.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_PublicVariables.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/FSM/updatetownmarkers.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/FSM/updateteamsmarkers.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Client_UpdateRHUD.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Module/Skill/Skill_Init.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/server_town.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/server_town_ai.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/cleaners/*`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/restorers/buildings_restorer.sqf`

Wiki/docs:

- [AI, headless and performance](AI-Headless-And-Performance)
- [Feature status register](Feature-Status-Register)
- [Hardening roadmap](Hardening-Implementation-Roadmap)
- [Arma 2 OA external reference guide](Arma-2-OA-External-Reference-Guide)
- [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl)

## Notes By Area

### PVF Dispatch

`Init_PublicVariables.sqf:43-50` compiles each listed client/server handler into `CLTFNC*` / `SRVFNC*` globals and installs PVEHs. But `Server_HandlePVF.sqf:14` and `Client_HandlePVF.sqf:22` still do `Spawn (Call Compile _script)` per incoming message.

This is the most valuable performance-adjacent fix because it removes avoidable runtime compilation and closes the DR-1 arbitrary handler-string trust boundary. Do not treat it as a micro-optimization only; it belongs in the P0 hardening branch.

Validation:

- Source-only: every registered `_clientCommandPV` and `_serverCommandPV` resolves to CODE after init.
- Dedicated smoke: one server-bound PVF and one client-bound PVF still work.
- Negative smoke: bogus command string is rejected and logged without executing.

### Hosted Server FPS Loops

`serverFpsGUI.sqf` and `monitorServerFPS.sqf` both run `while {true}`. Their only `sleep 8` sits inside `if (isDedicated)`. On non-dedicated/hosted server, the branch is skipped and the loop has no sleep.

This is a small, low-risk patch if hosted/listen mode is supported. On dedicated servers, the current behavior is not a CPU spin, but there are still two publishers broadcasting closely related values every 8 seconds.

Validation:

- Hosted/listen source smoke: loop exits or sleeps when `!isDedicated`.
- Dedicated smoke: both HUD/status consumers still receive server FPS at the expected cadence, or documented consumers are migrated to one shared variable.

### Supply Mission Scan

`supplyMissionStarted.sqf:37-45` loops while the supply vehicle is alive. Every 3 seconds it scans all object classes within 80 meters and checks each result for `Base_WarfareBUAVterminal`.

This is patched in source Chernarus and maintained Vanilla Takistan by changing the 80-meter command-center scan to `["Base_WarfareBUAVterminal"]`. The code already wanted that class family, and the 8-meter nearby-player scan intentionally remains broad. Arma smoke remains pending.

Validation:

- Source/Vanilla: done. Source Chernarus and maintained Vanilla Takistan now have one narrowed `["Base_WarfareBUAVterminal"]` 80-meter scan and still have the broad 8-meter nearby-player scan.
- Dedicated smoke: supply completion still detects command centers for both sides and PR #1 supply helicopter/truck variants.
- JIP note: completion detection is server-side; cooldown JIP behavior should remain pull-based and unchanged.

### Duplicate Skill Initialization

`Init_Client.sqf` runs `Skill_Init.sqf` at `:547`, selects default gear based on `WFBE_SK_V_Type`, then runs `Skill_Init.sqf` again at `:571` before `WFBE_SK_FNC_Apply`.

`Skill_Init.sqf:49` mutates `WFBE_C_PLAYERS_AI_MAX` for Soldier class by setting it to `ceil (1.5 * current value)`. Because there is no guard or remembered base value, the double init compounds the cap. With default `WFBE_C_PLAYERS_AI_MAX = 16`, first init gives 24 and second init gives 36.

This was patched in source Chernarus and maintained Vanilla Takistan by removing the second client init call while preserving the later `WFBE_SK_FNC_Apply` call. Arma smoke remains pending for Soldier/non-Soldier caps and respawn reapply.

Validation:

- Source/Vanilla: done. Chernarus and maintained Vanilla now run `Skill_Init.sqf` once and still call `WFBE_SK_FNC_Apply`.
- Local smoke: Soldier sees the intended AI cap; non-Soldier classes keep their normal cap.
- Respawn smoke: `Client_PreRespawnHandler.sqf` can still call `WFBE_SK_FNC_Apply`.

### Factory Queue

`Client_BuildUnit.sqf:167-172` still uses the low-entropy random FIFO token. Queue changes are still broadcast with `_building setVariable ["queu", _queu, true]` at `:172`, `:191` and `:207`. Empty vehicle purchases still need local queue-cap cleanup before exiting at `:365`.

The hardening backlog item `factory-queue-cleanups` is patch-ready: soft-lock cleanup and token identity are the first pieces, while public queue broadcast reduction remains a separate UI-aware follow-up. Because the queue is visible to clients, do not silently remove network publication without checking UI consumers.

Validation:

- Repeated crewless empty-vehicle purchases do not soft-lock the local queue.
- Two simultaneous buyers cannot collide on the front token.
- Queue UI remains correct with reduced broadcasts.

### WASP Marker Dialog

`global_marking_monitor.sqf:57-73` still needs a throttled wait for display 54 while preserving input re-enable after display-open or timeout. The same file already used `waitUntil {sleep 0.1; !isNull (findDisplay 12)}` at `:80`.

This remains a small local UI cleanup, not a server-wide performance fix. See [WASP marker wait cleanup](WASP-Marker-Wait-Cleanup) for the patch shape and smoke plan.

Validation:

- Double-clicking the map still opens marker creation and prefixes marker text with player name on Enter.
- Escape still clears handlers.
- Input is always re-enabled, including timeout/no-dialog cases.

## Not First-Patch Items

### Town And Town-AI Loops

`server_town.sqf` and `server_town_ai.sqf` use per-town `nearEntities` scans, but both already have cooperative per-town `sleep 0.05`, a `sleep 5` between full cycles, and PerformanceAudit records with scan/detected/cycle metrics.

Patch only after RPT evidence shows these rows dominate. Changing detection cadence or class filters risks gameplay behavior: capture, town activation, despawn and patrol behavior depend on those scans.

### Client Marker Loops

`updatetownmarkers.sqf` now caches marker names/text, delays closed-map refreshes, and records skipped text writes. `updateteamsmarkers.sqf` updates only when map/GPS/Warfare UI is visible, throttles AI leader updates to 1 second, and records marker operations.

These are not first-patch targets. Use PerformanceAudit output before touching cadence.

### RHUD

`Client_UpdateRHUD.sqf` sleeps 1 second, caches display/control state, and avoids redundant text/color writes. It should stay measurement-led.

### Cleaner And Restorer Wide Scans

The whole-map cleaner/restorer scripts have wide scans, but they are class-filtered, low cadence and instrumented. Their `sleep 0.5` per item intentionally spreads deletion/restoration work. Treat them as audit-first candidates.

## Suggested Patch Order

1. PVF dispatcher lookup, because it is both P0 security and performance.
2. Hosted server FPS loop sleep/consolidation, if hosted/listen mode still matters.
3. Completed in source + maintained Vanilla: supply mission scan narrowing is patched; smoke remains.
5. Factory queue cleanup is patch-ready for counter leak and token identity; current source still needs the code patch, and broadcast reduction remains a later UI-aware follow-up.
6. WASP marker dialog wait cleanup remains an opportunity; code patch and Arma smoke remain.
7. Audit-led cleaner/restorer or marker-loop tuning only after RPT evidence.

## Handoff

For Codex:

- Keep this page linked from dashboard/status/context/backlog.
- Avoid scattering performance notes across subsystem pages unless they are implementation-ready.

For Claude:

- Good contradiction checks: prove whether the double `Skill_Init` call is intentional or historical accident; inspect whether any UI path consumes every broadcast `queu` update; verify exact class inheritance for `Base_WarfareBUAVterminal` in OA before a scan-narrowing patch.

For a future code owner:

- Smallest code patch: hosted FPS loop sleep/exit.
- Highest value patch: PVF dispatcher lookup from the existing playbook.
- Completed cleanup packages: [Client skill init idempotency](Client-Skill-Init-Idempotency), [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep) and [Supply mission scan narrowing](Supply-Mission-Scan-Narrowing), smoke pending.

## Continue Reading

Previous: [AI, headless and performance](AI-Headless-And-Performance) | Next: [Hardening roadmap](Hardening-Implementation-Roadmap)

Main map: [Home](Home) | Fast path: [Feature status](Feature-Status-Register) | Agent file: [`agent-context.json`](agent-context.json)
