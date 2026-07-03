# Design: clear stale AICOM rallying flags

Lane: 219 - Rallying flag never cleared after team recovers.

Status: design-only source PR. The runtime fix should stack on the active AICOM
Strategy/Produce owners because both runtime files are high-traffic in the
current PR board.

## Problem

The graceful withdrawal evaluator marks an HC team as rallying when it sends a
fresh rally order:

- `AI_Commander_Strategy.sqf:621-623` gates the evaluator behind
  `WFBE_C_AICOM_WITHDRAW_EVAL` and reads `WFBE_C_AICOM_WITHDRAW_MIN_ALIVE`.
- `AI_Commander_Strategy.sqf:633-636` reads `wfbe_aicom_wantrally` and
  `wfbe_aicom_rallying`.
- `AI_Commander_Strategy.sqf:649-650` only triggers a low-alive withdrawal when
  the team is not already rallying.
- `AI_Commander_Strategy.sqf:671-673` publishes the rally order, clears
  `wfbe_aicom_wantrally`, and sets `wfbe_aicom_rallying` to `true`.

The flag is later used by the top-up dispatcher:

- `AI_Commander_Produce.sqf:133-137` reads `wfbe_aicom_rallying` into
  `_wm_rally`.
- `AI_Commander_Produce.sqf:148` permits the top-up request when the team is
  rallying or parked.
- `AI_Commander_Produce.sqf:184-185` sends `wfbe_aicom_topup_req` to the HC
  driver with the rally position and class pool.
- `AI_Commander_Produce.sqf:197` logs the `TOPUP_REQ`.

No current path clears `wfbe_aicom_rallying` after the team recovers. A team that
has rallied once can remain permanently marked as rallying, which suppresses
later low-alive withdrawal triggers and keeps Produce treating the team as a
rally/top-up candidate long after it should have returned to normal offense.

## Desired Behavior

`wfbe_aicom_rallying` should mean "this team is currently in a recovery/rally
phase", not "this team once rallied". Clear it when the recovery phase has
ended.

Two clear points are enough:

1. Strategy recovery clear: when the team is no longer under the minimum alive
   threshold and is not explicitly requesting a new rally.
2. Produce top-up clear: after a successful top-up request is issued for a
   rallying team, once the team has a path to refill.

## Minimal Patch Shape

### Strategy clear point

Inside the graceful withdrawal per-team pass, after `_gwAlive`, `_gwWant`,
`_gwRallying`, and `_gwExempt` are known, add a narrow recovery clear before the
trigger decision:

```sqf
if (_gwRallying && {!_gwWant} && {_gwAlive >= _gwMinAlive} && {!_gwExempt}) then {
	_gwTeam setVariable ["wfbe_aicom_rallying", false, true];
	_gwRallying = false;
	["INFORMATION", Format ["AI_Commander_Strategy.sqf: [%1] team [%2] RALLY-CLEAR (alive=%3 >= min=%4).", _sideText, _gwTeam, _gwAlive, _gwMinAlive]] Call WFBE_CO_FNC_AICOMLog;
	diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|RALLY_CLEAR|team=" + (str _gwTeam) + "|alive=" + str _gwAlive);
};
```

Why here:

- the evaluator already has `_gwAlive`, `_gwWant`, `_gwRallying`, `_gwExempt`,
  `_sideText`, and `_gwTeam` in scope;
- clearing before `_gwTrigger` lets the existing understrength trigger re-arm on
  a later bleed-out;
- the broadcast preserves the HC-side view of the group variable.

### Produce clear point

After Produce successfully charges and writes a top-up request for a rallying
team, clear the rallying flag:

```sqf
if (_wm_rally) then {
	_team setVariable ["wfbe_aicom_rallying", false, true];
};
```

Place it immediately after the successful
`_team setVariable ["wfbe_aicom_topup_req", ...]` write. Keep the existing
`wfbe_aicom_topup_stamp`, charge, and log behavior unchanged.

Why here:

- the team has already been accepted for recovery support;
- the clear does not fire for parked-but-not-rallying teams;
- if the top-up is skipped for cost, cooldown, roster, combat, or disbanding
  reasons, the rallying state remains available for a later recovery pass.

## A2-OA Safety Notes

- Use plain group `getVariable` plus `isNil`, matching the current evaluator and
  Produce idioms.
- Do not use `params`, `pushBack`, `selectRandom`, `isEqualTo`, `remoteExec`, or
  other A3-only helpers.
- Do not use group `[name, default]` getVariable forms in new code.
- Keep all strings ASCII and use the existing `AICOMSTAT|v2|EVENT` format.

## Validation Plan

Static validation for the later runtime PR:

- focused SQF lint on all maintained `AI_Commander_Strategy.sqf` and
  `AI_Commander_Produce.sqf` mirrors;
- `git diff --check`;
- bracket-delta check per touched SQF file;
- added-line scans for A3-only commands, Boolean `==/!=`, and group
  `[name, default]` getVariable usage;
- LoadoutManager mirror run if the implementation touches maintained Chernarus
  source first.

Runtime smoke:

- Force an HC team below `WFBE_C_AICOM_WITHDRAW_MIN_ALIVE` and confirm Strategy
  sets `wfbe_aicom_rallying=true` and emits `RALLY_ORDER`.
- Let the team recover to at least the minimum alive count without
  `wfbe_aicom_wantrally=true`; confirm Strategy clears the flag and emits
  `RALLY_CLEAR`.
- Force a top-up request for a rallying team; confirm Produce writes
  `wfbe_aicom_topup_req` and clears `wfbe_aicom_rallying`.
- Bleed the same team down again later and confirm the evaluator can trigger a
  second `RALLY_ORDER`.

Expected RPT evidence:

```text
AICOMSTAT|v2|EVENT|<side>|<minute>|RALLY_ORDER|team=<group>|alive=<N>|want=<bool>
AICOMSTAT|v2|EVENT|<side>|<minute>|RALLY_CLEAR|team=<group>|alive=<N>
```

## Risk

Risk is limited to HC team recovery state. Clearing too early could allow a team
to re-enter withdrawal sooner, but the clear points require either recovered
alive count or successful top-up dispatch. Revert by removing the two clear
sites and the `RALLY_CLEAR` telemetry.

## Out of Scope

- No runtime edit in this PR.
- No changes to withdrawal thresholds, rally destination choice, top-up costs,
  top-up TTL, or HC driver execution.
- No package artifact, deploy, or live runtime action.
