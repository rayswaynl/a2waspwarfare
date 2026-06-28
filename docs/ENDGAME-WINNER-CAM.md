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

### The hard constraint: the server renders nothing

The WASP server is a **dedicated, headless** Arma 2 OA server — it has no 3D view, so there is no
video to grab from the server process. **Capture must run on a machine that actually renders the
game**: either a player's client or a dedicated "caster" client that joins and spectates. This is the
decision that's still open (which PC), so nothing is installed yet.

### Recommended architecture: OBS replay buffer, triggered by the existing ROUNDEND telemetry

We already emit a clean end-of-round marker to the RPT log (see `docs/WASPSTAT-FORMAT.md`):

```
WASPSTAT|v1|<seq>|ROUNDEND|<winnerSide>|<durationSec>|<map>
```

Pipeline on the **recording client PC**:

1. **OBS Studio** runs with the **Replay Buffer** enabled, capturing the game window continuously
   (rolling ~60s buffer, never writing to disk until told to). Negligible overhead on a gaming PC.
2. A small **watcher** (PowerShell, same pattern as our existing RPT reporters) tails the **client**
   RPT — or the **server** RPT if capture runs on the same physical PC as the server — for a
   `|ROUNDEND|` line.
3. **Timing:** the 45s winner cam plays *after* ROUNDEND fires. So the watcher should **wait ~48s**
   (≈ `WFBE_C_ENDGAME_HOLD` + a margin), *then* trigger OBS **Save Replay Buffer**. With a ~60s buffer
   the saved clip = the deciding moment + the full winner cam.
4. Trigger OBS via the **obs-websocket** API (`SaveReplayBuffer` request) — cleaner than a global
   hotkey and lets us name the file `wasp_<map>_<winnerSide>_<seq>.mkv`.
5. **Vertical reformat for TikTok/Shorts (optional, automated):** `ffmpeg` crop+scale to 1080×1920,
   e.g. centre-crop then `scale=1080:1920`, optionally burn in a title card
   ("WEST victory — Chernarus"). ffmpeg is **not currently installed** either.

### Why replay-buffer-after-the-fact (not "start recording on ROUNDEND")

Starting a recording *at* ROUNDEND would miss the climactic final assault that *caused* the win, and
risks a few dropped frames on record-start. A continuously-running replay buffer already holds the
last 60s, so saving it ~48s later captures **both** the final battle and the whole cam in one clip,
with no record-start hitch.

### Open decisions before we install anything

- **Which PC renders/records?** This gaming PC (runs the server — would also need a client joined to
  it), or a separate caster PC? Determines whether the watcher reads the local server RPT or a client RPT.
- **Caster client?** A dedicated spectator slot that auto-flies the endgame would give the cleanest,
  player-independent footage. Could reuse the same orbit logic in a free spectator.
- **Auto-post vs. manual?** Recommend **manual** posting to TikTok first (auto-post needs the TikTok
  Content Posting API + app review; not worth it until the clips are proven good).
- **Install footprint:** OBS Studio + obs-websocket (bundled in OBS ≥ 28) + ffmpeg. ~all free.

### Smallest next step when ready

Install OBS on the chosen PC, enable Replay Buffer (60s) + obs-websocket, and write the
`ROUNDEND → wait 48s → SaveReplayBuffer` watcher (≈30 lines of PowerShell, mirrors the existing
RPT reporters). Vertical reformat is a follow-up once we like the raw 16:9 clips.
