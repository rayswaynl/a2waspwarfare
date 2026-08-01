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
