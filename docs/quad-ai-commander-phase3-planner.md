# Quad AI Commander Phase 3: Planner Priorities

Phase 3 turns Phase 2 beliefs into ranked commander priorities.

This phase should start in advisory mode. The planner may score threats and recommend actions, but workers should not consume those priorities until the output is proven sane in RPT/debug summaries.

## Scope

Add a planner pass that can:

- read active beliefs from `wfbe_aicom_context`
- score threats and opportunities
- produce bounded priority records
- explain each priority with a short reason string
- expose top priorities for later worker biasing
- emit slow debug summaries

Phase 3 should not directly issue waypoints, produce units, or start upgrades.

## Proposed Files

```text
Server/AI/Commander/AI_Commander_Plan.sqf
Server/AI/Commander/AI_Commander_PriorityScore.sqf
Server/AI/Commander/AI_Commander_PrioritySelect.sqf
Server/AI/Commander/AI_Commander_PlanDebug.sqf
```

Compile near the other AI Commander functions:

```sqf
WFBE_SE_FNC_AI_Com_Plan = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_Plan.sqf";
WFBE_SE_FNC_AI_Com_PriorityScore = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_PriorityScore.sqf";
WFBE_SE_FNC_AI_Com_PrioritySelect = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_PrioritySelect.sqf";
WFBE_SE_FNC_AI_Com_PlanDebug = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_PlanDebug.sqf";
```

## Storage

Store planner output on the side logic:

```sqf
_logik setVariable ["wfbe_aicom_priorities", []];
_logik setVariable ["wfbe_aicom_plan_last_update", 0];
_logik setVariable ["wfbe_aicom_plan_last_debug", 0];
_logik setVariable ["wfbe_aicom_plan_seq", 0];
_logik setVariable ["wfbe_aicom_plan_advisory", true];
```

Planner output is server-owned in Phase 3.

## Priority Shape

Use a compact array record:

```sqf
// [seq, priorityType, score, townObj, townName, pos, category, beliefId, reason, createdAt, expiresAt]
[12, "DEFEND_TOWN", 0.86, _gorka, "Gorka", [9610,8790,0], "armor", "contact-gorka-001", "enemy armor near friendly town", time, time + 180]
```

Field notes:

- `seq`: per-side planner sequence
- `priorityType`: uppercase action class
- `score`: 0.0 to 1.0
- `townObj` / `townName`: attached town where relevant
- `pos`: target or reference position
- `category`: belief category such as `armor`, `infantry`, `air`, `unknown`
- `beliefId`: source belief id
- `reason`: short human-readable explanation
- `createdAt` / `expiresAt`: bounded lifetime

## Priority Types

Initial types:

- `DEFEND_TOWN`: credible threat near a friendly town
- `SCOUT_CONTACT`: uncertain or stale enemy contact worth confirming
- `ATTACK_CONTACT`: credible enemy contact near an enemy-held town or open objective
- `CONTAIN_ARMOR`: armor contact that can later bias AT/heavy template choices
- `WATCH_AIR`: air contact that can later bias AA/air-defense priorities
- `IGNORE_STALE`: debug-only low score for stale/expired beliefs

Future artillery, UAV, retreat, ambush, or reserve behavior should wait.

## Scoring Model

Priority score should combine simple factors:

```text
score = confidence * threatWeight * townWeight * freshnessWeight * sourceWeight
```

Suggested factors:

- threat: armor 1.0, air 0.9, infantry 0.6, support 0.5, unknown 0.4
- town: friendly town 1.0, enemy town 0.75, no town 0.45
- freshness: fresh 1.0, aging 0.7, stale 0.4
- source: multiple sources 1.0, single direct source 0.75, rumor-only 0.55

Clamp final score between 0.0 and 1.0.

## Rule Examples

### DEFEND_TOWN

Create when:

- confidence >= 0.55
- nearest town belongs to the friendly side
- belief is within town-threat radius

Reason: `enemy armor near friendly town`.

### SCOUT_CONTACT

Create when:

- confidence is between 0.25 and 0.65
- belief is not expired
- no stronger priority already covers the same town/contact

Reason: `uncertain contact needs confirmation`.

### ATTACK_CONTACT

Create when:

- confidence >= 0.50
- belief is near an enemy-held town or neutral objective
- no friendly-town defense priority outranks it

Reason: `enemy contact near enemy-held town`.

### CONTAIN_ARMOR

Create when category is `armor` and confidence >= 0.45.

### WATCH_AIR

Create when category is `air` and confidence >= 0.35.

## Selection Rules

`AI_Commander_PrioritySelect.sqf` should sort and cap priorities.

Suggested caps:

```text
total selected priorities: 8
per town: 2
per belief: 2
worker-actionable priorities: 5
```

Selection should avoid dogpiling:

- do not select five attack priorities for the same town
- prefer the highest defense priority before attack priorities
- keep strategic variety across defense, scout, attack, and support priorities

## Advisory Mode

Advisory mode defaults true.

When advisory is true:

- planner stores priorities
- planner logs summaries
- workers do not consume priorities

When later disabled in Phase 4, workers may read selected priorities and bias behavior.

## Debug Output

Use slow summaries:

```text
AI_Commander_Plan: [WEST] top DEFEND_TOWN Gorka score=0.86 reason=enemy armor near friendly town belief=contact-gorka-001
AI_Commander_Plan: [WEST] selected 4 priorities: defend=1 scout=1 attack=1 support=1
```

Recommended interval: 120-180 seconds.

## Invariants

- Planner must not issue orders in advisory mode.
- Planner must not spend economy.
- Priority count remains bounded.
- Priority scores remain between 0 and 1.
- Expired beliefs do not produce actionable priorities.
- Human explicit orders remain untouched.
- Defense of friendly towns should outrank opportunistic attack when scores are close.
- Planner output should be explainable by belief id and reason string.

## Static Validation Checklist

- New files compile through `preprocessFileLineNumbers`.
- Planner functions are compiled before supervisor calls them.
- No Arma 3-only syntax is introduced.
- Priority arrays follow the fixed indexes documented here.
- Scores are clamped.
- Priority caps are enforced.
- Advisory mode defaults true.

## Runtime Smoke Checklist

Using synthetic or real belief context:

- High-confidence armor near friendly town creates `DEFEND_TOWN`.
- Medium-confidence unknown contact creates `SCOUT_CONTACT`.
- Credible contact near enemy town creates `ATTACK_CONTACT`.
- Armor belief creates `CONTAIN_ARMOR`.
- Air belief creates `WATCH_AIR`.
- Stale or expired beliefs do not produce actionable priorities.
- Multiple beliefs near one town are capped to avoid dogpiling.
- Planner summaries appear on the slow interval.
- No team waypoints, production, or upgrades change while advisory mode is true.

## Exit Criteria

Phase 3 is complete when the commander can turn Phase 2 beliefs into bounded, explainable, ranked priorities in advisory mode. The output must be stable enough for Phase 4 to bias existing workers without inventing new planner semantics.
