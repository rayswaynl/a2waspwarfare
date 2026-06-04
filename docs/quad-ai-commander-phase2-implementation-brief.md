# Quad AI Commander Phase 2 Implementation Brief

This is the kickoff brief for the first context/belief branch after Phase 1 structured logs are proven.

Active draft PR:

```text
#19 - [codex] Phase 2 AI Commander context beliefs
```

Target branch name:

```text
codex/ai-commander-context
```

Base branch:

```text
codex/ai-commander-logs
```

Primary specs:

```text
docs/quad-ai-commander-phase1-logs.md
docs/quad-ai-commander-phase2-beliefs.md
docs/quad-ai-commander-runtime-validation.md
```

## Objective

Add a server-owned AI Commander context layer that consumes structured logs and produces bounded tactical beliefs without changing any commander decisions.

Phase 2 is complete when `CONTACT`, `INTEL`, and `LOSS` structured logs can become bounded, decaying, nearest-town-aware beliefs on the side logic, with RPT/debug evidence proving the context layer is advisory-only.

## Preconditions

Do not begin behavior-affecting planner or worker changes here.

Required before marking Phase 2 ready:

- Phase 0 hybrid/handoff/stopped smoke evidence is complete on PR #14.
- Phase 1 structured log PR #18 has runtime evidence for `STATE`, `ORDER`, `TOWN_ASSIGN`, `PRODUCTION`, and `UPGRADE` records.
- Phase 1 proves no economy events occur while a human commander controls the side.
- Phase 1 log sequence and cap behavior are proven from RPT or scripted inspection.

A draft scaffold may be opened before those gates, but it must remain draft and advisory-only.

## Files To Add

```text
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_ContextUpdate.sqf
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_BeliefMerge.sqf
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_BeliefDecay.sqf
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_ContextDebug.sqf
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_ContextSyntheticSmoke.sqf
```

Takistan/variant propagation should wait until the Chernarus source is stable, unless the repo workflow requires immediate generated parity.

## Files To Edit

```text
Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander.sqf
```

Only add guarded compile/call hooks for context update and compile the manual synthetic smoke helper. Do not change town assignment, executor, type assignment, production, or upgrade decisions.

## Compile Strategy

Prefer compiling near other AI Commander functions when the branch is easy to edit locally.

If stacked through connector edits, the Phase 1 lazy-compile pattern is acceptable:

```sqf
if (isNil "WFBE_SE_FNC_AI_Com_ContextUpdate") then {WFBE_SE_FNC_AI_Com_ContextUpdate = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_ContextUpdate.sqf"};
if (isNil "WFBE_SE_FNC_AI_Com_BeliefMerge") then {WFBE_SE_FNC_AI_Com_BeliefMerge = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_BeliefMerge.sqf"};
if (isNil "WFBE_SE_FNC_AI_Com_BeliefDecay") then {WFBE_SE_FNC_AI_Com_BeliefDecay = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_BeliefDecay.sqf"};
if (isNil "WFBE_SE_FNC_AI_Com_ContextDebug") then {WFBE_SE_FNC_AI_Com_ContextDebug = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_ContextDebug.sqf"};
if (isNil "WFBE_SE_FNC_AI_Com_ContextSyntheticSmoke") then {WFBE_SE_FNC_AI_Com_ContextSyntheticSmoke = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_ContextSyntheticSmoke.sqf"};
```

Guard every call so context failure cannot break commander execution. The synthetic smoke helper must not be called automatically.

## Storage Contract

Store context on side logic:

```sqf
_logik setVariable ["wfbe_aicom_context", []];
_logik setVariable ["wfbe_aicom_context_last_seq", 0];
_logik setVariable ["wfbe_aicom_context_last_update", 0];
_logik setVariable ["wfbe_aicom_context_last_debug", 0];
```

No public broadcast is required in Phase 2.

## Function Contracts

### AI_Commander_ContextUpdate.sqf

Input:

```sqf
// _side
```

Required behavior:

- resolve side logic
- read `wfbe_aicom_context_last_seq`
- drain new records with `WFBE_SE_FNC_AI_Com_LogDrain`
- normalize only `CONTACT`, `INTEL`, and `LOSS` records into belief candidates
- call `AI_Commander_BeliefMerge` for candidates
- call `AI_Commander_BeliefDecay` every update
- cap stored beliefs at 50
- update `wfbe_aicom_context_last_seq` to the newest processed log sequence
- optionally call `AI_Commander_ContextDebug` on a slow interval
- fail soft and never issue orders

### AI_Commander_BeliefMerge.sqf

Input:

```sqf
// [_side, _context, _candidate]
```

Required behavior:

- merge nearby matching beliefs by enemy side, category, and town attachment
- use bounded confidence, capped at `0.95`
- preserve earliest first seen and newest last seen
- cap source labels to a small list
- return the updated context array

### AI_Commander_BeliefDecay.sqf

Input:

```sqf
// [_side, _context]
```

Required behavior:

- decay confidence based on age since `lastSeen`
- mark old low-confidence beliefs stale or expired
- drop expired records unless keeping a tiny debug tail
- enforce the 50-belief cap
- return the updated context array

### AI_Commander_ContextDebug.sqf

Input:

```sqf
// [_side, _context]
```

Required behavior:

- emit slow summary-only RPT output
- never dump every belief every tick
- include enough text to prove top belief status, category, town, confidence, age, and sources

Current draft output shape:

```text
AI_Commander_Context: [WEST] 3 tracked beliefs, top=active/armor near Gorka conf=0.78 age=42s sources="BLUEFOR-C1","INTEL-FUZZY".
```

### AI_Commander_ContextSyntheticSmoke.sqf

Input:

```sqf
// _side
```

Required behavior:

- append two nearby `CONTACT` records, one `INTEL` record, and one `LOSS` record through `WFBE_SE_FNC_AI_Com_LogAppend`
- use a town position as the anchor when towns exist
- emit a short RPT line confirming synthetic records were appended
- return `true` on success and `false` on missing side logic or log append helper
- never run automatically

## Synthetic Log Smoke

Preferred manual server/debug command:

```sqf
west Call WFBE_SE_FNC_AI_Com_ContextSyntheticSmoke;
```

Use `east` instead of `west` to smoke the other side.

Expected RPT anchors:

```text
AI_Commander_ContextSyntheticSmoke: [WEST] appended CONTACT/INTEL/LOSS synthetic records
AI_Commander_Log: [WEST] #... CONTACT
AI_Commander_Log: [WEST] #... INTEL
AI_Commander_Log: [WEST] #... LOSS
AI_Commander_Context: [WEST] ... tracked beliefs, top=...
```

The helper appends records equivalent to:

```sqf
[_side, "CONTACT", "SYNTHETIC-C1", [_enemy, "armor", _pos, 3, 6, 0.75, _label]] Call WFBE_SE_FNC_AI_Com_LogAppend;
[_side, "CONTACT", "SYNTHETIC-C2", [_enemy, "armor", _nearPos, 2, 5, 0.65, _label]] Call WFBE_SE_FNC_AI_Com_LogAppend;
[_side, "INTEL", "SYNTHETIC-RADIO", [_enemy, "unknown", _nearPos, 0, -1, 0.35, _label, "radio-traffic"]] Call WFBE_SE_FNC_AI_Com_LogAppend;
[_side, "LOSS", "SYNTHETIC-LOSS", [_team, _nearPos, "vehicle-destroyed", "armor", 0.45]] Call WFBE_SE_FNC_AI_Com_LogAppend;
```

Synthetic logs are for validation only. Do not wire fake contacts into normal gameplay.

## Supervisor Hook

Add a slow guarded context update interval inside `AI_Commander.sqf`, after Phase 1 helpers are compiled and while the commander is active.

Suggested interval:

```sqf
if (time - _ltContext > 30) then {
	if (!isNil "WFBE_SE_FNC_AI_Com_ContextUpdate") then {(_side) Call WFBE_SE_FNC_AI_Com_ContextUpdate};
	_ltContext = time;
};
```

This hook must not be inside the full-auto economy-only block. Hybrid mode needs context too, but context must still not spend economy or overwrite human orders.

## Static Checks

Before opening the PR:

- no Arma 3-only syntax
- all new files compile with `preprocessFileLineNumbers`
- context calls Phase 1 drain helper only when it exists
- synthetic smoke helper is compiled but not invoked automatically
- no worker reads `wfbe_aicom_context` yet
- no order, production, upgrade, or type-assignment logic changes
- belief count is capped
- confidence values are clamped between 0 and 1
- malformed logs fail soft

## Runtime Smoke

Using synthetic logs:

- one `CONTACT` creates one active belief
- nearby `CONTACT` from another source merges and raises confidence
- far `CONTACT` creates a separate belief, if manually appended beyond merge radius
- `INTEL` creates low-confidence rumor/context and does not jump to high confidence alone
- `LOSS` creates or reinforces a moderate-confidence threat belief
- confidence decays over time
- stale beliefs expire or stop appearing in tracked summaries
- nearest town attaches correctly when position is near a town
- debug summaries appear only on the slow interval
- no team waypoints, production, upgrades, or assignment decisions change solely from Phase 2

## PR Body Skeleton

```markdown
## What

Adds the Phase 2 AI Commander context layer. It consumes Phase 1 structured logs and builds bounded, decaying, nearest-town-aware beliefs without changing commander decisions.

## Boundaries

- Advisory/context-only.
- No planner priorities yet.
- No worker biasing.
- No economy or waypoint behavior changes.
- Context is server-owned and side-logic scoped.
- Synthetic smoke helper is manual only.

## Validation

- Static checks: ...
- Synthetic log smoke: ...
- RPT/debug excerpts: ...
```

## Stop Conditions

Stop and fix before publishing if:

- context update can crash when log helpers are absent
- malformed logs produce undefined-variable RPT noise
- context grows unbounded
- confidence exceeds 1 or goes below 0
- synthetic smoke runs automatically in normal gameplay
- any existing commander worker changes behavior because context exists
- human explicit orders or economy boundaries are affected

## Next Phase

After Phase 2 passes, use `docs/quad-ai-commander-phase3-planner.md` to implement an advisory planner branch. The planner should read beliefs and write priorities, but still must not issue orders or spend economy by default.
