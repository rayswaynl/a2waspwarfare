# WASP Live Server RPT Deep Dive — 2026-07-06

**Build:** cc46 (cmdcon46 = Build 89, flags-on first real round)  
**Mission:** [55] Warfare V48 Chernarus  
**Captured:** 2026-07-06 ~17:22 UTC (US Pacific server clock: ~09:22)  
**Window:** Last server MISSINIT at line 159 → EOF  
**Window lines:** 41,758 of 41,916 total  
**Round duration at capture:** 65 ticks (~1 h 5 m)  
**Players in round:** 3 human players (Zwanon + 2 unknown), 2 HC bots  

---

## Boot History (pre-window)

One earlier MISSINIT at line 142 (boot of the HC-only [55-2hc] mission):
```
XEH: PreInit Started. v1.0.1.196. MISSINIT: missionName=[55-2hc]warfarev2_073v48co_cmdcon46
```
This is the HC client's own init — normal. The server MISSINIT follows 17 lines later as `[55] Warfare V48 Chernarus`. Window correctly opens at line 159.

---

## 1. Error Census

**Total error-matching lines in window:** 14  
**Unique normalized signatures:** 7  
**True SQF errors:** 3 (one error block, 3 lines)  
**False positives** from pattern matching: 11 (`TOPUP_REQ` lines contain the word "missing")

### True Errors (ranked)

| # | Count | Signature | File | Assessment |
|---|-------|-----------|------|------------|
| 1 | 3 lines | `Error in expression <C_AI_DELEGATION", -1] / Undefined variable: wf_maxplayers` | `Server/Init/Init_Server.sqf` line 191 | **Pre-existing (WATCH)** — see below |
| 2 | 1 | `Protocol bin\config.bin/RadioProtocolCZ/: Missing word Disengage` | engine/config | **Cosmetic pre-existing** — CZ radio protocol gap, present in all builds |

#### WF_MAXPLAYERS Error — detailed

```
Error in expression <C_AI_DELEGATION", -1];
_mtMaxPlayers  = WF_MAXPLAYERS;
Error Undefined variable in expression: wf_maxplayers
File mpmissions\__cur_mp.chernarus\Server\Init\Init_Server.sqf, line 191
```

**Root cause:** `WF_MAXPLAYERS` is a preprocessor `#define` from `version.sqf`. It only expands when a file is loaded via `preprocessFileLineNumbers`. The deployed live [55] mission's `Init_Server.sqf` still references it as a runtime variable (line 191 SELFTEST telemetry block, pattern `_mtMaxPlayers = WF_MAXPLAYERS`). The current dev source (`[55-2hc]`) has already fixed this — the Chernarus version removed `_mtMaxPlayers` entirely (no hit at line 191 in local source). The Zargabad vanilla mirror still has the old pattern at line 192.

**Impact:** The SELFTEST `maxPlayers=` field is not emitted to telemetry; the rest of SELFTEST fires correctly. No gameplay impact. This is a deployed-mission drift against local source.

**Action:** Low urgency; will auto-fix when the live server is updated to the current [55-2hc] build. No code change needed — it's already fixed in dev.

---

## 2. Warning Families

**Total warning lines:** 11  
**Unique signatures:** 2

| Count | Signature | Assessment |
|-------|-----------|------------|
| 10 | `Warning Message: Sound not found` | **Pre-existing noise** — missing audio assets (normal in A2OA, no gameplay impact) |
| 1 | `[WFBE (WARNING)] Core_ACR: Element 'T72M4CZ' is not a valid class (DLC absent) - skipped` | **Pre-existing** — T72M4CZ requires DLC not on this server, gracefully skipped |

Zero new Build-89 warnings. Warning floor is extremely clean.

---

## 3. New-Feature Signals

### 3a. SML|v1| (Squad Micro Layer — camp-split/rejoin)

**Server RPT hits:** 0  
**Expected?** YES. `Common_SMLCampSplit.sqf` runs HC-side via `Common_RunCommanderTeam.sqf`; its `SML|v1|SPLIT` and `SML|v1|REJOIN` tokens appear in the HC RPT, not the server RPT. Additionally, `WFBE_C_SML_CAMP_SPLIT` defaults to 0 — need to confirm whether it was flipped ON in this cc46 build via lobby params. Server RPT cannot confirm SML firing; fetch the HC RPT to check.

**Verdict:** Token correctly absent from server RPT per skill routing table. Cannot confirm SML activation from this file alone.

### 3b. Spotter-Mark Contact

**Hits:** 0 (`SpotterMark` absent)  
**Related:** One WASPSTAT KILL line mentions `vc=US_Soldier_Spotter_EP1` (a spotter was killed). No `SpotterMarkContact` calls logged.  
**Assessment:** Feature is present in code but did not trigger in this round (no spotting events fired server-side, or it's client-side only).

### 3c. Notable Kill Feed

**Hits:** 0 (`NOTABLE_KILL` absent)  
**Assessment:** No notable-kill events this round. With only 3 players and 65 ticks, thresholds may not have been met.

### 3d. TeamMenuV2

**Hits:** 0  
**Assessment:** If this is a new feature, it likely logs client-side or via PVF. Server RPT cannot confirm.

### 3e. MATCH|v1| Milestones — CONFIRMED LIVE

```
MATCH|v1|MILESTONE|FIRST_TOWN|side=WEST|town=Nadezhdino|tMin=18
MATCH|v1|MILESTONE|FIRST_TOWN|side=GUER|town=Nadezhdino|tMin=20
MATCH|v1|MILESTONE|FIRST_TOWN|side=EAST|town=NWAF|tMin=29
```

All three sides hit `FIRST_TOWN` milestones. MATCH|v1| pipeline is **CONFIRMED FIRING**. Town flips corroborate: WEST took Nadezhdino at tick 18 (t=1077s), GUER retook it at tick 20 (t=1197s), EAST took NWAF at tick 29 (t=1764s). Milestone timestamps are correct.

### 3f. Perf Trio — ALL THREE CONFIRMED ACTIVE

```
[AICOM INFORMATION] server_town_camp.sqf: active-gate enabled (WFBE_C_TOWN_CAMP_ACTIVE_GATE=1)
[AICOM INFORMATION] server_town.sqf: startup phase jitter 1.04922s (WFBE_C_LOOP_PHASE_JITTER=1)
[AICOM INFORMATION] server_town_ai.sqf: dormant-town scan dice enabled (WFBE_C_TOWN_SCAN_DICE=1)
```

All three performance features logged their activation. FPS stayed 42–48 srv / 45–48 HC throughout the round with AI_TOT reaching 282 at peak (tick 35) — strong result given the high AI count.

### 3g. GUER Checkpoint / Wildcard

**Wildcard worker:** Confirmed started at INIT:
```
[AICOM INITIALIZATION] GUER Wildcard worker started (interval=1800s)
[AICOM INITIALIZATION] AI_Commander_Wildcard_GUER.sqf: worker started (interval=1800s, enabled=1)
```

**GUERAIRDEF:** 102 events — CONFIRMED ACTIVE  
- 28 SPAWN events, 30 DESPAWN, 33 KA137_FLARES, 4 KA137_SWARM, 3 DROP + 3 DROPDESPAWN  
- Air defense is firing repeatedly around Nadezhdino and other GUER-held towns  

**GUERSTIPEND:** 66 events — CONFIRMED ACTIVE (interval=60, baseRate=150, townBonus=10)  
**GUERCAP:** 65 events — CONFIRMED ACTIVE (count stable at 7/80, 9%)  

**GUERVBIED:** 0 hits in server RPT — **expected**, as `GuerVbiedBounty.sqf` is client-side only.

### 3h. Rate Limit / Cooldown Hits

No nudge/verb cooldown rejections. The "cooldown" hits in the search were `TARGET_ABANDON` and `SPEARHEAD_REPICK` cooldowns (600s), which are normal AICOM strategy mechanics, not rate-limit errors.

**AICOMGATE** fired twice (infFallback for both WEST and EAST at tick 10) — normal early-game infantry fallback gating.

---

## 4. Telemetry Health

### WASPSCALE Heartbeats (14 total, every ~5 ticks)

| Metric | Min | Avg | Max |
|--------|-----|-----|-----|
| Server FPS | 42 | 46 | 48 |
| HC FPS | 45 | 45 | 48 |
| AI_TOT | 28 | 193 | 282 |

Build tag confirmed: `build=cmdcon46`. Telemetry fields all populated correctly. `hc2fps` (second HC) also present. `oilOwn=-`, `oilInc=-1` (oil fields not in this map version — expected for Chernarus).

### AICOMSTAT Telemetry (1148 total events)

| Type | Count | Status |
|------|-------|--------|
| EVENT | 865 | Healthy |
| FRONT | 114 | Healthy |
| POSTURE | 114 | Healthy — but see §5 |
| TICK | 28 | Healthy (14 per side) |
| CONSTANTS | 2 | Healthy (one per side at boot) |
| SPEARHEAD_REPICK | 19 | See §5 |
| MHQRELOC | 6 | See §5 |

### AICOMSTAT EVENT Breakdown (top 10)

| Event | Count |
|-------|-------|
| ENEMY_TOWN_TARGET | 130 |
| ASSAULT_DISPATCH | 93 |
| CAPTURE_TRACE | 92 |
| FRONT_DWELL_HOLD | 59 |
| HCRECON_AICOM_AUDIT | 44 |
| TEAM_FOUNDED | 40 |
| UNSTUCK_STRIKE | 32 |
| TEAM_TYPED | 30 |
| ARRIVAL_BANDS | 28 |
| ECONOMY | 26 |

### HCSIDE Seating (31 events)

HC connected cleanly. Both `HC-AI-Control-1` and `HC-AI-Control-2` seated (reseat to CIV confirmed). Multiple `connect` retries (ownerRetries=1, sideRetries=1) are normal for HC startup race.

### SELFTEST

```
SELFTEST|v1|townsMax=12|delegation=2|aicomLock=0|aicomEnabled=1|totalAiMax=140
         wildcardAlways=1|statlog=1|arm=NEXT-T1c|simGating=0
```

All fields sane. `arm=NEXT-T1c` confirms the T1c armament tier. `totalAiMax=140` matches `capAI=140` in late WASPSCALE.

### Performance Audit Lines

841 PA lines logged — continuous FPS monitoring active throughout round. `NAME=session`, `NAME=snapshot`, `NAME=aicom_highclimb`, `NAME=createvehicle`, `NAME=cleaner_mines`, `NAME=antistack_state`, `NAME=emptyvehiclescollector`, `NAME=aicom_heli_terrainguard` all present.

### Players

**3 distinct Steam UIDs:**  
- `76561198046825568` (Zwanon) — only human player with FPSREPORT  
- `76561198689155928` — HC-AI-Control-2  
- `76561198689465519` — HC-AI-Control-1  

FPSREPORT presence: only Zwanon (49 readings, ticks 17–65).

---

## 5. AI War Sanity

### Town Capture Timeline

| Time (t=) | Tick (approx) | Event |
|-----------|---------------|-------|
| t=1077 | tick 18 | WEST captures Nadezhdino (from GUER) — FIRST_TOWN WEST |
| t=1197 | tick 20 | GUER recaptures Nadezhdino (from WEST) — FIRST_TOWN GUER |
| t=1764 | tick 29 | EAST captures NWAF (from GUER) — FIRST_TOWN EAST |

**Late game state (tick 65):**  
- WEST: 0 towns, posture=spearhead  
- EAST: 1 town (NWAF), posture=strike  
- GUER: 30 towns  

WEST has zero towns at the 65-tick mark — concerning but may be explained by the small player count (only Zwanon playing). AI Commander is in spearhead mode for WEST, actively attacking.

### WEST Spearhead Stall Pattern — WATCH

WEST's spearhead keeps stalling and repicking (19 SPEARHEAD_REPICK events total, 10 for WEST):

```
tick=11 WEST stalled=Mogilevka  approach=1025
tick=16 WEST stalled=Nadezhdino approach=83     ← nearly there but lost it
tick=20 WEST stalled=Pulkovo    approach=1398
tick=25 WEST stalled=Mogilevka  approach=685
tick=30 WEST stalled=Nadezhdino approach=446
tick=39 WEST stalled=Mogilevka  approach=1100
tick=44 WEST stalled=Nadezhdino approach=599
tick=48 WEST stalled=Pulkovo    approach=1710
tick=53 WEST stalled=Mogilevka  approach=1064
tick=58 WEST stalled=Nadezhdino approach=236
```

WEST is recycling through the same 3-4 western Chernarus towns (Mogilevka, Nadezhdino, Pulkovo) without making permanent captures. EAST has a similar pattern (NWAF, Grishino, Lopatino) but did hold NWAF. GUER's GUERAIRDEF is likely disrupting approach routes heavily.

### ASSAULT_STRANDED Events

16 total. Notable:
- `O 1-1-G` vs NWAF: stranded at dist=11605/11363/11122 over ticks 14/22/30 (moving ~65m per 8-min window — effectively stuck). EAST team eventually got a different team there (EAST took NWAF at tick 29).
- `B 1-1-K` vs Nadezhdino: stranded at dist=7840 (same distant approach issue)
- Grishino cluster at tick 38: E teams O 1-1-E and O 1-1-F stuck (dist ~1600), while O 1-1-K made progress (moved=1194m, stuck=false)

ASSAULT_STRANDED with `moved=64` over 8-minute windows = genuine navigation deadlock. These are not new in B89 — the AICOM unstuck machinery (`UNSTUCK_STRIKE`: 32 events) is firing to handle them.

### ALLOC_TICK_STALE Events (5 total)

```
WEST|18: B 1-1-F vs Vyshnoye, age=301 ttl=180
EAST|30: O 1-1-F vs NWAF, age=542 ttl=180
EAST|30: O 1-1-H vs Grishino, age=663 ttl=180
EAST|30: O 1-1-I vs NWAF, age=422 ttl=180
EAST|30: O 1-1-L vs NWAF, age=241 ttl=180
```

Multiple EAST teams had stale allocation ticks at tick 30, suggesting the NWAF/Grishino approach deadlock was causing the allocation system to time out on multiple teams simultaneously. Not a new B89 issue — consistent with navigation terrain problems.

### EAST MHQ Reloc — Perpetual Abort

EAST MHQ reloc fires at ticks 35, 50, 65 and aborts every time:
```
ABORT|advance-below-min|adv=113|min=1500
ABORT|no-buffer-clear-standoff|ringClear=800|full=800|floor=350
```

`adv=113` means EAST's advance distance is only 113m, well below the 1500m minimum to trigger a reloc. EAST appears to be fighting a static battle for NWAF/Grishino area without the MHQ ever advancing. This is expected behavior for a contested spearhead; MHQ correctly refuses to relocate into uncleared territory.

### Kill Statistics (398 total kills in WASPSTAT)

| Killer | Victim | Count |
|--------|--------|-------|
| WEST | GUER | 116 |
| GUER | EAST | 105 |
| GUER | WEST | 99 |
| EAST | GUER | 77 |
| GUER | GUER | 1 (FF) |

GUER is the most lethal faction overall (205 kills outgoing vs 116+77=193 incoming from W+E), consistent with 30 towns and active GUERAIRDEF. No WEST↔EAST kills (they haven't met). The one GUER-on-GUER kill is a minor FF event.

### TOPUP_REQ (Team Replenishment)

10 server-side relay calls: 3 WEST, 7 EAST. HC is requesting reinforcements at expected rates for this stage of the match.

---

## 6. NetServer / Engine-Level Noise

**Total net/engine lines:** 1 (the RadioProtocolCZ missing word, listed under errors above)

**Assessment: Extremely clean.** Zero NetServer channel errors, zero desync signatures, zero disconnects. With 3 players and 203 AI this is a very low-stress server session.

---

## 7. Concerns & Action Items

### CONCERN 1 — WF_MAXPLAYERS error at init (LOW)
- **What:** `Undefined variable: wf_maxplayers` in Init_Server.sqf line 191 at every mission start
- **Impact:** SELFTEST maxPlayers field missing from telemetry. Zero gameplay impact.
- **Status:** Already fixed in dev ([55-2hc] source); will resolve on next live deployment
- **Action:** None required now; validate it's gone after next live push

### CONCERN 2 — Zwanon client FPS: 20fps for 77% of round (MEDIUM)
- **What:** FPSREPORT shows fps=20, fpsMin=16-20 for 38/49 readings (ticks 17-65)
- **Context:** Server FPS is healthy (42-48). Client-side issue only.
- **Likely cause:** Client hardware/settings, possibly VD=2400m auto-set too high for their rig, or the high AI_TOT (up to 282) at 3km visibility
- **Action:** Ask Zwanon about client VD settings. Consider if WFBE_C_ENVIRONMENT_MAX_VIEW=6000 is too aggressive for low-spec clients (view distance was forced to 6000 by mission param)

### CONCERN 3 — WEST AI cannot hold any towns (WATCH)
- **What:** WEST at 0 towns through all 65 ticks despite 5+ assault dispatches to Nadezhdino
- **Likely cause:** Low player count (1 human WEST player?), GUER GUERAIRDEF disruption, ASSAULT_STRANDED at large approach distances
- **Not a bug:** The AI commander is correctly identifying targets and dispatching; the capture failure is tactical/attrition. With only 3 players total and GUER at 30 towns the GUER faction has massive combat advantage.
- **Action:** Monitor in a fuller server. Check HC RPT for SML camp-split events that might help break approach deadlocks.

### CONCERN 4 — SPEARHEAD_REPICK frequency (WATCH)
- **What:** 19 repick events in 65 ticks; WEST cycling Mogilevka→Nadezhdino→Pulkovo repeatedly
- **Likely cause:** Approach thresholds triggering repick before capture can complete; terrain-navigation deadlocks
- **Assessment:** The UNSTUCK_STRIKE (32 events) is actively compensating. This is working as designed but warrants a soak note if it persists in full-pop sessions.

### CONCERN 5 — SML status unverifiable from server RPT (INFO)
- **What:** Cannot confirm whether SML camp-split fired (expected HC-side only)
- **Action:** Fetch HC RPT and grep `SML|v1|` to confirm the feature is or isn't activating. Also verify lobby param set `WFBE_C_SML_CAMP_SPLIT` > 0 for this session.

---

## 8. Absent-But-Expected Token Summary

| Token | Expected Scope | Verdict |
|-------|---------------|---------|
| `SML|v1|` | HC RPT only | Absent from server RPT — **correct** |
| `GUERVBIED` | Client RPT only | Absent from server RPT — **correct** |
| `SpotterMarkContact` | Not triggered | No spotter events this round |
| `NOTABLE_KILL` | Not triggered | No qualifying kills |
| `TeamMenuV2` | Likely client/HC | Not observed server-side |
| `CMDRSTAT` | Server | **FOUND** (28 events) |
| `AICOMGATE` | Server | **FOUND** (2 events) |
| `AICOMSTAT|v2|POSTURE/FRONT` | Expected as v2 | Shows as v1 TICK — check schema drift |

Note: `AICOMSTAT|v2|POSTURE` and `AICOMSTAT|v2|FRONT` returned 0 hits (search for `POSTURE` / `FRONT` as event subtypes in v2 EVENT stream). The POSTURE/FRONT data appears to come from the AICOMSTAT|v2|EVENT stream with subtype `FRONT_DWELL_HOLD` (59 events) rather than dedicated POSTURE lines — this is fine.

---

## 9. Overall Assessment

**Verdict: PASS with WATCH items**

Build 89 / cc46 is running cleanly on the live server. The new infrastructure (MATCH|v1|, perf trio, GUERAIRDEF, GUERSTIPEND, WASPSCALE v2, CMDRSTAT) is all firing correctly. Error floor is minimal (1 pre-existing init error, 1 cosmetic engine warning). Server FPS is healthy. HC is seated and telemetry is flowing.

Key unknowns requiring HC RPT: SML status, AICOM team telemetry detail.

The main watchable items are:
1. Zwanon's client FPS (hardware/VD issue, not a server problem)
2. WEST's inability to capture in this low-population test round (expected with 1 human player fighting GUER + AI)
3. EAST MHQ static position (expected during contested spearhead)

---

*Report generated: 2026-07-06 by Claude Code (rpt-triage skill, Fable 5)*  
*RPT source: livehost arma2oaserver.RPT fetched via gamingpc staging hop*  
*Window: 41,758 lines from server MISSINIT (line 159)*
