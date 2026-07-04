# AICOM V2 Takistan Profile Dataset

Guide rev: GR-2026-07-03a. Scope: static dataset/spec only.

## Source and count

Primary source harvested in this worktree: `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/mission.sqm` `Init_Town.sqf` calls. Current source contains 31 non-air town nodes plus 2 airfield capture nodes, matching the roster lane.

Profile key: `TK`.

Zone constants:

| Field | Value |
|---|---|
| `worldName` | `Takistan` |
| `boundary` | `12800` |
| `STARTING_DISTANCE` | `7500` |
| `IS_NAVAL_MAP` | `false` |
| `IS_DESERT` | `true` |
| `airfields` | `Loy Manara AF`, `Rasman AF` |
| `carrier` | none |
| `sourceTownCount` | `31` |
| `sourceAirfieldCount` | `2` |

## Constant overrides and caveats

```
[
  ["WFBE_C_AICOM_HQSTRIKE_MIN_TOWNS",12],
  ["WFBE_C_AICOM_ENGAGE_MIN_TOWNS",10],
  ["WFBE_C_AICOM_LANE_OFFSET",60],
  ["WFBE_C_AICOM_ASSAULT_REACH_FOOT",1800],
  ["WFBE_C_AICOM_ASSAULT_REACH_MOUNTED",9000],
  ["WFBE_C_AICOM_ROAD_STANDOFF",40],
  ["WFBE_C_AICOM_SLOPE_Z",0.80],
  ["WFBE_C_AICOM_AIR_MIN_TOWNS",3],
  ["WFBE_C_AICOM_GROUP_CAP",110],
  ["WFBE_C_TOTAL_AI_MAX_BY_TIER",[140,130,100,80]],
  ["WFBE_C_AICOM_TEAMS_HARD_CAP",10],
  ["AICOMV2_ATTACK_SUPERIORITY_MIN",1.30],
  ["AICOMV2_RETARGET_COST",1.1],
  ["AICOMV2_PAIN_TTL_SEC",900],
  ["AICOMV2_VISIBLE_EVENT_MAX_GAP_SEC",240]
]
```

Faction caveats:

| Field | Value |
|---|---|
| WEST faction index | US index `1` |
| EAST faction index | TKA index `2` |
| GUER faction index | TKGUE index `2` |
| WEST supply/transport heli | `UH60M_EP1` |
| EAST supply/transport heli | `Mi17_TK_EP1` |
| GUER caveat | Crew classname drift exists between `GUE_*` and `TK_GUE_*_EP1`; V2 must not infer GUER capability from one classname family only. |

## Node table

| id | name | pos [x,z] | startSV | maxSV | value | tier | townType | source line |
|---:|---|---:|---:|---:|---:|---|---|---:|
| 0 | Chak Chak | [4388.97,747.76] | 20 | 80 | 800 | Large | LargeTown1,LargeTown2 | 228 |
| 1 | Huzrutimam | [6077.82,1082.20] | 10 | 50 | 600 | Medium | MediumTown1,MediumTown2 | 322 |
| 2 | Landay | [2072.86,303.90] | 10 | 40 | 400 | Small | SmallTown1 | 404 |
| 3 | Loy Manara | [8532.20,2467.03] | 30 | 120 | 1000 | Huge | HugeTown1,HugeTown2 | 449 |
| 4 | Sultansafee | [6483.94,2080.52] | 10 | 50 | 500 | Small | SmallTown1,SmallTown2 | 531 |
| 5 | Jaza | [9231.87,1832.25] | 10 | 40 | 400 | Small | SmallTown1 | 693 |
| 6 | Chardarakht | [10276.69,2331.52] | 10 | 50 | 500 | Medium | MediumTown1,MediumTown2 | 740 |
| 7 | Hazar Bagh | [11925.73,2642.01] | 10 | 30 | 400 | Small | SmallTown1 | 810 |
| 8 | Chaman | [513.21,2805.57] | 10 | 50 | 500 | Small | SmallTown1,SmallTown2 | 875 |
| 9 | Shukurkalay | [1480.62,3513.28] | 10 | 60 | 600 | Medium | MediumTown1,MediumTown2 | 921 |
| 10 | Sakhee | [3673.49,4347.64] | 20 | 80 | 800 | Large | LargeTown1,LargeTown2 | 1003 |
| 11 | Jilavur | [2535.10,5046.54] | 10 | 50 | 500 | Small | SmallTown1,SmallTown2 | 1072 |
| 12 | Khushab | [1609.35,5681.86] | 10 | 50 | 500 | Small | SmallTown1,SmallTown2 | 1154 |
| 13 | Mulladoost | [2089.99,7687.06] | 10 | 60 | 600 | Medium | MediumTown1,MediumTown2 | 1236 |
| 14 | Kakaru | [5313.79,4779.64] | 10 | 50 | 500 | Small | SmallTown1,SmallTown2 | 1318 |
| 15 | Anar | [6135.38,5670.72] | 10 | 50 | 500 | Medium | SmallTown1,MediumTown1 | 1388 |
| 16 | Feeruz Abad | [5203.16,6070.18] | 30 | 120 | 1200 | Huge | HugeTown1,HugeTown2 | 1469 |
| 17 | Timurkalay | [8994.12,5337.14] | 10 | 50 | 500 | Small | SmallTown1,SmallTown2 | 1551 |
| 18 | Falar | [5957.86,7360.59] | 10 | 50 | 600 | Medium | MediumTown1,MediumTown2 | 1633 |
| 19 | Garmarud | [9101.43,6755.59] | 10 | 50 | 600 | Medium | MediumTown1,MediumTown2 | 1715 |
| 20 | Garmsar | [10880.75,6405.08] | 30 | 120 | 1000 | Huge | HugeTown1,HugeTown2 | 1796 |
| 21 | Imarat | [8208.20,7770.27] | 10 | 50 | 500 | Medium | SmallTown1,SmallTown2,MediumTown1 | 1878 |
| 22 | Gospandi | [3666.85,8540.13] | 10 | 50 | 500 | Small | SmallTown1,SmallTown2 | 1960 |
| 23 | Ravanay | [11483.86,8302.22] | 10 | 40 | 400 | Small | SmallTown1 | 2030 |
| 24 | Karachinar | [12295.61,10398.32] | 10 | 40 | 500 | Small | SmallTown1,SmallTown2 | 2076 |
| 25 | Nur | [1784.34,11932.75] | 10 | 50 | 500 | Small | SmallTown1,SmallTown2 | 2134 |
| 26 | Zavarak | [9813.36,11495.40] | 20 | 80 | 800 | Large | LargeTown1,LargeTown2 | 2180 |
| 27 | Bastam | [5871.40,8999.91] | 20 | 70 | 800 | Large | LargeTown1,LargeTown2 | 2250 |
| 28 | Nagara | [3139.70,9963.53] | 30 | 120 | 1000 | Huge | HugeTown1,HugeTown2 | 2355 |
| 29 | Rasman | [6309.18,11122.31] | 30 | 120 | 1000 | Huge | HugeTown1,HugeTown2 | 2436 |
| 30 | Shamali | [4080.54,11720.01] | 10 | 40 | 500 | Small | SmallTown1,SmallTown2 | 2554 |
| 31 | Loy Manara AF | [8191.00,1880.00] | 10 | 40 | 400 | Airfield | PMCAirfield | 2765 |
| 32 | Rasman AF | [5690.00,11260.00] | 10 | 40 | 400 | Airfield | PMCAirfield | 2799 |

## Route graph edges

TK topology uses two main spines: the north/south central-west corridor and the northeast/east highland corridor, with airfield connectors at `[8191,1803]` and `[5689,11181]`.

| from | to | roadBias | bearing | flags |
|---|---|---:|---:|---|
| Landay | Chak Chak | 0.85 | 79 | south-spine |
| Chak Chak | Huzrutimam | 0.90 | 79 | south-spine |
| Huzrutimam | Sultansafee | 0.90 | 22 | south-spine |
| Sultansafee | Loy Manara | 0.85 | 80 | south-spine,airfield-adjacent |
| Loy Manara | Loy Manara AF | 0.95 | 196 | airfield |
| Loy Manara AF | Jaza | 0.90 | 88 | airfield |
| Jaza | Chardarakht | 0.85 | 101 | east-spine |
| Chardarakht | Hazar Bagh | 0.75 | 98 | east-spine |
| Chaman | Shukurkalay | 0.80 | 35 | west-corridor |
| Shukurkalay | Sakhee | 0.85 | 68 | west-corridor |
| Sakhee | Jilavur | 0.70 | 322 | west-corridor |
| Jilavur | Khushab | 0.75 | 303 | west-corridor |
| Khushab | Mulladoost | 0.80 | 14 | west-corridor |
| Sakhee | Kakaru | 0.75 | 75 | central-link |
| Kakaru | Anar | 0.85 | 43 | central |
| Anar | Feeruz Abad | 0.90 | 299 | central |
| Feeruz Abad | Falar | 0.90 | 23 | central |
| Falar | Bastam | 0.90 | 178 | central-north |
| Bastam | Rasman | 0.90 | 11 | north-spine |
| Rasman | Rasman AF | 0.95 | 266 | airfield |
| Rasman AF | Shamali | 0.85 | 247 | airfield |
| Shamali | Nagara | 0.80 | 244 | north-west |
| Nagara | Nur | 0.70 | 320 | north-west |
| Nagara | Gospandi | 0.75 | 20 | west-link |
| Gospandi | Mulladoost | 0.70 | 236 | west-link |
| Gospandi | Bastam | 0.75 | 77 | central-north |
| Falar | Imarat | 0.80 | 78 | central-east |
| Imarat | Garmarud | 0.80 | 140 | east-corridor |
| Garmarud | Garmsar | 0.90 | 101 | east-corridor |
| Garmsar | Ravanay | 0.70 | 21 | east-highland |
| Ravanay | Karachinar | 0.70 | 23 | east-highland |
| Karachinar | Zavarak | 0.70 | 289 | north-east |
| Zavarak | Rasman | 0.80 | 265 | north-spine |
| Timurkalay | Garmarud | 0.75 | 12 | east-corridor |
| Timurkalay | Imarat | 0.75 | 326 | central-east |

## Oilfield and zone annotations

| zone | kind | polygon/center | tags | values |
|---|---|---|---|---|
| TK_BOUNDARY | boundary | [[0,0],[12800,0],[12800,12800],[0,12800]] | desert,mountain,no-naval | [12800] |
| SOUTH_SPINE | front | [[1800,300],[10500,300],[10500,3100],[1800,3100]] | road-spine,south | [0.85] |
| WEST_CORRIDOR | front | [[300,2600],[3800,2600],[3800,8200],[300,8200]] | west-road,corridor | [0.80] |
| CENTRAL_BASIN | front | [[3500,4300],[6700,4300],[6700,7600],[3500,7600]] | central,high-value | [0.85] |
| EAST_HIGHLAND | interior | [[8200,5000],[12600,5000],[12600,10600],[8200,10600]] | mountain,slow-road | [0.65] |
| NORTH_SPINE | front | [[3000,8800],[10200,8800],[10200,12100],[3000,12100]] | north-road,airfield | [0.85] |
| LOY_MANARA_AF | airfield | [[7900,1650],[8500,1650],[8500,2100],[7900,2100]] | airfield,south | [31] |
| RASMAN_AF | airfield | [[5450,10950],[5950,10950],[5950,11550],[5450,11550]] | airfield,north | [32] |
| TK_OILFIELD_PRIMARY | oilfield | [[4300,5900],[4900,5900],[4900,6500],[4300,6500]] | high-value,neutral-resource | [4600,6200,1200] |

Oilfield loader rule: treat `TK_OILFIELD_PRIMARY` as a special high-value zone, not a town node. AICOM V2 may plan around it as economy pressure, but normal town capture routing must not assume it exists in `towns`.

## Paste-ready profile skeleton

```
WFBE_AICOMV2_PROFILE_Takistan = [
  "AICOMV2_PROFILE_V1",
  "TK",
  "Takistan",
  _constants,
  _nodes,
  _edges,
  _zones,
  ["source","mission.sqm","guide","GR-2026-07-03a","nodes",33]
];
```
