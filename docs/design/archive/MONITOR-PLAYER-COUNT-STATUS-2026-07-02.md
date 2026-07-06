# Lane 128 - Monitor Player Count Status (2026-07-02)

## Verdict

Lane 128 is already implemented on the current target
`origin/claude/build84-cmdcon36@b1608b096eb4a02d7c213d794e22b8bc59df8df0`.
No mission-source patch is needed for the prompt row that says
`MonitorPlayerCount.sqf` samples player count once after 120 seconds and then
exits.

Current source waits the initial 120 seconds, enters a permanent polling loop,
recounts live players every pass, subtracts live headless clients from the
count, and sleeps 300 seconds before the next sample.

## Current-Source Evidence

| Check | Current target evidence |
| --- | --- |
| Current path | The file lives at `Server/MonitorPlayerCount.sqf`, not under `Server/Module`. |
| Server startup hook | `Server/Init/Init_Server.sqf:1213-1218` sets `_logMatchWinPlayerCountThreshold = 10`, defaults `WFBE_Server_LogMatchWin = false`, and starts `Server\MonitorPlayerCount.sqf`. |
| Initial delay preserved | `MonitorPlayerCount.sqf:5` still sleeps 120 seconds before the first sample. |
| Repeating sample loop | `MonitorPlayerCount.sqf:7` wraps the sampler in `while {true} do`, so it no longer exits after the first sample. |
| Fresh count per pass | `MonitorPlayerCount.sqf:9-15` resets `_playerCount = 0` and scans `allUnits` for `isPlayer` every iteration. |
| HC exclusion | `MonitorPlayerCount.sqf:17-21` subtracts live registered HCs and floors the human count at 0. |
| Threshold write | `MonitorPlayerCount.sqf:23-25` sets `WFBE_Server_LogMatchWin = true` when the human count reaches the threshold. |
| Poll cadence | `MonitorPlayerCount.sqf:27` sleeps 300 seconds before the next sample. |
| Mirrored roots match | `git diff --no-index` is empty between Chernarus and Takistan `Server/MonitorPlayerCount.sqf`; the current Zargabad copy also matches Chernarus for this file. |

## Fix History

`580f5239d` (`Server: poll player count every 5 min instead of sampling once at
120 s`) added the permanent loop, per-pass reset, HC exclusion, threshold check,
and 300-second polling cadence to `Server/MonitorPlayerCount.sqf`.

## Boundaries

This audit closes only the stale lane-128 prompt claim about the monitor exiting
after one player-count sample. It does not change match-report semantics,
headless-client registration, `WFBE_Server_LogMatchWin` consumers, player
statistics loops, AI commander player-count scaling, or the new Zargabad mission
content.

No mission source changed, so LoadoutManager was not run and no package artifact
was produced. A live long-round smoke can still confirm the flag flips after a
late population increase, but the current-source single-sample bug named by lane
128 is no longer present.
