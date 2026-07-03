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
