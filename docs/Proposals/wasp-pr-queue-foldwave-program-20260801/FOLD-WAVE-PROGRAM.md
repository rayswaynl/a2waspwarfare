# PR-queue fold-wave program — 2026-08-01

**Task:** `wasp-pr-queue-foldwave-program-20260801`  
**Agent:** `grok-main-07311829-night` (read-only analysis / program design — no fold execution, no merge)  
**Repo:** `rayswaynl/a2waspwarfare`  
**Base:** `origin/master`  
**Generated:** 2026-08-01 UTC  
**Confidence:** high on live mergeability counts (re-queried via `gh pr list --json mergeable`); medium on wave labels (title/branch heuristics); low on patch-equivalence (prior session a443 patch-id index not regenerated this run)

---

## Executive result (live recompute)

| Metric | Brief (morning scan) | Live recompute (this run) |
|--------|----------------------|---------------------------|
| Open drafts | 123 | **126** (all draft) |
| MERGEABLE | 35 | **80** |
| UNKNOWN | 89 | **0** |
| CONFLICTING | 5 (named) / partial | **46** |
| Already-in-master (closed) | #1668 #1528 #1371 | Confirmed CLOSED |
| Superseded closed (not recut) | #1665 | Confirmed CLOSED |

### (1) UNKNOWN recompute — COMPLETE

`gh pr list --state open --limit 200 --json ...mergeable` returned mergeability for **all** 126 open drafts. **UNKNOWN count = 0.** No batch `gh pr view` recompute required.

Evidence files:

- `pr-meta.tsv` — full open-draft table
- `pr-classify-initial.tsv` — number/mergeable/title/head
- `mergeable-numbers.txt` / `conflicting-numbers.txt` / `unknown-numbers.txt` (empty)

### (2) MERGEABLE wave-fold queues — PROGRAM ONLY

Grok lane is **read-only** for this card (no SQF edit / no draft-fold execution / no merge). Bulk fold execution remains Codex-lane + Claude verify, war-gated per wave (model **#1799** spectator stack fold).

Recommended wave order (oldest-first within wave; exclude lineage holds):

| Wave order | Wave id | MERGEABLE n | First oldest candidates |
|------------|---------|-------------|-------------------------|
| W1 | `mission-core-r-series` | 26 | #1599 #1606 #1612 #1619 #1622 #1625 … r56–r80b series dominates later entries |
| W2 | `aicom` | 20 | #1540 #1548 #1584 #1588 #1589 #1598 … + fold drafts #1793–#1795 |
| W3 | `alife` | 6 | #1615 #1621 #1631 #1655 #1660 #1684 |
| W4 | `telemetry-client` | 8* | #1544 #1617 #1626 #1786 #1797 #1798 #1799 (*see holds) |
| W5 | `sqf-correctness` + pathfind + combat | 5 | #1530; #1770; #1547 #1620 #1661 |
| W6 | `other` + fold-meta | 15 | #1262 #1278 … #1791 #1792; #1401 |

Full oldest-first lists: **`WAVE-QUEUES.md`**.

#### Fold protocol (per wave — for Codex executors)

1. Claim one wave only; integration branch `fold/<wave>-YYYYMMDD` off **fresh** `origin/master`.
2. For each PR oldest-first: `git fetch` head; `git cherry` / patch-id re-check vs master; skip if already landed or shelved.
3. Cherry or surgical port; run LoadoutManager mirrors + lint gate; **draft PR only**.
4. Box **war gate** (clean boot is **not** acceptance) before owner merge.
5. Builder ≠ evaluator; never bulk-approve (fleet-review-queue rule).
6. Check shelved-PR register before each fold candidate.

#### Model reference

- **#1799** — `fold(spectator): v4 streaming stack` — MERGEABLE, draft, integration pattern.  
  URL: https://github.com/rayswaynl/a2waspwarfare/pull/1799  
  Fold of #1786 + #1715. Use as shape for subsystem integration PRs.

### (3) CONFLICTING recut list

Full 46: **`CONFLICTING-LIST.md`**.

#### Priority recuts (task-named; verified still OPEN + CONFLICTING)

| PR | Title | Head | Recut notes |
|----|-------|------|-------------|
| **#1596** | fix(hc): seat HCs on CIV natively | `fable/hc-civ-magnet-20260729` | **PRIORITY** — cold-boot HC WEST-preseat race still live. Recut must account for post-`a94b9983fd` mission.sqm **and** open **#1798** Caster 1/2 slots (same sqm surface). Do not merge as-is. |
| **#1773** | fix(mission-core): parachute/HALO airborne (r72) | `fix/mission-parachute-airborne-r72-g1606-20260731` | Recut onto current master; sibling #1772 also CONFLICTING — coordinate. |
| **#1767** | fix(sqf): loadout equip null integrity (r72b) | `fix/sqf-loadout-equip-null-r72b-g1606-20260731` | Recut; high surface area on equip/EASA. |
| **#1669** | fix(hc-lobby-lock): mission-live deadline anchor | `fable/hc-lobby-lock-mission-live-anchor-20260730` | Recut; pairs with HC cold-boot story (#1596). |

#### Explicit non-recuts

| PR | Status | Reason |
|----|--------|--------|
| **#1665** | CLOSED | Superseded/regressive (spectator v3); do **not** recut. Evidence on PR. |
| **#1668 #1528 #1371** | CLOSED | Already-in-master from mechanical equivalence sweep. |

### (4) Lineage holds

| PR | mergeable | Hold |
|----|-----------|------|
| **#1796** | MERGEABLE | **Stay open** as deploy-lineage tracking — never merge to master as-is (per task / PR comment). Exclude from fold waves. |
| **#1798** | MERGEABLE (mergeState UNSTABLE) | Caster slots; coordinate with any #1596 sqm recut. |
| **#1799** | MERGEABLE (mergeState UNSTABLE) | Fold model; war-gate then owner merge — not auto-bulk. |

---

## Wave cut recommendations (first executable slices)

Suggested first integration-branch candidates for Codex (small, oldest, low surface) once war gate capacity exists:

1. **W2-aicom-correctness mini:** #1540 (chunk founding) → #1598 (epilogue nilguard) if patch-id still novel vs master.  
2. **W3-alife mini:** #1615 hysteresis → #1621 ambient teardown (oldest alife pair).  
3. **W1-r-series late:** Prefer single high-value r78–r80b merges only after mid-series patch-id scan; r56–r80 dominates count — do **not** bulk-fold without per-PR cherry.

Do **not** start with #1596 until a dedicated recut branch lands post-#1798 sqm coordination.

---

## Guardrails restated

- Draft PRs only; never merge / deploy / restart live box from this program.  
- War-gate every wave on the box.  
- Shelved-PR register check per fold.  
- Never bulk-approve.  
- Route bulk execution through Codex; Claude orchestrates + verifies; this Grok deliverable is the **queue program + recompute evidence**.

---

## What was NOT verified this run

- Full `git patch-id --stable` re-index of master since 2026-07-01 (session a443 artifacts not found on disk).  
- Per-PR `git cherry` equivalence against current master for the 80 MERGEABLE.  
- Shelved-PR wiki register cross-check for every candidate.  
- Box war-gate / RPT for any PR.  
- Independent evaluator review of this program.

---

## Artifact index (this folder)

| File | Purpose |
|------|---------|
| `FOLD-WAVE-PROGRAM.md` | This program (owner-facing) |
| `WAVE-QUEUES.md` | MERGEABLE oldest-first by wave |
| `CONFLICTING-LIST.md` | All 46 CONFLICTING + priority marks |
| `pr-meta.tsv` | Full open-draft metadata |
| `pr-classify-initial.tsv` | Mergeability classification snapshot |
| `mergeable-detail.tsv` / `mergeable-by-wave.tsv` | Wave assignment TSV |
| `conflicting-detail.tsv` | CONFLICTING TSV |
| `mergeable-numbers.txt` / `conflicting-numbers.txt` / `unknown-numbers.txt` | Number lists |

---

## Close shape notes

- Work class: owner-facing **report program** (not code fold).  
- Next action for fleet: Codex claim W2 or W3 mini-fold OR #1596 recut design; Claude war-gate.  
- MILESTONE delivered via Fleet-Drop + Peach summary (see task done evidence).
