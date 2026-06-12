# Quad AI Commander Phase 4: Worker Biasing

Phase 4 lets planner priorities influence the existing AI Commander workers.

This is the first phase where Quad AI Commander changes behavior. It must therefore stay conservative, reversible, and bounded.

## Scope

Bias existing workers from Phase 3 priorities:

- `AI_Commander_AssignTowns.sqf`
- `AI_Commander_AssignTypes.sqf`
- `AI_Commander_Produce.sqf`
- `Server_AI_Com_Upgrade.sqf`

Do not replace the workers. If priority data is missing, stale, malformed, or advisory mode is still on, fall back to the existing behavior.

## Safety Rules

These rules are non-negotiable:

- Human explicit Move/Patrol/Defense orders are sacred.
- Non-delegated teams under a human commander must not be auto-overwritten.
- AI economy must not spend while a human commander is present.
- Planner priorities must expire and must not become permanent orders.
- Missing planner functions or empty priority lists must not break the current AI Commander.
- Every worker keeps its existing affordability, queue, upgrade, cap, and factory checks.
- Defense and scout behavior should start with one or two teams, not the whole side.

## Activation Gate

Phase 3 introduced advisory mode:

```sqf
_logik getVariable ["wfbe_aicom_plan_advisory", true]
```

Phase 4 should only bias behavior when advisory is false:

```sqf
if (_logik getVariable ["wfbe_aicom_plan_advisory", true]) exitWith { /* current fallback behavior */ };
```

Recommended rollout:

1. Enable priority reads behind a constant or side-logic flag.
2. Turn on town assignment bias first.
3. Add template bias second.
4. Add production/upgrade bias only after town/template behavior is stable.

## Shared Priority Read Helper

Optional helper:

```text
Server/AI/Commander/AI_Commander_GetPriorities.sqf
```

Suggested compile:

```sqf
WFBE_SE_FNC_AI_Com_GetPriorities = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_GetPriorities.sqf";
```

Input:

```sqf
// [_side, _types, _maxAge]
```

Behavior:

- Resolve side logic.
- Read `wfbe_aicom_priorities`.
- Filter by priority types.
- Filter expired records.
- Sort by score descending.
- Return a bounded array.

If this helper is not added, each worker should still perform the same filtering locally.

## Priority Indexes

From Phase 3:

```sqf
// [seq, priorityType, score, townObj, townName, pos, category, beliefId, reason, createdAt, expiresAt]
```

Recommended constants or local comments:

```sqf
#define QAI_PRI_SEQ 0
#define QAI_PRI_TYPE 1
#define QAI_PRI_SCORE 2
#define QAI_PRI_TOWN 3
#define QAI_PRI_TOWN_NAME 4
#define QAI_PRI_POS 5
#define QAI_PRI_CATEGORY 6
#define QAI_PRI_BELIEF_ID 7
#define QAI_PRI_REASON 8
#define QAI_PRI_CREATED_AT 9
#define QAI_PRI_EXPIRES_AT 10
```

If the project avoids preprocessor defines in SQF files, keep an indexed comment block near each consumer.

## Town Assignment Bias

Target: `AI_Commander_AssignTowns.sqf`.

Priority usage:

- `DEFEND_TOWN`: assign one eligible team to `defense` at/near the friendly town.
- `SCOUT_CONTACT`: assign one eligible team to `move` or `patrol` near the contact position.
- `ATTACK_CONTACT`: prefer the priority town/contact over nearest uncaptured town.

Eligibility must preserve current rules:

- team leader is not a player
- team has alive units
- no explicit human Move/Patrol/Defense order already owns the team
- in hybrid mode, team must be delegated via `wfbe_autonomous`

Suggested behavior:

```text
1. Build eligible teams with current gating.
2. Consume selected priorities by score.
3. Assign at most one team per priority at first.
4. Mark consumed priorities locally for this pass.
5. Fall back to nearest uncaptured town for remaining eligible teams.
```

Initial caps:

```text
DEFEND_TOWN teams per pass: 1
SCOUT_CONTACT teams per pass: 1
ATTACK_CONTACT teams per pass: 2
```

Do not dogpile every team onto the top priority.

## Template Assignment Bias

Target: `AI_Commander_AssignTypes.sqf`.

Current behavior chooses a random unlocked template. Phase 4 should weight eligible templates from support priorities.

Priority usage:

- `CONTAIN_ARMOR`: prefer templates with AT, armor, or heavy capability.
- `WATCH_AIR`: prefer AA-capable or air-defense templates when available.
- infantry-heavy contacts: prefer infantry/light templates.

Implementation note:

The branch may not have semantic metadata for templates. If so, start with a conservative classname/description heuristic and keep random fallback.

Suggested approach:

```text
1. Build current eligible template list.
2. If no planner priority applies, keep random fallback.
3. Score templates with small bonuses for matching keywords/classnames.
4. Pick from top-scored templates with randomness, not always the single top result.
```

Avoid brittle exact class assumptions where possible.

## Production Bias

Target: `AI_Commander_Produce.sqf`.

Do not bypass existing production checks.

Preferred first approach:

- Let template assignment bias shape what production wants.
- Keep `Produce` filling the chosen template exactly as it does now.

Optional later approach:

- If a team template contains multiple missing unit classes, prefer the missing unit that best matches the active priority.
- Still respect `_reqUp`, factory availability, funds, queue, and side AI cap.

Phase 4 should not directly create special units outside the template system.

## Upgrade Bias

Target: `Server_AI_Com_Upgrade.sqf`.

Be conservative. Current AI upgrade order is deterministic and easier to reason about.

Possible later behavior:

- `CONTAIN_ARMOR`: slightly prefer heavy/AT-related upgrade path if available.
- `WATCH_AIR`: slightly prefer air/AA-related upgrades if available.

Initial Phase 4 recommendation:

- Do not change upgrade choice yet.
- Only log which planner priority would have influenced upgrades.

Upgrade bias can be Phase 4.5 after town/template/production behavior is stable.

## Logging

Every priority-driven worker action should log a reason:

```text
AI_Commander_AssignTowns: [WEST] team [B 1-2] defending Gorka from priority DEFEND_TOWN score=0.86 reason=enemy armor near friendly town
AI_Commander_AssignTypes: [WEST] team [B 1-3] picked template 4 from CONTAIN_ARMOR priority belief=contact-gorka-001
```

These logs should be transition/action logs only, not repeated every worker tick for unchanged choices.

## Invariants

- Current fallback behavior remains available.
- Planner advisory mode prevents all behavior changes.
- Expired priorities are ignored.
- A priority can influence at most a bounded number of teams per pass.
- Human commander economy rule remains intact.
- Existing production queue/funds/factory/cap guards remain intact.
- Runtime logs explain every planner-driven action.

## Static Validation Checklist

- No Arma 3-only syntax is introduced.
- Worker edits preserve existing explicit-order/hybrid delegation gates.
- Priority records are index-read consistently.
- Advisory mode and expiry checks exist before worker biasing.
- Fallback path still uses current behavior.
- Production and upgrade safety checks are not bypassed.

## Runtime Smoke Checklist

With advisory mode true:

- Planner priorities exist, but town assignment remains current behavior.
- No template/production/upgrade changes occur from priorities.

With advisory mode false and synthetic priorities:

- `DEFEND_TOWN` assigns one eligible/delegated AI team to defense near the friendly town.
- Non-delegated teams under human commander are not touched.
- Explicit human Move/Patrol/Defense orders are not overwritten.
- `SCOUT_CONTACT` assigns at most one scout/move/patrol team.
- `ATTACK_CONTACT` biases target selection without sending every team to the same contact.
- `CONTAIN_ARMOR` can influence template selection when matching eligible templates exist.
- Empty/expired/malformed priorities fall back to current nearest-town/random-template behavior.
- AI economy remains frozen while a human commander is present.
- Production queue and AI cap behavior remain unchanged.

## Exit Criteria

Phase 4 is complete when planner priorities can safely bias existing workers under a controlled flag, with fallbacks intact and runtime evidence proving that human orders, delegation boundaries, and economy rules are preserved.
