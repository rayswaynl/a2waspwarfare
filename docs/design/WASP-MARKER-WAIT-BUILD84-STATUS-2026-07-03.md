# WASP Marker Wait Build84 Status - 2026-07-03

Claim: `fleet-wasp-marker-wait-build84-status-2026-07-03`
Base checked: `origin/claude/build84-cmdcon36@b1608b096eb4a02d7c213d794e22b8bc59df8df0`
Scope: docs-only status route for the brain `wasp-marker-wait-cleanup` record. No mission source changed.

## Summary

The current Build84 target already carries the narrow WASP marker display-54 wait throttle in all maintained roots.

The source shape still uses the legacy `while {time < _this}` loop, but it now sleeps before each `findDisplay 54` poll. That is the small cleanup requested by the owner page for old-shape refs, so this target should not receive another blind source patch for the marker-wait issue.

## Source Evidence

| Root | Launch | Display-54 wait | Handler wiring |
| --- | --- | --- | --- |
| Chernarus | `Client/Init/Init_Client.sqf:496` launches `WASP\global_marking_monitor.sqf`. | `WASP/global_marking_monitor.sqf:62-65` loops with `sleep 0.1` before `findDisplay 54`. | `WASP/global_marking_monitor.sqf:69-70` still attaches the marker dialog keyUp/keyDown handlers, and `:74` releases input. |
| Takistan | `Client/Init/Init_Client.sqf:496` launches `WASP\global_marking_monitor.sqf`. | `WASP/global_marking_monitor.sqf:62-65` loops with `sleep 0.1` before `findDisplay 54`. | `WASP/global_marking_monitor.sqf:69-70` still attaches the marker dialog keyUp/keyDown handlers, and `:74` releases input. |
| Zargabad | `Client/Init/Init_Client.sqf:496` launches `WASP\global_marking_monitor.sqf`. | `WASP/global_marking_monitor.sqf:62-65` loops with `sleep 0.1` before `findDisplay 54`. | `WASP/global_marking_monitor.sqf:69-70` still attaches the marker dialog keyUp/keyDown handlers, and `:74` releases input. |

The same helper already has the later display-12 wait throttled with `waitUntil {sleep 0.1; !isNull (findDisplay 12)}` at `WASP/global_marking_monitor.sqf:81` in all three maintained roots.

## Routing

- Treat `claude/build84-cmdcon36` as source-present for the `wasp-marker-wait-cleanup` throttle.
- Do not reopen the nearby `wasp-perf-marker-consolidation` duplicate guard as a new patch lane.
- Do not replace this with a broader WASP authority cleanup; `WASP/actions/Action_RepairMHQDepot.sqf` and other WASP actions are separate owner routes.
- Older refs documented by the wiki owner page may still be old-shape. This status note is only for the current Build84 target.

## Caveats

- This is source audit only. The remaining proof is an in-engine marker-dialog smoke: double-click map, type marker text, press Enter, confirm the text is prefixed with the player name, confirm empty text becomes the player name, confirm Escape clears handlers, and confirm timeout/no-dialog cases do not leave input disabled.
- `Modded_Missions/*/Client/Init/Init_Client.sqf` still contains `execVM "WASP\global_marking_monitor.sqf"` references, but this target only has `WASP/global_marking_monitor.sqf` files in the maintained Chernarus, Takistan, and Zargabad roots. That is a modded-folder parity question, not part of this maintained-root Build84 marker-wait status.

## Verification

- Source anchor scan confirmed `sleep 0.1` before `findDisplay 54` in Chernarus, Takistan, and Zargabad.
- Source anchor scan confirmed keyUp/keyDown handler wiring and `disableUserInput false` remain in the same helper.
- Source file inventory found exactly three `global_marking_monitor.sqf` files, all under the maintained roots listed above.
- LoadoutManager was not run because this is a docs-only status note.
