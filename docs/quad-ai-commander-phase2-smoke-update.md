# Quad AI Commander Phase 2 Smoke Update

This note records the current Phase 2 smoke-test behavior for PR #19 / `codex/ai-commander-context`.

## Current Helper Behavior

`AI_Commander_ContextSyntheticSmoke.sqf` is still manual-only and is not called during normal gameplay.

Manual server/debug command:

```sqf
west Call WFBE_SE_FNC_AI_Com_ContextSyntheticSmoke;
```

Use `east` for the other side.

The helper now does three things in one manual call:

1. Appends two nearby `CONTACT` records, one `INTEL` record, and one `LOSS` record through the Phase 1 structured log helper.
2. Emits the synthetic-smoke RPT marker.
3. Forces one guarded context update/debug pass immediately after appending the records.

That immediate update/debug pass means testers should not need to wait for the normal 30-second context interval or 120-second debug interval to see the first Phase 2 belief summary.

## Expected RPT Anchors

```text
AI_Commander_ContextSyntheticSmoke: [WEST] appended CONTACT/INTEL/LOSS synthetic records
AI_Commander_Log: [WEST] #... CONTACT
AI_Commander_Log: [WEST] #... INTEL
AI_Commander_Log: [WEST] #... LOSS
AI_Commander_Context: [WEST] ... tracked beliefs, top=...
```

## Evidence Still Required

The helper makes evidence collection faster, but it does not prove Phase 2 by itself. PR #19 should remain draft until runtime RPT confirms:

- synthetic `CONTACT` creates a tracked belief
- nearby contact merges and raises confidence without exceeding the cap
- synthetic `INTEL` appears as low-confidence rumor/tracked context
- synthetic `LOSS` creates or reinforces moderate threat context
- nearest-town attachment appears in the debug summary
- confidence decays and stale beliefs expire or stop appearing
- no worker reads `wfbe_aicom_context`
- no waypoint, production, upgrade, or type-assignment behavior changes because context exists

## Stack Gate

Keep the smoke order intact:

1. PR #14 Phase 0 execution substrate proves hybrid/handoff/stopped behavior.
2. PR #18 Phase 1 structured logs prove runtime log records and behavior neutrality.
3. PR #19 Phase 2 synthetic smoke proves context/beliefs are advisory-only.
