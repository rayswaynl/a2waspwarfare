# Upgrade Research Reference (cross-faction cost, level, and dependency tables)

> Source-verified 2026-06-21 against then-current master cf2a6d6a4; current origin/master is 0139a346, so recheck cited paths before current-head claims. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

Each faction has a dedicated upgrade config file under `Common/Config/Core_Upgrades/`. Every file sets five missionNamespace arrays (ENABLED, COSTS, LEVELS, LINKS, TIMES) and one AI_ORDER array, then calls `Check_Upgrades.sqf` to patch any gaps in the AI build order. The 23 array positions map to constants defined in `Common/Init/Init_CommonConstants.sqf:37-59`.

---

## 1. Upgrade Index (WFBE_UP_* constants)

| Idx | Constant | UI Label (from `Labels_Upgrades.sqf:54-78`) |
|-----|----------|----------------------------------------------|
| 0 | `WFBE_UP_BARRACKS` | Barracks |
| 1 | `WFBE_UP_LIGHT` | Light Factory |
| 2 | `WFBE_UP_HEAVY` | Heavy Factory |
| 3 | `WFBE_UP_AIR` | Aircraft Factory |
| 4 | `WFBE_UP_PARATROOPERS` | Paratroopers |
| 5 | `WFBE_UP_UAV` | UAV |
| 6 | `WFBE_UP_SUPPLYRATE` | Supply Rate |
| 7 | `WFBE_UP_RESPAWNRANGE` | Respawn Range |
| 8 | `WFBE_UP_AIRLIFT` | Airlift |
| 9 | `WFBE_UP_FLARESCM` | Countermeasures (Custom Flares) |
| 10 | `WFBE_UP_ARTYTIMEOUT` | Artillery Cooldown |
| 11 | `WFBE_UP_ICBM` | ICBM |
| 12 | `WFBE_UP_FASTTRAVEL` | Fast Travel |
| 13 | `WFBE_UP_GEAR` | Gear |
| 14 | `WFBE_UP_AMMOCOIN` | Build Ammo |
| 15 | `WFBE_UP_EASA` | EASA |
| 16 | `WFBE_UP_SUPPLYPARADROP` | Supply Paradrop |
| 17 | `WFBE_UP_ARTYAMMO` | Artillery Ammo |
| 18 | `WFBE_UP_IRSMOKE` | IR Smoke |
| 19 | `WFBE_UP_AIRAAM` | Aircraft AA Missiles |
| 20 | `WFBE_UP_AAR` | Anti-Air Radar |
| 21 | `WFBE_UP_UNITCOST` | Unit Cost Modifier |
| 22 | `WFBE_UP_PATROLS` | Patrols |

Sources: `Common/Init/Init_CommonConstants.sqf:37-59`, `Common/Config/Core_Upgrades/Labels_Upgrades.sqf:54-78`.

---

## 2. Per-Faction Availability and File Map

Each upgrade config file receives the faction string as `_this` (the `_side` parameter) and is called via `ExecVM` or `Call Compile preprocessFileLineNumbers` from the corresponding `Common/Config/Core_Root/Root_<faction>.sqf`. Example dispatch line: `Common/Config/Core_Root/Root_US.sqf:137`.

| File | Faction string (_side) | AAR (idx 20) purchasable? | Supply Lv3 cost | Build Ammo link |
|------|------------------------|--------------------------|-----------------|-----------------|
| `Upgrades_CO_US.sqf` | CO_US | **Yes** (LEVELS[20] = 2) | 8,000 | GEAR 5 |
| `Upgrades_CO_RU.sqf` | CO_RU | **Yes** (LEVELS[20] = 2) | 8,000 | GEAR 5 |
| `Upgrades_GUE.sqf` | GUE | **No** (LEVELS[20] = 0) | 6,000 | GEAR 2 |
| `Upgrades_CO_GUE.sqf` | CO_GUE | **No** (LEVELS[20] = 0) | 6,000 | GEAR 2 |
| `Upgrades_INS.sqf` | INS | **No** (LEVELS[20] = 0) | 6,000 | GEAR 2 |
| `Upgrades_CDF.sqf` | CDF | **No** (LEVELS[20] = 0) | 6,000 | GEAR 2 |
| `Upgrades_RU.sqf` | RU | **No** (LEVELS[20] = 0) | 6,000 | GEAR 2 |
| `Upgrades_OA_US.sqf` | OA_US | **No** (LEVELS[20] = 0) | 6,000 | GEAR 2 |
| `Upgrades_OA_TKA.sqf` | OA_TKA | **Yes** (LEVELS[20] = 2) | 6,000 | GEAR 2 |
| `Upgrades_OA_TKGUE.sqf` | OA_TKGUE | **No** (LEVELS[20] = 0) | 6,000 | GEAR 2 |
| `Upgrades_USMC.sqf` | USMC | **No** (LEVELS[20] = 0) | 6,000 | GEAR 2 |

**AAR disabled pattern**: AAR-disabled factions leave `ENABLED[20] = true` and `COSTS[20]` at real values (`[[5000,0],[12500,0]]`) but set `LEVELS[20] = 0`, which prevents any purchase. The index-21 slot (UNITCOST) uses cost `[999999,0]` as a guard (`Upgrades_GUE.sqf:54`) and `ENABLED[21] = false` (`Upgrades_GUE.sqf:27`) because UNITCOST is also disabled in those factions. The correct citation for AAR disable is `Upgrades_GUE.sqf:80` (LEVELS[20] = 0); `Upgrades_CO_US.sqf:80` shows the enabled form (LEVELS[20] = 2).

**Module-gated upgrades**: nine module-gated upgrade slots resolve their `ENABLED` value at runtime from module constants, not hardcoded booleans. See `Upgrades_CO_US.sqf:11-28` for the full pattern. The nine slots are: UAV (`WFBE_<side>UAV` nil-check), Custom Flares (`WFBE_C_MODULE_WFBE_FLARES == 1`), Artillery Timeout (`WFBE_C_ARTILLERY > 0`), ICBM (`WFBE_C_MODULE_WFBE_ICBM > 0`), Fast Travel (`WFBE_C_GAMEPLAY_FAST_TRAVEL > 0`), EASA (`WFBE_C_MODULE_WFBE_EASA > 0`), Artillery Ammo (`WFBE_C_ARTILLERY > 0`), IR Smoke (`WFBE_C_MODULE_WFBE_IRSMOKE > 0`), Aircraft AA Missiles (`WFBE_C_MODULE_WFBE_FLARES == 1` — same gate as Custom Flares). Custom Flares and Aircraft AA Missiles share one module gate.

---

## 3. Cost Tables (COSTS array — format `[cash, supply]`)

All faction files share costs for most upgrades; the two meaningful differences are **Supply Rate level 3** and **Build Ammo dependency**, documented in Section 2 above. The tables below show the exact COSTS arrays from source.

### 3a. CO_US / CO_RU (identical costs)

`Upgrades_CO_US.sqf:31-56`, `Upgrades_CO_RU.sqf:31-56`

| Upgrade | Lv 1 | Lv 2 | Lv 3 | Lv 4 | Lv 5 | Lv 6 |
|---------|------|------|------|------|------|------|
| Barracks | 540 | 1,350 | 2,070 | — | — | — |
| Light Factory | 250 | 950 | 1,900 | 3,500 | — | — |
| Heavy Factory | 1,200 | 4,400 | 9,500 | 10,500 | — | — |
| Aircraft Factory | 1,200 | 4,000 | 9,200 | 10,500 | 17,600 | — |
| Paratroopers | 1,500 | 2,500 | 3,500 | — | — | — |
| UAV | 2,000 | — | — | — | — | — |
| Supply Rate | 2,700 | 4,800 | **8,000** | — | — | — |
| Respawn Range | 500 | 1,500 | — | — | — | — |
| Airlift | 1,000 | — | — | — | — | — |
| Countermeasures | 4,500 | — | — | — | — | — |
| Artillery Cooldown | 800 | 1,400 | 2,200 | 3,700 | 6,100 | 10,000 |
| ICBM | 49,500 (+80,000 supply) | — | — | — | — | — |
| Fast Travel | 1,500 | — | — | — | — | — |
| Gear | 250 | 650 | 1,200 | 2,100 | 2,400 | — |
| Build Ammo | 750 | — | — | — | — | — |
| EASA | 4,000 | — | — | — | — | — |
| Supply Paradrop | 2,000 | — | — | — | — | — |
| Artillery Ammo | 2,500 | — | — | — | — | — |
| IR Smoke | 3,000 | 9,000 | — | — | — | — |
| Aircraft AA Missiles | 7,500 | — | — | — | — | — |
| Anti-Air Radar | 5,000 | 12,500 | — | — | — | — |
| Unit Cost Modifier | 25,000 | 50,000 | — | — | — | — |
| Patrols | 300 | 1,000 | 2,000 | — | — | — |

All costs are `[cash, 0]` except ICBM which costs `[49500, 80000]`. `Upgrades_CO_US.sqf:31-56`.

### 3b. GUE / CO_GUE / INS / CDF / RU / OA_US / OA_TKGUE / USMC (identical costs among these, AAR unavailable)

`Upgrades_GUE.sqf:31-56` (canonical; confirmed identical in CO_GUE, INS, CDF, RU, OA_US, OA_TKGUE, USMC)

Differs from CO_US/CO_RU in two cells:

| Upgrade | CO_US / CO_RU | GUE / INS / CDF / RU / OA_US / OA_TKGUE / USMC / CO_GUE |
|---------|---------------|-----------------------------------------------------------|
| Supply Rate Lv 3 | **8,000** | **6,000** |
| Anti-Air Radar Lv 1 | 5,000 | 5,000 *(costs present but LEVELS[20] = 0; upgrade unavailable)* |
| Anti-Air Radar Lv 2 | 12,500 | 12,500 *(idem)* |
| Unit Cost Modifier Lv 1 | 25,000 | *(guard — COSTS[21] = `[999999,0]`)* |

All other cost entries are identical to the CO_US table above. `Upgrades_GUE.sqf:38,53-54`.

### 3c. OA_TKA (unique: AAR enabled, Supply Lv3 at 6,000)

`Upgrades_OA_TKA.sqf:31-56`

OA_TKA is the only faction that combines AAR enabled (`ENABLED[20] = true`, costs 5,000 / 12,500) with the cheaper Supply Rate level 3 (6,000). All other cost values match the GUE/INS/etc. column above.

---

## 4. Max Levels (LEVELS array)

`Upgrades_CO_US.sqf:58-83` — these values are identical across all factions except where AAR is disabled (those factions set `LEVELS[20] = 0` and `LEVELS[21] = 0`).

| Upgrade | Max levels (all factions with upgrade enabled) | AAR-disabled factions |
|---------|------------------------------------------------|-----------------------|
| Barracks | 3 | 3 |
| Light Factory | 4 | 4 |
| Heavy Factory | 4 | 4 |
| Aircraft Factory | 5 | 5 |
| Paratroopers | 3 | 3 |
| UAV | 1 | 1 |
| Supply Rate | 3 | 3 |
| Respawn Range | 2 | 2 |
| Airlift | 1 | 1 |
| Countermeasures | 1 | 1 |
| Artillery Cooldown | 6 | 6 |
| ICBM | 1 | 1 |
| Fast Travel | 1 | 1 |
| Gear | 5 | 5 |
| Build Ammo | 1 | 1 |
| EASA | 1 | 1 |
| Supply Paradrop | 1 | 1 |
| Artillery Ammo | 1 | 1 |
| IR Smoke | 2 | 2 |
| Aircraft AA Missiles | 1 | 1 |
| **Anti-Air Radar** | **2** (CO_US, CO_RU, OA_TKA) | **0** (all others) |
| Unit Cost Modifier | 2 | 0 (same factions that have AAR unavailable) |
| Patrols | 3 | 3 |

**Disable mechanism differs between AAR and UNITCOST.** AAR (idx 20) is disabled in non-CO factions using only `LEVELS[20] = 0` (`Upgrades_GUE.sqf:80`); `ENABLED[20]` remains `true` and `COSTS[20]` holds real values. UNITCOST (idx 21) uses a full three-layer disable in those same factions: `ENABLED[21] = false` (`Upgrades_GUE.sqf:27`), `COSTS[21] = [[999999,0]]` (`Upgrades_GUE.sqf:54`), and `LEVELS[21] = 0` (`Upgrades_GUE.sqf:81`). The note "same disable pattern" in older documentation is inaccurate — they share only the LEVELS = 0 layer.

---

## 5. Research Times (TIMES array, in seconds)

Two distinct time profiles exist. CO_US and CO_RU share the same faster progression for some upgrades; all other factions share the second profile.

`Upgrades_CO_US.sqf:120-145`, `Upgrades_GUE.sqf:120-145`

| Upgrade | CO_US / CO_RU | All other factions |
|---------|---------------|--------------------|
| Barracks | 30 / 60 / 90 s | 30 / 60 / 90 s |
| Light Factory | 40 / **70** / **100** / **130** s | 40 / **60** / **80** / **100** s |
| Heavy Factory | 30 / **50** / **80** / **100** s | 50 / **70** / **90** / **110** s |
| Aircraft Factory | 60 / **80** / **100** / **120** / **140** s | 60 / **75** / **90** / **105** / **120** s |
| Paratroopers | 35 / 55 / 75 s | 35 / 55 / 75 s |
| UAV | 60 s | 60 s |
| Supply Rate | 60 / 80 / 120 s | 60 / 80 / 120 s |
| Respawn Range | 30 / 60 / 90 s | 30 / 60 / 90 s |
| Airlift | 30 s | 30 s |
| Countermeasures | 100 s | 100 s |
| Artillery Cooldown | 40 / 70 / 100 / 130 / 160 / 190 s | 40 / 70 / 100 / 130 / 160 / 190 s |
| ICBM | 300 s | 300 s |
| Fast Travel | 60 s | 60 s |
| Gear | 25 / 50 / 75 / 100 / 125 s | 25 / 50 / 75 / 100 / 125 s |
| Build Ammo | 40 s | 40 s |
| EASA | 90 s | 90 s |
| Supply Paradrop | 50 s | 50 s |
| Artillery Ammo | 60 s | 60 s |
| IR Smoke | 120 / 180 s | 120 / 180 s |
| Aircraft AA Missiles | 120 s | 120 s |
| Anti-Air Radar | 50 / 125 s (CO_US/CO_RU); also 50/125 (OA_TKA) | 0 (padded, not shown) |
| Unit Cost Modifier | 120 / 200 s (CO_US/CO_RU); OA_TKA same | 0 (padded) |
| Patrols | 90 / 150 / 240 s | 90 / 150 / 240 s |

Bold entries mark where CO_US/CO_RU diverge from the other factions. The Heavy Factory sequence is notably reversed: CO_US/CO_RU are faster at early levels but level 1 takes only 30 s vs. 50 s for other factions. Light Factory and Aircraft Factory are slower in CO_US/CO_RU at high levels than the standard profile.

**Respawn Range note:** TIMES[7] contains three entries in source ([30,60,90]) but LEVELS[7] = 2 for all factions; the third time value (90 s) is padded and never reached.

---

## 6. Dependency Links (LINKS array)

Links are prerequisites: a given upgrade level cannot be purchased until all listed `[upgrade_index, level]` pairs are already owned. Format per entry: `[[WFBE_UP_X, lvl], ...]`. An empty inner array `[]` means no prerequisites for that level.

The two groupings below cover all meaningful link differences.

### 6a. CO_US and CO_RU — unique links

`Upgrades_CO_US.sqf:85-118`

| Upgrade | Level | Prerequisites |
|---------|-------|---------------|
| Barracks | 1 | GEAR 2 |
| Barracks | 2 | GEAR 3 |
| Barracks | 3 | GEAR 5 |
| Paratroopers | 1 | BARRACKS 1, AIR 1, GEAR 1 |
| Paratroopers | 2 | BARRACKS 2, AIR 2, GEAR 2 |
| Paratroopers | 3 | BARRACKS 3, AIR 3, GEAR 3 |
| UAV | 1 | AIR 2 |
| Respawn Range | 1 | LIGHT 1 |
| Respawn Range | 2 | *(none)* |
| Airlift | 1 | AIR 1 |
| Countermeasures | 1 | AIR 2 |
| ICBM | 1 | **AIR 5** |
| Fast Travel | 1 | LIGHT 1, SUPPLY 1 |
| **Build Ammo** | 1 | **GEAR 5** |
| EASA | 1 | AIR 1 |
| Supply Paradrop | 1 | AIRLIFT 1 |
| Artillery Ammo | 1 | GEAR 1, HEAVY 1 |
| IR Smoke | 1 | HEAVY 3 |
| IR Smoke | 2 | *(none)* |
| Aircraft AA Missiles | 1 | AIR 3 |
| Anti-Air Radar | 1 | *(none)* |
| Anti-Air Radar | 2 | *(none)* |
| Patrols | 1 | *(none)* |
| Patrols | 2 | LIGHT 1 |
| Patrols | 3 | HEAVY 2 |

### 6b. All other factions (GUE, CO_GUE, INS, CDF, RU, OA_US, OA_TKA, OA_TKGUE, USMC)

`Upgrades_GUE.sqf:85-118` (identical in all named files)

Differences from CO_US/CO_RU:

| Upgrade | Level | CO_US/CO_RU | Other factions |
|---------|-------|-------------|----------------|
| Heavy Factory | *all* | 3 entries `[[],[],[]]` | 4 entries `[[],[],[],[]]` *(same content but Heavy has 4 levels in array shape)* |
| **Build Ammo** | 1 | **GEAR 5** | **GEAR 2** |
| ICBM | 1 | AIR 5 | AIR 3 |

All other link entries are identical between the two groups. The lighter Build Ammo prerequisite (GEAR 2 vs. GEAR 5) makes ammo depot access notably cheaper to unlock for non-CO factions.

---

## 7. AI Commander Build Order (AI_ORDER array)

The AI commander follows the `WFBE_C_UPGRADES_<side>_AI_ORDER` array in sequence. `Check_Upgrades.sqf` appends any enabled levels missing from this list at runtime. `Check_Upgrades.sqf:1-41`.

Two distinct orders exist:

### 7a. CO_US and CO_RU AI order

`Upgrades_CO_US.sqf:148-185`

```
BARRACKS 1, GEAR 1, LIGHT 1, SUPPLY 1, BARRACKS 2, GEAR 2, LIGHT 2,
BARRACKS 3, LIGHT 3, RESPAWNRANGE 1, SUPPLY 2, HEAVY 1, HEAVY 2,
ARTYTIMEOUT 1, SUPPLY 3, HEAVY 3, ARTYTIMEOUT 2, GEAR 3,
RESPAWNRANGE 2, ARTYTIMEOUT 3, AIR 1, AIRLIFT 1, AIR 2,
FLARESCM 1, PARATROOPERS 1, PARATROOPERS 2, AIR 3, UAV 1,
PARATROOPERS 3, EASA 1, SUPPLYPARADROP 1, AIRAAM 1,
GEAR 4, LIGHT 4, AAR 1, AAR 2
```

Note: CO_US/CO_RU explicitly order RESPAWNRANGE 1 and 2 (lines 158, 167). There is no RESPAWNRANGE 3 for this faction (LEVELS[7] = 2); Check_Upgrades.sqf has nothing to append for that index. GEAR 4 and LIGHT 4 are at the tail of the explicit list; AAR 1 and AAR 2 are the final two entries.

### 7b. All other factions AI order

`Upgrades_GUE.sqf:148-182` (array content lines 149-181; line 182 is the closing `]];`) — identical in CO_GUE, INS, CDF, RU, OA_US, OA_TKA, OA_TKGUE, USMC

```
BARRACKS 1, GEAR 1, LIGHT 1, SUPPLY 1, BARRACKS 2, GEAR 2, LIGHT 2,
BARRACKS 3, LIGHT 3, RESPAWNRANGE 1, SUPPLY 2, HEAVY 1, HEAVY 2,
ARTYTIMEOUT 1, SUPPLY 3, HEAVY 3, ARTYTIMEOUT 2, GEAR 3,
RESPAWNRANGE 2, ARTYTIMEOUT 3, AIR 1, AIRLIFT 1, RESPAWNRANGE 3,
AIR 2, FLARESCM 1, PARATROOPERS 1, PARATROOPERS 2, AIR 3, UAV 1,
PARATROOPERS 3, EASA 1, SUPPLYPARADROP 1, AIRAAM 1
```

Key differences from CO_US/CO_RU:
- RESPAWNRANGE 3 is explicitly ordered (after AIRLIFT 1, before AIR 2).
- GEAR 4, LIGHT 4, AAR 1, AAR 2 are absent (AAR not available; Gear/Light level 4 left to Check_Upgrades.sqf auto-append).
- Total explicit entries: 33 vs. 36 for CO_US/CO_RU.

---

## 8. Cross-Faction Summary of Meaningful Differences

| Difference | CO_US, CO_RU | OA_TKA | GUE, CO_GUE, INS, CDF, RU, OA_US, OA_TKGUE, USMC |
|------------|-------------|--------|---------------------------------------------------|
| AAR enabled | Yes | Yes | No |
| AAR cost (Lv1/Lv2) | 5,000 / 12,500 | 5,000 / 12,500 | n/a |
| Supply Lv3 cost | **8,000** | 6,000 | **6,000** |
| Build Ammo prerequisite | **GEAR 5** | GEAR 2 | **GEAR 2** |
| ICBM prerequisite | **AIR 5** | AIR 3 | **AIR 3** |
| Light Factory research times (Lv2/3/4) | **70/100/130 s** | 60/80/100 s | **60/80/100 s** |
| Heavy Factory research times (Lv1/2/3/4) | **30/50/80/100 s** | 50/70/90/110 s | **50/70/90/110 s** |
| Aircraft Factory research times (Lv2/3/4/5) | **80/100/120/140 s** | 75/90/105/120 s | **75/90/105/120 s** |
| AI order includes AAR | Yes | No (Check_Upgrades patches if needed) | No |
| AI order includes RESPAWNRANGE 3 explicitly | No | Yes | Yes |
| Unit Cost Modifier (idx 21) enabled | Yes (max 2) | Yes (max 2) | No (max 0) |

Sources: `Upgrades_CO_US.sqf:31-145`, `Upgrades_GUE.sqf:31-145`, `Upgrades_OA_TKA.sqf:31-145`.

---

## 9. Array Encoding Notes for Developers

Each COSTS entry is `[[cash, supply], ...]` where supply is nearly always 0. The ICBM is the only upgrade with a non-zero supply component: `[49500, 80000]`. `Upgrades_CO_US.sqf:43`.

The `LINKS` array is parallel to `LEVELS`: one sub-array per upgrade, each sub-array containing one entry per level. A level entry is itself a flat array of `[upgrade_index, level]` pairs. An empty level entry means no prerequisites. `Upgrades_CO_US.sqf:85-118`.

AAR-disabled factions use a single-layer guard: `LEVELS[20] = 0` (`Upgrades_GUE.sqf:80`). `ENABLED[20]` remains `true` and `COSTS[20]` holds real values (`[[5000,0],[12500,0]]` — `Upgrades_GUE.sqf:53`); there is no `999999` guard on AAR. The `999999` cost and `ENABLED = false` belong to COSTS[21] / ENABLED[21] (the UNITCOST index-padding slot — `Upgrades_GUE.sqf:27,54`), which is a separate, fully disabled slot. LEVELS = 0 is sufficient to block research-menu display and purchase for AAR; no cost guard is required on that index.

When adding a new upgrade to any faction file, the array length must be consistent across ENABLED, COSTS, LEVELS, LINKS, and TIMES. `Check_Upgrades.sqf` will only auto-append missing AI_ORDER entries; it will not catch length mismatches in the other arrays.

---

## Continue Reading

- [Upgrades-And-Research-Atlas](Upgrades-And-Research-Atlas) — upgrade system mechanics, research loop, and how the WFBE_C_UPGRADES_* arrays are read at runtime
- [Economy-Towns-And-Supply](Economy-Towns-And-Supply) — supply income rates that the Supply Rate upgrade modifies
- [Gear-Loadout-And-EASA-Atlas](Gear-Loadout-And-EASA-Atlas) — EASA and Gear upgrade effects on loadout availability
- [Modules-Atlas](Modules-Atlas) — WFBE_C_MODULE_WFBE_* constants that gate ICBM, Flares, EASA, IR Smoke, and Aircraft AA Missiles upgrades
- [Commander-HQ-Lifecycle-Atlas](Commander-HQ-Lifecycle-Atlas) — how the commander accesses and spends the research budget
