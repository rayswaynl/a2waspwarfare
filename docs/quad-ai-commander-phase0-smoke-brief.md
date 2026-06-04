# Quad AI Commander Phase 0 Smoke Brief

Phase 0 is the current `feat/ai-commander` execution substrate. It must be proven before starting `feat/ai-commander-logs`.

Target PR:

```text
#14 AI Commander + hybrid co-op command
```

Target branch:

```text
feat/ai-commander
```

## Objective

Prove the current AI Commander branch is a stable execution substrate:

- full-auto command works when no human commander exists
- hybrid-assist works when a human commander exists
- human command-bar Move/Patrol/Defense orders become real waypoints
- delegated teams can be automated without overwriting non-delegated teams
- AI economy does not spend while a human commander is present
- handoff and stopped states behave cleanly

## Required Runtime Modes

Run these four modes if possible:

```text
full-auto
hybrid-assist
handoff
stopped
```

Both WEST and EAST are ideal. One side is acceptable for first smoke if the RPT clearly states the tested side.

## Evidence To Capture

For every run, capture:

```text
Branch:
Commit:
Mission/map:
Side:
Mode:
Runtime duration:
RPT path:
Tester:
```

Include RPT excerpts for every PASS/FAIL/UNCERTAIN gate.

## Mode 1: Full-Auto

Setup:

- AI Commander enabled in lobby.
- No human commander for the tested side.
- Side HQ alive.

Expected behavior:

- supervisor logs active/full command
- AI teams receive template assignments
- AI teams receive town assignments
- at least one town waypoint/path is created
- production attempts happen when funds/factory/upgrades allow
- upgrade starts when affordable

Evidence examples:

```text
AI_Commander.sqf: [WEST] AI commander ACTIVE (full command).
AI_Commander_AssignTypes.sqf: [WEST] assigned template ...
AI_Commander_AssignTowns.sqf: [WEST] team [...] heading to attack town [...]
AI_Commander_Produce.sqf: [WEST] team [...] ordering [...] at ... factory
```

Pass criteria:

- full state enters once per transition, not every tick
- teams get useful orders
- no nil-code or undefined-variable RPT errors
- production queue does not permanently stick after a successful build/cancel path

## Mode 2: Hybrid-Assist

Setup:

- Human commander present.
- At least one AI-led team available.
- Test both delegated and non-delegated teams if possible.

Expected behavior:

- supervisor logs assist/hybrid state
- explicit human Move order creates real waypoint
- explicit human Patrol order creates real waypoint
- explicit human Defense order creates real waypoint
- delegated team can receive auto-town assignment
- non-delegated AI team is not overwritten by auto-town assignment
- AI production and upgrades do not run while human commands

Evidence examples:

```text
AI_Commander.sqf: [WEST] AI commander ASSIST (hybrid ...)
AI_Commander_Execute.sqf: [WEST] team [...] executing move order at [...]
AI_Commander_Execute.sqf: [WEST] team [...] executing patrol order at [...]
AI_Commander_Execute.sqf: [WEST] team [...] executing defense order at [...]
```

Pass criteria:

- command-bar orders visibly move/create waypoints for AI-led teams
- delegated-only automation boundary is preserved
- no `AI_Commander_Produce` or upgrade spending occurs under human command

## Mode 3: Handoff

Setup:

- Start with human commander present.
- Issue at least one explicit order.
- Toggle delegation for at least one AI-led team.
- Human commander leaves/disconnects/loses commander role.

Expected behavior:

- supervisor transitions from assist to full
- full-auto retakes side cleanly
- AI does not stall after handoff
- stale explicit orders do not prevent full-auto town flow

Evidence examples:

```text
AI_Commander.sqf: [WEST] AI commander ASSIST ...
AI_Commander.sqf: [WEST] AI commander ACTIVE (full command).
AI_Commander_AssignTowns.sqf: [WEST] team [...] heading to attack town [...]
```

Pass criteria:

- retake occurs without nil-code errors
- teams resume sensible town/production/upgrade behavior
- handoff reset does not break player-led groups

## Mode 4: Stopped

Setup options:

- disable AI Commander lobby parameter, or
- destroy/kill side HQ, or
- otherwise trigger inactive state.

Expected behavior:

- supervisor logs stopped state
- running flag is false
- no further auto-town, production, or upgrade behavior runs for that side

Evidence example:

```text
AI_Commander.sqf: [WEST] AI commander STOPPED (disabled / HQ down).
```

Pass criteria:

- stopped state logs once per transition
- no repeated noisy stop logs
- commander work remains stopped until reactivated by intended game conditions

## Watchlist

These are not automatic failures unless repeated or behavior-breaking, but they must be noted:

- town retargeting every interval before teams reach the 1500m band
- `wfbe_exec_sig` preventing waypoint restoration after external waypoint clears
- side AI cap preventing useful team production too early
- factory destroyed/cancel path leaving `wfbe_queue` stuck
- human-leaves reset wiping too much useful state

## Hard Stop Failures

Stop and fix before Phase 1 if any appear:

- human explicit orders are overwritten in hybrid mode
- non-delegated teams are auto-driven under human command
- AI spends funds or supply while human commands
- nil-code or undefined-variable RPT errors from AI Commander files
- repeated waypoint reset loops prevent teams from reaching towns
- production queue permanently blocks a team
- stopped state keeps running commander workers

## Phase 0 Report Template

```text
Branch:
Commit:
Mission/map:
Side(s):
Runtime duration:
RPT path:
Tester:

Full-auto: PASS/FAIL/UNCERTAIN
Evidence:
- ...

Hybrid-assist: PASS/FAIL/UNCERTAIN
Evidence:
- ...

Handoff: PASS/FAIL/UNCERTAIN
Evidence:
- ...

Stopped: PASS/FAIL/UNCERTAIN
Evidence:
- ...

Watchlist notes:
- ...

Blocking failures:
- ...

Decision:
- Ready for `feat/ai-commander-logs`: YES/NO
```

## Exit Criteria

Phase 0 is complete when full-auto, hybrid-assist, handoff, and stopped behavior have positive runtime evidence or a clearly documented reason for any deferred gate. Phase 1 should not start until blockers are fixed or explicitly accepted.
