# Performance Opportunity Sweep

This page ranks source-backed performance opportunities found in the Chernarus source mission. It separates quick low-risk wins from higher-value fixes that are already bundled with security, correctness or gameplay behavior.

For the old BennyBoy WarfareBE comparison that sparked the current FPS discussion, see [Old WarfareBE performance comparison](Old-WarfareBE-Performance-Comparison). That page separates old-code lessons from A/B test variables so current Wasp changes can be measured rather than guessed.

## Ranked Opportunities

| Priority | Opportunity | Source evidence | Why it matters | Implementation shape |
| --- | --- | --- | --- | --- |
| P0 | PVF dispatcher lookup | `Server/Functions/Server_HandlePVF.sqf:14`, `Client/Functions/Client_HandlePVF.sqf:22`, `Common/Init/Init_PublicVariables.sqf:43-50` | Every PVF dispatch recompiles the sender-chosen function string even though init already compiles `CLTFNC*` and `SRVFNC*`. This is also DR-1 security hardening. | Use the [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook): validated namespace/allowlist lookup, keep `Spawn`, log rejects. |
| P1 | Hosted server FPS loop sleep/consolidation | `origin/master` `Server/GUI/serverFpsGUI.sqf:1-12`, `Server/Module/serverFPS/monitorServerFPS.sqf:1-8`; branch-local guarded files at `:1-10` / `:1-8` | `origin/master` still has the DR-19 busy-loop shape. This docs branch has early `!isDedicated` exits in both publishers; `origin/release/2026-06-feature-bundle` has a guarded `serverFpsGUI.sqf` and removes the redundant Chernarus `monitorServerFPS.sqf` path. Arma smoke remains pending. | Merge/adopt the branch fix before calling DR-19 shipped on master; smoke dedicated RHUD FPS updates and hosted/listen no-spin behavior. See [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep). |
| P1 | Old-FPS scout easy-win bundle | Returned scout thread `old-warfarebe-fps-scout`; 2026-06-05 delegated report `Old-BE-vs-Wasp-FPS-Archaeology.md`; owner pages [Old WarfareBE performance comparison](Old-WarfareBE-Performance-Comparison), [AI/headless](AI-Headless-And-Performance), [Player AI caps](Player-AI-Caps-And-Role-Balance) | The best cheap actions are now evidence-routed: test normal-role AI cap `8-10`, reduce or role-gate commander bonus, count AI by source, verify HC is actually carrying town/static AI, consolidate/consumer-map duplicate FPS publishers, pin view distance for tests, run PerformanceAudit/AntiStack ON/OFF presets, and keep static-defense HC readback out of "confirmed FPS win" claims. | Treat as a test/config/docs bundle first. Only patch source after smoke chooses a lane: role-aware cap policy, FPS publisher consolidation, audit default choice, safer town vehicle despawn, low-SV town group tuning or static-defense tracking. |
| P1 | Supply mission command-center scan narrowing | `origin/master` `Server/Module/supplyMission/supplyMissionStarted.sqf:24-28`; branch-local `:24-28`; release `:50-56` | `origin/master` still scans all object classes inside 80 m then filters in SQF. This docs branch narrows the 80 m scan to `["Base_WarfareBUAVterminal"]`; `origin/release/2026-06-feature-bundle` carries a PR #1-compatible narrowed scan with heli-aware radius. Arma smoke remains pending. | Merge/adopt the branch fix before calling DR-39 shipped on master; smoke truck/heli delivery at command centers and no-completion near unrelated objects. See [Supply mission scan narrowing](Supply-Mission-Scan-Narrowing). |
| P2 | Duplicate `Skill_Init` and non-idempotent Soldier AI cap | `origin/master` `Client/Init/Init_Client.sqf:561,585-586`; docs-branch `:547,571`; `Client/Module/Skill/Skill_Init.sqf:39-49` | `origin/master` and `origin/release/2026-06-feature-bundle` still run `Skill_Init.sqf` twice before applying skills. This docs branch removes the second init and keeps `WFBE_SK_FNC_Apply`; Arma smoke remains pending before calling the fix shipped. | Merge/adopt the branch fix, then smoke Soldier/non-Soldier caps and respawn skill reapply. See [Client skill init idempotency](Client-Skill-Init-Idempotency). |
| P2 | Factory queue broadcast churn and soft-lock | `Client/Functions/Client_BuildUnit.sqf:167-172`, `Client/Functions/Client_BuildUnit.sqf:365-369`, `Client/Functions/Client_BuildUnit.sqf:467-469` | Current source still has the random queue token and empty-vehicle counter leak. Public `queu` broadcasts also remain on queue mutations. | Smoke repeated crewless buys, normal crewed/infantry buys, concurrent buyers and factory-dead cleanup. Broadcast reduction remains a follow-up. See [Factory queue cleanup](Factory-Queue-Counter-Token-Cleanup). |
| P2 | WASP marker dialog busy-spin | `WASP/global_marking_monitor.sqf:57-73`, `WASP/global_marking_monitor.sqf:80-81` | Current source still has the short display-54 busy wait; patch with a throttled wait and preserve input re-enable behavior. | Smoke map double-click marker naming, Enter prefixing, Escape cleanup and timeout/no-dialog input re-enable. See [WASP marker wait cleanup](WASP-Marker-Wait-Cleanup). |
| P3 | Cleaner/restorer wide scans | `Server/FSM/cleaners/crater_cleaner.sqf:14-49`, `Server/FSM/cleaners/droppeditems_cleaner.sqf:15,22,29`, `Server/FSM/cleaners/ruins_cleaner.sqf:9-28`, `Server/FSM/restorers/buildings_restorer.sqf:10-26`; cadence/cost guide in [Marker cleanup/restoration atlas](Marker-Cleanup-Restoration-Systems-Atlas#cadence-and-cost-interpretation) | These use very wide class-filtered `nearestObjects` scans, but run on long timers, sleep between per-item work, and already emit PerformanceAudit records. `droppeditems_cleaner.sqf` is the clearest scan-refactor target because it repeats three 20 km scans over the same center for `weaponholder`, `Mine` and `MineE`. Garbage/empty-vehicle collectors are the opposite shape: 0.5-second registry drains where idempotent queue/flag behavior matters more than scan narrowing. | Do not patch first. Use RPT audit rows to prove actual cost, then consider smaller terrain-aware centers/radii, combined scan strategy or tracked-object lists. Fix mine pair removal and garbage flag mismatch as correctness items before speculative cadence changes. |

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

On `origin/master`, `serverFpsGUI.sqf` and `monitorServerFPS.sqf` both run `while {true}` with their only `sleep 8` inside `if (isDedicated)`. On non-dedicated/hosted server, that branch is skipped and the loop has no sleep.

This docs branch's source already has the low-risk DR-19 shape: both publishers exit immediately on `!isDedicated`, then keep the dedicated 8-second cadence. The remaining work is smoke and branch adoption, plus the separate decision of whether to consolidate two closely related FPS variables.

The old-FPS scout rechecked the consumers: RHUD reads `SERVER_FPS_GUI` (`Client/Client_UpdateRHUD.sqf:113`), while no obvious current-source consumer was found for `WFBE_VAR_SERVER_FPS` beyond its publisher. Do not remove it on that search alone; use a branch smoke or full consumer grep across maintained/generated mission copies before consolidation.

Validation:

- Hosted/listen source smoke: both publisher scripts exit when `!isDedicated`.
- Dedicated smoke: both HUD/status consumers still receive server FPS at the expected cadence, or documented consumers are migrated to one shared variable.

### Supply Mission Scan

`origin/master` `supplyMissionStarted.sqf:24-28` scans all object classes within 80 meters and checks each result for `Base_WarfareBUAVterminal`. This docs branch runs the same loop at `:20-28` with the narrowed class filter already in place.

This is patched in this docs branch's source Chernarus and maintained Vanilla Takistan by changing the 80-meter command-center scan to `["Base_WarfareBUAVterminal"]`; `origin/release/2026-06-feature-bundle` carries a PR #1-compatible narrowed scan too. `origin/master` remains broad-scan. The code already wanted that class family, and the 8-meter nearby-player scan intentionally remains broad. Arma smoke remains pending.

Do not "optimize" the command-center scan by switching it to `nearEntities`: the target is a `Base_WarfareBUAVterminal` structure, so the safe shape is class-filtered `nearestObjects`/`nearObjects` plus `isKindOf` (`supplyMissionStarted.sqf:25,28`). In this mission, `nearEntities` belongs to entity/logics proximity scans such as camps, towns, vehicles and units.

Validation:

- Branch-local source/Vanilla: done. This docs branch's source Chernarus and maintained Vanilla Takistan now have one narrowed `["Base_WarfareBUAVterminal"]` 80-meter scan and still have the broad 8-meter nearby-player scan. `origin/master` is not patched.
- Dedicated smoke: supply completion still detects command centers for both sides and PR #1 supply helicopter/truck variants.
- JIP note: completion detection is server-side; cooldown JIP behavior should remain pull-based and unchanged.

### Duplicate Skill Initialization

`origin/master` runs `Skill_Init.sqf` at `Init_Client.sqf:561`, selects default gear based on `WFBE_SK_V_Type`, then runs `Skill_Init.sqf` again at `:585` before `WFBE_SK_FNC_Apply` at `:586`. `origin/release/2026-06-feature-bundle` has the same duplicate pattern at `:562` and `:586`, with Apply at `:587`. This docs branch has the intended shape: `Skill_Init.sqf` once at `:547`, then `WFBE_SK_FNC_Apply` at `:571`.

`Skill_Init.sqf:49` mutates `WFBE_C_PLAYERS_AI_MAX` for Soldier class by setting it to `ceil (1.5 * current value)`. Because there is no guard or remembered base value, the double init compounds the cap. With default `WFBE_C_PLAYERS_AI_MAX = 16`, first init gives 24 and second init gives 36.

This is patched in this docs branch's source Chernarus by removing the second client init call while preserving the later `WFBE_SK_FNC_Apply` call. `origin/master` and the release branch still need adoption; Arma smoke remains pending for Soldier/non-Soldier caps and respawn reapply.

Validation:

- Branch-local source: done. This docs branch runs `Skill_Init.sqf` once and still calls `WFBE_SK_FNC_Apply`; `origin/master` and `origin/release/2026-06-feature-bundle` still have the duplicate init.
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

### AntiStack And Collector Loops

AntiStack loop candidates are measurement-first, not first-patch simplifications. The server startup cluster launches `countPlayerScores`, `updateScoreInternal`, `skillDiffCompensation` and launch-join ACK workers, while garbage and empty-vehicle collectors drain registries at short cadence. These loops have correctness roles around join balance, skill totals, score persistence, cleanup idempotency and player-occupied object safety.

Do not reduce cadence or remove waits before collecting RPT/DB latency evidence and checking disabled-AntiStack, teamswap, launch join, late join and match-end behavior. AntiStack and PerformanceAudit should be explicit A/B variables in old-vs-current performance weekends because both are current-only support surfaces and both default on in current parameter/config paths. For collectors, validate array shape, idempotency flags and crew/player occupancy before optimizing queue drains.

### Client Marker Loops

`updatetownmarkers.sqf` now caches marker names/text, delays closed-map refreshes, and records skipped text writes. `updateteamsmarkers.sqf` updates only when map/GPS/Warfare UI is visible, throttles AI leader updates to 1 second, and records marker operations.

Common marker helpers are in the same caution bucket: `Common_MarkerUpdate.sqf:73-109,182-229` and `Common_AARadarMarkerUpdate.sqf:54-75,105-106,184` already cache marker text/position/color or radar marker state. These are not first-patch targets. Use PerformanceAudit output before touching cadence.

### RHUD

`Client_UpdateRHUD.sqf` sleeps 1 second, caches display/control state, and avoids redundant text/color writes. It should stay measurement-led.

### Cleaner And Restorer Wide Scans

The whole-map cleaner/restorer scripts have wide scans, but they are class-filtered, low cadence and instrumented. Their `sleep 0.5` per item intentionally spreads deletion/restoration work. Treat them as audit-first candidates.

The current source-level cadence readout is now in [Marker cleanup/restoration atlas](Marker-Cleanup-Restoration-Systems-Atlas#cadence-and-cost-interpretation). Use these labels in the server RPT before tuning: `cleaner_droppeditems`, `cleaner_craters`, `cleaner_ruins`, `restorer_buildings`, `cleaner_mines`, `server_garbage_collector` and `emptyvehiclescollector`. A wide scan is not automatically a hot path when the timer is 30-90 minutes; a 0.5-second loop is not automatically unsafe if the registry stays tiny and idempotent.

## Suggested Patch Order

1. PVF dispatcher lookup, because it is both P0 security and performance.
2. Hosted server FPS loop sleep/consolidation, if hosted/listen mode still matters.
3. Completed in branch-local source + maintained Vanilla and present in `origin/release/2026-06-feature-bundle`: supply mission scan narrowing is patched outside `origin/master`; master adoption and smoke remain.
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
