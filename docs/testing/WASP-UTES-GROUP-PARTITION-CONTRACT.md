# Utes equal-work group-partition contract

> **LAB ONLY — DO NOT MERGE OR DEPLOY.** This contract measures server-local synthetic groups. It does not authorize a production team-size change and does not prove HC-owned AICOM behavior.

## Question

At the same realized infantry exposure, how does changing the number of independently simulated groups affect server FPS and route completion?

The screen changes one coupled dimension: group partition. Unit count, map, source/lab hashes, measurement duration, route anchors, vehicle count, process topology, parameters and host configuration remain fixed.

## Registered arms

The primary screen uses 240 requested infantry and two fixed 120-unit spawn anchors:

| Arm | Groups x infantry | Requested infantry per anchor |
|---|---:|---:|
| `density-4` | 60 x 4 | 120 |
| `density-6` | 40 x 6 | 120 |
| `density-8` | 30 x 8 | 120 |
| `density-10` | 24 x 10 | 120 |
| `density-12` | 20 x 12 | 120 |

Every arm explicitly sets `vehicleEvery=0`, `expectedHcs=0`, `busRate=0` and `schedulerMode=off`. A bus or scheduler load would introduce another coupled dimension, so both the builder and aggregator reject it. A 12-member arm is an upper-bound lab observation, not a blanket production recommendation.

The confirmation screen uses 360 infantry and three fixed 120-unit anchors:

```text
90x4  60x6  45x8  36x10  30x12
```

Use the builder's safe `--groups` and `--units-per-group` overrides. The builder rejects a target that cannot be divided into equal unit work per fixed anchor.
The 240-unit/two-anchor screen and 360-unit/three-anchor confirmation are the only registered totals; a 120-unit one-anchor run is not buildable or aggregate-eligible.

## Runtime barrier

Each run must emit the complete phase sequence:

```text
SPAWN -> SETTLE -> GO -> MEASURE -> CLEANUP
```

Groups are materialized during `SPAWN`, remain unordered during `SETTLE`, and receive their first path/combat order only at `GO`. Measurement counters and exposure integrals reset at `GO`; pre-GO ramp differences are not benchmark samples. A run without the barrier or a complete `RESULT` is not eligible for the partition aggregate.

## Realized-work gates

Requested template tokens are not accepted as proof of work. The controller records, per group and cumulatively:

- requested and created infantry;
- created crew and vehicles;
- final group-member histogram;
- underfilled, oversized and failed groups;
- realized members per fixed anchor;
- post-GO member-seconds and group-seconds;
- route identities, legs started and arrivals.

The dedicated `group_partition.py` aggregator is intentionally separate from `compare.py`. The generic comparer remains strict and should continue warning when scenario, target-group or units-per-group fields differ.

A screening aggregate requires at least three complete `PASS` runs for every 4/6/8/10/12 arm. The `--min-repetitions` option may raise that floor but cannot lower it. It requires the exact Utes three-town topology and rejects mixed source/lab/git/partition contracts, any rejected input, nonzero vehicles, creation failures, oversized groups, bus or scheduler load, missing/non-finite/out-of-range numeric START evidence, a batch size outside the registered `5/4/3/2/2` arm mapping, incomplete per-group evidence, misidentified or unequal anchor work, less than 98% target member/group exposure, exposure above the exact target by more than one sampling interval, member-seconds outside the registered 3% equivalence band, or cleanup evidence other than exactly zero objects and zero groups remaining. The independently derived `REALIZED` evidence must contain one valid row for every group ID `1..targetGroups`; its metric sums, histogram and anchor maps must exactly match the cumulative composition. Phase-scoped `MEASURE` sample counters must be present and monotonic, sample counts must reconcile, and the final `RESULT` work totals may advance beyond the last sample by no more than one sample interval. Route records must reconcile with their cumulative starts/completions, and arrival units cannot exceed completed groups times the declared arm size, before outcomes are normalized by exposure; raw leg counts are expected to change with group count.

## Interpretation

- One valid run is an observation.
- Three balanced repetitions per arm are a screen, not a production conclusion.
- A stronger claim needs the campaign's six-run balanced block and a current-Chernarus confirmation.
- Never add a group-partition delta to HC, Common_Send, scheduler, allocator, affinity or native-extension estimates.
- Reject an apparent FPS gain when it comes with less realized work, worse route outcomes, incomplete cleanup or protocol contamination.

Editor load/save and dedicated cold boots with 0/1/2 HCs remain mandatory qualification gates for the generated Utes asset before any runtime campaign.
