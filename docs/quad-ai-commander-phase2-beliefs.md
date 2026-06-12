# Quad AI Commander Phase 2: Context And Beliefs

Phase 2 consumes structured commander logs from Phase 1 and turns relevant events into a per-side tactical context.

This phase should still avoid changing AI decisions by default. Its purpose is to prove that logs can become bounded, explainable contact beliefs that a later planner can use.

## Scope

Add a context update layer that can:

- drain new structured logs since the previous update
- convert `CONTACT`, `INTEL`, and selected `LOSS` events into beliefs
- merge nearby related reports
- decay confidence over time
- expire stale beliefs
- attach nearest town information where possible
- emit slow debug summaries for verification

Do not bias town assignment, template selection, production, or upgrades in Phase 2. That belongs to Phase 3/4.

## Proposed Files

```text
Server/AI/Commander/AI_Commander_ContextUpdate.sqf
Server/AI/Commander/AI_Commander_BeliefMerge.sqf
Server/AI/Commander/AI_Commander_BeliefDecay.sqf
Server/AI/Commander/AI_Commander_ContextDebug.sqf
```

Compile near the existing AI Commander functions:

```sqf
WFBE_SE_FNC_AI_Com_ContextUpdate = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_ContextUpdate.sqf";
WFBE_SE_FNC_AI_Com_BeliefMerge = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_BeliefMerge.sqf";
WFBE_SE_FNC_AI_Com_BeliefDecay = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_BeliefDecay.sqf";
WFBE_SE_FNC_AI_Com_ContextDebug = Compile preprocessFileLineNumbers "Server\AI\Commander\AI_Commander_ContextDebug.sqf";
```

## Storage

Store context on the side logic.

```sqf
_logik setVariable ["wfbe_aicom_context", []];
_logik setVariable ["wfbe_aicom_context_last_seq", 0];
_logik setVariable ["wfbe_aicom_context_last_update", 0];
_logik setVariable ["wfbe_aicom_context_last_debug", 0];
```

The context is server-owned in Phase 2. It does not need public broadcast yet.

## Belief Shape

Use a compact array record:

```sqf
// [id, enemySide, category, pos, townObj, townName, countMin, countMax, confidence, firstSeen, lastSeen, sources, status]
[
  "contact-gorka-001",
  east,
  "armor",
  [9610,8790,0],
  _gorka,
  "Gorka",
  3,
  6,
  0.78,
  time - 240,
  time - 30,
  ["BLUEFOR-C1", "INTEL-FUZZY"],
  "active"
]
```

Field notes:

- `id`: stable-enough local identifier; does not need to be globally unique beyond the side context
- `enemySide`: side reported as enemy
- `category`: broad type such as `infantry`, `armor`, `air`, `support`, `unknown`
- `pos`: last estimated position
- `townObj` / `townName`: nearest town attachment, if available
- `countMin` / `countMax`: estimate range; use `0` or `-1` for unknown
- `confidence`: 0.0 to 1.0
- `firstSeen` / `lastSeen`: mission `time`
- `sources`: short list of source labels
- `status`: `active`, `stale`, `expired`, `lost`, `destroyed`, or `rumor`

## Log Inputs

### CONTACT

Expected payload from Phase 1 or future emitters:

```sqf
// [enemySide, category, pos, countMin, countMax, confidence, label]
[east, "armor", _pos, 3, 6, 0.75, "Gorka"]
```

This should create or update an active belief.

### INTEL

Expected payload:

```sqf
// [enemySide, category, pos, countMin, countMax, confidence, label, intelKind]
[east, "unknown", _pos, 0, -1, 0.35, "Gorka", "radio-traffic"]
```

This should create lower-confidence beliefs or reinforce existing ones, but should not become high-confidence alone unless repeated or corroborated.

### LOSS

Expected payload:

```sqf
// [friendlyTeamOrUnit, pos, lossKind, suspectedEnemyCategory, confidence]
[_team, _pos, "vehicle-destroyed", "armor", 0.45]
```

This can create a low-to-medium-confidence threat belief if no direct contact exists.

## Context Update Loop

`AI_Commander_ContextUpdate.sqf` input:

```sqf
// _side
```

Behavior:

1. Resolve side logic.
2. Read `wfbe_aicom_context_last_seq`.
3. Drain structured logs with `AI_Commander_LogDrain`.
4. For each relevant log, normalize it into a candidate belief.
5. Merge the candidate with current context via `AI_Commander_BeliefMerge`.
6. Decay all beliefs via `AI_Commander_BeliefDecay`.
7. Drop expired records or keep a tiny expired tail for debug.
8. Store updated context and latest processed seq.
9. Optionally emit a slow debug summary.

Recommended interval: 30-60 seconds.

## Merge Rules

A candidate should merge into an existing belief when:

- enemy side matches
- category matches or one side is `unknown`
- position distance is within a merge radius
- nearest town matches, if both have towns

Suggested merge radius by category:

```text
infantry: 300m
armor: 600m
air: 1200m
support: 600m
unknown: 400m
```

Merge behavior:

- `pos`: weighted toward the newest report
- `countMin`: minimum of known mins, unless unknown
- `countMax`: maximum of known maxes, unless unknown
- `confidence`: increase for corroboration, capped at 0.95
- `firstSeen`: earliest firstSeen
- `lastSeen`: newest lastSeen
- `sources`: append source label if new, cap to 4-6 entries
- `status`: prefer `active` over `rumor` if a direct contact arrives

Suggested confidence merge:

```text
mergedConfidence = min(0.95, max(oldConfidence, newConfidence) + corroborationBonus)
```

Suggested corroboration bonus:

```text
same source: +0.02
new source: +0.08
direct CONTACT over INTEL: +0.10
LOSS only: +0.03
```

Exact math can be tuned later; the important invariant is bounded confidence.

## Decay Rules

Decay confidence based on age since `lastSeen`.

Suggested bands:

```text
0-120s: no decay
120-300s: light decay
300-600s: medium decay
600s+: heavy decay / stale
900s+: expire unless recently reinforced
```

Suggested behavior:

- below 0.25 confidence: mark `stale`
- below 0.10 confidence or older than expiry: mark/drop `expired`
- direct contact should decay slower than rumor-only intel
- air contacts should decay faster than static/town-linked contacts

## Nearest Town Attachment

When a candidate has a position, attach nearest town:

```sqf
_town = [_pos, towns] Call WFBE_CO_FNC_GetClosestEntity;
```

Only attach the town if it exists and is within a reasonable radius.

Suggested radius:

```text
1500m default
2500m for air
```

If no town is near, use `objNull` and an empty town name.

## Debug Output

Debug should be slow and summary-oriented.

Example:

```text
AI_Commander_Context: [WEST] 3 active beliefs, top=armor near Gorka conf=0.78 age=42s sources=BLUEFOR-C1,INTEL-FUZZY
```

Do not dump every belief every tick.

Recommended debug interval: 120-180 seconds.

## Invariants

- Context update must not issue orders.
- Context update must not spend economy.
- Missing or malformed logs fail soft.
- Belief count remains bounded.
- Confidence remains between 0 and 1.
- Expired beliefs do not influence future planner priorities.
- Human explicit orders remain untouched.
- Phase 2 can be disabled without changing existing AI Commander behavior.

Suggested cap:

```sqf
WFBE_C_AI_COMMANDER_BELIEFS_MAX = 50;
```

If no constant is added, enforce a local cap of 50.

## Static Validation Checklist

- New files compile through `preprocessFileLineNumbers`.
- No Arma 3-only syntax is introduced.
- Context functions are compiled before the supervisor can call them.
- Context update calls Phase 1 log helpers only after they exist.
- Arrays use fixed indexes documented in this spec.
- Belief caps and confidence bounds are enforced.

## Runtime Smoke Checklist

Using synthetic or scripted logs:

- One `CONTACT` creates one belief.
- A second nearby `CONTACT` from a different source merges and raises confidence.
- A far contact creates a separate belief.
- An `INTEL` rumor creates low confidence and does not jump to high confidence alone.
- A `LOSS` event creates or reinforces a threat belief with moderate confidence.
- Confidence decays over time.
- Stale beliefs expire or stop appearing in active summaries.
- Nearest town attaches correctly when position is near a town.
- Debug summary appears on the configured slow interval.
- No town assignment, production, upgrade, or executor behavior changes solely from Phase 2.

## Exit Criteria

Phase 2 is complete when structured logs can be converted into bounded, decaying, nearest-town-aware beliefs without changing commander decisions. The context must be stable enough for Phase 3 planner priorities to consume.
