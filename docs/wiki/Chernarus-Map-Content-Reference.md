# Chernarus Map Content Reference

> Source-verified 2026-06-21 against then-current master cf2a6d6a4; current origin/master is 0139a346, so recheck cited paths before current-head claims. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

Chernarus is the **authoritative source mission** — Takistan and all modded-terrain variants are generated from it by LoadoutManager. This page catalogs all Chernarus-specific content: map parameters, the 40 active towns with exact supply values, 3 airports, naval exclusives, faction indices, and start vehicle pools.

---

## Mission Parameters

| Parameter | Value | Source |
|---|---|---|
| World name | `chernarus` | Tools/LoadoutManager/Data/Terrains/Implementations/MainMap/CHERNARUS.cs:9 (`inGameMapName`); initJIPCompatible.sqf:28 logs it at runtime |
| Slot count (`WF_MAXPLAYERS`) | **55** | Tools/LoadoutManager/Data/Terrains/BaseTerrain.cs:162–163 (FOREST → 55) |
| Starting distance | **7500 m** | Tools/LoadoutManager/Data/Terrains/Implementations/MainMap/CHERNARUS.cs:7 |
| Boundary radius | **15360 m** | Common/Init/Init_Boundaries.sqf:5 |
| Terrain type | `FOREST` | Tools/LoadoutManager/Data/Terrains/Implementations/MainMap/CHERNARUS.cs:6 |
| Terrain mod status | `MAIN` (not modded) | Tools/LoadoutManager/Data/Terrains/Implementations/MainMap/CHERNARUS.cs:8 |
| `IS_naval_map` | **true** | initJIPCompatible.sqf:15–17; Tools/LoadoutManager/Data/Terrains/Implementations/MainMap/CHERNARUS.cs:10 (`isNavalTerrain = true`) |
| `IS_chernarus_map_dependent` | **true** | initJIPCompatible.sqf:114–116 |
| Game type | CTI | Rsc/Header.hpp:19 |

The `IS_NAVAL_MAP` and `IS_CHERNARUS_MAP_DEPENDENT` preprocessor defines are emitted unconditionally (no `//` comment prefix) for Chernarus by LoadoutManager's `version.sqf` generator. `IS_NAVAL_MAP` is emitted when `isNavalTerrain == true`; `IS_CHERNARUS_MAP_DEPENDENT` is emitted when terrain type is not `DESERT`. Both are guarded by `#ifdef` in `initJIPCompatible.sqf` (lines 16, 115).

---

## Chernarus Faction Indices

On Chernarus, `IS_chernarus_map_dependent` is true and the faction index assignments differ from Takistan. Set in Common/Init/Init_CommonConstants.sqf:408–416.

| Side | Variable | Index | Faction array element | Faction |
|---|---|---|---|---|
| WEST | `WFBE_C_UNITS_FACTION_WEST` | **2** | `WFBE_C_UNITS_FACTIONS_WEST[2]` | USMC |
| EAST | `WFBE_C_UNITS_FACTION_EAST` | **1** | `WFBE_C_UNITS_FACTIONS_EAST[1]` | RU |
| GUER | `WFBE_C_UNITS_FACTION_GUER` | **0** | `WFBE_C_UNITS_FACTIONS_GUER[0]` | GUE |

Faction arrays (`WFBE_C_UNITS_FACTIONS_WEST`, `_EAST`, `_GUER`) are set at Init_CommonConstants.sqf:403–405.

Supply helicopter types on Chernarus: `['MH60S','Mi17_Ins']` (WEST MH-60S, EAST Mi-17 Ins). Init_CommonConstants.sqf:181.

---

## Airports (3)

Three `LocationLogicAirport` logic objects are placed in `mission.sqm`. Positions are `[x, y, z]` in Arma world coordinates.

| Airport object (SQM id) | Position (x, z) | mission.sqm line |
|---|---|---|
| id=7 | 4550, 2280 (SW — Balota airstrip area) | mission.sqm:189–193 |
| id=8 | 4479, 10618 (NW — Zeleno/Vybor airfield area) | mission.sqm:207–212 |
| id=9 | 11812, 12623 (NE — Krasnostav airfield area) | mission.sqm:225–231 |

All three objects have `init="this setVariable [\"wfbe_skip_auto_hangar\",true,true];this enableSimulation false;"` — they set `wfbe_skip_auto_hangar` to `true` (broadcast globally) before disabling simulation.

---

## Naval Content (Chernarus-Exclusive)

Boats are added to unit pools under two separate guards. The initial `Zodiac` and `PBX` entries are gated on `IS_chernarus_map_dependent`; the additional pool entries for both sides are gated on `IS_naval_map`. On Chernarus both flags are true, so all rows are active; on Takistan and modded terrains neither flag is set.

| Class | Side | Condition | Source |
|---|---|---|---|
| `Zodiac` | WEST (USMC) | `IS_chernarus_map_dependent` | Common/Config/Core_Units/Units_CO_US.sqf:144 |
| `Zodiac` | WEST (USMC) — additional pool entries | `IS_naval_map` | Units_CO_US.sqf:307, :335 |
| `PBX` | EAST (RU) | `IS_chernarus_map_dependent` | Common/Config/Core_Units/Units_CO_RU.sqf:84 |
| `PBX` | EAST (RU) — additional pool entries | `IS_naval_map` | Units_CO_RU.sqf:261–262, :291–292 |

---

## Start Vehicle Pools

Defined in WASP/unsort/StartVeh.sqf:1–26. These are the vehicles each side can begin with; selection logic is elsewhere.

### WEST (`WEST_StartVeh`)

| Class |
|---|
| `M1126_ICV_M2_EP1` |
| `M1126_ICV_mk19_EP1` |
| `M1129_MC_EP1` |
| `M1135_ATGMV_EP1` |
| `HMMWV_M1151_M2_DES_EP1` |
| `HMMWV_M998_crows_MK19_DES_EP1` |
| `HMMWV_TOW` |
| `LAV25` |
| `Pandur2_ACR` |
| `BAF_Jackal2_L2A1_W` |

### EAST (`EAST_StartVeh`)

| Class |
|---|
| `UAZ_MG_INS` |
| `UAZ_AGS30_RU` |
| `UAZ_SPG9_INS` |
| `BTR40_MG_TK_INS_EP1` |
| `LandRover_MG_TK_EP1` |
| `LandRover_SPG9_TK_EP1` |
| `BRDM2_INS` |
| `BRDM2_ATGM_INS` |
| `GAZ_Vodnik_HMG` |
| `BTR60_TK_EP1` |
| `Ural_ZU23_INS` |
| `BTR90` |

Source: WASP/unsort/StartVeh.sqf:1–26.

---

## Town Catalog — All 40 Active Towns

Init call signature: `[logicObject, townName, dubbingName, startSV, maxSV, townValue, townTypeArray]`

- **startSV** — Supply value awarded on capture.
- **maxSV** — Maximum supply value the town can hold/generate.
- **townValue** — Base income-related value (funds contribution).
- **townType** — Defense template(s); governs which composition spawns to defend the town. A single string means one template; an array means a pool to pick from.
- **dubbingName** — Localization alias used for audio/text. `"+"` means use townName directly.

The `totalTowns` counter is set to **43** on the TownMode logic object (mission.sqm:3265). There are 43 `LocationLogicDepot` objects with `Init_Town.sqf` calls: the 40 regular towns catalogued below, plus three airfield depot logics — NWAF (id=304, mission.sqm:4811), NEAF (id=305, mission.sqm:4845), and Balota (id=306, mission.sqm:4879). These airfield depots use townType `["PMCAirfield"]` and dubbing name `"++"`. Pogorevka, Kozlovka, and Orlovets appear in `Towns_Removed*` pool arrays but have no placed `LocationLogicDepot` and are not counted in `totalTowns`.

| # | Town name | Dubbing name | Start SV | Max SV | Town value | Town type(s) | mission.sqm line |
|---|---|---|---|---|---|---|---|
| 1 | Kamenka | + | 10 | 45 | 300 | SmallTown1, SmallTown2 | :128 |
| 2 | Pavlovo | + | 10 | 45 | 250 | SmallTown1, SmallTown2 | :344 |
| 3 | Komarovo | + | 10 | 55 | 300 | MediumTown1, MediumTown2 | :414 |
| 4 | Zelenogorsk | + | 30 | 120 | 1000 | HugeTown1, HugeTown2 | :484 |
| 5 | Chernogorsk | + | 30 | 120 | 1000 | HugeTown1, HugeTown2 | :565 |
| 6 | Bor | + | 10 | 40 | 250 | SmallTown1, SmallTown2 | :679 |
| 7 | Nadezhdino | + | 10 | 50 | 300 | MediumTown1, MediumTown2 | :749 |
| 8 | Prigorodki | + | 10 | 30 | 100 | TinyTown1 | :819 |
| 9 | Pusta | + | 10 | 50 | 250 | SmallTown1, SmallTown2 | :877 |
| 10 | Elektrozavodsk | + | 30 | 120 | 1000 | HugeTown1, HugeTown2 | :946 |
| 11 | Kamyshovo | + | 10 | 40 | 200 | TinyTown1 | :1040 |
| 12 | Tulga | + | 10 | 40 | 100 | SmallTown1 | :1110 |
| 13 | Msta | + | 10 | 40 | 100 | SmallTown1 | :1156 |
| 14 | Staroye | + | 20 | 80 | 500 | LargeTown1, LargeTown2 | :1214 |
| 15 | Mogilevka | + | 20 | 100 | 500 | LargeTown1, LargeTown2 | :1296 |
| 16 | Shakhovka | + | 10 | 45 | 250 | TinyTown1 | :1390 |
| 17 | Guglovo | + | 10 | 55 | 250 | MediumTown1, MediumTown2 | :1461 |
| 18 | Novy Sobor | + | 10 | 65 | 300 | MediumTown1, MediumTown2 | :1531 |
| 19 | Vyshnoye | Vyshnoe | 10 | 60 | 250 | MediumTown1, MediumTown2 | :1624 |
| 20 | Pulkovo | + | 10 | 40 | 250 | SmallTown1, SmallTown2 | :1694 |
| 21 | Myshkino | + | 10 | 40 | 250 | TinyTown1, SmallTown1, SmallTown2 | :1764 |
| 22 | Pustoshka | + | 10 | 50 | 300 | SmallTown1, SmallTown2 | :1833 |
| 23 | Stary Sobor | + | 30 | 150 | 500 | HugeTown1, HugeTown2 | :1916 |
| 24 | Vybor | + | 10 | 50 | 250 | SmallTown1, SmallTown2 | :1998 |
| 25 | Lopatino | + | 20 | 80 | 500 | LargeTown1, LargeTown2 | :2068 |
| 26 | Kabanino | + | 10 | 65 | 300 | MediumTown1, MediumTown2, SmallTown2 | :2149 |
| 27 | Petrovka | + | 10 | 40 | 250 | SmallTown1, SmallTown2 | :2242 |
| 28 | Grishino | + | 20 | 80 | 500 | LargeTown1, LargeTown2 | :2312 |
| 29 | Gvozdno | + | 10 | 40 | 250 | SmallTown1, SmallTown2 | :2417 |
| 30 | Dolina | + | 10 | 50 | 250 | SmallTown1, SmallTown2 | :2499 |
| 31 | Solnichniy | + | 20 | 80 | 500 | LargeTown1, LargeTown2 | :2569 |
| 32 | Nizhnoye | + | 10 | 40 | 200 | TinyTown1, SmallTown2 | :2651 |
| 33 | Polana | + | 10 | 50 | 300 | MediumTown1, MediumTown2 | :2721 |
| 34 | Gorka | + | 20 | 80 | 500 | LargeTown1, LargeTown2 | :2803 |
| 35 | Dubrovka | + | 10 | 55 | 300 | MediumTown1, MediumTown2 | :2894 |
| 36 | Berezino | + | 30 | 120 | 1000 | HugeTown1, HugeTown2 | :2987 |
| 37 | Krasnostav | + | 30 | 120 | 1000 | HugeTown1, HugeTown2 | :3081 |
| 38 | Khelm | + | 10 | 45 | 100 | SmallTown1 | :3163 |
| 39 | Olsha | + | 10 | 30 | 100 | TinyTown1 | :3221 |
| 40 | Rogovo | + | 10 | 40 | 250 | SmallTown1, SmallTown2 | :4642 |

**Note on Vyshnoye (row 19):** the only town with a non-`"+"` dubbing name. The engine uses `"Vyshnoe"` for audio/text calls instead of the display name `"Vyshnoye"`. mission.sqm:1624.

---

## Town Supply-Value Summary by Category

| Category | Town type(s) | Start SV range | Max SV range | Town value | Count |
|---|---|---|---|---|---|
| Huge | HugeTown1, HugeTown2 | 30 | 120–150 | 1000 (or 500 for StarySobor) | 6 |
| Large | LargeTown1, LargeTown2 | 20 | 80–100 | 500 | 6 |
| Medium | MediumTown1, MediumTown2 | 10 | 50–65 | 250–300 | 7 (8 incl. Kabanino; see note) |
| Small | SmallTown1, SmallTown2 | 10 | 40–55 | 250–300 | 14 |
| Tiny | TinyTown1 (± SmallTown) | 10 | 30–45 | 100–250 | 6 |

Huge towns: Zelenogorsk, Chernogorsk, Elektrozavodsk, Stary Sobor, Berezino, Krasnostav. Stary Sobor differs — maxSV 150 but town value 500 (not 1000). mission.sqm:1916.

**Medium count note:** 7 towns have a type array of purely MediumTown1/2 (Komarovo, Nadezhdino, Guglovo, Novy Sobor, Vyshnoye, Polana, Dubrovka). Kabanino (mission.sqm:2149) carries a mixed type array `MediumTown1, MediumTown2, SmallTown2` and is counted separately; including it yields 8 towns with at least one Medium type.

---

## Town-Mode Pool Exclusion Lists

The TownMode logic object (mission.sqm:3265) defines `Towns_Removed*` arrays used at runtime to restrict which towns are eligible depending on the active town-mode setting. These are string names (matching `_townName` from Init_Town). Key lists:

| Variable | Purpose |
|---|---|
| `Towns_RemovedXSmall` | Towns excluded in XSmall mode (only largest towns active) |
| `Towns_RemovedSmall` | Towns excluded in Small mode |
| `Towns_RemovedMedium` | Towns excluded in Medium mode |
| `Towns_RemovedLarge` | Towns excluded in Large mode |
| `Towns_RemovedBigTowns` | The 12 highest-value towns (Huge + top Large); excluded to create smaller-scale games |
| `Towns_RemovedCentralLine` | Towns along the central corridor; excluded for edge-biased games |
| `Towns_RemovedSmallTowns` | Small/tiny towns excluded for high-value-only games |

Three names appear in these lists but have no `Init_Town.sqf` logic object: `Pogorevka`, `Kozlovka`, `Orlovets`. These are referenced in `Towns_Removed*` pool management but are not placed as active towns in the current mission and are not counted in `totalTowns`.

---

## Continue Reading

- [Content-Structure-And-Maps](Content-Structure-And-Maps) — how Chernarus is the source mission and Takistan is generated from it; map-selection flow
- [Economy-Towns-And-Supply](Economy-Towns-And-Supply) — supply value income math, town capture loop, and how `townValue`/`maxSV` drive economy
- [Factory-And-Purchase-Systems-Atlas](Factory-And-Purchase-Systems-Atlas) — how faction indices (USMC/RU/GUE) determine which buy lists are loaded
- [Assets-Config-Localization-And-Parameters-Atlas](Assets-Config-Localization-And-Parameters-Atlas) — LoadoutManager terrain configuration model and how `version.sqf` is generated
- [Upgrades-And-Research-Atlas](Upgrades-And-Research-Atlas) — upgrade trees that unlock aircraft (affects supply helicopter faction by map)
