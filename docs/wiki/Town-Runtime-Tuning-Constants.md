# Town Runtime Tuning Constants (WFBE_C_TOWNS_* combat/garrison knobs)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

This page is the single index of the `WFBE_C_TOWNS_*` runtime tuning constants — the town capture geometry, AI-mortar fire control, detection ranges, defender/garrison lifecycle, group-merge targets, and group caps. They are assigned in `Common/Init/Init_CommonConstants.sqf`, mostly as plain `WFBE_C_X = …` lines (so a server `init.sqf` cannot pre-seed them) with a handful guarded by `if (isNil "WFBE_C_X") then {…}`. Most of these constants do **not** appear in `Rsc/Parameters.hpp`, so they are absent from the lobby-parameter index and the lobby cannot set them — see [Mission Start Parameters Index](Mission-Start-Parameters-Index). The exceptions are the lobby town knobs already catalogued there and excluded from the "lobby cannot set" claim: `WFBE_C_TOWNS_DEFENDER`, `WFBE_C_TOWNS_OCCUPATION`, `WFBE_C_TOWNS_PATROLS`, plus three constants this page still documents for completeness — `WFBE_C_TOWNS_CAPTURE_MODE` (param 73, `Parameters.hpp:467`, lobby default `2`), `WFBE_C_TOWNS_BUILD_PROTECTION_RANGE` (param 78, `Parameters.hpp:497`, lobby default `100`), and `WFBE_C_TOWNS_VEHICLES_LOCK_DEFENDER` (param 80, `Parameters.hpp:509`, lobby default `0`). All three are `if (isNil)`-guarded in `Init_CommonConstants.sqf`, so the `Init_CommonConstants` value is only a fallback the lobby overrides — the effective default is the lobby default, not the value shown in their rows below. This page is also distinct from [Town AI Group Composition Catalog](Town-AI-Group-Composition-Catalog), which documents the named group templates rather than the numeric knobs that scale and merge them.

Every row below was opened in source. The "Consumer" column names the FSM/function that reads the constant via `getVariable` (verified where a direct reader exists; a few constants are defined-but-not-directly-grepped and are flagged as such).

## Capture geometry & rate

`server_town.sqf` selects which range constant to use based on `WFBE_C_TOWNS_CAPTURE_MODE` (`server_town.sqf:13-19`): mode 0/default reads `CAPTURE_RANGE`, mode 1 reads `CAPTURE_THRESHOLD_RANGE`. The capture mode itself is the most heavily-commented knob in the block.

| Constant | Default | Line | Meaning | Consumer |
|---|---|---|---|---|
| `WFBE_C_TOWNS_CAPTURE_MODE` | `0` (fallback) | `Init_CommonConstants.sqf:482` | Capture rule. 0 Normal/Classic (flip on defender-clear + presence within `CAPTURE_RANGE`), 1 Threshold (140m majority), 2 All Camps (must hold every camp dismounted). A/B comment: changed 2→0 because mounted AI teams never satisfied mode 2's all-camps gate. **Lobby param 73** (`Parameters.hpp:467`, lobby default `2`); `if (isNil)`-guarded so the `0` shown is the dead fallback — effective default is the lobby `2` unless overridden. | `server_town.sqf:13` |
| `WFBE_C_TOWNS_CAPTURE_RANGE` | `40` | `Init_CommonConstants.sqf:495` | Range (m) for the classic-mode capture-presence check; also the commander-team capture scan radius. | `server_town.sqf:15`; `Common_RunCommanderTeam.sqf:596` |
| `WFBE_C_TOWNS_CAPTURE_THRESHOLD_RANGE` | `140` | `Init_CommonConstants.sqf:497` | Range (m) used when `CAPTURE_MODE = 1` (majority-presence threshold). | `server_town.sqf:16` |
| `WFBE_C_TOWNS_CAPTURE_RATE` | `0.4` | `Init_CommonConstants.sqf:496` | Per-tick town capture progress rate. | `server_town.sqf:20` |
| `WFBE_C_TOWNS_CAPTURE_ASSIST` | `400` | `Init_CommonConstants.sqf:494` | Range (m) within which a player counts toward the capture-assist credit on `TownCaptured`. | `Client/PVFunctions/TownCaptured.sqf:57` |

## Detection ranges

`server_town_ai.sqf` builds the town's idle and active activation radii from a base range scaled by these coefficients (`server_town_ai.sqf:11-12`); the air-detection height threshold is read at `:14`.

| Constant | Default | Line | Meaning | Consumer |
|---|---|---|---|---|
| `WFBE_C_TOWNS_DETECTION_RANGE_COEF` | `1` | `Init_CommonConstants.sqf:500` | Activation-range multiplier while the town is idle (town range × coef). | `server_town_ai.sqf:11`; `server_town.sqf:356` |
| `WFBE_C_TOWNS_DETECTION_RANGE_ACTIVE_COEF` | `1` | `Init_CommonConstants.sqf:499` | Activation-range multiplier once the town is active (town range × coef). | `server_town_ai.sqf:12` |
| `WFBE_C_TOWNS_DETECTION_RANGE_AIR` | `50` | `Init_CommonConstants.sqf:501` | Air units are detected only above this height (`_airHeight`). | `server_town_ai.sqf:14` |

## AI mortar fire control

The AI-mortar block tunes the town garrison's indirect fire. The scan/precognition/splash values have direct readers in the artillery core; the interval and min/max range are defined here as the town-side fire constraints (the min/max comments warn they must stay inside the artillery core values).

| Constant | Default | Line | Meaning |
|---|---|---|---|
| `WFBE_C_TOWNS_MORTARS_SCAN` | `60` | `Init_CommonConstants.sqf:502` | Radius scanned around a target for friends/enemies before firing. |
| `WFBE_C_TOWNS_MORTARS_INTERVAL` | `200` | `Init_CommonConstants.sqf:503` | Minimum seconds between AI mortar fires. |
| `WFBE_C_TOWNS_MORTARS_PRECOGNITION` | `25` | `Init_CommonConstants.sqf:504` | Percent chance the mortar fires on a target by precognition. |
| `WFBE_C_TOWNS_MORTARS_RANGE_MAX` | `750` | `Init_CommonConstants.sqf:505` | Max engagement range (m); must not exceed artillery core values. |
| `WFBE_C_TOWNS_MORTARS_RANGE_MIN` | `125` | `Init_CommonConstants.sqf:506` | Min engagement range (m); must not be below artillery core values. |
| `WFBE_C_TOWNS_MORTARS_SPLASH_RANGE` | `60` | `Init_CommonConstants.sqf:507` | AI mortar area-of-effect radius. |

## Defender & garrison lifecycle

Base-defense spawn timing and post-capture grace periods. `GUNNERS_ON_CAPTURE`, `DEFENSE_SPAWN_DELAY`, and `DEFENDER_LINGER` sit in a separate Task-32 block (`Init_CommonConstants.sqf:589-596`) and are consumed by the capture branch of `server_town.sqf`. The two `REINFORCEMENT_*` toggles default off and are defined in the lobby-adjacent guarded block.

| Constant | Default | Line | Meaning | Consumer |
|---|---|---|---|---|
| `WFBE_C_TOWNS_DEFENSE_RANGE` | `30` | `Init_CommonConstants.sqf:498` | Range (m) around the town used by the defense-patrol logic. | `server_town_patrol.sqf:17` |
| `WFBE_C_TOWNS_GUNNERS_ON_CAPTURE` | `true` | `Init_CommonConstants.sqf:589` | Immediately man static defenses on capture for all sides; `false` = reactive only. `if (isNil)`-overridable. | `server_town.sqf:289` |
| `WFBE_C_TOWNS_DEFENSE_SPAWN_DELAY` | `300` | `Init_CommonConstants.sqf:593` | Seconds after capture before the new owner's statics/defense teams spawn (with a fire-time ownership guard). | `server_town.sqf:286` |
| `WFBE_C_TOWNS_DEFENDER_LINGER` | `180` | `Init_CommonConstants.sqf:596` | Seconds the old owner's gunners keep fighting after capture before cleanup (fire-time guard aborts cleanup if the town flipped back). | `server_town.sqf:267` |
| `WFBE_C_TOWNS_REINFORCEMENT_DEFENDER` | `0` | `Init_CommonConstants.sqf:487` | Enable defender-side town reinforcement (off). `if (isNil)`-guarded. | defined; no direct reader grepped |
| `WFBE_C_TOWNS_REINFORCEMENT_OCCUPATION` | `0` | `Init_CommonConstants.sqf:488` | Enable occupation-side town reinforcement (off). `if (isNil)`-guarded. | defined; no direct reader grepped |
| `WFBE_C_TOWNS_VEHICLES_LOCK_DEFENDER` | `1` (fallback) | `Init_CommonConstants.sqf:490` | Lock the defender side's town vehicles. **Lobby param 80** (`Parameters.hpp:509`, lobby default `0`); `if (isNil)`-guarded so the `1` shown is the dead fallback — effective default is the lobby `0` unless overridden. | `server_patrols.sqf:10`; `Common_CreateTownUnits.sqf:31` |
| `WFBE_C_TOWNS_UNITS_INACTIVE` | `90` | `Init_CommonConstants.sqf:513` | Remove town units if no enemies are found within this many seconds. | `server_town_ai.sqf:15` |
| `WFBE_C_TOWNS_UNITS_SPAWN_CAPTURE_DELAY` | `1200` | `Init_CommonConstants.sqf:514` | If this many seconds elapsed since a town's last capture, units may respawn during the next capture. | defined; consumed via town capture state |
| `WFBE_C_TOWNS_UNITS_WAYPOINTS` | `9` | `Init_CommonConstants.sqf:515` | Base waypoint count for town garrison patrols (plus usable building positions). | `Common_WaypointPatrolTown.sqf:21` |
| `WFBE_C_TOWNS_BUILD_PROTECTION_RANGE` | `450` (fallback) | `Init_CommonConstants.sqf:481` | No construction allowed within this radius of a town. **Lobby param 78** (`Parameters.hpp:497`, lobby default `100`); `if (isNil)`-guarded so the `450` shown is the dead fallback — effective default is the lobby `100` unless overridden. | `updateavailableactions.fsm:38` |
| `WFBE_C_TOWNS_PURCHASE_RANGE` | `60` | `Init_CommonConstants.sqf:510` | Range (m) for town-based purchasing. | defined |

## Occupation / defender coefficients & garrison-size scaling

These two `switch`-derived coefficients are the bridge from the lobby difficulty knobs (`WFBE_C_TOWNS_OCCUPATION`, `WFBE_C_TOWNS_DEFENDER`) to garrison size. They are computed at init (`Init_CommonConstants.sqf:678-679`) and multiplied into `_groups_max` in the group builders.

| Constant | Default (Medium) | Line | Meaning | Consumer |
|---|---|---|---|---|
| `WFBE_C_TOWNS_UNITS_COEF` | `1.5` | `Init_CommonConstants.sqf:678` | Garrison-size multiplier from `WFBE_C_TOWNS_OCCUPATION` (case 1→1, 2→1.5, 3→2, 4→2.5, default 1). | `Server_GetTownGroups.sqf:141` |
| `WFBE_C_TOWNS_UNITS_DEFENDER_COEF` | `1.5` | `Init_CommonConstants.sqf:679` | Defender-garrison multiplier from `WFBE_C_TOWNS_DEFENDER` (same case ladder). | `Server_GetTownGroupsDefender.sqf:82` |

## Group-merge targets & caps

The merge constants fuse identical infantry rosters into fewer server group-brains (an FPS optimization that does not change which units spawn). `MERGE_TARGET` is global; the two `_DEFENDER` variants are GUER-specific A/B knobs raised above the historical hardcoded cap of 10.

| Constant | Default | Line | Meaning | Consumer |
|---|---|---|---|---|
| `WFBE_C_TOWNS_MERGE_TARGET` | `5` | `Init_CommonConstants.sqf:680` | Target units per consolidated town-garrison infantry group (hard cap 10). `0` disables merging (one group per template). Vehicles never merged. | `Server_GetTownGroups.sqf:222`; `Server_GetTownGroupsDefender.sqf:163` |
| `WFBE_C_TOWNS_MERGE_TARGET_DEFENDER` | `11` | `Init_CommonConstants.sqf:681` | GUER-only merge target (raised 9→11 to fuse defender garrisons harder). `if (isNil)`-guarded. | `Server_GetTownGroupsDefender.sqf:162` |
| `WFBE_C_TOWNS_MERGE_CAP_DEFENDER` | `12` | `Init_CommonConstants.sqf:682` | GUER-only merged-group size cap (raised from the global 10 so the 11-target can flush; 12 = classic A2 squad max). `if (isNil)`-guarded; falls back to 10. | `Server_GetTownGroupsDefender.sqf:164` |
| `WFBE_C_TOWNS_ACTIVE_MAX` | `12` | `Init_CommonConstants.sqf:108` | Max concurrently active towns (server-FPS budget lever). `if (isNil)`-guarded. | `server_town_ai.sqf:23` |

## Supply ladders

Per-upgrade-level supply rates, read by the town economy and upgrade-label logic. Which array is used depends on `WFBE_C_ECONOMY_SUPPLY_SYSTEM` (time-based vs truck-based).

| Constant | Default | Line | Meaning | Consumer |
|---|---|---|---|---|
| `WFBE_C_TOWNS_SUPPLY_LEVELS_TIME` | `[1, 2, 3, 4, 5]` | `Init_CommonConstants.sqf:511` | Time-based supply-rate ladder, indexed by the `SUPPLYRATE` upgrade level. | `server_town.sqf:81`; `Labels_Upgrades.sqf:19` |
| `WFBE_C_TOWNS_SUPPLY_LEVELS_TRUCK` | `[5, 6, 7, 8, 10]` | `Init_CommonConstants.sqf:512` | Truck-based supply ladder (used when `WFBE_C_ECONOMY_SUPPLY_SYSTEM != 1`). | `Labels_Upgrades.sqf:19` |

## Related GUER group ceiling

Not a `TOWNS_` constant but the backstop named throughout the town-tuning comments: `WFBE_C_GUER_GROUPS_MAX = 80` (`Init_CommonConstants.sqf:112`, `if (isNil)`-guarded) is the hard ceiling on total resistance groups (garrisons + uprising + side-patrols), bounding GUER growth toward the engine's ~144-groups/side limit. The `ACTIVE_MAX` and merge constants above are tuned with this cap as the worst-case backstop.

## Continue Reading

- [Mission Start Parameters Index](Mission-Start-Parameters-Index)
- [Experimental Feature-Flag Constants Reference](Experimental-Feature-Flag-Constants-Reference)
- [Town AI Group Composition Catalog](Town-AI-Group-Composition-Catalog)
- [Towns, Camps And Capture Atlas](Towns-Camps-And-Capture-Atlas)
- [Town AI Vehicle Despawn Safety](Town-AI-Vehicle-Despawn-Safety)
