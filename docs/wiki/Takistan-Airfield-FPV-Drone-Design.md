# Takistan Airfield FPV Drone Design

> July update planning note for Steff's Takistan captured-airfield FPV drone concept. This page records owner answers from the 2026-06-05 questionnaire and keeps the implementation scope separate from shipped source until the DEV branch is implemented and smoked.

## Status

| Field | Value |
| --- | --- |
| Planning lane | `july-takistan-airfield-fpv-drone` |
| DEV branch | `dev/july-takistan-airfield-fpv-drone` |
| Release target | July update candidate |
| Terrain scope | Takistan first |
| Gameplay source changed by this note | No |
| Required authority posture | Server-authoritative spawn, purchase, caps, ownership and range validation |

## Source Anchors

- Maintained Takistan has two `LocationLogicAirport` objects in `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/mission.sqm`: one around `8191,1803`, one around `5689,11181`.
- `Common/Init/Init_Airports.sqf` currently creates the hangar model and local yellow airport marker for each airport logic. It does not create side ownership or capture state.
- Existing UAV support is not a sufficient authority model for this feature: current stable UAV spawn and spend are mostly client-owned, while the wiki's drone branch lessons call out server-side validation as the safer path.
- EASA is useful as a progression/loadout inspiration, but the actual drone buy path should use a separate Drone Bay menu unless a future owner deliberately extends generated EASA data.

## Decided Design

### Capture And Ownership

- Both Takistan airfields start neutral.
- The runway should not be blocked by the capture object. Replace the first-pass "middle of runway" idea with an owner-placed capture building or marker near the runway start/edge, so drones and aircraft can still use the runway.
- A nearby bunker/camp is required before drone buying unlocks.
- Captured airfields do not affect victory conditions.
- Normal aircraft hangar buying should not require airfield ownership in this first version.
- Captured airfields should provide extra team income: `$50` per player, every economy cycle. The exact target account still needs an implementation decision: side funds, team funds or distributed player funds.

### Drone Access

- Any player on the owning side can buy a drone.
- No commander approval is required.
- Purchases use player funds.
- One active drone per player.
- Add a side-wide active drone cap.
- Losing the airfield disables new purchases only; already-active drones continue until destroyed, range-killed or expended.
- One underused class should get a drone discount, likely recon/scout. The exact class name, discount and UI hint are still owner decisions.

### Range And Counterplay

- Drones have a hard center-map boundary.
- Drones are destroyed or forced down when they exceed the allowed area.
- Drones cannot damage HQ/base structures or main-base assets.
- Small arms should not be the reliable counter.
- AA/static AA/radar should reveal, warn about or counter drones.
- Enemy launch warning is not required.

### Tiers And Unlocks

| Tier | Owner intent | Notes |
| --- | --- | --- |
| Tier 1 | Recon drone | Cheap camera/scout drone, no warhead. |
| Tier 2 | Light HE drone | Anti-infantry/light-vehicle role. |
| Tier 3 | AT drone | Expensive, capped armor threat. |
| Anti-air | Excluded | FPV drones should not directly counter aircraft or helicopters. |

Unlock policy:

- UAV research is required before any airfield drone can be bought.
- EASA level gates drone payload/tier options.
- Use a dedicated Drone Bay menu instead of normal EASA UI.

## Implementation Shape

Recommended architecture:

1. Add Takistan airfield objective metadata for the two existing airport logics.
2. Add a server-owned airfield ownership state, separate from normal town victory state.
3. Add runway-edge capture object placement and one capture bunker/camp per airfield.
4. Add a Drone Bay client menu that only sends a request, not trusted final state.
5. Add server request handling that re-derives player, side, funds, upgrades, airfield ownership, active caps and requested drone tier.
6. Spawn the drone server-side, track owner/player/side/airfield/tier, and publish only the state needed for clients.
7. Enforce range and base-protection rules server-side.
8. Add AA/radar counter behavior after the basic spawn/range lifecycle works.

Do not simply graft this onto the current client-owned UAV spawn path. A prototype may reuse presentation pieces, but the final July candidate should validate effect and spend server-side.

## LOC Estimate

| Scope | Estimate | Risk |
| --- | --- | --- |
| Rough prototype | ~350-700 LOC | Fast, but easy to inherit client-authority and balance problems. |
| July-quality Takistan-only version | ~1000-1800 LOC plus `mission.sqm` object edits | Better fit for public-server balance; requires dedicated/JIP smoke. |
| Shared Takistan/Chernarus airfield-objective module | ~1400-2400 LOC plus map-specific object edits | Better long-term, but larger July scope. |

## Open Owner Decisions

- Exact runway-edge capture placement for both Takistan airfields.
- Exact bunker/camp object class and position near hangars.
- Whether `$50 per player every cycle` means side funds, team funds or per-player payout.
- Side-wide active cap number.
- Recon/scout class identifier and discount amount.
- Drone classnames and weapon/magazine classnames for each tier.
- Boundary geometry: strict center line, polygon per airfield, or radius clipped to center.
- AA/radar counter implementation: reveal marker, warning tone, automatic damage, lock-on behavior or forced signal loss.

## Validation Gate

- Takistan boot smoke with both airfields neutral at start.
- Capture smoke for runway-edge point and bunker/camp.
- JIP smoke: late joiner sees correct ownership, markers, bunker state and Drone Bay availability.
- Economy smoke: captured airfield grants the intended `$50` per player per cycle and stops on loss.
- Upgrade smoke: UAV gate blocks all drones; EASA gates payload tiers.
- Purchase smoke: funds debit once, one-drone-per-player and side cap hold under repeated requests.
- Authority smoke: invalid side, invalid airfield, insufficient funds, invalid tier and out-of-range requests fail server-side.
- Range smoke: crossing the center boundary destroys or forces down the drone.
- Protection smoke: HQ/base structures cannot be damaged by drone effects.
- Counterplay smoke: AA/radar counter works without global enemy launch warning.

## Continue Reading

- [Support specials and tactical modules](Support-Specials-And-Tactical-Modules-Atlas)
- [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas)
- [Towns, camps and capture atlas](Towns-Camps-And-Capture-Atlas)
- [Server authority migration map](Server-Authority-Migration-Map)
- [Content structure and maps](Content-Structure-And-Maps)
