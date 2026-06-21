# Auxiliary, Special-Forces and Civilian Unit Catalog (the non-primary `Core_*.sqf` unit sets)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

The [Faction Unit and Vehicle Roster Catalog](Faction-Unit-And-Vehicle-Roster-Catalog) covers the 11 primary faction rosters (`Core_US/USMC/RU/GUE/INS/CDF/PMC/BAF*/TKA/TKGUE`). It deliberately excludes a second group of `Common/Config/Core/Core_*.sqf` files that register *auxiliary special-forces, premium-armour and civilian* unit sets. This page catalogs those nine files: `Core_DeltaForce`, `Core_Spetsnaz`, `Core_KSK`, `Core_MVD`, `Core_FR`, `Core_ACR`, `Core_TKSF`, `Core_CIV`, `Core_TKCIV`.

Each file uses the **same builder pattern and 10-field metadata tuple** as the primary roster files: it appends class names to `_c` and metadata arrays to `_i`, then a `for '_z' …` loop calls `missionNamespace setVariable [_c select _z, _i select _z]` for every valid class. The tuple layout (per [Faction-Unit-And-Vehicle-Roster-Catalog](Faction-Unit-And-Vehicle-Roster-Catalog)) is:

```
[displayName, picture, cost, buildTime, crewSlots, upgradeLevel, factory, isInfantry, factionTag, extraSlots]
```

- **cost** (index 2) — purchase price.
- **buildTime** (index 3) — seconds for vehicles; skill tier (4–7) for infantry.
- **crewSlots** (index 4) — `-1` for infantry, `-2` triggers a config crew-slot lookup, or an explicit `[…]` seat array.
- **upgradeLevel** (index 5) — research level gate (`0` = none). See [Upgrades-And-Research-Atlas](Upgrades-And-Research-Atlas).
- **factory** (index 6) — pool selector: `0` Barracks, `1` Light, `2` Heavy, `3` Air; string tags (`'Fortification'`, `'Strategic'`, `'Defense'`) for structures.
- **isInfantry** (index 7) — `1` for `Man` class, `0` for vehicles/structures; civilians use the fractional weight `0.4`.
- **factionTag** (index 8) — UI grouping / side string.

---

## How these files are actually loaded — VERIFY THIS, it is not "unconditional"

The Core block is **not** loaded unconditionally. It sits inside a `switch (true)` whose only case is `WF_A2_CombinedOps` (`Common/Init/Init_Common.sqf:225-226`). The whole class-Core list runs only on the Combined-Operations branch (`Common/Init/Init_Common.sqf:244-263`):

```
switch (true) do {
    case WF_A2_CombinedOps: {
        ...
        /* Class Core */
        Call Compile preprocessFileLineNumbers 'Common\Config\Core\Core_ACR.sqf';   // :245
        ...
    };
};
```

Within that branch the load list is an **alphabetised set of explicit `Call Compile preprocessFileLineNumbers` lines**. Crucially, only **seven** of this page's nine files appear in it:

| File | Loaded? | Load line | Notes |
|------|---------|-----------|-------|
| `Core_ACR.sqf` | yes | `Common/Init/Init_Common.sqf:245` | |
| `Core_CIV.sqf` | yes | `Common/Init/Init_Common.sqf:250` | |
| `Core_FR.sqf` | yes | `Common/Init/Init_Common.sqf:251` | |
| `Core_MVD.sqf` | yes | `Common/Init/Init_Common.sqf:254` | |
| `Core_Spetsnaz.sqf` | yes | `Common/Init/Init_Common.sqf:257` | |
| `Core_TKCIV.sqf` | yes | `Common/Init/Init_Common.sqf:259` | |
| `Core_TKSF.sqf` | yes | `Common/Init/Init_Common.sqf:261` | |
| `Core_DeltaForce.sqf` | **NO** | — | Not in the load list; no `Call Compile`/`execVM` for it anywhere in the mission tree. |
| `Core_KSK.sqf` | **NO** | — | Same — never loaded anywhere in the mission tree. |

There is no `factionTag`-keyed or `Format[...]` dynamic load for these — the seven loaded files are literal hard-coded paths. (Contrast the per-side `Root_%1`/`Defenses_%1`/`Groups_%1` loads at `Common/Init/Init_Common.sqf:300-317`, which *are* tag-driven.) A whole-tree grep for `Core_DeltaForce`/`Core_KSK` returns only their own internal `diag_log` strings — no loader references them.

**Consequence:** `Core_DeltaForce.sqf` and `Core_KSK.sqf` never execute, so their `missionNamespace setVariable` registrations never happen. Their class names are not registered with WFBE pricing/metadata even though the classes exist:

- The Delta-Force class names ARE still consumed elsewhere — the US factory pool (`Common/Config/Core_Units/Units_CO_US.sqf:96-106`, `Units_OA_US.sqf:31-…`), the level-3 paratrooper drop (`Common/Config/Core_Root/Root_US.sqf:41`), and the skill module (`Client/Module/Skill/Skill_Init.sqf:14-17`). Because `Core_DeltaForce.sqf` never registers them, those references resolve against engine `CfgVehicles` defaults rather than the cost/level table below.
- The KSK class names (`GER_Soldier_*_EP1`) appear only in `Skill_Init.sqf:15,17` (`GER_Soldier_Scout_EP1`, `GER_Soldier_Medic_EP1`); the rest of the `Core_KSK` table is effectively dead data.

---

## Core_DeltaForce.sqf — US Delta Force (NOT loaded — dead file)

File: `Common/Config/Core/Core_DeltaForce.sqf` (64 lines; register loop at `:41-63`). All entries are infantry, `factionTag 'US Delta Force'`, factory `0`, upgradeLevel `3`, skill `6`.

> **Header mislabel:** line 1 is `/* Spetsnaz Configuration */` — a copy-paste leftover; this file configures Delta Force, not Spetsnaz (`Common/Config/Core/Core_DeltaForce.sqf:1`).

| Class | Cost | Skill | Upgrade req | factionTag | Source |
|-------|------|-------|-------------|------------|--------|
| `US_Delta_Force_EP1` | 300 | 6 | 3 | US Delta Force | `Core_DeltaForce.sqf:8-9` |
| `US_Delta_Force_TL_EP1` | 360 | 6 | 3 | US Delta Force | `Core_DeltaForce.sqf:11-12` |
| `US_Delta_Force_Medic_EP1` | 320 | 6 | 3 | US Delta Force | `Core_DeltaForce.sqf:14-15` |
| `US_Delta_Force_Assault_EP1` | 335 | 6 | 3 | US Delta Force | `Core_DeltaForce.sqf:17-18` |
| `US_Delta_Force_SD_EP1` | 345 | 6 | 3 | US Delta Force | `Core_DeltaForce.sqf:20-21` |
| `US_Delta_Force_MG_EP1` | 340 | 6 | 3 | US Delta Force | `Core_DeltaForce.sqf:23-24` |
| `US_Delta_Force_AR_EP1` | 330 | 6 | 3 | US Delta Force | `Core_DeltaForce.sqf:26-27` |
| `US_Delta_Force_Night_EP1` | 315 | 6 | 3 | US Delta Force | `Core_DeltaForce.sqf:29-30` |
| `US_Delta_Force_Marksman_EP1` | 320 | 6 | 3 | US Delta Force | `Core_DeltaForce.sqf:32-33` |
| `US_Delta_Force_M14_EP1` | 310 | 6 | 3 | US Delta Force | `Core_DeltaForce.sqf:35-36` |
| `US_Delta_Force_Air_Controller_EP1` | 350 | 6 | 3 | US Delta Force | `Core_DeltaForce.sqf:38-39` |

---

## Core_Spetsnaz.sqf — Russians Spetsnaz

File: `Common/Config/Core/Core_Spetsnaz.sqf` (52 lines; register loop at `:29-…`). Loaded at `Common/Init/Init_Common.sqf:257`. All entries infantry, `factionTag 'Russians Spetsnaz'`, factory `0`, skill `6`.

| Class | Cost | Skill | Upgrade req | factionTag | Source |
|-------|------|-------|-------------|------------|--------|
| `RUS_Soldier1` | 250 | 6 | 2 | Russians Spetsnaz | `Core_Spetsnaz.sqf:8-9` |
| `RUS_Soldier2` | 260 | 6 | 3 | Russians Spetsnaz | `Core_Spetsnaz.sqf:11-12` |
| `RUS_Soldier_GL` | 270 | 6 | 3 | Russians Spetsnaz | `Core_Spetsnaz.sqf:14-15` |
| `RUS_Soldier_Marksman` | 290 | 6 | 2 | Russians Spetsnaz | `Core_Spetsnaz.sqf:17-18` |
| `RUS_Soldier3` | 295 | 6 | 3 | Russians Spetsnaz | `Core_Spetsnaz.sqf:20-21` |
| `RUS_Soldier_TL` | 300 | 6 | 3 | Russians Spetsnaz | `Core_Spetsnaz.sqf:23-24` |
| `RUS_Soldier_Medic` | 300 | 6 | 3 | Russians Spetsnaz | `Core_Spetsnaz.sqf:26-27` |

---

## Core_KSK.sqf — German KSK (NOT loaded — dead file)

File: `Common/Config/Core/Core_KSK.sqf` (46 lines; register loop at `:23-…`). Header correctly reads `/* KSK Configuration */` (`Core_KSK.sqf:1`). **Not loaded anywhere** — table is dead data except `GER_Soldier_Scout_EP1` / `GER_Soldier_Medic_EP1`, referenced by the skill module (`Client/Module/Skill/Skill_Init.sqf:15,17`). All entries infantry, `factionTag 'KSK'`, factory `0`, upgradeLevel `2`, skill `6`.

| Class | Cost | Skill | Upgrade req | factionTag | Source |
|-------|------|-------|-------------|------------|--------|
| `GER_Soldier_MG_EP1` | 340 | 6 | 2 | KSK | `Core_KSK.sqf:8-9` |
| `GER_Soldier_Medic_EP1` | 325 | 6 | 2 | KSK | `Core_KSK.sqf:11-12` |
| `GER_Soldier_EP1` | 310 | 6 | 2 | KSK | `Core_KSK.sqf:14-15` |
| `GER_Soldier_Scout_EP1` | 345 | 6 | 2 | KSK | `Core_KSK.sqf:17-18` |
| `GER_Soldier_TL_EP1` | 355 | 6 | 2 | KSK | `Core_KSK.sqf:20-21` |

---

## Core_MVD.sqf — Russian MVD (Interior troops)

File: `Common/Config/Core/Core_MVD.sqf` (50 lines; register loop at `:27-…`). Loaded at `Common/Init/Init_Common.sqf:254`. All entries infantry, `factionTag 'MVD'`, factory `0`.

| Class | Cost | Skill | Upgrade req | Display name | factionTag | Source |
|-------|------|-------|-------------|--------------|------------|--------|
| `MVD_Soldier_GL` | 310 | 7 | 3 | (auto) | MVD | `Core_MVD.sqf:8-9` |
| `MVD_Soldier_MG` | 320 | 7 | 3 | (auto) | MVD | `Core_MVD.sqf:11-12` |
| `MVD_Soldier_Marksman` | 330 | 7 | 2 | (auto) | MVD | `Core_MVD.sqf:14-15` |
| `MVD_Soldier_AT` | 350 | 5 | 2 | `Rifleman (RPG-7 VR)` | MVD | `Core_MVD.sqf:18-19` |
| `MVD_Soldier_Sniper` | 350 | 7 | 3 | (auto) | MVD | `Core_MVD.sqf:21-22` |
| `MVD_Soldier_TL` | 360 | 7 | 3 | (auto) | MVD | `Core_MVD.sqf:24-25` |

---

## Core_FR.sqf — USMC Force Recon

File: `Common/Config/Core/Core_FR.sqf` (80 lines; register loop at `:57-…`). Loaded at `Common/Init/Init_Common.sqf:251`. All entries infantry, `factionTag 'USMC Force Recon'`, factory `0`, skill `6`. The block at `:42-55` is tagged `/* Infantry - Special Characters */` (named campaign characters, upgradeLevel `3`).

| Class | Cost | Skill | Upgrade req | factionTag | Source |
|-------|------|-------|-------------|------------|--------|
| `FR_GL` | 260 | 6 | 2 | USMC Force Recon | `Core_FR.sqf:8-9` |
| `FR_Corpsman` | 270 | 6 | 2 | USMC Force Recon | `Core_FR.sqf:11-12` |
| `FR_Commander` | 295 | 6 | 2 | USMC Force Recon | `Core_FR.sqf:14-15` |
| `FR_TL` | 285 | 6 | 2 | USMC Force Recon | `Core_FR.sqf:17-18` |
| `FR_Assault_R` | 280 | 6 | 2 | USMC Force Recon | `Core_FR.sqf:20-21` |
| `FR_Assault_GL` | 285 | 6 | 2 | USMC Force Recon | `Core_FR.sqf:23-24` |
| `FR_AR` | 290 | 6 | 2 | USMC Force Recon | `Core_FR.sqf:26-27` |
| `FR_R` | 300 | 6 | 2 | USMC Force Recon | `Core_FR.sqf:29-30` |
| `FR_Sapper` | 310 | 6 | 2 | USMC Force Recon | `Core_FR.sqf:32-33` |
| `FR_AC` | 320 | 6 | 2 | USMC Force Recon | `Core_FR.sqf:35-36` |
| `FR_Marksman` | 340 | 6 | 2 | USMC Force Recon | `Core_FR.sqf:38-39` |
| `FR_Cooper` (special) | 400 | 6 | 3 | USMC Force Recon | `Core_FR.sqf:42-43` |
| `FR_Miles` (special) | 300 | 6 | 3 | USMC Force Recon | `Core_FR.sqf:45-46` |
| `FR_OHara` (special) | 400 | 6 | 3 | USMC Force Recon | `Core_FR.sqf:48-49` |
| `FR_Rodriguez` (special) | 400 | 6 | 3 | USMC Force Recon | `Core_FR.sqf:51-52` |
| `FR_Sykes` (special) | 400 | 6 | 3 | USMC Force Recon | `Core_FR.sqf:54-55` |

---

## Core_ACR.sqf — Czech Army (ACR DLC: infantry, vehicles, premium armour)

File: `Common/Config/Core/Core_ACR.sqf` (135 lines; register loop at `:112-…`). Loaded at `Common/Init/Init_Common.sqf:245`. The largest of these files — it spans infantry, light vehicles, support trucks, premium capture-unlock armour, and aircraft. `factionTag 'Czech'` throughout.

### Infantry (factory `0`, skill `4`–`5`)

| Class | Cost | Skill | Upgrade req | Source |
|-------|------|-------|-------------|--------|
| `CZ_Soldier_Light_DES_EP1` | 125 | 4 | 0 | `Core_ACR.sqf:8-9` |
| `CZ_Soldier_DES_EP1` | 150 | 4 | 0 | `Core_ACR.sqf:11-12` |
| `CZ_Soldier_B_DES_EP1` | 150 | 4 | 0 | `Core_ACR.sqf:14-15` |
| `CZ_Soldier_AT_DES_EP1` | 310 | 5 | 0 | `Core_ACR.sqf:17-18` |
| `CZ_Soldier_AMG_DES_EP1` | 210 | 5 | 1 | `Core_ACR.sqf:20-21` |
| `CZ_Soldier_MG_DES_EP1` | 220 | 5 | 0 | `Core_ACR.sqf:23-24` |
| `CZ_Soldier_Sniper_EP1` | 280 | 5 | 1 | `Core_ACR.sqf:26-27` |
| `CZ_Special_Forces_GL_DES_EP1` | 290 | 5 | 3 | `Core_ACR.sqf:29-30` |
| `CZ_Special_Forces_MG_DES_EP1` | 310 | 5 | 3 | `Core_ACR.sqf:32-33` |
| `CZ_Special_Forces_DES_EP1` | 285 | 5 | 3 | `Core_ACR.sqf:35-36` |
| `CZ_Special_Forces_Scout_DES_EP1` | 305 | 5 | 3 | `Core_ACR.sqf:38-39` |
| `CZ_Special_Forces_TL_DES_EP1` | 310 | 5 | 3 | `Core_ACR.sqf:41-42` |
| `CZ_Soldier_Pilot_EP1` | 120 | 4 | 0 | `Core_ACR.sqf:44-45` |
| `CZ_Soldier_Office_DES_EP1` | 240 | 5 | 1 | `Core_ACR.sqf:47-48` |
| `CZ_Soldier_SL_DES_EP1` | 220 | 5 | 2 | `Core_ACR.sqf:50-51` |

### Light vehicles & support trucks (factory `1`)

| Class | Cost | Build (s) | Upgrade req | crewSlots | Source |
|-------|------|-----------|-------------|-----------|--------|
| `ATV_CZ_EP1` | 175 | 15 | 0 | -2 (auto) | `Core_ACR.sqf:54-55` |
| `HMMWV_M1151_M2_CZ_DES_EP1` | 850 | 20 | 1 | -2 (auto) | `Core_ACR.sqf:57-58` |
| `LandRover_CZ_EP1` | 275 | 18 | 1 | -2 (auto) | `Core_ACR.sqf:60-61` |
| `LandRover_Special_CZ_EP1` | 700 | 20 | 2 | -2 (auto) | `Core_ACR.sqf:63-64` |
| `Dingo_WDL_ACR` | 870 | 20 | 2 | -2 (auto) | `Core_ACR.sqf:66-67` |
| `Dingo_GL_Wdl_ACR` | 1050 | 21 | 2 | -2 (auto) | `Core_ACR.sqf:69-70` |
| `Dingo_DST_ACR` | 870 | 20 | 2 | -2 (auto) | `Core_ACR.sqf:72-73` |
| `Dingo_GL_DST_ACR` | 1050 | 21 | 2 | -2 (auto) | `Core_ACR.sqf:75-76` |
| `Pandur2_ACR` | 2650 | 25 | 3 | explicit `[true,false,2,0]` | `Core_ACR.sqf:78-79` |
| `T810_CZ_EP1` | 500 | 20 | 1 | -2 (auto) | `Core_ACR.sqf:82-83` |
| `T810_Repair_CZ_EP1` | 2500 | 22 | 2 | -2 (auto) | `Core_ACR.sqf:85-86` |
| `T810_Refuel_CZ_EP1` | 500 | 22 | 1 | -2 (auto) | `Core_ACR.sqf:88-89` |
| `T810_Ammo_CZ_EP1` | 1750 | 22 | 1 | -2 (auto) | `Core_ACR.sqf:91-92` |

### Premium capture-unlock armour & rocket artillery

| Class | Cost | Build (s) | Upgrade req | Factory | Source |
|-------|------|-----------|-------------|---------|--------|
| `T72M4CZ` | 7000 | 45 | 4 | 2 (Heavy) | `Core_ACR.sqf:95-96` |
| `RM70_ACR` | 6800 | 25 | 4 | 1 (Light) | `Core_ACR.sqf:99-100` |

These two are the ACR premium "capture-unlock" classes referenced from the per-faction `Root_*` files; the source tags them `ACR premium (capture-unlock)` at `Core_ACR.sqf:94,98`.

### Air vehicles (factory `3`)

| Class | Cost | Build (s) | Upgrade req | Source |
|-------|------|-----------|-------------|--------|
| `Mi171Sh_CZ_EP1` | 7600 | 35 | 1 | `Core_ACR.sqf:103-104` |
| `Mi24_D_CZ_ACR` | 39620 | 45 | 4 | `Core_ACR.sqf:106-107` |
| `Mi171Sh_rockets_CZ_EP1` | 24000 | 40 | 3 | airfield-exclusive gunship `Core_ACR.sqf:109-110` |

---

## Core_TKSF.sqf — Takistani Special Forces

File: `Common/Config/Core/Core_TKSF.sqf` (40 lines; register loop at `:17-…`). Loaded at `Common/Init/Init_Common.sqf:261`. All entries infantry, `factionTag 'Takistani Special Forces'`, factory `0`, upgradeLevel `2`, skill `6`.

| Class | Cost | Skill | Upgrade req | factionTag | Source |
|-------|------|-------|-------------|------------|--------|
| `TK_Special_Forces_EP1` | 280 | 6 | 2 | Takistani Special Forces | `Core_TKSF.sqf:8-9` |
| `TK_Special_Forces_TL_EP1` | 300 | 6 | 2 | Takistani Special Forces | `Core_TKSF.sqf:11-12` |
| `TK_Special_Forces_MG_EP1` | 305 | 6 | 2 | Takistani Special Forces | `Core_TKSF.sqf:14-15` |

---

## Core_CIV.sqf — Chernarus Civilians (workers, vehicles, base build menu)

File: `Common/Config/Core/Core_CIV.sqf` (233 lines; register loop at `:210-…`). Loaded at `Common/Init/Init_Common.sqf:250`. `factionTag 'Civilians'` throughout (one structure entry slips back to `'Civilians'` after a `'Takistani Civilians'` copy in TKCIV — see TKCIV note). This file is large because it also supplies the **base-build / fortification / AI-defense-position** menu entries (factory string tags). Worker infantry use `isInfantry` weight `0.4`.

### Worker infantry (factory `0`, isInfantry `0.4`)

| Class | Cost | Skill | Upgrade req | factionTag | Source |
|-------|------|-------|-------------|------------|--------|
| `Worker1` | 375 | 4 | 0 | Civilians | `Core_CIV.sqf:8-9` |
| `Worker2` | 375 | 4 | 0 | Civilians | `Core_CIV.sqf:11-12` |
| `Worker3` | 375 | 4 | 0 | Civilians | `Core_CIV.sqf:14-15` |
| `Worker4` | 375 | 4 | 0 | Civilians | `Core_CIV.sqf:17-18` |

### Civilian vehicles (factory `1`, crewSlots `-2`)

| Class | Cost | Build (s) | Source |
|-------|------|-----------|--------|
| `MMT_Civ` | 50 | 8 | `Core_CIV.sqf:21-22` |
| `TT650_Civ` | 100 | 12 | `Core_CIV.sqf:24-25` |
| `Tractor` | 150 | 15 | `Core_CIV.sqf:27-28` |
| `Lada1` | 175 | 18 | `Core_CIV.sqf:30-31` |
| `Lada2` | 175 | 18 | `Core_CIV.sqf:33-34` |
| `LadaLM` | 180 | 20 | `Core_CIV.sqf:36-37` |
| `SkodaBlue` | 190 | 17 | `Core_CIV.sqf:39-40` |
| `SkodaRed` | 190 | 17 | `Core_CIV.sqf:42-43` |
| `car_sedan` | 200 | 20 | `Core_CIV.sqf:45-46` |
| `car_hatchback` | 220 | 20 | `Core_CIV.sqf:48-49` |
| `datsun1_civil_1_open` | 250 | 22 | `Core_CIV.sqf:51-52` |
| `datsun1_civil_2_covered` | 250 | 22 | `Core_CIV.sqf:54-55` |
| `datsun1_civil_3_open` | 250 | 22 | `Core_CIV.sqf:57-58` |
| `VWGolf` | 270 | 23 | `Core_CIV.sqf:60-61` |
| `hilux1_civil_1_open` | 340 | 25 | `Core_CIV.sqf:63-64` |
| `hilux1_civil_2_covered` | 340 | 25 | `Core_CIV.sqf:66-67` |
| `V3S_Civ` | 380 | 22 | `Core_CIV.sqf:69-70` |
| `UralCivil` | 390 | 25 | `Core_CIV.sqf:72-73` |
| `Ikarus` | 420 | 25 | `Core_CIV.sqf:75-76` |
| `Smallboat_1` | 350 | 30 | `Core_CIV.sqf:78-79` |
| `Smallboat_2` | 350 | 30 | `Core_CIV.sqf:81-82` |
| `Fishing_Boat` | 800 | 30 | `Core_CIV.sqf:84-85` |
| `Mi17_Civilian` (factory `3`, Air) | 9000 | 35 | `Core_CIV.sqf:88-89` |

### Base-build / fortification / strategic / AI-defense entries (string factory tags)

These supply the civilian base-build menu — fortifications, spawn-point markers, and the AI-manned defensive positions (the display names encode the AI count). Selected entries (full list at `Core_CIV.sqf:91-202`):

| Class | Display name | Cost | Factory tag | Source |
|-------|--------------|------|-------------|--------|
| `Land_HBarrier3` | (auto) | 30 | Fortification | `Core_CIV.sqf:91-92` |
| `Sr_border` | `B SPAWNPOINT` | 15 | Strategic | `Core_CIV.sqf:117-118` |
| `HeliH` | `LF SPAWNPOINT` | 15 | Strategic | `Core_CIV.sqf:120-121` |
| `HeliHRescue` | `HF SPAWNPOINT` | 15 | Strategic | `Core_CIV.sqf:123-124` |
| `HeliHCivil` | `AF SPAWNPOINT` | 15 | Strategic | `Core_CIV.sqf:126-127` |
| `Sign_Danger` | `STR_WF_Minefield` (localized) | 1200 | Strategic | `Core_CIV.sqf:165-166` |
| `Land_Ind_BoardsPack1` | `AA Position (Light, 2 AI)` | 2500 | Defense | `Core_CIV.sqf:177-178` |
| `Land_CncBlock_Stripes` | `AA Position (Heavy, 4 AI)` | 4500 | Defense | `Core_CIV.sqf:180-181` |
| `Land_Barrel_sand` | `Artillery (Light, 1 AI)` | 2500 | Defense | `Core_CIV.sqf:183-184` |
| `Land_Ind_BoardsPack2` | `Artillery (Heavy, 4 AI)` | 5000 | Defense | `Core_CIV.sqf:186-187` |
| `Land_WoodenRamp` | `Mixed Position (Light, 2 AI)` | 2500 | Defense | `Core_CIV.sqf:189-190` |
| `RoadCone` | `Mixed Position (Heavy, 4 AI)` | 5000 | Defense | `Core_CIV.sqf:192-193` |
| `Paleta1` | `Base Wall - Straight` | 250 | Fortification | `Core_CIV.sqf:195-196` |
| `Land_Pneu` | `Site Clearance (10/tree)` | 0 | Strategic | `Core_CIV.sqf:206-207` |

The `Land_Pneu` site-clearance entry at `:206-207` is appended inside a conditional block (`:205+`), not at top level.

---

## Core_TKCIV.sqf — Takistani Civilians

File: `Common/Config/Core/Core_TKCIV.sqf` (148 lines; register loop at `:125-…`). Loaded at `Common/Init/Init_Common.sqf:259`. Header comment reads `/* CIV Configuration */` (`Core_TKCIV.sqf:1`), i.e. it shares the CIV header text. `factionTag 'Takistani Civilians'` for almost all entries; the `Land_Campfire` structure is mis-tagged `'Civilians'` (`Core_TKCIV.sqf:92-93`).

### Worker infantry (factory `0`, isInfantry `0.4`)

| Class | Cost | Skill | Upgrade req | Source |
|-------|------|-------|-------------|--------|
| `TK_CIV_Worker01_EP1` | 375 | 4 | 0 | `Core_TKCIV.sqf:8-9` |
| `TK_CIV_Worker02_EP1` | 375 | 4 | 0 | `Core_TKCIV.sqf:11-12` |

### Civilian vehicles (factory `1`, crewSlots `-2`)

| Class | Cost | Build (s) | Source |
|-------|------|-----------|--------|
| `Old_bike_TK_CIV_EP1` | 50 | 8 | `Core_TKCIV.sqf:15-16` |
| `Old_moto_TK_Civ_EP1` | 100 | 12 | `Core_TKCIV.sqf:18-19` |
| `TT650_TK_CIV_EP1` | 110 | 15 | `Core_TKCIV.sqf:21-22` |
| `Lada1_TK_CIV_EP1` | 175 | 18 | `Core_TKCIV.sqf:24-25` |
| `Lada2_TK_CIV_EP1` | 175 | 18 | `Core_TKCIV.sqf:27-28` |
| `Volha_1_TK_CIV_EP1` | 200 | 21 | `Core_TKCIV.sqf:30-31` |
| `Volha_2_TK_CIV_EP1` | 200 | 21 | `Core_TKCIV.sqf:33-34` |
| `VolhaLimo_TK_CIV_EP1` | 200 | 22 | `Core_TKCIV.sqf:36-37` |
| `LandRover_TK_CIV_EP1` | 250 | 24 | `Core_TKCIV.sqf:39-40` |
| `S1203_TK_CIV_EP1` | 320 | 20 | `Core_TKCIV.sqf:42-43` |
| `V3S_Open_TK_CIV_EP1` | 380 | 25 | `Core_TKCIV.sqf:45-46` |
| `Ural_TK_CIV_EP1` | 390 | 25 | `Core_TKCIV.sqf:48-49` |
| `Ikarus_TK_CIV_EP1` | 420 | 25 | `Core_TKCIV.sqf:51-52` |
| `An2_1_TK_CIV_EP1` (factory `3`, Air) | 10000 | 35 | `Core_TKCIV.sqf:55-56` |
| `An2_2_TK_CIV_EP1` (factory `3`, Air) | 10000 | 35 | `Core_TKCIV.sqf:58-59` |

### Fortification / strategic structures (string factory tags)

Takistan-asset variants of the CIV base-build set (`Core_TKCIV.sqf:62-114`). Selected entries:

| Class | Cost | Factory tag | Source |
|-------|------|-------------|--------|
| `Land_HBarrier3` | 30 | Fortification | `Core_TKCIV.sqf:62-63` |
| `Hedgehog_EP1` | 5 | Fortification | `Core_TKCIV.sqf:83-84` |
| `MASH_EP1` | 30 | Strategic | `Core_TKCIV.sqf:89-90` |
| `Land_fort_artillery_nest_EP1` | 65 | Fortification | `STR_WF_ArtilleryNest` (localized) `Core_TKCIV.sqf:98-99` |
| `Sign_Danger` | 1200 | Strategic | `STR_WF_Minefield` (localized) `Core_TKCIV.sqf:104-105` |
| `Concrete_Wall_EP1` | 30 | Fortification | `Core_TKCIV.sqf:110-111` |

> **Source quirk:** two TKCIV structure entries omit one tuple element, producing 9-field arrays instead of 10 — `Land_HBarrier5` (`Core_TKCIV.sqf:65-66`) and `Land_HBarrier_large` (`Core_TKCIV.sqf:68-69`) drop a leading `0` that their CIV counterparts (`Core_CIV.sqf:94-95,97-98`) include. WFBE's consumer tolerates this for fortifications, but the field positions shift for those two rows.

---

## Continue Reading

- [Faction-Unit-And-Vehicle-Roster-Catalog](Faction-Unit-And-Vehicle-Roster-Catalog) — the 11 primary faction rosters this page complements.
- [Factory-And-Purchase-Systems-Atlas](Factory-And-Purchase-Systems-Atlas) — how the factory pools and purchase menus consume these registered classes.
- [AI-Squad-Team-Templates-Catalog](AI-Squad-Team-Templates-Catalog) — buyable AI squads that draw on special-forces class names.
- [Faction-Root-Variables-Reference](Faction-Root-Variables-Reference) — per-faction `Root_*` variables, including the paratrooper tiers and capture-unlock classes referenced above.
- [Default-Gear-Template-Content-Catalog](Default-Gear-Template-Content-Catalog) — loadout templates assigned to these unit classes.
