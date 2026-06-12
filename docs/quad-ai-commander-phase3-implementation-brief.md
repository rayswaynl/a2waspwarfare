# Quad AI Commander Phase 3 Implementation Brief

This is the kickoff brief for the advisory planner branch after Phase 2 context/beliefs are proven.

Target branch name:

```text
codex/ai-commander-planner
```

Base branch:

```text
codex/ai-commander-context
```

Primary specs:

```text
docs/quad-ai-commander-phase2-beliefs.md
docs/quad-ai-commander-phase3-planner.md
docs/quad-ai-commander-runtime-validation.md
```

## Objective

Add an advisory AI Commander planner that reads bounded Phase 2 beliefs and writes bounded, explainable priorities without changing commander decisions.

Phase 3 is complete when the commander can turn active beliefs into ranked priority records, emit slow debug summaries, and prove that no workers consume those priorities while advisory mode is true.

## Preconditions

Do not open this branch for ready review until:

- PR #14 has Phase 0 runtime evidence for full-auto, hybrid-assist, handoff, and stopped modes.
- PR #18 has Phase 1 runtime evidence for structured logs and behavior neutrality.
- PR #19 has Phase 2 synthetic/runtime evidence for belief create/merge/decay/expiry and advisory-only behavior.

A draft scaffold may be opened before those gates, but it must remain advisory-only and must not wire priorities into workers.

## Files To Add

```text
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Plan.sqf
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_PriorityScore.sqf
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_PrioritySelect.sqf
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_PlanDebug.sqf
```

Optional validation-only helper, if runtime smoke needs seeded beliefs without waiting for natural context:

```text
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_PlanSyntheticSmoke.sqf
```

The synthetic planner helper, if added, must be manual-only and never called by gameplay.

## Files To Edit

```text
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander.sqf
```

Only add guarded compile/call hooks for the advisory planner. Do not edit town assignment, executor, type assignment, production, upgrade, or worker behavior in Phase 3.

## Compile Strategy

Prefer compiling near other AI Commander functions when local editing is easy.

If stacked through connector edits, the lazy-compile pattern is acceptable:

```sqf
if (isNil "WFBE_SE_FNC_AI_Com_Plan") then {WFBE_SE_FNC_AI_Com_Plan = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_Plan.sqf"};
if (isNil "WFBE_SE_FNC_AI_Com_PriorityScore") then {WFBE_SE_FNC_AI_Com_PriorityScore = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_PriorityScore.sqf"};
if (isNil "WFBE_SE_FNC_AI_Com_PrioritySelect") then {WFBE_SE_FNC_AI_Com_PrioritySelect = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_PrioritySelect.sqf"};
if (isNil "WFBE_SE_FNC_AI_Com_PlanDebug") then {WFBE_SE_FNC_AI_Com_PlanDebug = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_PlanDebug.sqf"};
```

Guard every call so planner failure cannot break commander execution.

## Storage Contract

Store planner output on side logic:

```sqf
_logik setVariable ["wfbe_aicom_priorities", []];
_logik setVariable ["wfbe_aicom_plan_last_update", 0];
_logik setVariable ["wfbe_aicom_plan_last_debug", 0];
_logik setVariable ["wfbe_aicom_plan_seq", 0];
_logik setVariable ["wfbe_aicom_plan_advisory", true];
```

No public broadcast is required in Phase 3.

## Function Contracts

### AI_Commander_Plan.sqf

Input:

```sqf
// _side
```

Required behavior:

- resolve side logic
- read `wfbe_aicom_context`
- ignore expired beliefs
- generate candidate priorities from active/stale beliefs
- score candidates with `AI_Commander_PriorityScore`
- select/cap candidates with `AI_Commander_PrioritySelect`
- store `wfbe_aicom_priorities`
- increment `wfbe_aicom_plan_seq` per generated priority batch
- optionally emit slow debug summaries
- never issue orders, produce units, start upgrades, or change team modes

### AI_Commander_PriorityScore.sqf

Input:

```sqf
// [_side, _belief, _priorityType]
```

Required behavior:

- calculate a score from confidence, threat type, town relation, freshness, and source count
- clamp score between 0 and 1
- return a compact scored priority candidate or `[]` if the belief should not produce that priority

Suggested model:

```text
score = confidence * threatWeight * townWeight * freshnessWeight * sourceWeight
```

### AI_Commander_PrioritySelect.sqf

Input:

```sqf
// [_side, _priorities]
```

Required behavior:

- sort or repeatedly select highest-scoring priorities
- cap total selected priorities at 8
- cap per town at 2
- cap per belief at 2
- avoid selecting only attack priorities for one town
- return selected priorities only

### AI_Commander_PlanDebug.sqf

Input:

```sqf
// [_side, _priorities]
```

Required behavior:

- emit slow summary-only RPT output
- include top priority type, town, score, reason, and belief id
- include selected counts by broad class when possible
- never dump every priority every tick

Example:

```text
AI_Commander_Plan: [WEST] top DEFEND_TOWN Gorka score=0.86 reason=enemy armor near friendly town belief=contact-WEST-12
AI_Commander_Plan: [WEST] selected 4 priorities: defend=1 scout=1 attack=1 support=1
```

## Priority Shape

Use the Phase 3 spec record:

```sqf
// [seq, priorityType, score, townObj, townName, pos, category, beliefId, reason, createdAt, expiresAt]
[12, "DEFEND_TOWN", 0.86, _gorka, "Gorka", [9610,8790,0], "armor", "contact-WEST-12", "enemy armor near friendly town", time, time + 180]
```

Initial priority types:

```text
DEFEND_TOWN
SCOUT_CONTACT
ATTACK_CONTACT
CONTAIN_ARMOR
WATCH_AIR
IGNORE_STALE
```

## Supervisor Hook

Add a slow guarded planner interval inside `AI_Commander.sqf`, after context update exists and while the commander is active.

Suggested interval:

```sqf
if (time - _ltPlan > 45) then {
	if (!isNil "WFBE_SE_FNC_AI_Com_Plan") then {(_side) Call WFBE_SE_FNC_AI_Com_Plan};
	_ltPlan = time;
};
```

This hook must not be inside the full-auto economy-only block. Hybrid mode can produce advisory priorities, but workers must not consume them in Phase 3.

## Static Checks

Before opening or updating the PR:

- no Arma 3-only syntax
- all new files compile with `preprocessFileLineNumbers`
- planner reads `wfbe_aicom_context` but no worker reads `wfbe_aicom_priorities`
- advisory mode defaults true
- no order, production, upgrade, type-assignment, or town-assignment behavior changes
- priority count is capped
- priority scores are clamped between 0 and 1
- malformed beliefs fail soft

## Runtime Smoke

Using Phase 2 synthetic context or real beliefs:

- high-confidence armor near friendly town creates `DEFEND_TOWN`
- medium-confidence unknown contact creates `SCOUT_CONTACT`
- credible contact near enemy town creates `ATTACK_CONTACT`
- armor belief creates `CONTAIN_ARMOR`
- air belief creates `WATCH_AIR`
- stale/expired beliefs do not produce actionable priorities
- multiple beliefs near one town are capped
- planner summaries appear only on the slow interval
- no team waypoints, production, upgrades, templates, or town assignments change while advisory mode is true

## PR Body Skeleton

```markdown
## What

Adds the Phase 3 AI Commander advisory planner. It reads Phase 2 beliefs and writes bounded, explainable priorities without changing commander behavior.

## Boundaries

- Advisory planner only.
- No worker biasing yet.
- No economy or waypoint behavior changes.
- Priorities are server-owned and side-logic scoped.
- Advisory mode defaults true.

## Validation

- Static checks: ...
- Planner smoke: ...
- RPT/debug excerpts: ...
```

## Stop Conditions

Stop and fix before publishing if:

- planner output can crash when context is missing or malformed
- priorities grow unbounded
- scores exceed 1 or go below 0
- workers read priorities in Phase 3
- human explicit orders or economy boundaries are affected
- advisory mode is false by default

## Next Phase

After Phase 3 passes, use `docs/quad-ai-commander-phase4-worker-biasing.md` to implement guarded worker biasing. Phase 4 is the first phase where planner output may affect behavior, and it must preserve human/delegation/economy boundaries.
