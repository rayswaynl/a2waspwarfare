# Flag System Quick Reference - 2026-07-03

Base checked: `origin/claude/build84-cmdcon36@873c7f7af2`.

Scope: fleet lane 316 reference for `Common/Init/Init_CommonConstants.sqf`, the main source-side index of `WFBE_C_*` tunables and feature gates. This page is documentation-only and does not change any mission behavior.

## First Rule

For multiplayer, `Rsc/Parameters.hpp` wins for any variable exposed as a lobby parameter.

The boot order is:

1. `initJIPCompatible.sqf:138` calls `Common/Init/Init_Parameters.sqf` in multiplayer.
2. `Init_Parameters.sqf:5-9` loops over every `missionConfigFile >> "Params"` class and writes the selected/default value into `missionNamespace` under the class name.
3. `initJIPCompatible.sqf:140` then calls `Common/Init/Init_CommonConstants.sqf`.
4. Most tunables in `Init_CommonConstants.sqf` use `if (isNil "NAME") then {NAME = fallback};`, so a parameter-loaded value is already non-nil and the fallback is skipped.

Practical consequence: if a name exists in `Rsc/Parameters.hpp`, check that class default and values before citing the live value. Changing only the `Init_CommonConstants.sqf` fallback does not change dedicated-server behavior for exposed lobby params.

## Known Overrides

- `WFBE_C_GUER_PLAYERSIDE` is both a constant fallback (`Init_CommonConstants.sqf:101`) and a lobby param (`Parameters.hpp:629`). Dedicated MP then force-reads the parameter default again at `initJIPCompatible.sqf:142-147` because the last parameter can be stale in cached `paramsArray`.
- Starting funds and supply are exposed in the lobby (`Parameters.hpp:161-183`) and have SQF fallbacks (`Init_CommonConstants.sqf:1277-1286`), but dedicated MP also applies the economy boost and lean override at `initJIPCompatible.sqf:149-173`.
- The live side-supply cap is the lobby parameter `WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT` (`Parameters.hpp:186`), not the local fallback alone. The constants file documents this at `Init_CommonConstants.sqf:1287-1293`.
- `WFBE_C_GAMEPLAY_FAST_TRAVEL` defaults to fee mode in the lobby (`Parameters.hpp:244`) while the SQF fallback is free mode (`Init_CommonConstants.sqf:1396`). Dedicated MP reads the lobby value.
- IR smoke has a name mismatch: the lobby exposes `WFBE_C_MODULE_WFBE_IRS` (`Parameters.hpp:430`), while runtime readers use `WFBE_C_MODULE_WFBE_IRSMOKE`; the optional alias is guarded at `Init_CommonConstants.sqf:1437-1440`.

## Source Index

| Area | Main anchors | Notes |
| --- | --- | --- |
| Upgrade ids | `Init_CommonConstants.sqf:37-60` | `WFBE_UP_BARRACKS` through `WFBE_UP_PATROLS` are fixed index constants. These must match all side upgrade arrays. |
| Boot/side ids | `Init_CommonConstants.sqf:24-33` | `WFBE_C_WEST_ID`, `WFBE_C_EAST_ID`, `WFBE_C_GUER_ID`, `WFBE_C_CIV_ID`, and `WFBE_C_UNKNOWN_ID` are not feature flags. |
| Zargabad pre-sets | `Init_CommonConstants.sqf:75-96` | ZG seeds selected AICOM/base constants before the later `isNil` CH/TK fallbacks, so the ZG value wins without changing CH/TK defaults. |
| GUER player systems | `Init_CommonConstants.sqf:101-215` | Playable GUER, VBIED, mortar, improvised armor, kill tiers, FOBs, depot-neutral buy, and barracks AI cap. |
| GUER air defense and Ka-137 | `Init_CommonConstants.sqf:220-250`, `:356-359` | Server GUER air-defense loop, Ka-137 swarm/flare knobs, paradrop cap, and Ka-137 reward coefficient. These are mostly constants-only, not lobby params. |
| AI commander master and pop scale | `Init_CommonConstants.sqf:273-360` | AI commander enable/lock/garrison, GUER group cap, AI group size, team-count curve, pop-tier arrays, AICOM group cap, and route basics. |
| AICOM air and airlift | `Init_CommonConstants.sqf:417-456` | Plane air-start, air hull caps, heli/airfield waivers, hot-LZ paradrop, retained transport, and tiered vehicle lift. |
| AICOM objective scoring | `Init_CommonConstants.sqf:560-577`, `:686-710` | Near-band, concentration, spearhead count, HQ strike thresholds, v2 allocate/fist/harass/expand flags. |
| AICOM base/HQ strike/economy | `Init_CommonConstants.sqf:592-654` | MHQ relocation/rebase, HQ-strike commit/overrun, bootstrap supply gate, base sell, income taper, funds sink. |
| AICOM behavior wave | `Init_CommonConstants.sqf:881-930` | Spread/hold, base assault, losing press, withdrawal, strike staging, orbiter/stuck decay, top-up TTL, command menu V2, econ sink teamcap. |
| Economy and supply | `Init_CommonConstants.sqf:1277-1320` | Starting funds/supply fallbacks, income cadence, supply cap notes, supply income multiplier, supply-mission cargo/heli knobs. |
| Gameplay and modules | `Init_CommonConstants.sqf:1393-1443` | Fast travel, friendly fire, hangars, thermal imaging, ambient skirmish, EASA/flares/auto-CM/ICBM/IR smoke. |
| Player AI cap | `Init_CommonConstants.sqf:1445-1446` | Fallback for `WFBE_C_PLAYERS_AI_MAX`; lobby default is separate at `Parameters.hpp:47`. |
| Structures | `Init_CommonConstants.sqf:1485-1503`, `:1563-1565`, `:1637-1649`, `:1741-1750` | Structure toggles, HQ deploy cost/range, max counts, damage reduction, flatness checks, WDDM/experimental structures, per-type maxima. |
| Towns | `Init_CommonConstants.sqf:1512-1552`, `:1652-1660`, `:1753-1757` | Town amount/mode, capture mode, garrison/occupation difficulty, patrols, capture ranges, static-gunner timing, merge targets. |
| Telemetry and reports | `Init_CommonConstants.sqf:1633-1651` | Playerstat emitter, `WFBE_C_STATLOG`, and temporary `WFBE_C_LOG_TOWN_COORDS`. Reset coordinate harvest after use. |

## Lobby-Exposed Families

The current lobby file exposes only a subset of the flag space. Major exposed families:

| Family | `Rsc/Parameters.hpp` anchors | Examples |
| --- | --- | --- |
| Supply mission | `:5` | `WFBE_C_SUPPLY_HELI_ENABLED` |
| AI/player sizes and commander | `:41`, `:47`, `:77`, `:83` | `WFBE_C_AI_MAX`, `WFBE_C_PLAYERS_AI_MAX`, `WFBE_C_AI_COMMANDER_ENABLED`, `WFBE_C_AI_COMMANDER_LEVEL` |
| Structures | `:89`, `:107-125` | `WFBE_C_STRUCTURES_ANTIAIRRADAR`, `WFBE_C_STRUCTURES_MAX`, `WFBE_C_STRUCTURES_HQ_COST_DEPLOY` |
| Economy | `:149-186` | Currency, income interval, start funds/supply, side supply cap |
| Gameplay | `:220-351` | Fast travel, friendly fire, boundaries, missiles, team-swap, thermal imaging, victory condition |
| Modules | `:213`, `:381-430` | PMC, flares, auto-CM, EASA, ICBM, IR smoke lobby name |
| Towns and patrols | `:479-557` | Town amount, capture mode, defender/occupation, patrols, build protection, town start mode |
| GUER lobby controls | `:629-656` | Playable GUER and scavenger values; air-defense, kill-tier, FOB, Ka-137, and mortar knobs are not exposed here. |

## Editing Rules

- Verify the symbol exists in the current branch before citing a line number. This file is a moving target during the fleet.
- If the name appears in `Rsc/Parameters.hpp`, change/check the parameter class for live dedicated defaults.
- Append new feature flags near related constants with the existing `if (isNil "NAME") then {NAME = value};` idiom unless the surrounding section is intentionally enum-style.
- Do not reorder `WFBE_UP_*` values. They are array indices, not free tunables.
- Treat direct assignments like `WFBE_C_TOTAL_AI_MAX_BY_TIER = [...]` as constants unless the caller intentionally supports live overriding elsewhere.
- For numeric gates, consumers should test `> 0`, not rely on bare numeric truthiness.
- For documentation or QA, prefer line anchors plus the owning consumer file. A constant's presence alone does not prove it is still read.

## Quick Checks

Use these before filing a constants/defaults PR:

1. Search both files:
   `rg -n "WFBE_C_SOME_FLAG|class WFBE_C_SOME_FLAG" Missions/[55-2hc]warfarev2_073v48co.chernarus`
2. If exposed in `Parameters.hpp`, record the lobby default and values, then check whether `Init_CommonConstants.sqf` is only a local/editor fallback.
3. Search consumers:
   `rg -n "WFBE_C_SOME_FLAG" Missions/[55-2hc]warfarev2_073v48co.chernarus --glob "*.sqf" --glob "*.fsm" --glob "*.hpp"`
4. For map-conditional constants, check Chernarus, Takistan, and Zargabad intent before changing a shared fallback.
5. For docs-only work, no LoadoutManager mirror is required. For any SQF behavior change, edit Chernarus source first and mirror through LoadoutManager.

## Non-Goals

This page is not a full generated catalog of every `WFBE_C_*` symbol. It is a routing map for agents: where the current families live, which defaults are parameter-owned, and what must be verified before citing or changing a flag.
