# Map Ruleset Model And Object Config

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted (other roots: Server/, Common/, Client/). Arma 2 OA 1.64.

Warfare picks the *physical* editor-objects used for the town depot, the capturable camps, and the airfield hangar from a per-ruleset config file under `Common/Config/Core_Models/`. Each file sets a small block of `WFBE_C_*` mission-namespace variables: the camp/depot/hangar classnames, the camp flag and its relative offset, a per-object placement rotation (`*_RDIR`), the build-menu spawn geometry (`*_BUY_DISTANCE` / `*_BUY_DIR`) and a camp damage-resistance coefficient (`WFBE_C_CAMP_HEALTH_COEF`). The split exists so the mission can run on either the legacy ArmA 2 base game object set (`Vanilla.sqf`) or the Operation Arrowhead / Combined Operations OA-DLC set (`CombinedOps.sqf`, `Arrowhead.sqf`), with a Chernarus-specific variant (`CombinedOps_W.sqf`) that keeps OA depot geometry but uses base-game camp/flag/hangar models.

## How a ruleset is selected and loaded

The model config is loaded once during common init via a `switch (true)` on the build-time ruleset flags (`Common/Init/Init_Common.sqf:225`). Only the Combined Operations case loads a model file, choosing the Chernarus variant when the map-dependent flag is set:

| Branch | File loaded | Line |
|---|---|---|
| `case WF_A2_CombinedOps`, `!(IS_chernarus_map_dependent)` | `Common\Config\Core_Models\CombinedOps.sqf` | `Common/Init/Init_Common.sqf:229` |
| `case WF_A2_CombinedOps`, `IS_chernarus_map_dependent` | `Common\Config\Core_Models\CombinedOps_W.sqf` | `Common/Init/Init_Common.sqf:231` |

The ruleset flags themselves are derived from preprocessor macros: `WF_A2_Vanilla` (`initJIPCompatible.sqf:95`), `WF_A2_Arrowhead` (`initJIPCompatible.sqf:100`), `WF_A2_CombinedOps` (`initJIPCompatible.sqf:105`) and `IS_chernarus_map_dependent` (`initJIPCompatible.sqf:115`), each toggled by an `#ifdef` (`VANILLA` / `ARROWHEAD` / `COMBINEDOPS` / `IS_CHERNARUS_MAP_DEPENDENT`). For this Chernarus mission the Combined Operations + Chernarus path is the live one, so `CombinedOps_W.sqf` supplies the runtime values. `Vanilla.sqf` and `Arrowhead.sqf` are parallel reference configs in the same folder that no code path in this mission loads — they document the base-game and pure-Arrowhead object sets respectively.

## Who consumes these variables

| Variable | Consumer | Line |
|---|---|---|
| `WFBE_C_DEPOT` | town depot model spawn | `Common/Init/Init_Town.sqf:82` |
| `WFBE_C_DEPOT_RDIR` | depot `setDir` offset | `Common/Init/Init_Town.sqf:83` |
| `WFBE_C_CAMP` | camp model spawn (per camp) | `Common/Init/Init_Town.sqf:99` |
| `WFBE_C_CAMP_RDIR` | camp `setDir` offset | `Common/Init/Init_Town.sqf:100` |
| `WFBE_C_CAMP_HEALTH_COEF` | camp `handleDamage` divisor | `Common/Init/Init_Town.sqf:104,106` |
| `WFBE_C_CAMP_FLAG` | camp flag model spawn | `Common/Init/Init_Town.sqf:110` |
| `WFBE_C_CAMP_FLAG_POS` | flag `setPos` via `modelToWorld` | `Common/Init/Init_Town.sqf:111` |
| `WFBE_C_HANGAR` | airfield/hangar model spawn | `Common/Init/Init_Airports.sqf:16`, `Server/FSM/server_town.sqf:493` |
| `WFBE_C_HANGAR_RDIR` | airfield/hangar `setDir` offset | `Common/Init/Init_Airports.sqf:17`, `Server/FSM/server_town.sqf:494` |
| `WFBE_C_DEPOT_BUY_DISTANCE` / `WFBE_C_DEPOT_BUY_DIR` | depot build-spawn geometry | `Client/Functions/Client_BuildUnit.sqf:155,156` |
| `WFBE_C_HANGAR_BUY_DISTANCE` / `WFBE_C_HANGAR_BUY_DIR` | hangar build-spawn geometry | `Client/Functions/Client_BuildUnit.sqf:160,161` |

`WFBE_C_CAMP_HEALTH_COEF` is wired as a divisor inside the camp's `handleDamage` event handler: incoming damage is divided by the coefficient, so a *higher* number makes a camp tankier (`Common/Init/Init_Town.sqf:106`). The buy-distance/buy-dir pair feeds `GetPositionFrom` to place freshly-built units a fixed offset out from the depot or hangar (`Client/Functions/Client_BuildUnit.sqf:164`).

## Vanilla.sqf — legacy base-game object set

| Variable | Value | Line |
|---|---|---|
| `WFBE_C_CAMP` | `WarfareBCamp` | `Common/Config/Core_Models/Vanilla.sqf:5` |
| `WFBE_C_CAMP_FLAG` | `FlagCarrierGUE` | `Common/Config/Core_Models/Vanilla.sqf:6` |
| `WFBE_C_CAMP_FLAG_POS` | `[-5,5]` | `Common/Config/Core_Models/Vanilla.sqf:7` |
| `WFBE_C_CAMP_HEALTH_COEF` | `30` | `Common/Config/Core_Models/Vanilla.sqf:8` |
| `WFBE_C_CAMP_RDIR` | `-90` | `Common/Config/Core_Models/Vanilla.sqf:9` |
| `WFBE_C_DEPOT` | `WarfareBDepot` | `Common/Config/Core_Models/Vanilla.sqf:10` |
| `WFBE_C_DEPOT_BUY_DIR` | `0` | `Common/Config/Core_Models/Vanilla.sqf:11` |
| `WFBE_C_DEPOT_BUY_DISTANCE` | `21` | `Common/Config/Core_Models/Vanilla.sqf:12` |
| `WFBE_C_DEPOT_RDIR` | `0` | `Common/Config/Core_Models/Vanilla.sqf:13` |
| `WFBE_C_HANGAR` | `WarfareBAirport` | `Common/Config/Core_Models/Vanilla.sqf:14` |
| `WFBE_C_HANGAR_BUY_DIR` | `0` | `Common/Config/Core_Models/Vanilla.sqf:15` |
| `WFBE_C_HANGAR_BUY_DISTANCE` | `60` | `Common/Config/Core_Models/Vanilla.sqf:16` |
| `WFBE_C_HANGAR_RDIR` | `180` | `Common/Config/Core_Models/Vanilla.sqf:17` |

## CombinedOps.sqf — Operation Arrowhead (EP1) object set

| Variable | Value | Line |
|---|---|---|
| `WFBE_C_CAMP` | `Land_Fort_Watchtower_EP1` | `Common/Config/Core_Models/CombinedOps.sqf:5` |
| `WFBE_C_CAMP_FLAG` | `FlagCarrierTakistan_EP1` | `Common/Config/Core_Models/CombinedOps.sqf:6` |
| `WFBE_C_CAMP_FLAG_POS` | `[-5,5]` | `Common/Config/Core_Models/CombinedOps.sqf:7` |
| `WFBE_C_CAMP_HEALTH_COEF` | `15` | `Common/Config/Core_Models/CombinedOps.sqf:8` |
| `WFBE_C_CAMP_RDIR` | `-90` | `Common/Config/Core_Models/CombinedOps.sqf:9` |
| `WFBE_C_DEPOT` | `Land_fortified_nest_big_EP1` | `Common/Config/Core_Models/CombinedOps.sqf:10` |
| `WFBE_C_DEPOT_BUY_DIR` | `0` | `Common/Config/Core_Models/CombinedOps.sqf:11` |
| `WFBE_C_DEPOT_BUY_DISTANCE` | `21` | `Common/Config/Core_Models/CombinedOps.sqf:12` |
| `WFBE_C_DEPOT_RDIR` | `0` | `Common/Config/Core_Models/CombinedOps.sqf:13` |
| `WFBE_C_HANGAR` | `Land_Mil_hangar_EP1` | `Common/Config/Core_Models/CombinedOps.sqf:14` |
| `WFBE_C_HANGAR_BUY_DIR` | `0` | `Common/Config/Core_Models/CombinedOps.sqf:15` |
| `WFBE_C_HANGAR_BUY_DISTANCE` | `60` | `Common/Config/Core_Models/CombinedOps.sqf:16` |
| `WFBE_C_HANGAR_RDIR` | `180` | `Common/Config/Core_Models/CombinedOps.sqf:17` |

## CombinedOps_W.sqf — Chernarus variant (live for this mission)

Identical to `CombinedOps.sqf` except for three values: the camp uses the base-game watchtower (no `_EP1` suffix), the camp flag reverts to the GUE flag, and the hangar reverts to the base-game `WarfareBAirport`. It keeps the OA `Land_fortified_nest_big_EP1` depot and the higher `30` camp health coefficient.

| Variable | Value | Line | Differs from CombinedOps.sqf |
|---|---|---|---|
| `WFBE_C_CAMP` | `Land_Fort_Watchtower` | `Common/Config/Core_Models/CombinedOps_W.sqf:5` | yes (no `_EP1`) |
| `WFBE_C_CAMP_FLAG` | `FlagCarrierGUE` | `Common/Config/Core_Models/CombinedOps_W.sqf:6` | yes |
| `WFBE_C_CAMP_FLAG_POS` | `[-5,5]` | `Common/Config/Core_Models/CombinedOps_W.sqf:7` | no |
| `WFBE_C_CAMP_HEALTH_COEF` | `30` | `Common/Config/Core_Models/CombinedOps_W.sqf:8` | yes (15 → 30) |
| `WFBE_C_CAMP_RDIR` | `-90` | `Common/Config/Core_Models/CombinedOps_W.sqf:9` | no |
| `WFBE_C_DEPOT` | `Land_fortified_nest_big_EP1` | `Common/Config/Core_Models/CombinedOps_W.sqf:10` | no |
| `WFBE_C_DEPOT_BUY_DIR` | `0` | `Common/Config/Core_Models/CombinedOps_W.sqf:11` | no |
| `WFBE_C_DEPOT_BUY_DISTANCE` | `21` | `Common/Config/Core_Models/CombinedOps_W.sqf:12` | no |
| `WFBE_C_DEPOT_RDIR` | `0` | `Common/Config/Core_Models/CombinedOps_W.sqf:13` | no |
| `WFBE_C_HANGAR` | `WarfareBAirport` | `Common/Config/Core_Models/CombinedOps_W.sqf:14` | yes |
| `WFBE_C_HANGAR_BUY_DIR` | `0` | `Common/Config/Core_Models/CombinedOps_W.sqf:15` | no |
| `WFBE_C_HANGAR_BUY_DISTANCE` | `60` | `Common/Config/Core_Models/CombinedOps_W.sqf:16` | no |
| `WFBE_C_HANGAR_RDIR` | `180` | `Common/Config/Core_Models/CombinedOps_W.sqf:17` | no |

## Arrowhead.sqf — pure Arrowhead reference set

Value-for-value identical to `CombinedOps.sqf` (OA models, camp health `15`). The only difference is line ordering: `WFBE_C_CAMP_RDIR` precedes `WFBE_C_CAMP_HEALTH_COEF` here, the reverse of the other three files.

| Variable | Value | Line |
|---|---|---|
| `WFBE_C_CAMP` | `Land_Fort_Watchtower_EP1` | `Common/Config/Core_Models/Arrowhead.sqf:5` |
| `WFBE_C_CAMP_FLAG` | `FlagCarrierTakistan_EP1` | `Common/Config/Core_Models/Arrowhead.sqf:6` |
| `WFBE_C_CAMP_FLAG_POS` | `[-5,5]` | `Common/Config/Core_Models/Arrowhead.sqf:7` |
| `WFBE_C_CAMP_RDIR` | `-90` | `Common/Config/Core_Models/Arrowhead.sqf:8` |
| `WFBE_C_CAMP_HEALTH_COEF` | `15` | `Common/Config/Core_Models/Arrowhead.sqf:9` |
| `WFBE_C_DEPOT` | `Land_fortified_nest_big_EP1` | `Common/Config/Core_Models/Arrowhead.sqf:10` |
| `WFBE_C_DEPOT_BUY_DIR` | `0` | `Common/Config/Core_Models/Arrowhead.sqf:11` |
| `WFBE_C_DEPOT_BUY_DISTANCE` | `21` | `Common/Config/Core_Models/Arrowhead.sqf:12` |
| `WFBE_C_DEPOT_RDIR` | `0` | `Common/Config/Core_Models/Arrowhead.sqf:13` |
| `WFBE_C_HANGAR` | `Land_Mil_hangar_EP1` | `Common/Config/Core_Models/Arrowhead.sqf:14` |
| `WFBE_C_HANGAR_BUY_DIR` | `0` | `Common/Config/Core_Models/Arrowhead.sqf:15` |
| `WFBE_C_HANGAR_BUY_DISTANCE` | `60` | `Common/Config/Core_Models/Arrowhead.sqf:16` |
| `WFBE_C_HANGAR_RDIR` | `180` | `Common/Config/Core_Models/Arrowhead.sqf:17` |

## Shared geometry (constant across all four files)

These values are identical in every ruleset and define the spawn offsets and placement rotations regardless of which object set is active:

| Variable | Value | Meaning |
|---|---|---|
| `WFBE_C_DEPOT_BUY_DISTANCE` | `21` | metres out from the depot a built unit spawns |
| `WFBE_C_HANGAR_BUY_DISTANCE` | `60` | metres out from the hangar a built aircraft spawns |
| `WFBE_C_DEPOT_BUY_DIR` / `WFBE_C_HANGAR_BUY_DIR` | `0` | spawn-direction offset added to the building's heading |
| `WFBE_C_CAMP_RDIR` | `-90` | camp model rotation offset |
| `WFBE_C_DEPOT_RDIR` | `0` | depot model rotation offset |
| `WFBE_C_HANGAR_RDIR` | `180` | hangar model rotation offset |
| `WFBE_C_CAMP_FLAG_POS` | `[-5,5]` | flag offset (model-space) from the camp |

## Continue Reading

- [Towns Camps And Capture Atlas](Towns-Camps-And-Capture-Atlas)
- [Factory And Purchase Systems Atlas](Factory-And-Purchase-Systems-Atlas)
- [Mission Start Parameters Index](Mission-Start-Parameters-Index)
- [Server HandleSpecial Request Router Reference](Server-HandleSpecial-Request-Router-Reference)
- [Miksuu Wiki Archive Project Script Architecture Of Chernarus Mission](Miksuu-Wiki-Archive-Project-Script-Architecture-Of-Chernarus-Mission)
