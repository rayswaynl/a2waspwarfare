# Overnight Loop — 2026-07-06 (Agent A, Main PC)

Owner directive (~01:30): "set a loop… Finish all the work, test, and suggest improvements for morning through autonomous testing of the mission / features on the miksuus warfare testserver (hetzner ssh)."
**Consent granted this run:** autonomous test deployments + mission soaks on the Hetzner box (78.46.107.142, reachable `ssh gamingpc` → `ssh livehost`). Safety rule stands: **never restart a mission with human players connected** (HC slots excluded); check the player roster before every restart. No changes to the PM2/web prod stack. Flags stay default-0 in all deployed test builds except the specific shadow-telemetry validation target.

## Queue (work top-down; one meaty item or verify-pass per wake)

### A. Absorb Agent B output (every wake, first)
- `gh pr list` for new PRs from the Game PC seat (TP-14 driver-press expected on `fable/aicom-v2-l1-press`, then TP-13 rate-limit, TP-15 stuck-repair). Each: Agent A diff pass + Fable refuter (owner-intent + A2-safety lenses), post verdict comment, log.
- TP-14 MUST contain the #724 MAJOR fix (phantom guards → `wfbe_aicom_garrison` side-logic compare + per-team `wfbe_aicom_holding_town`) + the stale `AI_Commander.sqf:503` comment fix. If missing → fix-request comment.

### B. Hetzner autonomous soak program (the big one)
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

### E. Morning deliverable (~07:30-08:00)
- `MORNING-REPORT-2026-07-06.md`: everything shipped/verified overnight, soak KPIs + DECAP sense-chain validation verdict, improvement suggestions ranked from soak evidence, open decisions. Peach+ DM the digest.

## Coordination
- Claim ledger = FABLE-BUILD-LOG on this branch. Agent B (Game PC) works its fixed queue (TP-14→TP-13→TP-15) and does NOT deploy or touch the box; only this loop deploys.
- Context preservation: update this doc's Log section every wake BEFORE doing work.

## Log
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
TP-14 driver-press (incl. #724 guard fix + stale :503 comment) → TP-13 aicom-focus rate-limit → TP-15 stuck-driven in-place repair (from TP-10 §recommendation) → TP-19 factory/base construction placement safety (isFlatEmpty/slope/road/water) → then pull from the ⏳-B items above. One bounded draft PR at a time, full lint+mirror+template flow, self-grade ≥95 for AICOM code, escalate on cutover-file collisions.

