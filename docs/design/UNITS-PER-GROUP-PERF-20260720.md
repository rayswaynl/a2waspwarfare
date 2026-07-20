# Units per group: same-mass consolidation proposal

## Decision

Keep the selected town-defense force unchanged and reduce its group count by packing the
selected infantry classnames into 9-10 person groups. Do not make every small spawner add
new AI merely to reach ten people: that grows total simulation load without reducing the
number of groups it owns.

The implementation changes the two town-garrison planners and their live knobs:

| Path | Before | After | Force-mass effect |
| --- | --- | --- | --- |
| WEST/EAST town garrison | target `5`, whole rosters could not cross the 10-man cap | target `9`, entries pack across roster boundaries | unchanged |
| GUER defender garrison | target `11`, cap `12` | target `10`, cap `12` retained | unchanged |
| Zargabad garrison | target `9` | target `10` | unchanged |

The prior planner treated a selected roster as indivisible. With normal six-man rosters,
`6 + 6` exceeded its cap, so a target change from 5 to 9 did not consolidate anything.
The new packing pass preserves classname order and forms target-sized groups: three
six-man selections become `9 + 9`, not `6 + 6 + 6`.

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
was run red against the old whole-roster behavior, then green after the packing change.

Required before merge/review:

1. Run `LoadoutManager` from Chernarus source to regenerate maintained mirrors.
2. Run targeted SQF lint and bracket deltas on generated changes.
3. Run a server/HC soak with the telemetry fields above and compare against this baseline.
