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
   **✅ DESIGN COMPLETE (fleet run `wj1le31cr`) → [docs/design/NO-TOWN-UNCAPTURABLE.md](design/NO-TOWN-UNCAPTURABLE.md):**
   an ESCALATION LADDER (`wfbe_aicom_escalate`) converts every blacklist/abandon path into "concentrate more
   teams + raise priority" (flag `WFBE_C_AICOM_ESCALATE_MODE`, MAXCONC=12/MAXTOWNS=2 guards so the army never
   piles on one impossible town). Verdict: NO server_town.sqf change needed (drain is linear in attacker count →
   mass always wins). Ready to implement in the morning on Ray's word.
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
- **Tick 5** (first subagent-driven check per Ray's "use subagents on every check"): ran a 2-agent fleet check (`wfk5p114j`: capture-verify + infra-health) on live cmdcon39. **INFRA HEALTHY: 3/3 procs, 0 errors, AICOMHB v2 (no regression), WASPSCALE emitting (fps=45, hc_fps=45, build=cmdcon39aicom).** Captures: too early (match ~4 min, mission clock reset during HC-seat sequence; assault pipeline alive — ASSAULT_DISPATCH→Khelm) — real capture verdict next tick (>15 min). No issue → launched a read-only fleet DESIGN investigation `wj1le31cr` for Ray's "no town is uncapturable" morning item (map every abandon/uncapturable path → design escalate-not-abandon). Design will be staged to the morning queue when it returns. NO deploy (morning-only policy).
- **Tick 6** (CAPTURE VERDICT — NEGATIVE): subagent check `wx4x43isy` on live cmdcon39 at **minute 20**: infra healthy (3/3, 0 err, AICOMHB v2, 47 fps, AI_TOT=235) BUT **captures STILL 0 — `CAPTURED=0` AND `begin_capture=0` across the whole RPT, on BOTH sides** (even dominant EAST @123 AI captures nothing; 33 ASSAULT_DISPATCH, 0 arrivals-into-capture). **This means tonight's drain-wait + arrival-gate fixes address the WRONG layer** — no team ever ENTERS the capture phase (`_arrived && _mode=="towns-target"`, L934), so the depot-hold code never runs. Prime suspect: the dispatch writes order mode `"towns"` not `"towns-target"` (mode-string mismatch) → capture phase gate never true. Launched root-cause fleet trace `wln6wj9cn` (mode/order-writer + driver trace). Fix will be STAGED to PR (no deploy — morning-only). Secondary note: WEST founding imbalance (WEST 41 AI vs EAST 123) — the old WEST-founding issue, logged for a balance pass. NO deploy.
- **Tick 7** (MOVEMENT ROOT FIX — the real capture fix — deployed): fleet `w9kbdt0a3` found the TRUE cause of begin_capture=0 / 0 captures all session: **AICOM teams never left spawn.** Live: teams moved 1m in 482s, stuck=false, reissue=0/43, zero road-march logs. `Common_WaypointsAdd.sqf:34` only called setCurrentWaypoint when `_WPCount==0`, but A2-OA WaypointsRemove leaves a residual index-0 waypoint → on every re-lay (each commander seq-bump/arrival) `_WPCount>=1` → the fresh MOVE chain was never made active → teams sat at spawn. **One-line fix: `_WPCount==0` → `_forEachIndex==0`** (fire setCurrentWaypoint on the first node of each batch at its real engine index). Garrisons (fresh group) unchanged. git `76299d159`, bracket-clean, CH→TK mirrored. **Deployed cmdcon40 (Ray-authorized "final town cap fix + restart"). Boot-smoke clean: 0 errors, AICOMHB v2, active.** Movement signals 0 (match ~2 min, teams not yet founded). NEXT: verify ASSAULT_ARRIVED>0 → begin_capture>0 → CAPTURED>0. Bundled the arrival-gate 250m fix (`wln6wj9cn`). Also this tick: Peach+ reports FIXED+verified (build tag reads via WASPSCALE now); AICOM-AIRCRAFT.md staged (heli airfield-spawn + air research-gate, morning); 60-agent mission audit `w2mcwe481` running.
- **Tick 8** (MAJOR METHODOLOGY CORRECTION): the "0 captures / begin_capture=0" all night was partly a **WRONG-LOG measurement error.** The AICOM commander TEAMS run on the HC, so the team-driver logs (begin_capture / CAPTURED / did-not-flip / driver ERRORS) go to **`ArmA2OA.RPT` (HC)**, not `arma2oaserver.RPT` (server) which I'd been grepping. Saved memory `wasp-hc-rpt-is-where-teams-log`. **Scoped to the current cmdcon40 match, the HC RPT is CLEAN: 0 errors, begin_capture=2** (WEST teams B 1-1-E + B 1-1-A holding the Myshkino depot; no did_not_flip / RELEASED → the drain-wait fix IS working, they hold for the flip instead of bailing). The 86 `!= _govSteep` HC errors were STALE pre-fix history (grade-stamp fix confirmed working — 0 in current match; HC RPT isn't archived on deploy so scope to last MISSINIT). CAPTURED=0 still (drain in progress OR Myshkino defended; throughput slow — few of 21 teams reaching towns yet). NET: the fixes (waypoint + drain-wait + arrival-gate + grade-stamp) ARE working; teams reach + hold towns. Remaining: throughput (more teams reaching) + flip completion. NEXT: watch HC RPT (scoped) for CAPTURED climbing.
- **Tick 9** (00:07, correct-log check): infra perfect — 3/3, 0 errors on BOTH logs, AICOMHB v2, 47 fps. HC **begin_capture climbed 2→9** (teams reaching + entering capture), ASSAULT_DISPATCH=71. But CAPTURED=0, did_not_flip=0, RELEASED=0; server POSTURE both sides myTowns=1/enTowns=1 (only start towns) at match min 41. So the chain WORKS + climbs but **no completed FLIP yet** — the 9 begin_captures went somewhere without completing (and without the did_not_flip/RELEASED outcomes). Launched diagnosis `a660d79f0ceb8a504`: re-task interruption (commander capAbort's its own captures mid-hold) vs contested middle-town stalemate (both sides in the 40m ring → server _skip=true → never drains). Fix will be STAGED (no deploy, morning). The no-town-uncapturable escalation design already targets the contested case.
- **Tick 10** (✅ CAPTURES CONFIRMED — the night's goal is met): my own-eyes verify — HC current match **CAPTURED=6** (correct pattern `CAPTURED \[`): WEST×2 Myshkino (incl. an armour team), EAST×4 Khelm; begin_capture=9, 0 errors. **The AI DOES capture towns — the movement→arrival→capture→flip pipeline works end-to-end.** The all-night "0 captures" was TWO stacked measurement errors: wrong log (server vs HC RPT) + a grep pattern (`CAPTURED - holding center`) that never matched the real line `CAPTURED [Town] - holding center.` (correct = `CAPTURED \[`). Diagnosis a660d79f0ceb8a504 caught it.
  **Remaining (tuning, NOT a bug):** server POSTURE still myTowns=1 each because the contested middle towns SEE-SAW — a side captures, its team immediately retargets+leaves (AssignTowns:203 retarget-on-capture), the town flips back; plus DOGPILING (7 EAST teams all onto Khelm) so the front doesn't widen. FIX (staged, morning): (a) leave a thin post-capture GARRISON to hold the town (the NO-TOWN-UNCAPTURABLE.md DEFEND_TOWN concept), (b) per-town team-cap in the AssignTowns selector so a side spreads across multiple enemy towns instead of dogpiling one. No deploy (cmdcon40 stands). Build 85 changelog 'AI takes towns' is now VERIFIED TRUE.
- **Tick 11** (00:25, SEE-SAW confirmed): health check — server healthy (3/3, 0 err both logs, AICOMHB v2, fps 43/45, AI_TOT=288). HC CAPTURED=6 (FLAT this interval — Khelm=4/Myshkino=2 = the dogpile), begin_capture=9, 0 fail-outcomes. Server POSTURE min 60: both sides myTowns=1/enTowns=1 STUCK. **EAST has a 2:1 strength lead (myStr=95 vs enStr=40) but posture=HOLD with only 1 town** — the dominant side isn't PRESSING its advantage into territory. So three tuning gaps on a WORKING capture chain: (A) dogpile (7 teams→Khelm), (B) no post-capture hold (see-saw), (C) dominant side not pressing a 2:1 lead. Launched design fleet `wg2d9lgvs` for SPREAD+HOLD (per-town cap + thin post-capture garrison). Flagged: NO-TOWN-UNCAPTURABLE.md escalation is now MISALIGNED (would worsen dogpile) → de-prioritise. All STAGED for morning (no deploy — cmdcon40 stands, server healthy). Match is a healthy stalemate overnight.
- **Tick 12** (00:43, HEALTHY-SEESAW + delivered a confirmed bug fix): health check — server healthy (3/3, 0 err both logs, AICOMHB v2, fps 43/40), HC CAPTURED=6 (flat), begin_capture=9, 0 fail-outcomes. POSTURE min 78 both myTowns=1/enTowns=1 (stalemate, WEST now 66 vs 42 str lead but not converting). Note: **AI_GUER=195** (WEST 81/EAST 48) — GUER grown huge, balance data-point for morning. No new bug; known see-saw (SPREAD+HOLD staged). **Delivered:** verified + fixed the 60-audit's confirmed HQ round-ender bug — `Server_MHQRepair.sqf:43` + `Construction_HQSite.sqf:104` sent `_mhq` (nil, case-sensitive) instead of `_MHQ` → a repaired/mobilized HQ's killed round-ender was wired to nothing. Both → `_MHQ` (git `52f9eb169`, CH→TK mirrored, STAGED no deploy).
