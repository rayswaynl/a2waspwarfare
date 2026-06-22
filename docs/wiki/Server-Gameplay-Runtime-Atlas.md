# Server Gameplay Runtime Atlas

Upstream-history note: Miksuu commit clusters show that server runtime changes around town AI, JIP and performance often need follow-up fixes. Read [Developer history and upstream lessons](Developer-History-And-Upstream-Lessons) before altering long-running server loops or wakeup logic.

This atlas maps long-running server gameplay loops and runtime surfaces that future owners should treat carefully. Paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

For deployment, packaging, BattlEye, extension and RPT collection questions, use [Server runtime and operations](Server-Runtime-And-Operations) to route to the correct operations page instead of expanding this runtime atlas.

## How To Use This Atlas

This page is the server-loop orientation map. Use it to find the runtime owner, then follow the branch/status page before making a current-master, release or patch-ready claim.

| Need | Start here | Then route to |
| --- | --- | --- |
| Server startup gates and long workers | [Runtime Loops](#runtime-loops), [Branch Scope For Source Anchors](#branch-scope-for-source-anchors) | [SQF code atlas](SQF-Code-Atlas), [Lifecycle wait-chain](Lifecycle-Wait-Chain) |
| Town capture, town AI and camps | Town capture / town AI rows | [Towns/camps/capture](Towns-Camps-And-Capture-Atlas), [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map) |
| Economy, resources and supply missions | Resource loop / supply mission rows | [Economy, towns and supply](Economy-Towns-And-Supply), [Supply mission architecture](Supply-Mission-Architecture), [Feature status register](Feature-Status-Register) |
| Patrols v2 and HC delegation | Side patrol branch row | [Towns/camps/capture](Towns-Camps-And-Capture-Atlas#patrols-v2-side-upgrade-path), [Headless delegation/failover](Headless-Delegation-And-Failover-Playbook) |
| FPS publishers, collectors and performance proof | FPS / collector rows | [Performance opportunity sweep](Performance-Opportunity-Sweep), [Testing workflow](Testing-Debugging-And-Release-Workflow), [Source fix propagation queue](Source-Fix-Propagation-Queue) |
| Direct PV/PVF authority risks | [Current Runtime Risks](#current-runtime-risks) | [Public variable channel index](Public-Variable-Channel-Index), [Server authority migration map](Server-Authority-Migration-Map) |
| Deployment, logs and release operations | Do not expand this page | [Server runtime and operations](Server-Runtime-And-Operations), [Server ops runbook](Server-Ops-Runbook) |

## Branch Scope For Source Anchors

Unless a row names another ref, source anchors below are valid for docs head `docs/developer-wiki-index` `a6785f51`. Rechecked 2026-06-14: targeted source diffs from `4277a2ad` to `HEAD` over the listed server-runtime paths return no changes, preserving the earlier `92c5cf05` / `6afcc58e` anchor snapshots. Rechecked Patrols v2 on 2026-06-21: docs branch `docs/developer-wiki-index@d30d2346` is unchanged from the earlier Patrols source anchors for checked paths, current stable is `origin/master@0139a346`, and current origin exposes no live `release/*` heads. Hosted-FPS anchors were refreshed on 2026-06-22: docs HEAD `d0161083` is source-unchanged from `a27086cd` for checked FPS paths, current stable `origin/master@0139a346` line-drifted the single-publisher init anchors to `Init_Server.sqf:769` and `:815-817`, and no `origin/dev/july-update-hosted-server-fps-loop-fix` head was found. Stable `origin/master@0139a346`, historical release `a96fdda2`, Miksuu `b8389e74` and `origin/perf/quick-wins` `0076040f` differ by runtime surface, so use the branch row and owner page before turning this atlas into current-master or release evidence.

| Runtime surface | Docs head `a6785f51` | Current stable `origin/master@0139a346` | Owner route |
| --- | --- | --- | --- |
| AI supply-truck startup | `Init_Server.sqf:36` comments the compile, but the AI-commander/supply-system gate initializes `wfbe_ai_supplytrucks` at `:382` and raw-spawns `UpdateSupplyTruck` at `:383`. | `Init_Server.sqf:37` still comments the compile, but `:383-384` initializes `wfbe_ai_supplytrucks` and logs that legacy supply-truck logistics are disabled instead of spawning the missing worker. Release `a96fdda2` matches this cleanup; Miksuu `b8389e74` and perf `0076040f` retain the raw-spawn shape in checked roots. | [AI commander autonomy](AI-Commander-Autonomy-Audit#ai-supply-truck-branch-matrix) |
| Patrols side-upgrade driver | No `Server/FSM/server_side_patrols.sqf`, `Common/Functions/Common_RunSidePatrol.sqf` or `Client/FSM/updatepatrolmarkers.sqf` exists in this docs checkout source; old `server_patrols.sqf` remains present. | `Init_Server.sqf:690` starts `server_side_patrols.sqf`; that driver initializes/publishes `WFBE_ACTIVE_PATROLS` at `:19`, waits/logs when no owned towns exist at `:48`, dispatches a live HC at `:67` or local runner at `:72`, and publishes patrol marker state through the owner route. Historical release `a96fdda2`, Miksuu and perf checked roots do not carry the Patrols v2 files. | [Towns/camps/capture](Towns-Camps-And-Capture-Atlas#patrols-v2-side-upgrade-path), [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map) |
| Server FPS publishers | `Init_Server.sqf:578,595` starts `serverFpsGUI.sqf` and `monitorServerFPS.sqf`; both files exit on `!isDedicated` at line `1`. | `Init_Server.sqf:769` starts `serverFpsGUI.sqf`; `:815-817` records that `monitorServerFPS.sqf` was removed as a redundant publisher, and `serverFpsGUI.sqf:4` exits on `!isDedicated`. Historical `a96fdda2` matches this single-publisher shape with older anchors `:579` and `:595-597`; Miksuu and perf keep two unguarded publishers in checked roots. | [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep), [Performance opportunity sweep](Performance-Opportunity-Sweep) |

## Runtime Loops

| Runtime surface | Source anchors | Notes |
| --- | --- | --- |
| Town capture loop | `Server/Init/Init_Server.sqf:510`; `Server/FSM/server_town.sqf` | Server-owned capture, supply value changes, camp side updates and performance audit rows. |
| Town AI loop | `Server/Init/Init_Server.sqf:512-514`; `Server/FSM/server_town_ai.sqf` | Defender/occupation activation, town AI delegation, static defense operation and despawn behavior. |
| Resource loop | `Server/Init/Init_Server.sqf:531`; `Server/FSM/updateresources.sqf:20-75` | Side supply/player funds/commander funds. The `_supply < WFBE_C_ECONOMY_SUPPLY_MAX_TEAM_LIMIT` gate wraps all three payout paths, so economy-cap changes suppress player paychecks and side-supply growth; AI commander funds continue to flow via a TOWN-STALL FIX block outside the gate (updateresources.sqf:95-109) that pays AI commander income and stipend whenever supply is at or over the cap. |
| Victory loop | `Server/Init/Init_Server.sqf:528`; `Server/FSM/server_victory_threeway.sqf` | Winner inversion/double-fire hazards live here; route through DR-11/DR-36 before patching. |
| Supply mission tracking | `Server/Module/supplyMission/supplyMissionStarted.sqf`; `Server/Module/supplyMission/supplyMissionCompleted.sqf` | Client-stamped cargo/reward state remains an authority cleanup lane; completion calls `ChangeSideSupply`, so rewards hit the DR-44 `wfbe_supply_temp_<side>` final mutation channel. Scan narrowing is docs/source propagated; use [Current source status snapshot](Current-Source-Status-Snapshot) before making stable-master or release claims. |
| Patrols side-upgrade driver | Branch-sensitive: current stable `origin/master@0139a346` `Init_Server.sqf:690`; `Server/FSM/server_side_patrols.sqf:12,19,48,67,72`; `Common/Functions/Common_RunSidePatrol.sqf:54,82,119,148,245,264`; `Server/Functions/Server_HandleSpecial.sqf:345-380`; `Client/FSM/updatepatrolmarkers.sqf:3,19` | Current stable has Patrols v2 source in Chernarus and maintained Vanilla, but this docs checkout, historical release `a96fdda2`, Miksuu and perf checked roots do not. Treat old DR-57 town-patrol wording as historical for earlier branches; current Patrols v2 is source-present and smoke-pending. |
| Garbage and empty-vehicle collectors | `Server/Init/Init_Server.sqf:535,537`; `Server/FSM/server_collector_garbage.sqf`; `Server/FSM/emptyvehiclescollector.sqf` | Dead-object and empty-vehicle cleanup surfaces; route supply-truck timeout and cleanup policy through [Marker cleanup/restoration](Marker-Cleanup-Restoration-Systems-Atlas) and [Performance opportunity sweep](Performance-Opportunity-Sweep). |
| HQ killed processing | `Server/Construction/Construction_HQSite.sqf:89,91`; `Client/Init/Init_Client.sqf:500-503`; `Server/Functions/Server_OnHQKilled.sqf:46-81,96-114` | Mobile-HQ killed EHs can fire from multiple owning-side clients; `Server_OnHQKilled.sqf` currently has no processed-once guard before score awards, messages and HQ marker/state broadcasts. Canonical finding: [Deep-review findings](Deep-Review-Findings) DR-20. |
| Server FPS publishing | `Server/GUI/serverFpsGUI.sqf`; `Server/Module/serverFPS/monitorServerFPS.sqf`; `Server/Init/Init_Server.sqf:578,595` | Current docs/source exits both publishers on `!isDedicated`; Arma smoke and branch-scope proof still decide release status. Canonical finding: [Deep-review findings](Deep-Review-Findings) DR-19. |
| Side radio/message pipeline | `Server/Init/Init_Server.sqf:32`; `Server/Functions/Server_SideMessage.sqf`; callers in `server_town.sqf:199,230,233`, `Server_BuildingKilled.sqf:92` and `Server_ProcessUpgrade.sqf:85` | Server-owned HQ-radio/kbTell messages for towns, bases, strongpoints, construction, commander votes and upgrades. Keep this separate from `LocalizeMessage` chat/PVF effects. See [SideMessage pipeline shape](#sidemessage-pipeline-shape). |

Server init is one dense startup cluster around `Server/Init/Init_Server.sqf:507-626` in this docs checkout and around the same worker band in `origin/master`. Runtime edits should be reviewed as a worker set rather than isolated scripts; use [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map) for AI/HC loop tables, [External integrations](External-Integrations) for AntiStack/DB deployment and [Testing workflow](Testing-Debugging-And-Release-Workflow) for smoke scope.

## SideMessage Pipeline Shape

`SideMessage` is a server-compiled radio wrapper, not the same path as client `LocalizeMessage`. Server init compiles it from `Server/Functions/Server_SideMessage.sqf` (`Server/Init/Init_Server.sqf:32`). The handler reads the side, message key and optional parameters (`Server_SideMessage.sqf:3-5`), resolves the side radio HQ speaker/receiver/topic from side logic (`:7-11`) and then calls `kbTell` through a compact switch (`:13-64`).

The payload shape is message-family dependent:

| Message family | Expected shape | Representative callers |
| --- | --- | --- |
| Town object messages | `[_side, "Lost" / "Captured" / "HostilesDetectedNear", _townLogic]` | town lost/captured uses `server_town.sqf:230,233`; town-AI activation uses `server_town_ai.sqf:134`. |
| Nearby strongpoint/town messages | `[_side, "LostAt" / "CapturedNear", ["Strongpoint", _townLogic]]` | camp side changes use `server_town_camp.sqf:127,130`; handler expects `select 0` as a spoken label and `select 1` as the town logic (`Server_SideMessage.sqf:23-30`). |
| Base or town attack/construction messages | `[_side, "Constructed" / "Destroyed" / "Deployed" / "Mobilized" / "IsUnderAttack", ["Base", _structure]]` or `["Town", _townLogic]` | construction/HQ paths use `Construction_SmallSite.sqf:115`, `Construction_MediumSite.sqf:130`, `Construction_HQSite.sqf:35,88`; base damage/kill/HQ kill use `Server_BuildingDamaged.sqf:13`, `Server_BuildingKilled.sqf:92`, `Server_OnHQKilled.sqf:53`; town attack uses `server_town.sqf:199`. |
| No-parameter radio topics | `[_side, "VotingForNewCommander" / "NewIntelAvailable" / "MMissionFailed" / "NewMissionAvailable"]` | commander vote uses `RequestCommanderVote.sqf:20`; upgrade completion uses `Server_ProcessUpgrade.sqf:85`. |
| Parameterized mission/extraction topics | `[_side, "MMissionComplete" / "ExtractionTeam" / "ExtractionTeamCancel", [spokenText, dubbingClass]]` | handled by `Server_SideMessage.sqf:61-62`; source-check the current caller before adding one. |

Do not collapse this into `LocalizeMessage`. `LocalizeMessage` is registered as a client PVF (`Common/Init/Init_PublicVariables.sqf:32`) and its client handler can show chat/title text or mutate local funds for some tags, for example `Teamkill`, `SecondaryAward` and `HeadHunterReceiveBounty` (`Client/PVFunctions/LocalizeMessage.sqf:49,53,57-68`). `SideMessage` is the server-owned radio/dubbing path. If you add radio lines, dubbing classes or new side-message keys, smoke each payload family in Arma 2 OA and inspect both the side radio output and the adjacent `LocalizeMessage` path if the same gameplay event also emits chat/economy feedback.

## Current Runtime Risks

| Risk | Status | Owner route |
| --- | --- | --- |
| Hosted/listen FPS busy loop | Branch-sensitive; the branch-scope table above and hosted-FPS owner page own exact refs. Docs/source keeps two guarded publishers, stable/release keep one guarded publisher, and Miksuu/perf keep the old two-loop shape. Arma smoke still decides release-ready wording; DR-19. | [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep), [Current source status snapshot](Current-Source-Status-Snapshot) and [Deep-review findings](Deep-Review-Findings) DR-19 |
| Supply command-center broad scan | Docs/source propagated; stable/release branch status and Arma smoke decide shipped state | [Supply mission scan narrowing](Supply-Mission-Scan-Narrowing) |
| Supply reward/cooldown authority | Open hardening; includes DR-44 final side-supply mutation channel | [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook) |
| AI supply-truck startup branch split | Branch-sensitive; the branch-scope table above and AI commander owner matrix own exact refs. Docs/Miksuu/perf retain the raw-spawn trap, stable/release log-disable the legacy path, and `feat/ai-commander` is only a partial branch guard. | [AI commander autonomy](AI-Commander-Autonomy-Audit#ai-supply-truck-branch-matrix), [Source fix propagation queue](Source-Fix-Propagation-Queue) |
| Patrols v2 source/smoke split | Current stable `origin/master@0139a346` has the side-upgrade patrol path in Chernarus and maintained Vanilla; docs checkout, historical release, Miksuu and perf checked roots do not. Treat Patrols v2 as source-present/smoke-pending on current master, not as the old DR-57 town-patrol bug. | [Towns/camps/capture](Towns-Camps-And-Capture-Atlas#patrols-v2-side-upgrade-path), [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map), [Testing workflow](Testing-Debugging-And-Release-Workflow) |
| Victory double-fire/winner inversion | Open correctness | [Deep-review findings](Deep-Review-Findings) DR-11/DR-36 |
| HQ-killed duplicate processing / score exploit | Open correctness; DR-20 | [Deep-review findings](Deep-Review-Findings) DR-20 |
| Direct PV authority | Open hardening | [Public variable channel index](Public-Variable-Channel-Index) |
| Side-message payload shape | Source-cited runtime surface | Use [SideMessage pipeline shape](#sidemessage-pipeline-shape). `SideMessage` takes different parameter shapes for town, strongpoint, base/construction and no-parameter radio topics; keep it separate from `LocalizeMessage` before adding radio/dubbing or changing message text. |
| AntiStack/database loops | High-sensitivity lifecycle surface | [External integrations](External-Integrations), [AntiStack database extension audit](AntiStack-Database-Extension-Audit) and [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map) |
| Dormant maintenance hooks | Disabled/commented server hooks are orientation signals only; branch-sensitive startup facts belong in the branch-scope table and owner pages. The SQF atlas now owns the compact disabled/deferred compile map. | [SQF code atlas](SQF-Code-Atlas#disabled-or-deferred-compile-signals), [Server init bind cleanup](Server-Init-Bind-Cleanup), [AI commander autonomy](AI-Commander-Autonomy-Audit#ai-supply-truck-branch-matrix) |

## Safe Runtime Rules

- Do not remove sleeps or change scan cadence without measuring gameplay and performance effects.
- Keep Arma 2 OA hosted/dedicated/headless differences explicit; do not import Arma 3 locality/JIP examples.
- Treat publicVariable handlers as lacking a trusted sender identity unless source proves a server-owned anchor.
- When gameplay code is requested later, patch source Chernarus first and propagate generated Vanilla Takistan through LoadoutManager.

## Continue Reading

Systems: [Gameplay systems atlas](Gameplay-Systems-Atlas) | Performance: [Performance opportunity sweep](Performance-Opportunity-Sweep) | Current truth: [Current source status snapshot](Current-Source-Status-Snapshot) | Propagation: [Source fix propagation queue](Source-Fix-Propagation-Queue)
