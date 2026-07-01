# Overnight autonomous loop — 2026-07-02 (claude-gaming)

## Directive (Ray, 2026-07-01 night)
> Keep heavily monitoring the server, my RPT and the HCs all night, every 15 minutes. If you don't
> find an issue, seek a fix or improvement for something instead (keep delivering all night). Make
> your own PR for this. Keep the loop going no matter what — if the server crashed, just start a new
> match and get back on track. Link the WASPSCALE panel.

## Loop policy
- **Cadence:** every ~15 min (ScheduleWakeup, 900s), all night, until Ray says stop.
- **Each tick:** pull the live server RPT + Ray's client RPT + both HC RPTs → scan for real script
  errors / crashes / AICOM pathology / perf regressions.
  - **Issue found** → diagnose + fix (commit to this branch).
  - **No issue** → pull the next item off the improvement backlog below and ship it.
  - **Server crashed / procs < 3** → restart the chain (deploy script / service restart) and resume.
- **Safety / DEPLOY POLICY (Ray directive 2026-07-02, ~cmdcon39):** **NO more live deploys tonight.**
  The NEXT update goes live only in the MORNING when Ray says so. Until then: develop + commit + push
  fixes to THIS PR, monitor, and stage everything for the morning bundle. Crash recovery (restarting the
  SAME live build after a crash / procs<3) is still allowed to keep the server up — that is not "an update".
  Live build is **cmdcon39aicom** (drain-wait + arrival-gate capture fixes + class-text marker). Match
  rotation stays box-side (WaspMatchEndRotate).
- **Live panel:** WASPSCALE scope-vs-FPS → https://miksuu.com/wasp (Performance tab).

## Shipped this session (folded into this branch)
- Grade-stamp A2-OA Bool `!=` fault fixed (`Common_RunCommanderTeam.sqf:858`) — was firing every road-march tick.
- Friendly map markers restored to the **`b_inf` class icon** (was `mil_arrow2` arrow) per Ray.
- **WASPSCALE v2 emitter** — `build=` + `hc_fps=` added to the telemetry (AI_Commander.sqf + HCStat.sqf).
- **HC lobby slot** relabelled `Headless Client` → **`HC`** on both maps (both sides). NOTE: the HC label
  was already on the id-lowest WEST/EAST slot (the one the HC grabs); do NOT renumber slots.

## Improvement backlog (loop pulls from here when no issue is found)
1. **Camps "afraid of" fix (Fix A)** — in AllCamps mode (`WFBE_C_TOWNS_CAPTURE_MODE=2`), the camp-first
   no-progress bail (`Common_RunCommanderTeam.sqf:1107`, `WFBE_C_AICOM_CAMP_STALL_PASSES`) abandons camps
   then falls through to a depot it can't drain → grinds a town forever. Gate the bail on capture mode
   (new `WFBE_C_AICOM_CAMP_GATE_MODE2`, default 1). Low risk.
2. **No-money JIP funds-heal harden** — B76 FUNDS-HEAL sometimes needs a second request; make it retry
   until funds land (or bump the request count) so joiners never spawn broke.
3. **WEST team-size >8** — one WEST team founded 11 units (>the size-8 cap); verify the founding roster
   path applies the cap for WEST.
4. **Team-tag click error** — Ray reported a popup on clicking team tags; no SQF error logs → likely a
   UI/config error. Needs the error text OR a reproduction dig into GUI_Menu_Command roster handlers.
5. **Camp-grab (Fix B, optional)** — commander peels 1 idle team to grab a lone front-line camp; default OFF.
6. **Pre-existing `_govSteep` cleanup + any new fault the loop surfaces.**

## MORNING PATCH QUEUE (Ray directives, 2026-07-02)
1. **NO TOWN IS UNCAPTURABLE.** Design guarantee: no town may ever be permanently un-takeable by the AI.
   Current mechanic (`server_town.sqf` mode 0/Classic): a town drains+flips with ≥1 attacker in the 40m
   depot ring AND no live defender of the current owner present (a defender sets `_skip=true` → protected,
   regens supply). So the only "uncapturable" states are (a) a town whose defenders the AI can't fully clear
   (they out-reinforce the attacker), and (b) the `RELEASED uncapturable` abandon after N no-flip passes
   (`Common_RunCommanderTeam.sqf:1235`). Plan: make the AI ESCALATE force onto a stubborn town (concentrate
   more teams / heavier units) instead of abandoning, and audit for any true mechanical dead-end. Pairs with
   tonight's drain-wait (`e1d031f47`) + arrival-gate (`87d7b3d94`) fixes. Consider a per-town "assault escalation"
   counter that raises committed force each failed pass rather than releasing.
2. **PLAYER CLASS-ICON MARKER.** Tonight's `4f33143cd` reverted the A3-invalid `b_inf` back to the working
   `mil_arrow2` heading arrow (class still shows as a `[SOL]/[MED]/…` text tag). Ray wants the marker to show
   his CLASS as an icon. A2-OA-1.64 has no native class-symbol markers (b_inf is A3-only), so a true class icon
   needs a custom `CfgMarkers` texture in description.ext — background research agent `ac94170c925754a1b` is
   finding a valid A2-OA icon path / the best built-in per-class mapping. Ship in the morning bundle.

**Morning deploy bundle (staged in PR, NOT yet live):** arrival-gate `87d7b3d94` + marker revert `4f33143cd`
(+ the class-icon + no-town-uncapturable work once designed). Deploy together as one build in the morning
(or fold the arrival-gate sooner if tonight's capture verification shows `begin_capture` still 0).

## Tick log
- **Tick 0** (setup): server healthy (3/3 procs, cmdcon36, 0 errors, AICOMHB v2, WEST 10-0). No issue →
  shipped the pending batch above (grade-stamp, marker b_inf, WASPSCALE v2 emitter, HC label). Loop armed.
- **Tick 1** (Ray-requested deploy): shipped **cmdcon37** = the patch + **camps Fix A** (`WFBE_C_AICOM_CAMP_GATE_MODE2`, hold+clear camps in AllCamps mode) + **stall-advance floor**
  (`WFBE_C_AICOM_STALL_ADVANCE_SECS=240`, re-route parked-not-flipping teams — the real fix for the live "0 town-captures / grind unflippable depot" root of standing+circling+afraid-of-camps).
  Boot-smoke found + fixed a WASPSCALE build-tag string-`find` A3 fault (aborted the emit → 0 lines) → re-deployed. **Live cmdcon37 clean: 0 errors, AICOMHB v2, WASPSCALE v2 emitting `build=cmdcon37aicom|hc_fps=46`.**
- **Tick 2** (ROOT-CAUSE fix + deploy + changelog): early-verification pull showed `CAPTURED=0` — the metric that was stuck at 0 all last soak. Launched a fleet root-cause dig (`wt2xsqblt`, 3 Explore agents + Opus synth) + validated against real code.
  **THE ROOT (not camps):** the depot-hold loop in `Common_RunCommanderTeam.sqf` (both infantry L1187 + pure-armour L1283) exited the moment enemies cleared (`_resNear==0`), but `server_town.sqf:51/112/202-214` drains the depot over MANY 5s ticks while our bodies sit in the 40m ring. So a peaceful, capturable town exited the hold in ~10s, never flipped, and got RELEASED as "uncapturable" after 2 empty passes → re-dispatched to the same town forever (live: 0 captures, TARGET_ABANDON=0, "standing around / afraid of camps").
  Also found: **cmdcon37 camps FixA is INERT on live** (gated on capture-mode==2; live mode is 0/Classic) — so this drain-wait fix is the one that actually matters.
  **FIX (git `e1d031f47`):** both hold loops now key on a flip flag (`_holdFlipped`/`_armHoldFlipped`) → hold the drain ring until the town FLIPS or the 360s timeout/re-task interrupt. Bumped `WFBE_C_AICOM_STALL_ADVANCE_SECS` 240→420 so the backstop doesn't preempt a legit slow drain. All freeze-guards preserved. Bracket-verified, CH→TK mirrored.
  Deployed **cmdcon38** (human dropped on restart as expected; match can't self-end while the bug is live, so waiting for match-end wasn't an option). **Boot-smoke clean: 0 errors, builderr=0, AICOMHB v2, WASPSCALE v2 `build=cmdcon38aicom|hc_fps=45`.** Published **Build 85** changelog (miksuu.com `b054895` + Discord). NEXT: watch `CAPTURED` climb off zero (the real proof).
- **Tick 3** (capture verification — inconclusive, prepared next fix): live cmdcon38 at minute 18: **0 errors, 3/3, WASPSCALE healthy, AI_TOT=152, fps=46**. But `CAPTURED=0` **and** `begin_capture=0` **and** `did_not_flip=0` — no team has entered the capture phase at all yet. Teams ARE dispatched to real towns (`ASSAULT_DISPATCH town=Myshkino dist=1500`, `→Khelm dist=1055`), `contested=0`, founding still 9/10 → most likely the two 152-unit armies are clashing in the FIELD between bases (not a regression: my drain-wait change only touches the depot-hold *after* arrival). Traced the full capture chain: dispatch → **60m arrival gate** (`Common_RunCommanderTeam.sqf:890`, `CAPTURE_RANGE+20`) → capture phase → drain-wait depot-hold.
  Found a plausible secondary gap: the approach SAD ring is **80m** (`WFBE_C_AICOM_ASSAULT_SAD`) but the arrival gate is only **60m**, so a squad can rove its search ring and never cross into the capture phase. **Committed (NOT deployed) `87d7b3d94`:** arrival gate → `max(CAPTURE_RANGE, ASSAULT_SAD)+20` (=100m). Held the deploy to preserve the capture-verification clock. **NEXT TICK:** re-check `CAPTURED`/`begin_capture` at ~minute 33 — if still 0, deploy the arrival-gate fix (cmdcon39); if captures are flowing, the drain-wait fix is confirmed and the arrival-gate change is a bonus reliability win.
- **Tick 4** (Ray marker clarification + PR audit + LAST deploy): Ray wants his marker to show class as **shortened TEXT** (SOL/MED/…), not a graphic icon. Used the wiki + Miksuu upstream (Ray's steer): confirmed **A2-OA has NO class-symbol markers** (b_inf is A3-only) and Miksuu's parent used plain `"Arrow"` with no class text — so this is NEW. Wired the shortened class onto the reliable `_ownMarker` (which set no text) — git `aecc87dae`; SpecOps tag SUP→SPEC. Deployed **cmdcon39** (marker + arrival-gate + drain-wait) so Ray can see it — **boot-smoke clean: 0 errors, cmdcon39 active, 3/3**. Published the **Build 85 changelog correction** (marker = class TEXT, not the A3 icon that never worked) to miksuu.com (`e4c5e30`) + Discord.
  **PR audit (Ray ask):** graded the 7 other open PRs. Only genuinely useful gameplay content = **#125's RequestUpgrade anti-forge** (+150, real client→server upgrade authority) + **`WFBE_CO_FNC_GroupGetBool`** helper (safe A2 group-var reads, incl. `wfbe_aicom_cappasses`). Rest = release tooling/metadata/docs. #125 NOT mergeable (pins heartbeat back to v1 = regression). **PROPOSED to Ray** to fold just those two into the morning patch — awaiting his go.
  **DEPLOY POLICY now morning-only** (see above). Loop continues as monitor+stage only.
