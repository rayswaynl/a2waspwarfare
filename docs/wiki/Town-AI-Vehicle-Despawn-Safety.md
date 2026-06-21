# Town AI Vehicle Despawn Safety

Implementation playbook for [Deep-review findings](Deep-Review-Findings) DR-45, the confirmed town-AI vehicle cleanup bug in the maintained source missions.

Scope: source Chernarus `Missions/[55-2hc]warfarev2_073v48co.chernarus` plus maintained Vanilla `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan`. Apply gameplay patches to source Chernarus first, then propagate generated missions with `Tools/LoadoutManager` or a deliberate maintained-Vanilla port.

## Status

| Field | Value |
| --- | --- |
| Finding | Confirmed bug; formal record is [Deep-review findings](Deep-Review-Findings) DR-45 |
| Backlog id | `town-ai-vehicle-despawn-safety` |
| Primary file | `Server/FSM/server_town_ai.sqf` |
| Risk | A town-AI vehicle can be deleted while a player is aboard if that player is not the group leader. |
| Patch type | Small server-side cleanup guard |

## Current Branch Matrix

Branch route `ai-runtime-hc-loop-branch-scope-route` rechecked the maintained roots on 2026-06-13 after stable `origin/master` advanced to `cf2a6d6a`, Miksuu to `b8389e74` and release to `a96fdda2`.

| Branch / root | Evidence | Status |
| --- | --- | --- |
| Docs checkout `b9e80da0` Chernarus and maintained Vanilla | `server_town_ai.sqf` initializes `wfbe_active_vehicles` at `:30`, appends server-created/delegated vehicles at `:161,:179`, deletes tracked inactive vehicles with only `!(isPlayer leader group _x)` at `:214`, clears at `:219`, and does not check player `crew`. | Patch-ready DR-45 still present in both maintained roots. |
| Stable `origin/master` `cf2a6d6a` Chernarus and maintained Vanilla | Same tracked-vehicle cleanup shape with line drift: initialize `:28`, append `:152,:171`, delete at `:207`, clear at `:213`. Stable no longer contains the older `Server_CleanupExpiredTownDefenseAssets.sqf` helper named in `89ae9dad`-era docs. | Current stable remains source-unpatched for DR-45; persistent-defense helper evidence is historical. |
| Miksuu upstream `b8389e74` Chernarus and maintained Vanilla | Same tracked-vehicle cleanup shape with line drift: initialize `:28`, append `:140,:159`, delete at `:195`, clear at `:201`; no checked `Server_CleanupExpiredTownDefenseAssets.sqf` path. | Upstream still needs the tracked-vehicle occupancy guard. |
| `origin/perf/quick-wins` `0076040f` Chernarus and maintained Vanilla | Same tracked-vehicle cleanup shape with line drift: initialize `:30`, append `:166,:184`, delete at `:219`, clear at `:224`; no checked persistent-defense helper. | Perf branch does not rescue this safety bug. |
| Release `origin/release/2026-06-feature-bundle` `a96fdda2` Chernarus and maintained Vanilla | Same tracked-vehicle cleanup shape with line drift: initialize `:28`, append `:145,:164`, delete at `:200`, clear at `:206`; no checked persistent-defense helper. | Release still needs the player-occupancy guard before release-ready safety wording. |
| `origin/feat/ai-commander` `c20ce153` | Not a town-AI vehicle safety fix in this pass; only checked here for AI supply-truck branch split. | Do not route DR-45 closure through the AI commander branch without a fresh source audit. |

## Source Chain

| File | Evidence |
| --- | --- |
| `Common/Functions/Common_CreateTownUnits.sqf` | Town teams are created from templates, vehicles returned by `WFBE_CO_FNC_CreateTeam` are appended to `_town_vehicles`, each server-local vehicle starts `WFBE_SE_FNC_HandleEmptyVehicle`, and the function returns `[_town_teams, _town_vehicles]`. |
| `Server/FSM/server_town_ai.sqf` | On activation, server-created town vehicles are appended to the town variable `wfbe_active_vehicles`; on inactivity, the same variable is iterated for cleanup. |
| `Server/FSM/server_town_ai.sqf:205-219` on docs checkout `b9e80da0`; stable line drift `:198-213` | Inactivity cleanup deletes town team units/groups, then town vehicles, then clears `wfbe_active_vehicles`. |
| `Server/FSM/server_town_ai.sqf:214` on docs checkout `b9e80da0`; stable line drift `:207` | Vehicle deletion checks `alive _x` and `!(isPlayer leader group _x)`, but does not inspect vehicle crew/cargo/turret occupants. |
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

## Branch-Historical Adjacent Work

Earlier `89ae9dad`-era docs recorded a town-defense diagnostics / captured-defender persistence batch with `Server_CleanupExpiredTownDefenseAssets.sqf`. A fresh 2026-06-13 ref scan found no `Server_CleanupExpiredTownDefenseAssets.sqf` path in docs checkout `b9e80da0`, stable `origin/master` `cf2a6d6a`, Miksuu `b8389e74`, `origin/perf/quick-wins` `0076040f`, release `a96fdda2` or `origin/feat/ai-commander` `c20ce153`.

Keep that helper evidence as historical/branch-specific until a target branch actually contains the file again. It is not a substitute for this DR-45 fix:

- captured-defender persistence, when present on a branch, is a separate cleanup surface that also needs player-occupancy review;
- DR-45 guards inactivity-time deletion of an already tracked `wfbe_active_vehicles` entry with a player aboard;
- both cleanup surfaces should be smoke-tested together if a future branch reintroduces the persistence helper.

### Historical DR-48 Capture-Persistence Cleanup

DR-48 remains useful historical evidence for `89ae9dad`-era branches, even though the helper is absent from the 2026-06-13 checked heads above:

| Branch / file | Evidence | Why it matters |
| --- | --- | --- |
| `89ae9dad` Chernarus and maintained Vanilla | `Server/Init/Init_Server.sqf:55` compiles `WFBE_SE_FNC_CleanupExpiredTownDefenseAssets`; `server_town_ai.sqf:61` calls it per town; `server_town.sqf:238,241,260,324` tracks captured defender persistence through `wfbe_persistent_town_defense_assets`. | Any branch carrying this helper has a second cleanup surface beyond the tracked inactive vehicle loop. |
| `89ae9dad` `Server_CleanupExpiredTownDefenseAssets.sqf:58,62-63` in both maintained roots | The GROUP path deletes every unit in the group at `:58`; the OBJECT path checks only `isPlayer _asset` and `isPlayer leader group _asset` before `deleteVehicle _asset` at `:62-63`. | If this helper is reintroduced, audit player `crew` / cargo / turret occupancy for object assets and player units in group assets before release wording. |

## Safe Patch Shape

Use an explicit vehicle local variable so the nested `crew` count does not reuse the outer `_x` accidentally:

```sqf
//--- Teams vehicles.
{
	private ["_vehicle", "_hasPlayerCrew"];
	_vehicle = _x;
	if (alive _vehicle && {local _vehicle}) then {
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
- [AI runtime and HC loop map](AI-Runtime-HC-Loop-Map)
- [Headless delegation and failover](Headless-Delegation-And-Failover-Playbook)
- [Miksuu upstream commit intel](Upstream-Miksuu-Commit-Intel)
- [Feature status register](Feature-Status-Register)
- [Hardening implementation roadmap](Hardening-Implementation-Roadmap)
- [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl)

## Continue Reading

Previous: [HC delegation/failover](Headless-Delegation-And-Failover-Playbook) | Next: [Client UI/HUD/menus](Client-UI-HUD-And-Menus)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
