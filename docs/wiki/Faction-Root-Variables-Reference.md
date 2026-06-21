# Faction Root Variables Reference (per-faction Core_Root config)

> Source-verified 2026-06-21 against then-current master cf2a6d6a4; current origin/master is 0139a346, so recheck cited paths before current-head claims (rayswaynl/a2waspwarfare). Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

Each `Common/Config/Core_Root/Root_<faction>.sqf` file runs once at mission init and writes per-faction runtime variables into `missionNamespace` using the pattern `Format["WFBE_%1<VAR>", _side]`. This page catalogues every variable set, the value each faction assigns, and the execution context in which it is written.

---

## Variable Overview

| Variable pattern | Type | Execution context | Purpose |
|---|---|---|---|
| `WFBE_%1CREW` | String | All machines | Generic crew classname (vehicles spawn with this) |
| `WFBE_%1PILOT` | String | All machines | Generic pilot classname |
| `WFBE_%1SOLDIER` | String | All machines | Generic infantry classname |
| `WFBE_%1FLAG` | String | All machines | Path to flag `.paa` texture |
| `WFBE_%1AMBULANCES` | Array | All machines | Classnames recognised as ambulances (respawn vehicles) |
| `WFBE_%1REPAIRTRUCKS` | Array | All machines | Classnames recognised as repair trucks |
| `WFBE_%1SALVAGETRUCK` | Array | All machines | Classnames recognised as salvage trucks |
| `WFBE_%1SUPPLYTRUCKS` | Array | All machines | Classnames recognised as supply trucks |
| `WFBE_%1UAV` | String | All machines | UAV classname; absent on TKA, GUE, PMC, and TKGUE |
| `WFBE_%1AMMOTRUCKS` | Array | All machines | Ammo re-arm trucks; also gates gear-access in `updateavailableactions.sqf`; absent on CDF, INS, GUE, PMC, and TKGUE |
| `WFBE_%1ECMTRUCKS` | Array | All machines | Refuel trucks; also used for ECM attachment logic; absent on CDF, INS, GUE, PMC, and TKGUE |
| `WFBE_%1LIFTVEHICLE` | Array | All machines | Classnames eligible for sling-load lift; absent on CDF, INS, GUE, PMC, and TKGUE |
| `WFBE_%1ARTYVEHICLE` | Array | All machines | Artillery vehicle classnames; absent on CDF, INS, GUE, PMC, and TKGUE |
| `WFBE_%1_RadioAnnouncers` | Array | All machines | Soldier classnames used as radio announcers |
| `WFBE_%1_RadioAnnouncers_Config` | String | All machines | CfgRadioProtocol class name |
| `WFBE_%1PARACHUTELEVEL1` | Array | All machines | Paratrooper squad composition — Tier 1 |
| `WFBE_%1PARACHUTELEVEL2` | Array | All machines | Paratrooper squad composition — Tier 2 |
| `WFBE_%1PARACHUTELEVEL3` | Array | All machines | Paratrooper squad composition — Tier 3 |
| `WFBE_%1PARACARGO` | String | All machines | Aircraft classname for the paratrooper drop |
| `WFBE_%1REPAIRTRUCK` | String | All machines | Single repair-truck classname (model reference) |
| `WFBE_%1STARTINGVEHICLES` | Array | All machines | Vehicles present at faction HQ at mission start |
| `WFBE_%1PARAAMMO` | Array | All machines | Ammo box classnames dropped by supply paradrop |
| `WFBE_%1PARAVEHICARGO` | String | All machines | Vehicle classname dropped by supply paradrop |
| `WFBE_%1PARAVEHI` | String | All machines | Aircraft classname for supply paradrop delivery |
| `WFBE_%1PARACHUTE` | String | All machines | Parachute classname used for paradrop |
| `WFBE_%1SUPPLYTRUCK` | String | All machines | Single supply-truck classname (model reference) |
| `WFBE_%1_PATROL_LIGHT` | Array of arrays | `isServer` only | Light patrol composition pools |
| `WFBE_%1_PATROL_MEDIUM` | Array of arrays | `isServer` only | Medium patrol composition pools |
| `WFBE_%1_PATROL_HEAVY` | Array of arrays | `isServer` only | Heavy patrol composition pools |
| `WFBE_%1_AI_Loadout_0..3` | Array | `isServer` only | AI weapon loadout sets per upgrade tier (0=base, 3=max) |
| `WFBE_%1DEFAULTFACTION` | String | `local player` only | Buy-menu faction label |
| `WFBE_%1_DefaultGear` | Array | All machines | Player default loadout: `[weapons, magazines, muzzles]` |
| `WFBE_%1_DefaultGearEngineer` | Array | All machines | Engineer player loadout |
| `WFBE_%1_DefaultGearSpot` | Array | All machines | Sniper/spotter player loadout |
| `WFBE_%1_DefaultGearOfficer` | Array | All machines | Officer / MASH player loadout |
| `WFBE_%1_DefaultGearSoldier` | Array | All machines | Soldier player loadout |
| `WFBE_%1_DefaultGearLock` | Array | All machines | LMG / lock player loadout |
| `WFBE_%1_DefaultGearMedic` | Array | All machines | Medic player loadout |

`WFBE_%1MASHES` appears commented out in all Root files — it is latent and never set at runtime.

---

## Service Vehicles by Faction

| Faction | File | `_side` | Ambulances | Repair trucks | Salvage truck | Supply trucks |
|---|---|---|---|---|---|---|
| US (OA) | `Root_US.sqf` | `WEST` | `HMMWV_Ambulance`, `HMMWV_Ambulance_DES_EP1`, `UH60M_MEV_EP1`, `M1133_MEV_EP1` | `MtvrRepair`, `MtvrRepair_DES_EP1` | `WarfareSalvageTruck_USMC`, `MtvrSalvage_DES_EP1` | `WarfareSupplyTruck_USMC`, `MtvrSupply_DES_EP1` |
| US (Chernarus/USMC overlay) | `Root_US_Camo.sqf` | `WEST` | `HMMWV_Ambulance`, `HMMWV_Ambulance_DES_EP1`, `UH60M_MEV_EP1`, `M1133_MEV_EP1` | `MtvrRepair`, `MtvrRepair_DES_EP1` | `WarfareSalvageTruck_USMC`, `MtvrSalvage_DES_EP1` | `WarfareSupplyTruck_USMC`, `MtvrSupply_DES_EP1` |
| USMC | `Root_USMC.sqf` | `WEST` | `HMMWV_Ambulance`, `HMMWV_Ambulance_DES_EP1`, `UH60M_MEV_EP1`, `M1133_MEV_EP1` | `MtvrRepair`, `MtvrRepair_DES_EP1` | `WarfareSalvageTruck_USMC`, `MtvrSalvage_DES_EP1` | `WarfareSupplyTruck_USMC`, `MtvrSupply_DES_EP1` |
| CDF | `Root_CDF.sqf` | `WEST` | `BMP2_Ambul_CDF` | `UralRepair_CDF` | `WarfareSalvageTruck_CDF` | `WarfareSupplyTruck_CDF` |
| Russia | `Root_RU.sqf` | `EAST` | `GAZ_Vodnik_MedEvac`, `M113Ambul_TK_EP1`, `Mi17_medevac_RU`, `M113Ambul_TK_EP1` | `KamazRepair`, `UralRepair_TK_EP1` | `WarfareSalvageTruck_RU`, `UralSalvage_TK_EP1` | `WarfareSupplyTruck_RU`, `UralSupply_TK_EP1` |
| Takistani Army | `Root_TKA.sqf` | `EAST` | `GAZ_Vodnik_MedEvac`, `M113Ambul_TK_EP1`, `Mi17_medevac_RU`, `M113Ambul_TK_EP1` | `KamazRepair`, `UralRepair_TK_EP1` | `WarfareSalvageTruck_RU`, `UralSalvage_TK_EP1` | `WarfareSupplyTruck_RU`, `UralSupply_TK_EP1` |
| Insurgents | `Root_INS.sqf` | `EAST` | `BMP2_Ambul_INS` | `UralRepair_INS` | `WarfareSalvageTruck_INS` | `WarfareSupplyTruck_INS` |
| Guerilla (Chernarus) | `Root_GUE.sqf` | `GUER` | `V3S_TK_GUE_EP1`, `V3S_Gue` | `WarfareRepairTruck_Gue`, `V3S_Repair_TK_GUE_EP1` | `WarfareSalvageTruck_Gue`, `V3S_Salvage_TK_GUE_EP1` | `WarfareSupplyTruck_Gue`, `V3S_Supply_TK_GUE_EP1` |
| PMC | `Root_PMC.sqf` | `GUER` | `V3S_TK_GUE_EP1`, `V3S_Gue` | `WarfareRepairTruck_Gue`, `V3S_Repair_TK_GUE_EP1` | `WarfareSalvageTruck_Gue`, `V3S_Salvage_TK_GUE_EP1` | `WarfareSupplyTruck_Gue`, `V3S_Supply_TK_GUE_EP1` |
| Takistani Guerilla | `Root_TKGUE.sqf` | `GUER` | `V3S_TK_GUE_EP1`, `V3S_Gue` | `WarfareRepairTruck_Gue`, `V3S_Repair_TK_GUE_EP1` | `WarfareSalvageTruck_Gue`, `V3S_Salvage_TK_GUE_EP1` | `WarfareSupplyTruck_Gue`, `V3S_Supply_TK_GUE_EP1` |

Sources: `Root_US.sqf:13-17`, `Root_US_Camo.sqf:14-18`, `Root_USMC.sqf:13-17`, `Root_CDF.sqf:13-17`, `Root_RU.sqf:13-16`, `Root_TKA.sqf:13-17`, `Root_INS.sqf:13-16`, `Root_GUE.sqf:13-17`, `Root_PMC.sqf:13-16`, `Root_TKGUE.sqf:13-16`.

---

## UAV, Lift, and Artillery Vehicles

Only factions that explicitly set these variables are shown. GUE, PMC, and TKGUE omit `WFBE_%1UAV`, `WFBE_%1LIFTVEHICLE`, and `WFBE_%1ARTYVEHICLE` entirely. TKA omits `WFBE_%1UAV` but does set `WFBE_%1LIFTVEHICLE` and `WFBE_%1ARTYVEHICLE`. CDF sets `WFBE_%1UAV` only. INS sets `WFBE_%1UAV` only (`Pchela1T`, `Root_INS.sqf:17`).

| Faction | UAV | Lift vehicles | Artillery vehicles |
|---|---|---|---|
| US (OA) | `MQ9PredatorB_US_EP1` | `MH60S`, `MV22`, `C130J`, `UH60M_EP1`, `UH60M_MEV_EP1`, `CH_47F_EP1`, `C130J_US_EP1`, `BAF_Merlin_HC3_D`, `CH_47F_BAF`, `Mi17_Civilian` | `MLRS_DES_EP1`, `MLRS`, `M1129_MC_EP1` |
| US_Camo | `MQ9PredatorB_US_EP1` | (same as US OA) | `MLRS_DES_EP1`, `MLRS`, `M1129_MC_EP1` |
| USMC | `MQ9PredatorB` | (same as US OA) | `MLRS_DES_EP1`, `MLRS`, `M1129_MC_EP1` |
| CDF | `MQ9PredatorB` | _(not set)_ | _(not set)_ |
| Russia | `Pchela1T` | `Mi17_Ins`, `Mi17_medevac_RU`, `Mi17_TK_EP1` | `GRAD_TK_EP1`, `GRAD_RU` |
| TKA | _(not set)_ | `Mi17_Ins`, `Mi17_medevac_RU`, `Mi17_TK_EP1` | `GRAD_TK_EP1`, `GRAD_RU` |
| INS | `Pchela1T` | _(not set)_ | _(not set)_ |

Sources: `Root_US.sqf:18,23-24`, `Root_US_Camo.sqf:19,23-24`, `Root_USMC.sqf:18,22-23`, `Root_CDF.sqf:18`, `Root_RU.sqf:17,21-22`, `Root_TKA.sqf:21-22`, `Root_INS.sqf:17`.

---

## Paradrop Variables

The supply-paradrop system uses five variables. `WFBE_%1PARAAMMO` for Russia (EAST, `Root_RU.sqf:36`) is never set: on that physical line the `STARTINGVEHICLES` assignment is followed immediately by `//--- Starting Vehicles.` and then the `PARAAMMO` setVariable call — because SQF `//` comments extend to end-of-line, the `PARAAMMO` call sits inside the comment token and is not executed at runtime. The ammo-box values `RUBasicAmmunitionBox`, `RUBasicWeaponsBox`, `RULaunchersBox` appear in the source but are unreachable dead code.

| Faction | File | PARAAMMO (ammo boxes dropped) | PARAVEHICARGO (vehicle dropped) | PARAVEHI (delivery aircraft) | PARACHUTE |
|---|---|---|---|---|---|
| US (OA) | `Root_US.sqf:40-43` | `USBasicAmmunitionBox_EP1`, `USBasicWeapons_EP1`, `USLaunchers_EP1` | `MtvrRepair_DES_EP1` | `CH_47F_EP1` | `ParachuteMediumWest_EP1` |
| US_Camo | `Root_US_Camo.sqf:39-42` | `USBasicAmmunitionBox`, `USBasicWeaponsBox`, `USLaunchersBox` | `MtvrRepair` | `MH60S` | `ParachuteMediumWest` |
| USMC | `Root_USMC.sqf:38-41` | `USBasicAmmunitionBox`, `USBasicWeaponsBox`, `USLaunchersBox` | `MtvrRepair` | `MH60S` | `ParachuteMediumWest` |
| CDF | `Root_CDF.sqf:32-35` | `RUBasicAmmunitionBox`, `RUBasicWeaponsBox`, `RULaunchersBox` | `BRDM2_CDF` | `Mi17_CDF` | `ParachuteMediumWest` |
| Russia | `Root_RU.sqf:36-39` | _(not set — dead code, see note above)_ | `KamazRepair` | `Mi17_Ins` | `ParachuteMediumEast` |
| TKA | `Root_TKA.sqf:38-41` | `TKBasicAmmunitionBox_EP1`, `TKBasicWeapons_EP1`, `TKLaunchers_EP1` | `UralRepair_TK_EP1` | `Mi17_TK_EP1` | `ParachuteMediumEast_EP1` |
| INS | `Root_INS.sqf:31-34` | `RUBasicAmmunitionBox`, `RUBasicWeaponsBox`, `RULaunchersBox` | `BRDM2_INS` | `Mi17_Ins` | `ParachuteMediumEast` |
| GUE | `Root_GUE.sqf:31-34` | `RUBasicAmmunitionBox`, `RUBasicWeaponsBox`, `RULaunchersBox` | `BRDM2_Gue` | `Mi17_Civilian` | `ParachuteC` |
| PMC | `Root_PMC.sqf:30-33` | `TKBasicAmmunitionBox_EP1`, `TKBasicWeapons_EP1`, `TKLaunchers_EP1` | `SUV_PMC` | `Ka60_PMC` | `ParachuteMediumEast_EP1` |
| TKGUE | `Root_TKGUE.sqf:30-33` | `TKBasicAmmunitionBox_EP1`, `TKBasicWeapons_EP1`, `TKLaunchers_EP1` | `BTR40_TK_GUE_EP1` | `UH1H_TK_GUE_EP1` | `ParachuteMediumEast_EP1` |

---

## Paratrooper Squad Compositions

Each faction defines three tiers. Tier 1 is a small assault squad (6 men), Tier 2 is a reinforced squad (8-9), Tier 3 is an elite/heavy squad (12-13). GUE Tier 3 has 12; US OA Tier 3 has 13.

### WEST factions

| Faction | Tier 1 (6) | Tier 3 head classname | Source |
|---|---|---|---|
| US (OA) | `US_Soldier_SL_EP1`, `US_Soldier_LAT_EP1`, `US_Soldier_EP1` x2, `US_Soldier_AR_EP1`, `US_Soldier_Medic_EP1` | `US_Delta_Force_TL_EP1` | `Root_US.sqf:33-35` |
| US_Camo | `USMC_Soldier_SL`, `USMC_Soldier_LAT`, `USMC_Soldier`, `USMC_Soldier2`, `USMC_Soldier_AR`, `USMC_Soldier_Medic` | `FR_Assault_R` | `Root_US_Camo.sqf:32-34` |
| USMC | `USMC_Soldier_SL`, `USMC_Soldier_LAT`, `USMC_Soldier`, `USMC_Soldier2`, `USMC_Soldier_AR`, `USMC_Soldier_Medic` | `FR_Assault_R` | `Root_USMC.sqf:31-33` |
| CDF | `CDF_Soldier_TL`, `CDF_Soldier_RPG`, `CDF_Soldier` x2, `CDF_Soldier_AR`, `CDF_Soldier_Medic` | `CDF_Soldier_TL` | `Root_CDF.sqf:25-27` |

### EAST factions

| Faction | Tier 1 (6) | Tier 3 head classname | Source |
|---|---|---|---|
| Russia | `RU_Soldier_SL`, `RU_Soldier_LAT`, `RU_Soldier`, `RU_Soldier2`, `RU_Soldier_AR`, `RU_Soldier_Medic` | `MVD_Soldier_TL` | `Root_RU.sqf:30-32` |
| TKA | `TK_Soldier_SL_EP1`, `TK_Soldier_LAT_EP1`, `TK_Soldier_EP1`, `TK_Soldier_LAT_EP1`, `TK_Soldier_AR_EP1`, `TK_Soldier_Medic_EP1` | `TK_Special_Forces_TL_EP1` | `Root_TKA.sqf:31-33` |
| INS | `USMC_Soldier_SL`, `USMC_Soldier_LAT`, `USMC_Soldier`, `USMC_Soldier2`, `USMC_Soldier_AR`, `USMC_Soldier_Medic` | `FR_Assault_R` | `Root_INS.sqf:24-26` |

Note: INS paratrooper classnames are USMC soldiers, not Insurgent classnames. This appears to be a copy-paste oversight in the source — the Insurgents use USMC classnames for their paratrooper squads while their paracargo vehicle (`Mi17_Ins`) and parachute (`ParachuteMediumEast`) remain East-faction. Source: `Root_INS.sqf:24-26`.

### GUER factions

| Faction | Tier 1 (6) | Tier 3 head classname | Source |
|---|---|---|---|
| GUE | `GUE_Soldier_CO`, `GUE_Soldier_AT`, `GUE_Soldier_2`, `GUE_Soldier_3`, `GUE_Soldier_AR`, `GUE_Soldier_Medic` | `GUE_Soldier_CO` | `Root_GUE.sqf:24-26` |
| PMC | `Soldier_TL_PMC`, `Soldier_AT_PMC`, `Soldier_Bodyguard_M4_PMC`, `Soldier_AT_PMC`, `Soldier_MG_PKM_PMC`, `Soldier_Medic_PMC` | `Soldier_TL_PMC` | `Root_PMC.sqf:23-25` |
| TKGUE | `TK_GUE_Warlord_EP1`, `TK_GUE_Soldier_AT_EP1`, `TK_GUE_Soldier_EP1`, `TK_GUE_Soldier_AT_EP1`, `TK_GUE_Soldier_AR_EP1`, `TK_GUE_Bonesetter_EP1` | `TK_GUE_Warlord_EP1` | `Root_TKGUE.sqf:23-25` |

---

## Starting Vehicles

The two-element array placed at each faction's HQ at mission start. Source lines: `Root_US.sqf:39`, `Root_US_Camo.sqf:38`, `Root_USMC.sqf:37`, `Root_CDF.sqf:31`, `Root_RU.sqf:36`, `Root_TKA.sqf:37`, `Root_INS.sqf:30`, `Root_GUE.sqf:30`, `Root_PMC.sqf:29`, `Root_TKGUE.sqf:29`.

| Faction | Starting vehicles |
|---|---|
| US (OA) | `HMMWV_Ambulance_DES_EP1`, `Pandur2_ACR` |
| US_Camo | `HMMWV_Ambulance`, `Pandur2_ACR` |
| USMC | `HMMWV_Ambulance`, `Pandur2_ACR` |
| CDF | `BMP2_Ambul_CDF`, `BTR90` |
| Russia | `GAZ_Vodnik_MedEvac`, `BTR90` |
| TKA | `GAZ_Vodnik_MedEvac`, `BTR90` |
| INS | `BMP2_Ambul_INS`, `BTR90` |
| GUE | `TT650_Gue`, `BTR90`, `Offroad_DSHKM_Gue` (3 vehicles) |
| PMC | `V3S_TK_GUE_EP1`, `Offroad_DSHKM_TK_GUE_EP1` |
| TKGUE | `V3S_TK_GUE_EP1`, `Offroad_DSHKM_TK_GUE_EP1` |

---

## Radio Announcers

| Faction | Announcer classnames | Config class | Source |
|---|---|---|---|
| US (OA) | `WFHQ_EN0_EP1` .. `WFHQ_EN5_EP1` (5 announcers, skips EN3) | `RadioProtocol_EP1_EN` | `Root_US.sqf:29-30` |
| US_Camo | `WFHQ_EN0_EP1` .. `WFHQ_EN5_EP1` (5 announcers) | `RadioProtocol_EP1_EN` | `Root_US_Camo.sqf:28-29` |
| USMC | `WFHQ_EN0` .. `WFHQ_EN2` (3 announcers) | `RadioProtocolEN` | `Root_USMC.sqf:27-28` |
| CDF | `WFHQ_RU0` .. `WFHQ_RU2` (3 announcers) | `RadioProtocolRU` | `Root_CDF.sqf:21-22` |
| Russia | `WFHQ_RU0` .. `WFHQ_RU2` (3 announcers) | `RadioProtocolRU` | `Root_RU.sqf:26-27` |
| TKA | `WFHQ_TK0_EP1` .. `WFHQ_TK4_EP1` (5 announcers) | `RadioProtocol_EP1_TK` | `Root_TKA.sqf:27-28` |
| INS | `WFHQ_CZ0` .. `WFHQ_CZ2` (3 announcers) | `RadioProtocolCZ` | `Root_INS.sqf:20-21` |
| GUE | `WFHQ_CZ0` .. `WFHQ_CZ2` (3 announcers) | `RadioProtocolCZ` | `Root_GUE.sqf:20-21` |
| PMC | `WFHQ_EN0_EP1` .. `WFHQ_EN5_EP1` (5 announcers) | `RadioProtocol_EP1_EN` | `Root_PMC.sqf:19-20` |
| TKGUE | `WFHQ_TK0_EP1` .. `WFHQ_TK4_EP1` (5 announcers) | `RadioProtocol_EP1_TK` | `Root_TKGUE.sqf:19-20` |

---

## AI Loadout Tiers (server-only)

Each faction defines four AI loadout tiers (`_AI_Loadout_0` through `_AI_Loadout_3`). Each tier is an array of 1-3 loadout variants; the runtime picks one at random. The format is `[[weapons_array, magazines_array, muzzles_array], ...]`.

### Primary weapon summary per tier

| Faction | Tier 0 (no NVG) | Tier 1 (NVG) | Tier 2 | Tier 3 (top) | Source |
|---|---|---|---|---|---|
| US (OA) | `SCAR_L_CQC` / `G36C_camo` | `M4A3_CCO_EP1` / `G36K_camo` / `M14_EP1` | `SCAR_L_STD_HOLO` / `G36C_camo` | `SCAR_L_CQC_EGLM_Holo` / `SCAR_H_STD_EGLM_Spect`+Javelin | `Root_US.sqf:69-103` |
| US_Camo | `SCAR_L_CQC` / `G36C_camo` | `M4A3_CCO_EP1` / `G36K_camo` / `M14_EP1` | `SCAR_L_STD_HOLO` / `G36C_camo` | `SCAR_L_CQC_EGLM_Holo` / `SCAR_H_STD_EGLM_Spect`+Javelin | `Root_US_Camo.sqf:68-102` |
| USMC | `m16a4_acg` / `G36C` | `M4A1_Aim_camo` / `G36K` / `DMR` | `M4A1_Aim_camo` / `G36C` + SMAW | `M4A1_HWS_GL` / `M4A1_HWS_GL_camo`+Javelin | `Root_USMC.sqf:67-101` |
| CDF | `AKS_74_kobra` / `AKS_74_U` | `AKS_74_kobra` x2 / `SVD` | `AKS_74_pso` x2 | `AK_74_GL` / `AK_74_GL`+Makarov | `Root_CDF.sqf:61-95` |
| Russia | `AK_107_kobra` / `AKS_74_U` | `AK_107_kobra` x2 / `SVD` | `AK_107_pso` x2 | `AK_107_GL_pso` / `AK_107_GL_pso`+MetisLauncher | `Root_RU.sqf:65-99` |
| TKA | `AKS_74_kobra` / `AKS_74_U` | `AKS_74_kobra` x2 / `SVD` | `AKS_74_pso` x2 | `AK_74_GL_kobra` / `AK_74_GL_kobra`+MetisLauncher | `Root_TKA.sqf:67-101` |
| INS | `AKS_74_kobra` / `AKS_74_U` | `AKS_74_kobra` x2 / `SVD` | `AKS_74_pso` x2 | `AK_74_GL` / `AK_74_GL`+Makarov | `Root_INS.sqf:60-94` |
| GUE | `AKS_74_kobra` / `AKS_74_U` | `AKS_74_kobra` x2 / `SVD` | `AKS_74_pso` x2 | `AK_74_GL` x2 | `Root_GUE.sqf:54-88` |
| PMC | `AKS_74_kobra` | `m8_carbine_pmc` / `m8_compact_pmc` | `m8_sharpshooter` | `m8_carbineGL` / `m8_carbineGL`+`M47Launcher_EP1` | `Root_PMC.sqf:58-83` |
| TKGUE | `AKS_74_kobra` / `AKS_74_U` | `AKS_74_kobra` x2 / `SVD` | `AKS_74_pso` x2 | `AK_74_GL_kobra` / `AK_74_GL_kobra`+MetisLauncher | `Root_TKGUE.sqf:54-88` |

---

## File Selection and Execution Notes

Root files are not included automatically. The map initialisation selects one Root file per side based on the active faction configuration. `Root_US_Camo.sqf` carries the comment `/* This config file is used with IS_chernarus_map_dependent, required CO */` (`Root_US_Camo.sqf:1`) indicating it is the Chernarus-specific US variant and requires Combined Operations. Both it and `Root_USMC.sqf` share the `WEST` side variable slot, so only one can be active per mission.

`Root_PMC.sqf` and `Root_GUE.sqf` both write to `GUER` side variables. PMC replaces GUE when PMC faction is active; they cannot coexist.

The `WFBE_%1DEFAULTFACTION` variable (buy-menu label) is gated to `local player` and is therefore never set on headless clients or the server. All other variables above the `if (isServer)` block are global and are present on every machine.

---

## Continue Reading

- [Faction-Unit-And-Vehicle-Roster-Catalog](Faction-Unit-And-Vehicle-Roster-Catalog) — full classname roster and vehicle tables per faction
- [Supply-Mission-Architecture](Supply-Mission-Architecture) — how `WFBE_%1PARAAMMO`, `WFBE_%1PARAVEHI`, and the paradrop pipeline are consumed at runtime
- [Gear-Loadout-And-EASA-Atlas](Gear-Loadout-And-EASA-Atlas) — how `WFBE_%1_DefaultGear` and its role variants are applied to players
- [Variable-And-Naming-Conventions](Variable-And-Naming-Conventions) — the `WFBE_%1` pattern, side tokens, and namespace conventions used across the codebase
- [Support-Specials-And-Tactical-Modules-Atlas](Support-Specials-And-Tactical-Modules-Atlas) — paratrooper and supply-drop module mechanics that consume the PARACHUTE/PARAVEHI variables
