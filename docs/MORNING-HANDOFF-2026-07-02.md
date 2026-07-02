# WASP overnight handoff → morning (2026-07-02)

## TL;DR
**The all-night problem — "AI doesn't capture towns" — is SOLVED and verified.** The AI now road-marches
to towns, holds the depot, and flips them (live cmdcon40, `CAPTURED=6+` confirmed). The remaining behavior is
a **see-saw stalemate** (both sides stuck at 1 town for ~2h) — a *tuning* problem, fully designed + staged, not
a broken pipeline. Server healthy all night (0 HC errors, 3/3 procs, ~44 fps). No unattended risky deploys.

## What's LIVE right now
- **Build:** `cmdcon40aicom` (Chernarus active; Takistan parked). Clean: 0 script errors, AICOMHB v2, WASPSCALE
  emitting, ~44 server / ~47 HC fps.
- **Fixes live in cmdcon40:** movement root fix (teams actually move — the real capture fix), drain-wait,
  arrival-gate (250m), grade-stamp `!=` fix, class-TEXT marker (SOL/MED/…), WASPSCALE v2, HC lobby label.
- **Everything else is STAGED in PR #136 (not deployed).** Deploy policy overnight was: nothing new live without
  your word (cmdcon40 was your authorized "final town cap fix").

## Recommended MORNING ORDER
1. **Deploy SPREAD+HOLD** → `docs/design/SPREAD-AND-HOLD.md`. This is THE fix for the see-saw. Two flag-gated
   changes: (a) SPREAD — stop the Allocator dogpiling 7 teams on one town (widen the "fist" to 2-3 towns +
   per-town cap); (b) HOLD — the first team to capture a town stays on DEFEND ~180s so it doesn't flip back.
   Implement (it's line-verified), boot-smoke, soak → myTowns should climb past 1. **This is the highest-value
   next step.**
2. **AICOM aircraft** → `docs/design/AICOM-AIRCRAFT.md`. (a) helis spawn at BASE not your owned airfield — safe
   2-edit fix (`_isAirTeam`); (b) helis ignore aircraft-factory research — needs pairing with an AICOM
   air-research step (don't flip the flag alone or air disappears). You own an airfield now, so this matters.
3. **60-agent audit fixes** → `docs/design/MISSION-AUDIT-60.md`. Already DONE + staged: HQ round-ender
   `_mhq→_MHQ` (`52f9eb169`), RequestStructure find-guard (`c179aa86f`), Core_MVD log (`42c899d31`). **Your
   call** (not auto-applied): Groups_US GER/BAF→US classnames (changes which units spawn — did you want the
   variety?), gear-price double-count (ambiguous A2 semantics). ~half the raw audit flags were false positives
   (documented in REJECTED).
4. **AI-count OSCILLATES with GUER waves (self-limiting — not a runaway):** GUER insurgent count spikes then
   collapses (observed 61→209→224→86 across ticks), pulling hc_fps down to ~16 at a peak then recovering to ~47
   as the wave dies. AI_TOT rides it (~257-395). It self-corrects each time — no restart was needed overnight.
   Still worth a daylight look at GUER wave sizing/cap (209-224 peaks are heavy), but it is NOT causing a
   sustained perf collapse. SPREAD+HOLD (item 1) still matters for the see-saw itself.

## ✅ OVERNIGHT RESULT — the AI played a FULL match to a real WIN
The see-saw broke (WEST → 2→3→4 towns + `HQ_STRIKE`), and at match-minute ~415 **WEST WON via BASE OVERRUN** —
razed EAST's HQ+factories via a sustained siege (`BASE_OVERRUN|strikers=8|via=siege|siege=5`,
`WASPSTAT|ROUNDEND|WEST`, `ROUNDSTAT winner=WEST townsW=4 townsE=2`). So the whole chain works end-to-end:
**capture → dominate → HQ-strike → base overrun → victory.** The strike-conversion is SLOW (the strike ran
~2h, bleeding WEST's strength, before the siege counter accrued + razed the HQ) — so the "DECAPITATE doesn't
finish" concern is **slow, not broken**. Speeding up conversion (durability latch + staging so the siege
accrues faster) is a worthwhile AICOM tune, but NOT urgent — the AI genuinely closes games. HUGE validation of
the night's capture fix.

## ⚠️ NEW BUG found at the win — match-end rotation gets STUCK (ambiguous both-maps)
When WEST won, `WaspMatchEndRotate` tried to rotate and hit: **`AMBIGUOUS state (chActive=True tkActive=True)
- abort to avoid corrupting`** — BOTH the Chernarus and Takistan pbos were in MPMissions, so rotate2 refused
to act (safety guard) and the server was left stuck on the ended round. Overnight I recovered it by running
`deploy40ch.ps1` (retires all MPMissions pbos → clean fresh CH match). **Morning fix:** find why both maps end
up in MPMissions at match-end (likely the deploy/park-model + rotate2 interaction — my cmdcon deploys park TK
while CH is active, but at rotate the swap left both present) and make rotate2 resolve the ambiguity (retire the
old, activate the intended next map) instead of aborting. Until fixed, each match-end may need a manual
`deploy40ch.ps1` (matches run ~6h so it's infrequent).

## Already handled (no morning action)
- **Peach+ reports** — fixed live (build tag was blank after the friendly-missionName change; now reads the
  WASPSCALE `build=` tag). Your next 2h/4h/12h pulse is coherent again.
- **Build 85 changelog** — live + accurate (marker line corrected to class-text; "AI takes towns" now verified true).
- **Player class marker** — shows shortened class text (SOL/MED/ENG/SPEC/SNI/OFF). A2 has no class-ICON marker
  (b_inf is A3-only) — text was your actual ask.

## The one big lesson (saved as memory)
`wasp-hc-rpt-is-where-teams-log`: the AICOM **teams run on the HC**, so begin_capture/CAPTURED/driver-errors are
in **`ArmA2OA.RPT`** (HC), scoped to the last MISSINIT — NOT `arma2oaserver.RPT`. Reading the server RPT gave
false "0 captures / 0 errors" and cost hours. Check the HC log for anything about team behavior.

## Full night-by-night detail
`docs/OVERNIGHT-LOOP-2026-07-02.md` (Tick 0-14+). All work is in PR #136 on branch `claude/overnight-2026-07-02`.
