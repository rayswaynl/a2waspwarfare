# Server Gameplay Runtime Atlas

For town object startup, capture/SV, camp capture, marker visibility and town-AI activation ownership, use [Towns, camps and capture atlas](Towns-Camps-And-Capture-Atlas). For commander vote/reassignment, HQ deploy/mobilize, HQ destruction, wreck markers and MHQ repair ownership, use [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas). For match-end detection, winner/loser semantics and win-stat logging, use [Victory/endgame atlas](Victory-And-Endgame-Atlas). This page stays the broader server-loop router.

This page maps the long-running server gameplay systems from source: town capture, town AI, camps, economy/resources, commander/team state, victory checks, supply mission trust boundaries and server performance loops.

All paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

## Runtime Graph

```mermaid
flowchart TD
    IJ["initJIPCompatible.sqf"] --> Common["Common init + PVF registration"]
    IJ --> TownInit["Common town discovery"]
    IJ --> Server["Server/Init/Init_Server.sqf"]
    Server --> SideState["Side logic: HQ, teams, commander, upgrades, supply"]
    TownInit --> TownState["Town logics: sideID, SV, camps, defenses"]
    Server --> TownLoop["server_town.sqf capture/SV"]
    Server --> CampLoop["server_town_camp.sqf camps"]
    Server --> TownAI["server_town_ai.sqf activation/despawn"]
    Server --> Economy["updateresources.sqf income/supply/funds"]
    Server --> Victory["server_victory_threeway.sqf end state"]
    Server --> Perf["FPS publishers + PerformanceAudit"]
```

## Server Lifecycle Entrypoints

Lifecycle ownership note: [Lifecycle wait-chain](Lifecycle-Wait-Chain) owns the flag table, boot ordering, JIP waits and client/HC wait hazards. This atlas only lists the server runtime owners that start after `Init_Server.sqf` reaches its long-running loop phase.

`Server/Init/Init_Server.sqf` is the central server owner. It guards repeated execution at `:1`, compiles server functions at `:10-103`, initializes side/HQ/team state at `:302-503`, then starts long-running systems.

| System | Server entrypoint |
| --- | --- |
| Town capture and supply value loop | `Init_Server.sqf:509-510` starts `Server/FSM/server_town.sqf`. |
| Town AI activation/despawn | `Init_Server.sqf:512-516` starts `Server/FSM/server_town_ai.sqf`. |
| Camp capture manager | `Common/Init/Init_Town.sqf:129-130` registers camp workers; `Server/FSM/server_town_camp.sqf:8-25` runs one singleton manager. |
| Commander/HQ lifecycle | `Init_Server.sqf:313-371,622`, `Construction_HQSite.sqf`, `Server_OnHQKilled.sqf`, `Server_MHQRepair.sqf`; deep map in [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas). DR-20 covers `Server_OnHQKilled.sqf` score/idempotency risk. |
| Resources and economy | `Init_Server.sqf:526-532` starts `Server/FSM/updateresources.sqf`. |
| Victory/end state | `Init_Server.sqf:526-529` starts `Server/FSM/server_victory_threeway.sqf`. |
| Garbage, empty vehicles and cleaners | `Init_Server.sqf:535-559`. |
| Server FPS monitors | `Init_Server.sqf:577-595`. |
| AntiStack loops | `Init_Server.sqf:597-614`; deep map in [AntiStack database extension audit](AntiStack-Database-Extension-Audit). |
| Commander vote bootstrap | `Init_Server.sqf:622`. |

## Data Ownership

| Data | Owner | Evidence |
| --- | --- | --- |
| Town list | Global `towns` array populated by `Common/Init/Init_Town.sqf`. | `Init_Town.sqf:165` |
| Town static vars | Town logic objects: `name`, `range`, `startingSupplyValue`, `maxSupplyValue`, `lastSupplyMissionRun`, `supplyMissionCoolDownEnabled`, `wfbe_town_type`. | `Init_Town.sqf:31-40` |
| Town server vars | Town logic objects: `camps`, `wfbe_town_defenses`, `sideID`, `supplyValue`. | `Init_Town.sqf:63-64`, `:87-89` |
| Town AI state | Town logic objects: `wfbe_active`, `wfbe_active_air`, `wfbe_active_sideIDs`, `wfbe_inactivity`, `wfbe_active_override`, `wfbe_active_vehicles`, `wfbe_town_teams`. | `server_town_ai.sqf:21-32` |
| Side/commander state | Side logic objects: `wfbe_commander`, `wfbe_hq`, `wfbe_structures`, `wfbe_aicom_running`, `wfbe_aicom_funds`, `wfbe_upgrades`, `wfbe_upgrading`, `wfbe_votetime`, `wfbe_ai_supplytrucks`, `wfbe_commander_percent`. | `Init_Server.sqf:356-389` |
| Team list | Side logic `wfbe_teams`. | `Init_Server.sqf:500-501` |
| Team/group vars | Group variables: `wfbe_funds`, `wfbe_side`, `wfbe_queue`, `wfbe_vote`, `wfbe_autonomous`, `wfbe_respawn`, `wfbe_teamtype`, `wfbe_teammode`, `wfbe_teamgoto`. | `Init_Server.sqf:474-483` |
| Side supply | Mission namespace `wfbe_supply_<side>` plus temporary public variables `wfbe_supply_temp_<side>`. DR-44 confirms these direct temp channels are client-forgeable unless the server re-derives/validates the delta. | `Init_Server.sqf:386`, `Common_ChangeSideSupply.sqf:28-30`, `Server_ChangeSideSupply.sqf:1-47` |

## Long-Running Loop Notes

`Server/FSM/server_town.sqf` scans town ranges with `nearEntities` (`:57`), sleeps per town (`:259`) and per cycle (`:270`), then records performance audit data (`:262-266`).

`Server/FSM/server_town_ai.sqf` avoids aircraft in activation scans (`:84-93`), despawns inactive town AI (`:191-222`) and records audit data (`:244-248`). This is spawn/delete distance activation, not simulation caching.

`Server/FSM/server_town_camp.sqf` centralizes camp capture into a singleton manager. It registers workers and prevents duplicate managers at `:8-13`, then scans on a one-second cadence at `:22-25` and `:157`.

`Common/Functions/Common_PerformanceAudit.sqf` is local RPT logging, not network sync. It snapshots FPS/player/AI/unit/vehicle/town-active counts (`:28-105`), records aggregate call stats (`:159-193`) and flushes every 60 seconds by default (`:221-239`).

Ampere's runtime pass confirmed that the major loops are cooperative rather than tight in the normal dedicated-server path: town capture, town AI, camps, resources, victory, garbage and empty-vehicle collection all have sleeps or per-cycle yields. [Deep-review findings](Deep-Review-Findings) DR-19 owns the FPS publisher hosted/listen exception; it is now patched in source Chernarus and maintained Vanilla Takistan, with Arma smoke and any restored AI supply-truck path still review targets.

Patrol loop caveat: `server_patrols.sqf` and `server_town_patrol.sqf` use `while {!WFBE_GameOver || _team_alive}` / `while {!WFBE_GameOver || _aliveTeam}`, so after game over they can keep polling/sleeping while their team remains alive. Their active behavior branches are still guarded by `!WFBE_GameOver`, so document this as mostly inert post-game polling rather than continued active patrol assignment.

## Server Load Risks

| Risk | Evidence | Development note |
| --- | --- | --- |
| Low-FPS sleep inversion | `Common_GetSleepFPS.sqf:5-9` shortens sleeps under lower FPS. | Overloaded servers may run some loops more often, not less. Verify before reusing this helper. |
| Hosted-server FPS busy loop | DR-19: `Init_Server.sqf:578` starts `Server/GUI/serverFpsGUI.sqf` and `:595` starts `Server/Module/serverFPS/monitorServerFPS.sqf`; source Chernarus and maintained Vanilla Takistan now exit on `!isDedicated` before entering their loops (`serverFpsGUI.sqf:1`, `monitorServerFPS.sqf:1`). | Propagated, smoke pending. Dedicated publishing is preserved. See [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep). |
| Post-game patrol loop polling | `server_patrols.sqf` and `server_town_patrol.sqf` keep looping while their team remains alive, but active work is behind `!WFBE_GameOver` checks. | Low/medium cleanup. If post-game polling is unwanted, exit on game-over after confirming no cleanup semantics are being preserved. |
| Town scans | `server_town.sqf:57` uses `nearEntities` per town. | Preserve per-town/per-cycle sleeps and audit records. |
| Garbage scan | `server_collector_garbage.sqf:4-32` scans `allDead` every 0.5s. | Avoid adding more all-world scans nearby. |
| Empty vehicle scan | `emptyvehiclescollector.sqf:4-30` polls every 0.5s. | Keep cleanup conditions cheap. |
| AntiStack DB loop | `Server/Module/AntiStack/mainLoop.sqf:15-43` iterates `allUnits` and performs DB retrieve/store per player. | Extension/database latency is live-server sensitive; [AntiStack database extension audit](AntiStack-Database-Extension-Audit) owns the procedure/guard table. |

## Supply Mission Data Flow

```mermaid
flowchart LR
    ClientStart["Client supplyMissionStart.sqf"] --> TruckVars["Truck vars: SupplyFromTown, SupplyAmount"]
    ClientStart --> StartPV["WFBE_Client_PV_SupplyMissionStarted"]
    StartPV --> ServerStart["Server supplyMissionStarted.sqf"]
    TruckVars --> Completion["Server supplyMissionCompleted.sqf"]
    Completion --> Reward["Funds + supply reward"]
    Completion --> Cooldown["Town LastSupplyMissionRun"]
```

Supply mission start is not fully server-authoritative. Client code sets `SupplyFromTown` and `SupplyAmount` on the truck at `Client/Module/supplyMission/supplyMissionStart.sqf:20-34`, then sends `WFBE_Client_PV_SupplyMissionStarted` at `:38-39`. Completion later trusts truck variables in `Server/Module/supplyMission/supplyMissionCompleted.sqf:9-27`.

Current `master` duplicate-start risk is parallel tracking, not PR #1 interdiction handlers. `supplyMissionStarted.sqf` has no already-tracked guard, so repeated starts can spawn multiple completion loops for the same vehicle. `supplyMissionCompleted.sqf` clears `SupplyAmount` and `SupplyFromTown`, which bounds repeated reward risk, but repeated server/PV work and racey completion semantics remain unproven until an idempotency guard is added and smoked.

Cooldown casing detail is canonical in [Deep-review findings](Deep-Review-Findings) DR-18 and the [Supply mission architecture](Supply-Mission-Architecture) page. This atlas keeps only the runtime owner map.

## AI Commander Status

AI commander support is partially present. Boyle's second-pass review corrected the earlier shorthand: the upgrade worker and AI commander funds are real, but no obvious live scheduler was found that drives the full autonomous commander loop or sets `wfbe_aicom_running = true`. The detailed revival audit and source table now live in [AI commander autonomy audit](AI-Commander-Autonomy-Audit).

Evidence:

- Constants expose AI commander settings at `Common/Init/Init_CommonConstants.sqf:91-100`.
- Side logic state and funds exist at `Server/Init/Init_Server.sqf:364-365`.
- `WFBE_SE_FNC_AI_Com_Upgrade` is compiled at `Server/Init/Init_Server.sqf:48`; `Server/Functions/Server_AI_Com_Upgrade.sqf:12-50` reads upgrade order, checks funds/supply and debits through `ChangeAICommanderFunds` / `ChangeSideSupply`.
- Commander vote/assign code stops AI commander when a player commander exists at `Server/Functions/Server_VoteForCommander.sqf:54-57`.
- No active loop/FSM was found that starts and drives AI commander automation.

Treat AI commander production and autonomous logistics as partial until a dedicated implementation pass proves or restores the runtime owner. In particular, `AIBuyUnit` appears latent and `UpdateSupplyTruck` is broken under the supply-system-0 + AI commander branch. `Rsc/Parameters.hpp:92-97` also gives the AI commander mission parameter default as `0`, while `Init_CommonConstants.sqf:91` is only a nil fallback; use the audit before making default-state claims.

## Server End Conditions

`Server/FSM/server_victory_threeway.sqf:23-57` ends the mission when victory conditions are met. [Victory/endgame atlas](Victory-And-Endgame-Atlas) owns the exact implementation map, risk register and smoke checklist. The broad end-state pattern is:

- HQ is dead and no factories remain, or a side holds all towns.
- Server publishes endgame state, sets winner data such as `WF_Winner`, and flips `gameOver` / `WFBE_GameOver`.
- Optional AntiStack persistence may run.
- Mission ends through `failMission "END1"`.

Canonical correctness findings are routed through [Victory/endgame atlas](Victory-And-Endgame-Atlas), with raw evidence in [Deep-review findings](Deep-Review-Findings) DR-11 and DR-36. Runtime summary: the loop is server-authoritative and DR-36 found its Perf/JIP/HC posture clean, but the end-condition guard, winner semantics and no-break side loop still need the atlas fix before match results are trusted.

## Confirmed Defects And Partial Features

| Area | Evidence | Status |
| --- | --- | --- |
| AI supply truck system | `UpdateSupplyTruck` compile is commented at `Init_Server.sqf:36`, but spawn remains under supply system 0 + AI commander at `:381-383`; script calls missing `Server/FSM/supplytruck.fsm` at `Server/AI/AI_UpdateSupplyTruck.sqf:17`. | Config-gated broken path; see [AI commander autonomy audit](AI-Commander-Autonomy-Audit). |
| AI commander automation | State/funds/constants exist, but no active AI commander loop/FSM was found. | Partial/latent; see [AI commander autonomy audit](AI-Commander-Autonomy-Audit). |
| `Server_AssignNewCommander` call shape | `_side = _this` then `_commander = _this select 1` in `Server_AssignNewCommander.sqf:3-5`; caller passes `[_side, _assigned_commander]` from `RequestNewCommander.sqf:12-14`. | Confirmed bug; use [commander reassignment call shape](Commander-Reassignment-Call-Shape). |
| HQ-killed score/idempotency | Redundant HQ killed detection is intentional for locality/JIP (`Init_Server.sqf:319`, `Construction_HQSite.sqf:36,89`, `Init_Client.sqf:499-503`), but `Server_OnHQKilled.sqf:46-50` and `:74-81` award score without a done guard. | Confirmed [Deep-review findings](Deep-Review-Findings) DR-20. Guard the server consumer so repeated detections act once. |
| Supply mission cooldown casing | DR-18 confirms `lastSupplyMissionRun` / `LastSupplyMissionRun` mismatch. | Correctness bug; route details through [Supply mission architecture](Supply-Mission-Architecture) and DR-18. |
| Supply mission reward authority | Client sets truck `SupplyFromTown` and `SupplyAmount`; server completion trusts truck vars. | Hardening gap. |
| Supply mission duplicate starts | `supplyMissionStarted.sqf` can start parallel tracking loops for one vehicle; completion clears truck vars but does not prove idempotency. | Correctness/hardening gap; add an already-tracked guard before PR #1 supply-heli interdiction work is merged. |
| Side-supply direct PV forgery | `Common_ChangeSideSupply.sqf:28-30` sends `wfbe_supply_temp_<side>` directly; `Server_ChangeSideSupply.sqf:1-47` trusts payload side/amount and writes `wfbe_supply_<side>`. | DR-44. Re-derive the side and authorized delta server-side; also fix DR-22's negative-floor bug in the same handler. |
| Resistance supply handler gap | Common sender can format `wfbe_supply_temp_<side>` generically, but server handlers only exist for west/east. | Partially scaffolded but unsupported for live economy; use [resistance supply scaffold](Resistance-Supply-Scaffold). |
| Paratrooper markers | Server sends `HandleParatrooperMarkerCreation`; source Chernarus and maintained Vanilla Takistan now register the client PVF and ship the handler file. | Propagated, smoke pending; modded folders still drift. Use [Paratrooper marker revival](Paratrooper-Marker-Revival). |
| MASH markers | Server rebroadcast exists, client receiver compile is commented, and DR-34 found no client broadcast of `WFBE_CL_MASH_MARKER_CREATED`. | Broken/dead on both ends; MASH respawn itself is separate and mapped in [Respawn/death lifecycle](Respawn-And-Death-Lifecycle-Atlas). Revive markers with a server-held marker list and JIP replay, or remove. |
| Victory/endgame guard | `server_victory_threeway.sqf:23` plus the per-side loop are the DR-36 root-cause surface for DR-11/DR-13. | Correctness bug; use [Victory/endgame atlas](Victory-And-Endgame-Atlas) for the developer map and [Deep-review findings](Deep-Review-Findings) DR-11/DR-36 for raw evidence. |

## Safe Extension Points

- New server loops should start from `Init_Server.sqf` only after common/town initialization is complete and should set a visible lifecycle flag if clients or headless code wait on it.
- Add performance audit records around any loop that scans towns, all units, all dead objects, vehicles or players.
- Keep side-owned state on side logic objects and team-owned state on group variables; do not introduce parallel globals unless a public-variable sync path needs them.
- For supply/economy changes, make the server recompute authoritative reward/cooldown data from trusted town/truck state rather than client-provided amounts.

## Continue Reading

Previous: [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas) | Next: [Core systems index](Core-Systems-Index)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
