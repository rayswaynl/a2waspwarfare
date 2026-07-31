# Spectator Cam v4 — Streaming-Grade Director (2026-07-31)

Extends the v3 director (town cams, auto-pick, broadcast HUD) into a hands-off
broadcast camera for autonomous streaming to TikTok/Twitch/Kick. Owner-directed scope
(approved 2026-07-31):

- Fix yanky/jittery trailing (follow + director track)
- Fix too-slow zoom, too-fast/too-slow panning
- Town cams ONLY on active fights in towns (keep town cams otherwise)
- Auto-start on join for the caster UID (no keypresses on the OBS box)
- Hybrid idle fallback: recent-contact units, else wide establishing shots

## Root causes (v3 code reading)

- Movement loop `sleep 0.05` hard-caps camera updates at ~20 Hz while the capture
  renders 60+ fps; every `camCommit 0` between renders is a visible snap.
- Follow mode has no smoothing at all (raw `modelToWorld` per tick).
- Both follow/director add raw networked `velocity` x 0.4 s (`LEAD_SEC`) to camera
  AND aim each tick; remote velocity stair-steps, so the lead amplifies jitter.
- `FOV_RATE` 0.05/s = 10-15 s wide-to-tight while a TIGHT shot dwells 1.5-3 s; the
  zoom lands after the shot ends. After a target cut the FOV keeps crawling from
  the previous shot's value.
- Aim slew is a flat 8 deg/s (`PAN_DEG_PER_SEC`) — sprinting targets outrun it
  (too slow) — while the 35 deg `PAN_CUT_DEG` threshold snaps mid-shot (too fast).
- `DirectorBuildTowns` scores quiet towns via headcount/supply-delta with no contact
  requirement (-250 idle penalty loses to +300 headcount), so the cam parks on
  garrisoned peaceful towns. Distinct-side counting also counts non-belligerents.

## Motion (v4)

- Loop tick via `WFBE_C_SPECTATOR_TICK` (default 0.01): per-frame camera updates.
- Shared `WFBE_CL_FNC_SpectatorKinematics` helper: EMA-smoothed subject velocity
  (`VEL_EMA_RATE` 8/s) and speed-scaled lead (`LEAD_MAX_SEC` 0.5 at
  `LEAD_FULL_SPEED` 25 m/s; walking infantry get ~none). Used by follow AND director.
- Follow mode gets the same exponential position+aim smoothing as director
  (`SMOOTHING` 5/s, `FAST_GAIN_MULT` over 8 m/s); snaps only on target switch.
- Adaptive aim slew in `DirectorAimStep`: `rate = clamp(err*PAN_EASE(6),
  PAN_MIN(25), PAN_MAX(240)) deg/s` — fast when far off-axis, ease-out when close.
- Cut discipline: `PAN_CUT_DEG` 35 -> 70 (no mid-shot snaps); on a deliberate
  target/shot switch, pos + aim + FOV snap together, then ease.
- `FOV_RATE` 0.05 -> 0.35; movement loop also snaps FOV on target switch
  (respecting `MANUAL_ZOOM_LOCK_SEC`).

## Director brain (v4)

- TOWN hard gate: only belligerent sides (west/east/resistance) count toward the
  side mix (parked CIV caster bodies, neutral crew no longer fake a contest);
  a town is action-pickable only while contested (contact >= 1) or inside
  `TOWN_LINGER_SEC` (45 s) after the last enemy leaves (firefight pauses must
  not flicker the shot). Non-hot towns keep a small size/trend score so they can
  still serve as WIDE establishing shots, never TIGHT/MEDIUM action picks.
- Tiered `DirectorPickNext`: tier 1 = live contact entries (any class);
  tier 2 = players/teams by score (recent build-up footage); tier 3 = quiet
  towns/HQ wide establishing. Existing cooldown/hysteresis/repeat-margin logic
  runs unchanged within the chosen tier.
- Shot grammar retune: TIGHT dwell 3-6 s (was 1.5-3), MEDIUM 4-7 s (was 3-5);
  inline getVariable defaults updated to match the constants file.
- New RPT lines: `SPECTATE|v4|town-hot`, `SPECTATE|v4|autostart` for VOD tuning.

## Auto-start

- New flag `WFBE_C_SPECTATOR_AUTOSTART` (default 0). The attach loop
  (Client_SpectatorAttach.sqf) auto-enters spectator for allowlisted UIDs once the
  body is alive past `WFBE_Client_DeadspawnEscaped`, then engages director-auto +
  orbit (same var init as the G key). Self-heals across respawns via the existing
  poll loop. Entry remains gated by `WFBE_C_SPECTATOR` + `WFBE_C_SPECTATOR_UIDS`.

## Files

- `Client/Functions/Client_SpectatorEnter.sqf` — tick, kinematics, follow smoothing,
  adaptive pan usage, FOV snap-on-cut, header comment refresh.
- `Client/Functions/Client_SpectatorDirector.sqf` — belligerent filter, hot linger,
  entry contact/hot fields, tiered pick, adaptive AimStep, dwell inline defaults.
- `Client/Functions/Client_SpectatorAttach.sqf` — autostart block + header comment.
- `Common/Init/Init_CommonConstants.sqf` — appended v4 block (TICK, AUTOSTART,
  PAN_MIN/MAX/EASE, TOWN_LINGER_SEC, LEAD_MAX_SEC, LEAD_FULL_SPEED, VEL_EMA_RATE);
  retuned FOV_RATE/PAN_CUT_DEG/TIGHT+MEDIUM dwell with dated owner comments.

## Mirrors & gates

Chernarus edited; TK/ZG propagated via `Tools/LoadoutManager dotnet run -c RELEASE`
(then `version.sqf.template` restore per AGENTS.md). Lint gate
(`Tools/Lint/check_sqf.py`, standard selector list) zero new findings in edited
files; net bracket delta zero per file; `test_spectator_broadcast_hud.py` green;
flag-off (AUTOSTART 0 / DIRECTOR 0) leaves behavior identical to HEAD.

## A2 OA 1.64 safety

Only v3-proven commands; no new engine surface beyond arithmetic. No `params`,
no `pushBack`, no `#` selector, lazy `&& {}`/`|| {}` only, group receivers never
use 2-arg getVariable.

## Done when

All three mirrors carry identical v4 files, lint + HUD contract test pass, bracket
delta zero, and every v3 safety property is intact (invulnerable captive body,
death auto-exit, idempotent exit, flags-off inert).
