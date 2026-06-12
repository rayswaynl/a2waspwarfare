# Quad AI Commander Runtime Validation Plan

This document defines the evidence needed before each Quad AI Commander phase is considered ready to merge or to feed the next phase.

The core rule: prove each layer works before allowing it to influence the next layer.

## Validation Principles

- Prefer RPT evidence with exact log excerpts.
- Record side, state, town, team, priority, and belief ids wherever possible.
- Separate advisory phases from behavior-changing phases.
- Treat absence of errors as insufficient; each phase needs positive evidence.
- Keep human-command boundaries visible in every hybrid test.
- Re-run handoff tests when the current `feat/ai-commander` execution branch changes.

## Current Stack

| PR | Branch | Phase | Runtime State |
|---|---|---|---|
| #14 | `feat/ai-commander` | Phase 0 execution substrate | full-auto partly evidenced; hybrid/handoff/stopped pending |
| #18 | `codex/ai-commander-logs` | Phase 1 structured logs | draft; runtime log evidence pending |
| #19 | `codex/ai-commander-context` | Phase 2 context/beliefs | draft; synthetic context evidence pending |

Planner and worker-biasing branches should not move out of draft until this stack has positive RPT evidence through Phase 2.

## Required Runtime Modes

Test at least these modes:

```text
full-auto: no human commander, AI controls side
hybrid-assist: human commander present, delegated teams only
handoff: human commander leaves, AI retakes full command
stopped: HQ down or AI commander disabled
```

Where possible, run both WEST and EAST. A single-side smoke is acceptable for early development, but release confidence requires both sides because side-specific constants/templates often drift.

## Stacked Smoke Handoff

Run the stack in this order. Do not advance a phase from draft until the previous phase still passes its regression checks.

### 1. Phase 0 On `feat/ai-commander` / PR #14

Collect RPT evidence for the current execution substrate first:

```text
AI_Commander.sqf: [WEST] AI commander ACTIVE (full command).
AI_Commander_AssignTypes.sqf: [WEST] team ... assigned type ...
AI_Commander_AssignTowns.sqf: [WEST] team ... heading to attack town ...
AI_Commander_Produce.sqf: [WEST] team ... ordering ...
AI_Commander.sqf: [WEST] AI commander ASSIST (hybrid - human commander, executor only).
AI_Commander_Execute.sqf: [WEST] team ... executing move/patrol/defense order ...
AI_Commander.sqf: [WEST] AI commander STOPPED (disabled / HQ down).
```

Required assertions:

- full-auto assigns types, towns, production, and upgrades
- hybrid command-bar Move/Patrol/Defense produces real waypoints
- delegated teams can still be auto-assigned
- non-delegated teams are not overwritten
- no production or upgrade spending happens while a human commands
- human-leaves handoff resumes full-auto cleanly
- stopped state does not keep issuing worker actions

### 2. Phase 1 On `codex/ai-commander-logs` / PR #18

After Phase 0 passes, run the structured-log branch and collect both behavior and log evidence:

```text
AI_Commander_Log: [WEST] #... STATE
AI_Commander_Log: [WEST] #... ORDER
AI_Commander_Log: [WEST] #... TOWN_ASSIGN
AI_Commander_Log: [WEST] #... PRODUCTION
AI_Commander_Log: [WEST] #... UPGRADE
```

Required assertions:

- sequence numbers increase per side
- log buffer remains bounded after a longer run
- `STATE full`, `STATE assist`, and `STATE stopped` appear on transitions
- `ORDER` appears for hybrid human Move/Patrol/Defense execution
- `TOWN_ASSIGN` appears for full-auto or delegated teams
- `PRODUCTION` and `UPGRADE` appear in full-auto only
- no `PRODUCTION` or `UPGRADE` appears while a human commander owns economy
- no commander behavior changes solely because logging exists

### 3. Phase 2 On `codex/ai-commander-context` / PR #19

After Phase 1 passes, run the context branch and use the manual synthetic smoke helper from server/debug context:

```sqf
west Call WFBE_SE_FNC_AI_Com_ContextSyntheticSmoke;
```

Use `east` for the other side.

Expected RPT anchors:

```text
AI_Commander_ContextSyntheticSmoke: [WEST] appended CONTACT/INTEL/LOSS synthetic records
AI_Commander_Log: [WEST] #... CONTACT
AI_Commander_Log: [WEST] #... INTEL
AI_Commander_Log: [WEST] #... LOSS
AI_Commander_Context: [WEST] ... tracked beliefs, top=...
```

Required assertions:

- synthetic helper runs only when manually invoked
- synthetic `CONTACT`, `INTEL`, and `LOSS` records are appended through Phase 1 logging
- nearby contacts merge and raise confidence without exceeding `0.95`
- low-confidence `INTEL` remains rumor/tracked context and does not jump to high confidence alone
- `LOSS` creates or reinforces moderate-confidence threat context
- nearest-town attachment appears in context debug summary when a town anchor exists
- confidence decays and old beliefs expire or stop appearing in tracked summaries
- no worker reads `wfbe_aicom_context` yet
- no waypoint, production, upgrade, or type-assignment behavior changes solely because context exists

## Phase 0: Execution Substrate Evidence

Target branch: `feat/ai-commander`.

Evidence required:

- `STATE full` equivalent lifecycle log when no human commander exists.
- AI teams receive templates.
- AI teams receive town assignments.
- Produced unit enters and leaves `wfbe_queue` normally.
- Upgrade starts only when affordable.
- `STATE assist` equivalent lifecycle log when human commander exists.
- Human Move/Patrol/Defense command produces real waypoints.
- Delegated teams can still be auto-assigned.
- Non-delegated teams under human command are not overwritten.
- AI economy does not spend while human commands.
- Human-leaves handoff resumes full-auto cleanly.
- HQ down or disabled parameter stops the supervisor.

Watch items:

- repeated town retargeting before teams enter the 1500m band
- stale `wfbe_exec_sig` after external waypoint clears
- side-wide AI cap starving commander teams due to support/defense units

## Phase 1: Structured Logs Evidence

Target branch: `codex/ai-commander-logs`.

Positive evidence:

```text
AI_Commander_Log: [WEST] #... STATE
AI_Commander_Log: [WEST] #... TOWN_ASSIGN
AI_Commander_Log: [WEST] #... PRODUCTION
AI_Commander_Log: [WEST] #... UPGRADE
AI_Commander_Log: [WEST] #... ORDER
```

Checks:

- sequence numbers increase per side
- logs are stored on side logic
- log arrays remain bounded after a long run
- logging failure does not stop execution
- no AI decisions change compared with Phase 0 baseline
- hybrid mode produces `ORDER` and delegated `TOWN_ASSIGN`, but no `PRODUCTION` or `UPGRADE` while human commands

## Phase 2: Context/Beliefs Evidence

Target branch: `codex/ai-commander-context`.

Use the manual synthetic smoke helper if natural contacts are hard to force:

```sqf
west Call WFBE_SE_FNC_AI_Com_ContextSyntheticSmoke;
```

Positive evidence:

```text
AI_Commander_ContextSyntheticSmoke: [WEST] appended CONTACT/INTEL/LOSS synthetic records
AI_Commander_Log: [WEST] #... CONTACT
AI_Commander_Log: [WEST] #... INTEL
AI_Commander_Log: [WEST] #... LOSS
AI_Commander_Context: [WEST] ... tracked beliefs, top=active/armor near ... conf=...
```

Checks:

- one `CONTACT` creates one belief
- nearby second report merges and raises confidence
- far report creates separate belief, if manually appended beyond merge radius
- rumor-only `INTEL` remains low confidence
- `LOSS` creates or reinforces moderate-confidence threat
- nearest town attaches correctly
- confidence remains 0.0-1.0
- stale beliefs stop appearing in tracked summaries
- no orders, production, or upgrades change from Phase 2 alone
- synthetic smoke helper does not run automatically

## Phase 3: Advisory Planner Evidence

Target branch: `codex/ai-commander-planner`.

Do not open this branch for ready review until Phase 2 has positive context evidence.

Positive evidence:

```text
AI_Commander_Plan: [WEST] top DEFEND_TOWN Gorka score=0.86 reason=enemy armor near friendly town belief=contact-gorka-001
AI_Commander_Plan: [WEST] selected 4 priorities: defend=1 scout=1 attack=1 support=1
```

Checks:

- high-confidence threat near friendly town creates `DEFEND_TOWN`
- medium-confidence unknown creates `SCOUT_CONTACT`
- credible enemy-town contact creates `ATTACK_CONTACT`
- armor creates `CONTAIN_ARMOR`
- air creates `WATCH_AIR`
- stale/expired beliefs do not create actionable priorities
- priorities are capped per town and per belief
- advisory mode defaults true
- no waypoint, production, upgrade, or template behavior changes while advisory mode is true

## Phase 4: Worker Biasing Evidence

Target branch: `codex/ai-commander-worker-biasing`.

Run both advisory-on and advisory-off tests.

Advisory-on checks:

- priorities exist
- workers fall back to current behavior
- no priority-driven team assignments occur

Advisory-off checks:

```text
AI_Commander_AssignTowns: [WEST] team [B 1-2] defending Gorka from priority DEFEND_TOWN score=0.86 reason=enemy armor near friendly town
AI_Commander_AssignTypes: [WEST] team [B 1-3] picked template 4 from CONTAIN_ARMOR priority belief=contact-gorka-001
```

Checks:

- `DEFEND_TOWN` assigns at most one eligible/delegated team at first
- `SCOUT_CONTACT` assigns at most one eligible/delegated team
- `ATTACK_CONTACT` biases target selection without dogpiling all teams
- explicit human Move/Patrol/Defense orders are not overwritten
- non-delegated teams under human commander are untouched
- AI economy remains frozen while human commands
- expired/malformed priorities fall back to current behavior
- production queue/funds/factory/cap checks remain intact
- upgrade behavior is logged as advisory unless separately enabled

## Minimal RPT Report Template

Use this shape for runtime handoff comments:

```text
Branch:
Commit:
Mission/map:
Mode: full-auto | hybrid-assist | handoff | stopped
Side(s): WEST/EAST
Runtime duration:
RPT path:

Phase gates:
- Phase 0 execution: PASS/FAIL/UNCERTAIN
- Phase 1 logs: PASS/FAIL/UNCERTAIN
- Phase 2 beliefs: PASS/FAIL/UNCERTAIN
- Phase 3 planner: PASS/FAIL/UNCERTAIN
- Phase 4 worker biasing: PASS/FAIL/UNCERTAIN

Evidence excerpts:
1. ...
2. ...
3. ...

Failures / uncertainty:
- ...

Screenshots / coordinates if relevant:
- ...
```

## Stop-Go Rules

Stop and fix before proceeding when:

- any phase changes behavior before its activation gate
- human explicit orders are overwritten
- AI spends economy under human command
- logs or beliefs grow unbounded
- stale priorities keep driving behavior
- RPT shows undefined variables, nil-code calls, or repeated waypoint reset loops
- synthetic smoke helpers run automatically in normal gameplay

Proceed to the next phase only when the current phase has positive evidence and the previous phase still passes its regression checks.

## Release Readiness

Quad AI Commander is not release-ready until:

- execution substrate has full-auto/hybrid/handoff/stopped evidence
- structured logs are bounded and positive events are visible
- beliefs merge, decay, expire, and attach towns correctly
- planner priorities are explainable and bounded in advisory mode
- worker biasing preserves human/delegation/economy boundaries
- both sides have at least one successful runtime pass or a documented reason for single-side-only coverage
