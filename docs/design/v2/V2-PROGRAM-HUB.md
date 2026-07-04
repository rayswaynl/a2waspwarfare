# V2 Program Hub

Status: DRAFT index updated by N5N7  
Lane: 452  
Guide rev for future PR bodies: `GR-2026-07-03a`

## Purpose

Single index for V2 prep artifacts under `docs/design/v2/`. Status values are factual:

- READY: builder can implement from it without major product questions.
- DRAFT: useful artifact exists, but a verification/source-mining gap remains.
- BLOCKED: required external command or source access failed.

## Artifact Index

| Lane | Artifact | Status | Summary |
|---:|---|---|---|
| 435 | `STATS-V2-SCHEMA.md` | READY | Drizzle DDL draft for `matches`, `match_events`, `match_players`, rollup SQL, idempotency/backfill rules. |
| 436 | `INGEST-WORKER-SPEC.md` | READY | WASPSTAT/AICOMSTAT/WASPSCALE ingest grammar, idempotency, transport modes, backfill procedure. |
| 437 | `ADMIN-HUB-SPEC.md` | READY | Read-only admin page inventory, match/stats-health queries, `:8080` fold-in map. |
| 438 | `GUIDES-AUDIT.md` | DRAFT | Player-facing copy inventory and rewrite pack; needs mechanical MDX word-count/mtime refresh. |
| 438 | `GUIDES-REWRITES/` | READY | Copy-ready guide drafts for Start here and Gameplay surfaces. |
| 439 | `BOT-V2-SPEC.md` | READY | Match report, `/mystats`, admin alerts, outbox job types, embed fields. |
| 440 | `PLAYER-STATS-UX-SPEC.md` | READY | Player profile component tree, query contract, privacy matrix, empty states. |
| 441 | `STYLE-GUIDE.md` | READY | Tone, glossary, bot copy rules, anti-patterns, checklist. |
| 446 | `ARCHIVE-CTI-CATALOG.md` | DRAFT | Observed E: archive CTI candidates and top borrow-as-design picks; needs full extraction pass. |
| 447 | `MIKSUU-DRIVE-CATALOG.md` | DRAFT | Miksuu mirror catalog structure and partial observed root context; needs full mirror walk. |
| 448 | `BENNY-DELTA-REPORT.md` | DRAFT | Changelog-level delta matrix and skip filters; needs full source/version reconstruction. |
| 449 | `CTI-COMMANDER-DESIGN-ANALYSIS.md` | DRAFT | crCTI/MCTI/WICT analytical comparison with confidence tags; needs exact source appendix. |
| 450 | `FORUMS-INTELLIGENCE-REPORT.md` | DRAFT | 20 findings and 8 complaint patterns; needs exact forum quotes/source URLs where required. |
| 451 | `TERRAIN-CENSUS.md` | READY | Vanilla terrain CTI fit menu with mode twists and implementation caveats. |
| 452 | `V2-PROGRAM-HUB.md` | DRAFT | This index. |
| 453 | `PR-QUEUE-TRIAGE.md` | BLOCKED | Triage method and owner filters; live PR enumeration not possible in this sandbox. |

## Cross-Cutting Constraints

- No gameplay code in prep artifacts.
- Do not use Arma 3 commands or docs for A2 OA 1.64 implementation.
- Archive material is design input only until license and A2 compatibility are checked.
- `WFBE_C_SIM_GATING` stays rejected.
- PR bodies drafted later must cite `GUIDE-REV GR-2026-07-03a`.

## Where Builders Start

1. Stats/backend: `STATS-V2-SCHEMA.md` then `INGEST-WORKER-SPEC.md`.
2. Website admin: `ADMIN-HUB-SPEC.md`.
3. Public profile: `PLAYER-STATS-UX-SPEC.md`.
4. Bot: `BOT-V2-SPEC.md`.
5. Copy: `STYLE-GUIDE.md`, `GUIDES-AUDIT.md`, `GUIDES-REWRITES/`.
6. Archive-informed design: use DRAFT reports only after filling source gaps.
