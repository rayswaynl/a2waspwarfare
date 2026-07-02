# Commander Reassignment Payload Audit

Date: 2026-07-02
Lane: 132 - commander reassignment payload shape
Branch: `codex/lane132-commander-reassign-audit`
Base: `claude/build84-cmdcon36`

## Verdict

Lane 132 is already fixed on the current target. No source change is needed.

The prompt row described an old shape mismatch where `RequestNewCommander.sqf` passed
`[_side, _cmdr]`, but `Server_AssignNewCommander.sqf` treated the whole payload as `_side`. Current
source keeps the side and commander team as separate values all the way through the direct assignment
path.

## Evidence

- Chernarus `Server/PVFunctions/RequestNewCommander.sqf:3-4` reads `_side = _this select 0` and `_assigned_commander = _this select 1`.
- Chernarus `Server/PVFunctions/RequestNewCommander.sqf:32-33` stores `_assigned_commander` and spawns `[_side, _assigned_commander] Spawn WFBE_SE_FNC_AssignForCommander`.
- Chernarus `Server/Functions/Server_AssignNewCommander.sqf:3-6` reads `_side = _this select 0`, `_commander = _this select 1`, and resolves side logic from `_side`.
- Chernarus `Server/Functions/Server_AssignNewCommander.sqf:10-15` broadcasts the commander assignment with the side scalar and only toggles AI commander state when `_commander` is non-null.
- Takistan copies of both files match Chernarus under `git diff --no-index`.
- `Server/Init/Init_Server.sqf:100` still compiles `WFBE_SE_FNC_AssignForCommander` from `Server_AssignNewCommander.sqf` in both roots.

## Scope Notes

- No mission source was changed.
- No LoadoutManager run was needed because this is docs-only.
- The low-priority vote-menu `objNull`/primitive-row UX note in `docs/design/VOTE-SYSTEM-QA-2026-07-02.md` is adjacent but separate. It does not reintroduce the stale lane 132 side-payload corruption.

## Suggested Smoke

In an engine smoke:

- Start a commander vote or use the direct reassignment path.
- Confirm the selected side still receives `new-commander-assigned`.
- Confirm AI commander state stops only when a non-null human commander team is assigned.
