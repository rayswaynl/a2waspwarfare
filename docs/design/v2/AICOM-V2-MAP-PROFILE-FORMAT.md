# AICOM V2 Map Profile Format Spec

Guide rev: GR-2026-07-03a. Scope: final-form format spec only.

## Profile object

The supervisor reads one missionNamespace variable at boot:

`WFBE_AICOMV2_PROFILE_<worldName>`

For current maps:

| worldName | profile key | variable |
|---|---|---|
| `Chernarus` | `CH` | `WFBE_AICOMV2_PROFILE_Chernarus` |
| `Takistan` | `TK` | `WFBE_AICOMV2_PROFILE_Takistan` |
| `Zargabad` | `ZG` | `WFBE_AICOMV2_PROFILE_Zargabad` |

Record shape:

`["AICOMV2_PROFILE_V1", key, worldName, constants, nodes, edges, zones, loaderMeta]`

All fields are arrays, strings and numbers. Do not use hash maps.

## Constants bundle

`constants` shape:

`[["NAME", value], ["NAME2", value2], ...]`

Loader rule:

1. Read the profile variable with a nil guard.
2. If missing or malformed, use built-in defaults and log `fallback=1`.
3. For every constant, apply it only to V2 local profile state. Do not overwrite V1 globals unless the builder intentionally wires a compatibility bridge.
4. If a V2 constant mirrors an existing V1 `WFBE_C_AICOM_*`, keep the same name in the bundle.

Current source-derived terrain-sensitive defaults:

| Constant | CH | TK | ZG | Source evidence |
|---|---:|---:|---:|---|
| `WFBE_C_AICOM_HQSTRIKE_MIN_TOWNS` | 12 | 12 | 5 | `Init_CommonConstants.sqf:620`, ZG preset `:86` |
| `WFBE_C_AICOM_ENGAGE_MIN_TOWNS` | 10 | 10 | 4 | `Init_CommonConstants.sqf:721`, ZG preset `:87` |
| `WFBE_C_AICOM_LANE_OFFSET` | 120 | 60 | 60 | `Init_CommonConstants.sqf:380`, ZG preset `:88` |
| `WFBE_C_AICOM_ASSAULT_REACH_FOOT` | 2500 | 1800 | 1800 | `Init_CommonConstants.sqf:1273`, ZG preset `:89` |
| `WFBE_C_AICOM_ASSAULT_REACH_MOUNTED` | 9000 | 9000 | 9000 | `Init_CommonConstants.sqf:1274` |
| `WFBE_C_AICOM_ROAD_STANDOFF` | 24 | 40 | 24 | `Init_CommonConstants.sqf:376` |
| `WFBE_C_AICOM_SLOPE_Z` | 0.86 | 0.80 | 0.86 | `Init_CommonConstants.sqf:1288` |
| `WFBE_C_AICOM_AIR_MIN_TOWNS` | 3 | 3 | 3 | `Init_CommonConstants.sqf:357` |
| `WFBE_C_AICOM_GROUP_CAP` | 110 | 110 | 110 | `Init_CommonConstants.sqf:372` |
| `WFBE_C_TOTAL_AI_MAX_BY_TIER` | `[140,130,100,80]` | `[140,130,100,80]` | `[80,80,70,60]` | `Init_CommonConstants.sqf:350`, ZG override `:1815` |
| `WFBE_C_AICOM_TEAMS_HARD_CAP` | 10 | 10 | 5 | `Init_CommonConstants.sqf:328`, ZG override `:1819` |
| `WFBE_C_AICOM_TEAMS_PC_LOW` | 10 | 10 | 6 | `Init_CommonConstants.sqf:324`, ZG override `:1822` |
| `WFBE_C_AICOM_TEAMS_PC_MID` | 7 | 7 | 5 | `Init_CommonConstants.sqf:325`, ZG override `:1823` |
| `WFBE_C_TOWNS_MERGE_TARGET` | 5 | 5 | 9 | ZG override `Init_CommonConstants.sqf:1830`; CH/TK legacy target referenced by rollback comment |
| `WFBE_C_AICOM_DISBAND_INTERVAL` | 300 | 300 | 150 | ZG override `Init_CommonConstants.sqf:1835`; CH/TK rollback comment |
| `WFBE_C_AICOM_DISBAND_INFANTRY_FLOOR` | 2 | 2 | 1 | ZG override `Init_CommonConstants.sqf:1836`; CH/TK rollback comment |
| `WFBE_C_BASE_EGRESS_MAP_BOUNDS` | 0 | 0 | 1 | `Init_CommonConstants.sqf:1093`, ZG preset `:94` |
| `WFBE_C_AICOM_REPICK_PENALTY` | default V1 | default V1 | 800 | ZG preset `Init_CommonConstants.sqf:100` |
| `WFBE_C_AICOM_REPICK_MEMORY_MIN` | default V1 | default V1 | 7 | ZG preset `Init_CommonConstants.sqf:101` |

Recommended V2-only constants, profile-owned:

| Constant | Type | Default | Meaning |
|---|---|---:|---|
| `AICOMV2_ATTACK_SUPERIORITY_MIN` | number | 1.35 | Minimum attacker:defender local strength for attack. |
| `AICOMV2_RETARGET_COST` | number | 1.0 | Hysteresis penalty applied to changing a live target. |
| `AICOMV2_PAIN_TTL_SEC` | number | 900 | Pain-memory retention. |
| `AICOMV2_VISIBLE_EVENT_MAX_GAP_SEC` | number | 240 | No-dead-air pulse ceiling. |
| `AICOMV2_KPI_FLATLINE_WINDOW_SEC` | number | 1800 | Self-watchdog window. |

## Route graph schema

Nodes are encoded as parallel arrays so SQF builders can avoid nested object-like parsing:

`nodes = [nodeNames, nodePos, nodeSupply, nodeMaxSupply, nodeValue, nodeType, nodeTier, nodeFlags]`

| Parallel array | Item type | Example |
|---|---|---|
| `nodeNames` | string | `"Chernogorsk"` |
| `nodePos` | array `[x,z]` | `[6832.99,2438.54]` |
| `nodeSupply` | number | `30` |
| `nodeMaxSupply` | number | `120` |
| `nodeValue` | number | `1000` |
| `nodeType` | string | `"HugeTown1,HugeTown2"` |
| `nodeTier` | string | `"Huge"` |
| `nodeFlags` | string | `"coastal,urban"` |

Edge schema:

`edges = [edgeFrom, edgeTo, edgeRoadBias, edgeBearing, edgeFlags]`

| Parallel array | Type | Meaning |
|---|---|---|
| `edgeFrom` | string | From town name. |
| `edgeTo` | string | To town name. |
| `edgeRoadBias` | number | `0.0` cross-country only, `1.0` pure road. |
| `edgeBearing` | number | Approximate approach bearing from `from` to `to`, degrees 0-359. |
| `edgeFlags` | string | CSV tags: `coastal`, `spine`, `chokepoint`, `wallGap`, `edgeExcluded`, `airfield`, `oilfield`. |

Builder rule: edge lists are undirected unless `oneway` appears in `edgeFlags`. Planning may traverse both directions and should preserve the stored bearing for the forward direction; reverse bearing is `(bearing + 180) % 360`.

## Zone annotations

`zones = [zoneNames, zoneKind, zonePolygon, zoneTags, zoneValues]`

| Array | Type | Meaning |
|---|---|---|
| `zoneNames` | string | Stable name. |
| `zoneKind` | string | `"front"`, `"coastal"`, `"interior"`, `"chokepoint"`, `"airfield"`, `"oilfield"`, `"excluded"`, `"urban-wall"`. |
| `zonePolygon` | array | `[[x,z],[x,z],...]`; for point zones use a 4-point square. |
| `zoneTags` | string | CSV tags. |
| `zoneValues` | array | Numeric bundle. Meaning depends on kind; document in profile file. |

Every profile must include:

| Annotation | Required |
|---|---|
| `boundary` | Map playable box from `WFBE_BOUNDARIESXY` or version template. |
| `front-zone` | Polygon(s) where first-line fights normally happen. |
| `interior` | Towns not suited as first contact unless owned front collapses. |
| `chokepoint` | Route graph edges that should not receive multiple simultaneous convoys. |
| `coastal` | True on CH coastal roads and any future naval map. |
| `airfield` | Capture airfield nodes and radius. |

## Loader contract

Supervisor boot:

1. Build `_varName = format ["WFBE_AICOMV2_PROFILE_%1", worldName]`.
2. `_profile = missionNamespace getVariable _varName;`
3. If nil or wrong schema, call `WFBE_SE_FNC_AICOMV2_DefaultProfile`.
4. Validate node parallel arrays have equal length.
5. Validate edge parallel arrays have equal length.
6. Validate every edge endpoint exists in `nodeNames`.
7. Validate every profile constant is `[string, scalar/string/array]`.
8. Log `AICOMSTAT|v3|PROFILE|<side>|0|LOAD|map=<world>|profile=<key>|fallback=<0/1>|nodes=<n>|edges=<n>|constants=<n>`.

A2 safety:

Do not use `params`, `pushBack`, `apply`, `findIf`, hash maps, `isEqualTo`, `distance2D`, string `find`, or substring `select [a,b]`. Use indexed arrays and loop counters.

## Terrain comparison summary

| Profile | Boundary | Starting distance | Naval | Airfields | Terrain doctrine |
|---|---:|---:|---|---:|---|
| CH | 15360 | 7500 | yes | 3 | Forest/mixed, long coastal and central spines, wider lane offset. |
| TK | 12800 | 7500 | no | 2 | Desert/mountain, road-spine dependent, tighter lane offset and lower slope threshold. |
| ZG | 8192 runtime `WFBE_BOUNDARIESXY`; 6000-6400 compact tactical envelope | 5000 | no | 1 | Dense low-pop urban, short reach, reduced AI caps, central wall gap and edge exclusions. Runtime boundary is source-verified in `Init_Boundaries.sqf`; do not clip nodes to 6000 because `Military Base` sits above that line. |
