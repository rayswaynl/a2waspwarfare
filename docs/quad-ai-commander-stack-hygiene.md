# Quad AI Commander Stack Hygiene

This note records current branch-stack housekeeping for the Quad AI Commander PR chain.

## Current Stack

```text
#14 feat/ai-commander
  -> #18 codex/ai-commander-logs
      -> #19 codex/ai-commander-context
```

#17 / `codex/quad-ai-commander` remains the docs/wiki source of truth.

## Current Housekeeping State

Phase 1 was hardened in `AI_Commander_LogAppend.sqf` to avoid a code-block `isNil` check around `wfbe_aicom_log_last_prune`. The helper now sets the prune timestamp after append/prune, which keeps the behavior equivalent while reducing Arma 2/OA compatibility risk.

The same `AI_Commander_LogAppend.sqf` content was mirrored onto #19 so Phase 2 manual smoke uses the hardened log append helper.

Because this was mirrored instead of rebased, #19 can show as:

```text
mergeable draft
15 ahead / 1 behind codex/ai-commander-logs
```

That state is stack housekeeping, not a behavior gate. The content conflict is cleared; a normal stack refresh or rebase can tidy the compare before ready review.

## Ready-Review Order

Do not advance stacked PRs out of draft just because they are mergeable.

1. Prove #14 Phase 0 runtime behavior first.
2. Refresh #18 against the accepted #14 head if #14 changes.
3. Prove #18 structured logs with RPT evidence.
4. Refresh #19 against the accepted #18 head.
5. Prove #19 context/beliefs with synthetic/manual RPT evidence.

## Current Runtime Gates

#14 still needs runtime proof for:

- hybrid command-bar Move/Patrol/Defense execution
- delegated teams auto-driving while non-delegated human teams are not overwritten
- AI economy freeze while a human commander owns the side
- human-leaves handoff back to full AI command
- disabled/HQ-down stopped behavior

#18 still needs runtime proof for:

- `STATE full`, `STATE assist`, and `STATE stopped`
- `ORDER` from explicit command execution
- `TOWN_ASSIGN` from autonomous/delegated assignment
- `PRODUCTION` and `UPGRADE` in full-auto only
- bounded per-side sequence/log storage
- no behavior changes caused by logging

#19 still needs runtime proof for:

- manual synthetic helper appends `CONTACT`, `INTEL`, and `LOSS`
- synthetic records become bounded beliefs
- nearby contact merge raises confidence without exceeding `0.95`
- low-confidence `INTEL` remains rumor/tracked context
- `LOSS` creates or reinforces moderate threat context
- nearest-town attachment appears in debug output
- belief confidence decays and stale beliefs stop appearing
- no worker reads `wfbe_aicom_context`
