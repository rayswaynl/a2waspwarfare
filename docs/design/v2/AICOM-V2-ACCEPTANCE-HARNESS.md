# AICOM V2 Acceptance Harness Spec

Guide rev: GR-2026-07-03a. Scope: final-form harness spec only.

This harness grades the V2 one-shot build without manual RPT interpretation. It extends `Tools/Soak/analyze_soak.py` and the cmdcon41 KPI style documented in `Tools/Soak/README.md`.

## Soak protocol

| Run type | Minimum runtime | Required maps | Required logs | Pass condition |
|---|---:|---|---|---|
| AI-vs-AI unattended | 4h each | CH and TK | server RPT plus all HC RPTs | All global and map gates PASS. |
| Player-assisted smoke | 2h with 4+ players | CH or TK | server RPT plus all HC RPTs | No critical gate FAIL; player-visible doctrine proxies WATCH or PASS. |
| ZG reduced soak | 2h | ZG | server RPT plus all HC RPTs | ZG-specific thresholds PASS; no nil cascade; profile load confirmed. |

MISSINIT scoping rule:

Reuse the current `analyze_soak.py` convention: only parse lines after the last mission-init boundary for the requested run. If multiple rounds exist inside the same RPT, segment by `MISSINIT` and `ROUNDEND`/`ROUND_END` markers and compute per-segment plus aggregate metrics.

Log sources:

| Source | Required use |
|---|---|
| Server RPT | Supervisor, planning, profile load, WASPSCALE, ROUNDEND, economy, MHQ relocation. |
| HC RPT | Team order ACK, capture-driver events, arrival/capture local execution, HC FPS if present. |

## KPI thresholds

PASS/WATCH/FAIL thresholds are per side unless stated otherwise.

| KPI | PASS | WATCH | FAIL | Pattern/source |
|---|---:|---:|---:|---|
| Arrival percent | CH/TK `>30%`, ZG `>15%` | CH/TK `15-30%`, ZG `8-15%` | Below WATCH | `ASSAULT_DISPATCH`, `ASSAULT_ARRIVED` |
| Zombie teams | `<=2` | `3-5` | `>5` | Existing zombie/group GC counters |
| WEST/EAST kill share | Both sides `>5%` of W/E kills | one side `2-5%` | any side `<2%` after 60m | WASPSTAT KILL or analyzer kill share |
| Target churn | `<=50%` V1 baseline retargets/team-hour | `50-75%` baseline | `>75%` baseline | V3 `PLAN_CHANGE` or V2 target events |
| ROUND_END/ROUNDEND fired | `>=1` in 4h AI run | none in 4h but base-overrun pressure present | none and no base pressure | `ROUNDEND`, `ROUND_END`, `BASE_OVERRUN` |
| MHQ relocation deployed | `>=1` per 4h side pair | attempted but no deploy | zero attempts on 2-town+ economy | `MHQRELOC|DEPLOYED` or V3 equivalent |
| Supervisor watchdog restarts | `0` | `1-2` | `>2` | `AICOMSTAT|v3|WATCHDOG|RESTART` |
| Profile load | one PASS line per side at boot | fallback profile used intentionally | no profile line or malformed profile | `AICOMSTAT|v3|PROFILE|...|LOAD` |
| Per-map constants confirmed | all required constants logged | any optional missing | required override missing | `AICOMSTAT|v3|PROFILE|...|CONST` |
| FPS parity | server FPS median remains in V1 `44-48` band at 250+ AI or within 5% of paired V1 baseline | 5-10% below | >10% below | `WASPSCALE|v2`, PerformanceAudit |
| KPI flatline | no flatline alarm | one alarm recovers | repeated alarms or no recovery | `AICOMSTAT|v3|WATCHDOG|KPI_FLATLINE` |

## Doctrine proxy gates

These encode all 8 behavioural doctrine points.

| Doctrine | Metric | PASS | WATCH | FAIL | Required log |
|---|---|---:|---:|---:|---|
| Commit, do not churn | Retargets per team-hour | `<=0.50 * V1_baseline` | `0.50-0.75 * V1` | `>0.75 * V1` | `AICOMSTAT|v3|PLAN|CHANGE|team=...|from=...|to=...|reason=...` |
| Refuse fair fights | Attacker:defender ratio at first contact | median `>=1.35` | `1.10-1.35` | `<1.10` | `AICOMSTAT|v3|CONTACT|FIRST|atk=...|def=...` |
| Tempo awareness | Inter-capture interval trend after a successful flip | winning side next interval decreases or holds within 10% | flat | increases >25% while winning | WASPSTAT CAPTURE plus V3 posture |
| Be legible | Ordered grammar sequence present | `RECON -> PREP/FIRE -> ASSAULT` on >=60% attacks | 30-60% | <30% | V3 WHY + SideMessage tags |
| Punish and remember | Player-action reaction within TTL | counter/avoid decision within 15m pain TTL on >=50% qualifying player events | 20-50% | <20% | `PLAYER_INTEL`, `PAIN_MEMORY`, `COUNTERATTACK` |
| Never be psychic | Decisions referencing unseen entities | `0` | any analyzer uncertainty | `>0 confirmed` | V3 decision WHY includes `intelId`; analyzer validates source |
| Money is pressure | Spend floor while losing | spend-rate >= posture floor and no hoard+lose alarm | one recoverable alarm | repeated hoard+lose | `ECON_PRESSURE`, funds/supply TICK |
| No dead air | Max player-visible event gap | `<=240s` CH/TK, `<=180s` ZG | +60s grace | >grace | `VISIBLE_EVENT` family |

## New analyzer scorer functions

### `score_round_end(lines, session)`

Match patterns:

- `ROUNDEND`
- `ROUND_END`
- `AICOMSTAT|v1|EVENT|.*|BASE_OVERRUN|`

Output:

`{"round_end_count": n, "base_pressure_count": n2, "status": "PASS|WATCH|FAIL"}`

PASS if `round_end_count >= 1` in a 4h AI-vs-AI soak. WATCH if no round end but base pressure exists. FAIL if neither appears.

### `score_mhq_deployed(lines, session)`

Match patterns:

- `MHQRELOC|DEPLOYED`
- `AICOMSTAT|v3|EVENT|.*|MHQRELOC_DEPLOYED`
- `AICOMSTAT|v1|EVENT|.*|MHQRELOC.*DEPLOYED`

Output:

`{"mhq_deployed": n, "mhq_attempts": n2, "status": ...}`

PASS if `mhq_deployed >= 1` in 4h CH/TK. WATCH if attempts exist but deploy zero. FAIL if no attempts after either side owns at least 2 towns for 90m.

### `score_watchdog_restarts(lines, session)`

Match patterns:

- `AICOMSTAT|v3|WATCHDOG|RESTART|side=(WEST|EAST)|gen=(\d+)`
- legacy fallback: `AI_Commander.sqf: .* watchdog .* restart`

PASS `0`, WATCH `1-2`, FAIL `>2`.

### `score_profile_load(lines, session)`

Match pattern:

`AICOMSTAT|v3|PROFILE|(?P<side>[^|]+)|0|LOAD|map=(?P<map>[^|]+)|profile=(?P<profile>[^|]+)|fallback=(?P<fallback>[01])|nodes=(?P<nodes>\d+)|edges=(?P<edges>\d+)`

Expected:

| Map | Profile | Nodes minimum | Required fallback |
|---|---|---:|---:|
| Chernarus | CH | 46 | 0 |
| Takistan | TK | 33 | 0 |
| Zargabad | ZG | 11 | 0 |

PASS if every AI side logs the correct profile and node/edge counts meet minimum. FAIL if missing or fallback is `1` without explicit test override.

### `score_garrison_split(lines, session)`

Match patterns:

- `AICOMSTAT|v1|STALL|<side>|<min>|...|garBodies=<n>|myStr=<n>|enStr=<n>`
- V3 preferred: `AICOMSTAT|v3|ASSESS|<side>|<min>|...|garBodies=<n>|maneuver=<n>|garrison=<n>`

Metric:

`garrison_body_share = garBodies / max(1, garBodies + maneuverBodies)`

PASS if a winning side with `myTowns > enTowns` has `garrison_body_share <= 0.55` and no stall streak >3. WATCH if share `0.55-0.70`. FAIL if share >0.70 and capture rate flatlines.

### `score_phase_jitter(lines, session)`

Match patterns:

- `AI_Commander.sqf: \[(WEST|EAST|.*)\] spawn phase-jitter (\d+)s`
- V3 preferred: `AICOMHB|v3|BOOT|(?P<side>[^|]+)|gen=\d+|jitter=(?P<jitter>\d+)`

PASS if absolute WEST/EAST first boot tick offset is >=5s. WATCH if 1-4s. FAIL if 0s or missing.

## Additional scorer functions required for doctrine

### `score_doctrine_churn`

Pattern:

`AICOMSTAT|v3|PLAN|CHANGE|side=(?P<side>[^|]+)|team=(?P<team>[^|]+)|from=(?P<from>[^|]+)|to=(?P<to>[^|]+)|reason=(?P<reason>[^|]+)`

Compute retargets per team-hour:

`retargets / max(1, sum(team_active_minutes) / 60)`

Do not count changes with reason `town_flipped`, `laststand`, `player_order`, or `target_destroyed` as churn; report them separately as deliberate changes.

### `score_first_contact_superiority`

Pattern:

`AICOMSTAT|v3|CONTACT|FIRST|side=(?P<side>[^|]+)|town=(?P<town>[^|]+)|atk=(?P<atk>\d+)|def=(?P<def>\d+)|intel=(?P<intel>[^|]+)`

Compute median and p25 attacker:defender ratio. PASS if median >= profile threshold and p25 >=1.10.

### `score_visible_event_gap`

Visible event patterns:

- `AICOMSTAT|v3|VISIBLE_EVENT|`
- `SideMessage` lines with AICOM V2 tags
- `FIRE_MISSION`, `AIR_PARADROP`, `HQ_STRIKE`, `MHQRELOC_DEPLOYED`, `WILDCARD`, `COUNTERATTACK`

Compute max gap in mission seconds per side after T+10m. PASS CH/TK `<=240`, ZG `<=180`.

### `score_fog_honesty`

Pattern:

`AICOMSTAT|v3|WHY|side=(?P<side>[^|]+)|decision=(?P<decision>[^|]+)|reason=(?P<reason>[^|]+)|intel=(?P<intel>[^|]+)|seen=(?P<seen>[01])`

FAIL if any combat decision has `seen=0` and reason is not one of `profile_default`, `town_owner_public`, `last_known_expired_wait`, or `base_under_attack_public`.

### `score_economy_pressure`

Patterns:

- `AICOMSTAT|v1|TICK|...funds=...supply=...`
- V3 preferred: `AICOMSTAT|v3|ECON|side=...|funds=...|supply=...|spend=...|floor=...|posture=...|hoardLose=...`

FAIL if `hoardLose=1` for two consecutive 10m windows or if funds grow for 30m while `myTowns < enTowns` and spend floor is unmet.

## Per-map gate table

| Gate | CH | TK | ZG |
|---|---:|---:|---:|
| Minimum AI-vs-AI soak | 4h | 4h | 2h |
| Arrival PASS | >30% | >30% | >15% |
| Visible event max gap | 240s | 240s | 180s |
| Profile nodes min | 46 | 33 | 11 |
| Edge flags required | coastal,airfield | airfield,oilfield | wallGap,edgeExcluded |
| FPS target | parity with V1 44-48 band at 250+ AI | parity with V1 44-48 band at 250+ AI | no ZG nil cascade, stable below low-pop cap |
| Constant override proof | CH constants line | TK constants line | ZG constants and ALIVEPOP_INIT line |

## Required V3 log lines

Profile load:

`AICOMSTAT|v3|PROFILE|WEST|0|LOAD|map=Chernarus|profile=CH|fallback=0|nodes=46|edges=53|constants=15`

Constants:

`AICOMSTAT|v3|PROFILE|WEST|0|CONST|WFBE_C_AICOM_LANE_OFFSET=120|WFBE_C_AICOM_ASSAULT_REACH_FOOT=2500|WFBE_C_AICOM_HQSTRIKE_MIN_TOWNS=12`

Heartbeat:

`AICOMHB|v3|TICK|WEST|42|gen=1|state=PRESS|planSeq=93|decisions=7|cpuMs=4|profile=CH`

Plan change:

`AICOMSTAT|v3|PLAN|CHANGE|side=WEST|team=W-04|from=Gorka|to=Dubrovka|reason=town_flipped|cost=0`

WHY:

`AICOMSTAT|v3|WHY|side=WEST|decision=attack|reason=mass_superiority|target=Dubrovka|confidence=0.82|intel=town_public|seen=1`

Visible pulse:

`AICOMSTAT|v3|VISIBLE_EVENT|side=EAST|min=64|kind=arty_prep|target=Rasman|radio=1`

Watchdog flatline:

`AICOMSTAT|v3|WATCHDOG|KPI_FLATLINE|side=EAST|min=91|captures=0|arrivals=0|window=1800|action=hold_v1_fallback`

## Acceptance summary output

`analyze_soak.py` must print and export:

| Section | Required content |
|---|---|
| `AICOM V2 Profile` | map, profile, fallback, nodes, edges, constants verified |
| `AICOM V2 Doctrine` | 8 doctrine proxy rows with PASS/WATCH/FAIL |
| `AICOM V2 Reliability` | heartbeat, watchdog restarts, phase jitter, HC order ACK |
| `AICOM V2 Performance` | FPS parity, AI totals, group counts, CPU budget if logged |
| `AICOM V2 Round Progress` | captures/hour, arrivals, churn, round_end, MHQ deployed |

Final run result is FAIL if any hard gate fails. WATCH may ship only with owner sign-off and a named follow-up lane.
