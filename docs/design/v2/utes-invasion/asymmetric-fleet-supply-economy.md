# Utes Invasion Asymmetric Fleet-Supply Economy

Lane: 432
Status: final-form economy spec, no gameplay code
Scope: supply, income, and reinforcement asymmetry for Utes Invasion
Binding guide: AGENTS.md GUIDE-REV GR-2026-07-03a

## Economy Intent

Utes Invasion should not use symmetric full-map supply parity at match start. The attacker has fleet staging and initiative, but poor throughput until a beachhead opens. The defender has island towns, roads, and shorter reinforcement loops, but loses strategic depth quickly if the airfield and beachheads fall.

The economy should make shore logistics the central question:

- Can the attacker keep enough supply flowing through a beachhead to expand?
- Can the defender interdict the beachhead without abandoning the island interior?

## Core Economy Objects

| Object | Owner at start | Function |
| --- | --- | --- |
| Fleet staging | Attacker | Initial spawn, launch, limited offshore supply reserve |
| Beachhead inlet | Defender/neutral | Converts to attacker supply throughput when open |
| Airfield | Defender | Mobility/economy multiplier once captured |
| Kamennyy | Defender | Town income/control node |
| Strelka | Defender | Town income/control node |
| Defender HQ sector | Defender | Command continuity and reinforcement anchor |

## Supply Model

Recommended first-pass supply states:

| State | Attacker fleet supply | Attacker shore supply | Defender supply | Intended pressure |
| --- | --- | --- | --- | --- |
| No beachhead open | Limited reserve only | None | Normal island income | Attacker must land, cannot turtle offshore forever |
| One beachhead open | Reserve plus low shore throughput | Low | Normal, unless nearby town lost | Attacker can hold but not flood island |
| Two beachheads open | Moderate | Moderate | Reduced local control | Attacker has credible expansion |
| Airfield captured | Moderate/high | Moderate/high | Strategic penalty | Attacker can sustain island fight |
| All beachheads lost | Reserve only | None | Recovery window | Defender can reset invasion momentum |

Do not make fleet staging an infinite full-income base. That removes the beachhead problem.

## Throughput Guidance

Use relative values rather than hard numbers until builder can compare current mission economy constants.

| Source | Suggested relative throughput |
| --- | --- |
| Fleet reserve without beachhead | Low and time-limited |
| One open beachhead | 25-40 percent of normal mature base flow |
| Two open beachheads | 50-70 percent of mature base flow |
| Beachhead plus airfield | 75-100 percent of mature base flow |
| Contested beachhead | 0-50 percent of that beachhead's value |
| Interdicted beachhead | Reduced but not always zero |

Exact values must be tuned after a soak pass.

## Defender Economy

The defender starts with island economy but should not become unbeatable by simply waiting.

Defender strengths:

- Initial town income.
- Short reinforcement loops.
- Airfield control.
- Road network control.

Defender penalties:

- Losing the airfield reduces mobility and/or reinforcement tempo.
- Losing both Kamennyy and Strelka isolates HQ.
- Losing two beachheads gives attacker supply parity.

Avoid sudden all-or-nothing defender collapse unless HQ is destroyed/captured through existing Warfare logic.

## Attacker Economy

Attacker strengths:

- Protected offshore start.
- First-wave initiative.
- Ability to choose landing lane.
- Fleet reserve to recover from one failed wave.

Attacker limitations:

- No full shore economy until a beachhead opens.
- Boat/landing losses should matter.
- Repeated failed waves should delay next assault.
- Beachhead loss should cut shore throughput.

## Supply Events

Recommended event taxonomy:

| Event ID | Meaning | Stats/log use |
| --- | --- | --- |
| UTI-SUP-01 | First fleet wave launched | Measures opening tempo |
| UTI-SUP-02 | First beachhead contested | Measures defender detection |
| UTI-SUP-03 | Beachhead opened | Starts shore throughput |
| UTI-SUP-04 | Beachhead interdicted | Reduces throughput |
| UTI-SUP-05 | Beachhead lost | Cuts throughput |
| UTI-SUP-06 | Airfield captured | Economy/mobility escalation |
| UTI-SUP-07 | All beachheads closed | Attacker reset pressure |

## Anti-Farm Controls

Controls should prevent resource exploits without suppressing combat:

- Boat losses have replacement delay.
- Failed AI waves do not instantly respawn.
- Fleet reserve cannot generate full late-game income offshore.
- Beachhead throughput pauses/reduces when contested.
- Defender cannot farm endless supply from neutral beachhead markers.

Do not implement hard GUER caps as an anti-farm measure.

## Integration Points

Builder must locate current mission economy hooks before coding. Likely affected surfaces:

- Town income calculation.
- Side supply pools.
- Vehicle/unit purchase availability.
- AI commander purchase tempo.
- Match report/stat output.
- Map rotation eligibility.

No code path should run for CH/TK/ZG when `WFBE_C_V2_UTES_INVASION` is `0`.

## Done Criteria For Builder

- Attacker cannot sustain a full island war without at least one open beachhead.
- Defender has a meaningful recovery window after closing all beachheads.
- Capturing the airfield matters economically or operationally.
- Supply state changes are logged and exported to stats.
- Economy values are configurable/tunable without editing core logic everywhere.
