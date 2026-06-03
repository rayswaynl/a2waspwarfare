# Supply Mission Architecture

Page ownership: this page owns the supply-mission flow, cooldown/JIP pattern and state-owner map. [Deep-review findings](Deep-Review-Findings) DR-18 owns the exact cooldown casing defect evidence; [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook) owns the implementation-ready patch shape.

Supply missions are one of the most cross-cutting systems in the mission. They touch client actions, skill roles, town cooldown state, server tracking loops, side supply, commander/team funds in PR #1, player rewards, public variables and buy-menu affordances.

Authority summary: the live path is still client-authored at start and partly client-rewarded at completion. Client-side checks are affordance gates; the server tracks return-to-base and writes side supply, but today it accepts client-stamped `SupplyFromTown` / `SupplyAmount` state and the client completion message path handles personal cash/score reward presentation.

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
10. Server `supplyMissionStarted.sqf` starts a loop against the vehicle object, checking for command center proximity within 80m with a narrowed `Base_WarfareBUAVterminal` object scan.
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
| `WFBE_SE_PLAYERLIST` | server | Used to resolve real player near/inside supply vehicle. Source Chernarus and maintained Vanilla Takistan now fix UID row replacement indexing, but disconnect pruning/stale object cleanup remains open. |

## Fragility Points

- `supplyMissionStart.sqf` on master uses duplicated hardcoded supply-truck classname arrays.
- Start is client-authored: the server start handler should revalidate sender ownership, vehicle class, source town, cooldown and duplicate-start state before accepting future hardened starts.
- The client asks for cooldown and immediately reads local town state; timing/race behavior depends on the server response arriving quickly enough.
- Cooldown variable casing is a confirmed DR-18 defect: town init seeds `lastSupplyMissionRun`, while server supply code reads/writes `LastSupplyMissionRun`.
- `supplyMissionStarted.sqf` loops until the vehicle dies; it should avoid creating duplicate tracking loops for the same loaded vehicle.
- Completion trusts object variables on the supply vehicle, so any feature that reuses those vars must clear them reliably.
- Completion reward is split: the server mutates side supply, while the client completion message path grants personal funds locally and requests score reward.
- Player resolution depends on `WFBE_SE_PLAYERLIST` and proximity/driver checks; stale rows can survive disconnects until the lifecycle cleanup lane is patched.

Claude DR-39 split the Perf/JIP status cleanly:

| Item | Status | Development note |
| --- | --- | --- |
| `supplyMissionActive.sqf` | Dead twin. It is compiled as `WFBE_SE_FNC_SupplyMissionActive`, but the live path is `supplyMissionStarted.sqf`, which self-registers the `WFBE_Client_PV_SupplyMissionStarted` handler. The dead twin still carries older broad-scan logic. | Remove the dead compile/function or keep it explicitly marked as retired; do not patch it as the live implementation. |
| Command-center detection loop | Source and maintained Vanilla Takistan are patched in the live handler. The live loop still sleeps 3 seconds, but now uses `nearestObjects [pos, ["Base_WarfareBUAVterminal"], 80]` for command-center detection. | Smoke delivery at command centers and no-completion near unrelated objects; authority cleanup remains separate. |
| Cooldown JIP behavior | Pull-based and useful, but casing/race-sensitive. Clients ask `WFBE_Client_PV_IsSupplyMissionActiveInTown`; server computes from `LastSupplyMissionRun`; clients store the answer locally. | Keep the server accept/reject decision authoritative. The response is broadcast to all clients today, not targeted to the requester, and the starter reads a local cache immediately after requesting it. |
| Player-object list | Partial source and maintained Vanilla Takistan patch. `playerObjectsList.sqf` now tracks the loop index correctly, but the server does not prune rows on disconnect. | Add disconnect cleanup and smoke same-UID reconnect plus supply completion lookup. |

## PR #1 Changes

PR #1 improves the system by centralizing supply vehicle types, adding `SupplyByHeli`, changing labels to `LOAD SUPPLIES`, adding air rewards/cash runs/interdiction, and highlighting supply helicopters in buy menus. It is additive: it extends the same client-started, server-completed object-var flow rather than replacing the trust model.

Current `origin/feat/supply-helicopter` has already addressed the older handler-stacking review risk with a `wfbe_supply_killed_eh_set` guard before adding the interdiction `Killed` handler. Keep that guarded shape and smoke repeated load/deliver/destroy cycles before merge.

## Master vs PR #1 Authority Matrix

| Area | `master` | PR #1 / `feat/supply-helicopter` |
| --- | --- | --- |
| Vehicle type | Truck-only hardcoded class checks. | Centralized `WFBE_C_SUPPLY_TRUCK_TYPES`, `WFBE_C_SUPPLY_HELI_TYPES` and `WFBE_C_SUPPLY_VEHICLE_TYPES`. |
| Start authority | Client chooses eligible vehicle, stamps `SupplyFromTown` / `SupplyAmount`, then notifies server. | Same trust model, plus `SupplyByHeli` and heli class/upgrade gates. |
| Completion authority | Server loop verifies command-center proximity, then trusts the vehicle object vars. | Same server-completion pattern; reward path branches for truck, heli and cash run. |
| Reward | Side supply on completion; player message/score path follows completion broadcast. | Heli rewards add the air bonus; heli deliveries at Supply upgrade 3 become cash runs that pay commander team funds when a commander exists. |
| Cooldown | Town object cooldown uses `LastSupplyMissionRun`, with source casing mismatch against seeded `lastSupplyMissionRun`. | Same cooldown foundation; PR does not redesign cooldown ownership. |
| AI logistics | Broken/deferred `UpdateSupplyTruck` / missing `supplytruck.fsm`. | Still deferred; PR covers player-run vehicles, not autonomous AI-flown supply helicopters. |
| Known PR risk | Not applicable. | Current branch guards the interdiction `Killed` handler; repeated load/deliver/destroy behavior still needs Arma smoke before merge. |

## Future Design Direction

- Keep supply-capable vehicle classes in one constant source of truth.
- Add an explicit loaded/unloaded state variable to prevent duplicate tracking loops; keep or deliberately extend the PR's `Killed` handler guard.
- Split client affordance, server validation and reward calculation into documented helper functions.
- Keep the pull-based cooldown request/response pattern for JIP-visible state, but target responses where possible.
- Command-center scan narrowing is patched in source and maintained Vanilla Takistan; keep Arma smoke evidence on [Supply mission scan narrowing](Supply-Mission-Scan-Narrowing) and [Testing workflow](Testing-Debugging-And-Release-Workflow#propagated-fix-smoke-pack).
- Redesign autonomous AI logistics separately from the broken `AI_UpdateSupplyTruck` / missing `supplytruck.fsm` path.

## Continue Reading

Previous: [Economy/towns/supply](Economy-Towns-And-Supply) | Next: [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
