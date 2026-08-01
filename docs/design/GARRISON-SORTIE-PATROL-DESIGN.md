# Lane 237: Garrison sortie patrol design
<!-- GUIDE-REV: GR-2026-07-03a -->

Status: runtime implemented and owner-armed in `master`; this document is the
source-backed design and behavior contract for lane 237.

The original note was intentionally docs-only while the runtime was still
unclaimed. The implementation now exists in `Server/Server_GarrisonSortie.sqf`
and is launched from `Server/Init/Init_Server.sqf`. Keep this document aligned
with those source anchors so a future behavior or tuning change does not get
mistaken for an unimplemented proposal.

## Goal

Lane 237 proposes a small server-side patrol loop that lets active, side-owned towns send short-lived garrison
sorties outside the capture radius. The feature should create moving contact near towns without adding standing AI
at empty map locations.

The original design called for a dark default:

```sqf
WFBE_C_GARRISON_SORTIE = 0
```

The current owner-armed `master` default is `1` (owner go, 2026-07-27), while
`0` remains the safe off switch: `Init_Server.sqf` does not launch the worker,
so no sortie groups are created and the mission's pre-feature behavior is
preserved.

## Current runtime reconciliation

- `Common/Init/Init_CommonConstants.sqf` is the source of truth for the armed
  default and tunables.
- `Server/Init/Init_Server.sqf` launches the worker only when
  `WFBE_C_GARRISON_SORTIE > 0`.
- `Server/Server_GarrisonSortie.sqf` waits for a populated `towns` array, waits
  45 seconds, then polls every `WFBE_C_GARRISON_SORTIE_INTERVAL` seconds.
- The registry entry is the implemented shape
  `[_town, _group, _spawnTime, _sideID]`; it is script-local, not persistent.
- The proximity gate scans `playableUnits` for an alive human, excludes
  civilians, and excludes names in `WFBE_C_HC_NAMES` so a headless client does
  not count as player presence.
- Cleanup drops a sortie when its group is null/wiped, its town changes side or
  becomes inactive, or the TTL expires. It deletes only non-player units and
  deletes the group only when no player remains. Null-unit guards are proposed
  separately in open PR #1723; they are not part of `master` yet.
- When performance audit is enabled, each poll records
  `garrison_sortie_cycle`; that timing includes prune, eligibility, creation,
  patrol ordering, and cleanup work.

## Source anchors

- `Server/Init/Init_Server.sqf` compiles `AIPatrol` and launches the worker
  behind the flag using the existing append-only `execVM` style.
- `Server/Server_GarrisonSortie.sqf` owns the startup wait, poll loop,
  eligibility gates, group/unit creation, patrol order, registry, cleanup, and
  `garrison_sortie_cycle` audit record.
- `Server/Server_GuerAirDef.sqf` is the established precedent for tunables,
  active-town filtering, group/unit creation, `AIPatrol`, and player-safe
  cleanup.
- `Common/Functions/Common_CreateGroup.sqf` provides the emergency group-cap
  guard and source tagging; `Common/Functions/Common_CreateUnit.sqf` degrades
  cleanly on `grpNull` or failed `createUnit` and applies weapon backfill.

## Runtime worker shape

The implemented worker is launched from `Init_Server.sqf` behind
`WFBE_C_GARRISON_SORTIE > 0`, after the optional server workers, using the same
append-only style as `Server_GuerAirDef.sqf` and `Server_Oilfields.sqf`.

Use script-local state:

```sqf
_sorties = []; // each entry: [_town, _group, _spawnTime, _sideID]
```

Current tunables (the flag is owner-armed; the remaining values are
conservative):

- `WFBE_C_GARRISON_SORTIE = 1`
- `WFBE_C_GARRISON_SORTIE_INTERVAL = 120`
- `WFBE_C_GARRISON_SORTIE_TTL = 300`
- `WFBE_C_GARRISON_SORTIE_PLAYER_RANGE = 1500`
- `WFBE_C_GARRISON_SORTIE_PATROL_MIN = 300`
- `WFBE_C_GARRISON_SORTIE_PATROL_MAX = 800`
- `WFBE_C_GARRISON_SORTIE_SIZE = 4`
- `WFBE_C_GARRISON_SORTIE_MAX_ACTIVE = 4`

Eligibility per poll:

1. Wait until `towns` exists and contains entries.
2. Skip if the global active-sortie count is at `WFBE_C_GARRISON_SORTIE_MAX_ACTIVE`.
3. Consider only towns with `wfbe_active == true` and `sideID` matching WEST, EAST or GUER.
4. Require at least one alive, non-civilian human player within
   `WFBE_C_GARRISON_SORTIE_PLAYER_RANGE` before spawning, excluding names in
   `WFBE_C_HC_NAMES`. This keeps the feature from maintaining extra AI at towns
   nobody can encounter and prevents HC telemetry clients from opening the
   gate.
5. Skip any town that already has a live sortie in `_sorties`.
6. Resolve the side-appropriate infantry class from the existing
   `WFBE_%1SOLDIER` mission variable, falling back to the A2-safe WEST/EAST/GUER
   classes in the worker before creating units.

Spawn and order:

1. Create one group with `[side, "garrison-sortie"] Call WFBE_CO_FNC_CreateGroup`.
2. If the group is `grpNull`, log one warning and skip this poll.
3. Create `WFBE_C_GARRISON_SORTIE_SIZE` infantry with `WFBE_CO_FNC_CreateUnit`.
4. Tag the group with `wfbe_garrison_sortie = true`; do not mark it `wfbe_persistent`.
5. Order one patrol loop using `AIPatrol` around the town at a radius between the min/max tunables.

Cleanup:

1. Drop the registry entry when the group is null, all units are gone, the town
   is lost, the town becomes inactive, or the TTL expires. `WFBE_GameOver`
   stops further polling; it does not run a final teardown pass inside this
   worker.
2. During cleanup, delete only non-player units, then delete the group only
   when no player remains in it.
3. A sortie still consumes a real engine group while alive. `wfbe_persistent = false` only allows empty-group GC to
   reap it later; it does not remove the group from the live cap. Keep the global active cap low.

## Collision notes

The worker and launch point are now present in `master`. Any future source
change to `Server_GarrisonSortie.sqf`, `Init_Server.sqf`, or the flag constants
must still check open PR ownership before editing. This document-only
reconciliation does not change mission behavior or stack on the open cleanup
PR that also touches the worker.

## Validation and parity contract

- Run `A2WASP_SKIP_ZIP=1 dotnet run -c RELEASE` from `Tools/LoadoutManager`.
- Restore TK/ZG `version.sqf.template` to the branch base before staging, then verify the expected per-map values.
- Run `python Tools/Lint/check_sqf.py --select A3CMD,A3MARKER,A3REVEAL,A3SELECT,A3SORT,A3STRING,GROUPGETVAR,BRACKET,NSSETVAR3 --no-classname-index`.
- Check delimiter deltas for every touched SQF file.
- Confirm the flag-off path leaves no running worker and no new live groups.
- Scan the added code for A3-only commands, `missionNamespace setVariable [..., true]`, group `getVariable [name, default]`, bare numeric flag guards and `exitWith` inside `forEach`.
