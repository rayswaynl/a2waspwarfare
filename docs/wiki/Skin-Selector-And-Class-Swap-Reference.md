# Skin Selector And Class Swap Reference

> Source-backed on 2026-06-21 from stable master 0139a346, Arma 2 OA 1.64; source mission: Missions/[55-2hc]warfarev2_073v48co.chernarus.

The Skin Selector is an optional infantry class-swap UI, not a normal gear dialog. Current master ships the dialog, class pools and apply chain, but the global gate defaults off and the WF-menu shortcut is hidden in the footer resource (`Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:601`; `Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Dialogs.hpp:1258`). Treat it as source-present but disabled unless `WFBE_C_SKIN_SELECTOR` is deliberately enabled and smoked in Arma 2 OA.

## Current Source State

| Area | Source-backed behavior | Evidence |
| --- | --- | --- |
| Feature gate | `WFBE_C_SKIN_SELECTOR` defaults to `0`; the adjacent vehicle-markings gate explicitly says infantry skin selector is separate. | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:601-602` |
| WF menu exposure | The WF menu resource keeps the Skin Selector footer shortcut at `show = 0`, while the menu controller still has a `MenuAction == 21` branch that opens it if the gate is enabled and the player is alive/on foot. | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Dialogs.hpp:1258-1266`; `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_Menu.sqf:211-215` |
| Join-time opener | The Skill module opens the selector once after join only when `WFBE_C_SKIN_SELECTOR == 1` and `WFBE_SkinSelector_ShownOnJoin` is still false. | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Module/Skill/Skill_Init.sqf:75-77` |
| Hotkey opener | `Client/Init/Init_Keybind.sqf` binds `User11`; the handler opens the selector only when enabled, alive, on foot and no dialog is open. | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Init/Init_Keybind.sqf:1-14` |
| Maintained Vanilla | The maintained Vanilla Takistan root has the same default-off gate, menu hide, opener, apply and respawn persistence shape. | `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Init/Init_CommonConstants.sqf:601-602`; `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Rsc/Dialogs.hpp:1258`; `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Module/Skill/Skill_Init.sqf:75-77`; `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/WASP/actions/SkinSelector/SkinSelector_Apply.sqf:251-253` |

## Dialog And Entry Points

| Surface | What it owns | Evidence |
| --- | --- | --- |
| Dialog resource | `WFBE_SkinSelectorMenu` is dialog `idd = 27000`, with `onLoad` routed to `Client\GUI\GUI_SkinSelectorMenu.sqf`. | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Dialogs.hpp:3273-3277` |
| Dialog controls | The resource defines header `27008`, list `27001`, portrait `27002`, skin label `27003`, faction label `27004`, ghillie note `27005`, Apply and Skip buttons. | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Dialogs.hpp:3313-3416` |
| onLoad shim | The GUI shim stores the display as `WFBE_Display_SkinSelector` and sets the localized title; the controller loop is in `SkinSelector_Open.sqf`. | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_SkinSelectorMenu.sqf:1-10` |
| Open guard | `SkinSelector_Open.sqf` exits unless the feature is enabled, the player is alive, the player is on foot and no dialog is already open. | `Missions/[55-2hc]warfarev2_073v48co.chernarus/WASP/actions/SkinSelector/SkinSelector_Open.sqf:17-20` |
| List population | The opener calls `SkinSelector_Data.sqf`, filters ghillie rows for non-Spotters, exits with a hint if no rows survive, creates dialog `27000`, then fills list `27001`. | `Missions/[55-2hc]warfarev2_073v48co.chernarus/WASP/actions/SkinSelector/SkinSelector_Open.sqf:22-53` |
| Preview loop | While the dialog is open, the loop reads the selected class, resolves portrait from unit registry or config, sets the label/faction controls, runs Apply through `SkinSelector_Apply.sqf`, and closes on Skip. | `Missions/[55-2hc]warfarev2_073v48co.chernarus/WASP/actions/SkinSelector/SkinSelector_Open.sqf:65-107` |

## Skin Pools

`SkinSelector_Data.sqf` returns `[classname, displayLabel, isGhillie]` rows for the player's group side; empty labels are resolved through unit registry/config at runtime, and rows whose class is absent from `CfgVehicles` are dropped (`Missions/[55-2hc]warfarev2_073v48co.chernarus/WASP/actions/SkinSelector/SkinSelector_Data.sqf:1-8`; `Missions/[55-2hc]warfarev2_073v48co.chernarus/WASP/actions/SkinSelector/SkinSelector_Data.sqf:69-95`).

| Side | Candidate rows before `isClass` filter | Ghillie-only rows | Evidence |
| --- | --- | --- | --- |
| WEST | `USMC_Soldier`, `USMC_Soldier_TL`, `USMC_SoldierS`, `USMC_Soldier_MG`, `USMC_Soldier_GL`, `USMC_Soldier_Medic`, `USMC_SoldierS_Engineer`, `US_Soldier_EP1`, `BAF_Soldier_MTP`, `BAF_Soldier_SL_MTP`, `CZ_Soldier_DES_EP1`, `US_Soldier_MG_EP1`, `US_Soldier_TL_EP1`, `FR_Corpsman`, `FR_GL`, `mks_w_multicam`, `mks_w_ranger`, `mks_w_coyote`, `USMC_SoldierS_Sniper`, `USMC_SoldierS_SniperH`. | `USMC_SoldierS_Sniper`, `USMC_SoldierS_SniperH`. | `Missions/[55-2hc]warfarev2_073v48co.chernarus/WASP/actions/SkinSelector/SkinSelector_Data.sqf:16-40` |
| EAST | `RU_Soldier`, `RU_Soldier_TL`, `RU_Soldier_AR`, `RU_Soldier_MG`, `RU_Soldier_GL`, `RU_Soldier_Medic`, `CDF_Soldier`, `CDF_Soldier_TL`, `CDF_Soldier_Light`, `Ins_Soldier_1`, `Ins_Soldier_2`, `MVD_Soldier_TL`, `TK_Soldier_EP1`, `TK_Soldier_SL_EP1`, `mks_e_gorka`, `mks_e_spetsnaz`, `RU_Soldier_Sniper`, `RU_Soldier_SniperH`. | `RU_Soldier_Sniper`, `RU_Soldier_SniperH`. | `Missions/[55-2hc]warfarev2_073v48co.chernarus/WASP/actions/SkinSelector/SkinSelector_Data.sqf:43-66` |

Ghillie rows are tied to the Skill module's sniper role string, `Spotter`: the role array is `WFBE_SK_V_Spotters`, the initializer maps matching player classes to `WFBE_SK_V_Type = "Spotter"`, and the opener hides ghillie entries unless that type is current (`Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Module/Skill/Skill_Init.sqf:16`; `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Module/Skill/Skill_Init.sqf:55-60`; `Missions/[55-2hc]warfarev2_073v48co.chernarus/WASP/actions/SkinSelector/SkinSelector_Open.sqf:23-33`; `Missions/[55-2hc]warfarev2_073v48co.chernarus/WASP/actions/SkinSelector/SkinSelector_Open.sqf:56-57`).

## Apply Lifecycle

| Phase | Source-backed behavior | Evidence |
| --- | --- | --- |
| Preflight | Apply exits when the player is not on foot, the selected class is absent from `CfgVehicles`, the player is dead, or a previous apply is already in progress. | `Missions/[55-2hc]warfarev2_073v48co.chernarus/WASP/actions/SkinSelector/SkinSelector_Apply.sqf:35-66` |
| Capture | The script captures old group, position, direction, rank, gear and leader status; comments document that A2 OA cannot read/apply the same face/speaker/name path used by newer engines. | `Missions/[55-2hc]warfarev2_073v48co.chernarus/WASP/actions/SkinSelector/SkinSelector_Apply.sqf:68-93` |
| Gear snapshot | `SkinSelector_CopyGear.sqf` captures primary, secondary, handgun, magazines and backpack content; `SkinSelector_ApplyGear.sqf` clears weapons, restores weapons/magazines/backpack cargo and selects the primary weapon. | `Missions/[55-2hc]warfarev2_073v48co.chernarus/WASP/actions/SkinSelector/SkinSelector_CopyGear.sqf:1-30`; `Missions/[55-2hc]warfarev2_073v48co.chernarus/WASP/actions/SkinSelector/SkinSelector_ApplyGear.sqf:1-57` |
| Replacement unit creation | Apply creates a fresh local swap group, tags it, then calls `WFBE_CO_FNC_CreateUnit` with `_global=false`; `Common_CreateUnit.sqf` creates a fallback local group for non-local leaders and only runs `setVehicleInit` / `processInitCommands` inside its `_global` branch. | `Missions/[55-2hc]warfarev2_073v48co.chernarus/WASP/actions/SkinSelector/SkinSelector_Apply.sqf:85-115`; `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_CreateUnit.sqf:35-36`; `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_CreateUnit.sqf:49`; `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_CreateUnit.sqf:98-109` |
| Transfer | The new unit receives position, direction, rank, captured gear and AFK variables, rejoins the original group, then `selectPlayer` moves the player into the replacement body. | `Missions/[55-2hc]warfarev2_073v48co.chernarus/WASP/actions/SkinSelector/SkinSelector_Apply.sqf:121-157` |
| Cleanup | If the player was leader, the script restores group leadership, deletes the empty swap group, hides/disables/sinks the old unit, waits, deletes it and spawns a second delete check if needed. | `Missions/[55-2hc]warfarev2_073v48co.chernarus/WASP/actions/SkinSelector/SkinSelector_Apply.sqf:159-204` |
| Client handler restore | The replacement player receives Killed, HandleDamage and Fired handlers, WF menu action, Skill actions, player-AI actions, WASP `AddActions.sqf`, class variable and the `User11` key handler. | `Missions/[55-2hc]warfarev2_073v48co.chernarus/WASP/actions/SkinSelector/SkinSelector_Apply.sqf:207-238` |
| Commander build action | If the player's group is `commanderTeam`, the script restores the HQ build action after the swap. | `Missions/[55-2hc]warfarev2_073v48co.chernarus/WASP/actions/SkinSelector/SkinSelector_Apply.sqf:240-247` |
| Persistence | The selected class is saved as `WFBE_SkinSelector_Skin_<uid>`, `WFBE_SkinSelector_Applied` is set true, and the in-progress guard is released. | `Missions/[55-2hc]warfarev2_073v48co.chernarus/WASP/actions/SkinSelector/SkinSelector_Apply.sqf:249-257` |

## Respawn Persistence

The respawn handler re-applies the saved skin only when the feature is enabled and `WFBE_SkinSelector_Applied` is true. It looks up `WFBE_SkinSelector_Skin_<uid>`, stores it on the new unit as `WFBE_SkinSelector_PendingRespawnSkin`, waits briefly, then calls `SkinSelector_Apply.sqf` again only if the class is present, the unit is alive and the player is on foot (`Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_OnRespawnHandler.sqf:130-146`).

## Maintenance Notes

| When changing this system | Check first | Evidence |
| --- | --- | --- |
| Enabling the feature | Smoke join-time open, hidden WF-menu route if made visible, `User11`, Apply, Skip, death during dialog and on-foot-only guards. | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Module/Skill/Skill_Init.sqf:75-77`; `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_Menu.sqf:211-215`; `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Init/Init_Keybind.sqf:1-14`; `Missions/[55-2hc]warfarev2_073v48co.chernarus/WASP/actions/SkinSelector/SkinSelector_Open.sqf:17-20` |
| Editing the class pools | Keep the `isClass` filter and runtime label fallback; otherwise DLC/addon rows can become config errors or blank UI labels. | `Missions/[55-2hc]warfarev2_073v48co.chernarus/WASP/actions/SkinSelector/SkinSelector_Data.sqf:69-95` |
| Editing role restrictions | Do not rename the ghillie role from `Spotter` without updating the Skill module, the skin opener and every docs route that treats Spotter as the sniper role. | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Module/Skill/Skill_Init.sqf:16`; `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Module/Skill/Skill_Init.sqf:55-60`; `Missions/[55-2hc]warfarev2_073v48co.chernarus/WASP/actions/SkinSelector/SkinSelector_Open.sqf:23-33` |
| Editing apply/respawn | Re-check handler/action restoration and the saved UID skin path; a successful swap replaces the local player object and must rebuild action surfaces. | `Missions/[55-2hc]warfarev2_073v48co.chernarus/WASP/actions/SkinSelector/SkinSelector_Apply.sqf:207-257`; `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_OnRespawnHandler.sqf:130-146` |

## Continue Reading

- [Player UI workflow map](Player-UI-Workflow-Map)
- [Player skill abilities](Player-Skill-Abilities-Reference)
- [Respawn and death lifecycle](Respawn-And-Death-Lifecycle-Atlas)
- [WASP overlay](WASP-Overlay)
- [Client UI systems atlas](Client-UI-Systems-Atlas)
