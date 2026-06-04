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

#14 now includes a Phase 0 static compatibility pass over the current AI Commander hot path. The pass flattened lazy `&& { ... }` / `|| { ... }` condition-block patterns in:

- `AI_Commander.sqf`
- `AI_Commander_AssignTowns.sqf`
- `AI_Commander_AssignTypes.sqf`
- `AI_Commander_Execute.sqf`
- `AI_Commander_Produce.sqf`

This is intended as Arma 2/OA compatibility hardening only. It does not replace runtime proof for hybrid execution, delegation, economy freeze, handoff, or stopped/HQ-down behavior.

#18 has since received a contents-API refresh onto that Phase 0 compatibility surface. The refreshed content preserves Phase 1 instrumentation while inheriting #14's hardened hot-path shape:

- `AI_Commander.sqf` keeps helper compile and `STATE` records.
- `AI_Commander_AssignTowns.sqf` keeps `TOWN_ASSIGN` records.
- `AI_Commander_Execute.sqf` keeps `ORDER` records.
- `AI_Commander_Produce.sqf` keeps `PRODUCTION` records.
- `AI_Commander_AssignTypes.sqf` inherits the #14 hardening even though Phase 1 does not log there.
- `Server_AI_Com_Upgrade.sqf` continues to emit `UPGRADE` records.

Because the refresh was done as contents-API commits instead of a true git rebase, #18 can still compare as graph-diverged against `feat/ai-commander`:

```text
codex/ai-commander-logs
14 ahead / 5 behind feat/ai-commander
may remain non-mergeable until a normal rebase/merge refresh
```

That state is stack housekeeping, not a new Phase 1 behavior decision. Before Phase 1 smoke or ready review, perform a normal branch refresh/rebase if possible and verify that the visible diff remains instrumentation-only plus inherited Phase 0 compatibility hardening.

Phase 1 was also hardened in `AI_Commander_LogAppend.sqf` to avoid a code-block `isNil` check around `wfbe_aicom_log_last_prune`. The helper now sets the prune timestamp after append/prune, which keeps the behavior equivalent while reducing Arma 2/OA compatibility risk.

The same `AI_Commander_LogAppend.sqf` content was mirrored onto #19 so Phase 2 manual smoke uses the hardened log append helper. Because #18 has now moved again, #19 can show as:

```text
codex/ai-commander-context
15 ahead / 6 behind codex/ai-commander-logs
needs refresh after #18 is graph-refreshed
```

That #19 state is also stack housekeeping, not a behavior gate. Phase 2 remains advisory-only, but it should not be used for smoke until refreshed onto the current #18 head.

## Ready-Review Order

Do not advance stacked PRs out of draft just because they are mergeable.

1. Prove #14 Phase 0 runtime behavior first.
2. Graph-refresh #18 against the accepted #14 head.
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

#14 also still needs non-runtime readiness for:

- Takistan/generated mission parity through the normal regeneration or propagation workflow
- PR8-L1 Command Center label rename alignment
- PR body hygiene that keeps runtime evidence separate from non-runtime readiness

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
