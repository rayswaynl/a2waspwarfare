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
[_side, _assigned_commander] Call AssignNewCommander;
```

The helper then unpacks the same payload incorrectly:

```sqf
_side = _this;
_commander = _this select 1;
```

`Common_GetSideLogic.sqf` expects a real `SIDE` value and otherwise falls back to `objNull`. Passing the whole array as `_side` means helper-side side-logic work and notification routing use an invalid side value.

## Evidence

| File | Evidence |
| --- | --- |
| `Client/GUI/GUI_Commander_VoteMenu.sqf:46` | Sends `["RequestNewCommander", [side group player, _voted_commander]]`. |
| `Common/Init/Init_PublicVariables.sqf:13,50` | Registers and compiles `RequestNewCommander` as a server PVF command. |
| `Server/Functions/Server_HandlePVF.sqf:11` | Spawns PVF parameters into the compiled handler. |
| `Server/PVFunctions/RequestNewCommander.sqf:3,12-14` | Reads `_side = _this select 0`, sets `wfbe_commander`, calls `AssignNewCommander`, and sends a `new-commander-assigned` message. |
| `Server/Functions/Server_AssignNewCommander.sqf:3-5` | Uses `_side = _this` while also indexing `_this select 1`. |
| `Common/Functions/Common_GetSideLogic.sqf:7` | Side-logic lookup only handles actual side values and defaults to `objNull`. |

## Likely Impact

The assignment itself probably lands because `RequestNewCommander.sqf` sets the side-logic `wfbe_commander` variable before calling the helper. The broken helper still matters:

- AI commander shutdown/reset logic resolves side logic from an array and can miss the intended side.
- The helper's `new-commander-assigned` client notification uses the bad side destination.
- The caller also sends a correct `new-commander-assigned` notification, so fixing the helper without choosing one notification owner can create duplicate messages.

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
- Exactly one `new-commander-assigned` message path remains for the reassignment.
- Generated Vanilla diff is inspected after LoadoutManager propagation.

Arma smoke:

- Manual commander reassignment changes the commander for the intended side.
- The previous AI commander, if any, is stopped/reset for the intended side.
- Clients receive one reassignment message, not zero and not two.
- Commander vote fallback still works after reassignment.

## Continue Reading

Previous: [Feature status](Feature-Status-Register) | Next: [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas)

Main map: [Home](Home) | Fast path: [Public variable channel index](Public-Variable-Channel-Index) | Agent file: [`agent-feature-status.jsonl`](agent-feature-status.jsonl)
