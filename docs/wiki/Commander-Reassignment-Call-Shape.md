# Commander Reassignment Call Shape

Status: branch-split. Current stable `origin/master@f8a76de34` / `origin/claude/b74.1-aicom@f8a76de34`, current B69 `origin/claude/b69@8d465fce` and adjacent B74 `origin/claude/b74-aicom-spend@b23f557f` have the DR-15 helper unpacking fix in the maintained Chernarus and Vanilla roots, but docs/source `HEAD@60c35c05` and current stable/B74.1/B69/B74 full modded forks still carry the old helper shape. Duplicate reassignment notifications, visible-name UI targeting, requester authority and smoke remain open.

All source paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

## What To Read

- `Client/GUI/GUI_Commander_VoteMenu.sqf`
- `Common/Init/Init_PublicVariables.sqf`
- `Server/PVFunctions/RequestNewCommander.sqf`
- `Server/Functions/Server_AssignNewCommander.sqf`
- `Common/Functions/Common_GetSideLogic.sqf`
- [Feature status register](Feature-Status-Register)
- [Public variable channel index](Public-Variable-Channel-Index)

## Current Flow

Manual commander reassignment starts in the commander vote menu:

```sqf
["RequestNewCommander", [side group player, _voted_commander]] Call WFBE_CO_FNC_SendToServer;
```

`RequestNewCommander` is a registered server PVF command. `Init_PublicVariables.sqf` includes it in the server-bound list and builds the `SRVFNCRequestNewCommander` compile/handler registration. `Server_HandlePVF.sqf` then spawns the registered function with the payload array.

Inside `Server/PVFunctions/RequestNewCommander.sqf`, the payload is read correctly:

```sqf
_side = _this select 0;
_assigned_commander = _this select 1;
...
[_side, _assigned_commander] Spawn WFBE_SE_FNC_AssignForCommander;
```

The docs branch snapshot still unpacks the helper payload incorrectly:

```sqf
_side = _this;
_commander = _this select 1;
```

Current stable `origin/master@f8a76de34` / `origin/claude/b74.1-aicom@f8a76de34`, current B69 `origin/claude/b69@8d465fce` and adjacent B74 `origin/claude/b74-aicom-spend@b23f557f` fix the maintained-root helper unpacking:

```sqf
_side = _this select 0;
_commander = _this select 1;
```

`Common_GetSideLogic.sqf` expects a real `SIDE` value and otherwise falls back to `objNull`. On old-shape targets, passing the whole array as `_side` means helper-side side-logic work and notification routing use an invalid side value. On current stable/current B74.1/current B69/B74 maintained roots, the helper-side destination is valid, so the remaining defects are the duplicate `new-commander-assigned` senders, visible-name UI selection and requester-authority checks.

## Current Branch Matrix

Branch route `commander-vote-reassignment-current-b741-b742-queue-refresh-2026-06-23` rechecked maintained Chernarus and Vanilla roots after `git fetch --all --prune` on 2026-06-23. Docs/source `HEAD@60c35c05` is unchanged from `337ed166` and `b44aaaf8` for the checked reassignment paths and still has the old helper unpacking. Current stable is `origin/master@f8a76de34`, the same commit as `origin/claude/b74.1-aicom@f8a76de34`; B74.2 is `origin/claude/b74.2-aicom@d472da6a`. The scoped `0139a3468609..origin/master` and `origin/master..origin/claude/b74.2-aicom` diffs touch no maintained-root `RequestNewCommander.sqf`, `Server_AssignNewCommander.sqf` or `GUI_Commander_VoteMenu.sqf` files. Current B69 is `origin/claude/b69@8d465fce`; adjacent B74 is `origin/claude/b74-aicom-spend@b23f557f`. Checked path deltas `origin/claude/b69..origin/claude/b74-aicom-spend`, `0a1ccb4d..origin/claude/b74-aicom-spend` and `b8530477..origin/claude/b74-aicom-spend` are empty for the maintained reassignment paths. Current origin exposes no live `release/*`, `feat/*commander*`, `feat/*vote*`, `feat/*reassign*`, `feature/*commander*`, `feature/*vote*` or `feature/*reassign*` heads, so `a96fdda2` and `c20ce153` are historical evidence unless those refs are restored.

| Root / branch | Helper call shape | Remaining commander reassignment risks | Practical meaning |
| --- | --- | --- | --- |
| Docs/source `HEAD@60c35c05` Chernarus and maintained Vanilla | Still broken and unchanged from `337ed166` / `b44aaaf8` for checked reassignment paths: `Server_AssignNewCommander.sqf:3-5` uses `_side = _this` and `_commander = _this select 1`. | Vote menu resolves by visible leader name (`GUI_Commander_VoteMenu.sqf:33-46`); `RequestNewCommander.sqf:14` and helper `:9` both send `new-commander-assigned`. | Patch-ready on the docs/source snapshot; not current-stable/B69/B74 proof. |
| Current stable `origin/master@f8a76de34` / B74.1 / B74.2 `origin/claude/b74.2-aicom@d472da6a` Chernarus and maintained Vanilla | Helper unpacking is fixed: `_side = _this select 0`, `_commander = _this select 1` (`Server_AssignNewCommander.sqf:4-5`). This reassignment path is unchanged from `0139a3468609` to `f8a76de34`, and B74.2 has no checked reassignment-path delta over current stable. | UI still selects by leader-name text, and both `RequestNewCommander.sqf:14` plus helper `:10` still send `new-commander-assigned`. | Current stable/B74.1/B74.2 is source-present for DR-15 helper shape, but not release-complete for reassignment. |
| Current B69/B74 `origin/claude/b69@8d465fce` / `origin/claude/b74-aicom-spend@b23f557f` Chernarus and maintained Vanilla | Matches current stable/B74.1 helper shape: `_side = _this select 0`, `_commander = _this select 1` (`Server_AssignNewCommander.sqf:4-5`). B69..B74 and older-B69-to-B74 reassignment path deltas are empty for checked commander reassignment paths. | UI still selects by leader-name text, and both `RequestNewCommander.sqf:14` plus helper `:10` still send `new-commander-assigned`. | Do not reopen helper unpacking on B69/B74 maintained roots; keep notification ownership, row identity and requester authority open. |
| Current stable/B74.1/B69/B74 full modded forks Napf/Eden/Lingor | Still old-shape: `_side = _this` at `Modded_Missions/*/Server/Functions/Server_AssignNewCommander.sqf:3`. | Same duplicate sender and visible-name UI shape where the files exist. | Do not claim modded propagation; current tooling does not actively maintain these forks. |
| Miksuu upstream `b8389e748243` Chernarus and maintained Vanilla | Same fixed helper unpacking as current stable/B74.1/B69/B74 at `Server_AssignNewCommander.sqf:4-5`. | Same visible-name selector and duplicate sender shape. | Upstream is a helper-fix source, not a complete reassignment fix. |
| `origin/perf/quick-wins@0076040f` Chernarus and maintained Vanilla | Same fixed helper unpacking as current stable/B74.1/B69/B74 at `Server_AssignNewCommander.sqf:4-5`. | Same visible-name selector and duplicate sender shape. | Perf branch does not close reassignment UI/notification/authority risks. |
| Historical release commit `a96fdda2` Chernarus and maintained Vanilla | Same fixed helper unpacking as current stable/B74.1/B69/B74 at `Server_AssignNewCommander.sqf:4-5`; no live `origin/release/*` head existed during this refresh. | Same visible-name selector and duplicate sender shape. | Treat as historical partial cleanup until a release head is restored or rechecked. |
| Historical AI-commander commit `c20ce153` Chernarus and maintained Vanilla | Same fixed helper unpacking as current stable/B74.1/B69/B74 at `Server_AssignNewCommander.sqf:4-5`; no live `origin/feat/*commander*` head existed during this refresh. | Same visible-name selector and duplicate sender shape; AI commander supervisor behavior is separate. | Do not route reassignment closure through AI commander revival without the UI/notification smoke here. |

This means future code work can either port the fixed helper shape from stable/B69/B74/historical fixed refs or implement it directly, but it still needs one notification owner and a row-value/team-identity selector before the reassignment path is clean.

## Evidence

| File | Evidence |
| --- | --- |
| `Client/GUI/GUI_Commander_VoteMenu.sqf:46` | Sends `["RequestNewCommander", [side group player, _voted_commander]]`. |
| `Client/GUI/GUI_Commander_VoteMenu.sqf:33-46` | Resolves the selected commander by visible leader name text before sending. |
| Current stable/B74.1 `Common/Init/Init_PublicVariables.sqf:12-13,29,60-62` | Lines 12-13 add `RequestCommanderVote` and `RequestNewCommander` to the server PV list; line 29 seals `_serverCommandPV`; lines 60-62 compile `SRVFNC*` handlers and register value-only `addPublicVariableEventHandler` for each server PV. |
| `Server/Functions/Server_HandlePVF.sqf:14` | Spawns PVF parameters into the compiled handler. |
| `Server/PVFunctions/RequestNewCommander.sqf:3,12-14` | Reads `_side = _this select 0`, sets `wfbe_commander`, spawns `WFBE_SE_FNC_AssignForCommander` with `[_side, _assigned_commander]`, and sends a `new-commander-assigned` message. Current stable/B74.1/current B69/B74 keep the same caller notification at `:14`. |
| Docs branch `Server/Functions/Server_AssignNewCommander.sqf:3-5` | Uses `_side = _this` while also indexing `_this select 1`. |
| Current stable/B74.1/current B69/B74 `Server/Functions/Server_AssignNewCommander.sqf:4-5,10` | Uses `_side = _this select 0`, `_commander = _this select 1`, then sends a second `new-commander-assigned` message. |
| Current stable/B74.1/current B69/B74 `Modded_Missions/*/Server/Functions/Server_AssignNewCommander.sqf:3-4` | Napf, Eden and Lingor still use `_side = _this`, `_commander = _this select 1`. |
| `Common/Functions/Common_GetSideLogic.sqf:7` | Side-logic lookup only handles actual side values and defaults to `objNull`. |

## Likely Impact

On old-shape targets, the assignment itself probably lands because `RequestNewCommander.sqf` sets the side-logic `wfbe_commander` variable before calling the helper. The broken helper still matters there:

- AI commander shutdown/reset logic resolves side logic from an array and can miss the intended side.
- The helper's `new-commander-assigned` client notification uses the bad side destination.
- The caller also sends a correct `new-commander-assigned` notification.

On current stable/B74.1/current B69/B74 maintained roots, the helper-side routing now reaches the intended side, but clients can receive duplicate commander messages because both the caller and helper send `new-commander-assigned`.

The client selector also needs a small identity cleanup while this flow is open. `GUI_Commander_VoteMenu.sqf` stores the team index in the list row, but on submit it reads `lnbText` and matches `name leader _x`. Duplicate player names or a name change while the dialog is open can select the wrong team or fail the intended lookup. Use the stored row value/team index when patching the reassignment flow.

## Patch Shape

For old-shape targets, patch source Chernarus first:

```sqf
// Server/Functions/Server_AssignNewCommander.sqf
_side = _this select 0;
_commander = _this select 1;
```

Then remove or suppress one `new-commander-assigned` send. Prefer keeping notification in `AssignNewCommander` if the helper is intended to own assignment side effects; otherwise keep it in `RequestNewCommander` and remove it from the helper. Do not leave both after the side fix.

For current stable/B74.1/current B69/B74 maintained roots, do not reopen the helper unpacking edit. The remaining reassignment cleanup is notification ownership, row-value/team-identity selection and requester authority. Do not combine this with PVF dispatcher hardening unless the branch is explicitly about networking authority.

## Generated And Modded Copies

Current stable/B74.1/current B69/B74 maintained Chernarus and Vanilla Takistan roots match for the helper fix. Current stable/B74.1/current B69/B74 full modded Napf/Eden/Lingor copies still carry `_side = _this`; other modded folders are partial overlays and may not contain this helper.

Patch source Chernarus, then run `Tools/LoadoutManager` from a checkout with an ancestor folder literally named `a2waspwarfare` so Vanilla Takistan is generated from source. Treat modded full copies as a separate owner decision because the current generation/package path does not actively maintain them.

## Validation

Source-only:

- `Server_AssignNewCommander.sqf` uses `_this select 0` for `_side`.
- `GUI_Commander_VoteMenu.sqf` resolves the selected commander by row value/team identity, not visible name text.
- Exactly one `new-commander-assigned` message path remains for the reassignment.
- Generated Vanilla diff is inspected after LoadoutManager propagation.
- Modded forks are either regenerated from maintained source or explicitly excluded from any release/parity claim.

Arma smoke:

- Manual commander reassignment changes the commander for the intended side.
- The previous AI commander, if any, is stopped/reset for the intended side.
- Clients receive one reassignment message, not zero and not two.
- Commander vote fallback still works after reassignment.

## Agent Index Facts

```json
[
  {"fact":"commander_reassignment_docs_branch_old_shape","source":"docs/developer-wiki-index@60c35c05 Server_AssignNewCommander.sqf:3-5; RequestNewCommander.sqf:13-14; GUI_Commander_VoteMenu.sqf:33-46","summary":"The docs/source snapshot remains unchanged from 337ed166 and b44aaaf8 for checked reassignment paths and still has the old helper side argument, duplicate notification senders and visible-name commander selection."},
  {"fact":"commander_reassignment_current_stable_b741_b69_b74_partial_source_present","source":"origin/master@f8a76de34 / origin/claude/b74.1-aicom@f8a76de34, origin/claude/b69@8d465fce and origin/claude/b74-aicom-spend@b23f557f Server_AssignNewCommander.sqf:4-5,10; RequestNewCommander.sqf:13-14; GUI_Commander_VoteMenu.sqf:33-46","summary":"Current stable/B74.1/current B69/B74 Chernarus and maintained Vanilla fix the helper payload unpacking, but the UI still resolves by visible leader-name text and both caller/helper notification senders remain. Scoped diff 0139a3468609..f8a76de34 touches no maintained-root reassignment paths."},
  {"fact":"commander_reassignment_modded_fork_drift","source":"origin/master@f8a76de34 / origin/claude/b74.1-aicom@f8a76de34, origin/claude/b69@8d465fce and origin/claude/b74-aicom-spend@b23f557f Modded_Missions/*/Server/Functions/Server_AssignNewCommander.sqf:3-4","summary":"Current stable/B74.1/current B69/B74 full modded Napf/Eden/Lingor forks still use _side = _this; do not claim modded propagation from the maintained-root helper fix."}
]
```

## Continue Reading

Previous: [Feature status](Feature-Status-Register) | Next: [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas)

Main map: [Home](Home) | Fast path: [Public variable channel index](Public-Variable-Channel-Index) | Agent file: [`agent-feature-status.jsonl`](agent-feature-status.jsonl)
