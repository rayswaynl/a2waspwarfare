# Quad AI Commander Integration Tracker

This tracker summarizes the staged Quad AI Commander integration plan, current status, dependencies, and evidence gates.

## Current PRs

| PR | Branch | Purpose | Status |
|---|---|---|---|
| #14 | `feat/ai-commander` | Execution substrate: supervisor, executor, town assignment, production, upgrades, hybrid command | Open draft; full-auto smoke noted, hybrid/handoff/stopped evidence still needed |
| #17 | `codex/quad-ai-commander` | Docs, roadmap, phase specs, validation plan, implementation briefs | Open; docs-only source-of-truth |
| #18 | `codex/ai-commander-logs` | Phase 1 structured log implementation stacked on `feat/ai-commander` | Open draft; implementation-only, runtime evidence pending |
| #19 | `codex/ai-commander-context` | Phase 2 context/belief scaffold stacked on `codex/ai-commander-logs` | Open draft; advisory-only, synthetic/runtime evidence pending |

## Phase Status

| Phase | Branch | Depends On | Status | Decision Impact |
|---|---|---|---|---|
| 0 Execution substrate | `feat/ai-commander` | current AI commander PR | In progress; partial full-auto evidence | yes, current PR behavior |
| 1 Structured logs | `codex/ai-commander-logs` | Phase 0 stable | Draft PR #18 open; static surface clean, runtime evidence pending | no |
| 2 Context/beliefs | `codex/ai-commander-context` | Phase 1 logs | Draft PR #19 open; advisory-only scaffold with manual smoke helper, synthetic/runtime evidence pending | no |
| 3 Advisory planner | `codex/ai-commander-planner` | Phase 2 beliefs | Spec ready, implementation pending | no by default |
| 4 Worker biasing | `codex/ai-commander-worker-biasing` | Phase 3 planner | Spec ready, implementation pending | yes, gated |

## Phase Documents

| Document | Purpose |
|---|---|
| `docs/quad-ai-commander.md` | Concept and architecture overview |
| `docs/quad-ai-commander-implementation-roadmap.md` | Full staged roadmap |
| `docs/quad-ai-commander-phase0-smoke-brief.md` | Current AI Commander smoke-test brief |
| `docs/quad-ai-commander-phase0-rpt-patterns.md` | Concrete RPT anchors for Phase 0 smoke testing |
| `docs/quad-ai-commander-phase1-logs.md` | Structured log API spec |
| `docs/quad-ai-commander-phase1-implementation-brief.md` | First implementation branch runbook |
| `docs/quad-ai-commander-phase2-beliefs.md` | Context and belief merge/decay spec |
| `docs/quad-ai-commander-phase2-implementation-brief.md` | Context/belief implementation runbook |
| `docs/quad-ai-commander-phase3-planner.md` | Advisory planner priority spec |
| `docs/quad-ai-commander-phase4-worker-biasing.md` | Behavior-changing worker biasing spec |
| `docs/quad-ai-commander-runtime-validation.md` | Runtime evidence, RPT handoff, stop-go rules |
| `wiki/Quad-AI-Commander.md` | Wiki-ready overview |
| `wiki/Quad-AI-Commander-Integration.md` | Integration notes against `feat/ai-commander` |

## Next Best Action

Finish Phase 0 smoke-testing on PR #14, then collect Phase 1 log evidence on draft PR #18. Phase 2 draft PR #19 should stay advisory-only and behind those gates, but its manual smoke helper is ready for synthetic context validation once #18 is runnable.

Already noted in PR #14:

- full-auto boot gates
- supervisor lifecycle
- type assignment
- town attacks
- upgrades
- supervisor disengages when a player takes commander

Remaining Phase 0 proof:

- hybrid mode executes human Move/Patrol/Defense waypoints
- delegated teams auto-drive; non-delegated teams are not overwritten
- AI economy remains frozen under human command
- human-leaves handoff resumes full-auto cleanly
- disabled/HQ-down state stops commander cleanly
- watchlist has no blocking waypoint reset, stale `wfbe_exec_sig`, or stuck `wfbe_queue` issue

Phase 1 is drafted:

```text
PR: #18
branch: codex/ai-commander-logs
base: feat/ai-commander
runbook: docs/quad-ai-commander-phase1-implementation-brief.md
```

Required Phase 1 proof before it can leave draft:

- `STATE full`, `STATE assist`, and `STATE stopped` appear on transitions
- `ORDER` appears for hybrid human Move/Patrol/Defense execution
- `TOWN_ASSIGN` appears for delegated or full-auto town assignment
- `PRODUCTION` and `UPGRADE` appear in full-auto only
- no `PRODUCTION` or `UPGRADE` appears while a human commander owns economy
- log sequence increases per side and stays capped
- existing commander behavior remains unchanged

Phase 2 is drafted:

```text
PR: #19
branch: codex/ai-commander-context
base: codex/ai-commander-logs
runbook: docs/quad-ai-commander-phase2-implementation-brief.md
manual smoke: west Call WFBE_SE_FNC_AI_Com_ContextSyntheticSmoke;
```

Required Phase 2 proof before it can leave draft:

- manual synthetic helper appends `CONTACT`, `INTEL`, and `LOSS` records through Phase 1 logging
- synthetic `CONTACT` creates a tracked belief
- nearby contact merges and raises confidence without exceeding the cap
- synthetic `INTEL` appears as low-confidence rumor/tracked context
- synthetic `LOSS` creates or reinforces a moderate threat belief
- confidence decays and stale beliefs expire
- nearest-town attachment appears in debug summary
- no worker reads `wfbe_aicom_context` yet
- no order, production, upgrade, or type-assignment behavior changes because context exists

## Invariants Across All Phases

- Human explicit Move/Patrol/Defense orders are sacred.
- Non-delegated teams under a human commander are not auto-overwritten.
- AI does not spend economy while a human commander is present.
- Every new layer fails soft and preserves the previous layer's behavior.
- Structured logs, beliefs, and priorities remain bounded.
- Advisory phases do not issue orders, produce units, or start upgrades.
- Runtime evidence must include positive RPT excerpts, not only absence of errors.

## Open Evidence

| Evidence | Needed For | Current State |
|---|---|---|
| Full-auto in-engine smoke | Phase 0 | partial evidence noted in PR #14 body |
| Hybrid command-bar execution smoke | Phase 0 | pending |
| Hybrid delegation/economy-freeze smoke | Phase 0 | pending |
| Handoff smoke | Phase 0 | pending |
| HQ-down/disabled smoke | Phase 0 | pending |
| Phase 1 structured log RPT excerpts | Phase 1 | draft implementation open in PR #18; runtime evidence pending |
| Phase 2 belief merge/decay excerpts | Phase 2 | draft implementation open in PR #19 with manual smoke helper; synthetic/runtime evidence pending |
| Phase 3 advisory priority excerpts | Phase 3 | pending implementation; should wait for Phase 2 smoke evidence |
| Phase 4 worker biasing advisory-on/off excerpts | Phase 4 | pending implementation |

## Stop-Go Rules

Stop and fix before proceeding when:

- behavior changes before the intended activation gate
- human explicit orders are overwritten
- AI spends funds or supply under human command
- logs, beliefs, or priorities grow unbounded
- stale priorities keep driving behavior
- RPT shows undefined variables or nil-code calls
- repeated waypoint reset loops appear in runtime testing
- synthetic smoke helpers run automatically in normal gameplay

## Completion Definition

The Quad AI Commander integration is ready to implement and test when:

1. PR #14 Phase 0 has positive runtime evidence for full-auto, hybrid-assist, handoff, and stopped modes.
2. PR #17 docs are merged or accepted as the source of truth.
3. PR #18 Phase 1 structured logs have positive runtime evidence and remain behavior-neutral.
4. PR #19 Phase 2 context/beliefs have synthetic/runtime evidence and remain advisory-only.
5. Runtime validation expectations are agreed for the planner and worker-biasing follow-up branches.

The full integration is not complete until the log, belief, planner, and worker-biasing branches are implemented and proven by runtime evidence.
