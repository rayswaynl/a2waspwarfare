# Supply Mission Architecture

Page ownership: this page owns the supply-mission flow, cooldown/JIP pattern and state-owner map. [Deep-review findings](Deep-Review-Findings) DR-18 owns the exact cooldown casing defect evidence; [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook) owns the implementation-ready patch shape.

Supply missions are one of the most cross-cutting systems in the mission. They touch client actions, skill roles, town cooldown state, server tracking loops, side supply, commander/team funds on supply-heli/cash-run branches, player rewards, public variables and buy-menu affordances.

Authority summary: the live path is still client-authored at start and partly client-rewarded at completion. Client-side checks are affordance gates; the server tracks return-to-base and writes side supply, but today it accepts client-stamped `SupplyFromTown` / `SupplyAmount` state and the client completion message path handles personal cash/score reward presentation. The completion message channel is therefore gameplay-relevant, not cosmetic: `supplyMissionCompleted.sqf:24-34` broadcasts amount/player data, and `supplyMissionCompletedMessage.sqf:11-23` locally grants player funds and sends a score-change request when the payload player matches the local player.

Current-source scope: rechecked 2026-06-23 against docs branch `origin/docs/developer-wiki-index@15563691`, current stable/B74.1 `origin/master@f8a76de34`, B74.2 `origin/claude/b74.2-aicom@21b62b04`, current B69 `origin/claude/b69@8d465fce`, adjacent B74 `origin/claude/b74-aicom-spend@b23f557f`, direct current Miksuu upstream `b8389e748243`, `origin/perf/quick-wins@0076040f` and historical release commits `a96fdda2` / `7ff18c49`. The checked docs branch supply-start files are unchanged from the older `4bd37b98` and `8a6695b8` anchors and remain truck-only with no `SupplyByHeli` hits. Current stable/B74.1, B74.2, B69 and adjacent B74 carry the supply-heli/cash-run shape in both maintained roots; current Miksuu and perf remain truck-only. Current origin exposes no live `release/*` or supply feature heads, so release evidence here is historical until a release ref returns or is rechecked.

## Current Branch Matrix

Use this table before asking "is supply fixed?" The answer depends on branch, maintained root and whether the question is scan narrowing, cooldown casing, dead-twin cleanup, heli support or authority hardening.

| Scope | Command-center scan | Cooldown key | Dead twin `supplyMissionActive.sqf` | Heli/cash-run state | Development meaning |
| --- | --- | --- | --- | --- | --- |
| Docs/source Chernarus `15563691` | Truck-only scan is narrowed to `nearestObjects [..., ["Base_WarfareBUAVterminal"], 80]` in `supplyMissionStarted.sqf:25-28`; 8 m nearby-player scan remains broad by design at `:44`. | Still split: `Common/Init/Init_Town.sqf:35` seeds lowercase `lastSupplyMissionRun`, while `isSupplyMissionActiveInTown.sqf:8` reads `LastSupplyMissionRun`. | Still compiled as `WFBE_SE_FNC_SupplyMissionActive` in `Init_Server.sqf:81`; live path is `supplyMissionStarted.sqf`. | No `SupplyByHeli` hits in the checked maintained roots. | Truck scan sub-step is docs/source patched; authority, cooldown casing, dead-twin retirement, player-object rescan and smoke remain open. |
| Maintained Vanilla Takistan `15563691` | Same narrowed truck-only scan at `supplyMissionStarted.sqf:25-28` and same broad nearby-player scan at `:44`. | Same lowercase/uppercase split. | Same compiled dead twin. | No `SupplyByHeli` hits. | Propagated for scan narrowing and player-list indexing only; not release-complete without Arma smoke. |
| Current stable/B74.1 `origin/master@f8a76de34`; B74.2 `origin/claude/b74.2-aicom@21b62b04`; B69/B74 shaped refs | Heli-aware narrowed scan in both maintained roots: heli flag at `supplyMissionStarted.sqf:7`, terminal guard at `:55`, typed truck/heli scan at `:61`, broad nearby-player scan at `:83`. B74.2 does not change these start-handler anchors. | Fixed in maintained roots: `Common/Init/Init_Town.sqf:35` seeds `LastSupplyMissionRun`; `isSupplyMissionActiveInTown.sqf:8` reads with default `0`. | Removed/commented in `Init_Server.sqf:105` on current source Chernarus and `:99` on maintained Vanilla; `supplyMissionActive.sqf` and `checkCCProximity.sqf` are absent from both maintained roots. | `SupplyByHeli` is set at `supplyMissionStart.sqf:80`, guarded `Killed` handler setup uses `wfbe_supply_killed_eh_set` at `supplyMissionStarted.sqf:15-17`, and B74.1 reads/clears heli state at `supplyMissionCompleted.sqf:26,:47` in source Chernarus and `:26,:44` in Vanilla. B74.2 source Chernarus line-drifts completion to `:29,:50`; Vanilla remains `:26,:44`. | Current stable/B74-shaped refs carry the advanced branch shape in both maintained roots, but server-owned mission state, duplicate-start guard, cargo validation, friendly-CC checks and Arma truck/heli smoke remain pending. |
| Historical release commits `a96fdda2` / `7ff18c49` | Both local release-line commits have the heli-aware typed scan in both maintained roots. `a96fdda2` uses `supplyMissionStarted.sqf:7,53,59,81`; `7ff18c49` uses `:7,52,58,80`. | `a96fdda2` seeds `LastSupplyMissionRun` at `Common/Init/Init_Town.sqf:35` and reads with default `0` at `isSupplyMissionActiveInTown.sqf:8`. | `a96fdda2` comments the dead compile at `Init_Server.sqf:81`; the dead twin files are absent. | `a96fdda2` sets `SupplyByHeli` at `supplyMissionStart.sqf:80`, reads it at `supplyMissionCompleted.sqf:26`, clears it at `:44` and includes cash-run state at `:29-33`. | Historical release evidence has maintained-root parity for the static supply scan/cooldown/dead-twin cleanup shape, but runtime smoke and broader authority cleanup remain pending; do not call it a current release head. |
| Miksuu `b8389e74` and `origin/perf/quick-wins` `0076040f` | Broad 80 m command-center scan remains: `nearestObjects [..., [], 80]` at `supplyMissionStarted.sqf:28` in Chernarus and Vanilla. | Same lowercase/uppercase split as docs/source. | Compiled dead twin remains at `Init_Server.sqf:81`. | No `SupplyByHeli`. | Upstream/perf have not rescued the scan, cooldown or dead-twin cleanup; re-audit before porting any stable/release behavior back. |

## Docs Checkout Truck-Only Flow

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

- `supplyMissionStart.sqf` in the docs checkout uses duplicated hardcoded supply-truck classname arrays.
- Start is client-authored: the server start handler should revalidate sender ownership, vehicle class, source town, cooldown and duplicate-start state before accepting future hardened starts.
- The client asks for cooldown and immediately reads local town state; timing/race behavior depends on the server response arriving quickly enough.
- Cooldown variable casing is a confirmed DR-18 defect: town init seeds `lastSupplyMissionRun`, while server supply code reads/writes `LastSupplyMissionRun`.
- `supplyMissionStarted.sqf` loops until the vehicle dies; it should avoid creating duplicate tracking loops for the same loaded vehicle.
- Completion trusts object variables on the supply vehicle, so any feature that reuses those vars must clear them reliably.
- Completion reward is split: the server mutates side supply, while the client completion message path grants personal funds locally and requests score reward. The personal cash award is `_reward` (`supplyMissionCompletedMessage.sqf:16-21`): equal to `_supplyAmount` for truck runs, or `round(_supplyAmount * WFBE_C_SUPPLY_HELI_REWARD_MULT)` (×1.25) for heli deliveries — not the stale `STR_Supplies_2` stringtable claim of `4 x actual value`. Because the cash/score side effect happens in the client handler (`supplyMissionCompletedMessage.sqf:11-23`), hardening must treat `WFBE_Server_PV_SupplyMissionCompletedMessage` as an authority surface, not just a notification.
- Supply request/response caches are mutable local state. `Client_ReceiveSupplyValue.sqf:1-8` writes `missionNamespace["wfbe_supply_%side"]`, `townSupplyStatus.sqf:1-8` writes `supplyMissionCoolDownEnabled` on town objects, and `Common_GetSideSupply.sqf:13-18,26-31,39-44` waits on those local values with no timeout. Keep local cache poisoning and unbounded waits in mind before adding more client-side economy gates on top of supply reads.
- Player resolution depends on `WFBE_SE_PLAYERLIST` and proximity/driver checks; stale rows can survive disconnects until the lifecycle cleanup lane is patched. A 2026-06-04 scout also found an in-loop persistence edge in the live handler: `_playerObject` is initialized from the start payload at `supplyMissionStarted.sqf:3-6`, can be reassigned from proximity/driver matches at `:39-53`, and then `_match = !(isNull _playerObject)` at `:61` without resetting `_playerObject` at the top of each loop/row scan. A previous valid match can therefore remain meaningful after local proximity context changes unless the loop explicitly rescans from `objNull` each iteration.

Claude DR-39 split the Perf/JIP status cleanly. The table below is current-docs/source oriented; use [Current Branch Matrix](#current-branch-matrix) for release/stable/upstream scope.

| Item | Status | Development note |
| --- | --- | --- |
| `supplyMissionActive.sqf` | Dead twin in docs/source, Miksuu and perf; current stable/B74.1 `f8a76de34` and B74.2 `21b62b04` comment the removed compile at `Init_Server.sqf:105` on source Chernarus and `:99` on maintained Vanilla, while historical `a96fdda2` comments it at `:81`. Current stable/B74-shaped refs and historical release remove `supplyMissionActive.sqf` / `checkCCProximity.sqf` in the maintained roots. It is compiled as `WFBE_SE_FNC_SupplyMissionActive` wherever it remains, but the live path is `supplyMissionStarted.sqf`, which self-registers the `WFBE_Client_PV_SupplyMissionStarted` handler. | Remove the dead compile/function or keep it explicitly marked as retired; do not patch it as the live implementation. |
| Command-center detection loop | Docs/source and current stable are patched in the live handler, with different branch shapes: truck-only typed scan in docs/source and heli-aware typed scan in current stable. Current Miksuu and perf still broad-enumerate then post-filter. | Smoke delivery at command centers and no-completion near unrelated objects; authority cleanup remains separate. |
| Cooldown JIP behavior | Pull-based and useful, but casing/race-sensitive. Clients ask `WFBE_Client_PV_IsSupplyMissionActiveInTown`; server computes from `LastSupplyMissionRun`; clients store the answer locally. | Keep the server accept/reject decision authoritative. The response is broadcast to all clients today, not targeted to the requester, and the starter reads a local cache immediately after requesting it. |
| Player-object list and object match | Partial source and maintained Vanilla Takistan patch. `playerObjectsList.sqf` still has a broken loop-index counter: `_i` is initialised to 0 inside the forEach block (line 18) and resets each iteration, so `_arrayPosMatch` always captures 0 rather than the true array position of the matching UID; UID replacement therefore always overwrites index 0 instead of the correct slot. The server also does not prune rows on disconnect. In the live completion loop, `_playerObject` is not reset before each proximity/driver scan (`supplyMissionStarted.sqf:3-6,39-53,61-65`), so stale matched player state is an additional smoke target. | Add disconnect cleanup, reset/rescan object matching per loop, and smoke same-UID reconnect plus supply completion lookup. |

## Supply-Heli Branch Shape

The old PR #1 notes are now historical branch-review context. Current stable/B74.1 `origin/master@f8a76de34`, B74.2 `origin/claude/b74.2-aicom@21b62b04`, B69 and adjacent B74 carry the supply-heli/cash-run implementation in both maintained roots, including guarded `wfbe_supply_killed_eh_set` setup in the live start handler (`supplyMissionStarted.sqf:15-17`), `SupplyByHeli` set at `supplyMissionStart.sqf:80`, heli reward constant `WFBE_C_SUPPLY_HELI_REWARD_MULT` (B74.1 source Chernarus `Init_CommonConstants.sqf:550`, maintained Vanilla `:352`; B74.2 source Chernarus `:563`, maintained Vanilla `:352`), and cash-run completion state. B74.1 reads/clears heli state at source Chernarus `supplyMissionCompleted.sqf:26,:47` and Vanilla `:26,:44`; B74.2 source Chernarus line-drifts to `:29,:50` while Vanilla remains `:26,:44`. Historical release `a96fdda2` remains release-line evidence. The trust model is still the same client-started, server-completed object-var flow.

| Area | Docs/Miksuu/perf truck-only shape | Stable/release supply-heli shape |
| --- | --- | --- |
| Vehicle type | Truck-only hardcoded class checks. | Centralized `WFBE_C_SUPPLY_TRUCK_TYPES`, `WFBE_C_SUPPLY_HELI_TYPES` and `WFBE_C_SUPPLY_VEHICLE_TYPES`. |
| Start authority | Client chooses eligible vehicle, stamps `SupplyFromTown` / `SupplyAmount`, then notifies server. | Same trust model, plus `SupplyByHeli` and heli class/upgrade gates. |
| Completion authority | Server loop verifies command-center proximity, then trusts the vehicle object vars. | Same server-completion pattern; reward path branches for truck, heli and cash run. |
| Reward | Side supply on completion; player message/score path follows completion broadcast. | Heli rewards add the air bonus; heli deliveries at Aircraft Factory upgrade 4 become cash runs that pay commander team funds when a commander exists. |
| State cleanup | Completion clears `SupplyAmount` and `SupplyFromTown`. | Completion clears `SupplyAmount`, `SupplyFromTown` and `SupplyByHeli` (`supplyMissionCompleted.sqf:42-44` on stable/release). |
| Cooldown | Town object cooldown uses `LastSupplyMissionRun`, with source casing mismatch against seeded `lastSupplyMissionRun`. | Same ownership pattern, but stable/release seed `LastSupplyMissionRun` and read it with default `0`. |
| AI logistics | Broken/deferred `UpdateSupplyTruck` / missing `supplytruck.fsm`. | Still deferred; PR covers player-run vehicles, not autonomous AI-flown supply helicopters. |
| Runtime risk | Truck flow still needs server-owned cargo/reward hardening and smoke. | Repeated load/deliver/destroy, truck/heli command-center delivery, no-completion near unrelated objects, cash-run semantics and JIP cooldown behavior still need Arma smoke on the target branch. |

## Future Design Direction

- Keep supply-capable vehicle classes in one constant source of truth.
- Add an explicit loaded/unloaded state variable to prevent duplicate tracking loops; keep or deliberately extend the guarded `Killed` handler shape on supply-heli branches.
- Split client affordance, server validation and reward calculation into documented helper functions.
- Keep the pull-based cooldown request/response pattern for JIP-visible state, but target responses where possible.
- Add terminal timeouts/fallback behavior to `Common_GetSideSupply` request waits so lost or blocked `SUPPLY_VALUE_REQUESTED` responses cannot hang every caller on that client.
- Command-center scan narrowing is branch-split: docs/source uses the truck-only typed terminal scan, current stable uses the heli-aware typed scan, historical release commits preserve the release-line shape, and current Miksuu/perf still use the broad scan. Keep Arma smoke evidence on [Supply mission scan narrowing](Supply-Mission-Scan-Narrowing) and [Testing workflow](Testing-Debugging-And-Release-Workflow#propagated-fix-smoke-pack).
- Redesign autonomous AI logistics separately from the broken `UpdateSupplyTruck` runtime path (`Init_Server.sqf:36,383`; filename/log label `AI_UpdateSupplyTruck.sqf`) and missing `supplytruck.fsm`.

## Continue Reading

Previous: [Economy/towns/supply](Economy-Towns-And-Supply) | Next: [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
