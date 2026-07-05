# AICOM V2 Cutover And Reconciliation Brief

Guide rev: GUIDE-REV GR-2026-07-03a. Owner ruling: Ray, 2026-07-05.
Status: binding program directive for every agent building, spec'ing, or reviewing AICOM V2. Read this BEFORE citing the lane specs or the live build lane.

## The ruling

AICOM V2 deploys **in full, at once** — a one-shot cutover, not a permanent parallel system. After cutover, the OLD V1 commander implementation **and its telemetry** are **mapped, then shelved, then removed**. There will be no permanent dual-brain codebase and no long-term dual telemetry grammar in the RPT.

The mission-global flag model (`WFBE_C_AICOM_V2_ENABLE`, one rollback knob) governs the **transition window only**. It is not the end state; the flag itself retires at step 5.

## The five-step sequence (gates, in order)

1. **Map.** `AICOM-V2-MIGRATION-MAP.md` must account for EVERY V1 worker, constant, and telemetry emitter: each one maps to its V2 home or is recorded as a deliberate drop. A V1 surface not in the map blocks the cutover build. This document gains a telemetry-consumers section (below).
2. **Cut over.** The one-shot build ships. V2 is the only commander logic running. V1 code is still present but inert behind the flag.
3. **Parity soak.** N clean T3 nights against recorded V1 baselines (capture-rate at or above baseline, FPS parity gate, zero filtered RPT script errors, telemetry grammar conformance). The rollback flag stays live for the whole window. N is an owner call at cutover time.
4. **Shelve.** V1 commander files and V1-only AICOMSTAT emitters are removed from the mission tree onto a tagged branch, with a `Shelved-AICOM-V1` wiki record in the established Shelved-* pattern (what/where/how-to-revive).
5. **Remove.** The rollback flag retires, docs re-anchor to V2-only, and wiki pages citing V1 behaviour are marked historical. From this point rollback = revert to the tagged branch, not a flag flip.

## The fork — resolved by force

Two V2 lines currently exist:

| | Spec line (Codex pack, PRs #700-705) | Live line (fable/aicom-v2-l1, PR #713) |
|---|---|---|
| Records | `AICOMV2_*` (PullWorldState, THIRD_VIEW, ...) | `AICOM2_Snapshot` / `AICOM2_Allocate` (`wfbe_aicom2_snap`, `WFBE_SNAP_*`) |
| Telemetry | `AICOMSTAT\|v3` grammar (PLAN/WHY/INTEL families) | `AICOM2\|v1\|` family (e.g. `AICOM2\|v1\|DECAP`) |
| Method | clean-room, harness-first, lanes 415-426 | incremental milestones M0-M5 on live code |
| Validation | acceptance harness + fixtures | shadow-mode + live soak evidence |

A full-at-once deployment can ship exactly ONE of these. **Reconciliation is therefore a blocking prerequisite of step 2**, not a cleanup task.

Reconciliation direction (recommended, owner-adjustable):

- **The live `AICOM2` machinery is the base.** It is shadow-validated against live soak data (M0 snapshot, M1 allocator, M5 latch) and already coexists with the mission's locality/HC reality. Do not build the spec pack's from-scratch `AICOMV2_PullWorldState` alongside it.
- **The spec pack is the contract, re-anchored.** Lane behaviours (415-426), doctrine rules, schema discipline (primitives-only boundaries), explainability (WHY rows), volume protection (424), and the acceptance harness all still bind — ported onto `AICOM2` vocabulary. Where a spec record name collides with a live function, the live name wins and the spec doc gets a rename note.
- **One telemetry grammar ships.** Either the `AICOM2|v1|` family grows the v3 features (WHY correlation, INTEL families, harness-parseable enums) or the v3 grammar adopts the `AICOM2` prefix — builders pick one, document it in the migration map, and every emitter plus every consumer moves to it. No third option, no long-term coexistence.
- **Deliverable:** an updated `AICOM-V2-MIGRATION-MAP.md` with (a) a record/function mapping table `AICOMV2_x <-> AICOM2_y`, (b) the unified grammar decision, (c) the consumer port plan below. Harness fixtures update to score the unified grammar.

## Telemetry consumers — port or retire BEFORE removal

Old-line AICOMSTAT/diag parsing exists outside the mission. Each consumer must be ported to the unified grammar or deliberately retired, and the decision recorded in the migration map:

- `Tools/PrTestHarness/Ops/aicom-watch.ps1` — live AICOM line watcher.
- `Tools/PrTestHarness/Aicom/Score-AicomRounds.ps1` — soak round scorer (this one gates step 3, so it ports FIRST).
- `Tools/PrTestHarness/Rpt/*` analyzers and `KnownNoise.txt`/`MissionIssuePatterns.txt` pattern lists.
- Box-side scripts on the live host (e.g. `C:\WASP\rpt-grpaudit.ps1`, the :8080 stats dashboard's RPT parsing).
- WASPSCALE v2/v2-ext analyzers and their coverage docs.
- Wiki reference pages: `AI-Commander-Logging-And-AICOMSTAT-Telemetry`, `AICOMSTAT-V2-Event-Vocabulary-Census`, `WASPSCALE-V2-Telemetry-Reference`, plus any page citing V1 worker behaviour (mark historical at step 5).

NOT in scope for removal: `GRPBUDGET|`, `DELEGSTAT|`, `TOWNSTAT|`, `GRPEMPTY|` and the groupsGC audit lines. These are group/HC diagnostics owned by `server_groupsGC`/town systems, not the V1 commander — they survive the cutover unchanged (GRPBUDGET emission moves home if its current host file is removed, but the line format stays).

## Builder requirements

- Cite `GUIDE-REV GR-2026-07-03a` and this brief in any cutover-related build report.
- During the transition window (steps 2-3) the RPT may briefly carry both old and unified lines; after step 4 any V1-only emitter in the tree is a review FAIL.
- The V2 design commandments stay binding through cutover: locality-first, pure testable planning core, master-flag fallback (until step 5), perf self-watchdog, defensive map reads.
- Lane 800 (GUER Director, PR #715) is sequenced AFTER cutover stabilises unless the owner pulls it earlier; it is not part of the one-shot.
- Chernarus is source of truth; Takistan/Zargabad mirrors via LoadoutManager, as always.

## Continue reading

- `docs/design/v2/AICOM-V2-LAYER-ARCH.md` — layer architecture and flag model.
- `docs/design/v2/AICOM-V2-MIGRATION-MAP.md` — the mapping this brief extends.
- `docs/design/v2/AICOM-V3-TELEMETRY-CONTRACT.md` — the grammar being unified.
- PR #713 — live lane state (M5 DECAPITATE shadow) and the fork's original statement.
