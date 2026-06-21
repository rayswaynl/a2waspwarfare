# Defense Structures Catalog (per-faction classnames, prices, categories)

> Source-verified 2026-06-21 against then-current master cf2a6d6a4; current origin/master is 0139a346, so recheck cited paths before current-head claims. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

Every buildable static defense available in WASP Warfare, enumerated per faction with classname, price, category, and town-defense kind. The `_n` (name) array is always `''` for every entry across all factions — the engine auto-generates display names from the classname's CfgVehicles config.

---

## How Defenses Are Loaded

`Common/Init/Init_Common.sqf:299-301` loads three faction defense files at mission start, one per playable side, using the active faction index:

```sqf
Call Compile preprocessFileLineNumbers Format["Common\Config\Defenses\Defenses_%1.sqf",_grpWest];
Call Compile preprocessFileLineNumbers Format["Common\Config\Defenses\Defenses_%1.sqf",_grpEast];
Call Compile preprocessFileLineNumbers Format["Common\Config\Defenses\Defenses_%1.sqf",_grpRes];
```

`_grpWest/East/Res` are resolved from `WFBE_C_UNITS_FACTIONS_WEST/EAST/GUER` by the active faction index (`WFBE_C_UNITS_FACTION_WEST/EAST/GUER`). (`Common/Init/Init_CommonConstants.sqf:403-416`)

**Faction pools** (`Common/Init/Init_CommonConstants.sqf:403-405`):

| Side | Faction pool (index 0 → 1 → 2) |
|------|--------------------------------|
| WEST | `CDF`, `US`, `USMC` |
| EAST | `INS`, `RU`, `TKA` |
| GUER | `GUE`, `PMC`, `TKGUE` |

**Map-dependent defaults** (`Common/Init/Init_CommonConstants.sqf:408-416`):

| Map | WEST active | EAST active | GUER active |
|-----|-------------|-------------|-------------|
| Chernarus (`IS_chernarus_map_dependent = true`) | USMC (idx 2) | RU (idx 1) | GUE (idx 0) |
| Takistan (`IS_chernarus_map_dependent = false`) | US (idx 1) | TKA (idx 2) | TKGUE (idx 2) |

`IS_chernarus_map_dependent` is set in `initJIPCompatible.sqf:114-117`.

---

## Per-Faction Defense Catalogs

All entries have category `"Defense"`. The `Kind` column is the town-defense kind string used by `Config_Defenses_Towns.sqf`; an empty string means the item is excluded from town-defense spawning.

### US — `Common/Config/Defenses/Defenses_US.sqf`

Side: `WEST`. (`Defenses_US.sqf:7-8`)

| # | Classname | Price | Kind |
|---|-----------|------:|------|
| 1 | `WarfareBMGNest_M240_US_EP1` | $300 | `MGNest` |
| 2 | `SearchLight_US_EP1` | $50 | *(none)* |
| 3 | `M2HD_mini_TriPod_US_EP1` | $150 | *(none)* |
| 4 | `M2StaticMG_US_EP1` | $200 | `MG` |
| 5 | `MK19_TriPod_US_EP1` | $600 | `GL` |
| 6 | `TOW_TriPod_US_EP1` | $850 | `AT` |
| 7 | `Stinger_Pod_US_EP1` | $700 | `AA` |
| 8 | `M252_US_EP1` | $1,100 | *(none)* |
| 9 | `M119_US_EP1` | $1,800 | `Artillery` |

Source lines: `Defenses_US.sqf:17-69`

---

### RU — `Common/Config/Defenses/Defenses_RU.sqf`

Side: `EAST`. (`Defenses_RU.sqf:7-8`)

| # | Classname | Price | Kind |
|---|-----------|------:|------|
| 1 | `RU_WarfareBMGNest_PK` | $300 | `MGNest` |
| 2 | `SearchLight_RUS` | $50 | *(none)* |
| 3 | `KORD` | $150 | *(none)* |
| 4 | `KORD_high` | $200 | `MG` |
| 5 | `AGS_RU` | $600 | `GL` |
| 6 | `Metis` | $650 | `AT` |
| 7 | `Igla_AA_pod_East` | $700 | `AA` |
| 8 | `2b14_82mm` | $1,100 | *(none)* |
| 9 | `D30_RU` | $1,800 | `Artillery` |

Source lines: `Defenses_RU.sqf:17-69`

Note: RU AT price is $650 (Metis), not $850 like the US TOW.

---

### GUE — `Common/Config/Defenses/Defenses_GUE.sqf`

Side: `GUER`. (`Defenses_GUE.sqf:7-8`)

| # | Classname | Price | Kind |
|---|-----------|------:|------|
| 1 | `GUE_WarfareBMGNest_PK` | $300 | `MGNest` |
| 2 | `SearchLight_Gue` | $50 | *(none)* |
| 3 | `DSHKM_Gue` | $200 | `MG` |
| 4 | `SPG9_Gue` | $400 | `AT` |
| 5 | `ZU23_Gue` | $600 | `AA` |
| 6 | `2b14_82mm_GUE` | $1,100 | *(none)* |

Source lines: `Defenses_GUE.sqf:17-51`

**GUE has 6 entries, not 9.** It has no $150 light MG tripod, no $600 grenade launcher, and no artillery piece. The AA is `ZU23_Gue` (no `Igla`-equivalent). This is the shallowest defense catalog of all nine factions.

---

### PMC — `Common/Config/Defenses/Defenses_PMC.sqf`

Side: `GUER`. (`Defenses_PMC.sqf:7-8`)

| # | Classname | Price | Kind |
|---|-----------|------:|------|
| 1 | `WarfareBMGNest_PK_TK_GUE_EP1` | $300 | `MGNest` |
| 2 | `SearchLight_TK_GUE_EP1` | $50 | *(none)* |
| 3 | `DSHKM_TK_GUE_EP1` | $200 | `MG` |
| 4 | `AGS_TK_GUE_EP1` | $600 | `GL` |
| 5 | `SPG9_TK_GUE_EP1` | $400 | `AT` |
| 6 | `ZU23_TK_GUE_EP1` | $600 | `AA` |
| 7 | `2b14_82mm_TK_GUE_EP1` | $1,100 | *(none)* |
| 8 | `D30_TK_GUE_EP1` | $1,800 | `Artillery` |

Source lines: `Defenses_PMC.sqf:17-63`

PMC has 8 entries. Compared to GUE: adds a `GL`-kind AGS ($600) and the D30 artillery piece ($1,800). No $150 light tripod.

---

### USMC — `Common/Config/Defenses/Defenses_USMC.sqf`

Side: `WEST`. (`Defenses_USMC.sqf:7-8`)

| # | Classname | Price | Kind |
|---|-----------|------:|------|
| 1 | `USMC_WarfareBMGNest_M240` | $300 | `MGNest` |
| 2 | `SearchLight` | $50 | *(none)* |
| 3 | `M2HD_mini_TriPod` | $150 | *(none)* |
| 4 | `M2StaticMG` | $200 | `MG` |
| 5 | `MK19_TriPod` | $600 | `GL` |
| 6 | `TOW_TriPod` | $850 | `AT` |
| 7 | `Stinger_Pod` | $700 | `AA` |
| 8 | `M252` | $1,100 | *(none)* |
| 9 | `M119` | $1,800 | `Artillery` |

Source lines: `Defenses_USMC.sqf:17-69`

USMC mirrors the US weapon tier and price structure exactly; only classnames differ (vanilla A2 classes vs EP1-suffixed variants for US).

---

### TKA — `Common/Config/Defenses/Defenses_TKA.sqf`

Side: `EAST`. (`Defenses_TKA.sqf:7-8`)

| # | Classname | Price | Kind |
|---|-----------|------:|------|
| 1 | `WarfareBMGNest_PK_TK_EP1` | $300 | `MGNest` |
| 2 | `SearchLight_TK_EP1` | $50 | *(none)* |
| 3 | `KORD_TK_EP1` | $150 | *(none)* |
| 4 | `KORD_high_TK_EP1` | $200 | `MG` |
| 5 | `AGS_TK_EP1` | $600 | `GL` |
| 6 | `SPG9_TK_INS_EP1` | $400 | `AT` |
| 7 | `Metis_TK_EP1` | $650 | `AT` |
| 8 | `ZU23_TK_EP1` | $600 | `AA` |
| 9 | `Igla_AA_pod_TK_EP1` | $700 | `AA` |
| 10 | `2b14_82mm_TK_EP1` | $1,100 | *(none)* |
| 11 | `D30_TK_EP1` | $1,800 | `Artillery` |

Source lines: `Defenses_TKA.sqf:17-81`

**TKA has 11 entries — the largest catalog.** It carries two AT weapons (SPG9 $400 + Metis $650) and two AA weapons (ZU23 $600 + Igla $700), giving it the widest anti-armor and anti-air coverage of any faction.

---

### TKGUE — `Common/Config/Defenses/Defenses_TKGUE.sqf`

Side: `GUER` (file declares `_faction = "GUE"`). (`Defenses_TKGUE.sqf:7-8`)

| # | Classname | Price | Kind |
|---|-----------|------:|------|
| 1 | `WarfareBMGNest_PK_TK_GUE_EP1` | $300 | `MGNest` |
| 2 | `SearchLight_TK_GUE_EP1` | $50 | *(none)* |
| 3 | `DSHKM_TK_GUE_EP1` | $200 | `MG` |
| 4 | `AGS_TK_GUE_EP1` | $600 | `GL` |
| 5 | `SPG9_TK_GUE_EP1` | $400 | `AT` |
| 6 | `ZU23_TK_GUE_EP1` | $600 | `AA` |
| 7 | `2b14_82mm_TK_GUE_EP1` | $1,100 | *(none)* |
| 8 | `D30_TK_GUE_EP1` | $1,800 | `Artillery` |

Source lines: `Defenses_TKGUE.sqf:17-63`

TKGUE and PMC have identical classnames and prices — they share the TK GUE EP1 asset set. TKGUE declares `_faction = "GUE"`; PMC declares `_faction = "PMC"`. Both use side `"GUER"`. The distinction is the active faction index: TKGUE is GUER index 2 (active on Takistan map), PMC is GUER index 1.

---

### CDF — `Common/Config/Defenses/Defenses_CDF.sqf`

Side: `WEST`. (`Defenses_CDF.sqf:7-8`)

| # | Classname | Price | Kind |
|---|-----------|------:|------|
| 1 | `CDF_WarfareBMGNest_PK` | $300 | `MGNest` |
| 2 | `SearchLight_CDF` | $50 | *(none)* |
| 3 | `DSHkM_Mini_TriPod_CDF` | $150 | *(none)* |
| 4 | `DSHKM_CDF` | $200 | `MG` |
| 5 | `AGS_CDF` | $600 | `GL` |
| 6 | `SPG9_CDF` | $400 | `AT` |
| 7 | `ZU23_CDF` | $600 | `AA` |
| 8 | `2b14_82mm_CDF` | $1,100 | *(none)* |
| 9 | `D30_CDF` | $1,800 | `Artillery` |

Source lines: `Defenses_CDF.sqf:17-69`

CDF (a WEST faction) uses Eastern-origin weapon classes (DSHKM, AGS, SPG9, ZU23, D30). The $150 light tripod is `DSHkM_Mini_TriPod_CDF` (mixed-case K, matching the source literal). No Igla or TOW equivalent.

---

### INS — `Common/Config/Defenses/Defenses_INS.sqf`

Side: `EAST`. (`Defenses_INS.sqf:7-8`)

| # | Classname | Price | Kind |
|---|-----------|------:|------|
| 1 | `Ins_WarfareBMGNest_PK` | $300 | `MGNest` |
| 2 | `SearchLight_INS` | $50 | *(none)* |
| 3 | `DSHkM_Mini_TriPod` | $150 | *(none)* |
| 4 | `DSHKM_Ins` | $200 | `MG` |
| 5 | `AGS_Ins` | $600 | `GL` |
| 6 | `SPG9_Ins` | $400 | `AT` |
| 7 | `ZU23_Ins` | $600 | `AA` |
| 8 | `2b14_82mm_INS` | $1,100 | *(none)* |
| 9 | `D30_Ins` | $1,800 | `Artillery` |

Source lines: `Defenses_INS.sqf:17-69`

INS mirrors the CDF weapon tier and price structure exactly; classnames use `_Ins` suffix vs `_CDF`.

---

## Cross-Faction Comparison

### Entry count per faction

| Faction | Entries | Notes |
|---------|--------:|-------|
| US | 9 | Full US EP1 set |
| USMC | 9 | Vanilla A2 classes; same tier as US |
| RU | 9 | Full East set |
| CDF | 9 | Eastern weapons, WEST side |
| INS | 9 | Eastern weapons, EAST side |
| PMC | 8 | TK GUE EP1 set; has artillery, no $150 tripod |
| TKGUE | 8 | Identical classnames/prices to PMC |
| TKA | 11 | Largest catalog; dual AT + dual AA |
| GUE | 6 | Smallest catalog; no GL, no artillery |

### Price ladder by kind (all factions where present)

| Kind | US / USMC | RU | TKA | CDF / INS | GUE | PMC / TKGUE |
|------|-----------|----|-----|-----------|-----|-------------|
| MGNest | $300 | $300 | $300 | $300 | $300 | $300 |
| MG | $200 | $200 | $200 | $200 | $200 | $200 |
| GL | $600 | $600 | $600 | $600 | — | $600 |
| AT | $850 (TOW) | $650 (Metis) | $400 (SPG9) + $650 (Metis) | $400 (SPG9) | $400 (SPG9) | $400 (SPG9) |
| AA | $700 (Stinger) | $700 (Igla) | $600 (ZU23) + $700 (Igla) | $600 (ZU23) | $600 (ZU23) | $600 (ZU23) |
| Artillery | $1,800 | $1,800 | $1,800 | $1,800 | — | $1,800 |
| Mortar | $1,100 | $1,100 | $1,100 | $1,100 | $1,100 | $1,100 |
| Searchlight | $50 | $50 | $50 | $50 | $50 | $50 |
| Light tripod | $150 | $150 | $150 | $150 | — | — |

---

## Town-Defense Kind System

`Config_Defenses_Towns.sqf` runs **server-side only** for each faction at init time. It reads the `_c` (classnames) and `_k` (kinds) arrays and groups classnames by their non-empty kind string. The result is stored in `missionNamespace` under:

```
WFBE_<side>_Defenses_<kind>
```

For example, US produces `WFBE_WEST_Defenses_MGNest = ['WarfareBMGNest_M240_US_EP1']`. (`Common/Config/Config_Defenses_Towns.sqf:22`)

`Server_SpawnTownDefense.sqf` consults these variables to pick a random classname from a random kind when placing a defense at a captured town logic object. Critically, **spawning exits immediately if the active side is not `WFBE_C_GUER_ID`** (`Server/Functions/Server_SpawnTownDefense.sqf:18`), so the town-defense spawn system is **active only for the GUER side**. WEST and EAST build their town defenses through the player-facing construction menu, not via this auto-spawn path.

`Config_Defenses_Towns.sqf` also logs: `"Config_Defenses_Towns.sqf : [<side>] [<count>] Category defined."` (`Common/Config/Config_Defenses_Towns.sqf:24`).

---

## Dead Code Note

All nine faction files end with a commented-out line:

```sqf
// [_faction, _c, _n, _o, _t] Call Compile preprocessFile "Common\Config\Config_Defenses.sqf";
```

`Common/Config/Config_Defenses.sqf` does not exist in the repository. This call was planned but never implemented; a section header above the dead code (Defenses_US.sqf:74) labels this area 'Fortitications and rest' (sic — source typo); no MASH functionality exists in the file or the repo. (`Defenses_US.sqf:76` and equivalent in all faction files)

---

## Continue Reading

- [Construction-And-CoIn-Systems-Atlas](Construction-And-CoIn-Systems-Atlas) — how defenses are constructed by players, CoIn spending, and the build queue
- [Economy-Towns-And-Supply](Economy-Towns-And-Supply) — how towns are captured, income, and supply flow that funds defense purchases
- [Factory-And-Purchase-Systems-Atlas](Factory-And-Purchase-Systems-Atlas) — the broader purchase menu system that surfaces defenses to players
- [Upgrades-And-Research-Atlas](Upgrades-And-Research-Atlas) — research gates and upgrades that may unlock or affect defense capabilities
- [Variable-And-Naming-Conventions](Variable-And-Naming-Conventions) — `WFBE_C_*` and `WFBE_<side>_*` namespace conventions used by the defense config system
