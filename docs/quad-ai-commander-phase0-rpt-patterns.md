# Quad AI Commander Phase 0 RPT Patterns

Use this checklist when smoke-testing PR #14 (`feat/ai-commander`). It complements `docs/quad-ai-commander-phase0-smoke-brief.md` with concrete strings to search for in the RPT.

The exact RPT text may vary slightly. Treat these as expected anchors, not strict machine regexes.

## Positive Anchors

### Full-Auto

```text
AI_Commander.sqf: [WEST] AI commander ACTIVE (full command).
AI_Commander.sqf: [EAST] AI commander ACTIVE (full command).
AI_Commander_AssignTypes.sqf: [WEST] assigned template
AI_Commander_AssignTowns.sqf: [WEST] team
AI_Commander_Produce.sqf: [WEST] team
```

Evidence meaning:

- supervisor entered full command
- team type assignment ran
- town assignment ran
- production attempted when conditions allowed

### Hybrid Assist

```text
AI_Commander.sqf: [WEST] AI commander ASSIST (hybrid
AI_Commander_Execute.sqf: [WEST] team
executing move order
executing patrol order
executing defense order
```

Evidence meaning:

- supervisor entered assist mode
- human command-bar orders were converted into waypoints

### Handoff

```text
AI_Commander.sqf: [WEST] AI commander ASSIST (hybrid
AI_Commander.sqf: [WEST] AI commander ACTIVE (full command).
AI_Commander_AssignTowns.sqf: [WEST] team
```

Evidence meaning:

- side was in hybrid mode
- human commander left or lost command
- full-auto resumed and assigned teams again

### Stopped

```text
AI_Commander.sqf: [WEST] AI commander STOPPED (disabled / HQ down).
AI_Commander.sqf: [EAST] AI commander STOPPED (disabled / HQ down).
```

Evidence meaning:

- disabled parameter or HQ-down state stopped the supervisor

## Negative Anchors

Search for these and treat hits as suspicious until explained.

```text
Error Undefined variable in expression
Error Generic error in expression
Error Zero divisor
Error Missing ;
Error position:
Undefined variable: _cost
Undefined variable: _logik
Undefined variable: _team
Type Array, expected
Type Object, expected
Type Group, expected
```

AI Commander-specific suspicious anchors:

```text
AI_Commander
AI_Commander_Execute
AI_Commander_AssignTowns
AI_Commander_Produce
Server_AI_Com_Upgrade
AIBuyUnit
wfbe_queue
wfbe_exec_sig
```

When one of the generic errors appears near an AI Commander-specific anchor, include that excerpt in the smoke report.

## Economy Freeze Check

In hybrid mode, after assist starts, there should be no AI production or upgrade spending for that side while the human remains commander.

Suspicious if these appear after assist starts and before handoff:

```text
AI_Commander_Produce.sqf: [WEST]
AI_Commander_Produce.sqf: [EAST]
AI commander tech upgrade
Server_AI_Com_Upgrade
```

If they appear, note whether the human commander had already left. If not, this blocks Phase 1.

## Delegation Boundary Check

For delegated teams, `AssignTowns` may run in hybrid mode.

For non-delegated teams, `AssignTowns` should not overwrite explicit human control.

Useful evidence shape:

```text
team <name/id> delegated=true -> AssignTowns entry appears
team <name/id> delegated=false -> no auto-town overwrite observed
```

If team identifiers are unclear from RPT alone, include screenshots or manual notes with team names.

## Waypoint Reset Watch

Repeated town retargeting may look like the same team being assigned repeatedly before reaching the town approach band.

Suspicious pattern:

```text
AI_Commander_AssignTowns.sqf: [WEST] team [B 1-2] heading to attack town [Gorka]
AI_Commander_AssignTowns.sqf: [WEST] team [B 1-2] heading to attack town [Gorka]
AI_Commander_AssignTowns.sqf: [WEST] team [B 1-2] heading to attack town [Gorka]
```

This is a blocker only if it prevents progress or appears every town interval for the same team/target.

## Queue Watch

Production should not permanently leave a team stuck with a non-empty `wfbe_queue`.

Useful evidence:

```text
AI_Commander_Produce.sqf: [WEST] team [...] ordering [...]
Server_BuyUnit.sqf: [WEST] Team [...] has purchased [...]
```

Suspicious symptoms:

- team orders one unit and never produces again despite funds/factory availability
- RPT errors around `wfbe_queue`
- factory destruction/cancel path leaves repeated no-op production attempts

## Minimal Grep Set

Search the RPT for:

```text
AI_Commander.sqf:
AI_Commander_Execute.sqf:
AI_Commander_AssignTowns.sqf:
AI_Commander_AssignTypes.sqf:
AI_Commander_Produce.sqf:
Server_AI_Com_Upgrade
AI commander tech upgrade
Error Undefined variable
Error Generic error
wfbe_queue
wfbe_exec_sig
```

## Report Output

Paste the relevant excerpts under the Phase 0 report template and end with:

```text
Ready for feat/ai-commander-logs: YES/NO
```

Use `NO` if any hard-stop failure appears or if hybrid/handoff/stopped evidence is still missing.
