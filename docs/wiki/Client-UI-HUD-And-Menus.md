# Client UI, HUD And Menus

This is the quick-reference gateway for client UI work. The canonical implementation map is [Client UI systems atlas](Client-UI-Systems-Atlas); update that atlas for detailed dialog tables, title resources, controller loops, marker/action UI and UI risk analysis.

## First Stops

| Need | Start here | Source anchors | Canonical detail |
| --- | --- | --- | --- |
| Main Warfare menu routing | `Client/GUI/GUI_Menu.sqf` | `Rsc/Dialogs.hpp:1019`, `GUI_Menu.sqf:33-43`, `:162-179`, `:191-199` | [Client UI systems atlas](Client-UI-Systems-Atlas) Main Menu Router |
| Buy units / factories | `Client/GUI/GUI_Menu_BuyUnits.sqf` -> `Client/Functions/Client_BuildUnit.sqf` | `Rsc/Dialogs.hpp:1445-1447`, `GUI_Menu_BuyUnits.sqf:89-156` | [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas) |
| Gear, service and EASA | `GUI_BuyGearMenu.sqf`, `GUI_Menu_Service.sqf`, `GUI_Menu_EASA.sqf` | `Rsc/Dialogs.hpp:530-532`, `:2870-2872`, `:3209-3211` | [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas) |
| Upgrades and economy menu | `GUI_UpgradeMenu.sqf`, `GUI_Menu_Economy.sqf` | `Rsc/Dialogs.hpp:4-6`, `:3287-3289`, `GUI_UpgradeMenu.sqf:137-171` | [Gameplay systems atlas](Gameplay-Systems-Atlas) and [Economy](Economy-Towns-And-Supply) |
| RHUD / FPS HUD / title resources | `Client/Client_UpdateRHUD.sqf`, `Rsc/Titles.hpp` | `Rsc/Titles.hpp:25`, `:44`, `:164-173`, `Client_UpdateRHUD.sqf:3-7`, `:207-208` | [Client UI systems atlas](Client-UI-Systems-Atlas) Title And HUD Resource Map |
| Respawn selector and markers | `GUI_RespawnMenu.sqf`, client marker FSMs | `GUI_RespawnMenu.sqf:31`, `:100`, `:193`, `Client_UI_Respawn_Selector.sqf:19-31` | [Client UI systems atlas](Client-UI-Systems-Atlas) Map And Marker UI |

## UI Safety Rules

- UI code is usually client-local, but UI actions can still mutate server-visible state through PVF or direct publicVariable paths.
- Treat any UI change that touches score, funds, supply, structures, upgrades, support, loadouts, HQ state or vehicle creation as a networking/economy change too.
- Do not assume dialog IDs are unique: `RscMenu_EASA` and `RscMenu_Economy` share `idd = 23000`, and `RscOverlay` / `OptionsAvailable` both use `idd = 10200`.
- Keep polling menu loops and marker/HUD loops light; reuse cached display handles and existing update flags.

## Known UI Findings

| Finding | Meaning | Canonical page |
| --- | --- | --- |
| DR-14 | Player unit purchase is client-authoritative; no `RequestBuyUnit` PVF exists. | [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas) |
| DR-16 / DR-17 / DR-24 | Gear/template/cargo and stale UI behavior need careful source checks. | [Deep-review findings](Deep-Review-Findings) |
| DR-25a/b | EASA and service spend/loadout paths are UI-originated authority risks. | [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas) |
| Duplicate IDDs | EASA/Economy share `23000`; overlay/title resources share `10200`. | [Client UI systems atlas](Client-UI-Systems-Atlas) |
| Command task partial | Commander task controls are visible, but the `SetTask` send path is commented out. | [Client UI systems atlas](Client-UI-Systems-Atlas) |

## UI Risk Index

Use this as the fast route before touching UI:

| Risk | Go to |
| --- | --- |
| Duplicate dialog/title IDs | [UI IDD collision repair](UI-IDD-Collision-Repair) |
| Service affordability and action-time guards | [Service menu affordability guards](Service-Menu-Affordability-Guards) |
| Command task controls / dormant task system | [Client UI systems atlas](Client-UI-Systems-Atlas) |
| Gear/EASA/template/cargo partials | [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas), [Gear template profile filter](Gear-Template-Profile-Filter), [Vehicle cargo equip loop bounds](Vehicle-Cargo-Equip-Loop-Bounds) |
| Stale legacy dialogs | [Deep-review findings](Deep-Review-Findings) DR-24 and [Feature status](Feature-Status-Register) |

## Continue Reading

Previous: [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety) | Next: [Client UI systems atlas](Client-UI-Systems-Atlas)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
