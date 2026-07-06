# SPEC-SOAK-LENS-PACK

Status: SPEC-READY. Implementation files are intentionally not created in this prep lane.

Guide rev for downstream PR bodies: GR-2026-07-03a.

## Objective

Add a Python 3.6+ stdlib rule pack that converts soak analyzer JSON plus raw RPT pattern counts into four explicit verdict lenses. The farm then uses the worst lens as the Discord and ledger verdict.

The lens pack must not replace `Tools/Soak/analyze_soak.py`; it wraps it with operational checks learned from the 44b/44d/44f cycle and the B57/B58 overnight baselines.

## Baseline Facts To Encode

| Fact | Source | Rule impact |
| --- | --- | --- |
| 44b: 2646 err, 0 caps | roster baseline note | Error lens FAIL at high engine/log error volume even when caps are 0. |
| 44d: 697 err, 0 caps | roster baseline note | Error lens WATCH/FAIL boundary below 700 non-SQF engine errors. |
| 44f: 1 err, 3 caps | roster baseline note | 1 engine error can PASS; 3 group-cap warnings can be WATCH but not auto-fail. |
| 44f Zargabad 52 min: first flip t=600, 3 captures, cappasses x31, 72 PRESS | roster baseline note | War-progress lens PASS for first flip by 10 minutes and multiple captures in a short soak. |
| B57/B58 server FPS med about 43, min about 35, max about 49 | `B57-SOAK-PROPOSALS.md` | Perf PASS floor: median >= 39 and min >= 35 at scale. |
| HC FPS mostly 44-49 with transient dips | `B57-SOAK-PROPOSALS.md` | Single HC dip below 25 is WATCH if it recovers; sustained dips FAIL. |
| Antistack peaks around 361 ms are hands-off | `B57-SOAK-PROPOSALS.md` | Perf lens records antistack but never recommends touching antistack. |
| `Message not sent` can dominate the log while `err=0` | `B57-SOAK-PROPOSALS.md` | Error lens counts engine/network send failures separately from SQF errors. |

## Invocation

```powershell
python Tools\Soak\run_lens_pack.py `
  --stamp C:\Users\Game\a2waspwarfare-soak\.deploy-stamp.json `
  --analyze C:\Users\Game\a2waspwarfare-soak\rpt\<stamp>\analyze.json `
  --server C:\Users\Game\a2waspwarfare-soak\rpt\<stamp>\arma2oaserver.RPT `
  --hc C:\Users\Game\a2waspwarfare-soak\rpt\<stamp>\ArmA2OA.RPT `
  --out C:\Users\Game\a2waspwarfare-soak\rpt\<stamp>\lens.json
```

The script must exit non-zero only on invalid inputs or write failure. A bad soak is valid JSON with `overall.verdict=FAIL`.

## Verdict Order

Worst-of order:

```text
PASS < WATCH < FAIL < SKIP
```

`SKIP` is reserved for non-comparable runs: missing version marker, too short, no gameplay stats, or analyzer JSON absent.

## Lens 1: Release And Box Health

Purpose: prove the RPT belongs to the stamped build and the box was alive long enough to judge.

Patterns:

- `WASPRELEASE|v1|candidate=`
- `WF_RELEASE_MARKER`
- `MISSINIT`
- `WASPSTAT|v1|...|ROUNDEND|`
- `WASPSCALE|v2|`
- `HCDROP_AICOM_AUDIT`
- `HCRECON_AICOM_AUDIT`
- `Player without identity HC`
- `WaspCleanRestart`

Thresholds:

| Verdict | Rule |
| --- | --- |
| PASS | Expected release marker present; at least 52 minutes or ROUNDEND; at least one WASPSCALE sample; no HC drop without reconnect. |
| WATCH | Missing HC RPT but server RPT is analyzable; one clean restart with later matching marker; no ROUNDEND but duration >= 52 minutes. |
| FAIL | Release marker mismatches stamp; server RPT missing; no gameplay stats after MISSINIT; HC drops and never reconnects. |
| SKIP | Stamp absent/duplicate or soak shorter than 52 minutes without ROUNDEND. |

Fields:

```json
{
  "release": {
    "verdict": "PASS",
    "candidateMatch": true,
    "terrainMatch": true,
    "durationMinutes": 52,
    "roundendSeen": false,
    "serverRptPresent": true,
    "hcRptPresent": true,
    "hcDropCount": 0,
    "hcReconnectCount": 0,
    "cleanRestartCount": 0,
    "notes": []
  }
}
```

## Lens 2: Error And Log Health

Purpose: catch script errors and engine/network noise that the old impressions counter missed.

Patterns:

- `Error in expression`
- `Error position`
- `Undefined variable`
- `Missing ;`
- `No entry`
- `Warning Message`
- `Message not sent`
- `Object ... not found (message`
- `Cannot load sound`
- `Hitpoint ... not found`

Classification:

| Family | Severity |
| --- | --- |
| SQF expression, position, undefined, missing semicolon | FAIL if count > 0 |
| `Message not sent` | PASS <= 10 total, WATCH 11-700, FAIL > 700 or > 250/hour |
| `Object not found (message N)` | PASS <= 500/hour, WATCH above, FAIL only if paired with HC drop or send-failure burst |
| Cosmetic missing sound / hitpoint | PASS with note |
| `Warning Message` | WATCH if nonzero; FAIL if mission-content missing entry blocks gameplay |

The 44f reference allows `err=1` and 3 cap warnings to remain non-failing. The 44d reference shows 697 send/log errors is still too noisy for PASS. The B57/B58 note shows 20k `Message not sent` must be FAIL even when SQF errors are zero.

Fields:

```json
{
  "errors": {
    "verdict": "WATCH",
    "sqfErrorCount": 0,
    "undefinedCount": 0,
    "warningMessageCount": 0,
    "messageNotSentCount": 1,
    "objectNotFoundMessageCount": 0,
    "cosmeticNoiseCount": 2,
    "perHour": {
      "messageNotSent": 1.2
    },
    "notes": []
  }
}
```

## Lens 3: War Progress And Behavior

Purpose: detect dead-air, stuck-front, dogpile, and no-flip failures.

Analyzer JSON inputs:

- `hours`
- `arrival.arrival_pct`
- `arrival.dispatches`
- `zombies.count`
- `churn.front_changes`
- `churn.target_abandon`
- `hold.captures`
- `hold.capture_by_town`
- `hold.hc_captured`
- `war_state_ext.present`
- `war_state_ext.arrival_rate_pct` if present

Raw RPT patterns:

- `AICOMSTAT|v2|EVENT|...|PRESS`
- `AICOMSTAT|v2|EVENT|...|CAPTURE_PASS`
- `AICOMSTAT|v2|EVENT|...|ASSAULT_DISPATCH`
- `AICOMSTAT|v2|EVENT|...|ASSAULT_ARRIVED`
- `AICOMSTAT|v2|EVENT|...|TARGET_ABANDON`
- `AICOMSTAT|v2|EVENT|...|ASSAULT_STRANDED`
- `WASPSTAT|v1|...|CAPTURE`
- `CAPTURED [`

Thresholds:

| Verdict | Rule |
| --- | --- |
| PASS | First capture/flip by <= 900s on small-map soaks or captures/hour >= 2.0; arrival analyzer PASS; zombies <= 2; no town with >= 4 captures unless the match is see-sawing intentionally. |
| WATCH | First flip 901-1800s; captures/hour 0.5-2.0; 3-5 zombies; one dogpile town; stranded events resolve via abandon/recovery. |
| FAIL | No capture by 52 minutes; captures/hour < 0.5 after first hour; arrival < 10%; zombies > 5; repeated `ASSAULT_STRANDED` with no later abandon/recovery; target churn > 80% baseline. |

Special 44f Zargabad acceptance:

- 52-minute run with first flip at t=600, 3 captures, `CAPTURE_PASS` around 31, and `PRESS` around 72 is PASS for progress even without a full overnight.

Fields:

```json
{
  "war": {
    "verdict": "PASS",
    "firstFlipTick": 600,
    "captureCount": 3,
    "capturesPerHour": 3.46,
    "capturePassCount": 31,
    "pressCount": 72,
    "arrivalPct": 22.4,
    "zombieCount": 1,
    "dogpileTowns": [],
    "strandedCount": 0,
    "notes": []
  }
}
```

## Lens 4: Performance And Locality

Purpose: keep V2 and soak builds within the known healthy FPS/locality band.

Analyzer JSON inputs:

- `perf.fps` as `[min, median, max]`
- `perf.fpsmin` as `[min, median, max]`
- `perf.hc_fps`
- `perf.hc2fps`
- `perf.ai_tot`
- `perf.samples`
- `war_state_ext.group_*` if present

Raw RPT patterns:

- `[Performance Audit]`
- `GRPBUDGET|WARN`
- `HCSTAT`
- `HCDELEG`
- `HCDISPATCH`
- `delegate_townai_headless`
- `antistack_main`
- `antistack_flush`

Thresholds:

| Verdict | Rule |
| --- | --- |
| PASS | Server FPS median >= 39, server FPS min >= 35, HC median >= 44, no sustained HC FPS below 25, group-cap warnings <= 3 in a short run or <= 0.5/hour overnight. |
| WATCH | Server FPS median 35-38.9 or min 30-34.9; HC dips below 25 but recover in the next sample; group-cap warnings 4-10 short-run or <= 2/hour overnight. |
| FAIL | Server FPS median < 35; server FPS min < 30 outside boot; any HC dead/disconnected; sustained HC FPS below 25 across 3 samples; group-cap warnings > 10 short-run or > 2/hour overnight. |

Antistack:

Record max observed antistack milliseconds. Do not emit a recommendation to change antistack; AGENTS owner constraints make antistack out of scope.

Fields:

```json
{
  "perf": {
    "verdict": "PASS",
    "serverFps": {"min": 35, "median": 43, "max": 49},
    "serverFpsMinWindow": {"min": 35, "median": 41, "max": 46},
    "hcFps": {"min": 44, "median": 46, "max": 49},
    "hc2Fps": {"min": 44, "median": 46, "max": 49},
    "aiTotPeak": 375,
    "groupCapWarnCount": 3,
    "antistackMaxMs": 361,
    "notes": []
  }
}
```

## Full JSON Schema

Top-level:

```json
{
  "schema": "a2wasp-soak-lens-v1",
  "generatedAtUtc": "2026-07-04T00:00:00Z",
  "stampId": "cmdcon44f-20260703-231500Z",
  "candidate": "cmdcon44f",
  "terrain": "zargabad",
  "overall": {
    "verdict": "WATCH",
    "worstLens": "perf",
    "summary": "Progress PASS, errors PASS, release PASS, perf WATCH due cap warnings."
  },
  "release": {},
  "errors": {},
  "war": {},
  "perf": {},
  "source": {
    "analyzeJson": "C:/.../analyze.json",
    "serverRptLabel": "arma2oaserver.RPT",
    "hcRptLabel": "ArmA2OA.RPT"
  }
}
```

Do not include full local paths in Discord. Local paths are allowed in the JSON for operator troubleshooting.

## Baseline Update Policy

Only update thresholds when all are true:

- A new owner-approved soak baseline exists.
- The old and new analyzer JSON files are committed or archived with SHA256.
- `Tools/Soak/README.md` is updated in the same PR.
- The PR body explains why GR-2026-07-03a thresholds changed.

