# Playable Maps Master Catalog

> Source-verified 2026-06-21 against then-current master cf2a6d6a4; current origin/master is 0139a346, so recheck cited paths before current-head claims. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

This page is the single cross-map reference table. It lists every terrain the mission supports, its LoadoutManager classification, generated slot count, terrain type, naval flag, boundary size, faction family, and completeness tier. Detailed per-map content lives in the linked deep-dive pages; this page answers "which maps exist and in what state."

---

## Map Registry

The mission's terrain support is defined across three sources: LoadoutManager `.cs` classes under `Tools/LoadoutManager/Data/Terrains/Implementations/`, generated mission folders under `Missions/`, `Missions_Vanilla/`, and `Modded_Missions/`, and the runtime boundary table in `Common/Init/Init_Boundaries.sqf:4-15` (path relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ per the provenance note above).

The `TerrainModStatus` enum (`Tools/LoadoutManager/Data/Terrains/TerrainModStatus.cs:3-8`) defines three tiers: `MAIN`, `VANILLA`, and `MODDED`. A fourth tier — maps with a boundary entry but no `.cs` class and no generated folder — is noted below as **Boundary-Only**.

### Slot count derivation

`BaseTerrain.GenerateAndWriteVersionSqf()` (`Tools/LoadoutManager/Data/Terrains/BaseTerrain.cs`) produces `#define WF_MAXPLAYERS` from `DetermineMissionTypeIfItsForestOrDesert()`: FOREST terrains → `55`, DESERT terrains → `61`. Mission folder names encode this as the prefix (e.g. `[55-2hc]`, `[61-2hc]`).

### Faction family derivation

`initJIPCompatible.sqf:114-117` sets `IS_chernarus_map_dependent` from the generated `#define IS_CHERNARUS_MAP_DEPENDENT` in `version.sqf`. FOREST terrains inherit the Chernarus faction set (USMC/RU/GUE); DESERT terrains inherit the Takistan set (US/TKA/TKGUE). The authoring note in `Tools/LoadoutManager/Data/Terrains/BaseTerrain.cs:344` (two lines above `GenerateAndWriteVersionSqf()`, at line 346) reads verbatim: "IS_CHERNARUS_MAP_DEPENDENT MUST NOT BE COMMENTED IF the map depend on chernarus content. MUST BE COMMENT IF the map depend on takistan content."

---

## Full Map Table

| Map | Display Name | `inGameMapName` | Mod Status | Terrain Type | Max Players | Naval | Boundary (m) | Mission Folder | Faction Family | Completeness Tier |
|---|---|---|---|---|---|---|---|---|---|---|
| Chernarus | Chernarus | `chernarus` | MAIN | FOREST | 55 | Yes | 15 360 | `Missions/[55-2hc]…chernarus` | Chernarus (USMC/RU/GUE) | **Authoritative source** |
| Takistan | Takistan | `takistan` | VANILLA | DESERT | 61 | No | 12 800 | `Missions_Vanilla/[61-2hc]…takistan` | Takistan (US/TKA/TKGUE) | **Maintained — faithful generated copy** |
| Zargabad | Zargabad | `zargabad` | VANILLA | DESERT | 31† | No | 6 000 | `Missions_Vanilla/[31-2hc]…zargabad` | Takistan | **Branch-only candidate** (`origin/feature/zargabad-map`) |
| Napf | Napf | `Napf` | MODDED | FOREST | 55 | Yes | 20 500 | `Modded_Missions/[55-2hc]…Napf` | Chernarus | **Divergent fork — boot-incomplete, conflict markers** |
| Eden (Everon) | Everon | `eden` | MODDED | FOREST | 55 | Yes | 12 800 | `Modded_Missions/[55-2hc]…eden` | Chernarus | **Divergent fork — boot-incomplete, conflict markers** |
| Lingor | Lingor | `lingor` | MODDED | FOREST | 55 | Yes | 10 300 | `Modded_Missions/[55-2hc]…lingor` | Chernarus | **Hard boot blocker — no `description.ext`** |
| Taviana | Taviana | `tavi` | MODDED | FOREST | 55 | Yes | 25 600 | `Modded_Missions/[55-2hc]…tavi` | Chernarus | **Abandoned stub** |
| Sahrani | Sahrani | `smd_sahrani_a2` | MODDED | FOREST | 55 | Yes | 20 480 | `Modded_Missions/[55-2hc]…smd_sahrani_a2` | Chernarus | **Abandoned stub** |
| Isla Duala | Isla Duala | `isladuala` | MODDED | DESERT | 61 | Yes | 10 240 | `Modded_Missions/[61-2hc]…isladuala` | Takistan | **Abandoned stub** |
| Dingor | Dingor | `dingor` | MODDED | DESERT | 61 | Yes | 10 300 | `Modded_Missions/[61-2hc]…dingor` | Takistan | **Overlay/stub — no `version.sqf`, `mission.sqm`, or server init** |
| Utes | — | `utes` | — | — | — | — | 5 120 | — | **Boundary-only — no `.cs` class, no mission folder** |
| Tasmania | — | `tasmania2010` | — | — | — | — | 25 360 | — | **Boundary-only — no `.cs` class, no mission folder** |

Source columns:

- `inGameMapName`, `TerrainType`, `isNavalTerrain`, `startingDistanceInMeters`, `terrainModStatus`: terrain `.cs` files in `Tools/LoadoutManager/Data/Terrains/Implementations/` (see per-row notes below).
- Boundary: `Common/Init/Init_Boundaries.sqf:4-15` (relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/).
- Mission folder: `ls Missions/`, `ls Missions_Vanilla/`, `ls Modded_Missions/` (repo working tree).
- Zargabad: `origin/feature/zargabad-map` head `e9294ede`; not present on master.

---

## Per-Map Source Notes

### Chernarus

`Tools/LoadoutManager/Data/Terrains/Implementations/MainMap/CHERNARUS.cs:1-11`. `startingDistanceInMeters = 7500`. The only map with `terrainModStatus = TerrainModStatus.MAIN`. LoadoutManager writes Sounds, EASA, balance, and `version.sqf` directly into this folder; all other maps are derived from it. See [Chernarus-Map-Content-Reference](Chernarus-Map-Content-Reference) for the full content deep-dive.

### Takistan

`Tools/LoadoutManager/Data/Terrains/Implementations/VanillaMaps/TAKISTAN.cs:1-11`. `startingDistanceInMeters = 7500`, `isNavalTerrain = false`. Generated by copying the Chernarus mission and applying the Takistan skip-list (`BaseTerrain.cs:UpdateFilesForTakistan()`). `EnsureTakistanInitServerUsesCorrectMapId()` patches `Server/Init/Init_Server.sqf` to emit `[\"SET_MAP\", 2]` instead of `[\"SET_MAP\", 1]`. See [Takistan-Map-Content-Reference](Takistan-Map-Content-Reference).

### Zargabad (branch-only)

`Tools/LoadoutManager/Data/Terrains/Implementations/VanillaMaps/ZARGABAD.cs` exists only on `origin/feature/zargabad-map`. Boundary `6000` was added to `Init_Boundaries.sqf` on that branch. Slot count is claimed to be 31 (†low-pop, distinct from the 55/61 split produced by `DetermineMissionTypeIfItsForestOrDesert()`); however, no master-visible code path in `Tools/` produces a [31-2hc] prefix — the 31-slot count and the `IS_ZARGABAD_LOWPOP_MAP` define cannot be confirmed against master and may reflect a branch-local override whose mechanism is not yet documented. `IS_ZARGABAD_LOWPOP_MAP` is cited in `initJIPCompatible.sqf:121-124` (branch only). See [Zargabad-Branch-Audit](Zargabad-Branch-Audit) for full completeness evidence and to verify the slot-count override.

### Napf

`Tools/LoadoutManager/Data/Terrains/Implementations/ModdedMaps/NAPF.cs:1-11`. `startingDistanceInMeters = 12500` — notably higher than other maps. `inGameMapName = "Napf"` (capital N; case-sensitive for `worldName` match). Boundary `20500` (`Init_Boundaries.sqf:11`). `Modded_Missions/[55-2hc]warfarev2_073v48co.Napf` is present but boot-incomplete: tracked `version.sqf`, `stringtable.xml`, `loadScreen.jpg`, `mission.sqm`, `Sounds/description.ext`, and `Music/description.ext` are absent; conflict markers exist in `description.ext:43-46` and several SQF files.

### Eden (Everon)

`Tools/LoadoutManager/Data/Terrains/Implementations/ModdedMaps/EDEN.cs:1-11`. Display name is `Everon` (via `TerrainName` EnumMember: `Tools/LoadoutManager/Data/Terrains/TerrainName.cs`). `startingDistanceInMeters = 7500`. Boundary `12800`. `Modded_Missions/[55-2hc]warfarev2_073v48co.eden` is present but boot-incomplete: `version.sqf`, `stringtable.xml`, `loadScreen.jpg`, `Sounds/description.ext`, and `Music/description.ext` are absent. `Common/Functions/Common_GetTotalCamps.sqf` is referenced in `Common/Init/Init_Common.sqf:52-53,127-128` but the tracked file is absent. Conflict markers exist in `Client/Action/Action_RepairMHQ.sqf` and skill files.

### Lingor

`Tools/LoadoutManager/Data/Terrains/Implementations/ModdedMaps/LINGOR.cs:1-11`. `startingDistanceInMeters = 7500`. Boundary `10300` (`Init_Boundaries.sqf:12`). `Modded_Missions/[55-2hc]warfarev2_073v48co.lingor` has a hard boot blocker: tracked `description.ext` is absent entirely — no manifest include chain can execute. Also missing: `mission.sqm`, `initJIPCompatible.sqf`, `version.sqf`, `stringtable.xml`, `loadScreen.jpg`, sound/music descriptions, and textures. Conflict markers exist in RHUD, Nuke, `Init_Unit`, and multiple root/artillery config files.

### Taviana

`Tools/LoadoutManager/Data/Terrains/Implementations/ModdedMaps/TAVI.cs:1-11`. `startingDistanceInMeters = 7500`. Boundary `25600` (`Init_Boundaries.sqf:14`). `Modded_Missions/[55-2hc]warfarev2_073v48co.tavi` is present but is a stub: description, bootstrap, server init, generated, sound, music, and texture essentials are all absent.

### Sahrani

`Tools/LoadoutManager/Data/Terrains/Implementations/ModdedMaps/SMD_SAHRANI_A2.cs:1-11`. Display name `Sahrani`. `startingDistanceInMeters = 10500`. Boundary `20480` (`Init_Boundaries.sqf:13`). `Modded_Missions/[55-2hc]warfarev2_073v48co.smd_sahrani_a2` is a stub: mission/bootstrap/server-init/generated/sound/music/texture essentials are absent.

### Isla Duala

`Tools/LoadoutManager/Data/Terrains/Implementations/ModdedMaps/ISLADUALA.cs:1-11`. `startingDistanceInMeters = 5500` — the lowest starting distance of any supported terrain. DESERT type, so slot count is 61 and faction family is Takistan. Boundary `10240` (`Init_Boundaries.sqf:7`). `Modded_Missions/[61-2hc]warfarev2_073v48co.isladuala` is a stub.

### Dingor

`Tools/LoadoutManager/Data/Terrains/Implementations/ModdedMaps/DINGOR.cs:1-11`. Display name `Dingor`. DESERT type, naval (`isNavalTerrain = true`). `startingDistanceInMeters = 7500`. Boundary `10300` (`Init_Boundaries.sqf:15`). `Modded_Missions/[61-2hc]warfarev2_073v48co.dingor` is an overlay/stub: `description.ext` exists and includes generated/sound files, but `version.sqf`, `mission.sqm`, `initJIPCompatible.sqf`, server init, and `Sounds/` are absent.

### Utes

Boundary `5120` (`Init_Boundaries.sqf:9`). No `TerrainName` enum entry, no `.cs` terrain class, and no mission folder. The comment in `BaseTerrain.cs:68` references Utes as a map to "handle writing to the vanilla maps (Utes, Zargabad) more properly here later" — confirming intent but not implementation. Utes is not playable from the current checkout.

### Tasmania

Boundary `25360` (`Init_Boundaries.sqf:10`), `worldName` case `tasmania2010`. No `TerrainName` enum entry, no `.cs` terrain class, and no mission folder. Not playable from the current checkout.

---

## Completeness Tiers Defined

| Tier | Meaning |
|---|---|
| **Authoritative source** | Chernarus only. All gameplay edits belong here first. Generates all other maps. |
| **Maintained — faithful generated copy** | Takistan. Fully generated from Chernarus via LoadoutManager; drift is characterised and limited to documented skip-list differences. |
| **Branch-only candidate** | Zargabad on `origin/feature/zargabad-map`. Static validation passed; runtime evidence and whitespace cleanup still required. |
| **Divergent fork — boot-incomplete** | Napf, Eden. Generated folder is present and tracked; missing required files and/or contains unresolved conflict markers. Cannot boot from current checkout. |
| **Hard boot blocker** | Lingor. No `description.ext` — the include chain cannot start. |
| **Abandoned stub** | Taviana, Sahrani, Isla Duala. Generated folder present; nearly all playable-mission essentials are absent. |
| **Overlay/stub** | Dingor. Partial `description.ext` present; no `mission.sqm`, server init, or generated essentials. |
| **Boundary-only** | Utes, Tasmania. Boundary size is defined in `Init_Boundaries.sqf` but no LoadoutManager class or mission folder exists. |

---

## Build Pipeline Summary

LoadoutManager (`Tools/LoadoutManager/`) drives all map generation:

1. `TerrainModStatus.MAIN` (Chernarus) — writes in place to `Missions/`.
2. `TerrainModStatus.VANILLA` (Takistan, and Zargabad on the branch) — copies Chernarus source to `Missions_Vanilla/` then applies the skip-list and map-ID patch.
3. `TerrainModStatus.MODDED` — copies either `Missions/` (FOREST) or `Missions_Vanilla/` (DESERT) to `Modded_Missions/` (`BaseTerrain.cs:DetermineMissionSourcePathForModdedTerrains()`), then writes `Core_MOD.sqf` and patches `Init_Common.sqf` to compile it.

`ZipManager.cs:7-41` (`DoZipOperations()`; `missionDirectories` array at line 10) packages only `Missions` and `Missions_Vanilla`; modded maps are excluded from the release package. (Paths relative to `Tools/LoadoutManager/`.) The `SqfFileGenerator.cs:132-133` modded-write block is commented out, so modded maps do not receive regenerated `version.sqf` or EASA/balance files from the current checkout.

---

## Continue Reading

- [Content-Structure-And-Maps](Content-Structure-And-Maps) — folder layout, generation tiers, and modded completeness snapshot (parent overview).
- [Chernarus-Map-Content-Reference](Chernarus-Map-Content-Reference) — authoritative source map deep-dive: towns, bases, airfields, and content.
- [Takistan-Map-Content-Reference](Takistan-Map-Content-Reference) — Takistan deep-dive: generated-copy facts and map-specific content.
- [Zargabad-Branch-Audit](Zargabad-Branch-Audit) — full static and runtime evidence audit for the Zargabad branch candidate.
- [LoadoutManager-Data-Model-Contributor-Guide](LoadoutManager-Data-Model-Contributor-Guide) — how to add a new terrain class, generation rules, and skip-list mechanics.
