# AICOM V2 Chernarus Profile Dataset

Guide rev: GR-2026-07-03a. Scope: static dataset/spec only.

## Source and count

Primary source harvested in this worktree: `Missions/[55-2hc]warfarev2_073v48co.chernarus/mission.sqm` `Init_Town.sqf` calls. Current source contains 43 non-air town nodes plus 3 airfield capture nodes. The roster text expected 40 towns plus 3 airfields; builder should trust the current `mission.sqm` list below unless owner decides to drop the three Khe Sanh imported nodes or another source-verification pass changes the count.

Profile key: `CH`.

Zone constants:

| Field | Value |
|---|---|
| `worldName` | `Chernarus` |
| `boundary` | `15360` |
| `STARTING_DISTANCE` | `7500` |
| `IS_NAVAL_MAP` | `true` |
| `terrainClass` | `FOREST_MIXED_COASTAL` |
| `airfields` | `NWAF`, `NEAF`, `Balota` |
| `sourceTownCount` | `43` |
| `sourceAirfieldCount` | `3` |

## Constant overrides

Use the map-profile format from `AICOM-V2-MAP-PROFILE-FORMAT.md`.

```
[
  ["WFBE_C_AICOM_HQSTRIKE_MIN_TOWNS",12],
  ["WFBE_C_AICOM_ENGAGE_MIN_TOWNS",10],
  ["WFBE_C_AICOM_LANE_OFFSET",120],
  ["WFBE_C_AICOM_ASSAULT_REACH_FOOT",2500],
  ["WFBE_C_AICOM_ASSAULT_REACH_MOUNTED",9000],
  ["WFBE_C_AICOM_ROAD_STANDOFF",24],
  ["WFBE_C_AICOM_SLOPE_Z",0.86],
  ["WFBE_C_AICOM_AIR_MIN_TOWNS",3],
  ["WFBE_C_AICOM_GROUP_CAP",110],
  ["WFBE_C_TOTAL_AI_MAX_BY_TIER",[140,130,100,80]],
  ["WFBE_C_AICOM_TEAMS_HARD_CAP",10],
  ["AICOMV2_ATTACK_SUPERIORITY_MIN",1.35],
  ["AICOMV2_RETARGET_COST",1.0],
  ["AICOMV2_PAIN_TTL_SEC",900],
  ["AICOMV2_VISIBLE_EVENT_MAX_GAP_SEC",240]
]
```

Supply/founding heli notes:

| Side | Primary supply/transport heli class |
|---|---|
| WEST | `UH60M_EP1`, `UH60M_MEV_EP1` available in the US core config; CH may also use USMC/RU legacy air where the current side config selects it. |
| EAST | RU air from current core config; V2 profile should not force TK-only `Mi17_TK_EP1` on CH. |
| GUER | GUER is hazard/third side, not planned by WEST/EAST AICOM V2. |

## Node table

Tier rule used here: `Huge` if town type contains `Huge` or maxSV >= 120; `Large` if contains `Large` or maxSV >= 80; `Medium` if contains `Medium`; `Small` if contains `Small`; `Tiny` otherwise.

| id | name | pos [x,z] | startSV | maxSV | value | tier | townType | source line |
|---:|---|---:|---:|---:|---:|---|---|---:|
| 0 | Khe Sanh Alpha | [14700.00,9400.00] | 10 | 50 | 400 | Large | LargeTown1 | 56 |
| 1 | Khe Sanh Bravo | [10000.00,700.00] | 10 | 50 | 400 | Large | LargeTown1 | 78 |
| 2 | Khe Sanh Charlie | [14700.00,2000.00] | 10 | 50 | 400 | Large | LargeTown1 | 100 |
| 3 | Kamenka | [1827.08,2260.66] | 10 | 45 | 300 | Small | SmallTown1,SmallTown2 | 195 |
| 4 | Pavlovo | [1754.48,3925.20] | 10 | 45 | 250 | Small | SmallTown1,SmallTown2 | 411 |
| 5 | Komarovo | [3512.40,2484.67] | 10 | 55 | 300 | Medium | MediumTown1,MediumTown2 | 481 |
| 6 | Zelenogorsk | [2591.27,5436.54] | 30 | 120 | 1000 | Huge | HugeTown1,HugeTown2 | 551 |
| 7 | Chernogorsk | [6832.99,2438.54] | 30 | 120 | 1000 | Huge | HugeTown1,HugeTown2 | 632 |
| 8 | Bor | [3333.86,3921.25] | 10 | 40 | 250 | Small | SmallTown1,SmallTown2 | 746 |
| 9 | Nadezhdino | [5924.69,4726.55] | 10 | 50 | 300 | Medium | MediumTown1,MediumTown2 | 816 |
| 10 | Prigorodki | [8118.15,3306.49] | 10 | 30 | 100 | Tiny | TinyTown1 | 886 |
| 11 | Pusta | [9110.39,3808.68] | 10 | 50 | 250 | Small | SmallTown1,SmallTown2 | 944 |
| 12 | Elektrozavodsk | [10279.91,1970.03] | 30 | 120 | 1000 | Huge | HugeTown1,HugeTown2 | 1013 |
| 13 | Kamyshovo | [11959.67,3522.60] | 10 | 40 | 200 | Tiny | TinyTown1 | 1107 |
| 14 | Tulga | [12784.89,4473.23] | 10 | 40 | 100 | Small | SmallTown1 | 1177 |
| 15 | Msta | [11395.06,5510.47] | 10 | 40 | 100 | Small | SmallTown1 | 1223 |
| 16 | Staroye | [10061.50,5438.97] | 20 | 80 | 500 | Large | LargeTown1,LargeTown2 | 1281 |
| 17 | Mogilevka | [7477.01,5203.26] | 20 | 100 | 500 | Large | LargeTown1,LargeTown2 | 1363 |
| 18 | Shakhovka | [9735.36,6516.89] | 10 | 45 | 250 | Tiny | TinyTown1 | 1457 |
| 19 | Guglovo | [8414.11,6737.77] | 10 | 55 | 250 | Medium | MediumTown1,MediumTown2 | 1528 |
| 20 | Novy Sobor | [7140.17,7757.68] | 10 | 65 | 300 | Medium | MediumTown1,MediumTown2 | 1598 |
| 21 | Vyshnoye | [6531.90,6151.38] | 10 | 60 | 250 | Medium | MediumTown1,MediumTown2 | 1691 |
| 22 | Pulkovo | [4994.72,5595.13] | 10 | 40 | 250 | Small | SmallTown1,SmallTown2 | 1761 |
| 23 | Myshkino | [1915.78,7439.47] | 10 | 40 | 250 | Small | TinyTown1,SmallTown1,SmallTown2 | 1831 |
| 24 | Pustoshka | [3111.67,7946.70] | 10 | 50 | 300 | Small | SmallTown1,SmallTown2 | 1900 |
| 25 | Stary Sobor | [6221.88,7821.85] | 30 | 150 | 500 | Huge | HugeTown1,HugeTown2 | 1983 |
| 26 | Vybor | [3724.35,8987.71] | 10 | 50 | 250 | Small | SmallTown1,SmallTown2 | 2065 |
| 27 | Lopatino | [2787.11,9831.53] | 20 | 80 | 500 | Large | LargeTown1,LargeTown2 | 2135 |
| 28 | Kabanino | [5423.96,8616.21] | 10 | 65 | 300 | Medium | MediumTown1,MediumTown2,SmallTown2 | 2216 |
| 29 | Petrovka | [4983.59,12593.04] | 10 | 40 | 250 | Small | SmallTown1,SmallTown2 | 2309 |
| 30 | Grishino | [6076.07,10377.68] | 20 | 80 | 500 | Large | LargeTown1,LargeTown2 | 2379 |
| 31 | Gvozdno | [8639.63,11946.33] | 10 | 40 | 250 | Small | SmallTown1,SmallTown2 | 2484 |
| 32 | Dolina | [11268.78,6593.47] | 10 | 50 | 250 | Small | SmallTown1,SmallTown2 | 2566 |
| 33 | Solnichniy | [13405.91,6177.93] | 20 | 80 | 500 | Large | LargeTown1,LargeTown2 | 2636 |
| 34 | Nizhnoye | [12958.45,8094.98] | 10 | 40 | 200 | Tiny | TinyTown1,SmallTown2 | 2718 |
| 35 | Polana | [10702.24,7983.44] | 10 | 50 | 300 | Medium | MediumTown1,MediumTown2 | 2788 |
| 36 | Gorka | [9629.25,8865.72] | 20 | 80 | 500 | Large | LargeTown1,LargeTown2 | 2870 |
| 37 | Dubrovka | [10492.45,9831.44] | 10 | 55 | 300 | Medium | MediumTown1,MediumTown2 | 2961 |
| 38 | Berezino | [12124.92,9145.05] | 30 | 120 | 1000 | Huge | HugeTown1,HugeTown2 | 3054 |
| 39 | Krasnostav | [10984.05,12372.46] | 30 | 120 | 1000 | Huge | HugeTown1,HugeTown2 | 3148 |
| 40 | Khelm | [12376.25,10878.05] | 10 | 45 | 100 | Small | SmallTown1 | 3230 |
| 41 | Olsha | [13385.61,12855.70] | 10 | 30 | 100 | Tiny | TinyTown1 | 3288 |
| 42 | Rogovo | [4732.78,6766.95] | 10 | 40 | 250 | Small | SmallTown1,SmallTown2 | 4684 |
| 43 | NWAF | [4470.00,10615.00] | 10 | 40 | 400 | Airfield | PMCAirfield | 4879 |
| 44 | NEAF | [11850.00,12690.00] | 10 | 40 | 400 | Airfield | PMCAirfield | 4913 |
| 45 | Balota | [4540.00,2285.00] | 10 | 40 | 400 | Airfield | PMCAirfield | 4947 |

## Route graph edges

These are adjacency edges for the profile loader. Road bias is estimated from Chernarus road topology: south coastal road and east coastal strip are high-bias; forest/north connectors are medium; Khe Sanh imported nodes are low-confidence long connectors.

| from | to | roadBias | bearing | flags |
|---|---|---:|---:|---|
| Kamenka | Komarovo | 0.90 | 77 | coastal,south |
| Kamenka | Pavlovo | 0.55 | 357 | inland |
| Komarovo | Balota | 0.95 | 83 | coastal,airfield |
| Balota | Chernogorsk | 0.95 | 91 | coastal |
| Chernogorsk | Prigorodki | 0.95 | 43 | coastal |
| Prigorodki | Pusta | 0.75 | 53 | inland |
| Pusta | Elektrozavodsk | 0.95 | 129 | coastal |
| Elektrozavodsk | Kamyshovo | 0.90 | 55 | coastal |
| Kamyshovo | Tulga | 0.75 | 41 | east-coastal |
| Tulga | Msta | 0.60 | 312 | inland |
| Msta | Staroye | 0.75 | 273 | inland |
| Staroye | Mogilevka | 0.85 | 275 | central |
| Mogilevka | Nadezhdino | 0.80 | 244 | central |
| Nadezhdino | Chernogorsk | 0.80 | 150 | central-south |
| Nadezhdino | Vyshnoye | 0.75 | 31 | central |
| Vyshnoye | Pulkovo | 0.65 | 250 | central |
| Pulkovo | Zelenogorsk | 0.75 | 266 | west |
| Zelenogorsk | Bor | 0.65 | 333 | west |
| Bor | Komarovo | 0.55 | 174 | west-south |
| Bor | Pavlovo | 0.55 | 270 | west |
| Zelenogorsk | Myshkino | 0.55 | 318 | west-forest |
| Myshkino | Pustoshka | 0.70 | 73 | west-forest |
| Pustoshka | Vybor | 0.75 | 40 | west-forest |
| Vybor | Lopatino | 0.70 | 319 | northwest |
| Lopatino | Petrovka | 0.60 | 39 | northwest |
| Petrovka | Grishino | 0.65 | 147 | north |
| Grishino | NWAF | 0.85 | 226 | airfield |
| NWAF | Vybor | 0.85 | 200 | airfield |
| NWAF | Kabanino | 0.75 | 140 | central-airfield |
| Kabanino | Stary Sobor | 0.90 | 83 | central |
| Stary Sobor | Novy Sobor | 0.95 | 87 | central |
| Novy Sobor | Guglovo | 0.75 | 122 | central |
| Guglovo | Shakhovka | 0.65 | 103 | central-east |
| Shakhovka | Staroye | 0.70 | 169 | central-east |
| Guglovo | Polana | 0.75 | 59 | east |
| Polana | Gorka | 0.85 | 321 | east |
| Gorka | Dubrovka | 0.75 | 48 | east |
| Dubrovka | Berezino | 0.80 | 121 | east-coastal |
| Berezino | Nizhnoye | 0.90 | 293 | east-coastal |
| Nizhnoye | Solnichniy | 0.90 | 169 | east-coastal |
| Solnichniy | Dolina | 0.75 | 259 | east |
| Dolina | Msta | 0.65 | 236 | east |
| Berezino | Khelm | 0.75 | 19 | east |
| Khelm | NEAF | 0.80 | 336 | airfield |
| NEAF | Krasnostav | 0.85 | 245 | airfield |
| Krasnostav | Olsha | 0.70 | 79 | north |
| Krasnostav | Gvozdno | 0.65 | 251 | north |
| Gvozdno | Grishino | 0.60 | 234 | north-forest |
| Rogovo | Pulkovo | 0.65 | 340 | central |
| Rogovo | Novy Sobor | 0.70 | 55 | central |
| Khe Sanh Bravo | Elektrozavodsk | 0.30 | 18 | imported,low-confidence |
| Khe Sanh Charlie | Solnichniy | 0.30 | 319 | imported,low-confidence |
| Khe Sanh Alpha | NEAF | 0.30 | 251 | imported,low-confidence |

## Zone annotations

| zone | kind | polygon/center | tags | values |
|---|---|---|---|---|
| CH_BOUNDARY | boundary | [[0,0],[15360,0],[15360,15360],[0,15360]] | forest,mixed,coastal | [15360] |
| SOUTH_COAST | front | [[1500,1500],[12500,1500],[12500,4200],[1500,4200]] | coastal,high-road-bias,early-contact | [0.90] |
| CENTRAL_SPINE | front | [[4300,4300],[8500,4300],[8500,9000],[4300,9000]] | central,road-spine,high-value | [0.80] |
| WEST_FOREST | interior | [[1500,5200],[5200,5200],[5200,10300],[1500,10300]] | forest,medium-road-bias | [0.60] |
| NORTH_AIRFIELD | airfield | [[3800,10000],[5300,10000],[5300,11200],[3800,11200]] | NWAF,airfield | [43] |
| EAST_COAST | front | [[10300,5500],[13700,5500],[13700,10300],[10300,10300]] | coastal,east-road | [0.85] |
| NORTH_EAST | interior | [[8500,10300],[13700,10300],[13700,13300],[8500,13300]] | NEAF,Krasnostav,Olsha | [44] |

## Paste-ready profile skeleton

```
WFBE_AICOMV2_PROFILE_Chernarus = [
  "AICOMV2_PROFILE_V1",
  "CH",
  "Chernarus",
  _constants,
  _nodes,
  _edges,
  _zones,
  ["source","mission.sqm","guide","GR-2026-07-03a","nodes",46]
];
```
