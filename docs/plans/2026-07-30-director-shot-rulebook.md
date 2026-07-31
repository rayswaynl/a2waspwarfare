# WASP Spectator Director — Shot Rulebook v1

Synthesis of 3 research passes (broadcast/esports craft, film-cinematography + A2-engine constraints, academic auto-cinematography literature). Grounded primary sources: **He/Cohen/Salesin, "The Virtual Cinematographer" (SIGGRAPH 1996)**; **Christianson et al., DCCL/30-degree rule (AAAI 1996)**; **GAZED / Real-Time GAZED (arXiv 2311.15581)**; BIS `camSetFov`/`camCommit` wiki; Twitch encoding spec (`stream.twitch.tv/encoding`); Average-Shot-Length data (filmmakersacademy.com). All numbers below are the median/overlap of the three passes where they diverged, biased toward the tightest (most conservative) bound when sources disagreed, since a too-fast director is a bigger failure mode than a slightly slow one on a fixed-rate, no-DOF, no-motion-blur engine camera.

---

## 1. SHOT TYPES

| # | Shot type | Height AGL | Distance from subject | FOV (camSetFov value / ~deg) | Movement | Min / Max dwell | Target class |
|---|---|---|---|---|---|---|---|
| 1 | **WIDE ESTABLISH** | 80–150m | framed to hold full contested area (~150–300m radius in shot) | 0.80–0.95 (~65–80°) | static, or orbit 3–5°/s | 4.0s / 7.0s (9.0s allowed only in no-contact/patrol state) | town, HQ, multi-team overview |
| 2 | **TRACKING/TRANSIT** | 40–80m | 30–60m behind/above line of travel | 0.60–0.75 (~50–60°) | scripted track, aim at predicted position (see §3) | 4.0s / 8.0s | team/convoy in transit, no contact yet |
| 3 | **MEDIUM CONTEXT** | 10–25m | 8–20m (squad/vehicle) | 0.50–0.65 (~45-55°) | static, or push-in −15–25% distance over 6–10s ease | 3.0s / 5.0s | squad/fireteam, single vehicle |
| 4 | **TIGHT ACTION** | 2–6m (eye height) | 3–8m | 0.35–0.50 (~35–48°) | static; micro-correction only, cap 2°/s | 1.5s (hard floor) / 3.0s (1.5–2.0s allowed on hard-trigger kill/explosion cut) | player, single engagement |
| 5 | **ORBIT HERO — ground** | 5–12m | 15–30m | 0.45–0.60 | orbit 3–6°/s (only if subject stationary/near-stationary) | 5.0s / 10.0s | armor/vehicle hero shot, held position |
| 6 | **ORBIT HERO — air** | flight-altitude (heli 60-150m standoff; fixed-wing 150-350m standoff) | 60–150m (heli) / 150–350m (fixed-wing) | 0.15–0.30 (~15–25°, telephoto) | orbit 3–6°/s or straight track | 5.0s / 10.0s | helicopter, fixed-wing |
| 7 | **APEX / LINE-BRIDGE** | 30–60m | framed to hold both opposing centroids | 0.70–0.85 | static | 4.0s / 6.0s | mandatory neutral shot when crossing the 180° line, or a 3+ group multi-force rotation beat |
| 8 | **REACTION** | 15–30m | 20–40m | 0.50–0.60 | static | 2.0s / 4.0s | reinforcements / secondary group moving up |

Notes: FOV numeric convention per BIS `camSetFov` — **lower value = narrower/telephoto**, `angle = atan(FOV)*2`; engine default is 0.75. Ground-clearance check (≥0.5m over terrain-height query) applies to every waypoint, and any shot under 2.5m height must keep subject distance <15–20m or angle the frame so the grass-draw-distance line (~30–50m) falls behind a rise, not across open ground.

---

## 2. CUT RULES

**A. Dwell / cadence**
- Absolute global floor: **1.5s** — no cut, of any type, may land before 1.5s of the current shot (matches GAZED's hard minimum-duration floor).
- Per-type min/max as in the table above governs normal cutting.
- Target Average Shot Length (ASL), tracked as a rolling stat, not tuned directly:
  - Active combat (contact flag set within last 10s): **ASL 3–5s**.
  - No-contact / patrol / lull: **ASL 6–10s**.
  - Never sustain ASL < 2.0s for more than 3 consecutive cuts (Bourne-level frantic — treat as a bug state), never sustain ASL > 12s except a deliberate lull ESTABLISH hold.

**B. Switch hysteresis (prevents flicker between two similarly-scored targets)**
- A target switch may only be *evaluated* once the current shot's min-dwell floor for its type has been met.
- The candidate target's live interest score must exceed the current target's live score by **≥20%** before the switch is taken.

**C. 30-degree rule (same-subject re-cut)**
- A hard cut between two consecutive shots of the **same subject/group** is only permitted if at least one holds:
  - bearing delta ≥ **30°** (angle between (subjectPos − oldCamPos) and (subjectPos − newCamPos), projected to horizontal plane), **or**
  - a shot-*type* change (e.g. MEDIUM → TIGHT), **or**
  - a ≥**1.5×** change in camera-to-subject distance.
- If none hold: do not cut — extend the current shot (respecting its max dwell) or perform a smoothed reposition instead (see §D for the pan-speed cap that reposition must obey). Source: DCCL/Wikipedia "30-degree rule".

**D. 180-degree / line-of-interest rule**
- Per active engagement, define the line of interest as the horizontal vector between the two opposing forces' local centroids (or the attacker's axis of advance toward the contested town).
- Side test: `sign(cross(lineB−lineA, camPos−lineA))` must not flip across consecutive cuts on the same engagement.
- Crossing to the other side is only permitted by routing through an **APEX/LINE-BRIDGE** shot (both sides visible, FOV ≥0.70, held ≥4.0s) before the next cut lands on the new side.

**E. Variety pressure (repeat penalty)**
- Maintain a rolling history of the last 4 committed shots: (type, framing, subject id).
- Candidate scoring penalty: **−100% (reject)** if it repeats the immediately-prior shot's exact (type, framing, subject); **−25%** if it repeats any (type, framing) pair elsewhere in the last-4 window. Window resets on scene change (new engagement location).

**F. Establish-shot floor (whole-battlefield legibility)**
- ESTABLISH + APEX shots combined must occupy **≥40%** of cumulative runtime over any rolling **2-minute** window.
- If tracked share drops below 40%, the next scheduled cut is force-routed to WIDE ESTABLISH regardless of interest score.

**G. Max angular velocity (stream-safe pans/orbits)**
- Sustained pan/orbit rate ceiling for a "readable, non-judder" continuous move: **6–8°/s** (derived from the ~7s-per-frame-width rule at typical 40–50° horizontal FOV).
- Absolute ceiling before a move must become a cut instead: **20°/s**.
- If a required reframe exceeds ~35–40° of travel in under ~3s (i.e. would need >10–13°/s sustained), **do not pan — cut** directly to the new framing.
- Twitch's own 6000 kbps 1080p60 CBR H.264 spec (2s keyframe interval) makes fast-motion regions the hardest case for the codec — this is an independent, codec-side reason (not just perceptual) to keep sustained angular velocity under the 6–8°/s line whenever the shot is meant to be looked at closely (source: stream.twitch.tv/encoding).

**H. Acceleration / ease**
- Any continuous camera move (orbit, push-in, track) must ramp velocity in/out over **0.5–1.0s** at start and end — at 20Hz that's **10–20 ticks** of ramp, never a step-change in angular or linear velocity mid-move.
- Camera roll = **0** at all times (must be explicitly zeroed each tick; `camSetPos`/`camSetTarget` don't impose it automatically and it will drift from path math otherwise).

**I. FOV/zoom gating**
- Max FOV-units-per-second change **within a held shot**: **0.05/s** (a full 0.75→0.45 push takes ≥6s).
- Any FOV change larger/faster than that must be executed as a hard cut to a new shot, not an in-shot zoom (prevents the "game-menu zoom" read).

---

## 3. INTEREST-SCORE → SHOT MAPPING

| Interest-score condition (from existing scoring: contact counts, contested-town flag, player/team state) | Shot selection | Notes |
|---|---|---|
| No active contact anywhere; patrol/lull | WIDE ESTABLISH, orbit 3–5°/s, 6–9s hold; cycle across contested towns | Camera should *default* here between real triggers, not force-cut for lack of a target |
| Town flips to "contested" (first contact flag, 1–3 pax engaged) | WIDE ESTABLISH (4s) → cut to MEDIUM CONTEXT push-in | This is the "telegraph WHERE" beat |
| Team/convoy moving toward objective, speed ≥4 m/s, no contact, ETA ≤45s | TRACKING/TRANSIT, predictive aim: `predictedPos = currentPos + velocity × leadTime`, leadTime 3–8s, clamped once within 150m of the town | Pre-stage the camera at the destination, don't chase from behind |
| Moderate contact (4–8 pax, single engagement, no kill/explosion in last 10s) | MEDIUM CONTEXT, static or slow push-in, 3–5s holds | |
| Heavy contact (≥8–10 pax combined, sustained fire) | TIGHT ACTION, static, narrow FOV (0.35–0.45), chained cuts at ASL 3–5s; kill/explosion events may cut as fast as 1.5–2.0s | Never add camera pan on top when subjects already displace >10–15% of frame width/sec — hold static, micro-corrections only |
| 3+ groups in contact at one contested point (multi-force) | Rotate External(highest-score group) → External(next) → APEX, full rotation in **12–18s**, APEX mandatory once per rotation | Doubles as the mechanism that re-establishes the 180° line regularly |
| Town about to flip (capture progress crosses threshold / last defender eliminated) | WIDE ESTABLISH (4s) → push-in on MEDIUM/TIGHT of the flag/HQ, eased over 6–10s | "Wide then tight" — matches confirmed broadcast idiom |
| Stationary/held armor or vehicle, or a vehicle just destroyed | ORBIT HERO — ground, 3–6°/s, 5–10s | Never orbit fast around a *moving* vehicle — compounds angular velocity past the codec/comfort ceiling |
| Active helicopter / fixed-wing | ORBIT HERO — air variant per table (standoff + narrow FOV) | Standoff distance is a safety/trackability floor, narrow FOV compensates so the airframe doesn't shrink to a speck |
| Single standout player (kill-streak / clutch, score margin ≥20% over current target) | TIGHT ACTION, switch gated by hysteresis rule (§2B) | |

---

## 4. IMPLEMENTATION PRIORITY (smallest change first)

1. **Shot-type constant table** — add `WFBE_C_SPECTATOR_SHOTTYPES = [[type, hMin,hMax, dMin,dMax, fovMin,fovMax, minDwell,maxDwell], ...]` (the 8 rows from §1). Pure data; replaces whatever single hard-coded height/distance/FOV/dwell the current director uses. No behavior change to the 20Hz tick loop.
2. **Global hysteresis gate** — add `WFBE_C_SPECTATOR_MIN_DWELL = 1.5` and a 20% score-margin check into the existing target-rescore function; a switch may only be evaluated once current-shot minDwell (from the table, per its type) is met AND candidate score ≥ current score × 1.2.
3. **Ease-in/out ramp on the per-tick smoothing you just added** — clamp angular/linear velocity change per tick so a full 0–target ramp takes 10–20 ticks (0.5–1.0s at 20Hz); zero camera roll explicitly every tick. This is a direct addition to the existing per-tick `camSetPos`/`camSetTarget` smoothing code, not a new subsystem.
4. **30-degree same-subject cut gate** — before committing a hard cut where `newSubjectId == oldSubjectId`, compute bearing delta between old and new camera→subject vectors (horizontal plane); if <30° and shot-type unchanged and distance ratio <1.5×, block the cut and extend current shot instead (respecting its max dwell as the eventual fallback release).
5. **Variety-pressure rolling history** — a 4-slot ring buffer of (type, framing, subjectId) on each committed shot; subtract −100%/−25% from candidate scores per §2E before the existing target-selection argmax runs.
6. **Line-of-interest (180°) tracker per active engagement** — on engagement creation, store centroid pair (or attacker-axis) and the sign of the current camera's side; on every candidate cut, reject candidates that flip sign unless the candidate is explicitly the APEX/LINE-BRIDGE shot type held ≥4.0s.
7. **ASL + establish-share rolling stats** — track rolling ASL (for the sanity-check bounds in §2A) and rolling ESTABLISH+APEX runtime share over a 2-minute window; if share <40%, force next scheduled cut to WIDE ESTABLISH regardless of interest score. This is the first rule that actively overrides the score-argmax rather than just gating it.
8. **Predictive lead-point tracking for TRANSIT shots** — using existing per-unit velocity data already available to the interest-scorer, compute `predictedPos = currentPos + velocity × leadTime` (leadTime 3–8s, clamp once within 150m of a town) and aim `camSetTarget` at that point instead of current position when a tracked group's closing speed ≥4 m/s and time-to-contact ≤45s. Largest behavioral change — do last, after the gating/hysteresis machinery above exists to keep it from causing flicker.

**Honest capability note:** 20Hz `camSetPos`/`camSetTarget` + `camCommit 0` gives you full control over continuous scripted paths (orbit, push-in, track — computed as parametric position updates each tick, since there are no engine splines) and instantaneous hard cuts. It does **not** give you: real motion blur (fast pans will strobe on stream regardless of scripting — hence the 6–8°/s soft cap and 20°/s hard cap), depth-of-field (foreground-parallax framing and FOV compression are the only scriptable substitutes for subject/background separation), or roll/tilt smoothing for free (must be explicitly zeroed/ramped every tick or it drifts). All rules above are written to work within exactly those constraints — nothing here assumes cinematic-camera features A2 OA 1.64 doesn't have.

**Primary sources cited:** He, Cohen & Salesin, *The Virtual Cinematographer*, SIGGRAPH 1996 (grail.cs.washington.edu); Christianson et al., DCCL, AAAI 1996 / 30-degree rule (en.wikipedia.org/wiki/30-degree_rule); *Real-Time GAZED*, arXiv:2311.15581; BIS Community Wiki `camSetFov`/`camPrepareFov`/`camCommit`; Twitch encoding spec (stream.twitch.tv/encoding); Average Shot Length data (filmmakersacademy.com/glossary/average-shot-length-asl).