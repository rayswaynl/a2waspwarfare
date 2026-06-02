# AI Runtime And HC Loop Map

This page is a focused runtime map for server loops, town AI, headless-client delegation and AI/autonomy edges. Use it with [AI/headless/performance](AI-Headless-And-Performance), [Server runtime atlas](Server-Gameplay-Runtime-Atlas), [HC delegation/failover](Headless-Delegation-And-Failover-Playbook), [AI commander autonomy audit](AI-Commander-Autonomy-Audit) and [Performance opportunity sweep](Performance-Opportunity-Sweep).

`SRC` below means `Missions/[55-2hc]warfarev2_073v48co.chernarus`.

## Runtime Loop Table

| Loop / handler | Source refs | Role | Cadence / exit | Risk |
| --- | --- | --- | --- | --- |
| Role split / init chain | `SRC/initJIPCompatible.sqf:55-57`, `:214-239` | Common, server, client, HC | Once, with waits | HC is `!(hasInterface || isDedicated)`; all roles branch from one file. |
| HC support gate | `SRC/initJIPCompatible.sqf:164-170` | Common | Once | AI delegation mode 2 is disabled below OA 1.62 build gate. |
| HC boot / registration | `SRC/Headless/Init/Init_HC.sqf:4-15` | HC | Fixed `sleep 20`, fire-once PVF | No retry or heartbeat. |
| Server init waits | `SRC/Server/Init/Init_Server.sqf:1`, `:126-127`, `:507`, `:583` | Dedicated/hosted server | Waits for common/town/time gates | Stalls if common/town init never completes. |
| Client init waits/JIP fanout | `SRC/Client/Init/Init_Client.sqf:164-165`, `:594-596`, `:757-770`, `:960-962` | Client/hosted player | Waits, then JIP queries | Heavy town-wide query fanout on join. |
| Town state loop | `SRC/Server/FSM/server_town.sqf:34`, `:57`, `:259-270` | Server | Per-town `sleep 0.05`, outer `sleep 5`; exits on `WFBE_GameOver` | Core scan/capture/supply loop. |
| Town AI activation loop | `SRC/Server/FSM/server_town_ai.sqf:35`, `:84-121`, `:157-185`, `:191-251` | Server | Per-town `sleep 0.05`, outer `sleep 5`; exits on `WFBE_GameOver` | Drives AI spawn/despawn and HC delegation. |
| Camp capture manager | `SRC/Server/FSM/server_town_camp.sqf:8-13`, `:25`, `:150-157` | Server | About one-second global scan; exits on `WFBE_GameOver` | Continuous camp scan. |
| Town patrol workers | `SRC/Common/Functions/Common_CreateTownUnits.sqf:42-63`; `SRC/Server/FSM/server_town_patrol.sqf:18`, `:47-53` | Server or delegated locality | `sleep 30`; `!WFBE_GameOver || _aliveTeam` | Lifecycle condition can keep workers alive after game over while the team lives. |
| Ambient patrol workers | `SRC/Server/FSM/server_patrols.sqf:26`, `:68`, `:71-72` | Server | `sleep 30`; `!WFBE_GameOver || _team_alive` | Same patrol lifecycle risk. |
| Static defense manage/operate | `SRC/Server/Functions/Server_ManageTownDefenses.sqf:15-32`; `Server_OperateTownDefensesUnits.sqf:24-85`, `:115-118` | Server with optional HC creation | Event-like on town activation/capture | Resistance-only; HC static gunners are fire-and-forget. |
| Base defense remanning | `SRC/Server/Functions/Server_HandleDefense.sqf:7-42`; `SRC/Server/Construction/Construction_StationaryDefense.sqf:90-99` | Server with optional HC creation | Missing gunner `sleep 7`, normal `sleep 420`; exits when defense dies | No explicit game-over exit. |
| Resource/income loop | `SRC/Server/FSM/updateresources.sqf:20`, `:67`, `:74-75` | Server | FPS-adjusted sleep; exits on `gameOver` | Uses inverse `GetSleepFPS`; low FPS shortens sleeps. |
| FPS sleep helper | `SRC/Common/Functions/Common_GetSleepFPS.sqf:5-9` | Common helper | Called by loops | Scaling may be inverted depending on intended semantics. |
| Performance audit loop | `SRC/Common/Functions/Common_PerformanceAudit.sqf:221-240`; `SRC/Server/Init/Init_Server.sqf:586-589` | Server audit runner | Default flush `sleep 60`; exits on `gameOver` if set | Good observability hook but only as complete as callers. |
| Server FPS publishers | `SRC/Server/GUI/serverFpsGUI.sqf:3-9`; `SRC/Server/Module/serverFPS/monitorServerFPS.sqf:1-8` | Dedicated both; hosted/listen GUI publisher only in current source | `sleep 8`; no match-end exit | Dedicated duplicates FPS publishing surfaces. |
| Cleanup/restorer set | `SRC/Server/Init/Init_Server.sqf:535-560`; cleaners such as `droppeditems_cleaner.sqf:4`, `:19`, `:42` | Server | Timer plus per-item sleeps; mostly `WFBE_GameOver` | Always-on cleanup pressure. |
| Global stats extension | `SRC/Server/CallExtensions/GlobalGameStats.sqf:5`, `:24` | Server | `sleep 60`; no explicit exit | Always-on extension loop; player-count heuristics exclude HC. |
| AntiStack loops | `SRC/Server/Init/Init_Server.sqf:597-614`; `AntiStack/updateScoreInternal.sqf:13`; `mainLoop.sqf:15`; `flushLoop.sqf:17` | Server if enabled | Mixed DB polling/sleeps | Optional but some loops can outlive a match. |
| AI supply truck loop | `SRC/Server/AI/AI_UpdateSupplyTruck.sqf:5-17`; `SRC/Server/Init/Init_Server.sqf:36`, `:381-383` | Intended server | `sleep 60`; exits on `gameOver` | Compile is commented, branch still calls `UpdateSupplyTruck`, FSM target is missing. |

## HC Delegation Map

| Flow | Evidence | Completeness |
| --- | --- | --- |
| HC detection | `SRC/Headless/Functions/HC_IsHeadlessClient.sqf:5`; `SRC/initJIPCompatible.sqf:55-57` | Complete for OA HC identity assumption. |
| HC registration | `SRC/Headless/Init/Init_HC.sqf:12-15`; `SRC/Server/Functions/Server_HandleSpecial.sqf:117-131`; `Server_OnPlayerDisconnected.sqf:23-27` | Connect/disconnect handled; no heartbeat, retry or delegated-work failback. |
| Client delegation mode 1 | `SRC/Server/Functions/Server_OnPlayerConnected.sqf:68-70`; `Server_FNC_Delegation.sqf:15-73`, `:104-178`; `Client/FSM/updateavailableactions.fsm:49`, `:124` | Most complete: client FPS/group counts, fallback to server and tracker cleanup. |
| Town AI to HC mode 2 | `SRC/Server/FSM/server_town_ai.sqf:157-172`; `Server_DelegateAITownHeadless.sqf:23-35`; `Client_DelegateTownAI.sqf:26-45` | Partial: delegated vehicles report back, but there is no timeout/failback. |
| Static town defense to HC | `Server_OperateTownDefensesUnits.sqf:41-56`; `Server_DelegateAIStaticDefenceHeadless.sqf:22-27`; `Client_DelegateAIStaticDefence.sqf:25-38` | Fire-and-forget; callback is commented. |
| Base defense remanning to HC | `Server_HandleDefense.sqf:19-23` | Fire-and-forget; no confirmation callback. |
| Generic `delegate-ai` | `Client/PVFunctions/HandleSpecial.sqf:13-15`; `Client_DelegateAI.sqf:20-32`; `Common_CreateUnitsForResBases.sqf:35` | Stale/abandoned-looking; no clear live caller found. |
| Locality transfer helper | `Server_SetLocalityOwner.sqf:13` | Not used by town/static HC AI delegation; delegation creates on remote rather than transferring existing locality. |

## Findings

| Severity | Finding | Evidence | Safe next action |
| --- | --- | --- | --- |
| High | AI supply trucks are broken if enabled. | `Init_Server.sqf:36`, `:381-383`; `AI_UpdateSupplyTruck.sqf:5-17`; missing `Server/FSM/supplytruck.fsm`. | Guard/remove the branch or restore compile + FSM + smoke before enabling. |
| High | Static-defense HC delegation has no completion/failback path. | `Server_DelegateAIStaticDefenceHeadless.sqf:22-27`; `Client_DelegateAIStaticDefence.sqf:28`. | Add callback/timeout or keep static-defense manning server-local. |
| Medium | Town HC delegation lacks heartbeat/failback. | `Server_DelegateAITownHeadless.sqf:23-30`; `Client_DelegateTownAI.sqf:35`. | Smoke HC disconnect during active town and document orphan behavior. |
| Medium | FPS sleep helper may be inverted. | `Common_GetSleepFPS.sqf:5-9`; `updateresources.sqf:74-75`. | Decide intent before patching; record RPT/perf evidence. |
| Medium | Patrol exit condition is lifecycle-hostile. | `server_town_patrol.sqf:18`; `server_patrols.sqf:26`. | Replace with bounded lifecycle after confirming cleanup semantics. |
| Medium | AI commander autonomy is scaffolded, not complete. | Funds at `Init_Server.sqf:356-365`; upgrade helper `Server_AI_Com_Upgrade.sqf:12-50`; no complete scheduler proven. | Treat as owner decision / disabled partial until scheduler and buy/upgrade smoke exist. |
| Low/Medium | Stale delegation helper shadows the current inline implementation. | `Server/Functions/Server_GetDelegators.sqf:1-10` still exists, while active delegation defines `WFBE_SE_FNC_GetDelegators` inline in `Server_FNC_Delegation.sqf:139-178`; no compile/reference to `Server_GetDelegators` was found in the source mission. | Annotate or delete the stale helper only after a generated/modded reference check; keep active patches in `Server_FNC_Delegation.sqf`. |
| Low/Medium | Town static defenses are resistance-only. | `Server_SpawnTownDefense.sqf:18`; `Server_OperateTownDefensesUnits.sqf:24`. | Correct any docs implying all occupied towns spawn static defense crews. |

## Runtime Smoke

| Target | Smoke gates |
| --- | --- |
| Dedicated server | Verify `commonInitComplete`, `townInit`, `serverInitFull`, town loop, town AI loop, camp loop, cleanup loops, performance audit and both FPS publishers. |
| Hosted/listen | Verify server/client branches both run, `monitorServerFPS.sqf` exits, `serverFpsGUI.sqf` publishes and client waits/JIP queries finish. |
| JIP | Join after server init and town activation; verify side logic, town/camp states, marker updates, day/night sync and no duplicated local loops. |
| HC | Run dedicated plus HC with delegation mode 2; verify HC registration, town AI delegation, `update-town-delegation`, HC disconnect removal and fallback behavior. |
| Negative AI supply | In a private test only, enable the old AI supply-truck path and confirm current failure; use that as a release gate before any revival. |

## Continue Reading

Previous: [AI/headless/performance](AI-Headless-And-Performance) | Next: [HC delegation/failover](Headless-Delegation-And-Failover-Playbook)

Related: [Server runtime atlas](Server-Gameplay-Runtime-Atlas) | [AI commander autonomy audit](AI-Commander-Autonomy-Audit) | [Feature status](Feature-Status-Register)
