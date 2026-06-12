# Quad AI Commander Evidence Audit Matrix

Use this matrix when deciding whether the Quad AI Commander stack is ready to advance from one phase to the next. It is intentionally evidence-first: a gate is not complete until the listed proof exists in the named PR or runtime handoff comment.

Do not use this page to claim completion from static review. Static review can confirm implementation shape, but runtime gates require RPT excerpts or equivalent in-engine observations.

## How To Use

1. Test the current phase on the branch named in the `Proof Owner` column.
2. Paste exact RPT excerpts into the relevant PR conversation or runtime report.
3. Mark each row `PASS`, `FAIL`, or `UNCERTAIN`.
4. Treat `FAIL` and `UNCERTAIN` as blockers unless the PR explicitly accepts the risk with a reason.
5. Re-run earlier regression gates after a branch refresh or graph rebase.

## Stack Gate Matrix

| Gate | Proof Owner | Required Proof | Blocks If Missing | Current State |
|---|---|---|---|---|
| Phase 0 full-auto lifecycle | PR #14 `feat/ai-commander` | RPT shows AI commander entering full command, assigning types, assigning towns, producing, and upgrading when conditions allow | #18 runtime smoke and ready review | Partly evidenced; hybrid/handoff/stopped still pending |
| Phase 0 hybrid command-bar | PR #14 `feat/ai-commander` | RPT and observation show human Move, Patrol, and Defense orders become real waypoints through `AI_Commander_Execute.sqf` | #18 runtime smoke and ready review | Pending |
| Phase 0 delegation boundary | PR #14 `feat/ai-commander` | Delegated AI-led teams are auto-driven; non-delegated teams and explicit human orders are not overwritten | #18 runtime smoke and ready review | Pending |
| Phase 0 economy freeze | PR #14 `feat/ai-commander` | No AI production or upgrade spending appears while a human commander owns the side | #18 runtime smoke and ready review | Pending |
| Phase 0 handoff | PR #14 `feat/ai-commander` | Human-leaves transition returns to full-auto and useful worker actions resume without waypoint reset loops | #18 runtime smoke and ready review | Pending |
| Phase 0 stopped state | PR #14 `feat/ai-commander` | Disabled parameter or HQ-down state logs stopped once per transition and workers stop issuing actions | #18 runtime smoke and ready review | Pending |
| Phase 0 watchlist sweep | PR #14 `feat/ai-commander` | RPT and observation show no blocking `wfbe_exec_sig`, `wfbe_queue`, repeated town retargeting, or AI Commander nil/undefined errors | #18 runtime smoke and ready review | Pending |
| Phase 0 non-runtime readiness | PR #14 / release coordination | Takistan/generated mission parity and Command Center label alignment are resolved or explicitly scoped outside runtime smoke | #14 ready-for-review | Pending |
| Phase 1 graph refresh | PR #18 `codex/ai-commander-logs` | Branch is refreshed/rebased onto accepted #14 head; visible diff remains instrumentation-only plus inherited Phase 0 hardening | #18 runtime smoke and ready review | Pending; current compare may show `14 ahead / 5 behind` |
| Phase 1 state/order logs | PR #18 `codex/ai-commander-logs` | RPT shows bounded `STATE full`, `STATE assist`, `STATE stopped`, and `ORDER` records | #19 refresh and runtime smoke | Pending |
| Phase 1 worker logs | PR #18 `codex/ai-commander-logs` | RPT shows `TOWN_ASSIGN`, `PRODUCTION`, and `UPGRADE` where Phase 0 behavior already took those actions | #19 refresh and runtime smoke | Pending |
| Phase 1 neutrality | PR #18 `codex/ai-commander-logs` | Phase 0 behaviors still pass; logging failures do not stop execution; no production/upgrade logs occur under human economy ownership | #19 refresh and runtime smoke | Pending |
| Phase 1 bounds | PR #18 `codex/ai-commander-logs` | Per-side sequence increases monotonically and log arrays remain capped after longer runtime | #19 refresh and runtime smoke | Pending |
| Phase 2 graph refresh | PR #19 `codex/ai-commander-context` | Branch is refreshed/rebased onto accepted #18 head; visible diff is context hook plus context/belief helpers | #19 runtime smoke and Phase 3 implementation | Pending; current compare may show `20 ahead / 6 behind` |
| Phase 2 synthetic records | PR #19 `codex/ai-commander-context` | Manual helper appends `CONTACT`, `INTEL`, and `LOSS` through Phase 1 logging and never runs automatically | Phase 3 implementation | Pending |
| Phase 2 belief behavior | PR #19 `codex/ai-commander-context` | RPT/debug shows contact creation, nearby merge, capped confidence increase, rumor handling, loss reinforcement, nearest-town attachment, decay, and expiry | Phase 3 implementation | Pending |
| Phase 2 advisory boundary | PR #19 `codex/ai-commander-context` | No worker reads `wfbe_aicom_context`; no waypoint, production, upgrade, type assignment, or town assignment changes occur because context exists | Phase 3 implementation | Pending |
| Phase 3 planner start | Future `codex/ai-commander-planner` | #19 has positive Phase 2 evidence; planner writes bounded `wfbe_aicom_priorities`; advisory mode defaults true; workers do not read priorities | Phase 4 implementation | Not started |
| Phase 3 planner proof | Future `codex/ai-commander-planner` | RPT shows explainable priorities for defend, scout/attack, armor containment, air watch, and stale ignore without behavior changes | Phase 4 implementation | Not started |
| Phase 4 worker bias start | Future `codex/ai-commander-worker-biasing` | #20/Phase 3 has positive advisory evidence; worker bias defaults off and requires explicit activation | Behavior-changing ready review | Not started |
| Phase 4 worker bias proof | Future worker-biasing PR | Advisory-off tests show bounded priority-driven assignments while preserving human orders, delegation boundaries, economy freeze, and fallback behavior | Full integration readiness | Not started |

## Minimum Ready-To-Test Claim

The stack can be called ready to implement and test the planner only when these are all true:

- #14 has positive Phase 0 runtime evidence for full-auto, hybrid command-bar, delegation, economy freeze, handoff, stopped, and watchlist rows.
- #18 has been graph-refreshed onto #14 and has positive structured-log evidence while remaining behavior-neutral.
- #19 has been graph-refreshed onto #18 and has positive synthetic context/belief evidence while remaining advisory-only.
- #17 docs/wiki/tracker describe the same PR state that GitHub currently reports.

## Failure Handling

If a row fails:

- Fix the owning branch first.
- Re-run the failed row and any earlier regression row it could affect.
- Update the owning PR body or conversation with the failure, fix commit, and new evidence.
- Keep downstream branches draft until the owning row is `PASS`.

If a row is uncertain:

- Do not promote the branch.
- Add the missing observation or RPT excerpt to the next runtime pass.
- Avoid replacing missing evidence with inference from static code shape.
