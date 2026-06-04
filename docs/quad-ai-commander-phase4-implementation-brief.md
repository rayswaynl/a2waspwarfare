# Quad AI Commander Phase 4 Implementation Brief

This is the kickoff brief for guarded worker biasing after Phase 3 advisory planner priorities are proven.

Target branch name:

```text
codex/ai-commander-worker-biasing
```

Base branch:

```text
codex/ai-commander-planner
```

Primary specs:

```text
docs/quad-ai-commander-phase3-planner.md
docs/quad-ai-commander-phase4-worker-biasing.md
docs/quad-ai-commander-runtime-validation.md
```

## Objective

Let proven planner priorities conservatively bias existing AI Commander workers while preserving all human-command, delegation, economy, queue, factory, upgrade, and fallback boundaries.

Phase 4 is complete when priority-driven behavior can be enabled behind an explicit activation gate, proven with advisory-on and advisory-off runtime evidence, and disabled without changing current fallback behavior.

## Preconditions

Do not open this branch for ready review until:

- PR #14 has Phase 0 runtime evidence for full-auto, hybrid-assist, handoff, and stopped modes.
- PR #18 has Phase 1 runtime evidence for structured logs and behavior neutrality.
- PR #19 has Phase 2 context/belief evidence and remains advisory-only.
- The Phase 3 planner branch has advisory priority evidence and proves workers do not consume priorities while advisory mode is true.

A draft scaffold may be opened before all gates, but behavior-changing code must remain disabled by default and must not bypass fallback behavior.

## Files To Add

Optional shared helper:

```text
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_GetPriorities.sqf
```

Optional validation helper:

```text
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_WorkerBiasSyntheticSmoke.sqf
```

The validation helper, if added, must be manual-only and never called by normal gameplay.

## Files To Edit

Initial Phase 4 should prefer the smallest useful behavior surface:

```text
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_AssignTowns.sqf
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_AssignTypes.sqf
```

Later, after town/type bias is proven:

```text
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Produce.sqf
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_AI_Com_Upgrade.sqf
```

Do not change the executor in Phase 4. Human explicit Move/Patrol/Defense orders stay sacred.

## Activation Gate

Worker bias must be off unless explicitly enabled.

Use Phase 3 advisory mode as the first gate:

```sqf
if (_logik getVariable ["wfbe_aicom_plan_advisory", true]) exitWith { /* existing fallback behavior */ };
```

Add a separate worker-bias flag if practical:

```sqf
if !(_logik getVariable ["wfbe_aicom_worker_bias_enabled", false]) exitWith { /* existing fallback behavior */ };
```

Both gates should be required for behavior changes.

Default state:

```text
wfbe_aicom_plan_advisory = true
wfbe_aicom_worker_bias_enabled = false
```

## Shared Priority Helper Contract

### AI_Commander_GetPriorities.sqf

Input:

```sqf
// [_side, _types]
```

Required behavior:

- resolve side logic
- return `[]` if advisory mode is true
- return `[]` if worker bias flag is absent or false, if that flag is added
- read `wfbe_aicom_priorities`
- filter by requested priority types
- drop expired priorities
- drop malformed records
- sort or select by score descending
- cap returned records
- fail soft

Priority shape from Phase 3:

```sqf
// [seq, priorityType, score, townObj, townName, pos, category, beliefId, reason, createdAt, expiresAt]
```

## Town Assignment Bias

Target:

```text
AI_Commander_AssignTowns.sqf
```

Priority types:

```text
DEFEND_TOWN
SCOUT_CONTACT
ATTACK_CONTACT
```

Required behavior:

- keep current eligible-team gating
- skip player-led teams
- skip teams with explicit Move/Patrol/Defense ownership
- in hybrid mode, only touch delegated `wfbe_autonomous` teams
- assign at most one team to `DEFEND_TOWN` per pass initially
- assign at most one team to `SCOUT_CONTACT` per pass initially
- assign at most two teams to `ATTACK_CONTACT` per pass initially
- log every priority-driven assignment once
- fall back to current nearest-uncaptured-town behavior for remaining teams

Suggested action mapping:

```text
DEFEND_TOWN -> SetTeamMoveMode "defense" + SetTeamMovePos town/pos + AIMoveTo HOLD
SCOUT_CONTACT -> SetTeamMoveMode "patrol" + SetTeamMovePos pos + AIMoveTo SAD/MOVE with scout radius
ATTACK_CONTACT -> prefer priority town/contact over nearest uncaptured town
```

Do not repeatedly reset the same team's waypoint every worker tick. Preserve or extend `wfbe_exec_sig` style idempotency if needed.

## Type Assignment Bias

Target:

```text
AI_Commander_AssignTypes.sqf
```

Priority types:

```text
CONTAIN_ARMOR
WATCH_AIR
```

Required behavior:

- keep the current unlocked-template filtering
- keep random fallback when no priority applies
- do not choose locked templates
- do not assume exact classnames are always present
- score eligible templates with small bonuses rather than hard replacement

Suggested first heuristic:

```text
CONTAIN_ARMOR -> prefer templates/classes containing AT, AA where AT exists, heavy, tank, armor
WATCH_AIR -> prefer AA, air-defense, aircraft, stinger/strela/igla style strings if present
```

If template metadata is too weak, Phase 4 may log advisory template suggestions without changing type selection yet.

## Production Bias

Target:

```text
AI_Commander_Produce.sqf
```

Initial recommendation:

- do not change production in the first Phase 4 slice
- let type assignment bias shape production demand
- keep existing queue, funds, factory, upgrade, and AI cap checks intact

Optional later behavior:

- when multiple missing template units are available, prefer the missing unit that best matches active priority
- never produce units outside the selected template

## Upgrade Bias

Target:

```text
Server_AI_Com_Upgrade.sqf
```

Initial recommendation:

- do not change upgrade choice in the first Phase 4 slice
- log which priority would have influenced upgrades

Upgrade bias should be treated as Phase 4.5 unless runtime evidence shows town/type/production bias is stable.

## Logging

Every behavior-changing action must have a concise reason log:

```text
AI_Commander_AssignTowns: [WEST] team [B 1-2] defending Gorka from priority DEFEND_TOWN score=0.86 reason=enemy armor near friendly town
AI_Commander_AssignTypes: [WEST] team [B 1-3] picked template 4 from CONTAIN_ARMOR priority belief=contact-WEST-12
```

Logs should only appear when an action changes, not every tick for unchanged choices.

## Static Checks

Before opening or updating the PR:

- advisory mode prevents all behavior changes by default
- optional worker-bias flag defaults false
- no worker reads malformed/expired priorities
- fallback path still uses current behavior
- human explicit order ownership is preserved
- hybrid delegation gate is preserved
- AI economy freeze under human commander is preserved
- production queue/funds/factory/upgrade/cap checks are not bypassed
- no dogpiling all teams onto one priority

## Runtime Smoke

Run both advisory-on and advisory-off tests.

With advisory mode true or worker-bias flag false:

- priorities may exist
- town assignment remains current behavior
- type assignment remains current behavior
- production and upgrade remain current behavior
- no priority-driven assignment logs appear

With advisory mode false and worker-bias flag true:

- `DEFEND_TOWN` assigns at most one eligible/delegated AI team to defense
- `SCOUT_CONTACT` assigns at most one eligible/delegated AI team to scout/patrol
- `ATTACK_CONTACT` biases target selection without dogpiling every team
- non-delegated teams under human commander are not touched
- explicit human Move/Patrol/Defense orders are not overwritten
- `CONTAIN_ARMOR` can influence template selection only among eligible templates
- empty/expired/malformed priorities fall back to current behavior
- AI economy remains frozen while a human commander is present
- production queue and AI cap behavior remain unchanged

## PR Body Skeleton

```markdown
## What

Adds Phase 4 guarded worker biasing. Proven planner priorities can influence existing workers only when advisory mode is false and worker bias is explicitly enabled.

## Boundaries

- Behavior-changing phase, gated off by default.
- Human explicit orders remain sacred.
- Hybrid delegation and economy boundaries remain intact.
- Fallback behavior remains available.
- Initial scope is town/type bias only unless otherwise proven.

## Validation

- Static checks: ...
- Advisory-on smoke: ...
- Advisory-off smoke: ...
- RPT excerpts: ...
```

## Stop Conditions

Stop and fix before publishing if:

- worker bias is active by default
- any human explicit order is overwritten
- non-delegated hybrid teams are moved
- AI spends economy under a human commander
- production or upgrade checks are bypassed
- priorities dogpile all teams onto one objective
- expired priorities affect behavior
- fallback behavior is no longer reachable

## Exit Criteria

Phase 4 is complete when planner priorities safely bias existing workers under explicit activation, with runtime evidence proving fallback behavior, human-command boundaries, delegation boundaries, and economy rules still hold.
