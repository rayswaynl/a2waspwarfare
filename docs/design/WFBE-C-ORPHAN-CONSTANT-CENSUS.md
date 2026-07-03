# WFBE_C Orphan Constant Census

Lane 302 report generated from the current Build84 target (`claude/build84-cmdcon36`) using the canonical Chernarus source root only. Vanilla Takistan and Zargabad mirrors are generated from this source and were not counted again.

## Method

- Definition set: unique `WFBE_C_*` names with an assignment token in `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf`.
- Lobby-exposed set: `WFBE_C_*` class names referenced in `Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Parameters.hpp`.
- Runtime reference set: exact raw `WFBE_C_*` text hits in `.sqf` and `.fsm` files under the same Chernarus mission root, excluding `Init_CommonConstants.sqf`; comments are included, so this is an upper bound on real reads.
- This is intentionally grep-driven. Exact-token misses can happen where code builds variable names dynamically with `Format`; those rows are flagged as manual-review families, not deletion approvals.

## Summary

| Bucket | Count |
| --- | ---: |
| Unique `WFBE_C_*` assignments in `Init_CommonConstants.sqf` | 965 |
| Lobby-exposed in `Parameters.hpp` | 85 |
| Runtime-referenced outside init | 910 |
| Both lobby-exposed and runtime-referenced | 81 |
| Lobby-only exact-token rows | 4 |
| No lobby row and no exact runtime token | 51 |

The prompt snapshot expected 903 unique constants; this live Build84 scan finds 965 assignment-defined names. Treat the delta as evidence that the constant surface has grown since that snapshot, not as a failure of the lane.

## Lobby-only exact-token rows

| Constant | Init line | Note |
| --- | ---: | --- |
| `WFBE_C_AI_COMMANDER_LEVEL` | 513 | Lobby parameter exists, but no exact SQF/FSM token outside init was found by this scan. |
| `WFBE_C_STRUCTURES_HQ_RANGE_DEPLOYED` | 1458 | Lobby parameter exists, but no exact SQF/FSM token outside init was found by this scan. |
| `WFBE_C_STRUCTURES_MAX` | 1459 | Lobby parameter exists, but no exact SQF/FSM token outside init was found by this scan. |
| `WFBE_C_SUPPLY_HELI_ENABLED` | 1291 | Lobby parameter exists, but no exact SQF/FSM token outside init was found by this scan. |

## No exact runtime token candidates

These are the cleanup candidates surfaced by the exact-token pass. Review dynamic families and intended future toggles before deleting anything.

| Constant | Init line | Review note |
| --- | ---: | --- |
| `WFBE_C_AI_COMMANDER_FUNDS_MULT` | 515 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_AI_COMMANDER_MOVE_INTERVALS` | 265 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_AICOM_ATTACKHELI_MAX_TIME_BONUS` | 481 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_AICOM_DONATE_AMOUNT` | 705 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_AICOM_FEINT_COOLDOWN` | 671 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_AICOM_HC_TOPUP_MAX` | 1122 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_AICOM_LADDER_DECAY` | 879 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_AICOM_TEAMS_LOWPOP_EXTRA` | 305 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_BASE_COIN_DISTANCE_MIN` | 1473 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_BASE_COIN_GRADIENT_MAX` | 1474 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_BASE_HQ_REPAIR_COUNT_EAST` | 1175 | Dynamic family: `WFBE_C_BASE_HQ_REPAIR_COUNT_%1` is read/written via `Format` in MHQ repair flows. |
| `WFBE_C_BASE_HQ_REPAIR_COUNT_GUER` | 1176 | Dynamic family: `WFBE_C_BASE_HQ_REPAIR_COUNT_%1` is read/written via `Format` in MHQ repair flows. |
| `WFBE_C_BASE_HQ_REPAIR_COUNT_WEST` | 1174 | Dynamic family: `WFBE_C_BASE_HQ_REPAIR_COUNT_%1` is read/written via `Format` in MHQ repair flows. |
| `WFBE_C_BASE_HQ_REPAIR_PRICE_EAST` | 1172 | Dynamic family: `WFBE_C_BASE_HQ_REPAIR_PRICE_%1` is read/written via `Format` in MHQ repair flows. |
| `WFBE_C_BASE_HQ_REPAIR_PRICE_GUER` | 1173 | Dynamic family: `WFBE_C_BASE_HQ_REPAIR_PRICE_%1` is read/written via `Format` in MHQ repair flows. |
| `WFBE_C_BASE_HQ_REPAIR_PRICE_WEST` | 1171 | Dynamic family: `WFBE_C_BASE_HQ_REPAIR_PRICE_%1` is read/written via `Format` in MHQ repair flows. |
| `WFBE_C_BASE_RES` | 1151 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_ECONOMY_FUNDS_START_GUER` | 1251 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_ECONOMY_SUPPLY_START_GUER` | 1258 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_ENVIRONMENT_WEATHER_TRANSITION` | 1360 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_FIX_IRSMOKE_PARAM_ALIAS` | 1405 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_GUER_FOB_TOWN_BLOCK` | 148 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_GUER_VBIED_ARM_DELAY` | 77 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_PLAYERS_COMMANDER_SCORE_UPGRADE` | 1418 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_PLAYERS_SCORE_DELIVERY` | 1429 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_PLAYERS_SKILL_SOLDIER_UNITS_MAX` | 1430 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_PLAYERS_SQUADS_MAX_PLAYERS` | 1431 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_PLAYERS_SQUADS_REQUEST_DELAY` | 1433 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_PLAYERS_SUPPLY_TRUCKS_DELIVERY_FUNDS_COEF` | 1435 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_PLAYERS_SUPPLY_TRUCKS_DELIVERY_RANGE` | 1434 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_STRUCTURES_BUILDING_DEGRADATION` | 1465 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_STRUCTURES_MAX_AIRCRAFT` | 1713 | Dynamic family: `WFBE_C_STRUCTURES_MAX_%1` is read via `Format` in CoIn and AI commander base builders. |
| `WFBE_C_STRUCTURES_MAX_BARRACKS` | 1709 | Dynamic family: `WFBE_C_STRUCTURES_MAX_%1` is read via `Format` in CoIn and AI commander base builders. |
| `WFBE_C_STRUCTURES_MAX_COMMANDCENTER` | 1711 | Dynamic family: `WFBE_C_STRUCTURES_MAX_%1` is read via `Format` in CoIn and AI commander base builders. |
| `WFBE_C_STRUCTURES_MAX_HEAVY` | 1712 | Dynamic family: `WFBE_C_STRUCTURES_MAX_%1` is read via `Format` in CoIn and AI commander base builders. |
| `WFBE_C_STRUCTURES_MAX_LIGHT` | 1710 | Dynamic family: `WFBE_C_STRUCTURES_MAX_%1` is read via `Format` in CoIn and AI commander base builders. |
| `WFBE_C_STRUCTURES_MAX_SERVICEPOINT` | 1714 | Dynamic family: `WFBE_C_STRUCTURES_MAX_%1` is read via `Format` in CoIn and AI commander base builders. |
| `WFBE_C_STRUCTURES_MAX_TENTS` | 1715 | Dynamic family: `WFBE_C_STRUCTURES_MAX_%1` is read via `Format` in CoIn and AI commander base builders. |
| `WFBE_C_STRUCTURES_RUINS` | 1468 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_SUPPLY_VEHICLE_TYPES` | 1293 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_TOWNS_MORTARS_INTERVAL` | 1508 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_TOWNS_MORTARS_PRECOGNITION` | 1509 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_TOWNS_MORTARS_RANGE_MAX` | 1510 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_TOWNS_MORTARS_RANGE_MIN` | 1511 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_TOWNS_MORTARS_SCAN` | 1507 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_TOWNS_MORTARS_SPLASH_RANGE` | 1512 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_TOWNS_PATROL_HOPS` | 1513 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_TOWNS_REINFORCEMENT_DEFENDER` | 1490 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_TOWNS_REINFORCEMENT_OCCUPATION` | 1491 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_TOWNS_UNITS_SPAWN_CAPTURE_DELAY` | 1519 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |
| `WFBE_C_VICTORY_THREEWAY_LOCATION_SWAP` | 1675 | No exact SQF/FSM token outside `Init_CommonConstants.sqf` in this scan. |

## Follow-up recommendations

- Start manual review with the non-dynamic candidates that are neither lobby-exposed nor referenced by exact token.
- Keep dynamic families out of deletion PRs until their `Format` readers are mapped to the generated variable names.
- If a cleanup PR removes constants, keep it small by subsystem and include one grep proof per removed name.
- Consider a future lint helper that distinguishes exact-token reads from dynamic `missionNamespace getVariable Format [...]` families, because this report intentionally stops at grep evidence.
