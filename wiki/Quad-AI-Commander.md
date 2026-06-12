# Quad AI Commander

Quad AI Commander is a proposed AI battle staff layer for Wasp Warfare. It lets commanders and support systems write operational logs, then uses those logs to build a shared tactical context and issue believable orders.

The goal is not perfect AI knowledge. The goal is an AI commander that acts from reports, uncertainty, stale sightings, and partial intelligence.

## Current Implementation Status

The integration is staged, not complete:

1. #14 `feat/ai-commander` provides the execution substrate: supervisor states, order executor, town assignment, production, upgrades, and hybrid human/AI command.
2. #18 `codex/ai-commander-logs` adds Phase 1 structured logs, but remains draft until #14 runtime proof and branch graph refresh are complete.
3. #19 `codex/ai-commander-context` adds Phase 2 advisory contact beliefs, but remains draft until #18 is refreshed and proven.
4. Phase 3 planner priorities and Phase 4 worker biasing are specified, but should not drive behavior until the earlier evidence gates pass.

Use `docs/quad-ai-commander-long-term-goal-prompt.md` as the durable handoff for future implementation work. Use `docs/quad-ai-commander-integration-tracker.md` and `docs/quad-ai-commander-runtime-validation.md` for the current gate order and runtime proof requirements.

## Basic Idea

Commanders log what they see:

```text
[BLUEFOR-C1][12:04] Spotted OPFOR armor near Gorka, approx 5 units.
[BLUEFOR-C2][12:06] Heavy fire heard north of Gorka.
[BLUEFOR-C1][12:08] Lost visual. Enemy likely moving east.
```

The AI commander turns those logs into context:

```text
Contact: OPFOR armor
Location: Gorka
Strength: approx 5 units
Confidence: high
Last seen: 12:04-12:08
Trend: possible movement east
```

Then HQ can issue orders:

```text
[BLUEFOR-HQ][12:09] C2 hold position and observe east road.
[BLUEFOR-HQ][12:09] C1 pull back 300m and mark target zone.
[BLUEFOR-HQ][12:10] Mortar team prepare fire mission on Gorka crossroads.
```

## Why Logs

Logs make the system readable and tunable. Players, mission makers, and developers can inspect what the AI believed and why it acted.

They also allow controlled information leaks. Scripts can add fuzzy intel that helps the AI without making it feel like it is cheating.

```text
[INTEL-FUZZY][12:03] Radio traffic suggests OPFOR command activity near Gorka.
[DRONE-PARTIAL][12:05] Thermal blobs detected in tree line, count uncertain.
[CIV-RUMOR][12:06] Locals report tracked vehicles moving through Gorka.
```

## Suggested Flow

1. Units, commanders, and intel scripts write logs.
2. A parser extracts contacts, locations, counts, timestamps, and source names.
3. A context store merges reports into contact beliefs.
4. Confidence decays over time as reports become stale.
5. The AI commander chooses actions from the current beliefs.
6. Orders and results are written back into the log stream.

## Contact Belief Example

```json
{
  "side": "OPFOR",
  "type": "armor",
  "location": "Gorka",
  "count_estimate": 5,
  "confidence": 0.78,
  "last_seen": "12:04",
  "sources": ["BLUEFOR-C1", "INTEL-FUZZY"],
  "recommended_action": "contain_or_strike"
}
```

## First Version Scope

A small first implementation could support:

- field sighting logs
- fuzzy scripted intel logs
- contact merging by nearby location and type
- confidence decay for stale reports
- basic HQ orders for scout, defend, attack, retreat, or support fire
- debug-visible decision logs

## Design Notes

The commander should prefer useful uncertainty over perfect truth. Contradictory reports, stale sightings, and unsure enemy counts are features, not problems. They make the battlefield feel alive and give the AI room to behave like a real commander instead of a simple waypoint script.
