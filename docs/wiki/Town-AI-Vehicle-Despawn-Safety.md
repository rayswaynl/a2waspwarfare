# Town AI Vehicle Despawn Safety

Implementation playbook for [Deep-review findings](Deep-Review-Findings) DR-45, the confirmed town-AI vehicle cleanup bug in the Chernarus source mission.

Scope: `Missions/[55-2hc]warfarev2_073v48co.chernarus`. Apply gameplay patches there first, then propagate generated missions with `Tools/LoadoutManager`.

## Status

| Field | Value |
| --- | --- |
| Finding | Confirmed bug; formal record is [Deep-review findings](Deep-Review-Findings) DR-45 |
| Backlog id | `town-ai-vehicle-despawn-safety` |
| Primary file | `Server/FSM/server_town_ai.sqf` |
| Risk | A town-AI vehicle can be deleted while a player is aboard if that player is not the group leader. |
| Patch type | Small server-side cleanup guard |

## Source Chain

| File | Evidence |
| --- | --- |
| `Common/Functions/Common_CreateTownUnits.sqf` | Town teams are created from templates, vehicles returned by `WFBE_CO_FNC_CreateTeam` are appended to `_town_vehicles`, each server-local vehicle starts `WFBE_SE_FNC_HandleEmptyVehicle`, and the function returns `[_town_teams, _town_vehicles]`. |
| `Server/FSM/server_town_ai.sqf` | On activation, server-created town vehicles are appended to the town variable `wfbe_active_vehicles`; on inactivity, the same variable is iterated for cleanup. |
| `Server/FSM/server_town_ai.sqf:191-223` | Inactivity cleanup deletes town team units/groups, then town vehicles, then clears `wfbe_active_vehicles`. |
| `Server/FSM/server_town_ai.sqf:211-216` | Vehicle deletion checks `alive _x` and `!(isPlayer leader group _x)`, but does not inspect vehicle crew/cargo/turret occupants. |
| `Server/Functions/Server_HandleEmptyVehicle.sqf` | Separate empty-vehicle cleanup loop resets its timer while `{alive _x} count crew _vehicle > 0`; this is not the source of the town inactivity bug. |
| `Server/Functions/Server_OperateTownDefensesUnits.sqf` | Static defense removal has its own gunner/operator handling and should be validated separately from town vehicle despawn. |

## Failure Condition

The unsafe delete path exists when all of these are true:

| Condition | Source-backed reason |
| --- | --- |
| Town becomes inactive | `time - (_town getVariable "wfbe_inactivity") > WFBE_C_TOWNS_UNITS_INACTIVE`. |
| Vehicle is still tracked | The vehicle remains in `_town getVariable 'wfbe_active_vehicles'`. |
| Vehicle is alive | Cleanup only enters the delete branch under `if (alive _x)`. |
| Player is aboard but not leader | Existing guard only checks `isPlayer leader group _x`. |
| Vehicle has a player in crew/cargo/turret | Existing cleanup does not check `crew _vehicle`, so any non-leader player occupant can be missed. |

This is a player-experience correctness bug, not a generic empty-vehicle timeout bug. `Server_HandleEmptyVehicle.sqf:26-30` is already crew-aware; the unsafe delete lives in the town inactivity branch and is tracked as DR-45.

## Safe Patch Shape

Use an explicit vehicle local variable so the nested `crew` count does not reuse the outer `_x` accidentally:

```sqf
//--- Teams vehicles.
{
	private ["_vehicle", "_hasPlayerCrew"];
	_vehicle = _x;
	if (alive _vehicle) then {
		_hasPlayerCrew = ({isPlayer _x} count crew _vehicle) > 0;
		if (!_hasPlayerCrew && !(isPlayer leader group _vehicle)) then {deleteVehicle _vehicle};
	};
} forEach (_town getVariable 'wfbe_active_vehicles');
```

The `leader group` guard is behavior-preserving. If a future code owner wants the simpler rule, the target behavior can become:

```sqf
if (({isPlayer _x} count crew _vehicle) == 0) then {deleteVehicle _vehicle};
```

That simpler version is easier to reason about, but it is a behavioral change because it removes the current leader-based exception. Prefer the behavior-preserving guard first unless testing proves the exception is redundant.

## Edge Cases To Check

| Edge case | Expected result |
| --- | --- |
| Empty AI-only town vehicle | Deleted during town inactivity cleanup. |
| AI-crewed town vehicle with no player aboard | Deleted during town inactivity cleanup. |
| Player driver | Vehicle survives cleanup. |
| Player gunner/commander/turret occupant | Vehicle survives cleanup. |
| Player cargo/passenger | Vehicle survives cleanup. |
| Player group leader near but not aboard | Existing leader guard may still preserve old behavior; decide whether this is desired before simplifying. |
| Static defense gunner | Unchanged; static defenses are handled by `Server_OperateTownDefensesUnits.sqf`. |

## Validation

| Gate | Check |
| --- | --- |
| Static source check | Confirm `server_town_ai.sqf` no longer deletes `wfbe_active_vehicles` without a `crew` player check. |
| In-game smoke | Spawn/wake a town with vehicle templates, board a town-AI vehicle as cargo/gunner, force or wait for town inactivity, and verify the vehicle is not deleted while occupied. |
| Regression smoke | Let the same town despawn with empty AI-only vehicles and verify cleanup still removes them. |
| RPT | No scheduler or undefined-variable errors around town AI despawn. |
| Generated missions | After a gameplay patch, run `dotnet run` from `Tools/LoadoutManager` in a correctly named `a2waspwarfare` checkout; missing `7za` is packaging-only unless deployment packaging is required. |

## Implementation Notes For Agents

- Use Bohemia Interactive Arma 2 OA scripting semantics; do not assume Arma 3 commands or event behavior.
- Use `-LiteralPath` in PowerShell when reading or editing `[55-2hc]` paths.
- Keep gameplay changes in the Chernarus source mission first.
- Do not touch `Missions_Vanilla` by hand unless the LoadoutManager path is explicitly unavailable and the user approves manual propagation.
- If adding diagnostics, keep detailed logs behind `WF_Debug`; a small always-on `WARNING` is only justified if testers need to confirm a state transition in RPT.

## Related Pages

- [AI, headless and performance](AI-Headless-And-Performance)
- [Headless delegation and failover](Headless-Delegation-And-Failover-Playbook)
- [Feature status register](Feature-Status-Register)
- [Hardening implementation roadmap](Hardening-Implementation-Roadmap)
- [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl)

## Continue Reading

Previous: [HC delegation/failover](Headless-Delegation-And-Failover-Playbook) | Next: [Client UI/HUD/menus](Client-UI-HUD-And-Menus)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
