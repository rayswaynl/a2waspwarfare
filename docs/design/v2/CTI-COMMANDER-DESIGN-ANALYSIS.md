# CTI Commander Design Analysis

Status: DRAFT, analytical comparison with confidence tags  
Lane: 449

## Scope

Compare crCTI, MCTI, and WICT commander/design lineages against WASP AICOM B69/B84 behavior. This is design analysis, not a script dump.

## Lineage Summaries

### crCTI

Confidence: Medium. Source candidate observed: `E:\arma2-cache\archives\cti_doolittle_b22_WithPW.7z`.

Likely design center:

- town-control economy
- simple commander routines
- player-driven flow with AI filling pressure
- lower abstraction than WASP AICOM

Decision inputs to verify:

- owned town count
- available funds/supply
- nearest/enemy towns
- factory/base availability

Strategic option set:

- attack town
- defend town/base
- buy units
- repair/rebuild base

V2 relevance: use crCTI as a simplicity baseline. If V2 logic cannot explain itself more clearly than crCTI, the spec is too complex.

### MCTI

Confidence: High for archive presence, Medium for logic until extracted. Source candidates observed: R6-R9 Chernarus archives.

Likely design center:

- 40v40 scale
- AI support around a large multiplayer CTI loop
- iteration across R6-R9 useful for delta study

Decision inputs to verify:

- player ratio
- town/front state
- side economy
- group availability
- factory output

Strategic option set:

- reinforce front
- launch town attack
- defend base/town
- produce mixed force

V2 relevance: compare scale assumptions against WASP's 250+ AI acceptance and HC-driven execution.

### WICT

Confidence: High for archive presence (`WICT_v6-0_WithPW.7z`), Medium for detailed logic.

Design center:

- dynamic battlefield generation
- zones/fronts/spawn pressure
- player-visible activity pulse

Decision inputs to verify:

- player position
- active zones
- ownership/front proximity
- spawn/despawn budgets

Strategic option set:

- activate zone
- spawn attack/defense group
- move activity toward player/front
- clean inactive zones

V2 relevance: strongest prior-art lead for "No dead air" and legible activity pulses, but not a drop-in AICOM.

## Comparison Table

| Axis | WASP AICOM B69/B84 | crCTI | MCTI | WICT |
|---|---|---|---|---|
| Main loop | Server commander plus HC execution | Simpler CTI commander loop | CTI commander/support loop | Zone/front activity loop |
| Inputs | town state, funds, teams, posture, events, wildcards | towns/economy/base | towns/economy/player scale | player/front/zone activity |
| Commitment | Current V1 has churn risks; V2 requires hysteresis | Likely low/medium | Unknown | Zone persistence likely medium |
| Local superiority | Explicit V2 doctrine | Verify | Verify | Indirect through spawn density |
| Tempo | V2 posture/tempo target | Basic | Medium | Strong pulse model |
| Fog-of-war honesty | Required V2 WHY-log rule | Verify | Verify | Often player-proximity driven |
| Economy pressure | V2 spend-rate watchdog | Basic cash/supply | CTI economy | Not primary |
| Per-map profile fit | V2 requirement | Low | Medium | High for terrain-shaped zones |

## Ranked Design Gaps For V2

1. WICT-style activity pulse with strict A2 locality and budget guards.
2. MCTI scale lessons for large player/AI counts.
3. crCTI simplicity as an explainability test.
4. Version-to-version MCTI delta as evidence of what community authors repeatedly tuned.
5. Zone activation/deactivation ideas for future per-map profiles, not current gameplay code.

## Builder Follow-Up

Extract the archives and fill a per-lineage appendix with:

- loop file names
- cadence
- exact inputs
- exact output orders
- one source citation per conclusion

Do not paste raw SQF.
