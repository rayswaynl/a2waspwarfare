# WASP m0730g — headless-client topology + the spectator regression

Live on the Chernarus rotation entry since 2026-07-30. Seventh build of the day
(m0730b reconciliation → c deck dark → d addAction string fix → e tuning →
f serialization attempt → **g**). Takistan follows at the next restart (see §4).

---

## 1. Headless clients: 4 lobby slots → 2, CIV-only, on every terrain

**What you saw:** four `Headless Client` slots in the lobby when the box only runs
two HC processes, and — historically — headless clients turning up as BLUFOR/OPFOR
players.

**What was actually in the mission:**

| Terrain | Slots labelled "Headless Client" | Actually carried `forceHeadlessClient` |
|---|---|---|
| Chernarus | 4 | 4 |
| Zargabad | 4 | 4 |
| Takistan | 4 | **0** |

Takistan shipped **zero real HC slots**. All four of its slots were ordinary
playable CIV slots that merely had "Headless Client N" typed into the description
field. That is the mechanism behind HCs in BLUFOR/OPFOR: on OA 1.64 the engine
assigns an incoming client to the **lowest-id free `player="PLAY CDG"` slot,
side-blind**, and only honours `forceHeadlessClient` for a client that joins a
mission which is already live. A Takistan rotation therefore had nothing pinning
the HCs to CIV at all, and any cold-boot connect could land one in a rifle slot.

**Changed:**

- Removed the `Headless Client 3` and `Headless Client 4` groups from all three
  `mission.sqm` files. Group `items=` counts and the `class ItemNN` numbering were
  re-closed contiguously afterwards, because Arma reads `Item0..Item(items-1)` and
  a hole or a stale count silently drops entities: Chernarus 153 → 151,
  Takistan 102 → 100, Zargabad 66 → 64.
- Gave Takistan's two surviving slots the `forceHeadlessClient=1` flag they never
  had, so all three terrains now match.
- Verified across all three: exactly **2** forced-HC slots, all `side="CIV"`, and
  **zero** WEST/EAST/GUER slots carrying the flag.
- `WFBE_C_HC_SLOTS` 4 → 2. `WFBE_C_HC_LOBBY_EXPECTED` derives from it, so the
  optional lobby lock now expects 2 seated HCs instead of waiting forever for 4.

**Deliberately *not* narrowed:** the HC **name** list still covers
`HC-AI-Control-1..4`. That list is an exclusion net answering "is this body a real
human?" — used by spawn-proximity vetoes, real-player counts and side-credit. A
superset is the safe direction: the box still has `hc3_launch.cmd`/`hc4_launch.cmd`
on disk, and a stray one connecting must not be mistaken for a player. Narrowing
that list to match the slot count is exactly the drift that broke spawn vetoes
in #1456.

**Box side, for completeness:** the launcher chain was already correct — the live
box runs `Start-Wasp-2HC.ps1`, which waits for `MATCH|v1|START|` in the server RPT
and only then launches the two HCs, so both JIP into a live mission rather than
racing the load. The `WaspHC3`/`WaspHC4` scheduled tasks have now been **disabled**
so a stray manual run cannot seat a third or fourth HC.

**Verified live on m0730g:** `who="HC-AI-Control-1"` and `who="HC-AI-Control-2"`
both reporting in the same session, 45–46 fps each, delegating together.

---

## 2. Spectator: why m0730f went dead, and the actual fix

**What you reported:** "free camera is still horrendous", "H not working, no UI
showing up", "the freelook just pulls back to a focus point the whole time".

**Root cause — my own m0730f change.** m0730e ran this same script *with* its
`waitUntil` and *without* `disableSerialization`, and the camera loop worked (that
is the build where you reported over-sensitivity and the upward pitch drift — both
symptoms of a loop that was very much alive). m0730f changed exactly one thing at
the top of the file: it added `disableSerialization` to suppress the
`Variable '_disp' does not support serialization` popup. Everything after the
camera setup then stopped running — no display-handler attach, so H and every other
key was dead; no movement loop, so no controls card and no mouse steering; and the
camera sat frozen aimed at the target point it was given on entry, which is exactly
the "pulls back to a focus point" you described.

On A2 OA 1.64 a script that calls `disableSerialization` does not survive its first
suspension. That is the **opposite** of the Arma 3 behaviour, where the command is
required in order to hold a display across a sleep. I applied the A3 rule to a 1.64
mission; the repo's own guide warns that A3 documentation lies about this engine,
and this is a textbook instance.

**Fixed by removing the exposure instead of suppressing the error:**

- `disableSerialization` is gone from both spectator scripts. No live statement
  remains in either (grep-verified in the packed PBO).
- The `_disp` local is gone: handlers now attach inline via
  `(findDisplay 46) displayAddEventHandler [...]`, so no Display reference is ever
  held across a frame boundary and nothing can raise the serialization error in the
  first place.
- The `waitUntil {camCommitted ...}` after a zero-duration `camCommit` was dropped —
  it bought nothing and was one more suspension point in the critical path.
- Two always-on log lines added (`SPECTATE|v2|handlers-attached`,
  `SPECTATE|v2|loop-alive`) so the next RPT proves where this script stops instead
  of it failing silently a fourth time.

**Mouse model rewritten.** The m0730f attempt re-anchored the cursor on every other
event, which meant only half of your mouse movement steered the camera at all —
that alternation is its own source of the snap-back feel. Now every event steers at
full rate, and the cursor is warped back to centre **only when it nears the edge of
the UI**, with the single event after a warp re-anchoring rather than steering. The
anchor is therefore always a genuine reported position, so no constant recentre bias
can accumulate — that bias is what was slowly tipping the view to +89° until it
pinned straight up.

**Sensitivity default 45 → 25**, since every event now contributes instead of every
second one. `PgUp`/`PgDn` still retune it live in-session (range 10–400) and the
value is shown on the controls card, so you can dial in a broadcast feel without
waiting for another build.

---

## 3. Director mode (your streaming ask) — built, shipped dark

`WFBE_C_SPECTATOR_DIRECTOR`, default **0**, so m0730g behaves exactly as described
above until it is armed. Built on a separate branch from a three-agent design pass:

- **Target classes** — `TAB` cycles players → AI/HQ teams → towns → HQs, with
  `N`/`B` cycling within the active class.
- **Orbit** — `O` toggles an orbit around the current target's live position
  (radius / height / degrees-per-second are all flag-driven) versus a static framing.
- **Auto-switch** — `G` arms a director rotation on its own one-second poll thread
  that scores candidates by interest (contested towns, teams in contact, biggest
  engagements) and cuts on a dwell timer; `[` and `]` adjust dwell live.

The seagull carrier was evaluated and **rejected** for 1.64 rather than assumed to
work. Every switch is a hard cut, because the movement loop already issues one
shared `camCommit 0` every 50 ms and would stomp any eased commit on the next tick.

---

## 4. What still needs to happen

- **Takistan** is staged but not yet in the rotation config: `server-pr8.cfg` is held
  exclusively by the server process while it runs, so the entry can only be
  repointed in the gap between stop and start. A waiter task is armed on the box and
  will swap `m0728i.takistan` → `m0730g.takistan` at the next restart, then verify
  both rotation lines. Until it fires, a Takistan rotation still runs the old PBO
  with no forced HC slots.
- **Zargabad** is not in the current rotation and was left unpacked; its mission tree
  already carries the same 2-slot fix whenever it is next built.
