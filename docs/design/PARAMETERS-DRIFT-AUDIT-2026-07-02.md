# Parameters Drift Audit - 2026-07-02

Base checked: `origin/claude/build84-cmdcon36@eb0f8275a`.

This pass keeps gameplay defaults unchanged. The only source change is a default-off compatibility alias so a future soak can opt into honoring the existing IR smoke lobby parameter name without changing flag-0 behavior.

| Surface | Lobby/config evidence | Runtime evidence | Status |
| --- | --- | --- | --- |
| IR smoke module | `Rsc/Parameters.hpp:385` exposes `WFBE_C_MODULE_WFBE_IRS`, default `1`. | Constants/init/build/rearm/upgrade readers use `WFBE_C_MODULE_WFBE_IRSMOKE` (`Init_CommonConstants.sqf:1163`, `Init_Common.sqf:351`, `Common_RearmVehicle*.sqf`, `Client_BuildUnit.sqf`, `Server_BuyUnit.sqf`, and core upgrade files). | Fixed behind `WFBE_C_FIX_IRSMOKE_PARAM_ALIAS = 0`; when enabled, the exposed lobby value is copied to the runtime name after the legacy fallback is set. |
| Volumetric clouds | `Rsc/Parameters.hpp:207` exposes a single `0` value and documents the FPS/stutter reason. | Client/common init force `WFBE_C_ENVIRONMENT_WEATHER_VOLUMETRIC = 0`. | Intentional locked-off parameter, no source change. |
| BIS High Command toggle | `Rsc/Parameters.hpp:378` records the removed `WFBE_C_MODULE_BIS_HC` class. | No live runtime reader; HC routing uses `WFBE_C_AI_DELEGATION`. | Already pruned as a dead lobby toggle, no source change. |
| AI group size | `Rsc/Parameters.hpp:41` exposes `WFBE_C_AI_MAX`. | Commander production/HCTopUp and constants read `WFBE_C_AI_MAX`. | Live consumer present, no source change. |
| Vehicle cleanup timeout | `Rsc/Parameters.hpp:239` exposes `WFBE_C_UNITS_CLEAN_TIMEOUT`. | `Common_TrashObject.sqf` reads `WFBE_C_UNITS_CLEAN_TIMEOUT` for non-man cleanup. | Live consumer present, no source change. |

Out of scope: renaming the lobby class, changing parameter defaults, hidden upgrade-clearance switches, modded mission copy cleanup, and any UI/stringtable pass.
