# Eden (Everon) and Taviana Map Content Reference

> Source-verified 2026-06-21 against master 0139a346. Paths relative to the repo root (note each root: Tools/, Extension/, DiscordBot/, Modded_Missions/, or the Chernarus mission dir). Arma 2 OA 1.64.

Eden (Everon) and Taviana are the **only two modded-terrain forks that carry a tracked `mission.sqm`** (`Modded-Maps-Status-And-Content.md:49`; the other five modded folders have none). Each tracked `mission.sqm` hand-places a complete, terrain-specific content layer — a named-town roster, the `totalTowns` count, and the editor-placed `LocationLogicStart`/`Camp`/`Depot`/`Airport`/`Owner*` geometry — that diverges substantially from the Chernarus source mission they were forked from. This page catalogs that placement layer for both forks: the data that actually changes the playable map.

These are **modded-mission artifacts**, not runtime mission SQF. They are hand-edited copies of the Chernarus `mission.sqm` (a Real Virtuality mission editor file), excluded from the release archive (`Tools/LoadoutManager/ZipManager.cs:10`) and currently boot-incomplete (see [Modded-Maps-Status-And-Content](Modded-Maps-Status-And-Content)). The `Init_Town.sqf` / `Init_TownMode.sqf` / `Init_Boundaries.sqf` scripts these objects invoke are unchanged from Chernarus; only the **placement data baked into the `init=` strings and object positions** differs. That placement data is what this page documents.

---

## Fork Identity Blocks

Each fork's `class Intel` and `addOns[]` differ from Chernarus. Eden requires `sap_everon`; Taviana requires `tavi`; both add `PRACS_Molatian_MiG21` (the OPFOR MiG-21 gated by `IS_mod_map_dependent`, see [Modded-Maps-Status-And-Content](Modded-Maps-Status-And-Content)).

| Field | Eden (Everon) | Taviana | Source |
|---|---|---|---|
| `briefingName` | `[55] Warfare V48 Everon 1.01` | `[55] Warfare V48 Taviana 1.11` | eden/mission.sqm:25 · tavi/mission.sqm:25 |
| `briefingDescription` | `Map ported by Sgt.Ace . Scripting by Benny and Awesome&WASP + Miksuu` | `Map by -Martin-. Scripting by Benny and Awesome&WASP + Miksuu` | eden/mission.sqm:26 · tavi/mission.sqm:26 |
| Terrain addon (`addOns[]`) | `sap_everon` | `tavi` | eden/mission.sqm:7 · tavi/mission.sqm:7 |
| `resistanceWest` | 0 | 0 | eden/mission.sqm:27 · tavi/mission.sqm:27 |
| `year`/`month`/`day` | 2016 / 12 / 28 | 2016 / 12 / 28 | eden/mission.sqm:30–32 · tavi/mission.sqm:32–34 |
| `hour`/`minute` | 8 / 0 | 8 / 0 | eden/mission.sqm:33–34 · tavi/mission.sqm:35–36 |
| `startWeather`/`forecastWeather` | 0 / 0 (clear) | 0 / 0 (clear) | eden/mission.sqm:28–29 · tavi/mission.sqm:28,:30 |
| `randomSeed` | 10034581 | (present) | eden/mission.sqm:22 |
| `class Groups` `items=` | 88 | 116 | eden/mission.sqm:38 · tavi/mission.sqm:38 |

Paths in this section and below are relative to `Modded_Missions/`; the eden file is `Modded_Missions/[55-2hc]warfarev2_073v48co.eden/mission.sqm` and the tavi file is `Modded_Missions/[55-2hc]warfarev2_073v48co.tavi/mission.sqm` (brackets literal).

---

## Placement-Layer Divergence vs Chernarus

The `LocationLogic*` object families are the editor-placed geometry that defines where the game can start a base, place a camp, drop a depot, register an airport, and seat each faction's territory anchor. Counts below are exact `grep`-verified `vehicle="LocationLogic…"` tallies in each `mission.sqm`.

| Logic family | Eden | Taviana | Chernarus (source) | What it controls |
|---|---|---|---|---|
| `LocationLogicStart` | **9** | **11** | 19 | Candidate HQ/base start sites |
| `LocationLogicCamp` | **31** | **71** | 81 | Camp (forward-base) anchor points |
| `LocationLogicDepot` | **16** | **37** | 46 | Town/depot capture nodes |
| `LocationLogicAirport` | **1** | **3** | 3 | Airfield logic objects |
| `LocationLogicOwnerWest` | 1 | 1 | 1 | WEST territory anchor |
| `LocationLogicOwnerEast` | 1 | 1 | 1 | EAST territory anchor |
| `LocationLogicOwnerResistance` | **absent** | **absent** | 1 | GUER/Resistance anchor |
| `totalTowns` (TownMode logic) | **16** | **37** | 46 | Town counter / scaling |

Sources: Eden counts from `[55-2hc]warfarev2_073v48co.eden/mission.sqm` (`OwnerWest` id=106 :1772, `OwnerEast` id=107 :1791, `Airport` id=7 :193, `totalTowns` :1185); Taviana counts from `[55-2hc]warfarev2_073v48co.tavi/mission.sqm` (`OwnerWest` id=217, `OwnerEast` id=218, three airports id=7/8/9, `totalTowns` :2740); Chernarus baseline from `Missions/[55-2hc]warfarev2_073v48co.chernarus/mission.sqm` (`totalTowns` :3332, owner-Resistance logic present).

Two structural divergences stand out:

1. **No Resistance owner anchor.** Chernarus places a `LocationLogicOwnerResistance` logic; neither fork does. Both forks register only WEST and EAST territory anchors.
2. **`totalTowns` matches the placed `Init_Town` count exactly.** Eden has 16 `Init_Town.sqf` calls and `totalTowns=16`; Taviana has 37 and `totalTowns=37`. The Chernarus source has 46 of each. Both forks zero out every `Towns_Removed*` pool array (`[]`) on the TownMode logic, so no town-mode exclusion is configured — every placed town is always active (eden/mission.sqm:1185, tavi/mission.sqm:2740).

The `TownMode` logic also `ExecVM`s the **unchanged** `Common\Init\Init_TownMode.sqf`; only the inline `setVariable` payload (the `totalTowns` value and empty `Towns_Removed*` arrays) differs from Chernarus.

---

## Eden (Everon) Town Roster — 16 Towns

`Init_Town` call signature: `[logic, townName, dubbingName, startSV, maxSV, townValue, townType]` (see [Chernarus-Map-Content-Reference](Chernarus-Map-Content-Reference) for field semantics). All 16 Eden towns use dubbing name `"+"` (use town name directly). Every town name is Everon-specific (French place names), none shared with Chernarus.

| # | Town | Start SV | Max SV | Town value | Town type(s) | mission.sqm line |
|---|---|---|---|---|---|---|
| 1 | Tyrone | 10 | 50 | 150 | SmallTown1, MediumTown2 | :128 |
| 2 | Le Moule | 10 | 65 | 300 | MediumTown1, MediumTown2 | :254 |
| 3 | Chotain | 10 | 60 | 250 | SmallTown1, SmallTown2 | :324 |
| 4 | Saint Phillippe | 20 | 95 | 500 | LargeTown1, LargeTown2 | :392 |
| 5 | Provins | 10 | 60 | 200 | TinyTown1 | :474 |
| 6 | Entre Deux | 10 | 60 | 250 | SmallTown1, SmallTown2 | :545 |
| 7 | Durras | 10 | 60 | 250 | TinyTown1, SmallTown1, SmallTown2 | :615 |
| 8 | Levie | 10 | 50 | 100 | TinyTown1 | :685 |
| 9 | Montignac | 30 | 150 | 500 | HugeTown1, HugeTown2 | :756 |
| 10 | Morton | 20 | 100 | 200 | LargeTown1, LargeTown2 | :838 |
| 11 | Regina | 10 | 60 | 250 | SmallTown1, SmallTown2 | :920 |
| 12 | Lamentin | 20 | 100 | 250 | LargeTown1, LargeTown2 | :990 |
| 13 | Meaux | 10 | 70 | 300 | MediumTown1, MediumTown2 | :1071 |
| 14 | Gravette | 10 | 50 | 100 | SmallTown1 | :1141 |
| 15 | Saint Pierre | 20 | 80 | 300 | LargeTown1, LargeTown2 | :2563 |
| 16 | Figari | 10 | 50 | 200 | TinyTown1 | :2654 |

Only one Huge town (Montignac), and it carries town value 500 (not the Chernarus huge-town default of 1000). Eden is a deliberately smaller map than Chernarus: 16 towns vs 46.

### Eden start sites (9 `LocationLogicStart`)

| SQM id | Position (x, z) | mission.sqm line |
|---|---|---|
| 0 | 7254, 6826 | :42 (first Groups item) |
| 8 | 2852, 6434 | (start group) |
| 9 | 11108, 1681 | |
| 129 | 5127, 11743 | |
| 130 | 8872, 4423 | |
| 131 | 3499, 4464 | |
| 132 | 6517, 8650 | |
| 133 | 8199, 1980 | |
| 142 | 4260, 5851 | |

Positions are `[x, y, z]` Arma world coordinates from each start logic's `position[]`; (x, z) is the ground-plane pair. The single Eden airport logic (id=7) sits at 4843, 11864 (eden/mission.sqm:193 region); the WEST owner anchor (id=106) at 10901, 8811; the EAST owner anchor (id=107) at 10844, 8491 (eden/mission.sqm:1772, :1791) — the two faction anchors are ~320 m apart in the map's east-central area.

---

## Taviana Town Roster — 37 Towns

All 37 Taviana towns use dubbing name `"+"`. Names are Taviana-specific (Slavic/Russian place names), none shared with Chernarus or Eden. Taviana is the largest of the three by boundary (25600 m, `Init_Boundaries.sqf:14`) and second by town count.

| # | Town | Start SV | Max SV | Town value | Town type(s) | mission.sqm line |
|---|---|---|---|---|---|---|
| 1 | Kopech | 10 | 50 | 150 | SmallTown1, MediumTown2 | :130 |
| 2 | Komarovo | 10 | 55 | 300 | MediumTown1, MediumTown2 | :328 |
| 3 | Mitrovice | 30 | 150 | 1000 | HugeTown1, HugeTown2 | :398 |
| 4 | Sabina | 30 | 180 | 1000 | HugeTown1, HugeTown2 | :479 |
| 5 | Stari Sad | 10 | 50 | 250 | SmallTown1, SmallTown2 | :593 |
| 6 | Zhabinka | 10 | 30 | 100 | TinyTown1 | :663 |
| 7 | Bilgrad Na Moru | 30 | 150 | 1000 | HugeTown1, HugeTown2 | :709 |
| 8 | Marina | 10 | 40 | 200 | TinyTown1 | :803 |
| 9 | Vodice | 10 | 30 | 100 | SmallTown1 | :873 |
| 10 | Repkov | 10 | 30 | 100 | TinyTown1 | :919 |
| 11 | Topolka | 20 | 80 | 500 | LargeTown1, LargeTown2 | :977 |
| 12 | Martin | 20 | 80 | 500 | LargeTown1, LargeTown2 | :1059 |
| 13 | Polyanka | 10 | 30 | 100 | TinyTown1 | :1153 |
| 14 | Molotovsk | 20 | 100 | 500 | LargeTown1, LargeTown2 | :1224 |
| 15 | Novi Dvor | 10 | 50 | 250 | SmallTown1, SmallTown2 | :1318 |
| 16 | Vedich | 10 | 50 | 150 | TinyTown1, SmallTown1, SmallTown2 | :1388 |
| 17 | Duge Salo | 10 | 30 | 100 | TinyTown1 | :1458 |
| 18 | Byelov | 30 | 120 | 500 | HugeTown1, HugeTown2 | :1541 |
| 19 | Boye | 10 | 50 | 250 | SmallTown1, SmallTown2 | :1623 |
| 20 | Seven | 20 | 90 | 500 | LargeTown1, LargeTown2 | :1693 |
| 21 | Khotanovsk | 10 | 30 | 100 | TinyTown1 | :1774 |
| 22 | Branibor | 30 | 180 | 1000 | HugeTown1, HugeTown2 | :1844 |
| 23 | Novy Bor | 10 | 50 | 250 | SmallTown1, SmallTown2 | :1950 |
| 24 | Dalnogorsk | 10 | 50 | 250 | SmallTown1, SmallTown2 | :2032 |
| 25 | Etanovsk | 20 | 90 | 500 | LargeTown1, LargeTown2 | :2102 |
| 26 | Gorka | 10 | 55 | 200 | TinyTown1, SmallTown2 | :2183 |
| 27 | Solibor | 20 | 80 | 500 | LargeTown1, LargeTown2 | :2253 |
| 28 | Chernovar | 20 | 90 | 300 | LargeTown1, LargeTown2 | :2335 |
| 29 | Dubovo | 10 | 65 | 300 | MediumTown1, MediumTown2 | :2426 |
| 30 | Lyepestok | 30 | 180 | 1000 | HugeTown1, HugeTown2 | :2519 |
| 31 | Krasnoznamen'sk | 30 | 150 | 1000 | HugeTown1, HugeTown2 | :2614 |
| 32 | Kameni | 10 | 40 | 100 | SmallTown1 | :2696 |
| 33 | Vinograd | 10 | 50 | 300 | MediumTown1, MediumTown2 | :4118 |
| 34 | Ekaterinburg | 30 | 120 | 1000 | HugeTown1, HugeTown2 | :4187 |
| 35 | Lyobol' | 10 | 60 | 300 | SmallTown1, MediumTown1, MediumTown2 | :4269 |
| 36 | Chrveni Gradok | 20 | 90 | 300 | LargeTown1, LargeTown2 | :4339 |
| 37 | Sevastopol' | 20 | 100 | 500 | LargeTown1, LargeTown2 | :4453 |

Taviana carries 8 Huge towns (Mitrovice, Sabina, Bilgrad Na Moru, Byelov, Branibor, Lyepestok, Krasnoznamen'sk, Ekaterinburg) — several with `maxSV=180`, the highest max-supply value of any town on any of the three maps (Chernarus huge towns cap at 150). Three towns use apostrophe-bearing transliterated names (`Krasnoznamen'sk`, `Lyobol'`, `Sevastopol'`).

### Taviana airports and faction anchors

| Object | SQM id | Position (x, z) | mission.sqm |
|---|---|---|---|
| Airport 1 | 7 | 6877, 8537 | tavi airport group |
| Airport 2 | 8 | 10194, 18666 | tavi airport group |
| Airport 3 | 9 | 16699, 10172 | tavi airport group |
| `LocationLogicOwnerWest` | 217 | 11967, 21183 | tavi owner group |
| `LocationLogicOwnerEast` | 218 | 11926, 21039 | tavi owner group |

The two Taviana faction anchors sit only ~150 m apart in the map's far north (z ≈ 21000), a tighter pairing than Eden's. Taviana's three airports span the full map (z from 8500 to 18700), consistent with its 25600 m boundary.

---

## What Is NOT a Divergence (Scope Note)

The forks are older snapshots of the same Warfare mission, so most of the file is byte-identical to Chernarus and a wholesale file-diff is noise. The genuine, intentional divergences are confined to the `mission.sqm` placement layer documented above. Specifically **out of scope** here because they are documented elsewhere or are not terrain-intentional:

- **mission.sqm presence, addons, briefing names, boundary radii, boot-blocker tiers, conflict-marker file lists** — fully covered in [Modded-Maps-Status-And-Content](Modded-Maps-Status-And-Content) and [Playable-Maps-Catalog](Playable-Maps-Catalog).
- **Faction-family selection** (FOREST → Chernarus USMC/RU/GUE via `IS_chernarus_map_dependent`) — both forks are `FOREST`, so they inherit the Chernarus faction set; this is map-type-driven, not a per-fork edit. See [Modded-Maps-Status-And-Content](Modded-Maps-Status-And-Content) and [Chernarus-Map-Content-Reference](Chernarus-Map-Content-Reference) for the faction indices.
- **Stale config-merge artifacts** in modded `Common/Config/Core_Units` / `Core_Structures` files (e.g. unresolved conflict markers from an old branch) — these are merge debris, not deliberate terrain content, and are tracked as boot blockers, not divergences.

The new, otherwise-undocumented content is exactly the extracted town roster, `totalTowns`, and `LocationLogicStart`/`Camp`/`Depot`/`Airport`/`Owner*` geometry for the two forks that uniquely carry a tracked `mission.sqm`.

---

## Continue Reading

- [Modded-Maps-Status-And-Content](Modded-Maps-Status-And-Content) — terrain parameters, addons, mission.sqm status, and boot-blocker tiers for all seven modded forks
- [Playable-Maps-Catalog](Playable-Maps-Catalog) — cross-map registry: mod status, slot count, boundary, faction family, completeness tier
- [Chernarus-Map-Content-Reference](Chernarus-Map-Content-Reference) — the authoritative source mission these forks were cloned from: 46-town roster, airports, faction indices, start vehicle pools
- [Takistan-Map-Content-Reference](Takistan-Map-Content-Reference) — the vanilla generated DESERT reference and its map-specific content
- [Content-Structure-And-Maps](Content-Structure-And-Maps) — folder layout, generated-mission tiers, and how modded forks derive from Chernarus
