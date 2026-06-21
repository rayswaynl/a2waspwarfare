# Mission Tunable Constants Catalog (WFBE_C_* defaults, lines, roles)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

`Common/Init/Init_CommonConstants.sqf` is the build's master tuning surface: a single 710-line file that defines every `WFBE_C_*` (and a handful of bare `WFBE_*` / `TEAM_*`) gameplay constant before any subsystem boots. This page catalogs the in-scope thematic sections by their exact source line, default value, guard, and one-line role. It is a config catalog, not a behavior audit.

**Guard column — the param-overridable vs forced distinction.** Most of the file runs inside one `with missionNamespace do { ... }` block (opens at `Init_CommonConstants.sqf:73`). Two assignment forms coexist:
- **isNil-default** (`if (isNil "X") then {X = ...}`): param-overridable. A lobby/mission parameter that sets `X` earlier wins; this line is only the fallback default (see [Mission Start Parameters Index](Mission-Start-Parameters-Index)). Names are quoted with either `"X"` or `'X'` — both are valid Arma 2.
- **forced** (bare `X = ...`): unconditional assignment, cannot be changed by a param. A few are **env-conditional** (`if (WF_Debug)` / `if (WF_A2_Vanilla)` / `if (IS_chernarus_map_dependent)`) — still forced, but the value branches on environment, noted inline.

**Two blocks are EXCLUDED here and documented elsewhere** (do not duplicate): the contiguous `//--- AI.` block (`Init_CommonConstants.sqf:102-264`, plus the stuck/assault/slope constants under `//--- Camps.`) is in [AI Commander Tunable Constants Reference](AI-Commander-Tunable-Constants-Reference); the dashboard/leaderboard announcer + `// === EXPERITAL FEATURES ===` block + QoL/restart/player-stats flags (`Init_CommonConstants.sqf:553-561`, `563-629`, `688-707`) are in [Experimental Feature-Flag Constants Reference](Experimental-Feature-Flag-Constants-Reference).

## Side statics and upgrade index

Bare integer enums — side IDs and the upgrade-array index map. All forced (no params), no defaults.

| Constant | Default | Line | Guard | Role |
|---|---|---|---|---|
| `WFBE_C_WEST_ID` | `0` | 30 | forced | Side ID: WEST. |
| `WFBE_C_EAST_ID` | `1` | 31 | forced | Side ID: EAST. |
| `WFBE_C_GUER_ID` | `2` | 32 | forced | Side ID: resistance/GUER. |
| `WFBE_C_CIV_ID` | `3` | 33 | forced | Side ID: civilian. |
| `WFBE_C_UNKNOWN_ID` | `4` | 34 | forced | Side ID: unknown. |
| `WFBE_UP_BARRACKS` … `WFBE_UP_PATROLS` | `0`…`23` | 37-60 | forced | 24 upgrade-array index constants (BARRACKS=0, LIGHT=1, HEAVY=2, AIR=3, PARATROOPERS=4, UAV=5, SUPPLYRATE=6, RESPAWNRANGE=7, AIRLIFT=8, FLARESCM=9, ARTYTIMEOUT=10, ICBM=11, FASTTRAVEL=12, GEAR=13, AMMOCOIN=14, EASA=15, SUPPLYPARADROP=16, ARTYAMMO=17, IRSMOKE=18, AIRAAM=19, AAR=20, UNITCOST=21, CBRADAR=22, PATROLS=23). Each index must match the upgrades arrays. |

## Side patrols and GUER playable faction

`SIDE_PATROLS_MAX` is the only constant defined before the `with missionNamespace` block; the GUER gate opens that block.

| Constant | Default | Line | Guard | Role |
|---|---|---|---|---|
| `WFBE_C_SIDE_PATROLS_MAX` | `2` | 63 | isNil-default | B36.1: WEST/EAST max concurrent patrol teams per side (3→2). Effective cap is level-aware (`min(this, patrol level)`) in `server_side_patrols.sqf`. |
| `WFBE_C_GUER_PLAYERSIDE` | `0` | 76 | isNil-default | GUER "Insurgents" playable-faction master gate (0=off, 1=on). Default OFF = byte-for-byte today's behaviour. |
| `WFBE_C_GUER_VBIED_ARM_DELAY` | `3` | 77 | isNil-default | GUER VBIED arming delay (s). |
| `WFBE_C_GUER_VBIED_BLAST_RADIUS` | `30` | 78 | isNil-default | GUER VBIED blast radius (m). |
| `WFBE_C_GUER_VBIED_TYPE` | `"hilux1_civil_2_covered"` | 79 | isNil-default | GUER VBIED vehicle classname. |
| `WFBE_C_GUER_KILL_BOUNTY_COEF` | `0.5` | 80 | isNil-default | GUER kill-bounty coefficient. |

## Day/night cycle (Marty hybrid)

The hybrid accelerated day/night system. Enable + durations + sync tuning are param-overridable; the forced-month/day and the visual phase boundaries are bare.

| Constant | Default | Line | Guard | Role |
|---|---|---|---|---|
| `WFBE_DAYNIGHT_ENABLED` | `1` | 84 | isNil-default | Enable the hybrid accelerated day/night cycle. |
| `WFBE_DAY_DURATION` | `180` | 86 | isNil-default | Real-life duration of daytime (minutes). |
| `WFBE_NIGHT_DURATION` | `30` | 87 | isNil-default | Real-life duration of nighttime (minutes). |
| `WFBE_DAYNIGHT_CLIENT_TICK` | `0.1` | 89 | isNil-default | Seconds between each small client-side time step. |
| `WFBE_DAYNIGHT_SERVER_SYNC_INTERVAL` | `30` | 90 | isNil-default | Seconds between authoritative server date broadcasts. |
| `WFBE_DAYNIGHT_CLIENT_MAX_CORRECTION` | `0.0005` | 91 | isNil-default | Max drift correction in game hours per client tick. |
| `WFBE_DAYNIGHT_CLIENT_HARD_SYNC_DRIFT` | `6` | 92 | isNil-default | Drift (game hours) before one exceptional setDate correction. |
| `WFBE_DAYNIGHT_FORCED_MONTH` | `6` | 94 | forced | Force June when the accelerated cycle is enabled. |
| `WFBE_DAYNIGHT_FORCED_DAY` | `28` | 95 | forced | Force the 28th day when the accelerated cycle is enabled. |
| `WFBE_DAYNIGHT_DAWN_START` | `4` | 96 | forced | Dawn starts ~04:00. |
| `WFBE_DAYNIGHT_DAWN_END` | `5` | 97 | forced | Full daylight ~05:00. |
| `WFBE_DAYNIGHT_DUSK_START` | `20.5` | 98 | forced | Dusk starts ~20:30. |
| `WFBE_DAYNIGHT_DUSK_END` | `21.5` | 99 | forced | Night starts ~21:30. |
| `WFBE_DAYNIGHT_TWILIGHT_WEIGHT` | `3` | 100 | forced | Dawn/dusk game hours take x times longer than full-daylight game hours. |

## Camps (non-AI)

The `//--- Camps.` heading (`Init_CommonConstants.sqf:265`) contains both camp constants and the AI-commander stuck/assault/slope constants. **The AI constants `WFBE_C_AICOM_STUCK_*` / `_ASSAULT_*` / `_SLOPE_Z` (lines 274-298) are documented in [AI Commander Tunable Constants Reference](AI-Commander-Tunable-Constants-Reference).** The genuine camp constants:

| Constant | Default | Line | Guard | Role |
|---|---|---|---|---|
| `WFBE_C_CAMPS_CREATE` | `1` | 266 | isNil-default | Create the camp models. |
| `WFBE_C_CAMPS_CAPTURE_BOUNTY` | `500` | 267 | forced | Bounty paid to the player who captures a camp. |
| `WFBE_C_CAMPS_CAPTURE_RATE` | `20` | 268 | forced | Camp capture rate. |
| `WFBE_C_CAMPS_CAPTURE_RATE_MAX` | `25` | 269 | forced | Camp capture rate ceiling. |
| `WFBE_C_CAMPS_RANGE` | `10` | 270 | forced | Camp capture range (m). |
| `WFBE_C_CAMPS_RANGE_PLAYERS` | `5` | 271 | forced | Camp capture range for players (m). |
| `WFBE_C_CAMPS_REPAIR_DELAY` | `15` | 299 | forced | Camp repair delay (s). |
| `WFBE_C_CAMPS_REPAIR_PRICE` | `500` | 300 | forced | Camp repair price. |
| `WFBE_C_CAMPS_REPAIR_RANGE` | `15` | 301 | forced | Camp repair range (m). |

## Economy

The dual-currency core (funds + supply), starting balances (debug-branched), income system, and the supply-mission economy knobs.

| Constant | Default | Line | Guard | Role |
|---|---|---|---|---|
| `WFBE_C_ECONOMY_CURRENCY_SYSTEM` | `0` | 304 | isNil-default | 0: Funds + Supply, 1: Funds only. |
| `WFBE_C_ECONOMY_FUNDS_START_WEST` | `30000` (debug `900000`) | 307 | isNil-default, env (`WF_Debug`) | WEST starting funds. |
| `WFBE_C_ECONOMY_FUNDS_START_EAST` | `30000` (debug `900000`) | 308 | isNil-default, env (`WF_Debug`) | EAST starting funds. |
| `WFBE_C_ECONOMY_FUNDS_START_GUER` | `20000` (debug `900000`) | 309 | isNil-default, env (`WF_Debug`) | GUER starting funds. |
| `WFBE_C_AI_COMMANDER_START_FUNDS` | `200000` | 311 | isNil-default | B36 hotfix: AI commander flat 200k cash (it runs the whole side). Defined here in the Economy block; fully documented on the [AI Commander Tunable Constants Reference](AI-Commander-Tunable-Constants-Reference) page. |
| `WFBE_C_ECONOMY_INCOME_INTERVAL` | `60` | 312 | isNil-default | Income interval (seconds between paychecks). |
| `WFBE_C_ECONOMY_INCOME_SYSTEM` | `3` | 313 | isNil-default | Income system (1:Full, 2:Half, 3:Commander, 4:Commander Full). |
| `WFBE_C_ECONOMY_SUPPLY_START_WEST` | `12800` (debug `900000`) | 314 | isNil-default, env (`WF_Debug`) | WEST starting supply. |
| `WFBE_C_ECONOMY_SUPPLY_START_EAST` | `12800` (debug `900000`) | 315 | isNil-default, env (`WF_Debug`) | EAST starting supply. |
| `WFBE_C_ECONOMY_SUPPLY_START_GUER` | `30000` (debug `900000`) | 316 | isNil-default, env (`WF_Debug`) | GUER starting supply. |
| `WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT` | `40000` (debug `900000`) | 317 | isNil-default, env (`WF_Debug`) | Global supply ceiling. |
| `WFBE_C_ECONOMY_SUPPLY_SYSTEM` | `1` | 318 | isNil-default | Supply system (0: Trucks, 1: Automatic with time). |
| `WFBE_C_ECONOMY_INCOME_COEF` | `8` | 319 | forced | Town income multiplier (SV × x). |
| `WFBE_C_ECONOMY_INCOME_DIVIDED` | `1.2` | 320 | forced | Caps commander income; remainder goes to the players' pool. |
| `WFBE_C_ECONOMY_INCOME_PERCENT_MAX` | `30` | 321 | forced | Commander may set income up to x%. |
| `WFBE_C_ECONOMY_SUPPLY_TIME_INCREASE_DELAY` | `60` | 322 | forced | SV increase delay (s). |
| `WFBE_C_ECONOMY_SUPPLY_MAX_TEAM_LIMIT` | `50000` | 323 | forced | Per-team supply limit. |
| `WFBE_C_ECONOMY_SUPPLY_MISSION_MULTIPLIER` | `20` | 324 | forced | Supply-mission reward multiplier. |
| `WFBE_C_SUPPLY_HELI_REWARD_MULT` | `1.25` | 326 | forced | Pilot air-delivery bonus (+25%, money and score). |
| `WFBE_C_SUPPLY_CASHRUN_COMMANDER_CUT` | `0.20` | 327 | forced | Commander tithe on cash runs (20% of pilot reward, minted on top). |
| `WFBE_C_SUPPLY_INTERDICTION_CUT` | `0.25` | 328 | forced | Enemy reward for downing a loaded supply vehicle (25% of cargo). |
| `WFBE_C_SUPPLY_HELI_LOAD_TIME` | `15` | 329 | forced | Seconds to load a supply helicopter at a town (channeled). |
| `WFBE_C_SUPPLY_HELI_UNLOAD_TIME` | `15` | 330 | forced | Seconds the helicopter must hover/sit at the Command Center to unload. |
| `WFBE_C_SUPPLY_TRUCK_TYPES` | 7-classname array | 332 | forced | Supply-truck classnames (always eligible). |
| `WFBE_C_SUPPLY_HELI_TYPES` | `['MH60S','Mi17_Ins']` (Chernarus) | 334 | forced, env (`IS_chernarus_map_dependent`) | Per-side supply-heli classnames; Takistan branch `['UH60M_EP1','Mi17_TK_EP1']`. Reset to `[]` at line 336 if `WFBE_C_SUPPLY_HELI_ENABLED != 1`. |
| `WFBE_C_SUPPLY_HELI_ENABLED` | `1` | 335 | isNil-default | Lobby toggle to shelve the heli feature without a repack. |
| `WFBE_C_SUPPLY_VEHICLE_TYPES` | trucks + heli | 337 | forced | All supply-capable types (buy-menu highlight); derived `TRUCK_TYPES + HELI_TYPES`. |

## Anti-stack (team balancing)

Auto-balance knobs plus a set of bare runtime accumulators (`TEAM_SKILL_TICKS_*`, `SUPPLY_COMPENSATION_AMOUNT_*`) that start at 0. Note the unprefixed names — these are not `WFBE_C_*`.

| Constant | Default | Line | Guard | Role |
|---|---|---|---|---|
| `WFBE_C_ANTISTACK_ENABLED` | `1` | 341 | isNil-default | Anti-stack auto-balance master switch. |
| `TEAM_SKILL_TICKS_WEST` | `0` | 342 | forced | WEST skill-tick accumulator (runtime state seed). |
| `TEAM_SKILL_TICKS_EAST` | `0` | 343 | forced | EAST skill-tick accumulator. |
| `TEAM_SKILL_TICKS_DIFF_THRESHOLD` | `30` | 344 | forced | Player-count diff at which skill compensation engages. |
| `TEAM_SKILL_TICKS_COMPENSATION_MULTIPLIER` | `0.045` | 345 | forced | Skill compensation per-tick multiplier. |
| `TEAM_SKILL_TICKS_END_THRESHOLD` | `10` | 346 | forced | Diff below which compensation ends. |
| `SUPPLY_COMPENSATION_AMOUNT_WEST` | `0` | 347 | forced | WEST supply-compensation accumulator. |
| `SUPPLY_COMPENSATION_AMOUNT_EAST` | `0` | 348 | forced | EAST supply-compensation accumulator. |
| `PLAYER_NUMBER_DIFFERENCE_MODIFIER` | `0.15` | 349 | forced | Per-player-difference compensation modifier. |
| `WFBE_SUPPLY_MISSION_SCORE_COEF` | `1.5` | 350 | forced | Supply-mission score coefficient. |
| `WFBE_UPGRADE_SCORE_COEF` | `0.5` | 351 | forced | Upgrade score coefficient. |

## Supply-income stagnation (no players)

Throttles supply income when a side has no players. All bare/forced.

| Constant | Default | Line | Guard | Role |
|---|---|---|---|---|
| `TEAM_WEST_TICKS_NO_PLAYERS` | `0` | 354 | forced | WEST no-players tick accumulator. |
| `TEAM_EAST_TICKS_NO_PLAYERS` | `0` | 355 | forced | EAST no-players tick accumulator. |
| `SUPPLY_INCOME_TICK_MODIFIER_MULTIPLIER` | `0.10` | 356 | forced | Per-tick supply-income decay multiplier while no players. |

## Marker flashing in combat + attack wave + unit-cost modifier

The combat-marker blink config, plus the bare attack-wave and unit-cost-modifier runtime seeds that live in the same region (under their own `// Attack wave.` / `// Unit cost modifier` comments).

| Constant | Default | Line | Guard | Role |
|---|---|---|---|---|
| `FIRING_UNIT_BLINK_TIME` | `15` | 359 | forced | Seconds a firing unit's marker blinks. |
| `WFBE_C_PLAYERS_MARKER_BLINKS` | `16` | 360 | forced | Blink count — must stay even, else the icon stays red. |
| `BLINKING_UNITS_WEST` / `_EAST` | `[]` | 361-362 | forced | Per-side blinking-unit registries (runtime state seed). |
| `BLINKING_VEHICLES_WEST` / `_EAST` | `[]` | 363-364 | forced | Per-side blinking-vehicle registries. |
| `ATTACK_WAVE_PRICE_MODIFIER` | `1` | 367 | forced | Attack-wave price modifier. |
| `ATTACK_WAVE_ACTIVE_WEST` / `_EAST` | `false` | 368-369 | forced | Per-side attack-wave active flags (runtime state seed). |
| `UNIT_COST_MODIFIER` | `1` | 373 | forced | Unit-cost modifier driven by the related upgrade. |

## Environment

| Constant | Default | Line | Guard | Role |
|---|---|---|---|---|
| `WFBE_C_ENVIRONMENT_MAX_VIEW` | `5000` | 376 | isNil-default | Max view distance (m). |
| `WFBE_C_ENVIRONMENT_MAX_CLUTTER` | `50` | 377 | isNil-default | Max terrain grid. |
| `WFBE_C_ENVIRONMENT_STARTING_HOUR` | `9` | 378 | isNil-default | Starting hour of the day. |
| `WFBE_C_ENVIRONMENT_STARTING_MONTH` | `6` | 379 | isNil-default | Starting month of the year. |
| `WFBE_C_ENVIRONMENT_WEATHER` | `0` | 380 | isNil-default | Weather type (0: Clear, 1: Cloudy, 2: Rainy). |
| `WFBE_C_ENVIRONMENT_WEATHER_VOLUMETRIC` | `0` | 382 | forced | Volumetric clouds disabled globally (overrides any stale param). |
| `WFBE_C_ENVIRONMENT_WEATHER_TRANSITION` | `600` | 383 | forced | Weather transition period (s). |

## Gameplay

Master gameplay switches (mostly param-overridable) plus the fast-travel pricing knobs (forced) and the debug-branched vote timer.

| Constant | Default | Line | Guard | Role |
|---|---|---|---|---|
| `WFBE_C_GAMEPLAY_AIR_AA_MISSILES` | `1` | 386 | isNil-default | Air-to-air missiles (0: Off, 1: With upgrade, 2: On). |
| `WFBE_C_GAMEPLAY_BOUNDARIES_ENABLED` | `1` | 387 | isNil-default | Enable map boundaries if defined. |
| `WFBE_C_GAMEPLAY_FAST_TRAVEL` | `1` | 388 | isNil-default | Fast travel (0: Off, 1: Free, 2: Fee). |
| `WFBE_C_GAMEPLAY_HANDLE_FRIENDLYFIRE` | `1` | 389 | isNil-default | Handle friendly fire. |
| `WFBE_C_GAMEPLAY_HANGARS_ENABLED` | `1` | 390 | isNil-default | Enable hangars. |
| `WFBE_C_GAMEPLAY_MISSILES_RANGE` | `0` | 391 | isNil-default | Incoming guided-missile range limit (0 = disabled). |
| `WFBE_C_GAMEPLAY_TEAMSWAP_DISABLE` | `1` | 392 | isNil-default | Disable teamswitch. |
| `WFBE_C_GAMEPLAY_THERMAL_IMAGING` | `3` | 393 | isNil-default | Thermal imaging (0: Off, 1: Weapons, 2: Vehicles, 3: All). |
| `WFBE_C_GAMEPLAY_UID_SHOW` | `1` | 394 | isNil-default | Display the user ID on teamswap/tk. |
| `WFBE_C_GAMEPLAY_UPGRADES_CLEARANCE` | `0` | 395 | isNil-default | Upgrade clearance on start (0: Off … 7: All). |
| `WFBE_C_GAMEPLAY_VICTORY_CONDITION` | `2` | 396 | isNil-default | Victory condition (0: Annihilation, 1: Assassination, 2: Supremacy, 3: Towns). |
| `WFBE_C_GAMEPLAY_FAST_TRAVEL_RANGE` | `175` | 397 | forced | Min fast-travel range (m). |
| `WFBE_C_GAMEPLAY_FAST_TRAVEL_RANGE_MAX` | `3500` | 398 | forced | Max fast-travel range (m). |
| `WFBE_C_GAMEPLAY_FAST_TRAVEL_PRICE_KM` | `215` | 399 | forced | Fast-travel price per km. |
| `WFBE_C_GAMEPLAY_FAST_TRAVEL_TIME_COEF` | `0.8` | 400 | forced | Fast-travel time coefficient. |
| `WFBE_C_GAMEPLAY_VOTE_TIME` | `40` (debug `3`) | 401 | forced, env (`WF_Debug`) | Vote duration (s). |

## Modules

Content/feature module gates plus two ICBM/radiation timing knobs.

| Constant | Default | Line | Guard | Role |
|---|---|---|---|---|
| `WFBE_C_MODULE_BIS_PMC` | `1` | 404 | isNil-default | Enable PMC content. |
| `WFBE_C_MODULE_WFBE_EASA` | `1` | 405 | isNil-default | Enable the Exchangeable Armament System for Aircraft. |
| `WFBE_C_MODULE_WFBE_FLARES` | `1` | 406 | isNil-default | Countermeasure system (0: Off, 1: With upgrade, 2: On). |
| `WFBE_C_MODULE_WFBE_ICBM` | `1` | 407 | isNil-default | Enable the commander ICBM call. |
| `WFBE_C_MODULE_WFBE_IRSMOKE` | `1` | 408 | isNil-default | Enable IR smoke. |
| `WFBE_ICBM_TIME_TO_IMPACT` | `1` | 409 | isNil-default | ICBM time-to-impact. |
| `WFBE_RADZONE_TIME` | `1` | 410 | isNil-default | Radiation-effect duration. |

## Players (scoring, bounty, squad, UAV, HALO)

The player-facing tuning surface: kill/capture scoring weights, bounties, squad limits, gear, HALO height, and UAV spotting. Only `WFBE_C_PLAYERS_AI_MAX` is param-overridable; every score/bounty weight is forced.

| Constant | Default | Line | Guard | Role |
|---|---|---|---|---|
| `WFBE_C_PLAYERS_AI_MAX` | `16` | 413 | isNil-default | Max AI allowed in each player group. |
| `WFBE_C_PLAYERS_BOUNTY_CAPTURE` | `2000` | 414 | forced | Bounty for capturing a town. |
| `WFBE_C_PLAYERS_BOUNTY_CAPTURE_ASSIST` | `2000` | 415 | forced | Bounty for assisting a town capture. |
| `WFBE_C_PLAYERS_BOUNTY_CAPTURE_MISSION` | `2000` | 416 | forced | Bounty for a capture mission. |
| `WFBE_C_PLAYERS_BOUNTY_CAPTURE_MISSION_ASSIST` | `2000` | 417 | forced | Bounty for assisting a capture mission. |
| `WFBE_C_PLAYERS_COMMANDER_BOUNTY_CAPTURE_COEF` | `60` | 418 | forced | Commander capture-bounty coefficient. |
| `WFBE_C_PLAYERS_COMMANDER_SCORE_BUILD_COEF` | `1` | 419 | forced | Commander build-score coefficient. |
| `WFBE_C_PLAYERS_COMMANDER_SCORE_CAPTURE` | `5` | 420 | forced | Commander score per capture. |
| `WFBE_C_PLAYERS_COMMANDER_SCORE_UPGRADE` | `2` | 421 | forced | Commander score per upgrade. |
| `WFBE_C_PLAYERS_GEAR_SELL_COEF` | `0.6` | 422 | forced | Gear resale price = item price × x. |
| `WFBE_C_PLAYERS_GEAR_VEHICLE_RANGE` | `50` | 423 | forced | Range (m) to buy gear from a vehicle. |
| `WFBE_C_PLAYERS_HALO_HEIGHT` | `200` | 424 | forced | Altitude (m) above which a HALO jump is allowed. |
| `WFBE_C_PLAYERS_MARKER_DEAD_DELAY` | `60` | 425 | forced | Seconds a marker remains on a dead unit. |
| `WFBE_C_PLAYERS_MARKER_TOWN_RANGE` | `0.05` | 426 | forced | Town-marker update range (town range × coef). |
| `WFBE_C_PLAYERS_OFFMAP_TIMEOUT` | `50` | 427 | forced | Seconds a player may stay off-map before being killed. |
| `WFBE_C_PLAYERS_PENALTY_TEAMKILL` | `1000` | 428 | forced | Teamkill penalty. |
| `WFBE_C_PLAYERS_SCORE_CAPTURE` | `23` | 429 | forced | Player score per town capture. |
| `WFBE_C_PLAYERS_SCORE_CAPTURE_ASSIST` | `17` | 430 | forced | Player score per capture assist. |
| `WFBE_C_PLAYERS_SCORE_CAPTURE_CAMP` | `5` | 431 | forced | Player score per camp capture. |
| `WFBE_C_PLAYERS_SCORE_DELIVERY` | `3` | 432 | forced | Player score per supply delivery. |
| `WFBE_C_PLAYERS_SKILL_SOLDIER_UNITS_MAX` | `6` | 433 | forced | Soldier-skill bonus unit count. |
| `WFBE_C_PLAYERS_SQUADS_MAX_PLAYERS` | `4` | 434 | forced | Max players per player squad. |
| `WFBE_C_PLAYERS_SQUADS_REQUEST_TIMEOUT` | `100` | 435 | forced | Seconds before an unanswered squad request fades. |
| `WFBE_C_PLAYERS_SQUADS_REQUEST_DELAY` | `120` | 436 | forced | Delay (s) between squad hops. |
| `WFBE_C_PLAYERS_SUPPLY_TRUCKS_DELIVERY_RANGE` | `30` | 437 | forced | Client supply-truck delivery range (m). |
| `WFBE_C_PLAYERS_SUPPLY_TRUCKS_DELIVERY_FUNDS_COEF` | `4` | 438 | forced | Client delivery funds (SV × coef). |
| `WFBE_C_PLAYERS_SUPPORT_PARATROOPERS_DELAY` | `1200` | 439 | forced | Paratrooper-call interval (s). |
| `WFBE_C_PLAYERS_UAV_SPOTTING_DELAY` | `20` | 440 | forced | Interval (s) between UAV spotting routines. |
| `WFBE_C_PLAYERS_UAV_SPOTTING_DETECTION` | `0.21` | 441 | forced | UAV reveal value per target (0-4). |
| `WFBE_C_PLAYERS_UAV_SPOTTING_RANGE` | `1100` | 442 | forced | Max UAV spotting range (m). |

## Respawn

| Constant | Default | Line | Guard | Role |
|---|---|---|---|---|
| `WFBE_C_RESPAWN_CAMPS_MODE` | `2` | 445 | isNil-default | Respawn camps (0: Off, 1: Classic [town center], 2: Enhanced [nearby camps]). |
| `WFBE_C_RESPAWN_CAMPS_RANGE` | `550` | 446 | isNil-default | Distance (m) from a town required to spawn at camps. |
| `WFBE_C_RESPAWN_CAMPS_RULE_MODE` | `2` | 447 | isNil-default | Respawn-camps rule (0: Off, 1: W|E, 2: W|E|Res). |
| `WFBE_C_RESPAWN_DELAY` | `10` | 448 | isNil-default | Respawn delay (players/AI), seconds. |
| `WFBE_C_RESPAWN_LEADER` | `2` | 449 | isNil-default | Leader respawn (0: Off, 1: On, 2: On but default gear). |
| `WFBE_C_RESPAWN_MOBILE` | `2` | 450 | isNil-default | Mobile respawn (0: Off, 1: On, 2: On but default gear). |
| `WFBE_C_RESPAWN_PENALTY` | `4` | 451 | isNil-default | Respawn penalty (0: None … 4: pay 1/4 gear price, 5: Charge on mobile). |
| `WFBE_C_RESPAWN_CAMPS_SAFE_RADIUS` | `50` | 452 | forced | Respawn-camp safe radius (m). |
| `WFBE_C_RESPAWN_RANGE_LEADER` | `50` | 453 | forced | Leader respawn range (m). |
| `WFBE_C_RESPAWN_RANGES` | `[250, 350, 500]` | 454 | forced | Respawn-range tiers (m). |

## Structures

Base-structure switches, costs, ranges, and the vanilla-vs-OA-branched ruins model and base-coin geometry.

| Constant | Default | Line | Guard | Role |
|---|---|---|---|---|
| `WFBE_C_STRUCTURES_ANTIAIRRADAR` | `1` | 457 | isNil-default | Enable anti-air radar structure. |
| `WFBE_C_STRUCTURES_COLLIDING` | `1` | 458 | isNil-default | Enable structure collision checks on placement. |
| `WFBE_C_STRUCTURES_CONSTRUCTION_MODE` | `0` | 459 | isNil-default | Construction mode (0: Time). |
| `WFBE_C_STRUCTURES_HQ_COST_DEPLOY` | `100` | 460 | isNil-default | HQ deploy/mobilize price. |
| `WFBE_C_STRUCTURES_HQ_RANGE_DEPLOYED` | `200` | 461 | isNil-default | HQ deployed build radius (m). |
| `WFBE_C_STRUCTURES_MAX` | `3` | 462 | isNil-default | Default per-type structure cap (base for the Max-structures block below). |
| `WFBE_C_STRUCTURES_ANTIAIRRADAR_DETECTION` | `100` | 463 | forced | AA-radar detection range. |
| `WFBE_C_STRUCTURES_BUILDING_DEGRADATION` | `1` | 464 | forced | Building degradation per repair phase (over 100). |
| `WFBE_C_STRUCTURES_COMMANDCENTER_RANGE` | `5500` | 465 | forced | Command Center range (m). |
| `WFBE_C_STRUCTURES_DAMAGES_REDUCTION` | `6` | 466 | forced | Building damage reduction divisor (1 = normal). |
| `WFBE_C_STRUCTURES_RUINS` | `"Land_budova4_ruins"` (vanilla) | 467 | forced, env (`WF_A2_Vanilla`) | Ruins model; OA branch `"Land_Mil_Barracks_i_ruins_EP1"`. |
| `WFBE_C_STRUCTURES_SALE_DELAY` | `50` | 468 | forced | Seconds before a building is sold. |
| `WFBE_C_STRUCTURES_SALE_PERCENT` | `50` | 469 | forced | % of supply refunded on sale. |
| `WFBE_C_STRUCTURES_SERVICE_POINT_RANGE` | `50` | 470 | forced | Service-point range (m). |
| `WFBE_C_BASE_COIN_DISTANCE_MIN` | `8` (vanilla) / `100` (OA) | 472/475 | forced, env (`WF_A2_Vanilla`) | Min base-coin spacing distance. |
| `WFBE_C_BASE_COIN_GRADIENT_MAX` | `4` | 473/476 | forced, env (`WF_A2_Vanilla`) | Max base-coin placement gradient (both branches = 4). |

## Towns (capture, mortar, patrol, detection)

The largest single section. Town count/difficulty/capture-mode switches are param-overridable; the capture/mortar/patrol/detection knobs are forced. The `WFBE_C_TOWNS_*` runtime/combat knobs below are documented in depth — with the FSM/function that reads each one — in [Town Runtime Tuning Constants](Town-Runtime-Tuning-Constants); this catalog lists them for completeness as the master index, and additionally covers the setup knobs `WFBE_C_TOWNS_AMOUNT` / `_GEAR` / `_STARTING_MODE` that the runtime page omits. **The capture-mode note is load-bearing:** mode 0 (Classic) was set from 2 (claude-gaming 2026-06-14) because mode 2 (All Camps) effectively only let GUER flip towns.

| Constant | Default | Line | Guard | Role |
|---|---|---|---|---|
| `WFBE_C_TOWNS_AMOUNT` | `7` | 480 | isNil-default | Amount of towns (0: Very small … 4: Full). |
| `WFBE_C_TOWNS_BUILD_PROTECTION_RANGE` | `450` | 481 | isNil-default | Prevent construction within this radius of a town. |
| `WFBE_C_TOWNS_CAPTURE_MODE` | `0` | 482 | isNil-default | Capture mode (0: Classic, 1: Threshold, 2: All Camps). A/B: 2→0 Classic. |
| `WFBE_C_TOWNS_DEFENDER` | `2` | 483 | isNil-default | Defender difficulty (0: Off … 4: Insane). |
| `WFBE_C_TOWNS_OCCUPATION` | `2` | 484 | isNil-default | Occupation difficulty (0: Off … 4: Insane). |
| `WFBE_C_TOWNS_GEAR` | `1` | 485 | isNil-default | Buy gear from (0: None, 1: Camps, 2: Depot, 3: Both). |
| `WFBE_C_TOWNS_PATROLS` | `6` | 486 | isNil-default | Town-to-town patrols (up to 6 towns; 0 disables). |
| `WFBE_C_TOWNS_REINFORCEMENT_DEFENDER` | `0` | 487 | isNil-default | Enable town-defender reinforcement. |
| `WFBE_C_TOWNS_REINFORCEMENT_OCCUPATION` | `0` | 488 | isNil-default | Enable town-occupation reinforcement. |
| `WFBE_C_TOWNS_STARTING_MODE` | `0` | 489 | isNil-default | Town starting mode (0: Resistance, 1: 50/50, 2: Nearby, 3: Random). |
| `WFBE_C_TOWNS_VEHICLES_LOCK_DEFENDER` | `1` | 490 | isNil-default | Lock the defender side's vehicles. |
| `WFBE_C_JET_AA_SURVIVE` | `1` | 493 | isNil-default | Jets survive the 1st SPAAG hit (fuel drained + light damage); a 2nd explodes. 0 disables. |
| `WFBE_C_TOWNS_CAPTURE_ASSIST` | `400` | 494 | forced | Town capture-assist reward. |
| `WFBE_C_TOWNS_CAPTURE_RANGE` | `40` | 495 | forced | Capture presence range (m). |
| `WFBE_C_TOWNS_CAPTURE_RATE` | `0.4` | 496 | forced | Capture rate. |
| `WFBE_C_TOWNS_CAPTURE_THRESHOLD_RANGE` | `140` | 497 | forced | Threshold-mode majority range (m). |
| `WFBE_C_TOWNS_DEFENSE_RANGE` | `30` | 498 | forced | Town-defense range (m). |
| `WFBE_C_TOWNS_DETECTION_RANGE_ACTIVE_COEF` | `1` | 499 | forced | Activation range once active (town range × coef). |
| `WFBE_C_TOWNS_DETECTION_RANGE_COEF` | `1` | 500 | forced | Activation range while idling (town range × coef). |
| `WFBE_C_TOWNS_DETECTION_RANGE_AIR` | `50` | 501 | forced | Detect air above this range. |
| `WFBE_C_TOWNS_MORTARS_SCAN` | `60` | 502 | forced | Scan radius for friends/enemies around a mortar target. |
| `WFBE_C_TOWNS_MORTARS_INTERVAL` | `200` | 503 | forced | AI mortars may fire every x seconds. |
| `WFBE_C_TOWNS_MORTARS_PRECOGNITION` | `25` | 504 | forced | % chance AI mortars fire by precognition. |
| `WFBE_C_TOWNS_MORTARS_RANGE_MAX` | `750` | 505 | forced | Max mortar fire range (m; ≤ artillery core max). |
| `WFBE_C_TOWNS_MORTARS_RANGE_MIN` | `125` | 506 | forced | Min mortar fire range (m; ≥ artillery core min). |
| `WFBE_C_TOWNS_MORTARS_SPLASH_RANGE` | `60` | 507 | forced | Mortar AoE (m). |
| `WFBE_C_TOWNS_PATROL_HOPS` | `5` | 508 | forced | Waypoints per town AI patrol (higher = wider). |
| `WFBE_C_TOWNS_PATROL_RANGE` | `500` | 509 | forced | Town patrol range (m). |
| `WFBE_C_TOWNS_PURCHASE_RANGE` | `60` | 510 | forced | Town purchase range (m). |
| `WFBE_C_TOWNS_SUPPLY_LEVELS_TIME` | `[1, 2, 3, 4, 5]` | 511 | forced | Per-level time supply tiers. |
| `WFBE_C_TOWNS_SUPPLY_LEVELS_TRUCK` | `[5, 6, 7, 8, 10]` | 512 | forced | Per-level truck supply tiers. |
| `WFBE_C_TOWNS_UNITS_INACTIVE` | `90` | 513 | forced | Remove town units if no enemy within this time (s). |
| `WFBE_C_TOWNS_UNITS_SPAWN_CAPTURE_DELAY` | `1200` | 514 | forced | Seconds since last capture before units may respawn during a capture. |
| `WFBE_C_TOWNS_UNITS_WAYPOINTS` | `9` | 515 | forced | Waypoints assigned to town units. |

## Units

Unit bounty/balancing switches, body/vehicle cleanup timeouts, pricing/tracking, and the full repair/rearm/refuel/heal service price+time table.

| Constant | Default | Line | Guard | Role |
|---|---|---|---|---|
| `WFBE_C_UNITS_BALANCING` | `1` | 518 | isNil-default | Enable unit-weaponry balancing. |
| `WFBE_C_UNITS_BOUNTY` | `1` | 519 | isNil-default | Enable unit kill bounty. |
| `WFBE_C_UNITS_LAST_HIT_REWARD_WINDOW` | `60` | 520 | isNil-default | Seconds a damaged vehicle still awards its last hitter. |
| `WFBE_C_UNITS_CLEAN_TIMEOUT` | `60` | 521 | isNil-default | Dead-body lifespan (s). |
| `WFBE_C_UNITS_EMPTY_TIMEOUT` | `1800` | 522 | isNil-default | Empty-vehicle lifespan (s, 30 min). |
| `WFBE_C_UNITS_BODIES_TIMEOUT` | `60` | 523 | forced | Body-cleanup timeout (s). |
| `WFBE_C_UNITS_PRICING` | `0` | 524 | isNil-default | Price focus (0: Default, 1: Infantry, 2: Tanks, 3: Air). |
| `WFBE_C_UNITS_TOWN_PURCHASE` | `1` | 525 | isNil-default | Allow AI to be bought from depots. |
| `WFBE_C_UNITS_TRACK_INFANTRY` | `1` | 526 | isNil-default | Track infantry on the map. |
| `WFBE_C_UNITS_TRACK_LEADERS` | `1` | 527 | isNil-default | Track playable team leaders on the map. |
| `WFBE_C_UNITS_BOUNTY_COEF` | `1` | 528 | forced | Bounty = unit price × coef. |
| `WFBE_C_BUILDINGS_SCORE_COEF` | `3` | 529 | forced | Score for killing base structures/HQ = building bounty × coef. |
| `WFBE_C_UNITS_BOUNTY_ASSISTANCE_COEF` | `0.5` | 530 | forced | Bounty assist = unit price × coef × assist coef. |
| `WFBE_C_UNITS_COUNTERMEASURE_PLANES` | `64` | 531 | forced | Plane countermeasure count. |
| `WFBE_C_UNITS_COUNTERMEASURE_CHOPPERS` | `32` | 532 | forced | Helicopter countermeasure count. |
| `WFBE_C_UNITS_CREW_COST` | `120` | 533 | forced | Vehicle-crew cost. |
| `WFBE_C_UNITS_PURCHASE_RANGE` | `150` | 534 | forced | Unit purchase range (m). |
| `WFBE_C_UNITS_PURCHASE_GEAR_RANGE` | `150` | 535 | forced | Gear purchase range (m). |
| `WFBE_C_UNITS_PURCHASE_GEAR_MOBILE_RANGE` | `5` | 536 | forced | Mobile gear purchase range (m). |
| `WFBE_C_UNITS_PURCHASE_GEAR_MOBILE_AI_RANGE` | `45` | 537 | forced | Mobile AI gear purchase range (m). |
| `WFBE_C_UNITS_PURCHASE_HANGAR_RANGE` | `50` | 538 | forced | Hangar purchase range (m). |
| `WFBE_C_UNITS_REPAIR_TRUCK_RANGE` | `40` | 539 | forced | Repair-truck range (m). |
| `WFBE_C_UNITS_SALVAGER_SCAVENGE_RANGE` | `60` | 540 | forced | Salvager scavenge range (m). |
| `WFBE_C_UNITS_SALVAGER_SCAVENGE_RATIO` | `60` | 541 | forced | Salvager sell %. |
| `WFBE_C_UNITS_SKILL_DEFAULT` | `1` | 542 | forced | Default unit skill. |
| `WFBE_C_UNITS_SUPPORT_RANGE` | `70` | 543 | forced | Action range for repair/rearm/refuel (m). |
| `WFBE_C_UNITS_SUPPORT_HEAL_PRICE` | `125` | 544 | forced | Heal price. |
| `WFBE_C_UNITS_SUPPORT_HEAL_TIME` | `10` | 545 | forced | Heal time (s). |
| `WFBE_C_UNITS_SUPPORT_REARM_PRICE` | `14` | 546 | forced | Rearm price. |
| `WFBE_C_UNITS_SUPPORT_REARM_TIME` | `20` | 547 | forced | Rearm time (s). |
| `WFBE_C_UNITS_SUPPORT_REFUEL_PRICE` | `16` | 548 | forced | Refuel price. |
| `WFBE_C_UNITS_SUPPORT_REFUEL_TIME` | `10` | 549 | forced | Refuel time (s). |
| `WFBE_C_UNITS_SUPPORT_REPAIR_PRICE` | `2` | 550 | forced | Repair price. |
| `WFBE_C_UNITS_SUPPORT_REPAIR_TIME` | `20` | 551 | forced | Repair time (s). |

The QoL-trio and restart-announcer constants (`Init_CommonConstants.sqf:553-561`) sit inside the Units section but belong to the QoL/announcer features — see [Experimental Feature-Flag Constants Reference](Experimental-Feature-Flag-Constants-Reference).

## Victory

| Constant | Default | Line | Guard | Role |
|---|---|---|---|---|
| `WFBE_C_VICTORY_THREEWAY` | `0` | 631 | forced | Victory condition (0: side a vs side b [supremacy] minus defender). |
| `WFBE_C_VICTORY_THREEWAY_LOCATION_SWAP` | `300` | 632 | forced | Startup locations re-open for respawn (rotated) when a defender loses, to prevent spawn camping. |

## Overall mission coloration

Side marker colours are set with `setVariable` (not bare assignment) and branch on the viewing player's side — WEST view, GUER-insurgent view, and the EAST/default view each set five colours (`Init_CommonConstants.sqf:635-656`). Forced (no params).

| Constant (variable) | WEST view | GUER-insurgent view | EAST/default view | Lines |
|---|---|---|---|---|
| `WFBE_C_WEST_COLOR` | `"ColorGreen"` | `"ColorRed"` | `"ColorRed"` | 636 / 644 / 650 |
| `WFBE_C_EAST_COLOR` | `"ColorRed"` | `"ColorRed"` | `"ColorGreen"` | 637 / 645 / 651 |
| `WFBE_C_GUER_COLOR` | `"ColorBlue"` | `"ColorGreen"` | `"ColorBlue"` | 638 / 646 / 652 |
| `WFBE_C_CIV_COLOR` | `"ColorYellow"` | `"ColorYellow"` | `"ColorYellow"` | 639 / 647 / 653 |
| `WFBE_C_UNKNOWN_COLOR` | `"ColorBlue"` | `"ColorBlue"` | `"ColorBlue"` | 640 / 648 / 654 |

## Build area (radius/height)

Derived `[radius, height]` build-area boxes. Forced; the two HQ boxes are computed from `WFBE_C_STRUCTURES_HQ_RANGE_DEPLOYED` (line 461).

| Constant | Default | Line | Guard | Role |
|---|---|---|---|---|
| `WFBE_C_BASE_COIN_AREA_HQ_DEPLOYED` | `[HQ_RANGE_DEPLOYED, 25]` (= `[200, 25]`) | 661 | forced (derived) | Deployed-HQ build box. |
| `WFBE_C_BASE_COIN_AREA_HQ_UNDEPLOYED` | `[HQ_RANGE_DEPLOYED/2, 25]` (= `[100, 25]`) | 662 | forced (derived) | Undeployed-HQ build box. |
| `WFBE_C_BASE_COIN_AREA_REPAIR` | `[45, 10]` | 663 | forced | Repair build box. |

## Max structures (per-type caps)

Per-type caps, most defaulting to `WFBE_C_STRUCTURES_MAX` (3, line 462). All isNil-default (param-overridable).

| Constant | Default | Line | Guard | Role |
|---|---|---|---|---|
| `WFBE_C_STRUCTURES_MAX_BARRACKS` | `WFBE_C_STRUCTURES_MAX` (3) | 666 | isNil-default | Max barracks. |
| `WFBE_C_STRUCTURES_MAX_LIGHT` | `WFBE_C_STRUCTURES_MAX` (3) | 667 | isNil-default | Max light factories. |
| `WFBE_C_STRUCTURES_MAX_COMMANDCENTER` | `WFBE_C_STRUCTURES_MAX` (3) | 668 | isNil-default | Max command centers. |
| `WFBE_C_STRUCTURES_MAX_HEAVY` | `WFBE_C_STRUCTURES_MAX` (3) | 669 | isNil-default | Max heavy factories. |
| `WFBE_C_STRUCTURES_MAX_AIRCRAFT` | `WFBE_C_STRUCTURES_MAX` (3) | 670 | isNil-default | Max aircraft factories. |
| `WFBE_C_STRUCTURES_MAX_SERVICEPOINT` | `WFBE_C_STRUCTURES_MAX * 2` (6) | 671 | isNil-default | Max service points. |
| `WFBE_C_STRUCTURES_MAX_TENTS` | `3` | 672 | isNil-default | Max tents. |
| `WFBE_C_STRUCTURES_MAX_Bank` | `1` | 673 | isNil-default | Max banks. |
| `WFBE_C_STRUCTURES_MAX_CBRadar` | `1` | 674 | isNil-default | Max counter-battery radars. |
| `WFBE_C_STRUCTURES_MAX_AARadar` | `1` | 675 | isNil-default | Max anti-air radars. |

## Town unit coefficient and group-merge tuning

The closing block (`Init_CommonConstants.sqf:677-685`) derives the town-unit difficulty coefficients via `switch` on the occupation/defender difficulty, then sets the server-FPS group-merge knobs.

| Constant | Default | Line | Guard | Role |
|---|---|---|---|---|
| `WFBE_C_TOWNS_UNITS_COEF` | `switch(OCCUPATION)` → `1.5` at default occ 2 | 678 | forced (derived) | Occupation unit-count coefficient (case 1:1, 2:1.5, 3:2, 4:2.5). |
| `WFBE_C_TOWNS_UNITS_DEFENDER_COEF` | `switch(DEFENDER)` → `1.5` at default def 2 | 679 | forced (derived) | Defender unit-count coefficient (case 1:1, 2:1.5, 3:2, 4:2.5). |
| `WFBE_C_TOWNS_MERGE_TARGET` | `5` | 680 | forced | Target units per consolidated WEST/EAST town-garrison infantry group (hard cap 10). 0 disables. |
| `WFBE_C_TOWNS_MERGE_TARGET_DEFENDER` | `11` | 681 | isNil-default | GUER condense: units/group for defender garrisons (9→11). |
| `WFBE_C_TOWNS_MERGE_CAP_DEFENDER` | `12` | 682 | isNil-default | Defender merged-group size cap (raised from global 10). |
| `WFBE_C_SIDE_PATROLS_MAX_DEFENDER` | `1` | 683 | isNil-default | B36: GUER (defender) side-patrol cap (2→1). |
| `WFBE_C_GROUP_BUDGET_WARN` | `120` | 684 | forced | Per-side group-count WARN threshold (GRPBUDGET line; A2 OA hard cap is 144/side). |
| `WFBE_C_GROUPAUDIT_EVERY` | `5` | 685 | isNil-default | D2: run the expensive group-classification audit dump every Nth 5-min window (pure diagnostic throttle). |

The player-stats enum block (`Init_CommonConstants.sqf:688-707`) — `WFBE_C_STATS_ENABLED` (forced `false`), `WFBE_C_STATS_FLUSH_INTERVAL`, and the `WFBE_STAT_*` field-index constants — is feature-flagged OFF by default and is documented with the rest of the stats surface in [Experimental Feature-Flag Constants Reference](Experimental-Feature-Flag-Constants-Reference).

## Continue Reading

- [AI Commander Tunable Constants Reference](AI-Commander-Tunable-Constants-Reference) — the excluded `//--- AI.` block (commander cadences, team-scaling curve, spearhead scorer).
- [Experimental Feature-Flag Constants Reference](Experimental-Feature-Flag-Constants-Reference) — the excluded EXPERITAL block, QoL trio, restart announcer, dashboard/leaderboard, and player-stats flags.
- [Mission Start Parameters Index](Mission-Start-Parameters-Index) — the lobby/mission params that override every isNil-default constant above.
- [Variable And Naming Conventions](Variable-And-Naming-Conventions) — the `WFBE_C_*` constant / `WFBE_*` / bare-name conventions used throughout this file.
- [Town Runtime Tuning Constants](Town-Runtime-Tuning-Constants) — the in-depth `WFBE_C_TOWNS_*` runtime/combat dive, with the consumer FSM/function for each knob.
- [Gameplay Systems Atlas](Gameplay-Systems-Atlas) — the subsystems these constants tune, end to end.
