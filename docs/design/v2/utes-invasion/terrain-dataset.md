# Utes Invasion Terrain Dataset

Lane: 428
Status: final-form dataset spec, no gameplay code
Scope: Utes island objective and landing-area dataset for later implementation
Binding guide: AGENTS.md GUIDE-REV GR-2026-07-03a

## Evidence Status

Primary direct local evidence could not be opened in this session because the Windows sandbox failed before shell startup and the Node REPL failed before execution. The dataset below is therefore a builder-ready planning dataset based on:

- User directive that `crcti_WARFARE_03.utes.pbo` contains verified Utes boat spawns and beach capture points.
- User directive that Oden Warfare16 `airAssault.sqf` contains the island-index pattern needed as the A2 boat-AI workaround.
- Public Utes overview map evidence showing Kamennyy in the north, Strelka in the east/southeast, a central runway/airfield, offshore islets, roads, forests, and coastal approach lanes.

Builder must replace approximate map-grid anchors with exact editor/world coordinates during implementation.

## Terrain Model

Utes is small enough that one bad landing can decide the match, but large enough to support three simultaneous problems:

1. Shore entry
2. Airfield control
3. Settlement/road control

The map should be treated as a compact island with a central runway, a north settlement, an east/southeast settlement, wooded interior pockets, and several usable but uneven beaches. The important design property is not total landmass; it is that every route from shore to objective is short enough for defender QRF but exposed enough for attacker naval/air staging to matter.

## Strategic Zones

| Zone ID | Name | Role | Approximate map area | Terrain character | Gameplay use |
| --- | --- | --- | --- | --- | --- |
| UTI-Z01 | Offshore fleet box | Attacker start | Offshore west/southwest or southeast, outside direct town fire | Sea staging | LHD/fleet spawn, first-wave launch, protected logistics seed |
| UTI-Z02 | Northwest rocks/islets | Flank and patrol space | Northwest offshore | Small islands/rocks, broken coast | Recon, decoy landings, patrol routes |
| UTI-Z03 | Kamennyy | Northern settlement anchor | North/north-central island | Buildings, road fork, mild elevation | Defender early anchor, attacker midgame town |
| UTI-Z04 | Central runway/airfield | Decisive mobility hub | Central/southern interior | Long open runway, sparse cover | Midgame objective, air/vehicle hub |
| UTI-Z05 | Strelka | Eastern settlement anchor | East/southeast coast | Coastal village, road bend, shoreline | Port-side objective, defender fallback or attacker second lodgement |
| UTI-Z06 | Southwest wooded coast | Main landing candidate | Southwest coast below runway | Mixed woods, shore, short route to runway | Primary beachhead option |
| UTI-Z07 | South/southeast cove | Secondary landing candidate | South or southeast coast | Open shore and smaller approaches | Secondary beachhead, pressure on Strelka |
| UTI-Z08 | Interior woods/ridges | Ambush belt | Between runway, settlements, and coasts | Trees, elevation pockets | GUER patrols, defender ambush, attacker cover |

## Objective Dataset

Use these objective definitions as the first implementation pass. Exact positions must be set from the mission editor, not guessed from this markdown.

| Objective ID | Display name | Type | Initial owner | Strategic purpose | Capture radius guidance |
| --- | --- | --- | --- | --- | --- |
| UTI-OBJ-01 | Fleet Staging | Attacker staging | Attacker | Spawn and logistics origin; not a normal town | Not capturable by normal town logic |
| UTI-OBJ-02 | West Beachhead | Beachhead | Defender or neutral | Primary landing lane to runway | Small; only beach and immediate dismount |
| UTI-OBJ-03 | South Beachhead | Beachhead | Defender or neutral | Alternate landing lane, less direct to settlements | Small; avoid covering the runway |
| UTI-OBJ-04 | East/Strelka Beachhead | Beachhead | Defender or neutral | Risky landing near settlement | Small; coastal edge only |
| UTI-OBJ-05 | Kamennyy | Town | Defender | Northern road anchor | Normal Utes town radius |
| UTI-OBJ-06 | Strelka | Town | Defender | Eastern road/port anchor | Normal Utes town radius |
| UTI-OBJ-07 | Utes Airfield | HVT/town hybrid | Defender | Central mobility and escalation objective | Larger than beachhead, smaller than wide town |
| UTI-OBJ-08 | Defender HQ Sector | HQ pressure zone | Defender | End-state command collapse | Implementation-specific |

## Landing Candidate Dataset

| Landing ID | Beachhead target | Approach vector | Advantages | Risks | AI route notes |
| --- | --- | --- | --- | --- | --- |
| UTI-LZ-WEST | West Beachhead | From offshore west/southwest | Short path to runway, room for multiple waves | Predictable, exposed to interior counterattack | Use indexed assault route; avoid free-roam boat search |
| UTI-LZ-SOUTH | South Beachhead | From offshore south | Useful second lane, can threaten runway flank | Open ground after landing | Needs immediate infantry dispersion waypoint |
| UTI-LZ-EAST | East/Strelka Beachhead | From offshore east/southeast | Direct pressure on Strelka | Close to defender town fire | Use only after recon or as diversion unless player-led |
| UTI-LZ-NW | Northwest rocks/islets | From offshore northwest | Decoy/recon, harassment | Poor vehicle throughput | Not primary supply route |

## Road And Movement Dataset

| Route ID | Connects | Role | Vulnerability |
| --- | --- | --- | --- |
| UTI-R01 | West Beachhead to runway | Attacker first expansion route | Defender can counter from runway/interior woods |
| UTI-R02 | South Beachhead to runway | Alternate expansion route | Open approach, easy to interdict |
| UTI-R03 | Runway to Kamennyy | North-south island control | Key defender reinforcement route |
| UTI-R04 | Runway to Strelka | Eastward control route | Becomes decisive after airfield capture |
| UTI-R05 | Kamennyy to Strelka via interior road chain | Defender lateral route | If broken, defender becomes pocketed |

## Terrain Constraints For Builder

- Do not place the defender HQ directly on the shoreline.
- Do not let a single beachhead capture radius overlap the runway objective.
- Do not make offshore staging capturable through normal town logic.
- Do not require boat AI to dynamically discover valid beaches.
- Use explicit landing indexes derived from prior art and editor validation.
- Keep beachhead markers visually distinct from normal town markers.
- Keep capture counts small; Utes cannot support Chernarus-scale objective density.

## Dataset Completion Checklist

Before code:

- Extract exact boat spawn and beach capture coordinates from `crcti_WARFARE_03.utes.pbo`.
- Extract exact island-index behavior from Oden Warfare16 `airAssault.sqf`.
- Open Utes in the A2/OA editor and record world coordinates for every `UTI-OBJ-*` and `UTI-LZ-*`.
- Validate that each landing dismount point has enough flat ground for infantry and light vehicles.
- Validate that AI can move from each beachhead to the nearest road without a pathing trap.
- Confirm no coordinate is copied from an A3 Utes/Stratis/other-map source.
