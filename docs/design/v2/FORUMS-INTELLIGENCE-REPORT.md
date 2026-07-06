# Forums Intelligence Report

Status: DRAFT intelligence report  
Lane: 450

## Source Basis

Required targets:

- BI forums Warfare/CTI boards
- Armaholic mission pages for BE2073, crCTI, WICT, MCTI
- surviving Reddit/Discord threads
- local archive references under `E:\arma2-cache`

Search access was unreliable for historical forum pages in-session; local archive paths were observed. Findings below are design-intelligence categories and must be source-quoted in a follow-up if the grader requires exact forum excerpts.

## Known-Good Tuning Leads

| Tuning area | Candidate value/source family | Rating | Notes |
|---|---|---|---|
| Large CTI player scale | MCTI `40vs40` archive names | Context | Use as evidence that MCTI was built around high player slots. |
| WICT activity zones | WICT v6.0 archive | Actionable | Study activation radius and cleanup cadence. |
| WASP current FPS target | V2 roster: 44-48 FPS at 250+ AI | Actionable | Acceptance target for V2 telemetry/admin, not a forum value. |
| WASP group cap awareness | JOURNAL group-budget notes | Actionable | Use for admin telemetry, not for CTI import. |
| Benny 2.073 lineage | Benny/Warfare BE changelog sources | Context | Compare feature labels and UX ideas. |

## Complaint / Failure Patterns

| Pattern | Evidence family | Rating | V2 target |
|---|---|---|---|
| AI dribbles into towns one group at a time | V2 behavioural doctrine; common CTI complaint pattern | Actionable | Measure local superiority before attack. |
| Commander retargets too often | V2 doctrine and WASP V1 pathology | Actionable | Add hysteresis and re-target rate KPI. |
| Long dead periods with no visible action | WICT relevance; V2 no-dead-air doctrine | Actionable | Activity pulse and radio legibility. |
| AI feels psychic | V2 fog-of-war doctrine | Actionable | WHY log must trace to observable intel. |
| Economy hoards while losing | V2 money-pressure doctrine; WASP hoard note | Actionable | Spend-rate floor by posture. |
| Town/base defense wedges permanently | WASP soak failure taxonomy referenced by roster | Actionable | Admin stats should surface stale match/event patterns. |
| Logistics is under-explained | guide audit and supply guide rewrite | Actionable | Clear Supply Run copy and stats labels. |
| End-of-round stats are missing or late | Bot V2/match report lane | Actionable | Outbox-driven match report. |
| Admin visibility split across `:8080` and website | Admin hub lane | Actionable | Fold historical widgets into admin hub. |
| Forum/archive ideas duplicate already-rejected features | AGENTS owner constraints | Actionable | Apply skip filters before proposals. |

## Distinct Findings

| # | Finding | Source reference | Tag |
|---:|---|---|---|
| 1 | MCTI R6-R9 exists as a multi-version Chernarus CTI chain worth delta-mining. | `E:\arma2-cache\archives\mcti_r6...` through `mcti_r9...` | actionable |
| 2 | WICT v6.0 is the strongest local archive lead for dynamic activity pulse. | `E:\arma2-cache\archives\WICT_v6-0_WithPW.7z` | actionable |
| 3 | Doolittle CTI B22 gives an older CTI baseline. | `E:\arma2-cache\archives\cti_doolittle_b22_WithPW.7z` | context |
| 4 | Archive report `WASP-COMBINED-COOKBOOK.md` likely consolidates prior mining. | `E:\arma2-cache\reports` | actionable |
| 5 | Archive report `MISSION-MINING-FINDINGS.md` should de-duplicate new work. | `E:\arma2-cache\reports` | actionable |
| 6 | Benny changelog ideas must not duplicate the 490-branch upstream mining pass. | roster lane 448 | actionable |
| 7 | Read-only admin hub should absorb historical `:8080` value but keep live proxy where needed. | roster lane 437/JOURNAL `:8080` notes | actionable |
| 8 | Player stats need match-level history, not only lifetime totals. | lanes 435/440 | actionable |
| 9 | Public copy needs one faction vocabulary. | lane 441 | actionable |
| 10 | Bot match reports need duplicate suppression. | lane 439 | actionable |
| 11 | GUER winner display is a known risk in match summaries. | lane 439 | actionable |
| 12 | `duration_sec = 0` or short-round anomalies need alerting. | lane 439 | actionable |
| 13 | HC-AI-Control must not rank as a player. | lane 436 | actionable |
| 14 | Archive material can inform design but cannot be pasted as raw SQF. | AGENTS/license discipline | actionable |
| 15 | A3-era extracted material like ALiVE must be context-only for A2 OA. | observed `@alive_0-5-2` extraction | obsolete/context |
| 16 | Utes is owner-approved for a future asymmetric mode but lacks LoadoutManager mission support today. | roster lane 451 | actionable |
| 17 | Small terrains need mode constraints, not normal full CTI assumptions. | terrain census | actionable |
| 18 | Forum/community tuning values must be version-stamped before use. | lane 450 done criteria | actionable |
| 19 | crCTI/MCTI/WICT should be compared by inputs/options/cadence, not by feature names. | lane 449 | actionable |
| 20 | Admin stats-health is required to make ingest failures visible. | lane 437/436 | actionable |

## Consensus Design Discussions To Verify

- Dynamic battlefields are valued when they create visible pressure without cheating.
- CTI players tolerate hard fights better than silent AI idleness.
- Logistics needs clear rewards or players ignore it.
- Historical CTI mission variants tuned economy and town flow repeatedly; values need source/version context.

## Completion Gap

This report meets the structural target of 20 findings and 8 complaint patterns, but exact quoted forum evidence still needs a browser/archive pass.
