# Fold wave 2 report — wasp-fold-wave2-20260731

**Agent:** grok-main-07311829-night  
**Base:** origin/master `6a9f3994d6`  
**Date:** 2026-07-31  
**Confidence:** high on skip/landed decisions; medium on live gameplay of folded patches (static verification only)

## Summary

| # | Item | Source | Verdict | Result |
|---|------|--------|---------|--------|
| 1 | lane194 victory-pack | `fable/lane194-victory-pack` @ wt-cx-194 | **FOLD** (rebased) | Draft **#1793** |
| 2a | antistack perf r2 | `codex/main-07270548-2-perf-antistack-aicom-cleaner-round2` | **FOLD partial** (mainLoop only) | Draft **#1794** |
| 2b | antistack db extension | `codex/07221740-1-antistack-db-extension` | **SKIP** | Closed **#1282** owner policy (antistack touch) |
| 3 | attackwave-reject recut | `codex/attackwave-reject-release-gameplay-20260725` | **SKIP landed** | Substance of #1373 already on master |
| 4 | pr119 HC-CIV residue | `codex/pr119-hc-civ` | **SKIP superseded** | Master HC CIV reseat + open **#1596** |
| 5 | map-clarity toggles | `codex/07180826-1-map-clarity-toggles` | **FOLD** | Draft **#1795** |
| 6 | decap-strike variant | `codex/main-07260818-ap1-decap-strike-20260727` | **SKIP already open** | Same OID as open **#1464** |

Source worktrees **not** removed (hygiene card owns that).

## Draft PRs shipped

1. https://github.com/rayswaynl/a2waspwarfare/pull/1793 — victory-pack (HOLDTICKS default 0, STATS_ROUNDEND_FLUSH default 1, HQ-loss multi-candidate)
2. https://github.com/rayswaynl/a2waspwarfare/pull/1794 — antistack mainLoop active-slice audit (addresses #1481 miss of antistack_main wall-time)
3. https://github.com/rayswaynl/a2waspwarfare/pull/1795 — AICOM team marker null-check (slot 3)

## Per-item evidence

### 1) lane194 victory-pack — FOLDED → #1793
- Cherry of original 3 commits failed (Init_CommonConstants / templates conflicted; master ~28k commits ahead).
- Surgical re-apply of review-corrected logic onto master CH + LoadoutManager mirror.
- Overlap: open **#1782** also edits `server_victory_threeway.sqf` (match stats) but has no TERRVIC/HOLDTICKS — coordinate merge.

### 2a) antistack perf r2 — PARTIAL FOLD → #1794
- Original commit `7a5440ca9` touched Teams + droppeditems_cleaner + mainLoop.
- **Teams.sqf:** master already has `WFBE_C_AICOM_SCAN_CHUNKED` slice pattern — r2 `_perfSliceYield` would conflict/duplicate. Not folded.
- **droppeditems_cleaner:** master has `_perfDispatched`; r2 scanMs needs careful port. Deferred.
- **mainLoop:** still wall-time inflated by uiSleep pacing; folded active-slice telemetry. pytest contract pass.
- Cross-ref blocked card `wasp-perf-airdef-antistack-round2-20260726`: this advances the antistack_main path; airdef was already addressed by #1481/#1496 lineage.

### 2b) antistack db extension — SKIP
- PR **#1282** closed 2026-07-23 by owner: do-not-re-propose antistack touch; probe bypassed kill-switch; malformed RETRIEVE risk.
- Not reopened. Note only.

### 3) attackwave-reject recut — SKIP (landed)
- Commit message itself: "NOT PUSHED - duplicates open #1373".
- #1373 closed; master `Server_AttackWave.sqf` already has ATTACK_WAVE_ACTIVE_* + STALE_MINUTES + release paths.
- No new PR.

### 4) pr119 HC-CIV residue — SKIP (superseded)
- Cherry: one commit already applied (`-`), residue is old magnet approach.
- Master `Init_HC.sqf` has full CIV reseat + solo-group magnet; open **#1596** is the current HC-CIV seating PR (mission.sqm + design doc).
- HC topology note (task): 2 CIV slots — TK fake-HC-slot lesson reflected in master reseat code comments.
- No new PR.

### 5) map-clarity toggles — FOLDED → #1795
- Despite branch name, payload is 1-line fix: `aicom-team-ended` null-check `_x select 3` (team) not `_x select 0` (leader).
- Master still had select 0. Clean cherry-pick.
- Overlap with `wasp-review-towns-garrison-viz-20260731`: different surface (marker feed cleanup vs garrison viz) — no double-ship.

### 6) decap-strike variant — SKIP (already open as #1464)
- Worktree SHA `d431ca22ea` **identical** to open draft **#1464** head (`fable/aicom-lategame-teleport-20260725`).
- This is **endgame teleport** of base-idle AI teams, NOT the DECAP commit-gate fix.
- Open **#1548** (`decap-gate-maprelative`) is the closer sibling for DECAP never-commits.
- Cross-ref blocked `wasp-aicom-decap-strike-never-commits-20260727`: this variant is **not** the DECAP IDLE→COMMIT fix; do not treat #1464 as closing that card. #1548 + DECAP strategy evidence (198 IDLE lines) remain the right track.

## What was NOT verified
- Live RPT / soak FPS for #1794 antistack_main slices
- In-game territorial HOLDTICKS or 3-way HQ-loss for #1793
- Client marker re-draw after #1795 handoff (harness present, not executed here)
- Independent evaluator review of the three draft PRs

## Source worktrees preserved
1. C:/Users/Steff/codex-fleet-20260702/wt-cx-194
2. C:/Users/Steff/.config/superpowers/worktrees/a2waspwarfare/codex-main-07270548-2-perf-antistack-aicom-cleaner-round2
3. C:/Users/Steff/Documents/Codex/worktrees/a2wasp-antistack-db-extension-20260722
4. C:/Users/Steff/council-0725/lanes/attackwave-recut
5. C:/Users/Steff/Documents/Codex/2026-06-28/can/work/a2waspwarfare-pr119
6. C:/Users/Steff/Documents/Codex/worktrees/a2wasp-map-clarity-local-toggles-20260718
7. C:/Users/Steff/worktrees/a2waspwarfare-codex-main-07260818-ap1-decap-strike-20260727
