# Utes Invasion Naval Infrastructure Port Map And Gaps

Lane: 429
Status: final-form design report, no gameplay code
Scope: naval/LHD reuse contract, port-map, and implementation gaps
Binding guide: AGENTS.md GUIDE-REV GR-2026-07-03a

## Source Of Truth

The live mission naval source of truth is:

`Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_NavalHVT.sqf`

The user directive identifies this as the LHD carrier code to reuse. This research session could not open the local file because the Windows sandbox failed before shell startup, and GitHub path/search did not expose the file on the queried branch. Therefore this report does not invent exact LHD classnames, deck offsets, object arrays, markers, cleanup rules, or HVT lifecycle details.

Builder rule: every implementation claim below that touches naval objects must be rechecked against the live file before code is written.

## Naval Design Boundary

Utes Invasion needs naval infrastructure for three different jobs:

1. Attacker staging
2. Landing-wave transport
3. Supply throughput after beachhead capture

Only the first job should be based on the existing LHD/carrier implementation. The second and third jobs should consume that staging state but not rewrite the LHD system.

## Port Map

| Port ID | Name | Type | Owner at start | Role | Must derive from |
| --- | --- | --- | --- | --- | --- |
| UTI-PORT-01 | LHD/Fleet Staging | Offshore carrier/fleet | Attacker | Attacker HQ-adjacent sea start, aircraft/boat launch origin | Live `Init_NavalHVT.sqf` |
| UTI-PORT-02 | West Beachhead Inlet | Temporary shore inlet | Defender/neutral | Main attacker supply after capture | Utes editor + crcti prior art |
| UTI-PORT-03 | South Beachhead Inlet | Temporary shore inlet | Defender/neutral | Alternate supply and second-wave entry | Utes editor + crcti prior art |
| UTI-PORT-04 | Strelka/East Inlet | Risky shore inlet | Defender/neutral | Pressure near Strelka, late supply option | Utes editor + crcti prior art |
| UTI-PORT-05 | Northwest Recon/Decoy Inlet | Non-supply shore point | Neutral/defender | Patrol, decoy, small infantry raid only | Utes editor + crcti prior art |

## LHD Reuse Requirements

The builder must inspect live `Init_NavalHVT.sqf` and document:

- Existing object classnames and composition.
- Existing spawn position and orientation model.
- Existing marker naming and public state variables.
- Existing cleanup/destruction behavior.
- Existing HVT scoring or mission-objective side effects.
- Existing assumptions about map size and water depth.

Reuse rules:

- Do not duplicate carrier composition logic.
- Do not add a second source of truth for LHD classnames.
- Do not change existing CH/TK/ZG behavior when Utes flag is off.
- Keep Utes-specific port data in a map-specific dataset or config block.
- If the LHD HVT is currently a target, define whether Utes uses it as target, base, or both before coding.

Recommended owner decision: in Utes Invasion, the LHD is attacker infrastructure, not a defender target in the first implementation pass. If it is destructible/scorable, that should be a separate explicit owner-approved balance choice.

## Landing-Wave Infrastructure

A2 boat AI cannot be trusted to solve beach insertion from arbitrary offshore positions. Use indexed lanes.

Required data per landing lane:

| Field | Purpose |
| --- | --- |
| `lane_id` | Stable stats/logging key |
| offshore spawn anchor | Where boat/wave begins |
| approach waypoint | Keeps boat pointed at correct coast |
| dismount anchor | Where infantry leaves boat |
| beachhead objective | Ownership gate and supply inlet |
| fallback lane | Alternate if current lane blocked |
| stuck timeout | AI recovery condition |

No code is specified here. The builder should translate this data into the local mission pattern after extracting Oden Warfare16 `airAssault.sqf`.

## Known Infrastructure Gaps

| Gap ID | Gap | Impact | Required builder action |
| --- | --- | --- | --- |
| UTI-GAP-01 | Live LHD file not extracted in this sprint | Exact reuse surface unknown | Inspect `Init_NavalHVT.sqf` before coding |
| UTI-GAP-02 | Utes beach coordinates not extracted from archive | Port positions approximate | Extract from `crcti_WARFARE_03.utes.pbo` |
| UTI-GAP-03 | Boat pathing reliability unknown per beach | AI waves may stall offshore | Use Oden island-index pattern and add stuck recovery |
| UTI-GAP-04 | Supply throughput values not present in current map set | Economy can swing too hard | Start conservative and log throughput |
| UTI-GAP-05 | LHD destruction/scoring role ambiguous | Could create unfair sudden-loss condition | Owner decision before enabling scoring |
| UTI-GAP-06 | Beachhead UI/marker distinction absent | Players may confuse beachheads with towns | Add marker taxonomy in builder phase |

## Recommended Initial Naval Topology

The safest first implementation is:

- One attacker offshore staging box.
- One active primary landing lane at match start.
- Two unlockable alternate lanes.
- Three beachhead inlets total.
- No autonomous boat route discovery.
- No carrier relocation during match.
- No fleet supply while all beachheads are closed.

This keeps the scenario readable and avoids overloading A2 AI with dynamic amphibious planning.

## Validation Plan For Builder

- Confirm LHD composition spawns correctly on Utes water and is not intersecting terrain.
- Confirm attacker can spawn, board, launch, and dismount without player intervention.
- Confirm one boat-stuck case recovers or fails closed within a bounded time.
- Confirm each beachhead ownership state changes supply state.
- Confirm flag-off leaves CH/TK/ZG and normal naval HVT behavior unchanged.
- Confirm all classnames used by naval assets exist in mission tree/config proof.
