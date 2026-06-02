# AI, Headless And Performance

## AI Delegation

`WFBE_C_AI_DELEGATION` controls delegation. The mission parameter exposes the values in `Rsc/Parameters.hpp:50-54`, `initJIPCompatible.sqf:155` sets the default to headless mode, and `Common/Init/Init_CommonConstants.sqf:93` preserves a disabled fallback when the variable is not defined:

- `0`: disabled
- `1`: client-side AI creation/delegation
- `2`: headless client

`initJIPCompatible.sqf:176-180` downgrades headless delegation to disabled when the detected OA version does not support headless clients. Server functions `Server_DelegateAITownHeadless`, `Server_DelegateAIStaticDefenceHeadless` and `Server_FNC_Delegation` are compiled at `Server/Init/Init_Server.sqf:99-103`, with the HC candidate list initialized at `:109-110`. HC-side receivers compile through `Headless/Init/Init_HC.sqf:4-6`, announce themselves with `:15`, and receive `delegate-townai`, `delegate-ai` and `delegate-ai-static-defence` through `Client/PVFunctions/HandleSpecial.sqf:13-15`.

## Town AI

Town AI is centralized through `Server/FSM/server_town_ai.sqf`. The server starts it once globally when defenders or occupation are enabled (`Server/Init/Init_Server.sqf:512-514`). `Server_GetTownGroups`, `Server_GetTownGroupsDefender`, `Server_SpawnTownDefense`, and `Server_ManageTownDefenses` support the flow and are compiled at `Server/Init/Init_Server.sqf:49-60`.

## Player AI Watchdog

`Client_WatchdogPlayerAI.sqf` and `Client_RecoverPlayerAI.sqf` are client-side resilience systems for AI units in player groups. The client compiles player-AI action helpers at `Client/Init/Init_Client.sqf:90`, adds the diagnose/recover actions at `:514`, and starts the watchdog at `:515`. The watchdog prevents duplicate runners (`Client_WatchdogPlayerAI.sqf:58-59`), records stuck-unit state (`:255-311`), calls recovery automatically at `:332`, and audits `player_ai_watchdog` at `:337`. Manual recovery is exposed by `Client_AddPlayerAIActions.sqf:66-97`; recovery itself validates movement controller, locality, useful destination and physical movement viability in `Client_RecoverPlayerAI.sqf:354-398` / `:467-487`.

## Performance Audit

The mission writes structured `[Performance Audit]` RPT lines through `PerformanceAudit_Record` / `PerformanceAudit_Run`, compiled by `Common/Init/Init_Common.sqf:47` and defined in `Common/Functions/Common_PerformanceAudit.sqf:159` / `:221`. Clients wait for and start the audit runner at `Client/Init/Init_Client.sqf:343-344`; the server does the same at `Server/Init/Init_Server.sqf:587-588`. The analyzer in `Tools/PerformanceAuditAnalyzer` converts RPT lines into CSV, Markdown, HTML and Word-friendly reports.

For ranked, source-backed patch candidates, use [Performance opportunity sweep](Performance-Opportunity-Sweep). It keeps quick fixes such as PVF dispatcher lookup, supply mission scan status, factory queue churn and WASP marker wait cleanup in one place instead of scattering patch order across subsystem pages. The duplicate `Skill_Init`, hosted FPS busy-spin and supply command-center scan cleanups are already patched in source/Vanilla and now need only their smoke plans.

Instrumented areas include:

- client marker loops: `updatetownmarkers` (`Client/FSM/updatetownmarkers.sqf:121`), `updateteamsmarkers` (`Client/FSM/updateteamsmarkers.sqf:220`) and `updatesalvage` (`Client/FSM/updatesalvage.sqf:56`);
- client RHUD (`Client/Client_UpdateRHUD.sqf:201`, `:369`);
- combat marker blinking (`Client/Functions/Client_SetMapIconStatusInCombat.sqf:44`);
- updateavailableactions (`Client/FSM/updateavailableactions.fsm:237`);
- AFK update loop (`Client/FSM/updateclient.sqf:180`, `:249`);
- player AI low gear manager (`Client/Module/Valhalla/Func_Client_AI_LowGear_Manager.sqf:48`);
- town AI and town-defense delegation (`Server/FSM/server_town_ai.sqf:247`, `Server/Functions/Server_FNC_Delegation.sqf:69`, `Server/Functions/Server_DelegateAITownHeadless.sqf:34`, `Server/Functions/Server_OperateTownDefensesUnits.sqf:118`);
- server object/artifact maintenance: dead object garbage collection (`Server/FSM/server_collector_garbage.sqf:28`), empty vehicles (`Server/FSM/emptyvehiclescollector.sqf:26`), dropped items (`Server/FSM/cleaners/droppeditems_cleaner.sqf:37`), craters (`Server/FSM/cleaners/crater_cleaner.sqf:42`), ruins (`Server/FSM/cleaners/ruins_cleaner.sqf:22`), mines (`Server/FSM/cleaners/mines_cleaner.sqf:26`) and building restoration (`Server/FSM/restorers/buildings_restorer.sqf:23`).

## Runtime Optimizations Already Present

- RHUD caches controls, text and colors to avoid rewriting unchanged UI every second (`Client/Client_UpdateRHUD.sqf:11`, `:41-87`).
- Team and town marker loops include local caches and audit counters (`Client/FSM/updateteamsmarkers.sqf:218-220`, `Client/FSM/updatetownmarkers.sqf:119-121`).
- Volumetric clouds are force-disabled because of FPS/stutter cost with skipTime.
- Day/night sync uses small client-side skipTime steps, server date broadcasts and hard sync only for excessive drift.
- Anti-stack loops can be disabled by mission parameter for controlled audits.
- Server cleaners/restorers split cleanup work into dedicated loops.

## Server Cleanup And Restorers

`Server/Init/Init_Server.sqf` starts two object-lifecycle collectors first, then five map artifact loops. The dead-object collector runs `Server/FSM/server_collector_garbage.sqf` at `:535`; the empty-vehicle collector runs `Server/FSM/emptyvehiclescollector.sqf` at `:537`; the map cleaners/restorer are started at `:543`, `:547`, `:551`, `:555` and `:559`.

| Loop | Source | What it touches | Interval / cadence |
| --- | --- | --- | --- |
| Dead object garbage collector | `Server/FSM/server_collector_garbage.sqf` | Scans `allDead`, skips side HQs and objects with `wfbe_trashable`, then spawns `TrashObject` for newly tracked corpses/wrecks (`:7`, `:13-23`). | Fixed `sleep 0.5` (`:32`). |
| Empty vehicle collector | `Server/FSM/emptyvehiclescollector.sqf` | Reads `WF_Logic` `emptyVehicles`, avoids duplicates through `emptyQueu`, spawns `WFBE_SE_FNC_HandleEmptyVehicle`, then republishes the reduced list (`:9-19`). | Fixed `sleep 0.5` (`:30`). |
| Dropped items cleaner | `Server/FSM/cleaners/droppeditems_cleaner.sqf` | Map-wide `nearestObjects` scans for `weaponholder`, `Mine` and `MineE`, deleting each hit with cooperative `sleep 0.5` between deletes (`:15-33`). | `WFBE_C_DROPPEDITEMS_CLEANER_TIME_PERIOD`, default `120` seconds (`Rsc/Parameters.hpp:527-531`), fallback `600` (`droppeditems_cleaner.sqf:42-44`). |
| Crater cleaner | `Server/FSM/cleaners/crater_cleaner.sqf` | Map-wide scans for `CraterLong_small` and `CraterLong`, deleting each result with cooperative sleeps (`:15-37`). | `WFBE_C_CRATER_CLEANER_TIME_PERIOD`, default `1800` seconds (`Rsc/Parameters.hpp:521-525`), fallback `600` (`crater_cleaner.sqf:47-49`). |
| Ruins cleaner | `Server/FSM/cleaners/ruins_cleaner.sqf` | Map-wide scan for `Ruins`, deleting each result with cooperative sleeps (`:10-18`). | `WFBE_C_RUINS_CLEANER_TIME_PERIOD`, default `1800` seconds (`Rsc/Parameters.hpp:539-543`), fallback `600` (`ruins_cleaner.sqf:26-28`). |
| Mines cleaner | `Server/FSM/cleaners/mines_cleaner.sqf` | Owns the global `mines` list, scans tracked `[mine, time]` pairs and deletes entries older than the configured period (`:3-23`). Construction minefields and WASP dropped mines append to this list (`Construction_StationaryDefense.sqf:31-55`, `WASP/rpg_dropping/DropRPG.sqf:65-67`). | `WFBE_C_MINEFIELDS_CLEANER_TIME_PERIOD`, default `5400` seconds (`Rsc/Parameters.hpp:533-537`), fallback `600` (`mines_cleaner.sqf:30-32`). |
| Building restorer | `Server/FSM/restorers/buildings_restorer.sqf` | Scans `WarfareBBaseStructure` near the map center and sets damage to `0` on every result (`:11-19`). | `WFBE_C_BUILDING_RESTORER_TIME_PERIOD`, default `1800` seconds (`Rsc/Parameters.hpp:515-519`); script fallback is `600` (`buildings_restorer.sqf:3`, `:26`). |

Performance note: the artifact loops record active scan/delete/restore time and counts, while comments intentionally exclude the cooperative per-object sleeps from active timing (`droppeditems_cleaner.sqf:5`, `crater_cleaner.sqf:6`, `ruins_cleaner.sqf:5`, `mines_cleaner.sqf:7`, `buildings_restorer.sqf:6`). When reading analyzer output, use `cycleMs` for wall-clock cycle length and the active-time field for script work.

Safety note: these loops are server-owned maintenance, not headless delegation. Do not move them to HC or client paths without a dedicated locality audit; they mutate mission objects, global tracking arrays and public `WF_Logic` state.

## Server FPS

`Server/GUI/serverFpsGUI.sqf` and `Server/Module/serverFPS/monitorServerFPS.sqf` publish server FPS data used by HUD/status surfaces. Earlier compile lines for `WFBE_CO_FNC_monitorServerFPS` are commented (`Server/Init/Init_Server.sqf:65`, `:90`), but `Init_Server.sqf` later executes `serverFpsGUI.sqf` and the FPS module directly (`:578`, `:595`). Historical DR-19 found both files put `sleep 8` inside the `isDedicated` branch, so hosted/listen servers could spin without yielding. Current source Chernarus and Vanilla Takistan now exit immediately on `!isDedicated`, keep one dedicated `while {true}` publisher loop and retain the 8-second cadence; see [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep). Remaining work is Arma smoke for dedicated RHUD updates and hosted/listen no-spin behavior.

## Performance Caveats

- Do not compare client and server audit rows as if they measured the same impact.
- Public-variable storms can cause more harm than local scheduled work.
- Treat long monitoring rows with sleeps/database waits differently from CPU-heavy loops.

## Delegation & caching internals (Claude deep-dive, source-cited)

Paths relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

### Distance-based spawn/despawn is the primary perf mechanism

Town AI is **not** simulation-cached (`enableSimulation false` is used only on the invisible town logic entities in `mission.sqm`, never on AI units). Instead, `Server/FSM/server_town_ai.sqf` fully creates and fully deletes groups based on proximity:

- **Spawn:** `_town nearEntities [["Man","Car","Motorcycle","Tank","Ship"], _dynRange]` at `server_town_ai.sqf:85`, with aircraft explicitly filtered out at `:90` so fly-overs do not trigger spawns.
- **Despawn:** after `time - wfbe_inactivity > WFBE_C_TOWNS_UNITS_INACTIVE` (`server_town_ai.sqf:15`, `:192`) with no enemies, `{deleteVehicle _x} forEach units _x; deleteGroup _x;` at `:205-206`.
- **Gotcha:** the despawn deletes active vehicles when `!(isPlayer leader group _x)` (`server_town_ai.sqf:214`). A player riding as cargo/gunner (not leader) can have their vehicle deleted under them.

### HC delegation routing

There is **no `setGroupOwner` anywhere in the mission**. The HC owns AI because the HC's machine *creates* the units locally when it receives a delegation message (`delegate-townai`, `delegate-ai`, `delegate-ai-static-defence`) via `WFBE_CO_FNC_SendToClient` to the HC leader.

- HC registration: on `["RequestSpecial", ["connected-hc", player]]` (`Headless/Init/Init_HC.sqf:15`), `Server/Functions/Server_HandleSpecial.sqf:117-128` appends `group _hc` to `WFBE_HEADLESSCLIENTS_ID` — **but only if `owner _hc != 0`** (`:120`, `:125`); an HC that connects before the engine assigns a distinct owner ID is logged and skipped (`:129-130`).
- HC disconnect removes the HC group from the candidate pool (`Server/Functions/Server_OnPlayerDisconnected.sqf:23-28`). The full no-failover finding and code-owner options live in [Deep-review findings](Deep-Review-Findings) DR-21; keep that as the canonical wording so this page does not grow a second failover analysis.
- Static-defence delegation has an extra tracking gap (DR-42): `Server_DelegateAIStaticDefenceHeadless.sqf:26` sends `delegate-ai-static-defence`, and `Client_DelegateAIStaticDefence.sqf:25` creates the units, but the server update-back line at `:28` is commented (`update-delegation-static_defence`). Town AI does report back through `Client_DelegateTownAI.sqf:35` and `Server_HandleSpecial.sqf`'s `update-town-delegation` case. Result: HC-created static-defence units are invisible to server cleanup/accounting/re-delegation unless code owners restore and define that update-back path. See [Deep-review findings](Deep-Review-Findings) DR-42.

### Delegation mode can silently downgrade at init

`WFBE_C_AI_DELEGATION` is set to `2` (HC) at `initJIPCompatible.sqf:155`, then downgraded to `0` at `:178-179` if the OA version doesn't support HC **or** no HC has connected at init time. The downgrade happens once at boot and is not re-upgraded if an HC joins later — so an HC connecting after server init may never receive delegated work. (This refines the version-only framing above.)

### `GetSleepFPS` is inverted by design

`Common/Functions/Common_GetSleepFPS.sqf:6-9` returns a **shorter** sleep as FPS drops (x0.85 at <=15fps down to x0.50 at <=5fps). Used by `Server/FSM/updateresources.sqf:74-75`, this makes the income loop run *faster* under load — intentional, to avoid economic stalls during lag, at the cost of more work when the server is already struggling. Do not "fix" it as a bug.


