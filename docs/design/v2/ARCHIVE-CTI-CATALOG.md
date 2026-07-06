# Archive CTI Catalog

Status: DRAFT, local archive observed but full extraction pass blocked by intermittent sandbox command failures  
Related roster lane: 446  
Scope: Jerry/Armaholic archive sources for Warfare, CTI, MCTI, WICT, and commander mechanics.

## Archive Roots Observed

`E:\arma2-cache` was reachable on this host. Top-level roots observed:

- `E:\arma2-cache\archives`
- `E:\arma2-cache\buckets`
- `E:\arma2-cache\extracted`
- `E:\arma2-cache\jerry-dl`
- `E:\arma2-cache\jerry-dl2`
- `E:\arma2-cache\jerry-ex`
- `E:\arma2-cache\jerry-ex2`
- `E:\arma2-cache\reports`
- `E:\arma2-cache\triage`
- indexes: `index.csv`, `triage.csv`, `jerry-available.csv`, `island-catalog.csv`

Password for `*_WithPW.7z`: `armedassault`.

## Candidate CTI/Warfare Hits

| Archive/source | Observed path | Lineage | Confidence | Borrow verdict |
|---|---|---|---|---|
| Doolittle CTI B22 | `E:\arma2-cache\archives\cti_doolittle_b22_WithPW.7z` | crCTI-era CTI | Medium | Design lead only: older CTI economy/capture patterns; inspect for minimal town loop. |
| MCTI R6 Chernarus | `E:\arma2-cache\archives\mcti_r6_40vs40.Chernarus_WithPW.7z` | MCTI | High | Borrow as design: compare commander cadence and 40v40 scaling assumptions. |
| MCTI R7 Chernarus | `E:\arma2-cache\archives\mcti_r7_40vs40.Chernarus_WithPW.7z` | MCTI | High | Borrow as design: changelog delta vs R6. |
| MCTI R8 Chernarus | `E:\arma2-cache\archives\mcti_r8_40vs40.Chernarus_WithPW.7z` | MCTI | High | Borrow as design: candidate stable iteration. |
| MCTI R9 Chernarus | `E:\arma2-cache\archives\mcti_r9_40vs40.Chernarus_WithPW.7z` | MCTI | High | Top-5 pick: latest observed MCTI chain, likely best commander/economy snapshot. |
| WICT v6.0 | `E:\arma2-cache\archives\WICT_v6-0_WithPW.7z` | WICT dynamic battlefield | High | Top-5 pick: spawn-zone/frontline ideas, not code. |
| ALiVE 0.5.2 extracted modules | `E:\arma2-cache\extracted\@alive_0-5-2\...` | A3-era operational framework, not A2 CTI | Medium | Context only; avoid direct port to A2 OA. |
| AnS ProMode RandomMode OA AI | `E:\arma2-cache\extracted\AnS_ProMode_RandomMode_OA_AI_2011_04_05\...` | Scenario/random AI mission family | Medium | Design lead only: random-mode objective generation, not CTI core. |

## Top-5 Borrow-As-Design Picks

1. `mcti_r9_40vs40.Chernarus_WithPW.7z`: latest observed MCTI archive; inspect commander loop and economy scaling.
2. `WICT_v6-0_WithPW.7z`: extract dynamic front/spawn logic as inspiration for player-visible pulse, without adopting code.
3. `cti_doolittle_b22_WithPW.7z`: compare old CTI town ownership and cash flow for simplicity targets.
4. `mcti_r8_40vs40.Chernarus_WithPW.7z`: compare R8 to R9 to identify what changed late.
5. `MCTI R6/R7 pair`: use as evolution evidence, not as direct feature source.

## Mechanics To Extract In Follow-Up

For each archive, extract and summarize:

- AI commander decision loop
- economy model
- town capture mechanic
- faction structure
- notable modules
- patterns absent from WASP
- license/readme, especially GPLv3 indicators

## Hard Boundaries

- No raw SQF pasted into specs.
- No A3-only patterns adopted.
- No direct code borrowing without license review.
- Borrow verdict is design only until a builder validates A2 OA compatibility and license.
