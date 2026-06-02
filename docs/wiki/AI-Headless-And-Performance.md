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

## Delegation & caching internals (Claude deep-dive, source-cited)

Paths relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

### Distance-based spawn/despawn is the primary perf mechanism

Town AI is **not** simulation-cached (`enableSimulation false` is used only on the invisible town logic entities in `mission.sqm`, never on AI units). Instead, `Server/FSM/server_town_ai.sqf` fully creates and fully deletes groups based on proximity:

- **Spawn:** `_town nearEntities [["Man","Car","Motorcycle","Tank","Ship"], 600 * detection_coef]`, with aircraft explicitly filtered out so fly-overs don't trigger spawns.
- **Despawn:** after `time - wfbe_inactivity > WFBE_C_TOWNS_UNITS_INACTIVE` (default 90s) with no enemies, `{deleteVehicle _x} forEach units _x; deleteGroup _x;`.
- **Gotcha:** the despawn deletes active vehicles when `!(isPlayer leader group _x)`. A player riding as cargo/gunner (not leader) can have their vehicle deleted under them.

### HC delegation works by remote-creation, not ownership transfer

There is **no `setGroupOwner` anywhere in the mission**. The HC owns AI because the HC's machine *creates* the units locally when it receives a delegation message (`delegate-townai`, `delegate-ai`, `delegate-ai-static-defence`) via `WFBE_CO_FNC_SendToClient` to the HC leader. Implications:

- If the HC disconnects mid-mission, units it created become ownerless; `Server/Functions/Server_OnPlayerDisconnected.sqf:26` only removes the HC group from the candidate pool — it does not reclaim those units.
- HC registration: on `["RequestSpecial", ["connected-hc", player]]`, `Server/Functions/Server_HandleSpecial.sqf` appends `group _hc` to `WFBE_HEADLESSCLIENTS_ID` — **but only if `owner _hc != 0`**; an HC that connects before the engine assigns a distinct owner ID is logged and skipped.
- Static-defence delegation has an extra tracking gap (DR-42): `Server_DelegateAIStaticDefenceHeadless.sqf:26` sends `delegate-ai-static-defence`, and `Client_DelegateAIStaticDefence.sqf:25` creates the units, but the server update-back line at `:28` is commented (`update-delegation-static_defence`). Town AI does report back through `Client_DelegateTownAI.sqf:35` and `Server_HandleSpecial.sqf`'s `update-town-delegation` case. Result: HC-created static-defence units are invisible to server cleanup/accounting/re-delegation unless code owners restore and define that update-back path. See [Deep-review findings](Deep-Review-Findings) DR-42.

### Delegation mode can silently downgrade at init

`WFBE_C_AI_DELEGATION` is set to `2` (HC) at `initJIPCompatible.sqf:155`, then downgraded to `0` at `:178-179` if the OA version doesn't support HC **or** no HC has connected at init time. The downgrade happens once at boot and is not re-upgraded if an HC joins later — so an HC connecting after server init may never receive delegated work. (This refines the version-only framing above.)

### `GetSleepFPS` is inverted by design

`Common/Functions/Common_GetSleepFPS.sqf` returns a **shorter** sleep as FPS drops (×0.85 ≤15fps … ×0.50 ≤5fps). Used by `updateresources.sqf:74`, this makes the income loop run *faster* under load — intentional, to avoid economic stalls during lag, at the cost of more work when the server is already struggling. Don't "fix" it as a bug.


