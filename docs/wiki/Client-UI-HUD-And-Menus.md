# Client UI, HUD And Menus

## UI Resource Layer

`description.ext:46-62` includes the `Rsc` stack:

- `Header.hpp`
- `Styles.hpp`
- `Parameters.hpp`
- `Ressources.hpp`
- `Dialogs.hpp`
- `Titles.hpp`
- `Identities.hpp` outside vanilla mode

Dialog definitions in `Rsc/Dialogs.hpp` then launch scripts under `Client/GUI` through `onLoad` handlers.

## Main Menus

Important GUI files:

- `GUI_Menu.sqf`: main Warfare menu and HUD/FPS toggles (`Rsc/Dialogs.hpp:1025`, `GUI_Menu.sqf:193-199`).
- `GUI_Menu_BuyUnits.sqf`: player unit purchasing list and factory interaction (`Rsc/Dialogs.hpp:1445-1448`).
- `GUI_BuyGearMenu.sqf`: gear purchase and template UI (`Rsc/Dialogs.hpp:533`).
- `GUI_Menu_Command.sqf`: commander/team command controls (`Rsc/Dialogs.hpp:1789-1792`).
- `GUI_Menu_Tactical.sqf`: tactical actions such as fast travel and support-style commands (`Rsc/Dialogs.hpp:2161-2164`).
- `GUI_UpgradeMenu.sqf`: upgrades (`Rsc/Dialogs.hpp:7`; dead duplicate `RscMenu_Upgrade` is tracked below).
- `GUI_RespawnMenu.sqf`: respawn UI (`Rsc/Dialogs.hpp:317`).
- `GUI_Menu_EASA.sqf`: aircraft loadout system (`Rsc/Dialogs.hpp:3209-3212`).
- `GUI_Menu_Service.sqf`: service/repair support (`Rsc/Dialogs.hpp:2870-2873`).

## Buy Unit Path

Factory purchase flow:

1. UI list is populated from config and current upgrade state.
2. Player selection goes through `GUI_Menu_BuyUnits.sqf`.
3. Spawn logic is handled by `Client_BuildUnit.sqf`.
4. Factory-specific marker conventions determine spawn location.

This is the UI-facing source path for DR-14: `GUI_Menu_BuyUnits.sqf:102` reads local funds, `:155` spawns `BuildUnit`, and `:156` debits player funds locally. Keep the full economy-class synthesis in [Economy](Economy-Towns-And-Supply#authority-model) and the redesign sequencing in [Economy authority first cut](Economy-Authority-First-Cut).

## Gear Templates

Gear files and UI helpers support profile gear templates:

- `Client_UI_Gear_AddTemplate` (`Client/Init/Init_Client.sqf:116`)
- `Client_UI_Gear_SaveTemplateProfile` (`Client/Init/Init_Client.sqf:171`)
- `Client_UI_Gear_FillTemplates` (`Client/Init/Init_Client.sqf:121`)
- `Client_UI_Gear_UpdatePrice` (`Client/Init/Init_Client.sqf:124`)
- `Client_UI_Gear_UpdateTarget` (`Client/Init/Init_Client.sqf:125`)
- `Init_ProfileGear.sqf` (`Client/Init/Init_ProfileVariables.sqf:41`)
- `Init_ProfileVariables.sqf` (`Client/Init/Init_Client.sqf:172`)

## Gear, EASA And Service Authority

Gear/EASA/service screens are active UI and keep the UI source anchors here: EASA local funds/equip/debit at `Client/GUI/GUI_Menu_EASA.sqf:40-49`; service affordability/actions at `Client/GUI/GUI_Menu_Service.sqf:130-145`, `:198-201`, `:209-212`, `:219-222` and `:230-233`. Treat these as UI affordances; the authority class lives in [Economy](Economy-Towns-And-Supply#authority-model), [Economy authority first cut](Economy-Authority-First-Cut) and DR-28.

## Confirmed UI Defects

- Structure selling is the UI-side DR-16 source path from `Client/GUI/GUI_Menu_Economy.sqf:105-128`; see [Economy](Economy-Towns-And-Supply#authority-model) for the broader class.
- `RscMenu_EASA` and `RscMenu_Economy` both use dialog IDD `23000` (`Rsc/Dialogs.hpp:3211`, `:3289`); see DR-17.
- `RscMenu_Upgrade` starts at `Rsc/Dialogs.hpp:2425` and points at the missing `Client/GUI/GUI_Menu_Upgrade.sqf`; see DR-24.
- `Rsc/Titles.hpp:165` duplicates title IDD `10200`, and `Rsc/Ressources.hpp:556` has a malformed `RscClickableText.soundPush[]`; see DR-25a/b.

## RHUD And FPS HUD

`Client/Init/Init_Client.sqf:332-339` initializes `RUBHUD` / `RUBFPSHUD` and starts `Client/Client_UpdateRHUD.sqf`. `GUI_Menu.sqf:193-199` toggles those flags. `Client_UpdateRHUD.sqf:113` reads `SERVER_FPS_GUI`, `:207-208` chooses FPS-only vs full HUD mode, and `:201` / `:369` records performance audit rows.

## Map And Marker UI

Client marker updates are split between:

- `Client/FSM/updatetownmarkers.sqf` (`Client/Init/Init_Client.sqf:366`, audit row at `updatetownmarkers.sqf:121`)
- `Client/FSM/updateteamsmarkers.sqf` (`Client/Init/Init_Client.sqf:356`, audit row at `updateteamsmarkers.sqf:220`)
- `Client_BlinkMapIcon` (`Client/Init/Init_Client.sqf:139`)
- `Client_BookkeepBlinkingIcons` (`Client/Init/Init_Client.sqf:781`)
- `Client_SetMapIconStatusInCombat` (`Client/Init/Init_Client.sqf:137`)

The combat icon blinking feature is guarded by `WFBE_C_MAP_ICON_BLINKING_ENABLED` in `Client/Init/Init_Client.sqf:20`, `:780-781`, `Client_BookkeepBlinkingIcons.sqf:6`, and `Client_SetMapIconStatusInCombat.sqf:8`.

## UI Risk Notes

- Avoid heavy work in display loops and map marker refresh.
- Preserve cached-write patterns in RHUD and marker scripts.
- Keep action label changes consistent with localized string usage where available.

