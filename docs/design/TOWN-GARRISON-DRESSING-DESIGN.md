# Town Garrison Dressing Design - Lane 241
<!-- GUIDE-REV: GR-2026-07-03a -->

Lane: 241, static ZU-23 town dressing
Base checked: `origin/claude/build84-cmdcon36@4910fc3f5fb5657feee6b554d700155f3a827092`
Scope: docs-only implementation design. No mission runtime files were edited.

## Summary

Lane 241 should ship, in a later runtime PR, as a default-off server-only dressing worker for GUER-held active towns. When enabled, the worker places one `ZU23_Gue` near an eligible town, optionally adds one `SearchLight_RUS` during night hours, mans the gun with a GUER rifleman, and removes the dressing when the town flips, deactivates, ages out, or no players/enemies remain nearby.

The important design choice is ownership: this dressing should not become another delegated town-AI system. Keep the registry script-local, create the crew server-local, and delete the crew/static objects in the same worker. That copies the proven self-cleaning shape from `Server_GuerAirDef.sqf` and avoids HC-local cleanup pressure.

## Source Anchors

| Area | Evidence | Use in the runtime PR |
| --- | --- | --- |
| Static ZU-23 classname | `Common/Config/Core/Core_GUE.sqf:149`, `Common/Config/Core_Structures/Structures_GUE.sqf:120`, `Common/Config/Defenses/Defenses_GUE.sqf:22` list `ZU23_Gue`. | Classname is already in-tree, so no external config proof is needed. |
| Searchlight classname | `Common/Config/Core/Core_RU.sqf:157`, `Common/Config/Core_Structures/Structures_RU.sqf:163`, `Common/Config/Defenses/Defenses_RU.sqf:23` list `SearchLight_RUS`. | Optional night dressing can reuse an in-tree static prop. |
| GUER crew class | `Common/Config/Core/Core_GUE.sqf:8`, `Common/Config/Core_Root/Root_GUE.sqf:7-8`, `Server/Config/Config_GUE.sqf:87` bind GUER soldiers to `GUE_Soldier_1`. | Crew should read `WFBE_GUERRESSOLDIER` with `GUE_Soldier_1` as fallback. |
| Create helpers | `Common/Init/Init_Common.sqf:117` compiles `WFBE_CO_FNC_CreateGroup`; line 122 compiles `WFBE_CO_FNC_CreateUnit`. | Use the mission wrappers rather than raw unit creation. |
| Static manning idiom | `Common/Functions/Common_CreateUnitForStaticDefence.sqf:130-178` creates a static gunner, assigns it, orders it in, retries, and disables movement after a successful mount. | Copy the assignment/watchdog idea, but do it inside the new worker to keep ownership local and cleanup simple. |
| Active-town cleanup | `Server/FSM/server_town_ai.sqf:410-433` clears `wfbe_active`, resets `wfbe_town_teams`, deletes server-local town AI, and broadcasts delegated cleanup only for already-delegated town AI. | Dressing eligibility should follow `wfbe_active`; cleanup should happen before or during the next worker tick. |
| Capture cleanup pattern | `Server/FSM/server_town.sqf:537-557` deletes tagged airfield garrison units on capture and broadcasts only because some airfield garrison units can be non-local. | For Lane 241, prefer server-local crew so no new PVF cleanup route is required. |
| Server loop pattern | `Server/Server_GuerAirDef.sqf` keeps `_defenders` script-local, prunes on destroyed hulls, town loss, town inactivity, quiet timeout, and lifetime. | `Server_TownGarrisonDressing.sqf` should use the same registry and prune style. |
| Launch pattern | `Server/Init/Init_Server.sqf:941`, `1012-1013` launch optional server workers after checking feature flags. | Add the future worker behind `WFBE_C_GARRISON_DRESSING > 0`. |

## Proposed Runtime Shape

Add one new worker:

`Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Server_TownGarrisonDressing.sqf`

Launch it from `Server/Init/Init_Server.sqf` only when:

- the machine is the server,
- `WFBE_GameOver` is false,
- `missionNamespace getVariable ["WFBE_C_GARRISON_DRESSING", 0]` is greater than 0.

Append new defaults in `Common/Init/Init_CommonConstants.sqf` only when the runtime PR is ready:

| Constant | Suggested default | Purpose |
| --- | --- | --- |
| `WFBE_C_GARRISON_DRESSING` | `0` | Master enable. Flag-off must leave the mission byte-identical to HEAD behavior. |
| `WFBE_C_GARRISON_DRESSING_INTERVAL` | `45` | Worker cadence. |
| `WFBE_C_GARRISON_DRESSING_RADIUS` | `900` | Player/enemy proximity gate around the town logic. |
| `WFBE_C_GARRISON_DRESSING_LIFETIME` | `900` | Forced recycle age. |
| `WFBE_C_GARRISON_DRESSING_MAX` | `6` | Maximum simultaneous dressed towns. |
| `WFBE_C_GARRISON_DRESSING_SEARCHLIGHT` | `1` | Optional night searchlight companion. |

The worker registry should stay local to the script:

`[_town, _gun, _light, _group, _crew, _spawnTime, _lastContactTime]`

Do not store this registry on `missionNamespace`, do not mark the group `wfbe_persistent`, and do not add the crew group to `wfbe_town_teams`. This keeps the dressing cosmetic and self-cleaning instead of changing town force accounting.

## Eligibility

An eligible town must satisfy all of these:

- town object is not null,
- `sideID` equals `WFBE_C_GUER_ID`,
- `wfbe_active` is true,
- no existing registry entry already owns that town,
- at least one WEST or EAST player or AI enemy is inside the proximity radius,
- global active dressing count is below `WFBE_C_GARRISON_DRESSING_MAX`.

This deliberately excludes inactive rear-area GUER towns. The lane is meant to dress live contested spaces, not create standing AI across the whole map.

## Placement

Use the town logic as the anchor and derive one deterministic offset per town. Recommended shape:

- choose a bearing from the town index/name hash so the position does not jump every tick,
- place the gun on a ring between roughly 40% and 70% of `(_town getVariable ["range", 600])`,
- keep a minimum 120 m distance from the town center so it reads as a perimeter weapon,
- avoid placement directly inside water when a map-specific water check is already available,
- put the optional searchlight 8-12 m beside the gun and point both toward town center or the nearest WEST/EAST contact.

The worker should skip a town when the chosen position is unsafe rather than trying expensive placement searches. This is dressing, not a critical spawn path.

## Creation And Manning

For each eligible town:

1. Create the `ZU23_Gue` server-side and tag it with `wfbe_garrison_dressing = true`.
2. Optionally create `SearchLight_RUS` when searchlights are enabled and the mission time is night.
3. Create a resistance group through `WFBE_CO_FNC_CreateGroup` with a distinct source string such as `town-garrison-dressing`.
4. Create one crew unit through `WFBE_CO_FNC_CreateUnit`, using `WFBE_GUERRESSOLDIER` or `GUE_Soldier_1`.
5. Assign the crew as gunner, order it in, then retry once after a short sleep if `gunner _gun` is still not the crew.
6. Disable crew movement only after the unit is actually in the gun.

This mirrors the static-defense manning sequence without borrowing the HC-bridged `defense-gunners` groups. The crew exists only to operate this cosmetic static and should be deleted by the same worker that created it.

## Cleanup

Prune an entry when any of these becomes true:

- gun is null or dead,
- town is null,
- town side is no longer GUER,
- `wfbe_active` is false,
- no WEST/EAST player or AI contact has been near the town for the configured quiet window,
- entry lifetime exceeds `WFBE_C_GARRISON_DRESSING_LIFETIME`,
- game over.

Deletion order:

1. If the gun has player crew, drop the registry entry but do not delete the player or occupied gun.
2. Delete non-player crew units in the group.
3. Delete the group.
4. Delete the searchlight when local and alive.
5. Delete the empty gun when local and alive.

Player safety should copy the `Server_GuerAirDef.sqf` rule: never delete a vehicle or crew path that currently contains a player.

## Non-Goals For Lane 241

- No source runtime implementation in this PR.
- No edit to `Init_Server.sqf`.
- No edit to `Init_CommonConstants.sqf`.
- No new PVF cleanup handler.
- No HC delegation or group locality transfer work.
- No LoadoutManager run, because no mission mirror files are changed.
- No package artifact and no deployment action.

## Validation Plan For The Runtime PR

- Run the SQF lint gate from `AGENTS.md` with the selected A2/OA trap checks.
- Verify bracket deltas for `Server_TownGarrisonDressing.sqf`, `Init_Server.sqf`, and `Init_CommonConstants.sqf`.
- Prove flag-off inertness by showing the worker is not launched when `WFBE_C_GARRISON_DRESSING` is 0.
- Run LoadoutManager after runtime SQF edits and restore TK/ZG `version.sqf.template` if it drifts.
- Grep the diff for A3-only commands, Boolean `==`/`!=`, group two-argument `getVariable`, and `missionNamespace setVariable` with a public third argument.
- Runtime smoke: enable the flag on a local/dedicated test, capture a GUER town, confirm one gun appears, flips/deactivation remove it, a player in the gun is not deleted, and night searchlights appear only when enabled.

## This PR Verification

- Source read only except for this design document.
- No SQF, SQM, HPP, EXT, or generated mission files were changed.
- No mirror generation was needed.
- Base branch: `origin/claude/build84-cmdcon36@4910fc3f5fb5657feee6b554d700155f3a827092`.
