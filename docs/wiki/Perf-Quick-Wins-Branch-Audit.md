# Perf Quick Wins Branch Audit

This page deep-audits `origin/perf/quick-wins` as branch evidence, not stable-master source truth.

## What this branch is

`origin/perf/quick-wins` head `0076040f` is a compact Chernarus-only fix candidate. Despite the branch name, it is not only performance work: it combines server-loop cleanup, economy/factory correctness fixes, paratrooper marker revival plumbing and several small nil/off-by-one/runtime-error repairs.

- Head: `0076040f` (`fix: factory queue soft-lock, camp-bunker nil-code EH, unregistered paratrooper-marker PV`)
- Merge base versus stable `origin/master`: `2cdf5fb8`
- Diff versus `origin/master`: 18 files, +27/-27
- Scope: 18 files under `Missions/[55-2hc]warfarev2_073v48co.chernarus`
- Maintained Vanilla scope: no `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan` files are touched
- Static cleanup gate: `git diff --check origin/master..origin/perf/quick-wins` is clean

## Commit Breakdown

| Commit | Message | Files | Meaning |
| --- | --- | ---: | --- |
| `95481b37` | `perf: fix three harness-verifiable server bugs + drop duplicate compile block` | 4 | Mine cleaner leak, garbage collector duplicate trash handling, resource-update FPS feedback loop and duplicate server compile block. |
| `0a1e6165` | `fix: 11 harness-verifiable bugs (economy exploit, off-by-ones, wrong vars, condition inversions)` | 11 | Side-supply clamp, cargo-loop bounds, patrol loop conditions, camp flag side, kill-assist bounty type, WASP nil/off-by-one fixes. |
| `0076040f` | `fix: factory queue soft-lock, camp-bunker nil-code EH, unregistered paratrooper-marker PV` | 3 | DR-33a factory queue leak, camp-bunker nil-code killed EH and DR-2 paratrooper marker PV registration. |

## Where it Lives

| Area | Branch evidence |
| --- | --- |
| Factory queue cleanup | `Client/Functions/Client_BuildUnit.sqf:366-368` decrements `unitQueu` and `WFBE_C_QUEUE_<factory>` before the crewless-buy `exitWith` |
| Client paratrooper marker PV | `Common/Init/Init_PublicVariables.sqf:40` adds `HandleParatrooperMarkerCreation` to `_clientCommandPV` |
| Side-supply clamp, common sender | `Common/Functions/Common_ChangeSideSupply.sqf:25` floors negative `_change` at `0`, but still sends `_amount` through the direct temp PV |
| Side-supply clamp, server receiver | `Server/Functions/Server_ChangeSideSupply.sqf:12,36` floors negative `_change` at `0` for both west/east handlers |
| Duplicate server compile cleanup | `Server/Init/Init_Server.sqf:88` replaces the duplicate compile block with a note; earlier compiles remain at `:81-84` |
| Mine cleaner leak | `Server/FSM/cleaners/mines_cleaner.sqf:17` removes the `[mine,time]` pair with `mines = mines - [_x]` |
| Dead-object garbage collector | `Server/FSM/server_collector_garbage.sqf:17` honors `wfbe_trashed` as well as `wfbe_trashable` |
| Patrol exit conditions | `Server/FSM/server_patrols.sqf:26` and `Server/FSM/server_town_patrol.sqf:18` use `&&` instead of `||` so loops exit on game over or dead team |
| Camp capture flag side | `Server/FSM/server_town_camp.sqf:135` uses `_newSide` for the captured camp flag texture |
| Resource update interval | `Server/FSM/updateresources.sqf:74` sleeps `_ii` instead of shortening the income loop through `GetSleepFPS` |
| Camp-bunker killed EH | `Server/Functions/Server_HandleSpecial.sqf:235-236` removes the killed EH that called nonexistent `WFBE_SE_FNC_OnBuildingKilled` |
| Kill-assist bounty type | `Server/PVFunctions/RequestOnUnitKilled.sqf:92` uses `_killed_type` instead of undefined `_objectType` |
| Cargo loop bounds | `Common/Functions/Common_EquipBackpack.sqf:35,41` and `Common/Functions/Common_EquipVehicle.sqf:27,33,39` stop at `count(_items)-1` |
| WASP HQ repair nil default | `WASP/actions/Action_RepairMHQDepot.sqf:6` reads `cashrepaired` with default `false` |
| WASP base repair loop bounds | `WASP/baserep/viem.sqf:20,38` stops at `count baseb - 1` |
| WASP RPG base-protection loop bounds | `WASP/rpg_dropping/DropRPG.sqf:57` stops at `count _list - 1` |

## How it Runs

This branch does not add a new subsystem. It adjusts existing hot paths and handlers:

- client factory purchase completion (`Client_BuildUnit.sqf`);
- common/server side-supply mutation (`Common_ChangeSideSupply.sqf`, `Server_ChangeSideSupply.sqf`);
- common init PV registration (`Init_PublicVariables.sqf`);
- server loops for mines, dead objects, patrols, town camps and resource income;
- server support/special/kill handling;
- WASP utility actions.

The most important source discipline is that these fixes are still branch-only. Some line shapes overlap with docs/source propagated work elsewhere, but `origin/master` is not proof of these fixes, and `origin/perf/quick-wins` does not propagate them to maintained Vanilla Takistan.

## What Depends On It

- Economy and authority docs depend on the DR-22 clamp shape, but the broader DR-44 direct-PV trust problem remains open even if the clamp is accepted.
- Factory cleanup depends on the DR-33a queue-decrement shape; DR-33b random-token identity is not solved by this branch.
- Paratrooper marker docs depend on the client PV registration, but support smoke is still required before calling marker revival runtime-proven.
- Server performance docs depend on the distinction between deliberate lower-frequency loops and `GetSleepFPS` acceleration. This branch treats the resource income loop as a fixed interval.
- Vanilla release planning depends on hand propagation or a generator run; this branch is source-Chernarus only.

## What Is Risky Or Incomplete

| Risk | Evidence | Required gate |
| --- | --- | --- |
| Chernarus-only scope | `git diff --name-only origin/master..origin/perf/quick-wins -- Missions_Vanilla` returns no changed files | Decide and perform maintained Vanilla propagation before any Vanilla/release wording. |
| Clamp is not authority | `Common_ChangeSideSupply.sqf:25` still publishes `wfbe_supply_temp_<side>` with `_amount`; DR-44 remains a direct client-writable channel problem | Treat clamp as necessary but not sufficient; server-owned side-supply authority remains a separate owner decision. |
| Factory queue fix is partial | `Client_BuildUnit.sqf:366-368` fixes crewless-buy counter decrement; DR-33b token/random identity remains documented separately | Smoke crewless/crewed factory buys and keep token cleanup separate. |
| Resource interval change can alter economy pacing under low FPS | `updateresources.sqf:74` removes FPS-shortened resource ticks | Dedicated low-FPS/RPT smoke should confirm fewer broadcasts without unexpected economy starvation. |
| Branch comments are implementation notes | Many changed lines add long inline comments into SQF source | Review whether to keep, shorten or move comments before merging gameplay code. |
| Runtime proof not present | No Arma RPT/screenshot/test artifact is recorded for this branch | Run dedicated smoke for economy, factory queue, paratrooper markers, cleaners, camp repair and resource updates. |

## Promotion Gates

1. Decide merge strategy: cherry-pick high-confidence fixes, split by subsystem, or merge the branch as one repair batch.
2. Reconcile with docs/source propagated fixes so duplicate or conflicting patches are not applied twice.
3. Propagate maintained Vanilla deliberately or mark the branch Chernarus-only.
4. Smoke side-supply debit/overspend so debits never become credits.
5. Smoke crewless and crewed factory purchases until queue limits would previously soft-lock.
6. Smoke tactical paratrooper marker creation on hosted and dedicated clients.
7. Watch RPT while exercising mine cleanup, garbage collector, camp bunker repair/destruction, patrol loops, resource income, kill-assist bounty and WASP HQ/base/RPG actions.
8. Keep `git diff --check` clean after any cherry-pick/split.

## Development Lesson

Small fix branches still need a payload table. A branch named `perf/quick-wins` can carry security-adjacent economy clamps, networking registration, factory soft-lock fixes and WASP UI/action repairs. Future agents should classify each hunk by subsystem and propagation scope before treating the branch as "just performance."

## Continue Reading

- [Performance opportunity sweep](Performance-Opportunity-Sweep)
- [Factory queue cleanup](Factory-Queue-Counter-Token-Cleanup)
- [Paratrooper marker revival](Paratrooper-Marker-Revival)
- [Economy authority first cut](Economy-Authority-First-Cut)
- [Pending owner decisions](Pending-Owner-Decisions#branch-only-feature-promotion-decisions)
- [Testing workflow](Testing-Debugging-And-Release-Workflow#branch-only-feature-smoke-pack)
