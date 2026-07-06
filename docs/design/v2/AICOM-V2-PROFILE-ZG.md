# AICOM V2 Zargabad Profile Dataset

Guide rev: GR-2026-07-03a. Scope: static dataset/spec only.

## Source and count

Primary sources harvested in this worktree:

- `docs/zargabad-campaign.json`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/mission.sqm` `Init_Town.sqf` calls
- Zargabad-specific constant blocks in `Common/Init/Init_CommonConstants.sqf`

Current source contains 10 non-air town nodes plus 1 airfield capture node. The profile is low-pop and dense; runtime `WFBE_BOUNDARIESXY` for `zargabad` is `8192` in `Common/Init/Init_Boundaries.sqf`, while the useful tactical envelope is the compact urban box around roughly `6000-6400`. V2 must read profile coordinates and zone envelopes explicitly, not infer map bounds from CH defaults and not clip ZG nodes to `6000`.

Profile key: `ZG`.

Zone constants:

| Field | Value |
|---|---|
| `worldName` | `Zargabad` |
| `runtimeBoundary` | `8192` |
| `STARTING_DISTANCE` | `5000` |
| `IS_NAVAL_MAP` | `false` |
| `IS_ZARGABAD_LOWPOP_MAP` | `true` |
| `airfields` | `Zargabad AF` |
| `sourceTownCount` | `10` |
| `sourceAirfieldCount` | `1` |

## Constant overrides

```
[
  ["WFBE_C_AICOM_HQSTRIKE_MIN_TOWNS",5],
  ["WFBE_C_AICOM_ENGAGE_MIN_TOWNS",4],
  ["WFBE_C_AICOM_LANE_OFFSET",60],
  ["WFBE_C_AICOM_ASSAULT_REACH_FOOT",1800],
  ["WFBE_C_AICOM_ASSAULT_REACH_MOUNTED",9000],
  ["WFBE_C_AICOM_ROAD_STANDOFF",24],
  ["WFBE_C_AICOM_SLOPE_Z",0.86],
  ["WFBE_C_AICOM_AIR_MIN_TOWNS",3],
  ["WFBE_C_AICOM_GROUP_CAP",110],
  ["WFBE_C_TOTAL_AI_MAX_BY_TIER",[80,80,70,60]],
  ["WFBE_C_AICOM_TEAMS_HARD_CAP",5],
  ["WFBE_C_AICOM_TEAMS_PC_LOW",6],
  ["WFBE_C_AICOM_TEAMS_PC_MID",5],
  ["WFBE_C_TOWNS_MERGE_TARGET",9],
  ["WFBE_C_AICOM_DISBAND_INTERVAL",150],
  ["WFBE_C_AICOM_DISBAND_INFANTRY_FLOOR",1],
  ["WFBE_C_BASE_EGRESS_MAP_BOUNDS",1],
  ["WFBE_C_AICOM_REPICK_PENALTY",800],
  ["WFBE_C_AICOM_REPICK_MEMORY_MIN",7],
  ["AICOMV2_ATTACK_SUPERIORITY_MIN",1.25],
  ["AICOMV2_RETARGET_COST",1.25],
  ["AICOMV2_PAIN_TTL_SEC",900],
  ["AICOMV2_VISIBLE_EVENT_MAX_GAP_SEC",180]
]
```

Ordnance and economy notes:

| Field | Value |
|---|---|
| Max commander ordnance profile range | `1500m` |
| ICBM | disabled/no ICBM profile |
| Shorter start distance effect | Attack arcs are compressed; do not use CH 2500m foot reach or 120m lane offset. |
| Price multipliers | BARRACKS `0.95`, LIGHT `1.15`, HEAVY `1.4`, AIRCRAFT `1.75`, AIRPORT `2.0`, DEPOT `1.0` |

## Node table

| id | name | pos [x,z] | startSV | maxSV | value | tier | townType | source line |
|---:|---|---:|---:|---:|---:|---|---|---:|
| 0 | Zargabad | [4071.37,4183.32] | 30 | 120 | 1200 | Huge | HugeTown1,HugeTown2 | SQM 57 |
| 1 | Zargabad AF | [3386.26,4082.67] | 10 | 40 | 400 | Airfield | PMCAirfield | SQM 131 |
| 2 | Yarum | [4154.24,3592.65] | 10 | 50 | 500 | Small | SmallTown1,SmallTown2 | SQM 162 |
| 3 | The Villa | [4813.26,4645.28] | 10 | 50 | 500 | Small | SmallTown1,SmallTown2 | SQM 204 |
| 4 | Nango | [2823.53,5022.13] | 20 | 80 | 800 | Large | LargeTown1,LargeTown2 | SQM 246 |
| 5 | Azizayt | [1929.89,4652.94] | 10 | 40 | 400 | Small | SmallTown1 | SQM 309 |
| 6 | Hazar Bagh | [3943.51,5957.63] | 10 | 40 | 400 | Small | SmallTown1 | SQM 351 |
| 7 | Military Base | [4982.72,6207.94] | 10 | 60 | 600 | Medium | MediumTown1,MediumTown2 | SQM 393 |
| 8 | Shahbaz | [3528.11,1932.74] | 10 | 40 | 400 | Small | SmallTown1 | SQM 446 |
| 9 | Firuz Baharv | [5059.49,1878.24] | 10 | 40 | 400 | Small | SmallTown1 | SQM 488 |
| 10 | Shur Dam | [2889.65,3143.63] | 10 | 40 | 400 | Small | SmallTown1 | SQM 530 |

## Route graph edges

ZG route graph is deliberately small. Wall-gap and rim exclusions are first-class flags so the planner does not treat every short Euclidean segment as equally drivable.

| from | to | roadBias | bearing | flags |
|---|---|---:|---:|---|
| Shahbaz | Shur Dam | 0.75 | 324 | south-west |
| Shahbaz | Firuz Baharv | 0.65 | 88 | south-rim |
| Firuz Baharv | Yarum | 0.70 | 329 | south-east |
| Shur Dam | Yarum | 0.75 | 53 | central-approach,wallGap |
| Shur Dam | Nango | 0.70 | 358 | west-approach |
| Yarum | Zargabad | 0.85 | 9 | urban-core,wallGap |
| Zargabad | Zargabad AF | 0.85 | 262 | urban-core,airfield |
| Zargabad | The Villa | 0.75 | 58 | urban-east |
| Zargabad | Nango | 0.80 | 302 | urban-west,wallGap |
| Nango | Azizayt | 0.70 | 247 | west-rim |
| Nango | Hazar Bagh | 0.65 | 40 | north-west |
| Hazar Bagh | Military Base | 0.70 | 76 | north-rim |
| Military Base | The Villa | 0.60 | 174 | east-rim,edgeExcluded |
| The Villa | Firuz Baharv | 0.55 | 173 | east-rim,edgeExcluded |
| Azizayt | Shur Dam | 0.55 | 137 | west-rim,edgeExcluded |

`wallGap=true` means the route crosses the central H-barrier gap and must be serialized into one convoy slot per side at a time. `edgeExcluded=true` means the edge is legal only if no central alternative exists; it should not be selected for first-line expansion unless the active target is on that rim.

## Zone annotations

| zone | kind | polygon/center | tags | values |
|---|---|---|---|---|
| ZG_BOUNDARY | boundary | [[0,0],[8192,0],[8192,8192],[0,8192]] | lowpop,urban,runtime | [8192] |
| CENTRAL_CORE | front | [[3300,3400],[4550,3400],[4550,4650],[3300,4650]] | urban,high-value,wallGap | [0,2] |
| H_BARRIER_WALL | urban-wall | [[3700,3300],[4500,3300],[4500,4700],[3700,4700]] | central-wall,h-barrier | [1] |
| WALL_GAP | chokepoint | [[3850,3750],[4250,3750],[4250,4300],[3850,4300]] | wallGap,convoy-limit | [1] |
| WEST_RIM | excluded | [[1700,3000],[3100,3000],[3100,5250],[1700,5250]] | rim,edgeExcluded | [1] |
| EAST_RIM | excluded | [[4750,1750],[5250,1750],[5250,6250],[4750,6250]] | rim,edgeExcluded | [1] |
| BLACK_MARKET_AF | airfield | [[3200,3900],[3550,3900],[3550,4250],[3200,4250]] | black-market,airfield | [1] |
| NORTH_MIL | front | [[3800,5700],[5250,5700],[5250,6350],[3800,6350]] | military,north | [7] |

## Loader integration requirements

1. Profile load must log `AICOMSTAT|v3|PROFILE|<side>|0|LOAD|map=Zargabad|profile=ZG|fallback=0|nodes=11|edges=15`.
2. Edge-guard integration must read `edgeFlags` and reject `edgeExcluded` routes while any non-excluded route exists to the same target tier.
3. Wall-gap routes must apply a convoy mutex keyed by `ZG_WALL_GAP`. If mutex is held, emit a wait decision rather than re-targeting.
4. Profile coordinate conversion must stay in raw 8192 runtime space for node positions. If a builder adds normalized tactical-envelope coordinates for scoring, store them in separate fields and never mix them with raw `pos [x,z]` nodes.

## Paste-ready profile skeleton

```
WFBE_AICOMV2_PROFILE_Zargabad = [
  "AICOMV2_PROFILE_V1",
  "ZG",
  "Zargabad",
  _constants,
  _nodes,
  _edges,
  _zones,
  ["source","mission.sqm+docs/zargabad-campaign.json+Init_Boundaries.sqf","guide","GR-2026-07-03a","nodes",11,"runtimeBoundary",8192]
];
```
