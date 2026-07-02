# ICBM / Build Ammo Tier-5 Gate Audit

Date: 2026-07-02
Lane: fleet lane 40, proposal-only
Base checked: `origin/claude/build84-cmdcon36` at `11736873`

## Scope

`MISSION-AUDIT-60.md` item 10 flags `Upgrades_CO_RU.sqf:104,109` and
`Upgrades_CO_US.sqf:104,109` because those two files require tier 5 for the
ICBM and Build Ammo gates. This pass checks whether those gates are mechanically
unreachable, then records the balance choice without changing source.

No mission source, generated Takistan files, lobby parameters, costs, times, or
upgrade defaults are changed here.

## Verdict

The tier-5 gates are reachable on the live lane. All 11 maintained Chernarus
faction upgrade files set both `WFBE_UP_AIR` and `WFBE_UP_GEAR` max levels to 5.

The real finding is faction parity, not reachability:

- `Upgrades_CO_RU.sqf` and `Upgrades_CO_US.sqf` require `AIR 5` for both ICBM
  levels and `GEAR 5` for Build Ammo.
- The other nine faction files require `AIR 3` for both ICBM levels and
  `GEAR 2` for Build Ammo.

Because this is a balance asymmetry, the recommendation is proposal-only: Ray
should decide whether the CO RU/US stricter gate is intentional late-game pacing
or should be normalized.

## Evidence Table

| File | Air max | Gear max | ICBM link | Build Ammo link | Result |
| --- | ---: | ---: | --- | --- | --- |
| `Upgrades_CDF.sqf` | 5 (`:64`) | 5 (`:74`) | `[[WFBE_UP_AIR,3],[WFBE_UP_AIR,3]]` (`:104`) | `[[WFBE_UP_GEAR,2]]` (`:109`) | Reachable |
| `Upgrades_CO_GUE.sqf` | 5 (`:64`) | 5 (`:74`) | `[[WFBE_UP_AIR,3],[WFBE_UP_AIR,3]]` (`:104`) | `[[WFBE_UP_GEAR,2]]` (`:109`) | Reachable |
| `Upgrades_CO_RU.sqf` | 5 (`:64`) | 5 (`:74`) | `[[WFBE_UP_AIR,5],[WFBE_UP_AIR,5]]` (`:104`) | `[[WFBE_UP_GEAR,5]]` (`:109`) | Reachable, stricter outlier |
| `Upgrades_CO_US.sqf` | 5 (`:64`) | 5 (`:74`) | `[[WFBE_UP_AIR,5],[WFBE_UP_AIR,5]]` (`:104`) | `[[WFBE_UP_GEAR,5]]` (`:109`) | Reachable, stricter outlier |
| `Upgrades_GUE.sqf` | 5 (`:64`) | 5 (`:74`) | `[[WFBE_UP_AIR,3],[WFBE_UP_AIR,3]]` (`:104`) | `[[WFBE_UP_GEAR,2]]` (`:109`) | Reachable |
| `Upgrades_INS.sqf` | 5 (`:64`) | 5 (`:74`) | `[[WFBE_UP_AIR,3],[WFBE_UP_AIR,3]]` (`:104`) | `[[WFBE_UP_GEAR,2]]` (`:109`) | Reachable |
| `Upgrades_OA_TKA.sqf` | 5 (`:64`) | 5 (`:74`) | `[[WFBE_UP_AIR,3],[WFBE_UP_AIR,3]]` (`:104`) | `[[WFBE_UP_GEAR,2]]` (`:109`) | Reachable |
| `Upgrades_OA_TKGUE.sqf` | 5 (`:64`) | 5 (`:74`) | `[[WFBE_UP_AIR,3],[WFBE_UP_AIR,3]]` (`:104`) | `[[WFBE_UP_GEAR,2]]` (`:109`) | Reachable |
| `Upgrades_OA_US.sqf` | 5 (`:64`) | 5 (`:74`) | `[[WFBE_UP_AIR,3],[WFBE_UP_AIR,3]]` (`:104`) | `[[WFBE_UP_GEAR,2]]` (`:109`) | Reachable |
| `Upgrades_RU.sqf` | 5 (`:64`) | 5 (`:74`) | `[[WFBE_UP_AIR,3],[WFBE_UP_AIR,3]]` (`:104`) | `[[WFBE_UP_GEAR,2]]` (`:109`) | Reachable |
| `Upgrades_USMC.sqf` | 5 (`:64`) | 5 (`:74`) | `[[WFBE_UP_AIR,3],[WFBE_UP_AIR,3]]` (`:104`) | `[[WFBE_UP_GEAR,2]]` (`:109`) | Reachable |

All line references are under:

`Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Config/Core_Upgrades/`

## Runtime Gate Check

The upgrade systems use the configured max levels and links directly:

- Player commander upgrades reject requests once `_current >= (_levels select _upgrade_id)`, then read `LINKS` for the current level and block unmet dependencies (`Server/PVFunctions/RequestUpgrade.sqf:90-129`).
- The queue driver performs the same max-level and link checks before auto-starting a queued upgrade (`Server/FSM/upgradeQueue.sqf:45-71`).
- The Build 86 AI commander economy sink explicitly scans `LEVELS`, `COSTS`, and `LINKS`, then starts only a dependency-satisfied affordable upgrade (`Server/AI/Commander/AI_Commander.sqf:553-618`).
- A sanity scan found no authored ICBM or Build Ammo entries in the 11 checked `AI_ORDER` blocks. The legacy `AI_ORDER` path is completed by `Check_Upgrades.sqf`, which appends missing levels by upgrade id and level; with `AIR` at index 3, ICBM at index 11, `GEAR` at index 13, and Build Ammo at index 14, the generated order still reaches the tier-5 prerequisite levels before those gated upgrades are considered (`Common/Config/Core_Upgrades/Check_Upgrades.sqf:9-35`).

That makes the suspected `AIR 5` / `GEAR 5` gates reachable in the current data model.

## Proposal Options

Option A: keep the CO RU/US stricter gates. This treats their `AIR 5` ICBM and
`GEAR 5` Build Ammo requirements as intentional late-game pacing.

Option B: normalize parity. Change `CO_RU` and `CO_US` to match the other nine
files: ICBM levels require `AIR 3`, and Build Ammo requires `GEAR 2`.

Option C: split the two-level SCUD/ICBM gate. For the CO RU/US pair, level 1
could require `AIR 3` for the conventional SCUD platform while level 2 keeps
`AIR 5` for the nuke-capable tier. Build Ammo could still be Ray's call:
leave at `GEAR 5` or normalize to `GEAR 2`.

No retune is made in this lane.

## Verification

- Parsed all 11 `Upgrades_*.sqf` files on `origin/claude/build84-cmdcon36`.
- Confirmed every `AIR 5` and `GEAR 5` requirement is within the configured max
  level for that same faction file.
- Confirmed this PR is docs-only; no SQF/SQM/HPP/EXT files changed.
- LoadoutManager was not run because no mission files changed.
