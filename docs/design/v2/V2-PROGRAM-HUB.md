# V2 Program Hub

GUIDE-REV: GR-2026-07-03a
Base checked: claude/build84-cmdcon36 at b61bf786482631a946d02c3927d2b5c54f261b7c
Prompt SHA256: 5A590C3CDDC3F81D38EA9E092E78E0A166898262937163BA5EC302847AD52E40
Hub lane: 452 / H-1

This page is the source-side index for the 48-hour V2 prep sprint. It is deliberately status-first: rows describe the actual artifact state on this branch, not the desired future state.

Status meanings:

- `DRAFT`: artifact exists but still needs owner/Fable review before being treated as build input.
- `READY`: artifact exists and is intended as build input.
- `MISSING`: the prompt defines the lane, but no artifact exists on this branch yet.
- `TBD`: the lane exists, but the prompt did not name a final artifact path; the lane owner must replace the path when shipping.

Current directory audit:

- Before this hub PR, `docs/design/v2/` had no entries on `claude/build84-cmdcon36`.
- This PR adds only `docs/design/v2/V2-PROGRAM-HUB.md`.
- Future prep lanes must update their own row here when they add or promote an artifact.

## Program Blocks

| Block | Lanes | Theme | Current state |
|---|---:|---|---|
| N1 | 400-407 | AICOM V2 archaeology | Missing |
| N2 | 408-414 | AICOM V2 design pack | Missing |
| N3 | 415-426 | AICOM V2 behavior angles | Missing |
| N4 | 427-434 | Utes Invasion | Missing |
| N5 | 435-441 | Website and bot V2 prep | Missing |
| N6 | 442-445 | Nightly soak farm | Missing |
| N7 | 446-451 | Archive and web mining | Missing |
| N8 | 452-455 | Program hygiene | Hub draft present |

## Artifact Index

| Lane | Block | Artifact | Status | Notes |
|---:|---|---|---|---|
| 400 | N1 | `docs/design/v2/AICOM-V2-BEHAVIORAL-INVENTORY.md` | MISSING | Current commander inventory. |
| 401 | N1 | `docs/design/v2/AICOM-V2-GIT-ARCHAEOLOGY.md` | MISSING | Past commander branch archaeology. |
| 402 | N1 | `docs/design/v2/AICOM-V2-SOAK-DATASET.md` | MISSING | RPT archive behavior dataset; helper scripts may live under `docs/design/v2/tools/`. |
| 403 | N1 | `docs/design/v2/AICOM-V2-B69-CONSOLIDATED-BRIEF.md` | MISSING | B69 sketches and design-doc consolidation. |
| 404 | N1 | `docs/design/v2/AICOM-V2-FAILURE-CATALOG.md` | MISSING | Soak-derived failure catalog. |
| 405 | N1 | `docs/design/v2/AICOM-V2-HC-CONTRACT.md` | MISSING | HC and locality contract. |
| 406 | N1 | `docs/design/v2/AICOM-V3-TELEMETRY-CONTRACT.md` | MISSING | AICOMSTAT v3 telemetry draft. |
| 407 | N1 | `docs/design/v2/AICOM-V2-EXTERNAL-PRIORART.md` | MISSING | Benny, crCTI, WICT and related prior art. |
| 408 | N2 | `docs/design/v2/AICOM-V2-LAYER-ARCH.md` | MISSING | Four-layer architecture spec. |
| 409 | N2 | `docs/design/v2/AICOM-V2-MAP-PROFILE-FORMAT.md` | MISSING | Per-map profile schema. |
| 410 | N2 | `docs/design/v2/AICOM-V2-PROFILE-CH.md` | MISSING | Chernarus profile dataset. |
| 411 | N2 | `docs/design/v2/AICOM-V2-PROFILE-TK.md` | MISSING | Takistan profile dataset. |
| 412 | N2 | `docs/design/v2/AICOM-V2-PROFILE-ZG.md` | MISSING | Zargabad profile dataset. |
| 413 | N2 | `docs/design/v2/AICOM-V2-MIGRATION-MAP.md` | MISSING | V1-to-V2 behavior port map. |
| 414 | N2 | `docs/design/v2/AICOM-V2-ACCEPTANCE-HARNESS.md` | MISSING | V2 soak and analyzer acceptance spec. |
| 415 | N3 | `docs/design/v2/AICOM-V2-MOVEMENT-ROUTE-GRAPH.md` | MISSING | Route-graph doctrine per map profile. |
| 416 | N3 | `docs/design/v2/AICOM-V2-FLUIDITY-LATENCY.md` | MISSING | Reaction-latency budgets and retasking. |
| 417 | N3 | `docs/design/v2/AICOM-V2-BUILD-RESEARCH-PLANNER.md` | MISSING | Goal-driven build order and counter-tech. |
| 418 | N3 | `docs/design/v2/AICOM-V2-BASE-RELOCATION.md` | MISSING | Planning-layer relocation utility. |
| 419 | N3 | `docs/design/v2/AICOM-V2-FIRE-SUPPORT.md` | MISSING | Artillery, CBR and SCUD/TEL doctrine. |
| 420 | N3 | `docs/design/v2/AICOM-V2-ESCALATION-DIRECTOR.md` | MISSING | Phase-aware asset arc. |
| 421 | N3 | `docs/design/v2/AICOM-V2-LIFECYCLE-CLEANUP.md` | MISSING | Entity TTL, reaper and group-budget policy. |
| 422 | N3 | `docs/design/v2/AICOM-V2-DEFENSE-COUNTERATTACK.md` | MISSING | Garrison and counterattack doctrine. |
| 423 | N3 | `docs/design/v2/AICOM-V2-INTEL-PERCEPTION.md` | MISSING | Known-enemy state and fog-of-war rules. |
| 424 | N3 | `docs/design/v2/AICOM-V2-GUER-ENDGAME.md` | MISSING | Third-side and win-condition doctrine. |
| 425 | N3 | `docs/design/v2/AICOM-V2-DIFFICULTY-PROFILES.md` | MISSING | Per-map profiles and commander skill dial. |
| 426 | N3 | `docs/design/v2/AICOM-V2-EXPLAINABILITY-COMMS.md` | MISSING | Decision reasons and player radio flavor. |
| 427 | N4 | `docs/design/v2/utes-invasion/SPEC-UTES-INVASION.md` | MISSING | Complete Utes Invasion ruleset. |
| 428 | N4 | `docs/design/v2/utes-invasion/DATASET-UTES-TERRAIN.md` | MISSING | Utes terrain survey. |
| 429 | N4 | `docs/design/v2/utes-invasion/DATASET-NAVAL-INFRA.md` | MISSING | Naval infrastructure port map. |
| 430 | N4 | `docs/design/v2/utes-invasion/SPEC-DEFENDER-AI-DOCTRINE.md` | MISSING | Utes defender AI doctrine. |
| 431 | N4 | `docs/design/v2/utes-invasion/SPEC-ATTACKER-AI-DOCTRINE.md` | MISSING | Utes attacker AI doctrine. |
| 432 | N4 | `docs/design/v2/utes-invasion/SPEC-ECONOMY.md` | MISSING | Asymmetric economy spec. |
| 433 | N4 | `docs/design/v2/utes-invasion/SPEC-ROTATION-INTEGRATION.md` | MISSING | Rotation, params and stats integration. |
| 434 | N4 | `docs/design/v2/utes-invasion/DATASET-AMPHIBIOUS-PRIORART.md` | MISSING | Amphibious prior-art catalog. |
| 435 | N5 | `docs/design/v2/STATS-V2-SCHEMA.md` | MISSING | Stats V2 schema and migration spec. |
| 436 | N5 | `docs/design/v2/INGEST-WORKER-SPEC.md` | MISSING | WASP ingest worker spec. |
| 437 | N5 | `docs/design/v2/ADMIN-HUB-SPEC.md` | MISSING | Read-only admin hub spec. |
| 438 | N5 | `docs/design/v2/GUIDES-AUDIT.md` | MISSING | Guide inventory and rewrite audit. |
| 438 | N5 | `docs/design/v2/GUIDES-REWRITES/` | MISSING | Rewrite drafts for stale guide pages. |
| 439 | N5 | `docs/design/v2/BOT-V2-SPEC.md` | MISSING | Match-report, mystats and alert spec. |
| 440 | N5 | `docs/design/v2/PLAYER-STATS-UX-SPEC.md` | MISSING | Public player stats page UX spec. |
| 441 | N5 | `docs/design/v2/STYLE-GUIDE.md` | MISSING | Player-facing writing style guide. |
| 442 | N6 | `docs/design/v2/SPEC-SOAK-FARM-NIGHTLY.md` | MISSING | Nightly soak-farm pipeline design. |
| 443 | N6 | `docs/design/v2/SPEC-SOAK-LENS-PACK.md` | MISSING | Four-lens auto-analysis rule pack. |
| 444 | N6 | `docs/design/v2/SPEC-SOAK-LEDGER-CONTRACT.md` | MISSING | Build-ledger data contract. |
| 445 | N6 | `docs/design/v2/SPEC-BOX-RUNBOOK.md` | MISSING | Box runbook and DEPLOY-CLAIM protocol. |
| 446 | N7 | `docs/design/v2/ARCHIVE-CTI-CATALOG.md` | MISSING | Jerry archive Warfare/CTI sweep. |
| 447 | N7 | `docs/design/v2/MIKSUU-DRIVE-CATALOG.md` | MISSING | Miksuu Drive mirror catalog. |
| 448 | N7 | `docs/design/v2/BENNY-DELTA-REPORT.md` | MISSING | Benny 2.073+ changelog and delta report. |
| 449 | N7 | `docs/design/v2/CTI-COMMANDER-DESIGN-ANALYSIS.md` | MISSING | crCTI, MCTI and WICT commander extraction. |
| 450 | N7 | `docs/design/v2/FORUMS-INTELLIGENCE-REPORT.md` | MISSING | Warfare/CTI forum intelligence sweep. |
| 451 | N7 | `docs/design/v2/TERRAIN-CENSUS.md` | MISSING | Vanilla terrain gameplay census. |
| 452 | N8 | `docs/design/v2/V2-PROGRAM-HUB.md` | DRAFT | This hub PR; must be updated by each later prep lane. |
| 453 | N8 | `docs/design/v2/PR-QUEUE-TRIAGE.md` | MISSING | Open PR queue owner decision table. |
| 454 | N8 | `docs/design/v2/FLAG-CENSUS.md` | DRAFT | Lane 454 adds the dark/default-zero flag census with `FLIP-ON`, `OWNER-DECIDE`, `HOLD-DARK`, and `NO-FLIP` classifications. |
| 455 | N8 | `docs/design/v2/AGENTS-GUIDE-REV-STAGED-DIFF.md` | MISSING | Staged guide-rev diff pack. |

## Update Rule

When a prep lane ships, update exactly its row before opening or updating the PR:

1. Change `Status` to `DRAFT` or `READY`.
2. Replace any inferred path if the lane shipped a different artifact name.
3. Add the draft PR number or merge/commit note in `Notes`.
4. Leave unrelated rows untouched.

For multi-artifact lanes, add one row per committed artifact or directory. If a lane chooses a wiki page instead of a source artifact, set the artifact cell to the wiki page name and explain that choice in `Notes`.
