# Zeta Cargo Sling-Load Reference

> Source-verified 2026-06-21 against master cf2a6d6a4. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

ZetaCargo is the airlift module labelled "Zeta Cargo by Benny" in its init file and compiled from client init (`Client/Module/ZetaCargo/Zeta_Init.sqf:1`; `Client/Init/Init_Client.sqf:551-552`). The live action grant checks `Zeta_Lifter` plus `WFBE_UP_AIRLIFT`, then adds `Client\Module\ZetaCargo\Zeta_Hook.sqf` as the localized lift action (`Common/Init/Init_Unit.sqf:51-53`). The hook path attaches one nearby unmanned land vehicle to the lifter (`Client/Module/ZetaCargo/Zeta_Hook.sqf:15-17,28,30`), while the manual detach path is currently partial because `Zeta_Hook.sqf` adds the detach action without an argument payload and `Zeta_Unhook.sqf` expects `_this select 3 select 0` to be the lifted vehicle (`Client/Module/ZetaCargo/Zeta_Hook.sqf:34`; `Client/Module/ZetaCargo/Zeta_Unhook.sqf:3-7`).

---

## Boot and Upgrade Gate

| Surface | Current source behavior | Source |
| --- | --- | --- |
| Client init | The client compiles/runs `Client\Module\ZetaCargo\Zeta_Init.sqf` from the Zeta Cargo Lifter block. | `Client/Init/Init_Client.sqf:551-552` |
| Upgrade index | `WFBE_UP_AIRLIFT` is upgrade index `8`. | `Common/Init/Init_CommonConstants.sqf:45` |
| Action grant | During unit initialization, `_unit_kind` must be present in `Zeta_Lifter`, and `_upgrades select WFBE_UP_AIRLIFT` must be greater than `0`, before the unit receives the localized `STR_WF_Lift` addAction to `Client\Module\ZetaCargo\Zeta_Hook.sqf`. | `Common/Init/Init_Unit.sqf:51-53` |
| Purchase-list color | The buy-list filler reads `_UpAirlift` from `WFBE_UP_AIRLIFT` and colors rows only when the unit is also in side-specific `WFBE_%1LIFTVEHICLE`. This is UI marking, not the runtime attach-action gate. | `Client/Functions/Client_UIFillListBuyUnits.sqf:21,78-82`; `Common/Init/Init_Unit.sqf:51-53` |
| Buy-menu hint | The buy menu shows the lift-capable hint for non-supply-heli units found in side-specific `WFBE_%1LIFTVEHICLE`. | `Client/GUI/GUI_Menu_BuyUnits.sqf:486-487` |
| Upgrade label | The upgrade label is localized as `STR_WF_UPGRADE_Airlift`; its description says the upgrade unlocks airlifting. | `Common/Config/Core_Upgrades/Labels_Upgrades.sqf:63,89`; `stringtable.xml:3836-3841,4045-4050` |

## Airlift Upgrade Values

The checked Chernarus core upgrade files use the same Airlift shape: enabled, cost `[[1000,0]]`, one level, dependency `[[WFBE_UP_AIR,1]]`, and research time `[30]`.

| Upgrade family | Enabled | Cost | Levels | Dependency | Time |
| --- | --- | --- | --- | --- | --- |
| CombinedOps US | `true` | `[[1000,0]]` | `1` | `[[WFBE_UP_AIR,1]]` | `[30]` |
| CombinedOps RU | `true` | `[[1000,0]]` | `1` | `[[WFBE_UP_AIR,1]]` | `[30]` |
| Other Chernarus upgrade files | Same Airlift rows and line positions across `Upgrades_CO_GUE.sqf`, `Upgrades_USMC.sqf`, `Upgrades_RU.sqf`, `Upgrades_CDF.sqf`, `Upgrades_GUE.sqf`, `Upgrades_INS.sqf`, `Upgrades_OA_US.sqf`, `Upgrades_OA_TKA.sqf`, and `Upgrades_OA_TKGUE.sqf`. | Same | Same | Same | Same |

Sources: `Common/Config/Core_Upgrades/Upgrades_CO_US.sqf:14,40,67,98,129`; `Common/Config/Core_Upgrades/Upgrades_CO_RU.sqf:14,40,67,98,129`; `Common/Config/Core_Upgrades/Upgrades_CO_GUE.sqf:14,40,67,98,129`; `Common/Config/Core_Upgrades/Upgrades_USMC.sqf:14,40,67,98,129`; `Common/Config/Core_Upgrades/Upgrades_RU.sqf:14,40,67,98,129`; `Common/Config/Core_Upgrades/Upgrades_CDF.sqf:14,40,67,98,129`; `Common/Config/Core_Upgrades/Upgrades_GUE.sqf:14,40,67,98,129`; `Common/Config/Core_Upgrades/Upgrades_INS.sqf:14,40,67,98,129`; `Common/Config/Core_Upgrades/Upgrades_OA_US.sqf:14,40,67,98,129`; `Common/Config/Core_Upgrades/Upgrades_OA_TKA.sqf:14,40,67,98,129`; `Common/Config/Core_Upgrades/Upgrades_OA_TKGUE.sqf:14,40,67,98,129`.

---

## Runtime Lifter Allow-List

`Zeta_Lifter` is the runtime list used by `Init_Unit.sqf` before adding the attach action.

| Classname | Source |
| --- | --- |
| `MH60S` | `Client/Module/ZetaCargo/Zeta_Init.sqf:4` |
| `MV22` | `Client/Module/ZetaCargo/Zeta_Init.sqf:4` |
| `C130J` | `Client/Module/ZetaCargo/Zeta_Init.sqf:4` |
| `Mi17_Ins` | `Client/Module/ZetaCargo/Zeta_Init.sqf:4` |
| `Mi17_medevac_RU` | `Client/Module/ZetaCargo/Zeta_Init.sqf:4` |
| `UH60M_EP1` | `Client/Module/ZetaCargo/Zeta_Init.sqf:4` |
| `UH60M_MEV_EP1` | `Client/Module/ZetaCargo/Zeta_Init.sqf:4` |
| `CH_47F_EP1` | `Client/Module/ZetaCargo/Zeta_Init.sqf:4` |
| `C130J_US_EP1` | `Client/Module/ZetaCargo/Zeta_Init.sqf:4` |
| `Mi17_TK_EP1` | `Client/Module/ZetaCargo/Zeta_Init.sqf:4` |
| `BAF_Merlin_HC3_D` | `Client/Module/ZetaCargo/Zeta_Init.sqf:4` |
| `CH_47F_BAF` | `Client/Module/ZetaCargo/Zeta_Init.sqf:4` |
| `Mi17_Civilian` | `Client/Module/ZetaCargo/Zeta_Init.sqf:4` |
| `An2_TK_EP1` | `Client/Module/ZetaCargo/Zeta_Init.sqf:4` |

## Side UI Lift Lists

Side root files set `WFBE_%1LIFTVEHICLE` lists for UI coloring and buy-menu hints. These lists are narrower than the runtime `Zeta_Lifter` allow-list and are not what `Init_Unit.sqf` checks when adding the attach action.

| Root file | UI-marked lift vehicle classes | Source |
| --- | --- | --- |
| `Root_US.sqf` | `MH60S`, `MV22`, `C130J`, `UH60M_EP1`, `UH60M_MEV_EP1`, `CH_47F_EP1`, `C130J_US_EP1`, `BAF_Merlin_HC3_D`, `CH_47F_BAF`, `Mi17_Civilian` | `Common/Config/Core_Root/Root_US.sqf:23` |
| `Root_US_Camo.sqf` | `MH60S`, `MV22`, `C130J`, `UH60M_EP1`, `UH60M_MEV_EP1`, `CH_47F_EP1`, `C130J_US_EP1`, `BAF_Merlin_HC3_D`, `CH_47F_BAF`, `Mi17_Civilian` | `Common/Config/Core_Root/Root_US_Camo.sqf:23` |
| `Root_USMC.sqf` | `MH60S`, `MV22`, `C130J`, `UH60M_EP1`, `UH60M_MEV_EP1`, `CH_47F_EP1`, `C130J_US_EP1`, `BAF_Merlin_HC3_D`, `CH_47F_BAF`, `Mi17_Civilian` | `Common/Config/Core_Root/Root_USMC.sqf:22` |
| `Root_RU.sqf` | `Mi17_Ins`, `Mi17_medevac_RU`, `Mi17_TK_EP1` | `Common/Config/Core_Root/Root_RU.sqf:21` |
| `Root_TKA.sqf` | `Mi17_Ins`, `Mi17_medevac_RU`, `Mi17_TK_EP1` | `Common/Config/Core_Root/Root_TKA.sqf:21` |

---

## Hook Search and Attach Flow

| Step | Current behavior | Source |
| --- | --- | --- |
| Caller gate | The attach script exits unless the action caller is the driver of the lifter. | `Client/Module/ZetaCargo/Zeta_Hook.sqf:3-9` |
| Speed/altitude gate | `C130J` and `C130J_US_EP1` exit above speed `20`; other lifters exit above speed `20` or below altitude `2`. | `Client/Module/ZetaCargo/Zeta_Hook.sqf:10-13`; `Client/Module/ZetaCargo/Zeta_Init.sqf:11` |
| Target search | The live hook searches `nearObjects ["LandVehicle", 10]` and exits when none are found. | `Client/Module/ZetaCargo/Zeta_Hook.sqf:15-17` |
| Closest target | The nearest searched vehicle is selected through `WFBE_CO_FNC_GetClosestEntity`. | `Client/Module/ZetaCargo/Zeta_Hook.sqf:19` |
| Enemy HQ wreck guard | WEST callers cannot airlift dead EAST HQ wreck classes `BTR90_HQ`, `BMP2_HQ_TK_EP1`, `BMP2_HQ_INS`; EAST callers cannot airlift dead WEST HQ wreck classes `LAV25_HQ`, `M1130_CV_EP1`, `BMP2_HQ_CDF`. | `Client/Module/ZetaCargo/Zeta_Hook.sqf:6-7,21-22` |
| Manned target guard | Any target with crew exits with localized `STR_WF_INFO_Hook_Manned`. | `Client/Module/ZetaCargo/Zeta_Hook.sqf:28`; `stringtable.xml:849-855` |
| Offset selection | Default attach offset is `[0,0,-10]`; `C130J` and `C130J_US_EP1` use special offset `[0,0,-2]`. | `Client/Module/ZetaCargo/Zeta_Init.sqf:8,11-12`; `Client/Module/ZetaCargo/Zeta_Hook.sqf:23-26` |
| Attach and state | The target is attached to the lifter, and the lifter receives local variable `Attached = true`. | `Client/Module/ZetaCargo/Zeta_Hook.sqf:30-31` |
| Action swap | The attach action is removed, then a localized `STR_WF_Lift_Detach` action is added for `Client\Module\ZetaCargo\Zeta_Unhook.sqf`. | `Client/Module/ZetaCargo/Zeta_Hook.sqf:32-34`; `stringtable.xml:4437-4449` |
| Monitor loop | While the game is not over, the hook loop sleeps `2` seconds and detaches automatically if lifter damage is above `0.3`, `Attached` is false, or the lifter no longer has a driver. | `Client/Module/ZetaCargo/Zeta_Hook.sqf:36-43` |

`Zeta_Types` declares `Car`, `Motorcycle`, `Tank`, and `Ship`, but the current hook search above is the `LandVehicle` near-object query. Treat `Zeta_Types` as module configuration, not proof that ships are reachable through the live attach action. Sources: `Client/Module/ZetaCargo/Zeta_Init.sqf:5-6`; `Client/Module/ZetaCargo/Zeta_Hook.sqf:15-17`.

## Detach Path Status

| Path | Current behavior | Source |
| --- | --- | --- |
| Manual detach action | The detach action is added without an argument payload. | `Client/Module/ZetaCargo/Zeta_Hook.sqf:34` |
| Unhook expectation | `Zeta_Unhook.sqf` expects `_this select 3`, then reads `_param select 0` as the lifted vehicle. | `Client/Module/ZetaCargo/Zeta_Unhook.sqf:3-7` |
| Unhook state | If a lifted vehicle is supplied, the script sets `Attached = false`, detaches the vehicle, applies lifter velocity, removes the detach action, waits `1` second, and clamps below-ground drops back to Z `0` with downward velocity `-0.1`. | `Client/Module/ZetaCargo/Zeta_Unhook.sqf:9-20` |
| C-130 drop position | For special lifters, the unhook path moves the lifted vehicle 15 meters behind the lifter's position using `getDir _vehicle`, then keeps the lifter's current Z position. | `Client/Module/ZetaCargo/Zeta_Unhook.sqf:11-13` |
| Automatic detach | The hook loop can still detach without calling `Zeta_Unhook.sqf` when damage, missing driver, or `Attached = false` ends the loop. | `Client/Module/ZetaCargo/Zeta_Hook.sqf:36-43` |

Patch caution: the page documents stable master, not a tested in-game fix. A future code change should either pass `[_vehicle]` when adding the detach action or make `Zeta_Unhook.sqf` recover the attached object safely, then smoke attach/manual-detach/auto-detach for a normal helicopter and a C-130 variant.

## Continue Reading

Module gateway: [Modules atlas](Modules-Atlas) | Support surface: [Support specials and tactical modules](Support-Specials-And-Tactical-Modules-Atlas) | Upgrade catalog: [Upgrade research cross-faction reference](Upgrade-Research-Cross-Faction-Reference) | Gear/cargo caveat: [Vehicle cargo equip loop bounds](Vehicle-Cargo-Equip-Loop-Bounds)
