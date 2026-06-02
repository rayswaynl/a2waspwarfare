# Function And Module Index

This page names the major function groups and what they are for. It is intentionally behavior-oriented so a developer or AI assistant can find the right file family quickly.

## Common Function Families

- `Common_Array*`: array helpers used by older SQF code that predates richer utility libraries.
- `Common_Get*`: lookup helpers for factories, towns, camps, depots, groups, side IDs, side logic, funds, supply, upgrades and positions.
- `Common_Set*`: shared state setters for teams, waypoints, profile variables and turret magazines.
- `Common_SendTo*`: network abstraction around PVF dispatch to client(s) and server.
- `Common_Handle*`: event handlers for reload, AT, AA, artillery, alarms and damage.
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
- `Server_AI_Com_Upgrade`: live AI commander upgrade worker; selects from `WFBE_C_UPGRADES_%SIDE_AI_ORDER`, checks AI commander funds/supply and debits, but no obvious live scheduler has been found.
- `Server_DelegateAI*`: delegation to headless/client workers.
- `Server_FNC_Delegation`: selects delegation targets for town/player AI. No `setGroupOwner` rebalancing path has been found.
- `Server_AssignNewCommander`: commander assignment notification/AI-commander stop helper; likely call-shape bug because it assigns `_side = _this` while callers pass `[_side, _commander]`.
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
