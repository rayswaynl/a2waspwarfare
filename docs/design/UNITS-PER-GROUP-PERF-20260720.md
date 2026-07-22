# Units per group: same-mass consolidation proposal

## Decision

Keep the selected town-defense force unchanged and reduce its group count by packing the
selected infantry classnames into 9-10 person groups. Do not make every small spawner add
new AI merely to reach ten people: that grows total simulation load without reducing the
number of groups it owns.

The implementation changes the two town-garrison planners and their live knobs:

| Path | Before | After | Force-mass effect |
| --- | --- | --- | --- |
| WEST/EAST town garrison | target `5`, whole rosters could not cross the 10-man cap | target `9` | unchanged |
| GUER defender garrison | target `11`, cap `12` | target `10`, cap `12` retained | unchanged |
| Zargabad garrison | target `5` | target `9` (ZG-scoped override) | unchanged |

The planner fuses whole infantry rosters into one flat classname list per group. Entries
accumulate until the running group reaches the merge target; a roster that would push the
running group past the size cap (10 shared, `WFBE_C_TOWNS_MERGE_CAP_DEFENDER` for
defenders) starts the next group instead. An already-oversized source roster stays
atomic. Because `CreateTeam` spawns every classname of a passed list into the single
group it is given, the town fields the identical selected units in fewer server
group-brains. Vehicle rosters are never merged, preserving the `CreateTeam`
addVehicle/crew path.

Merged on `master` via update-wave PR #1196 (merge `b34559739b`). That fold carries the
owner/Fable-accepted flat-pack variant and supersedes the earlier packed-segments draft
PR #1197 (`2c28bbc`), which split rosters at the cap to hold every group at 9-10; the
flat-pack keeps rosters whole and accepts a smaller tail group instead.

## Current local baseline

The available `ArmA2OA.RPT` is a local Zargabad client RPT, not an HC/server telemetry
stream. Its late samples show:

| Metric | Observed range |
| --- | --- |
| `allGroups` | 91-117 |
| AI | 265-302 |
| client FPS | 19-45 |
| ZG AICOM init merge target | 9 |
| server per-side/HC group count | absent |

This is sufficient to prove active group pressure, but it is not a substitute for the
required next server/HC soak. That soak must capture `HCSTAT`, `AICOMSTAT`, per-side
group diagnostics and server FPS before any further AI-mass change.

## Spawner inventory and scope decision

| Spawner | Current source of roster/group | This change | Why |
| --- | --- | --- | --- |
| Town garrison | `Server_GetTownGroups.sqf` | packed | Same selected force, fewer groups. |
| GUER town defender | `Server_GetTownGroupsDefender.sqf` | packed | Same selected force, fewer groups. |
| Capture mop-up | `server_town.sqf` resolves `WFBE_*_GROUPS_Squad_*` | inherits | It consumes the shared group roster. |
| Static-defense gunner pool | `Server_OperateTownDefensesUnits.sqf` / `Common_CreateUnitForStaticDefence.sqf` | unchanged | Existing shared pool is already a 12-cap pattern; separate groups are intentional per static. |
| AICOM founded teams | `AI_Commander_Teams.sqf` | measured hold | The existing `FOUND_SIZE=10` is currently clamped to max 8. Lifting it increases AI mass unless the population curve and bank-valve targets are lowered together. |
| Side patrols | `Common_RunSidePatrol.sqf` + `Core_Root/Root_*.sqf` | measured hold | Each patrol is already one group; padding its template adds AI without collapsing another group. |
| GUER wildcard G1/G2/G5 | `AI_Commander_Wildcard_GUER.sqf` | measured hold | The hard-coded crews/foot cells are single groups. Enlarging them is mass growth, not consolidation. |
| GUER director / A-Life | `Server_GuerDirector.sqf`, `Server_GuerAirDef.sqf` | measured hold | Vehicle crews and sorties have role/seat constraints; they need a per-event cap and RPT baseline. |

The direct request to make every template 8-10 men conflicts with the same-army-mass
requirement for one-group spawners. The safe next iteration is an A/B soak: raise the
AICOM founding cap to 10 only alongside a curve that reduces founded-team targets by
about 20%, then compare total AI, groups per side, capture rate and server FPS.

## Validation

`Tools/Lint/test_town_group_packing.py` is a regression contract for both planners. It
pins the flat-pack merge loop markers, the shared 10-man cap, the defender cap/target
fallback chain, the merged constants (global 9, defender 10, defender cap 12, ZG
override 9), CH=TK=ZG mirror parity, and a Python model of the loop proving
classname-multiset preservation, cap-bounded group sizes and group-count reduction.

Required before merge/review:

1. Run `LoadoutManager` from Chernarus source to regenerate maintained mirrors.
2. Run targeted SQF lint and bracket deltas on generated changes.
3. Run a server/HC soak with the telemetry fields above and compare against this baseline.
