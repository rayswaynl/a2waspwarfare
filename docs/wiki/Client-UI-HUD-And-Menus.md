# Client UI, HUD And Menus

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

## Map And Marker UI

Client marker updates are split between:

- `Client/FSM/updatetownmarkers.sqf`
- `Client/FSM/updateteamsmarkers.sqf`
- `Client_BlinkMapIcon`
- `Client_BookkeepBlinkingIcons`
- `Client_SetMapIconStatusInCombat`

The combat icon blinking feature is guarded by `WFBE_C_MAP_ICON_BLINKING_ENABLED`.

## UI Risk Notes

- Avoid heavy work in display loops and map marker refresh.
- Preserve cached-write patterns in RHUD and marker scripts.
- Keep action label changes consistent with localized string usage where available.

