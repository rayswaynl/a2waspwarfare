# Factory Queue Counter Token Cleanup

Status: patch-ready/current-source-unpatched for the narrow DR-33 queue-counter/token cleanup; source/Vanilla patching, Arma smoke and public `queu` broadcast review remain pending.

## What To Read

- `Client/GUI/GUI_Menu_BuyUnits.sqf`
- `Client/Functions/Client_BuildUnit.sqf`
- `Client/Init/Init_Client.sqf`
- `Common/Init/Init_Common.sqf`
- [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas)
- [Deep-review findings](Deep-Review-Findings) Round 24 / DR-33
- [Feature status register](Feature-Status-Register)
- [Performance opportunity sweep](Performance-Opportunity-Sweep)

## Current Behavior

The buy menu increments `WFBE_C_QUEUE_<type>` before spawning `BuildUnit`. `Client_BuildUnit.sqf` adds the purchase to the building FIFO stored in public variable `queu`, waits for the token to reach the front, removes that token, builds the unit/vehicle, then decrements `unitQueu` and `WFBE_C_QUEUE_<type>` at the normal tail.

Current source Chernarus and generated Vanilla Takistan still need the two narrow DR-33 fixes:

- `Client_BuildUnit.sqf:167-168` still sets `_unique = varQueu`, then randomizes `varQueu`.
- The empty crewless-vehicle branch still exits before the normal `unitQueu` / `WFBE_C_QUEUE_<type>` decrement.

The separate performance opportunity also remains: `Client_BuildUnit.sqf` publishes building `queu` changes with `_building setVariable ["queu", _queu, true]`. That broadcast-reduction work should stay a separate UI-aware performance patch.

## Source State

| Item | Current source/Vanilla state | Remaining gate |
| --- | --- | --- |
| Local queue cap leak | Current source/Vanilla still exit before the normal queue decrement in the crewless-vehicle branch. | Patch source/Vanilla, then smoke repeated crewless buys, normal crewed/infantry buys and factory-dead cleanup. |
| FIFO token identity | Current source/Vanilla still use the old randomized `varQueu` token shape. | Patch to a monotonic player-scoped token, then smoke concurrent buyers and queue hints. |
| Public `queu` broadcast churn | Still present on enqueue/advance/completion. | Review UI consumers before reducing or redesigning publication. |
| Generated Vanilla/modded targets | Vanilla Takistan mirrors the unpatched source shape; modded targets are not maintained by this patch lane. | Patch source, propagate Vanilla, and treat modded drift as a separate owner decision. |

## Patch Shape

Narrow maintained-target patch shape still to apply in source/Vanilla:

1. Replace the old random-only FIFO token with a per-client monotonic token.
2. Add the same local cleanup used by the normal tail before the empty-vehicle `exitWith`.
3. Leave public `setVariable ["queu", _queu, true]` behavior alone until UI consumers are reviewed.

Possible cleanup shape in the empty-vehicle exit:

```sqf
if (!_driver && !_gunner && !_commander) exitWith {
    unitQueu = unitQueu - _cpt;
    missionNamespace setVariable [Format["WFBE_C_QUEUE_%1", _factory], (missionNamespace getVariable Format["WFBE_C_QUEUE_%1", _factory]) - 1];
};
```

Do not treat this as a server-authority migration. Player purchases are still client-local and remain part of the broader economy authority class.

## Validation Needed

Source-only:

- After patching, source Chernarus and generated Vanilla use the monotonic player-scoped `varQueu` token in `Client_BuildUnit.sqf`.
- After patching, source Chernarus and generated Vanilla decrement the local factory queue counter before the crewless-vehicle exit.
- `git diff --check` remains clean.

Arma smoke:

- Buy repeated crewless light/heavy vehicles and verify the queue cap does not soft-lock.
- Buy crewed vehicles and infantry after crewless vehicles to verify normal production still decrements.
- Queue multiple buyers at the same factory and verify FIFO order and queue hints still behave.
- Destroy the factory mid-build and verify the existing factory-dead cleanup still decrements.
- Test JIP/client reconnect behavior around a queued purchase if possible.

## Handoff

Future owner: run Arma smoke for the local counter and token fix. Decide separately whether the public `queu` broadcast should be reduced, converted to local UI state, or moved into a broader server-owned purchase queue redesign.

## Continue Reading

Previous: [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas) | Next: [Performance opportunity sweep](Performance-Opportunity-Sweep)

Main map: [Home](Home) | Fast path: [Feature status](Feature-Status-Register) | Agent file: [`agent-context.json`](agent-context.json)
