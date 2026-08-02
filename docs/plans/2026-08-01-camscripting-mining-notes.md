# Camscripting doc mining — Spectator v8 and adjacent lanes

**Date:** 2026-08-01
**Status:** UNTRACKED working note.

## Outcome (2026-08-01, after review against the actual v8 source)

Findings below were derived from a *command-frequency diff* — which commands v8 never calls.
That shows absence, not deficiency. Reading the v8 source showed two of the three "gaps" are
places where v8 deliberately solves the problem with a better primitive.

| # | Finding | Verdict |
|---|---|---|
| 1 | `preloadCamera` before director cuts | **DRAFT PR [#1815](https://github.com/rayswaynl/a2waspwarfare/pull/1815)** — branch `feat/spectator-v8-camscript-20260801`, commit `784fcb4e27`, base `deploy/m0801h-20260801`, flag `WFBE_C_SPECTATOR_PRELOAD` default 0. Static gates pass; **box smoke still OPEN** |
| 2 | `camSetRelPos` for follow cam | **REJECTED** — would be a downgrade, see below |
| 3 | `camPrepare*` / `camCommitPrepared` | **REJECTED** — no-op at best, harmful at worst, see below |
**Sources mined** (pulled from our own Codex library, `https://dl.chernaruscodex.com/jerry-hopper/`):

| File | What it actually is |
|---|---|
| `AMS_Camscripting_Tutorial_eng_V.0.99.pdf` | 27pp English camscripting tutorial (Assault Mission Studio). The useful one. |
| `AMS_Camscripting.Intro/scene.sqs` | Working example mission — a complete cam sequence incl. a per-frame follow-cam loop. |
| `Armed-Assault_..._Mr-Murray_EN.pdf` | 45.8 MB English edition of the Deluxe guide. Ch8 = camscripting, Ch10 = dialogs. |
| `ArmA_Edit_A2update1.zip` | **Not** a guide supplement — `commands.dat` + `unit.dat` for the AMS editor tool, "Updated for ARMA 2 by Celery, 17 Nov 2009". |

---

## Baseline: what Spectator v8 actually uses

v8 = `f41697da99` ("m0801i v8 DEFINITIVE rebuild — single-writer camera, event-track director,
broadcast overlay"). **Not an ancestor of HEAD `283c246495`** — lives on `crashfix/m0801i-20260801`
and `deploy/m0801h-20260801`. Owner cutover still pending.

Complete camera vocabulary across v8's four client spectator files
(`Client_SpectatorAimFrame/Director/Enter/Exit.sqf`):

```
camCreate 1   camSetPos 6   camSetTarget 6   camSetFov 3
camCommit 3   cameraEffect 4   camDestroy 1
```

That's the whole set. Seven commands.

**Absent entirely from v8:** `camSetRelPos`, `camPreparePos`, `camPrepareTarget`, `camPrepareFov`,
`camCommitPrepared`, `camCommitted`, `preloadCamera`, `camUseNVG`, `camSetDive`, `camSetBank`,
`showCinemaBorder`, `titleCut`, `camSetFocus`, `camSetDir`, `enableRadio`, `enableEnvironment`,
`fadeMusic`, `fadeSound`.

All of the above appear in the Nov-2009 A2 command list (1,142 entries) — see the caveat on that
list at the bottom before treating it as proof.

---

## Findings, highest value first

### 1. `preloadCamera` — texture pop on every director cut
**AMS §5.3.** The tutorial names exactly our situation: on a big camera position jump, terrain and
object textures are not resident yet, "what creates a nevertheless very negative effect."

Their SQS idiom:
```sqs
_preload = [] spawn {waitUntil{preloadCamera [16134.26,-96230.73,15.64]}}
@scriptDone _preload
```
SQF translation for us:
```sqf
_h = [] spawn { waitUntil { preloadCamera _nextPos } };
waitUntil { scriptDone _h };
```
v8's event-track director cuts between POIs anywhere on the map. Every one of those cuts currently
shows unloaded ground for a beat — on a stream, that is the single most visible defect.

**Design note:** do *not* block the director loop on the preload. Fire it during the outgoing
shot's dwell time so the next position is resident before the cut is called. That turns a blocking
wait into free latency hiding.

### 2. `camSetRelPos` — follow cam without hand-rolled offset math — **REJECTED**

> **Verdict after reading v8:** do not do this. `Client_SpectatorAimFrame.sqf:88-109` already
> derives the follow pose with `_subject modelToWorld [0,-8,3]` — which is target-relative
> placement, same as `camSetRelPos` — and then adds a velocity **lead** and an **EMA ease**
> (`_gk`/`_gf` gains) on position and aim independently. `camSetRelPos` offers no easing hook
> and no way to fold in the lead, so adopting it would mean deleting the smoothing that makes
> v8's follow watchable. `modelToWorld` is the better primitive here. Original note kept below
> for the record.
v8 does 6× `camSetPos` with computed positions. `camSetRelPos` expresses "offset relative to the
target" natively. The AMS `scene.sqs` `#Loop` block is a complete chase cam in five lines:
```sqs
#Loop
_camera camSetTarget UH60
_camera camSetRelPos [10,-15,4]
_camera camCommit 0
@camCommitted _camera
goto "Loop"
```
**Scope boundary:** this is an *implementation primitive* for follow shots v8 already performs.
It is not the convoy-anticipation/lookahead behaviour the owner rejected — do not let it grow into that.

### 3. `camPrepare*` + `camCommitPrepared` + `camCommitted` — **REJECTED**

> **Verdict after reading v8:** the premise was wrong. I claimed "the camera is in a mixed state
> across those writes". It is not. `Client_SpectatorAimFrame.sqf` is an `onEachFrame` handler that
> writes pos/target/FOV and then commits with `camCommit 0` **inside the same frame** (line 210) —
> nothing renders between the writes, so there is no observable mixed state. Converting to
> `camCommitPrepared 0` would be a pure rename; converting with a non-zero time would be worse,
> because each frame would restart a timed interpolation and fight the per-frame integrator.
> `waitUntil { camCommitted _cam }` is also explicitly banned in that file — its header rules
> forbid `sleep`/`waitUntil` because the handler is unscheduled. Original note kept below.
v8's stated law is "single-writer camera". The prepare/commit pair is the engine's own mechanism for
exactly that: stage pos/target/FOV, commit atomically, and test completion with `camCommitted`
rather than inferring it. Today v8 writes pos, then target, then FOV, then commits — the camera is
in a mixed state across those writes. This is the cheapest structural win available and it
*strengthens* the invariant v8 was rebuilt around.

### 4. `enableRadio false` / `enableEnvironment false` — broadcast audio hygiene
**AMS §8.3.** One line each. v8 ships a broadcast overlay and the box runs caster slots with
autostart; suppressing radio chatter and ambient during the caster feed is a direct quality win for
the stream. Must be restored to `true` on spectator exit.

### 5. `camUseNVG true` — night coverage
**AMS §8.4.** WASP runs at all times of day. A night match currently means the spectator camera sees
essentially nothing. One command, gated on time-of-day.

### 6. `titleCut ["", "BLACK IN", n]` / `"BLACK OUT"` — transitions
**AMS §8.1.** Clean fades on director cuts and on spectator enter/exit, instead of a hard snap.
Also the honest fix for any cut that would otherwise reveal a half-loaded scene (pairs with #1).

### 7. `showCinemaBorder` — letterbox for the broadcast overlay
Cosmetic, one line, reads as "production" on stream.

### 8. `camSetDive` / `camSetBank` — establishing-shot vocabulary
Dive and roll angles for establishing shots. Lowest priority here; listed for completeness.

---

## Cross-cutting: an A2 command **allowlist** for the lint gate

`commands.dat` contains **1,142 A2 scripting command names**. Our lint gate's `A3_TRAPS` is a
**27-entry denylist** (`Tools/Lint/check_sqf.py:495-498`) — it only catches A3-only commands somebody
already thought to add.

An allowlist check derived from `commands.dat` catches *any* command not in the A2 set, including
ones nobody has been burned by yet. That is a categorically different class of coverage than a
27-entry denylist.

**Ship it warn-only, not as a hard gate.** The list is dated 17 Nov 2009 — Arma 2 1.04 era. It
predates OA and the 1.60/1.62/1.64 command additions, so it *will* false-positive on legitimately
available commands. Correct use: union it with the OA command set, or emit it as an advisory code
that a human clears. Do not wire it as a blocking gate on that data alone.

`unit.dat` is A1/OFP weapon and magazine class lists — same trap as Mr-Murray Ch3. Not useful to us.

---

## Secondary: Mr-Murray Ch10 (Dialogs) → WF menu remake / Loadout Lab

Ch10 covers `resource.h` constants, base/sub control classes, fonts, buttons, frames, and video
sequences (pp. 279–297 in the **German** edition — EN pagination differs). This is the reference
material for the deferred WF menu UI remake and for Loadout Lab dialog work. Not mined in detail
here; flagged as the known-good starting point when that lane reopens.

---

## Caveats — read before acting on any of the above

1. **`commands.dat` is not BI-authoritative.** It is AMS tool data maintained by a community author
   in Nov 2009. It is corroborating evidence that a command exists on A2, not proof. Every command
   above must go through the repo's `a2oa-verify-command` ladder before it lands in an edit.
2. **All AMS examples are SQS**, not SQF — `@camCommitted`, `~3`, `goto`, `?`. They need translating
   to `waitUntil {}` / `sleep` / structured control flow, not pasting.
3. **Findings target `f41697da99`, not HEAD.** If v8 changes before cutover, re-run the vocabulary
   check before implementing.
4. **Repo flag policy applies.** Every item here is a feature addition, so each needs its own
   `WFBE_C_*` flag defaulting to 0, with the mission byte-identical to HEAD when the flag is off.
