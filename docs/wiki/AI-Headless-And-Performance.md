# AI, Headless And Performance

For the loop-level runtime and HC delegation table, see [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map). This page remains the broader atlas for AI, headless-client behavior and performance ownership.

## AI Delegation

`WFBE_C_AI_DELEGATION` controls delegation:

- `0`: disabled
- `1`: client-side AI creation/delegation
- `2`: headless client

Source anchors: `Rsc/Parameters.hpp:50-53` exposes the mission parameter; `Common/Init/Init_CommonConstants.sqf:93-100` defines the default delegation mode and client-FPS thresholds. `initJIPCompatible.sqf:155` forces HC mode for the fork, while `initJIPCompatible.sqf:164-170` downgrades HC mode to disabled when the detected OA build lacks HC support.

Server functions `Server_DelegateAITownHeadless.sqf`, `Server_DelegateAIStaticDefenceHeadless.sqf` and `Server_FNC_Delegation.sqf` are the core delegation hooks. Client handlers `Client_DelegateAI.sqf`, `Client_DelegateTownAI.sqf` and `Client_DelegateAIStaticDefence.sqf` receive delegated work through `Client/PVFunctions/HandleSpecial.sqf:13-15`.

Page ownership: this atlas owns AI/performance runtime orientation and source routing. The implementation patch shape, work-record model, disconnect policy and DR-21/DR-42 decisions live in [Headless delegation and failover](Headless-Delegation-And-Failover-Playbook).

Confirmed finding cross-links: [Deep-review findings](Deep-Review-Findings) DR-21 covers HC disconnect/no failover, DR-42 covers static-defense HC one-way delegation / missing update-back, and DR-45 covers town-AI vehicle despawn deleting vehicles with player passengers. Treat those as the canonical finding records and use the linked playbooks for patch shape. For AI commander/autonomous logistics revival decisions, use [AI commander autonomy audit](AI-Commander-Autonomy-Audit).

Boyle's second-pass autonomy review clarified the split between real AI plumbing and missing autonomy:

| Area | Source status | Notes |
| --- | --- | --- |
| AI commander constants/state | Live. Constants are in `Common/Init/Init_CommonConstants.sqf:91-102`; side state/funds are initialized in `Server/Init/Init_Server.sqf:364-365`. | This is real state, not just comments. |
| AI commander upgrade worker | Live function. `WFBE_SE_FNC_AI_Com_Upgrade` is compiled at `Server/Init/Init_Server.sqf:48`; `Server_AI_Com_Upgrade.sqf:12-50` selects an upgrade, checks AI commander funds/supply and debits. | The worker exists, but no obvious live scheduler was found that calls it end-to-end. |
| AI buy worker | Latent. `AIBuyUnit` is compiled from `Server_BuyUnit.sqf`, but no static caller was found outside that file family. | Do not document AI unit production as fully operational until a dynamic caller is proven. |
| AI commander run flag | Partial. `wfbe_aicom_running` is initialized and cleared by commander reassignment/vote code, but no visible owner loop was found that starts autonomous commander behavior. | Scaffolding plus workers, not a complete self-driving commander brain. |

Canonical revival/readiness detail lives in [AI commander autonomy audit](AI-Commander-Autonomy-Audit), including the mission-parameter/fallback-default distinction and the broken `UpdateSupplyTruck` / missing `supplytruck.fsm` path.

## Town AI

Town AI is centralized through `Server/FSM/server_town_ai.sqf`. The server starts it once globally when defenders or occupation are enabled at `Server/Init/Init_Server.sqf:513-514`. `Server_GetTownGroups`, `Server_GetTownGroupsDefender`, `Server_SpawnTownDefense`, and `Server_ManageTownDefenses` are compiled at `Server/Init/Init_Server.sqf:49-60`.

Source anchors: `server_town_ai.sqf:11-19` loads range, inactivity and delegation settings; `server_town_ai.sqf:35-51` owns the global loop and performance timing; `server_town_ai.sqf:157-179` switches between client delegation, HC delegation and server fallback; `server_town_ai.sqf:205-219` deletes inactive town groups/vehicles.

## Player AI Watchdog

`Client_WatchdogPlayerAI.sqf` and `Client_RecoverPlayerAI.sqf` are client-side resilience systems for AI units in player groups. They check locality, alive state, vehicle validity, movement destination quality and recovery cooldowns.

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
- Volumetric clouds are force-disabled because of FPS/stutter cost with skipTime.
- Day/night sync uses small client-side skipTime steps, server date broadcasts and hard sync only for excessive drift.
- Anti-stack loops can be disabled by mission parameter for controlled audits.
- Server cleaners/restorers split cleanup work into dedicated loops.

## Server FPS

`Server/GUI/serverFpsGUI.sqf` and `Server/Module/serverFPS/monitorServerFPS.sqf` publish server FPS data used by HUD/status surfaces. Earlier compile lines for `WFBE_CO_FNC_monitorServerFPS` are commented at `Server/Init/Init_Server.sqf:65,90`, but `Init_Server.sqf` later executes the GUI and module directly at `Server/Init/Init_Server.sqf:578,595`.

Source anchors: `Server/GUI/serverFpsGUI.sqf:1-10` exits immediately when `!isDedicated`, then publishes `SERVER_FPS_GUI` every 8 seconds on dedicated servers; `Server/Module/serverFPS/monitorServerFPS.sqf:1-6` now uses the same early-exit shape for `WFBE_VAR_SERVER_FPS`. The hosted/listen-server busy-loop caveat is DR-19 and is patched in source Chernarus plus maintained Vanilla; Arma smoke remains pending.

## Performance Caveats

- Do not compare client and server audit rows as if they measured the same impact.
- Public-variable storms can cause more harm than local scheduled work.
- Treat long monitoring rows with sleeps/database waits differently from CPU-heavy loops.

## Delegation And Caching Internals

Claude's review sharpened several assumptions about AI performance and HC behavior. Paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

### Town AI Is Spawned And Deleted

Town AI is not simulation-cached. `enableSimulation false` is used on invisible town logic entities in `mission.sqm`, not as the town AI cache. The active mechanism is `Server/FSM/server_town_ai.sqf`:

- Spawn: nearby `"Man"`, `"Car"`, `"Motorcycle"`, `"Tank"` and `"Ship"` entities inside `600 * detection_coef` wake a town; aircraft are filtered out so flyovers do not activate towns.
- Despawn: after `time - wfbe_inactivity > WFBE_C_TOWNS_UNITS_INACTIVE` with no enemies, units and groups are deleted.
- Confirmed DR-45 risk: the vehicle cleanup in `server_town_ai.sqf:191-223`, especially `:211-216`, iterates `wfbe_active_vehicles` and deletes each alive vehicle when `!(isPlayer leader group _x)`. It does not check `crew`, cargo or turret occupants, so a player riding in a town-AI vehicle while not group leader can still be inside a vehicle that gets deleted. This is separate from `Server_HandleEmptyVehicle.sqf:26-30`, which has its own empty-vehicle wait and is not the source of this bug. See [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety) for the source chain, patch shape and validation gates.

### HC Delegation Source Router

There is no `setGroupOwner` in the mission. HC mode uses remote creation: the server sends `delegate-townai`, `delegate-ai` or `delegate-ai-static-defence`, and the headless/client receiver creates the units locally. Keep detailed patch decisions in [Headless delegation and failover](Headless-Delegation-And-Failover-Playbook); use this table to find the live source path.

| Topic | Source anchors | Canonical patch guide |
| --- | --- | --- |
| HC bootstrap and registration | `initJIPCompatible.sqf:236-238`; `Headless/Init/Init_HC.sqf:4-15`; `Server_HandleSpecial.sqf:117-131`; `Server/Init/Init_Server.sqf:109-110` | [Headless delegation and failover](Headless-Delegation-And-Failover-Playbook) |
| Town AI HC path | `Server_DelegateAITownHeadless.sqf:23-34`; `Client_DelegateTownAI.sqf:23-35`; `Server_HandleSpecial.sqf:86-96` | [Headless delegation and failover](Headless-Delegation-And-Failover-Playbook) |
| Static-defense HC path | `Server_OperateTownDefensesUnits.sqf:38-56`; `Server_HandleDefense.sqf:19-24`; `Server_DelegateAIStaticDefenceHeadless.sqf:23-26`; `Client_DelegateAIStaticDefence.sqf:25-28` | [Headless delegation and failover](Headless-Delegation-And-Failover-Playbook) |
| Disconnect and late-HC behavior | `Server_OnPlayerDisconnected.sqf:22-29`; `initJIPCompatible.sqf:155,164-170` | [Headless delegation and failover](Headless-Delegation-And-Failover-Playbook) |

Runtime caveats: HC mode can be forced at `initJIPCompatible.sqf:155`, then downgraded once during init if the OA build lacks HC support (`initJIPCompatible.sqf:164-170`). The current mission has no visible failover/rebalancing pass on HC disconnect and no late-HC rebalance pass. DR-21 and DR-42 track those as implementation findings; this atlas only routes readers to the live code.

### `GetSleepFPS` Is Intentional

`Common/Functions/Common_GetSleepFPS.sqf:5-9` returns shorter sleeps when FPS drops. In `Server/FSM/updateresources.sqf:74-75`, that means the economy loop tries to avoid income stalls during lag, at the cost of doing more scheduled work while the server is already stressed. Treat it as a design tradeoff, not an obvious bug.

## Continue Reading

Previous: [Supply heli PR #1](Current-Work-Supply-Helicopters-PR1) | Next: [HC delegation/failover](Headless-Delegation-And-Failover-Playbook)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
