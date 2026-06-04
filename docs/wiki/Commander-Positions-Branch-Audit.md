# Commander Positions Branch Audit

This page deep-audits `origin/feat/commander-positions` as branch evidence, not shipped source truth.

## What this branch is

`origin/feat/commander-positions` head `560db61c` adds WDDM-authored commander-buildable defense positions and modular wall anchors to the source Chernarus mission. The useful feature is real, but the branch is not a clean construction-only branch:

- Head: `560db61c` (`fix(commander-positions): build composition at the placement point, not the map corner`)
- Feature commits: `98b15e97`, `b28b351f`, `560db61c`
- Merge base versus stable `origin/master`: `f5985b77`, older than stable head `2cdf5fb8`
- Diff versus `origin/master`: 83 files, +524/-2025
- Static check: `git diff --check origin/master..origin/feat/commander-positions` reports trailing whitespace in `Client/FSM/updateclient.sqf:124` and `Client/Init/Init_ProfileVariables.sqf:25` for both source Chernarus and maintained Vanilla

## Where it lives

The actual commander-position runtime is source-Chernarus only on this branch:

| Area | Source evidence |
| --- | --- |
| West build-menu anchors | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Config/Core_Structures/Structures_CO_US.sqf:168-174` |
| East build-menu anchors | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Config/Core_Structures/Structures_CO_RU.sqf:166-172` |
| Placeholder cost entries | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Config/Core/Core_CIV.sqf:174-177` |
| Server compile | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_Server.sqf:24-26` |
| Position templates and anchor map | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_Defenses.sqf:93-183` |
| Request routing | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/PVFunctions/RequestDefense.sqf:1-16` |
| Composition builder | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_ConstructPosition.sqf:1-66` |
| HQ/CoIn cleanup fix | Commit `b28b351f`, `Client/Module/CoIn/coin_interface.sqf:519-545` diff hunk |
| Debug hint removal | Commit `b28b351f`, `Server/Construction/Construction_StationaryDefense.sqf:2-13` diff hunk |

Important scope note: `git grep` finds no `Server_ConstructPosition`, no `WFBE_POSITION_TEMPLATE_MAP`, and no WDDM commander-position anchor registrations under `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan` on this branch. Vanilla is changed by the broad branch, but the new position feature is not actually propagated there.

## How it runs

The branch adds six commander-visible anchor classes to both side defense-name lists:

| Anchor | Intended buildable |
| --- | --- |
| `Land_Ind_BoardsPack1` | AA Position Large |
| `Land_Ind_BoardsPack2` | Artillery Position Large |
| `Land_WoodenRamp` | Mixed Position Large |
| `Paleta1` | Base Wall Straight |
| `Paleta2` | Base Wall Corner |
| `RoadBarrier_long` | Base Wall Gate |

`RequestDefense.sqf:8-16` still starts by checking whether the requested `_defenseType` is in the side's defense-name list. If the class is in `WFBE_POSITION_ANCHOR_NAMES`, it spawns `Server_ConstructPosition`; otherwise it calls the normal single-object `ConstructDefense` path.

`Server_ConstructPosition.sqf:18-36` resolves the anchor into a template variable through `WFBE_POSITION_TEMPLATE_MAP`. Faction-specific templates append `_WEST` or `_EAST`; neutral wall templates use the base name directly. The child objects then route through stock `ConstructDefense` at `Server_ConstructPosition.sqf:58-60`, so manned guns, artillery setup, scoring and prop placement follow the existing defense builder instead of duplicating manning logic.

## Map-corner placement bug and fix

Commit `560db61c` fixes an important branch-local bug. The builder originally used a spawned `Land_HelipadEmpty` origin plus `modelToWorld`, but the helper could be created at `[0,0,0]`, causing the whole composition to build near the map corner.

The current branch head avoids that helper. `Server_ConstructPosition.sqf:39-57` computes each child object's world position with direct rotation around the requested `_pos`, then calls `ConstructDefense` with the resulting `_worldPos` and `_worldDir`.

Runtime smoke must still prove the fix in Arma 2 OA:

- Place every anchor at the clicked point, not near `[0,0]`.
- Test headings `0`, `90`, `180` and `270`.
- Test flat terrain and slopes.
- Inspect whether wall gates align and AI/vehicles can still path through intended openings.

## What depends on it

The branch relies on existing construction/CoIn behavior:

- CoIn defense placement must still produce the `RequestDefense` payload.
- `ConstructDefense` owns the actual spawned object, manning, score and artillery behavior.
- Existing defense cost/build-menu logic must tolerate anchor placeholder classes.
- Static-defense HC delegation and cleanup still matter for crewed children because the branch deliberately routes through the stock defense builder.
- The feature crosses UI, commander construction, server defense creation and base pathing.

## What is risky or broken

| Risk | Evidence | Why it matters |
| --- | --- | --- |
| Not propagated to maintained Vanilla | No `Server_ConstructPosition`, `WFBE_POSITION_TEMPLATE_MAP` or WDDM anchor registrations under `Missions_Vanilla/[61-2hc]...` on branch grep | The branch touches Vanilla files, but that is not proof the feature works in Vanilla. |
| Broad unrelated branch baggage | `git diff --stat origin/master..origin/feat/commander-positions` is 83 files, +524/-2025; changed paths include Valhalla, AFK/profile, service/team/upgrade UI, `Server_HandleSpecial`, `Server_AssignNewCommander`, town AI and static-defense delegation | Merging the branch as a whole risks importing unrelated behavior changes with the construction feature. |
| Older base | Merge base is `f5985b77`, not current stable `2cdf5fb8` | Rebase/cherry-pick review must account for later stable changes. |
| DR-6 construction authority still applies | `RequestDefense.sqf:1-16` still trusts payload side/type/pos/dir/manned after only a class-membership check | The new anchor path expands the impact of forged construction requests unless server authority is fixed. |
| Branch whitespace | `git diff --check origin/master..origin/feat/commander-positions` reports four trailing-whitespace hits | Clean before merge/release. |
| CoIn display handler cleanup is branch-local | Commit `b28b351f` changes HQ-undeploy cleanup from `WF_COIN_DEH2/DEH3` to `WF_COIN_DEH3/DEH4` for mouse handlers | Needs UI smoke to prove no stale mouse handlers after HQ undeploy/redeploy. |
| Construction debug hint removal is branch-local | Commit `b28b351f` removes a `hintsilent` from `Construction_StationaryDefense.sqf` | Good cleanup, but it should be carried with any extracted position feature because compositions spawn many child objects. |

## Recommended promotion path

1. Extract the construction-position feature from unrelated branch baggage, or explicitly accept the branch as a broad gameplay/UI bundle.
2. Rebase or cherry-pick onto current stable `origin/master` and re-run `git diff --check`.
3. Decide whether maintained Vanilla should get the feature. If yes, propagate the actual `Server_ConstructPosition` runtime, template map and defense anchors, not only the incidental branch deltas.
4. Apply or schedule DR-6 construction authority hardening before public-server trust claims.
5. Run the branch-only smoke pack:
   - commander builds all six anchors;
   - placement point and orientation are correct;
   - manned guns crew and score normally;
   - artillery pieces still register as artillery where expected;
   - walls/gates are usable;
   - HQ undeploy/redeploy cleans CoIn handlers;
   - Chernarus and maintained Vanilla scope matches the owner decision.

## Development lesson

Branch names can lie by omission. A branch named for one feature can carry a large amount of unrelated gameplay/UI/runtime baggage. Future agents should use three labels before merge claims:

| Label | Required evidence |
| --- | --- |
| Feature payload | The narrow files and line refs that implement the named feature. |
| Branch baggage | Diff stat, changed path families and static-check failures outside the feature payload. |
| Propagation scope | Explicit Chernarus, maintained Vanilla and modded/generated-mission coverage. |

For this branch, the payload is Chernarus WDDM commander-position construction. The baggage is broad. The propagation scope is not complete for maintained Vanilla.

## Continue Reading

Previous: [Construction and CoIn systems atlas](Construction-And-CoIn-Systems-Atlas) | Next: [Pending owner decisions](Pending-Owner-Decisions)

Main map: [Home](Home) | Status row: [Feature status register](Feature-Status-Register) | Smoke gates: [Testing workflow](Testing-Debugging-And-Release-Workflow#branch-only-feature-smoke-pack)
