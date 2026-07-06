# V2 Cutover T3 Parity Soak Program

Guide-Rev: GR-2026-07-03a — binding document; supersedes any earlier draft soak spec.
Owner: Ray (owner-authorised 2026-07-06).
Status: **STAGED — awaiting first empty server window to fire soak 1.**

---

## 1. What a T3 parity soak is

A **T3 parity soak** is a full AI-vs-AI overnight match run on the live box in a dedicated empty window (no players), using the V2 cutover build (`fable/v2-cutover` rebased onto current master), with the `WFBE_C_AICOM_V2_ENABLE` rollback flag set to `DECAP_ENABLE=0` for soak 1 and `DECAP_ENABLE=1` for soak 2+.

The purpose is to validate that the V2 commander matches or exceeds the V1 baseline on all KPIs measured by `Tools/Soak/analyze_soak.py` (section 10: AICOM2 telemetry) before the cutover is declared stable and V1 code is shelved (step 4 of the five-step sequence in AICOM-V2-CUTOVER-AND-RECONCILIATION.md).

**"T3"** = the mission runs with full AI delegation (HC present, delegation tier 3), which is the configuration used on the live server. Soaks at lower tiers do not gate the cutover.

**"Parity"** = the soak RPT must satisfy the PASS/WATCH thresholds in `analyze_soak.py` at the same level as or better than the archived V1 reference baseline (`wasp-westwin-20260701.rpt`, 583 dispatches / 40 arrivals / 13 zombie teams / 32 W<->E kills).

---

## 2. KPIs that decide PASS / WATCH / FAIL

Graded by `python -X utf8 Tools/Soak/analyze_soak.py <server.rpt> --hc <hc.rpt> --json` against the thresholds in the tool. The soak-gate verdict is the **OVERALL** field (worst-of).

| Section | Signal | PASS threshold | FAIL threshold |
|---------|--------|---------------|----------------|
| 1. ARRIVAL | Assault arrival % | > 20% (> 30% = great) | < 10% |
| 2. ZOMBIES | Teams with 0 arrivals (>=3 dispatches) | <= 2 | > 5 |
| 3. W<->E SHARE | Army-vs-army kill share of total kills | > 5% | < 2.5% |
| 4. CHURN | FRONT primary changes / hour (per side) | <= 50% of baseline | > 80% of baseline |
| 7. PERF | Server FPS median | >= 15 (no explicit gate; flag if < 12) | drop > 20% vs prior soak |
| 10. AICOM2-DECAP | DECAP lines present + roll cadence | PASS = present + cadence OK | FAIL = SNAP present, DECAP absent |

**Additional V2-specific gates (manual review, not scored by the tool):**

| Gate | What to check | PASS |
|------|--------------|------|
| DECAP shadow | `AICOM2|v1|DECAP` lines emitted for both WEST and EAST | Both sides emitting |
| War progress | `WASPSTAT|v1|CAPTURE` events accumulate over the run; at least one town changes hands per faction | Yes |
| Rollback flag | `WFBE_C_AICOM_V2_ENABLE` in RPT matches the intended flag value | Yes |
| Error budget | Script error / Undefined variable / No entry error lines < 20 per match-hour | Yes |

---

## 3. Exact execution procedure (per soak)

### Pre-conditions

- The live box (livehost = `78.46.107.142`) is **empty** (zero players, no active round, or a scheduled maintenance window).
- `cc48` is the currently deployed build (confirmed via `ssh gamingpc "ssh livehost powershell -NoProfile -Command \"(Get-Content 'C:\WASP\version.txt')\""` or RPT header).
- You have the `fable/v2-cutover` branch rebased onto the current master tip and the PBO built (see pre-flight checklist below).
- The `WFBE_C_AICOM_V2_ENABLE` lobby parameter default is set to the correct value for this soak number (see flag schedule below).

### Flag schedule

| Soak # | DECAP_ENABLE value | What it tests |
|--------|-------------------|--------------|
| 1 | 0 | V2 SNAP/ALLOC/FISTPOOL active, DECAP circuit **disabled** (shadow mode — validates commander core without the decapitate arm) |
| 2 | 1 | Full V2 including DECAP arm — organic sensing, driver-press hook, UNSTUCK guard all active |
| 3 | 1 | Repeat with different terrain (Takistan) or same Chernarus if soak 2 had anomalies; confirm parity is stable |

### Step-by-step

```
STEP 1 — Build the soak PBO (on Main PC, development machine)
  a. Fetch and rebase fable/v2-cutover onto master:
       git -C C:\Users\Steff\a2waspwarfare fetch origin
       git -C C:\Users\Steff\a2waspwarfare checkout fable/v2-cutover
       git -C C:\Users\Steff\a2waspwarfare rebase origin/master
     [If conflicts: resolve the 5 CH files listed in section 6, then mirror and verify]
  b. Set DECAP_ENABLE in Common/Init/Init_CommonConstants.sqf:
       soak 1:  WFBE_C_AICOM_V2_ENABLE default = 0
       soak 2+: WFBE_C_AICOM_V2_ENABLE default = 1
     (The lobby param in Rsc/Parameters.hpp overrides this; ensure Parameters.hpp
      default= matches the intended value.)
  c. Build the PBO:
       cd C:\Users\Steff\a2waspwarfare\Tools\LoadoutManager
       dotnet run -c RELEASE
  d. Note the build label (version.sqf WF_VERSION string).

STEP 2 — Stage on the box (during the empty window)
  a. Confirm box is empty:
       ssh gamingpc "ssh livehost powershell -NoProfile -Command \"Get-Content C:\WASP\players.txt\""
     (or check BattleMetrics / Discord)
  b. SCP the soak PBO to the box:
       scp "C:\Users\Steff\a2waspwarfare\_MISSIONS\[55-2hc]warfarev2_073v48co.chernarus.pbo" \
           "Administrator@78.46.107.142:C:/WASP/MPMissions/"
  c. Deploy (using deploy-v2.ps1):
       ssh gamingpc "ssh livehost powershell -NoProfile -File C:\WASP\deploy-v2.ps1 -Mission [55-2hc]warfarev2_073v48co.chernarus"
  d. Verify MISSINIT fires in RPT:
       ssh gamingpc "ssh livehost powershell -NoProfile -Command \"Select-String 'MISSINIT' C:\WASP\arma2oaserver.RPT | Select-Object -Last 3\""

STEP 3 — Run the soak (2 hours minimum, 4+ preferred)
  a. Let the mission run AI-vs-AI. Do NOT join as a player during the soak window.
  b. Optionally watch AICOM2 lines live:
       ssh gamingpc "ssh livehost powershell -NoProfile -File C:\WASP\Tools\PrTestHarness\Ops\aicom-watch.ps1"
  c. Minimum duration: 120 minutes of AICOM tick (tick 120+ in the last WASPSCALE line).

STEP 4 — Restore cc48
  a. SCP cc48 PBO back:
       scp "C:\Users\Steff\a2waspwarfare\_MISSIONS\cc48_backup\[55-2hc]warfarev2_073v48co.chernarus.pbo" \
           "Administrator@78.46.107.142:C:/WASP/MPMissions/"
  b. Redeploy cc48:
       ssh gamingpc "ssh livehost powershell -NoProfile -File C:\WASP\deploy-v2.ps1 -Mission [55-2hc]warfarev2_073v48co.chernarus"
  c. Confirm MISSINIT in RPT shows cc48 build label.
  d. Open server for players.

STEP 5 — Pull RPTs and grade
  Server RPT:
    scp "Administrator@78.46.107.142:C:/Users/Administrator/Documents/Arma 2 Other Profiles/*/arma2oaserver.RPT" \
        .\soak$(N)_server.rpt
  HC RPT:
    scp "Administrator@78.46.107.142:C:/Users/Administrator/AppData/Local/ArmA 2 OA/ArmA2OA.RPT" \
        .\soak$(N)_hc.rpt

  Grade:
    python -X utf8 Tools\Soak\analyze_soak.py .\soak$(N)_server.rpt --hc .\soak$(N)_hc.rpt --json > soak$(N)_grade.json
    python -X utf8 Tools\Soak\analyze_soak.py .\soak$(N)_server.rpt --hc .\soak$(N)_hc.rpt --no-color

  Also run Score-AicomRounds.ps1 for the per-round scorecard:
    .\Tools\PrTestHarness\Aicom\Score-AicomRounds.ps1 -RptPath .\soak$(N)_server.rpt -RequireDecap -MaxErrors 20

STEP 6 — Record result
  Update the soak log table in this file (section 5) with: soak#, date, DECAP_ENABLE value,
  overall verdict, arrival%, zombie count, DECAP verdict, notes.
  Save the grade JSON as docs/testing/soak-grades/soak$(N).json.
```

---

## 4. Rollback semantics

The rollback flag `WFBE_C_AICOM_V2_ENABLE` (integer, default 0 during the transition window) is the sole cutover knob. When it is 0, the V1 commander paths run and the mission is byte-identical to cc48 from the perspective of AI behaviour.

To rollback DURING a soak:
1. Restore cc48 (step 4 above).
2. No flag changes needed — cc48 does not carry the V2 branch.

To rollback AFTER cutover is declared (V1 shelved):
- Revert to the tagged `shelved/aicom-v1-<date>` branch using `git revert` or by cherry-picking cc48's mission tree onto a new branch.
- This is a deliberate, coordinated operation; it is not a flag flip once step 4 (shelve) is complete.

---

## 5. How many clean soaks gate the cutover — N = 3

The cutover brief (GR-2026-07-03a step 3) defers N to the owner. This program proposes **N = 3** for the following reasons:

1. **One soak is insufficient** to rule out lucky timing (e.g., both factions happened to start with good town positions). A2 AI is stochastic and match outcomes vary significantly run to run.
2. **Two soaks** catches regressions that emerge only after the full DECAP arm is enabled (soak 1 with DECAP_ENABLE=0 does not stress the decapitate circuit). Soak 2 adds the DECAP arm; soak 3 is the confirmatory run.
3. **Three soaks** (1 × shadow-mode + 2 × full-V2) is the minimum to establish that the DECAP arm is both functional (DECAP verdict = PASS in soak 2) and stable (DECAP verdict = PASS in soak 3 as well). This matches the empirical cadence used for the cmdcon41 fix-package validation.
4. **Any FAIL verdict resets the counter** to 0 on that gate. A WATCH verdict does not reset; it is carried as a finding and addressed before the next soak if actionable.

Gate: **3 consecutive soaks** where every graded KPI is PASS or WATCH (no FAIL), and the AICOM2-DECAP verdict is PASS in soaks 2 and 3 (where DECAP_ENABLE=1).

---

## 6. Rebase check — fable/v2-cutover onto master

**Checked: 2026-07-06 against master tip `169eb16fa`.**

Trial merge (`git merge-tree b8f8b8e72 master fable/v2-cutover`) reports **5 conflicting file groups** (CH + TK + ZG mirrors = 15 git objects total, but only 5 unique logical files):

| File (CH path) | Why it conflicts |
|---------------|-----------------|
| `Common/Functions/Common_RunCommanderTeam.sqf` | master: SML-3/4/5 hooks (#774) + teleport guard (#780) + stuck-repair reset. v2-cutover: DECAP driver-press hook + UNSTUCK press-guard. Both sides edited this file. |
| `Common/Init/Init_CommonConstants.sqf` | master: SML-3/4/5 flag registrations + deploy-v2 flags. v2-cutover: WFBE_C_AICOM_V2_ENABLE registration. |
| `Server/AI/Commander/AI_Commander_Allocate.sqf` | master: ROAD-CLEAR gate (#779). v2-cutover: V2 ALLOC telemetry emitter. |
| `Server/AI/Commander/AI_Commander_Strategy.sqf` | master: Base paren hotfix (#777). v2-cutover: DECAP_ENABLE gate (V1 HQ-strike suppressed when V2 is armed). |
| `Server/Init/Init_Server.sqf` | master: Deploy-v2 readiness gate (#770). v2-cutover: V2 init sequence. |

**Conclusion: fable/v2-cutover does NOT merge cleanly onto master `169eb16fa`.** A manual rebase with conflict resolution is required before the soak PBO can be built.

### Rebase resolution guide

For each conflict file, the intent is:

- `Common_RunCommanderTeam.sqf`: Keep BOTH the SML-3/4/5 hooks and the DECAP driver-press hook. The SML hooks are independent; they run in a different code path (SML overwatch/retreat/unstuck) from the DECAP press-hook (which triggers on HC AICOM loop). Merge by accepting both edits. Verify the stuck-repair tier reset (#780) is preserved.
- `Init_CommonConstants.sqf`: Append V2 flag `WFBE_C_AICOM_V2_ENABLE` after the SML/deploy flags from master. No ordering dependency.
- `AI_Commander_Allocate.sqf`: Accept master's ROAD-CLEAR gate and V2-cutover's ALLOC telemetry emitter. Both are additive.
- `AI_Commander_Strategy.sqf`: Accept master's Base paren hotfix AND the DECAP_ENABLE gate. Apply paren fix first, then ensure the DECAP_ENABLE guard wraps the V1 HQ-strike block.
- `Init_Server.sqf`: Accept master's deploy-v2 readiness gate and V2-cutover's init sequence. Ensure V2 init runs AFTER the readiness gate.

---

## 7. Pre-flight checklist (before firing soak 1)

- [ ] PR #784 (analyze_soak.py conflict fix) merged into claude/build84-cmdcon36
- [ ] `python -X utf8 Tools/Soak/analyze_soak.py --help` on the box Python confirms no import errors
- [ ] `fable/v2-cutover` rebased onto current master tip; conflicts resolved (section 6 guide applied)
- [ ] Lint gate clean on rebased branch: `python Tools\Lint\check_sqf.py --select A3CMD,A3MARKER,A3NUMGATE,A3REVEAL,A3SELECT,A3SORT,A3STRING,GROUPGETVAR,BRACKET,NSSETVAR3 --no-classname-index` — no new findings in V2-edited files
- [ ] `WFBE_C_AICOM_V2_ENABLE` registered in `Init_CommonConstants.sqf` with `default = 0`
- [ ] `Rsc/Parameters.hpp` lobby default for soak 1 set to `DECAP_ENABLE=0` (shadow mode)
- [ ] LoadoutManager run; TK/ZG mirrors verified (templates restored)
- [ ] cc48 PBO backed up on Main PC at a known path before deploying the soak build
- [ ] Box has no active players (checked BattleMetrics + Discord)
- [ ] aicom-watch.ps1 tested in dry-run to confirm it can connect to the box RPT path
- [ ] Score-AicomRounds.ps1 self-test passes: `.\Score-AicomRounds.ps1 -SelfTest`
- [ ] Soak window reserved: minimum 2.5 hours of uninterrupted empty server time

---

## 8. Soak log (fill in as soaks complete)

| Soak | Date | DECAP_ENABLE | Terrain | Duration | OVERALL | AICOM2-DECAP | Arrival% | Zombies | Notes |
|------|------|-------------|---------|----------|---------|-------------|----------|---------|-------|
| 1 | - | 0 | Chernarus | - | - | - | - | - | Shadow mode — DECAP circuit off |
| 2 | - | 1 | Chernarus | - | - | - | - | - | Full V2 |
| 3 | - | 1 | Chernarus/TK | - | - | - | - | - | Confirmatory |

**N=3 gate**: all three OVERALL = PASS or WATCH; soaks 2 and 3 AICOM2-DECAP = PASS. If any OVERALL = FAIL, that soak does not count toward N; fix and re-run.

---

## 9. References

- `docs/design/v2/AICOM-V2-CUTOVER-AND-RECONCILIATION.md` — the five-step sequence and owner ruling
- `Tools/Soak/README.md` — analyze_soak.py scorecard sections and KPI thresholds
- `Tools/Soak/analyze_soak.py` — grader (section 10 = AICOM2 soak-gate; GUIDE-REV GR-2026-07-03a)
- `Tools/PrTestHarness/Aicom/Score-AicomRounds.ps1` — per-round scorecard with gate mode
- `Tools/PrTestHarness/Ops/aicom-watch.ps1` — live AICOM2 line watcher
- `docs/design/v2/AICOM-V2-MIGRATION-MAP.md` — V1->V2 record/function mapping
- `docs/design/v2/AICOM-V3-TELEMETRY-CONTRACT.md` — unified grammar (AICOM2|v1| family)
