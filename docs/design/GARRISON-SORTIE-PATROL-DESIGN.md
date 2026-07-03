# Lane 237: Garrison sortie patrol design
<!-- GUIDE-REV: GR-2026-07-03a -->

Status: docs-only source PR for lane 237. No mission source is changed by this note.

Reason for docs-only scope: the runtime implementation needs at least a default-off flag registration in
`Common/Init/Init_CommonConstants.sqf`, and that file had many active open PRs at claim time. This document
captures the source-backed shape so a later runtime PR can stack deliberately instead of adding another
uncoordinated constants edit.

## Goal

Lane 237 proposes a small server-side patrol loop that lets active, side-owned towns send short-lived garrison
sorties outside the capture radius. The feature should create moving contact near towns without adding standing AI
at empty map locations.

The future runtime feature should be dark by default:

```sqf
WFBE_C_GARRISON_SORTIE = 0
```

With the flag at `0`, no worker should start and mission behavior should remain byte-identical to the current
target except for generated template comments or pack artifacts, which should not be staged.

## Source anchors

- `Server/Init/Init_Server.sqf:26` compiles `AIPatrol`, which is the existing patrol-order primitive the sortie
  worker should reuse rather than adding a new waypoint engine.
- `Server/Init/Init_Server.sqf:941` launches `Server_GuerAirDef.sqf` as an independent server worker; lines
  `1012` and `1019` show the same append-only `execVM` launch style for other optional server loops.
- `Server/Server_GuerAirDef.sqf:50` reads interval/cap tunables from `missionNamespace`, `:157` runs the
  maintain loop while `!WFBE_GameOver`, `:278-279` filters active GUER-held towns, `:335` creates a tagged
  group through `WFBE_CO_FNC_CreateGroup`, `:342` creates units through `WFBE_CO_FNC_CreateUnit`, and `:395`
  hands the group to `AIPatrol`.
- `Server/Server_GuerAirDef.sqf:209-210` and `:262` show the player-safe cleanup pattern: delete non-player
  units and groups, but never `deleteVehicle` a player.
- `Common/Functions/Common_CreateGroup.sqf:35-64` has the current emergency group-cap guard, and `:79` tags
  successful groups with `wfbe_group_src`.
- `Common/Functions/Common_CreateUnit.sqf:41-54` degrades cleanly on `grpNull` or failed `createUnit`, and
  `:59-74` applies the existing weapon-backfill safety for weaponless specialist classes.

## Proposed worker shape

Add `Server/Server_GarrisonSortie.sqf` only in the future runtime PR. Launch it from `Init_Server.sqf` behind
`WFBE_C_GARRISON_SORTIE > 0` after the optional server workers, using the same append-only style as
`Server_GuerAirDef.sqf` and `Server_Oilfields.sqf`.

Use script-local state:

```sqf
_sorties = []; // each entry: [_town, _group, _spawnTime, _lastEnemyTime]
```

Suggested tunables, all default-off or conservative:

- `WFBE_C_GARRISON_SORTIE = 0`
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
4. Require at least one player within `WFBE_C_GARRISON_SORTIE_PLAYER_RANGE` before spawning. This keeps the
   feature from maintaining extra AI at towns nobody can encounter.
5. Skip any town that already has a live sortie in `_sorties`.
6. Pick the side-appropriate infantry class from existing mission variables, but verify the exact class source in
   the runtime PR before creating units.

Spawn and order:

1. Create one group with `[side, "garrison-sortie"] Call WFBE_CO_FNC_CreateGroup`.
2. If the group is `grpNull`, log one warning and skip this poll.
3. Create `WFBE_C_GARRISON_SORTIE_SIZE` infantry with `WFBE_CO_FNC_CreateUnit`.
4. Tag the group with `wfbe_garrison_sortie = true`; do not mark it `wfbe_persistent`.
5. Order one patrol loop using `AIPatrol` around the town at a radius between the min/max tunables.

Cleanup:

1. Drop the registry entry when the group is null, all units are gone, the town is lost, the town becomes inactive,
   the TTL expires, or `WFBE_GameOver` becomes true.
2. During cleanup, delete only non-player units, then delete the group.
3. A sortie still consumes a real engine group while alive. `wfbe_persistent = false` only allows empty-group GC to
   reap it later; it does not remove the group from the live cap. Keep the global active cap low.

## Collision notes

At claim time, open PR metadata showed active edits on `Init_CommonConstants.sqf`, including current AICOM,
economy, defense and map-scale lanes. A runtime implementation should either wait for those branches to fold or
base explicitly on the chosen upstream PR and declare the stack in the PR body.

The new worker file and `Init_Server.sqf` launch point were clear at the file level, but the required flag
registration was not clear. That is why this PR only documents the implementation plan.

## Validation plan for the future runtime PR

- Run `A2WASP_SKIP_ZIP=1 dotnet run -c RELEASE` from `Tools/LoadoutManager`.
- Restore TK/ZG `version.sqf.template` to the branch base before staging, then verify the expected per-map values.
- Run `python Tools/Lint/check_sqf.py --select A3CMD,A3MARKER,A3REVEAL,A3SELECT,A3SORT,A3STRING,GROUPGETVAR,BRACKET,NSSETVAR3 --no-classname-index`.
- Check delimiter deltas for every touched SQF file.
- Confirm the flag-off diff leaves no running worker and no new live groups.
- Scan the added code for A3-only commands, `missionNamespace setVariable [..., true]`, group `getVariable [name, default]`, bare numeric flag guards and `exitWith` inside `forEach`.
