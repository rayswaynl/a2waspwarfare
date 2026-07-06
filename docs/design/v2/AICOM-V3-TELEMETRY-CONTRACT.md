# AICOMSTAT V3 Telemetry Contract Draft

Source status: direct reads of `Common/Functions/Common_AICommanderLog.sqf`, `Tools/Soak/analyze_soak.py`, and telemetry wiki pages were blocked by Windows sandbox error 206. This is the implementation contract for V3; retained v1/v2 layouts must be source-confirmed before code.

## Versioning Rule

Retain existing `AICOMSTAT|v1|...` and `AICOMSTAT|v2|...` field layouts unchanged. Add new V3 families rather than mutating old ones. Analyzer must parse v1/v2 as legacy and v3 as named KPI input.

## Side Normalization Decision

Use lowercase canonical side strings in every new v3 field: `west`, `east`, `guer`, `civ`, `unknown`. If an existing v1/v2 event uses numeric side id or uppercase, analyzer normalizes to the canonical string in derived metrics without changing raw record storage.

## New V3 Events

| Event | Format | Purpose |
|---|---|---|
| Supervisor heartbeat | `AICOMHB|v3|TICK|t|side|gen|state|posture|teams|orders|funds|supply|fps|kpiFlags` | Detect silent death, duplicate loops, KPI flatline. |
| Watchdog restart | `AICOMSTAT|v3|WATCHDOG_RESTART|t|side|oldGen|newGen|reason|lastTickAge|teams|orders` | Prove self-recovery and count restarts. |
| HC drop | `AICOMSTAT|v3|HC_DROP|t|side|ownerId|ownerGen|activeTeams|aicomTeams|sidepatrols|staticDefense|markerContinuity` | Audit HC loss. |
| HC reconnect | `AICOMSTAT|v3|HC_RECONNECT|t|ownerId|oldGen|newGen|recoveredTeams|orphanedTeams` | Audit reconnection. |
| Team founded | `AICOMSTAT|v3|TEAM_FOUNDED|t|side|teamId|teamType|templateId|count|padClass|padCount|hcOwner|ownerGen|groupCount` | Confirm founding pad and HC allocation. |
| Depleted merge | `AICOMSTAT|v3|TEAM_MERGE|t|side|fromTeam|toTeam|fromCount|toCount|reason|ownerGen` | Track survivor recovery. |
| WEST fallback | `AICOMSTAT|v3|WEST_INF_FALLBACK|t|reason|funds|supply|groupCount|blockedType|fallbackTemplate` | Catch cmdcon30-style no founding. |
| Top-up TTL expiry | `AICOMSTAT|v3|TOPUP_EXPIRED|t|side|teamId|age|classes|pos|reason` | Confirm lane 376 behavior. |
| HQ strike package | `AICOMSTAT|v3|HQ_STRIKE|t|side|phase|targetSide|eligibleTeams|selectedTeams|reason|orderSeq` | Gate/picker/order visibility. |
| Hoard warning | `AICOMSTAT|v3|ECON_HOARD_WARN|t|side|funds|supply|townDelta|posture|spendRate` | Enforce money-as-pressure doctrine. |
| Visible pulse | `AICOMSTAT|v3|VISIBLE_PULSE|t|side|eventId|sourceIntel|gapSec|cost|target` | Enforce no-dead-air and no-psychic doctrine. |

## Retained v1/v2 Families

| Family | Layout | V3 treatment |
|---|---|---|
| `TICK` | unchanged | Legacy economy and team counts. |
| `POSTURE` / posture events | unchanged | Normalize posture names and side field in analyzer only. |
| `ASSAULT_DISPATCH` | unchanged | Named KPI for dispatch counts and retarget rate. |
| `ASSAULT_ARRIVED` | unchanged | Named KPI for arrival percent and elapsed distribution. |
| `TARGET_ABANDON` | unchanged | Named KPI for churn and failure reasons. |
| `TEAM_FOUNDED` v1/v2 | unchanged | Legacy count; v3 adds type/pad/owner fields. |
| `TEAM_RETIRE` | unchanged | Legacy lifecycle; pair with v3 merge. |
| `BOOTSTRAP_STIPEND_WINDFALL` | unchanged | Named KPI for bootstrap economy. |
| Other v2 families | unchanged | Generic-collected unless promoted below. |

## KPI Promotion Decision

Promote to named KPI:

| KPI | Events | Rationale |
|---|---|---|
| Supervisor liveness | `AICOMHB`, `WATCHDOG_RESTART` | Catches silent death/duplicate loop. |
| Team founding health | `TEAM_FOUNDED`, `WEST_INF_FALLBACK`, `GRPBUDGET` | Catches cmdcon30 no-team windows. |
| Arrival effectiveness | `ASSAULT_DISPATCH`, `ASSAULT_ARRIVED`, `ORBITER_STUCK` | Measures V2 movement doctrine. |
| Churn | `TARGET_ABANDON`, dispatch target changes | Enforces commit doctrine. |
| Economy pressure | `TICK`, `ECON_HOARD_WARN`, stipend events | Enforces spend while losing. |
| HC continuity | `HC_DROP`, `HC_RECONNECT`, stale report | Locality reliability. |
| Visible pulse | `VISIBLE_PULSE`, wildcard events | No dead air and intel honesty. |

All remaining v2 families stay generic-collected with counts and raw-tail samples.

## Analyzer Contract

Exact regexes for mechanical `analyze_soak.py` update:

```python
RE_AICOMHB = r"AICOMHB\|v3\|TICK\|(?P<t>[^|]*)\|(?P<side>[^|]*)\|(?P<gen>[^|]*)\|(?P<state>[^|]*)\|(?P<posture>[^|]*)\|(?P<teams>[^|]*)\|(?P<orders>[^|]*)\|(?P<funds>[^|]*)\|(?P<supply>[^|]*)\|(?P<fps>[^|]*)\|(?P<kpiFlags>.*)$"
RE_WATCHDOG = r"AICOMSTAT\|v3\|WATCHDOG_RESTART\|(?P<t>[^|]*)\|(?P<side>[^|]*)\|(?P<oldGen>[^|]*)\|(?P<newGen>[^|]*)\|(?P<reason>[^|]*)\|(?P<lastTickAge>[^|]*)\|(?P<teams>[^|]*)\|(?P<orders>.*)$"
RE_HC_DROP = r"AICOMSTAT\|v3\|HC_DROP\|(?P<t>[^|]*)\|(?P<side>[^|]*)\|(?P<ownerId>[^|]*)\|(?P<ownerGen>[^|]*)\|(?P<activeTeams>[^|]*)\|(?P<aicomTeams>[^|]*)\|(?P<sidepatrols>[^|]*)\|(?P<staticDefense>[^|]*)\|(?P<markerContinuity>.*)$"
RE_TEAM_FOUNDED_V3 = r"AICOMSTAT\|v3\|TEAM_FOUNDED\|(?P<t>[^|]*)\|(?P<side>[^|]*)\|(?P<teamId>[^|]*)\|(?P<teamType>[^|]*)\|(?P<templateId>[^|]*)\|(?P<count>[^|]*)\|(?P<padClass>[^|]*)\|(?P<padCount>[^|]*)\|(?P<hcOwner>[^|]*)\|(?P<ownerGen>[^|]*)\|(?P<groupCount>.*)$"
RE_TEAM_MERGE = r"AICOMSTAT\|v3\|TEAM_MERGE\|(?P<t>[^|]*)\|(?P<side>[^|]*)\|(?P<fromTeam>[^|]*)\|(?P<toTeam>[^|]*)\|(?P<fromCount>[^|]*)\|(?P<toCount>[^|]*)\|(?P<reason>[^|]*)\|(?P<ownerGen>.*)$"
RE_WEST_FALLBACK = r"AICOMSTAT\|v3\|WEST_INF_FALLBACK\|(?P<t>[^|]*)\|(?P<reason>[^|]*)\|(?P<funds>[^|]*)\|(?P<supply>[^|]*)\|(?P<groupCount>[^|]*)\|(?P<blockedType>[^|]*)\|(?P<fallbackTemplate>.*)$"
```

Metric computation:

| Metric | Computation |
|---|---|
| heartbeat_gap_max | Max delta between `AICOMHB` ticks per side/gen. |
| restart_count | Count `WATCHDOG_RESTART`; PASS 0, WATCH 1-2, FAIL >2 per 4h. |
| founded_per_hour | Count v3 `TEAM_FOUNDED` by side over scoped runtime. |
| fallback_count | Count `WEST_INF_FALLBACK`; any nonzero is WATCH unless it prevents zero-team stall. |
| arrival_percent | `ASSAULT_ARRIVED / ASSAULT_DISPATCH` per side. |
| churn_rate | Count target changes and `TARGET_ABANDON` per team-hour. |
| hoard_lose_alarm | Count `ECON_HOARD_WARN`; FAIL if repeated while townDelta negative. |
| visible_gap_max | Max delta between `VISIBLE_PULSE` or player-visible event per side. |

## Field Safety

All fields are primitives: strings, numbers, and flat pipe-delimited records. Do not emit arrays as SQF text unless encoded as comma-separated strings with no nested pipes.
