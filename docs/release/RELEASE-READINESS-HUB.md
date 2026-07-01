# WASP Warfare — Release Readiness Hub (Chernarus + Takistan)

**Owner:** claude-gaming &middot; **Branch:** `claude/release-readiness-2026-07-01` &middot; **Base:** `origin/master` (`5bf5f9238`) + `bcc6e3974` &middot; **Opened:** 2026-07-01

This is the **single source-of-truth ledger** for getting the updated WASP Warfare mission release-ready on **both** maintained terrains — Chernarus (`Missions/[55-2hc]…chernarus`) and Takistan (`Missions_Vanilla/[61-2hc]…takistan`) — with the code optimized and the core features (especially the **AI Commander**) improved. It consolidates the fragmented release lanes (codex PRs #123–#126) into one living hub, lands verified low-risk fixes incrementally, and stages riskier work as reviewable proposals.

> This PR is updated continuously as multi-agent findings land. Sections marked _(populated by workflow)_ fill in over successive passes.

---

## 1. Release gate — current verdict: **NO-GO** (runtime evidence pending)

A build is release-ready only when the exact chosen package has real Arma 2 OA runtime evidence on **both** maps across the role matrix:

| Terrain | Server | HC1 | HC2 | Start-client | Late-JIP |
|---|---|---|---|---|---|
| Chernarus | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| Takistan  | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |

Runtime proof must show: expected AICOM tokens, release markers, package SHA, client/HC role proofs, **no** stop-condition errors, and the Takistan WEST-infantry founding-fallback token. Collecting this requires launching Arma / SSH to the livehost / pulling private RPTs — **approval-gated** (see §7). Static gates (§4) do **not** require approval and run now.

---

## 2. Consolidation of the existing release lanes

Four overlapping codex draft PRs existed for this same release loop; this hub reconciles them so there is one place to look:

| PR | Lane | What it is | Disposition here |
|---|---|---|---|
| #123 | `codex/release-findings` | Release-captain findings LOG (`docs/release-pr122-findings.md`) | Folded into §1 gate + §6 evidence |
| #124 | `release/2026-07-02-stackcheck-r8` | Release-stack integration + RPT tooling; conflicted vs master | Tooling referenced; findings folded |
| #125 | `codex/release-command-center-20260630` | AICOM command-center + large `Tools/PrTestHarness`; mergeable | Biggest AICOM lane — reviewed in §3, selectively folded |
| #126 | `codex/release-readiness-20260701` | AICOM guardrails + ledger + commander-guide fix | Verified pieces already in master via #127; remainder tracked here |
| **#127** | merged | Folded verified legacy-fit wins from #124/#125/#126 | Already in `origin/master` |

---

## 3. AI Commander (core feature) — review + improvements

The `Server/AI/Commander` subsystem is **ours-only** (absent from upstream `Miksuu/a2waspwarfare`), the largest single behavioral surface (~500 KB across 18 files), and therefore the top release risk. Deep review + adversarial verification lane.

**Carried on this branch (`bcc6e3974`, Ray cmdcon33, 2026-07-01):**
- **WEST founds-0 on Takistan** — starved-infantry founding fallback relocated to run **before** the founding empty-set early-exit in `AI_Commander_Teams.sqf` (both maps). The earlier `8de3c4a60`/cmdcon31 fallback sat *after* the exit and never ran when the eligible set was empty.
- **HQ deploy blocked on mountains** — `Init_Client.sqf` structure-preview: `objNull _area` guard (no base area before first HQ deploy no longer falsely reddens the HQ ghost) + `Warfare_HQ_base_unfolded` exemption from the flat-ground check (both maps).

> **P1 reconciliation (open):** `AI_Commander_Teams.sqf` now contains **two** starved-infantry fallback blocks — cmdcon33 @ ~L310 (before-exit) and cmdcon31 @ ~L368 (after-exit). Confirm whether these are distinct founding selection passes or a double-admit, then remove/merge accordingly. Verify both maps stay identical after the fix.

_(Further AICOM findings populated by workflow.)_

---

## 4. Static release gate + parity — _(populated by workflow)_

Runs without approval. Covers:
- A2/OA compat lint across both roots (A3-only tokens: `isEqualType`, `isEqualTo`, `allMapMarkers`, `params`, `pushBack`, `getPosVisual`, `remoteExec`, `BIS_fnc_MP`, `selectRandom`, `findIf`, `worldSize`, …).
- `count`-expression precedence risks inside boolean logic.
- Stringtable / `localize` coverage.
- **Chernarus ↔ Takistan parity**: shared logic must be byte-identical; only expected LoadoutManager deltas (`mission.sqm`, `version.sqf`, loadouts) may differ.

---

## 5. Performance / optimization — _(populated by workflow)_

Levers from `WASP-AUDIT-2026-06-28.md`: town/camp scan phasing, cached world snapshots, commander-team & town-garrison group-count reduction (~470-unit server-FPS knee), O(units) AICOM/town scans, dead-code sweep.

**Hard constraints (Ray):** NO sim/distance-gating of AI (static gunners always active); do **not** touch antistack. Prefer count-neutral or count-reducing wins.

---

## 6. Sources & external intake — _(populated by workflow)_

- Repo `rayswaynl/a2waspwarfare` (origin) + `Miksuu/a2waspwarfare` (upstream — diff for missing upstream fixes; AICOM is ours-only).
- Wiki `rayswaynl/a2waspwarfare.wiki` (re-audit owed: prior 342-fix pass was against master, not v2).
- Jerry bIdentify dump (Warfare V2_073 baselines); Miksuu Drive dump (pw `armedassault`, enumeration gated).
- BI forums (WASP / Warfare BE known issues, A2 OA scripting semantics).
- Read-only stats: `miksuu.com/wasp`, livehost `:8080`.

---

## 7. Approval gates — will NOT do without explicit Ray approval

Launch Arma locally &middot; SSH to livehost &middot; copy/analyze private RPTs &middot; upload/replace live mission files &middot; restart server processes &middot; clear caches &middot; deploy/rollback. Wiki pushes publish directly, so wiki fixes are staged and published only after review.

---

## 8. Changelog of this PR

- **2026-07-01** — Hub created. Consolidated codex lanes #123–#126. Carried Ray's cmdcon33 fixes (`bcc6e3974`) on an isolated worktree branch off `origin/master`. Opened P1 double-fallback reconciliation. Launched multi-agent recon/audit.
