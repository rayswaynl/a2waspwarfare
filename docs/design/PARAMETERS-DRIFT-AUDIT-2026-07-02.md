# Parameters Drift Audit - 2026-07-02

Original base checked: `origin/claude/build84-cmdcon36@eb0f8275a`.
Lane 210 delta checked: `origin/claude/build84-cmdcon36@c76f3e0062d6a6f968a12908994bf8d9c12a1243`.

The original pass kept gameplay defaults unchanged. Its only source change was a default-off compatibility alias so a future soak could opt into honoring the existing IR smoke lobby parameter name without changing flag-0 behavior.

| Surface | Lobby/config evidence | Runtime evidence | Status |
| --- | --- | --- | --- |
| IR smoke module | `Rsc/Parameters.hpp:385` exposes `WFBE_C_MODULE_WFBE_IRS`, default `1`. | Constants/init/build/rearm/upgrade readers use `WFBE_C_MODULE_WFBE_IRSMOKE` (`Init_CommonConstants.sqf:1163`, `Init_Common.sqf:351`, `Common_RearmVehicle*.sqf`, `Client_BuildUnit.sqf`, `Server_BuyUnit.sqf`, and core upgrade files). | Fixed behind `WFBE_C_FIX_IRSMOKE_PARAM_ALIAS = 0`; when enabled, the exposed lobby value is copied to the runtime name after the legacy fallback is set. |
| Volumetric clouds | `Rsc/Parameters.hpp:207` exposes a single `0` value and documents the FPS/stutter reason. | Client/common init force `WFBE_C_ENVIRONMENT_WEATHER_VOLUMETRIC = 0`. | Intentional locked-off parameter, no source change. |
| BIS High Command toggle | `Rsc/Parameters.hpp:378` records the removed `WFBE_C_MODULE_BIS_HC` class. | No live runtime reader; HC routing uses `WFBE_C_AI_DELEGATION`. | Already pruned as a dead lobby toggle, no source change. |
| AI group size | `Rsc/Parameters.hpp:41` exposes `WFBE_C_AI_MAX`. | Commander production/HCTopUp and constants read `WFBE_C_AI_MAX`. | Live consumer present, no source change. |
| Vehicle cleanup timeout | `Rsc/Parameters.hpp:239` exposes `WFBE_C_UNITS_CLEAN_TIMEOUT`. | `Common_TrashObject.sqf` reads `WFBE_C_UNITS_CLEAN_TIMEOUT` for non-man cleanup. | Live consumer present, no source change. |

## 2026-07-03 lane 210 delta

This delta keeps gameplay defaults unchanged. On dedicated, `Rsc/Parameters.hpp` defaults win at runtime because parameter compilation seeds the `WFBE_C_*` variables before `Init_CommonConstants.sqf` reaches its `isNil` fallbacks. The fallback values still matter for code review, script-only tests, local harnesses, and any launch path that misses parameter compilation.

Static census against Chernarus source plus the maintained `Missions_Vanilla` Takistan and Zargabad roots found the same value set in all three roots:

- 103 `Rsc/Parameters.hpp` classes with `default = ...`.
- 79 matching simple one-line `if (isNil "...") then { ... }` fallbacks in `Init_CommonConstants.sqf`.
- 29 simple value drifts where the lobby default and fallback differ.
- Block K's named review targets are real: `WFBE_C_AI_TEAMS_ENABLED`, `WFBE_C_AI_TEAMS_JIP_PRESERVE`, and `WFBE_C_RESPAWN_PENALTY`.

The table uses Chernarus line anchors; Takistan and Zargabad carry the same values in their `Missions_Vanilla` roots.

| Name | Lobby default | Fallback | Evidence | Recommendation |
| --- | ---: | ---: | --- | --- |
| `WFBE_C_AI_DELEGATION` | `2` | `0` | `Rsc/Parameters.hpp:39`; `Init_CommonConstants.sqf:261` | Existing lobby-wins drift; do not change without owner balance decision. |
| `WFBE_C_AI_MAX` | `4` | `12` | `Rsc/Parameters.hpp:45`; `Init_CommonConstants.sqf:260` | Existing lobby-wins drift; do not change without owner balance decision. |
| `WFBE_C_AI_TEAMS_ENABLED` | `0` | `1` | `Rsc/Parameters.hpp:63`; `Init_CommonConstants.sqf:262` | Block K review target: decide whether lobby-off or fallback-on is intended; align one surface after owner choice. |
| `WFBE_C_AI_TEAMS_JIP_PRESERVE` | `0` | `1` | `Rsc/Parameters.hpp:57`; `Init_CommonConstants.sqf:263` | Block K review target: decide whether JIP preserve should default off or on; align one surface after owner choice. |
| `WFBE_C_ARTILLERY` | `2` | `1` | `Rsc/Parameters.hpp:69`; `Init_CommonConstants.sqf:1090` | Existing lobby-wins drift; do not change without owner balance decision. |
| `WFBE_C_BASE_AREA` | `3` | `2` | `Rsc/Parameters.hpp:99`; `Init_CommonConstants.sqf:1104` | Existing lobby-wins drift; do not change without owner balance decision. |
| `WFBE_C_BASE_DEFENSE_MANNING_RANGE` | `350` | `250` | `Rsc/Parameters.hpp:105`; `Init_CommonConstants.sqf:1107` | Existing lobby-wins drift; do not change without owner balance decision. |
| `WFBE_C_ENVIRONMENT_MAX_VIEW` | `6000` | `5000` | `Rsc/Parameters.hpp:386`; `Init_CommonConstants.sqf:1302` | Existing lobby-wins drift; do not change without owner balance decision. |
| `WFBE_C_GAMEPLAY_AIR_AA_MISSILES` | `2` | `1` | `Rsc/Parameters.hpp:231`; `Init_CommonConstants.sqf:1317` | Existing lobby-wins drift; do not change without owner balance decision. |
| `WFBE_C_GAMEPLAY_FAST_TRAVEL` | `2` | `1` | `Rsc/Parameters.hpp:255`; `Init_CommonConstants.sqf:1319` | Existing lobby-wins drift; do not change without owner balance decision. |
| `WFBE_C_GAMEPLAY_MISSILES_RANGE` | `3000` | `0` | `Rsc/Parameters.hpp:297`; `Init_CommonConstants.sqf:1322` | Existing lobby-wins drift; do not change without owner balance decision. |
| `WFBE_C_MODULE_WFBE_FLARES` | `2` | `1` | `Rsc/Parameters.hpp:392`; `Init_CommonConstants.sqf:1344` | Existing lobby-wins drift; do not change without owner balance decision. |
| `WFBE_C_PLAYERS_AI_MAX` | `15` | `16` | `Rsc/Parameters.hpp:51`; `Init_CommonConstants.sqf:1356` | Existing lobby-wins drift; do not change without owner balance decision. |
| `WFBE_C_RESPAWN_CAMPS_MODE` | `1` | `2` | `Rsc/Parameters.hpp:447`; `Init_CommonConstants.sqf:1384` | Existing lobby-wins drift; do not change without owner balance decision. |
| `WFBE_C_RESPAWN_CAMPS_RANGE` | `400` | `550` | `Rsc/Parameters.hpp:484`; `Init_CommonConstants.sqf:1385` | Existing lobby-wins drift; do not change without owner balance decision. |
| `WFBE_C_RESPAWN_CAMPS_RULE_MODE` | `1` | `2` | `Rsc/Parameters.hpp:453`; `Init_CommonConstants.sqf:1386` | Existing lobby-wins drift; do not change without owner balance decision. |
| `WFBE_C_RESPAWN_DELAY` | `30` | `10` | `Rsc/Parameters.hpp:460`; `Init_CommonConstants.sqf:1387` | Existing lobby-wins drift; do not change without owner balance decision. |
| `WFBE_C_RESPAWN_LEADER` | `0` | `2` | `Rsc/Parameters.hpp:466`; `Init_CommonConstants.sqf:1388` | Existing lobby-wins drift; do not change without owner balance decision. |
| `WFBE_C_RESPAWN_MOBILE` | `1` | `2` | `Rsc/Parameters.hpp:472`; `Init_CommonConstants.sqf:1389` | Existing lobby-wins drift; do not change without owner balance decision. |
| `WFBE_C_RESPAWN_PENALTY` | `0` | `4` | `Rsc/Parameters.hpp:478`; `Init_CommonConstants.sqf:1390` | Block K review target: lobby currently disables penalty while fallback says one-fourth gear price; align one surface after owner choice. |
| `WFBE_C_STRUCTURES_MAX` | `2` | `3` | `Rsc/Parameters.hpp:111`; `Init_CommonConstants.sqf:1401` | Existing lobby-wins drift; do not change without owner balance decision. |
| `WFBE_C_TOWNS_AMOUNT` | `4` | `7` | `Rsc/Parameters.hpp:490`; `Init_CommonConstants.sqf:1423` | Existing lobby-wins drift; do not change without owner balance decision. |
| `WFBE_C_TOWNS_BUILD_PROTECTION_RANGE` | `100` | `450` | `Rsc/Parameters.hpp:550`; `Init_CommonConstants.sqf:1424` | Existing lobby-wins drift; do not change without owner balance decision. |
| `WFBE_C_TOWNS_CAPTURE_MODE` | `2` | `0` | `Rsc/Parameters.hpp:502`; `Init_CommonConstants.sqf:1425` | Existing lobby-wins drift; do not change without owner balance decision. |
| `WFBE_C_TOWNS_OCCUPATION` | `1` | `2` | `Rsc/Parameters.hpp:520`; `Init_CommonConstants.sqf:1427` | Existing lobby-wins drift; do not change without owner balance decision. |
| `WFBE_C_TOWNS_VEHICLES_LOCK_DEFENDER` | `0` | `1` | `Rsc/Parameters.hpp:562`; `Init_CommonConstants.sqf:1434` | Existing lobby-wins drift; do not change without owner balance decision. |
| `WFBE_C_UNITS_CLEAN_TIMEOUT` | `120` | `60` | `Rsc/Parameters.hpp:243`; `Init_CommonConstants.sqf:1467` | Existing lobby-wins drift; do not change without owner balance decision. |
| `WFBE_C_UNITS_EMPTY_TIMEOUT` | `300` | `1800` | `Rsc/Parameters.hpp:249`; `Init_CommonConstants.sqf:1468` | Existing lobby-wins drift; do not change without owner balance decision. |
| `WFBE_C_UNITS_TRACK_INFANTRY` | `0` | `1` | `Rsc/Parameters.hpp:321`; `Init_CommonConstants.sqf:1480` | Existing lobby-wins drift; do not change without owner balance decision. |

Delta recommendation: treat the three Block K rows as owner-decision items rather than silent source fixes. A future source PR should either align the fallback/comment text to the lobby-default runtime truth or deliberately change lobby defaults with an explicit gameplay rationale.

Out of scope: renaming the lobby class, changing parameter defaults, hidden upgrade-clearance switches, modded mission copy cleanup, and any UI/stringtable pass.
