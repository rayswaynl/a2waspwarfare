# Quad AI Commander Implementation Roadmap

This roadmap turns the Quad AI Commander concept into staged implementation work for Wasp Warfare.

The key design choice is to keep the current `feat/ai-commander` branch as the execution substrate. Quad AI Commander should be layered on top as a planner and context system.

```text
execution substrate: supervisor, explicit order executor, town assignment, production, upgrades
planning layer: structured logs, contact beliefs, confidence decay, priority decisions, explainable orders
```

## Goals

- Give AI commanders a shared tactical context built from logs and reports.
- Track enemy information as beliefs with uncertainty, not perfect truth.
- Let fuzzy intel expose useful hidden state in a believable way.
- Bias existing town, template, production, and upgrade workers without breaking their safety checks.
- Make commander decisions explainable through RPT/debug logs and optional player-facing summaries.
- Preserve hybrid behavior: human explicit orders stay sacred, delegated AI teams can be automated, and the AI does not spend economy while a human commands.

## Non-Goals For The First Implementation

- No LLM runtime dependency inside Arma.
- No free-text parsing requirement in SQF.
- No direct omniscient access to every enemy unit as commander truth.
- No direct economy spending from fuzzy intel.
- No replacement of `AI_Commander_Execute.sqf` or the existing waypoint helpers.

## Phase 0: Stabilize Execution Branch

Target branch: `feat/ai-commander`.

Before adding the planner layer, prove the execution layer works:

- Full-auto with no human commander:
  - supervisor enters `full`
  - teams get templates
  - teams receive town assignments
  - production queues and releases correctly
  - upgrades start when affordable
- Hybrid with human commander:
  - supervisor enters `assist`
  - explicit Move/Patrol/Defense orders execute as waypoints
  - delegated teams can be auto-assigned
  - non-delegated teams are not overwritten by auto-town assignment
  - AI economy does not spend while human commands
- Handoff:
  - human leaves and full-auto retakes cleanly
  - HQ down or disabled parameter stops the supervisor

Watch specifically for:

- town waypoint reset loops caused by repeated retargeting while still more than 1500m away
- stale `wfbe_exec_sig` if another system clears waypoints
- side-wide AI cap starving commander production because support/defense units count against it

## Phase 1: Structured Commander Log API

Add a minimal append/read API. Keep it structured and SQF-friendly.

Suggested files:

```text
Server/AI/Commander/AI_Commander_LogAppend.sqf
Server/AI/Commander/AI_Commander_LogDrain.sqf
Server/AI/Commander/AI_Commander_LogPrune.sqf
```

Suggested namespace variables on side logic:

```sqf
_logik setVariable ["wfbe_aicom_logs", []];
_logik setVariable ["wfbe_aicom_log_seq", 0];
```

Record shape:

```sqf
// [seq, kind, time, friendlySide, source, payload]
[17, "CONTACT", time, west, _team, [east, "armor", _pos, 3, 6, 0.75, "Gorka"]]
```

Initial kinds:

- `STATE`: supervisor full/assist/stopped transitions
- `ORDER`: orders issued or executed
- `TOWN_ASSIGN`: team assigned to town
- `PRODUCTION`: unit production ordered
- `UPGRADE`: upgrade started
- `CONTACT`: direct enemy sighting/report
- `INTEL`: fuzzy scripted intelligence
- `LOSS`: known friendly losses or broken contact

Phase 1 should first log existing AI Commander events. It does not need to change decisions yet.

## Phase 2: Context And Belief Store

Add a per-side context store.

Suggested files:

```text
Server/AI/Commander/AI_Commander_ContextUpdate.sqf
Server/AI/Commander/AI_Commander_BeliefMerge.sqf
Server/AI/Commander/AI_Commander_BeliefDecay.sqf
```

Suggested variable:

```sqf
_logik setVariable ["wfbe_aicom_context", []];
```

Belief shape:

```sqf
// [id, enemySide, category, pos, townObj, countMin, countMax, confidence, firstSeen, lastSeen, sources, status]
[
  "contact-gorka-001",
  east,
  "armor",
  [9610,8790,0],
  _gorka,
  3,
  6,
  0.78,
  time - 240,
  time - 30,
  ["BLUEFOR-C1", "INTEL-FUZZY"],
  "moving-east"
]
```

Core operations:

- merge nearby same-category reports
- raise confidence for multiple sources
- decay confidence as `time - lastSeen` grows
- drop expired beliefs
- attach nearest town where possible
- keep source list short to avoid unbounded growth

## Phase 3: Planner Priorities

Add a planner pass that converts beliefs into priorities.

Suggested file:

```text
Server/AI/Commander/AI_Commander_Plan.sqf
```

Suggested priority shape:

```sqf
// [priorityType, score, townObj, pos, category, beliefId, reason]
["DEFEND_TOWN", 0.86, _gorka, getPos _gorka, "armor", "contact-gorka-001", "enemy armor near friendly town"]
```

Initial rules:

- High-confidence enemy near a friendly town creates `DEFEND_TOWN`.
- Medium-confidence enemy near an enemy town creates `SCOUT_OR_ATTACK`.
- Recent friendly loss near a town raises defense priority.
- Stale belief lowers score.
- Multiple active threats compete by score.

Planner interval should be slower than the executor, around 30-60 seconds.

## Phase 4: Bias Existing Workers

Do not directly spawn new tactical behavior at first. Bias the existing workers.

### Town Assignment

Modify `AI_Commander_AssignTowns.sqf` to optionally prefer planner priorities:

- `DEFEND_TOWN`: set delegated/idle teams to `defense` near the friendly town.
- `SCOUT_OR_ATTACK`: send one team toward the target town/position.
- fallback: current nearest uncaptured town logic.

Explicit human orders must remain untouched.

### Template Assignment

Modify `AI_Commander_AssignTypes.sqf` to weight eligible templates:

- enemy armor belief: prefer AT/heavy-capable templates
- enemy infantry/light presence: prefer infantry/light templates
- air threat: prefer AA-capable templates once available
- no strong belief: current random unlocked template fallback

### Production

Keep `AI_Commander_Produce.sqf` affordability, queue, and cap checks. The planner should influence team type before production, not bypass the production worker.

### Upgrades

Use beliefs as soft upgrade priority only after the upgrade path is stable. Avoid twitchy tech spending from one report.

## Phase 5: Explainability And Debugging

Every planner decision should have a reason string.

Log examples:

```text
[AI-COM][WEST] DEFEND_TOWN Gorka score=0.86 reason=enemy armor near friendly town sources=BLUEFOR-C1,INTEL-FUZZY
[AI-COM][WEST] Team B 1-2 assigned defense near Gorka from belief contact-gorka-001
```

Recommended debug summary interval: 120-180 seconds.

Do not spam every unchanged belief every tick. Log changes, transitions, and selected priorities.

## Runtime Smoke Gates For Planner Layer

- Structured logs append and prune without unbounded growth.
- Existing `STATE`, `ORDER`, `TOWN_ASSIGN`, `PRODUCTION`, and `UPGRADE` events appear in RPT.
- Contact logs merge into beliefs.
- Confidence decays and stale beliefs expire.
- Friendly-town threat causes a defense assignment.
- Enemy-town contact causes one scout/attack assignment, not every team dogpiling.
- Human explicit Move/Patrol/Defense order is not overridden.
- Human commander present still blocks AI economy spending.
- Disabled parameter or HQ down stops planner and executor work.

## Suggested Follow-Up PR Sequence

1. `docs/quad-ai-commander`: concept, wiki, integration notes, roadmap.
2. `feat/ai-commander`: execution substrate and hybrid command path.
3. `feat/ai-commander-logs`: structured log API and event emission only.
4. `feat/ai-commander-context`: belief merge/decay and debug summaries.
5. `feat/ai-commander-planner`: planner priorities and worker biasing.

This keeps each PR testable and avoids mixing execution fixes with strategic behavior changes.
