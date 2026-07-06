# SPEC-ADAPTIVE-COMMANDER

Guide rev: GR-2026-07-03a. Lane: 456. Scope: final-form architecture spec only; no gameplay code.

Base reviewed: `origin/claude/build84-cmdcon36` at `55c11551f61c5193672dd73e8c88d1aa69e88be4`.

Prompt hash reviewed: `731DF072DEC219050A1B4694D1B04D36B178191C69E81FCCD28D7C4B5197A910`.

## Purpose

Adaptive Commander is the learning layer for AICOM V2. It lets the commander remember what just hurt it, carry safe round-level priors forward, and mine soak/stat data into versioned knowledge packs without making the in-match AI psychic, random, or unreviewable.

This spec defines three tiers:

| Tier | Runtime | Owner | Output |
|---|---|---|---|
| T1 within-round adaptation | Live mission SQF | Server-side AICOM V2 memory layer | Pain memory, counter-tech scores, opponent spend model, route/counter decisions with TTLs |
| T2 cross-round persistence | Mission start/end bridge plus Stats V2 ingest | Server extension/DB or RPT ingest worker | Versioned round summaries and map/profile priors |
| T3 offline meta-learning | Stats V2 plus soak farm | Website/worker/offline tools | Versioned knowledge packs stored in map profiles |

The design rule is simple: learning adjusts weights inside doctrine. It must never bypass locality, evidence, fallback, or explainability rules.

## Binding Constraints

- A2 OA 1.64 only. Use arrays, strings, numbers, and booleans. No hash maps, no A3-only commands, no group `getVariable`.
- `WFBE_C_AICOM_V2_ENABLE = 0` remains the master fallback; with the flag at 0, V1 commander behaviour is unchanged.
- Learning tunes within the five design commandments and eight behavioural doctrine rules. It may adjust thresholds, priors, and route/build preferences; it must never override legibility, no-dead-air, never-psychic, locality-first, or map-profile constraints.
- No doctrine personalities. Per-map profiles and skill/handicap dials are allowed; stored knowledge packs are versioned map/profile inputs, not personality presets.
- All persistent reads are optional. If an extension or database call is absent, empty, malformed, slow, or stale, V2 continues with compiled profile defaults and logs the fallback.

## Verified V1 Evidence

| Evidence | Verified source |
|---|---|
| V2 master rollback flag and server-side parallel brain contract | `docs/design/v2/AICOM-V2-LAYER-ARCH.md:7` |
| V2 map profile variable naming and profile record shape | `docs/design/v2/AICOM-V2-MAP-PROFILE-FORMAT.md:9`, `:21` |
| CH/TK/ZG profile variables exist in the spec pack | `docs/design/v2/AICOM-V2-PROFILE-CH.md:184`, `AICOM-V2-PROFILE-TK.md:157`, `AICOM-V2-PROFILE-ZG.md:132` |
| Acceptance harness grades churn, superiority, never-psychic, no-dead-air, profile load, and FPS parity | `docs/design/v2/AICOM-V2-ACCEPTANCE-HARNESS.md:35`, `:50-57`, `:93-102`, `:142`, `:172` |
| Current RPT analyzer parses `AICOMSTAT`, `WASPSTAT`, and `WASPSCALE` anchors | `Tools/Soak/analyze_soak.py:169`, `:230-254` |
| Current `WASPSTAT|v1` record types are `KILL`, `CAPTURE`, `ROUNDEND`, and implicit player-stat rows | `docs/WASPSTAT-FORMAT.md:15-26`, `:39-50`, `:83-143` |
| Server extension functions are registered in `Init_Server.sqf` and use `A2WaspDatabase` through AntiStack helpers | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_Server.sqf:109-124` |
| Existing guarded database read pattern for side skill | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_StagnateSupplyIncomeNoPlayers.sqf:14-20` |
| Current `REQUEST_SIDE_SKILL` extension call and empty-response guard | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Module/AntiStack/callDatabaseRequestSideTotalSkill.sqf:27-35` |
| Existing `a2waspwarfare_Extension` bridge accepts `GLOBALGAMESTATS` only | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/CallExtensions/GlobalGameStats.sqf:2`, `:26`; `Extension/src/BaseExtensionClass/ExtensionName.cs:1-3` |
| `GLOBALGAMESTATS` stores raw exported args and serializes through the base class | `Extension/src/BaseExtensionClass/Implementations/GLOBALGAMESTATS.cs:17-21`; `Extension/src/BaseExtensionClass/BaseExtensionClass.cs:16` |

## Source Contracts

### V2 architecture contracts

Adaptive Commander sits beside the V2 layer architecture rather than replacing it:

- Perception produces defensive, A2/OA-safe primitive world-state arrays.
- Assessment and planning stay pure: array in, array out, no globals, no spawning, no PVF.
- Execution is the only layer that writes side/team state, delegates orders, and emits runtime logs.
- All decision state lives server-side. HC receives orders and may emit audit telemetry only.
- Profiles load from `WFBE_AICOMV2_PROFILE_<worldName>` with nil/malformed fallback and a profile load telemetry line.

Adaptive state therefore has two forms:

| Form | Lives where | Used by |
|---|---|---|
| Runtime memory snapshot | Server-side side logic namespace | Perception/assessment snapshot input |
| Pure adaptation record | Primitive array passed into planning | Planner score modifiers and WHY output |

No adaptive state may live on HC. No adaptive planner may read object refs, group refs, or global hidden enemy arrays directly.

### Four-layer interface

| Layer | Reads | Writes | Learning responsibility |
|---|---|---|---|
| Perception | Town state, observed contacts, kill/capture events, wildcard/recon intel, route outcomes | `intelId`, `painEvent`, `enemyTechSeen`, `routeOutcome` records | Creates evidence only from observable events; stamps `seen=1` for WHY validation. |
| Assessment | Perception records, current posture, funds/supply, profile, current knowledge pack | `spendPressure`, `tempoShift`, doctrine proxy fields | Computes whether learning hints are legal under doctrine and profile clamps. |
| Planning | Assessment, pure T1 memory, T2/T3 priors, route graph, build/research queues | Decision records with `why`, `learningHints`, `packId` | Applies small bounded priors only after hard gates pass; cannot choose unseen targets. |
| Execution | Accepted decision records, existing order bridge, extension helpers at round start/end | Orders, telemetry, optional store calls | Emits `BUILDORDER`/`KNOWLEDGE` lines, stores aggregates after round end, never blocks active orders. |

### Current extension and database contracts

Current tree has two different extension styles, and this spec must not conflate them.

`Server/CallExtensions/GlobalGameStats.sqf` is a narrow fire-and-forget global stats writer:

- It sends class name `GLOBALGAMESTATS`.
- It calls `"a2waspwarfare_Extension" callExtension format ["%1,%2,%3,%4,%5,%6", ...]`.
- The payload is score west, score east, current map, uptime, player count.
- It sleeps 60 seconds between sends.

The C# extension side currently exposes only `GLOBALGAMESTATS` in `ExtensionName.cs`. `BaseExtensionClass.cs` calls the derived class and then serializes the DB. `GLOBALGAMESTATS.cs` only stores the incoming args in `GameData.Instance.exportedArgs`.

AntiStack uses a separate `"A2WaspDatabase"` extension protocol:

- Write path: `callDatabaseStore.sqf` uses procedure `202` and expects a compiled array response.
- Side write path: `callDatabaseStoreSide.sqf` uses procedure `404`.
- Player list write path: `callDatabaseSendPlayerList.sqf` uses procedure `303`.
- Read path: `callDatabaseRetrieve.sqf` sends procedure `101`, receives a request id, then polls procedure `505` until a response or timeout.
- Team skill read path: `callDatabaseRequestSideTotalSkill.sqf` sends procedure `606`, then polls procedure `707`.
- All recent callers guard empty extension responses because `callExtension` can return `""`, and `call compile ""` becomes nil.

Implication: Adaptive Commander must not hijack the AntiStack procedure namespace or assume `a2waspwarfare_Extension` is a general key-value database. T2 persistence needs either a new explicit extension class/procedure contract, or an RPT-to-Stats V2 ingest path first.

### Current telemetry and stats contracts

`docs/WASPSTAT-FORMAT.md` defines `WASPSTAT|v1|` as the authoritative mission-to-RPT stats stream:

- Prefix: `WASPSTAT|v1|<seq>|...`
- `seq` is a shared server-global monotonic sequence.
- Player stat flushes have no `PLAYERSTATS` keyword.
- `KILL`, `CAPTURE`, and `ROUNDEND` are explicit record types.
- `ROUNDEND` carries winner side, duration seconds, and map.

`Tools/Soak/analyze_soak.py` already treats `WASPSTAT|`, `AICOMSTAT|`, and `WASPSCALE|` as scoped RPT stats markers. The V2 specs keep AICOM records append-only: retain old v1/v2 layouts and add new v3 families rather than mutating existing lines.

Stats V2 branch specs define:

- `matches` keyed by `round_key`.
- `match_events` keyed by `(round_key, seq)`.
- `match_players` keyed by `(round_key, steam_id64)`.
- `round_key = <rptid>#<ordinal>`.
- AICOMSTAT and WASPSCALE stay append-only through their existing parser/route ownership.

Adaptive Commander should add AICOMSTAT v3 adaptive families and optional `BUILDORDER` mission lines; it should not mutate WASPSTAT v1 field layouts.

## Non-Negotiable Guardrails

1. Master flag:
   - Use one default-off master gate: `WFBE_C_AICOM_V2_ADAPTIVE = 0`.
   - With the flag at `0`, V1 and non-adaptive V2 behavior stay inert.
   - Do not wire `WFBE_C_SIM_GATING`.

2. Locality:
   - Server owns all adaptive memory and persistence calls.
   - HC receives orders only.
   - HC never writes adaptive memory back to server.

3. Pure planning:
   - T1 memory is serialized into an input record before planning.
   - Planner receives `[worldState, assessment, profile, adaptation]`.
   - Planner returns decisions plus WHY/adaptive telemetry records.
   - No planner reads globals, object refs, or hidden enemy arrays.

4. A2/OA-safe data:
   - Use arrays, strings, numbers, and 0/1 booleans.
   - No hash maps.
   - No A3-only commands from `AGENTS.md`.
   - No group `getVariable [name, default]`.
   - No public third argument on `missionNamespace setVariable`.

5. Fog-of-war honesty:
   - Every adaptation has an evidence source.
   - Counter-tech needs observed threat/loss/spend evidence.
   - Stale evidence can justify caution, probes, or lower confidence; it cannot trigger perfect counters.

6. Doctrine guardrails:
   - Adaptive weights cannot disable no-dead-air, crisis defense, group cap safety, or map-profile fallback.
   - Profiles stay internal weight sets, not owner-rejected doctrine personalities.
   - GUER volume is never capped or nerfed by learning.
   - AntiStack is hands-off except for read-only reference to its extension call shape.

7. Poison resistance:
   - No UID-specific nemesis memory in the one-shot build.
   - Persist only aggregate map/side/profile observations.
   - Require minimum samples before promotion.
   - Clamp every learned delta.
   - Decay old data.
   - Separate map, side, profile, build version, and human-vs-AI commander mode.
   - Reject outliers and suspicious one-player/one-round swings.

8. Observability:
   - Every round logs active pack id.
   - Every adaptive decision logs source, confidence, applied delta, and clamp result.
   - Analyzer updates must be mechanical from the event definitions below.

## T1: Within-Round Adaptation

T1 is live SQF memory that expires inside the current round. It gives players the feeling that the commander noticed them without making anything persistent or privacy-sensitive.

### T1 state owner

Execution owns mutation. Perception reads the state, serializes a primitive snapshot, and passes it into assessment/planning.

Recommended side-logic variables:

| Variable | Type | Meaning |
|---|---|---|
| `wfbe_aicom_v2_adapt_mem` | array | All active pain/threat/spend records for one side |
| `wfbe_aicom_v2_adapt_seq` | number | Monotonic memory event id |
| `wfbe_aicom_v2_adapt_pack` | array | Loaded T2/T3 pack metadata and priors |
| `wfbe_aicom_v2_adapt_last_write` | number | Last persistence summary attempt time |

The runtime memory array shape:

```text
["AICOM_ADAPT_T1_V1", sideId, timeSec, seq, painRecords, spendRecords, routeRecords, summary]
```

### Pain memory

Pain memory records costly local damage that the commander can legitimately observe.

Record shape:

```text
[id, sideId, areaKey, areaX, areaZ, sourceType, sourceId, sourceSide, observedClass, lossType, lossValue, firstSeen, lastSeen, ttlSec, confidence, responseMask, decayClass]
```

Field meanings:

| Field | Type | Meaning |
|---|---|---|
| `id` | string | Stable local id such as `pm-<side>-<seq>` |
| `areaKey` | string | Town name/id or route bucket |
| `areaX`, `areaZ` | number | Approximate center, never exact hidden unit position |
| `sourceType` | string | `friendlyLoss`, `townFlip`, `playerIntel`, `contact`, `routeStuck`, `supportHit` |
| `sourceId` | string | Event id, seq, or `na` |
| `sourceSide` | number/string | Observed actor side if known |
| `observedClass` | string | Visible class/category, or `unknown` |
| `lossType` | string | `inf`, `veh`, `air`, `static`, `hq`, `town`, `time` |
| `lossValue` | number | Score contribution |
| `firstSeen`, `lastSeen` | number | Mission time seconds |
| `ttlSec` | number | Default 900 seconds, matching the 15-minute doctrine |
| `confidence` | number | 0.0 to 1.0 |
| `responseMask` | string | CSV-like allowed responses: `avoid,counter,arty,air,probe,defend` |
| `decayClass` | string | `fast`, `normal`, `slow` |

Evidence sources allowed for pain:

- Friendly team loss near known town or route.
- `WASPSTAT|v1|KILL` where killer/victim side/category is enough to infer battlefield pressure.
- `WASPSTAT|v1|CAPTURE` for a town the side just lost or flipped.
- V2 `PLAYER_INTEL` or contact report from the intel lane.
- HC team driver stranded/capture failures when already surfaced as V2 telemetry.
- Public base/MHQ under-attack state if the V1 source is cited by the builder.

Forbidden sources:

- Hidden enemy object arrays.
- Exact enemy composition before contact.
- A global scan of all enemy vehicles without an observation path.
- UID-specific player history carried across rounds.

### Pain scoring

Each new event updates or creates one pain record:

```text
newConfidence = min(1.0, oldConfidence * carry + eventWeight)
lossValue = baseLoss + objectiveWeight + repeatBonus
expiresAt = lastSeen + ttlSec
```

Recommended event weights:

| Event | Weight | Notes |
|---|---:|---|
| Friendly infantry loss | 0.10 | Requires local area/town |
| Friendly vehicle loss | 0.20 | Raises armor/AT concern if class/category supports it |
| Friendly aircraft loss | 0.25 | Raises AA concern only from observed source |
| Town lost | 0.35 | Strong public evidence |
| HQ/MHQ/base hit | 0.50 | Crisis path, still bounded by evidence |
| Repeated same area within TTL | +0.10 | Clamp total confidence at 1.0 |

Planners consume pain through modifiers:

| Planner | Allowed effect |
|---|---|
| Movement | Avoid route/town, reroute staging, delay fair fight, probe instead |
| Defense | Reinforce, counterattack route/source, enter crisis if base/MHQ/core threat |
| Support | Bias arty/air/scud support toward last known area if support lane allows it |
| Build/research | Increase counter evidence score; never force hidden tech |
| Explainability | Add WHY `painMemory` with `memoryId`, source, confidence |

### Counter-tech rules

Counter-tech is score-based. It never switches because the hidden enemy build is known. It switches when evidence crosses threshold.

Counter evidence record:

```text
[counterKey, sideId, areaKey, sourceType, observedClass, count, lossValue, confidence, firstSeen, lastSeen, expiry]
```

Counter keys:

| Key | Evidence required | Allowed response |
|---|---|---|
| `counterArmor` | Observed armor class, repeated vehicle losses, public enemy tech if already visible | Raise AT/armor/air support score |
| `counterAir` | Observed aircraft, air losses, AA engagement reports | Raise AA/air-defense score |
| `counterStatic` | Observed static/base defense, losses near static area | Bias arty/probe/alternate route |
| `counterInfMass` | Repeated infantry swarms in known area | Bias MG/grenade/arty support if available |
| `counterTownTrap` | Repeated losses entering same town/route | Avoid, probe, flank, or support prep |

Default thresholds:

| Constant | Default | Meaning |
|---|---:|---|
| `WFBE_C_AICOM_V2_ADAPT_COUNTER_MIN` | 0.55 | Minimum confidence to bias counter scoring |
| `WFBE_C_AICOM_V2_ADAPT_COUNTER_STRONG` | 0.80 | Strong evidence, still clamped |
| `WFBE_C_AICOM_V2_ADAPT_COUNTER_DECAY_SEC` | 900 | Evidence TTL |
| `WFBE_C_AICOM_V2_ADAPT_COUNTER_MAX_DELTA` | 0.20 | Max score delta applied to a planner weight |

### Opponent spend model

The spend model is an estimate, not truth. It infers pressure from observed outputs and public progress.

Record shape:

```text
[sideId, enemySideId, timeSec, windowSec, obsInf, obsVeh, obsAir, obsStatic, townDelta, killDelta, captureDelta, techHints, confidence]
```

Allowed inputs:

- Observed class/category from `WASPSTAT|v1|KILL`.
- V2 contact/intel reports.
- Town capture tempo.
- Public side score/funds/supply if already available to commanders through V1 code.
- Enemy support events that are visibly logged or announced.

Forbidden inputs:

- Enemy account bank from hidden side globals unless already public to the commander.
- Enemy factory queue or exact research state unless V1 already exposes it legitimately.
- Future knowledge from offline pack applied as if it were current hidden truth.

Planner effects:

| Spend signal | Effect |
|---|---|
| `armorLikely` | Raise AT/armor counter score within clamp |
| `airLikely` | Raise AA/air counter score within clamp |
| `staticLikely` | Prefer prep/support/probe over direct fair assault |
| `lowSpendPressure` | Increase no-dead-air pulse, probe, or expansion if evidence supports it |
| `highTempoEnemy` | Consolidate, counterattack, or interdict route |

### Exploration slice

T1 must leave room to learn and avoid deterministic traps.

Recommended constants:

| Constant | Default | Meaning |
|---|---:|---|
| `WFBE_C_AICOM_V2_ADAPT_EXPLORE_PCT` | 8 | Percent of eligible non-crisis decisions allowed to choose second-best safe option |
| `WFBE_C_AICOM_V2_ADAPT_EXPLORE_MIN_SEC` | 600 | Minimum spacing between exploration choices per side |
| `WFBE_C_AICOM_V2_ADAPT_EXPLORE_MAX_DELTA` | 0.15 | Max score disadvantage allowed for exploration |

Exploration is never allowed for:

- Base/MHQ crisis.
- Group-cap emergency.
- No-dead-air required pulse.
- Decisions lacking legal evidence.
- Hidden counters.

Exploration choices must log `explore=1` and the top two scores.

## T2: Cross-Round Persistence

T2 carries safe round-level priors forward. It is optional at runtime and must degrade to static map profiles plus RPT logging if persistence is absent.

### Persistence stance

The current tree does not provide a general adaptive DB. Builders have two safe options:

1. RPT-first path:
   - Mission emits AICOMSTAT v3 adaptive summaries and BUILDORDER events.
   - Stats V2 ingest stores them append-only.
   - A later offline process emits knowledge packs into map profiles.
   - No mission read from DB is needed for the one-shot.

2. New extension path:
   - Add a new explicit extension class/procedure namespace for AICOM adaptive reads/writes.
   - Keep it separate from AntiStack procedures.
   - Match the request-id/poll/timeout style if asynchronous.
   - Nil guard every response and fall back to profile defaults.

For the first build, prefer RPT-first for writes and profile-pack reads. Add live DB reads only after the extension contract is implemented and tested.

### T2 mission-side helpers

When the extension path is implemented, add the following named helpers rather than re-using AntiStack entry points:

| Helper | Location | Behaviour |
|---|---|---|
| `WFBE_SE_FNC_AICOMV2_KnowledgeLoad` | `Server/Module/AntiStack/callDatabaseAicomV2KnowledgeLoad.sqf` or equivalent server module | Reads one map/profile/pack tuple. Returns `[]` on absent extension, empty response, parse failure, or timeout. |
| `WFBE_SE_FNC_AICOMV2_KnowledgeStore` | `Server/Module/AntiStack/callDatabaseAicomV2KnowledgeStore.sqf` or equivalent server module | Writes one compact aggregate at round end. Fire-and-forget; failure logs but never changes match outcome. |

Use the existing extension safety pattern from `callDatabaseRequestSideTotalSkill.sqf`: detect `""`/nil responses before compile/select, log one warning, and return `[]`. Never block the commander supervisor waiting for T2.

### Adaptive read contract

If a DB/extension read exists, use one logical request with the named operation `AICOMV2_KNOWLEDGE_LOAD`:

| Operation | Request tuple | Response |
|---|---|---|
| `AICOMV2_KNOWLEDGE_LOAD` | `[op, mapKey, profileKey, packId, schemaVersion]` | `["AICOMV2_KNOWLEDGE_V1", packId, sampleCount, generatedAt, priors, clamps]` or `[]` |
| `AICOMV2_KNOWLEDGE_STORE` | `[op, mapKey, profileKey, packId, roundId, summary]` | `["OK"]`, `["STALE"]`, or `["ERR", reason]` |

Rules:

- A `[]` response means no pack; use static profile.
- An `["ERR", reason]` response is a fallback, not a mission error.
- Wrong schema/version is a fallback.
- Timeout is a fallback.
- Missing extension is a fallback.

If using the current `A2WaspDatabase` style, the call must follow this shape:

1. Send a new non-AntiStack request procedure.
2. Receive compiled array `[code, requestId]`.
3. Poll a new non-AntiStack retrieve procedure.
4. Compile response.
5. Validate array, schema, version, map, side, and profile before use.
6. Fall back on nil, empty string, malformed array, timeout, or version mismatch.

### Adaptive write contract

Mission-side writes are append-only summaries, not full memory dumps:

```text
AICOM_ADAPT_WRITE|schema|roundKey|map|side|profile|packId|summary
```

Summary payload shape:

```text
["AICOM_ADAPT_SUMMARY_V1", roundKey, sideId, mapKey, profileKey, packId, startTime, endTime, openingBookArm, buildOrder, painSummary, counterSummary, outcome, confidence, telemetryRefs]
```

Fields:

| Field | Type | Meaning |
|---|---|---|
| `openingBookArm` | string | The selected opening/strategy arm |
| `buildOrder` | array | `[[tSec, item, reason], ...]` |
| `painSummary` | array | Aggregate counts by area/source/counter, no UID |
| `counterSummary` | array | Counter evidence and response counts |
| `outcome` | array | Winner, duration, capture counts, score deltas |
| `confidence` | number | How representative the round is |
| `telemetryRefs` | array | AICOMSTAT event ids or seq ranges |

No UID-specific punishment, no raw player names, and no precise hidden unit positions are persisted.

### Stored aggregate keys

T2 aggregates are keyed by:

```text
[schema, mapKey, sideKey, profileKey, buildMajor, commanderMode, packVersion]
```

Where:

- `mapKey`: `CH`, `TK`, `ZG`, or future profile key.
- `sideKey`: `west`, `east`, `guer`.
- `profileKey`: internal V2 profile/weight key.
- `buildMajor`: build/cmdcon family to avoid learning across incompatible systems.
- `commanderMode`: `ai-vs-ai`, `human-west`, `human-east`, `mixed`.
- `packVersion`: knowledge pack schema version.

The following aggregate types and their key formats are recognized:

| Aggregate | Key | Value |
|---|---|---|
| Opening success | `open:<map>:<profile>:<side>:<bookId>` | `[samples, wins, medianTownDelta20, medianCaptureMinute, abandonRate]` |
| Counter-tech | `counter:<map>:<profile>:<enemyCategory>:<responseId>` | `[samples, successRate, medianTimeToCounter, lossDelta]` |
| Route outcome | `route:<map>:<profile>:<edgeId>` | `[samples, arrivedRate, medianElapsed, stuckRate, lossScore]` |
| Relocation outcome | `reloc:<map>:<profile>:<zoneId>` | `[samples, deployRate, abortRate, postRelocCaptureRate]` |
| Fire-support value | `support:<map>:<profile>:<supportKind>:<zoneId>` | `[samples, exploitRate, friendlyIncidentCount, wasteRate]` |

### Round-start prior application

T2 can adjust:

- Opening arm scores.
- Early research/build intent scores.
- Route/town risk priors.
- Counter confidence baseline by map/side/profile.
- Exploration slice selection weights.

T2 cannot:

- Force an attack on unseen enemies.
- Skip no-dead-air or crisis defense.
- Override map-profile hard constraints.
- Change group caps or GUER volume.
- Apply a learned delta outside clamps.

Prior application record:

```text
[priorId, sourcePackId, key, baseScore, learnedDelta, clampMin, clampMax, appliedDelta, confidence, reason]
```

Default clamps:

| Prior type | Max absolute delta |
|---|---:|
| Opening arm score | 0.15 |
| Counter prior | 0.20 |
| Route risk | 0.25 |
| Research/build intent | 0.15 |
| Relocation zone prior | 0.20 |
| Fire-support zone prior | 0.15 |
| Exploration choice weight | 0.08 |

Hard guards for aggregate application:

- Aggregates with `sampleCount < WFBE_C_AICOM_V2_LEARN_SAMPLE_FLOOR` are ignored.
- Aggregates with `generatedAt` older than `WFBE_C_AICOM_V2_LEARN_PACK_MAX_AGE_DAYS` are ignored, unless the pack is the compiled static pack embedded in the shipped profile.
- Any aggregate that would violate profile boundaries, superiority gates, no-psychic evidence, no-dead-air, or GUER volume preservation is ignored and logged as `reject=doctrine_guard`.

### Fallback behavior

If T2 is disabled or unavailable:

- Load static map profile.
- Log `PACK_LOAD` with `fallback=1`.
- Run T1 normally.
- Emit T1/T2 summary telemetry to RPT if adaptive flag is enabled.
- Do not block boot, planning, or round end.

## T3: Offline Meta-Learning

T3 converts many rounds into knowledge packs. It is offline by design so live SQF stays simple, deterministic, and explainable.

### BUILDORDER telemetry

Mission emits build-order events whenever the AI commander buys, researches, or commits to a production/tech intent.

Line shape:

```text
AICOMSTAT|v3|ADAPT|<side>|<min>|BUILDORDER|round=<roundKey>|t=<sec>|item=<item>|kind=<kind>|cost=<n>|reason=<reason>|evidence=<source>|pack=<packId>
```

Required fields:

| Field | Meaning |
|---|---|
| `side` | Canonical side string |
| `min` | AICOM minute tick |
| `round` | `round_key` if known, else `pending` until ingest assigns |
| `t` | Mission seconds |
| `item` | Stable item/tech/template key, not display text |
| `kind` | `unit`, `tech`, `structure`, `support`, `doctrine` |
| `cost` | Known cost or `-1` |
| `reason` | Stable reason code |
| `evidence` | Evidence id/source or `profileDefault` |
| `pack` | Active pack id or `static` |

Do not add `BUILDORDER` to WASPSTAT v1. Keep it as AICOMSTAT v3 so ingest ownership stays with AICOM.

### Offline mining inputs

Stats V2 joins:

- `matches` for winner, map/world, duration, ended_at, player_count.
- `match_events` for KILL/CAPTURE/ROUNDEND tempo and event ordering.
- `match_players` for side participation, not UID-specific AI grudges.
- AICOM append-only event table for adaptive, build-order, WHY, profile, watchdog, and visible-pulse lines.
- `waspscale_samples` for FPS and AI load guardrails.
- Soak ledger/lens outputs for candidate promotion health.

Derived features:

| Feature | Source | Use |
|---|---|---|
| Opening first 20 minutes | BUILDORDER, CAPTURE, KILL | Opening-book arm performance |
| First contact timing | CONTACT/FIRST, KILL, ASSAULT_DISPATCH | Tempo and no-dead-air scores |
| Counter effectiveness | Counter events, KILL categories, CAPTURE deltas | Counter-table priors |
| Route/town pain | Pain events, dogpile/capture_by_town, stranded events | Route risk priors |
| Spend pressure | BUILDORDER cadence, economy AICOM lines | Anti-hoard tuning |
| Stability | WATCHDOG, FPS, errors, lens verdicts | Promotion rejection |

### Knowledge pack format

Knowledge packs are versioned SQF data arrays stored inside map-profile files or loaded by the map profile loader. They are data-only and use A2/OA-safe primitives.

Top-level shape:

```text
[
  "AICOM_KP_V1",
  packId,
  mapKey,
  profileKey,
  generatedAtUtc,
  sourceWindow,
  sourceBuild,
  sourceSha,
  confidence,
  openingArms,
  counterTables,
  terrainHints,
  clamps,
  poison,
  promotion
]
```

Field definitions:

| Field | Type | Meaning |
|---|---|---|
| `packId` | string | Stable id, e.g. `kp-ch-balanced-20260704-001` |
| `mapKey` | string | `CH`, `TK`, `ZG`, future map key |
| `profileKey` | string | Internal V2 profile key |
| `generatedAtUtc` | string | UTC generation timestamp |
| `sourceWindow` | array | `[fromUtc, toUtc, matchCount, soakCount]` |
| `sourceBuild` | string | Build/cmdcon family |
| `sourceSha` | string | Source stats/ledger checksum from offline tool |
| `confidence` | number | 0.0 to 1.0 pack confidence |
| `openingArms` | array | Opening-book candidates |
| `counterTables` | array | Counter priors |
| `terrainHints` | array | Route/town risk priors |
| `clamps` | array | Max deltas and exploration caps |
| `poison` | array | Sample and outlier guard metadata |
| `promotion` | array | Promotion decision and rollback pointer |

Opening arm shape:

```text
[armId, sideKey, minSample, n, winRate, medianFirstCaptureSec, medianArrivalPct, medianFps, scoreDelta, exploreWeight, notes]
```

Counter table shape:

```text
[counterKey, sideKey, threatKey, minSample, n, successRate, lossReduction, scoreDelta, confidence, evidenceRule]
```

Terrain hint shape:

```text
[hintKey, areaKey, routeKey, minSample, n, riskDelta, avoidDelta, probeDelta, confidence, expiryClass]
```

Clamp shape:

```text
[key, minValue, maxValue, defaultValue, reason]
```

Poison metadata shape:

```text
[minMatches, minSoaks, maxSingleRoundWeight, outlierPolicy, decayHalfLifeDays, humanModeSplit, sideSplit, mapSplit]
```

Promotion shape:

```text
[status, promotedAtUtc, promotedBy, previousPackId, rollbackPackId, ledgerRefs, notes]
```

When embedded as a static array inside a map profile, the pack uses the same `AICOM_KP_V1` schema. Profile-embedded packs are exempt from the age-staleness cutoff (see T2 hard guards).

### Knowledge pack loader

At supervisor boot:

1. Load map profile through the normal profile loader.
2. Read the optional knowledge-pack array from profile field `adaptivePacks`.
3. Pick the newest pack matching `[schema, mapKey, profileKey, sideKey allowed]`.
4. Validate schema, version, pack id, map/profile match, clamp presence, and poison metadata.
5. If valid, store pack metadata in `wfbe_aicom_v2_adapt_pack`.
6. If missing/malformed, use static defaults.
7. Emit `PACK_LOAD`.

Loader event:

```text
AICOMSTAT|v3|ADAPT|<side>|0|PACK_LOAD|pack=<packId>|schema=AICOM_KP_V1|map=<mapKey>|profile=<profileKey>|fallback=<0/1>|confidence=<n>|source=<sourceSha>|reason=<reason>
```

### Poison resistance

Offline pack generation must enforce:

| Guard | Rule |
|---|---|
| Minimum sample | No promoted opening arm below 20 comparable matches or 5 accepted soaks |
| Single-round cap | One round contributes at most 10 percent of any promoted score |
| Outlier rejection | Drop rounds with severe script-error lens FAIL, FPS collapse, or known non-comparable build |
| Decay | Half-life 30 days unless owner approves a different baseline |
| Side split | WEST/EAST/GUER learned separately |
| Map split | CH/TK/ZG learned separately |
| Profile split | Internal V2 profiles learned separately |
| Human mode split | AI-vs-AI and human commander rounds do not mix by default |
| Winner bias clamp | Winning-side data cannot raise more than 0.15 without matching loss reduction evidence |
| Exploration reserve | Keep at least 5 percent of safe decisions available for exploration |

Pack rejection must be logged:

```text
AICOMSTAT|v3|ADAPT|<side>|0|PACK_REJECT|pack=<packId>|reason=<reason>|detail=<detail>
```

### Promotion gates

A pack can be promoted only when:

- Schema validates.
- Source window and checksums are recorded.
- Soak lens verdict is not FAIL.
- Performance remains within V2 acceptance bands.
- No watchdog restart regression.
- No psychic-decision analyzer failures.
- Opening/counter deltas are within clamps.
- A rollback pack id exists.

Promotion status:

| Status | Meaning |
|---|---|
| `candidate` | Generated by offline mining, not loaded by default |
| `soak` | Loaded only in soak farm candidate build |
| `promoted` | Default pack for map/profile |
| `rolledBack` | Kept for audit, not loaded |
| `rejected` | Kept for audit, not loaded |

## Required Constants

Register these only when implementing the feature, in `Common/Init/Init_CommonConstants.sqf`, default-off unless stated:

| Constant | Default | Meaning |
|---|---|---|
| `WFBE_C_AICOM_V2_ADAPTIVE` | `0` | Master lane-456 gate. Requires `WFBE_C_AICOM_V2_ENABLE > 0`. |
| `WFBE_C_AICOM_V2_LEARN_T1` | `1` | Allows within-round pure memory when adaptive gate is on. Safe because it is not persistent. |
| `WFBE_C_AICOM_V2_LEARN_T2` | `0` | Allows optional extension/database load/store. |
| `WFBE_C_AICOM_V2_LEARN_T3_PACKS` | `1` | Allows shipped static knowledge packs inside profiles. |
| `WFBE_C_AICOM_V2_LEARN_SAMPLE_FLOOR` | `12` | Minimum samples before a persistent aggregate affects planning. |
| `WFBE_C_AICOM_V2_LEARN_PACK_MAX_AGE_DAYS` | `45` | Staleness cutoff for non-compiled packs. |
| `WFBE_C_AICOM_V2_LEARN_EXPLORE_PCT` | `5` | Percent of equal-score decisions allowed to explore within doctrine gates. |
| `WFBE_C_AICOM_V2_LEARN_OPEN_CLAMP` | `0.15` | Opening-book prior clamp. |
| `WFBE_C_AICOM_V2_LEARN_ROUTE_CLAMP` | `0.25` | Route prior clamp. |
| `WFBE_C_AICOM_V2_LEARN_COUNTER_CLAMP` | `0.20` | Counter-tech prior clamp. |
| `WFBE_C_AICOM_V2_LEARN_SUPPORT_CLAMP` | `0.15` | Fire-support prior clamp. |

## AICOMSTAT V3 Adaptive Events

All adaptive events use the same family:

```text
AICOMSTAT|v3|ADAPT|<side>|<min>|<event>|key=value|key=value...
```

Side should use the V3 canonical lowercase side when feasible: `west`, `east`, `guer`, `unknown`.

### Event table

| Event | Purpose | Required fields |
|---|---|---|
| `PACK_LOAD` | Round-start pack selection | `pack`, `schema`, `map`, `profile`, `fallback`, `confidence`, `source`, `reason` |
| `T1_MEMORY_ADD` | New/updated pain memory | `id`, `area`, `source`, `loss`, `ttl`, `confidence`, `response` |
| `T1_MEMORY_DECAY` | Memory expired/decayed | `id`, `area`, `old`, `new`, `reason` |
| `T1_DECISION` | Adaptive decision applied | `decision`, `target`, `memory`, `source`, `confidence`, `delta`, `clamped`, `why` |
| `T2_PRIOR_APPLY` | Pack prior applied | `pack`, `prior`, `base`, `delta`, `applied`, `confidence`, `clamp` |
| `BUILDORDER` | Build/research/order item | `round`, `t`, `item`, `kind`, `cost`, `reason`, `evidence`, `pack` |
| `PACK_WRITE` | Round summary emitted | `round`, `pack`, `status`, `events`, `confidence`, `path` |
| `PACK_REJECT` | Pack rejected by loader/analyzer | `pack`, `reason`, `detail` |
| `EXPLORE` | Safe exploration choice | `decision`, `best`, `chosen`, `delta`, `reason`, `pack` |

`PACK_REJECT` reason codes: `sample_floor`, `stale`, `doctrine_guard`, `schema`, `parse`, `extension`. Every rejection must carry one of these codes so the analyzer can distinguish guard categories without free-text parsing.

### Analyzer regexes

Mechanical parser additions:

```python
RE_ADAPT = re.compile(
    r"AICOMSTAT\|v3\|ADAPT\|(?P<side>[^|]+)\|(?P<tick>\d+)\|(?P<event>[A-Z0-9_]+)\|?(?P<rest>.*)$"
)
RE_ADAPT_KV = re.compile(r"([A-Za-z_][A-Za-z0-9_]*)=([^|\r\n]*)")
RE_BUILDORDER = re.compile(
    r"AICOMSTAT\|v3\|ADAPT\|(?P<side>[^|]+)\|(?P<min>\d+)\|BUILDORDER\|(?P<body>.*)$"
)
```

Derived metrics:

| Metric | Computation | Acceptance use |
|---|---|---|
| `pack_load_count` | Count `PACK_LOAD` per side | Must be one per enabled side |
| `pack_fallback_count` | `PACK_LOAD fallback=1` | WATCH unless intentional test |
| `memory_add_count` | Count `T1_MEMORY_ADD` | Confirms T1 reacting |
| `memory_decision_ratio` | `T1_DECISION / T1_MEMORY_ADD` | Qualifying player events should get visible response >=50 percent |
| `psychic_adapt_count` | Decisions with missing/illegal source | Must be 0 |
| `prior_delta_max` | Max absolute `applied` | Must be within clamp |
| `explore_rate` | `EXPLORE / eligible decisions` | Must stay <= configured slice |
| `buildorder_count` | Count `BUILDORDER` | Required for T3 mining |
| `pack_write_status` | Last `PACK_WRITE status` | Must not block mission |

## Pure Data Contracts

### Adaptation input to planner

```text
["AICOM_ADAPT_PLAN_IN_V1", sideId, timeSec, activePack, t1Memory, priors, clamps, exploreState]
```

Where:

- `activePack = [packId, schema, confidence, sourceSha, fallback01]`
- `t1Memory = [painRecords, counterRecords, spendRecords, routeRecords]`
- `priors = [openingPriors, counterPriors, routePriors, buildPriors]`
- `clamps = [[key,min,max], ...]`
- `exploreState = [lastExploreSec, explorePct, eligibleCount, chosenCount]`

### Adaptation output from planner

```text
["AICOM_ADAPT_PLAN_OUT_V1", sideId, timeSec, applied, telemetry, writeHints]
```

Where:

- `applied` contains prior/pain/counter deltas actually used.
- `telemetry` contains event records for execution to log.
- `writeHints` contains summary counters for end-of-round persistence.

Execution, not planning, writes logs and namespace variables.

## Implementation Order

1. Add constants only:
   - `WFBE_C_AICOM_V2_ADAPTIVE = 0`
   - `WFBE_C_AICOM_V2_LEARN_T1 = 1`, `WFBE_C_AICOM_V2_LEARN_T2 = 0`, `WFBE_C_AICOM_V2_LEARN_T3_PACKS = 1`
   - T1 TTL/counter/explore clamps
   - Optional T2 persistence gate default `0`

2. Add T1 memory module:
   - Server-side only.
   - Pure append/update/decay helpers using arrays.
   - Unit-style pure tests outside Arma for add/decay/query.

3. Feed T1 from existing legal events:
   - Town capture/loss.
   - Friendly loss/category events.
   - V2 intel/contact when available.
   - No hidden scans.

4. Wire pure planner input:
   - Serialize memory into adaptation input record.
   - Apply score deltas inside clamps.
   - Add WHY evidence output.

5. Add AICOMSTAT v3 adaptive logs:
   - `PACK_LOAD`
   - `T1_MEMORY_ADD`
   - `T1_DECISION`
   - `BUILDORDER`
   - `EXPLORE`

6. Add RPT-first T2 summaries:
   - Emit `PACK_WRITE` summary at round end or round-close hook.
   - Do not require extension writes for first build.

7. Add offline pack generator:
   - Mine Stats V2 and soak ledger.
   - Generate `AICOM_KP_V1` arrays.
   - Validate poison guards.
   - Commit packs into map profile data after review.

8. Add optional extension read/write:
   - Only after new explicit `AICOM_ADAPT_*` extension contract exists.
   - Must nil guard like AntiStack and fall back like profile loader.
   - Use `WFBE_SE_FNC_AICOMV2_KnowledgeLoad` and `WFBE_SE_FNC_AICOMV2_KnowledgeStore` as the named entry points.

## Acceptance Criteria

### Spec acceptance for this lane

- This file exists at `docs/design/v2/aicom/SPEC-ADAPTIVE-COMMANDER.md`.
- It defines T1, T2, and T3.
- It names the current extension split and does not repurpose AntiStack.
- It specifies knowledge-pack format/versioning.
- It specifies poison resistance, exploration, and doctrine guardrails.
- It defines RPT/Stats V2 telemetry enough for mechanical analyzer work.

### Builder acceptance for T1 (pure-core)

- `WFBE_C_AICOM_V2_ADAPTIVE = 0` leaves mission behavior inert.
- With the flag enabled, T1 memory is server-owned and HC receives orders only.
- Pure tests cover memory add/update/decay/query and clamp application.
- A representative in-engine T2 smoke shows pain memory TTL around 900 seconds.
- Qualifying player-action events produce counter/avoid/probe decisions within TTL on at least 50 percent of eligible cases.
- WHY logs cite source and confidence for every adaptive combat decision.
- No hidden enemy state drives adaptive decisions.
- No A3-only lint failures or RPT script errors.

### Builder acceptance for T2 (local micro-soak)

- At boot, HC/server RPT contains one `KNOWLEDGE|LOAD` per side. If extension helpers are absent, it must be `fallback=1|reject=extension` and the commander continues.
- Missing extension/DB produces static fallback and `PACK_LOAD fallback=1`, not a boot failure.
- At least one `BUILDORDER` line appears for each side that builds or researches.
- Round summary writes are append-only.
- No UID-specific punishment persists.
- Priors apply only within clamps.
- Active pack id appears in every round-start and adaptive decision summary.
- No `WATCHDOG|KPI_FLATLINE` repeats after adaptive hints are applied.
- `PLAN|CHANGE` churn remains within the acceptance harness PASS band.
- `WHY` lines for adapted decisions include `pack=<packId>` and `seen=1` when they depend on intel.
- If a live extension path is added, nil/malformed/timeout cases are tested.

### Builder acceptance for T3 (box soak)

Run as overnight farm comparison pairing each adaptive run with one same-map V2 no-learning baseline:

- PASS if captures/hour is not worse by more than 5%, target churn remains PASS/WATCH, FPS parity remains within the harness band, and `PACK_REJECT|reason=doctrine_guard` is zero for accepted decisions.
- FAIL if persistent knowledge causes unseen-target decisions, more than two supervisor restarts, GUER volume suppression, or sustained bank growth while losing ground.
- Offline pack generator records source window, checksums, sample counts, and promotion status.
- Packs are A2/OA-safe arrays.
- Packs are map/profile/side/build scoped.
- Poison guards reject under-sampled or non-comparable candidates.
- Soak farm validates candidate pack before promotion.
- Rollback pack id is recorded.
- Analyzer reports pack load, adaptive decisions, exploration rate, and prior delta max.

## Open Risks

| Risk | Mitigation |
|---|---|
| Current `a2waspwarfare_Extension` only has `GLOBALGAMESTATS` | Use RPT-first T2 until explicit adaptive extension exists |
| AntiStack DB procedure namespace is unrelated | Do not reuse or overload AntiStack procedures |
| Pack learning could overfit one odd round | Minimum samples, single-round cap, outlier rejection, decay |
| Adaptive response could feel psychic | Require evidence id/source on every counter, analyzer must flag missing source |
| Exploration could look random | Exploration limited to safe non-crisis decisions and logged with score delta |
| RPT spam from memory updates | Always-on only for state changes; verbose dumps behind existing logging convention |
| Future profiles become personalities | Keep profiles internal weight sets and enforce doctrine guardrails |

## Done

Adaptive Commander is ready for the Fable build burst when a builder can implement T1 from the pure data contracts, wire T2 as RPT-first summaries without touching AntiStack, and generate T3 `AICOM_KP_V1` packs from Stats V2/soak data without asking what the schema, clamps, poison gates, or fallback behavior should be.
