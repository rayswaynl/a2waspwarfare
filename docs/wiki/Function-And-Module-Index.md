# Function And Module Index

This page names the major function groups and what they are for. It is intentionally behavior-oriented so a developer or AI assistant can find the right file family quickly.

Unless a row names another ref, line refs below are from docs checkout `docs/developer-wiki-index` `1f0b9018` and the Chernarus source mission root `Missions/[55-2hc]warfarev2_073v48co.chernarus/`. Treat this page as a source-family route map, not the canonical patch-status matrix.

## How To Use This Page

| Need | Open first |
| --- | --- |
| Compile counts and regenerate commands | [SQF code atlas](SQF-Code-Atlas) |
| Runtime boot order and role dispatch | [Mission entrypoints and lifecycle](Mission-Entrypoints-And-Lifecycle), [Lifecycle wait-chain](Lifecycle-Wait-Chain) |
| Module status, dead modules and revive/remove decisions | [Modules atlas](Modules-Atlas), [Dead/stale code register](Dead-Code-And-Stale-Code-Register), [Abandoned feature revival](Abandoned-Feature-Revival-Review) |
| Network/PVF handler risk | [Networking and public variables](Networking-And-Public-Variables), [Public variable channel index](Public-Variable-Channel-Index), [PVF dispatch implementation](PVF-Dispatch-Implementation-Playbook) |
| Commander, paratrooper, MASH or performance-audit branch status | [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook), [Source fix propagation queue](Source-Fix-Propagation-Queue), [Respawn and death lifecycle](Respawn-And-Death-Lifecycle-Atlas), [PerformanceAuditAnalyzer](PerformanceAuditAnalyzer) |

## Common Function Families

- `Common_Array*`: array helpers used by older SQF code that predates richer utility libraries.
- `Common_Get*`: lookup helpers for factories, towns, camps, groups, side IDs, side logic/HQ, team state, funds, supply, upgrades, config data and positions (`Common/Init/Init_Common.sqf:24-65,113-140`). Depot lookup is a client family helper (`WFBE_CL_FNC_GetClosestDepot` at `Client/Init/Init_Client.sqf:102`), not a `Common_Get*` helper.
- `Common_Set*`: shared state setters for commander votes, team autonomy/respawn/move mode/move position/type, namespace/profile variables and turret magazines (`Common/Init/Init_Common.sqf:75-80,150,171`).
- `Common_SendTo*`: network abstraction around PVF dispatch to client(s) and server.
- `Common_Handle*`: event handlers for reload, AT, AA, missile/bomb/artillery, rocket tracer and alarms (`Common/Init/Init_Common.sqf:6-16,66-68,141-143`). Generic building damage handling is server-side (`BuildingHandleDamages`), not a `Common_HandleDamage` helper.
- `Common_CreateMarker`, `Common_MarkerUpdate`, `Common_AARadarMarkerUpdate`: marker creation/update layers.
- `Common_LogContent`: mission logging wrapper used for `INITIALIZATION`, `INFORMATION`, `WARNING` and error-style RPT lines.
- `PerformanceAudit_*`: RPT audit writer helpers consumed by `Tools/PerformanceAuditAnalyzer`.

## Client Function Families

- `Client_BuildUnit`: main player purchase/spawn path after buy-menu selection.
- `Client_UI*`: list filling, gear templates, price updates, respawn selector and target updates.
- `Client_Get*`: client-side lookup helpers for respawn, income, gear content, nearby camps/depots/airports.
- `Client_Handle*`: map clicks, PVF dispatch, map state and HQ action helpers.
- `Client_Delegate*`: local AI delegation handlers when server delegates AI work to clients/headless.
- `Client_WatchdogPlayerAI` and `Client_RecoverPlayerAI`: player AI recovery/watchdog systems.
- `Client_BookkeepBlinkingIcons` and `Client_SetMapIconStatusInCombat`: combat marker blinking system.
- `Client_UpdateRHUD`: HUD/FPS overlay update loop with cached UI writes.

## Server Function Families

- `Server_BuyUnit`: AI/team purchase path.
- `Server_ProcessUpgrade`: authoritative upgrade processing.
- `Server_UpdateTeam`: team state synchronization.
- `Server_HandlePVF`: server-side PVF dispatcher.
- `Server_HandleDefense`, `Server_SpawnTownDefense`, `Server_ManageTownDefenses`: town/static defense systems.
- `Server_AI_SetTownAttackPath*`: AI attack path selection and safety checks.
- `Server_AI_Com_Upgrade`: live AI commander upgrade worker; selects from `Format ["WFBE_C_UPGRADES_%1_AI_ORDER", _side]` (`Server/Functions/Server_AI_Com_Upgrade.sqf:12`), checks AI commander funds/supply and debits, but no obvious live scheduler has been found.
- `Server_DelegateAI*`: delegation to headless/client workers.
- `Server_FNC_Delegation`: selects delegation targets for town/player AI. No `setGroupOwner` rebalancing path has been found.
- `Server_AssignNewCommander`: commander assignment notification/AI-commander stop helper. Docs checkout `1f0b9018` still has the DR-15 helper unpacking bug (`Server_AssignNewCommander.sqf:3-4`), while stable `origin/master` `cf2a6d6a`, release `a96fdda2`, Miksuu `b8389e74` and `origin/perf/quick-wins` `0076040f` fix that helper shape but keep duplicate notification/UI identity risks; use [Commander reassignment call shape](Commander-Reassignment-Call-Shape#current-branch-matrix).
- `Server_HandleBuilding*`, `Server_Building*`, `Server_OnHQKilled`, `Server_MHQRepair`: structure lifecycle and HQ damage/repair.
- `Server_ChangeSideSupply`, `Server_PV_RequestSupplyValue`: side supply network bridge.
- `Server_LogGameEnd`, `Server_CallExtensions/GlobalGameStats`: operational reporting.

## Client Modules

- `Client/Module/AFKkick`
- `Client/Module/AntiStack`
- `Client/Module/AutoFlip`
- `Client/Module/CM`
- `Client/Module/CoIn`
- `Client/Module/EASA`
- `Client/Module/Engines`
- `Client/Module/MASH`
- `Client/Module/Nuke`
- `Client/Module/Skill`
- `Client/Module/supplyMission`
- `Client/Module/UAV`
- `Client/Module/Valhalla`
- `Client/Module/ZetaCargo`

## Common Modules

- `Common/Module/Arty`
- `Common/Module/CIPHER`
- `Common/Module/IRS`
- `Common/Module/Reaktiv`

## Server Modules

- `Server/Module/afkKick`
- `Server/Module/AntiStack`
- `Server/Module/MASH`
- `Server/Module/NEURO`
- `Server/Module/serverFPS`
- `Server/Module/supplyMission`

## Module Status And Gates

Presence in the tree does not always mean enabled in the current mission mode. Popper's module/support pass found this practical status split:

| Module family | Status | Gate / note |
| --- | --- | --- |
| `Common/Module/Arty` | Live. | Used through common artillery handlers and support flows. |
| `Common/Module/IRS` | Live. | Initialized through common init at `Init_Common.sqf:320`; vehicle/module availability still depends on constants and vehicle config. |
| `Common/Module/Reaktiv` | Branch-sensitive dead/unreachable module. | Docs checkout, Miksuu and perf keep maintained-root files (`Reaktiv_Init.sqf:5`) with no init caller; stable and release have no maintained-root `Common/Module/Reaktiv` hits. Use [Modules atlas](Modules-Atlas#reaktiv--reactive-era-armor-commonmodulereaktiv) for the current branch matrix. |
| `Client/Module/Nuke` | Live and config-gated. | `RequestSpecial` / ICBM authority is the critical DR-27 risk. |
| `Client/Module/EASA`, `Client/Module/CM` | Live but config-gated. | Countermeasures are also gated by vanilla/OA mode. |
| `Server/Module/AntiStack` | Compiled but optional. | Runtime loops are dormant when `WFBE_C_ANTISTACK_ENABLED == 0`; external DB dependency is still live-server sensitive when enabled. |
| `Server/Module/MASH` | Branch-sensitive: docs/Miksuu/perf keep local MASH respawn plus orphaned marker relay; stable/release remove the MASH deploy/init/module path while retaining some config class residues. | Do not infer MASH behavior from the module folder alone. Use [Respawn and death lifecycle](Respawn-And-Death-Lifecycle-Atlas#mash-split-live-respawn-dead-marker-relay) for branch scope. |
| `Server/Support/Support_Paratroopers.sqf` | Drop flow live; marker registration is branch-scoped and smoke-pending. | Docs checkout, stable and release register `HandleParatrooperMarkerCreation` in both maintained roots; Miksuu omits it; perf fixes Chernarus only. Use [Source fix propagation queue](Source-Fix-Propagation-Queue#current-branch-scope-2026-06-14) and [Paratrooper marker revival](Paratrooper-Marker-Revival). |

## High-Risk Edit Areas

- `Init_CommonConstants.sqf`: central constant namespace. Changes here affect both server and clients.
- `Init_PublicVariables.sqf`: PVF registration. Missing files or mismatched function names break networking; direct publicVariable channels outside this registry are inventoried in [Networking/PV](Networking-And-Public-Variables).
- `description.ext` / `initJIPCompatible.sqf`: both include generated `version.sqf`; a fresh checkout without generated version files will not preprocess cleanly.
- `Client_BuildUnit.sqf` and `Server_BuyUnit.sqf`: purchase/spawn paths with many factory-specific assumptions.
- `Server/Init/Init_Server.sqf`: long-lived server loops; duplicate or unconditional loops can hurt live performance.
- `Tools/LoadoutManager`: generated mission copying/packing; accidental edits to generated mission folders can be overwritten.

## Continue Reading

Previous: [SQF code atlas](SQF-Code-Atlas) | Next: [Networking/PV](Networking-And-Public-Variables)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
