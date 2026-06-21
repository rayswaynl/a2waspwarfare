# Faction Unit and Vehicle Roster Catalog

> Source-verified 2026-06-21 against then-current master cf2a6d6a4; current origin/master is 0139a346, so recheck cited paths before current-head claims. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

Each faction is initialized by a `Core_<ID>.sqf` file under `Common/Config/Core/`. That file builds two parallel arrays, `_c` (class names) and `_i` (metadata arrays), then calls `missionNamespace setVariable [_c select _z, _i select _z]` for every valid class (`Common/Config/Core/Core_US.sqf:287-308`). The metadata array layout is:

```
[displayName, picture, cost, buildTime, crewSlots, upgradeLevel, factory, isInfantry, factionTag, extraSlots]
```

- **cost** — purchase price in currency units.
- **buildTime** — factory build time in seconds (infantry values are skill tiers: 4–7).
- **crewSlots** — `-1` for infantry (single unit), `-2` triggers a config lookup via `Common_GetConfigVehicleCrewSlot.sqf` to fill in actual seat count at init.
- **upgradeLevel** — minimum research level required (0 = no gate). See [Upgrades-And-Research-Atlas](Upgrades-And-Research-Atlas) for level definitions.
- **factory** — pool selector: `0` = Barracks/infantry, `1` = Light Vehicles, `2` = Heavy Vehicles, `3` = Air/Helicopter. Defense and fortification entries use string tags (`'Defense'`, `'Fortification'`, `'Strategic'`, `'Ammo'`).
- **isInfantry** — `1` for `Man` class, `0` for vehicles.
- **factionTag** — string used for UI grouping and side identification.

The factory pool arrays — which control what appears in each purchase menu tab — are set separately by the `Units_CO_<ID>.sqf` files in `Common/Config/Core_Units/`. Those arrays use the same class names but only list what is available in each store tab (Barracks, Light, Heavy, Aircraft, Airport, Depot).

---

## Data array field summary

| Index | Field | Infantry example | Vehicle example |
|-------|-------|-----------------|-----------------|
| 0 | displayName | `''` (auto-filled) | `'AH-64D (Hellfire)'` |
| 1 | picture | filled at init | filled at init |
| 2 | cost | `130` | `300` |
| 3 | buildTime / skill | `4` | `15` |
| 4 | crewSlots | `-1` | `-2` (auto) or explicit |
| 5 | upgradeLevel | `0` | `3` |
| 6 | factory | `0` | `1` / `2` / `3` |
| 7 | isInfantry | `1` | `0` |
| 8 | factionTag | `'US'` | `'USMC'` |
| 9 | extraSlots | `[]` | `[]` or `[[0]]` |

Source: `Common/Config/Core/Core_US.sqf:9` (first infantry entry; the same layout is used by every `_i` literal in the file). Lines 287-308 of `Core_US.sqf` are the init loop that consumes these arrays, not the field definitions.

---

## WFBE_C_UNITS_BALANCING flag

Several top-tier vehicle prices change when `WFBE_C_UNITS_BALANCING > 0`. Affected entries:

| Class | Balancing OFF | Balancing ON | Source |
|-------|--------------|-------------|--------|
| `M2A2_EP1` | 3800 | 2800 | `Core_US.sqf:166` |
| `Ka52` | 75000 | 41880 | `Core_RU.sqf:138` |
| `Ka52Black` | 75000 | 46800 | `Core_RU.sqf:141` |

The `WF_A2_Vanilla` flag alters upgrade-level gates for `M1A1`, `M1A2_TUSK_MG` (USMC) and `BMP3`, `T72_RU`, `T90` (RU). See `Core_USMC.sqf:131,137` and `Core_RU.sqf:107,110,113`.

---

## Map-conditional class variants (IS_chernarus_map_dependent)

The US and RU factory pool arrays have two branches gated by `IS_chernarus_map_dependent`. This macro is `true` when the mission is running on the Chernarus map and `false` for Takistan. The switch point is the Barracks/Light/Heavy/Airport pool, not the Core pricing table.

**US faction (Units_CO_US.sqf:5-221)**

| Pool | Chernarus | Takistan |
|------|-----------|----------|
| Barracks | USMC + FR + BAF (MTP camo) soldiers | US_*_EP1 + Delta Force + BAF (DDPM camo) soldiers |
| Light | USMC HMMWVs, MTVRs, Strikers, BAF Jackal/Offroad, ACR Dingos | Desert HMMWVs (`_DES_EP1`), ACR Dingos (DST), BAF Offroad/Jackal (Desert) |
| Heavy | AAV, M2A2/M2A3, M1A1, MLRS, M1A2_TUSK, M6_EP1 (if not air-war), BAF_FV510 (W/D) | Same pattern with desert variants |
| Aircraft | Shared list (no map branch) — MH6J, MH60S, UH60M, UH60M_MEV, CH_47F_EP1, CH_47F_BAF, MV22, C130J_US_EP1, BAF_Merlin, AH6J, UH1Y, AW159_Lynx, Mi24_D_CZ_ACR, AH64D, AH64D_EP1, BAF_Apache, AH1Z, L159_ACR, A10, A10_US_EP1, AV8B, AV8B2, F35B | Same |
| Airport | MV22, C130J_US_EP1, L159_ACR, A10/A10_US_EP1, AV8B/AV8B2, F35B | Same |
| Depot | Civilian vehicles + optional town-purchase soldiers (USMC camo on Chernarus, US desert on Takistan) | Same pattern |

Source: `Common/Config/Core_Units/Units_CO_US.sqf:5-350`.

**RU faction (Units_CO_RU.sqf:7-308)**

| Pool | Chernarus | Takistan |
|------|-----------|----------|
| Barracks | RU_Soldier family + MVD + RUS_Soldier + TK_Soldier_Engineer_EP1 | TK_Soldier family + MVD AT/Dragon + TK_Special_Forces |
| Light | UAZ/Kamaz family + GAZ Vodnik + BRDM + BTR90 + GRAD_RU | UAZ/Ural TK family + BRDM TK + BTR60 + GRAD_TK_EP1 |
| Heavy | M113_TK + BMP2_INS + BVP1_TK_ACR + BMP3 + ZSU_INS + T34/T55/T72_RU + T90 + 2S6M_Tunguska | Same with BMP2_TK + ZSU_TK + T72_TK |
| Aircraft | Mi-8 family + Mi24 family + Ka52/Ka52Black + An2 + L39 + Su25/Su39/Su34 (+ Mi17_Ins on Cher / Mi17_TK on Tak) | Same |
| Airport | Mi17_Ins (Cher) or Mi17_TK (Tak) + An2 + L39 + Su25/Su39/Su34 (+ ibrPRACS_MiG21mol if IS_mod_map_dependent) | Same |

Source: `Common/Config/Core_Units/Units_CO_RU.sqf:7-308`.

---

## Faction Rosters

### US (Takistan map, Operation Arrowhead DLC)

File: `Common/Config/Core/Core_US.sqf`. Faction tag: `'US'`.

#### Infantry

| Class | Cost | Skill | Upgrade req | Notes |
|-------|------|-------|-------------|-------|
| `US_Soldier_Light_EP1` | 130 | 4 | 0 | `Core_US.sqf:8-9` |
| `US_Soldier_EP1` | 150 | 4 | 0 | `Core_US.sqf:11-12` |
| `US_Soldier_B_EP1` | 155 | 4 | 0 | `Core_US.sqf:14-15` |
| `US_Soldier_LAT_EP1` | 225 | 5 | 0 | `Core_US.sqf:17-18` |
| `US_Soldier_AT_EP1` | 350 | 5 | 2 | `Core_US.sqf:20-21` |
| `US_Soldier_HAT_EP1` | 1050 | 6 | 3 | `Core_US.sqf:23-24` |
| `US_Soldier_AA_EP1` | 400 | 6 | 2 | `Core_US.sqf:26-27` |
| `US_Soldier_AR_EP1` | 210 | 5 | 1 | `Core_US.sqf:29-30` |
| `US_Soldier_MG_EP1` | 220 | 5 | 1 | `Core_US.sqf:32-33` |
| `US_Soldier_GL_EP1` | 160 | 5 | 0 | `Core_US.sqf:35-36` |
| `US_Soldier_Sniper_EP1` | 320 | 6 | 2 | `Core_US.sqf:38-39` |
| `US_Soldier_SniperH_EP1` | 350 | 6 | 3 | `Core_US.sqf:41-42` |
| `US_Soldier_Sniper_NV_EP1` | 370 | 6 | 3 | `Core_US.sqf:44-45` |
| `US_Soldier_Marksman_EP1` | 330 | 6 | 2 | `Core_US.sqf:47-48` |
| `US_Soldier_Medic_EP1` | 190 | 4 | 0 | `Core_US.sqf:50-51` |
| `US_Soldier_Engineer_EP1` | 225 | 5 | 1 | `Core_US.sqf:53-54` |
| `US_Soldier_AMG_EP1` | 185 | 6 | 2 | `Core_US.sqf:56-57` |
| `US_Soldier_AAR_EP1` | 185 | 6 | 3 | `Core_US.sqf:59-60` |
| `US_Soldier_AHAT_EP1` | 185 | 6 | 3 | `Core_US.sqf:62-63` |
| `US_Soldier_AAT_EP1` | 320 | 6 | 3 | `Core_US.sqf:65-66` |
| `US_Soldier_Spotter_EP1` | 320 | 6 | 3 | `Core_US.sqf:68-69` |
| `US_Soldier_Crew_EP1` | 120 | 4 | 0 | `Core_US.sqf:71-72` |
| `US_Soldier_Pilot_EP1` | 120 | 4 | 0 | `Core_US.sqf:74-75` |
| `US_Soldier_TL_EP1` | 240 | 5 | 1 | `Core_US.sqf:77-78` |
| `US_Soldier_SL_EP1` | 220 | 5 | 2 | `Core_US.sqf:80-81` |
| `US_Soldier_Officer_EP1` | 250 | 5 | 1 | `Core_US.sqf:83-84` |

#### Light Vehicles

| Class | Cost | Build (s) | Upgrade req | Notes |
|-------|------|-----------|-------------|-------|
| `M1030_US_DES_EP1` | 150 | 12 | 0 | `Core_US.sqf:87-88` |
| `ATV_US_EP1` | 175 | 14 | 0 | `Core_US.sqf:90-91` |
| `HMMWV_DES_EP1` | 300 | 15 | 0 | `Core_US.sqf:93-94` |
| `HMMWV_M1035_DES_EP1` | 350 | 15 | 2 | `Core_US.sqf:96-97` |
| `HMMWV_Terminal_EP1` | 400 | 15 | 1 | `Core_US.sqf:99-100` |
| `HMMWV_MK19_DES_EP1` | 720 | 18 | 1 | `Core_US.sqf:102-103` |
| `HMMWV_M998A2_SOV_DES_EP1` | 950 | 20 | 1 | `Core_US.sqf:105-106` |
| `HMMWV_M1151_M2_DES_EP1` | 680 | 20 | 2 | `Core_US.sqf:108-109` |
| `HMMWV_M998_crows_M2_DES_EP1` | 900 | 22 | 2 | `Core_US.sqf:111-112` |
| `HMMWV_M998_crows_MK19_DES_EP1` | 1050 | 22 | 2 | `Core_US.sqf:114-115` |
| `HMMWV_TOW_DES_EP1` | 1450 | 20 | 3 | `Core_US.sqf:117-118` |
| `HMMWV_Avenger_DES_EP1` | 1750 | 25 | 4 | `Core_US.sqf:120-121` |
| `HMMWV_Ambulance_DES_EP1` | 4000 | 22 | 2 | `Core_US.sqf:123-124` |
| `MTVR_DES_EP1` | 500 | 20 | 1 | Cargo truck `Core_US.sqf:126-127` |
| `MtvrSalvage_DES_EP1` | 750 | 21 | 1 | `Core_US.sqf:129-130` |
| `MtvrRepair_DES_EP1` | 2500 | 22 | 2 | `Core_US.sqf:132-133` |
| `MtvrReammo_DES_EP1` | 1750 | 22 | 1 | `Core_US.sqf:135-136` |
| `MtvrRefuel_DES_EP1` | 500 | 22 | 1 | `Core_US.sqf:138-139` |
| `MtvrSupply_DES_EP1` | 550 | 25 | 0 | `Core_US.sqf:141-142` |
| `M1126_ICV_M2_EP1` | 1200 | 25 | 3 | Stryker ICV; crewSlots from config `Core_US.sqf:145-146` |
| `M1126_ICV_mk19_EP1` | 1450 | 25 | 3 | `Core_US.sqf:148-149` |
| `M1129_MC_EP1` | 4800 | 25 | 4 | Stryker mortar carrier `Core_US.sqf:151-152` |
| `M1135_ATGMV_EP1` | 1850 | 25 | 3 | `Core_US.sqf:154-155` |
| `M1128_MGS_EP1` | 2800 | 25 | 4 | `Core_US.sqf:157-158` |
| `M1133_MEV_EP1` | 4500 | 25 | 3 | Medical `Core_US.sqf:160-161` |

#### Heavy Vehicles

| Class | Cost (normal/balanced) | Build (s) | Upgrade req | Notes |
|-------|------------------------|-----------|-------------|-------|
| `M2A2_EP1` | 3800 / 2800 | 22 | 1 | Bradley; price conditional `Core_US.sqf:165-166` |
| `M2A3_EP1` | 3800 | 28 | 2 | `Core_US.sqf:168-169` |
| `M1A1_US_DES_EP1` | 5600 | 40 | 3 | `Core_US.sqf:171-172` |
| `MLRS_DES_EP1` | 8500 | 40 | 3 | `Core_US.sqf:174-175` |
| `M1A2_US_TUSK_MG_EP1` | 6500 | 40 | 4 | `Core_US.sqf:177-178` |
| `M6_EP1` | 7500 | 35 | 4 | Linebacker AA; excluded when `IS_air_war_event` `Core_US.sqf:180-181` |

#### Air Vehicles

| Class | Cost | Build (s) | Upgrade req | Notes |
|-------|------|-----------|-------------|-------|
| `MH6J_EP1` | 4928 | 25 | 0 | Little Bird `Core_US.sqf:184-185` |
| `UH60M_EP1` | 7168 | 30 | 1 | `Core_US.sqf:187-188` |
| `UH60M_MEV_EP1` | 8168 | 30 | 2 | Medical `Core_US.sqf:190-191` |
| `CH_47F_EP1` | 8976 | 30 | 1 | `Core_US.sqf:193-194` |
| `C130J_US_EP1` | 9440 | 30 | 1 | `Core_US.sqf:196-197` |
| `AH6X_EP1` | 4416 | 50 | 0 | `Core_US.sqf:199-200` |
| `AH6J_EP1` | 9119 | 35 | 2 | `Core_US.sqf:202-203` |
| `AH64D_EP1` | 34707 | 45 | 4 | Displays as `'AH-64D (Hellfire)'`; tag `'USMC'` `Core_US.sqf:205-206` |
| `A10_US_EP1` | 32320 | 45 | 4 | Displays as `'A-10C'` `Core_US.sqf:209-210` |
| `MQ9PredatorB_US_EP1` | 30000 | 35 | 2 | UAV `Core_US.sqf:214-215` |

#### Static Defenses

| Class | Cost | Notes |
|-------|------|-------|
| `WarfareBMGNest_M240_US_EP1` | 300 | `Core_US.sqf:218-219` |
| `M2HD_mini_TriPod_US_EP1` | 200 | `Core_US.sqf:221-222` |
| `M2StaticMG_US_EP1` | 225 | `Core_US.sqf:224-225` |
| `SearchLight_US_EP1` | 125 | `Core_US.sqf:227-228` |
| `MK19_TriPod_US_EP1` | 700 | `Core_US.sqf:230-231` |
| `TOW_TriPod_US_EP1` | 2000 | `Core_US.sqf:233-234` |
| `Stinger_Pod_US_EP1` | 3000 | `Core_US.sqf:236-237` |
| `M252_US_EP1` | 1150 | 82 mm mortar `Core_US.sqf:239-240` |
| `M119_US_EP1` | 2800 | 105 mm howitzer `Core_US.sqf:242-243` |

#### Fortifications / Supplies / Strategic

| Class | Cost | Category | Source |
|-------|------|----------|--------|
| `US_WarfareBBarrier5x_EP1` | 50 | Fortification | `Core_US.sqf:246-247` |
| `US_WarfareBBarrier10x_EP1` | 100 | Fortification | `Core_US.sqf:249-250` |
| `US_WarfareBBarrier10xTall_EP1` | 200 | Fortification | `Core_US.sqf:252-253` |
| `Land_CamoNet_NATO_EP1` | 35 | Strategic | `Core_US.sqf:255-256` |
| `Land_CamoNetVar_NATO_EP1` | 45 | Strategic | `Core_US.sqf:258-259` |
| `Land_CamoNetB_NATO_EP1` | 55 | Strategic | `Core_US.sqf:261-262` |
| `USOrdnanceBox_EP1` | 850 | Ammo | `Core_US.sqf:264-265` |
| `USVehicleBox_EP1` | 1200 | Ammo | `Core_US.sqf:267-268` |
| `USBasicAmmunitionBox_EP1` | 1950 | Ammo | `Core_US.sqf:270-271` |
| `USBasicWeapons_EP1` | 2975 | Ammo | `Core_US.sqf:273-274` |
| `USLaunchers_EP1` | 6250 | Ammo | `Core_US.sqf:276-277` |
| `USSpecialWeapons_EP1` | 7200 | Ammo | `Core_US.sqf:279-280` |
| `US_WarfareBVehicleServicePoint_Base_EP1` | 5500 | Strategic | `Core_US.sqf:284-285` |

---

### USMC (Chernarus map, base A2)

File: `Common/Config/Core/Core_USMC.sqf`. Faction tag: `'USMC'`.

#### Infantry

| Class | Cost | Skill | Upgrade req | Source |
|-------|------|-------|-------------|--------|
| `USMC_Soldier` | 150 | 4 | 0 | `Core_USMC.sqf:8-9` |
| `USMC_Soldier2` | 125 | 4 | 0 | `Core_USMC.sqf:11-12` |
| `USMC_Soldier_LAT` | 225 | 5 | 0 | `Core_USMC.sqf:14-15` |
| `USMC_Soldier_AT` | 700 | 5 | 2 | `Core_USMC.sqf:17-18` |
| `USMC_Soldier_HAT` | 1050 | 6 | 3 | `Core_USMC.sqf:20-21` |
| `USMC_Soldier_AA` | 400 | 6 | 2 | `Core_USMC.sqf:23-24` |
| `USMC_Soldier_AR` | 210 | 5 | 1 | `Core_USMC.sqf:26-27` |
| `USMC_Soldier_MG` | 220 | 5 | 1 | `Core_USMC.sqf:29-30` |
| `USMC_Soldier_GL` | 160 | 5 | 0 | `Core_USMC.sqf:32-33` |
| `USMC_SoldierS_Sniper` | 320 | 6 | 2 | `Core_USMC.sqf:35-36` |
| `USMC_SoldierM_Marksman` | 350 | 6 | 2 | `Core_USMC.sqf:38-39` |
| `USMC_SoldierS_SniperH` | 400 | 6 | 3 | `Core_USMC.sqf:41-42` |
| `USMC_Soldier_Medic` | 190 | 4 | 0 | `Core_USMC.sqf:44-45` |
| `USMC_SoldierS_Engineer` | 225 | 5 | 0 | `Core_USMC.sqf:47-48` |
| `USMC_SoldierS` | 300 | 7 | 1 | `Core_USMC.sqf:50-51` |
| `USMC_SoldierS_Spotter` | 320 | 6 | 3 | `Core_USMC.sqf:53-54` |
| `USMC_Soldier_Crew` | 120 | 4 | 0 | `Core_USMC.sqf:56-57` |
| `USMC_Soldier_Pilot` | 120 | 4 | 0 | `Core_USMC.sqf:59-60` |
| `USMC_Soldier_TL` | 240 | 5 | 1 | `Core_USMC.sqf:62-63` |
| `USMC_Soldier_SL` | 220 | 5 | 2 | `Core_USMC.sqf:65-66` |

#### Light Vehicles

| Class | Cost | Build (s) | Upgrade req | Source |
|-------|------|-----------|-------------|--------|
| `MMT_USMC` | 50 | 10 | 0 | `Core_USMC.sqf:69-70` |
| `M1030` | 150 | 12 | 0 | `Core_USMC.sqf:72-73` |
| `HMMWV` | 350 | 15 | 0 | `Core_USMC.sqf:75-76` |
| `Zodiac` | 225 | 17 | 0 | `Core_USMC.sqf:78-79` |
| `HMMWV_M2` | 620 | 18 | 1 | `Core_USMC.sqf:81-82` |
| `HMMWV_Armored` | 600 | 20 | 2 | `Core_USMC.sqf:84-85` |
| `HMMWV_MK19` | 750 | 22 | 1 | `Core_USMC.sqf:87-88` |
| `HMMWV_TOW` | 1450 | 20 | 3 | `Core_USMC.sqf:90-91` |
| `HMMWV_Avenger` | 1750 | 25 | 4 | `Core_USMC.sqf:93-94` |
| `HMMWV_Ambulance` | 4000 | 22 | 2 | `Core_USMC.sqf:96-97` |
| `MTVR` | 500 | 20 | 1 | `Core_USMC.sqf:99-100` |
| `WarfareSalvageTruck_USMC` | 750 | 21 | 1 | `Core_USMC.sqf:102-103` |
| `MtvrRepair` | 2500 | 22 | 2 | `Core_USMC.sqf:105-106` |
| `WarfareReammoTruck_USMC` | 1750 | 22 | 1 | `Core_USMC.sqf:108-109` |
| `MtvrRefuel` | 500 | 22 | 1 | `Core_USMC.sqf:111-112` |
| `WarfareSupplyTruck_USMC` | 550 | 25 | 0 | `Core_USMC.sqf:114-115` |
| `RHIB` | 850 | 25 | 1 | `Core_USMC.sqf:117-118` |
| `RHIB2Turret` | 1250 | 27 | 2 | `Core_USMC.sqf:120-121` |
| `LAV25` | 1650 | 27 | 3 | `Core_USMC.sqf:123-124` |

#### Heavy Vehicles

| Class | Cost | Build (s) | Upgrade req (vanilla/mod) | Source |
|-------|------|-----------|---------------------------|--------|
| `AAV` | 1300 | 18 | 0 | `Core_USMC.sqf:127-128` |
| `M1A1` | 5600 | 40 | 2 (vanilla) / 3 (mod) | `Core_USMC.sqf:130-131` |
| `MLRS` | 8500 | 40 | 3 | `Core_USMC.sqf:133-134` |
| `M1A2_TUSK_MG` | 6500 | 40 | 3 (vanilla) / 4 (mod) | `Core_USMC.sqf:136-137` |

#### Air Vehicles

| Class | Cost | Build (s) | Upgrade req | Notes |
|-------|------|-----------|-------------|-------|
| `MH60S` | 6528 | 30 | 1 | `Core_USMC.sqf:140-141` |
| `UH1Y` | 10522 | 35 | 2 | `Core_USMC.sqf:143-144` |
| `MV22` | 12672 | 30 | 1 | `Core_USMC.sqf:146-147` |
| `C130J` | 9440 | 30 | 1 | `Core_USMC.sqf:149-150` |
| `AH1Z` | 47632 | 50 | 5 | `Core_USMC.sqf:152-153` |
| `AH64D` | 31880 | 40 | 3 | Displays as `'AH-64D (TOW)'` `Core_USMC.sqf:155-156` |
| `F35B` | 41330 | 50 | 5 | `Core_USMC.sqf:158-159` |
| `L159_ACR` | 24395 | 40 | 3 | ACR DLC required `Core_USMC.sqf:161-162` |
| `AV8B` | 30720 | 45 | 4 | `Core_USMC.sqf:164-165` |
| `AV8B2` | 36110 | 50 | 5 | `Core_USMC.sqf:167-168` |
| `A10` | 28340 | 40 | 3 | Displays as `'A-10A'` `Core_USMC.sqf:171-172` |
| `MQ9PredatorB` | 30000 | 35 | 2 | UAV; crewSlots `2` (explicit, not `-2`) `Core_USMC.sqf:176-177` |

#### Static Defenses (USMC)

| Class | Cost | Source |
|-------|------|--------|
| `USMC_WarfareBMGNest_M240` | 300 | `Core_USMC.sqf:180-181` |
| `M2HD_mini_TriPod` | 200 | `Core_USMC.sqf:183-184` |
| `M2StaticMG` | 225 | `Core_USMC.sqf:186-187` |
| `SearchLight` | 125 | `Core_USMC.sqf:189-190` |
| `MK19_TriPod` | 700 | `Core_USMC.sqf:192-193` |
| `TOW_TriPod` | 2000 | `Core_USMC.sqf:195-196` |
| `Stinger_Pod` | 3000 | `Core_USMC.sqf:198-199` |
| `M252` | 1150 | `Core_USMC.sqf:201-202` |
| `M119` | 2800 | `Core_USMC.sqf:204-205` |

---

### Russians / RU (Chernarus map)

File: `Common/Config/Core/Core_RU.sqf`. Faction tag: `'Russians'`.

#### Infantry

| Class | Cost | Skill | Upgrade req | Source |
|-------|------|-------|-------------|--------|
| `RU_Soldier` | 150 | 4 | 0 | `Core_RU.sqf:8-9` |
| `RU_Soldier2` | 120 | 4 | 0 | `Core_RU.sqf:11-12` |
| `RU_Soldier_LAT` | 220 | 5 | 0 | `Core_RU.sqf:14-15` |
| `RU_Soldier_AT` | 310 | 5 | 1 | `Core_RU.sqf:17-18` |
| `RU_Soldier_HAT` | 1050 | 6 | 3 | `Core_RU.sqf:20-21` |
| `RU_Soldier_AA` | 425 | 6 | 1 | `Core_RU.sqf:23-24` |
| `RU_Soldier_AR` | 210 | 5 | 0 | `Core_RU.sqf:26-27` |
| `RU_Soldier_MG` | 220 | 5 | 1 | `Core_RU.sqf:29-30` |
| `RU_Soldier_GL` | 160 | 5 | 0 | `Core_RU.sqf:32-33` |
| `RU_Soldier_Marksman` | 290 | 5 | 1 | `Core_RU.sqf:35-36` |
| `RU_Soldier_Spotter` | 295 | 5 | 2 | `Core_RU.sqf:38-39` |
| `RU_Soldier_Sniper` | 300 | 5 | 2 | `Core_RU.sqf:41-42` |
| `RU_Soldier_SniperH` | 330 | 5 | 3 | `Core_RU.sqf:44-45` |
| `RU_Soldier_Medic` | 190 | 4 | 0 | `Core_RU.sqf:47-48` |
| `RU_Soldier_Crew` | 120 | 4 | 0 | `Core_RU.sqf:50-51` |
| `RU_Soldier_Pilot` | 120 | 4 | 0 | `Core_RU.sqf:53-54` |
| `RU_Soldier_TL` | 240 | 5 | 1 | `Core_RU.sqf:56-57` |
| `RU_Soldier_SL` | 220 | 5 | 2 | `Core_RU.sqf:59-60` |

#### Light Vehicles

| Class | Cost | Build (s) | Upgrade req | Source |
|-------|------|-----------|-------------|--------|
| `UAZ_RU` | 260 | 15 | 0 | `Core_RU.sqf:63-64` |
| `PBX` | 225 | 15 | 0 | Boat `Core_RU.sqf:66-67` |
| `UAZ_AGS30_RU` | 685 | 18 | 1 | `Core_RU.sqf:69-70` |
| `Kamaz` | 500 | 15 | 1 | `Core_RU.sqf:72-73` |
| `WarfareSalvageTruck_RU` | 750 | 18 | 1 | `Core_RU.sqf:75-76` |
| `KamazRepair` | 2500 | 21 | 2 | `Core_RU.sqf:78-79` |
| `WarfareReammoTruck_RU` | 1750 | 21 | 1 | `Core_RU.sqf:81-82` |
| `KamazRefuel` | 500 | 21 | 1 | `Core_RU.sqf:84-85` |
| `WarfareSupplyTruck_RU` | 550 | 21 | 0 | `Core_RU.sqf:87-88` |
| `GAZ_Vodnik_MedEvac` | 3200 | 25 | 3 | `Core_RU.sqf:90-91` |
| `GAZ_Vodnik` | 900 | 22 | 2 | `Core_RU.sqf:93-94` |
| `GAZ_Vodnik_HMG` | 1450 | 24 | 3 | Explicit crew slot `[false,true,2,0]`; extra seats `[[0]]` `Core_RU.sqf:96-97` |
| `BTR90` | 2550 | 25 | 3 | `Core_RU.sqf:99-100` |
| `GRAD_RU` | 6800 | 25 | 4 | `Core_RU.sqf:102-103` |

#### Heavy Vehicles

| Class | Cost | Build (s) | Upgrade req (vanilla/mod) | Source |
|-------|------|-----------|---------------------------|--------|
| `BMP3` | 4600 | 35 | 1 (vanilla) / 3 (mod) | `Core_RU.sqf:106-107` |
| `T72_RU` | 5200 | 40 | 2 (vanilla) / 3 (mod) | `Core_RU.sqf:109-110` |
| `T90` | 6500 | 40 | 3 (vanilla) / 4 (mod) | `Core_RU.sqf:112-113` |
| `2S6M_Tunguska` | 8800 | 35 | 4 | `Core_RU.sqf:115-116` |

#### Air Vehicles

| Class | Cost (normal/balanced) | Build (s) | Upgrade req | Source |
|-------|------------------------|-----------|-------------|--------|
| `Mi17_medevac_RU` | 9800 | 30 | 2 | `Core_RU.sqf:119-120` |
| `Mi17_rockets_RU` | 16904 | 40 | 3 | `Core_RU.sqf:122-123` |
| `Mi24_V` | 39600 | 45 | 4 | `Core_RU.sqf:125-126` |
| `Mi24_P` | 32600 | 40 | 3 | `Core_RU.sqf:128-129` |
| `Su34` | 41230 | 50 | 5 | `Core_RU.sqf:131-132` |
| `Su39` | 37520 | 50 | 5 | Displays as `'Su-39'` `Core_RU.sqf:134-135` |
| `Ka52` | 75000 / 41880 | 45 | 4 | Balancing flag conditional `Core_RU.sqf:137-138` |
| `Ka52Black` | 75000 / 46800 | 50 | 5 | `Core_RU.sqf:140-141` |
| `Pchela1T` | 9000 | 35 | 1 | UAV drone `Core_RU.sqf:144-145` |

#### Static Defenses (RU)

| Class | Display name | Cost | Source |
|-------|-------------|------|--------|
| `RU_WarfareBMGNest_PK` | — | 300 | `Core_RU.sqf:148-149` |
| `KORD` | KORD | 200 | `Core_RU.sqf:151-152` |
| `KORD_high` | KORD Minitripod | 225 | `Core_RU.sqf:154-155` |
| `SearchLight_RUS` | — | 125 | `Core_RU.sqf:157-158` |
| `AGS_RU` | — | 650 | `Core_RU.sqf:160-161` |
| `Metis` | Metis-M 9K115-2 | 1200 | `Core_RU.sqf:163-164` |
| `Igla_AA_pod_East` | Igla AA POD launcher | 3000 | `Core_RU.sqf:166-167` |
| `2b14_82mm` | Podnos 2B14 | 1025 | `Core_RU.sqf:169-170` |
| `D30_RU` | — | 2800 | `Core_RU.sqf:172-173` |

---

### Guerilla / GUE (Chernarus, independent)

File: `Common/Config/Core/Core_GUE.sqf`. Faction tag: `'Guerilla'`.

#### Infantry

| Class | Cost | Skill | Upgrade req | Notes |
|-------|------|-------|-------------|-------|
| `GUE_Soldier_1` | 150 | 4 | 0 | `Core_GUE.sqf:8-9` |
| `GUE_Soldier_2` | 120 | 4 | 0 | `Core_GUE.sqf:11-12` |
| `GUE_Soldier_3` | 140 | 4 | 0 | `Core_GUE.sqf:14-15` |
| `GUE_Soldier_GL` | 150 | 5 | 1 | `Core_GUE.sqf:17-18` |
| `GUE_Soldier_AT` | 220 | 5 | 1 | `Core_GUE.sqf:20-21` |
| `GUE_Soldier_AA` | 250 | 4 | 0 | `Core_GUE.sqf:23-24` |
| `GUE_Soldier_AR` | 150 | 4 | 1 | `Core_GUE.sqf:26-27` |
| `GUE_Soldier_MG` | 190 | 4 | 0 | `Core_GUE.sqf:29-30` |
| `GUE_Soldier_Sniper` | 175 | 6 | 1 | `Core_GUE.sqf:32-33` |
| `GUE_Soldier_Medic` | 160 | 6 | 0 | `Core_GUE.sqf:35-36` |
| `GUE_Soldier_Crew` | 120 | 5 | 0 | `Core_GUE.sqf:38-39` |
| `GUE_Soldier_Pilot` | 120 | 5 | 0 | `Core_GUE.sqf:41-42` |
| `GUE_Soldier_Scout` | 260 | 5 | 3 | `Core_GUE.sqf:44-45` |
| `GUE_Soldier_CO` | 300 | 5 | 1 | `Core_GUE.sqf:47-48` |
| `GUE_Soldier_Sab` | 220 | 5 | 2 | `Core_GUE.sqf:50-51` |
| `GUE_Commander` | 240 | 5 | 0 | `Core_GUE.sqf:53-54` |
| `GUE_Worker2` | 100 | 5 | 0 | `Core_GUE.sqf:56-57` |
| `GUE_Woodlander3` | 100 | 5 | 0 | `Core_GUE.sqf:59-60` |
| `GUE_Villager3` | 100 | 5 | 0 | `Core_GUE.sqf:62-63` |
| `GUE_Woodlander2` | 100 | 5 | 0 | `Core_GUE.sqf:65-66` |
| `GUE_Woodlander1` | 100 | 5 | 0 | `Core_GUE.sqf:68-69` |
| `GUE_Villager4` | 100 | 5 | 0 | `Core_GUE.sqf:71-72` |

#### Light Vehicles

| Class | Cost | Build (s) | Upgrade req | Source |
|-------|------|-----------|-------------|--------|
| `TT650_Gue` | 150 | 15 | 0 | `Core_GUE.sqf:75-76` |
| `V3S_Gue` | 175 | 15 | 0 | `Core_GUE.sqf:78-79` |
| `Pickup_PK_GUE` | 250 | 17 | 0 | `Core_GUE.sqf:81-82` |
| `Offroad_DSHKM_Gue` | 550 | 25 | 1 | `Core_GUE.sqf:84-85` |
| `Offroad_SPG9_Gue` | 750 | 20 | 2 | `Core_GUE.sqf:87-88` |
| `WarfareRepairTruck_Gue` | 425 | 17 | 2 | `Core_GUE.sqf:89-90` |
| `WarfareSalvageTruck_Gue` | 450 | 17 | 1 | `Core_GUE.sqf:92-93` |
| `WarfareReammoTruck_Gue` | 450 | 18 | 1 | `Core_GUE.sqf:95-96` |
| `WarfareSupplyTruck_Gue` | 450 | 21 | 0 | `Core_GUE.sqf:98-99` |
| `BRDM2_Gue` | 1200 | 25 | 2 | `Core_GUE.sqf:101-102` |
| `Ural_ZU23_Gue` | 1100 | 20 | 2 | `Core_GUE.sqf:104-105` |

#### Heavy Vehicles

| Class | Cost | Build (s) | Upgrade req | Notes |
|-------|------|-----------|-------------|-------|
| `M113_UN_EP1` | 1100 | 30 | 0 | Tag `'Takistani Guerilla'` `Core_GUE.sqf:108-109` |
| `BMP2_Gue` | 3400 | 28 | 1 | `Core_GUE.sqf:111-112` |
| `T72_Gue` | 5200 | 35 | 3 | `Core_GUE.sqf:114-115` |

#### Aircraft Pool (Chernarus GUE)

The GUE aircraft pool contains only `Mi17_Civilian` (`Units_GUE.sqf:51-53`). The airport pool is empty (`Units_GUE.sqf:56-59`).

#### Static Defenses (GUE)

| Class | Cost | Source |
|-------|------|--------|
| `GUE_WarfareBMGNest_PK` | 300 | `Core_GUE.sqf:118-119` |
| `DSHKM_Gue` | 225 | `Core_GUE.sqf:121-122` |
| `SPG9_Gue` | 675 | `Core_GUE.sqf:124-125` |
| `ZU23_Gue` | 700 | `Core_GUE.sqf:127-128` |
| `2b14_82mm_GUE` | 1025 | Podnos 2B14 `Core_GUE.sqf:129-130` |

---

### Insurgents / INS (Chernarus, independent)

File: `Common/Config/Core/Core_INS.sqf`. Faction tag: `'Insurgents'`.

#### Infantry

| Class | Cost | Skill | Upgrade req | Notes |
|-------|------|-------|-------------|-------|
| `Ins_Soldier_1` | 150 | 4 | 0 | `Core_INS.sqf:8-9` |
| `Ins_Soldier_2` | 160 | 4 | 0 | `Core_INS.sqf:11-12` |
| `Ins_Soldier_GL` | 175 | 4 | 0 | `Core_INS.sqf:14-15` |
| `Ins_Soldier_CO` | 210 | 5 | 1 | `Core_INS.sqf:17-18` |
| `Ins_Commander` | 250 | 5 | 2 | `Core_INS.sqf:20-21` |
| `Ins_Soldier_Medic` | 175 | 4 | 0 | `Core_INS.sqf:23-24` |
| `Ins_Soldier_AR` | 180 | 4 | 1 | `Core_INS.sqf:26-27` |
| `Ins_Soldier_MG` | 190 | 4 | 1 | `Core_INS.sqf:29-30` |
| `Ins_Soldier_AT` | 600 | 6 | 2 | Display: `'AT Specialist (Dragon)'`; note in source `Core_INS.sqf:33-34` |
| `Ins_Soldier_AA` | 300 | 6 | 2 | `Core_INS.sqf:36-37` |
| `Ins_Soldier_Sniper` | 220 | 6 | 1 | `Core_INS.sqf:39-40` |
| `Ins_Soldier_Sapper` | 190 | 5 | 2 | `Core_INS.sqf:42-43` |
| `Ins_Soldier_Sab` | 180 | 5 | 2 | `Core_INS.sqf:45-46` |
| `Ins_Soldier_Pilot` | 130 | 5 | 0 | `Core_INS.sqf:48-49` |
| `Ins_Soldier_Crew` | 130 | 5 | 0 | `Core_INS.sqf:51-52` |
| `INS_Woodlander1` | 100 | 5 | 0 | `Core_INS.sqf:54-55` |
| `INS_Woodlander2` | 100 | 5 | 0 | `Core_INS.sqf:57-58` |
| `INS_Woodlander3` | 100 | 5 | 0 | `Core_INS.sqf:60-61` |
| `INS_Villager3` | 100 | 5 | 0 | `Core_INS.sqf:63-64` |
| `INS_Villager4` | 100 | 5 | 0 | `Core_INS.sqf:66-67` |

#### Light Vehicles

| Class | Cost | Build (s) | Upgrade req | Source |
|-------|------|-----------|-------------|--------|
| `TT650_Ins` | 150 | 15 | 0 | `Core_INS.sqf:70-71` |
| `UAZ_INS` | 260 | 15 | 0 | `Core_INS.sqf:73-74` |
| `Pickup_PK_INS` | 300 | 15 | 1 | `Core_INS.sqf:76-77` |
| `Offroad_DSHKM_INS` | 350 | 15 | 1 | `Core_INS.sqf:79-80` |
| `UAZ_MG_INS` | 460 | 17 | 1 | `Core_INS.sqf:82-83` |
| `UAZ_AGS30_INS` | 685 | 25 | 2 | `Core_INS.sqf:85-86` |
| `UAZ_SPG9_INS` | 960 | 20 | 2 | `Core_INS.sqf:88-89` |
| `UralOpen_INS` | 490 | 20 | 1 | `Core_INS.sqf:91-92` |
| `Ural_INS` | 500 | 20 | 1 | `Core_INS.sqf:94-95` |
| `WarfareSalvageTruck_INS` | 750 | 18 | 1 | `Core_INS.sqf:97-98` |
| `UralRepair_INS` | 525 | 21 | 2 | `Core_INS.sqf:100-101` |
| `UralReammo_INS` | 550 | 21 | 1 | `Core_INS.sqf:103-104` |
| `UralRefuel_INS` | 500 | 21 | 1 | `Core_INS.sqf:106-107` |
| `WarfareSupplyTruck_INS` | 550 | 21 | 0 | `Core_INS.sqf:109-110` |
| `BRDM2_INS` | 1200 | 25 | 3 | `Core_INS.sqf:112-113` |
| `BRDM2_ATGM_INS` | 2150 | 25 | 3 | Display: `'BRDM (Igla)'` `Core_INS.sqf:115-116` |
| `Ural_ZU23_INS` | 1100 | 20 | 3 | `Core_INS.sqf:118-119` |
| `GRAD_INS` | 6800 | 35 | 5 | `Core_INS.sqf:121-122` |

#### Heavy Vehicles

| Class | Cost | Build (s) | Upgrade req | Source |
|-------|------|-----------|-------------|--------|
| `BMP2_Ambul_INS` | 3950 | 20 | 1 | `Core_INS.sqf:125-126` |
| `BMP2_INS` | 3400 | 28 | 1 | `Core_INS.sqf:128-129` |
| `ZSU_INS` | 3500 | 35 | 3 | `Core_INS.sqf:131-132` |
| `T72_INS` | 5200 | 35 | 3 | `Core_INS.sqf:134-135` |

#### Air Vehicles

| Class | Cost | Build (s) | Upgrade req | Source |
|-------|------|-----------|-------------|--------|
| `Mi17_Ins` | 8800 | 30 | 1 | `Core_INS.sqf:138-139` |
| `Mi17_medevac_Ins` | 9800 | 30 | 2 | `Core_INS.sqf:141-142` |
| `Su25_Ins` | 25584 | 45 | 3 | Display: `'Su-25A'` `Core_INS.sqf:144-145` |

#### Static Defenses (INS)

| Class | Cost | Notes |
|-------|------|-------|
| `Ins_WarfareBMGNest_PK` | 300 | `Core_INS.sqf:148-149` |
| `DSHkM_Mini_TriPod` | 200 | `Core_INS.sqf:151-152` |
| `DSHKM_Ins` | 225 | `Core_INS.sqf:154-155` |
| `SearchLight_INS` | 125 | `Core_INS.sqf:157-158` |
| `AGS_Ins` | 650 | `Core_INS.sqf:160-161` |
| `SPG9_Ins` | 475 | `Core_INS.sqf:163-164` |
| `ZU23_Ins` | 945 | `Core_INS.sqf:166-167` |
| `2b14_82mm_INS` | 1025 | Podnos 2B14 `Core_INS.sqf:169-170` |
| `D30_Ins` | 2800 | `Core_INS.sqf:172-173` |
| `INS_WarfareBVehicleServicePoint` | 5500 | Note: tag hardcoded to `'US'` (source bug) `Core_INS.sqf:176-177` |

---

### CDF (Chernarus Defence Forces, independent)

File: `Common/Config/Core/Core_CDF.sqf`. Faction tag: `'CDF'`.

#### Infantry

| Class | Cost | Skill | Upgrade req | Source |
|-------|------|-------|-------------|--------|
| `CDF_Soldier` | 150 | 4 | 0 | `Core_CDF.sqf:8-9` |
| `CDF_Soldier_Engineer` | 225 | 5 | 0 | `Core_CDF.sqf:11-12` |
| `CDF_Soldier_Light` | 175 | 4 | 0 | `Core_CDF.sqf:14-15` |
| `CDF_Soldier_GL` | 180 | 4 | 0 | `Core_CDF.sqf:17-18` |
| `CDF_Soldier_Militia` | 160 | 3 | 0 | `Core_CDF.sqf:20-21` |
| `CDF_Soldier_Medic` | 210 | 4 | 0 | `Core_CDF.sqf:23-24` |
| `CDF_Soldier_Sniper` | 230 | 5 | 1 | `Core_CDF.sqf:26-27` |
| `CDF_Soldier_Spotter` | 240 | 6 | 1 | `Core_CDF.sqf:29-30` |
| `CDF_Soldier_Marksman` | 235 | 7 | 3 | `Core_CDF.sqf:32-33` |
| `CDF_Soldier_RPG` | 250 | 6 | 1 | `Core_CDF.sqf:35-36` |
| `CDF_Soldier_Strela` | 400 | 6 | 2 | `Core_CDF.sqf:38-39` |
| `CDF_Soldier_AR` | 165 | 6 | 1 | `Core_CDF.sqf:41-42` |
| `CDF_Soldier_MG` | 180 | 5 | 0 | `Core_CDF.sqf:44-45` |
| `CDF_Soldier_TL` | 210 | 6 | 2 | `Core_CDF.sqf:47-48` |
| `CDF_Soldier_Officer` | 230 | 7 | 1 | `Core_CDF.sqf:50-51` |
| `CDF_Commander` | 280 | 7 | 3 | `Core_CDF.sqf:53-54` |
| `CDF_Soldier_Pilot` | 130 | 5 | 0 | `Core_CDF.sqf:56-57` |
| `CDF_Soldier_Crew` | 130 | 5 | 0 | `Core_CDF.sqf:59-60` |

#### Light Vehicles

| Class | Cost | Build (s) | Upgrade req | Source |
|-------|------|-----------|-------------|--------|
| `UAZ_CDF` | 150 | 15 | 0 | `Core_CDF.sqf:63-64` |
| `UAZ_MG_CDF` | 310 | 17 | 0 | `Core_CDF.sqf:66-67` |
| `UAZ_AGS30_CDF` | 475 | 25 | 1 | `Core_CDF.sqf:69-70` |
| `Ural_CDF` | 300 | 20 | 0 | `Core_CDF.sqf:72-73` |
| `WarfareSalvageTruck_CDF` | 450 | 18 | 0 | `Core_CDF.sqf:75-76` |
| `UralRepair_CDF` | 2500 | 21 | 1 | `Core_CDF.sqf:78-79` |
| `UralReammo_CDF` | 550 | 21 | 1 | `Core_CDF.sqf:81-82` |
| `UralRefuel_CDF` | 500 | 21 | 1 | `Core_CDF.sqf:84-85` |
| `WarfareSupplyTruck_CDF` | 550 | 21 | 0 | `Core_CDF.sqf:87-88` |
| `BRDM2_CDF` | 1100 | 25 | 1 | `Core_CDF.sqf:90-91` |
| `BRDM2_ATGM_CDF` | 2150 | 25 | 3 | `Core_CDF.sqf:93-94` |
| `Ural_ZU23_CDF` | 1100 | 20 | 2 | `Core_CDF.sqf:96-97` |
| `GRAD_CDF` | 6800 | 35 | 3 | `Core_CDF.sqf:99-100` |

#### Heavy Vehicles

| Class | Cost | Build (s) | Upgrade req | Source |
|-------|------|-----------|-------------|--------|
| `BMP2_Ambul_CDF` | 3800 | 20 | 0 | `Core_CDF.sqf:103-104` |
| `BVP1_TK_ACR` | 2200 | 22 | 1 | ACR DLC `Core_CDF.sqf:106-107` |
| `BMP2_CDF` | 2600 | 30 | 1 | `Core_CDF.sqf:109-110` |
| `ZSU_CDF` | 3500 | 35 | 3 | `Core_CDF.sqf:112-113` |
| `T72_CDF` | 5200 | 35 | 3 | `Core_CDF.sqf:115-116` |

#### Air Vehicles

| Class | Cost | Build (s) | Upgrade req | Source |
|-------|------|-----------|-------------|--------|
| `Mi17_CDF` | 8800 | 30 | 1 | `Core_CDF.sqf:119-120` |
| `Mi17_medevac_CDF` | 9800 | 30 | 2 | `Core_CDF.sqf:122-123` |
| `Mi24_D` | 22580 | 40 | 3 | `Core_CDF.sqf:125-126` |
| `Su25_CDF` | 42640 | 55 | 4 | `Core_CDF.sqf:128-129` |

#### Static Defenses (CDF)

| Class | Cost | Notes |
|-------|------|-------|
| `CDF_WarfareBMGNest_PK` | 300 | `Core_CDF.sqf:132-133` |
| `DSHkM_Mini_TriPod_CDF` | 200 | `Core_CDF.sqf:135-136` |
| `DSHKM_CDF` | 225 | `Core_CDF.sqf:138-139` |
| `SearchLight_CDF` | 125 | `Core_CDF.sqf:141-142` |
| `AGS_CDF` | 700 | `Core_CDF.sqf:144-145` |
| `SPG9_CDF` | 475 | `Core_CDF.sqf:147-148` |
| `ZU23_CDF` | 945 | `Core_CDF.sqf:150-151` |
| `2b14_82mm_CDF` | 1150 | Podnos 2B14 `Core_CDF.sqf:153-154` |
| `D30_CDF` | 2250 | `Core_CDF.sqf:156-157` |
| `CDF_WarfareBVehicleServicePoint` | 5500 | Note: tag hardcoded to `'US'` `Core_CDF.sqf:160-161` |

---

### PMC (Private Military Company, independent)

File: `Common/Config/Core/Core_PMC.sqf`. Faction tag: `'PMC'`. PMC has no heavy vehicles or static defenses in this file.

#### Infantry

| Class | Cost | Skill | Upgrade req | Source |
|-------|------|-------|-------------|--------|
| `Soldier_AA_PMC` | 300 | 6 | 2 | `Core_PMC.sqf:8-9` |
| `Soldier_AT_PMC` | 260 | 6 | 0 | `Core_PMC.sqf:11-12` |
| `Soldier_Bodyguard_AA12_PMC` | 325 | 6 | 3 | `Core_PMC.sqf:14-15` |
| `Soldier_Bodyguard_M4_PMC` | 225 | 6 | 0 | `Core_PMC.sqf:17-18` |
| `Soldier_Crew_PMC` | 170 | 6 | 0 | `Core_PMC.sqf:20-21` |
| `Soldier_Engineer_PMC` | 270 | 6 | 2 | `Core_PMC.sqf:23-24` |
| `Soldier_GL_M16A2_PMC` | 185 | 6 | 0 | `Core_PMC.sqf:26-27` |
| `Soldier_GL_PMC` | 260 | 6 | 2 | `Core_PMC.sqf:29-30` |
| `Soldier_M4A3_PMC` | 210 | 6 | 1 | `Core_PMC.sqf:32-33` |
| `Soldier_Medic_PMC` | 255 | 6 | 2 | `Core_PMC.sqf:35-36` |
| `Soldier_MG_PKM_PMC` | 190 | 6 | 0 | `Core_PMC.sqf:38-39` |
| `Soldier_MG_PMC` | 260 | 6 | 3 | `Core_PMC.sqf:41-42` |
| `Soldier_Pilot_PMC` | 175 | 6 | 0 | `Core_PMC.sqf:44-45` |
| `Soldier_PMC` | 230 | 6 | 0 | `Core_PMC.sqf:47-48` |
| `Soldier_Sniper_KSVK_PMC` | 290 | 6 | 0 | `Core_PMC.sqf:50-51` |
| `Soldier_Sniper_PMC` | 275 | 6 | 0 | `Core_PMC.sqf:53-54` |
| `Soldier_TL_PMC` | 280 | 6 | 0 | `Core_PMC.sqf:56-57` |

All PMC infantry carry skill tier 6 regardless of upgrade level.

#### Light Vehicles

| Class | Cost | Build (s) | Upgrade req | Source |
|-------|------|-----------|-------------|--------|
| `SUV_PMC` | 300 | 20 | 1 | `Core_PMC.sqf:60-61` |
| `ArmoredSUV_PMC` | 800 | 25 | 2 | `Core_PMC.sqf:63-64` |

#### Air Vehicles

| Class | Cost | Build (s) | Upgrade req | Source |
|-------|------|-----------|-------------|--------|
| `Ka137_PMC` | 3000 | 35 | 0 | `Core_PMC.sqf:67-68` |
| `Ka137_MG_PMC` | 3500 | 35 | 1 | `Core_PMC.sqf:70-71` |
| `Ka60_PMC` | 6000 | 43 | 2 | `Core_PMC.sqf:73-74` |
| `Ka60_GL_PMC` | 6500 | 45 | 2 | `Core_PMC.sqf:76-77` |

---

### BAF (British Armed Forces — map-variant camo)

Three BAF Core files exist sharing the same infantry class set with identical stats, differentiated only by camo variant and faction tag:

| File | Classes suffix | Faction tag |
|------|---------------|-------------|
| `Core_BAF.sqf` | `_MTP` | `'British'` |
| `Core_BAFW.sqf` | `_W` (Woodland) | `'British (Woodland)'` |
| `Core_BAFD.sqf` | `_DDPM` / `_D` (Desert) | (see file) |

BAF infantry classes share identical pricing between MTP and Woodland variants. Woodland-specific differences:
- `BAF_Soldier_AT_W` costs 650 (`Core_BAFW.sqf:27`) vs `BAF_Soldier_AT_MTP` at 360 (`Core_BAF.sqf:27`).

#### BAF Infantry (MTP / representative prices)

| Class (MTP) | Cost | Skill | Upgrade req | Source |
|-------------|------|-------|-------------|--------|
| `BAF_Soldier_AA_MTP` | 410 | 6 | 2 | `Core_BAF.sqf:8-9` |
| `BAF_Soldier_AAA_MTP` | 190 | 6 | 2 | `Core_BAF.sqf:11-12` |
| `BAF_Soldier_AAT_MTP` | 190 | 4 | 2 | `Core_BAF.sqf:14-15` |
| `BAF_Soldier_AHAT_MTP` | 190 | 6 | 3 | `Core_BAF.sqf:17-18` |
| `BAF_Soldier_AAR_MTP` | 190 | 5 | 2 | `Core_BAF.sqf:20-21` |
| `BAF_Soldier_AMG_MTP` | 190 | 6 | 1 | `Core_BAF.sqf:23-24` |
| `BAF_Soldier_AT_MTP` | 360 | 6 | 2 | `Core_BAF.sqf:26-27` |
| `BAF_Soldier_HAT_MTP` | 1050 | 6 | 3 | `Core_BAF.sqf:29-30` |
| `BAF_Soldier_AR_MTP` | 210 | 5 | 2 | `Core_BAF.sqf:32-33` |
| `BAF_crewman_MTP` | 125 | 5 | 0 | `Core_BAF.sqf:35-36` |
| `BAF_Soldier_EN_MTP` | 230 | 5 | 0 | `Core_BAF.sqf:38-39` |
| `BAF_Soldier_GL_MTP` | 170 | 5 | 0 | `Core_BAF.sqf:41-42` |
| `BAF_Soldier_FAC_MTP` | 375 | 6 | 3 | `Core_BAF.sqf:44-45` |
| `BAF_Soldier_MG_MTP` | 210 | 5 | 0 | `Core_BAF.sqf:47-48` |
| `BAF_Soldier_scout_MTP` | 340 | 6 | 2 | `Core_BAF.sqf:50-51` |
| `BAF_Soldier_Marksman_MTP` | 370 | 6 | 3 | `Core_BAF.sqf:53-54` |
| `BAF_Soldier_Medic_MTP` | 200 | 6 | 0 | `Core_BAF.sqf:56-57` |
| `BAF_Soldier_Officer_MTP` | 265 | 6 | 2 | `Core_BAF.sqf:59-60` |
| `BAF_Pilot_MTP` | 125 | 6 | 0 | `Core_BAF.sqf:62-63` |
| `BAF_Soldier_MTP` | 155 | 6 | 0 | `Core_BAF.sqf:65-66` |
| `BAF_ASoldier_MTP` | 160 | 6 | 0 | `Core_BAF.sqf:68-69` |
| `BAF_Soldier_L_MTP` | 130 | 6 | 0 | `Core_BAF.sqf:71-72` |
| `BAF_Soldier_N_MTP` | 175 | 6 | 1 | `Core_BAF.sqf:74-75` |
| `BAF_Soldier_SL_MTP` | 235 | 6 | 2 | `Core_BAF.sqf:77-78` |
| `BAF_Soldier_SniperN_MTP` | 390 | 6 | 3 | `Core_BAF.sqf:80-81` |
| `BAF_Soldier_SniperH_MTP` | 420 | 6 | 2 | `Core_BAF.sqf:83-84` |
| `BAF_Soldier_Sniper_MTP` | 395 | 6 | 2 | `Core_BAF.sqf:86-87` |
| `BAF_Soldier_spotter_MTP` | 340 | 6 | 2 | `Core_BAF.sqf:89-90` |
| `BAF_Soldier_spotterN_MTP` | 350 | 6 | 2 | `Core_BAF.sqf:92-93` |
| `BAF_Soldier_TL_MTP` | 245 | 6 | 1 | `Core_BAF.sqf:95-96` |

#### BAF Air Vehicles (shared across all three camo variants)

| Class | Cost | Build (s) | Upgrade req | Source |
|-------|------|-----------|-------------|--------|
| `BAF_Merlin_HC3_D` | 13948 | 35 | 2 | `Core_BAF.sqf:100-101` |
| `CH_47F_BAF` | 8976 | 30 | 1 | `Core_BAF.sqf:103-104` |
| `BAF_Apache_AH1_D` | 39617 | 45 | 4 | `Core_BAF.sqf:106-107` |
| `AW159_Lynx_BAF` | 22692 | 35 | 3 | `Core_BAF.sqf:109-110` |

#### BAF Woodland Light and Heavy Vehicles

| Class | Cost | Build (s) | Upgrade req | Source |
|-------|------|-----------|-------------|--------|
| `BAF_ATV_W` | 175 | 12 | 0 | `Core_BAFW.sqf:99-100` |
| `BAF_Offroad_W` | 375 | 13 | 1 | `Core_BAFW.sqf:102-103` |
| `BAF_Jackal2_GMG_W` | 965 | 20 | 2 | `Core_BAFW.sqf:105-106` |
| `BAF_Jackal2_L2A1_W` | 725 | 21 | 2 | `Core_BAFW.sqf:108-109` |
| `BAF_FV510_W` | 6500 | 30 | 3 | IFV `Core_BAFW.sqf:112-113` |

#### BAF Woodland Static Defenses

| Class | Cost | Source |
|-------|------|--------|
| `BAF_GPMG_Minitripod_W` | 225 | `Core_BAFW.sqf:116-117` |
| `BAF_GMG_Tripod_W` | 250 | `Core_BAFW.sqf:119-120` |
| `BAF_L2A1_Minitripod_W` | 300 | `Core_BAFW.sqf:122-123` |
| `BAF_L2A1_Tripod_W` | 325 | `Core_BAFW.sqf:125-126` |

---

### Takistani Army / TKA (Takistan map)

File: `Common/Config/Core/Core_TKA.sqf`. Faction tag: `'Takistani Army'`.

#### Infantry

| Class | Cost | Skill | Upgrade req | Source |
|-------|------|-------|-------------|--------|
| `TK_Soldier_EP1` | 150 | 4 | 0 | `Core_TKA.sqf:8-9` |
| `TK_Soldier_B_EP1` | 125 | 4 | 0 | `Core_TKA.sqf:11-12` |
| `TK_Soldier_TWS_EP1` | 205 | 5 | 0 | Thermal weapon sight `Core_TKA.sqf:14-15` |
| `TK_Soldier_Engineer_EP1` | 155 | 5 | 1 | `Core_TKA.sqf:17-18` |
| `TK_Soldier_LAT_EP1` | 225 | 5 | 0 | `Core_TKA.sqf:20-21` |
| `TK_Soldier_AT_EP1` | 310 | 5 | 1 | `Core_TKA.sqf:23-24` |
| `TK_Soldier_AAT_EP1` | 270 | 5 | 1 | `Core_TKA.sqf:26-27` |
| `TK_Soldier_HAT_EP1` | 1050 | 7 | 3 | `Core_TKA.sqf:29-30` |
| `TK_Soldier_AA_EP1` | 425 | 6 | 1 | `Core_TKA.sqf:32-33` |
| `TK_Soldier_AR_EP1` | 210 | 5 | 1 | `Core_TKA.sqf:35-36` |
| `TK_Soldier_AMG_EP1` | 205 | 5 | 0 | `Core_TKA.sqf:38-39` |
| `TK_Soldier_MG_EP1` | 220 | 5 | 1 | `Core_TKA.sqf:41-42` |
| `TK_Soldier_GL_EP1` | 160 | 5 | 0 | `Core_TKA.sqf:44-45` |
| `TK_Soldier_Sniper_EP1` | 280 | 5 | 1 | `Core_TKA.sqf:47-48` |
| `TK_Soldier_SniperH_EP1` | 320 | 5 | 3 | `Core_TKA.sqf:50-51` |
| `TK_Soldier_Spotter_EP1` | 290 | 5 | 1 | `Core_TKA.sqf:53-54` |
| `TK_Soldier_Medic_EP1` | 190 | 4 | 0 | `Core_TKA.sqf:56-57` |
| `TK_Soldier_Crew_EP1` | 120 | 4 | 0 | `Core_TKA.sqf:59-60` |
| `TK_Soldier_Pilot_EP1` | 120 | 4 | 0 | `Core_TKA.sqf:62-63` |
| `TK_Soldier_Officer_EP1` | 240 | 5 | 1 | `Core_TKA.sqf:65-66` |
| `TK_Soldier_SL_EP1` | 220 | 5 | 2 | `Core_TKA.sqf:68-69` |

Note: `TK_Soldier_TWS_EP1` (thermal sight soldier) is added to the TKA Barracks pool only when `WFBE_C_GAMEPLAY_THERMAL_IMAGING` is 1 or 3 (`Units_OA_TKA.sqf:4-5,9-11`).

#### Light Vehicles

| Class | Cost | Build (s) | Upgrade req | Source |
|-------|------|-----------|-------------|--------|
| `TT650_TK_EP1` | 150 | 15 | 0 | `Core_TKA.sqf:72-73` |
| `UAZ_Unarmed_TK_EP1` | 260 | 15 | 0 | `Core_TKA.sqf:75-76` |
| `SUV_TK_EP1` | 290 | 15 | 1 | `Core_TKA.sqf:78-79` |
| `UAZ_MG_TK_EP1` | 460 | 15 | 1 | `Core_TKA.sqf:81-82` |
| `UAZ_AGS30_TK_EP1` | 685 | 15 | 1 | `Core_TKA.sqf:84-85` |
| `LandRover_MG_TK_EP1` | 550 | 17 | 1 | `Core_TKA.sqf:87-88` |
| `LandRover_SPG9_TK_EP1` | 920 | 17 | 2 | `Core_TKA.sqf:90-91` |
| `V3S_TK_EP1` | 375 | 20 | 1 | `Core_TKA.sqf:93-94` |
| `V3S_Open_TK_EP1` | 350 | 20 | 1 | `Core_TKA.sqf:96-97` |
| `UralRepair_TK_EP1` | 2500 | 17 | 2 | `Core_TKA.sqf:99-100` |
| `UralSalvage_TK_EP1` | 750 | 17 | 1 | `Core_TKA.sqf:102-103` |
| `UralReammo_TK_EP1` | 1750 | 18 | 1 | `Core_TKA.sqf:105-106` |
| `UralRefuel_TK_EP1` | 500 | 19 | 1 | `Core_TKA.sqf:108-109` |
| `UralSupply_TK_EP1` | 450 | 21 | 0 | `Core_TKA.sqf:111-112` |
| `M113Ambul_TK_EP1` | 4800 | 25 | 2 | `Core_TKA.sqf:114-115` |
| `BRDM2_TK_EP1` | 1200 | 22 | 2 | `Core_TKA.sqf:117-118` |
| `BRDM2_ATGM_TK_EP1` | 1850 | 22 | 3 | `Core_TKA.sqf:120-121` |
| `BTR60_TK_EP1` | 1425 | 25 | 3 | `Core_TKA.sqf:123-124` |
| `Ural_ZU23_TK_EP1` | 1100 | 20 | 2 | `Core_TKA.sqf:126-127` |
| `GRAD_TK_EP1` | 6800 | 25 | 4 | `Core_TKA.sqf:129-130` |

#### Heavy Vehicles

| Class | Cost | Build (s) | Upgrade req | Source |
|-------|------|-----------|-------------|--------|
| `M113_TK_EP1` | 900 | 17 | 0 | `Core_TKA.sqf:133-134` |
| `BVP1_TK_ACR` | 2900 | 22 | 1 | `Core_TKA.sqf:136-137` |
| `BMP2_TK_EP1` | 3400 | 28 | 2 | `Core_TKA.sqf:139-140` |
| `ZSU_TK_EP1` | 3500 | 25 | 3 | `Core_TKA.sqf:142-143` |
| `T34_TK_EP1` | 1900 | 18 | 1 | `Core_TKA.sqf:145-146` |
| `T55_TK_EP1` | 3600 | 27 | 2 | `Core_TKA.sqf:148-149` |
| `T72_TK_EP1` | 5200 | 30 | 3 | `Core_TKA.sqf:151-152` |

#### Air Vehicles

| Class | Cost | Build (s) | Upgrade req | Source |
|-------|------|-----------|-------------|--------|
| `An2_TK_EP1` | 8265 | 30 | 1 | `Core_TKA.sqf:155-156` |
| `Mi17_TK_EP1` | 8800 | 30 | 1 | `Core_TKA.sqf:158-159` |
| `UH1H_TK_EP1` | 4992 | 25 | 0 | `Core_TKA.sqf:161-162` |
| `Mi24_D_TK_EP1` | 22580 | 40 | 3 | `Core_TKA.sqf:164-165` |
| `L39_TK_EP1` | 21904 | 40 | 3 | `Core_TKA.sqf:167-168` |
| `Su25_TK_EP1` | 31980 | 45 | 4 | Display: `'Su-25T'` `Core_TKA.sqf:170-171` |
| `Pchela1T` | 9000 | 35 | 1 | UAV `Core_TKA.sqf:245-246` |

#### Static Defenses (TKA)

| Class | Display name | Cost | Source |
|-------|-------------|------|--------|
| `WarfareBMGNest_PK_TK_EP1` | — | 300 | `Core_TKA.sqf:174-175` |
| `KORD_TK_EP1` | KORD Minitripod | 200 | `Core_TKA.sqf:177-178` |
| `KORD_high_TK_EP1` | KORD | 225 | `Core_TKA.sqf:180-181` |
| `SearchLight_TK_EP1` | — | 125 | `Core_TKA.sqf:183-184` |
| `AGS_TK_EP1` | — | 650 | `Core_TKA.sqf:186-187` |
| `SPG9_TK_INS_EP1` | — | 475 | `Core_TKA.sqf:189-190` |
| `Metis_TK_EP1` | Metis-M 9K115-2 | 1500 | `Core_TKA.sqf:192-193` |
| `Igla_AA_pod_TK_EP1` | Igla AA POD launcher | 3000 | `Core_TKA.sqf:195-196` |
| `ZU23_TK_EP1` | — | 945 | `Core_TKA.sqf:198-199` |
| `2b14_82mm_TK_EP1` | Podnos 2B14 | 1025 | `Core_TKA.sqf:201-202` |
| `D30_TK_EP1` | — | 2800 | `Core_TKA.sqf:204-205` |
| `TK_WarfareBVehicleServicePoint_Base_EP1` | — | 5500 | `Core_TKA.sqf:250-251` |

---

### Takistani Guerilla / TKGUE (Takistan, independent)

File: `Common/Config/Core/Core_TKGUE.sqf`. Faction tag: `'Takistani Guerilla'`.

#### Infantry

| Class | Cost | Skill | Upgrade req | Source |
|-------|------|-------|-------------|--------|
| `TK_GUE_Soldier_EP1` | 110 | 4 | 0 | `Core_TKGUE.sqf:8-9` |
| `TK_GUE_Soldier_2_EP1` | 120 | 4 | 0 | `Core_TKGUE.sqf:11-12` |
| `TK_GUE_Soldier_3_EP1` | 110 | 4 | 0 | `Core_TKGUE.sqf:14-15` |
| `TK_GUE_Soldier_4_EP1` | 100 | 5 | 0 | `Core_TKGUE.sqf:17-18` |
| `TK_GUE_Soldier_5_EP1` | 100 | 5 | 0 | `Core_TKGUE.sqf:20-21` |
| `TK_GUE_Soldier_AT_EP1` | 220 | 4 | 1 | `Core_TKGUE.sqf:23-24` |
| `TK_GUE_Soldier_AAT_EP1` | 210 | 4 | 2 | `Core_TKGUE.sqf:26-27` |
| `TK_GUE_Soldier_AA_EP1` | 270 | 4 | 2 | `Core_TKGUE.sqf:29-30` |
| `TK_GUE_Soldier_AR_EP1` | 190 | 5 | 1 | `Core_TKGUE.sqf:32-33` |
| `TK_GUE_Soldier_MG_EP1` | 200 | 6 | 0 | `Core_TKGUE.sqf:35-36` |
| `TK_GUE_Soldier_Sniper_EP1` | 180 | 5 | 1 | `Core_TKGUE.sqf:38-39` |
| `TK_GUE_Bonesetter_EP1` | 125 | 5 | 0 | Medic `Core_TKGUE.sqf:41-42` |
| `TK_GUE_Soldier_HAT_EP1` | 350 | 5 | 3 | `Core_TKGUE.sqf:44-45` |
| `TK_GUE_Soldier_TL_EP1` | 200 | 5 | 2 | `Core_TKGUE.sqf:47-48` |
| `TK_GUE_Warlord_EP1` | 210 | 5 | 1 | `Core_TKGUE.sqf:50-51` |

#### Light Vehicles

| Class | Cost | Build (s) | Upgrade req | Source |
|-------|------|-----------|-------------|--------|
| `V3S_TK_GUE_EP1` | 175 | 15 | 0 | `Core_TKGUE.sqf:54-55` |
| `Pickup_PK_TK_GUE_EP1` | 250 | 17 | 0 | `Core_TKGUE.sqf:57-58` |
| `Offroad_DSHKM_TK_GUE_EP1` | 300 | 25 | 1 | `Core_TKGUE.sqf:60-61` |
| `Offroad_SPG9_TK_GUE_EP1` | 380 | 20 | 2 | `Core_TKGUE.sqf:63-64` |
| `V3S_Repair_TK_GUE_EP1` | 425 | 17 | 2 | `Core_TKGUE.sqf:66-67` |
| `V3S_Salvage_TK_GUE_EP1` | 450 | 17 | 1 | `Core_TKGUE.sqf:69-70` |
| `V3S_Reammo_TK_GUE_EP1` | 450 | 18 | 1 | `Core_TKGUE.sqf:72-73` |
| `V3S_Refuel_TK_GUE_EP1` | 400 | 19 | 0 | `Core_TKGUE.sqf:75-76` |
| `V3S_Supply_TK_GUE_EP1` | 450 | 21 | 0 | `Core_TKGUE.sqf:78-79` |
| `BRDM2_TK_GUE_EP1` | 600 | 25 | 3 | `Core_TKGUE.sqf:81-82` |
| `BTR40_TK_GUE_EP1` | 650 | 25 | 1 | `Core_TKGUE.sqf:84-85` |
| `BTR40_MG_TK_GUE_EP1` | 800 | 25 | 2 | `Core_TKGUE.sqf:87-88` |
| `BTR40_TK_INS_EP1` | 650 | 25 | 1 | Insurgent-skinned `Core_TKGUE.sqf:90-91` |
| `BTR40_MG_TK_INS_EP1` | 800 | 25 | 2 | `Core_TKGUE.sqf:93-94` |
| `Ural_ZU23_TK_GUE_EP1` | 950 | 25 | 2 | `Core_TKGUE.sqf:96-97` |

#### Heavy Vehicles

| Class | Cost | Build (s) | Upgrade req | Source |
|-------|------|-----------|-------------|--------|
| `T34_TK_GUE_EP1` | 2400 | 30 | 1 | `Core_TKGUE.sqf:100-101` |
| `T55_TK_GUE_EP1` | 2800 | 35 | 2 | `Core_TKGUE.sqf:103-104` |

#### Air Vehicles

| Class | Cost | Build (s) | Upgrade req | Source |
|-------|------|-----------|-------------|--------|
| `UH1H_TK_GUE_EP1` | 12500 | 30 | 0 | `Core_TKGUE.sqf:107-108` |

#### Static Defenses (TKGUE)

| Class | Cost | Source |
|-------|------|--------|
| `SearchLight_TK_GUE_EP1` | 125 | `Core_TKGUE.sqf:111-112` |
| `WarfareBMGNest_PK_TK_GUE_EP1` | 300 | `Core_TKGUE.sqf:114-115` |
| `DSHkM_Mini_TriPod_TK_GUE_EP1` | 200 | `Core_TKGUE.sqf:117-118` |
| `DSHKM_TK_GUE_EP1` | 225 | `Core_TKGUE.sqf:120-121` |
| `AGS_TK_GUE_EP1` | 650 | `Core_TKGUE.sqf:123-124` |
| `SPG9_TK_GUE_EP1` | 475 | `Core_TKGUE.sqf:126-127` |
| `ZU23_TK_GUE_EP1` | 600 | `Core_TKGUE.sqf:129-130` |
| `2b14_82mm_TK_GUE_EP1` | 1025 | Podnos 2B14 `Core_TKGUE.sqf:132-133` |
| `D30_TK_GUE_EP1` | 2800 | `Core_TKGUE.sqf:135-136` |

---

## Factory Pool Variable Reference

The `Units_CO_<ID>.sqf` files publish six missionNamespace arrays per faction side:

| Variable | Contents | Source pattern |
|----------|----------|---------------|
| `WFBE_<side>BARRACKSUNITS` | Infantry classes shown in Barracks tab | `Units_CO_US.sqf:136` |
| `WFBE_<side>LIGHTUNITS` | Light vehicles (Light Factory tab) | `Units_CO_US.sqf:223` |
| `WFBE_<side>HEAVYUNITS` | Heavy vehicles (Heavy Factory tab) | `Units_CO_US.sqf:250` |
| `WFBE_<side>AIRCRAFTUNITS` | Helicopters + fixed-wing (Helipad tab) | `Units_CO_US.sqf:277` |
| `WFBE_<side>AIRPORTUNITS` | Fixed-wing only (Airport tab) | `Units_CO_US.sqf:290` |
| `WFBE_<side>DEPOTUNITS` | Civilian vehicles + optional town soldiers | `Units_CO_US.sqf:350` |

After publishing, the array is forwarded to `Client\Init\Init_Faction.sqf` for local player UI init (when `local player` is true). See [Factory-And-Purchase-Systems-Atlas](Factory-And-Purchase-Systems-Atlas) for how these arrays are consumed by the buy menu.

---

## Faction Comparison: Top-Tier Air Prices

| Faction | Costliest aircraft | Cost |
|---------|-------------------|------|
| USMC | `AH1Z` | 47632 |
| Russians | `Su34` | 41230 |
| USMC | `F35B` | 41330 |
| BAF | `BAF_Apache_AH1_D` | 39617 |
| Russians | `Ka52` (balancing OFF) | 75000 |
| Russians | `Ka52` (balancing ON) | 41880 |
| CDF | `Su25_CDF` | 42640 |

---

## Known Source Notes

- `INS_WarfareBVehicleServicePoint` and `CDF_WarfareBVehicleServicePoint` have their factionTag hardcoded to `'US'` — this is a source-level copy-paste issue (`Core_INS.sqf:177`, `Core_CDF.sqf:161`).
- `M113_UN_EP1` in `Core_GUE.sqf:109` uses faction tag `'Takistani Guerilla'` despite being in the Chernarus GUE config; the class shares the UN-skinned M113.
- The `GUE_Soldier_CO` is absent from `Units_GUE.sqf` (Barracks pool). It is in the Core pricing table but not exposed through the Chernarus GUE Barracks pool array. Cross-check before adding it to AI team templates.
- `GRAD_INS` carries upgrade level 5 (`Core_INS.sqf:122`), the highest of any GRAD variant. By contrast `GRAD_RU`, `GRAD_CDF`, and `GRAD_TK_EP1` are all at 3 or 4.

---

## Continue Reading

- [Factory-And-Purchase-Systems-Atlas](Factory-And-Purchase-Systems-Atlas) — how the buy menu reads these pools and processes purchases
- [Upgrades-And-Research-Atlas](Upgrades-And-Research-Atlas) — upgrade level definitions and research tree that gate the `upgradeLevel` column above
- [Economy-Towns-And-Supply](Economy-Towns-And-Supply) — how currency is earned and flows to faction budgets
- [Variable-And-Naming-Conventions](Variable-And-Naming-Conventions) — `WFBE_*` variable naming rules including the `WFBE_<side>BARRACKSUNITS` pattern
- [Gear-Loadout-And-EASA-Atlas](Gear-Loadout-And-EASA-Atlas) — how infantry loadouts are applied after purchase from these class lists
