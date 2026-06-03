# Core Systems Index

## Towns And Capture

Town data is initialized through `Common/Init/Init_Towns.sqf` and server-side town behavior runs globally through `Server/FSM/server_town.sqf`. Town AI and resistance behavior live in `Server/FSM/server_town_ai.sqf`, `Server/AI/AI_Resistance.sqf`, and helpers such as `Server_GetTownGroups`, `Server_SpawnTownDefense`, `Server_ManageTownDefenses`, and `Server_OperateTownDefensesUnits`.

Current defaults in common constants favor all-camp capture mode, medium defenders/occupation, automatic supply growth, and enhanced camp respawns.

## Economy

Economy state is split between funds and side supply. Common helpers expose team funds, side supply and income. Server resource updates run through `Server/FSM/updateresources.sqf`. The commander economy uses configurable income percentages and supply caps; player delivery rewards are derived from town supply value and configured coefficients.

## Commander And Teams

Each side has logic objects with `wfbe_teams`, commander state, HQ state and upgrade arrays. Commander voting and reassignment use server functions and PVF requests. Client command menus call into PVF request handlers rather than directly mutating server state.

## Construction And Base

Construction is a server-owned flow. Client building placement goes through CoIn/UI code, then server PVF request handlers validate and create structures. Important structure systems include HQ deployment, base area grouping, anti-air radar, repair/sale timing, structure max counts, and base defense manning range.

## Factories And Purchases

Player unit purchases for Barracks, Light, Heavy, Aircraft and Hangar/Airport run through `Client/GUI/GUI_Menu_BuyUnits.sqf` and `Client/Functions/Client_BuildUnit.sqf`. AI purchases use `Server/Functions/Server_BuyUnit.sqf`.

Spawn marker convention from repo instructions:

- Barracks: nearby `Sr_border`
- Light: `HeliH`, excluding `HeliHCivil` and `HeliHRescue`
- Heavy: `HeliHRescue`
- Aircraft: `HeliHCivil`
- Hangar/Airport: `WFBE_C_HANGAR_BUY_DISTANCE` plus `WFBE_C_HANGAR_BUY_DIR` fallback logic

## Upgrades

Upgrade indices are constants in `Init_CommonConstants.sqf`, from `WFBE_UP_BARRACKS = 0` through `WFBE_UP_UNITCOST = 21`. Upgrade processing is server-side via `Server_ProcessUpgrade`, while UI and availability are exposed through client menus.

## Respawn

Respawn modes include camp, leader, MASH and mobile respawn. Constants cover respawn delay, camp mode/ranges, MASH/mobile behavior, penalties and safe radius. Player respawn flow uses client handlers and server-owned team state.

## Support Systems

Support includes artillery, paratroopers, para ammo, para vehicles, UAV, fast travel, service point repair/rearm/refuel, HALO, ICBM, IR smoke, countermeasures, EASA and airlift/cargo.

## Administrative/Operational Systems

Operational systems include anti-stack, AFK kick through BattlEye publicVariable filters, server FPS publication, performance audit logs, global game stats extension export, and Discord bot status publishing.

## Representative Source Anchors

| System | Source anchors |
| --- | --- |
| Towns and capture | `Common/Init/Init_Town.sqf:31-40` seeds town variables; `Server/FSM/server_town.sqf:34-58` runs the town scan/capture loop; `:149-189` enforces all-camp capture mode. |
| Economy | `Server/FSM/updateresources.sqf:20-67` converts town supply into side/player/commander income; `Common/Init/Init_CommonConstants.sqf:276-278` defines supply-truck delivery reward/range settings. |
| Commander and teams | `Server/PVFunctions/RequestNewCommander.sqf:3-14` handles manual reassignment input; `Server/Functions/Server_AssignNewCommander.sqf:3-9` is the current DR-15 call-shape hazard. |
| Construction and base | `Server/PVFunctions/RequestStructure.sqf:3-22` dispatches structure creation; `Server/Construction/Construction_HQSite.sqf:20-38` deploys HQs and `:72-91` mobilizes MHQs plus killed-EH broadcasts. |
| Factories and purchases | `Client/GUI/GUI_Menu_BuyUnits.sqf:83,155` feeds player purchase UI; `Client/Functions/Client_BuildUnit.sqf:167-172,463-469` covers player queue/waypoint/decrement behavior; `Server/Functions/Server_BuyUnit.sqf:21-76` covers AI queue handling. |
| Upgrades | `Common/Init/Init_CommonConstants.sqf:37-58` defines upgrade indices; `Server/PVFunctions/RequestUpgrade.sqf:1-5` forwards requests; `Server/Functions/Server_ProcessUpgrade.sqf:17-47` publishes upgrade progress/completion state. |
| Respawn | `Common/Init/Init_CommonConstants.sqf:283-294` defines camp/leader/MASH/mobile respawn settings; `Client/Init/Init_Client.sqf:470-487` chooses the initial player spawn location. |
| Support systems | `Client/GUI/GUI_Menu_Tactical.sqf:58-59` lists tactical support actions; `Server/Functions/Server_HandleSpecial.sqf:43-49` routes para support; `Client/Init/Init_Client.sqf:534-535,589` initializes Zeta cargo and EASA. |
| Administrative/operational systems | `Server/Module/AntiStack/mainLoop.sqf:8-18` gates AntiStack DB loops and performance timing; `Server/Init/Init_Server.sqf:591-595` starts AFK/FPS operational hooks. |
