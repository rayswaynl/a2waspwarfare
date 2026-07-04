# Utes Invasion Defender AI Doctrine

Lane: 430
Status: final-form AI doctrine spec, no gameplay code
Scope: island defender behavior for asymmetric amphibious map
Binding guide: AGENTS.md GUIDE-REV GR-2026-07-03a

## Doctrine Summary

The defender wins by preventing the attacker from turning a beach landing into a supply network. It does not need to annihilate every landing craft. It needs to delay capture, keep internal roads open, and counterattack beachheads at the moment the attacker is stretched between shore and runway.

The defender must feel local and reactive, not omniscient. It should react fastest near known coastal watch points, slower from the opposite side of the island, and hardest around the airfield and HQ sector.

## Starting Posture

| Defender element | Initial area | Purpose |
| --- | --- | --- |
| Coastal watch squads | Near likely beachheads, not directly on surf line | Detect and delay first wave |
| Kamennyy garrison | North settlement | Hold northern road anchor |
| Strelka garrison | East/southeast settlement | Hold eastern anchor and port-side road |
| Airfield reserve | Central runway/interior | Main QRF and mobility defense |
| HQ guard | Interior/HQ sector | Prevent early command snipe |
| GUER/local patrols if enabled | Woods, road edges, minor coast points | Add friction without reducing defender role |

Do not put every defender on the beach. The first wave should be dangerous but not an instant spawn camp.

## Reaction Doctrine

Defender reactions should be event-driven:

| Trigger | Defender response | Max scope |
| --- | --- | --- |
| Boat/landing detected near closed beach | Coastal squad delays, nearest QRF prepares | Local coast and nearest road |
| Beachhead contested | Airfield reserve or nearest town sends QRF | One reserve group first, not all groups |
| Beachhead captured | Counterattack within short delay | Nearest two nodes |
| Airfield threatened | Prioritize runway defense over remote beach | Island-wide defender focus |
| Kamennyy/Strelka isolated | Attempt corridor reopening | Adjacent road chain |
| Defender HQ threatened | Pull reserve, not all garrisons | HQ plus nearest objective |

The defender should not instantly know a decoy landing on the far side of Utes unless a patrol detects it or the beachhead enters contested/captured state.

## QRF Priorities

Recommended priority order:

1. Defender HQ under direct threat
2. Airfield contested or attacker-owned
3. Open attacker beachhead with active supply
4. Strelka or Kamennyy contested
5. Closed beach under harassment
6. Decoy/recon landing with no beachhead progress

Rationale: if the defender over-prioritizes boats, the scenario becomes a shoreline shooting gallery. If it under-prioritizes beachheads, the attacker snowballs before the map becomes a fight.

## Beach Counterattack Pattern

A beach counterattack should use three rings:

- Ring 1: local coastal patrol delays dismount.
- Ring 2: nearest town squad pushes to the capture radius edge.
- Ring 3: airfield reserve attacks the attacker route between beachhead and runway.

This prevents the defender from simply piling into the beach marker and getting farmed by offshore support. It also gives the attacker a real route-security problem.

## Airfield Defense Pattern

The airfield is the defender's decisive midgame position.

Behavior:

- Keep a reserve near but not on the runway centerline.
- Defend approaches from west and south beachheads.
- If Strelka is still held, use it as a lateral support route.
- If Kamennyy is still held, use it as a northern fallback and counterattack source.
- If the airfield falls, shift doctrine from beach denial to HQ defense and town recapture.

## GUER/Resistance Behavior

If Resistance/GUER is enabled:

- Use it to create patrol pressure in woods and minor roads.
- Do not cap its output for comfort.
- Do not let it replace defender QRF.
- Let it harass both sides if consistent with current mission behavior.
- Avoid putting GUER on deterministic beach spawn-kill positions.

GUER is most valuable when it makes routes uncertain, not when it is a static wall.

## Anti-Patterns

- Do not script omniscient defender teleportation to every landing.
- Do not spawn all defender groups on the beach.
- Do not make the airfield irrelevant by giving every beach equal full supply.
- Do not require defender boats unless prior-art extraction proves they work.
- Do not use A3-only commands or behavior assumptions.
- Do not change HC ownership or JIP enrollment to support this doctrine.

## Required Logs/Stats Hooks

Builder should add always-on state transition logs for:

- First landing detected.
- First beachhead contested.
- First beachhead opened.
- Airfield contested.
- Defender reserve committed.
- Defender HQ threatened.

Verbose value dumps, if any, must follow existing `WF_LOG_CONTENT` policy from AGENTS.md.

## Done Criteria For Builder

- Defender reacts locally to at least three landing lanes.
- Defender can retake an open beachhead.
- Defender does not abandon HQ and airfield for every boat contact.
- GUER remains pressure, not a capped nuisance.
- No behavior depends on A3-only SQF commands.
