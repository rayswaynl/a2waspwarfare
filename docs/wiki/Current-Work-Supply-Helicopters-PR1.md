# Current Work: Supply Helicopters PR #1

PR: <https://github.com/rayswaynl/a2waspwarfare/pull/1>

Branch: `feat/supply-helicopter`

Base: `master`

Status at original indexing: open, not draft, mergeable, no status checks reported by GitHub. A 2026-06-04 local branch recheck found `origin/feat/supply-helicopter` at head `262dc431`; the line-by-line source table below is refreshed against that historical head.

2026-06-23 ref status: PR #1 remains historical branch-review evidence: the older `gh pr view 1` check reported it `CLOSED`, unmerged, `feat/supply-helicopter` -> `master`, updated `2026-06-03T12:43:21Z`, and the current remote branch scan shows no live origin supply/heli/release head. Current live stable supply-heli/cash-run behavior is now documented in [Supply mission architecture](Supply-Mission-Architecture#current-branch-matrix) against current stable/B74.1 `origin/master@f8a76de34`, B74.2 `origin/claude/b74.2-aicom@21b62b04`, B69 and adjacent B74.

## Summary

PR #1's supply-heli feature path extends player-run supply missions from trucks to transport helicopters. The stable `master` flow is vehicle-object based on the server, so the supply-specific code expands client eligibility, action labels, upgrade gating, rewards and completion messaging.

Important merge caveat: the historical local `origin/feat/supply-helicopter` snapshot was not a narrow supply-only PR. At head `262dc431`, `git diff --shortstat origin/master..origin/feat/supply-helicopter` showed 82 changed files, 462 insertions and 2056 deletions across source Chernarus and Vanilla Takistan. The supply-heli lane was additive, but the branch also carried unrelated service-menu, Valhalla/low-gear, HC/static-defense, performance-audit and UI/resource deltas. Isolate or review those separately before using this branch as a merge baseline.

Propagation caveat: the supply-heli implementation is present in the Chernarus source mission on this PR branch, but not in maintained Vanilla Takistan. A branch grep for `SupplyByHeli`, `WFBE_C_SUPPLY_HELI_TYPES`, `WFBE_C_SUPPLY_HELI_ENABLED` and `wfbe_supply_killed_eh_set` under `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan` returned no hits; among supply/parameter paths, only Vanilla `Rsc/Parameters.hpp` appears in the diff. Run LoadoutManager or hand-review propagation before any Vanilla release claim.

## Current Head Drift

Current local head `262dc431` changes important mechanics from the older `ffeea4c2` audit:

- Supply helicopters are lobby-toggleable through `Rsc/Parameters.hpp:4-7`.
- Heli-specific gating now uses Aircraft Factory upgrade levels: `Client/Module/supplyMission/supplyMissionStart.sqf:21-29` denies heli loading until Aircraft Factory upgrade level 3.
- `Common/Init/Init_CommonConstants.sqf:172-173` adds load/unload timers, and `:176-180` records the "one supply helicopter per side" / Air 3 load / Air 4 cash-run intent.
- `Server/Module/supplyMission/supplyMissionCompleted.sqf:24-35` treats heli delivery at Air upgrade level 4 as a cash run, with commander-team tithe through `WFBE_CO_FNC_ChangeTeamFunds`.
- Current PR head writes `SupplyByHeli` at `supplyMissionStart.sqf:54` and reads it at `supplyMissionStarted.sqf:7` / `supplyMissionCompleted.sqf:24`, but completion only clears `SupplyAmount` and `SupplyFromTown` (`supplyMissionCompleted.sqf:40-41`). Current stable/B74.1 already clears `SupplyByHeli` after completion in source Chernarus at `supplyMissionCompleted.sqf:47` and maintained Vanilla at `:44`; B74.2 source Chernarus line-drifts that clear to `:50` while Vanilla remains `:44`. Preserve or port that line if the historical PR branch is revived.
- Maintained Vanilla still has no `SupplyByHeli`, `WFBE_C_SUPPLY_HELI_TYPES`, `WFBE_C_SUPPLY_HELI_ENABLED` or `wfbe_supply_killed_eh_set` hits on this branch, so any Vanilla release claim needs propagation first.

## Supply-Heli Core Files

- `Client/Functions/Client_UIFillListBuyUnits.sqf`
- `Client/Module/Skill/Skill_Apply.sqf`
- `Client/Module/supplyMission/supplyMissionCompletedMessage.sqf`
- `Client/Module/supplyMission/supplyMissionStart.sqf`
- `Common/Init/Init_CommonConstants.sqf`
- `Rsc/Parameters.hpp`
- `Server/Module/supplyMission/supplyMissionCompleted.sqf`
- `Server/Module/supplyMission/supplyMissionStarted.sqf`

## Branch-Wide Delta Caveat

The branch-wide diff also includes non-supply changes. Examples from `origin/master..origin/feat/supply-helicopter`:

- `Client/Functions/Client_WatchdogCommandBarDeadUnits.sqf` is deleted.
- `Client/GUI/GUI_Menu_Service.sqf` has a large service-menu simplification/reversion.
- `Client/Module/Valhalla/*` and `Common/Init/Init_Unit.sqf` change low-gear / high-climbing behavior.
- `Common/Functions/Common_PerformanceAudit.sqf` changes the default audit-enabled behavior.
- `Server/Functions/Server_HandleSpecial.sqf`, static-defense delegation files and UI/resources also change.

Treat these as branch hygiene / merge-scope review items, not evidence for the player-run supply-heli feature itself.

## Mechanics From The PR

- SpecOps players can buy transport helicopters and use `LOAD SUPPLIES`.
- WEST examples include CH-47F/UH-60M class families already present in lift vehicle lists.
- EAST examples include Mi-17 family transports.
- Supply helicopters require Aircraft Factory upgrade level 3 to load on historical PR head `262dc431`.
- Aircraft Factory upgrade level 4 converts heli deliveries into cash runs for the commander team on historical PR head `262dc431`.
- Air delivery gives the pilot +25 percent funds/score reward.
- Destroying a loaded enemy supply vehicle awards the killer's side 25 percent of cargo value.
- Buy menu highlights supply helicopters similarly to supply trucks.

## Line-By-Line Delta Audit

This table is refreshed against `origin/feat/supply-helicopter` head `262dc431`. Older `ffeea4c2` review notes remain useful only where explicitly marked historical. Paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

| File | Branch evidence | Delta | Review note |
| --- | --- | --- | --- |
| `Rsc/Parameters.hpp` | `:4-10` | Adds lobby parameter `WFBE_C_SUPPLY_HELI_ENABLED`, default enabled. | Chernarus branch has the toggle. Vanilla feature propagation still needs checking because the heli constants and runtime vars are absent from Vanilla on this branch. |
| `Common/Init/Init_CommonConstants.sqf` | `:168-180` | Adds reward/cash/interdiction multipliers, heli load/unload timers, truck/heli/combined supply class lists, map-dependent heli classes and the feature toggle fallback. | Centralizes class lists. The comment explicitly says Takistan buy lists need verification. |
| `Client/Module/Skill/Skill_Apply.sqf` | `:62-72` | Adds `LOAD SUPPLIES`; trucks are always eligible, and supply heli action visibility requires the cursor target to be in `WFBE_C_SUPPLY_HELI_TYPES` and Aircraft Factory upgrade `WFBE_UP_AIR >= 3`. | UI/action affordance only; server authority still depends on supply mission start/completion hardening. |
| `Client/Module/supplyMission/supplyMissionStart.sqf` | `:16-60` | Recomputes vehicle type, Air upgrade level, truck/heli eligibility, level-3 denial message, timed heli load and object vars `SupplyFromTown`, `SupplyByHeli`, `SupplyAmount`. | Still client-started and object-var based. Server-side class, cooldown, timer-interruption and source-town validation remain future hardening gates. |
| `Server/Module/supplyMission/supplyMissionStarted.sqf` | `:7-30`, `:42-60`, `:93-95` | Reads `SupplyByHeli`, adds a guarded `Killed` handler, awards interdiction through `ChangeSideSupply`, clears `SupplyAmount` after death, expands heli command-center scan to 400m, uses 2D distance and requires timed unload dwell. | The old stacked-handler claim is stale. The guard is persistent, so repeated load/deliver/destroy cycles still need smoke and any future removal/re-arm behavior needs a handler-ID plan. |
| `Server/Module/supplyMission/supplyMissionCompleted.sqf` | `:24-41` | Reads `SupplyByHeli`, treats heli deliveries at Air upgrade >= 4 as cash runs, pays commander-team tithe through `WFBE_CO_FNC_ChangeTeamFunds` when a commander group exists, and clears `SupplyAmount`/`SupplyFromTown`. | On the historical PR head, if no commander team exists, the cash-run branch has no side-supply fallback and `SupplyByHeli` is not cleared on completion. Current stable/B74-shaped refs already clear it; preserve that behavior if reviving this branch. |
| `Client/Module/supplyMission/supplyMissionCompletedMessage.sqf` | `:10-32` | Reads `_byHeli`/`_cashRun`, applies the air reward multiplier to pilot funds and score, and labels the completion as `HELI` or `truck`. | Personal reward remains client-side and score is still a `RequestChangeScore` PVF, so this does not solve economy authority. |
| `Client/Functions/Client_UIFillListBuyUnits.sqf` | `:102` | Colors supply heli classes like supply trucks in the buy list. | Uses the central heli list; safe UI affordance. |
| `Client/GUI/GUI_Menu_BuyUnits.sqf` | `:451-456` | Adds explanatory hint text for supply helicopters and separates ordinary lift helicopters from supply helicopters. | Text is hardcoded English, matching existing UI style but still localization debt. |

## Why The Server Flow Can Work

On `master`, server delivery already tracks a vehicle object and checks command-center proximity. The server completion code is not intrinsically truck-only. The PR carries a `SupplyByHeli` flag end-to-end to distinguish rewards and cargo behavior.

## Authority And Reward Notes

| Topic | Current reading |
| --- | --- |
| Start authority | Still client initiated. The client performs eligibility checks and writes object variables before the server tracking loop starts. |
| Completion authority | Server verifies proximity to a command center, then trusts vehicle state such as `SupplyAmount`, `SupplyFromTown` and PR #1's `SupplyByHeli`. |
| Cooldown | Still town-var based; the `lastSupplyMissionRun` / `LastSupplyMissionRun` casing mismatch was fixed in master (XR4 in `Common/Init/Init_Town.sqf`); confirm the fix is also present on this PR branch before merge. |
| Cash runs | On current head `262dc431`, heli delivery at Air upgrade level 4 can route commander-tithe value to commander team funds when a commander exists. If no commander team exists, current PR code has no side-supply fallback; decide whether that pilot-only outcome is intended. |
| Interdiction | Destroying a loaded enemy supply vehicle pays a fraction of cargo value. Current branch sets `wfbe_supply_killed_eh_set` before adding the handler, so older unguarded-stacking wording is stale. Repeated load/deliver/destroy smoke is still required because the guard is persistent and no handler-ID removal/re-arm plan is documented. |
| State cleanup | Historical PR head completion clears `SupplyAmount` and `SupplyFromTown` but not `SupplyByHeli`. Current stable/B74-shaped refs clear all three. If reviving the PR branch, keep the stable clear-on-completion line instead of reintroducing retained heli state. |
| Vanilla propagation | Not complete on this PR branch. The Chernarus source mission contains the heli constants, `SupplyByHeli` flow and guarded handler; `git grep` found no equivalent symbols under maintained Vanilla Takistan. |

## Deferred Work

Autonomous AI-flown supply helicopters are intentionally deferred. The upstream AI supply truck path is incomplete: `AI_UpdateSupplyTruck.sqf` references missing `Server/FSM/supplytruck.fsm`, and the compile line is commented out on `master`.

## Suggested Review Focus

- Confirm action eligibility cannot be triggered by non-supply helicopters.
- Confirm upgrade gates match the single heli class list and Aircraft Factory upgrade thresholds.
- Confirm loaded vehicle kill handler cannot double-award interdiction rewards.
- Confirm repeated loading of the same vehicle keeps the guarded interdiction `Killed` event handler idempotent.
- Confirm cash-run funds go to the intended commander/team account.
- Confirm the historical PR branch preserves the current stable/B74-shaped `SupplyByHeli` clear-on-completion behavior before merge.
- Confirm action labels and completion messages still make sense for trucks and helicopters.
- Run LoadoutManager after merge to propagate Chernarus source changes to Takistan/generated targets.

## Claude Review Pass

Claude verified the review questions against the `master..feat/supply-helicopter` diff. Paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

| Question | Verdict | Evidence |
| --- | --- | --- |
| Can a non-supply helicopter trigger the action? | No. | `Client/Module/Skill/Skill_Apply.sqf` gates the action by truck class or supply-heli class plus upgrade level, and `supplyMissionStart.sqf` recomputes eligibility before loading. |
| Do upgrade gates match the class lists? | Superseded for historical head. | Claude's original verdict was correct for older head `ffeea4c2`: `Init_CommonConstants.sqf:173-178` added `WFBE_C_SUPPLY_TRUCK_TYPES`, `WFBE_C_SUPPLY_HELI_TYPES` and `WFBE_C_SUPPLY_VEHICLE_TYPES`; `supplyMissionStart.sqf:21-22` gated heli loading at Supply upgrade >=2, while `supplyMissionCompleted.sqf:26-27` made heli deliveries cash runs at upgrade >=3. Historical head `262dc431` moved heli load/cash-run semantics to Aircraft Factory upgrade 3/4 (`supplyMissionStart.sqf:21-29`, `supplyMissionCompleted.sqf:24-35`). |
| Can interdiction double-award? | No for one death. | The guarded `Killed` EH awards `round(_amt * 0.25)` only while `SupplyAmount` is positive and immediately sets `SupplyAmount` to `0`, so repeated handler invocations see zero. |
| Do repeated reloads stack handlers? | Not in the current PR branch. | `supplyMissionStarted.sqf:13-30` sets `wfbe_supply_killed_eh_set` before adding the `Killed` EH. This guard should still be smoke-tested across repeated load/deliver/destroy cycles before merge. |
| Do cash-run funds reach the intended account? | Partially. | Heli cash runs move the commander tithe to commander team funds through `ChangeTeamFunds` when `GetCommanderTeam` returns a group (`supplyMissionCompleted.sqf:29-35`). If no commander team exists, this branch does not fall back to side supply; the pilot still receives the client-side reward. Decide whether that no-commander drop is intended before merge. |
| Do messages still read sensibly? | Yes. | Labels use `LOAD SUPPLIES`; messages distinguish `"HELI"` and `"truck"` and append `" (cash run)"` where appropriate. |

### New Constants Introduced By PR #1

`Init_CommonConstants.sqf:173-178` gains `WFBE_C_SUPPLY_TRUCK_TYPES`, `WFBE_C_SUPPLY_HELI_TYPES` and `WFBE_C_SUPPLY_VEHICLE_TYPES`. This centralizes class lists that were previously duplicated in action and mission-start logic.

### Confirmed Follow-Up Risks

The current PR branch already uses `wfbe_supply_killed_eh_set` before adding the interdiction `Killed` handler. Keep that guard, smoke repeated load/deliver/destroy cycles, and do not add future side effects to the handler without an explicit handler-ID/removal plan.

The current PR branch also has branch-wide non-supply drift. Review or isolate the unrelated changes before merging supply helicopters, especially the deleted command-bar watchdog, service-menu simplification, Valhalla/low-gear changes, static-defense/HC edits and performance-audit default change.

Use [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook) before turning PR #1 into baseline behavior.

## Continue Reading

Previous: [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook) | Next: [AI/headless/performance](AI-Headless-And-Performance)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
