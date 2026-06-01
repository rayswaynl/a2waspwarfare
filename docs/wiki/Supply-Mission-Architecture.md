# Supply Mission Architecture

Supply missions are one of the most cross-cutting systems in the mission. They touch client actions, skill roles, town cooldown state, server tracking loops, side supply, commander/team funds in PR #1, player rewards, public variables and buy-menu affordances.

## Master Branch Flow

1. SpecOps receives the supply action in `Client/Module/Skill/Skill_Apply.sqf` when role/module conditions are met.
2. The action runs `Client/Module/supplyMission/supplyMissionStart.sqf`.
3. Client finds the closest friendly town with `GetClosestFriendlyLocation`.
4. Client asks server whether that town is cooling down by sending `WFBE_Client_PV_IsSupplyMissionActiveInTown`.
5. Server `isSupplyMissionActiveInTown.sqf` checks `LastSupplyMissionRun` against `WFBE_CO_VAR_SupplyMissionRegenInterval` and broadcasts `WFBE_Server_PV_IsSupplyMissionActiveInTown`.
6. Client stores cooldown on the town as `supplyMissionCoolDownEnabled`.
7. If allowed, client validates cursor target against hardcoded supply-truck classes and distance < 50m.
8. Client writes object variables on the vehicle: `SupplyFromTown` and `SupplyAmount`.
9. Client broadcasts `WFBE_Client_PV_SupplyMissionStarted`.
10. Server `supplyMissionStarted.sqf` starts a loop against the vehicle object, checking for command center proximity within 80m.
11. On match, server broadcasts `WFBE_Server_PV_SupplyMissionCompleted`.
12. Server `supplyMissionCompleted.sqf` reads the vehicle object variables, calls `ChangeSideSupply`, clears the vehicle vars and broadcasts completion message.
13. Client `supplyMissionCompletedMessage.sqf` displays the message and requests score reward.

## Key State

| State | Owner | Notes |
| --- | --- | --- |
| `LastSupplyMissionRun` | town object/server | Cooldown anchor. |
| `supplyMissionCoolDownEnabled` | town object/client | Client-side affordance for map/action feedback. |
| `SupplyFromTown` | supply vehicle object | Source town object. |
| `SupplyAmount` | supply vehicle object | Payload amount. Cleared on completion. |
| `WFBE_SE_PLAYERLIST` | server | Used to resolve real player near/inside supply vehicle. |

## Fragility Points

- `supplyMissionStart.sqf` on master uses duplicated hardcoded supply-truck classname arrays.
- The client asks for cooldown and immediately reads local town state; timing/race behavior depends on the server response arriving quickly enough.
- `supplyMissionStarted.sqf` loops until the vehicle dies; it should avoid creating duplicate tracking loops for the same loaded vehicle.
- Completion trusts object variables on the supply vehicle, so any feature that reuses those vars must clear them reliably.
- Player resolution depends on `WFBE_SE_PLAYERLIST` and proximity/driver checks.

## PR #1 Changes

PR #1 improves the system by centralizing supply vehicle types, adding helicopter tiers, adding `SupplyByHeli`, changing labels to `LOAD SUPPLIES`, adding air rewards/cash runs/interdiction, and highlighting supply helicopters in buy menus.

Review risk from the independent doc reviewer: the PR adds a `Killed` event handler when a supply mission starts. Make sure repeated reloads of the same vehicle cannot stack duplicate handlers or duplicate interdiction rewards.

## Future Design Direction

- Move all supply-capable vehicle classes to one constant source of truth.
- Add an explicit loaded/unloaded state variable to prevent duplicate loops and duplicate event handlers.
- Split client affordance, server validation and reward calculation into documented helper functions.
- Redesign autonomous AI logistics separately from the broken `AI_UpdateSupplyTruck` / missing `supplytruck.fsm` path.

## Continue Reading

Previous: [Economy/towns/supply](Economy-Towns-And-Supply) | Next: [Supply heli PR #1](Current-Work-Supply-Helicopters-PR1)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
