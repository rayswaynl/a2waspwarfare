# Spectator Cam v2 — Design (2026-07-29)

Extends the v1 UID-allowlisted spectator overlay (PR #1594, flag `WFBE_C_SPECTATOR` default 1)
from a keyboard-only free cam into a caster-grade watch tool. Owner-directed scope:

- Mouse look (replaces Q/E + arrow-key turning)
- Zoom (mouse-wheel FOV) + speed control (Shift boost / Alt precision) + fly-along-view WASD
- Follow-a-player chase cam
- See-through-eyes POV mode
- No auto-cycle / cinematic mode (explicitly skipped by owner)

## Controls (v2)

| Input | Action |
|---|---|
| Mouse | Free-look yaw/pitch (±89° pitch clamp, cursor re-centered per event) |
| Wheel | FOV zoom, multiplicative, clamped [`WFBE_C_SPECTATOR_FOV_MIN`, `_MAX`] |
| W/S | Fly along view direction (incl. pitch) |
| A/D | Horizontal strafe |
| Space/Ctrl | Vertical up/down |
| Shift / Alt | ×`WFBE_C_SPECTATOR_BOOST` / ×`WFBE_C_SPECTATOR_SLOW` speed |
| N / B | Arm next/previous alive player as target (wraps, skips self/dead/null) |
| F | Toggle follow-cam on armed target (8 m behind, 3 m above, re-pointed per tick) |
| V | Toggle through-their-eyes POV (`eyePos` + `eyeDirection`) |
| H | Toggle the hint overlay (clean OBS capture) |
| Backspace | Quick exit (same path as the "Exit Spectator" addAction) |

Modes: `free` (default) / `follow` / `eyes`, stored in `WFBE_C_VAR_SpectatorMode`; target in
`WFBE_C_VAR_SpectatorTarget`. Any WASD/Space/Ctrl input while in follow/eyes reverts to free
at the current camera position; yaw/pitch are tracked continuously in follow/eyes so the
handoff has no snap. A dead/null target auto-reverts to free with a chat notice (never a
dangling camera — same philosophy as v1's death watchdog).

## Architecture

Same three files, extended; no new respawn/JIP/enrollment edits (v1 hard constraint kept).

- `Client/Functions/Client_SpectatorEnter.sqf` — mode/target state, `MouseMoving` +
  `MouseZChanged` display EHs alongside KeyDown/KeyUp, inline target-cycle helper
  (`WFBE_CL_FNC_SpectatorCycleTarget`, alive-player list from `allUnits` + `isPlayer`,
  self excluded), rebuilt per-tick loop (view-plane movement, zoom, follow/eyes branches,
  hint overlay, body position **and direction** lock so the parked body doesn't spin under
  the mouse). Movement keys are now *consumed* (handler returns true) so the body never
  walks under camera input; the v1 position re-lock stays as pure backup.
- `Client/Functions/Client_SpectatorExit.sqf` — additionally removes the two mouse EHs,
  clears the hint, resets mode/target vars. Idempotent guard unchanged.
- `Client/Functions/Client_SpectatorAttach.sqf` — unchanged.
- `Common/Init/Init_CommonConstants.sqf` — appended tuning constants (defaults): SPEED 15,
  BOOST 4, SLOW 0.25, SENS 300, FOV_MIN 0.05, FOV_MAX 1.2. Existing flag/default untouched.

## A2 OA 1.64 safety

Only v1-proven commands plus `MouseMoving`/`MouseZChanged` display EHs (same display-EH
family v1 already uses), `setMousePosition` (A2 OA 1.60+), `eyePos`/`eyeDirection`,
`atan2`. No A3-only commands; no `disableUserInput` (v1's documented rejection stands).

Playtest item: `eyeDirection` on remote units is network-interpolated — POV may be slightly
less smooth than a local unit. Fallback if it jitters: `weaponDirection`.

## Mirrors & gates

Chernarus edited; TK/ZG propagated via `Tools/LoadoutManager dotnet run -c RELEASE`
(then `version.sqf.template` restore per AGENTS.md). Lint gate
(`Tools/Lint/check_sqf.py`, standard selector list) must show zero new findings in edited
files; net bracket delta zero per file.

## In-flight overlap

PR #1580 (draft, caster mode) touches `Init_CommonConstants.sqf` and `Init_Client.sqf` but
not the three spectator files; v2 does not touch `Init_Client.sqf` at all, and constants are
appended adjacent to the v1 block — worst case a trivial line-level merge.

## Done when

All three mirrors carry identical v2 files, lint is clean, and every v1 safety property is
intact (invulnerable captive body, death auto-exit, idempotent exit, flag-off inert).
