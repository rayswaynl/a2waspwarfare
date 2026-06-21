# AI Runtime And HC Loop Map

This page is a focused runtime map for server loops, town AI, headless-client delegation and AI/autonomy edges. Use it with [AI/headless/performance](AI-Headless-And-Performance), [Server runtime atlas](Server-Gameplay-Runtime-Atlas), [HC delegation/failover](Headless-Delegation-And-Failover-Playbook), [AI commander autonomy audit](AI-Commander-Autonomy-Audit) and [Performance opportunity sweep](Performance-Opportunity-Sweep).

`SRC` below means `Missions/[55-2hc]warfarev2_073v48co.chernarus`.

## How To Use This Page

| Need | Go here |
| --- | --- |
| Server/HC loop orientation | Use the [runtime loop table](#runtime-loop-table), then follow owner pages for branch-sensitive details. |
| AI commander and autonomous logistics | Use [AI commander autonomy audit](AI-Commander-Autonomy-Audit); it owns the AI supply-truck and AI commander branch matrices. |
| Town AI vehicle cleanup safety | Use [Town AI vehicle despawn safety](Town-AI-Vehicle-Despawn-Safety#current-branch-matrix) for the DR-45 player-occupancy guard route. |
| Patrols v2 | Use [Towns/camps/capture](Towns-Camps-And-Capture-Atlas#patrols-v2-side-upgrade-path) for the current side-upgrade patrol path and historical DR-57 branch matrix. |
| HC lifecycle/failback | Use [Headless delegation/failover](Headless-Delegation-And-Failover-Playbook) for payloads, callbacks, disconnect behavior and smoke gates. |

## Current Branch Scope

Checked 2026-06-13 on docs checkout `b9e80da0`, stable `origin/master` `cf2a6d6a`, Miksuu `b8389e74`, `origin/perf/quick-wins` `0076040f`, release `a96fdda2` and `origin/feat/ai-commander` `c20ce153`. Rechecked Patrols v2 file presence on 2026-06-14 from docs checkout `ee383941`; rechecked source continuity again from docs head `ca028bff`. The checked Chernarus and maintained Vanilla mission source paths remain unchanged from `b9e80da0`, stable `origin/master` still carries Patrols v2 in both maintained roots, and docs checkout/release/Miksuu/perf/feat-ai do not carry the Patrols v2 files in checked maintained roots.

| Surface | Current branch truth | Route |
| --- | --- | --- |
| AI supply-truck logistics | Docs checkout `b9e80da0`, Miksuu `b8389e74` and perf `0076040f` still raw-spawn the commented/missing `UpdateSupplyTruck` worker from both maintained roots (`Init_Server.sqf:382-383`, perf Chernarus `:377-378`). Stable `origin/master` `cf2a6d6a` and release `a96fdda2` initialize `wfbe_ai_supplytrucks` and warning-disable legacy logistics at `Init_Server.sqf:383-384` in Chernarus and maintained Vanilla; `AI_UpdateSupplyTruck.sqf:17` still points at missing `Server\FSM\supplytruck.fsm`. `feat/ai-commander` `c20ce153` guards Chernarus at `Init_Server.sqf:389` but leaves Vanilla raw. | [AI commander autonomy audit](AI-Commander-Autonomy-Audit#ai-supply-truck-branch-matrix) |
| Town AI tracked-vehicle cleanup | Docs checkout `b9e80da0` deletes tracked inactive vehicles with only `!(isPlayer leader group _x)` at `server_town_ai.sqf:214`; stable `cf2a6d6a` at `:207`; Miksuu `b8389e74` at `:195`; perf `0076040f` at `:219`; release `a96fdda2` at `:200`. No checked ref in this pass contains `Server_CleanupExpiredTownDefenseAssets.sqf`; older `89ae9dad` helper evidence is historical, not current branch truth. | [Town AI vehicle despawn safety](Town-AI-Vehicle-Despawn-Safety#current-branch-matrix) |
| Patrols v2 | Stable `origin/master` `cf2a6d6a` carries the side-upgrade patrol driver and `&&` patrol worker exit in both maintained roots. Release `a96fdda2` does **not** carry the Patrols v2 files in checked maintained roots; it keeps the older release patrol loop-exit fix. Docs checkout, Miksuu, perf and `feat/ai-commander` also lack the Patrols v2 files in checked maintained roots. Runtime smoke remains pending for the stable-master Patrols v2 path. | [Towns/camps/capture](Towns-Camps-And-Capture-Atlas#patrols-v2-side-upgrade-path) |

## Runtime Loop Table

| Loop / handler | Source refs | Role | Cadence / exit | Risk |
| --- | --- | --- | --- | --- |
| Role split / init chain | `SRC/initJIPCompatible.sqf:55-57`, `:214-239` | Common, server, client, HC | Once, with waits | HC is `!(hasInterface || isDedicated)`; all roles branch from one file. |
| HC support gate | `SRC/initJIPCompatible.sqf:164-170` | Common | Once | AI delegation mode 2 is disabled below OA 1.62 build gate. |
| HC boot / registration | `SRC/Headless/Init/Init_HC.sqf:4-15` | HC | Fixed `sleep 20`, fire-once PVF | Initial register is fire-once; a persistent reseat watcher (`Init_HC.sqf` reseat loop) re-announces `connected-hc` every 15s on mission-restart re-grabs. No delegated-work failback. |
| Server init waits | `SRC/Server/Init/Init_Server.sqf:1`, `:126-127`, `:507`, `:583` | Dedicated/hosted server | Waits for common/town/time gates | Stalls if common/town init never completes. |
| Client init waits/JIP fanout | `SRC/Client/Init/Init_Client.sqf:164-165`, `:594-596`, `:757-770`, `:960-962` | Client/hosted player | Waits, then JIP queries | Heavy town-wide query fanout on join. |
| Town state loop | `SRC/Server/FSM/server_town.sqf:34`, `:57`, `:259-270` | Server | Per-town `sleep 0.05`, outer `sleep 5`; exits on `WFBE_GameOver` | Core scan/capture/supply loop. |
| Town AI activation loop | `SRC/Server/FSM/server_town_ai.sqf:35`, `:84-121`, `:157-185`, `:191-251` | Server | Per-town `sleep 0.05`, outer `sleep 5`; exits on `WFBE_GameOver` | Drives AI spawn/despawn and HC delegation. This is an intentionally throttled scheduled loop, not a per-frame target. |
| Camp capture manager | `SRC/Server/FSM/server_town_camp.sqf:8-13`, `:25`, `:91-93` | Server | Per-camp `sleep 0.01` (10 ms inner), outer `sleep 0.1` (~100 ms cycle); exits on `WFBE_GameOver` | Continuous camp scan. |
| Town patrol workers | `SRC/Common/Functions/Common_CreateTownUnits.sqf:42-63`; `SRC/Server/FSM/server_town_patrol.sqf:18`, `:47-53` | Server or delegated locality | `sleep 30`; `!WFBE_GameOver && _aliveTeam` | Workers exit as soon as `WFBE_GameOver` is true OR the team dies; there is no cross-condition survivor risk. |
| Patrols v2 side patrol driver | Branch-sensitive source: stable `origin/master` `cf2a6d6a` has `Server/FSM/server_side_patrols.sqf:24-58`, `Common/Functions/Common_RunSidePatrol.sqf:53-83` and `Server/Functions/Server_HandleSpecial.sqf:215-242`. These files are absent from the docs checkout, release `a96fdda2`, Miksuu, perf and `feat/ai-commander` checked maintained roots. | Server or HC on stable master | Driver sleeps 20; patrol runner sleeps 30; both exit on `WFBE_GameOver`; current runner uses `&&` | Stable `origin/master` / local `master` `cf2a6d6a` supersedes the old `server_town_ai` random-town patrol launch. Smoke upgrade levels 1/2/3, HC `delegate-sidepatrol`, friendly markers and side-slot/cooldown release. Historical DR-57/AI1 and release older loop-exit evidence live in [Towns/camps/capture](Towns-Camps-And-Capture-Atlas#historical-town-patrol-mechanic-pre-patrols-v2). |
| Static defense manage/operate | `SRC/Server/Functions/Server_ManageTownDefenses.sqf:15-32`; `Server_OperateTownDefensesUnits.sqf:24-85`, `:115-118` | Server with optional HC creation | Event-like on town activation/capture | Resistance-only; HC static gunners are fire-and-forget. |
| Base defense remanning | `SRC/Server/Functions/Server_HandleDefense.sqf:7-42`; `SRC/Server/Construction/Construction_StationaryDefense.sqf:90-99` | Server with optional HC creation | Missing gunner `sleep 7`, normal `sleep 420`; exits when defense dies | No explicit game-over exit. |
| Resource/income loop | `SRC/Server/FSM/updateresources.sqf:20`, `:67`, `:74-75` | Server | FPS-adjusted sleep; exits on `gameOver` | Uses inverse `GetSleepFPS`; low FPS shortens sleeps. |
| FPS sleep helper | `SRC/Common/Functions/Common_GetSleepFPS.sqf:5-9` | Common helper | Called by loops | Scaling may be inverted depending on intended semantics. |
| Performance audit loop | `SRC/Common/Functions/Common_PerformanceAudit.sqf:221-240`; `SRC/Server/Init/Init_Server.sqf:586-589` | Server audit runner | Default flush `sleep 60`; exits on `gameOver` if set | Good observability hook but only as complete as callers. |
| Cleanup/restorer set | `SRC/Server/Init/Init_Server.sqf:535-560`; cleaners such as `droppeditems_cleaner.sqf:4`, `:19`, `:42` | Server | Timer plus per-item sleeps; mostly `WFBE_GameOver` | Always-on cleanup pressure. |
| Global stats extension | `SRC/Server/CallExtensions/GlobalGameStats.sqf:5`, `:24` | Server | `sleep 60`; no explicit exit | Always-on extension loop; player-count heuristics exclude HC. |
| AI supply truck loop | `SRC/Server/AI/AI_UpdateSupplyTruck.sqf:5-17`; docs checkout `SRC/Server/Init/Init_Server.sqf:36`, `:382-383`; stable `origin/master` `cf2a6d6a` line drift `:37`, `:383-384` | Intended server | `sleep 60`; exits on `gameOver` if spawned | Branch-sensitive legacy path: docs checkout/Miksuu/perf raw-spawn a commented/missing worker; stable/release warning-disable it instead. Keep details on [AI commander autonomy audit](AI-Commander-Autonomy-Audit#ai-supply-truck-branch-matrix). |
| Commander map-order executor | `SRC/Client/GUI/GUI_Menu_Command.sqf:252-306`; `SRC/Common/Functions/Common_SetTeamMoveMode.sqf:8`; `SRC/Common/Functions/Common_SetTeamMovePos.sqf:8`; `SRC/Server/AI/AI_SquadRespawn.sqf:105-109`; `SRC/Server/AI/AI_AdvancedRespawn.sqf:120-124` | UI writes replicated group vars; static server reads found only respawn reset | No general loop found | `wfbe_teammode` / `wfbe_teamgoto` are not proof of a server-owned waypoint executor. |
| AI town attack-path helper | `SRC/Server/Init/Init_Server.sqf:45-47`; `SRC/Server/Functions/Server_AI_SetTownAttackPath.sqf:18,41,80-109` | Compiled server helper for arced town attack waypoints | No static caller found in stable master scan | Helper clears existing waypoints before path generation; if a future caller revives it, smoke the early-exit branches before relying on generated attack routes. |
| Spawned-unit follow-up | `SRC/Client/Functions/Client_BuildUnit.sqf:463-465`; `SRC/Client/Functions/Client_SendSpawnedUnitsToLeaderWaypoint.sqf:13-94` | Client-side helper for newly bought AI | On spawn/build completion only | Runs only when `AUTO_SEND_SPAWNED_UNITS_TO_WAYPOINT` is enabled (`:13`). It purges stale stored map orders within 25m (`:24-34`), falls back through current waypoint / `expectedDestination` (`:37-65`), then `commandMove`s units or vehicle drivers (`:80-92`). This is not a general commander AI scheduler. |
| Player AI watchdog/recovery | `SRC/Client/Init/Init_Client.sqf:515`; `SRC/Client/Functions/Client_WatchdogPlayerAI.sqf:147-333`; `SRC/Client/Functions/Client_RecoverPlayerAI.sqf:1-1000` | Client-side stuck-AI recovery | Client loop/action path | Automatic recovery has a 120s cooldown and 50m destination threshold (`Client_WatchdogPlayerAI.sqf:69-70`), skips deliberate `STOP` orders (`:203-207`) and updates the last-recovery marker at `:308`. Manual recovery can use a 2m threshold (`Client_RecoverPlayerAI.sqf:104-112`) and treats `DoNotPlan` as usable when a destination exists and is far enough (`:12-14`, `:224-225`). |
| AI leader respawn hooks | `SRC/Server/Init/Init_Server.sqf:10-12`; `SRC/Server/AI/AI_AddMultiplayerRespawnEH.sqf:1`; `SRC/Server/AI/AI_AdvancedRespawn.sqf:25-124`; `SRC/Server/AI/AI_SquadRespawn.sqf:14-111` | Server-owned AI leader respawn | Branch differs by `WF_A2_Vanilla` | Non-vanilla rebinds the killed/MPRespawn path (`AI_AdvancedRespawn.sqf:25-26`, `:55-65`); vanilla uses the squad-respawn loop and bails if a player has taken the leader slot (`AI_SquadRespawn.sqf:15`, `:21`, `:29`). Both reset non-autonomous move state (`AI_SquadRespawn.sqf:103-109`; `AI_AdvancedRespawn.sqf:118-124`). |

Non-AI runtime surfaces such as server-FPS publishers and AntiStack database loops are intentionally routed to [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas), [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep), [External integrations](External-Integrations) and [AntiStack database extension audit](AntiStack-Database-Extension-Audit). Keep this page focused on AI, HC and player-AI lifecycle when adding new rows.

## HC Delegation Map

HC delegation creates units on another machine through request/response helpers; it does not magically transfer already-created unit locality. The HC boot path in `SRC/Headless/Init/Init_HC.sqf:12-15` uses a fixed `sleep 20` before `connected-hc`, so treat HC startup as a timing hazard until a timeout/retry-backed registration exists.

| Flow | Evidence | Completeness |
| --- | --- | --- |
| HC detection | `SRC/Headless/Functions/HC_IsHeadlessClient.sqf:5`; `SRC/initJIPCompatible.sqf:55-57` | Complete for OA HC identity assumption. |
| HC registration | `SRC/Headless/Init/Init_HC.sqf:12-15`; `SRC/Server/Functions/Server_HandleSpecial.sqf:117-131`; `Server_OnPlayerDisconnected.sqf:23-27` | Connect/disconnect handled; a persistent reseat watcher re-announces `connected-hc` every 15s on mission-restart re-grabs; no delegated-work failback. |
| Client delegation mode 1 | `SRC/Server/Functions/Server_OnPlayerConnected.sqf:68-70`; `Server_FNC_Delegation.sqf:15-73`, `:104-178`; `Client/FSM/updateavailableactions.fsm:49`, `:124` | Most complete: client FPS/group counts, fallback to server and tracker cleanup. |
| Town AI to HC mode 2 | `SRC/Server/FSM/server_town_ai.sqf:157-172`; `Server_DelegateAITownHeadless.sqf:23-35`; `Client_DelegateTownAI.sqf:26-45` | Partial: delegated vehicles report back, but there is no timeout/failback. |
| Static town defense to HC | `Server_OperateTownDefensesUnits.sqf:41-56`; `Server_DelegateAIStaticDefenceHeadless.sqf:22-27`; `Client_DelegateAIStaticDefence.sqf:25-38` | Fire-and-forget; callback is commented. |
| Base defense remanning to HC | `Server_HandleDefense.sqf:19-23` | Fire-and-forget; no confirmation callback. |
| Generic `delegate-ai` | `Client/PVFunctions/HandleSpecial.sqf:13-15`; `Client_DelegateAI.sqf:20-32`; `Common_CreateUnitsForResBases.sqf:35` | Stale/abandoned-looking; no clear live caller found. |
| Locality transfer helper | `Server_SetLocalityOwner.sqf:13` | Not used by town/static HC AI delegation; delegation creates on remote rather than transferring existing locality. |

Cleanup-loop edge: the client/HC delegation receivers each spin a local group cleanup poll after remote creation. `Client_DelegateTownAI.sqf:42-43`, `Client_DelegateAI.sqf:29-30` and `Client_DelegateAIStaticDefence.sqf:35-36` all wait while `count (units _team) > 0`, sleep one second, then `deleteGroup _team`. There is no timeout or server reconciliation in those receivers; a leaked unit can leave a long-lived local cleanup thread.

## Order And Recovery Chain

There are three separate order/recovery concepts that are easy to blend together:

| Concept | Source | Scope |
| --- | --- | --- |
| Commander order UI | `GUI_Menu_Command.sqf:252-306` | Commander-facing Move/Patrol/Defense map-click flow. It writes team variables and marker feedback; a general server-side executor is still unproven by static source. |
| Spawned-unit inheritance | `Client_BuildUnit.sqf:463-465`; `Client_SendSpawnedUnitsToLeaderWaypoint.sqf:13-94` | Newly bought units can inherit a stored map order, group waypoint or `expectedDestination`. This only runs at build/spawn handoff time and then issues `commandMove`; it does not maintain a queue. |
| Player-AI recovery | `Client_WatchdogPlayerAI.sqf:147-333`; `Client_RecoverPlayerAI.sqf:1-1000` | Client-side stuck-unit recovery for player-group AI, with manual and automatic paths. Preserve the STOP-order skip, recovery cooldown and `DoNotPlan`/destination fallback semantics before treating a unit as stuck. |

When debugging "AI ignores orders", first identify which layer is failing: command UI write, spawned-unit handoff, server/HC waypoint creation, or client-side recovery. Patching the wrong layer can make the visible symptom disappear in one scenario while leaving the real owner path untouched.

## Findings

| Severity | Finding | Evidence | Safe next action |
| --- | --- | --- | --- |
| High | AI supply trucks are broken if enabled on raw-spawn branches. | Docs checkout `Init_Server.sqf:36,382-383`; stable `cf2a6d6a` / release `a96fdda2` safe-disable at `Init_Server.sqf:37,383-384`; `AI_UpdateSupplyTruck.sqf:5-17`; missing `Server/FSM/supplytruck.fsm`. | Preserve the stable/release warning-disable shape during merges, or revive logistics only with a real server-owned loop/FSM and smoke. |
| High | Static-defense HC delegation has no completion/failback path. | `Server_DelegateAIStaticDefenceHeadless.sqf:22-27`; `Client_DelegateAIStaticDefence.sqf:28`. | Add callback/timeout or keep static-defense manning server-local. |
| Medium | Town HC delegation lacks heartbeat/failback. | `Server_DelegateAITownHeadless.sqf:23-30`; `Client_DelegateTownAI.sqf:35`. | Smoke HC disconnect during active town and document orphan behavior. |
| Medium | Client/HC delegated-group cleanup polls are unbounded. | `Client_DelegateTownAI.sqf:42-43`; `Client_DelegateAI.sqf:29-30`; `Client_DelegateAIStaticDefence.sqf:35-36`. | Add timeout/diagnostic/reconciliation when adding HC work records; smoke leaked/dead group cleanup on HC disconnect. |
| Medium | FPS sleep helper may be inverted. | `Common_GetSleepFPS.sqf:5-9`; `updateresources.sqf:74-75`. | Decide intent before patching; record RPT/perf evidence. |
| Medium | Patrols v2 is current-master source-present but runtime-smoke pending. | Stable `origin/master` `cf2a6d6a` has `server_side_patrols.sqf:24-58`, `Common_RunSidePatrol.sqf:53-83` and `Client/FSM/updatepatrolmarkers.sqf:18-58`; [branch matrix](Towns-Camps-And-Capture-Atlas#patrols-v2-side-upgrade-path). | On current `cf2a6d6a`, run an Arma 2 OA smoke for Patrols upgrade levels 1/2/3, HC delegation, marker audience, patrol death and side-slot/cooldown release. Treat old DR-57/AI1 and release's older patrol-loop fix as historical unless working on those branch families. |
| Medium | AI commander autonomy is scaffolded, not complete. | Funds at `Init_Server.sqf:356-365`; upgrade helper `Server_AI_Com_Upgrade.sqf:12-50`; no complete scheduler proven. | Treat as owner decision / disabled partial until scheduler and buy/upgrade smoke exist. |
| Medium | Commander map-order execution is not proven by static source. | `GUI_Menu_Command.sqf:252-306` writes `wfbe_teammode` / `wfbe_teamgoto`; `RequestTeamUpdate.sqf:3-25` is a separate live team-property PVF; static `AIMoveTo` / `AIPatrol` callers are support/resistance paths, not the command-menu vars. | Smoke Move, Patrol, Defense and Take Towns in Arma 2 OA before hardening or extending commander AI orders. |
| Medium | AI town attack-path helper is compiled but dormant-looking in stable master, and its path-building branch clears existing waypoints before random/safety exits. | `Init_Server.sqf:45-47`; `Server_AI_SetTownAttackPath.sqf:18,41,74-78,80-109`; no static caller found for `WFBE_SE_FNC_AI_SetTownAttackPath` outside compile/docs in this scan. Branch check 2026-06-06 found current source/Vanilla, stable `origin/master`, Miksuu upstream, `perf/quick-wins` and release all still carry the TODO comments for combat/speed, radio-on-waypoint completion and possible camp securing. | Treat the TODOs as AI polish/enhancement debt, not a confirmed runtime failure. If AI commander/order revival calls this helper, add a smoke where a distant team receives a town attack order and still has final depot/camp waypoints after random/safety branches; only then tune behavior/combat speed or radio messages. |
| Low/Medium | Stale delegation helper shadows the current inline implementation. | `Server/Functions/Server_GetDelegators.sqf` still exists in source, Vanilla and modded trees, but no compile/reference to it was found. Active source/Vanilla delegation defines `WFBE_SE_FNC_GetDelegators` inline in `Server_FNC_Delegation.sqf:139-178`; modded Eden/Lingor/Napf use the same inline pattern around `:127`. The inline version also accounts for already-selected repeats, unlike the standalone helper. | Treat `Server_GetDelegators.sqf` as stale duplicate/generated drift. Keep active patches in `Server_FNC_Delegation.sqf`; delete/annotate the stale helper only after a generated/modded cleanup decision. |
| Low/Medium | Town static defenses are resistance-only. | `Server_SpawnTownDefense.sqf:18`; `Server_OperateTownDefensesUnits.sqf:24`. | Correct any docs implying all occupied towns spawn static defense crews. |

## Runtime Smoke

| Target | Smoke gates |
| --- | --- |
| Dedicated server | Verify `commonInitComplete`, `townInit`, `serverInitFull`, town loop, town AI loop, camp loop, cleanup loops, performance audit and the target branch's FPS publisher shape. Use [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep) for one-publisher vs two-publisher expectations. |
| Hosted/listen | Verify server/client branches both run, the target branch's FPS publishers exit cleanly or are absent as expected, and client waits/JIP queries finish without relying on server-FPS publication. |
| JIP | Join after server init and town activation; verify side logic, town/camp states, marker updates, day/night sync and no duplicated local loops. |
| HC | Run dedicated plus HC with delegation mode 2; verify HC registration, town AI delegation, `update-town-delegation`, HC disconnect removal and fallback behavior. |
| Negative AI supply | In a private raw-spawn branch only, enable the old AI supply-truck path and confirm the missing-FSM failure; use that as a release gate before any revival. Stable/release should instead show the warning-disable path. |

## Continue Reading

Previous: [AI/headless/performance](AI-Headless-And-Performance) | Next: [HC delegation/failover](Headless-Delegation-And-Failover-Playbook)

Related: [Server runtime atlas](Server-Gameplay-Runtime-Atlas) | [AI commander autonomy audit](AI-Commander-Autonomy-Audit) | [Town AI vehicle despawn safety](Town-AI-Vehicle-Despawn-Safety) | [Feature status](Feature-Status-Register)
