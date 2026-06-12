# Quad AI Commander Phase 1: Structured Logs

Phase 1 adds a structured commander log API on top of the current AI Commander execution branch.

This phase should not change AI decisions. Its job is to record what the existing commander already does, in a format later phases can consume for context and planning.

## Scope

Add structured logs for existing AI Commander activity:

- supervisor state changes
- explicit orders executed by the order executor
- town assignments
- production orders
- upgrade starts

Do not add contact belief merging or planner behavior in this phase.

## Proposed Files

```text
Server/AI/Commander/AI_Commander_LogAppend.sqf
Server/AI/Commander/AI_Commander_LogDrain.sqf
Server/AI/Commander/AI_Commander_LogPrune.sqf
```

Compile in `Server/Init/Init_Server.sqf` near the other AI Commander workers:

```sqf
WFBE_SE_FNC_AI_Com_LogAppend = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_LogAppend.sqf";
WFBE_SE_FNC_AI_Com_LogDrain = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_LogDrain.sqf";
WFBE_SE_FNC_AI_Com_LogPrune = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_LogPrune.sqf";
```

## Storage

Store logs on the side logic, not in global side-specific mission variables.

```sqf
_logik setVariable ["wfbe_aicom_logs", []];
_logik setVariable ["wfbe_aicom_log_seq", 0];
_logik setVariable ["wfbe_aicom_log_last_prune", 0];
```

Storage is server-owned. Public broadcast is not required for Phase 1.

## Record Shape

Use a compact array record:

```sqf
// [seq, kind, createdAt, side, source, payload]
[17, "TOWN_ASSIGN", time, west, _team, [_targetTown, getPos _targetTown, "nearest-uncaptured"]]
```

Field meanings:

- `seq`: monotonically increasing per-side integer
- `kind`: uppercase string event kind
- `createdAt`: mission `time`
- `side`: side being commanded
- `source`: group/object/string that produced the event
- `payload`: kind-specific compact array

## Event Kinds

### STATE

Supervisor lifecycle transition.

```sqf
["STATE", _side, "full"]
["STATE", _side, "assist"]
["STATE", _side, "stopped"]
```

Payload:

```sqf
// [state, reason]
["full", "no-human-commander"]
```

### ORDER

Explicit order executed by `AI_Commander_Execute.sqf`.

Payload:

```sqf
// [team, mode, pos, waypointType, radius]
[_team, "move", _goto, "MOVE", 50]
```

### TOWN_ASSIGN

Town assignment from `AI_Commander_AssignTowns.sqf`.

Payload:

```sqf
// [team, townObj, townName, mode, reason]
[_team, _target, _target getVariable ["name", "town"], "towns", "nearest-uncaptured"]
```

### PRODUCTION

Production order from `AI_Commander_Produce.sqf`.

Payload:

```sqf
// [team, unitType, factoryType, price]
[_team, _toBuild, _typeName, _price]
```

### UPGRADE

Upgrade start from `Server_AI_Com_Upgrade.sqf`.

Payload:

```sqf
// [upgradeId, fromLevel, toLevel, supplyCost, fundsCost]
[_upgrade, _upgrades select _upgrade, (_to_upgrade select 1), _cost select 0, _cost select 1]
```

## Helper Contracts

### AI_Commander_LogAppend.sqf

Input:

```sqf
// [_side, _kind, _source, _payload]
```

Behavior:

1. Resolve side logic.
2. Initialize log variables if missing.
3. Increment `wfbe_aicom_log_seq`.
4. Append `[seq, kind, time, side, source, payload]`.
5. Cap log size if needed.
6. Return the record or `nil` on failure.

Suggested size cap:

```sqf
WFBE_C_AI_COMMANDER_LOG_MAX = 200;
```

If adding a constant in Phase 1 is too much, hardcode `200` locally and promote to a parameter later.

### AI_Commander_LogDrain.sqf

Input:

```sqf
// [_side, _afterSeq]
```

Behavior:

- Return records whose `seq` is greater than `_afterSeq`.
- Do not mutate the log.
- Used by future context update code.

### AI_Commander_LogPrune.sqf

Input:

```sqf
// [_side]
```

Behavior:

- Enforce the size cap.
- Optionally remove records older than a TTL.
- Update `wfbe_aicom_log_last_prune`.

Recommended TTL for Phase 1:

```sqf
WFBE_C_AI_COMMANDER_LOG_TTL = 600;
```

If no constant is added, use size-cap pruning only.

## Emission Points

### AI_Commander.sqf

Emit `STATE` only when `_state != _prevState` or when stopping. This avoids per-tick noise.

### AI_Commander_Execute.sqf

Emit `ORDER` only when a new signature is executed.

### AI_Commander_AssignTowns.sqf

Emit `TOWN_ASSIGN` only when a team receives a new town.

### AI_Commander_Produce.sqf

Emit `PRODUCTION` only after funds are deducted and `AIBuyUnit` is spawned.

### Server_AI_Com_Upgrade.sqf

Emit `UPGRADE` only after affordability validation passes and `ProcessUpgrade` is spawned.

## RPT Formatting

The structured log is the source of truth. RPT messages should remain short and human-readable.

Suggested prefix:

```text
AI_Commander_Log: [WEST] #17 TOWN_ASSIGN team=B 1-2 town=Gorka reason=nearest-uncaptured
```

Do not dump full payload arrays every time unless debug mode is added.

## Invariants

- Logs are server-owned.
- Event emission must not change decisions.
- Missing log helper must not break commander execution.
- Logs must remain bounded.
- Sequence numbers must increase per side.
- Human explicit orders remain sacred.
- AI economy still does not spend while a human commands.

## Failure Behavior

Logging should fail soft. If side logic is missing, payload is malformed, or variables are absent, the helper should exit without throwing runtime errors.

Avoid making the commander depend on successful logging in Phase 1.

## Static Validation Checklist

- New files compile with `preprocessFileLineNumbers`.
- New helper names are compiled before `AI_Commander.sqf` supervisors spawn.
- Every call passes `[_side, _kind, _source, _payload]`.
- No Arma 3-only syntax is introduced.
- No publicVariable is required.
- Log arrays are capped.

## Runtime Smoke Checklist

In full-auto mode:

- `STATE full` appears once per transition.
- `TOWN_ASSIGN` appears when teams receive town targets.
- `PRODUCTION` appears when units are ordered.
- `UPGRADE` appears when the AI starts a tech upgrade.

In hybrid mode:

- `STATE assist` appears when a human commander is present.
- Human Move/Patrol/Defense commands produce `ORDER` entries when executed.
- Delegated teams can still produce `TOWN_ASSIGN` entries.
- No `PRODUCTION` or `UPGRADE` entries appear while the human commander owns economy.

On stop/handoff:

- `STATE stopped` appears when disabled or HQ is down.
- Human-leaves transition can emit `STATE full` and resume full-auto entries.
- Log size remains bounded after a long run.

## Exit Criteria

Phase 1 is complete when logs record existing AI Commander behavior without changing it, remain bounded, and provide enough structured events for Phase 2 context/belief code to consume.
