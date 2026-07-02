# Map-Aware Cleaner / Restorer Origins Audit

Date: 2026-07-02
Lane: fleet lane 171, docs-only closure
Base checked: `origin/claude/build84-cmdcon36@b2dbab5f`

## Scope

Fleet lane 171 asks for the dropped-item cleaner, crater cleaner, ruins cleaner,
building restorer, and related map-bound logic to stop hardcoding Chernarus
scan origins/bounds. This pass checks the current `claude/build84-cmdcon36`
target and records the actual state without changing gameplay source.

No mission source, generated Takistan files, lobby parameters, cleaner cadence,
scan classes, scan radius defaults, or live deployment artifacts are changed in
this lane.

## Verdict

The lane is already implemented as default-off source on the current target.
The four checked cleaner/restorer files still define legacy Chernarus scan
anchors for flag-0 behavior, but each file also reads
`WFBE_C_CLEANER_MAP_AWARE_ORIGINS`. When that flag is enabled, the scan center
is recalculated from `WFBE_BOUNDARIESXY / 2` and the scan radius becomes
`WFBE_BOUNDARIESXY * 0.72` before the first scan runs.

`WFBE_BOUNDARIESXY` is populated by `Init_Boundaries.sqf` for known islands even
when the gameplay boundary parameter is disabled, so the cleaner/restorer flag
does not depend on the visible map-boundary gameplay feature being active.

The remaining decision is operational rather than patch-ready: whether Ray wants
to enable or expose `WFBE_C_CLEANER_MAP_AWARE_ORIGINS` for a soak. Keeping it at
default `0` preserves the legacy scan boxes; setting it to `1` switches the four
checked systems to the existing map-size path.

## Evidence Table

| Surface | Legacy flag-0 behavior | Flag-1 map-aware path | First scan uses flag-adjusted values? |
| --- | --- | --- | --- |
| Dropped items | `_scanCentre = [7000, 7500, 0]`, `_scanRadius = 20000` (`droppeditems_cleaner.sqf:33-35`) | Reads `WFBE_BOUNDARIESXY`, sets `_scanCentre = [_mapHalf, _mapHalf, 0]`, `_scanRadius = _mapSize * 0.72` (`:36-42`) | Yes. `_scanItems` is defined after the flag branch and uses `_scanCentre/_scanRadius` (`:44-49`); the first sweep starts after `_firstDelay` (`:51-69`). |
| Craters | `_scanCentre = [7000,7500,0]`, `_scanRadius = 20000` (`crater_cleaner.sqf:7-8`) | Reads `WFBE_BOUNDARIESXY`, sets center/radius from map size (`:9-15`) | Yes. The first `nearestObjects` calls are inside the loop after the flag branch and initial sleep (`:17-42`). |
| Ruins | `_scanCentre = [7000,7500,0]`, `_scanRadius = 20000` (`ruins_cleaner.sqf:7-8`) | Reads `WFBE_BOUNDARIESXY`, sets center/radius from map size (`:9-15`) | Yes. The first `nearestObjects` call is inside the loop after the flag branch and initial sleep (`:17-25`). |
| Building restorer | `_scanCentre = [7500,7900,0]`, `_scanRadius = 10500` (`buildings_restorer.sqf:6-7`) | Reads `WFBE_BOUNDARIESXY`, sets center/radius from map size (`:8-14`) | Yes. The first `nearestObjects` call is inside the loop after the flag branch and initial `uisleep` (`:16-24`). |

All source line references above are under:

`Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/`

## Boundary Contract

`Common/Init/Init_Boundaries.sqf` maps known `worldName` values to explicit
A2/OA-safe sizes, including Chernarus `15360`, Takistan `12800`, Utes `5120`,
and several mod terrains (`Init_Boundaries.sqf:4-16`). For known worlds it sets
`WFBE_BOUNDARIESXY` whether the gameplay boundary overlay is enabled or disabled
(`:19-36`).

`Common/Init/Init_Common.sqf:350` compiles `Init_Boundaries.sqf` during common
initialization, before `initJIPCompatible.sqf:340` starts
`Server/Init/Init_Server.sqf`. `Init_Server.sqf:1106-1128` then launches the
cleaners/restorer. That order means the map-size variable is available before
the checked server cleaner/restorer scripts evaluate the flag.

The controlling default is:

`Common/Init/Init_CommonConstants.sqf:1120`

`WFBE_C_CLEANER_MAP_AWARE_ORIGINS = 0`

The inline comment records the intended contract: default off keeps legacy
Chernarus scan anchors, while `1` makes cleaners/restorers use the
`Init_Boundaries` map size for scan center/radius.

## Lane 5 Overlap

The prompt correctly asks future workers to coordinate with the lane-5
`_egressOK` hardcoded-boundary work. On current `claude/build84-cmdcon36`,
that is a separate flag and path: `WFBE_C_BASE_EGRESS_MAP_BOUNDS` controls
random-start edge checks in `Init_Server.sqf:382-389`, while
`WFBE_C_CLEANER_MAP_AWARE_ORIGINS` controls the four cleaner/restorer scan
origins above.

No shared source edit is needed for this docs-only lane.

## Recommendation

Treat lane 171 as implemented-but-default-off on the current target. Before
flipping or exposing the flag, run a soak with `WFBE_C_CLEANER_MAP_AWARE_ORIGINS`
enabled and watch the existing PerformanceAudit labels:

- `cleaner_droppeditems`
- `cleaner_craters`
- `cleaner_ruins`
- `restorer_buildings`

The soak should confirm no large debris backlog on Takistan/mod terrains and no
unexpected scan-cost spike from the map-size-derived radius. If that passes, the
follow-up can be a config/default decision rather than a source-repair patch.

## Verification

- Checked `origin/claude/build84-cmdcon36@b2dbab5f`.
- Confirmed both maintained Chernarus and generated Takistan copies contain
  `WFBE_C_CLEANER_MAP_AWARE_ORIGINS` in the same four cleaner/restorer files.
- Confirmed the four checked Chernarus and Takistan cleaner/restorer files are
  byte-equivalent by `git diff --no-index`.
- Confirmed this PR is docs-only; no SQF/SQM/HPP/EXT files changed.
- LoadoutManager was not run because no mission files changed.
