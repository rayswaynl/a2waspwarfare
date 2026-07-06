# Lane 127 - Supply Player List Dedupe Status (2026-07-02)

## Verdict

Lane 127 is already implemented on the current target
`origin/claude/build84-cmdcon36@ca278c4bc7a5989be7523f08d90ed5953d15854d`.
No mission-source patch is needed for the prompt row that says
`playerObjectsList.sqf` resets `_i` inside the player-list loop and therefore
updates row 0 instead of the matching UID row.

Current Chernarus and Takistan both initialize `_i = 0` before the
`WFBE_SE_PLAYERLIST` scan, increment `_i` once per row, store the matched row in
`_arrayPosMatch`, and replace that row when a non-null player object arrives
for the same UID.

## Current-Source Evidence

| Check | Current target evidence |
| --- | --- |
| Index initialized once | `Server/Module/supplyMission/playerObjectsList.sqf:17` sets `_i = 0` before the `forEach WFBE_SE_PLAYERLIST` block and carries a `wiki-wins` comment describing the old in-loop reset. |
| Match records true row | `playerObjectsList.sqf:23-25` compares `_iteratedPlayerUID` to `_currentPlayerUID` and stores `_arrayPosMatch = _i` when the UID matches. |
| Index advances per row | `playerObjectsList.sqf:28` increments `_i` inside the loop after each inspected row. |
| Existing UID is updated | `playerObjectsList.sqf:31-32` replaces `WFBE_SE_PLAYERLIST` at `_arrayPosMatch` when a matching UID has a non-null player object. |
| New UID is appended | `playerObjectsList.sqf:33-34` appends a row only when no matching live player object update is available. |
| Mirrored roots match | The maintained Chernarus and Takistan copies of `Server/Module/supplyMission/playerObjectsList.sqf` match under `git diff --no-index`. |

## Fix History

`1ad62bf4a` (`b759: adopt PR #83 bucket-A correctness fixes + economy guards`)
moved `_i = 0` out of the `forEach` loop in both maintained roots. The commit's
scoped diff for `playerObjectsList.sqf` is exactly the two-line shape needed for
lane 127: add `_i = 0` before the loop, remove the loop-local reset.

## Boundaries

This audit closes only the stale lane-127 prompt claim about the UID dedupe loop
index. It does not change supply mission authority, disconnect pruning,
null/stale row cleanup, supply completion player matching, or reconnect/JIP
runtime smoke requirements.

No mission source changed, so LoadoutManager was not run and no package artifact
was produced. Runtime reconnect/supply smoke remains useful for the broader
supply lifecycle backlog, but the current-source bug named by lane 127 is no
longer present.
