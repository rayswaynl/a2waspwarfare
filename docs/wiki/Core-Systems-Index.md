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

