# Town AI Lifecycle Reference

<!-- GUIDE-REV: GR-2026-07-08a -->

LANE: 215. Town-AI lifecycle reference.

This document maps the current town AI lifecycle on `origin/master` without changing
mission behavior. It is intended as a shared reference for future AICOM, town defense, and
performance lanes that need to touch the town AI path.

## Scope

- Source branch: `master` (verified against `origin/master` @ `bbab122f0`, 2026-07-12).
  Re-anchored 2026-07-12 from the retired `claude/build84-cmdcon36` baseline (Fleet lane
  `wasp-town-ai-lifecycle-reference-reconcile`); the line numbers and layout below reflect
  current master, not Build84.
- Documentation only: no SQF, constants, loadout, package, or deploy changes
- Primary files: `Server/FSM/server_town_ai.sqf`,
  `Server/FSM/server_town.sqf`,
  `Common/Functions/Common_CreateTownUnits.sqf`,
  `Server/Functions/Server_OperateTownDefensesUnits.sqf`,
  `Server/FSM/server_town_patrol.sqf`, and
  `Common/Functions/Common_RunCommanderTeam.sqf`

## Source Map

| Area | Source |
| --- | --- |
| Town AI startup and activation loop | `Server/FSM/server_town_ai.sqf:28` |
| Capture transition, lazy garrison, and mop-up TTL | `Server/FSM/server_town.sqf:431` |
| Town group creation and defender tagging | `Common/Functions/Common_CreateTownUnits.sqf:141` |
| Static gunner manning and cleanup | `Server/Functions/Server_OperateTownDefensesUnits.sqf:21` |
| Patrol versus defense waypoints | `Server/FSM/server_town_patrol.sqf:31` |
| AICOM post-capture hold/release behavior | `Common/Functions/Common_RunCommanderTeam.sqf:2307` |
| Active-town and GUER group budgets | `Common/Init/Init_CommonConstants.sqf:326` |
| Town difficulty, detection, defense, linger, and mop-up defaults | `Common/Init/Init_CommonConstants.sqf:1759` |
| Town-garrison group-merge caps | `Common/Init/Init_CommonConstants.sqf:2015` |

## 1. Startup And Constants

The server starts town AI when defender or occupation mode is enabled during server
initialization (`Server/Init/Init_Server.sqf:1125`). `server_town_ai.sqf` caches the
core tuning values near startup:

- `WFBE_C_TOWNS_DETECTION_RANGE_ACTIVE_COEF` adjusts detection for active towns.
- `WFBE_C_TOWNS_UNITS_INACTIVE` is the inactive timeout before cleanup.
- `WFBE_C_PATROLS_DELAY_SPAWN` is cached as the patrol spawn delay
  (`Server/FSM/server_town_ai.sqf:28`).
- `WFBE_C_AI_DELEGATION` decides whether town groups can be delegated.
- `WFBE_C_TOWNS_DEFENDER` and `WFBE_C_TOWNS_OCCUPATION` gate defender/occupation
  behavior.

The loop also initializes each town with lifecycle variables
(`Server/FSM/server_town_ai.sqf:51`):

- `wfbe_active`: ground activation state.
- `wfbe_active_air`: air-only activation state.
- `wfbe_inactivity`: last-seen/enemy timeout marker.
- `wfbe_active_override`: manual/forced activation escape hatch.
- `wfbe_active_vehicles`: active spawned vehicles for cleanup.
- `wfbe_town_teams`: active spawned groups for cleanup.
- `wfbe_episode_spawned`: per-activation-episode spawn latch.

## 2. Activation Scan

Each town AI sweep recomputes active-town pressure before evaluating towns. The loop
counts currently active towns and publishes `wfbe_active_town_count`
(`Server/FSM/server_town_ai.sqf:77`), then rereads the per-sweep population-tier budget
from `WFBE_C_TOWNS_ACTIVE_MAX_BY_TIER` (`Server/FSM/server_town_ai.sqf:84`). It also
caches the current GUER group count from the per-side group-count cache, falling back to
a live `allGroups` scan when the cache has not yet warmed
(`Server/FSM/server_town_ai.sqf:93`).

For each town, the detection range is derived from town radius and the configured
coefficient. The near-entity scan filters out town defender AI so the town does not
wake itself from its own garrison (`Server/FSM/server_town_ai.sqf:158`). Owned
towns count hostile WEST/EAST sides; GUER/UNKNOWN ownership ignores resistance for
the wake decision so resistance presence alone does not keep the town active.

When enemies are found, the loop refreshes `wfbe_inactivity`, clears stale active
override state, and uses `wfbe_episode_spawned` as a latch to prevent duplicate
spawns in the same activation episode (`Server/FSM/server_town_ai.sqf:203`).

## 3. Budget Deferrals

Before spawning, the loop applies two explicit budget gates that skip activation for the
current pass (each guarded by a debounced "deferred" log line, at most one per five
minutes). This is the important pressure valve:

- Active-town budget: `WFBE_C_TOWNS_ACTIVE_MAX` seeds the cap on concurrently
  ground-active towns (`Common/Init/Init_CommonConstants.sqf:326`); the live per-sweep
  value is read from the population-tier array `WFBE_C_TOWNS_ACTIVE_MAX_BY_TIER`
  (`Common/Init/Init_CommonConstants.sqf:391`). Activation is skipped once the
  active-town count has reached that cap (`Server/FSM/server_town_ai.sqf:244`).
- Resistance group budget: `WFBE_C_GUER_GROUPS_MAX` limits the total GUER group
  pressure (`Common/Init/Init_CommonConstants.sqf:331`). A resistance garrison is
  deferred when the current GUER group count is at that budget
  (`Server/FSM/server_town_ai.sqf:260`).
- Town-garrison group-merge caps consolidate spawned garrisons into fewer group-brains
  (staying under the group budget without cutting units): `WFBE_C_TOWNS_MERGE_TARGET`
  and the defender-specific `WFBE_C_TOWNS_MERGE_TARGET_DEFENDER` /
  `WFBE_C_TOWNS_MERGE_CAP_DEFENDER` (`Common/Init/Init_CommonConstants.sqf:2015`).

If a town is over either budget, the scan can still see enemies, but the activation path
is suppressed for that pass.

## 4. Ground And Air Activation

Ground activation sets `wfbe_active`, marks `wfbe_episode_spawned`, and chooses the
group list through `GetTownGroups` or `GetTownGroupsDefender` depending on town side
and current role (`Server/FSM/server_town_ai.sqf:297`). Air-only activation uses
`wfbe_active_air` and does not imply the same ground garrison lifecycle.

When the spawn path runs, the loop chooses spawn positions, creates the server,
client, or headless-client group, records the group in `wfbe_town_teams`, tracks
active vehicles, optionally mans static defenses, and emits the faction smoke cue
(`Server/FSM/server_town_ai.sqf:435`).

`Common_CreateTownUnits.sqf` is responsible for the actual unit creation. It tags
units, crew, and vehicles with `WFBE_IsTownDefenderAI` so later detection and cleanup
can distinguish them from attacking teams (`Common/Functions/Common_CreateTownUnits.sqf:141`).
It also attaches `WFBE_TownAI_*` metadata and starts `server_town_patrol.sqf` for
valid groups (`Common/Functions/Common_CreateTownUnits.sqf:169`).

## 5. Patrol Versus Defense Orders

Town groups begin in patrol mode inside `server_town_patrol.sqf`. The patrol loop
switches a group to defense mode when the owning side changes or when supply drops,
with optional contested-only behavior via `WFBE_C_TOWNS_PATROL_CONTESTED_ONLY`
(`Server/FSM/server_town_patrol.sqf:31`).

Patrol mode uses town patrol waypoints when available, falling back to general patrol
waypoints. Defense mode uses a SAD waypoint at the town defense range
(`Server/FSM/server_town_patrol.sqf:50`). The default range is
`WFBE_C_TOWNS_DEFENSE_RANGE` (`Common/Init/Init_CommonConstants.sqf:1777`).

## 6. Static Defense Operators

Static defenses are manned through `Server_OperateTownDefensesUnits.sqf`. Each town
uses a shared gunner group capped at 12 active gunner units; if that path cannot be
used, the function falls back to the global defense team
(`Server/Functions/Server_OperateTownDefensesUnits.sqf:21`).

The server fallback creates a gunner, tags it as `WFBE_IsTownDefenderAI`, assigns it
into the empty static weapon, and records the operator on the defense object
(`Server/Functions/Server_OperateTownDefensesUnits.sqf:79`). Cleanup removes
non-player operators, clears the defense operator reference, and marks per-town
gunner groups non-persistent for garbage collection
(`Server/Functions/Server_OperateTownDefensesUnits.sqf:130`).

On capture, GUER static defenses are removed when WEST/EAST capture a resistance
town so captors do not inherit old resistance statics (`Server/FSM/server_town.sqf:600`).

## 7. Capture Transition And Lazy Garrison

When a town changes side, `server_town.sqf` clears old active flags and the episode
latch for the previous garrison before broadcasting `TownCaptured`
(`Server/FSM/server_town.sqf:431`). Existing defenders can linger briefly under
`WFBE_C_TOWNS_DEFENDER_LINGER`; if the town is still held by the new side after the
linger window, the old defenders are cleaned up (`Server/FSM/server_town.sqf:558`).

For WEST/EAST ownership, the capture path does not immediately force full defenses.
It uses the lazy garrison/mop-up route: full defenses still spawn when enemies enter
the radius, while capture-side cleanup work can be handled by a small mop-up squad
(`Server/FSM/server_town.sqf:580`).

After a short delay, if the town is still owned by the captor, the server spawns one
mop-up squad from the smallest barracks squad, tags it as town defender AI, and
stores the group and units on the town (`Server/FSM/server_town.sqf:611`).

## 8. Mop-Up TTL

The mop-up group scans around the town every 30 seconds using the detection range and
coefficient. It includes resistance crew in the scan, exits after two clear scans, and
also stops when the town flips, the town deactivates, or
`WFBE_C_TOWNS_MOPUP_TTL` expires (`Server/FSM/server_town.sqf:657`). The default
TTL is defined at `Common/Init/Init_CommonConstants.sqf:1914`.

When the mop-up path exits, it deletes its units, vehicles, and group, then clears
the town variables that tracked the temporary squad (`Server/FSM/server_town.sqf:694`).

## 9. Deactivation Cleanup

The normal town AI cleanup path requires no current enemies and an expired
`wfbe_inactivity` window (`Server/FSM/server_town_ai.sqf:536`). Once that condition
is met, the server broadcasts the cleanup request, removes server-local units and
vehicles, clears `wfbe_town_teams`, clears active vehicle tracking, and removes
defense operators (`Server/FSM/server_town_ai.sqf:628`).

After cleanup, the loop clears `wfbe_episode_spawned` and sortie pointers so a later
wake can begin a new activation episode without inheriting stale state
(`Server/FSM/server_town_ai.sqf:637`).

## 10. AICOM Interaction

AICOM capture logic is separate from town AI spawning, but it touches the same
post-capture experience. When a team captures a town, the commander can assign a short
DEFEND hold - gated by `WFBE_C_AICOM_HOLD_MODE` and self-expiring after
`WFBE_C_AICOM_HOLD_SECS` (default 180s) - by stamping `wfbe_aicom_hold_until` on the
town, setting `wfbe_teammode = defense`, and setting `wfbe_teamgoto` to the town center
(`Common/Functions/Common_RunCommanderTeam.sqf:2319`).

If the team should not hold, AICOM clears town order state and returns the team to the
towns mode (`Common/Functions/Common_RunCommanderTeam.sqf:2340`). Capture pass logic
can also retry or release an uncapturable depot target after the configured pass limit
`WFBE_C_AICOM_CAPTURE_MAXPASSES` (`Common/Functions/Common_RunCommanderTeam.sqf:2370`).

## Guardrails For Future Lanes

- Do not count `WFBE_IsTownDefenderAI` units as attackers in town wake logic.
- Preserve separate `wfbe_active` and `wfbe_active_air` state unless intentionally
  changing air-only activation semantics.
- Keep `wfbe_episode_spawned` cleanup paired with activation cleanup to avoid either
  duplicate spawns or permanently suppressed spawns.
- Treat static gunner lifecycle and town group lifecycle as coupled but distinct:
  gunner groups have their own persistence/cleanup path.
- Any source lane touching activation, mop-up, static manning, or AICOM hold logic
  should re-check active-town and GUER group budgets before changing spawn cadence.

## Validation Used For This Reference

- Compared the reference against current `origin/master` source anchors (@ `bbab122f0`,
  2026-07-12); every `file:line` above was re-verified by direct source read, with an
  independent per-file verification pass over all 35 anchors.
- Re-anchored from the retired `claude/build84-cmdcon36` baseline: the constants file was
  reorganized, with the active-town/GUER budgets and the new `*_BY_TIER` population-tier
  arrays now near the top, the difficulty/detection/defense/linger/mop-up defaults in the
  1759-1914 band, and the group-merge caps near 2015.
- Kept the lane documentation-only; the changed file set is limited to this document.
- No package, deploy, server runtime, or LoadoutManager path was touched.
