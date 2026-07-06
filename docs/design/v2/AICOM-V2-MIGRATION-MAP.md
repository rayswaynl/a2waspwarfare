# AICOM V2 Migration Map — Spec ↔ Live Reconciliation

**Artifact name:** `AICOM-V2-MIGRATION-MAP.md`
**Guide-Rev:** GR-2026-07-03a
**Status:** v1 DRAFT — binding for cutover step 2 (build gate). TBD cells are called out; do not advance to cutover-build without resolving them.
**Owner ruling:** Ray, 2026-07-05. Source: `docs/design/v2/AICOM-V2-CUTOVER-AND-RECONCILIATION.md`.

This map is the mandatory output of cutover **Step 1 (Map)**. Every V1 worker, constant, and telemetry emitter must appear in one of the tables below. A V1 surface not listed here blocks the cutover build.

---

## Part 1 — AICOMV2_x ↔ AICOM2_y Record/Function Mapping Table

The spec line (Codex pack PRs #700-705) named records `AICOMV2_*`. The live lane
(`fable/aicom-v2-l1-press-fix`) uses `AICOM2_*` / `WFBE_SE_FNC_AICOM2_*` names registered in
`Init_Server.sqf` lines 79-81. The reconciliation direction per the cutover brief: **live names
win; spec vocabulary is renamed to match live**.

### Milestone / Module Mapping

| Spec pack name (PRs #700-705) | Live-lane equivalent | File | Status | Notes |
|---|---|---|---|---|
| `AICOMV2_PullWorldState` | `WFBE_SE_FNC_AICOM2_Snapshot` | `AI_Commander_Snapshot.sqf` | LIVE (M0) | Full world-model snapshot; builds `wfbe_aicom2_snap` indexed by `WFBE_SNAP_*` constants (`Init_CommonConstants.sqf` lines 693-706). Behaviour-neutral shadow — nothing in the spec pack replaces it. **Spec name dropped; live name wins.** |
| `AICOMV2_Allocate` | `WFBE_SE_FNC_AICOM2_Allocate` | `AI_Commander_Allocate.sqf` | LIVE (M1/M2/M4/M5) | Concentrates on one front fist (`WFBE_C_AICOM2_FIST_TOWNS`), M2 harass, M4 focus, M5 support-push, expansion-first gate + contested-engage fix (BUG-1, `WFBE_C_AICOM_ENGAGE_CONTESTED` default 1). **Spec name dropped.** |
| `AICOMV2_Execute` | `WFBE_SE_FNC_AI_Com_Execute` | `AI_Commander_Execute.sqf` | V1 FILE — KEEP | Direction-agnostic waypoint issuer. Turns `wfbe_teammode`/`wfbe_teamgoto` into real waypoints. Not replaced by any V2 file. Survives cutover unchanged. |
| `AICOMV2_Decapitate` | `WFBE_SE_FNC_AICOM2_Decapitate` | `AI_Commander_Decapitate.sqf` | LIVE (M5, flag default 0) | Organic base-sensing + ARM/COMMIT/ABORT state machine (`wfbe_aicom2_decap_streak`, `_committed`, etc. on side logic). Consumes Snapshot; stamps `wfbe_aicom_decap` broadcast (A2-OA network-safe); press hook in `Common_RunCommanderTeam.sqf` line 928 consumes the stamp. **Spec name dropped; live name wins.** |
| `AICOMV2_PressHook` (driver-press) | Press hook block | `Common_RunCommanderTeam.sqf` lines 928-996 | LIVE | HC-local press handler: reads `wfbe_aicom_decap` broadcast stamp → overrides dest, sets `wfbe_aicom_press_on` latch, emits `AICOM2|v1|DECAP|…|PRESS|`. Not a standalone file; embedded in the team driver. **Spec name dropped.** |
| Spec stance machine (`AICOMV2_StanceEval`) | `AI_Commander_Strategy.sqf` POSTURE line (~line 1034) | `AI_Commander_Strategy.sqf` | V1 — TBD | The V1 Strategy worker computes ATTACK/DEFEND/LAST-STAND/HQ-STRIKE and emits `AICOMSTAT|v1|POSTURE`. No standalone V2 stance machine was built in the live lane. **Gap G4: POSTURE content is PORTed (see Part 3); the clean V2 stance machine is a post-cutover N3 increment (lane 408). Does not block the one-shot cutover.** |
| `WFBE_SNAP_*` constants (index schema) | Array index constants | `Init_CommonConstants.sqf` lines 693-706 | LIVE | 26-field layout: `WFBE_SNAP_TIME=0`…`WFBE_SNAP_TGTTOWNOBJS=25`; per-team digest `WFBE_SNT_*` constants follow. Spec record names map to array indices; no naming conflict. |
| `AICOM2_Snapshot` (namespace var) | `wfbe_aicom2_snap` on side logic object | — | LIVE | The cached snapshot array. Read by Allocate (`_snap = _logik getVariable ["wfbe_aicom2_snap", []]`), Decapitate, Strategy (`_snapOk` path at line 33), AssignTowns (`_allocTgt` path). |
| Spec harness acceptance fixtures | `Tools/PrTestHarness/Aicom/Score-AicomRounds.ps1` + `Tools/PrTestHarness/Ops/aicom-watch.ps1` | `fable/soak-gate-tooling` | EXISTS — NOT YET MERGED | Scorer and watcher exist on `fable/soak-gate-tooling`; parse AICOM2 natively. **Must merge to base before parity-soak step 3 can gate anything (Gap G1).** |

### V1 Files at a glance — 18 workers

| V1 Worker File | V2 Disposition |
|---|---|
| `AI_Commander.sqf` (supervisor) | KEEP — calls all workers; adds `WFBE_SE_FNC_AICOM2_*` milestones |
| `AI_Commander_Snapshot.sqf` | KEEP — IS the V2 M0 implementation |
| `AI_Commander_Allocate.sqf` | KEEP — IS the V2 M1/M2/M4/M5 implementation |
| `AI_Commander_Decapitate.sqf` | KEEP — IS the V2 M5 closer |
| `AI_Commander_Strategy.sqf` | KEEP (modified) — V2 gates the HQ-strike block when DECAP is armed; POSTURE line ported |
| `AI_Commander_Execute.sqf` | KEEP — direction-agnostic |
| `AI_Commander_AssignTowns.sqf` | KEEP — route/dispatch/stuck; reads `wfbe_aicom_alloc_target` set by Allocate |
| `AI_Commander_AssignTypes.sqf` | KEEP — template assignment; unchanged |
| `AI_Commander_Teams.sqf` | KEEP — team founding; unchanged |
| `AI_Commander_Produce.sqf` | KEEP — per-unit reinforcement; unchanged |
| `AI_Commander_Base.sqf` | KEEP — HQ deploy + base build; unchanged |
| `AI_Commander_BaseSell.sqf` | KEEP — structure recycle; unchanged |
| `AI_Commander_FundsSink.sqf` | KEEP — wealth-conversion surge; unchanged |
| `AI_Commander_MHQReloc.sqf` | KEEP — MHQ relocation; unchanged |
| `AI_Commander_DisbandLowTier.sqf` | KEEP — disband selector; unchanged |
| `AI_Commander_Beacon.sqf` | KEEP — forward spawn beacon; unchanged |
| `AI_Commander_Paratroops.sqf` | KEEP — paratroop reinforcement; unchanged |
| `AI_Commander_PlayerArty.sqf` | KEEP — player arty resolver; unchanged |

No V1 worker files are deleted at cutover step 2. Deletions happen at step 4 (Shelve) only for files
whose content has been fully superseded by V2 equivalents. Based on live-lane code, no V1 worker is
fully superseded today — the new V2 files (`Snapshot.sqf`, `Allocate.sqf`, `Decapitate.sqf`) are
additions that run alongside V1 workers, not replacements. `AI_Commander_HCTopUp.DRAFT.sqf` is a
draft not compiled by Init_Server.sqf; shelve it at step 4.

---

## Part 2 — Unified Telemetry Grammar Decision

### Decision: `AICOM2|v1|` grows the v3 features

Per the cutover brief §Fork resolution: "Either the `AICOM2|v1|` family grows the v3 features … or
the v3 grammar adopts the `AICOM2` prefix — builders pick one."

**Ruling: `AICOM2|v1|` is the unified prefix.** Rationale:

- The live lane already emits `AICOM2|v1|SNAP`, `AICOM2|v1|ALLOC`, `AICOM2|v1|DECAP`,
  `AICOM2|v1|FISTPOOL` (39 emitters in 5 files).
- `analyze_soak.py` and `Score-AicomRounds.ps1` already parse `AICOM2|v1|*` natively
  (on `fable/soak-gate-tooling`).
- Growing in-place avoids a global find-replace across the mission tree and keeps the soak
  tooling intact.
- The `AICOMSTAT|v3|` grammar from the spec pack is abandoned; its named rows (PLAN/WHY/INTEL)
  are implemented under `AICOM2|v1|` below.

### Concrete line grammars for the three v3 additions

All lines use pipe-delimited key=value fields after a fixed positional prefix. Fields are
optional/sparse — a consumer that does not understand a field ignores it. `tick` is always
`round(time/60)` (integer minutes elapsed). No pipes inside field values.

#### WHY rows (decision correlation)

Emitted immediately following an action line when the Allocator or Decapitate makes a significant
state change. One WHY row per decision. Format:

```
AICOM2|v1|WHY|<SIDE>|<tick>|act=<ACTION_TYPE>|reason=<REASON_CODE>|intel=<INTEL_KEY>|conf=<0..1 float 1dp>|detail=<freeform no-pipes>
```

Examples:
```
AICOM2|v1|WHY|west|42|act=FIST_CHANGE|reason=FRONT_ADVANCE|intel=myTowns_gt_prev|conf=0.9|detail=fist moved Elektro to Chernogorsk after capture
AICOM2|v1|WHY|east|67|act=DECAP_COMMIT|reason=DOMINANT_SUSTAINED|intel=myEff_1.7x_enEff|conf=0.8|detail=streak=3 inRange=2 sensed=1
AICOM2|v1|WHY|west|88|act=DECAP_ABORT|reason=EFF_COLLAPSE|intel=myEff_lt_enEff_0.9|conf=1.0|detail=myEff=12 enEff=18 minCommit elapsed
```

Reason codes (initial set — extend without schema breakage):
`FRONT_ADVANCE`, `CONTESTED_ENGAGE`, `EXPAND_FIRST`, `DOMINANT_SUSTAINED`, `EFF_COLLAPSE`,
`HQ_DEAD`, `PLAYER_POSTURE`, `FIELD_ORDER`, `HARASS_RETARGET`, `CONSOLIDATE_PAUSE`, `STALL_REPICK`

#### INTEL classification rows

Emitted once per strategy tick by Snapshot, summarising the classified picture. One row per side.
Format:

```
AICOM2|v1|INTEL|<SIDE>|<tick>|class=<THREAT_CLASS>|enTowns=<n>|enHQ=<alive|dead>|myEff=<n>|enEff=<n>|ratio=<2dp>|posture=<ATTACK|DEFEND|STALL|UNKNOWN>|inRange=<n>
```

`class` values: `DOMINANT` (ratio >= 1.5), `PARITY` (0.8..1.5), `DEFICIT` (< 0.8),
`WIN_IMMINENT` (enHQ=alive and enTowns <= 1 and dominant),
`STALEMATE` (both sides stalled > N ticks).

Example:
```
AICOM2|v1|INTEL|east|42|class=DOMINANT|enTowns=3|enHQ=alive|myEff=28|enEff=14|ratio=2.00|posture=ATTACK|inRange=2
```

#### PLAN / DECISION rows

Emitted by Allocator after fist selection is resolved. One PLAN row per strategy tick per side.
The existing `AICOM2|v1|ALLOC` line stays for backward compat; the PLAN row adds explicit decision
rationale that WHY rows cross-reference.

```
AICOM2|v1|PLAN|<SIDE>|<tick>|decision=<DECISION_CODE>|primary=<town>|secondary=<town|none>|harass=<town|none>|teamsAssigned=<n>|src=<AUTO|FOCUS|SUPPORT>|override=<FIELD_ORDER|POSTURE|none>
```

`decision` values: `FIST_STEADY`, `FIST_ADVANCE`, `FIST_RETREAT`, `FIST_NEUTRAL`
(expansion-first in effect), `DECAP_OVERRIDE` (Decapitate committed), `IDLE`.

Example:
```
AICOM2|v1|PLAN|west|42|decision=FIST_ADVANCE|primary=Chernogorsk|secondary=Elektro|harass=Berezino|teamsAssigned=5|src=AUTO|override=none
```

### Parser registration requirements

Before parity soak (step 3) these three families must be registered in:
- `Tools/Soak/analyze_soak.py` — add regex patterns in the AICOM2 section (lines 276-296)
  mirroring the existing SNAP/ALLOC/DECAP patterns; add dual-match for ported AICOMSTAT lines (Gap G8)
- `Tools/PrTestHarness/Aicom/Score-AicomRounds.ps1` — add WHY/INTEL/PLAN to the family filter
  and scorecard output
- `Tools/PrTestHarness/Ops/aicom-watch.ps1` — add colour-coding for WHY/INTEL rows

---

## Part 3 — 168 AICOMSTAT Emitter Disposition Table

Source: `TELEMETRY-AND-STATS-V2-PLAN.md` census (`origin/claude/fable-completion-push`). Total
confirmed: **168 `AICOMSTAT` emitters across 35 source files**. Per-file counts verified by grep on
`origin/claude/build84-cmdcon36`.

Disposition codes:
- **PORT** — content must be re-emitted under unified `AICOM2|v1|` grammar before step 4
- **DROP** — content not meaningful in V2; remove at step 4 without a replacement
- **KEEP-AS-IS** — emitter stays verbatim (not commander-owned or consumed by non-V2 tools)
- **RELOCATE** — byte-identical format survives but hosting file is being shelved; move emission
- **ALREADY-V2** — already emits `AICOMSTAT|v2|` sub-grammar; prefix-swap to `AICOM2|v2|` at step 4

### AI_Commander.sqf (35 emitters; ~20 AICOMSTAT + ~15 other families)

| Line | Event Tag | Current Format | Disposition | Notes |
|---|---|---|---|---|
| ~51 | `SUPERVISOR_JITTER` | `AICOMSTAT|v1|EVENT` | DROP | Phase-jitter V1 startup artefact; V2 de-correlates differently |
| ~108 | `RESEARCH_AIR` | `AICOMSTAT|v2|EVENT` | ALREADY-V2 | Port prefix to `AICOM2|v2|EVENT` at step 4 |
| ~123 | `SCAFFOLD_RESEARCH` | `AICOMSTAT|v1|EVENT` | DROP | V1 scaffold path; PATROLS-4 research now covered by V2 doctrine program |
| ~399 | `BOOTSTRAP_STIPEND|start` | `AICOMSTAT|v1|EVENT` | PORT | → `AICOM2|v1|STIPEND|<side>|<tick>|event=start` + WHY reason=BOOTSTRAP |
| ~404 | `BOOTSTRAP_STIPEND|end-first-town` | `AICOMSTAT|v1|EVENT` | PORT | → `AICOM2|v1|STIPEND|<side>|<tick>|event=end|reason=first-town` |
| ~407 | `BOOTSTRAP_STIPEND|end-timeout` | `AICOMSTAT|v1|EVENT` | PORT | → `AICOM2|v1|STIPEND|<side>|<tick>|event=end|reason=timeout` |
| ~428 | `BOOTSTRAP_STIPEND_WINDFALL` | `AICOMSTAT|v2|EVENT` | ALREADY-V2 | Port prefix; keep all k=v fields |
| ~576 | `WEALTH_CONVERSION` | `AICOMSTAT|v1|EVENT` | PORT | → `AICOM2|v1|WEALTH|<side>|<tick>|event=conversion|funds=…` |
| ~610 | `ECON_SINK_SURGE|off|human_commander` | `AICOMSTAT|v2|EVENT` | ALREADY-V2 | Port prefix |
| ~625 | `ECON_SINK_SURGE|on` | `AICOMSTAT|v2|EVENT` | ALREADY-V2 | Port prefix |
| ~630 | `ECON_SINK_SURGE|off` | `AICOMSTAT|v2|EVENT` | ALREADY-V2 | Port prefix |
| ~709 | `ECON_SINK_RESEARCH` | `AICOMSTAT|v2|EVENT` | ALREADY-V2 | Port prefix |
| ~724 | `SCAFFOLD_RESEARCH_REACTIVE` | `AICOMSTAT|v1|EVENT` | DROP | V1-only CBRadar reactive append; V2 doctrine program covers |
| ~771 | `TICK` (300s heartbeat) | `AICOMSTAT|v1|TICK` | PORT | **Critical soak KPI.** → `AICOM2|v1|TICK|<side>|<tick>|towns=…|supply=…|funds=…|fTeams=…|eTeams=…|upgCsv=…|units=…` same fields, new prefix. Consumer: `analyze_soak.py` section 5. |
| ~787 | `ECONOMY` | `AICOMSTAT|v2|EVENT` | ALREADY-V2 | Port prefix |
| ~809 | `ECONFLOW` | `AICOMSTAT|v2|EVENT` | ALREADY-V2 | Port prefix |
| ~869 | `CMDRSTAT` | `CMDRSTAT|v1|` | KEEP-AS-IS | Not commander-owned; hosted in AI_Commander.sqf which is not shelved at cutover. Consumed by `analyze_soak.py` section 8. No action at cutover. |
| ~901 | `SRVPERF` | `SRVPERF|v1|` | KEEP-AS-IS | Same — stays in AI_Commander.sqf. No action at cutover. |
| ~998 | `WASPSCALE` | `WASPSCALE|v2|` | KEEP-AS-IS | Wire-stable soak KPI backbone; do not touch. Consumed by analyze_soak.py + box dashboard. |
| ~1010,~1015,~1020 | `GRPBUDGET` (3 lines) | `GRPBUDGET|v1|` | KEEP-AS-IS | Cutover brief §NOTinscope exempts GRPBUDGET. If AI_Commander.sqf is eventually shelved at a later step, relocate emission to `server_groupsGC.sqf` byte-identical. No action at cutover steps 2-3. |
| ~1049 | `HCDELEG` | `HCDELEG|v1|` | KEEP-AS-IS | HC delegation diagnostics; not commander-owned; survives |
| ~1071 | `SUPERVISOR_SUPERSEDED` | `AICOMSTAT|v1|EVENT` | PORT | → `AICOM2|v1|SUPERVISOR|<side>|<tick>|event=superseded|old=…|new=…` |
| ~1082 | `END` | `AICOMSTAT|v1|END` | PORT | **Critical round-end line.** → `AICOM2|v1|END|<side>|<tick>|winner=…|doctrine=…|towns=…|funds=…` Consumer: analyze_soak.py END-event detection. |
| ~1094 | `ROUNDSTAT` | `ROUNDSTAT|v1|` | KEEP-AS-IS | Not commander-owned; stays in AI_Commander.sqf. Consumed by analyze_soak.py. |

### AI_Commander_Strategy.sqf (18 AICOMSTAT emitters)

| Line | Event Tag | Current Format | Disposition | Notes |
|---|---|---|---|---|
| ~371 | `SPEARHEAD_REPICK` | `AICOMSTAT|v1|SPEARHEAD_REPICK` | PORT | → `AICOM2|v1|STRATEGY|<side>|<tick>|event=spearhead_repick|stalled=…|approach=…|evals=…|newPrimary=…|cooldown=…` + WHY reason=STALL_REPICK. analyze_soak.py regex at line 247 must update prefix. |
| ~402 | `FRONT_DWELL_HOLD` | `AICOMSTAT|v2|EVENT` | ALREADY-V2 | Port prefix |
| ~455 | `RELIEF_TOWN_LOST` | `AICOMSTAT|v2|EVENT` | ALREADY-V2 | Port prefix |
| ~556 | `RELIEF` | `AICOMSTAT|v1|EVENT` | PORT | → `AICOM2|v1|STRATEGY|<side>|<tick>|event=relief|town=…` |
| ~562 | `RELIEF_CAP_SKIP` | `AICOMSTAT|v2|EVENT` | ALREADY-V2 | Port prefix |
| ~610 | `WEDGE_RELEASE` | `AICOMSTAT|v2|EVENT` | ALREADY-V2 | Port prefix |
| ~689 | `RALLY_ORDER` | `AICOMSTAT|v2|EVENT` | ALREADY-V2 | Port prefix |
| ~735 | `HQ_STRIKE_STALL_OVERRIDE` | `AICOMSTAT|v1|EVENT` | DROP | V1 HQ-strike path; superseded by Decapitate closer |
| ~757 | `HQ_STRIKE` | `AICOMSTAT|v1|EVENT` | DROP | V1 HQ-strike path; superseded by Decapitate closer |
| ~813 | `STRIKE_STAGE_RELEASE` | `AICOMSTAT|v2|EVENT` | DROP | V1 strike stage; superseded by Decapitate COMMIT/ABORT |
| ~975 | `BASE_OVERRUN` (script-raze) | `AICOMSTAT|v1|EVENT` | PORT | → `AICOM2|v1|STRATEGY|<side>|<tick>|event=overrun|via=script-raze|strikers=…|enemies=…|siege=…` |
| ~978 | `BASE_OVERRUN` (assault-progress) | `AICOMSTAT|v1|EVENT` | PORT | → same, `via=assault-progress` |
| ~1018 | `LOSING_PRESS_FLOOR` | `AICOMSTAT|v1|EVENT` | PORT | → `AICOM2|v1|STRATEGY|<side>|<tick>|event=losing_press_floor|myTowns=…|enTowns=…|myEff=…|enEff=…` |
| ~1034 | `POSTURE` | `AICOMSTAT|v1|POSTURE` | PORT | **Critical soak line. New format:** `AICOM2|v1|POSTURE|<side>|<tick>|<STANCE>|myTowns=…|enTowns=…|myStr=…|enStr=…|myEff=…|enEff=…|townStr=…|garBodies=…|strikeOn=…` analyze_soak.py regex at line 241 must update to `AICOM2\|v1\|POSTURE`. Score-AicomRounds must track POSTURE distribution. |
| ~1036 | `FRONT` | `AICOMSTAT|v1|FRONT` | PORT | → `AICOM2|v1|FRONT|<side>|<tick>|held=…|enemyHeld=…|contested=…|primary=…|onFront=…` analyze_soak.py regex at line 244 must update prefix. |
| ~1056 | `STALL` | `AICOMSTAT|v1|STALL` | PORT | → `AICOM2|v1|STALL|<side>|<tick>|posture=…|myTowns=…|enTowns=…|myStr=…|enStr=…|myEff=…|enEff=…|streak=…` |
| ~1114 | `FIRE_MISSION` | `AICOMSTAT|v1|EVENT` | PORT | → `AICOM2|v1|STRATEGY|<side>|<tick>|event=fire_mission|type=…` |
| (Strategy debug lines) | `AICOMDBG` / misc | TBD | TBD | Strategy may have additional debug lines not caught by primary grep; audit required before step 4 (Gap G9) |

### AI_Commander_AssignTowns.sqf (18 AICOMSTAT emitters, all ALREADY-V2)

All 18 emitters are `AICOMSTAT|v2|EVENT`. Disposition for all: **ALREADY-V2 → prefix-swap to
`AICOM2|v2|EVENT` at step 4**. Events: `ASSAULT_ARRIVED`, `ORBITER_STUCK`, `ASSAULT_STRANDED`,
`RECYCLE_FLAG` (×3), `GARRISON_REASSIGN`, `TARGET_ABANDON` (×3), `SIDE_BLACKLIST` (×2),
`JOURNEY_COMMIT`, `CAPTURE_LOCK_SUPPRESS`, `UNSTUCK_STRIKE`, `CAPTURE_TRACE|ORDER_PUBLISHED`,
`ASSAULT_DISPATCH`. No logic changes.

### AI_Commander_Teams.sqf (8 AICOMSTAT emitters, all ALREADY-V2)

All 8 emitters are `AICOMSTAT|v2|EVENT`. Disposition for all: **ALREADY-V2 → prefix-swap at step 4**.
Events: `TEAMS_TARGET`, `HCDISPATCH`, `HCDISPATCH_REAP`, `TEAM_RETIRED`, `FOUND_GATE_SKIP`,
`TEAM_FOUNDED` (×2). One emitter unconfirmed by grep — audit before step 4 (Gap G6).

### AI_Commander_Allocate.sqf (3 AICOMSTAT emitters)

| Line | Event Tag | Disposition | Notes |
|---|---|---|---|
| ~183 | `CAPDBG|SC` (residual) | DROP | Debug residual in scout path; no soak consumer |
| ~233 | `ENEMY_TOWN_TARGET` | PORT | Can fold into the ALLOC line as extra fields or keep as `AICOM2|v1|ALLOC|…|event=ENEMY_TOWN_TARGET` |
| ~334 | `HARASS_SKIP` | PORT | → `AICOM2|v1|ALLOC|…|event=HARASS_SKIP|skipped=…|picked=…` |

### Common_RunCommanderTeam.sqf (23 AICOMSTAT emitters)

| Line | Key Event | Disposition | Notes |
|---|---|---|---|
| ~1034 | `UNSTUCK_FIRED` | ALREADY-V2 | `AICOMSTAT|v2|EVENT`; port prefix at step 4. Consumed by analyze_soak.py recov counter. |
| (remaining ~22) | Capture-trace, garrison, stuck events | ALREADY-V2 or PORT | Most are `AICOMSTAT|v2|EVENT`; remaining V1 lines port to `AICOM2|v1|EXEC|…`. Full audit before step 4. |

### AI_Commander_MHQReloc.sqf (21 AICOMSTAT emitters, all PORT)

All 21 emitters are `AICOMSTAT|v1|MHQRELOC|…`. Disposition for all: **PORT → `AICOM2|v1|MHQRELOC|<side>|<tick>|event=<TAG>|…`** preserving existing k=v fields. Events:
`RELAXED`, `ABORT` (×3), `DEFER`, `TRIGGER`, `MOBILIZED`, `AUTOFUEL`, `ROUTE_CONTACT`,
`ROUTE_CLEAR`, `NUDGE`, `STUCK_TELEPORT`, `TELEPORT_STEP`, `TELEPORT_BLOCKED`, `RELEASE` (×2),
`FINAL_REVALIDATE` (×3), `DEPLOYED`. analyze_soak.py `AICOMSTAT|v1|MHQRELOC` regex at line 250
must update prefix.

### Remaining Workers (1-2 emitters each)

| Worker | Count | Current Format | Disposition | Target format |
|---|---|---|---|---|
| `AI_Commander_Base.sqf` | 7 | Mix of v1/v2 EVENT | TBD — full audit required | `AICOM2|v1|BASE|…` for v1 lines; prefix-swap for v2 lines (Gap G5) |
| `AI_Commander_Produce.sqf` | 1 | `AICOMSTAT|v2|EVENT|…|UNIT_PRODUCED` | ALREADY-V2 | Prefix-swap |
| `AI_Commander_BaseSell.sqf` | 1 | `AICOMSTAT|v2|EVENT` | ALREADY-V2 | Prefix-swap |
| `AI_Commander_DisbandLowTier.sqf` | 1 | `AICOMSTAT|v2|EVENT` | ALREADY-V2 | Prefix-swap |
| `AI_Commander_FundsSink.sqf` | 1 | `AICOMSTAT|v2|EVENT` | ALREADY-V2 | Prefix-swap |
| `AI_Commander_Beacon.sqf` | 2 | `AICOMSTAT|v1|EVENT` | PORT | → `AICOM2|v1|BEACON|<side>|<tick>|event=…` |
| `AI_Commander_Paratroops.sqf` | 1 | `AICOMSTAT|v1|EVENT` | PORT | → `AICOM2|v1|PARATROOPS|<side>|<tick>|event=…` |
| `AI_Commander_PlayerArty.sqf` | 1 | `AICOMSTAT|v1|EVENT` | PORT | → `AICOM2|v1|PLAYERARTY|<side>|<tick>|event=…` |
| `AI_Commander_AssignTypes.sqf` | 1 | `AICOMSTAT|v1|EVENT` | PORT | → `AICOM2|v1|TEAMS|<side>|<tick>|event=assigntype|…` |

### Disposition Summary (168 total)

| Disposition | Approx count | Notes |
|---|---|---|
| ALREADY-V2 (prefix swap only) | ~85 | `AICOMSTAT|v2|EVENT` lines; trivial swap at step 4 |
| PORT (grammar remap) | ~55 | V1 lines with soak value; new `AICOM2|v1|*` lines required |
| DROP | ~8 | V1 HQ-strike path (×3), scaffold-research (×2), phase-jitter (×1), CAPDBG residual (×1), Strategy debug TBD (×1) |
| KEEP-AS-IS / RELOCATE | ~20 | CMDRSTAT, SRVPERF, GRPBUDGET, HCDELEG, ROUNDSTAT, WASPSCALE — not commander-owned or wire-stable |
| TBD (audit required) | 0 at category level | Base.sqf and Teams.sqf 8th emitter need line-level confirmation before step 4 |

---

## Part 4 — Consumer Port Plan and Gating Order

Consumers must be ported to the unified grammar **before removal (step 4)**. The parity-soak scorer
ports first because it gates step 3.

### Consumer inventory

| Consumer | Location | Parses | Port status | Action required |
|---|---|---|---|---|
| `Score-AicomRounds.ps1` | `Tools/PrTestHarness/Aicom/Score-AicomRounds.ps1` | `AICOM2|v1|SNAP/DECAP/ALLOC`, `WASPSCALE|v2|`, error families | EXISTS on `fable/soak-gate-tooling` — parses AICOM2 natively. **Merge to base.** | Merge `fable/soak-gate-tooling`; add WHY/INTEL/PLAN family patterns. |
| `aicom-watch.ps1` | `Tools/PrTestHarness/Ops/aicom-watch.ps1` | `AICOM2|v1|*`, `AICOMSTAT|*`, `WASPSTAT|*` | EXISTS on `fable/soak-gate-tooling` — tails and colour-codes AICOM2 lines. | Merge with Score-AicomRounds; add WHY/INTEL colour rules. |
| `analyze_soak.py` | `Tools/Soak/analyze_soak.py` | `AICOMSTAT|v1|TICK/POSTURE/MHQRELOC/FRONT/SPEARHEAD_REPICK`, `AICOMSTAT|v2|EVENT`, `AICOM2|v1|SNAP/ALLOC/DECAP/FISTPOOL` | AICOM2 section EXISTS on `fable/soak-gate-tooling` (lines 276-296). V1 AICOMSTAT patterns (lines 238-253) must **dual-match** old+new prefixes during transition window, then drop old at step 4. | Add `AICOM2\|v1\|POSTURE\|` as alternative in regex at line 241 etc.; add WHY/INTEL/PLAN patterns. |
| `Get-WaspRptMarkerSweep.ps1` | `Tools/Monitor/` | `AICOMSTAT|`, `WASPSTAT|`, `WASPSCALE|` | Not yet updated | Add `AICOM2|` to catch-patterns. Low priority — not a soak gate. |
| Box `update-PublicStats.ps1` | Livehost `C:\WASP\` | `EMPTYGRP|v1|` (known prefix mismatch — emits `EMPTYGRP|`, box parses `GRPEMPTY|`; dashboard gauge silently dead), AICOMSTAT families for :8080 dashboard | Not ported | **Known defect: fix `GRPEMPTY` consumer on box (Gap G2).** Add `AICOM2|` parse pass for :8080 dashboard. TBD — box-side script access required. |
| Box RPT ingest worker | Livehost (path TBD) | Tails RPT → POST `/api/aicom-stats` | Not confirmed | Extend to parse `AICOM2|` prefix alongside `AICOMSTAT|`. Priority: before step 3. (Gap G3) |
| Wiki pages | GitHub wiki | Narrative descriptions of V1 behaviour | Historical at step 5 | Target: `AI-Commander-Logging-And-AICOMSTAT-Telemetry`, `AICOMSTAT-V2-Event-Vocabulary-Census`, `WASPSCALE-V2-Telemetry-Reference`. Do not mark historical before step 5. |

### Gating order

1. **Before cutover build (step 2):** This migration map finalised and owner-approved. Strategy
   HQ-strike guard coded; telemetry PORT implementations drafted.
2. **Before parity soak (step 3):** `fable/soak-gate-tooling` merged; `Score-AicomRounds.ps1` and
   `aicom-watch.ps1` operational with AICOM2 grammar; `analyze_soak.py` dual-matching old+new
   prefixes; box-side ingest extended; box EMPTYGRP defect fixed.
3. **Before shelve (step 4):** All PORT emitters re-emitted under `AICOM2|v1|`; all consumers
   updated to new prefix only; V1-only emitters (DROP category) confirmed removed.
4. **At shelve (step 4):** DROP-category emitters deleted from source; fully-superseded V1 files
   (none yet identified) moved to tagged branch with `Shelved-AICOM-V1` wiki record; GRPBUDGET/
   SRVPERF emission relocated if their host file enters the shelve set.
5. **At flag retirement (step 5):** `WFBE_C_AICOM_V2_ENABLE` flag retired; wiki pages marked
   historical; docs re-anchored to V2-only.

---

## Part 5 — V1 Commander Workers → V2 Home or Fold Work Order

18 worker files on `origin/claude/build84-cmdcon36` under
`Server/AI/Commander/`. Each entry gives the V2 disposition, telemetry fold work order, and
spec-pack / N3-lane cross-reference.

### Supervisor: `AI_Commander.sqf`

**V2 home:** Stays as the supervisor. Already calls `WFBE_SE_FNC_AICOM2_Snapshot`,
`WFBE_SE_FNC_AICOM2_Allocate`, `WFBE_SE_FNC_AICOM2_Decapitate` per strategy tick on
`fable/aicom-v2-l1-press-fix`. No standalone V2 replacement.

**Fold work order:** Port AICOMSTAT emitters per Part 3. No structural logic changes.

**8 IMPLEMENT-IN-ONE-SHOT PRs connection:** None of the N3 spec lanes replace the supervisor;
they add behaviour in callee workers.

### `AI_Commander_Snapshot.sqf` (M0)

**V2 home:** This file IS the V2 M0 implementation. Function name `WFBE_SE_FNC_AICOM2_Snapshot`.

**Fold work order:** Add INTEL row emission (Part 2) after the existing `AICOM2|v1|SNAP` line.
No other changes.

**Spec cross-ref:** Lane 408 (`AICOM-V2-LAYER-ARCH.md`, MISSING at hub) — the layer architecture
spec described here. `WFBE_SNAP_*` constants are the canonical world-model interface.

### `AI_Commander_Allocate.sqf` (M1/M2/M4/M5)

**V2 home:** This file IS the V2 offensive authority. Function `WFBE_SE_FNC_AICOM2_Allocate`.

**Fold work order:** Add PLAN row + WHY rows (Part 2). Port 3 AICOMSTAT emitters (Part 3).

**Spec cross-ref:** Lane 415 (route-graph doctrine) → `_frontDist` helper and expansion-first
logic already present. Lane 416 (fluidity/retasking latency) → `WFBE_C_AICOM2_CONSOLIDATE_SECS`
already present. Lane 424 (GUER endgame) → `_guerID`-aware neutral-pool already present. Full
spec-harness acceptance pending lane 414 (`AICOM-V2-ACCEPTANCE-HARNESS.md`, MISSING at hub).

### `AI_Commander_Decapitate.sqf` (M5)

**V2 home:** This file IS the V2 HQ closer. Function `WFBE_SE_FNC_AICOM2_Decapitate`.

**Fold work order:** Add WHY rows on state transitions (COMMIT, ABORT, WON-HQDEAD) (Part 2).
No other changes.

### `AI_Commander_Strategy.sqf`

**V2 home:** Stays. Two modifications required at cutover build:

1. **Gate the HQ-strike launch block** (lines ~730-760) on
   `(missionNamespace getVariable ["WFBE_C_AICOM2_DECAP_ENABLE", 0]) <= 0` so V1 strike is
   suppressed when V2 Decapitate is armed. Flag-off → byte-identical to HEAD (no gate fires).
2. **Port POSTURE/FRONT/STALL/SPEARHEAD_REPICK emitters** to `AICOM2|v1|` prefix (see Part 3).

**Fold work order:** One-line flag gate; port 18 telemetry emitters.

**Spec cross-ref:** Lane 422 (defense/counterattack) maps to existing RELIEF block
(lines ~440-565). Lane 423 (intel/perception) maps to `_attacked` scan and POSTURE computation.

### `AI_Commander_Execute.sqf`

**V2 home:** Stays unchanged. No emitters; no logic changes.

### `AI_Commander_AssignTowns.sqf`

**V2 home:** Stays. Allocate writes `wfbe_aicom_alloc_target` per team; AssignTowns reads it
at the `_allocTgt` path and routes the team. This is the execution bridge between Allocate and movement.

**Fold work order:** Port 18 emitters (all ALREADY-V2 → prefix swap). No logic changes.

### `AI_Commander_AssignTypes.sqf`

**V2 home:** Stays. Template assignment independent of planning layer.

**Fold work order:** 1 emitter; PORT. No logic changes.

**Spec cross-ref:** Lane 425 (difficulty profiles) may inject template weightings here — TBD at
lane 425 build time.

### `AI_Commander_Teams.sqf`

**V2 home:** Stays. Team founding unchanged.

**Fold work order:** Port 8 emitters (all ALREADY-V2 → prefix swap). Confirm 8th emitter before step 4.

### `AI_Commander_Produce.sqf`

**V2 home:** Stays. Per-unit reinforcement unchanged.

**Fold work order:** 1 emitter; ALREADY-V2 → prefix swap.

### `AI_Commander_Base.sqf`

**V2 home:** Stays. HQ deploy + base build unchanged.

**Fold work order:** 7 emitters; full audit required before step 4 (Gap G5). Expected: mix of
`AICOM2|v1|BASE|…` PORT and ALREADY-V2 prefix-swap.

### `AI_Commander_BaseSell.sqf`

**V2 home:** Stays. Structure recycle unchanged.

**Fold work order:** 1 emitter; ALREADY-V2 → prefix swap.

### `AI_Commander_FundsSink.sqf`

**V2 home:** Stays. Wealth-conversion unchanged.

**Fold work order:** 1 emitter; ALREADY-V2 → prefix swap.

### `AI_Commander_MHQReloc.sqf`

**V2 home:** Stays. MHQ relocation unchanged. `_mhqrel` counter already consumed by WASPSCALE.

**Fold work order:** 21 emitters; all PORT to `AICOM2|v1|MHQRELOC|…` (see Part 3).

### `AI_Commander_DisbandLowTier.sqf`

**V2 home:** Stays. Disband selector unchanged.

**Fold work order:** 1 emitter; ALREADY-V2 → prefix swap.

### `AI_Commander_Beacon.sqf`

**V2 home:** Stays. Forward spawn beacon unchanged.

**Fold work order:** 2 emitters; PORT to `AICOM2|v1|BEACON|…`.

### `AI_Commander_Paratroops.sqf`

**V2 home:** Stays. Paratroop drop unchanged.

**Fold work order:** 1 emitter; PORT to `AICOM2|v1|PARATROOPS|…`.

### `AI_Commander_PlayerArty.sqf`

**V2 home:** Stays. Player arty resolver unchanged. Called every supervisor tick in assist-mode too.

**Fold work order:** 1 emitter; PORT to `AICOM2|v1|PLAYERARTY|…`.

### `AI_Commander_HCTopUp.DRAFT.sqf`

Not compiled by `Init_Server.sqf`. Not one of the 18 live workers. **Shelve at step 4 alongside
any fully-superseded V1 files; do not include in the cutover build.**

### The 8 IMPLEMENT-IN-ONE-SHOT PRs (spec lanes 415-426, N3 block)

These lanes add incremental V2 behaviours on top of the one-shot cutover. They are **not blocking
the one-shot** (per cutover brief). Each maps to an N3 lane in V2-PROGRAM-HUB.md:

| Lane | Spec doc | Target worker(s) | Cutover-block? |
|---|---|---|---|
| 415 | `AICOM-V2-MOVEMENT-ROUTE-GRAPH.md` | AssignTowns, Allocate | No |
| 416 | `AICOM-V2-FLUIDITY-LATENCY.md` | Allocate, AssignTowns | No |
| 417 | `AICOM-V2-BUILD-RESEARCH-PLANNER.md` | Base, Produce | No |
| 418 | `AICOM-V2-BASE-RELOCATION.md` | MHQReloc | No |
| 419 | `AICOM-V2-FIRE-SUPPORT.md` | Strategy (arty), PlayerArty | No |
| 420 | `AICOM-V2-ESCALATION-DIRECTOR.md` | Strategy, Teams | No |
| 421 | `AICOM-V2-LIFECYCLE-CLEANUP.md` | DisbandLowTier, Teams | No |
| 422 | `AICOM-V2-DEFENSE-COUNTERATTACK.md` | Strategy (RELIEF block) | No |
| 423 | `AICOM-V2-INTEL-PERCEPTION.md` | Snapshot, Allocate | No — INTEL row grammar spec'd in Part 2 |
| 424 | `AICOM-V2-GUER-ENDGAME.md` | Allocate (neutral pool) | No — neutral-pool already live |
| 425 | `AICOM-V2-DIFFICULTY-PROFILES.md` | AssignTypes, Teams | No |
| 426 | `AICOM-V2-EXPLAINABILITY-COMMS.md` | WHY rows (Part 2) | No — grammar spec'd in Part 2 |

The cutover build ships M0 + M1/M2/M4/M5 + M5-closer + press-hook. N3 lanes are post-cutover
increments on top of the unified `AICOM2|v1|` grammar.

### Micro-layer spec cross-reference

`docs/design/v2/MICRO-LAYER.md` defines the per-HC micro-layer contract. Its implementation lives
in `Common_RunCommanderTeam.sqf`. The press-hook (lines 928-996) is the first micro-layer behaviour
added under V2. Remaining micro-layer behaviours — stuck-recovery v2 reference (codex lane 165),
HC state upward report `WFBE_SNT_REPORT` (currently `[]` in all Snapshot team digests) — are TBD
incremental additions that do not block the one-shot cutover.

---

## Known Gaps / TBD Items

| # | Gap | Blocking step | Resolution path |
|---|---|---|---|
| G1 | `fable/soak-gate-tooling` not yet merged — `Score-AicomRounds.ps1` and `aicom-watch.ps1` not on base | Blocks step 3 gate | Merge before parity soak |
| G2 | Box-side `update-PublicStats.ps1` EMPTYGRP prefix mismatch (emits `EMPTYGRP|v1|`, box parses `GRPEMPTY|v1|`; :8080 gauge silently dead) | No (pre-dates V2) | Fix consumer on box at step 3 prep |
| G3 | Box-side RPT ingest worker path not confirmed; AICOM2 parsing not verified | Blocks step 3 consumer completeness | Confirm on livehost before soak |
| G4 | V2 standalone stance machine (`AICOMV2_StanceEval`) not built; Strategy POSTURE remains V1 logic ported to `AICOM2|v1|POSTURE` | No (behaviour adequate; clean SM is post-cutover N3) | Post-cutover lane 408 |
| G5 | `AI_Commander_Base.sqf` 7 emitters require full audit for PORT vs DROP vs ALREADY-V2 | No (base events are diagnostics, not soak KPIs) | Before step 4 |
| G6 | `AI_Commander_Teams.sqf` 8th emitter not resolved by primary grep | No | Full grep audit before step 4 |
| G7 | WHY/INTEL/PLAN grammar (Part 2) requires emitter implementation in Allocate, Decapitate, Snapshot | No (grammar spec ships here; emitter code is a post-cutover build task) | Post-cutover increment |
| G8 | `analyze_soak.py` AICOMSTAT legacy patterns (lines 238-253) need dual-match during transition window (steps 2-3) before old prefix is removed | Blocks step 3 analysis correctness | Add `AICOM2\|v1\|POSTURE` etc. as alternatives in the regexes |
| G9 | Strategy.sqf debug lines (`AICOMDBG` family) not fully counted in the 168 census | No (debug lines not soak KPIs) | Full grep audit before step 4 |

---

*Guide-Rev: GR-2026-07-03a. Do not advance to cutover step 2 without owner sign-off on this map.
Cite this document in any cutover-related build report.*
