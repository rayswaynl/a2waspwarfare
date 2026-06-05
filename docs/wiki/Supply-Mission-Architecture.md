# Supply Mission Architecture

Page ownership: this page owns the supply-mission flow, cooldown/JIP pattern and state-owner map. [Deep-review findings](Deep-Review-Findings) DR-18 owns the exact cooldown casing defect evidence; [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook) owns the implementation-ready patch shape.

Supply missions are one of the most cross-cutting systems in the mission. They touch client actions, skill roles, town cooldown state, server tracking loops, side supply, commander/team funds in PR #1, player rewards, public variables and buy-menu affordances.

Authority summary: the live path is still client-authored at start and partly client-rewarded at completion. Client-side checks are affordance gates; the server tracks return-to-base and writes side supply, but today it accepts client-stamped `SupplyFromTown` / `SupplyAmount` state and the client completion message path handles personal cash/score reward presentation. The completion message channel is therefore gameplay-relevant, not cosmetic: `supplyMissionCompleted.sqf:24-34` broadcasts amount/player data, and `supplyMissionCompletedMessage.sqf:11-23` locally grants player funds and sends a score-change request when the payload player matches the local player.

Current-source scope: the checked-in Chernarus source is still truck-only. A 2026-06-04 supply scout found no `SupplyByHeli` hits under `Missions/[55-2hc]warfarev2_073v48co.chernarus`; `SupplyByHeli` belongs to PR #1 / `origin/feat/supply-helicopter` branch evidence until that branch is merged.

## Current Branch Matrix

Use this table before asking "is supply fixed?" The answer depends on branch, maintained root and whether the question is scan narrowing, cooldown casing, dead-twin cleanup, heli support or authority hardening.

| Scope | Command-center scan | Cooldown key | Dead twin `supplyMissionActive.sqf` | Heli/cash-run state | Development meaning |
| --- | --- | --- | --- | --- | --- |
| docs/source Chernarus | Truck-only scan is narrowed to `nearestObjects [..., ["Base_WarfareBUAVterminal"], 80]` in `supplyMissionStarted.sqf:25-28`; 8 m nearby-player scan remains broad by design. | Still split: `Init_Town.sqf:35` seeds lowercase `lastSupplyMissionRun`, while server reads/writes `LastSupplyMissionRun`. | Still compiled as `WFBE_SE_FNC_SupplyMissionActive` in `Init_Server.sqf:81`; live path is `supplyMissionStarted.sqf`. | No `SupplyByHeli` in current source. | Truck scan sub-step is docs/source patched; authority, cooldown casing, dead-twin retirement, player-object rescan and smoke remain open. |
| maintained Vanilla Takistan | Same narrowed truck-only scan at `supplyMissionStarted.sqf:25-28`. | Same lowercase/uppercase split. | Same compiled dead twin. | No `SupplyByHeli`. | Propagated for scan narrowing and player-list indexing only; not release-complete without Arma smoke. |
| `origin/master` / `miksuu/master` | Broad 80 m command-center scan remains: `nearestObjects [..., [], 80]` at `supplyMissionStarted.sqf:28` in Chernarus and Vanilla. | Same lowercase/uppercase split. | Compiled dead twin remains. | No `SupplyByHeli`. | Stable/upstream baseline still needs scan narrowing and cleanup; do not cite docs/source patches as stable behavior. |
| `origin/release/2026-06-feature-bundle` `7195b331` Chernarus | Heli-aware narrowed scan at `supplyMissionStarted.sqf:52,58`: terminal class filter, truck 80 m, heli 400 m plus 2D gate. | Fixed: `Init_Town.sqf:35` seeds `LastSupplyMissionRun`. | Removed/commented in `Init_Server.sqf:82`; `supplyMissionActive.sqf` / `checkCCProximity.sqf` are deleted by release cleanup. | Reads and clears `SupplyByHeli` (`supplyMissionCompleted.sqf:24,40-42`). | Release Chernarus has the most advanced cleanup shape, but still needs server-owned mission state, duplicate-start guard, cargo validation, friendly-CC checks and smoke. |
| `origin/release/2026-06-feature-bundle` `7195b331` Vanilla | Same heli-aware narrowed scan at `supplyMissionStarted.sqf:52,58`: terminal class filter, truck 80 m, heli 400 m plus 2D gate. | Same `LastSupplyMissionRun` seed/read/write shape as release Chernarus. | Same removed/commented dead twin cleanup as release Chernarus. | Same `SupplyByHeli` read/clear path as release Chernarus. | Current release head now has maintained-root parity for the static supply scan/cooldown/dead-twin cleanup shape, but Arma truck/heli delivery smoke and broader authority cleanup remain pending. |

## Master Branch Flow

1. SpecOps receives the supply action in `Client/Module/Skill/Skill_Apply.sqf` when role/module conditions are met.
2. The action runs `Client/Module/supplyMission/supplyMissionStart.sqf`.
3. Client finds the closest friendly town with `GetClosestFriendlyLocation`.
4. Client asks server whether that town is cooling down by sending `WFBE_Client_PV_IsSupplyMissionActiveInTown`.
5. Server `isSupplyMissionActiveInTown.sqf` checks `LastSupplyMissionRun` against `WFBE_CO_VAR_SupplyMissionRegenInterval` and broadcasts `WFBE_Server_PV_IsSupplyMissionActiveInTown`.
6. Client stores cooldown on the town as `supplyMissionCoolDownEnabled`.
7. If allowed, client validates cursor target against hardcoded supply-truck classes and distance < 50m.
8. Client writes object variables on the vehicle: `SupplyFromTown` and `SupplyAmount`. The live amount is `floor((town supplyValue) * WFBE_C_ECONOMY_SUPPLY_MISSION_MULTIPLIER * supplyUpgradeModifier)` (`supplyMissionStart.sqf:22-34`; multiplier `20` at `Init_CommonConstants.sqf:167`).
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
- Completion reward is split: the server mutates side supply, while the client completion message path grants personal funds locally and requests score reward. The personal cash award is raw `_supplyAmount` (`supplyMissionCompletedMessage.sqf:8,13-14`), not the stale `STR_Supplies_2` stringtable claim of `4 x actual value`. Because the cash/score side effect happens in the client handler (`supplyMissionCompletedMessage.sqf:11-23`), hardening must treat `WFBE_Server_PV_SupplyMissionCompletedMessage` as an authority surface, not just a notification.
- Supply request/response caches are mutable local state. `Client_ReceiveSupplyValue.sqf:1-8` writes `missionNamespace["wfbe_supply_%side"]`, `townSupplyStatus.sqf:1-8` writes `supplyMissionCoolDownEnabled` on town objects, and `Common_GetSideSupply.sqf:13-18,26-31,39-44` waits on those local values with no timeout. Keep local cache poisoning and unbounded waits in mind before adding more client-side economy gates on top of supply reads.
- Player resolution depends on `WFBE_SE_PLAYERLIST` and proximity/driver checks; stale rows can survive disconnects until the lifecycle cleanup lane is patched. A 2026-06-04 scout also found an in-loop persistence edge in the live handler: `_playerObject` is initialized from the start payload at `supplyMissionStarted.sqf:3-6`, can be reassigned from proximity/driver matches at `:39-53`, and then `_match = !(isNull _playerObject)` at `:61` without resetting `_playerObject` at the top of each loop/row scan. A previous valid match can therefore remain meaningful after local proximity context changes unless the loop explicitly rescans from `objNull` each iteration.

Claude DR-39 split the Perf/JIP status cleanly. The table below is current-docs/source oriented; use [Current Branch Matrix](#current-branch-matrix) for release/stable/upstream scope.

| Item | Status | Development note |
| --- | --- | --- |
| `supplyMissionActive.sqf` | Dead twin in current docs/source and stable/upstream; release `7195b331` comments the dead compile at `Init_Server.sqf:82` and removes `supplyMissionActive.sqf` / `checkCCProximity.sqf` in both maintained release roots. It is compiled as `WFBE_SE_FNC_SupplyMissionActive` wherever it remains, but the live path is `supplyMissionStarted.sqf`, which self-registers the `WFBE_Client_PV_SupplyMissionStarted` handler. | Remove the dead compile/function or keep it explicitly marked as retired; do not patch it as the live implementation. |
| Command-center detection loop | Source and maintained Vanilla Takistan are patched in the live handler. The live loop still sleeps 3 seconds, but now uses `nearestObjects [pos, ["Base_WarfareBUAVterminal"], 80]` for command-center detection. | Smoke delivery at command centers and no-completion near unrelated objects; authority cleanup remains separate. |
| Cooldown JIP behavior | Pull-based and useful, but casing/race-sensitive. Clients ask `WFBE_Client_PV_IsSupplyMissionActiveInTown`; server computes from `LastSupplyMissionRun`; clients store the answer locally. | Keep the server accept/reject decision authoritative. The response is broadcast to all clients today, not targeted to the requester, and the starter reads a local cache immediately after requesting it. |
| Player-object list and object match | Partial source and maintained Vanilla Takistan patch. `playerObjectsList.sqf` now tracks the loop index correctly, but the server does not prune rows on disconnect. In the live completion loop, `_playerObject` is not reset before each proximity/driver scan (`supplyMissionStarted.sqf:3-6,39-53,61-65`), so stale matched player state is an additional smoke target. | Add disconnect cleanup, reset/rescan object matching per loop, and smoke same-UID reconnect plus supply completion lookup. |

## PR #1 Changes

PR #1 improves the Chernarus source supply system by centralizing supply vehicle types, adding `SupplyByHeli`, changing labels to `LOAD SUPPLIES`, adding air rewards/cash runs/interdiction, and highlighting supply helicopters in buy menus. The supply-heli feature path is additive: it extends the same client-started, server-completed object-var flow rather than replacing the trust model.

Current `origin/feat/supply-helicopter` has already addressed the older handler-stacking review risk with a `wfbe_supply_killed_eh_set` guard before adding the interdiction `Killed` handler. Keep that guarded shape and smoke repeated load/deliver/destroy cycles before merge.

Propagation caveat: the current PR branch has the supply-heli runtime symbols in `Missions/[55-2hc]warfarev2_073v48co.chernarus` only. A branch grep found no `SupplyByHeli`, `WFBE_C_SUPPLY_HELI_TYPES`, `WFBE_C_SUPPLY_HELI_ENABLED` or `wfbe_supply_killed_eh_set` symbols under maintained Vanilla Takistan, so Vanilla propagation remains a merge/release gate.

Merge-scope caveat: current local `origin/feat/supply-helicopter` head is `262dc431` and is broader than this feature path. The branch diff against `origin/master` changes 82 files with 462 insertions and 2056 deletions, including service-menu, Valhalla/low-gear, static-defense/HC, performance-audit and UI/resource changes. Review or isolate those separately before treating the branch as a supply-only merge.

## Master vs PR #1 Authority Matrix

| Area | `master` | PR #1 / `feat/supply-helicopter` |
| --- | --- | --- |
| Vehicle type | Truck-only hardcoded class checks. | Centralized `WFBE_C_SUPPLY_TRUCK_TYPES`, `WFBE_C_SUPPLY_HELI_TYPES` and `WFBE_C_SUPPLY_VEHICLE_TYPES`. |
| Start authority | Client chooses eligible vehicle, stamps `SupplyFromTown` / `SupplyAmount`, then notifies server. | Same trust model, plus `SupplyByHeli` and heli class/upgrade gates. |
| Completion authority | Server loop verifies command-center proximity, then trusts the vehicle object vars. | Same server-completion pattern; reward path branches for truck, heli and cash run. |
| Reward | Side supply on completion; player message/score path follows completion broadcast. | Heli rewards add the air bonus; heli deliveries at Aircraft Factory upgrade 4 become cash runs that pay commander team funds when a commander exists. Current PR code does not fall back to side supply when no commander team exists. |
| State cleanup | Completion clears `SupplyAmount` and `SupplyFromTown`. | Current head `262dc431` also writes/reads `SupplyByHeli`, but `supplyMissionCompleted.sqf:40-41` clears only amount/source. Decide whether to clear `SupplyByHeli` or document retained state as harmless because amount is zeroed. |
| Cooldown | Town object cooldown uses `LastSupplyMissionRun`, with source casing mismatch against seeded `lastSupplyMissionRun`. | Same cooldown foundation; PR does not redesign cooldown ownership. |
| AI logistics | Broken/deferred `UpdateSupplyTruck` / missing `supplytruck.fsm`. | Still deferred; PR covers player-run vehicles, not autonomous AI-flown supply helicopters. |
| Known PR risk | Not applicable. | Current branch guards the interdiction `Killed` handler; repeated load/deliver/destroy behavior still needs Arma smoke before merge. |
| Generated target | Truck flow exists in maintained Vanilla. | Supply-heli runtime is not propagated to maintained Vanilla on the current PR branch; run LoadoutManager or explicitly hand-review generated target drift before release. |

## Future Design Direction

- Keep supply-capable vehicle classes in one constant source of truth.
- Add an explicit loaded/unloaded state variable to prevent duplicate tracking loops; keep or deliberately extend the PR's `Killed` handler guard.
- Split client affordance, server validation and reward calculation into documented helper functions.
- Keep the pull-based cooldown request/response pattern for JIP-visible state, but target responses where possible.
- Add terminal timeouts/fallback behavior to `Common_GetSideSupply` request waits so lost or blocked `SUPPLY_VALUE_REQUESTED` responses cannot hang every caller on that client.
- Command-center scan narrowing is patched in source and maintained Vanilla Takistan; keep Arma smoke evidence on [Supply mission scan narrowing](Supply-Mission-Scan-Narrowing) and [Testing workflow](Testing-Debugging-And-Release-Workflow#propagated-fix-smoke-pack).
- Redesign autonomous AI logistics separately from the broken `UpdateSupplyTruck` runtime path (`Init_Server.sqf:36,383`; filename/log label `AI_UpdateSupplyTruck.sqf`) and missing `supplytruck.fsm`.

## Continue Reading

Previous: [Economy/towns/supply](Economy-Towns-And-Supply) | Next: [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
