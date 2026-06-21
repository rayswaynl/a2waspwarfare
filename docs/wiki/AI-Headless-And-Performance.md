# AI, Headless And Performance

This page is the broad gateway for AI, headless-client behavior, player-AI recovery and performance ownership. For loop-level runtime and HC delegation tables, use [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map); for implementation decisions, use the narrower owner pages linked below.

For the old BennyBoy WarfareBE vs current Wasp FPS archaeology pass, see [Old WarfareBE performance comparison](Old-WarfareBE-Performance-Comparison). It is useful when discussing whether older mission code was lighter, because it compares old per-town FSM activation and FPS-gated client delegation against current global town loops and HC mode.

Unless a row names another ref, source anchors below are from docs head `docs/developer-wiki-index` `ca028bff`. Rechecked 2026-06-14: targeted mission-root diffs from the earlier `b9e80da0` AI runtime pass and the later `ee383941` gateway snapshot to `HEAD` return no checked Chernarus or maintained Vanilla source changes, so the line refs remain valid. Treat stable `origin/master` `cf2a6d6a`, release `a96fdda2`, Miksuu `b8389e74`, `origin/perf/quick-wins` `0076040f` and `origin/feat/ai-commander` `c20ce153` as branch-scope refs before citing their line numbers.

## How To Use This Page

| Need | Open first |
| --- | --- |
| Runtime loop and HC delegation source map | [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map) |
| HC disconnect, callback, timeout and failover design | [Headless delegation and failover](Headless-Delegation-And-Failover-Playbook), [HC upstream history and lessons](HC-Upstream-History-And-Lessons) |
| AI commander, autonomous logistics or `feat/ai-commander` review | [AI commander autonomy audit](AI-Commander-Autonomy-Audit), [branch-only feature smoke pack](Testing-Debugging-And-Release-Workflow#branch-only-feature-smoke-pack) |
| Town AI cleanup safety and player-occupied vehicles | [Town AI vehicle despawn safety](Town-AI-Vehicle-Despawn-Safety#current-branch-matrix) |
| Patrols v2 vs old patrols | [Towns/camps/capture](Towns-Camps-And-Capture-Atlas#patrols-v2-side-upgrade-path), [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map#current-branch-scope) |
| Server FPS, audit RPTs and full-server performance tests | [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas#branch-scope-for-source-anchors), [Performance opportunity sweep](Performance-Opportunity-Sweep), [Testing workflow](Testing-Debugging-And-Release-Workflow) |
| Old BE comparison, player-AI caps and role balance | [Old WarfareBE performance comparison](Old-WarfareBE-Performance-Comparison), [Player AI caps and role balance](Player-AI-Caps-And-Role-Balance) |

## Current Branch Scope

Use this table before turning this broad atlas into a branch claim. Detailed matrices stay on the owner pages.

| Ref | AI / HC / performance scope | Practical route |
| --- | --- | --- |
| Docs head `ca028bff` | Checked Chernarus and maintained Vanilla mission source paths are unchanged from `ee383941` and the older `b9e80da0` AI runtime snapshot. This docs source still lacks Patrols v2 files and still has the old AI supply-truck raw-spawn shape when truck supply plus AI commander logistics are enabled. | Use this page for orientation, then open [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map) or [AI commander autonomy audit](AI-Commander-Autonomy-Audit) before making patch-status claims. |
| Stable `origin/master` `cf2a6d6a` | Safe-disables legacy AI supply-truck logistics, carries Patrols v2 in both maintained roots and keeps `serverFpsGUI.sqf` as the single server-FPS publisher. | Current-master AI runtime claims should start from [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map#current-branch-scope), [Towns/camps/capture](Towns-Camps-And-Capture-Atlas#patrols-v2-side-upgrade-path) and [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas#branch-scope-for-source-anchors). |
| Release `a96fdda2` | Matches stable's AI supply-truck safe-disable and single server-FPS publisher, but does not carry Patrols v2 files in checked maintained roots; it only carries the older patrol loop-exit fix. | Do not cite release as Patrols v2 evidence. Use [Towns/camps/capture](Towns-Camps-And-Capture-Atlas#historical-town-patrol-mechanic-pre-patrols-v2) for the release patrol scope. |
| Miksuu `b8389e74` and `origin/perf/quick-wins` `0076040f` | Both lack Patrols v2 in checked maintained roots and keep raw-spawning the old missing-FSM AI supply-truck worker; perf line refs differ between Chernarus and maintained Vanilla. | Recheck exact branch files before merging AI/runtime changes; route old-branch patrol and supply-truck claims through owner matrices. |
| `origin/feat/ai-commander` `c20ce153` | Branch-only AI commander revival attempt. It adds Chernarus supervisor/workers/order execution and a Chernarus-only `UpdateSupplyTruck` nil guard, while maintained Vanilla remains old-shape for that supply-truck edge. | Treat as branch-review evidence, not stable/release truth; smoke dedicated/JIP/Vanilla before calling AI commander revived. |

## AI Delegation

`WFBE_C_AI_DELEGATION` controls delegation:

- `0`: disabled
- `1`: client-side AI creation/delegation
- `2`: headless client

Source anchors: `Rsc/Parameters.hpp:50-53` exposes the mission parameter; `Common/Init/Init_CommonConstants.sqf:93-100` defines the default delegation mode and client-FPS thresholds. `initJIPCompatible.sqf:155` forces HC mode for the fork, while `initJIPCompatible.sqf:164-170` downgrades HC mode to disabled when the detected OA build lacks HC support.

Server functions `Server_DelegateAITownHeadless.sqf`, `Server_DelegateAIStaticDefenceHeadless.sqf` and `Server_FNC_Delegation.sqf` are the core delegation hooks. Client handlers `Client_DelegateAI.sqf`, `Client_DelegateTownAI.sqf` and `Client_DelegateAIStaticDefence.sqf` receive delegated work through `Client/PVFunctions/HandleSpecial.sqf:13-15`.

Page ownership: this atlas owns AI/performance runtime orientation and source routing. The implementation patch shape, work-record model, disconnect policy and DR-21/DR-42 decisions live in [Headless delegation and failover](Headless-Delegation-And-Failover-Playbook). Older upstream branch evidence for typed HC routing, side-less PVF filtering, wrong-name errors and generated mission-slot drift lives in [HC upstream history and lessons](HC-Upstream-History-And-Lessons).

Confirmed finding cross-links: [Deep-review findings](Deep-Review-Findings) DR-21 covers HC disconnect/no failover, DR-42 covers static-defense HC one-way delegation / missing update-back, and DR-45 covers town-AI vehicle despawn deleting vehicles with player passengers. Treat those as the canonical finding records and use the linked playbooks for patch shape. For AI commander/autonomous logistics revival decisions, use [AI commander autonomy audit](AI-Commander-Autonomy-Audit).

Terminology warning: current docs use "HC" for headless-client delegation, but the source also contains a separate Arma high-command UI path. `Client/FSM/updateavailableactions.fsm:47` initializes `_hc_enabled = false`, and the only `HCSetGroup` add path is gated by that flag at `:115-117`; no current source assignment was found that flips it true. Cleanup still removes high-command groups when commander state changes (`Client/FSM/updateclient.sqf:204,228`). Do not confuse this inert high-command UI ownership path with live headless-client AI creation/delegation.

HC timing caveat: the headless-client entry point currently sleeps for a fixed 20 seconds (`Headless/Init/Init_HC.sqf:14`), then runs a bounded reseat-to-civilian poll (up to ~60 s), parks the HC body in the deadspawn ring, and only after all that sends `["RequestSpecial", ["connected-hc", player]]` at line 129. The server only sets `serverInitFull = true` later in `Server/Init/Init_Server.sqf:507`, so HC registration is not protected by a real full-server barrier. Treat HC startup bugs as lifecycle issues too; the canonical wait-chain view is [Lifecycle wait-chain](Lifecycle-Wait-Chain).

Boyle's second-pass autonomy review clarified the split between real AI plumbing and missing autonomy:

| Area | Source status | Notes |
| --- | --- | --- |
| AI commander constants/state | Live. Constants are in `Common/Init/Init_CommonConstants.sqf:91-102`; side state/funds are initialized in `Server/Init/Init_Server.sqf:364-365`. | This is real state, not just comments. |
| AI commander upgrade worker | Live function. `WFBE_SE_FNC_AI_Com_Upgrade` is compiled at `Server/Init/Init_Server.sqf:48`; `Server_AI_Com_Upgrade.sqf:12-50` selects an upgrade, checks AI commander funds/supply and debits. | The worker exists, but no obvious live scheduler was found that calls it end-to-end. |
| AI buy worker | Latent. `AIBuyUnit` is compiled from `Server_BuyUnit.sqf`, but no static caller was found outside that file family. | Do not document AI unit production as fully operational until a dynamic caller is proven. |
| AI commander run flag | Partial. `wfbe_aicom_running` is initialized and cleared by commander reassignment/vote code, but no visible owner loop was found that starts autonomous commander behavior. | Scaffolding plus workers, not a complete self-driving commander brain. |
| Team `wfbe_autonomous` flag | Partial order-state flag. `Common_SetTeamAutonomous.sqf:8` only replicates state; source-visible consumers are command-menu toggles, commander-loss cleanup and AI respawn order-reset logic. | Do not treat this variable name as proof of live independent team command. Detailed wording lives in [AI commander autonomy audit](AI-Commander-Autonomy-Audit). |

Canonical revival/readiness detail lives in [AI commander autonomy audit](AI-Commander-Autonomy-Audit), including the mission-parameter/fallback-default distinction, the broken `UpdateSupplyTruck` / missing `supplytruck.fsm` path, and the branch-only `origin/feat/ai-commander` head `c20ce153` revival attempt. Earlier `4dba060e` evidence is a historical sub-piece of that branch, not the current head.

### Commander Team Order Variables

The command menu has three different order-like surfaces, and they should not be collapsed into one working system:

| Surface | Current proof | Development implication |
| --- | --- | --- |
| Team properties | Live PVF path. The client sends `RequestTeamUpdate` from `GUI_Menu_Command.sqf:425-428`; the server handler applies behavior/combat/formation/speed to selected groups or the side teams at `Server/PVFunctions/RequestTeamUpdate.sqf:3-25`. | This is a real server-side effect, but still a high-trust registered handler that needs sender/role validation before public-server hardening. |
| Map orders (`towns`, `MOVE`, `PATROL`, `DEFENSE`) | The command menu writes replicated group variables via `SetTeamMoveMode` / `SetTeamMovePos` (`GUI_Menu_Command.sqf:252-306`; setter writes at `Common_SetTeamMoveMode.sqf:8`, `Common_SetTeamMovePos.sqf:8`). Static source search found no general server loop that consumes `wfbe_teammode` + `wfbe_teamgoto` and dispatches `AIMoveTo` / `AIPatrol` / `AITownPatrol`; reads are UI display and AI-respawn reset (`AI_SquadRespawn.sqf:105-109`, `AI_AdvancedRespawn.sqf:120-124`). | Treat commander map-order execution as unproven until Arma smoke or a dynamic caller proves it. Do not use these variables as evidence of a server-owned order queue. |
| Command tasks | The `SetTask` client PVF is registered and implemented (`Init_PublicVariables.sqf:33`; `Client/PVFunctions/SetTask.sqf:1-35`), but the command menu send calls are commented at `GUI_Menu_Command.sqf:335-337,343`. | Visible/dormant UI. Revive or hide deliberately; do not document task assignment as working. |

The waypoint helpers themselves are real, but their static callers are support/resistance paths: paratrooper/para-ammo/para-vehicle support calls `AIMoveTo`, and resistance can call `AIWPAdd` / `AIPatrol` (`Server/Support/Support_Paratroopers.sqf:92,122`; `Server/Support/Support_ParaAmmo.sqf:38,96`; `Server/Support/Support_ParaVehicles.sqf:39,78`; `Server/AI/AI_Resistance.sqf:14-16`). That proves the helper family, not the commander map-order executor. Resistance also bypasses the west/east `CanUpdateTeam`/`UpdateTeam` gate (`Server/AI/AI_Resistance.sqf:7-16`), so keep resistance behavior separate from commander-team autonomy when writing docs or code.

Legacy AI order notes from the 2026-06-04 scout:

- `Server/AI/AI_TLWPHandler.sqs:9-31` still exists and teleports stragglers toward a team leader, but no static Chernarus caller or compile reference was found. Treat it as a legacy/orphan candidate unless a dynamic caller is proven.
- `Server/AI/Orders/AI_WPAdd.sqf:35-36` can apply waypoint scripts/statements, but current static callers pass empty script/statement values (`AI_MoveTo.sqf:21`; `AI_Patrol.sqf:32,37`; `AI_TownPatrol.sqf:64,69`; `AI_Resistance.sqf:14`). No current client/network-controlled path to those statement strings was found in this pass.
- The water-avoidance loops in `AI_Patrol.sqf:27` and `AI_TownPatrol.sqf:51` are capped at 20 retries on master (`while {surfaceIsWater _pos && _wtr < 20} do` with `_wtr = _wtr + 1` inside) and fall back to the town/destination centre position when still in water after 20 attempts. This is not an open uncapped-loop finding on master; verify any branch that modifies these files before re-opening it.

## Town AI

Town AI is centralized through `Server/FSM/server_town_ai.sqf`. The server starts it once globally when defenders or occupation are enabled at `Server/Init/Init_Server.sqf:513-514`. `Server_GetTownGroups`, `Server_GetTownGroupsDefender`, `Server_SpawnTownDefense`, and `Server_ManageTownDefenses` are compiled at `Server/Init/Init_Server.sqf:49-60`.

Source anchors: `server_town_ai.sqf:11-19` loads range, inactivity and delegation settings; `server_town_ai.sqf:35-51` owns the global loop and performance timing; `server_town_ai.sqf:157-179` switches between client delegation, HC delegation and server fallback; `server_town_ai.sqf:205-219` deletes inactive town groups/vehicles.

The town-AI model is spawn/delete and delegation bookkeeping, not engine simulation caching. Preserve the active/delegated vehicle registries and cleanup checks when optimizing this loop; do not remove scans or cache state just because the loop is visible. The patch-ready risk is the incomplete player-occupancy test in `server_town_ai.sqf:211-216`, not the existence of the scheduled loop itself.

## Player AI Watchdog

`Client_WatchdogPlayerAI.sqf` and `Client_RecoverPlayerAI.sqf` are client-side resilience systems for AI units in player groups. They check locality, alive state, vehicle validity, movement destination quality and recovery cooldowns.

Depth scout note: the automatic watchdog is intentionally conservative. Current source sets a 120 second recovery cooldown and a 50m minimum destination distance in `Client_WatchdogPlayerAI.sqf:69-70`, skips units with an intentional `STOP` order at `:203-207`, and records `Player_AI_Watchdog_Last_Recovery` at `:308`. `Client_RecoverPlayerAI.sqf:104-112` uses a much lower 2m threshold for manual recovery, while comments at `:12-14` and `:224-225` explain that `DoNotPlan` can still be a usable movement state when `expectedDestination` exists and is far enough away. Do not "simplify" these paths into one stuck-AI test without Arma smoke.

## Performance Audit

The mission writes structured `[Performance Audit]` RPT lines through `PerformanceAudit_Record` / `PerformanceAudit_Run`. The analyzer in `Tools/PerformanceAuditAnalyzer` converts RPT lines into CSV, Markdown, HTML and Word-friendly reports.

Instrumented areas include:

- client marker loops: `updatetownmarkers`, `updateteamsmarkers`, `updatesalvage`;
- client RHUD;
- combat marker blinking;
- updateavailableactions;
- AFK update loop;
- player AI low gear manager;
- town AI delegation and fallback views in the analyzer;
- cleanup/restorer focused reporting.

## Runtime Optimizations Already Present

- RHUD caches controls, text and colors to avoid rewriting unchanged UI every second.
- Team and town marker loops include local caches and audit counters.
- Common marker helper loops (`Common_MarkerUpdate.sqf` and `Common_AARadarMarkerUpdate.sqf`) also use cached marker state and should remain measurement-led.
- Delegated town AI avoids some global per-unit init work by passing the non-global creation path through `Client_DelegateTownAI.sqf` and `Common_CreateTownUnits.sqf`; this is a current-Wasp optimization over the old embedded delegation path, not a regression.
- Volumetric clouds are force-disabled because of FPS/stutter cost with skipTime.
- Day/night sync uses small client-side skipTime steps, server date broadcasts and hard sync only for excessive drift.
- Anti-stack loops can be disabled by mission parameter for controlled audits.
- Server cleaners/restorers split cleanup work into dedicated loops.

## Server FPS

This gateway only records where server-FPS evidence lives. Detailed publisher shape, branch drift and hosted/listen busy-loop status belong to [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas#branch-scope-for-source-anchors) and [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep).

| Question | Owner route |
| --- | --- |
| Which target branch has one publisher, two guarded publishers or two old unguarded publishers? | [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas#branch-scope-for-source-anchors), [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep#current-branch-scope) |
| Which FPS value feeds RHUD/status surfaces and which publisher lacks an obvious current source consumer? | [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep#handoff), [Performance opportunity sweep](Performance-Opportunity-Sweep) |
| What smoke proves dedicated publishing and hosted/listen no-spin behavior? | [Testing workflow](Testing-Debugging-And-Release-Workflow), [Source fix propagation queue](Source-Fix-Propagation-Queue#validation-matrix) |

## Performance Caveats

- Do not compare client and server audit rows as if they measured the same impact.
- Public-variable storms can cause more harm than local scheduled work.
- Treat long monitoring rows with sleeps/database waits differently from CPU-heavy loops.

## Delegation And Caching Internals

Claude's review sharpened several assumptions about AI performance and HC behavior. Paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

### Town AI Is Spawned And Deleted

Town AI is not simulation-cached. `enableSimulation false` is used on invisible town logic entities in `mission.sqm`, not as the town AI cache. The active mechanism is `Server/FSM/server_town_ai.sqf`:

- Spawn: nearby `"Man"`, `"Car"`, `"Motorcycle"`, `"Tank"`, `"Air"` and `"Ship"` entities inside `600 * detection_coef` wake a town; Air-class entities are included in the scan but filtered by `unitsBelowHeight 20`, so only aircraft below 20 m altitude activate towns — high-altitude flyovers do not.
- Despawn: after `time - wfbe_inactivity > WFBE_C_TOWNS_UNITS_INACTIVE` with no enemies, units and groups are deleted.
- Confirmed DR-45 risk: the vehicle cleanup in `server_town_ai.sqf:191-223`, especially `:211-216`, iterates `wfbe_active_vehicles` and deletes each alive vehicle when `!(isPlayer leader group _x)`. It does not check `crew`, cargo or turret occupants, so a player riding in a town-AI vehicle while not group leader can still be inside a vehicle that gets deleted. This is separate from `Server_HandleEmptyVehicle.sqf:26-30`, which has its own empty-vehicle wait and is not the source of this bug. See [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety) for the source chain, patch shape and validation gates.

### HC Delegation Source Router

There is no `setGroupOwner` in the mission. HC mode uses remote creation: the server sends `delegate-townai`, `delegate-ai` or `delegate-ai-static-defence`, and the headless/client receiver creates the units locally. Keep detailed patch decisions in [Headless delegation and failover](Headless-Delegation-And-Failover-Playbook); use this table to find the live source path.

| Topic | Source anchors | Canonical patch guide |
| --- | --- | --- |
| HC bootstrap and registration | `initJIPCompatible.sqf:236-238`; `Headless/Init/Init_HC.sqf:4-15`; `Server_HandleSpecial.sqf:117-131`; `Server/Init/Init_Server.sqf:109-110` | [Headless delegation and failover](Headless-Delegation-And-Failover-Playbook) |
| Town AI HC path | `Server_DelegateAITownHeadless.sqf:23-34`; `Client_DelegateTownAI.sqf:23-35`; `Server_HandleSpecial.sqf:86-96` | [Headless delegation and failover](Headless-Delegation-And-Failover-Playbook) |
| Static-defense HC path | `Server_OperateTownDefensesUnits.sqf:38-56`; `Server_HandleDefense.sqf:19-24`; `Server_DelegateAIStaticDefenceHeadless.sqf:23-26`; `Client_DelegateAIStaticDefence.sqf:25-28` | [Headless delegation and failover](Headless-Delegation-And-Failover-Playbook) |
| Player-client FPS delegation trust | `updateavailableactions.fsm:121-125`; `Server_HandleSpecial.sqf:75-83`; `Server_OnPlayerConnected.sqf:68-70`; `Server_FNC_Delegation.sqf:153-158` | [Headless delegation and failover](Headless-Delegation-And-Failover-Playbook) |
| Arma high-command UI group add path | `updateavailableactions.fsm:47,115-117`; `updateclient.sqf:204,228` | Inert unless `_hc_enabled` is deliberately revived. |
| Disconnect and late-HC behavior | `Server_OnPlayerDisconnected.sqf:22-29`; `initJIPCompatible.sqf:155,164-170` | [Headless delegation and failover](Headless-Delegation-And-Failover-Playbook) |

Runtime caveats: HC mode can be forced at `initJIPCompatible.sqf:155`, then downgraded once during init if the OA build lacks HC support (`initJIPCompatible.sqf:164-170`). The current mission has no visible failover/rebalancing pass on HC disconnect and no late-HC rebalance pass. DR-21 and DR-42 track those as implementation findings; this atlas only routes readers to the live code.

### `GetSleepFPS` Is Intentional

`Common/Functions/Common_GetSleepFPS.sqf:5-9` returns shorter sleeps when FPS drops. In `Server/FSM/updateresources.sqf:74-75`, that means the economy loop tries to avoid income stalls during lag, at the cost of doing more scheduled work while the server is already stressed. Treat it as a design tradeoff, not an obvious bug.

## Continue Reading

Previous: [Supply heli PR #1](Current-Work-Supply-Helicopters-PR1) | Next: [HC delegation/failover](Headless-Delegation-And-Failover-Playbook)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
