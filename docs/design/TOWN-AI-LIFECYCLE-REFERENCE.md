# Town AI Lifecycle Reference

<!-- GUIDE-REV: GR-2026-07-03a -->

LANE: 215. Town-AI lifecycle reference.

This document maps the current Build84 town AI lifecycle without changing mission
behavior. It is intended as a shared reference for future AICOM, town defense, and
performance lanes that need to touch the town AI path.

## Scope

- Source branch: `claude/build84-cmdcon36`
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
| Town AI startup and activation loop | `Server/FSM/server_town_ai.sqf:24` |
| Capture transition, lazy garrison, and mop-up TTL | `Server/FSM/server_town.sqf:332` |
| Town group creation and defender tagging | `Common/Functions/Common_CreateTownUnits.sqf:73` |
| Static gunner manning and cleanup | `Server/Functions/Server_OperateTownDefensesUnits.sqf:19` |
| Patrol versus defense waypoints | `Server/FSM/server_town_patrol.sqf:20` |
| AICOM post-capture hold/release behavior | `Common/Functions/Common_RunCommanderTeam.sqf:2027` |
| Defaults and caps | `Common/Init/Init_CommonConstants.sqf:1516` |

## 1. Startup And Constants

The server starts town AI when defender or occupation mode is enabled during server
initialization (`Server/Init/Init_Server.sqf:1027`). `server_town_ai.sqf` caches the
core tuning values near startup:

- `WFBE_C_TOWNS_DETECTION_RANGE_ACTIVE_COEF` adjusts detection for active towns.
- `WFBE_C_TOWNS_UNITS_INACTIVE` is the inactive timeout before cleanup.
- `WFBE_C_PATROLS_DELAY_SPAWN` is cached as the patrol spawn delay.
- `WFBE_C_AI_DELEGATION` decides whether town groups can be delegated.
- `WFBE_C_TOWNS_DEFENDER` and `WFBE_C_TOWNS_OCCUPATION` gate defender/occupation
  behavior.

The loop also initializes each town with lifecycle variables:

- `wfbe_active`: ground activation state.
- `wfbe_active_air`: air-only activation state.
- `wfbe_inactivity`: last-seen/enemy timeout marker.
- `wfbe_active_override`: manual/forced activation escape hatch.
- `wfbe_active_vehicles`: active spawned vehicles for cleanup.
- `wfbe_town_teams`: active spawned groups for cleanup.

## 2. Activation Scan

Each town AI sweep recomputes active-town pressure before evaluating towns. The loop
counts currently active towns, publishes `wfbe_active_town_count`, and rereads the
population-tier budget (`Server/FSM/server_town_ai.sqf:70`). It also caches the
current GUER group count, falling back safely when the engine count path is not
available (`Server/FSM/server_town_ai.sqf:87`).

For each town, the detection range is derived from town radius and the configured
coefficient. The near-entity scan filters out town defender AI so the town does not
wake itself from its own garrison (`Server/FSM/server_town_ai.sqf:118`). Owned
towns count hostile WEST/EAST sides; GUER/UNKNOWN ownership ignores resistance for
the wake decision so resistance presence alone does not keep the town active.

When enemies are found, the loop refreshes `wfbe_inactivity`, clears stale active
override state, and uses `wfbe_episode_spawned` as a latch to prevent duplicate
spawns in the same activation episode (`Server/FSM/server_town_ai.sqf:159`).

## 3. Budget Deferrals

Before spawning, the loop can defer activation by zeroing the local enemy arrays.
This is the important pressure valve:

- Active-town budget: `WFBE_C_TOWNS_ACTIVE_MAX` limits how many ground-active towns
  can exist at once (`Common/Init/Init_CommonConstants.sqf:280`).
- Resistance group budget: `WFBE_C_GUER_GROUPS_MAX` limits the total GUER group
  pressure (`Common/Init/Init_CommonConstants.sqf:285`).
- Town group merge/cap settings are defined with the town group controls near
  `Common/Init/Init_CommonConstants.sqf:1755`.

If a town is over budget, the scan can still see enemies, but the activation path is
suppressed for that pass (`Server/FSM/server_town_ai.sqf:175`).

## 4. Ground And Air Activation

Ground activation sets `wfbe_active`, marks `wfbe_episode_spawned`, and chooses the
group list through `GetTownGroups` or `GetTownGroupsDefender` depending on town side
and current role (`Server/FSM/server_town_ai.sqf:209`). Air-only activation uses
`wfbe_active_air` and does not imply the same ground garrison lifecycle.

When the spawn path runs, the loop chooses spawn positions, creates the server,
client, or headless-client group, records the group in `wfbe_town_teams`, tracks
active vehicles, optionally mans static defenses, and emits the faction smoke cue
(`Server/FSM/server_town_ai.sqf:246`).

`Common_CreateTownUnits.sqf` is responsible for the actual unit creation. It tags
units, crew, and vehicles with `WFBE_IsTownDefenderAI` so later detection and cleanup
can distinguish them from attacking teams (`Common/Functions/Common_CreateTownUnits.sqf:73`).
It also attaches `WFBE_TownAI_*` metadata and starts `server_town_patrol.sqf` for
valid groups (`Common/Functions/Common_CreateTownUnits.sqf:113`).

## 5. Patrol Versus Defense Orders

Town groups begin in patrol mode inside `server_town_patrol.sqf`. The patrol loop
switches a group to defense mode when the owning side changes or when supply drops,
with optional contested-only behavior via `WFBE_C_TOWNS_PATROL_CONTESTED_ONLY`
(`Server/FSM/server_town_patrol.sqf:20`).

Patrol mode uses town patrol waypoints when available, falling back to general patrol
waypoints. Defense mode uses a SAD waypoint at the town defense range
(`Server/FSM/server_town_patrol.sqf:43`). The default range is
`WFBE_C_TOWNS_DEFENSE_RANGE` (`Common/Init/Init_CommonConstants.sqf:1533`).

## 6. Static Defense Operators

Static defenses are manned through `Server_OperateTownDefensesUnits.sqf`. Each town
uses a shared gunner group capped at 12 active gunner units; if that path cannot be
used, the function falls back to the global defense team
(`Server/Functions/Server_OperateTownDefensesUnits.sqf:19`).

The server fallback creates a gunner, tags it as `WFBE_IsTownDefenderAI`, assigns it
into the empty static weapon, and records the operator on the defense object
(`Server/Functions/Server_OperateTownDefensesUnits.sqf:76`). Cleanup removes
non-player operators, clears the defense operator reference, and marks per-town
gunner groups non-persistent for garbage collection
(`Server/Functions/Server_OperateTownDefensesUnits.sqf:106`).

On capture, GUER static defenses are removed when WEST/EAST capture a resistance
town so captors do not inherit old resistance statics (`Server/FSM/server_town.sqf:422`).

## 7. Capture Transition And Lazy Garrison

When a town changes side, `server_town.sqf` clears old active flags and the episode
latch for the previous garrison before broadcasting `TownCaptured`
(`Server/FSM/server_town.sqf:332`). Existing defenders can linger briefly under
`WFBE_C_TOWNS_DEFENDER_LINGER`; if the town is still held by the new side after the
linger window, the old defenders are cleaned up (`Server/FSM/server_town.sqf:387`).

For WEST/EAST ownership, the capture path does not immediately force full defenses.
It uses the lazy garrison/mop-up route: full defenses still spawn when enemies enter
the radius, while capture-side cleanup work can be handled by a small mop-up squad
(`Server/FSM/server_town.sqf:432`).

After a short delay, if the town is still owned by the captor, the server spawns one
mop-up squad from the smallest barracks squad, tags it as town defender AI, and
stores the group and units on the town (`Server/FSM/server_town.sqf:445`).

## 8. Mop-Up TTL

The mop-up group scans around the town every 30 seconds using the detection range and
coefficient. It includes resistance crew in the scan, exits after two clear scans,
and also stops when the town flips, the town deactivates, or
`WFBE_C_TOWNS_MOPUP_TTL` expires (`Server/FSM/server_town.sqf:479`). The default
TTL is defined at `Common/Init/Init_CommonConstants.sqf:1660`.

When the mop-up path exits, it deletes its units, vehicles, and group, then clears
the town variables that tracked the temporary squad (`Server/FSM/server_town.sqf:514`).

## 9. Deactivation Cleanup

The normal town AI cleanup path requires no current enemies and an expired
`wfbe_inactivity` window (`Server/FSM/server_town_ai.sqf:393`). Once that condition
is met, the server broadcasts the cleanup request, removes server-local units and
vehicles, clears `wfbe_town_teams`, clears active vehicle tracking, and removes
defense operators (`Server/FSM/server_town_ai.sqf:412`).

After cleanup, the loop clears `wfbe_episode_spawned` and sortie pointers so a later
wake can begin a new activation episode without inheriting stale state
(`Server/FSM/server_town_ai.sqf:450`).

## 10. AICOM Interaction

AICOM capture logic is separate from town AI spawning, but it touches the same
post-capture experience. When a team captures a town, the commander can assign a
short DEFEND hold by setting `wfbe_aicom_hold_until`, `wfbe_teammode = defense`, and
`wfbe_teamgoto` to the town center (`Common/Functions/Common_RunCommanderTeam.sqf:2027`).

If the team should not hold, AICOM clears town order state and returns the team to
the towns mode (`Common/Functions/Common_RunCommanderTeam.sqf:2051`). Capture pass
logic can also retry or release an uncapturable depot target after the configured
pass limit (`Common/Functions/Common_RunCommanderTeam.sqf:2069`).

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

- Compared the reference against Build84 source anchors listed above.
- Kept the lane documentation-only; changed file set is limited to this document.
- No package, deploy, server runtime, or LoadoutManager path was touched.
