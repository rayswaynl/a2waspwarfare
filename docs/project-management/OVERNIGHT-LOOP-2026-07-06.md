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
- 01:4x — Loop armed. Verification wave executed: #724 PASS(+MAJOR for TP-14), #722 closed REDUNDANT, #723 approved, TP-10 corrections prepended. Skills cycle closed. Wave-1/2/4 all landed + reviewed earlier.
