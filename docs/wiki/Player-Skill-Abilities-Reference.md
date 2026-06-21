# Player Skill Abilities Reference

> Source-verified 2026-06-21 against master cf2a6d6a4. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

The Skill module is a client-side player-role layer. Client init compiles `Client\Module\Skill\Skill_Init.sqf`, uses `WFBE_SK_V_Type` to choose the class default gear, then calls `WFBE_SK_FNC_Apply` on the player (`Client/Init/Init_Client.sqf:563-587`). Respawn reapplies skill actions by calling `WFBE_SK_FNC_Apply` on the new unit (`Client/Functions/Client_PreRespawnHandler.sqf:1-5`).

## Runtime Wiring

| Surface | Source behavior | Source |
| --- | --- | --- |
| Skill script root | `WFBE_SK_V_Root` points action scripts at `Client\Module\Skill\Skill_`. | `Client/Module/Skill/Skill_Init.sqf:6-10` |
| Apply function | `WFBE_SK_FNC_Apply` compiles `Client\Module\Skill\Skill_Apply.sqf`. | `Client/Module/Skill/Skill_Init.sqf:9-10` |
| Type detection | `WFBE_SK_V_Type` starts empty, then class membership sets it to `Engineer`, `Soldier`, `SpecOps`, `Spotter` or `Medic`. | `Client/Module/Skill/Skill_Init.sqf:39-45` |
| Initial application | Client init runs `Skill_Init.sqf`, selects class default gear from `WFBE_SK_V_Type`, equips it, then applies skill actions. | `Client/Init/Init_Client.sqf:563-587` |
| Respawn application | The pre-respawn handler calls `WFBE_SK_FNC_Apply` for the replacement unit without rerunning `Skill_Init.sqf`. | `Client/Functions/Client_PreRespawnHandler.sqf:1-5` |
| Default gear mapping | Initial spawn maps `Spotter`, `Officer`, `Soldier`, `Engineer`, `SpecOps` and `Medic` to side-specific default gear variables. | `Client/Init/Init_Client.sqf:567-574` |
| Respawn gear mapping | Respawn uses the same `WFBE_SK_V_Type` gear switch for class default loadouts. | `Client/Functions/Client_OnRespawnHandler.sqf:80-104` |

## Class Groups

| Skill type | Player classnames | Direct type source |
| --- | --- | --- |
| Engineer | `USMC_SoldierS_Engineer`, `CDF_Soldier_Engineer`, `Ins_Soldier_Sapper`, `TK_Soldier_Engineer_EP1`, `Ins_Soldier_CO`, `US_Soldier_Engineer_EP1`, `US_Soldier_Officer_EP1`, `BAF_Soldier_SL_DDPM`, `MVD_Soldier_TL`, `USMC_Soldier_TL`, `TK_Soldier_Officer_EP1` | `Client/Module/Skill/Skill_Init.sqf:13`; `Client/Module/Skill/Skill_Init.sqf:41` |
| Soldier | `CDF_Soldier`, `RUS_Soldier1`, `US_Delta_Force_EP1`, `TK_Special_Forces_EP1`, `FR_Miles`, `FR_R`, `Ins_Soldier_1` | `Client/Module/Skill/Skill_Init.sqf:14`; `Client/Module/Skill/Skill_Init.sqf:42` |
| SpecOps | `FR_TL`, `RUS_Soldier_TL`, `US_Soldier_TL_EP1`, `US_Delta_Force_TL_EP1`, `TK_Special_Forces_TL_EP1`, `CDF_Soldier_TL`, `Ins_Soldier_2`, `GER_Soldier_Scout_EP1`, `RUS_Commander` | `Client/Module/Skill/Skill_Init.sqf:15`; `Client/Module/Skill/Skill_Init.sqf:43` |
| Spotter | `US_Soldier_Sniper_EP1`, `TK_Soldier_Sniper_EP1`, `Ins_Soldier_Sniper`, `CDF_Soldier_Sniper`, `USMC_SoldierS_Sniper`, `RU_Soldier_Sniper` | `Client/Module/Skill/Skill_Init.sqf:16`; `Client/Module/Skill/Skill_Init.sqf:44` |
| Medic | `FR_Corpsman`, `US_Soldier_Medic_EP1`, `TK_Soldier_Medic_EP1`, `RUS_Soldier_Medic`, `GER_Soldier_Medic_EP1`, `BAF_Soldier_Medic_DDPM`, `RU_Soldier_Medic`, `US_Delta_Force_Medic_EP1`, `USMC_Soldier_Medic` | `Client/Module/Skill/Skill_Init.sqf:17`; `Client/Module/Skill/Skill_Init.sqf:45` |
| Officer branch | `Skill_Apply.sqf` still contains an `Officer` case, but `Skill_Init.sqf` does not assign `WFBE_SK_V_Type = "Officer"` in the current initializer. | `Client/Module/Skill/Skill_Init.sqf:39-45`; `Client/Module/Skill/Skill_Apply.sqf:42-45` |

## Cooldowns And Shared State

| Variable | Initial value | Used by | Reload / rule | Source |
| --- | ---: | --- | ---: | --- |
| `WFBE_SK_V_LastUse_Repair` | `-1200` | Engineer repair | 25 seconds | `Client/Module/Skill/Skill_Init.sqf:22-36` |
| `WFBE_SK_V_LastUse_LR` | `-1200` | Fast repair (`Skill_LR.sqf`) | 300 seconds | `Client/Module/Skill/Skill_Init.sqf:22-36` |
| `WFBE_SK_V_LastUse_Lockpick` | `-1200` | Lockpick (`Skill_SpecOps.sqf`) | 5 seconds | `Client/Module/Skill/Skill_Init.sqf:22-36` |
| `WFBE_SK_V_LastUse_Salvage` | `-1200` | Engineer salvage | 10 seconds | `Client/Module/Skill/Skill_Init.sqf:22-36` |
| `WFBE_SK_V_LastUse_Spot` | `-1200` | Spotter marker | 8 seconds | `Client/Module/Skill/Skill_Init.sqf:22-36` |
| `WFBE_SK_V_LastUse_RepairPointEASA` | `-1200` | Engineer repair-truck EASA access | 60 seconds | `Client/Module/Skill/Skill_Init.sqf:22-36` |
| `WFBE_C_PLAYERS_AI_MAX` | default `16`, locally boosted by Soldier to `ceil(1.5 * WFBE_C_PLAYERS_AI_MAX)` | Soldier AI cap | default 16 becomes 24 after one Soldier init | `Common/Init/Init_CommonConstants.sqf:259-260`; `Client/Module/Skill/Skill_Init.sqf:47-49` |

## Applied Actions By Skill Type

| Skill type | Actions applied | Important gates | Action source |
| --- | --- | --- | --- |
| Engineer | Repair vehicle, salvage wrecks, repair destroyed camps. | Repair and salvage use their cooldown variables; camp repair action appears only near a destroyed camp through `WFBE_CL_FNC_CanRepairCampNearby`. | `Client/Module/Skill/Skill_Apply.sqf:12-39`; `Client/Init/Init_Client.sqf:101-104` |
| Soldier | Fast repair and repair destroyed camps. | Fast repair requires a land or air cursor target within 5 m and the 300-second LR cooldown; camp repair uses the destroyed-camp helper. | `Client/Module/Skill/Skill_Apply.sqf:143-157` |
| SpecOps | Load supplies, unload loaded supply helicopters, fast repair. | Load requires the player on foot within 70 m of the closest friendly location and a supply truck, or a supply helicopter when `WFBE_UP_AIR` is at least 3; unload looks for loaded `WFBE_C_SUPPLY_HELI_TYPES`; fast repair uses the 300-second LR cooldown. | `Client/Module/Skill/Skill_Apply.sqf:48-83` |
| Spotter | Spot marker, lockpick, fast repair, repair destroyed camps. | Spot uses the 8-second spot cooldown; lockpick uses the 5-second lockpick cooldown; fast repair uses the 300-second LR cooldown; camp repair uses the destroyed-camp helper. | `Client/Module/Skill/Skill_Apply.sqf:84-121` |
| Medic | Fast repair and repair destroyed camps. | Fast repair uses the same LR action and cooldown; camp repair uses the destroyed-camp helper. | `Client/Module/Skill/Skill_Apply.sqf:125-139` |
| Officer branch | MASH deploy is explicitly removed; the branch keeps only repair destroyed camps. | Current `Skill_Init.sqf` does not assign `Officer`, so treat this as a latent branch in the current initializer. | `Client/Module/Skill/Skill_Init.sqf:39-45`; `Client/Module/Skill/Skill_Apply.sqf:42-45` |

## Action Scripts

| Action | Who gets it | What it does | Source |
| --- | --- | --- | --- |
| Repair | Engineer | Finds the closest `Car`, `Motorcycle`, `Tank`, `Ship`, `Air` or `StaticWeapon` within 5 m, exits if the target is undamaged, plays three repair animation cycles, aborts if the player dies, enters a vehicle, loses the target or moves beyond 5 m, then reduces damage by `0.25`. | `Client/Module/Skill/Skill_Engineer.sqf:7-29` |
| Fast repair / LR | Soldier, SpecOps, Spotter, Medic | Uses the same 5 m target classes as Engineer repair, plays five repair animation cycles, aborts on the same fail states, then reduces damage by `0.08`. | `Client/Module/Skill/Skill_LR.sqf:7-29` |
| Salvage | Engineer | Scans dead `Car`, `Motorcycle`, `Ship`, `Air`, `Tank` and `StaticWeapon` objects within `WFBE_C_UNITS_SALVAGER_SCAVENGE_RANGE`, removes side HQs from the wreck list, uses 250 as the fallback payout when no unit metadata exists, otherwise pays `QUERYUNITPRICE * WFBE_C_UNITS_SALVAGER_SCAVENGE_RATIO / 100`, deletes each salvaged wreck and credits the total to the client. | `Client/Module/Skill/Skill_Salvage.sqf:1-38`; `Common/Init/Init_CommonConstants.sqf:384-388` |
| Spot marker | Spotter | Requires the current weapon to be one of `Laserdesignator`, `Binocular` or `Binocular_Vector`, creates a local red `mil_destroy` marker at screen center with `SPOTTED: <time>`, and deletes it after 180 seconds. | `Client/Module/Skill/Skill_Init.sqf:19-20`; `Client/Module/Skill/Skill_Sniper.sqf:7-29` |
| Lockpick | Spotter | Finds a locked nearby vehicle within 5 m, initializes lockpick chance to `-20` only for `WFBE_SK_V_Type == "SpecOps"` and `0` otherwise, plays four animation cycles, rolls `random 100 - WFBE_SK_V_LockpickChance`, sends `RequestVehicleLock` on success, and improves the chance by decrementing it while it is greater than `-51`. | `Client/Module/Skill/Skill_SpecOps.sqf:7-57`; `Client/Module/Skill/Skill_Apply.sqf:97-107` |
| Repair camp | Engineer, Soldier, Spotter, Medic, latent Officer branch | Finds nearby camp logics inside `WFBE_C_CAMPS_REPAIR_RANGE`, drops undefined camp logics and already-live bunkers, charges `WFBE_C_CAMPS_REPAIR_PRICE` if configured, channels for `WFBE_C_CAMPS_REPAIR_DELAY`, refunds if another repair completed first, then sends `RequestSpecial ["repair-camp", _camp, WFBE_Client_SideID]`. Defaults are 15 seconds, 500 funds and 15 m. | `Client/Action/Action_RepairCampEngineer.sqf:10-67`; `Common/Init/Init_CommonConstants.sqf:145-152`; `Client/Module/Skill/Skill_Apply.sqf:37-45`; `Client/Module/Skill/Skill_Apply.sqf:120-121`; `Client/Module/Skill/Skill_Apply.sqf:138-139`; `Client/Module/Skill/Skill_Apply.sqf:156-157` |
| Load supplies | SpecOps | Shows when the player is on foot, within 70 m of the closest friendly location, the cursor target is not already loaded/loading, and the target is a supply truck or a supply helicopter with Air upgrade level at least 3. | `Client/Module/Skill/Skill_Apply.sqf:49-59`; `Common/Init/Init_CommonConstants.sqf:175-184` |
| Unload supplies | SpecOps | Shows for a loaded supply helicopter in the player's vehicle, cursor target or a nearby 30 m scan of supply helicopter types. | `Client/Module/Skill/Skill_Apply.sqf:61-70`; `Common/Init/Init_CommonConstants.sqf:175-184` |

## Secondary Skill Consumers

| Consumer | Skill dependency | Source |
| --- | --- | --- |
| Town marker labels | When a visible friendly or nearby town has no supply mission cooldown, `SpecOps` sees `SV: current/max [+SUPPLY]`; other skill types see `SV: current/max [+]`. | `Client/FSM/updatetownmarkers.sqf:20-28` |
| Skin selector ghillie filter | The optional Skin Selector treats the `Spotter` skill type as the sniper role for ghillie rows; full class-swap behavior is routed through [Skin selector/class swap](Skin-Selector-And-Class-Swap-Reference). | `Client/Module/Skill/Skill_Init.sqf:16`; `Client/Module/Skill/Skill_Init.sqf:55-60`; `WASP/actions/SkinSelector/SkinSelector_Open.sqf:23-33`; `WASP/actions/SkinSelector/SkinSelector_Open.sqf:56-57` |
| Repair-truck EASA access | The service menu can enable EASA through repair-truck service points when the normal command-service-point gate is unavailable; the helper allows only Engineers driving an EASA vehicle, outside the repair-point cooldown, near a `WFBE_RepairTruckServicePoint`. | `Client/GUI/GUI_Menu_Service.sqf:228-250`; `Client/Functions/Client_CanUseRepairPointEASA.sqf:6-17`; `Client/Functions/Client_GetRepairTruckServicePoints.sqf:6-16` |
| Repair-truck EASA purchase | The EASA menu rechecks the repair-point cooldown and helper, spends the selected loadout cost, then updates `WFBE_SK_V_LastUse_RepairPointEASA` and clears `WFBE_CL_V_RepairPointEASAActive`. | `Client/GUI/GUI_Menu_EASA.sqf:58-82` |
| WASP base repair overlay | Spotter can inspect enemy base structures under cursor within 1000 m and see a local damage-state hint. | `WASP/baserep/viem.sqf:15-30` |

## Current-Source Notes

| Note | Evidence |
| --- | --- |
| The Skill module's class comments are not always the current action truth: the `SpecOps` class comment says lockpick, but the current `SpecOps` apply branch wires supply load/unload plus fast repair and does not add the lockpick action. | `Client/Module/Skill/Skill_Init.sqf:15`; `Client/Module/Skill/Skill_Apply.sqf:48-83`; `Client/Module/Skill/Skill_Apply.sqf:97-107` |
| The lockpick script gives the `-20` initial chance only when `WFBE_SK_V_Type == "SpecOps"`, but the current lockpick action is wired from the Spotter branch. | `Client/Module/Skill/Skill_SpecOps.sqf:10-16`; `Client/Module/Skill/Skill_Apply.sqf:84-107` |
| The older Officer MASH player action should not be documented as live on `master@cf2a6d6a4`: the current `Officer` apply branch says MASH deploy was removed, and the current initializer does not assign the `Officer` type. | `Client/Module/Skill/Skill_Init.sqf:39-45`; `Client/Module/Skill/Skill_Apply.sqf:42-45` |
| Soldier's current Skill-module AI-cap boost is the 1.5x local multiplier; the player constants block also defines `WFBE_C_PLAYERS_SKILL_SOLDIER_UNITS_MAX = 6`, so do not substitute that value for the applied Skill-module formula. | `Client/Module/Skill/Skill_Init.sqf:47-49`; `Common/Init/Init_CommonConstants.sqf:259-280` |

## Continue Reading

- [Modules atlas](Modules-Atlas)
- [Skin selector and class swap](Skin-Selector-And-Class-Swap-Reference)
- [Supply mission architecture](Supply-Mission-Architecture)
- [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas)
- [Respawn and death lifecycle](Respawn-And-Death-Lifecycle-Atlas)
- [Player AI caps and role balance](Player-AI-Caps-And-Role-Balance)
