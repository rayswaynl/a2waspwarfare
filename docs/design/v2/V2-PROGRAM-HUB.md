# V2-PROGRAM-HUB

Status: SPEC-READY hub seed. Created because no pre-seeded hub existed in this worktree.

Guide rev for downstream PR bodies: GR-2026-07-03a.

## Program Rules

- All V2 prep output is research, specs, datasets, or reports under `docs/design/v2/`.
- No gameplay code is produced by prep lanes.
- V2 commander work follows the five design commandments: locality-first, pure testable planning core, master-flag fallback, perf/KPI self-watchdog, and defensive map-data reads.
- V2 behavior must preserve the eight doctrine points: commit, mass, tempo, legibility, memory, non-psychic intel, money pressure, and no dead air.
- Archive-derived ideas are design inputs only unless license and owner constraints are cleared.

## Artifact Index

| Artifact | Lane | Status | Owner/action |
| --- | --- | --- | --- |
| `SPEC-SOAK-FARM-NIGHTLY.md` | 442 | SPEC-READY | Builder implements scripts/tests from spec. |
| `SPEC-SOAK-LENS-PACK.md` | 443 | SPEC-READY | Builder implements `run_lens_pack.py` and tests. |
| `SPEC-SOAK-LEDGER-CONTRACT.md` | 444 | SPEC-READY | Builder implements append helper, seed ledger, Pester tests. |
| `SPEC-BOX-RUNBOOK.md` | 445 | SPEC-READY | Docs PR can add DEPLOY-CLAIM section to AGENTS.md. |
| `ARCHIVE-CTI-CATALOG.md` | 446 | PARTIAL-BLOCKED | Needs Main PC `E:\arma2-cache` exhaustive sweep. |
| `MIKSUU-DRIVE-CATALOG.md` | 447 | PARTIAL-BLOCKED | Needs Main PC Drive mirror tree walk. |
| `PR-QUEUE-TRIAGE.md` | 453 | PARTIAL-BLOCKED | Needs authenticated `gh pr list` or orchestrator export. |
| `FLAG-CENSUS.md` | 454 | SPEC-READY-PARTIAL-EVIDENCE | Local constants read; `git log --grep` unavailable. |
| `AGENTS-GUIDE-REV-STAGED-DIFF.md` | 455 | SPEC-READY | Staged unified diffs only; not applied in prep lane. |

## Missing From This Worktree

No existing `docs/design/v2/` directory was present before this lane. Any other V2 artifacts created by parallel agents must be added to this hub by the orchestrator when branches are combined.

## Publication Notes

Draft PR body must cite GUIDE-REV `GR-2026-07-03a`.

No `Co-Authored-By` trailer.

