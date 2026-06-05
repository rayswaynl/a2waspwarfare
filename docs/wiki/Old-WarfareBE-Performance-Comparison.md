# Old WarfareBE Performance Comparison

This page compares the old BennyBoy WarfareBE Takistan source with current Wasp Chernarus for FPS-relevant architecture. It is meant to answer the community question: would the older mission code likely perform better, and what lessons should be tested before cutting core gameplay?

Scope:

- Old source: [`BennyBoy-/ArmA2_WarfareBE`](https://github.com/BennyBoy-/ArmA2_WarfareBE) at commit `aeb71bb` (`Updated nfo`), cloned locally for this pass.
- Current source: `Missions/[55-2hc]warfarev2_073v48co.chernarus` on `docs/developer-wiki-index`.
- This is docs-only analysis. It does not prove runtime FPS by itself; it identifies what to measure.

## Short Answer

The old mission is likely lighter in some practical ways, but not because its core Warfare model is radically different. Old WarfareBE still has town `nearEntities` scans, town-AI activation/despawn, dynamic town defense gunners, public-variable dispatch, garbage collectors, AI teams and support loops.

The stronger FPS suspects are:

1. Lower old default player AI cap and lower practical content load.
2. Fewer Wasp-era added systems: performance audit, server-FPS publishers, AFK/AntiStack, extra marker/HUD state, cleaner/restorer scripts, integrations and feature branches.
3. Wasp current public-variable/event surface is broader.
4. Current Wasp defaults assume headless-client delegation, but when HC is absent or misbehaving, server fallback still carries the work.

So the best next move is not “revert to old code.” It is a controlled A/B test: same player count, same AI cap, same view distance, same town-defense settings, same cleanup settings, with RPT/performance audit output captured.

## Discord Summary

```text
Old Benny WarfareBE probably feels lighter, but the source does not show a magic old town-AI system.

Both old and current Wasp use town nearEntities scans, town-AI spawn/despawn, static-defense gunners, public variables, garbage collectors and AI teams.

Likely FPS differences:
- old default player AI cap was lower: 12 vs current Wasp lobby default 15
- current Wasp has more extra systems: HC routing, PerformanceAudit, server FPS publishers, AFK/AntiStack, more PV channels, cleaner/restorer scripts, richer HUD/marker logic
- Wasp has more code/content overall: old clone 603 files / 546 script files; current source mission 787 files / 676 script files
- if HC is not actually carrying town/static AI, Wasp falls back to server-side work

Recommendation: test old vs current with the same AI cap first. Then test current Wasp with player AI capped around 8-10 for normal roles and Soldier as the high-AI role.
```

## Key Numbers

| Metric | Old BennyBoy WarfareBE | Current Wasp source mission | Interpretation |
| --- | ---: | ---: | --- |
| Files in mission tree | `603` | `787` | Wasp has a broader code/content surface. |
| SQF/SQS/FSM script files | `546` | `676` | Wasp has more scheduled/runtime code to audit. |
| `nearEntities` hits | `120` | `110` | Old is not free of entity scans; current has fewer raw hits in this scan. |
| `nearestObjects` hits | `21` | `26` | Current has slightly more object-scan surfaces. |
| `while {true}` hits | `32` | `34` | Loop count is similar; loop content/cadence matters more. |
| `setVariable [..., true]` hits | `198` | `216` | Current has a somewhat broader replicated-state surface. |
| `publicVariable` hits | `22` | `65` | Current has many more explicit public-variable references. |
| `addPublicVariableEventHandler` hits | `6` | `34` | Current has more direct event-handler setup. |
| `PerformanceAudit` hits | `0` | `198` | Current has a measurement layer old does not have. Useful, but still code. |
| `serverFPS` / `SERVER_FPS` hits | `0` | `16` | Current publishes server FPS; old source does not have that feature. |

Scan command family: `rg` over old clone and current source with `*.sqf`, `*.sqs`, `*.fsm`, `*.hpp` filters. Treat these as rough comparison counters, not profiler output.

## AI Cap Comparison

Old default lobby values:

| Old source | Evidence |
| --- | --- |
| AI group size default `10` | `BennyBoy-/ArmA2_WarfareBE@aeb71bb` `Rsc/Parameters.hpp:10-15`; fallback `Common/Init/Init_CommonConstants.sqf:63` |
| Player group size default `12` | `Rsc/Parameters.hpp:16-21` |
| AI delegation default disabled | `Rsc/Parameters.hpp:4-9`; fallback `Common/Init/Init_CommonConstants.sqf:64` |

Current Wasp defaults:

| Current source | Evidence |
| --- | --- |
| AI group size lobby default `4` | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Parameters.hpp:56-60` |
| Player group size lobby default `15` | `Rsc/Parameters.hpp:62-67` |
| Player cap fallback `16` | `Common/Init/Init_CommonConstants.sqf:243` |
| Soldier role can multiply player AI cap by `1.5` | `Client/Module/Skill/Skill_Init.sqf:49`; detailed table in [Player AI caps and role balance](Player-AI-Caps-And-Role-Balance) |
| AI delegation lobby default is headless client mode `2` | `Rsc/Parameters.hpp:50-55` |

Practical lesson: if the community wants immediate FPS relief without removing CTI identity, cap normal roles lower first. Player AI count is a cleaner, more predictable lever than town-loop surgery.

Suggested experimental cap direction:

| Role family | Suggested first test | Reason |
| --- | ---: | --- |
| Normal roles | `8-10` AI followers at full barracks | Keeps support/specialist utility while reducing total simulated units. |
| Soldier role | `16-20` AI followers at full barracks | Preserves the infantry-leader identity. |
| Commander bonus | reduce from `+10` to `+5`, or apply full bonus only to Soldier commander | Commander already has strategic power and base workload. |
| Server event test | same cap for all roles, then role-specific caps | Separates raw AI-load impact from role balance arguments. |

## Town AI And Town Activation

Old WarfareBE:

- `Common/Init/Init_Town.sqf:127-131` starts one `server_town.fsm` per town and conditionally one `server_town_ai.fsm` per town when defender or occupation AI is enabled.
- Town capture scans nearby `"Man"`, `"Car"`, `"Motorcycle"`, `"Tank"`, `"Air"` and `"Ship"` within capture range, then filters by height: `Server/FSM/server_town.fsm:139`.
- Town capture is a polling loop rather than a static state: `Server/FSM/server_town.fsm:137-153` repeats nearby-entity checks roughly every 5 seconds.
- Town AI initializes active flags, air-active flags, inactivity state and active vehicle tracking: `Server/FSM/server_town_ai.fsm:126-142`.
- Town group count scales from town SV and `WFBE_C_TOWNS_UNITS_COEF`, with a hard cap before coefficient and a separate air-only clamp: `Server/Functions/Server_GetTownGroups.sqf:23-73`.
- Town AI reads `WFBE_C_TOWNS_UNITS_INACTIVE`: `Server/FSM/server_town_ai.fsm:142`.
- Town AI detects nearby entities with the same broad class family and height filtering: `Server/FSM/server_town_ai.fsm:615`.
- Active ground and air town AI are spawned on demand: `server_town_ai.fsm:369-375,417-423`.
- `Common/Functions/Common_CreateTownUnits.sqf:27-48` creates town teams, starts `server_town_patrol.fsm`, reveals area and registers vehicles for empty-vehicle cleanup.
- The old code already had FPS-aware client delegation: clients send averaged `diag_fps` through `Client/FSM/updateavailableactions.fsm:119,122`, and `Server/Functions/Server_FNC_Delegation.sqf:133-144` checks group limits plus FPS before delegating AI work.
- Inactive town teams are deleted: `server_town_ai.fsm:555`.
- Inactive town vehicles are deleted if not player units: `server_town_ai.fsm:564`.
- Town defenses are manned and removed via `WFBE_SE_FNC_OperateTownDefensesUnits`: `server_town_ai.fsm:447,572`.

Current Wasp:

- Current Wasp moves town/SV and town-AI processing into global SQF loops launched once from `Server/Init/Init_Server.sqf:509-515`.
- Current town AI scans towns in a loop and records audit counters: `Server/FSM/server_town_ai.sqf:35-57`.
- Current town AI supports client delegation and HC delegation, then falls back to server AI: `server_town_ai.sqf:157-180`.
- Current town AI despawns teams and vehicles after inactivity: `server_town_ai.sqf:191-216`.

What this means:

- The old mission does not avoid town scans, per-town loops or spawn/despawn behavior.
- Current Wasp trades old per-town FSM workers for global SQF loops plus audit counters, HC/client delegation choices and more branch-specific safety concerns.
- Fewer or more files is not the deciding question here. The testable variables are active towns, spawned town groups, static gunners, player squads and whether delegation actually keeps AI off the dedicated server.
- Town AI should be measured with active-town count and AI count in the RPT before any rewrite.
- The already-documented town vehicle deletion risk remains a correctness fix, not a blanket FPS fix.

## Static Defenses

Old WarfareBE:

- Mission-placed defense logics carry `wfbe_defense_kind` values in `mission.sqm`.
- `Server_SpawnTownDefense.sqf:39-45` creates static defense vehicles and stores them on the logic.
- `Server_OperateTownDefensesUnits.sqf:20-48` creates gunners for mortars/defenses.
- `Server_OperateTownDefensesUnits.sqf:60-100` removes those gunners when despawning.

Current Wasp:

- Static-defense work still exists, but current code includes more HC-aware routing and performance audit around these paths.
- Current Wasp also has a high base-defense AI cap surface. Planck's scan found `WFBE_C_BASE_DEFENSE_MAX_AI = 40` in current constants and static-defense delegation paths through `Server_OperateTownDefensesUnits.sqf`.

Recommendation: do not only count player AI. Count static-defense gunners and town-defense gunners separately during tests. A town/base-defense-heavy match can keep many AI alive even when player groups are capped.

## Cleanup And Restorers

Old WarfareBE:

- Dead/killed units route into a trash object flow: `Common/Functions/Common_OnUnitKilled.sqf:45-49`.
- `Server_TrashObject.sqf:19-23` sleeps `WFBE_C_UNITS_CLEAN_TIMEOUT`, hides bodies for men, then deletes the object.
- Server init starts garbage and empty-vehicle collectors: `Server/Init/Init_Server.sqf:434-457`.
- The global garbage collector drains `allDead` and spawns `TrashObject` work: `Server/FSM/server_collector_garbage.fsm:63,66`.
- Empty vehicles use a 20-second polling wait around `WFBE_C_UNITS_EMPTY_TIMEOUT` before trashing or releasing: `Server/Functions/Server_HandleEmptyVehicle.sqf:7,10,17,29`.

Current Wasp:

- Current Wasp still has garbage and empty-vehicle collectors.
- Current Wasp additionally starts map cleaners/restorers for dropped items, craters, ruins, buildings and mines: `Server/Init/Init_Server.sqf:540-562`.
- These cleaner/restorer loops are already documented as measurement-first in [Performance opportunity sweep](Performance-Opportunity-Sweep) and [Marker cleanup/restoration atlas](Marker-Cleanup-Restoration-Systems-Atlas).

Recommendation: test with cleaner/restorer PerformanceAudit labels before changing cadence. Wide scans can look scary in source but run on long timers; AI count tends to dominate sooner.

## Public Variables And Network Shape

Old WarfareBE:

- PVF handlers are compiled into `CLTFNC*` / `SRVFNC*` names and PVEHs are registered: `Common/Init/Init_PublicVariables.sqf:38-46`.
- `Common_SendToClients.sqf:14-18` uses dynamic `Call Compile Format` to assign and `publicVariable` the target PV name, with hosted-server local spawn behavior.
- `Common_SendToServer.sqf:14-18` has the same dynamic pattern for server-bound PVF.
- The old PV receiver uses dynamic compile to resolve the requested handler: `Server/Functions/Server_HandlePVF.sqf:11-14`, `Client/Functions/Client_HandlePVF.sqf:19-22`.

Current Wasp:

- Current source keeps the same basic PVF compile/register pattern: `Common/Init/Init_PublicVariables.sqf:44-52`.
- Current send helpers still use the dynamic `Call Compile Format` pattern: `Common/Functions/Common_SendToClients.sqf:14-18`, `Common/Functions/Common_SendToServer.sqf:14-18`.
- Current Wasp has more PV-related source hits and more direct event-handler registrations in the quick scan.

Interpretation:

- Old WarfareBE is not safer or cleaner by default on PVF dispatch.
- Current Wasp has a broader network surface, so hardening and reducing chatty state still matter.
- The [PVF dispatch implementation playbook](PVF-Dispatch-Implementation-Playbook) remains a high-value fix because it removes runtime compile lookup and improves trust boundaries.

## Modern Wasp Additions That Need Measurement

These additions may be worth their cost, but they should be visible in tests:

| System | Current evidence | Test note |
| --- | --- | --- |
| PerformanceAudit | `Common/Functions/Common_PerformanceAudit.sqf:8,44-80` | Useful for this project, but include audit ON/OFF in at least one controlled test. |
| Server FPS publishers | `Server/GUI/serverFpsGUI.sqf:1-9`, `Server/Module/serverFPS/monitorServerFPS.sqf:1-8` | Low cadence, but duplicate published variables are still noise. |
| Cleaner/restorer scripts | `Server/Init/Init_Server.sqf:540-562` | Measure before cadence changes. |
| AntiStack loops | `Server/Init/Init_Server.sqf:597-608` | Test AntiStack ON/OFF separately from mission gameplay. |
| AFK/player status | See [Player join/disconnect and AntiStack lifecycle](Player-Join-Disconnect-And-AntiStack-Lifecycle) | Client/server status writes can matter with high player count. |
| HC delegation | `Server/FSM/server_town_ai.sqf:157-180` | Test with HC present and absent; fallback changes server load. |

## Test Plan

Minimum useful A/B weekend test:

| Step | Old mission | Current Wasp | Why |
| --- | --- | --- | --- |
| 1 | Default old settings | Current default settings | Shows real community experience difference, but not cause. |
| 2 | Player AI cap `10` | Player AI cap `10` | Normalizes the biggest likely variable. |
| 3 | Same view distance / terrain / weather | Same view distance / terrain / weather | Avoids client FPS false positives. |
| 4 | Record active AI / vehicles / players every 5-10 minutes | Use PerformanceAudit/RPT snapshots | Compare load, not feelings. |
| 5 | Repeat with current Wasp HC connected and disconnected | Current only | Proves whether HC is helping or falling back. |
| 6 | Repeat current Wasp with AntiStack/audit toggles where safe | Current only | Isolates modern support-system cost. |

Metrics to capture:

- player count;
- active AI count;
- vehicles count;
- active towns;
- server FPS;
- average client FPS from several clients;
- view distance / terrain grid;
- AI cap parameter;
- town defender/occupation settings;
- HC connected or absent;
- AntiStack and PerformanceAudit state.

## Recommendation Backlog

| Priority | Recommendation | Type | Owner page |
| --- | --- | --- | --- |
| P0 | Run old-vs-current test with the same player AI cap before drawing conclusions. | test | This page |
| P0 | Cap normal player roles lower first; keep Soldier as high-AI role. | balance/config | [Player AI caps and role balance](Player-AI-Caps-And-Role-Balance) |
| P1 | Count static-defense/town-defense gunners separately from player AI. | measurement | [AI, headless and performance](AI-Headless-And-Performance) |
| P1 | Test current Wasp with HC present and absent. | measurement | [Headless delegation and failover](Headless-Delegation-And-Failover-Playbook) |
| P1 | Use PerformanceAudit labels to prove cleaner/restorer and town-AI cost before patching loops. | measurement | [Performance opportunity sweep](Performance-Opportunity-Sweep) |
| P2 | Reduce duplicate server FPS publishing after consumer mapping. | cleanup | [Performance opportunity sweep](Performance-Opportunity-Sweep) |
| P2 | Keep PVF dispatcher lookup in the hardening backlog; old code has the same dynamic family, current code has more channels. | hardening/perf | [PVF dispatch implementation playbook](PVF-Dispatch-Implementation-Playbook) |

## Continue Reading

Previous: [Performance opportunity sweep](Performance-Opportunity-Sweep) | Next: [Player AI caps and role balance](Player-AI-Caps-And-Role-Balance)

Related: [AI, headless and performance](AI-Headless-And-Performance) | [Headless client scaling](Headless-Client-Scaling-And-Topology) | [Marker cleanup/restoration atlas](Marker-Cleanup-Restoration-Systems-Atlas) | [Networking and public variables](Networking-And-Public-Variables)

Main map: [Home](Home) | Live status: [Progress dashboard](Progress-Dashboard)
