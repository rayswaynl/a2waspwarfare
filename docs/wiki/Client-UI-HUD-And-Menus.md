# Client UI, HUD And Menus

This is the quick-reference gateway for client UI work. Start with the [player UI workflow map](Player-UI-Workflow-Map) when you need a "what can the player click?" tour. The canonical implementation map is [Client UI systems atlas](Client-UI-Systems-Atlas); update that atlas for detailed dialog tables, title resources, controller loops, marker/action UI and UI risk analysis.

## First Stops

| Need | Start here | Source anchors | Canonical detail |
| --- | --- | --- | --- |
| Main Warfare menu routing | `Client/GUI/GUI_Menu.sqf` | `Rsc/Dialogs.hpp:1019-1022`, `GUI_Menu.sqf:33-43`, `:162-179`, `:191-199` | [Client UI systems atlas](Client-UI-Systems-Atlas) Main Menu Router |
| Buy units / factories | `Client/GUI/GUI_Menu_BuyUnits.sqf` -> `Client/Functions/Client_BuildUnit.sqf` | `Rsc/Dialogs.hpp:1445-1447`, `GUI_Menu_BuyUnits.sqf:89-156` | [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas) |
| Gear, service and EASA | `GUI_BuyGearMenu.sqf`, `GUI_Menu_Service.sqf`, `GUI_Menu_EASA.sqf` | `Rsc/Dialogs.hpp:530-532`, `:2870-2872`, `:3209-3211` | [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas), [service menu affordability guards](Service-Menu-Affordability-Guards) |
| Upgrades and economy menu | `GUI_UpgradeMenu.sqf`, `GUI_Menu_Economy.sqf` | `Rsc/Dialogs.hpp:4-6`, `:3287-3289`, `GUI_UpgradeMenu.sqf:137-171` | [Gameplay systems atlas](Gameplay-Systems-Atlas) and [Economy](Economy-Towns-And-Supply) |
| RHUD / FPS HUD / title resources | `Client/Client_UpdateRHUD.sqf`, `Rsc/Titles.hpp` | `Rsc/Titles.hpp:25`, `:44`, `:164-173`, `:532-540`, `Client_UpdateRHUD.sqf:3-7`, `:89-92`, `:183-190` | [Client UI systems atlas](Client-UI-Systems-Atlas) Title And HUD Resource Map |
| Respawn selector and markers | `GUI_RespawnMenu.sqf`, client marker FSMs | `GUI_RespawnMenu.sqf:31`, `:100`, `:193`, `Client_UI_Respawn_Selector.sqf:19-31` | [Client UI systems atlas](Client-UI-Systems-Atlas) Map And Marker UI |
| UI JIP/headless scope | `initJIPCompatible.sqf`, `Init_Client.sqf`, `Client_UpdateRHUD.sqf` | `initJIPCompatible.sqf:70-76`, `:224-238`, `Init_Client.sqf:730-734`, `Client_UpdateRHUD.sqf:87-95` | [Client UI systems atlas](Client-UI-Systems-Atlas) JIP And Headless-Client Verdict |

## UI Safety Rules

- UI code is usually client-local, but UI actions can still mutate server-visible state through PVF or direct publicVariable paths.
- Treat any UI change that touches score, funds, supply, structures, upgrades, support, loadouts, HQ state or vehicle creation as a networking/economy change too.
- Check [UI IDD collision repair](UI-IDD-Collision-Repair) before adding `findDisplay` or title-display automation; duplicate dialog/title IDs and `currentCutDisplay` reuse are known risks.
- Check [Client UI systems atlas](Client-UI-Systems-Atlas) before touching economy map controls, main-menu GPS routes, help unload state or base clickable controls.
- Check [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas) and [Service menu affordability guards](Service-Menu-Affordability-Guards) before changing EASA, gear, service or spending behavior.
- Keep polling menu loops and marker/HUD loops light; reuse cached display handles and existing update flags.
- Headless clients do not run the UI init path; "HC" calls inside `updateclient.sqf` are high-command player UI controls, not headless-client rendering.
- Late-join UI support exists, but do not call it fully clean without feature smoke: several UI waits depend on synchronized variables with no timeout.

## Known UI Findings

| Finding family | Meaning | Canonical page |
| --- | --- | --- |
| Client-visible indicator inventory | HUD/title resources, map/tactical markers, support markers, menu/list icons, status channels and image references need one owner/audience/update/cleanup matrix before indicator pruning or redesign. | [Client UI systems atlas](Client-UI-Systems-Atlas#indicator-exploration-backlog), [UI resource parity cleanup](UI-Resource-Parity-Cleanup) |
| UI as authority surface | Player buys, structure sale, upgrades, supports, gear/EASA/service and some economy actions are client-originated or client-authoritative. | [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas), [Server authority map](Server-Authority-Migration-Map), [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas) |
| Duplicate/stale display resources | EASA/Economy share dialog ID, overlay/title resources share title ID/display handles, and old upgrade/menu resources remain stale. | [UI IDD collision repair](UI-IDD-Collision-Repair), [Abandoned feature revival](Abandoned-Feature-Revival-Review#old-upgrade-dialog), [Client UI systems atlas](Client-UI-Systems-Atlas) |
| Economy/help/main-menu cleanup | Missing economy controls, stale economy map-click latch, orphan main-menu GPS zoom cases and help unload mismatch are UI correctness debts. | [Client UI systems atlas](Client-UI-Systems-Atlas), [Player UI workflow map](Player-UI-Workflow-Map) |
| Gear/EASA/service partials | EASA unsupported-vehicle fail-open, exact-funds rejection, gear template filtering and service affordability guards are routed to the equipment pages. | [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas), [Service menu affordability guards](Service-Menu-Affordability-Guards), [Gear template profile filter](Gear-Template-Profile-Filter) |
| Command task partial | Commander task controls are visible and the `SetTask` send/receive pipeline is active (send in `GUI_Menu_Command.sqf` lines 336 and 344, receive in `Client/PVFunctions/SetTask.sqf`, registered in `Common/Init/Init_PublicVariables.sqf` line 40). | [Client UI systems atlas](Client-UI-Systems-Atlas), [Player UI workflow map](Player-UI-Workflow-Map) |

## UI Risk Index

Use this as the fast route before touching UI:

| Risk | Go to |
| --- | --- |
| Duplicate dialog/title IDs and title display handles | [UI IDD collision repair](UI-IDD-Collision-Repair) |
| Service affordability and action-time guards | [Service menu affordability guards](Service-Menu-Affordability-Guards) |
| Command task controls / dormant task system | [Client UI systems atlas](Client-UI-Systems-Atlas) |
| Gear/EASA/template/cargo partials | [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas), [Gear template profile filter](Gear-Template-Profile-Filter), [Vehicle cargo equip loop bounds](Vehicle-Cargo-Equip-Loop-Bounds) |
| Stale legacy dialogs | [Abandoned feature revival](Abandoned-Feature-Revival-Review#old-upgrade-dialog), [Feature status](Feature-Status-Register) |

## Continue Reading

Previous: [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety) | Next: [Player UI workflow map](Player-UI-Workflow-Map)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
