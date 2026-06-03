# Current Work: Supply Helicopters PR #1

PR: <https://github.com/rayswaynl/a2waspwarfare/pull/1>

Branch: `feat/supply-helicopter`

Base: `master`

Status at original indexing: open, not draft, mergeable, no status checks reported by GitHub. A 2026-06-04 local branch recheck found `origin/feat/supply-helicopter` at head `262dc431`; the earlier line-by-line audit used `ffeea4c2`. PR web state was not re-verified here.

## Summary

PR #1's supply-heli feature path extends player-run supply missions from trucks to transport helicopters. The stable `master` flow is vehicle-object based on the server, so the supply-specific code expands client eligibility, action labels, upgrade gating, rewards and completion messaging.

Important merge caveat: the current local `origin/feat/supply-helicopter` diff against `origin/master` is not a narrow supply-only PR. At head `262dc431`, `git diff --shortstat origin/master..origin/feat/supply-helicopter` shows 82 changed files, 462 insertions and 2056 deletions across source Chernarus and Vanilla Takistan. The supply-heli lane is additive, but the branch also carries unrelated service-menu, Valhalla/low-gear, HC/static-defense, performance-audit and UI/resource deltas. Isolate or review those separately before using this branch as a merge baseline.

Propagation caveat: the supply-heli implementation is present in the Chernarus source mission on this PR branch, but not in maintained Vanilla Takistan. A branch grep for `SupplyByHeli`, `WFBE_C_SUPPLY_HELI_TYPES`, `WFBE_C_SUPPLY_HELI_ENABLED` and `wfbe_supply_killed_eh_set` under `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan` returned no hits; among supply/parameter paths, only Vanilla `Rsc/Parameters.hpp` appears in the diff. Run LoadoutManager or hand-review propagation before any Vanilla release claim.

## Current Head Drift

Current local head `262dc431` changes important mechanics from the older `ffeea4c2` audit:

- Supply helicopters are lobby-toggleable through `Rsc/Parameters.hpp:4-7`.
- Heli-specific gating now uses Aircraft Factory upgrade levels: `Client/Module/supplyMission/supplyMissionStart.sqf:21-29` denies heli loading until Aircraft Factory upgrade level 3.
- `Common/Init/Init_CommonConstants.sqf:172-173` adds load/unload timers, and `:176-180` records the "one supply helicopter per side" / Air 3 load / Air 4 cash-run intent.
- `Server/Module/supplyMission/supplyMissionCompleted.sqf:24-35` treats heli delivery at Air upgrade level 4 as a cash run, with commander-team tithe through `WFBE_CO_FNC_ChangeTeamFunds`.
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
- Supply helicopters require Aircraft Factory upgrade level 3 to load on current local head `262dc431`.
- Aircraft Factory upgrade level 4 converts heli deliveries into cash runs for the commander team on current local head `262dc431`.
- Air delivery gives the pilot +25 percent funds/score reward.
- Destroying a loaded enemy supply vehicle awards the killer's side 25 percent of cargo value.
- Buy menu highlights supply helicopters similarly to supply trucks.

## Line-By-Line Delta Audit

This audit was originally source-scoped to `origin/feat/supply-helicopter` at `ffeea4c2`; the 2026-06-04 `262dc431` head-drift note above supersedes its upgrade-level wording. Re-run the full table before merge approval. Paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

| File | Branch evidence | Delta | Review note |
| --- | --- | --- | --- |
| `Rsc/Parameters.hpp` | `:5-11` | Adds lobby parameter `WFBE_C_SUPPLY_HELI_ENABLED`, default enabled. | Chernarus branch has the toggle. Vanilla feature propagation still needs checking because the heli constants and runtime vars are absent from Vanilla on this branch. |
| `Common/Init/Init_CommonConstants.sqf` | `:169-178` | Adds reward/cash/interdiction multipliers, truck/heli/combined supply class lists, map-dependent heli classes and the feature toggle fallback. | Centralizes class lists. The comment explicitly says Takistan buy lists need verification. |
| `Client/Module/Skill/Skill_Apply.sqf` | older `ffeea4c2`: `:65,72` | Changes action label to `LOAD SUPPLIES` and allowed trucks or supply-heli classes once Supply upgrade >= 2. Current `262dc431` needs a refreshed line audit because load gating moved to Air upgrade level 3 in `supplyMissionStart.sqf:21-29`. | UI/action affordance only; server authority still depends on supply mission start/completion hardening. |
| `Client/Module/supplyMission/supplyMissionStart.sqf` | current `262dc431`: `:21-29`, `:54` | Recomputes truck/heli eligibility, shows an Aircraft Factory level-3 warning for locked supply helis and stamps `SupplyByHeli` alongside `SupplyFromTown`/`SupplyAmount`. | Still client-started and object-var based. Server-side class, cooldown, timer-interruption and source-town validation remain future hardening gates. |
| `Server/Module/supplyMission/supplyMissionStarted.sqf` | `:7,13-30,36-43` | Reads `SupplyByHeli`, adds a guarded `Killed` handler, awards interdiction through `ChangeSideSupply`, clears `SupplyAmount` after death and expands heli command-center scan to 400m with a 2D-distance check. | The old stacked-handler claim is stale. The guard is persistent, so repeated load/deliver/destroy cycles still need smoke and any future removal/re-arm behavior needs a handler-ID plan. |
| `Server/Module/supplyMission/supplyMissionCompleted.sqf` | current `262dc431`: `:24-35` | Reads `SupplyByHeli`, treats heli deliveries at Air upgrade >= 4 as cash runs and pays a commander-team tithe through `WFBE_CO_FNC_ChangeTeamFunds` when a commander group exists. | If no commander team exists, the cash-run branch has no side-supply fallback. Decide whether that pilot-only outcome is intended. |
| `Client/Module/supplyMission/supplyMissionCompletedMessage.sqf` | `:13-31` | Reads `_byHeli`/`_cashRun`, applies the air reward multiplier to pilot funds and score, and labels the completion as `HELI` or `truck`. | Personal reward remains client-side and score is still a `RequestChangeScore` PVF, so this does not solve economy authority. |
| `Client/Functions/Client_UIFillListBuyUnits.sqf` | `:102` | Colors supply heli classes like supply trucks in the buy list. | Uses the central heli list; safe UI affordance. |
| `Client/GUI/GUI_Menu_BuyUnits.sqf` | `:451-456` | Adds explanatory hint text for supply helicopters and separates ordinary lift helicopters from supply helicopters. | Text is hardcoded English, matching existing UI style but still localization debt. |

## Why The Server Flow Can Work

On `master`, server delivery already tracks a vehicle object and checks command-center proximity. The server completion code is not intrinsically truck-only. The PR carries a `SupplyByHeli` flag end-to-end to distinguish rewards and cargo behavior.

## Authority And Reward Notes

| Topic | Current reading |
| --- | --- |
| Start authority | Still client initiated. The client performs eligibility checks and writes object variables before the server tracking loop starts. |
| Completion authority | Server verifies proximity to a command center, then trusts vehicle state such as `SupplyAmount`, `SupplyFromTown` and PR #1's `SupplyByHeli`. |
| Cooldown | Still town-var based; the existing `lastSupplyMissionRun` / `LastSupplyMissionRun` casing mismatch remains a master and PR concern. |
| Cash runs | On current head `262dc431`, heli delivery at Air upgrade level 4 can route commander-tithe value to commander team funds when a commander exists. If no commander team exists, current PR code has no side-supply fallback; decide whether that pilot-only outcome is intended. |
| Interdiction | Destroying a loaded enemy supply vehicle pays a fraction of cargo value. Current branch sets `wfbe_supply_killed_eh_set` before adding the handler, so older unguarded-stacking wording is stale. Repeated load/deliver/destroy smoke is still required because the guard is persistent and no handler-ID removal/re-arm plan is documented. |
| Vanilla propagation | Not complete on this PR branch. | The Chernarus source mission contains the heli constants, `SupplyByHeli` flow and guarded handler; `git grep` found no equivalent symbols under maintained Vanilla Takistan. |

## Deferred Work

Autonomous AI-flown supply helicopters are intentionally deferred. The upstream AI supply truck path is incomplete: `AI_UpdateSupplyTruck.sqf` references missing `Server/FSM/supplytruck.fsm`, and the compile line is commented out on `master`.

## Suggested Review Focus

- Confirm action eligibility cannot be triggered by non-supply helicopters.
- Confirm upgrade gates match the single heli class list and Supply upgrade thresholds.
- Confirm loaded vehicle kill handler cannot double-award interdiction rewards.
- Confirm repeated loading of the same vehicle keeps the guarded interdiction `Killed` event handler idempotent.
- Confirm cash-run funds go to the intended commander/team account.
- Confirm action labels and completion messages still make sense for trucks and helicopters.
- Run LoadoutManager after merge to propagate Chernarus source changes to Takistan/generated targets.

## Claude Review Pass

Claude verified the review questions against the `master..feat/supply-helicopter` diff. Paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

| Question | Verdict | Evidence |
| --- | --- | --- |
| Can a non-supply helicopter trigger the action? | No. | `Client/Module/Skill/Skill_Apply.sqf` gates the action by truck class or supply-heli class plus upgrade level, and `supplyMissionStart.sqf` recomputes eligibility before loading. |
| Do upgrade gates match the class lists? | Superseded for current head. | Claude's original verdict was correct for older head `ffeea4c2`: `Init_CommonConstants.sqf:173-178` added `WFBE_C_SUPPLY_TRUCK_TYPES`, `WFBE_C_SUPPLY_HELI_TYPES` and `WFBE_C_SUPPLY_VEHICLE_TYPES`; `supplyMissionStart.sqf:21-22` gated heli loading at Supply upgrade >=2, while `supplyMissionCompleted.sqf:26-27` made heli deliveries cash runs at upgrade >=3. Current head `262dc431` moved heli load/cash-run semantics to Aircraft Factory upgrade 3/4 (`supplyMissionStart.sqf:21-29`, `supplyMissionCompleted.sqf:24-35`). |
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
