# Quad AI Commander

Quad AI Commander is a proposed command-layer system for Wasp Warfare. The idea is to let individual commanders, squads, scripts, and intel sources write operational logs, then have an AI commander read those logs to build a shared picture of the fight and issue believable orders.

Instead of giving the AI perfect direct knowledge of every unit, the system uses reports, stale sightings, rumors, and scripted intel entries. That makes the AI feel like a battle staff working from imperfect information.

## Core Loop

1. Field commanders and systems write short log entries.
2. A parser extracts contacts, locations, timestamps, unit counts, confidence, and source names.
3. A shared context store merges matching reports and tracks uncertainty.
4. The AI commander plans responses from the context store.
5. Orders are dispatched back to commanders, squads, or support systems.
6. New field results create more logs, continuing the loop.

Example field logs:

```text
[BLUEFOR-C1][12:04] Spotted OPFOR armor near Gorka, approx 5 units.
[BLUEFOR-C2][12:06] Heavy fire heard north of Gorka.
[BLUEFOR-C1][12:08] Lost visual. Enemy likely moving east.
```

Example interpreted contact:

```json
{
  "side": "OPFOR",
  "type": "armor",
  "location": "Gorka",
  "count_estimate": 5,
  "confidence": 0.78,
  "last_seen": "12:04",
  "sources": ["BLUEFOR-C1"],
  "trend": "possible movement east"
}
```

Example AI orders:

```text
[BLUEFOR-HQ][12:09] C2 hold position and observe east road.
[BLUEFOR-HQ][12:09] C1 pull back 300m and mark target zone.
[BLUEFOR-HQ][12:10] Mortar team prepare fire mission on Gorka crossroads.
```

## Log Types

The AI commander can consume several classes of logs:

- `FIELD`: direct commander or squad observations.
- `CONTACT`: structured enemy sighting reports.
- `INTEL`: scripted or semi-scripted information that can expose hidden state in a believable way.
- `ORDER`: commands issued by HQ or subordinate commanders.
- `RESULT`: outcome logs after an order is executed.
- `LOSS`: casualties, lost vehicles, destroyed assets, or broken contact.

## Believable Intel Hooks

The log system can deliberately expose useful hidden context without making the AI feel omniscient. These entries should be fuzzy, partial, and source-labeled.

```text
[INTEL-FUZZY][12:03] Radio traffic suggests OPFOR command activity near Gorka.
[DRONE-PARTIAL][12:05] Thermal blobs detected in tree line, count uncertain.
[CIV-RUMOR][12:06] Locals report tracked vehicles moving through Gorka.
```

This gives the commander enough signal to act while preserving uncertainty.

## Suggested Data Model

Each detected contact could be tracked as a belief rather than as perfect truth.

```json
{
  "id": "contact-gorka-001",
  "side": "OPFOR",
  "category": "armor",
  "location_name": "Gorka",
  "position": [9610, 8790, 0],
  "count_min": 3,
  "count_max": 6,
  "confidence": 0.78,
  "first_seen": "12:04",
  "last_seen": "12:08",
  "sources": ["BLUEFOR-C1", "DRONE-PARTIAL"],
  "status": "unconfirmed-moving-east"
}
```

## Commander Behaviors

The first implementation should focus on a small set of clear behaviors:

- Combine nearby reports into a single contact belief.
- Lower confidence as reports age.
- Ask for confirmation when confidence is low but threat is high.
- Dispatch scouts or nearby squads to observe likely enemy movement.
- Redirect defenders toward threatened towns.
- Prepare artillery, mortar, or air support only when confidence and priority justify it.
- Log every decision so players can understand why orders were issued.

## Implementation Notes

A practical first version could be implemented as an SQF-friendly structured log pipeline:

- Use a central array or namespace variable for pending logs.
- Normalize each log into a compact contact or event object.
- Periodically merge logs into a commander context store.
- Run the commander planner on a fixed interval, such as every 30-60 seconds.
- Emit orders as structured records that existing commander or squad systems can consume.

The system should start as advisory or debug-visible before it controls major combat behavior. That makes it easier to tune without destabilizing normal warfare flow.

## Open Questions

- Which commanders or systems should be allowed to write logs?
- How much hidden state should scripted intel expose?
- Should AI orders be mandatory, weighted suggestions, or player-visible recommendations?
- How long should stale reports remain actionable?
- Should each side have separate context, or should neutral intel feed both sides differently?
