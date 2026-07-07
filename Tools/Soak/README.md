# WASP Soak-KPI Analyzer (`analyze_soak.py`)

One command to grade a soak against the **cmdcon41 fix-package KPIs**.

After a soak match ends, pull the two RPTs and run the analyzer. It prints a
compact scorecard with `PASS` / `WATCH` / `FAIL` per KPI and an overall verdict.

- **Python 3.6+, standard library only.** No install, no deps.
- Reads a **server RPT** (required) and an optional **HC RPT** (the AICOM
  *team-driver* logs — including `CAPTURED [` capture lines — live on the
  Headless Client, not the server; see "Why two RPTs" below).

---

## Quick start

```bash
# server RPT only
python analyze_soak.py arma2oaserver.RPT

# server + HC RPT (recommended — adds capture-driver / dogpile detail)
python analyze_soak.py arma2oaserver.RPT ArmA2OA.RPT
#   ...or explicitly:
python analyze_soak.py arma2oaserver.RPT --hc ArmA2OA.RPT

# machine-readable dump (for dashboards / diffing runs)
python analyze_soak.py arma2oaserver.RPT --hc ArmA2OA.RPT --json

# compare the current run against a saved JSON run from an older build
python analyze_soak.py arma2oaserver.RPT --hc ArmA2OA.RPT --compare-json build85.json

# validate against the archived reference match (reproduces known numbers)
python analyze_soak.py C:/Users/Game/wasp-westwin-20260701.rpt
```

### Options

| flag | meaning |
|------|---------|
| `<server.rpt>` | **required** — `arma2oaserver.RPT` from the box |
| `[hc.rpt]` or `--hc <path>` | optional Headless-Client RPT (`ArmA2OA.RPT`) |
| `--zombie-min N` | dispatches threshold for the "zombie" definition (default **3**, which reproduces the documented baseline of 13; `2` → 15, `1` → 20) |
| `--json` | emit JSON instead of the text scorecard |
| `--compare-json <path>` | compare headline KPIs against a previous analyzer JSON file |
| `--no-color` | disable ANSI color (auto-disabled when piped/redirected) |
| `-h`, `--help` | print the module docstring (full log-format cheat-sheet) |

Color is on for a TTY and off when the output is piped or redirected, so
`> report.txt` and `| tee` produce clean plain text automatically.

---

## Pulling the RPTs from the box

Live box: **`Administrator@78.46.107.142`** (Windows / OpenSSH). The box runs
US-Pacific time (~9h behind Amsterdam).

```bash
# --- server RPT (the AICOM commander + WASPSTAT + WASPSCALE lines) ---
scp "Administrator@78.46.107.142:C:/Users/Administrator/Documents/Arma 2 Other Profiles/*/arma2oaserver.RPT" ./arma2oaserver.RPT
#   (exact server RPT dir varies by profile; if unsure, ssh in and locate it:
#    ssh Administrator@78.46.107.142 'dir /s /b C:\arma2oaserver.RPT')

# --- HC RPT (the team-driver / CAPTURED [ lines) ---
scp "Administrator@78.46.107.142:C:/Users/Administrator/AppData/Local/ArmA 2 OA/ArmA2OA.RPT" ./ArmA2OA.RPT
```

> **HC RPT path (authoritative):**
> `C:\Users\Administrator\AppData\Local\ArmA 2 OA\ArmA2OA.RPT`

Then:

```bash
python analyze_soak.py ./arma2oaserver.RPT --hc ./ArmA2OA.RPT
```

### MISSINIT scoping (important)

Both RPTs are scoped to the **last MISSINIT that actually has gameplay stats
after it**, automatically:

- The **HC RPT is not rotated on deploy**, so it accumulates every past match.
  Scoping to the last *played* MISSINIT keeps only the current soak.
- A match ends with a post-deploy **reboot** that emits a fresh MISSINIT but no
  stats (a "dead boot"). The tool skips that empty tail and scopes to the last
  MISSINIT block that contains `WASPSTAT|` / `AICOMSTAT|` / `WASPSCALE|` lines.
  (The archived reference RPT has exactly this dead-boot tail; the tool handles
  it correctly.)

You do **not** need to trim the RPTs by hand.

---

## Why two RPTs

Per the mission architecture, **AICOM teams run on the Headless Client**, so the
team-level telemetry — `begin_capture`, `CAPTURED [ ... ]`, driver stall/errors
— is written to the **HC** RPT (`ArmA2OA.RPT`), *not* the server RPT
(`arma2oaserver.RPT`). The server RPT carries the commander-level lines
(`AICOMSTAT|v1/v2`, `WASPSTAT|v1`, `WASPSCALE|v2`).

If you pass only the server RPT you still get every KPI that matters for the
fix-package (arrival, zombies, army-vs-army, churn, MHQ, perf, new events);
adding the HC RPT unlocks the **capture-driver / per-town dogpile** detail in
section 6.

---

## What the scorecard reports

1. **ARRIVAL** — dispatches, arrivals, arrival % (overall + by dispatch-distance
   bucket `<500 / 500-2000 / 2000+`), delta vs the pre-fix baseline **6.9%**, and
   the median dispatch→arrival time in minutes.
2. **ZOMBIES** — teams with `>= --zombie-min` dispatches and **0** arrivals
   (worst 5 listed), vs baseline **13**.
3. **ARMY-VS-ARMY** — killer-side × victim-side kill matrix, plus the W↔E share
   of total kills (baseline **32 / 3813 = 0.8%**). W↔E counts kills where *both*
   killer and victim are WEST/EAST (i.e. army-vs-army, GUER excluded).
4. **CHURN** — FRONT primary changes per side **per hour** (baseline W 102 /
   E 122 over ~7h), TARGET_ABANDON (with reasons), SPEARHEAD_REPICK, and the
   reissue share of dispatches.
5. **NEW cmdcon41 events** — count + last-3 samples for each of:
   `TARGET_ESCALATE, RALLY_ORDER, RALLY_ARRIVED, BREAKOFF, TOPUP_REQ,
   TOPUP_DONE, TEAM_RECYCLE, RECYCLE_FLAG, ORBITER_STUCK, ECON_SINK,
   CAPTURE_TRACE, STAGE`; the `CAPTURE_TRACE` **ARRIVAL_GATE vs ARRIVAL_WAIT**
   ratio; `BASE-ASSAULT` fire-phase lines; and **MHQRELOC DEPLOYED vs ABORT**
   with abort-reason breakdown (baseline **43/43 aborts, 0 deployed**).
6. **HOLD / SEE-SAW** — max simultaneous towns held per side (from POSTURE
   `myTowns=`), captures per town (**dogpile** flag at ≥4), and — if the HC RPT
   is supplied — the HC `CAPTURED [` driver counts per town.
7. **PERF** — WASPSCALE server-fps / HC-fps min/median/max, AI_TOT curve, GUER
   peak, and fps at peak AI load (the FPS-cliff check).
8. **BUILD 86+ LOG FAMILIES** — first-class counters for `MHQRELOC` verbs
   including `RELAXED`, `BUILD_ROAD_*` base-placement gates, ground-patrol
   naval-HVT skips, `ICBMTEL|v1|...` SCUD/TEL events and munitions, the
   `[WFBE (SKIN)]` B0–B6 chain, EASA/gear log-line samples, and cmdcon43
   families (`UPGRADE_SOUND`, `TIP_SKIP`, `TIP_SHOW`, `VEHLIFT_DROP`,
   `VEHLIFT_ABORT`, `BISRNG`).
9. **VERDICT** — PASS/WATCH/FAIL per KPI + overall (worst-of).

### Per-build comparison

Save one run with `--json`, then pass that file to a later run with
`--compare-json previous.json`. The text report adds a compact comparison table
for arrival %, zombie teams, W↔E share, MHQ deployed/abort counts, median
server FPS, TEL fires, patrol naval skips and skin-selector completions. With
`--json`, the same comparison appears under `comparison`.

The repository includes `sample_build86.rpt` as a tiny parser smoke fixture:

```bash
python analyze_soak.py Tools/Soak/sample_build86.rpt --json
python analyze_soak.py Tools/Soak/sample_build86.rpt --compare-json previous.json
```

### Verdict thresholds

| KPI | PASS | WATCH | FAIL |
|-----|------|-------|------|
| arrival % | > 20% (> 30% = great) | 10–20% | < 10% |
| zombies | ≤ 2 | 3–5 | > 5 |
| W↔E kill share | > 5% | 2.5–5% | < 2.5% |
| churn (per side, per hour) | ≤ 50% of baseline (halved) | 50–80% | > 80% |

Tune the constants at the top of `analyze_soak.py` (`TH_*`, `BASE_*`,
`ZOMBIE_MIN_DISPATCH`) if the fix-package targets change.

---

## Validation

Running against the archived reference match reproduces the known pre-fix
numbers (and, correctly, **FAILs every KPI** — it is the *pre-fix* baseline
being graded against the cmdcon41 targets):

```
$ python analyze_soak.py C:/Users/Game/wasp-westwin-20260701.rpt
  dispatches : 583   arrivals : 40   arrival % : 6.9%
  zombie teams: 13
  W<->E kills : 32   (0.84% of 3813)
  FRONT changes: WEST 102   EAST 122
  MHQRELOC: DEPLOYED=0  ABORT=43   (no-buffer-clear-standoff=31, advance-below-min=12)
  OVERALL: FAIL   (expected — pre-fix baseline)
```

A healthy **cmdcon41** soak should flip ARRIVAL/ZOMBIES/CHURN toward PASS and
begin populating the section-5 new-event counters.

---

## Section 10 — AICOM2 soak-gate (V2 cutover, GR-2026-07-03a)

Section 10 of the scorecard is added automatically when the RPT contains
`AICOM2|v1|` lines.  It gates the parity-soak requirement from the AICOM V2
cutover brief (Guide-Rev GR-2026-07-03a).

### AICOM2 grammar reference

| Family | Key fields |
|--------|-----------|
| `AICOM2\|v1\|SNAP\|<side>\|<tick>\|…` | myTowns, enTowns, myEff, enEff, funds, enHQ |
| `AICOM2\|v1\|ALLOC\|<side>\|<tick>\|…` | primary, src, harassTo, assigned, harass, concentrate |
| `AICOM2\|v1\|DECAP\|<side>\|<tick>\|…` | state (SCAN/TRACK/PRESS), inRange, roll, sensed, stamped |
| `AICOM2\|v1\|FISTPOOL\|<side>\|…` | soft, neutInclGuer, using |
| `AICOM2\|v1\|ORDER\|<subtype>\|<side>\|<tick>\|…` | mode, goto |
| `AICOMSTAT\|v1\|POSTURE\|<SIDE>\|<tick>\|PRESS\|…` | myTowns, enTowns (PRESS-mode confirmation) |

All lines are scoped to the last MISSINIT before scoring.

### Section 10 heuristics

| Signal | Description |
|--------|-------------|
| **SNAP trajectory** | myTowns first → last; peak; enHQ last value |
| **ALLOC summary** | primary changes (strategy pivots), harass ticks, src distribution |
| **DECAP state distribution** | SCAN/TRACK/PRESS counts per side |
| **inRange streaks** | longest consecutive tick-run with inRange > 0 |
| **Roll cadence** | expects ≥1 roll=1 every 4-tick window |
| **Sensed latches** | count of false → true transitions on the sensed field |
| **stamped max** | cumulative stamped counter high-water mark |
| **PRESS events** | AICOMSTAT POSTURE PRESS confirmation count |
| **DECAP verdict** | FAIL if SNAP present but DECAP entirely absent (V2 not wired); WATCH if roll cadence violated; PASS otherwise |

The DECAP verdict participates in the OVERALL verdict (worst-of).

### Fixture for section 10

`sample_cc44u.rpt` is a ~33-line fixture covering the full AICOM2 grammar.
It is used by `test_analyze_soak.py` (`AnalyzeSoakAicom2Tests`, 10 tests).
Run with:

```bash
python analyze_soak.py Tools/Soak/sample_cc44u.rpt
python -m unittest Tools/Soak/test_analyze_soak.py
```

---

## Companion tools — AICOM2 soak-gate tooling

These two PowerShell scripts live in `Tools/PrTestHarness/` and complement the
Python analyzer for real-time soak monitoring and per-round scoring.

---

### `Tools/PrTestHarness/Aicom/Score-AicomRounds.ps1`

Reads the **latest round** (MISSINIT-scoped) from an RPT file or the newest
RPT in an archive directory and emits a compact round scorecard.

**Scorecard sections:**

- Round outcome (winner from WASPSTAT ROUNDEND or AICOMSTAT FINAL)
- WASPSCALE FPS / HC-FPS samples (min / median / max, build label)
- Per-side SNAP trajectory (towns, enHQ)
- Per-side ALLOC summary (primary changes, harass ticks, src distribution)
- Per-side DECAP chain (state distribution, inRange max + longest streak,
  roll cadence, sensed latches, stamped max, PRESS events)
- AICOM2 ORDER subtype counts
- Error-family counts (Script error / Undefined variable / No entry / etc.)
- Gate verdict (pass/fail, exit code 0/1)

**Usage:**

```powershell
# Score the live server RPT
.\Score-AicomRounds.ps1 -RptPath "C:\WASP\rpts\arma2oaserver.RPT"

# Soak-gate mode (fail if gates not met)
.\Score-AicomRounds.ps1 -RptPath "arma2oaserver.RPT" `
    -MinSnapLines 5 -RequireDecap -MaxErrors 10

# Auto-pick newest RPT from an archive dir
.\Score-AicomRounds.ps1 -ArchiveDir "C:\WASP\rpts\"

# Self-test against sample_cc44u.rpt
.\Score-AicomRounds.ps1 -SelfTest
```

**Exit codes:** 0 = all gates pass, 1 = one or more gates failed.

---

### `Tools/PrTestHarness/Ops/aicom-watch.ps1`

`tail -f` style live watcher filtering for `AICOM2|` and `AICOMSTAT|` lines.
Colorizes DECAP state transitions (SCAN / TRACK / PRESS) and flags the moment
a side crosses into PRESS mode.

**Color key:**

| Color | Meaning |
|-------|---------|
| dim   | SNAP lines (low-frequency summary) |
| yellow | TRACK state |
| red background | PRESS state / POSTURE PRESS events |
| magenta | ORDER lines |
| cyan | AICOMSTAT / FISTPOOL |
| green background | ROUNDEND |

A `-> ` annotation is appended when the DECAP state *changes*, making
mode transitions visible at a glance.

**Usage:**

```powershell
# Watch the default HC RPT (auto-discovered from %LOCALAPPDATA%\ArmA 2 OA\)
.\aicom-watch.ps1

# Watch only DECAP lines
.\aicom-watch.ps1 -Family DECAP

# Watch a specific RPT, also show ROUNDEND/KILL/CAPTURE
.\aicom-watch.ps1 -RptPath "arma2oaserver.RPT" -ShowWaspstat

# Self-test (no live RPT needed)
.\aicom-watch.ps1 -SelfTest
```

CTRL+C to stop the watcher.  The script is non-destructive and read-only.

---

## Soak ledger (the data spine)

The ledger is the append-only, durable record every soak run flows into — the substrate the
nightly farm, the Discord verdict poster, the golden-baseline regression check, and any future
admin hub all read from. Its schema is frozen in
[`docs/design/v2/SPEC-SOAK-LEDGER-CONTRACT.md`](../../docs/design/v2/SPEC-SOAK-LEDGER-CONTRACT.md)
and mirrored as a machine-checkable JSON Schema in `run_result.schema.json`.

**Files**

| File | Role |
| --- | --- |
| `soak-ledger.jsonl` | The ledger itself. One JSON object per line; first line is a `#` header comment. Runtime data — **git-ignored**, created on first append. |
| `run_result.schema.json` | JSON Schema (draft-07) freezing the v1 row contract. |
| `Append-LedgerRow.ps1` | The only supported writer. Generates `rowId`, de-dupes on `stampId`, maps analyzer JSON into the curated row, appends one line. |
| `Append-LedgerRow.Tests.ps1` | Dependency-free assertion suite (no Pester). Exit 0 pass / 1 fail. |
| `validate_ledger.py` | Validates a ledger file against the schema without needing the `jsonschema` package. `--self-test` for CI. |
| `golden-baselines.json` | Per-regime expected-value baselines for regression detection. Provisional `documented` seeds (n=0) get promoted to `measured` once ≥5 real rows exist. |

**Core rules** (enforced by the writer + validator):

- **Null is not zero.** An unknown/N-A field is `null` and is never omitted; `0` means a measured zero. Readers must never infer PASS from a missing field.
- **`rowId` = `YYYYMMDD-NNNN`**, one-based and scoped to the UTC append date; the writer computes it, callers never pass it.
- **Duplicate `stampId` is rejected** (throws, appends nothing) unless the row is a `SKIP_*` status *and* `-AllowDuplicateSkip` is set.

**Append a row** (normal deploy-candidate run):

```powershell
python Tools\Soak\analyze_soak.py <server.RPT> --hc <ArmA2OA.RPT> --json > analyze.json
$rowId = .\Tools\Soak\Append-LedgerRow.ps1 `
    -LedgerPath   Tools\Soak\soak-ledger.jsonl `
    -Status       POSTED `
    -StampPath    <deploy-stamp.json> `
    -AnalyzeJsonPath analyze.json `
    -ServerRptPath <server.RPT> -HcRptPath <ArmA2OA.RPT> `
    -DiscordGuildId 1510513623800221857 -DiscordChannelId 1510573856275038228
```

**Record a run that never produced an RPT** (box down, too short, etc.) — KPIs land as `null`, not `0`:

```powershell
.\Tools\Soak\Append-LedgerRow.ps1 -LedgerPath Tools\Soak\soak-ledger.jsonl `
    -Status SKIP_BOX_DOWN -StampPath <stamp.json> -AllowDuplicateSkip -Note "SCP failed before analyzer stage."
```

**Verify** (both are CI-friendly, dependency-free):

```powershell
pwsh Tools\Soak\Append-LedgerRow.Tests.ps1     # writer round-trip + contract checks
python Tools\Soak\validate_ledger.py --self-test
python Tools\Soak\validate_ledger.py Tools\Soak\soak-ledger.jsonl   # conformance of a real ledger
```

---

## Scenarios (named, repeatable recipes)

Instead of ad-hoc soaks, tests are **named recipes** in `scenarios.json`. `Get-ScenarioSpec.ps1`
resolves a name to a full config; `Run-Scenario.ps1` plans or grades it and feeds the ledger above.

**Catalog** (`scenarios.json`): `defend-town`, `big-assault`, `load-ramp` (popPin sweep),
`idle-soak`, `hc-split` (1-HC-vs-2-HC sweep), `flight-probe`, `a-life-probe` (GUER Director aliveness).
Each recipe carries a map/HC/popPin/duration config, the flags to inject, and threshold **asserts**
(`severity: fail` → a miss makes the run FAIL; `watch` → WATCH).

```powershell
# list the catalog
.\Tools\Soak\Get-ScenarioSpec.ps1 -List

# resolve a recipe to concrete runs (sweeps expand to one run per value)
.\Tools\Soak\Get-ScenarioSpec.ps1 -Name hc-split -Json

# PLAN a run — prints config + the server/HC launch command lines + asserts. No side effects.
.\Tools\Soak\Run-Scenario.ps1 -Name big-assault -DryRun

# GRADE a produced RPT — analyze -> metrics -> verdict -> Run-Result JSON + ledger row (+ -Peach DM)
.\Tools\Soak\Run-Scenario.ps1 -Name idle-soak -FromRpt <server.RPT> -HcRpt <ArmA2OA.RPT> -Peach
```

`Run-Scenario.ps1` **does not spawn Arma** — it plans (`-DryRun`) and grades (`-FromRpt`). Live boot
orchestration is the sandbox-boot track; keeping the driver spawn-free makes it safe and fully
testable. Each `-FromRpt` grade writes `results/<runId>.json` (the Standard Run-Result: config,
metrics, per-assert verdicts, boot-smoke, ledger rowId, artifacts) and appends one ledger row.

**Metrics** the asserts reference (computed from `analyze_soak.py` output): `serverFpsMedian`,
`serverFpsMin`, `hcFpsMedian`, `hc2FpsMedian`, `aiTotPeak`, `guerPeak`, `captures`, `arrivalPct`,
`maxTownsWest`, `maxTownsEast`, `hours`.

**Verify:**
```powershell
pwsh Tools\Soak\Get-ScenarioSpec.Tests.ps1
pwsh Tools\Soak\Run-Scenario.Tests.ps1
```

---

## Charts (`chart_soak.py`)

Renders the ledger + Run-Result JSONs as a single **self-contained HTML report** with inline SVG.
**Dependency-free** (hand-rolled SVG — no matplotlib/numpy), so it runs on the box exactly as on a
dev box. Charts are **theme-aware** (adapt to the viewer's light/dark) and **null is not zero**
(a missing metric is skipped, never plotted as 0).

Five chart types:
1. **FPS knee** — `serverFpsMedian` vs `aiTotPeak` (with the documented ~450-470 unit band shaded).
2. **HC split** — `serverFpsMedian` at 1 HC vs 2 HC for matched population (grouped bars).
3. **Population sweep** — `serverFpsMedian` + `hcFpsMedian` vs `popPin`.
4. **FPS timeline** — `serverFpsMedian` across ledger history.
5. **Verdict tally** — PASS / WATCH / FAIL counts.

```powershell
# standalone
python Tools\Soak\chart_soak.py --ledger Tools\Soak\soak-ledger.jsonl --results Tools\Soak\results --out report\soak-report.html

# automatic: every grade refreshes the report
.\Tools\Soak\Run-Scenario.ps1 -Name load-ramp -RunLabel pin10 -FromRpt <server.RPT> -Report

# self-test
python Tools\Soak\chart_soak.py --self-test
```

Empty inputs render gracefully (each card shows "no data yet" until runs accumulate).
