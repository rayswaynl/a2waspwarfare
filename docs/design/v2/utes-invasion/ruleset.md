# Utes Invasion Ruleset Spec

Lane: 427
Status: final-form design spec, no gameplay code
Scope: owner-approved asymmetric amphibious fourth map for WASP Warfare V2
Binding guide: AGENTS.md GUIDE-REV GR-2026-07-03a

## Design Intent

Utes Invasion is an asymmetric amphibious Warfare scenario built around one attacking force arriving from the sea and one defending force already holding the island. It is not a symmetric town-chain conversion of Chernarus, Takistan, or Zargabad. The first fifteen minutes must feel like an invasion problem: secure a landing lane, survive coastal fire, bring supply ashore, then widen the lodgement before the defender can collapse onto it.

The scenario is designed as a fourth rotation map, not a replacement ruleset. It must remain flag-gated and inert when disabled.

## Non-Negotiables

- No gameplay code in this sprint deliverable.
- No Arma 3 syntax, systems, commands, or assumptions.
- No direct edits to Takistan or Zargabad mirrors.
- No live deployment.
- No HC architecture, player enrollment, JIP, deploy script, or box script changes.
- No GUER output caps or nerfs. If Resistance/GUER is active on Utes, volume is a pressure source, not a problem to suppress.
- Every naval implementation claim in the builder phase must be verified against the live `Common/Init/Init_NavalHVT.sqf` LHD carrier code before code is written.
- Any new classname must already exist in the mission tree or be backed by config proof.

## Feature Flag Contract

Recommended flag: `WFBE_C_V2_UTES_INVASION`

Default: `0`

Flag-off requirement: byte-identical mission behavior to current HEAD. The map must not enter normal rotation, stats, AI planning, supply economy, naval spawn setup, or special-case UI when the flag is `0`.

Flag-on behavior:

- Utes becomes an eligible rotation map.
- The attacker starts from offshore fleet/LHD staging.
- The defender starts with island control and shorter internal supply lines.
- Beachheads become first-class operational objectives.
- The economy uses fleet supply and beachhead throughput instead of ordinary full-map parity.

## Faction Roles

Primary attacker: WEST/BLUFOR unless owner directs otherwise.

Primary defender: EAST/OPFOR unless owner directs otherwise.

Independent/GUER role:

- Optional island friction force, patrol network, or local militia pressure.
- Must not replace the defender.
- Must not be capped to make the island easier.
- Should create uncertainty around flank roads, forests, and rear-area beachheads.

Reasoning: keeping WEST as the sea attacker matches player expectation for LHD reuse and avoids turning the LHD into a defender-only island object. EAST holding the island gives the scenario a readable invasion frame without requiring lore work.

## Victory Structure

Victory should combine normal Warfare town control with two Utes-specific gates:

1. Beachhead control
2. Island command collapse

Recommended decisive objective set:

| Objective | Role | Victory weight |
| --- | --- | --- |
| Primary beachhead | First attacker lodgement | Required for sustained attacker supply |
| Secondary beachhead | Redundant landing route | Strongly weighted |
| Utes airfield | Mobility and reinforcement hub | Decisive midgame objective |
| Kamennyy | Northern settlement anchor | Town-control weight |
| Strelka | Eastern settlement and port-side anchor | Town-control weight |
| Defender HQ zone | End-state target | Ends defender island integrity when destroyed/captured |

Attacker victory should not require every minor point if the defender HQ and main island command nodes are broken. Defender victory should not require sinking every boat if the attacker cannot hold a beachhead and supply ashore.

## Match Phases

### Phase 0: Setup

- Attacker HQ/fleet staging is offshore and protected from immediate land rush.
- Defender HQ is inland or on the airfield-side interior, not directly on a beach.
- Initial towns and coastal posts are defender-held.
- Beachhead objectives are neutral or defender-held, depending on implementation simplicity.

### Phase 1: Forced Entry

Attacker requirements:

- Launch landing craft/boats or scripted transport waves from fleet staging.
- Seize at least one beachhead.
- Land enough infantry and light logistics to survive the first counterattack.

Defender requirements:

- Detect the selected landing lane.
- Use coastal patrols and QRFs, not omniscient map-wide reaction.
- Delay supply arrival more than farming boat kills.

### Phase 2: Lodgement Expansion

Attacker requirements:

- Convert the beachhead into a supply inlet.
- Push to the airfield or nearest road hub.
- Open a second beachhead if the first becomes contested.

Defender requirements:

- Counterattack over short internal roads.
- Keep at least one route between Kamennyy, Strelka, and the airfield usable.
- Raid beachhead supply rather than idling in towns.

### Phase 3: Island Fight

Attacker requirements:

- Break island mobility by taking the airfield.
- Cut defender reinforcement loops.
- Drive toward defender HQ.

Defender requirements:

- Preserve HQ, airfield, and one settlement chain.
- Use interior terrain to force short, repeated engagements.
- Recapture exposed beachheads when attacker overextends.

## Beachhead Rules

Beachheads are not normal towns. They are amphibious logistics gates.

Required properties:

- Small capture radius.
- Clear side ownership state.
- Adjacent safe-ish dismount area.
- Road or track connection into the island.
- Supply throughput value.
- AI-readable landing index.

Recommended beachhead states:

| State | Meaning | Economy effect | AI effect |
| --- | --- | --- | --- |
| Closed | Defender or neutral control | No attacker shore supply | Attacker selects as assault target |
| Contested | Units from both sides nearby | Reduced or paused throughput | Both sides commit local QRF |
| Open | Attacker controls and no enemy pressure | Normal shore throughput | Attacker may route follow-up waves |
| Interdicted | Attacker owns but enemy fire/marker pressure present | Reduced throughput | Attacker sends security, defender raids |

## LHD And Fleet Reuse Contract

The builder must reuse the live LHD carrier/naval HVT implementation rather than creating a parallel carrier system. The source of truth is `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_NavalHVT.sqf` or its current live equivalent.

This spec intentionally does not name exact LHD object classes, deck offsets, or spawn logic because the local file was unavailable in this research session. The builder must extract those from the live file before coding.

Minimum reuse expectations:

- Use the existing LHD composition/classnames exactly as mission-proven.
- Keep current HVT lifecycle semantics unless owner approves a different scenario role.
- Do not create duplicate carrier cleanup, marker, or spawn ownership systems.
- Keep naval HVT code path separable from Utes map rules so flag-off is inert.

## Balance Targets

The attacker receives:

- Safer initial spawn.
- Fleet-based first wave.
- Stronger initiative.
- Limited shore throughput until beachhead capture.
- Longer reinforcement cycle if beachhead is lost.

The defender receives:

- Initial island control.
- Interior roads.
- Faster early QRF.
- Better knowledge of terrain.
- Vulnerability to losing the airfield and coastal supply nodes.

Balance is not equal starting conditions. Balance is whether both sides have credible winning lines.

## Done Criteria For Builder

- Flag-off behavior is byte-identical to HEAD.
- Utes can run as a fourth map without changing CH/TK/ZG semantics.
- Attacker can reach shore without depending on unreliable free-roaming boat AI.
- Defender reacts to beachheads without omniscient full-map teleport behavior.
- Beachhead ownership changes are visible in logs/stats.
- Naval object behavior is validated against live `Init_NavalHVT.sqf`.
- PR body cites GUIDE-REV GR-2026-07-03a.
