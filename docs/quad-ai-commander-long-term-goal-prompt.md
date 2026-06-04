# Quad AI Commander Long-Term Goal Prompt

Use this prompt to resume Codex or another implementation assistant on the Quad AI Commander integration without losing the intended scope, evidence gates, or branch order.

## Persistent Objective

Drive the Quad AI Commander integration for `rayswaynl/a2waspwarfare` from concept to usable, tested feature.

Evolve the current AI Commander execution branch into a log-driven planning/context layer with:

- structured commander logs
- contact and intel beliefs
- confidence merge/decay
- advisory planner priorities
- guarded worker biasing
- runtime watchlists
- wiki/documentation handoff
- honest stacked PR coordination

Do not redefine success as documentation, static review, or branch creation alone. The integration is not ready until the required runtime evidence exists.

## Current Stack Order

```text
#14 feat/ai-commander
  Phase 0 execution substrate
  supervisor, executor, town assignment, production, upgrades, hybrid command

#18 codex/ai-commander-logs
  Phase 1 structured logs
  STATE, ORDER, TOWN_ASSIGN, PRODUCTION, UPGRADE, bounded per-side log buffer

#19 codex/ai-commander-context
  Phase 2 context/beliefs
  CONTACT, INTEL, LOSS consumption into bounded advisory beliefs

#17 codex/quad-ai-commander
  docs/wiki/tracker source of truth
```

## Operating Rules

- Treat `feat/ai-commander` as the execution substrate.
- Add planning/context behavior as layers above the existing workers, not as replacements.
- Keep advisory phases advisory: no behavior change until the relevant evidence gate is passed.
- Preserve hybrid behavior:
  - human explicit Move/Patrol/Defense orders are sacred
  - non-delegated teams under a human commander are not auto-overwritten
  - delegated teams may be auto-driven
  - AI economy remains frozen while a human commander owns the side
- Keep all logs, beliefs, priorities, source lists, and debug output bounded.
- Prefer fail-soft guards over hard failures in server-side SQF helpers.
- Keep PR comments and docs honest when a branch is content-refreshed but not graph-rebased.
- Never claim runtime proof from static code review.

## Phase 0 Required Evidence

Before treating #14 as ready, collect positive runtime evidence for:

- full-auto lifecycle entering `full`
- type assignment
- town assignment and movement
- production queueing and release
- upgrade start and debit behavior
- hybrid mode entering `assist`
- human command-bar Move execution
- human command-bar Patrol execution
- human command-bar Defense execution
- delegated team auto-driving under a human commander
- non-delegated teams not being overwritten
- no AI production or upgrade spending while a human commander owns economy
- human-leaves handoff back to full AI command
- disabled parameter or HQ-down entering `stopped`
- no blocking RPT errors around AI Commander files, `wfbe_exec_sig`, or `wfbe_queue`

Non-runtime #14 readiness remains separate:

- Takistan/generated mission parity
- PR8-L1 Command Center label alignment
- PR body hygiene that separates evidence from pending work

## Phase 1 Required Evidence

Before #18 can leave draft, collect RPT evidence for:

- `STATE full`
- `STATE assist`
- `STATE stopped`
- `ORDER` for human/hybrid explicit orders
- `TOWN_ASSIGN` for autonomous or delegated town assignment
- `PRODUCTION` in full-auto only
- `UPGRADE` in full-auto only
- no `PRODUCTION` or `UPGRADE` while a human commander owns economy
- monotonically increasing per-side sequence numbers
- bounded log storage after many records
- no behavior change caused by logging

#18 is content-refreshed onto #14 hardening but still needs a true graph refresh/rebase before runtime smoke or ready review.

## Phase 2 Required Evidence

Before #19 can leave draft, collect RPT evidence for:

- manual synthetic helper appending `CONTACT`, `INTEL`, and `LOSS`
- `CONTACT` creating a tracked belief
- nearby contact merging and raising confidence without exceeding the cap
- `INTEL` appearing as low-confidence rumor/tracked context
- `LOSS` creating or reinforcing moderate threat context
- nearest-town attachment in debug output
- confidence decay over time
- stale belief expiry
- no worker reading `wfbe_aicom_context`
- no waypoint, production, upgrade, or type-assignment behavior change because context exists

#19 is content-refreshed onto #18 hot-path blobs but still needs a true graph refresh/rebase after #18 is refreshed.

## Phase 3 Advisory Planner Scope

Do not start planner code until Phase 2 has positive evidence.

When ready, the planner branch should:

- add `AI_Commander_Plan.sqf`
- write bounded `wfbe_aicom_priorities`
- default to advisory mode
- emit explainable priority summaries
- avoid worker reads of priorities
- avoid waypoint, economy, production, upgrade, type, or town-assignment behavior changes

Initial priority kinds:

- `DEFEND_TOWN`
- `SCOUT_OR_ATTACK`
- `HOLD_OR_DELAY`
- `IGNORE_STALE`

## Phase 4 Worker Biasing Scope

Do not start behavior-changing worker biasing until Phase 3 advisory priorities are proven.

When ready, worker biasing must:

- default off
- require advisory mode to be disabled explicitly before behavior changes
- preserve human explicit orders
- preserve non-delegated hybrid boundaries
- preserve human-command economy freeze
- preserve existing worker fallbacks
- never let stale or malformed priorities drive behavior

## Current Next Best Action

Follow this order:

1. Finish #14 Phase 0 runtime smoke.
2. Graph-refresh #18 onto the accepted #14 head.
3. Prove #18 structured logs in RPT.
4. Graph-refresh #19 onto the accepted #18 head.
5. Prove #19 context/beliefs in RPT.
6. Only then start Phase 3 planner implementation.

## Completion Definition

The integration is ready to implement and test further only when:

- #14 has positive runtime evidence for full-auto, hybrid-assist, handoff, and stopped modes.
- #18 has positive structured-log RPT evidence and remains behavior-neutral.
- #19 has positive synthetic/context RPT evidence and remains advisory-only.
- #17 docs/wiki/tracker remain synced to the real PR and branch state.
- Planner and worker-biasing follow-up gates are explicit and accepted.

The full Quad AI Commander integration is not complete until log, belief, planner, and guarded worker-biasing branches are implemented and proven by runtime evidence.
