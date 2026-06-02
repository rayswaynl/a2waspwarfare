# Performance Opportunity Sweep

This page ranks source-backed performance opportunities found in the Chernarus source mission. It separates quick low-risk wins from higher-value fixes that are already bundled with security, correctness or gameplay behavior.

## Ranked Opportunities

| Priority | Opportunity | Source evidence | Why it matters | Implementation shape |
| --- | --- | --- | --- | --- |
| P0 | PVF dispatcher lookup | `Server/Functions/Server_HandlePVF.sqf:14`, `Client/Functions/Client_HandlePVF.sqf:22`, `Common/Init/Init_PublicVariables.sqf:43-50` | Every PVF dispatch recompiles the sender-chosen function string even though init already compiles `CLTFNC*` and `SRVFNC*`. This is also DR-1 security hardening. | Use the [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook): validated namespace/allowlist lookup, keep `Spawn`, log rejects. |
| P1 | Hosted server FPS loop sleep/consolidation | `Server/GUI/serverFpsGUI.sqf:1-11`, `Server/Module/serverFPS/monitorServerFPS.sqf:1-8`, `Server/Init/Init_Server.sqf:577-595` | Both loops sleep only inside `isDedicated`. On hosted/listen server they can spin forever. Dedicated servers also run two near-identical 8-second FPS publishers. | If hosted mode matters, either exit immediately when `!isDedicated` or move sleep outside the branch. Consider one shared publisher for both `SERVER_FPS_GUI` and `WFBE_VAR_SERVER_FPS`. |
| P1 | Supply mission command-center scan narrowing | `Server/Module/supplyMission/supplyMissionStarted.sqf:37-45` | Every active supply mission checks every nearby object class with `nearestObjects [..., [], 80]` every 3 seconds, then filters with `isKindOf "Base_WarfareBUAVterminal"`. | Change the scan class array to command-center terminal classes or the base `Base_WarfareBUAVterminal` class if OA inheritance behaves as expected. Keep the 3-second cadence unless smoke data says otherwise. |
| P2 | Duplicate `Skill_Init` and non-idempotent Soldier AI cap | `Client/Init/Init_Client.sqf:547`, `Client/Init/Init_Client.sqf:571-572`, `Client/Module/Skill/Skill_Init.sqf:39-49` | Client init runs `Skill_Init.sqf` twice. For Soldier class, that multiplies local `WFBE_C_PLAYERS_AI_MAX` by 1.5 twice. With the default 16, the local cap can become 36 instead of the intended 24. This is a balance/perf multiplier. | Compile/init skills once, then call `WFBE_SK_FNC_Apply` separately. Or make the Soldier cap adjustment idempotent by storing base cap / applied flag. |
| P2 | Factory queue broadcast churn and soft-lock | `Client/Functions/Client_BuildUnit.sqf:167-207`, `Client/Functions/Client_BuildUnit.sqf:364-365`, `Client/Functions/Client_BuildUnit.sqf:467-469` | Queue token is low-entropy random, `queu` is broadcast on each mutation, and empty-vehicle exit skips the later local queue decrement. This is both player-facing correctness and network churn. | Use the existing `factory-queue-cleanups` backlog: decrement on every exit path, use unique queue tokens, reduce public queue writes where UI allows. |
| P2 | WASP marker dialog busy-spin | `WASP/global_marking_monitor.sqf:57-73`, `WASP/global_marking_monitor.sqf:80-81` | Double-click map marker naming disables user input and then spins until display 54 appears or a 2-second timeout expires. The same file already uses a throttled `waitUntil {sleep 0.1; ...}` pattern for display 12. | Replace the inner `while {time < _this}` with a throttled wait loop that always re-enables input. Smoke map double-click marker naming. |
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

This is a contained low-risk improvement because the code already wants one class family. The [Arma 2 OA external reference guide](Arma-2-OA-External-Reference-Guide) flags broad `nearestObjects` scans as review targets, and the supply mission cleanup playbook already calls this out.

Validation:

- Source-only: broad empty class array is gone.
- Dedicated smoke: supply completion still detects command centers for both sides and PR #1 supply helicopter/truck variants.
- JIP note: completion detection is server-side; cooldown JIP behavior should remain pull-based and unchanged.

### Duplicate Skill Initialization

`Init_Client.sqf` runs `Skill_Init.sqf` at `:547`, selects default gear based on `WFBE_SK_V_Type`, then runs `Skill_Init.sqf` again at `:571` before `WFBE_SK_FNC_Apply`.

`Skill_Init.sqf:49` mutates `WFBE_C_PLAYERS_AI_MAX` for Soldier class by setting it to `ceil (1.5 * current value)`. Because there is no guard or remembered base value, the double init compounds the cap. With default `WFBE_C_PLAYERS_AI_MAX = 16`, first init gives 24 and second init gives 36.

This is an opportunity because it can inflate per-player AI counts and affect server/client load. It is also a balance bug if Soldier was intended to get only one 1.5x boost.

Validation:

- Source-only: `Skill_Init.sqf` runs once, or the Soldier cap mutation is idempotent.
- Local smoke: Soldier sees the intended AI cap; non-Soldier classes keep their normal cap.
- Respawn smoke: `Client_PreRespawnHandler.sqf` can still call `WFBE_SK_FNC_Apply`.

### Factory Queue

`Client_BuildUnit.sqf:167-172` uses `varQueu`, then immediately changes `varQueu` to `random(10)+random(100)+random(1000)`. Queue changes are broadcast with `_building setVariable ["queu", _queu, true]` at `:172`, `:191` and `:207`. Empty vehicle purchases can exit at `:365` before the local queue cap is decremented at `:467-469`.

This is already in the hardening backlog as `factory-queue-cleanups`. Treat the soft-lock first, then reduce token/broadcast churn. Because the queue is visible to clients, do not silently remove network publication without checking UI consumers.

Validation:

- Repeated crewless empty-vehicle purchases do not soft-lock the local queue.
- Two simultaneous buyers cannot collide on the front token.
- Queue UI remains correct with reduced broadcasts.

### WASP Marker Dialog

`global_marking_monitor.sqf:57-73` disables input, spawns a 2-second window, and polls `findDisplay 54` without sleep. The same file uses a better `waitUntil {sleep 0.1; !isNull (findDisplay 12)}` pattern at `:80`.

This is not a server-wide disaster because it is one player action and time-bounded. It is still a friendly low-risk cleanup because the code already has the desired idiom.

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
3. Duplicate `Skill_Init` idempotency, because it can inflate AI caps.
4. Supply mission scan narrowing, bundled with the supply mission authority cleanup playbook.
5. Factory queue cleanup, because it fixes both soft-lock and network churn.
6. WASP marker dialog wait cleanup.
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
- New cleanup package: `client-skill-init-idempotency`.

## Continue Reading

Previous: [AI, headless and performance](AI-Headless-And-Performance) | Next: [Hardening roadmap](Hardening-Implementation-Roadmap)

Main map: [Home](Home) | Fast path: [Feature status](Feature-Status-Register) | Agent file: [`agent-context.json`](agent-context.json)
