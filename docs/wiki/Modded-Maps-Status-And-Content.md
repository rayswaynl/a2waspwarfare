# Modded Maps Status and Content

> Source-verified 2026-06-21 against then-current master cf2a6d6a4; current origin/master is 0139a346, so recheck cited paths before current-head claims. Paths relative to Modded_Missions/ unless noted. Arma 2 OA 1.64.

Seven modded-terrain variants exist under `Modded_Missions/`. None are packaged in the current release archive (see [Tools and build workflow](Tools-And-Build-Workflow)) and none have a generated `version.sqf` in the tracked checkout. They range from near-playable to bare stubs. This page catalogs terrain parameters, required mod addons, mission.sqm status, and the specific boot-blocking files missing from each folder.

---

## Terrain Parameters

All seven modded terrains are registered in `Tools/LoadoutManager/Data/Terrains/Implementations/ModdedMaps/`. The `TerrainType` field controls which faction family the mission uses at runtime: `FOREST` maps inherit Chernarus-style faction defaults (`IS_chernarus_map_dependent = true`); `DESERT` maps inherit Takistan-style defaults. The `startingDistanceInMeters` value becomes the `STARTING_DISTANCE` preprocessor define in the generated `version.sqf`. `isNavalTerrain = true` emits `#define IS_NAVAL_MAP`, which sets `IS_naval_map = true` at `initJIPCompatible.sqf:15–17` (Eden copy).

| Map (display name) | `inGameMapName` | Slot count | `TerrainType` | `startingDistanceInMeters` | `isNavalTerrain` | Source |
|---|---|---|---|---|---|---|
| Everon (Eden) | `eden` | 55 | `FOREST` | 7500 | true | Tools/LoadoutManager/Data/Terrains/Implementations/ModdedMaps/EDEN.cs:5–10 |
| Napf | `Napf` | 55 | `FOREST` | 12500 | true | Tools/LoadoutManager/Data/Terrains/Implementations/ModdedMaps/NAPF.cs:5–10 |
| Taviana (Tavi) | `tavi` | 55 | `FOREST` | 7500 | true | Tools/LoadoutManager/Data/Terrains/Implementations/ModdedMaps/TAVI.cs:5–10 |
| Sahrani | `smd_sahrani_a2` | 55 | `FOREST` | 10500 | true | Tools/LoadoutManager/Data/Terrains/Implementations/ModdedMaps/SMD_SAHRANI_A2.cs:5–10 |
| Lingor | `lingor` | 55 | `FOREST` | 7500 | true | Tools/LoadoutManager/Data/Terrains/Implementations/ModdedMaps/LINGOR.cs:5–10 |
| Dingor | `dingor` | 61 | `DESERT` | 7500 | true | Tools/LoadoutManager/Data/Terrains/Implementations/ModdedMaps/DINGOR.cs:5–10 |
| Isla Duala | `isladuala` | 61 | `DESERT` | 5500 | true | Tools/LoadoutManager/Data/Terrains/Implementations/ModdedMaps/ISLADUALA.cs:5–10 |

Slot count (55 vs 61) follows the `TerrainType`: `FOREST` → `[55-2hc]`, `DESERT` → `[61-2hc]`. See `Tools/LoadoutManager/Data/Terrains/BaseTerrain.cs:162–163` for the switch.

**Display names** come from the `[EnumMember(Value = "…")]` annotations in `Tools/LoadoutManager/Data/Terrains/TerrainName.cs`: Everon for EDEN, Isla Duala for ISLADUALA, Taviana for TAVI, Sahrani for SMD_SAHRANI_A2.

---

## Boundary Radii

The playable-area boundary radius (`WFBE_BOUNDARIESXY`, metres) is set at runtime in `Common/Init/Init_Boundaries.sqf` via a `switch (toLower(worldName))` block. Values below are from the Chernarus source mission, which is the canonical copy; Eden's tracked copy reproduces identical values.

| `worldName` | `_boundariesXY` (m) | Source |
|---|---|---|
| `eden` | 12800 | Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_Boundaries.sqf:6 |
| `napf` | 20500 | Common/Init/Init_Boundaries.sqf:11 |
| `lingor` | 10300 | Common/Init/Init_Boundaries.sqf:12 |
| `smd_sahrani_a2` | 20480 | Common/Init/Init_Boundaries.sqf:13 |
| `tavi` | 25600 | Common/Init/Init_Boundaries.sqf:14 |
| `dingor` | 10300 | Common/Init/Init_Boundaries.sqf:15 |
| `isladuala` | 10240 | Common/Init/Init_Boundaries.sqf:7 |

When `WFBE_C_GAMEPLAY_BOUNDARIES_ENABLED` is 0, the boundary value is still stored in `WFBE_BOUNDARIESXY` but the out-of-bounds kick is not enforced (`Init_Boundaries.sqf:19–38`).

---

## Mission.sqm Status and Required Addons

Only Eden and Taviana have a tracked `mission.sqm`. The others have no `mission.sqm` in the repo checkout and cannot boot without one.

| Folder | `mission.sqm` | `addOns[]` key entries | Version / briefing name | Source |
|---|---|---|---|---|
| `[55-2hc]warfarev2_073v48co.eden` | Present | `sap_everon`, `PRACS_Molatian_MiG21`, `cacharacters2`, `warfare2vehicles` | `[55] Warfare V48 Everon 1.01` | [55-2hc]warfarev2_073v48co.eden/mission.sqm:4–14 |
| `[55-2hc]warfarev2_073v48co.tavi` | Present | `tavi`, `PRACS_Molatian_MiG21`, `cacharacters2`, `warfare2vehicles` | `[55] Warfare V48 Taviana 1.11` | [55-2hc]warfarev2_073v48co.tavi/mission.sqm:4–14 |
| `[55-2hc]warfarev2_073v48co.Napf` | **Missing** | — | — | folder listing |
| `[55-2hc]warfarev2_073v48co.lingor` | **Missing** | — | — | folder listing |
| `[55-2hc]warfarev2_073v48co.smd_sahrani_a2` | **Missing** | — | — | folder listing |
| `[61-2hc]warfarev2_073v48co.dingor` | **Missing** | — | — | folder listing |
| `[61-2hc]warfarev2_073v48co.isladuala` | **Missing** | — | — | folder listing |

Both Eden and Taviana require `PRACS_Molatian_MiG21` in addition to their terrain pack. This addon unlocks the `ibrPRACS_MiG21mol` aircraft, which `IS_mod_map_dependent` gates in `Common/Config/Core_Units/Units_CO_RU.sqf:216,239` (OPFOR aircraft list and airport unit list). The define is set by `#define IS_MOD_MAP_DEPENDENT` in the generated `version.sqf` and read at `initJIPCompatible.sqf:116–118` (Eden copy).

---

## Boot-Blocker Summary

LoadoutManager generation for modded terrains is currently commented out (`Tools/LoadoutManager/SqfFileGenerators/SqfFileGenerator.cs:132–133`). `Modded_Missions/` is also excluded from the release archive (`Tools/LoadoutManager/ZipManager.cs:10`). Each folder's completeness tier is:

| Folder | Tier | Key missing files | Notes |
|---|---|---|---|
| `eden` | Boot-incomplete | `version.sqf`, `stringtable.xml`, `loadScreen.jpg`, `Sounds/description.ext`; `Common/Functions/Common_GetTotalCamps.sqf` (compiled at `Common/Init/Init_Common.sqf:59,136`) | `description.ext` present and includes `version.sqf` at line 39; `mission.sqm` present; `initJIPCompatible.sqf` present. Conflict markers in `Client/Action/Action_RepairMHQ.sqf`, `Client/Module/Skill/Skill_Apply.sqf` (lines 25–26, 98), `Common/Config/Core_Structures/Structures_CO_RU.sqf`. |
| `Napf` | Boot-incomplete | `version.sqf`, `mission.sqm`, `stringtable.xml`, `loadScreen.jpg`, `Sounds/description.ext`; `Music/description.ext` (conflict marker at `description.ext:43–46` shows it was removed in one branch); `Common/Functions/Common_GetTotalCamps.sqf` | `description.ext` present with conflict markers at lines 43–46. `initJIPCompatible.sqf` present. Conflict markers also in `Client/Module/Skill/Skill_Init.sqf`, `Common/Config/Core_Structures/Structures_CO_US.sqf`, `Common/Config/Core_Units/Units_RU.sqf`, `Common/Module/IRS/IRS_OnIncomingMissile.sqf`. |
| `lingor` | Hard boot blocker | `description.ext` entirely absent (no manifest include chain); `mission.sqm`, `initJIPCompatible.sqf`, `version.sqf`, `stringtable.xml`, `loadScreen.jpg`, all Sounds/Music/Textures; `Common/Functions/Common_GetTotalCamps.sqf` | Conflict markers in `Client/Client_UpdateRHUD.sqf`, `Client/Module/Nuke/nukeincoming.sqf`, five `Common/Config/Core_Root/Root_*.sqf` files, `Common/Init/Init_Unit.sqf`. |
| `smd_sahrani_a2` | Stub | `description.ext`, `mission.sqm`, `initJIPCompatible.sqf`, `version.sqf`, and all server-init/generated/sound/texture files | Only `Client/`, `Common/`, `briefing.sqf` present. |
| `tavi` | Stub | `description.ext`, `initJIPCompatible.sqf`, `version.sqf`, and all server-init/generated/sound/texture files | `mission.sqm` and `Common/` content present; all other runtime essentials absent. |
| `dingor` | Overlay/stub | `mission.sqm`, `initJIPCompatible.sqf`, `version.sqf`, `Sounds/description.ext` (referenced by `description.ext`) | `description.ext` present. Only `Client/`, `Server/`, `Textures/`, `WASP/` directories present. |
| `isladuala` | Stub | Everything — only `Client/` directory exists | No `description.ext`, no `mission.sqm`, no bootstrap. |

To bring any of these to a bootable state: (1) run LoadoutManager against the terrain after un-commenting the modded-write call at `SqfFileGenerators/SqfFileGenerator.cs:132`; (2) resolve all conflict markers; (3) supply or author a `mission.sqm`; (4) verify `Common/Functions/Common_GetTotalCamps.sqf` is present (it compiles at `Init_Common.sqf:59–60` and `:136–137`). The FOREST stubs (Sahrani, Tavi, Lingor) source their files from Chernarus during generation; DESERT stubs (Dingor, Isla Duala) source from Takistan.

---

## Continue Reading

- [Content-Structure-And-Maps](Content-Structure-And-Maps) — folder layout, generated-mission tiers, modded completeness context
- [Tools-And-Build-Workflow](Tools-And-Build-Workflow) — LoadoutManager propagation rules, ZipManager packaging, skip-list
- [Chernarus-Map-Content-Reference](Chernarus-Map-Content-Reference) — authoritative source map: towns, airports, boundaries, faction indices
- [Takistan-Map-Content-Reference](Takistan-Map-Content-Reference) — vanilla generated Takistan reference
- [Faction-Unit-And-Vehicle-Roster-Catalog](Faction-Unit-And-Vehicle-Roster-Catalog) — unit and vehicle lists per faction, including `IS_mod_map_dependent`-gated entries
