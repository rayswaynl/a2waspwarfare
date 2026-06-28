# Endgame Winner Cam & Auto-Capture

Branch: `claude/endgame-winner-cam` · 2026-06-28

Two parts:

1. **Winner cam (SHIPPED in this PR)** — an in-mission enhanced cinematic over the
   winning HQ at round end, held open long enough to watch/record, and skippable.
2. **Auto-capture pipeline (PLAN ONLY — nothing installed)** — a design for grabbing
   the endgame as a short clip to post to TikTok / Shorts.

---

## Part 1 — Winner cam (implemented)

### What changed

| File | Change |
|---|---|
| `Common/Init/Init_CommonConstants.sqf` | New `WFBE_C_ENDGAME_HOLD = 45` (seconds). Single lever for the whole feature. |
| `Server/FSM/server_victory_threeway.sqf` | Both `failMission "END1"` paths now `sleep WFBE_C_ENDGAME_HOLD` (floored at 5s) instead of a hard `sleep 5`, so the round is held open while the cam plays. |
| `Client/Client_EndGame.sqf` | Replaced the old "pan over every base on the map" loop with a **winner-focused slow orbit of the winning HQ**, time-bounded to `WFBE_C_ENDGAME_HOLD`, with a **SPACE/ESC skip**. |

### Why the server change was necessary (and is a latent-bug fix)

Victory flow: `server_victory_threeway.sqf` declares a winner → sends the `"endgame"`
special to every client (→ `Client_EndGame.sqf`) → saves player scores → `failMission "END1"`.

On a dedicated server **the server's `failMission` is the authoritative end** — it tears the
round down for everyone. Previously that fired only ~5–7s after the `"endgame"` signal, so the
client cinematic (which iterated over *all* bases and took far longer) was usually **cut short in
practice**. Holding the server end by `WFBE_C_ENDGAME_HOLD` fixes that *and* gives us the recording
window. The server's total hold = (score-save loop) + `WFBE_C_ENDGAME_HOLD`, which is always ≥ the
client cam window, so the cam is never clipped.

### Cam behaviour

- Targets the **winning** side's HQ (`_side` is the winner; this was already corrected in B67).
- Slow azimuth orbit (`24°`/leg, `camCommit 4`, radius 150) with a gentle sine vertical bob — reads
  as a sweep, not a flat turntable. ~¾ of a full circle over the 45s default.
- The existing **faction-coloured victory FX** (flare fountain + light pulse at the winning HQ) and
  **outro music** are unchanged and play under the orbit.
- The existing **`EndOfGameStats` CutRsc** scoreboard overlay still shows — it's a title resource, not
  a dialog, so it does **not** steal keyboard focus (the skip handler keeps working).

### Skip

- `findDisplay 46` `KeyDown` handler (same idiom the mission uses for hotkeys). **SPACE (DIK 57)** or
  **ESC (DIK 1)** sets `WFBE_ENDGAME_SKIP`; the loop breaks and the client drops to the debrief in ~0.2s.
- Those two keys are **consumed** (handler returns `true`) so ESC doesn't pop the pause menu over the
  cam; all other keys pass through. Skip is **per-client and local** — one player skipping does not end
  the round for anyone else (the server's hold timer is the global end).
- The handler is removed by its captured index at the end, so the mission's own handlers are untouched.

### Tuning

Everything is one constant: `WFBE_C_ENDGAME_HOLD`.
- `45` (default) — long enough to record, skippable.
- Lower (e.g. `20`) for snappier map rotation; `0` ends almost immediately (server floors at 5s).

### Cost / safety

Zero server cost and A2-OA safe: no units/AI created, the cam is entirely client-local and only runs
*after* `gameOver`/`failMission` is already in motion. No A3-only commands used.

---

## Part 2 — Auto-capture for TikTok (PLAN ONLY — not installed)

### The hard constraint: the Hetzner server renders nothing

The WASP game server runs on **Hetzner** as a **dedicated, headless** Arma 2 OA server — no GPU, no
3D view, nothing rendered. **You cannot capture video on the Hetzner box** (OBS there would record a
black screen / console). This is not a config issue; a dedicated Arma server never renders the game.

**So capture must run on a separate GPU machine** running a full Arma 2 OA **caster client** that
joins the Hetzner server and renders the match. Hetzner only supplies the **trigger** (the `ROUNDEND`
telemetry), not the video.

**Decided (2026-06-28):** the recorder is **this gaming PC** (it has a GPU and already receives the
ROUNDEND telemetry via the leaderboard pipeline). Still **plan-only — nothing installed yet.**

Synergy with Part 1: the winner-cam runs on *every* connected client, so a caster client joined to
the Hetzner match automatically gets the 45s orbit of the winning HQ at round end — that is exactly
the footage OBS captures. No extra in-game work.

### Recommended architecture: OBS replay buffer, triggered by the existing ROUNDEND telemetry

We already emit a clean end-of-round marker to the RPT log (see `docs/WASPSTAT-FORMAT.md`):

```
WASPSTAT|v1|<seq>|ROUNDEND|<winnerSide>|<durationSec>|<map>
```

Pipeline, all on **this gaming PC** (the caster/recorder):

1. **Caster client** — a full Arma 2 OA client auto-joins the **Hetzner** server and stays connected
   for the match (occupies one player slot; at round end it gets the winner-cam like everyone else).
   It must **auto-(re)join each match**, because matches rotate (`WaspMapRotate`, ~4h) and the mission
   restarts — Arma does not auto-reconnect by default. **This auto-join/relaunch loop is the main
   engineering effort of this lane** (a launcher script with `-connect=<hetzner-ip> -port=… -password=…`
   that relaunches when the client drops to the server browser).
2. **OBS Studio** runs with the **Replay Buffer** enabled, capturing the Arma window continuously
   (rolling ~60s buffer, never written to disk until told to). Negligible overhead on a gaming PC.
3. A small **watcher** (PowerShell, same pattern as our existing RPT reporters) detects round end.
   The cleanest source on this PC is the **ROUNDEND telemetry that already arrives** via
   `poster.ps1 → POST :3010` (see [[wasp-leaderboard-pipeline]]) — no new plumbing from Hetzner.
   (Fallback: tail the local caster client's RPT for `|ROUNDEND|`.)
4. **Timing:** the 45s winner cam plays *after* ROUNDEND fires. So the watcher should **wait ~48s**
   (≈ `WFBE_C_ENDGAME_HOLD` + a margin), *then* trigger OBS **Save Replay Buffer**. With a ~60s buffer
   the saved clip = the deciding moment + the full winner cam.
5. Trigger OBS via the **obs-websocket** API (`SaveReplayBuffer` request) — cleaner than a global
   hotkey and lets us name the file `wasp_<map>_<winnerSide>_<seq>.mkv`.
6. **Vertical reformat for TikTok/Shorts (optional, automated):** `ffmpeg` crop+scale to 1080×1920,
   e.g. centre-crop then `scale=1080:1920`, optionally burn in a title card
   ("WEST victory — Chernarus"). ffmpeg is **not currently installed** either.

### Why replay-buffer-after-the-fact (not "start recording on ROUNDEND")

Starting a recording *at* ROUNDEND would miss the climactic final assault that *caused* the win, and
risks a few dropped frames on record-start. A continuously-running replay buffer already holds the
last 60s, so saving it ~48s later captures **both** the final battle and the whole cam in one clip,
with no record-start hitch.

### Remaining decisions (smaller, deferred)

- **Caster slot behaviour during the match.** For round-end capture the caster only needs to be
  *connected* (the replay buffer + winner-cam do the rest), so v1 can just sit at base. A roaming
  auto-spectator that follows the action is a nice-to-have, not required.
- **Auto-post vs. manual.** Recommend **manual** posting to TikTok first (auto-post needs the TikTok
  Content Posting API + app review; not worth it until the clips are proven good).
- **Unattended/overnight.** The soak matches run unattended (see [[wasp-guer-overnight-soak]]); if we
  want clips from those, the caster launcher + OBS must survive reboots (Scheduled Task at logon) and
  the PC must stay logged in with the GPU session active (OBS can't capture from a locked session).

### Install footprint (when Ray says go)

OBS Studio + obs-websocket (bundled in OBS ≥ 28) + ffmpeg — all free. Plus a copy of Arma 2 OA on the
gaming PC for the caster client (likely already present).

### Smallest next step when ready

1. Write the **caster auto-join launcher** (the hard part) — launch Arma with `-connect`/`-password`,
   detect drop-to-browser, relaunch. 2. Install OBS, enable Replay Buffer (60s) + obs-websocket.
3. Write the `ROUNDEND → wait 48s → SaveReplayBuffer` watcher (≈30 lines PowerShell, mirrors the
   existing RPT reporters; can hook the `:3010` ingest that already receives ROUNDEND). Vertical
   reformat is a follow-up once we like the raw 16:9 clips.
