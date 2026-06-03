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

Operational systems include anti-stack, AFK kick through BattlEye publicVariable filters, server FPS publication, performance audit logs and global game stats extension export. Discord status publishing is a separate `DiscordBot/` integration that consumes exported data; the mission itself only contains Discord help text / community links.

## Representative Source Anchors

| System | Source anchors |
| --- | --- |
| Towns/capture | `initJIPCompatible.sqf:215`; `Server/Init/Init_Server.sqf:510,514,519`; `Server/FSM/server_town.sqf:222,227,235,240,265`; `Server/FSM/server_town_ai.sqf:211-216,247` |
| Economy and resources | `Common/Init/Init_Common.sqf:19-20,42,53,61-63`; `Server/Init/Init_Server.sqf:531` |
| Factories/purchases | `Rsc/Dialogs.hpp:1448`; `Client/Init/Init_Client.sqf:52`; `Server/Init/Init_Server.sqf:10`; `Server/Functions/Server_BuyUnit.sqf:19` |
| Upgrades | `Common/Init/Init_CommonConstants.sqf:37,58`; `Server/Init/Init_Server.sqf:57`; `Common/Init/Init_Common.sqf:323` |
| Support/admin ops | `Server/Init/Init_Server.sqf:39-42,298,578`; `Client/FSM/updateclient.sqf:153-160`; `Common/Functions/Common_PerformanceAudit.sqf:4` |
| Discord integration boundary | Mission text mentions Discord at `briefing.sqf:17,19`, `Client/Init/Init_Client.sqf:958` and `stringtable.xml:416`; status publishing code lives in `DiscordBot/src/ProgramRuntime.cs:69-70`, `DiscordBot/src/GameStatusUpdater.cs:14,52` and `DiscordBot/src/ExtensionData/GameData/GameData.cs:36,159`. |

## Continue Reading

Previous: [Server runtime atlas](Server-Gameplay-Runtime-Atlas) | Next: [Economy/towns/supply](Economy-Towns-And-Supply)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
