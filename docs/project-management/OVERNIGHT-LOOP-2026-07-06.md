# Overnight Loop — 2026-07-06 (Agent A, Main PC)

Owner directive (~01:30): "set a loop… Finish all the work, test, and suggest improvements for morning through autonomous testing of the mission / features on the miksuus warfare testserver (hetzner ssh)."
**Consent granted this run:** autonomous test deployments + mission soaks on the Hetzner box (78.46.107.142, reachable `ssh gamingpc` → `ssh livehost`). Safety rule stands: **never restart a mission with human players connected** (HC slots excluded); check the player roster before every restart. No changes to the PM2/web prod stack. Flags stay default-0 in all deployed test builds except the specific shadow-telemetry validation target.

## Queue (work top-down; one meaty item or verify-pass per wake)

### A. Absorb Agent B output (every wake, first)
- `gh pr list` for new PRs from the Game PC seat (TP-14 driver-press expected on `fable/aicom-v2-l1-press`, then TP-13 rate-limit, TP-15 stuck-repair). Each: Agent A diff pass + Fable refuter (owner-intent + A2-safety lenses), post verdict comment, log.
- TP-14 MUST contain the #724 MAJOR fix (phantom guards → `wfbe_aicom_garrison` side-logic compare + per-team `wfbe_aicom_holding_town`) + the stale `AI_Commander.sqf:503` comment fix. If missing → fix-request comment.

### B. Hetzner autonomous soak program — PIPELINE DISCOVERED, RETRY PENDING (player online)
**02:30 status: SOAK-BLOCKED — human player "hp" (UID 76561199004135096) actively playing (FPSREPORT players=3|hc=2). Retry the player check EVERY wake; deploy the moment the box is empty.**
**Discovered pipeline (verified):** build via Patch-PboFile.ps1 overlay + LoadoutManager -> PBOs to C:/WASP/incoming/ as cc44u-{ch,tk,zg}.pbo (current live = cc44t) -> clone deploy44t.ps1 -> new deploy44u.ps1 (stops Arma2OA-PR8 service + MiksuuHC/HC2/WaspSeatHeal tasks, retires PBOs, installs cmdcon44uaicom CH pbo, parks TK/ZG, archives RPT to rpt-archive/arma2oaserver-deploy44u-<ts>.RPT, restarts, relaunches HCs, polls MISSINIT; logs to rotate2.log). Player check: C:/WASP/incoming/_asrcheck.ps1 or A2S port 2303 minus HC count. Single instance = live instance (owner-authorized). Game PC worktree C:/Users/Game/a2wasp-tp5 already at organic HEAD dd7200578 (incl. guard fix).
**Harvest (after deploy):** fresh RPT at C:/Users/Administrator/AppData/Local/ArmA 2 OA/arma2oaserver.RPT, MISSINIT-scoped; grep AICOM2|v1|DECAP for inRange=/roll=/sensed= fields; scorecard via Tools/Soak/analyze_soak.py.
1. Discover the deploy flow: read `C:\WASP\*.ps1`/deploy scripts on livehost + `C:\Users\Game\wasp-build`, `wasp-deploy-staging`, `_wasp_box_live` on the Game PC. Do NOT invent a deploy path — use the existing scripted one (deploy44q/r/s archives prove one exists).
2. Build a TEST build from `fable/aicom-v2-l1-organic` (#724 head: includes #713+M0-M5+organic sensing, all flags 0 → DECAP shadow telemetry on).
3. Player-safety check → deploy to the box → restart mission → AI-vs-AI soak (players=HCs only). Target ≥2h Chernarus; if stable, one ZG round to confirm #720's error-loop fix zone stays quiet (note: #720 is unmerged — ZG error will still appear unless the test build includes it; consider a second test build stacking #720+#724 if clean).
4. Harvest: RPT → `Tools/Soak/analyze_soak.py` scorecard + grep the new `AICOM2|v1|DECAP` line — validate the sense chain (inRange>0 episodes, roll cadence ≈ every 4th tick, sensed latch/decay, stamped=0 at flag 0). This is exactly the pre-flag-1 evidence #724 needs.
5. Iterate on findings (fix → redeploy, test box only). Log every deploy + restart with timestamp + player-check result here.

### C. Default-approved build items (Q-defaults, silence = ship)
- TP-16: naval CAP 3× Mi-24 (Q4 default: no An-2, all carriers, `WFBE_C_NAVAL_CAP_THREE_HINDS` default 0) — `Init_NavalHVT.sqf` lines ~483-575.
- TP-17: HQ marker destination-direction mode (Q6 default: flag-gated, facing fallback) — `updateteamsmarkers.sqf`.
- TP-18: SCUD TEL diagnostics (Q5 default) — RPT log lines in `Init_IcbmTel.sqf` at TEL spawn + variable registration.
- TP-13 (if Agent B hasn't taken it): aicom-focus server-side UID cooldown.
- TP-10 spec: properly re-verify + rewrite the 3 MAJOR-flagged sections.

### D. PR queue hygiene (Q7 default)
- Close with rationale: #129 (superseded), #553 (superseded by #557), #694 (dup of #697), #261 (owner-rejected).
- Prepare (do NOT mass-merge overnight): fold-batch plan for the 49 MERGE-CANDIDATEs — verify mergeability, group into ≤5-PR batches, write the morning merge runbook.

### ⚠ SOAK STATUS FOR MORNING REPORT: pipeline fully mapped + deploy armed, but every check window had a human on the live box (single-instance = live). Needs owner action: free the box for a window, OR give me the authoritative empty-check (A2S port 2303 minus HC, or the exact mission-switcher.ps1 player-count call). Live box IS emitting AICOM2|v1| telemetry but on build cc44t (pre-#724) so the new inRange/roll/sensed fields require the deploy.

### E. Morning deliverable (~07:30-08:00)
- `MORNING-REPORT-2026-07-06.md`: everything shipped/verified overnight, soak KPIs + DECAP sense-chain validation verdict, improvement suggestions ranked from soak evidence, open decisions. Peach+ DM the digest.

## Coordination
- Claim ledger = FABLE-BUILD-LOG on this branch. Agent B (Game PC) works its fixed queue (TP-14→TP-13→TP-15) and does NOT deploy or touch the box; only this loop deploys.
- Context preservation: update this doc's Log section every wake BEFORE doing work.

## Log
- 04:0x — Iter 7: SOAK HARVEST #1 (t~64, ~1h game-time). ⭐ #724 build HEALTHY: SRVPERF fps 42-47 @185-249 AI; DELEGSTAT remotePct 89-95% (vs 21-37% collapse in pre-#724 07-05 baseline — notable, note in report); GRPBUDGET nominal (guer 20-42/144); errors 23 ErrInExpr/22 UndefVar over 1h = background noise, NOT a loop flood; grpNull=0 CannotCreate=0. DECAP: 126 lines all IDLE/inert (inRange=0, sensed=0 — early-game, 43 neut towns, no team near enemy HQ, expected). Shadow contract VALIDATED. WASPSCALE build=cmdcon44uaicom confirmed, both HCs seated. No new Agent B PRs (queue idle). Letting soak run to morning for more game-state.
- 03:3x — Iter 6: ⭐⭐ SOAK LIVE — deploy44u SUCCESS. cc44u (#724, all flags 0) running on the box; MISSINIT confirmed; DECAP shadow telemetry emitting the NEW fields (inRange/roll/sensed/stamped) correctly + inertly (IDLE, all 0 at flag 0). Pre-restart re-check passed (players=0 both sides). Pre-deploy RPT archived deploy44u-20260705-1754. Now accumulating game-time; harvest next. REALISTIC: inRange>0 needs a team within 3km of enemy HQ = late-dominance event (may not fully cycle overnight on 46-town CH) — soak validates shadow-contract + #724 regression health + any sensing episodes that develop.
- 03:2x — Iter 5: ⭐ SOAK GATE OPEN — definitive empty read (AICOM2 SNAP players=0|myPlayers=0 both sides t=985/986/987; 0 FPSREPORT in last 300 lines; human left ~t=963). Homepage reframe → PR #62 (approved, copy clean, CI red only from #60-not-merged). LAUNCHING deploy44u of #724 test build with hard pre-restart re-check.
- 03:1x — Iter 4: merge runbook → MORNING-MERGE-RUNBOOK doc (10 batches + rebase queue). TP-10 spec corrections landed (c75b9c3f2) — notably MARCH_YELLOW pacing + land 'GET OUT' dismount ALREADY implemented (saves rebuild). Soak: 3 checks, box shows human 'Mitch McConnell' active t=963 then 17min heartbeat-silence but NO positive disconnect signal + no authoritative player-counter available → DEFERRED (won't restart on ambiguous-empty). Banking time on homepage reframe (Q10 default numbers).
- 03:1x — Iter 3: #730 fix verified in-branch (both MAJORs closed, re-verified PASS, merge-ready). Soak player-check INCONCLUSIVE (no FPSREPORT in RPT tail — could be between-rounds/ssh; NOT treating as empty per safety principle) → deploy deferred to next clean positive read. All 6 overnight PRs (#726/#727/#728/#729/#730) now PASS/merge-ready.
- 03:0x — Iter 2: verdicts in — #729 PASS, #728 PASS (both merge-ready), #730 FAIL (2 MAJOR: unguarded select 1 + [0,0,0] map-corner trap — flag-0 inert so no live risk; fix dispatched). Soak retry: still 1 human ("Mitch McConnell") — blocked. Player-check script now reliable (scp'd pcheck.ps1).
- 02:4x — Iter 1 done: soak BLOCKED (human online; pipeline fully mapped, retry armed). TP-16->#729, TP-17->#730, TP-18->#728 (grades 95/95/96, verify wave launching). #726 PASS (guard fix landed on organic dd7200578 — B self-served it), #727 PASS-WITH-NOTES. NEW: TP-20 for B queue = same rate-limit for aicom-posture/aicom-fieldorder.
- 02:1x — Iter 1b: B already shipped #726 (TP-14, guard fix MISSING → fix-request posted) + #727 (TP-13, looks strong). Verifiers + soak-deploy + TP-16/17/18 launching. 4 closures done (#129/#553/#694/#261).
- 02:0x — Iter 1: launching §B soak-deploy (background) + §C builds TP-16/17/18/13 (TP-13 reverted to B — its #727 predates my claim) + §D closures. 
- 01:4x — Loop armed. Verification wave executed: #724 PASS(+MAJOR for TP-14), #722 closed REDUNDANT, #723 approved, TP-10 corrections prepended. Skills cycle closed. Wave-1/2/4 all landed + reviewed earlier.

## FULL BACKLOG COVERAGE MAP (nothing drops — every original-doc item tracked)
Legend: ✅ done+reviewed · 🔶 in-flight · ⏳ queued (owner=me / B=Agent B) · 🔒 gated on owner

### AICOM V2 / AI commander
- ✅ #713 re-scoped → organic sensing (#724, verified) · 🔶 driver-press hook (B: TP-14, incl. #724 MAJOR guard fix) · ⏳ GUER Director #715 (B or me, post-cutover) · ⏳ softest-lane push, base-placement safety (me, from TP-10 spec) · 🔒 V2 one-shot cutover + AICOMV2↔AICOM2 reconciliation (owner-sequenced) · ⏳ HC/ASR/perf audit research PR (me, §B soak feeds it)
### AI unit micro-layer (TP-10 spec, corrections prepended)
- ⏳ stuck-driven in-place repair (B: TP-15) · ⏳ pacing / fire-discipline / economy-of-force / air-insertion extensions (me+B, re-verify EXT-1/EXT-4 first) · ⏳ transport depth, composition no-ATV (me) · ✅ infinite fuel (already existed — #722 closed) · driver-swap/smoke = preserved
### Game UI/HUD
- ✅ Cancel Last, RHUD queue overflow, earplugs, TAGS persist, upgrade icons (#719) · ✅ tips rewrite (#721) · �Q team-menu (proposal ✅, build gated Q9) · ⏳ HQ marker destination mode (me: TP-17) · ⏳ SCUD TEL diagnostics (me: TP-18) · ⏳ factory/base construction placement safety (me)
### Spawns
- ✅ player strategic-spawn road-snap (#723) · ⏳ 3× Mi-24 naval CAP (me: TP-16) · ⏳ aircraft spawn isFlatEmpty fallback (me, low pri)
### Telemetry / Stats V2 / after-match
- ✅ GRPBUDGET/SRVPERF relocation (#718) · ✅ census + plan · ⏳ MATCH|v1| family + ingest (me, after soak) · ⏳ after-match report builder + test-Discord post (me) · ⏳ EMPTYGRP/GRPEMPTY consumer fix + soak-gate scripts (me)
### Website / Discord (miksuu)
- ✅ CI green (#60) · ✅ motion kit (#61) · �Q Command Center /stats build (spec ✅ TP-12, gated Q2/Q3/Q10) · ⏳ homepage reframe (me, Q10 numbers) · ⏳ #56 brand tokens rebase, #49 merge · ⏳ guides refresh · 🔒 #57 guild-architect + roles (owner prod-guild step) · ⏳ BOT.md cog-count fix
### Hygiene / docs
- ✅ wiki proposal · ✅ repo-instructions #725 · ✅ 2 skills · ⏳ close #129/#553/#694/#261 + 49-PR fold runbook (me: §D) · ⏳ bloat archive (74 STATUS docs) (me, low pri)

## Agent B night queue (Game PC — build lane; does NOT deploy/touch the box)
TP-14 driver-press (incl. #724 guard fix + stale :503 comment) → TP-13 aicom-focus rate-limit → TP-15 stuck-driven in-place repair (from TP-10 §recommendation) → TP-19 factory/base construction placement safety (isFlatEmpty/slope/road/water) → TP-20 rate-limit aicom-posture + aicom-fieldorder (same UID-key idiom as your #727) → then pull from the ⏳-B items above. One bounded draft PR at a time, full lint+mirror+template flow, self-grade ≥95 for AICOM code, escalate on cutover-file collisions.

