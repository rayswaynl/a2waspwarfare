# Takistan Map Content Reference

> Source-verified 2026-06-21 against then-current master cf2a6d6a4; current origin/master is 0139a346, so recheck cited paths before current-head claims. Paths relative to Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/ unless noted. Paths prefixed `Common/` without a mission qualifier share source with Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/. Arma 2 OA 1.64.

## Mission Profile

| Property | Value | Source |
|---|---|---|
| Mission file | `[61-2hc]warfarev2_073v48co.takistan` | `folder name` |
| Slot count | 66 (`player="PLAY CDG"` entries) | `mission.sqm:58,80,…` |
| Total towns (`totalTowns`) | 31 | `mission.sqm:633` |
| Airport logic objects | 2 (`LocationLogicAirport`) | `mission.sqm:1241,1423` |
| Naval flag (`isNavalTerrain`) | `false` — no boat classes generated | `Tools/LoadoutManager/Data/Terrains/Implementations/VanillaMaps/TAKISTAN.cs:10` |
| Terrain type | `DESERT` | `Tools/LoadoutManager/Data/Terrains/Implementations/VanillaMaps/TAKISTAN.cs:6` |
| In-game map name | `takistan` | `Tools/LoadoutManager/Data/Terrains/Implementations/VanillaMaps/TAKISTAN.cs:9` |
| Boundary (`WFBE_BOUNDARIESXY`) | 12800 m | `Common/Init/Init_Boundaries.sqf:8` |
| Starting distance | 7500 m | `Tools/LoadoutManager/Data/Terrains/Implementations/VanillaMaps/TAKISTAN.cs:7` |
| Chernarus-map-dependent flag | `false` — `IS_CHERNARUS_MAP_DEPENDENT` is never defined in this mission | `initJIPCompatible.sqf:114-116` |
| Faction profile flag | `IS_Takistan_Faction_On_This_Map = true`, `IS_Russian_Faction_On_This_Map = false` | `initJIPCompatible.sqf:265-270` |
| Maintenance tier | Faithful generated target (see [Content Structure And Maps](Content-Structure-And-Maps)) | — |

## Faction Selection

At runtime `IS_chernarus_map_dependent` is `false` (the preprocessor define `IS_CHERNARUS_MAP_DEPENDENT` is absent), so the Takistan faction branch executes throughout shared `Common/` code.

| Side | Faction key | Faction index in `WFBE_C_UNITS_FACTIONS_*` | Source |
|---|---|---|---|
| WEST | `US` | 1 (`WFBE_C_UNITS_FACTION_WEST = 1`) | `Common/Init/Init_CommonConstants.sqf:413` |
| EAST | `TKA` | 2 (`WFBE_C_UNITS_FACTION_EAST = 2`) | `Common/Init/Init_CommonConstants.sqf:414` |
| GUER | `TKGUE` | 2 (`WFBE_C_UNITS_FACTION_GUER = 2`) | `Common/Init/Init_CommonConstants.sqf:415` |

Faction arrays: `WFBE_C_UNITS_FACTIONS_WEST = ['CDF','US','USMC']`, `WFBE_C_UNITS_FACTIONS_EAST = ['INS','RU','TKA']`, `WFBE_C_UNITS_FACTIONS_GUER = ['GUE','PMC','TKGUE']` (`Common/Init/Init_CommonConstants.sqf:403-405`).

Supply helicopter pool on Takistan: `WFBE_C_SUPPLY_HELI_TYPES = ['UH60M_EP1','Mi17_TK_EP1']` (WEST UH-60M / EAST Mi-17 TK). On Chernarus the pool is `['MH60S','Mi17_Ins']` (`Common/Init/Init_CommonConstants.sqf:181`).

## Resistance (GUER) Squad Templates

`Config_GUE.sqf` defines four resistance squad templates. The infantry templates use `TK_GUE_*_EP1` classnames specific to the Takistan resistance faction; the fourth template uses PMC classnames. The file ends by setting three vehicle-crew fallback variables that retain Chernarus-era `GUE_*` classnames — a known drift not corrected in master (`Server/Config/Config_GUE.sqf:86-88`).

| Template | Leader | Composition | Type index | Source |
|---|---|---|---|---|
| Infantry Squad | `TK_GUE_Warlord_EP1` | AR + 2× EP1 Soldier + Sniper + HAT + AT + AAT | 0 (Inf) | `Server/Config/Config_GUE.sqf:10-17` |
| Rifle Squad A | `TK_GUE_Warlord_EP1` | AR + 2× Soldier_2 + Sniper + HAT + AT + AAT | 0 (Inf) | `Server/Config/Config_GUE.sqf:28-35` |
| Rifle Squad B | `TK_GUE_Warlord_EP1` | AR + 2× Soldier_3 + Sniper + HAT + AT + AAT | 0 (Inf) | `Server/Config/Config_GUE.sqf:46-53` |
| Weapon Squad (PMC) | `Soldier_TL_PMC` | 3× AT + 2× Bodyguard_M4 + MG + AA | 0 (Inf) | `Server/Config/Config_GUE.sqf:64-71` |

**WFBE_GUERRESCREW / WFBE_GUERRESSOLDIER / WFBE_GUERRESPILOT drift:** These three variables are set to `GUE_Soldier_Crew`, `GUE_Soldier_1`, and `GUE_Soldier_Pilot` in both the Chernarus and Takistan `Config_GUE.sqf` files (`Server/Config/Config_GUE.sqf:86-88`). Takistan-equivalent classnames (`TK_GUE_Soldier_Crew`, etc.) are not used. Consumers that spawn individual resistance crew members will spawn Chernarus-faction models on Takistan.

## Airports

Two `LocationLogicAirport` objects are placed in the mission editor. No additional init string beyond `this enableSimulation false` is set on either; airport behaviour is governed by shared `Common/` code that reads `LocationLogicAirport` objects at runtime.

| # | Position (X, Z, Y) | Azimuth | Logic ID | Source |
|---|---|---|---|---|
| Airport 1 | 8191.4, 296.0, 1803.5 | 60° | 66 | `mission.sqm:1237-1245` |
| Airport 2 | 5689.9, 83.0, 11181.2 | 220° | 78 | `mission.sqm:1418-1426` |

No naval marker (`LocationLogicNaval`) exists in the Takistan mission — consistent with `isNavalTerrain = false`.

## Start Vehicles

One random vehicle is spawned per playable side from the respective pool at mission start. The pool is compiled from `WASP/unsort/StartVeh.sqf` at `Server/Init/Init_Server.sqf:306` and selected at `:430` (WEST) and `:447` (EAST). No GUER start vehicle pool exists in this file; the resistance side does not receive a random start vehicle.

### EAST (TKA) Pool — 11 vehicles

| Classname | Source line |
|---|---|
| `UAZ_MG_INS` | `WASP/unsort/StartVeh.sqf:2` |
| `UAZ_AGS30_RU` | `:3` |
| `UAZ_SPG9_INS` | `:4` |
| `BTR40_MG_TK_INS_EP1` | `:5` |
| `LandRover_MG_TK_EP1` | `:6` |
| `LandRover_SPG9_TK_EP1` | `:7` |
| `BRDM2_TK_EP1` | `:8` |
| `GAZ_Vodnik_HMG` | `:9` |
| `BTR60_TK_EP1` | `:10` |
| `Ural_ZU23_INS` | `:12` |
| `BTR90` | `:12` |

### WEST (US) Pool — 10 vehicles

| Classname | Source line |
|---|---|
| `M1126_ICV_M2_EP1` | `WASP/unsort/StartVeh.sqf:16` |
| `M1126_ICV_mk19_EP1` | `:17` |
| `M1129_MC_EP1` | `:18` |
| `M1135_ATGMV_EP1` | `:19` |
| `HMMWV_M1151_M2_DES_EP1` | `:20` |
| `HMMWV_M998_crows_MK19_DES_EP1` | `:21` |
| `HMMWV_TOW` | `:23` |
| `LAV25` | `:23` |
| `Pandur2_ACR` | `:24` |
| `BAF_Jackal2_L2A1_W` | `:25` |

## Town Catalog

All 31 towns are listed below in `mission.sqm` appearance order. Each `LocationLogicDepot` object passes these arguments to `Common\Init\Init_Town.sqf`: `[logic, displayName, dubbingName, startSV, maxSV, townValue, townTypeTemplate(s)]`.

`dubbingName = "+"` means no separate dubbing string is used (the display name is used as the dubbing identifier). Town-type templates determine the AI defense composition loaded by `Init_Town.sqf`; multiple templates means the engine picks one at runtime.

| # | Display name | Start SV | Max SV | Town value | Town type template(s) | `mission.sqm` line |
|---|---|---|---|---|---|---|
| 1 | Chak Chak | 20 | 80 | 800 | `LargeTown1`, `LargeTown2` | 800 |
| 2 | Huzrutimam | 10 | 50 | 600 | `MediumTown1`, `MediumTown2` | 894 |
| 3 | Landay | 10 | 40 | 400 | `SmallTown1` | 976 |
| 4 | Loy Manara | 30 | 120 | 1000 | `HugeTown1`, `HugeTown2` | 1021 |
| 5 | Sultansafee | 10 | 50 | 500 | `SmallTown1`, `SmallTown2` | 1103 |
| 6 | Jaza | 10 | 40 | 400 | `SmallTown1` | 1265 |
| 7 | Chardarakht | 10 | 50 | 500 | `MediumTown1`, `MediumTown2` | 1312 |
| 8 | Hazar Bagh | 10 | 30 | 400 | `SmallTown1` | 1382 |
| 9 | Chaman | 10 | 50 | 500 | `SmallTown1`, `SmallTown2` | 1447 |
| 10 | Shukurkalay | 10 | 60 | 600 | `MediumTown1`, `MediumTown2` | 1493 |
| 11 | Sakhee | 20 | 80 | 800 | `LargeTown1`, `LargeTown2` | 1575 |
| 12 | Jilavur | 10 | 50 | 500 | `SmallTown1`, `SmallTown2` | 1644 |
| 13 | Khushab | 10 | 50 | 500 | `SmallTown1`, `SmallTown2` | 1726 |
| 14 | Mulladoost | 10 | 60 | 600 | `MediumTown1`, `MediumTown2` | 1808 |
| 15 | Kakaru | 10 | 50 | 500 | `SmallTown1`, `SmallTown2` | 1890 |
| 16 | Anar | 10 | 50 | 500 | `SmallTown1`, `MediumTown1` | 1960 |
| 17 | Feeruz Abad | 30 | 120 | 1200 | `HugeTown1`, `HugeTown2` | 2041 |
| 18 | Timurkalay | 10 | 50 | 500 | `SmallTown1`, `SmallTown2` | 2123 |
| 19 | Falar | 10 | 50 | 600 | `MediumTown1`, `MediumTown2` | 2205 |
| 20 | Garmarud | 10 | 50 | 600 | `MediumTown1`, `MediumTown2` | 2287 |
| 21 | Garmsar | 30 | 120 | 1000 | `HugeTown1`, `HugeTown2` | 2368 |
| 22 | Imarat | 10 | 50 | 500 | `SmallTown1`, `SmallTown2`, `MediumTown1` | 2450 |
| 23 | Gospandi | 10 | 50 | 500 | `SmallTown1`, `SmallTown2` | 2532 |
| 24 | Ravanay | 10 | 40 | 400 | `SmallTown1` | 2602 |
| 25 | Karachinar | 10 | 40 | 500 | `SmallTown1`, `SmallTown2` | 2648 |
| 26 | Nur | 10 | 50 | 500 | `SmallTown1`, `SmallTown2` | 2706 |
| 27 | Zavarak | 20 | 80 | 800 | `LargeTown1`, `LargeTown2` | 2752 |
| 28 | Bastam | 20 | 70 | 800 | `LargeTown1`, `LargeTown2` | 2822 |
| 29 | Nagara | 30 | 120 | 1000 | `HugeTown1`, `HugeTown2` | 2927 |
| 30 | Rasman | 30 | 120 | 1000 | `HugeTown1`, `HugeTown2` | 3008 |
| 31 | Shamali | 10 | 40 | 500 | `SmallTown1`, `SmallTown2` | 3126 |

**Total `totalTowns` variable:** set to `31` on the `WF_Logic` object at `mission.sqm:633`. This is the source of truth used by `Init_TownMode.sqf`.

## Town Type Summary

| Type | Count | Start SV range | Max SV range | Town value range |
|---|---|---|---|---|
| `SmallTown1` only | 4 (Landay, Jaza, Hazar Bagh, Ravanay) | 10 | 30–40 | 400 |
| `SmallTown1`/`SmallTown2` (two templates) | 10 | 10 | 40–50 | 500 |
| `SmallTown1`/`MediumTown1` (mixed small/medium) | 1 (Anar) | 10 | 50 | 500 |
| `SmallTown1`, `SmallTown2`, `MediumTown1` (three templates) | 1 (Imarat) | 10 | 50 | 500 |
| `MediumTown1`/`MediumTown2` | 6 | 10 | 50–60 | 500–600 |
| `LargeTown1`/`LargeTown2` | 4 | 20 | 70–80 | 800 |
| `HugeTown1`/`HugeTown2` | 5 | 30 | 120 | 1000–1200 |

## Town Removal Lists (Town Mode)

The `WF_Logic` object at `mission.sqm:633` pre-populates four removal arrays used by `Init_TownMode.sqf` to subset active towns based on the `WFBE_C_TOWNS_AMOUNT` parameter. Towns are listed by their internal removal key (no spaces, camelCase).

| Mode | Removed towns (keys) | Active count |
|---|---|---|
| `XSmall` | FeeruzAbad, Nagara, Garmsar, Bastam, Zavarak, ChakChak, Sakhee, Garmarud, Falar, Chaman, Mulladoost, Nur, Karachinar, Rasman, Ravanay, Imarat, Shamali, Gospandi, Landay, Jaza, Timurkalay, Sultansafee, Shukurkalay, Jilavur, Khushab, Kakaru, Anar, HazarBagh | 3 |
| `Small` | FeeruzAbad, Garmsar, Zavarak, ChakChak, LoyManara, Sakhee, Garmarud, Falar, Chaman, Mulladoost, Chardarakht, Karachinar, Ravanay, Imarat, Landay, Jaza, Timurkalay, Huzrutimam, Sultansafee, Shukurkalay, Jilavur, Khushab, Kakaru, Anar, HazarBagh | 6 |
| `Medium` | FeeruzAbad, Garmsar, Zavarak, ChakChak, LoyManara, Sakhee, Chaman, Chardarakht, Nur, Karachinar, Ravanay, Landay, Jaza, Timurkalay, Huzrutimam, Sultansafee, Shukurkalay, Jilavur, Kakaru, Anar, HazarBagh | 10 |
| `Large` | Chaman, HazarBagh, Nur, Landay | 27 |

Source: `mission.sqm:633` (single line containing the `WF_Logic` init string).

Note: the `XSmall` row leaves only 3 active towns (31 − 28 removed). These are: Huzrutimam, Loy Manara, and Chardarakht (the three towns absent from the XSmall removal array at mission.sqm:633).

## Chernarus vs. Takistan Differences

Key differences relevant to cross-map development work:

| Property | Chernarus | Takistan | Source |
|---|---|---|---|
| Mission file | `[55-2hc]…chernarus` | `[61-2hc]…takistan` | folder names |
| Slot count | 34 (`player="PLAY CDG"` count in Chernarus `mission.sqm` — master Chernarus is an AI-vs-AI eval build with reduced slots) | 62 (`player="PLAY CDG"` count) | `mission.sqm` |
| `totalTowns` | 43 | 31 | `mission.sqm:3265` (Chernarus), `mission.sqm:633` (Takistan) |
| Boundary | 15360 m | 12800 m | `Common/Init/Init_Boundaries.sqf:5,8` |
| `IS_chernarus_map_dependent` | `true` | `false` | `initJIPCompatible.sqf:114-116` |
| WEST faction | `USMC` (index 2) | `US` (index 1) | `Common/Init/Init_CommonConstants.sqf:409,413` |
| EAST faction | `RU` (index 1) | `TKA` (index 2) | `Common/Init/Init_CommonConstants.sqf:410,414` |
| GUER faction | `GUE` (index 0) | `TKGUE` (index 2) | `Common/Init/Init_CommonConstants.sqf:411,415` |
| Supply helicopters | `MH60S`, `Mi17_Ins` | `UH60M_EP1`, `Mi17_TK_EP1` | `Common/Init/Init_CommonConstants.sqf:181` |
| Naval marker | Yes (Zodiac/PBX content) | No | `Tools/LoadoutManager/…/TAKISTAN.cs:10` |
| GUE resistance infantry | `GUE_Commander`, `GUE_Soldier_MG`, etc. | `TK_GUE_Warlord_EP1`, `TK_GUE_Soldier_AR_EP1`, etc. | `Server/Config/Config_GUE.sqf:10-17` |
| GUERRESCREW / GUERRESSOLDIER / GUERRESPILOT | `GUE_Soldier_Crew` / `GUE_Soldier_1` / `GUE_Soldier_Pilot` | same values (not updated to TK_GUE equivalents) — **known drift** | `Server/Config/Config_GUE.sqf:86-88` |
| GUE structure classnames | `Gue_WarfareBBarracks`, `Gue_WarfareBLightFactory`, … | `TK_GUE_WarfareBBarracks_EP1`, `TK_GUE_WarfareBLightFactory_EP1`, … | `Common/Config/Core_Structures/Structures_CO_GUE.sqf:8-10` |

## Continue Reading

- [Content Structure And Maps](Content-Structure-And-Maps) — mission folder layout, terrain support in LoadoutManager, and the generated-folder maintenance tier table.
- [Towns, Camps And Capture Atlas](Towns-Camps-And-Capture-Atlas) — town init chain (`Init_Town.sqf`), camp capture, `Init_TownMode.sqf`, server ownership loops, and economy consumers.
- [Economy, Towns And Supply](Economy-Towns-And-Supply) — supply value model, income loop, supply mission flow, and the income display/runtime mismatch.
- [Assets, Config, Localization And Parameters Atlas](Assets-Config-Localization-And-Parameters-Atlas) — parameters, stringtable, description.ext structure, and localization keys.
- [Variable And Naming Conventions](Variable-And-Naming-Conventions) — `WFBE_C_*`, `WFBE_UP_*`, and faction/index constant naming patterns.
