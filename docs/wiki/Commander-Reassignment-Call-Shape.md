# Commander Reassignment Call Shape

Status: confirmed correctness bug, patch-ready. This page owns the source evidence and safe patch shape for DR-15 / `commander-reassignment-call-shape`.

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

The helper then unpacks the same payload incorrectly:

```sqf
_side = _this;
_commander = _this select 1;
```

`Common_GetSideLogic.sqf` expects a real `SIDE` value and otherwise falls back to `objNull`. Passing the whole array as `_side` means helper-side side-logic work and notification routing use an invalid side value.

## Current Branch Matrix

Branch route `commander-vote-reassign-branch-scope-route` rechecked maintained Chernarus and Vanilla roots on 2026-06-14 after stable `origin/master` sat at `cf2a6d6a`, Miksuu at `b8389e74` and release at `a96fdda2`.

| Root / branch | Helper call shape | Remaining commander reassignment risks | Practical meaning |
| --- | --- | --- | --- |
| Docs checkout `e2c9f6ed` Chernarus and maintained Vanilla | Still broken: `Server_AssignNewCommander.sqf:3-5` uses `_side = _this` and `_commander = _this select 1`. | Vote menu resolves by visible leader name (`GUI_Commander_VoteMenu.sqf:33-46`); `RequestNewCommander.sqf:14` and helper `:9` both send `new-commander-assigned`. | Patch-ready and source-unpatched on the docs branch. |
| Stable `origin/master` `cf2a6d6a` Chernarus and maintained Vanilla | Helper unpacking is fixed: `_side = _this select 0`, `_commander = _this select 1` (`Server_AssignNewCommander.sqf:4-5`). | UI still selects by leader-name text, and both `RequestNewCommander.sqf:14` plus helper `:10` still send `new-commander-assigned`. | Stable fixes the DR-15 call-shape bug, but not duplicate-message, UI identity or requester-authority cleanup. |
| Miksuu upstream `b8389e74` Chernarus and maintained Vanilla | Same fixed helper unpacking as stable at `Server_AssignNewCommander.sqf:4-5`. | Same visible-name selector and duplicate sender shape. | Upstream is a helper-fix source, not a complete reassignment fix. |
| `origin/perf/quick-wins` `0076040f` Chernarus and maintained Vanilla | Same fixed helper unpacking as stable at `Server_AssignNewCommander.sqf:4-5`. | Same visible-name selector and duplicate sender shape. | Perf branch does not close reassignment UI/notification/authority risks. |
| Release `origin/release/2026-06-feature-bundle` `a96fdda2` Chernarus and maintained Vanilla | Same fixed helper unpacking as stable at `Server_AssignNewCommander.sqf:4-5`. | Same visible-name selector and duplicate sender shape. | Treat release as partial commander reassignment cleanup, not a complete reassignment/authority fix. |
| `origin/feat/ai-commander` `c20ce153` Chernarus and maintained Vanilla | Same fixed helper unpacking as stable at `Server_AssignNewCommander.sqf:4-5`. | Same visible-name selector and duplicate sender shape; AI commander supervisor behavior is separate. | Do not route reassignment closure through AI commander revival without the UI/notification smoke here. |

This means future code work can either port the fixed helper shape from stable/release or implement it directly, but it still needs one notification owner and a row-value/team-identity selector before the reassignment path is clean.

## Evidence

| File | Evidence |
| --- | --- |
| `Client/GUI/GUI_Commander_VoteMenu.sqf:46` | Sends `["RequestNewCommander", [side group player, _voted_commander]]`. |
| `Client/GUI/GUI_Commander_VoteMenu.sqf:33-46` | Resolves the selected commander by visible leader name text before sending. |
| `Common/Init/Init_PublicVariables.sqf:13,50` | Registers and compiles `RequestNewCommander` as a server PVF command. |
| `Server/Functions/Server_HandlePVF.sqf:14` | Spawns PVF parameters into the compiled handler. |
| `Server/PVFunctions/RequestNewCommander.sqf:3,12-14` | Reads `_side = _this select 0`, sets `wfbe_commander`, spawns `WFBE_SE_FNC_AssignForCommander` with `[_side, _assigned_commander]`, and sends a `new-commander-assigned` message. |
| `Server/Functions/Server_AssignNewCommander.sqf:3-5` | Uses `_side = _this` while also indexing `_this select 1`. |
| `Common/Functions/Common_GetSideLogic.sqf:7` | Side-logic lookup only handles actual side values and defaults to `objNull`. |

## Likely Impact

The assignment itself probably lands because `RequestNewCommander.sqf` sets the side-logic `wfbe_commander` variable before calling the helper. The broken helper still matters:

- AI commander shutdown/reset logic resolves side logic from an array and can miss the intended side.
- The helper's `new-commander-assigned` client notification uses the bad side destination.
- The caller also sends a correct `new-commander-assigned` notification, so fixing the helper without choosing one notification owner can create duplicate messages.

The client selector also needs a small identity cleanup while this flow is open. `GUI_Commander_VoteMenu.sqf` stores the team index in the list row, but on submit it reads `lnbText` and matches `name leader _x`. Duplicate player names or a name change while the dialog is open can select the wrong team or fail the intended lookup. Use the stored row value/team index when patching the reassignment flow.

## Patch Shape

Patch source Chernarus first:

```sqf
// Server/Functions/Server_AssignNewCommander.sqf
_side = _this select 0;
_commander = _this select 1;
```

Then remove or suppress one `new-commander-assigned` send. Prefer keeping notification in `AssignNewCommander` if the helper is intended to own assignment side effects; otherwise keep it in `RequestNewCommander` and remove it from the helper. Do not leave both after the side fix.

Do not combine this with PVF dispatcher hardening unless the branch is explicitly about networking authority. This is a small correctness patch.

## Generated And Modded Copies

The same helper/caller shape appears in source Chernarus, generated Vanilla Takistan and the full modded Napf/Eden/Lingor copies. Other modded folders are partial overlays and may not contain this helper.

Patch source Chernarus, then run `Tools/LoadoutManager` from a checkout with an ancestor folder literally named `a2waspwarfare` so Vanilla Takistan is generated from source. Treat modded full copies as a separate owner decision because the current generation/package path does not actively maintain them.

## Validation

Source-only:

- `Server_AssignNewCommander.sqf` uses `_this select 0` for `_side`.
- `GUI_Commander_VoteMenu.sqf` resolves the selected commander by row value/team identity, not visible name text.
- Exactly one `new-commander-assigned` message path remains for the reassignment.
- Generated Vanilla diff is inspected after LoadoutManager propagation.

Arma smoke:

- Manual commander reassignment changes the commander for the intended side.
- The previous AI commander, if any, is stopped/reset for the intended side.
- Clients receive one reassignment message, not zero and not two.
- Commander vote fallback still works after reassignment.

## Agent Index Facts

```json
[
  {"fact":"commander_reassignment_current_source_unpatched","source":"Server_AssignNewCommander.sqf:3-5; RequestNewCommander.sqf:13-14; GUI_Commander_VoteMenu.sqf:33-46","summary":"Current source Chernarus and maintained Vanilla still have the bad helper side argument, duplicate notification senders and visible-name commander selection."},
  {"fact":"commander_reassignment_partial_branch_fix","source":"origin/master and origin/release/2026-06-feature-bundle Server_AssignNewCommander.sqf:4-5,10","summary":"Stable/upstream/release fix the helper payload unpacking, but the UI still resolves by visible leader-name text and both caller/helper notification senders remain."}
]
```

## Continue Reading

Previous: [Feature status](Feature-Status-Register) | Next: [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas)

Main map: [Home](Home) | Fast path: [Public variable channel index](Public-Variable-Channel-Index) | Agent file: [`agent-feature-status.jsonl`](agent-feature-status.jsonl)
