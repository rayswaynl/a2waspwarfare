# Commander Reassignment Call Shape

Status: patch-ready/current-source-unpatched for the DR-15 call-shape and duplicate-notification bug; source patch, Vanilla propagation, Arma smoke and broader `RequestNewCommander` authority validation remain pending.

All source paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/` unless a Vanilla path is named explicitly.

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

Current source and Vanilla `Server/PVFunctions/RequestNewCommander.sqf` read the payload and call the helper with an array:

```sqf
_side = _this select 0;
_assigned_commander = _this select 1;
...
[_side, _assigned_commander] Spawn WFBE_SE_FNC_AssignForCommander;
```

Current source and Vanilla `Server/Functions/Server_AssignNewCommander.sqf` still consume the helper payload as a single side value:

```sqf
_side = _this;
_commander = GetCommanderTeam _side;
```

That keeps the narrow DR-15 correctness bug open in maintained source/Vanilla: `GetSideLogic` receives an array instead of a side value, and both the request handler and helper path can emit `new-commander-assigned`. The public server PVF still needs requester/role/side validation as a separate authority hardening step.

## Evidence

| File | Evidence |
| --- | --- |
| `Client/GUI/GUI_Commander_VoteMenu.sqf:46` | Sends `["RequestNewCommander", [side group player, _voted_commander]]`. |
| `Common/Init/Init_PublicVariables.sqf:13,50` | Registers and compiles `RequestNewCommander` as a server PVF command. |
| `Server/Functions/Server_HandlePVF.sqf:11` | Spawns PVF parameters into the compiled handler. |
| `Server/PVFunctions/RequestNewCommander.sqf:3,13-14` | Reads `_side = _this select 0`, spawns `[_side, _assigned_commander]`, and still sends the duplicate caller-side reassignment notification. |
| `Server/Functions/Server_AssignNewCommander.sqf:3-9` | Still uses `_side = _this`, then sends `new-commander-assigned` through the helper path. |
| `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Functions/Server_AssignNewCommander.sqf:3-9` | Vanilla Takistan has the same unpatched helper shape. |
| `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/PVFunctions/RequestNewCommander.sqf:3,13-14` | Vanilla Takistan also sends the duplicate caller-side notification. |
| `Common/Functions/Common_GetSideLogic.sqf:7` | Side-logic lookup only handles actual side values and defaults to `objNull`. |

## Remaining Patch Shape

Patch source Chernarus first, then propagate or patch generated Vanilla Takistan:

1. Change `Server_AssignNewCommander.sqf` to read `_side = _this select 0` and `_commander = _this select 1`.
2. Keep exactly one `new-commander-assigned` notification path.
3. Do not mark the broader commander PVF authority lane complete from this correctness patch alone. `RequestNewCommander` still needs server-side requester/role/side validation as a separate authority hardening step.

## Generated And Modded Copies

Source Chernarus and generated Vanilla Takistan still need the helper/caller correction. Full modded Napf/Eden/Lingor copies may also need review; treat them as a separate owner decision because the current generation/package path does not actively maintain them.

## Validation

Source-only:

- After patching, `Server_AssignNewCommander.sqf` should use `_this select 0` for `_side`.
- Exactly one `new-commander-assigned` message path remains for reassignment.
- Generated Vanilla is propagated to the same helper/caller shape as source Chernarus.

Arma smoke:

- Manual commander reassignment changes the commander for the intended side.
- The previous AI commander, if any, is stopped/reset for the intended side.
- Clients receive one reassignment message, not zero and not two.
- Commander vote fallback still works after reassignment.

## Continue Reading

Previous: [Feature status](Feature-Status-Register) | Next: [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas)

Main map: [Home](Home) | Fast path: [Public variable channel index](Public-Variable-Channel-Index) | Agent file: [`agent-feature-status.jsonl`](agent-feature-status.jsonl)
