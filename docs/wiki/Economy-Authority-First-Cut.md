# Economy Authority First Cut

This page turns the broad economy/server-authority decision into the smallest source-backed implementation sequence worth doing first.

Scope: Chernarus source mission first, Arma 2 Operation Arrowhead 1.64 only, then LoadoutManager propagation. It complements [Server authority map](Server-Authority-Migration-Map), [Upgrades and research atlas](Upgrades-And-Research-Atlas), [Economy, towns and supply](Economy-Towns-And-Supply), [Hardening roadmap](Hardening-Implementation-Roadmap), [Public variable channel index](Public-Variable-Channel-Index), [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook), [Attack-wave authority playbook](Attack-Wave-Authority-Playbook) and [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl).

## Status

| Item | State |
| --- | --- |
| Finding class | Confirmed economy/server-authority class across DR-6, DR-14, DR-16, DR-22, DR-23, DR-27, DR-28, DR-41 and DR-44. |
| New value from this pass | First safe code sequence: side-supply arithmetic/validation first, then existing PVF spend handlers, then player-buy redesign. |
| Wave I refinement | Kepler split client-trusted score/funds/supply mutation from safer server-derived read and award helpers. |
| Wave Q refinement | Linnaeus's side-supply follow-up is now folded in: negative amounts are legitimate spend deltas, but the same signed `_amount` is also direct-PV payload data, so the first patch must clamp the result and validate channel/side/shape without pretending sign checks are authority. |
| 2026-06-04 scout refinement | AI commander upgrade debit order is suspect, resource income can couple money payouts to the supply-cap guard, client income display for income system `4` can differ from server paycheck math, and factory player buys need a protocol redesign rather than a narrow hardening patch. |
| 2026-06-24 side-supply/B74.2 current-head follow-up | Docs/source `HEAD@3bedb86dca88` keeps the old side-supply/reason shape from `973d817817d9` / `a908284c` for checked paths. Current stable/B74.1 `origin/master@f8a76de34` and current B74.2 `origin/claude/b74.2-aicom@21b62b04` match for checked side-supply/resistance paths: Chernarus removes dead common-side clamp arithmetic, floors west/resistance/east server negatives to `0` and wires `wfbe_supply_temp_resistance`, while maintained Vanilla stays old-shape. Checked `d472da6a..21b62b04` is empty for the side-supply/resistance/reason files; `origin/master..origin/claude/b74.2-aicom` only line-drifts source-Chernarus supply-completion calls. Current origin exposes no live `release/*`, supply, economy or resistance rescue heads on 2026-06-24, but live `origin/claude/faction-tint-sidefix@32acd272f92e` diverges before current stable and removes the Chernarus resistance temp-channel handler. Treat that branch as a regression warning if revived, not a rescue. |
| Immediate patch candidate | `Common_ChangeSideSupply.sqf` and `Server_ChangeSideSupply.sqf` negative clamp and side/channel validation. |
| Smallest server-led migration candidate | Upgrade purchase, because `RequestUpgrade` already reaches a server process but currently trusts client-side debit and dependency checks. |
| Do not treat as small | Player factory buys. They create units/vehicles from the client and have no `RequestBuyUnit` PVF. |

## What I Read

- `Common/Functions/Common_ChangeSideSupply.sqf:3-30`
- `Server/Functions/Server_ChangeSideSupply.sqf:1-47`
- `Common/Functions/Common_ChangeTeamFunds.sqf:1-8`
- `Server/PVFunctions/RequestChangeScore.sqf:3-13`
- `Client/PVFunctions/TownCaptured.sqf:71`
- `Common/Functions/Common_AwardScorePlayer.sqf:17-27`
- `Common/Functions/Common_GetTotalSupplyValue.sqf:7-11`
- `Common/Functions/Common_GetSideSupply.sqf:11,17,24,30,37,43`
- `Server/Functions/Server_PV_RequestSupplyValue.sqf:1-8`
- `Client/Functions/Client_ReceiveSupplyValue.sqf:7`
- `Client/Init/Init_Client.sqf:371`
- `Client/Functions/Client_ChangePlayerFunds.sqf:1`
- `Client/Functions/Client_GetPlayerFunds.sqf:1`
- `Client/GUI/GUI_UpgradeMenu.sqf:129-172`
- `Server/PVFunctions/RequestUpgrade.sqf:1-5`
- `Server/Functions/Server_ProcessUpgrade.sqf:12-18`, `:23-44`, `:85-87`
- `Client/Module/CoIn/coin_interface.sqf:240-260`, `:485-503`, `:667-724`
- `Server/PVFunctions/RequestStructure.sqf:3-22`
- `Server/PVFunctions/RequestDefense.sqf:2-10`
- `Client/GUI/GUI_Menu_BuyUnits.sqf:83-156`
- `Client/Functions/Client_BuildUnit.sqf:211-249`, `:409-455`
- `Client/GUI/GUI_Menu_Economy.sqf:120-150`
- `Client/GUI/GUI_Menu_Service.sqf:195-234`
- `Client/GUI/GUI_Menu_EASA.sqf:40-50`
- `Client/Action/Action_RepairMHQ.sqf:24-40`
- `WASP/actions/Action_RepairMHQDepot.sqf:13-28`
- `Client/Module/supplyMission/supplyMissionStart.sqf:3-51`
- `Server/Module/supplyMission/supplyMissionStarted.sqf:1-88`
- `Server/Module/supplyMission/supplyMissionCompleted.sqf:2-48`
- `Server/Module/supplyMission/isSupplyMissionActiveInTown.sqf:1-18`
- `Server/Functions/Server_HandleSpecial.sqf:97-111`
- `Server/Functions/Server_AttackWave.sqf:1-38`
- `Server/Functions/Server_AI_Com_Upgrade.sqf:27,32-50`
- `Server/FSM/updateresources.sqf:29-70`
- `Client/Functions/Client_GetIncome.sqf:20-29`
- Existing wiki records: [Deep-review findings](Deep-Review-Findings), [Server authority map](Server-Authority-Migration-Map), [Pending owner decisions](Pending-Owner-Decisions), [Public variable channel index](Public-Variable-Channel-Index), [Economy, towns and supply](Economy-Towns-And-Supply), [Attack-wave authority playbook](Attack-Wave-Authority-Playbook).

## What The Code Actually Does

### Funds are a replicated group variable

`Common_ChangeTeamFunds.sqf` takes `[team, amount]` and writes:

```sqf
_team setVariable ["wfbe_funds", (_team getVariable "wfbe_funds") + _amount, true];
```

`Client_ChangePlayerFunds.sqf:1` simply calls that with `clientTeam`, and `Client_GetPlayerFunds.sqf:1` reads the same team value. This is why many UI paths can debit or credit locally after client-side affordability checks.

There is no `Server/PVFunctions/RequestChangeFunds.sqf` in the current source. Funds authority is a convention over replicated group variables and shared helpers, not a single server request wall. Treat this as client-authoritative unless the target server also carries explicit BattlEye/script-filter constraints.

### Side supply uses direct publicVariable temp channels

`Common_ChangeSideSupply.sqf` writes `wfbe_supply_temp_<side>` and `publicVariableServer`s it. Old-shape refs and maintained Vanilla register only `wfbe_supply_temp_west` / `wfbe_supply_temp_east`; current stable/B74.1/B74.2 Chernarus also registers `wfbe_supply_temp_resistance`.

Old-shape common and server code compute:

```sqf
_change = _currentSupply + _amount;
if (_change < 0) then {_change = _currentSupply - _amount};
```

For `_currentSupply = 100` and `_amount = -1000`, this produces `1100`, not `0`. Current stable/B74.1/B74.2 Chernarus removes the dead local common-side clamp arithmetic and floors server negatives to `0`, but maintained Vanilla still has the old floor. The direct-PV authority issue remains even where that arithmetic is patched.

Important subtlety: negative `_amount` values are not inherently malicious. Normal spend paths use negative deltas, such as MHQ repair (`Client/Action/Action_RepairMHQ.sqf:30`), WASP base repair (`WASP/baserep/repair.sqf:24`), attack waves (`Server/PVFunctions/AttackWave.sqf:40`), upgrades (`Client/GUI/GUI_UpgradeMenu.sqf:159`), construction (`Client/Module/CoIn/coin_interface.sqf:500,672`) and building repair (`Server/Functions/Server_HandleBuildingRepair.sqf:71`). The problem is that the same signed amount is also the payload sent on `wfbe_supply_temp_<side>` (`Common_ChangeSideSupply.sqf:24-26` on current Chernarus, `:28-30` on old-shape/Vanilla) and then trusted by the temp handlers. Do not "fix" this by rejecting all negative amounts; fix the result clamp and channel/side/shape validation first, then move spend acceptance server-side flow by flow.

Small auditability bug: `Common_ChangeSideSupply.sqf:8-14` reads `_includeStagnation` and `_reason` only when `count _this > 3`. Three-argument calls such as `Server/PVFunctions/AttackWave.sqf:40` pass a reason string but still publish the default `"ERROR! No reason specified..."` reason. Fix this alongside the clamp/validation pass so economy logs keep useful provenance while malformed payloads still produce clear warnings: parse `_reason` at `count _this > 2`, then `_includeStagnation` at `count _this > 3`.

The live source of truth for side supply is the side-keyed mission variable `wfbe_supply_%1` read by `Common_GetSideSupply.sqf`. The generic `wfbe_supply` value initialized in `Client/Init/Init_Client.sqf:371` is a legacy alias/cache and should not be used as the target for new authority work.

## Side-Supply Reason String Branch Matrix

This matrix is about logging/audit provenance only. It should travel with the clamp/validation patch because the same helper is being edited, but it does not close direct-channel authority or spend acceptance.

| Scope | Reason parsing shape | Preserved reason callers | Development meaning |
| --- | --- | --- | --- |
| Docs branch `4db90f1c` Chernarus, unchanged from `7047da5d9` / `f52ccee8` for checked paths | `Common_ChangeSideSupply.sqf:8-14` reads both `_includeStagnation` and `_reason` only when `count _this > 3`; `:28` publishes the selected reason through `wfbe_supply_temp_<side>`. | `Server/PVFunctions/AttackWave.sqf:40` passes three arguments and loses `"Heavy attack mode activated."`; `Server/Module/supplyMission/supplyMissionCompleted.sqf:26` passes four arguments and keeps its formatted reason. | Patch-ready low-risk diagnostics cleanup. Parse `_reason` at `count _this > 2` and `_includeStagnation` at `count _this > 3`, while retaining the default error text for malformed/no-reason payloads. |
| Docs branch `4db90f1c` maintained Vanilla, unchanged from `7047da5d9` / `f52ccee8` for checked paths | Same helper guard and same AttackWave/supply-completion caller shape in the maintained root. | Same three-argument AttackWave reason drop; same four-argument supply mission reason preservation. | Propagate with the Chernarus helper edit; do not call the reason fix source-complete if Vanilla is still old. |
| Current stable/B74.1 `origin/master@f8a76de34` / `origin/claude/b74.1-aicom@f8a76de34` | Same `count _this > 3` reason guard in both maintained roots (`Common_ChangeSideSupply.sqf:8-14`). | Same AttackWave three-argument drop at `AttackWave.sqf:40`; supply completion is the heli-aware four-argument path at Chernarus `supplyMissionCompleted.sqf:40,43` and Vanilla `:40`. | Stable/B74.1 remains source-unpatched for audit provenance even though Chernarus has arithmetic/resistance-handler work. |
| Historical release commit `a96fdda2`; no current `release/*` head on 2026-06-22 | Same `count _this > 3` reason guard in both maintained roots. | Same AttackWave three-argument drop; supply completion is the heli-aware four-argument path at `supplyMissionCompleted.sqf:40`. | Historical release evidence does not rescue the reason-string lane. Recheck a restored release head before release wording. |
| Miksuu upstream `b8389e748243` | Same `count _this > 3` reason guard in both maintained roots. | Same AttackWave/supply-completion contrast, with supply completion at `supplyMissionCompleted.sqf:26`. | No upstream rescue candidate in the checked upstream head. |
| `origin/perf/quick-wins` `0076040f` | Same reason guard in both maintained roots; the branch's Chernarus side-supply arithmetic work does not alter reason parsing. | Same AttackWave/supply-completion contrast, with supply completion at `supplyMissionCompleted.sqf:26`. | The perf branch can inform arithmetic floor work, but it does not fix this logging defect. |
| Current B74.2 `origin/claude/b74.2-aicom@21b62b04`; previous B74.2 `d472da6a`; current B69 `origin/claude/b69@8d465fce`; adjacent B74 `origin/claude/b74-aicom-spend@b23f557f` | B74.2 has no checked helper delta over previous B74.2 or current stable. B69..B74 has no checked side-supply helper delta. Chernarus and maintained Vanilla still keep the `count _this > 3` reason guard (`Common_ChangeSideSupply.sqf:8-14`). | Same AttackWave/supply-completion contrast. Current B74.2 Chernarus line-drifts the four-argument supply-completion calls to `supplyMissionCompleted.sqf:43,46`, while current stable Chernarus uses `:40,43` and Vanilla remains `:40`; Chernarus publishes through `Common_ChangeSideSupply.sqf:24-26`, while Vanilla keeps `:28-30`. | Do not treat B74.2, B69 or B74 as a reason-string fix. If porting the side-supply arithmetic, still patch reason parsing in both maintained roots. |

## Side-Supply Branch Matrix

This matrix separates the small DR-22 arithmetic clamp from the larger DR-44 direct-channel authority problem. It is docs-only evidence; no current source patch is implied.

| Scope | Arithmetic floor | Direct temp-channel validation | Development meaning |
| --- | --- | --- | --- |
| Docs branch `4db90f1c` Chernarus, unchanged from `7047da5d9` / `f52ccee8` for checked paths | Old bug remains: `Common_ChangeSideSupply.sqf:24-30` computes `_change`, then floors negatives with `_currentSupply - _amount`; `Server_ChangeSideSupply.sqf:11-13,35-37` does the same for west/east handlers. | Open: handlers at `Server_ChangeSideSupply.sqf:1-21,25-45` read `_side` from the payload and write `wfbe_supply_%1`; channel suffix does not constrain the mutated side. | Patch-ready and current-source-unpatched. Clamp to `0`, keep max cap, validate side/channel/amount shape, and still treat spend authorization as future server-ledger work. |
| Docs branch `4db90f1c` maintained Vanilla, unchanged from `7047da5d9` / `f52ccee8` for checked paths | Same old floor in `Common_ChangeSideSupply.sqf:24-30` and `Server_ChangeSideSupply.sqf:11-13,35-37`. | Same payload-trusting west/east handlers. | Any fix must be propagated; do not cite a Chernarus-only branch as Vanilla-ready. |
| Current stable/B74.1 `origin/master@f8a76de34` / `origin/claude/b74.1-aicom@f8a76de34` | Branch-split. Chernarus removes dead common-side clamp arithmetic at `Common_ChangeSideSupply.sqf:20-22` and floors server west/resistance/east negatives to `0` at `Server_ChangeSideSupply.sqf:12,36,60`. Maintained Vanilla remains old-shape at `Common_ChangeSideSupply.sqf:25` and `Server_ChangeSideSupply.sqf:12,36`. | Chernarus adds `wfbe_supply_temp_resistance` at `Server_ChangeSideSupply.sqf:25-45`, but all temp handlers still trust payload `_side` / `_amount` and lack side/channel/requester validation. Vanilla still has only west/east handlers. | Current stable/B74.1 is a Chernarus partial rescue only: preserve the candidate, propagate or scope Vanilla, and keep DR-44 validation/server-ledger work open. |
| Historical release commit `a96fdda2`; no current `release/*` head on 2026-06-22 | Same old floor in Chernarus and maintained Vanilla when last checked. | Same payload-trusting direct temp channels. | Historical release evidence does not rescue the side-supply lane. Recheck a restored release head before release wording. |
| Miksuu upstream `b8389e748243` | Same old floor in Chernarus and Vanilla. | Same payload-trusting direct temp channels. | No upstream rescue candidate in current upstream head. |
| `origin/perf/quick-wins` `0076040f` | Chernarus only: `Common_ChangeSideSupply.sqf:25` and `Server_ChangeSideSupply.sqf:12,36` floor negatives to `0`. Vanilla on the same branch still has `_currentSupply - _amount`. | Still open even in Chernarus: the branch keeps `wfbe_supply_temp_%1` and does not add side/channel/requester validation. | Useful cherry-pick candidate for the DR-22 arithmetic floor only; not a DR-44 authority fix and not propagated. |
| Current B74.2 `origin/claude/b74.2-aicom@21b62b04`; previous B74.2 `d472da6a`; current B69 `origin/claude/b69@8d465fce`; adjacent B74 `origin/claude/b74-aicom-spend@b23f557f` | No checked side-supply/resistance path delta versus their respective bases: `d472da6a..21b62b04` is empty for checked side-supply/resistance paths, B74.2 matches current stable for this surface, and B69..B74 is empty for checked side-supply paths. Chernarus has the same floor-to-zero/resistance-handler candidate; maintained Vanilla remains old-shape. | Same as current stable/B74.1: Chernarus handler coverage is broader, but payload side/channel/requester validation is still absent; Vanilla is west/east only. | Useful Chernarus candidate evidence, not closure. Future code work must still propagate or scope Vanilla and implement DR-44 validation/server-owned acceptance. |
| Live `origin/claude/faction-tint-sidefix@32acd272f92e` (merge-base `d35d7c8fb774`; branch does not contain current stable) | Compared with current stable, Chernarus keeps west/east floor-to-zero at `Server_ChangeSideSupply.sqf:12,36` but removes the current-stable `wfbe_supply_temp_resistance` handler block. | Still no side/channel/requester validation; resistance writes would again have no receiver on that branch unless restored during rebase. | Treat as a stale divergent branch/regression warning, not as side-supply rescue evidence. If revived, rebase or restore the resistance handler deliberately, then add validation and Vanilla scope decisions. |

### Score and supply reads show mixed authority patterns

`RequestChangeScore.sqf` accepts a score value from the payload and applies it with `addScore`. `TownCaptured.sqf:71` uses this route after client-side capture reward handling, so capture bounty scoring belongs in the same authority family as funds and supply rewards.

There are also safer patterns worth reusing. `Common_AwardScorePlayer.sqf:17-27` derives score awards from configured constants, `RequestOnUnitKilled.sqf:71-80` computes kill points server-side, `Common_GetTotalSupplyValue.sqf:7-11` recomputes aggregate supply from town state, and `Server_PV_RequestSupplyValue.sqf:1-8` answers a read request by deriving the current supply on the server. New patches should move toward those server-derived patterns rather than adding more client-stamped mutation payloads.

### Upgrades already have a server entrypoint, but client owns debit and validation

`GUI_UpgradeMenu.sqf:141-161` checks funds, side supply and dependencies locally, then:

- debits player funds at `:158`;
- debits side supply through `ChangeSideSupply` at `:159`;
- sends `RequestUpgrade` with `[side, id, currentLevel, true]` at `:161`.

`RequestUpgrade.sqf:5` just spawns `Server_ProcessUpgrade`. `Server_ProcessUpgrade.sqf:12-18` trusts side, id and level from the payload to look up time; `:40-44` increments the upgrade state and clears the running flag. It does not recompute commander, current level, dependencies, cost or funds before accepting the transition. See [Upgrades and research atlas](Upgrades-And-Research-Atlas) for the full live-menu/server-worker/AI-worker map.

AI commander upgrades are server-side but not therefore automatically correct. The upgrade cost tables use `[supply, funds]` convention in source config, including examples such as `Common/Config/Core_Upgrades/Upgrades_CO_US.sqf:30-42` and `Upgrades_OA_US.sqf:30-42`. `Server_AI_Com_Upgrade.sqf:89` validates `_cost select 0` as supply (against `_supply` plus reserve) and `_cost select 1` as funds, matching the player upgrade menu. **RESOLVED (TR12, current master f8a76de3):** the debit order is now correct — it deducts `_cost select 1` (the funds price) from AI commander funds at `:125` and `_cost select 0` (the supply price) from side supply at `:136`, both tagged with `//--- TR12` notes that the earlier code had the two prices swapped. Before reviving autonomous AI commander upgrade loops, keep player/AI/server validation on the same `[supply, funds]` tuple convention.

### Resource income has payout/display edge cases

Old-shape refs place the side-supply increase, team paychecks and AI-commander funds inside an `_supply < WFBE_C_ECONOMY_SUPPLY_MAX_TEAM_LIMIT` guard: docs/source `HEAD@c8ec223a`, Miksuu `b8389e748243`, `origin/perf/quick-wins@0076040f` and historical release commit `a96fdda2` keep `Server/FSM/updateresources.sqf:29-70` with the guard at `:31`, side supply at `:49`, team funds at `:63` and AI commander funds at `:67`. `_supply` is the computed town supply income for the side, so the guard is not simply "current side supply is full". Do not refactor the income loop as a pure supply-cap cleanup without checking player/commander money payouts.

Current stable/B74.1 `origin/master@f8a76de34` equals `origin/claude/b74.1-aicom@f8a76de34`, and B74.2 `origin/claude/b74.2-aicom@d472da6a` has no checked income-file delta. Current Chernarus still gates side-supply growth (`updateresources.sqf:87`) and team paychecks (`:101`) behind `_supply < _supply_max_limit` at `:69`, but AI commander cash has hybrid-refill checks at `:105-114`, an over-cap fallback at `:126-132` and B74.1 AICOM taper at `:57-67,:106,:130`. Maintained Vanilla keeps the same cap/fallback shape without Chernarus hybrid refill, supply multiplier or taper (`:58,:76,:90,:94-103,:115-121`). The current branch/root route lives in [Economy, towns and supply](Economy-Towns-And-Supply#resource-income-branch-matrix); perf Chernarus changes the resource-loop wait cadence, not this payout/display behavior.

Current B69 `origin/claude/b69@8d465fce` and adjacent B74 `origin/claude/b74-aicom-spend@b23f557f` are identical for checked resource-income files. Both keep the cap gate at `updateresources.sqf:58`, side supply at `:76`, team paychecks at `:90` and AI commander fallback at `:115-121`; Chernarus additionally applies `WFBE_C_ECONOMY_SUPPLY_INCOME_MULT` to side supply at `:76` and broadens AI commander cash/stipend eligibility with `WFBE_C_AI_COMMANDER_HYBRID_REFILL` at `:94-103` and `:115`, while maintained Vanilla keeps the non-hybrid/raw-supply shape. Keep that parity difference visible when planning a current-stable port.

For income system `4`, server payout applies a `1.5` multiplier before commander/player split (`updateresources.sqf:42-43` on old-shape refs, current Chernarus `:80-81`, current maintained Vanilla `:69-70`, and B69/B74 Chernarus `:69-70`), while `Client_GetIncome.sqf:24-28` displays the split without that multiplier everywhere checked. UI work around RHUD/menu income should preserve or deliberately correct this mismatch with balance owner approval.

### Construction/defense already have server entrypoints, but client owns debit and placement affordance

`coin_interface.sqf:667-674` debits side supply or player funds for structures locally; `:718` sends `RequestStructure`. Defense purchase debits player funds at `:690-693` and sends `RequestDefense` at `:722`.

`RequestStructure.sqf:3-22` accepts side, class, position and direction from the payload, resolves the structure script and starts construction. `RequestDefense.sqf:2-10` accepts side, class, position, direction and manned flag and calls `ConstructDefense`. Neither handler proves requester, commander role, funds, base area, object side, placement or class permission beyond array membership.

### Player factory buys are the ceiling, not the first cut

`GUI_Menu_BuyUnits.sqf:102-108` checks funds locally, queues locally and at `:155-156` spawns `BuildUnit` and debits `ChangePlayerFunds`. `Client_BuildUnit.sqf:217` creates infantry through `WFBE_CO_FNC_CreateUnit`; `:249` creates vehicles through `WFBE_CO_FNC_CreateVehicle`; `:411-455` creates crew locally. There is no `RequestBuyUnit` PVF in `Init_PublicVariables.sqf` and no `Server/PVFunctions/RequestBuyUnit.sqf`.

That means player buy authority is a protocol redesign, not a tidy handler hardening patch. It needs a server request/acceptance/rollback contract or an explicit BattlEye `scripts.txt` posture while preserving locality. The current honest-client path debits immediately after spawning `BuildUnit` (`GUI_Menu_BuyUnits.sqf:155-156`), while `Client_BuildUnit.sqf:365` can exit an empty/crewless vehicle path before the normal queue and local-counter tail (`:467-469`). Server-side AI buy abort paths clean queue state (`Server_BuyUnit.sqf:47-55,78-83`) but do not define a player refund/rollback contract. The debit should either commit only after build acceptance or be refunded on every post-queue abort path by one source-of-truth helper.

### Supply missions are a separate logistics authority lane

On current `master`, `supplyMissionStart.sqf:20-39` lets the client stamp `SupplyFromTown` and `SupplyAmount` on the truck, then publishes `WFBE_Client_PV_SupplyMissionStarted`. The server starts a tracking loop in `supplyMissionStarted.sqf:1-88` and completes via `WFBE_Server_PV_SupplyMissionCompleted`. Completion reads the vehicle vars at `supplyMissionCompleted.sqf:9-28`, rewards side supply through `ChangeSideSupply`, clears the source/amount vars and broadcasts the completion message. The player's personal cash/score path is in the client completion message, not the server completion handler.

PR #1 adds `SupplyByHeli` and additional heli/cash-run reward branches on top of this trust model; keep those branch-only mechanics scoped to [Current supply helicopter PR](Current-Work-Supply-Helicopters-PR1) and [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook).

That flow is important, but it should stay with `supply-mission-authority-cleanup` rather than being bundled into the first economy patch.

## First Implementation Sequence

### 1. Patch side-supply arithmetic and temp-channel validation

Files:

- `Common/Functions/Common_ChangeSideSupply.sqf`
- `Server/Functions/Server_ChangeSideSupply.sqf`

Patch shape:

```sqf
_change = _currentSupply + _amount;
if (_change < 0) then {_change = 0};
if (_change > _maxSupplyLimit) then {_change = _maxSupplyLimit};
```

Also validate the direct temp channel:

- west handler accepts only `_side == west`;
- east handler accepts only `_side == east`;
- reject malformed `_amount` or `_side` values with one compact `WARNING`;
- reject side/channel mismatches, not just negative amounts;
- keep positive rewards and normal spend behavior unchanged.
- treat negative deltas as valid only after the flow itself has been authorized; the first clamp patch should not become the whole economy authority story.

Why first: this is the smallest source-backed exploit fix. It does not solve who is allowed to mutate supply, but it prevents overspend from becoming a windfall while future authority work is designed.

Validation:

- Source-only: both common and server copies no longer use `_currentSupply - _amount` for the negative floor.
- Dedicated smoke: normal town income still raises supply; normal construction/upgrade supply spend lowers supply; overspend floors at zero.
- Negative smoke: forged temp channel with `_side` mismatching its channel no-ops and logs once.

### 2. Migrate upgrades to server-owned acceptance/debit

Files:

- `Client/GUI/GUI_UpgradeMenu.sqf`
- `Server/PVFunctions/RequestUpgrade.sqf`
- `Server/Functions/Server_ProcessUpgrade.sqf`

Patch shape:

- Keep the client menu affordability/dependency checks for feedback only.
- Send requester context, not just side/id/level. For example, include `player` and `clientTeam`, then let the server derive side/commander status from server-known objects as far as Arma 2 OA allows.
- On the server, reject if:
  - requester/team is null or not on the claimed side;
  - requester team is not the commander team;
  - side is already upgrading;
  - requested id or level is out of range;
  - requested level is not the current server-held level;
  - dependencies are not met;
  - commander funds or side supply are insufficient.
- Debit funds/supply on the server only after acceptance.
- Preserve the existing `upgrade-started`, sync wait and `upgrade-complete` broadcasts.

Why second: there is already a PVF handler and server process, so this is smaller than player-buy authority and more coherent than trying to patch every client-local support action first.

Validation:

- Valid commander upgrade still starts and completes.
- Non-commander request rejects.
- Wrong-side, bad id, skipped dependency and insufficient funds/supply reject.
- Hosted and dedicated paths both preserve upgrade-running UI state.

### 3. Migrate construction and defense debit/acceptance

Files:

- `Client/Module/CoIn/coin_interface.sqf`
- `Server/PVFunctions/RequestStructure.sqf`
- `Server/PVFunctions/RequestDefense.sqf`

Patch shape:

- Keep preview colors and local affordance.
- Move final debit and acceptance into the server handler.
- Include requester context and let the server derive commander/side.
- Recompute class allowlist, cost, base area, HQ/deployed state, direction/position sanity and manned-defense permission.
- On acceptance, server debits funds/supply and executes construction/defense.
- On rejection, server logs compactly and the client shows a failure message if practical.

Validation:

- Valid HQ undeploy/deploy and one non-HQ structure still work.
- Valid defense still works.
- Wrong-side, unaffordable, out-of-base, bad class and non-commander requests reject.
- Existing side messages and base-area availability do not double-decrement.

### 4. Defer player factory buys until locality design is approved

Do not try to hide DR-14 inside a small economy patch. The live path creates units and vehicles from the client. A proper server-authority version needs a request/acceptance/rollback model that accounts for factory queues, buyer group locality, vehicle locality, AI ownership, destroyed factories, disconnects and crew creation.

Interim posture:

- document player buys as client-authoritative;
- if public-server hardening is required before redesign, design BattlEye `scripts.txt` constraints for client `createUnit`/`createVehicle` separately from `publicvariable.txt`;
- do not claim PVF dispatcher hardening or side-supply clamp makes player buys safe.

## Boundary Notes

This first-cut does not replace:

- [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook): dispatcher lookup hardening is still prerequisite foundation.
- [Attack-wave authority playbook](Attack-Wave-Authority-Playbook): `ATTACK_WAVE_INIT` is a direct publicVariable channel with its own server recomputation shape.
- `supply-mission-authority-cleanup`: supply mission cargo/reward trust and PR #1 helicopter reward behavior need a dedicated logistics pass.
- BattlEye owner decision: the repo still should not be described as public-server hardened without confirming production BEpath or adding real filters.

## Handoff

Future code owner:

1. Implement side-supply clamp/validation as the first economy hardening branch, e.g. `hardening/side-supply-clamp`.
2. Run source-only checks, then hosted/dedicated supply spend/reward smokes.
3. Record the validation in [Testing workflow](Testing-Debugging-And-Release-Workflow) terms.
4. Only then migrate upgrades and construction as separate branches. Do not bundle player-buy locality redesign into the clamp patch.
5. After mission edits, run `Tools/LoadoutManager` to propagate generated mission changes.

Codex/Claude follow-up:

- Review whether `Common_ChangeSideSupply.sqf` can be split into a server-local mutation helper plus a client request helper. That would reduce future direct-PV confusion.
- If owner wants public-server hardening before economy redesign, create a BattlEye posture page or filter-design handoff that covers both `publicvariable.txt` and `scripts.txt`.

## Continue Reading

Previous: [Server authority map](Server-Authority-Migration-Map) | Next: [Hardening roadmap](Hardening-Implementation-Roadmap)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
