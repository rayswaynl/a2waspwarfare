# Utes Invasion Attacker AI Doctrine

Lane: 431
Status: final-form AI doctrine spec, no gameplay code
Scope: amphibious attacker behavior and A2 boat-AI workaround strategy
Binding guide: AGENTS.md GUIDE-REV GR-2026-07-03a

## Doctrine Summary

The attacker wins by converting offshore initiative into a durable beachhead, then turning that beachhead into control of the airfield and settlements. The AI must not be asked to improvise amphibious operations. It should choose from validated landing indexes, execute bounded waves, dismount quickly, and shift to normal land behavior once ashore.

The user-verified prior-art pattern is Oden Warfare16 `airAssault.sqf`: an island-index air-assault pattern that works around A2 boat AI limitations by selecting known island/landing indexes instead of relying on free-form boat navigation. The builder must extract and adapt the pattern, not hand-roll dynamic beach discovery.

## Attacker Operating Principles

- Pick a landing lane from a fixed index.
- Launch in waves, not continuous trickle.
- Dismount infantry as soon as the lane reaches the beach anchor.
- Push inland immediately after capture starts.
- Treat boats as transport, not as combat units.
- Route supply through beachhead ownership state.
- Switch to normal Warfare land behavior after the airfield/road network is secured.

## Landing Index Model

Recommended conceptual fields:

| Field | Purpose |
| --- | --- |
| lane ID | Stable behavior/log key |
| offshore start | Where the wave begins |
| approach point | Keeps route aligned with coast |
| dismount point | Where troops leave craft |
| rally point | First infantry grouping point ashore |
| beachhead objective | Capture/supply target |
| inland push objective | Next objective after beachhead |
| fallback lane | Alternate if lane is blocked/stuck |

The builder must derive exact fields from the extracted Oden prior art and current mission conventions.

## Wave Types

| Wave | Composition goal | Trigger | Objective |
| --- | --- | --- | --- |
| Probe | Small infantry/recon | Match start or lane uncertainty | Detect beach resistance, avoid overcommitting |
| Assault | Infantry plus light support | Selected lane is viable | Capture beachhead |
| Security | Infantry/AT/AA as available in current mission economy | Beachhead contested/open | Hold capture radius and route |
| Supply | Logistics/repair/ammo equivalent if supported | Beachhead open | Enable sustained island fight |
| Exploit | Infantry/vehicle push | Beachhead stable | Push runway or nearest settlement |

No new vehicle/classname should be introduced unless already mission-valid.

## Lane Selection

Initial scoring should prefer:

1. Beachhead not currently interdicted.
2. Short path to airfield or road hub.
3. Lower defender concentration.
4. Valid dismount terrain.
5. Prior successful wave on same lane.

Lane selection should penalize:

- Recent boat stuck/failure.
- Active defender QRF at surf line.
- Beachhead capture radius under heavy fire.
- No follow-up supply available.

The first implementation can use deterministic preferred order plus simple failure fallback. It does not need a complex planner.

## Post-Dismount Behavior

Once ashore, attacker AI should immediately stop behaving like boat passengers.

Required transition:

| State | Behavior |
| --- | --- |
| Dismounted at beach | Move to rally point, orient inland |
| Beachhead contested | Capture and clear immediate cover |
| Beachhead open | Assign security group and route group |
| Route secured | Push runway/settlement objective |
| Beachhead lost | Either retake locally or fall back to fleet for next lane |

The most important implementation detail is to avoid leaving AI clustered at the boat/dismount point.

## Boat Failure Handling

Because A2 boat pathing is fragile, each wave needs a bounded failure model:

| Failure | Recovery |
| --- | --- |
| Boat stuck offshore | Timeout, delete/recover wave according to mission-safe cleanup pattern, mark lane penalized |
| Boat misses dismount anchor | Use nearest safe dismount only if validated; otherwise fail closed |
| Beachhead capture impossible | Commit one security wave, then switch lane |
| Boat destroyed before dismount | Count loss, delay next wave, avoid instant replacement spam |

No recovery should create infinite boat spawning or unbounded AI groups.

## Airfield Push

After one beachhead is open, the attacker should treat the airfield as the decisive midgame target unless the owner chooses a different objective order.

Recommended logic:

- West/South beachhead open: push runway first.
- East/Strelka beachhead open: push Strelka first if defender resistance is light; otherwise cut toward runway.
- Multiple beachheads open: reserve one group for beach security, commit the rest to runway.

## Player Interaction

Player-led landing should be allowed to outperform AI but not be required for the scenario to function.

AI must be able to:

- Select one lane.
- Land one wave.
- Capture one beachhead.
- Move inland.
- Attempt a second wave.

That is the minimum viable amphibious loop.

## Anti-Patterns

- Do not send boats to arbitrary map-click positions.
- Do not rely on boat crews to fight the island battle.
- Do not spawn replacement boats with no loss budget or delay.
- Do not keep all AI aboard until a perfect waypoint is reached.
- Do not switch to helicopter-only invasion unless owner explicitly approves abandoning the amphibious premise.
- Do not use `forceFollowRoad`, `findIf`, `pushBack`, `params`, or other A3-only conveniences.

## Done Criteria For Builder

- At least one AI attacker wave reaches and dismounts at a validated Utes beach.
- A failed lane is penalized or recovered without infinite spawns.
- Attacker can open beachhead supply when the beachhead is captured.
- Attacker transitions from shore to runway/settlement behavior.
- The Oden island-index prior-art pattern is cited in code comments/docs where adapted.
