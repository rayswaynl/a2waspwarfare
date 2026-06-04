# Quad AI Commander Phase 1 Implementation Brief

This is the kickoff brief for the first implementation branch after the current AI Commander execution substrate stabilizes.

Target branch name:

```text
feat/ai-commander-logs
```

Base branch:

```text
feat/ai-commander
```

Primary spec:

```text
docs/quad-ai-commander-phase1-logs.md
```

Validation spec:

```text
docs/quad-ai-commander-runtime-validation.md
```

## Objective

Add structured commander logging for existing AI Commander behavior without changing decisions.

Phase 1 is complete when existing supervisor, executor, town assignment, production, and upgrade actions are recorded as bounded structured logs on the side logic, with RPT evidence proving that behavior remains unchanged.

## Files To Add

```text
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_LogAppend.sqf
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_LogDrain.sqf
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_LogPrune.sqf
```

Takistan/variant propagation should wait until the Chernarus source is stable, unless the repo workflow requires immediate generated parity.

## Files To Edit

```text
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_Server.sqf
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander.sqf
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Execute.sqf
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_AssignTowns.sqf
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Produce.sqf
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_AI_Com_Upgrade.sqf
```

Only add log emission. Do not change order selection, production decisions, upgrade choice, delegation checks, or economy rules.

## Helper Contracts

### AI_Commander_LogAppend.sqf

Input:

```sqf
// [_side, _kind, _source, _payload]
```

Required behavior:

- resolve side logic
- initialize `wfbe_aicom_logs`, `wfbe_aicom_log_seq`, `wfbe_aicom_log_last_prune` if missing
- increment `wfbe_aicom_log_seq`
- append `[seq, kind, time, side, source, payload]`
- cap logs at 200 records
- return the record if successful
- fail soft if side logic is missing or input is malformed

### AI_Commander_LogDrain.sqf

Input:

```sqf
// [_side, _afterSeq]
```

Required behavior:

- return records with `seq > _afterSeq`
- do not mutate the log
- fail soft by returning `[]`

### AI_Commander_LogPrune.sqf

Input:

```sqf
// [_side]
```

Required behavior:

- enforce the 200-record cap
- update `wfbe_aicom_log_last_prune`
- fail soft

## Compile Lines

Add near the current AI Commander worker compiles:

```sqf
WFBE_SE_FNC_AI_Com_LogAppend = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_LogAppend.sqf";
WFBE_SE_FNC_AI_Com_LogDrain = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_LogDrain.sqf";
WFBE_SE_FNC_AI_Com_LogPrune = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_LogPrune.sqf";
```

These must compile before `WFBE_SE_FNC_AI_Commander` supervisors spawn.

## Emission Points

### Supervisor State

In `AI_Commander.sqf`, emit `STATE` only when state changes.

Payload:

```sqf
// [state, reason]
["full", "no-human-commander"]
["assist", "human-commander"]
["stopped", "disabled-or-hq-down"]
```

### Executed Explicit Orders

In `AI_Commander_Execute.sqf`, emit `ORDER` only when a new `wfbe_exec_sig` is executed.

Payload:

```sqf
// [team, mode, pos, waypointType, radius]
[_team, _modeL, _goto, _wpType, _radius]
```

### Town Assignments

In `AI_Commander_AssignTowns.sqf`, emit `TOWN_ASSIGN` only when a new town target is assigned.

Payload:

```sqf
// [team, townObj, townName, mode, reason]
[_team, _target, _target getVariable ["name", "town"], "towns", "nearest-uncaptured"]
```

### Production Orders

In `AI_Commander_Produce.sqf`, emit `PRODUCTION` after funds are deducted and `AIBuyUnit` is spawned.

Payload:

```sqf
// [team, unitType, factoryType, price]
[_team, _toBuild, _typeName, _price]
```

### Upgrade Starts

In `Server_AI_Com_Upgrade.sqf`, emit `UPGRADE` after affordability passes and `ProcessUpgrade` is spawned.

Payload:

```sqf
// [upgradeId, fromLevel, toLevel, supplyCost, fundsCost]
[_upgrade, _upgrades select _upgrade, _to_upgrade select 1, _cost select 0, _cost select 1]
```

## Guard Pattern

Each emission should be guarded so missing helper compilation cannot break command behavior:

```sqf
if (!isNil "WFBE_SE_FNC_AI_Com_LogAppend") then {
  [_side, "STATE", "AI_Commander", ["full", "no-human-commander"]] Call WFBE_SE_FNC_AI_Com_LogAppend;
};
```

Do not use log return values to control behavior.

## RPT Output

`LogAppend` may write a short summary line through `WFBE_CO_FNC_LogContent`.

Example:

```text
AI_Commander_Log: [WEST] #17 TOWN_ASSIGN team=B 1-2 town=Gorka reason=nearest-uncaptured
```

Keep payload dumps out of normal logs.

## Static Checks

Before opening the PR:

- no Arma 3-only syntax
- helper files compile with `preprocessFileLineNumbers`
- compile lines appear before supervisor spawn
- every log call uses `[_side, _kind, _source, _payload]`
- no behavior condition depends on log success
- log cap is enforced
- no publicVariable is required

## Runtime Smoke

Use the validation plan and collect RPT excerpts.

Required positive evidence:

- full-auto emits `STATE full`
- town auto-assignment emits `TOWN_ASSIGN`
- production emits `PRODUCTION`
- upgrade emits `UPGRADE`
- hybrid command-bar execution emits `ORDER`
- hybrid human commander does not emit `PRODUCTION` or `UPGRADE`
- log sequence increases per side
- log array remains bounded after a longer run

Regression evidence:

- full-auto still assigns towns, produces, and upgrades as before
- hybrid explicit orders still produce waypoints
- delegated/non-delegated behavior is unchanged
- human commander economy freeze is unchanged
- disabled/HQ-down stop behavior is unchanged

## PR Body Skeleton

```markdown
## What

Adds Phase 1 structured logs for the AI Commander. This records existing supervisor, order, town assignment, production, and upgrade events without changing AI decisions.

## Files

- `AI_Commander_LogAppend.sqf`
- `AI_Commander_LogDrain.sqf`
- `AI_Commander_LogPrune.sqf`
- emission points in supervisor/executor/town/produce/upgrade workers

## Boundaries

- No decision changes.
- No public broadcast.
- Logs are server-owned and side-logic scoped.
- Logging fails soft and remains bounded.

## Validation

- Static checks: ...
- Runtime smoke: ...
- RPT excerpts: ...
```

## Stop Conditions

Stop and fix before publishing if:

- a missing log helper breaks the commander
- any AI decision changes because logging was added
- log arrays grow unbounded
- hybrid mode emits economy events while human commander is active
- RPT shows undefined variables or nil-code from log helpers

## Next Phase

After Phase 1 passes, use `docs/quad-ai-commander-phase2-beliefs.md` to implement `feat/ai-commander-context`.
