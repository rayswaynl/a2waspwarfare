# Default Gear Template Content Catalog

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

This page catalogs the shipped **Template** tab seed content for the buy-gear menu. It is not a weapon-price catalog and it is not the player profile-template bug tracker; the weapon and magazine registries live in the loadout files plus `Config_Weapons.sqf` / `Config_Magazines.sqf`, while the profile-template defects stay on [Gear template profile filter](Gear-Template-Profile-Filter) (`Common/Config/readme.txt:34-42`).

The important source fact: current master ships one empty predefined template row in every `Common/Config/Loadout/Loadout_*.sqf` file. There are no prebuilt rifleman, AT, sniper, medic or backpack kit templates in the checked Chernarus source; the complete loadout-file table below cites all ten seed blocks (`Common/Config/Loadout/Loadout_BAF.sqf:83-86`; `Common/Config/Loadout/Loadout_CDF.sqf:80-82`; `Common/Config/Loadout/Loadout_GUE.sqf:80-83`; `Common/Config/Loadout/Loadout_INS.sqf:80-83`; `Common/Config/Loadout/Loadout_PMC.sqf:152-155`; `Common/Config/Loadout/Loadout_RU.sqf:113-116`; `Common/Config/Loadout/Loadout_TKA.sqf:135-138`; `Common/Config/Loadout/Loadout_TKGUE.sqf:118-121`; `Common/Config/Loadout/Loadout_US.sqf:139-142`; `Common/Config/Loadout/Loadout_USMC.sqf:106-110`).

## Runtime Shape

| Runtime step | Source-backed behavior |
| --- | --- |
| Loadout files define Template-tab seed arrays. | The config readme says loadout files define gear-menu loadouts and templates, and `Config_SetTemplates.sqf` consumes those template arrays (`Common/Config/readme.txt:34-42`). |
| Only one template block per side is used by default. | `_skiponexist` defaults to `true`, and the compiler exits if `WFBE_%1_Template` already exists (`Common/Config/Config_SetTemplates.sqf:11-17`). |
| The compiler initializes each template with no picture, no label, price `0`, and upgrade level `0`. | `_u_picture`, `_u_label`, `_u_price`, and `_u_upgrade` are initialized before item scans (`Common/Config/Config_SetTemplates.sqf:25-31`). |
| The stored template layout is `[picture, label, price, upgrade, weapons, magazines, backpackContent]`. | Fields `0` through `6` are written in that order (`Common/Config/Config_SetTemplates.sqf:113-119`). |
| The template array is stored as `WFBE_%SIDE_Template`. | New arrays are set or existing arrays are appended at the end of `Config_SetTemplates.sqf` (`Common/Config/Config_SetTemplates.sqf:128-132`). |
| The buy-gear menu reads `WFBE_%SIDE_Template` when the selected tab is `Template`. | `GUI_BuyGearMenu.sqf` defines the tab labels and fills tab `0` from `WFBE_%1_Template` (`Client/GUI/GUI_BuyGearMenu.sqf:8-12,122-130`). |
| Visible template rows are gated by current Gear upgrade level. | `Client_UI_Gear_FillTemplates.sqf` reads side upgrades and displays a template only when stored field `3` is `<= WFBE_UP_GEAR` (`Client/Functions/Client_UI_Gear_FillTemplates.sqf:12-22`). |
| Selecting a template loads stored weapons, magazine/count pairs and backpack content. | The menu reads fields `4`, `5`, and `6`; magazine/count pairs are expanded by `Client_UI_Gear_ParseTemplateContent.sqf` (`Client/GUI/GUI_BuyGearMenu.sqf:296-310`; `Client/Functions/Client_UI_Gear_ParseTemplateContent.sqf:10-17`). |

## Chernarus Route

`WF_A2_CombinedOps` starts false and is set true only when the `COMBINEDOPS` macro is defined (`initJIPCompatible.sqf:105-108`). `IS_chernarus_map_dependent` follows the `IS_CHERNARUS_MAP_DEPENDENT` macro (`initJIPCompatible.sqf:115-117`). In that Chernarus Combined Operations branch, faction arrays select WEST index `2` (`USMC`), EAST index `1` (`RU`) and GUER index `0` (`GUE`) (`Common/Init/Init_CommonConstants.sqf:613-621`). Those indices are resolved into `_grpWest`, `_grpEast`, and `_grpRes`; the imported roots on Chernarus are `_grpRes` for resistance, `_team_west = 'US_Camo'`, and `_team_east = 'RU'` (`Common/Init/Init_Common.sqf:265-302`).

| Side route | Root and loadout calls | Template effect |
| --- | --- | --- |
| WEST gear menu route | `Init_Common.sqf` uses `_team_west = 'US_Camo'` on Chernarus, then imports `Root_US_Camo.sqf` (`Common/Init/Init_Common.sqf:265-267,299-302`). `Root_US_Camo.sqf` calls `Loadout_US.sqf`, `Loadout_USMC.sqf`, then `Loadout_BAF.sqf` on local clients (`Common/Config/Core_Root/Root_US_Camo.sqf:129-137`). | `Loadout_US.sqf` is first and sets the empty template seed; later USMC/BAF template blocks hit the default skip-on-existing path unless called with the third `false` parameter (`Common/Config/Loadout/Loadout_US.sqf:139-142`; `Common/Config/Config_SetTemplates.sqf:11-17`; `Common/Config/readme.txt:40-42`). |
| EAST gear menu route | `Init_Common.sqf` uses `_team_east = 'RU'` on Chernarus and imports that root (`Common/Init/Init_Common.sqf:265-267,299-302`). `Root_RU.sqf` calls `Loadout_RU.sqf`, then `Loadout_TKA.sqf` when `WF_A2_CombinedOps` is true (`Common/Config/Core_Root/Root_RU.sqf:126-135`). | `Loadout_RU.sqf` is first and sets the empty template seed; the optional TKA block is also an empty seed and is skipped by default after RU creates `WFBE_%SIDE_Template` (`Common/Config/Loadout/Loadout_RU.sqf:113-116`; `Common/Config/Loadout/Loadout_TKA.sqf:135-138`; `Common/Config/Config_SetTemplates.sqf:11-17`). |
| GUER/resistance gear menu route | `Init_Common.sqf` resolves `_grpRes` from the GUER faction array and imports `Root_GUE.sqf` for Chernarus (`Common/Init/Init_CommonConstants.sqf:613-621`; `Common/Init/Init_Common.sqf:273-302`). `Root_GUE.sqf` calls `Loadout_GUE.sqf`, then `Loadout_TKGUE.sqf` when `WF_A2_CombinedOps` is true (`Common/Config/Core_Root/Root_GUE.sqf:116-126`). | `Loadout_GUE.sqf` is first and sets the empty template seed; the optional TKGUE block is also an empty seed and is skipped by default after GUE creates `WFBE_%SIDE_Template` (`Common/Config/Loadout/Loadout_GUE.sqf:80-83`; `Common/Config/Loadout/Loadout_TKGUE.sqf:118-121`; `Common/Config/Config_SetTemplates.sqf:11-17`). |

## Loadout File Template Seeds

Each row below is the complete predefined template content for that loadout file. `[[[],[[],[]]]]` means: an empty weapon array, an empty magazine classname array and an empty magazine-count array. Because no third element is supplied, `Config_SetTemplates.sqf` defaults backpack content to `[]` (`Common/Config/Config_SetTemplates.sqf:21-23`).

| Loadout file | Template seed | Compiler call | Source |
| --- | --- | --- | --- |
| `Loadout_BAF.sqf` | `[[[],[[],[]]]]` | `[_u, _side] Call Compile preprocessFile "Common\Config\Config_SetTemplates.sqf"` | `Common/Config/Loadout/Loadout_BAF.sqf:83-86` |
| `Loadout_CDF.sqf` | `[[[],[[],[]]]]` | `[_u, _side] Call Compile preprocessFile "Common\Config\Config_SetTemplates.sqf"` | `Common/Config/Loadout/Loadout_CDF.sqf:80-82` |
| `Loadout_GUE.sqf` | `[[[],[[],[]]]]` | `[_u, _side] Call Compile preprocessFile "Common\Config\Config_SetTemplates.sqf"` | `Common/Config/Loadout/Loadout_GUE.sqf:80-83` |
| `Loadout_INS.sqf` | `[[[],[[],[]]]]` | `[_u, _side] Call Compile preprocessFile "Common\Config\Config_SetTemplates.sqf"` | `Common/Config/Loadout/Loadout_INS.sqf:80-83` |
| `Loadout_PMC.sqf` | `[[[],[[],[]]]]` | `[_u, _side] Call Compile preprocessFile "Common\Config\Config_SetTemplates.sqf"` | `Common/Config/Loadout/Loadout_PMC.sqf:152-155` |
| `Loadout_RU.sqf` | `[[[],[[],[]]]]` | `[_u, _side] Call Compile preprocessFile "Common\Config\Config_SetTemplates.sqf"` | `Common/Config/Loadout/Loadout_RU.sqf:113-116` |
| `Loadout_TKA.sqf` | `[[[],[[],[]]]]` | `[_u, _side] Call Compile preprocessFile "Common\Config\Config_SetTemplates.sqf"` | `Common/Config/Loadout/Loadout_TKA.sqf:135-138` |
| `Loadout_TKGUE.sqf` | `[[[],[[],[]]]]` | `[_u, _side] Call Compile preprocessFile "Common\Config\Config_SetTemplates.sqf"` | `Common/Config/Loadout/Loadout_TKGUE.sqf:118-121` |
| `Loadout_US.sqf` | `[[[],[[],[]]]]` | `[_u, _side] Call Compile preprocessFile "Common\Config\Config_SetTemplates.sqf"` | `Common/Config/Loadout/Loadout_US.sqf:139-142` |
| `Loadout_USMC.sqf` | `[[[],[[],[]]]]` | `[_u, _side] Call Compile preprocessFile "Common\Config\Config_SetTemplates.sqf"` | `Common/Config/Loadout/Loadout_USMC.sqf:106-110` |

## Derived Empty Template

For the shipped seed rows above, the compiler sees no weapons, no magazines and no backpack element. The resulting predefined template therefore remains:

| Stored field | Derived value | Source |
| --- | --- | --- |
| `0` picture | `""` | `Common/Config/Config_SetTemplates.sqf:29,113` |
| `1` label | `""` | `Common/Config/Config_SetTemplates.sqf:28,114` |
| `2` price | `0` | `Common/Config/Config_SetTemplates.sqf:27,115` |
| `3` upgrade level | `0` | `Common/Config/Config_SetTemplates.sqf:26,116` |
| `4` weapons | `[]` | Seed rows in all loadout files; compiler writes `_u_weap` to field `4` (`Common/Config/Config_SetTemplates.sqf:21,117`). |
| `5` magazines/counts | `[[],[]]` | Seed rows in all loadout files; compiler writes `[_mags,_counts]` to field `5` (`Common/Config/Config_SetTemplates.sqf:22,54-73,118`). |
| `6` backpack content | `[]` | No seed row supplies a third element, so `_u_back` defaults to `[]` and field `6` stores `_u_back` (`Common/Config/Config_SetTemplates.sqf:23,119`). |

This means the default Template tab can have a visible zero-cost blank row if its empty label is rendered, because the list row formats field `2` as price text and field `1` as the visible label (`Client/Functions/Client_UI_Gear_FillTemplates.sqf:17-18`). Meaningful player-created templates are added later by the UI path and saved through profile logic (`Client/GUI/GUI_BuyGearMenu.sqf:469-524`; `Client/Functions/Client_UI_Gear_AddTemplate.sqf:145-147`; `Client/Functions/Client_UI_Gear_SaveTemplateProfile.sqf:9,103-104`).

## Do Not Confuse With

| Surface | What it is | Source |
| --- | --- | --- |
| Gear item catalog | Weapon, magazine and backpack class pools used by the buy-gear menu. | `Common/Config/readme.txt:34-39`; `Common/Config/Config_Weapons.sqf:34-42`; `Common/Config/Config_Magazines.sqf:24-32`; `Common/Config/Config_Backpack.sqf:24-65` |
| Soldier default gear | Default spawn/AI role loadout records under `WFBE_%SIDE_DefaultGear` and `WFBE_%SIDE_AI_Loadout_*`. | `Common/Config/Core_Root/Root_US_Camo.sqf:92-126`, `Common/Config/Core_Root/Root_US_Camo.sqf:140-145`; `Common/Config/Core_Root/Root_RU.sqf:89-123`, `Common/Config/Core_Root/Root_RU.sqf:138-143`; `Common/Config/Core_Root/Root_GUE.sqf:79-113`, `Common/Config/Core_Root/Root_GUE.sqf:135-139` |
| Player-created templates | Runtime templates created from the current gear selection and saved to profile namespace. | `Client/GUI/GUI_BuyGearMenu.sqf:469-524`; `Client/Functions/Client_UI_Gear_AddTemplate.sqf:145-147`; `Client/Functions/Client_UI_Gear_SaveTemplateProfile.sqf:9,103-104` |

## Continue Reading

- [Gear, loadout and EASA atlas](Gear-Loadout-And-EASA-Atlas)
- [Gear template profile filter](Gear-Template-Profile-Filter)
- [Player UI workflow map](Player-UI-Workflow-Map)
- [Faction unit and vehicle roster catalog](Faction-Unit-And-Vehicle-Roster-Catalog)
