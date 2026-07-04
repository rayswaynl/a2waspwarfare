# AICOM Near-Target Allocation Bias Status Audit - 2026-07-03

Lane: fleet lane 90, docs-only status audit
Base checked: `origin/claude/build84-cmdcon36@b1608b096eb4a02d7c213d794e22b8bc59df8df0`

## Scope

The prompt row asks for F5 near-target allocation bias: prefer targets inside
roughly 2000m because the source analysis measured much better arrival rates on
shorter legs than on 2000m+ legs.

This pass checks current target-branch source and records status only. It does
not edit mission source because the allocator is a hot AICOM surface and the
existing implementation appears to cover the lane.

## Verdict

Lane 90 is already implemented on the checked target, and the current target has
it default-on.

The prompt row says "Flag-gated default 0", but the checked target defines:

- `WFBE_C_AICOM_NEAR_BAND = 1`
- `WFBE_C_AICOM_NEAR_BAND_DIST = 2000`
- `WFBE_C_AICOM_NEAR_BAND_BONUS = 300`

The inline source comment records this as a `cmdcon43 Ray-approved flip-ON`, so
the current state is not merely a dormant flag.

The behavior is implemented as a fist-builder score bonus. The allocator
computes each candidate town's distance to the nearest owned town, falls back to
HQ distance if there are no owned towns, and adds the near-band bonus when the
candidate is within the configured 2000m band. That re-ranks which towns enter
the fist; it does not create a separate eligibility rule or a second per-team
nearest-pick heuristic after the fist has already been chosen.

## Evidence

| Surface | Current target evidence | Status |
| --- | --- | --- |
| Motivation | `docs/design/AICOM-UNIT-BEHAVIOR-FABLE.md:23-24` records arrival rates by leg length: 500-2000m did better than 2000m+, and `:100-101` names F5 as near-target allocation bias. | Documented |
| Handoff context | `docs/MORNING-HANDOFF-2026-07-02.md:101-107` records Ray's wave-2 decisions and says near-targets should carry the armies through GUER-held terrain. | Documented |
| Near-band constants | `Common/Init/Init_CommonConstants.sqf:533-538` documents and defines `WFBE_C_AICOM_NEAR_BAND=1`, `WFBE_C_AICOM_NEAR_BAND_DIST=2000`, and `WFBE_C_AICOM_NEAR_BAND_BONUS=300` in Chernarus, vanilla Takistan, and vanilla Zargabad. | Present, default on |
| Front-distance helper | `Server/AI/Commander/AI_Commander_Allocate.sqf:92-96` computes candidate distance to the nearest owned town, with HQ fallback when no owned town is available. | Present |
| Near-band reads | `AI_Commander_Allocate.sqf:129` declares `_nearBand`, `_nearBandDist`, and `_nearBandBonus`; `:135-137` reads the missionNamespace flags with fallback values `0`, `2000`, and `300`. | Present |
| Score bias | `AI_Commander_Allocate.sqf:140-144` scores candidate towns and adds `_nearBandBonus` when `_nearBand > 0` and `_dNear < _nearBandDist`. | Present |
| Scope nuance | The source comment on `AI_Commander_Allocate.sqf:144` says the bonus re-ranks and does not change eligibility. Team assignment later still chooses among the selected fist towns by reach/cap/nearest logic. | Important nuance |

## Maintained-Root Parity

The relevant source copies match across the maintained roots checked:
`Missions/[55-2hc]warfarev2_073v48co.chernarus`,
`Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan`, and
`Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad`.

| File | SHA-256 in Chernarus/Takistan/Zargabad |
| --- | --- |
| `Server/AI/Commander/AI_Commander_Allocate.sqf` | `478EB7A29DF24148649D27AFBA3DD207692F625473D05A5C67EAEA77C98C5D1E` |
| `Common/Init/Init_CommonConstants.sqf` | `0259B5AFC676AEC0397EE962AD6E4C8C9F72BB70329C6C0E6E4BC00138D7F29C` |

Compact scan counts also match across all three roots:

| Root | Flag def | Dist def | Bonus def | Flag read | Dist read | Bonus read | `_frontDist` refs | `nearBand` refs | Score-bonus add |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Chernarus | 1 | 1 | 1 | 1 | 1 | 1 | 4 | 5 | 1 |
| Takistan | 1 | 1 | 1 | 1 | 1 | 1 | 4 | 5 | 1 |
| Zargabad | 1 | 1 | 1 | 1 | 1 | 1 | 4 | 5 | 1 |

## BI Command References

The relevant Arma 2 OA command family is the standard variable, distance, and
iteration API used by the existing code:

- https://community.bistudio.com/wiki/getVariable
- https://community.bistudio.com/wiki/distance
- https://community.bistudio.com/wiki/forEach
- https://community.bistudio.com/wiki/count
- https://community.bistudio.com/wiki/Category:Arma_2:_Operation_Arrowhead:_Scripting_Commands

## Recommendation

Treat lane 90 as implemented on `claude/build84-cmdcon36`. Do not duplicate the
near-band constants or allocator score path.

The useful follow-up is runtime validation: compare fresh-match AICOM dispatch
leg lengths and arrival rates against the earlier fable baseline, with special
attention to whether the first fist towns stay inside the 2000m band when viable
targets exist.

## Verification

- Read `CLAUDE.md` and `JOURNAL.md` before the audit.
- Scanned lane 90 prompt text, active wiki claims, recent events, and open PRs
  before claiming the lane.
- Scanned near-band constants, allocator front-distance helper, near-band reads,
  score-bonus application, and existing F5 design references.
- Verified `AI_Commander_Allocate.sqf` and `Init_CommonConstants.sqf` have
  matching SHA-256 hashes across maintained roots.
- Verified this lane is docs-only; no SQF/SQM/HPP/EXT files changed.
- LoadoutManager was not run because no mission source changed.
