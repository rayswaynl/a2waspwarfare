# HC Send Guard Status - 2026-07-02

Lane: 81, stale-HC `publicVariableClient` `ID=ffffffff` log flood.

## Result

Current target already carries the lane 81 fix. No mission source change is needed.

The live base for this audit is `origin/claude/build84-cmdcon36@ca278c4bc`. Commit `1d7fc461d` is an ancestor of that base and is the shipped fix from merged PR #241:

- PR #241: `[fable] Fix ~20k/round 'Message not sent' HC log spam (validate client id in Common_SendToClient)`
- Branch: `fable/fix-hc-sendtoclient-idguard`
- Merge commit: `cad41086ddd02bad3f346a98a15f7d0cd459fbf6`
- Fix commit: `1d7fc461d`

## Current Source Evidence

`Common_SendToClient.sqf` now captures the target machine id before rewriting the payload:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_SendToClient.sqf:11`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Functions/Common_SendToClient.sqf:11`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Functions/Common_SendToClient.sqf:11`

Each maintained root then documents and guards the stale-HC case:

- `:16-21` explains that `owner()` can return `0` for disconnected or server-local HC targets, and that `publicVariableClient` with id `0` produces `Message not sent - error 0 ID=ffffffff`.
- `:23-24` sends the remote dedicated-server path only when `_id > 0`.
- `:29` applies the same `_id > 0` guard to the hosted multiplayer network send after the local hosted-server spawn.

The three maintained copies hash-match:

`1A917F53A77BD99C864D4171EA54595DB7EC9C09927EF27AF2846E8EC1D0B7BB`

## Wiki Drift

The older wiki row still says the issue is untouched:

- `Foundation-Perf-Findings-And-Tier3-Dead-Ends.md:34`: marks the `~20,826 "Message not sent - error 0 ID=ffffffff"` row as `Untouched`.

The later worklog already records the shipped fix:

- `Agent-Worklog.md:4726`: `PR #241 (81 HC log-spam, Common_SendToClient _id>0 guard)`.

So the current-target state is implemented, while one older finding table is stale.

## Runtime Smoke To Keep

When the next HC runtime packet is collected, confirm:

- No repeated `Message not sent - error 0 ID=ffffffff` spam during AICOM/HC team delegation.
- HC delegate sends still reach live HC clients while their `owner()` id is positive.
- Hosted/listen behavior remains unchanged: the local `WFBE_CL_FNC_HandlePVF` spawn still runs, and multiplayer network sends still require `_id > 0`.

## Out Of Scope

This report does not change mission behavior, HC registration, delegation selection, PVF dispatch, live runtime settings or package artifacts. The separate HC-registration dedupe backlog remains a future HC owner lane.
