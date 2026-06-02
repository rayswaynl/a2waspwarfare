# Factory Queue Counter Token Cleanup

Status: patch-ready playbook. Current source still has the DR-33a empty-vehicle counter leak and the DR-33b low-entropy FIFO token. Vanilla propagation, public `queu` broadcast reduction and Arma smoke are all pending.

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

Two parts are fragile:

- `Client_BuildUnit.sqf:167-168` uses `_unique = varQueu; varQueu = random(10)+random(100)+random(1000);`, a low-entropy numeric token shared by concurrent buyers.
- `Client_BuildUnit.sqf:365` can hit `if (!_driver && !_gunner && !_commander) exitWith {};` after the FIFO token is removed but before the normal tail decrement. Repeated crewless vehicle buys can leak the buyer's local `WFBE_C_QUEUE_<type>` counter and soft-lock that category.
- Wave R added an extra-crew nuance: `_extracrew` is parsed earlier from the vehicle crew options, but the empty-vehicle `exitWith` checks only driver/gunner/commander. If a config/UI path can expose extra-turret-crew-only purchases, that branch exits before the extra crew creation block and before queue cleanup.

The source line check on 2026-06-02 still shows both issues in source Chernarus. Do not treat this lane as patched until `Client_BuildUnit.sqf` changes and LoadoutManager propagation are both verified.

## Suggested Patch Shape

Keep this patch local and narrow:

1. Replace the low-entropy token with a monotonically increasing or otherwise per-client unique token.
2. Add the same local cleanup used by the normal tail before the empty-vehicle `exitWith`.
3. Decide whether extra-turret-crew-only purchases are valid. If they are valid, the empty-vehicle condition must include `_extracrew` so turret crew can still be created; if they are not valid, block that UI/config combination explicitly.
4. Leave public `setVariable ["queu", _queu, true]` behavior alone in the first patch.

Example cleanup shape for the empty-vehicle exit:

```sqf
if (!_driver && !_gunner && !_commander) exitWith {
    unitQueu = unitQueu - _cpt;
    missionNamespace setVariable [Format["WFBE_C_QUEUE_%1", _factory], (missionNamespace getVariable Format["WFBE_C_QUEUE_%1", _factory]) - 1];
};
```

Use exact local style after inspecting the surrounding code. Do not introduce a server-authority migration in the same patch.

If extra-turret-crew-only buys are intentionally supported, use the same cleanup idea but do not exit just because driver/gunner/commander are false; let the later extra-crew block run.

## Why It Matters

This is a player-facing correctness fix with a small performance side benefit. A player can repeatedly buy crewless light/heavy/air vehicles and eventually hit the local queue cap even though nothing is queued. The token change removes a low-probability front-of-queue collision class without redesigning the factory producer.

This is not public-server hardening. Player purchases are still client-local and funds are still deducted client-side. Use [Server authority migration map](Server-Authority-Migration-Map) and [Economy authority first cut](Economy-Authority-First-Cut) before treating buy/build flows as hardened.

## Remaining Opportunity

`Client_BuildUnit.sqf` still broadcasts the whole building `queu` array with `setVariable ["queu", _queu, true]` on enqueue, timeout cleanup and completion. That broadcast is still visible to the buy menu and queue hint behavior, so reducing it should be a separate UI-aware performance patch, not a silent removal.

## Validation Needed

Source-only:

- Source Chernarus no longer uses `random(10)+random(100)+random(1000)` in `Client_BuildUnit.sqf`.
- Source Chernarus decrements `unitQueu` and `WFBE_C_QUEUE_<type>` before the crewless-vehicle exit.
- Extra-turret-crew-only selection, if any valid UI/config exposes it, either produces turret crew or is explicitly rejected without leaking queue counters.
- Vanilla Takistan propagation is produced by LoadoutManager from a correctly named `a2waspwarfare` checkout.
- `git diff --check` remains clean.

Arma smoke:

- Buy repeated crewless light/heavy vehicles and verify the queue cap does not soft-lock.
- Buy crewed vehicles and infantry after crewless vehicles to verify normal production still decrements.
- Queue multiple buyers at the same factory and verify FIFO order and queue hints still behave.
- Destroy the factory mid-build and verify the existing factory-dead cleanup still decrements.
- Test JIP/client reconnect behavior around a queued purchase if possible.

## Handoff

Future owner: patch the local queue accounting/token identity first, then decide whether the public `queu` broadcast should be reduced, converted to local UI state, or moved into a broader server-owned purchase queue redesign.

## Continue Reading

Previous: [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas) | Next: [Performance opportunity sweep](Performance-Opportunity-Sweep)

Main map: [Home](Home) | Fast path: [Feature status](Feature-Status-Register) | Agent file: [`agent-context.json`](agent-context.json)
