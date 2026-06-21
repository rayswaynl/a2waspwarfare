# LoadoutManager Data-Model Contributor Guide

> Source-verified 2026-06-21 against master cf2a6d6a4. Paths under `Tools/LoadoutManager/` are relative to the repo root. Paths under `Missions/[55-2hc]warfarev2_073v48co.chernarus/` are relative to the Chernarus mission dir. Arma 2 OA 1.64.

The LoadoutManager is a C# console application (`Tools/LoadoutManager/`) that reads vehicle and terrain data-model classes and **generates** four SQF files per terrain:

| Generated file | Purpose |
|---|---|
| `Client/Module/EASA/EASA_Init.sqf` | Vehicle list + all pylon-combination loadouts with prices |
| `Common/Functions/Common_BalanceInit.sqf` | Per-vehicle `switch` block that adds/removes magazines and weapons from spawned vehicles |
| `Common/Common_ReturnAircraftNameFromItsType.sqf` | Radar-name overrides for aircraft with `hasCustomRadarName = true` |
| `Common/Functions/Common_ModifyAirVehicle.sqf` | Per-aircraft damage-model HandleDamage injection (AA-missile one-hit-kill logic) |

**You must re-run the tool after every data-model change.** The SQF files checked into the repo are the generator's output — editing them by hand will be overwritten on the next run.

---

## Class Hierarchy

```
BaseVehicle  (Tools/LoadoutManager/Data/Vehicles/BaseVehicle.cs)
├── BaseAircraft  (Data/Vehicles/Aircrafts/BaseAircraft.cs)
│   └── BaseHelicopter  (Data/Vehicles/Aircrafts/BaseHelicopter.cs)
│       └── e.g. AH64DEP1, MI24P, KA52 …
│   └── e.g. F35B, SU34, MIG21 (modded) …
└── BaseGroundVehicle  (Data/Vehicles/GroundVehicles/BaseGroundVehicle.cs)
    └── e.g. M2A2EP1, PANDUR …
```

---

## BaseVehicle — Fields All Vehicles Must Set

All concrete vehicle classes live under `Data/Vehicles/Aircrafts/Implementations/` or `Data/Vehicles/GroundVehicles/Implementations/`, organized by faction subfolder (`BLUFOR/`, `OPFOR/`).

| Field | Type | Required | Description | Source |
|---|---|---|---|---|
| `vehicleType` | `VehicleType` | Yes | Enum entry whose `[EnumMember]` value is the exact Arma class name | `BaseVehicle.cs:25` |
| `inGameDisplayName` | `string` | Yes | Display string shown in EASA screen and radar readout | `BaseVehicle.cs:52` |
| `inGameFactoryLevel` | `int` | Yes | Factory level gate (1–5) | `BaseVehicle.cs:46` |
| `producedFromFactoryType` | `FactoryType` | Yes | `LIGHTFACTORY`, `HEAVYFACTORY`, or `AIRCRAFTFACTORY` | `BaseVehicle.cs:49` |
| `factionType` | `FactionType` | Modded only | Only `MOLATIAN` ("Molatian Air Force") currently defined; vanilla vehicles omit this | `Data/Factions/FactionType.cs:6` |
| `moddedVehicle` | `bool` | Modded only | `true` routes output to `aircraftEasaLoadoutsFileForModdedMaps` / `commonBalanceInitFileForModdedMaps` | `BaseVehicle.cs:53` |
| `inGamePrice` | `int` | Modded only | Only written to `Core_MOD.sqf` for modded vehicles | `BaseVehicle.cs:43` |
| `ConstructionTime` | `int` | Modded only | Seconds to build; only written to `Core_MOD.sqf` | `BaseVehicle.cs:57` |
| `vanillaGameDefaultLoadout` | `Loadout` | Yes (can be empty) | Arma's built-in loadout before the mission modifies it | `BaseVehicle.cs:34` |
| `defaultLoadout` | `Loadout` | Yes (can be empty) | The WASP target loadout the mission applies at spawn | `BaseVehicle.cs:28` |

`UnknownValue1` defaults to `-2`, `UnknownValue2` to `3`, `UnknownValue3` to `3` — do not change without understanding the Core_MOD consumer (`BaseVehicle.cs:58-60`).

### VehicleType Enum

Every new vehicle needs a new enum entry in `Data/Vehicles/VehicleType.cs`. The `[EnumMember(Value = "...")]` attribute **must** match the exact Arma 2 CfgVehicles class name.

```csharp
// Tools/LoadoutManager/Data/Vehicles/VehicleType.cs:5-6
[EnumMember(Value = "Su34")]
SU34,
```

Modded vehicles go at the bottom of the enum, after the comment `// Modded vehicles` (`VehicleType.cs:114`).

---

## BaseAircraft — Aircraft-Specific Fields

Aircraft classes inherit `BaseAircraft` (fixed-wing) or `BaseHelicopter` (rotary). Both live under `Implementations/BLUFOR/` or `Implementations/OPFOR/`.

| Field | Type | Required | Description | Source |
|---|---|---|---|---|
| `pylonAmount` | `int` | Yes | Total number of pylons. Combinations are generated over `pylonAmount / 2` slots | `BaseAircraft.cs:11,64` |
| `allowedAmmunitionTypesWithTheirLimitationAmount` | `Dictionary<AmmunitionType, int>` | Yes | Keys = ammo types available on the EASA screen. Value `0` = unlimited; positive value = cap per combination | `BaseAircraft.cs:14` |
| `addToDefaultLoadoutPrice` | `bool` | No | When `true`, loadout price is the *delta* from `defaultLoadout` rather than the absolute cost of all pylons | `BaseAircraft.cs:16` |
| `hasCustomRadarName` | `bool` | No | When `true`, the vehicle is added to `Common_ReturnAircraftNameFromItsType.sqf` | `BaseAircraft.cs:22` |
| `excludeFromAntiAirMissileOneHitKill` | `bool` | No | When `true`, the vehicle is skipped in the AA damage-model injection into `Common_ModifyAirVehicle.sqf` | `BaseAircraft.cs:24` |
| `ammunitionTypeCostFloatModifier` | `Dictionary<AmmunitionType, float>` | No | Per-ammo-type multiplier applied on top of `costPerPylon` | `BaseAircraft.cs:19` |

### Pylon-Count Validation

`CalculateWeaponsCount` enforces that the total weapon-slots used equals `pylonAmount` before a combination is emitted (`BaseAircraft.cs:300`). Several ammo types receive special slot-counting treatment:

| AmmunitionType enum | Slot weight | Note |
|---|---|---|
| `TWELVEROUNDSVIKHR` | `× 2` | Each magazine counts as two slots | `BaseAircraft.cs:454-456` |
| `FOURROUNDCH29` | `× 2` | | `BaseAircraft.cs:455` |
| `EIGHTROUNDHELLFIRE` | `× 2` | | `BaseAircraft.cs:456` |
| `FOURROUNDFAB250` | `÷ 2` | Counts as half a slot | `BaseAircraft.cs:459` |
| `TWOROUNDFAB250` | `÷ 2` | Case fall-through at 459-460, multiplier applied at 461 | `BaseAircraft.cs:460` |
| `SIXROUNDCH29` | `× 3` | Each magazine counts as three slots | `BaseAircraft.cs:462-464` |
| All others | `× 1` (default) | | `BaseAircraft.cs:466` |

When `addToDefaultLoadoutPrice = true` the slot check is skipped (`BaseAircraft.cs:300`).

### Pylon Combination Algorithm

The generator builds every **combination with repetition** of the allowed ammo types taken `pylonAmount / 2` at a time (`BaseAircraft.cs:64`). Each selected ammo type fills **2 pylons** (i.e., magazines are added in pairs: `p % 2 != 0` iterations are skipped, `BaseAircraft.cs:331-334`).

Hellfires and Vikhr each consume 2 combination slots instead of 1 (`BaseAircraft.cs:501-510`).

`BASECH29` is blocked from appearing alone (2-magazine-only combinations are rejected, `BaseAircraft.cs:258-261`) and is replaced at output time with variant-specific magazine entries from `optionalAmmunitionDictionary` (`BaseAircraft.cs:376-386`).

`SIXTYROUNDCMFLAREMAGAZINE` is stripped from default-loadout rows (not from priced rows), so flares never appear in the EASA cost calculation (`BaseAircraft.cs:191-198`).

### Per-Loadout Price Formula

For each priced combination row (`_generateWithPriceAndWeaponsInfo = true`):

```
row_price = Σ (costPerPylon × 2 × costFloatModifier) per ammo-type pair
          + Σ costPerWeaponLauncher per ammo-type entry (before duplicate-launcher guard)
```

- `costPerPylon` is defined on each `BaseAmmunition` implementation (e.g. R-73 = 700, `Data/Ammunition/Implementations/AirToAirWeapons/R-73/TwoRoundR73.cs`; GBU-12 = 4000, `Data/Ammunition/Implementations/AirToGroundWeapons/Bombs/LaserGuidedBombs/GBU12/TWOROUNDGBU12.cs`).
- `costPerWeaponLauncher` is defined on each `BaseWeapon` implementation (e.g. R-73 launcher = 1000, `Data/Weapons/Implementations/AirToAirWeapons/R-73/R73_WEAPON.cs`). Added once per ammo-type entry in the sorted input, before the duplicate-launcher guard at line 394 — meaning if two `AmmunitionType` entries share the same `WeaponType` launcher, the launcher cost is charged for each. Check whether this is intentional before relying on this for price calculations (`BaseAircraft.cs:390`).
- `costFloatModifier` comes from `ammunitionTypeCostFloatModifier` on the vehicle class. If the key is absent, the modifier defaults to 1 (no change, `BaseAircraft.cs:174-181`).

When `addToDefaultLoadoutPrice = true` the per-pylon cost is the *delta* from `defaultLoadout`: `costPerPylon × (easaAmmoCount − defaultLoadoutAmmoCount)` (`BaseAircraft.cs:372`). This is used for AH-64D (EP1) and Mi-24P (`Data/Vehicles/Aircrafts/Implementations/BLUFOR/AH64DEP1.cs:29`; `OPFOR/MI24P.cs:63`).

### Mi-24P Special Case

`MI24P` has special handling in `GenerateDefaultLoadout`: it uses `defaultLoadout.AmmunitionTypesWithCount` rather than the turret path, even though a `defaultLoadoutOnTurret` is also populated (`BaseAircraft.cs:145-149`). The turret loadout affects only `Common_BalanceInit.sqf`, not `EASA_Init.sqf`.

### Wildcat Special Case

`WILDCAT` (`VehicleType.WILDCAT`, class `AW159_Lynx_BAF`) bypasses the slot-count check entirely and has three fixed weapons injected into every priced loadout row before price calculation:

| AmmunitionType | Count injected |
|---|---|
| `TWOHUNDREDROUNDCTWSHE` | 2 |
| `TWOHUNDREDROUNDCTWSSABOT` | 2 |
| `SIXROUNDCRV7HEPD` | 2 |

Source: `BaseAircraft.cs:275-296`.

---

## BaseHelicopter — Helicopter Cost Modifiers

`BaseHelicopter` sets default `ammunitionTypeCostFloatModifier` entries in its constructor so helicopters are cheaper or more expensive for certain munition types relative to their base `costPerPylon`:

| AmmunitionType | Modifier | Net effect |
|---|---|---|
| `EIGHTROUNDHELLFIRE` | 0.8333… | ~17% cheaper |
| `FOURROUNDATAKA` | 0.8333… | ~17% cheaper |
| `TWOROUNDSIDEWINDER` | 5.714… | ~5.7× more expensive |
| `TWOROUNDR73` | 5.714… | ~5.7× more expensive |
| `TWOROUNDSTINGER` | 12.5 | 12.5× more expensive |
| `TWOROUNDIGLA` | 12.5 | 12.5× more expensive |
| `SIXROUNDFAB250` | 1.5 | 1.5× more expensive |

Source: `Tools/LoadoutManager/Data/Vehicles/Aircrafts/BaseHelicopter.cs:7-16`.

Helicopter subclasses can override individual entries by re-assigning values after calling the base constructor.

---

## BaseGroundVehicle — Ground Vehicle Fields

Ground vehicles inherit `BaseGroundVehicle` (`Data/Vehicles/GroundVehicles/BaseGroundVehicle.cs`). They only contribute to `Common_BalanceInit.sqf`; they have no EASA pylon entries.

The key additional fields (from `BaseVehicle`) used by ground vehicles:

| Field | Type | Description | Source |
|---|---|---|---|
| `defaultLoadout` | `Loadout` | Main-seat load (driver/commander seat) | `BaseVehicle.cs:28` |
| `vanillaGameDefaultLoadout` | `Loadout` | Main-seat vanilla load | `BaseVehicle.cs:34` |
| `defaultLoadoutOnTurret` | `Loadout` | Turret-seat load | `BaseVehicle.cs:31` |
| `vanillaGameDefaultLoadoutOnTurret` | `Loadout` | Turret-seat vanilla load | `BaseVehicle.cs:37` |
| `turretPos` | `int` | Arma turret index (0 = first external turret, -1 = pilot/co-pilot position) | `BaseVehicle.cs:40` |
| `weaponsToRemoveUntilFactoryLevelOnAVehicle` | `Dictionary<WeaponType, int>` | Remove the weapon from main-body if factory level < value | `BaseVehicle.cs:63` |
| `weaponsOnTheTurretToRemoveUntilFactoryLevelOnAVehicle` | `Dictionary<WeaponType, int>` | Remove the weapon from turret if factory level < value | `BaseVehicle.cs:66` |

### Weapon-Removal Conditional Logic

When a vehicle sets `weaponsToRemoveUntilFactoryLevelOnAVehicle`, the generator emits a SQF guard block in `Common_BalanceInit.sqf` (`BaseVehicle.cs:137-157` non-turret / `BaseVehicle.cs:162-182` turret; lines 118-129 are the invocation site that calls these methods):

```sqf
// Generated output example (PANDUR, Spike on turret, requires factory level 4):
_currentFactoryLevel = ((side group player) Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_LIGHT;
if (_currentFactoryLevel < 4) then {
    _this removeWeaponTurret ["SpikeLauncher_ACR", [0]];
};
```

The factory variable used is:
- `WFBE_UP_HEAVY` when `producedFromFactoryType == HEAVYFACTORY`
- `WFBE_UP_LIGHT` when `producedFromFactoryType == LIGHTFACTORY`

Source: `BaseVehicle.cs:142-145`, `BaseVehicle.cs:168-171`.

Only the **first** entry in the dictionary is processed (the code calls `.First().Value`). If a vehicle needs multiple weapons removed at different levels, the current generator only handles one (`BaseVehicle.cs:151-153`).

### Ground Vehicle Example — M2A2 Bradley

```csharp
// Tools/LoadoutManager/Data/Vehicles/GroundVehicles/Implementations/BLUFOR/HeavyFactory/M2A2EP1.cs
VehicleType = VehicleType.M2A2EP1;           // → "M2A2_EP1"
producedFromFactoryType = FactoryType.HEAVYFACTORY;
inGameFactoryLevel = 1;
inGameDisplayName = "M2A2 Bradley";
// Vanilla has TOW-2 and M242 BC variants; WASP default strips TOW and replaces M242 BC → M242
```

### Ground Vehicle Example — Pandur (Turret + Conditional Weapon)

```csharp
// Tools/LoadoutManager/Data/Vehicles/GroundVehicles/Implementations/BLUFOR/LightFactory/PANDUR.cs
VehicleType = VehicleType.PANDUR;            // → "Pandur2_ACR"
producedFromFactoryType = FactoryType.LIGHTFACTORY;
inGameFactoryLevel = 3;
turretPos = 0;
// Turret load: ATK44 (vanilla) → M242 APDS/HEI (WASP)
// SpikeLauncher_ACR removed from turret if WFBE_UP_LIGHT < 4
```

---

## AmmunitionType Enum

`Data/Ammunition/AmmunitionType.cs` maps C# enum names to Arma magazine class names via `[EnumMember]`. Important conventions:

- Vanilla (unmodified Arma) entries are prefixed `VANILLA_`.
- `BASECH29` is flagged `ERROR_UNDEFINED_VARIANTS` (plural) in its `AmmunitionTypes` list — the generator skips entries with that literal string at `BaseAircraft.cs:351-353` and instead uses `optionalAmmunitionDictionary` for output (`BaseAircraft.cs:376-386`). Do not rely on `BASECH29` as the sole entry in a combination - 2-magazine-only combinations are rejected (`BaseAircraft.cs:258-261`). Use `BASECH29` as a key with value `0` (unlimited) alongside other ammo types; the generator will substitute variants from `optionalAmmunitionDictionary` at output time.
- `SIXROUNDFAB250` carries the `[EnumMember]` value `ERROR_UNDEFINED_VARIANT` (singular, no S) on the `AmmunitionType` enum entry as a marker that it is a meta-combination. Its concrete `BaseAmmunition` class lists `{FOURROUNDFAB250, TWOROUNDFAB250}` and is **not** skipped by the generator — the `ERROR_UNDEFINED_VARIANTS` check at line 351 does not match the singular form. `SIXROUNDFAB250` can appear in `allowedAmmunitionTypesWithTheirLimitationAmount`.
- `WARNING_GAME_CRASH_DO_NOT_USE_IN_LOADOUTS_TWELVEROUNDCRV7PG` (`12Rnd_CRV7`) is explicitly flagged in both `AmmunitionType.cs` (line 142) and `WeaponType.cs` (line 122) — never include `CRV7_PG` in any loadout.
- Modded entries at the bottom of the file (`AmmunitionType.cs:173-178`) are for the MiG-21 map mod.

Each enum entry is backed by a concrete `BaseAmmunition` subclass under `Data/Ammunition/Implementations/`. That class sets `costPerPylon`, `amountPerPylon`, `ammoDisplayName`, `weaponDefinition`, and `AmmunitionTypes` (the list of actual Arma magazine classes).

---

## WeaponType Enum

`Data/Weapons/WeaponType.cs` maps C# names to Arma weapon class names. Each entry is backed by a `BaseWeapon` subclass setting `costPerWeaponLauncher`. This cost is added **once per ammo-type entry** in the sorted input at `BaseAircraft.cs:390`, before the duplicate-launcher guard at line 394. If two `AmmunitionType` entries share the same `WeaponType` launcher, the launcher cost is charged for each entry.

`doNotAddWeapon` (on `BaseWeapon`) suppresses the weapon from the generated weapons-array while still charging its cost — used for internal-gun weapons that are always present on the vehicle.

---

## Adding a New Aircraft — Step-by-Step

1. **Add a `VehicleType` entry** in `Data/Vehicles/VehicleType.cs` with the exact Arma class name as the `[EnumMember]` value.
2. **Create the implementation file** under `Data/Vehicles/Aircrafts/Implementations/BLUFOR/` or `OPFOR/` (or `OPFOR/_Modded/` for modded vehicles).
3. **Choose the base class**: extend `BaseHelicopter` for rotary aircraft, `BaseAircraft` for fixed-wing.
4. **Set mandatory fields** in the constructor:

   | Field | Constraint |
   |---|---|
   | `VehicleType` | Must match new enum entry |
   | `pylonAmount` | Must be even; combinations use `pylonAmount / 2` slots |
   | `inGameDisplayName` | Free string; shown in EASA and radar name |
   | `inGameFactoryLevel` | 1–5 |
   | `producedFromFactoryType` | `FactoryType.AIRCRAFTFACTORY` for all aircraft |
   | `vanillaGameDefaultLoadout.AmmunitionTypesWithCount` | Arma's built-in magazines (use `VANILLA_*` entries) |
   | `defaultLoadout.AmmunitionTypesWithCount` | WASP's intended spawn loadout |
   | `allowedAmmunitionTypesWithTheirLimitationAmount` | At least one entry; `0` = unlimited |

5. **Verify pylon arithmetic**: sum of all slots in `allowedAmmunitionTypesWithTheirLimitationAmount` (accounting for the special-weight types above) must be able to fill `pylonAmount` exactly, or set `addToDefaultLoadoutPrice = true` to skip the check.
6. **Add `AmmunitionType` entries** if the aircraft uses magazines not already in the enum — and create the corresponding `BaseAmmunition` subclass.
7. **Set `moddedVehicle = true`** and populate `inGamePrice`, `ConstructionTime`, `factionType` if the vehicle requires a modded map's `Core_MOD.sqf`.
8. **Re-run the LoadoutManager** to regenerate all four SQF files per terrain.

---

## Adding a New Terrain — Step-by-Step

1. **Add a `TerrainName` entry** in `Data/Terrains/TerrainName.cs` (`[EnumMember]` value = display name used in `GUI_Menu_Help.sqf` header).
2. **Create the implementation file** under `Data/Terrains/Implementations/`:
   - `MainMap/` — for the Chernarus master (`TerrainModStatus.MAIN`)
   - `VanillaMaps/` — for Takistan and other maps copied from Chernarus (`TerrainModStatus.VANILLA`)
   - `ModdedMaps/` — for third-party maps requiring `Core_MOD.sqf` (`TerrainModStatus.MODDED`)
3. **Set mandatory fields**:

   | Field | Options | Meaning |
   |---|---|---|
   | `TerrainName` | `TerrainName.*` | Must match new enum entry |
   | `TerrainType` | `FOREST` / `DESERT` | Controls player count (55 vs 61) and Chernarus-dependent defines |
   | `terrainModStatus` | `MAIN` / `VANILLA` / `MODDED` | Controls file-copy path and `Core_MOD.sqf` generation |
   | `inGameMapName` | string | Arma map class name (lowercase); used to construct the mission directory path |
   | `startingDistanceInMeters` | int | Injected into `version.sqf` as `STARTING_DISTANCE` |
   | `isNavalTerrain` | bool | Controls `#define IS_NAVAL_MAP` in `version.sqf` |

4. **Wire it into `SqfFileGenerator`** (`SqfFileGenerators/SqfFileGenerator.cs:128-133`): vanilla/main terrains require an explicit `WriteAndUpdateToFilesForATerrain` call. Modded terrains are iterated automatically via `TerrainName` enum (the modded path is currently commented out pending re-enablement, `SqfFileGenerator.cs:132`).

### Terrain Examples

| Class | `TerrainModStatus` | `TerrainType` | `inGameMapName` | `isNavalTerrain` | Source |
|---|---|---|---|---|---|
| `CHERNARUS` | `MAIN` | `FOREST` | `chernarus` | `true` | `Implementations/MainMap/CHERNARUS.cs:3-10` |
| `TAKISTAN` | `VANILLA` | `DESERT` | `takistan` | `false` | `Implementations/VanillaMaps/TAKISTAN.cs:3-10` |
| `TAVI` | `MODDED` | `FOREST` | `tavi` | `true` | `Implementations/ModdedMaps/TAVI.cs:3-10` |

`VANILLA` terrains copy files from the Chernarus source directory and then patch `Init_Server.sqf` to replace `[\"SET_MAP\", 1]` with `[\"SET_MAP\", 2]` for Takistan (`BaseTerrain.cs:304-337`).

---

## Output Contract — What Gets Written Where

The generator calls `BaseTerrain.WriteAndUpdateTerrainFiles()` (`BaseTerrain.cs:31`) which writes:

| Target file (relative to mission dir) | Source variable | Insert method |
|---|---|---|
| `Client/Module/EASA/EASA_Init.sqf` | `_easaFileString` | Full overwrite |
| `Common/Functions/Common_BalanceInit.sqf` | `_commonBalanceFileString` | Full overwrite |
| `Common/Common_ReturnAircraftNameFromItsType.sqf` | `_aircraftDisplayNameStrings` | Full overwrite |
| `version.sqf` | generated internally | Full overwrite |
| `Common/Functions/Common_ModifyAirVehicle.sqf` | `_addedAircraftDamageModelChanges` | **Insertion** between markers `//LoadoutManagerInsertChanges` and `//LoadoutManagerInsertChanges_END` |
| `Common/Config/Core/Core_MOD.sqf` | `_coreModFile` | Full overwrite (modded terrains only) |

The `Common_BalanceInit.sqf` header is hardcoded by the generator and includes the `if (isServer) exitWith {};` guard to prevent an occasional server freeze when processing certain vehicles (e.g., Pandur, BTR-90) - see `SqfFileGenerator.cs:241-244` (`SqfFileGenerator.cs:241-244`).

---

## Common Contributor Mistakes

| Mistake | Consequence | Fix |
|---|---|---|
| Vehicle file placed in wrong faction folder | No runtime error, but file is not discovered by `EnumExtensions.GetInstance` if the naming convention is broken | Name the class exactly as the `VehicleType` enum member (case-sensitive) |
| `pylonAmount` odd number | `pylonAmount / 2` truncates; combinations silently under-fill | Always use an even value |
| Ammo type with `ERROR_UNDEFINED_VARIANTS` as `[EnumMember]` used in `allowedAmmunitionTypesWithTheirLimitationAmount` | Generator skips and emits empty loadout row | Use the concrete variant (`FOURROUNDCH29`, `SIXROUNDCH29`) or the `BASECH29` placeholder key as documented |
| `TerrainName` enum added but `WriteAndUpdateToFilesForATerrain` call not added | New terrain never written | Add explicit call for `VANILLA`/`MAIN`; modded path currently disabled |
| Editing generated SQF files directly | Overwritten on next tool run | Always edit the C# data model and regenerate |
| Using `CRV7_PG` / `TWELVEROUNDCRV7PG` | Game crash | Enum is prefixed `WARNING_GAME_CRASH_DO_NOT_USE_IN_LOADOUTS` for exactly this reason (`AmmunitionType.cs:142`, `WeaponType.cs:122`) |
| `weaponsToRemoveUntilFactoryLevelOnAVehicle` with multiple entries | Only `.First()` is processed | Current generator limitation — use a single entry per vehicle |

---

## Continue Reading

- [Gear-Loadout-And-EASA-Atlas](Gear-Loadout-And-EASA-Atlas) — EASA_Init.sqf runtime behaviour, EASA_Equip call shape, and how loadout rows are consumed in-game.
- [Factory-And-Purchase-Systems-Atlas](Factory-And-Purchase-Systems-Atlas) — Factory levels, `WFBE_UP_HEAVY` / `WFBE_UP_LIGHT` upgrade counters, and how `producedFromFactoryType` maps to purchase gates.
- [Assets-Config-Localization-And-Parameters-Atlas](Assets-Config-Localization-And-Parameters-Atlas) — CfgVehicles class names, faction configs, and how `VehicleType` `[EnumMember]` values must match the config.
- [Variable-And-Naming-Conventions](Variable-And-Naming-Conventions) — `WFBE_C_*` / `WFBE_UP_*` constant naming patterns referenced in the generated weapon-removal guards.
- [Faction-Unit-And-Vehicle-Roster-Catalog](Faction-Unit-And-Vehicle-Roster-Catalog) — Complete roster of vehicles by faction and factory tier, cross-referenced against the data-model classes documented here.
