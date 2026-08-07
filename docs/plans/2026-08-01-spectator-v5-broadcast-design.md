# Spectator v5 — Broadcast Mode design

**Date:** 2026-08-01 · **Status:** owner-approved direction (this doc = the spec)
**Base:** spectator v4.2 (free-cam + director, folded in #1799) + caster slots (#1798, armed 50b11b91a9)
**Owner decisions captured:** audience = live stream with AI-war visuals · control = auto-pilot with
manual seize · intel = omniscient camera with staged reveal · reveal trigger = danger-close ·
switchable overlay modes.

## 1. Goal

Turn the spectator into a broadcast tool for streaming WASP's AI-vs-AI war: a camera that is
always somewhere interesting *before* it gets interesting, and an overlay that tells the war's
story without a caster having to talk. Secondary: the same machinery doubles as an admin/AI-debug
view at zero extra cost.

**Non-goals:** recorded-highlight extraction (separate pipeline), player-facing spectate for the
dead, any change to gameplay or AI behaviour. The mission stays byte-identical for non-casters.

## 2. The three overlay modes (H cycles; auto-pilot identical underneath)

| Mode | Audience | Content |
|---|---|---|
| **BROADCAST** (default) | stream viewers | score bar (towns + momentum per side), location tag, ONE danger-close caption at a time (bottom third) |
| **WAR ROOM** | analyst segments / admin debug | full map overlay: both commanders' target towns + allocations, dispatch arrows, town SV bars, economy + supply readouts, GUER ledger |
| **CINEMA** | b-roll / recap capture | letterbox, zero UI; director keeps working silently |

Modes change only what is drawn, never what the camera knows. Caster can pin a mode
(suppresses H-cycle wraparound surprises mid-shot).

## 3. Intel model: omniscient camera, danger-close reveal

- The **director** reads full commander intent (target towns, dispatched forces, postures) and may
  pre-position on a target town while attackers are still minutes out. Arrive early.
- The **overlay** reveals an attack only when attackers close within `WFBE_C_BCAST_REVEAL_RANGE`
  (default 500 m) of the target — the viewer learns of it roughly when the defenders do. Reveal late.
- The gap between those two is the product: "why are we watching this quiet village… oh."
- GUER activity uses the same rule (cell within range of its objective).

## 4. Data channel (security decision)

Server maintains a compact snapshot (`WASP_BcastSnap`, ~5 s cadence): per side — target towns,
dispatched/arrived counts, posture, funds/supply, town SV deltas; plus danger-close events.
Delivered via **publicVariableClient to connected allowlisted casters only** (server tracks caster
presence from the existing caster-seat marker + UID allowlist). **Never** a global publicVariable:
intent data on every client is the same competitive-integrity leak as the unsanitized public
`stats.json` (`commanderIntel`) — the class of leak is known and must not be reintroduced.
Casters-only PVC means an AI-only stream and a live human match get the same code path safely.

## 5. Director v5: pre-positioning

Extends the v4 tiered auto-pick (contact > units > wide establishing) with an **anticipation
tier** above contact: when the snapshot shows a dispatched force whose distance-to-target is
closing and ETA < ~90 s, cut to a wide establishing shot of the target town before contact.
Existing dwell/cooldown/orbit params unchanged. Manual seize: any camera input takes control;
`WFBE_C_BCAST_AUTOPILOT_IDLE` (default 45 s) of no input returns to auto.

## 5a. Camera language: orbit + long lens, never dolly-close (owner 2026-08-01)

Owner verdict on the live v4 director: *"I really do not like these very close close-ups the
spectator auto cam does, I prefer orbiting and zooming in on stuff."* This is a standing style
rule for every shot the director composes, not a one-off tweak.

**The principle: get closer optically, not physically.** Approach a subject by narrowing FOV from
a standoff (long lens) instead of flying the camera in (dolly). Three reasons this is right for
this project specifically:

1. It is the broadcast look — sports and esports cameras sit far back on long glass.
2. Close cameras clip terrain, buildings and the subject's own geometry; a standoff cannot.
3. It compounds with P1: less camera-to-subject relative motion means less for the attached
   camera and the aim easing to chase, so the picture is steadier for free.

**Current state (what produces the complaint):**

| shot | radius | height | FOV band |
|---|---|---|---|
| TIGHT | **8 m** | 4 m | 0.35–0.50 |
| MEDIUM | **18 m** | 12 m | 0.50–0.65 |
| WIDE | 180 m | 110 m | 0.80–0.95 |

TIGHT at 8 m is inside personal space, and there is a 10× hole between MEDIUM and WIDE. Worse,
when a subject is *engaged* the director abandons orbit entirely and pins the camera statically
behind the subject (`_shotDir = getDir _t; _angle = _shotDir + 180`) — exactly the shot the owner
is objecting to, fired precisely when the action is most interesting.

**Target state — same apparent subject size, much greater distance:**

| shot | radius | height | FOV band | reads as |
|---|---|---|---|---|
| CLOSE (was TIGHT) | **35 m** | 14 m | **0.12–0.20** | subject fills frame, long lens |
| MEDIUM | **70 m** | 30 m | **0.28–0.40** | subject + immediate contacts |
| WIDE | 180 m | 110 m | 0.80–0.95 | unchanged — establishing |

Roughly: multiply radius ~4×, divide FOV ~3× — apparent size is preserved while the camera is far
enough out to clear geometry. Numbers are a starting point to tune on the box, not gospel; the
*rule* (standoff + narrow FOV, never a close dolly) is the part that is fixed.

**Orbit becomes the default motion, including while engaged.** Remove the engaged-static-behind
branch; an engaged subject orbits like any other, just slower. Orbit rate scales inversely with
shot distance so angular velocity on screen stays even: CLOSE ~3 deg/s, MEDIUM ~4 deg/s, WIDE ~4
deg/s (existing `WIDE_ORBIT_DEG_PER_SEC`). A caster can still stop orbit manually with `O`.

**Vehicle/air standoff multipliers** (`VEH_STANDOFF_MULT` 2.5, `AIR_STANDOFF_MULT` 4.0) stack on
top of the new radii as they do today, and their FOV-min floors must be re-tuned against the new
bands or a jet will end up framed as a dot.

## 5b. GUER must be followable (owner 2026-08-01)

The insurgency is a third of the war's story and a caster currently **cannot watch it**. Verified
in code, three pools and GUER falls out of the two that matter:

- **PLAYER pool** (`Client_SpectatorEnter.sqf` N/B cycle, and `DirectorBuildPlayers`) filters
  `isPlayer _x` over `allUnits`. GUER is AI-only, so no GUER unit can ever appear. HC bodies are
  already excluded here by name — the same list-building site is where GUER support belongs.
- **TEAM pool** (`DirectorBuildTeams`) reads `WFBE_ACTIVE_AICOM_TEAMS`, maintained only by the
  WEST/EAST commander team events in `Server_HandleSpecial.sqf`. GUER runs its own base-less deck
  (`AI_Commander_Wildcard_GUER`) and never publishes into that feed, so GUER squads are absent.
- **TOWN pool** *does* count `resistance` in its belligerent mix, so a town where insurgents are
  fighting can be picked. This is why GUER action is visible but never followable — the caster can
  watch the place, never the participants.

**Fix — a GUER target class, built client-side, no new replication.** GUER units are ordinary
networked AI, so the client can find them in `allUnits` by `side _x == resistance`. Build the pool
from **group leaders only** (`_x == leader (group _x)`), which keeps the cycle usable when GUER
volume is high (GUER volume is deliberate and uncapped by design — never nerf it to make the
camera's life easier).

- New director class `"GUER"` alongside PLAYER / TEAM / TOWN, scored on the TEAM model: alive
  count × size weight + contact × contact weight, minus the idle penalty. `TAB` pins it like any
  other class.
- Manual `N`/`B` cycle gains GUER leaders behind `WFBE_C_SPECTATOR_TARGET_GUER` (default **1**),
  labelled distinctly (e.g. `GUER <town> (n)`) so a caster knows what they armed.
- Reuse `DirectorContactCount` unchanged; it already takes an origin side and counts non-matching
  sides, so it is correct for `resistance` with no edit.
- The GUER director's own telemetry (`AICOMSTAT|v3|DIRECTOR|GUER`, `GDIR_LEDGER`) is the natural
  scoring input once the P2 snapshot exists — until then client-side contact counting is enough.

Acceptance: with the director pinned to GUER, the camera cycles distinct insurgent squads and
follows them; with the director off, `N`/`B` includes GUER leaders in the manual cycle.

## 6. Follow-cam smoothing (owner jank report, ships first)

v4's follow-cam chases moving targets with per-tick scripted positioning — visibly jittery on
vehicles and inherently unfixable at script cadence. v5 follow mode **attaches** the camera
(`attachTo` target with the current offset, engine-interpolated) and detaches on WASD/mode
change. Free-cam is untouched. This is item 1 of implementation: smallest change, biggest
perceived quality win, independently shippable.

## 7. Score bar + captions (BROADCAST)

- Score bar: towns held per side (W/E/G), momentum arrow from town-delta over the last 10 min,
  match clock. Top edge, one line, Consolas-style minimalism to match existing HUD.
- Captions: queue of danger-close events; show one at a time ≥ 8 s each, newest-preempts only for
  strictly bigger events (town assault > skirmish). Text pattern: side + force size class + town
  ("OPFOR armour closing on Figari").

## 7a. Caster operator UI (owner 2026-08-01: "UI for casting player can be much improved")

**Current state.** The spectator draws one always-on card — `SHOT <mode>` / `TARGET <name> |
DIRECTOR AUTO <on/off>` — plus, in FULL mode, a two-line wall of every keybind. That is an
operator debug readout: it describes the *camera* and says nothing about the *war*. It is also
permanently on screen, so on a single-PC stream it is burned into the broadcast.

**The constraint that shapes this whole section:** with one PC, the caster's screen IS the stream.
There is no privileged operator monitor. So every pixel is either designed for the viewer, or it
is visible clutter. The answer is not "hide the operator UI" — the caster genuinely needs it — but
to split it by *lifetime*:

- **Broadcast chrome** — persistent, designed, viewer-facing: the §7 score bar and caption slot.
- **Operator chrome** — transient, summoned: appears on the action that needs it, fades on a timer.

**Rules for operator chrome**

1. **The keybind wall is summoned, not resident.** It fades ~6 s after the last input and returns
   on `H`. A caster needs it for the first minute of a session and never again; the viewer never
   needs it.
2. **The status line compresses to a corner tag** — one short mono line, low opacity, e.g.
   `CLOSE · 3rd Rifle · AUTO`. Mono because it is instrumentation (brand rule); corner because it
   must never compete with the caption slot.
3. **Every transient element fades on the same timer** so the screen resolves to a clean frame
   between actions. A caster who stops touching the controls should be left with a broadcast
   picture, automatically.

**What is missing and worth adding — the shot list.** The single highest-value addition, and it is
nearly free: the director *already* builds a scored candidate list every poll (towns, teams,
players, and GUER once 5b lands). Today it scores them, picks one, and throws the rest away.
Surfacing the **top 3 alternatives** as a small ranked peek — label, class, contact count — turns
the caster from reactive to proactive: instead of discovering the fight after the cut, they can see
"Meaux 6 contacts / 2nd Armoured 4 / Figari 2" and choose. With the P2 snapshot it gets better
still: anticipation-tier candidates can appear in that list *before* contact, which is the whole
point of the omniscient-camera design.

The shot list is operator chrome — summoned (a key, or auto-shown briefly after each auto-cut so
the caster sees what was passed over), never resident.

**What the caster still lacks and should get**

- **Where am I** — town/grid name of the current subject, not just its unit name.
- **What is happening here** — contact count and side mix at the current subject, which the
  director already computes for scoring and currently discards.
- **Why did it cut** — a one-word cut reason on auto-cuts (`CONTACT`, `CAPTURE`, `ESTABLISH`), so
  the caster can narrate the director's logic instead of guessing at it.

**Not in scope here:** the WAR ROOM analyst panel (§2) is a *mode*, not operator chrome; it is
viewer-facing and stays persistent while selected.

Acceptance: after 10 s of no input the screen shows only broadcast chrome; `H` restores the
keybind wall; the shot list shows the director's true next-best candidates (cross-check against
`SPECTATE`/director telemetry); every operator element is mono, corner-anchored, and never overlaps
the caption slot.

## 8. Spectator entry is caster-seat-only (owner decision 2026-08-01)

The UID allowlist alone leaves the spectator action attached to an allowlisted player even in a
normal combat slot — clutter, plus one misclick from parking a live soldier mid-firefight.
`WFBE_C_SPECTATOR_CASTER_SEAT_ONLY` (default **1**): `Client_SpectatorAttach` requires the
`wfbe_caster_slot` seat marker **and** the UID allowlist. Set 0 to restore v4 behaviour
(UID-only) for solo testing on missions without caster seats.

## 9. Constants (all new, append-only, defaults inert for non-casters)

`WFBE_C_BCAST_ENABLED` (0) · `WFBE_C_BCAST_SNAP_SEC` (5) · `WFBE_C_BCAST_REVEAL_RANGE` (500) ·
`WFBE_C_BCAST_AUTOPILOT_IDLE` (45) · `WFBE_C_BCAST_ANTICIPATE_ETA` (90) ·
`WFBE_C_SPECTATOR_CASTER_SEAT_ONLY` (1) · mode default + pin.
Flag-off = no snapshot builder runs, no PVC traffic, spectator behaves exactly as v4.2.

## 10. Phasing (each phase independently shippable + war-gated)

1. **P1 follow-cam attachTo + caster-seat-only entry gate** (fixes live jank + slot clutter; no new systems)
2. **P2 snapshot + PVC channel + WAR ROOM overlay** (data first — visible value, no director change)
3. **P3 BROADCAST mode** (score bar + danger-close captions off the same snapshot)
   - and the **caster operator UI (7a)**: fade-timer chrome, corner status tag, shot list
   - also here: **camera-language re-tune (5a)** and **GUER target class (5b)** — both are
     director-local, need no snapshot, and can land earlier if P2 slips
4. **P4 director anticipation tier + seize/release polish**
5. **P5 CINEMA + mode pinning** (trivial once 2–4 exist)

## 11. Acceptance

- P1: owner follows a moving vehicle 60 s — no visible jitter.
- P2: WAR ROOM shows both commanders' current target towns matching `AICOMSTAT` log ground truth;
  a non-allowlisted client shows **nothing** and receives **no** `WASP_BcastSnap` PV traffic
  (verify with a second vanilla client).
- P3: a town assault produces exactly one caption, at reveal range, not at order time.
- P4: director cuts to the target town before first contact in ≥ half of observed assaults.
- Every phase: lint gates, mirrors, flag-off byte-identical, box war gate before live cutover.

## Known residuals tracked elsewhere

- HC/caster lobby slot ordering (cold-boot WEST preseat) — #1596 recut, carded.
- `_display` serialization residual in `GUI_RespawnMenu.sqf` / `GUI_Menu_UnitCamera.sqf` — carded.
