# AI, Headless And Performance

## AI Delegation

`WFBE_C_AI_DELEGATION` controls delegation:

- `0`: disabled
- `1`: client-side AI creation/delegation
- `2`: headless client

`initJIPCompatible.sqf` downgrades headless delegation to disabled when the detected OA version does not support headless clients. Server functions `Server_DelegateAITownHeadless`, `Server_DelegateAIStaticDefenceHeadless` and `Server_FNC_Delegation` are the core delegation hooks. Client handlers `Client_DelegateAI`, `Client_DelegateTownAI` and `Client_DelegateAIStaticDefence` receive delegated work.

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
- Risk: the despawn path checks `!(isPlayer leader group _x)`, so a player riding as cargo or gunner while not group leader may still be inside a vehicle that gets deleted.

### HC Delegation Uses Remote Creation

There is no `setGroupOwner` in the mission. The headless client owns delegated AI because it receives a `delegate-townai`, `delegate-ai`, or `delegate-ai-static-defence` message and creates the units locally.

- If the HC disconnects mid-mission, `Server/Functions/Server_OnPlayerDisconnected.sqf` removes the HC group from the candidate pool, but does not reclaim already-created units.
- HC registration is handled through `["RequestSpecial", ["connected-hc", player]]`; `Server/Functions/Server_HandleSpecial.sqf` appends `group _hc` to `WFBE_HEADLESSCLIENTS_ID` only if `owner _hc != 0`.

### Delegation Can Downgrade Once At Init

`WFBE_C_AI_DELEGATION` can be set to `2` for HC mode, then downgraded to `0` during init if the OA version does not support HC or no HC is connected when that check runs. The downgrade is not automatically reversed later when an HC joins, so late HC connection may not receive work unless the init/delegation flow is changed.

### `GetSleepFPS` Is Intentional

`Common/Functions/Common_GetSleepFPS.sqf` returns shorter sleeps when FPS drops. In `updateresources.sqf`, that means the economy loop tries to avoid income stalls during lag, at the cost of doing more scheduled work while the server is already stressed. Treat it as a design tradeoff, not an obvious bug.

## Continue Reading

Previous: [Supply heli PR #1](Current-Work-Supply-Helicopters-PR1) | Next: [Client UI/HUD/menus](Client-UI-HUD-And-Menus)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
