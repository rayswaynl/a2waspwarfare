# Utes Invasion Amphibious Prior-Art Catalog

Lane: 434
Status: final-form research report, no gameplay code
Scope: archive-mandate catalog for amphibious Utes implementation
Binding guide: AGENTS.md GUIDE-REV GR-2026-07-03a

## Archive Mandate Compliance

This catalog preserves the required prior-art sources named by the owner/orchestrator and converts them into builder obligations. The local archive path `E:\arma2-cache` could not be read in this session because the Windows sandbox failed before shell startup and the Node REPL failed before execution. Therefore this report clearly separates:

- User-verified prior-art facts.
- Builder extraction requirements.
- Design decisions that can be made now.
- Claims that must not be coded until the archive/live files are inspected.

## Catalog Summary

| Source ID | Source | Evidence status in this session | User-verified lesson | Builder use |
| --- | --- | --- | --- | --- |
| UTI-PA-01 | `E:\arma2-cache\crcti_WARFARE_03.utes.pbo` | Not locally readable here | Contains Utes boat spawns and beach capture points | Extract exact beach/boat coordinate dataset |
| UTI-PA-02 | Oden Warfare16 `airAssault.sqf` | Not locally readable here | Contains island-index air-assault pattern; needed as A2 boat-AI workaround | Adapt indexed landing selection and failure model |
| UTI-PA-03 | Live `Init_NavalHVT.sqf` | Not locally readable here; GitHub path/search did not expose it | Existing LHD carrier code is the naval implementation to reuse | Extract classnames/composition/lifecycle before coding |
| UTI-PA-04 | Public Utes overview map | Web image search visible | Kamennyy north, Strelka east/southeast, central runway, roads, forests, offshore islets | Validate terrain role model; not a substitute for editor coordinates |

## UTI-PA-01: crcti_WARFARE_03.utes.pbo

Known from user directive:

- It is a verified prior-art source.
- It contains boat spawns.
- It contains beach capture points.
- It targets Utes.

Builder extraction checklist:

- Unpack PBO using the local archive password/context provided by owner: `pw armedassault`.
- Locate mission files defining boat spawns.
- Locate markers/triggers/logic defining beach capture points.
- Record exact world coordinates, marker names, side ownership assumptions, and any waypoint chains.
- Identify whether boats spawn as empty vehicles, crewed vehicles, or grouped transport assets.
- Identify whether capture points are normal town logic, custom trigger zones, or marker-only objectives.
- Identify whether the mission uses static beach ownership or dynamic front-line behavior.

Expected design use:

- Replace approximate `UTI-LZ-*` and `UTI-PORT-*` anchors with extracted coordinates.
- Preserve beach capture intent, not necessarily exact old mission economy.
- Prefer known-working Utes beaches over visually tempting beaches that trap AI.

Do not copy:

- Unknown side economy wholesale.
- Old mission scripts without A2 OA 1.64 trap review.
- Any classname not present in current WASP mission tree/config proof.

## UTI-PA-02: Oden Warfare16 airAssault.sqf

Known from user directive:

- It contains an island-index air-assault pattern.
- That pattern is the intended A2 boat-AI workaround.

Interpretation:

The valuable design is not "use aircraft instead of boats." The valuable design is indexed insertion: pick from known island/landing entries, route through validated anchors, and avoid asking AI to solve open-ended water navigation.

Builder extraction checklist:

- Identify the island index data shape.
- Identify how the script chooses an island/landing target.
- Identify how it validates or retries failed insertions.
- Identify how groups transition from transport behavior to infantry behavior.
- Identify cleanup behavior for failed transport.
- Identify any A3-incompatible syntax if the source has been modified over time.

Expected design use:

- Convert Utes landing lanes into fixed indexes.
- Use deterministic lane fallback before adding complex scoring.
- Add bounded failure handling for stuck/destroyed/no-dismount waves.
- Preserve fast dismount and immediate inland rally behavior.

Do not copy:

- Helicopter-only assumptions if they undermine amphibious premise.
- Dynamic destination selection that was not proven on Utes water.
- Any code shape that violates AGENTS.md A2 OA hard-stop traps.

## UTI-PA-03: Live Init_NavalHVT.sqf

Known from user directive:

- It is the live LHD carrier code.
- Utes Invasion should reuse it.

Builder extraction checklist:

- Record exact path and revision used.
- Record all LHD/carrier classnames.
- Record object composition, offsets, direction, and placement assumptions.
- Record marker names and missionNamespace variables.
- Record destruction/scoring/HVT lifecycle.
- Record cleanup and respawn behavior.
- Record side assumptions.

Expected design use:

- Treat the LHD/fleet as attacker staging in Utes.
- Reuse existing carrier composition and lifecycle where possible.
- Keep Utes map behavior flag-gated.

Open owner question:

- Should the LHD be destructible/scorable in Utes Invasion, or should it be protected infrastructure for the first implementation pass?

Recommended default:

- Protected attacker infrastructure in first implementation pass. Destructible/scorable carrier is a separate balance feature.

## UTI-PA-04: Public Utes Map Evidence

Observed from public Utes overview image:

- Kamennyy is north/north-central.
- Strelka is east/southeast on the coast.
- A runway/airfield spans the central/southern island.
- Roads connect Kamennyy, the airfield area, and Strelka.
- Forest patches and minor elevations create ambush terrain.
- Offshore islets/rocks exist to northwest and southeast.

Use:

- Supports the terrain role model in `terrain-dataset.md`.
- Helps name zones and objective roles.

Limit:

- Not acceptable for final exact coordinates.
- Not a replacement for A2/OA editor validation.

## Prior-Art To Implementation Traceability

| Design decision | Prior-art dependency |
| --- | --- |
| Fixed beachhead list | `crcti_WARFARE_03.utes.pbo` beach capture points |
| Fixed boat spawn/approach anchors | `crcti_WARFARE_03.utes.pbo` boat spawns |
| Indexed amphibious AI lanes | Oden Warfare16 `airAssault.sqf` island-index pattern |
| Bounded boat failure handling | Oden pattern plus A2 boat-AI limitation |
| LHD/fleet staging | Live `Init_NavalHVT.sqf` |
| No new naval classnames without proof | AGENTS.md classname rule |

## Builder Stop Conditions

Stop and ask owner/orchestrator before coding if:

- `crcti_WARFARE_03.utes.pbo` cannot be unpacked.
- Oden Warfare16 `airAssault.sqf` cannot be located.
- Live `Init_NavalHVT.sqf` cannot be read.
- Utes exact beach coordinates cannot be validated in the A2/OA editor.
- The current LHD code is incompatible with Utes water placement.
- The owner wants destructible carrier scoring in the first pass.

## Final Prior-Art Requirement

No Utes Invasion gameplay PR should be opened until its PR body can truthfully state:

- The exact crCTI Utes boat spawn/capture data was extracted.
- The Oden island-index insertion pattern was reviewed.
- The live LHD carrier code was reviewed and reused or intentionally wrapped.
- GUIDE-REV GR-2026-07-03a is cited.
