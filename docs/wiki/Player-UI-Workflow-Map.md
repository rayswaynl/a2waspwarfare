# Player UI Workflow Map

This page maps what a player or commander can actually do from the client UI, and where each workflow lives in source. Use it before editing `Rsc/Dialogs.hpp`, `Client/GUI/*`, player actions, map-click behavior, HUD/title resources or WASP action surfaces.

Canonical implementation pages remain [Client UI systems atlas](Client-UI-Systems-Atlas), [Client UI/HUD/menus](Client-UI-HUD-And-Menus), [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas), [Service menu affordability guards](Service-Menu-Affordability-Guards), [UI IDD collision repair](UI-IDD-Collision-Repair), [Respawn/death lifecycle](Respawn-And-Death-Lifecycle-Atlas) and [WASP overlay](WASP-Overlay).

## Workflow Map

| Flow | What the player can do | Source owners | Status |
| --- | --- | --- | --- |
| Join/init | Loading blackout, side/stack request, briefing diary, intro video, optional commander vote and new-player menu hint. | `initJIPCompatible.sqf:70`, `:224`; `Client/Init/Init_Client.sqf:416`, `:787`, `:958`; `briefing.sqf:11` | Live. |
| WF menu entry | Scroll `Options` opens the main Warfare menu; vehicle action mirror also exists. | `Client/Functions/Client_AddWFMenuAction.sqf:17`; `Client/Action/Action_Menu.sqf:1`; `Client/FSM/updateactions.fsm:114` | Live. |
| Main menu | Buy units, gear, team, voting, command, tactical, upgrade, economy, service, help, params, unflip, headbug and HUD/FPS toggles. | `Rsc/Dialogs.hpp:1019-1022`; `Client/GUI/GUI_Menu.sqf:32-208` | Live; some help/tooltips are hardcoded. |
| Buy units | Select factory/depot/airport, select unit and buy; client queues, debits and spawns. | `Rsc/Dialogs.hpp:1445-1448`; `Client/GUI/GUI_Menu_BuyUnits.sqf:90-156`; `Client/Functions/Client_BuildUnit.sqf:216-253` | Live; client-authoritative purchase surface. |
| Buy gear/templates | Select target, gear tab/template, buy gear, create/delete/save templates. | `Rsc/Dialogs.hpp:530-533`; `Client/GUI/GUI_BuyGearMenu.sqf:418-509`; `Client/GUI/Client_UI_Gear_AddTemplate.sqf:132-150` | Live; client-authoritative and template-filter debt. |
| Team/vote/transfer | View terrain/FX/distance, transfer funds, disband AI, toggle vote popup and vote/select commander. | `Rsc/Dialogs.hpp:1233-1236`, `:409-412`, `:145-148`, `:237-240`; `GUI_Menu_Team.sqf:86-160`; `GUI_TransferMenu.sqf:57-75`; `GUI_VoteMenu.sqf:31-36` | Live. |
| Command | Commander issues AI orders, town/patrol/defend behavior, respawn, auto-AI, buy-type settings, selected-unit actions and property changes. | `Rsc/Dialogs.hpp:1789-1792`; `GUI_Menu_Command.sqf:252-443`, `:477-501` | Live with partial task UI. |
| Tactical/supports | Artillery, fast travel, ICBM, paradrop ammo/vehicle/paratroops, unit cam and UAV. | `Rsc/Dialogs.hpp:2161-2164`; `GUI_Menu_Tactical.sqf:56-61`, `:239-344`, `:363-527`, `:541-605` | Live; many paths are client-gated/debited. |
| Upgrade | Open live upgrade dialog and buy/sync upgrades. | `Rsc/Dialogs.hpp:4-7`; `GUI_Menu.sqf:161-165`; `GUI_UpgradeMenu.sqf:135-161` | Live. Old `RscMenu_Upgrade` is stale. |
| Economy/build | Commander opens CoIn build, changes income %, sells structures and respawns supply trucks. | `Client/FSM/updateclient.sqf:220`; `Action_Build.sqf:1`; `coin_interface.sqf:29`, `:672-718`; `GUI_Menu_Economy.sqf:74-150` | Live; high authority surface. |
| Service/EASA | Rearm, repair, refuel, heal and aircraft loadout dialog. | `Rsc/Dialogs.hpp:2870-2873`, `:3209-3212`; `GUI_Menu_Service.sqf:128-244`; `GUI_Menu_EASA.sqf:47-50` | Live; affordability/authority debt. |
| Respawn/RHUD/map/WASP | Respawn source/gear choice, RHUD/FPS overlay, map-click AI shortcuts, capture/title overlays and WASP actions. | `Client_OnKilled.sqf:155`; `GUI_RespawnMenu.sqf:13-157`; `Client_UpdateRHUD.sqf:3-95`; `Client_HandleMapSingleClick.sqf:20-179`; `WASP/actions/AddActions.sqf:15`; `WASP/baserep/viem.sqf:13-53` | Live with stale/commented WASP prototypes nearby. |

## Dialog And Action Surfaces

| Surface | Class/action | Source refs | Status |
| --- | --- | --- | --- |
| Upgrade | `WFBE_UpgradeMenu`, IDD `504000` | `Rsc/Dialogs.hpp:4-7`; `GUI_UpgradeMenu.sqf:135-161` | Live. |
| Vote | `WFBE_VoteMenu`, `WFBE_Commander_VoteMenu` | `Rsc/Dialogs.hpp:145-148`, `:237-240`; `GUI_Menu.sqf:56-96` | Live. |
| Respawn | `WFBE_RespawnMenu`, IDD `511000` | `Rsc/Dialogs.hpp:314-317`; `GUI_RespawnMenu.sqf:103-157` | Live. |
| Transfer | `WFBE_TransferMenu`, IDD `505000` | `Rsc/Dialogs.hpp:409-412`; `GUI_TransferMenu.sqf:57-75` | Live. |
| Gear | `WFBE_BuyGearMenu`, IDD `503000` | `Rsc/Dialogs.hpp:530-533`; `GUI_BuyGearMenu.sqf:418-509` | Live, risky. |
| Main | `WF_Menu`, IDD `11000` | `Rsc/Dialogs.hpp:1019-1022`; `GUI_Menu.sqf:32-208` | Live. |
| Team | `RscMenu_Team`, IDD `13000` | `Rsc/Dialogs.hpp:1233-1236`; `GUI_Menu_Team.sqf:86-160` | Live. |
| Buy units | `RscMenu_BuyUnits`, IDD `12000` | `Rsc/Dialogs.hpp:1445-1448`; `GUI_Menu_BuyUnits.sqf:90-156` | Live, risky. |
| Command | `RscMenu_Command`, IDD `14000` | `Rsc/Dialogs.hpp:1789-1792`; `GUI_Menu_Command.sqf:315-344` | Live/partial. |
| Tactical | `RscMenu_Tactical`, IDD `17000` | `Rsc/Dialogs.hpp:2161-2164`; `GUI_Menu_Tactical.sqf:363-527` | Live, risky. |
| Old upgrade | `RscMenu_Upgrade`, IDD `18000` | `Rsc/Dialogs.hpp:2425-2428`; missing `Client/GUI/GUI_Menu_Upgrade.sqf` | Stale. |
| Service | `RscMenu_Service`, IDD `20000` | `Rsc/Dialogs.hpp:2870-2873`; `GUI_Menu_Service.sqf:195-244` | Live, guard debt. |
| EASA | `RscMenu_EASA`, IDD `23000` | `Rsc/Dialogs.hpp:3209-3212`; `GUI_Menu_EASA.sqf:47-50` | Live; duplicate IDD. |
| Economy | `RscMenu_Economy`, IDD `23000` | `Rsc/Dialogs.hpp:3287-3290`; `GUI_Menu_Economy.sqf:74-150` | Live; duplicate IDD/risky. |
| RHUD/action title | `RscOverlay`, `OptionsAvailable`, both IDD `10200` | `Rsc/Titles.hpp:44-46`, `:164-171`; `Client_UpdateRHUD.sqf:7`, `:91` | Live; duplicate title IDD. |
| Capture/end/build titles | `CaptureBar`, `EndOfGameStats`, `WFBE_ConstructionInterface` | `Rsc/Titles.hpp:126`, `:532`, `:723`; `coin_interface.sqf:29` | Live. |
| WASP scroll actions | Recover HQ, base repair and skill actions | `WASP/actions/AddActions.sqf:15`; `WASP/baserep/viem.sqf:52`; `Client/Module/Skill/Skill_Apply.sqf:14-160` | Mixed live/stale. |

## High-Risk Action Surfaces

| Risk | Evidence | Action |
| --- | --- | --- |
| Client-authoritative player actions | Buy units (`GUI_Menu_BuyUnits.sqf:143-156`), buy gear (`GUI_BuyGearMenu.sqf:418-449`), tactical supports (`GUI_Menu_Tactical.sqf:363-527`), upgrades (`GUI_UpgradeMenu.sqf:135-161`), economy sale (`GUI_Menu_Economy.sqf:104-150`), CoIn (`coin_interface.sqf:672-718`) and WASP HQ repair (`WASP/actions/Action_RepairMHQDepot.sqf:19-28`). | Keep UI as affordance only in future hardening; server should validate funds, cooldowns, ownership, side, distance and effect target. |
| Duplicate display/title IDs | EASA/Economy both use `idd=23000`; `RscOverlay`/`OptionsAvailable` both use `10200`. | Use [UI IDD collision repair](UI-IDD-Collision-Repair) before adding `findDisplay`-based automation or new resources. |
| Visible command task partial | `GUI_Menu_Command.sqf:315-344` exposes task controls while `SetTask` sends are commented. | Hide or restore with server-backed task flow; do not document as working task assignment. |
| Stale upgrade dialog | `RscMenu_Upgrade` points at missing `Client/GUI/GUI_Menu_Upgrade.sqf`; live path is `WFBE_UpgradeMenu`. | Remove or repoint only with UI smoke. |
| Hardcoded UI text | New-player hint (`Init_Client.sqf:958`), HUD tooltips (`Rsc/Dialogs.hpp:1208-1227`), buy-unit/gear hints, artillery ammo hints and WASP `RECOVER HQ`. | Move only in a dedicated localization pass; keep source copy stable during behavior patches. |

## Manual UI Smoke

1. Join a fresh client and confirm the loading blackout clears, briefing appears, side/stack checks complete and the WF menu hint is visible.
2. Open the WF menu through the scroll action and verify main buttons open Buy Units, Gear, Team, Command, Tactical, Upgrade, Economy, Service and Help.
3. Buy one infantry unit and one vehicle from an appropriate factory/depot, then confirm queue cleanup and funds behavior.
4. Buy gear for self and save/delete a template; include profile-template save if testing [Gear template profile filter](Gear-Template-Profile-Filter).
5. Commander smoke: open Command, Economy/CoIn, Upgrade and Tactical; verify partial task controls are either knowingly no-op or patched.
6. Open EASA and Economy in separate flows and check no duplicate-IDD lookup assumptions appear in RPT.
7. Die and respawn from camp/mobile/MASH/leader where available; confirm RHUD and marker overlays recover after respawn.
8. Trigger WASP actions that are live in the current mission; do not revive old commented WASP init/action paths without a separate smoke.

## Continue Reading

Previous: [Client UI/HUD/menus](Client-UI-HUD-And-Menus) | Next: [Client UI systems atlas](Client-UI-Systems-Atlas)

Related: [Feature status](Feature-Status-Register) | [Server authority map](Server-Authority-Migration-Map) | [Testing workflow](Testing-Debugging-And-Release-Workflow)
