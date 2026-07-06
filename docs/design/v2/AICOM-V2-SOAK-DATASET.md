# AICOM V2 Soak Evidence Dataset

Source status: Hetzner RPT archive, local soak logs, and `Tools/Soak/` script reads were blocked by the local sandbox after initial context load. This file is the required dataset schema plus the confirmed evidence windows from loaded journal/roster material. The orchestrator should run the harvest script described below and append raw extracted tables.

## Harvest Scope

Required RPT sources:

| Source | Required files | Status in this run |
|---|---|---|
| Hetzner HC RPT archive | `ArmA2OA.RPT`, scoped to current `MISSINIT` boundary | Blocked/unreachable from sandbox. |
| Hetzner server RPT archive | Server RPT only for server-side tokens and MISSINIT markers | Blocked/unreachable. |
| Local `Tools/Soak/` logs | Analyzer inputs and previous reports | Blocked by error 206. |

Important: AICOM team logs must prioritize HC RPT over server RPT. Server boot-smoke is blind to several client/JIP and HC execution paths.

## Dataset Schema

| Table | Key | Required fields | Event families |
|---|---|---|---|
| Economy quintiles | build, side, elapsedQuintile | fundsMin, fundsMedian, fundsMax, supplyMin, supplyMedian, supplyMax, spendRate | `AICOMSTAT|v1|TICK`, v2 economy events |
| Posture distribution | build, side | posture, seconds, percent, transitions | `POSTURE`, `STRAT_MODE`, `AICOMHB` |
| Assault dispatch | build, side | count, target, teamType, localRatio, orderSeq | `ASSAULT_DISPATCH` |
| Assault arrival | build, side | count, elapsedSec p50/p90/max, timeoutCount | `ASSAULT_ARRIVED`, `ORBITER_STUCK` |
| Target abandon | build, side | reason, count, afterSec p50/p90 | `TARGET_ABANDON` |
| Team lifecycle | build, side | founded, retired, merged, disbanded, topupExpired | `TEAM_FOUNDED`, `TEAM_RETIRE`, top-up events |
| Group budget | build, side | warnCount, maxGroups, softCapPct, emergencyGC | `GRPBUDGET|WARN`, `GCSTAT`, `GUERCAP` |
| Cmdcon30 failure | window id | conditions, SNAP content, GRPBUDGET, WEST team count | `SNAP`, `GRPBUDGET`, team founded absence |

## Confirmed Evidence Windows From Loaded Project Context

| Window | Era | Evidence | V2 implication |
|---|---|---|---|
| B57 deployed 2026-06-20 | B57 soak | Runtime-confirmed `B57 padded infantry team to floor (8 units)`, 0 runtime errors, FPS 47 at AI=84. | Team floor at founding is safe and should be retained. |
| B57 thin-team root cause | B57 analysis | HC-founded teams skipped Produce because `wfbe_aicom_hc` teams were all live teams. | Refit/top-up cannot be the only place where team size floor is enforced. |
| Join saga B54/B56 | Pre-B57 incident | Server RPT looked healthy; client RPT exposed unbounded JIP wait. | AICOM acceptance must always include HC RPT and client/JIP-relevant logs when behavior seems absent. |
| GUER cap monitor | 2026-06-15 | `GUERCAP|v1|count|max|pct` planned at 60s GCSTAT cadence; cap raised to 80. | V2 cannot solve group pressure by reducing GUER output. |
| Cmdcon30 WEST 0-team-founding | Required by lane 402 | Roster explicitly requires identification of the window with SNAP and GRPBUDGET context. | Treat as open critical evidence gap until raw RPT is harvested. |
| ZG stall-clock | Roster commandment | KPI flatline and ORBITER_STUCK on compact map are known failure classes. | V2 self-watchdog and map lane offset required. |

## Required Harvest Script Contract

If a helper is written, place it under `docs/design/v2/tools/harvest_aicom_soak.py`. It should be a read-only parser:

```text
input: one or more RPT files
scope: split by latest MISSINIT marker unless --all-windows is passed
output: markdown tables plus optional JSON records
required regex families:
  AICOMSTAT tick:      ^.*AICOMSTAT\|v(?P<ver>[12])\|TICK\|(?P<body>.*)$
  posture:            ^.*AICOMSTAT\|v(?P<ver>[12])\|(?:POSTURE|EVENT)\|(?P<body>.*POSTURE.*)$
  dispatch:           ^.*AICOMSTAT\|v(?P<ver>[12])\|.*ASSAULT_DISPATCH\|(?P<body>.*)$
  arrived:            ^.*AICOMSTAT\|v(?P<ver>[12])\|.*ASSAULT_ARRIVED\|(?P<body>.*)$
  abandon:            ^.*AICOMSTAT\|v(?P<ver>[12])\|.*TARGET_ABANDON\|(?P<body>.*)$
  founded:            ^.*AICOMSTAT\|v(?P<ver>[12])\|.*TEAM_FOUNDED\|(?P<body>.*)$
  retired:            ^.*AICOMSTAT\|v(?P<ver>[12])\|.*TEAM_RETIRE\|(?P<body>.*)$
  grpbudget warn:     ^.*GRPBUDGET\|WARN\|(?P<body>.*)$
  snap:               ^.*SNAP\|(?P<body>.*)$
```

Parsing rule: tolerate extra fields by storing raw tail. Do not fail closed on an unknown v2 family; count it in generic-collected.

## Cross-Build Comparison Placeholder

| Build era | RPT window | Economy trajectory | Posture distribution | Arrival p50/p90 | Abandon top reason | Team balance | Group warnings |
|---|---|---|---|---|---|---|---|
| B57 | VERIFY raw RPT | Known stable at FPS 47/AI84, exact funds table pending | Pending | Pending | Pending | Founding pad active | Pending |
| B69 | VERIFY raw RPT | Pending | Pending | Pending | Pending | Pending | Pending |
| cmdcon30 | VERIFY raw RPT | Required to show WEST 0-team-founding conditions | Pending | Pending | Pending | WEST founded=0 in failure window | Required SNAP/GRPBUDGET |

## Cmdcon30 Failure Window Template

The final harvest must fill this exact block:

| Field | Required value |
|---|---|
| Build label | cmdcon30 |
| Side | WEST |
| Window start/end | elapsed minute and RPT timestamp |
| Team count | Expected zero founding window |
| Funds/supply | From nearest `AICOMSTAT|TICK` |
| Group budget | From nearest `GRPBUDGET` and group audit |
| SNAP | Paste summarized fields, not raw long log |
| Trigger hypothesis | Pending raw evidence |
| V2 prevention | Founding watchdog, spend-rate floor, explicit no-team alarm |

## Acceptance Data Requirements

Before V2 build starts, this file must have at least three filled RPT windows spanning at least two eras, with economy trajectory, posture, stuck/abandon, and team lifecycle tables populated.
