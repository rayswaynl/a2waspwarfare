# Utes Invasion Rotation And Stats Integration

Lane: 433
Status: final-form integration spec, no gameplay code
Scope: map rotation, match reporting, and telemetry requirements
Binding guide: AGENTS.md GUIDE-REV GR-2026-07-03a

## Integration Intent

Utes Invasion should enter V2 as a fourth, flagged map variant with enough telemetry to prove whether amphibious play works. It must not silently change current rotation behavior, stats schemas, or map assumptions while disabled.

## Rotation Contract

Recommended flag: `WFBE_C_V2_UTES_INVASION`

When flag is `0`:

- Utes is not eligible for production rotation.
- No Utes-specific map rules initialize.
- No beachhead stat keys are emitted.
- No fleet-supply modifiers apply.

When flag is `1`:

- Utes can be included as a fourth map candidate.
- Rotation metadata identifies it as asymmetric/amphibious.
- Match setup uses the Utes-specific ruleset.
- Match reporting includes Utes-specific fields.

## Rotation Metadata

Recommended metadata fields:

| Field | Value |
| --- | --- |
| map_key | `utes_invasion` |
| terrain | `utes` |
| mode_family | `warfare_v2` |
| variant | `asymmetric_amphibious` |
| attacker_start | `offshore_fleet` |
| defender_start | `island_control` |
| required_flag | `WFBE_C_V2_UTES_INVASION` |
| naval_source | `Init_NavalHVT.sqf` live LHD reuse |
| prior_art | `crcti_WARFARE_03.utes.pbo`, Oden Warfare16 `airAssault.sqf` |

## Match Report Fields

Additive fields only. Do not break existing report consumers.

| Field | Type | Meaning |
| --- | --- | --- |
| `map_variant` | string | `utes_invasion` |
| `attacker_side` | side/string | Side assigned offshore fleet start |
| `defender_side` | side/string | Side assigned island defense |
| `first_landing_lane` | string/null | First selected/used lane |
| `first_landing_time_s` | number/null | Seconds from mission start to first dismount/contact |
| `first_beachhead_open_time_s` | number/null | Seconds to first attacker-open beachhead |
| `airfield_capture_time_s` | number/null | First attacker capture of airfield |
| `beachheads_opened_count` | number | Count of attacker-open events |
| `beachheads_lost_count` | number | Count of attacker beachhead losses |
| `boat_wave_count` | number | Launched attacker boat waves |
| `boat_wave_fail_count` | number | Waves failed by stuck/destroyed/no dismount |
| `fleet_supply_generated` | number | Fleet reserve/supply generated |
| `shore_supply_delivered` | number | Supply delivered through open beachheads |
| `all_beachheads_closed_time_s` | number/null | First reset moment after attacker had opened one |

## Stats Questions To Answer

The first build should produce enough data to answer:

- Does attacker AI reach shore without player help?
- Which landing lanes fail most often?
- How long does the defender take to contest first landing?
- Does first beachhead opening predict match outcome too strongly?
- Does airfield capture happen too early, too late, or not at all?
- Is fleet supply too generous without beachhead control?
- Are boat-wave failures creating invisible match losses?

## Event Timeline

Recommended event order:

| Event | Required? | Notes |
| --- | --- | --- |
| Map variant initialized | Yes | Always-on once flag-on Utes starts |
| Fleet/LHD staging initialized | Yes | Must cite live naval source in implementation docs |
| Landing lane selected | Yes | Include lane ID |
| Boat wave launched | Yes | Include wave type |
| Wave dismounted | Yes | Time-to-shore |
| Wave failed | Yes | Reason key |
| Beachhead contested | Yes | Objective ID |
| Beachhead opened | Yes | Starts/changes supply |
| Beachhead lost | Yes | Stops/reduces supply |
| Airfield contested/captured | Yes | Midgame marker |
| Defender HQ threatened | Recommended | Useful for outcome correlation |

## Dashboard/Visible UX Requirements

Dashboards and admin panels are first-class deliverables per Steff workflow. The builder should make Utes visible in operations surfaces without turning this sprint into UI work.

Minimum visible signals:

- Map variant name.
- Current beachhead states.
- Open shore supply status.
- Boat wave failure count.
- Airfield owner.

Avoid visible explanatory text walls in the game UI. For admin/reporting, dense tables are acceptable.

## Compatibility Constraints

- Existing CH/TK/ZG match reports must continue to parse.
- New fields should be nullable or omitted outside Utes.
- No field should require A3-only classnames or commands.
- No stats path should depend on direct live-server deployment.
- No PR should omit GUIDE-REV GR-2026-07-03a.

## Done Criteria For Builder

- Utes is flag-gated in rotation.
- Match reports identify `utes_invasion`.
- Beachhead and boat-wave events are visible in logs/stats.
- Existing map reports remain backward compatible.
- Stats prove whether A2 boat workaround is functioning.
