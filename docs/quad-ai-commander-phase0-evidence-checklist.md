# Quad AI Commander Phase 0 Evidence Checklist

Use this checklist when testing PR #14 / `feat/ai-commander` before moving the stack to Phase 1 logs.

This is intentionally tester-facing. Fill it from the server RPT and any manual observations needed to prove command-bar, delegation, economy, handoff, and stopped behavior.

## Test Header

```text
Branch: feat/ai-commander
Commit:
Mission/map:
Side(s): WEST / EAST
Mode(s): full-auto / hybrid-assist / handoff / stopped
Runtime duration:
RPT path:
Tester:
Decision for Phase 1: YES / NO
```

## 1. Full-Auto Baseline

Setup:

- AI Commander enabled.
- No human commander for the tested side.
- HQ alive.

Required evidence:

```text
AI_Commander.sqf: [WEST] AI commander ACTIVE (full command).
AI_Commander_AssignTypes.sqf: [WEST]
AI_Commander_AssignTowns.sqf: [WEST] team
AI_Commander_Produce.sqf: [WEST] team
Server_AI_Com_Upgrade
```

Pass when:

- Full state appears once per transition, not every tick.
- At least one AI team receives a useful assignment.
- Production or upgrade appears when funds/factory/upgrades allow, or the report explains why it could not be forced.
- No AI Commander RPT errors appear.

## 2. Hybrid Command-Bar Execution

Setup:

- Human commander present for the tested side.
- At least one AI-led team exists.
- Issue one Move, one Patrol, and one Defense order through the command UI.

Required evidence:

```text
AI_Commander.sqf: [WEST] AI commander ASSIST (hybrid
AI_Commander_Execute.sqf: [WEST] team [...] executing move order
AI_Commander_Execute.sqf: [WEST] team [...] executing patrol order
AI_Commander_Execute.sqf: [WEST] team [...] executing defense order
```

Manual observation to record:

```text
Move waypoint visible/movement observed: YES / NO
Patrol waypoint visible/movement observed: YES / NO
Defense waypoint visible/movement observed: YES / NO
```

Blocks Phase 1 if:

- Any command-bar mode stores variables but creates no real waypoint.
- `wfbe_exec_sig` prevents a changed order from re-executing.
- RPT shows nil-code or undefined-variable errors from `AI_Commander_Execute.sqf`.

## 3. Delegation Boundary

Setup:

- Human commander present.
- Pick two AI-led teams.
- Team A: enable Command Center Auto AI / `wfbe_autonomous`.
- Team B: leave non-delegated.

Required evidence:

```text
AI_Commander.sqf: [WEST] AI commander ASSIST (hybrid
AI_Commander_AssignTowns.sqf: [WEST] team [Team A] heading to attack town
```

Manual observation to record:

```text
Delegated Team A auto-driven: YES / NO
Non-delegated Team B overwritten by auto-town assignment: YES / NO
Explicit Team B human order preserved: YES / NO
```

Blocks Phase 1 if:

- Non-delegated teams are auto-assigned under a human commander.
- Explicit human Move/Patrol/Defense orders are overwritten by auto-town assignment.

## 4. Economy Freeze Under Human Commander

Setup:

- Human commander present.
- Stay in hybrid-assist for long enough to cover at least one production and upgrade interval.

Search after the ASSIST anchor and before any handoff back to full-auto.

Suspicious anchors:

```text
AI_Commander_Produce.sqf: [WEST] team
AI commander tech upgrade
Server_AI_Com_Upgrade
```

Pass when:

- No AI production order appears while the human remains commander.
- No AI commander tech upgrade spending appears while the human remains commander.
- Any production/upgrade anchor is clearly after handoff back to full-auto.

Blocks Phase 1 if:

- AI spends funds or supply while a human commander owns the side.

## 5. Human-Leaves Handoff

Setup:

- Start in hybrid-assist.
- Issue at least one explicit command-bar order.
- Delegate at least one AI-led team.
- Have the human commander leave, disconnect, or lose commander role.

Required evidence:

```text
AI_Commander.sqf: [WEST] AI commander ASSIST (hybrid
AI_Commander.sqf: [WEST] AI commander ACTIVE (full command).
AI_Commander_AssignTowns.sqf: [WEST] team
```

Manual observation to record:

```text
Full-auto resumed after human left: YES / NO
Teams continued receiving sensible assignments: YES / NO
Player-led/non-AI groups were not broken by reset: YES / NO / N/A
```

Blocks Phase 1 if:

- The side remains stuck in assist after the human leaves.
- Full-auto resumes but workers stop issuing useful assignments.
- Handoff causes repeated RPT errors or waypoint reset loops.

## 6. Stopped / HQ-Down / Disabled State

Setup options:

- Disable AI Commander with the lobby parameter, or
- destroy/kill the side HQ, or
- otherwise trigger the branch's stopped condition.

Required evidence:

```text
AI_Commander.sqf: [WEST] AI commander STOPPED (disabled / HQ down).
```

Search after the stopped anchor.

Suspicious anchors:

```text
AI_Commander_AssignTowns.sqf: [WEST]
AI_Commander_Produce.sqf: [WEST]
AI commander tech upgrade
```

Pass when:

- Stopped logs once per transition, not every tick.
- No worker actions continue for that stopped side.
- Reactivation, if tested, occurs only through intended game conditions.

Blocks Phase 1 if:

- Commander workers continue after stopped.
- Stopped state spams RPT every tick/interval.

## 7. Error Sweep

Search the full RPT for:

```text
Error Undefined variable
Error Generic error
Error Missing ;
Error position:
Type Array, expected
Type Object, expected
Type Group, expected
AI_Commander
AI_Commander_Execute
AI_Commander_AssignTowns
AI_Commander_Produce
Server_AI_Com_Upgrade
wfbe_queue
wfbe_exec_sig
```

Record every hit near an AI Commander anchor.

## Final Decision

```text
Full-auto: PASS / FAIL / UNCERTAIN
Hybrid command-bar: PASS / FAIL / UNCERTAIN
Delegation boundary: PASS / FAIL / UNCERTAIN
Economy freeze: PASS / FAIL / UNCERTAIN
Handoff: PASS / FAIL / UNCERTAIN
Stopped: PASS / FAIL / UNCERTAIN
Error sweep: PASS / FAIL / UNCERTAIN

Ready for #18 / codex/ai-commander-logs runtime smoke: YES / NO
```

Use `NO` if any required gate is `FAIL` or `UNCERTAIN`, unless the uncertainty is explicitly accepted in the PR with a reason.
