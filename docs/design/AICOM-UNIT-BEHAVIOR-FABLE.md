# AICOM unit behavior & logic — Fable-led deep review (2026-07-02)

Ray: "Go over, analyse and improve AI commander behavior (its units also!) … I really want it to work
properly. (fable only, other agents can look for / feed you info)."

Analysis by the main loop (Fable). Agents supplied only raw inputs: verbatim code (`a4a29918`, from git
HEAD a6a1f15a1) + full-match journey stats (`a4de4bba`, from the archived 7h WEST-win RPT). Every claim
below is traceable to one of those two.

---

## 0. The one number that reframes everything

**WEST and EAST killed 32 of each other's units in 7 hours.** (W→E 28, E→W 0, W→W 2, E→E 2.)
GUER dealt **2,187** kills and took **1,607**. Total kills 3,813.

This match was not WEST vs EAST. It was two armies drowning in an insurgent sea, with a thin trickle
of survivors occasionally reaching a town. Every unit-behavior problem below compounds against that
backdrop: the map BETWEEN towns belongs to GUER, and the AI marches through it in engage-at-will mode.

## 1. The journey funnel (where units actually go)

583 dispatches → 40 arrivals (**6.9%**). By leg length: <500m → 33% arrive; 500-2000m → 11%;
**2000m+ → 4.6%** — and 67% of all dispatches were 2000m+. Median successful journey: 20 min
(dispatch→arrival), while the FRONT primary target changed every ~4 min (WEST 102 changes, EAST 122;
spearhead repicks 135). EAST oscillated Krasnostav↔Berezino↔Olsha↔Dubrovka almost 1:1 for 190 minutes.

**The failure is bimodal, not uniform.** 26 of 46 teams DID arrive at least once. Meanwhile a handful
of zombie teams consumed the budget: `B 1-1-H` **59 dispatches, 0 arrivals**; `B 1-1-M` 48; `B 1-1-L` 33;
`B 1-2-G` 29; `B 1-1-B` 28; `B 1-1-K` 23. Thirteen teams (11 WEST) had ≥3 dispatches and never arrived.
STRANDED movement is bimodal too: 49 of 79 moved <50m (physically wedged) vs 22 moved 300m+ (moving,
diverted, never closing).

Two zombie signatures, different roots:
- **Wedgers** (B 1-1-C: 33 unstuck strikes): the strike ladder (tiers 1-4: 81/48/30/17 fired) RESETS on
  any progress, so a team that lurches 200m and re-sticks cycles tier-1 forever and never earns the
  tier-3 teleport recovery. No terminal state exists — it thrashes for hours.
- **Orbiters** (B 1-1-H: 59 dispatches, few strikes): stuck detection requires `behaviour != "COMBAT"`
  (AssignTowns Hook-B L111) and moved<200m. A team permanently entangled with GUER en route is in
  COMBAT, moves constantly, closes never — invisible to every recovery system, re-aimed by every
  repick, forever.

## 2. Why they never arrive: the march itself

The transit stack (driver L738-822) is genuinely good now — road-snapped chains (~1 node/600m, cap 24,
lane jitter), COLUMN, FULL, remount-for-the-long-leg, seat-fraction gate, GUER-town route avoidance for
trucks, waypoint chain made current (the WAVE-3 fix). **The machinery moves. What kills journeys is
posture + environment:**

- Every transit waypoint ships `["AWARE","RED",…]` — **RED = engage at will** (STANCE task #1 chose
  this deliberately: "advance-and-engage"). On a map where GUER owns the space between towns, RED means
  every contact within detection range converts the column into a firefight. A2 groups in contact stop
  making waypoint progress. Result: 4.6% arrival on long legs, orbiter zombies, and 1,990 army-vs-GUER
  kills against 32 army-vs-army.
- The founding posture (driver L94) is also team-level RED.
- Nothing protects a journey in progress: spearhead repicks, stall-advance, strike pulls, and Strategy
  grabs all bump the order seq mid-leg; each bump = WaypointsRemove + full re-lay + journey restart.
  20-min journeys under a 4-min target-change cadence = most journeys die administratively.

## 3. Strategy-layer observations (logic in general)

- **EAST sat in DEFEND from minute 201 to 415** while holding 1 town vs 4 — at near strength PARITY
  (myStr 46-55 vs 51-66). A losing side with an intact army defended itself to death. There is no
  "losing side must press" floor in the live posture logic.
- **MHQ relocation: 43 attempts, 43 aborts** (31 `no-buffer-clear` @1600m clear-ring — impossible in
  GUER-land; 12 `advance-below-min`). The commander NEVER moves its base forward, so every leg stays
  2000m+ all game. This single dead feature feeds the distance problem all match.
- Founding is healthy (119 W / 70 E, classes sensible, veteran-skill path works) but teams average
  5.5-6.6 live units against the 8-cap — chronic understrength (no refit; SVC is armour-only) and they
  are dispatched anyway.
- Server-local fallback founding (Teams L1094+) sets NO posture/skill — engine defaults (minor; HC path
  covers live).

## 4. The fix package (wave-2, all flag-gated, A2-OA-safe)

Ranked by expected arrival-rate impact:

**F1 — March discipline: YELLOW in transit, RED on the objective.** `WFBE_C_AICOM_MARCH_YELLOW=1`.
Transit waypoint props + team-level combat mode → `YELLOW` (return fire, don't pursue); the FINAL
approach node + arrival SAD + capture phase stay `COMBAT/RED`. Columns roll past insurgent pot-shots
instead of dissolving into them. One flag, touches the props at driver L779/781/812/814/819 (+ team-level
L765) and Server_AI_SetTownAttackPath transit nodes. Directly attacks the 32-vs-2187 pathology.

**F2 — Journey commit (target stickiness).** `WFBE_C_AICOM_JOURNEY_COMMIT=1`. A team with an OPEN
dispatch that is MAKING PROGRESS (dist-to-target down ≥150m vs dispatch breadcrumb — townorder already
stores t0 + leader pos) is exempt from repick/strike-grab/reassign; only town-flipped, emergency-defense,
or explicit console orders override. Plus spearhead/FRONT hysteresis: a side's primary may change at most
every ~8 min (Strategy-side dwell). Kills the administrative journey-death + EAST's 4-town oscillation.

**F3 — Orbiter detection.** Hook-B upgrade: track progress-toward-target per watcher pass; in-contact
but no-progress for 3 consecutive windows (~6 min) = stuck-equivalent → enters the strike ladder (today
COMBAT exempts them from everything).

**F4 — Ladder decay + terminal recycle.** (a) Stuck-strike ladder DECAYS by 1 on progress instead of
resetting to 0 → oscillating wedgers eventually reach tier-3 teleport recovery. (b)
`WFBE_C_AICOM_FAILED_JOURNEYS_RECYCLE` (default 0 = off; set e.g. 6 to enable): a team accumulating N STRANDED/abandon closures
since its last arrival is RETIRED at a player-safe moment (existing disband idiom, never player-visible)
and refounded fresh at base — mounted, near base, short first leg. Ends the 59-dispatch zombies.

**F5 — Near-target bias in allocation.** Prefer targets <2000m when any exist (arrival 11% vs 4.6%);
weight the fist/nearest-pick by distance band, not pure priority. Compounds with SPREAD (wave-1) and F6.

**F6 — Revive MHQ relocation.** ringClear 1600 → ~500 + relax advance-below-min (flag the new values).
A forward-creeping base turns 2500m legs into 800m legs — the quiet force-multiplier for everything above.

**F7 — Losing-side aggression floor.** Posture logic: towns < enemy towns AND base not under direct
threat → minimum PRESS (never park in DEFEND at strength parity while losing on territory). Fixes the
EAST-sits-out-the-back-half pattern.

**F8 (dial, Ray's call) — Baseline unit skill.** Only the veteran flag sets skill today (0.85); everyone
else is engine default. Option: founding baseline `setSkill 0.65`. Snappier fights, affects player-vs-AI
difficulty too — Ray decides.

## 5. Sequencing

Wave-1 (in flight) already lands: SPREAD (anti-dogpile), HOLD (keep captures), assault-structures fire
phase, siege decay, remnant caution, refit flip (svc), GUER cap (wave-2 with stipend fix). **F1-F7 are
wave-2** — same files as wave-1, so they implement AFTER integration, as one reviewed batch, then
cmdcon41. F1+F2+F4 are the big three; F6 the sleeper. Soak metric: arrival rate (target: 6.9% → >30%),
army-vs-army kill share, zombie-team count (target: 0 teams >10 dispatches without arrival).

---

## 6. Wiki cross-check addendum (canonical wiki, 2026-07-02)

- **F1 (YELLOW-march):** the wiki CONFIRMS RED-on-march was deliberate — `AIMoveTo` is documented as "aggressive
  march posture" and a purpose-built guard stops `UpdateTeam` re-stamping AICOM teams back to AWARE/NORMAL/YELLOW.
  BUT: no recorded experiment with YELLOW transit, no dawdling-vs-banzai trade-off discussion anywhere — the choice
  predates the arrival telemetry. My 32-vs-2187 / 4.6%-arrival data is the first hard evidence on it. (The
  garrison-stance→RED record is about DEFENDERS standing passive — different context, not a contradiction.)
  → Ray's call (his design lineage).
- **F2:** an AssignTowns sticky-order guard + committed-mass pre-seed ALREADY exist (V0.8 "advance as a wave") —
  the live churn (122 FRONT changes, 135 repicks, 59-dispatch zombies) defeats them via abandon/strike/fist paths.
  Journey-commit + hysteresis is additive and in the spirit of the recorded design. Wave-1's FIST_TOWNS=2 matches
  the wiki's SPEARHEAD_TOWNS_MAX=2 intent.
- **F4 (recycle):** precedent exists — B68 retreat-cull recycles far lone survivors, and the B69 roadmap demands a
  `behaviour != COMBAT` guard on any cull. My zombie-recycle adopts both guards (never cull a fighting team, never
  near a player).
- **F6 (MHQ):** the B69 roadmap already contains the fix rows (per-tick re-drive ✅ done; MIN NET-ADVANCE gate;
  final-deploy re-validation; contact de-escalation; human-contact defer). Implement ring-relax WITH those rows,
  not instead of them.
- **F8 (skill):** the wiki records `CreateTeam (skill 90)` at team build + the W7 veteran scalar — units may
  already be ~0.9 skill; my "engine default" assumption needs code verification before any change. VERIFY FIRST.
- **GUER stipend CORRECTION:** the recon's "stipend economy dead / kill-attribution mis-wired" is a FALSE ALARM
  for AI-only matches — the stipend + kill counter gate on GUER *PLAYERS* (`isPlayer`, WFBE_GUER_PLAYER_KILLS)
  by design; zero GUER players overnight → zeros are CORRECT (matches memory `wasp-guer-stipend-not-broken`).
  GUER wave-2 work reduces to BODY-count capping (GROUPS_MAX=80 exists; bodies still peak 224).
- **Cheap adds from the wiki's own quick-win list (wave-2):** depot-hold formation LINE/STAG instead of WEDGE
  (one grenade wipes a WEDGE cluster at the hold); randomize the camp dwell `sleep 45` → `35 + random 20`.
- Unmined wiki sources (B69 sketch bodies, full roadmap, worklogs, jsonl stores) could still hold stance-era
  journal entries — noted as a gap, not blocking.
