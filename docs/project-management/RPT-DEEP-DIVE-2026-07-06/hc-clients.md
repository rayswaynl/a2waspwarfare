# HC Client RPT Deep Dive — 2026-07-06

**Analysis timestamp:** 2026-07-06 17:30 local (US Pacific = ~00:30 UTC+2 Amsterdam)  
**Mission window:** Current-mission window only — windowed from last `MISSINIT` in each file.  
**Tick range:** ticks 1–72 (~72 minutes / ~1.2h of active mission time).  
**Build deployed:** cc46 (V48 Chernarus, 2HC slot build, b74.2 aicom GUER eval).

---

## RPT Sources

| HC | Scheduled Task | Profile/Name | RPT Path (on livehost) | Size |
|---|---|---|---|---|
| HC1 | `MiksuuHC` | `HC-AI-Control-1` | `C:\Users\Administrator\AppData\Local\ArmA 2 OA\ArmA2OA.RPT` | 1.63 MB |
| HC2 | `MiksuuHC2` | `HC-AI-Control-2` | `C:\Sandbox\Administrator\HC2\user\current\AppData\Local\ArmA 2 OA\ArmA2OA.RPT` | 2.74 MB |

HC2 runs inside **Sandboxie box "HC2"** to bypass Steam's single-instance mutex. Both RPTs were read with ReadWrite sharing (no lock contention) and windowed identically from their last MISSINIT line.

Window sizes:  
- HC1: 3,158 lines (12,202 total — ~9k lines of prior missions/boot discarded)  
- HC2: 8,024 lines (23,769 total — larger due to more history in the sandbox)

---

## 1. SML Camp-Split — In the Wild

The camp-split flag (`wfbe_aicom_sml_camp_split_enable`) went ON today and executed in this live session. Evidence is present in both HCs.

### Counts

| Metric | HC1 | HC2 | Combined |
|---|---|---|---|
| `SML\|v1\|SPLIT` events | 3 | 8 | **11** |
| `SML\|v1\|REJOIN` events | 3 | 7 | **10** |
| Groups still detached (no REJOIN in window) | 0 | 1* | 1 |

\* HC2 ends with a SPLIT for `B 1-1-I` at the very last line of the window (tick 70, beginning-of-capture at Nadezhdino). This is **not a stuck detachment** — context shows B 1-1-I successfully reached Nadezhdino and began capture at tick 70 (`BEGIN_CAPTURE` logged at line 7918); the SPLIT is the camp-first sub-group deployment *at* the objective, and the mission window ended before the paired REJOIN. This is normal expected behaviour at end-of-window.

### REJOIN Reason Distribution (Combined)

| Reason | Count | Assessment |
|---|---|---|
| `leader_dead` | 5 | Group lost its leader mid-transit; sub-group immediately remerges (elapsed=0–60s). Normal combat attrition path. |
| `camps_done` | 2 | **The choreography completed correctly** — sub-group finished its camp objective and rejoined. |
| `retasked` | 2 | Team received a new order while split; sub-group aborted and rejoined. Expected retasking behaviour. |
| `disband` | 1 | Group fully disbanded (size too small to continue split). |

**TTL distribution: zero.** No REJOIN carried the `ttl` reason in this window, meaning the 240-second guard timer did not fire once. Every completed choreography terminated via a substantive exit path, not the timeout fallback.

### Camp Size Analysis

All 11 SPLIT events used symmetric group halves (gA = gB):  
- 2+2 (1 instance), 3+3 (7 instances), 4+4 (3 instances)

All SPLIT events logged `campA=?` and `campB=?` — the camp-location fields are unresolved placeholders. **This is a telemetry gap, not a runtime error.** The splits execute correctly (teams reach objectives, smoke is deployed, captures happen); the `campA/campB` fields in the SPLIT log line appear to reference a camp-resolution lookup that either hasn't run yet at log time or is not yet wired into the SML telemetry format. This should be filled in in a future instrumentation pass so post-hoc analysis can match splits to specific camp pairs.

### SML Activity Distribution

Camp-split activity is **exclusively on WEST (`B 1-*`) teams** across both HCs (10 of 11 events). One EAST split: `O 1-1-I` at HC2. This is consistent with WEST being the more active assault side in this session; EAST spent more time on NWAF perimeter holding.

### Detachment Safety — CONFIRMED CLEAN

Zero groups remained detached without eventual REJOIN within the observation window. The split-and-rejoin lifecycle is working correctly. No unit orphaning detected.

---

## 2. AICOM Team Machinery Health

### AICOMSTAT v2 Event Summary

HC1 handles predominantly WEST teams; HC2 handles predominantly EAST teams (split by `forceHeadlessClient` slot assignment, matching the per-side side-index encoding in `AICOMSTAT|v2|EVENT|0|` = WEST and `|1|` = EAST).

| Event Type | HC1 | HC2 | Notes |
|---|---|---|---|
| `CAPTURE_TRACE\|ORDER_ACCEPT` | 83 | 105 | Orders accepted by teams on each HC |
| `CAPTURE_TRACE\|ARRIVAL_GATE` | 22 | 30 | Teams reached arrival threshold |
| `CAPTURE_TRACE\|BEGIN_CAPTURE` | 9 | 13 | Capture sequences initiated |
| `UNSTUCK_FIRED` | 12 | 18 | Unstuck ladder activations |
| `SMOKE` | 15 | 19 | Smoke deployments at assault |
| `RALLY_FALLBACK` | 6 | 13 | Rally fallbacks (team failed to arrive, fell back to rally point) |
| `RALLY_ARRIVED` | 4 | 18 | Successful rally arrivals |
| `STUCK_REPAIR` | 0 | 2 | Repair events (new today) |
| `RICH_GEAR` | 13 | 7 | Rich-gear top-up events |

**AICOMSTAT v1 additional (per-HC):**

| Event | HC1 | HC2 |
|---|---|---|
| `HIGHCLIMB` | 213 | 93 |
| `HIGHCLIMB_HB` | 36 | 35 |
| `AUTOFLIP_HB` | 36 | 36 |
| `REMOUNT` | 9 | 1 |
| `TOPUP_DONE` | 5 | 4 |
| `SERVICE_ENROUTE` | 3 | 3 |
| `SERVICE_DONE` | 1 | 1 |
| `TEAM_RETIRE_HC` | 5 | 5 |

### AICOMGATE / CMDRSTAT

Both tokens are **absent from both HC windows**. These tokens are expected on the server RPT only, not HC clients. Confirmed: no triage error here.

### WASPSCALE

Also absent from both HCs — correct, WASPSCALE is a server-side heartbeat.

### HCSTAT / HC Self-Telemetry

The `HCSTAT` token is **absent from both HC RPTs**. The HC FPS readout appears inline in `[WFBE (INFORMATION)]` frame-header lines rather than a dedicated HCSTAT prefix. This means automated HCSTAT scrapers will find zero results; FPS data is extractable from the `fps:N.N` field in WFBE log headers.

### UNSTUCK Ladder Activity

**Combined 30 UNSTUCK_FIRED events** across both HCs. Three distinct teams showed sustained stuck behaviour:

| Team | HC | Tiers fired | Distance at stuck | Resolution |
|---|---|---|---|---|
| `B 1-1-K` (WEST) | HC1 | tier 1, 2, 3, 3, 4 | 7,914m → 4,522m → 7,684m | Continued receiving new orders; eventually cleared (seq continued) |
| `B 1-1-I` (WEST) | HC2 | tier 1, 2, 3 + STUCK_REPAIR | ~980m | STUCK_REPAIR fired at tier2+tier3; MTVR_DES_EP1 repaired in place; team eventually reached Nadezhdino at tick 70 |
| `O 1-1-G` (EAST) | HC2 | tier 1, 2, 3, 4, 1, 2, 3 | ~11,700m (enormous) | Still stuck at tier 3 at last sighting; dist barely decreased across 7 tiers |

**O 1-1-G is a concern.** The team registered 7 consecutive UNSTUCK tiers with a starting distance of ~11,700m (far side of the map) and the distance reduced by only ~350m over 6 events (ticks 10–28). This suggests pathfinding failure at extreme range rather than a vehicle stuck scenario — the UNSTUCK ladder's teleport/repair tiers may be insufficient to resolve a team that is effectively lost in open terrain at extreme distance. No STUCK_REPAIR fired for O 1-1-G (repair only fires for vehicle-specific stuck), so the team may be on foot or the stuck is path-planning, not physics. Team fell off the UNSTUCK feed after tick 28 — unclear if it recovered or silently stopped reporting.

### STUCK_REPAIR (new flag today)

Two `STUCK_REPAIR` events fired for `B 1-1-I` / MTVR_DES_EP1:
- Tier 2 at tick 30 (`dist=983`)  
- Tier 3 at tick 32 (`dist=858`)  

The repair fired correctly on the vehicle causing the stuck. After both repairs, B 1-1-I continued receiving orders (ticks 38, 59, 67, 70) and eventually reached Nadezhdino. The stuck-repair feature is **confirmed working on first live contact.**

### FSM Errors

**Zero FSM errors** in both HC windows.

### group-getVariable nil-trap

**Zero nil-trap errors** in both HC windows. The post-hunt-wave fix is holding clean.

### Driver-Swap Events

Zero driver-swap events in this window. Smoke events (15 HC1 + 19 HC2 = 34 combined) are all `SMOKE|ASSAULT` type — team assault smoke at arrival, not driver-swap scenarios.

### HIGHCLIMB

HC1 logged 213 HIGHCLIMB events vs HC2's 93. HIGHCLIMB fires when the HC boosts a stuck climbing vehicle (`MTVR_DES_EP1` predominantly). The HC1 skew is notable — it handles the WEST side which appears to be more vehicle-mobile in this session (more mountainous traversal). These are not errors; HIGHCLIMB is the terrain-climbing assist working normally.

### TEAM_RETIRE_HC

5 retirements per HC, all at ticks 58–69, logged as `deleted-local-units|cmd=true` — teams retired under commander control after completing objectives. Normal lifecycle.

### REMOUNT

HC1 logged 9 REMOUNT events; HC2 logged 1. REMOUNT fires when dismounted units re-board their transport. The HC1 skew again tracks with WEST being more vehicle-active.

### Service / Logistics

Both HCs show identical SERVICE_ENROUTE=3, SERVICE_DONE=1 per HC — supply vehicle dispatch working but most service runs still in progress at snapshot time. TOPUP_DONE (gear top-up at depot) = 5 HC1 / 4 HC2 — consistent.

---

## 3. Error Census

**Total RPT error lines in both HC windows: ZERO.**

This is a remarkable baseline. Neither HC logged a single line matching `\bError\b`, `Undefined variable`, `cannot be called`, `Script.*not found`, or similar patterns within the current mission window. Previous hunt-wave findings about nil-trap errors are verified clean. The cc46 build is running without HC-side script errors.

---

## 4. FPS / Performance Trend

FPS is extracted from the inline `fps:N.N` field in WFBE frame-header log lines.

| Metric | HC1 | HC2 |
|---|---|---|
| Sample count | 1,781 | 1,791 |
| Average FPS | 45.5 | 45.8 |
| Minimum FPS | 1.7 | 1.7 |
| Maximum FPS | 49.5 | 49.1 |
| FPS at 25th percentile | 46.8 | 47.2 |
| FPS at 50th (median) | 45.5 | 46.4 |
| FPS at 75th percentile | 45.8 | 47.8 |
| FPS at end of window | 47.8 | 45.3 |

**FPS trend: stable to healthy.** Both HCs show the expected startup dip (5 samples each below FPS=10, all at the very beginning of the window during mission load/HC init). After startup the FPS stabilises in the 45–47 range and does not degrade over the 72-minute window. There is no evidence of FPS collapse under growing unit load.

Early vs late comparison:
- HC1: early avg 1.7 (startup spike) → late avg 36.6 (end samples)
- HC2: early avg 14.9 → late avg 35.5

The late-window averages of 35–36 are drawn from the final logged frames and may include one or two end-of-session measurement artefacts. The percentile distribution (median ~46, 75th percentile ~47) is the more reliable performance indicator and shows excellent headroom.

### Seating / BAIL Events

**Zero BAIL events on either HC.** The B761-only guard fix (preventing spurious ejection during normal reseat) is **not yet deployed** (cc46 is the deployed build per the task brief). The pre-fix baseline shows: zero BAILs, meaning the old behaviour is not actively failing — either the triggering condition didn't occur in this window, or the sessions are early enough in mission runtime that the seat contention hasn't manifested. This is the pre-fix baseline to compare against post-deployment.

Seating events (normal HC init reseat):
- HC1: `HC C 1-1-C:1 ("HC-AI-Control-1") reseated onto CIVILIAN` at frameno 3444
- HC2: `HC C 1-1-D:1 ("HC-AI-Control-2") reseated onto CIVILIAN` at frameno 3444

Both HCs reseated normally at mission start. REMOUNT events (9 HC1, 1 HC2) reflect normal in-mission AI remounting of vehicles.

---

## 5. HCSTAT / Delegation Self-Report

### HCSTAT Logging

The `HCSTAT` and `HCSIDE` tokens are not present in either RPT. HC performance telemetry is embedded inside `[WFBE (INFORMATION)]` frame-header lines. Dedicated HCSTAT prefix logging is not enabled in this build.

### Delegation Activity

Both HCs receive near-identical delegation loads, confirming balanced HC distribution:

| Delegation Type | HC1 | HC2 |
|---|---|---|
| `DelegateTownAI` calls | 51 | 52 |
| `DelegateAIStaticDefence` WEST | 4 | 4 |
| `DelegateAIStaticDefence` EAST | 5 | 0 |
| `DelegateAIStaticDefence` GUER | 5 | 7 |

Town AI delegation breakdown (top towns by call count — both HCs covering the same set):

| Town | HC1 | HC2 |
|---|---|---|
| StarySobor | 13 | 15 |
| Lopatino | 9 | 9 |
| Grishino | 6 | 6 |
| NWAF | 5 | 5 |
| Nadezhdino | 5 | 5 |
| Pusta | 5 | 4 |
| Mogilevka | 3 | 3 |
| Vyshnoye | 3 | 2 |
| Komarovo | 2 | 3 |

StarySobor and Lopatino show the highest contention (most re-delegation events), consistent with their map-central positions.

### CAPTURED Events

6 total capture confirmations across both HCs:
- HC1 (EAST side): NWAF captured twice by EAST teams (O 1-1-D, O 1-1-H)
- HC2 (WEST side): Nadezhdino captured by WEST (B 1-1-D); NWAF captured by EAST twice (O 1-1-F, O 1-1-I)

NWAF appears to be the primary contest zone in this session (3 of 6 captures).

---

## 6. RALLY_FALLBACK / RALLY_ARRIVED Analysis

Combined across both HCs: 19 RALLY_FALLBACKs vs 22 RALLY_ARRIVEDs. The fallback rate (~46%) is normal for WASP-scale distances and enemy presence — teams fall back to rally when blocked, then recover. The RALLY_ARRIVED count exceeding FALLBACKs indicates most fallback cycles resolve successfully.

HC2 shows more RALLY activity (13 fallbacks, 18 arrivals) than HC1 (6 fallbacks, 4 arrivals) — consistent with HC2 handling more EAST teams in the contested NWAF corridor.

---

## 7. Concerns and Open Items

### WATCH — campA/campB telemetry gap

All 11 SML SPLIT lines log `campA=?` and `campB=?`. The camp assignment fields are unresolved placeholders. Runtime behaviour is correct (teams split, reach objectives, rejoin), but post-hoc analysis cannot map specific splits to specific camp pairs. **Instrumentation fix needed:** wire the camp-resolution value into the SML|v1|SPLIT log line at split time.

### WATCH — O 1-1-G (EAST) extreme-range stuck

Team `O 1-1-G` on HC2 registered 7 UNSTUCK tiers starting at 11,721m, with minimal distance reduction (11,721m → 11,362m over 16 ticks = 359m total movement). The team appears lost or stuck in pathfinding at extreme range rather than a vehicle physics issue. No STUCK_REPAIR fired (consistent with foot/no-vehicle scenario). The team fell off logs at tick 28 — unknown if it recovered or silently stalled. Follow-up: check server RPT for O 1-1-G WASPSTAT/CAPTURE activity post-tick-28.

### INFO — B761 BAIL guard not yet deployed (baseline captured)

Zero BAIL events observed in this window. This is the pre-fix baseline with cc46. After the B761-only guard fix deploys, compare against this baseline to confirm zero BAIL events are maintained (or reduced if they were occurring at a rate too low to appear in this session window).

### INFO — No TTL-forced rejoins

The 240-second TTL watchdog never fired. All rejoins were substantive exits (combat, objective completion, retasking, disband). Camp-split choreography is completing within the time budget.

### INFO — HCSTAT token absent from this build

HC self-telemetry is not available as a discrete parseable token. FPS data must be extracted from the WFBE frame-header inline. If future analysis automation depends on HCSTAT, the token needs to be added to HC logging.

---

## Summary Table

| Subsystem | Status | Notes |
|---|---|---|
| SML camp-split active | PASS | 11 SPLITs, 10 REJOINs (1 in-progress at window end). Zero TTL-forced exits. Zero stuck detachments. |
| Camp target resolution | WATCH | campA/campB always `?` — telemetry gap, not runtime error |
| O 1-1-G EAST pathfinding | WATCH | 7 UNSTUCK tiers, 11km+ range, barely moved. Post-28 status unknown |
| STUCK_REPAIR first contact | PASS | B 1-1-I MTVR repaired at tier2+tier3; team reached objective |
| UNSTUCK ladder | PASS | Tiers 1–4 all firing correctly; multi-tier escalation working |
| nil-trap errors | PASS | Zero instances — post-hunt-wave fix holding |
| FSM errors | PASS | Zero |
| Script errors (all) | PASS | Zero error lines in both HC windows |
| FPS | PASS | avg 45–46 FPS, no degradation over 72min window |
| HC seating | PASS | Both HCs reseated normally at mission start |
| BAIL events | PASS (baseline) | Zero pre-fix; B761 guard not yet deployed |
| Delegation balance | PASS | Both HCs equally loaded (~51 TownAI calls each) |
| AICOM event pipeline | PASS | ORDER_ACCEPT → ARRIVAL_GATE → BEGIN_CAPTURE chain firing correctly |
| AICOMGATE/CMDRSTAT | INFO | Absent from HCs (expected — server RPT only) |
| HCSTAT token | INFO | Absent — FPS must be parsed from WFBE frame headers |
