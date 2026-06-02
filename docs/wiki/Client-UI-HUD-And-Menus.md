# Client UI, HUD And Menus

For the implementation-level map of IDDs, `Rsc` resources, controller loops, HUD ownership, marker/action UI and known UI risks, read [Client UI systems atlas](Client-UI-Systems-Atlas).

## UI Triage Hub

Use this page as the quick router for UI work:

| Need | Start here | Then check |
| --- | --- | --- |
| Dialog/controller ownership | [Client UI systems atlas](Client-UI-Systems-Atlas) dialog map | [Feature status](Feature-Status-Register) for stale IDDs/files and authority risks |
| HUD, title resources and overlays | [Client UI systems atlas](Client-UI-Systems-Atlas) title/HUD map | [WASP overlay](WASP-Overlay) for legacy overlay/action wiring |
| Main menu or commander/team menus | `Client/GUI/GUI_Menu.sqf` and owning submenu | [Networking/PV](Networking-And-Public-Variables) for any server request triggered by the UI |
| Gear/EASA/service UI | [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas) | [Economy/towns/supply](Economy-Towns-And-Supply) for funds and spend authority |
| Marker/action visibility or JIP oddities | client marker/action loops below | [Mission lifecycle](Mission-Entrypoints-And-Lifecycle) and [Lifecycle wait-chain](Lifecycle-Wait-Chain) |

Rule of thumb: UI code is usually client-local, but many UI buttons trigger server-side effects through PVF/direct publicVariable paths. A UI change that mutates score, funds, structures, supply, upgrades, support, loadouts or HQ state should be reviewed as a networking/economy change too.

## Compact Dialog Index

| Dialog/resource | IDD | Controller/owner | Source anchor | Status |
| --- | ---: | --- | --- |
| `WF_Menu` | 11000 | `Client/GUI/GUI_Menu.sqf` | `Rsc/Dialogs.hpp:1019`, `GUI_Menu.sqf:33-43` | Main router. |
| `RscMenu_BuyUnits` | 12000 | `Client/GUI/GUI_Menu_BuyUnits.sqf` | `Rsc/Dialogs.hpp:1445-1447`, `GUI_Menu.sqf:33-36` | Live; client-authoritative purchase path risk is documented in [Factory/purchase atlas](Factory-And-Purchase-Systems-Atlas). |
| `RscMenu_Tactical` | 17000 | `Client/GUI/GUI_Menu_Tactical.sqf` | `Rsc/Dialogs.hpp:2161-2163` | Live; includes high-impact support paths such as ICBM. |
| `WFBE_UpgradeMenu` | 504000 | `Client/GUI/GUI_UpgradeMenu.sqf` | `Rsc/Dialogs.hpp:4-6`, `GUI_Menu.sqf:162-165` | Live upgrade UI. |
| `RscMenu_Upgrade` | 18000 | `Client/GUI/GUI_Menu_Upgrade.sqf` | `Rsc/Dialogs.hpp:2425-2427` | Stale legacy class; target controller file is missing. |
| `WFBE_BuyGearMenu` | 503000 | `Client/GUI/GUI_BuyGearMenu.sqf` | `Rsc/Dialogs.hpp:530-532`, `GUI_Menu.sqf:40-43` | Live gear/template UI. |
| `RscMenu_Service` | 20000 | `Client/GUI/GUI_Menu_Service.sqf` | `Rsc/Dialogs.hpp:2870-2872`, `GUI_Menu.sqf:176-179` | Live service/EASA entry; spend validation is client-side. |
| `RscMenu_EASA` | 23000 | `Client/GUI/GUI_Menu_EASA.sqf` | `Rsc/Dialogs.hpp:3209-3211`, `GUI_Menu_Service.sqf:241-244` | Live; shares IDD with economy menu. |
| `RscMenu_Economy` | 23000 | `Client/GUI/GUI_Menu_Economy.sqf` | `Rsc/Dialogs.hpp:3287-3289`, `GUI_Menu.sqf:169-172` | Live; IDD reuse is a maintenance trap. |
| `RscOverlay` / `OptionsAvailable` | 10200 | `Init_Client.sqf`, `Client_UpdateRHUD.sqf`, action FSMs | `Rsc/Titles.hpp:44`, `:164-173`, `Client_UpdateRHUD.sqf:3-7` | Legacy/current overlay resources share an IDD; use stored display handles rather than assuming unique `findDisplay`. |

## UI Resource Layer

`description.ext` includes the `Rsc` stack:

- `Header.hpp`
- `Styles.hpp`
- `Parameters.hpp`
- `Ressources.hpp`
- `Dialogs.hpp`
- `Titles.hpp`
- `Identities.hpp` outside vanilla mode

Dialog scripts then live under `Client/GUI`.

Source anchors: `description.ext:46-58` includes `Rsc/Header.hpp`, `Styles.hpp`, `Parameters.hpp`, `Ressources.hpp`, `Dialogs.hpp` and `Titles.hpp`; `Rsc/Titles.hpp:25` registers `RscOverlay`, `CaptureBar`, `OptionsAvailable` and `EndOfGameStats`.

## Main Menus

Important GUI files:

- `GUI_Menu.sqf`: main Warfare menu and HUD/FPS toggles.
- `GUI_Menu_BuyUnits.sqf`: player unit purchasing list and factory interaction.
- `GUI_BuyGearMenu.sqf`: gear purchase and template UI.
- `GUI_Menu_Command.sqf`: commander/team command controls.
- `GUI_Menu_Tactical.sqf`: tactical actions such as fast travel and support-style commands.
- `GUI_UpgradeMenu.sqf`: upgrades.
- `GUI_RespawnMenu.sqf`: respawn UI.
- `GUI_Menu_EASA.sqf`: aircraft loadout system.
- `GUI_Menu_Service.sqf`: service/repair support.

## Buy Unit Path

Factory purchase flow:

1. UI list is populated from config and current upgrade state.
2. Player selection goes through `GUI_Menu_BuyUnits.sqf`.
3. Spawn logic is handled by `Client_BuildUnit.sqf`.
4. Factory-specific marker conventions determine spawn location.

## Gear Templates

Gear files and UI helpers support profile gear templates:

- `Client_UI_Gear_AddTemplate`
- `Client_UI_Gear_SaveTemplateProfile`
- `Client_UI_Gear_FillTemplates`
- `Client_UI_Gear_UpdatePrice`
- `Client_UI_Gear_UpdateTarget`
- `Init_ProfileGear.sqf`
- `Init_ProfileVariables.sqf`

## RHUD And FPS HUD

`Client_UpdateRHUD.sqf` manages the full resource HUD and lightweight FPS overlay. `GUI_Menu.sqf` toggles `RUBHUD` and `RUBFPSHUD`. The code caches controls/text/colors and uses explicit client/server FPS rows.

Source anchors: `GUI_Menu.sqf:191-199` toggles `RUBHUD` / `RUBFPSHUD`; `Client_UpdateRHUD.sqf:3-7` initializes the flags and cuts `OptionsAvailable`; `Client_UpdateRHUD.sqf:207-208` selects FPS-only vs full HUD mode.

## Map And Marker UI

Client marker updates are split between:

- `Client/FSM/updatetownmarkers.sqf`
- `Client/FSM/updateteamsmarkers.sqf`
- `Client_BlinkMapIcon`
- `Client_BookkeepBlinkingIcons`
- `Client_SetMapIconStatusInCombat`

The combat icon blinking feature is guarded by `WFBE_C_MAP_ICON_BLINKING_ENABLED`.

Respawn selector anchor: `GUI_RespawnMenu.sqf:31,100,193` owns `WFBE_MarkerTracking`; `Client_UI_Respawn_Selector.sqf:19-31` loops while that variable exists and updates the local selector marker. Keep that loop light.

## UI Risk Notes

- Avoid heavy work in display loops and map marker refresh.
- Preserve cached-write patterns in RHUD and marker scripts.
- Keep action label changes consistent with localized string usage where available.
- Use unique dialog IDDs for new menus; this fork already has IDD reuse that future work should not expand.
- UI-originated economy actions are not automatically authoritative. For known risks, see [Deep-review findings](Deep-Review-Findings) DR-16/DR-17/DR-24 for gear/template/cargo behavior and DR-25a/b for EASA/service authority, plus [Client UI systems atlas](Client-UI-Systems-Atlas) for the source map.

## Continue Reading

Previous: [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety) | Next: [Client UI systems atlas](Client-UI-Systems-Atlas)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
