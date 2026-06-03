# Supply Mission Architecture

Page ownership: this page owns the supply-mission flow, cooldown/JIP pattern and state-owner map. [Deep-review findings](Deep-Review-Findings) DR-18 owns the exact cooldown casing defect evidence; [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook) owns the implementation-ready patch shape.

Supply missions are one of the most cross-cutting systems in the mission. They touch client actions, skill roles, town cooldown state, server tracking loops, side supply, commander/team funds in PR #1, player rewards, public variables and buy-menu affordances.

> **✅ UPDATE 2026-06-03 (Claude):** parts of this page are superseded by code. Now live (release `4cf443fe` + earlier): the command-center scan is **class-filtered + heli-aware** (`supplyMissionStarted.sqf:56`, heli 400 m / truck 80 m, + a heli 2D-distance gate at `:48-54`); cooldown casing **fixed** (DR-18 — `Init_Town.sqf` seeds `LastSupplyMissionRun`); dead twin `supplyMissionActive.sqf` **removed**; `SupplyByHeli` is stamped at start and now **cleared on completion** (XR3). The "unpatched / still broad / dead-twin-present / casing-mismatch" notes below are historical. Also live but undocumented: `supplyMissionTimerForTown.sqf` pushes a cooldown-expiry broadcast (in addition to the pull-based query).

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
10. Server `supplyMissionStarted.sqf` starts a loop against the vehicle object, checking for command-center proximity with a **class-filtered** scan (`nearestObjects [..., ["Base_WarfareBUAVterminal"], heli ? 400 : 80]`, `:56`) plus a heli horizontal-2D gate (`:48-54`), keeping the `isKindOf` guard.
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
- Cooldown variable casing was a confirmed DR-18 defect (town init seeded `lastSupplyMissionRun` while server code reads/writes `LastSupplyMissionRun`). **✅ FIXED 2026-06-03 (release `4cf443fe`)** — `Init_Town.sqf` now seeds `LastSupplyMissionRun`.
- `supplyMissionStarted.sqf` loops until the vehicle dies; it should avoid creating duplicate tracking loops for the same loaded vehicle.
- Completion trusts object variables on the supply vehicle, so any feature that reuses those vars must clear them reliably.
- Player resolution depends on `WFBE_SE_PLAYERLIST` and proximity/driver checks.

Claude DR-39 split the Perf/JIP status cleanly:

| Item | Status | Development note |
| --- | --- | --- |
| `supplyMissionActive.sqf` | ✅ Removed 2026-06-03 (release `4cf443fe`). Was a dead twin compiled as `WFBE_SE_FNC_SupplyMissionActive`; live path is `supplyMissionStarted.sqf`. | File deleted + compile line removed from `Init_Server.sqf`. |
| Command-center detection loop | ✅ Narrowed (shipped). The live loop is class-filtered (`nearestObjects [pos, ["Base_WarfareBUAVterminal"], heli ? 400 : 80]`, `:56`) with the `isKindOf` guard + a heli 2D gate (`:48-54`). | Smoke delivery at command centers and no-completion near unrelated objects; authority cleanup remains separate. |
| Cooldown JIP behavior | Pull-based and good. Clients ask `WFBE_Client_PV_IsSupplyMissionActiveInTown`; server computes from `LastSupplyMissionRun`; clients store the answer locally. | This is a positive pattern for JIP state: query current state instead of relying on replayed events. The response is broadcast to all clients today, not targeted to the requester. |

## PR #1 Changes

PR #1 improves the system by centralizing supply vehicle types, adding helicopter tiers, adding `SupplyByHeli`, changing labels to `LOAD SUPPLIES`, adding air rewards/cash runs/interdiction, and highlighting supply helicopters in buy menus. It is additive: it extends the same client-started, server-completed object-var flow rather than replacing the trust model.

Review risk from the independent doc reviewer: the PR adds a `Killed` event handler when a supply mission starts. Make sure repeated reloads of the same vehicle cannot stack duplicate handlers or duplicate interdiction rewards.

## Master vs PR #1 Authority Matrix

| Area | `master` | PR #1 / `feat/supply-helicopter` |
| --- | --- | --- |
| Vehicle type | Truck-only hardcoded class checks. | Centralized supply truck + light/heavy supply helicopter constants. |
| Start authority | Client chooses eligible vehicle, stamps `SupplyFromTown` / `SupplyAmount`, then notifies server. | Same trust model, plus `SupplyByHeli` and heli class/upgrade gates. |
| Completion authority | Server loop verifies command-center proximity, then trusts the vehicle object vars. | Same server-completion pattern; reward path branches for truck, heli and cash run. |
| Reward | Side supply on completion; player message/score path follows completion broadcast. | Heli rewards can add air bonus, interdiction reward and heavy-heli cash-run funds to commander team funds when a commander exists. |
| Cooldown | Town object cooldown uses `LastSupplyMissionRun`, with source casing mismatch against seeded `lastSupplyMissionRun`. | Same cooldown foundation; PR does not redesign cooldown ownership. |
| AI logistics | Broken/deferred `UpdateSupplyTruck` / missing `supplytruck.fsm`. | Still deferred; PR covers player-run vehicles, not autonomous AI-flown supply helicopters. |
| Known PR defect | Not applicable. | Reused vehicles can accumulate `Killed` handlers because each mission start adds another EH without a guard/removal. |

## Future Design Direction

- Move all supply-capable vehicle classes to one constant source of truth.
- Add an explicit loaded/unloaded state variable to prevent duplicate loops and duplicate event handlers.
- Split client affordance, server validation and reward calculation into documented helper functions.
- Keep the pull-based cooldown request/response pattern for JIP-visible state, but target responses where possible.
- Command-center scan narrowing remains patch-ready/current-source-unpatched; keep source evidence, patch notes and Arma smoke evidence on [Supply mission scan narrowing](Supply-Mission-Scan-Narrowing).
- Redesign autonomous AI logistics separately from the broken `AI_UpdateSupplyTruck` / missing `supplytruck.fsm` path.

## Continue Reading

Previous: [Economy/towns/supply](Economy-Towns-And-Supply) | Next: [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
