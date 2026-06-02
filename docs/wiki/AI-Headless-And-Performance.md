# AI, Headless And Performance

## AI Delegation

`WFBE_C_AI_DELEGATION` controls delegation:

- `0`: disabled
- `1`: client-side AI creation/delegation
- `2`: headless client

`initJIPCompatible.sqf` downgrades headless delegation to disabled when the detected OA version does not support headless clients. Server functions `Server_DelegateAITownHeadless`, `Server_DelegateAIStaticDefenceHeadless` and `Server_FNC_Delegation` are the core delegation hooks. Client handlers `Client_DelegateAI`, `Client_DelegateTownAI` and `Client_DelegateAIStaticDefence` receive delegated work.

Boyle's second-pass autonomy review clarified the split between real AI plumbing and missing autonomy:

| Area | Source status | Notes |
| --- | --- | --- |
| AI commander constants/state | Live. Constants are in `Common/Init/Init_CommonConstants.sqf:91-102`; side state/funds are initialized in `Server/Init/Init_Server.sqf:364-365`. | This is real state, not just comments. |
| AI commander upgrade worker | Live function. `WFBE_SE_FNC_AI_Com_Upgrade` is compiled at `Server/Init/Init_Server.sqf:48`; `Server_AI_Com_Upgrade.sqf:12-50` selects an upgrade, checks AI commander funds/supply and debits. | The worker exists, but no obvious live scheduler was found that calls it end-to-end. |
| AI buy worker | Latent. `AIBuyUnit` is compiled from `Server_BuyUnit.sqf`, but no static caller was found outside that file family. | Do not document AI unit production as fully operational until a dynamic caller is proven. |
| AI commander run flag | Partial. `wfbe_aicom_running` is initialized and cleared by commander reassignment/vote code, but no visible owner loop was found that starts autonomous commander behavior. | Scaffolding plus workers, not a complete self-driving commander brain. |

## Town AI

Town AI is centralized through `Server/FSM/server_town_ai.sqf`. The server starts it once globally when defenders or occupation are enabled. `Server_GetTownGroups`, `Server_GetTownGroupsDefender`, `Server_SpawnTownDefense`, and `Server_ManageTownDefenses` support the flow.

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

`Server/GUI/serverFpsGUI.sqf` and `Server/Module/serverFPS/monitorServerFPS.sqf` publish server FPS data used by HUD/status surfaces. Earlier compile lines for `WFBE_CO_FNC_monitorServerFPS` are commented, but `Init_Server.sqf` later executes the module directly.

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
- Confirmed risk: the vehicle cleanup in `server_town_ai.sqf:191-223`, especially `:211-216`, iterates `wfbe_active_vehicles` and deletes each alive vehicle when `!(isPlayer leader group _x)`. It does not check `crew`, cargo or turret occupants, so a player riding in a town-AI vehicle while not group leader can still be inside a vehicle that gets deleted. This is separate from `Server_HandleEmptyVehicle.sqf`, which has its own empty-vehicle wait and is not the source of this bug. See [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety) for the source chain, patch shape and validation gates.

### HC Delegation Uses Remote Creation

There is no `setGroupOwner` in the mission. The headless client owns delegated AI because it receives a `delegate-townai`, `delegate-ai`, or `delegate-ai-static-defence` message and creates the units locally.

- If the HC disconnects mid-mission, `Server/Functions/Server_OnPlayerDisconnected.sqf` removes the HC group from the candidate pool, but does not reclaim already-created units.
- HC registration is handled through `["RequestSpecial", ["connected-hc", player]]`; `Server/Functions/Server_HandleSpecial.sqf` appends `group _hc` to `WFBE_HEADLESSCLIENTS_ID` only if `owner _hc != 0`.
- `Client/Functions/Client_DelegateAIStaticDefence.sqf` has the server update branch commented near the end of the helper, so static-defense delegation should be treated as intentionally incomplete until source-tested.

### Delegation Can Downgrade Once At Init

`WFBE_C_AI_DELEGATION` can be set to `2` for HC mode, then downgraded to `0` during init if the OA version does not support HC or no HC is connected when that check runs. The downgrade is not automatically reversed later when an HC joins, so late HC connection may not receive work unless the init/delegation flow is changed.

There is also no visible failover/rebalancing pass on HC disconnect. A disconnected HC can dump locality/load back onto the server through engine behavior, but the mission does not use `setGroupOwner` and does not redistribute groups to a surviving HC.

### `GetSleepFPS` Is Intentional

`Common/Functions/Common_GetSleepFPS.sqf` returns shorter sleeps when FPS drops. In `updateresources.sqf`, that means the economy loop tries to avoid income stalls during lag, at the cost of doing more scheduled work while the server is already stressed. Treat it as a design tradeoff, not an obvious bug.

## Continue Reading

Previous: [Supply heli PR #1](Current-Work-Supply-Helicopters-PR1) | Next: [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
