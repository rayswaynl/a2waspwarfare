---
name: rpt-triage
description: Load when diagnosing live-server, soak, or boot behavior from RPT logs — which RPT holds which subsystem, mandatory MISSINIT windowing via Get-WindowedRpt.ps1, analyze_soak.py grading, and the expected token vocabulary.
---
<!-- source: Agent-Guide GUIDE-REV GR-2026-07-08a -->

# rpt-triage

Wiki background: [AI-Assistant-Developer-Guide](https://github.com/rayswaynl/a2waspwarfare/wiki/AI-Assistant-Developer-Guide);
KPI definitions: `Tools/Soak/README.md`.

## 1. Log routing table (read the RIGHT file first)

The centralized per-side AICOM workers and the per-team driver are different
execution contexts. Do not apply one blanket "AICOM lives on the HC" rule.

| Token / family | Emitter | Expected RPT |
|---|---|---|
| `ASSAULT_DISPATCH`, `ASSAULT_ARRIVED`, `ASSAULT_STRANDED`, `ASSAULT_RETARGET`, `TARGET_ABANDON`, `RECYCLE_FLAG`, `ORBITER_STUCK`, `UNSTUCK_STRIKE`, `STUCKSTAT`, `CAPTURE_TRACE\|ORDER_PUBLISHED` | `Server/AI/Commander/AI_Commander_AssignTowns.sqf` server-side worker | server `arma2oaserver.RPT` |
| `RALLY_ORDER`, `FOOT_STAGE`, `STRIKE_STAGE_SKIP`, `ECON_SINK_*` | `Server/AI/Commander/AI_Commander_Strategy.sqf`, `AI_Commander_AssignTowns.sqf`, / `AI_Commander.sqf` server workers | server `arma2oaserver.RPT` |
| `MHQRELOC` | `Server/AI/Commander/AI_Commander_MHQReloc.sqf` server worker | server `arma2oaserver.RPT` |
| `RALLY_ARRIVED`, `BREAKOFF`, `TOPUP_REQ_*`, `TOPUP_DONE`, `UNSTUCK_FIRED`, driver `CAPTURE_TRACE` phases | `Common/Functions/Common_RunCommanderTeam.sqf` local team-driver loop | HC `ArmA2OA.RPT`; server-local teams may also write server RPT |
| `CAPTURED [` | local capture driver | HC `ArmA2OA.RPT`; server-local teams may also write server RPT |

The `Common_RunCommanderTeam.sqf` rows are intentionally **both-source**:
the function runs on the machine that owns a team. When multiple HC RPTs are
provided, pass each one with repeated `--hc`; count each supplied file once,
route only tokens expected there, and retain wrong-file hits as diagnostics.

`TEAM_RECYCLE` and `TARGET_ESCALATE` currently have no `diag_log` emitter in
the maintained mission tree. They are `no source`, not zero. If an expected
RPT was not supplied or could not be read, the analyzer must report `not
measured`, never `0`.

## 2. ALWAYS window to the last MISSINIT

RPT files never truncate during a server's lifetime; whole-file greps match stale
errors from earlier missions. Use the shared reader:

```powershell
. Tools\Monitor\Get-WindowedRpt.ps1
$lines = Get-WindowedRpt -RptPath $rpt                                  # current-mission window
$errs  = Get-WindowedRpt -RptPath $rpt -Pattern 'Error|ERROR'           # filtered
$boot  = Get-WindowedRpt -RptPath $rpt -WindowMarker 'Dedicated host created'  # per-boot window
$tail  = Get-WindowedRpt -RptPath $rpt -Tail 200                        # last 200 window lines
```

It opens the file with ReadWrite share, so it never locks the RPT under a running server.

## 3. Soak grading

```powershell
python Tools/Soak/analyze_soak.py <server.rpt> --hc <hc1.rpt> --hc <hc2.rpt>
python Tools/Soak/analyze_soak.py <server.rpt> --json                      # machine-readable
python Tools/Soak/analyze_soak.py <server.rpt> --compare-json previous.json
```

Pass every HC RPT or HC-only/partial telemetry is `not measured`; it must not
be read as a dead subsystem. Only the LAST MISSINIT block of each HC RPT is
scoped (HC RPTs accumulate old matches). Verdicts: PASS/WATCH/FAIL.

## 4. Token vocabulary (what "healthy" looks like)

- `MISSINIT` — mission start marker; the window boundary for everything.
- `AICOMGATE` — AICOM gating decisions.
- `AICOMSTAT|v2|EVENT|...` — source-specific; use the routing table above for
  `TEAM_FOUNDED`, `ASSAULT_*`, `TARGET_ABANDON`, `RALLY_ORDER`, and driver events.
- `CMDRSTAT` — commander telemetry.
- `WASPSTAT|v1|<seq>|KILL/CAPTURE/ROUNDEND|...` — match stats feed (server RPT).
- `WASPSCALE|v2|<tick>|tier=|players=|...|fps=|hc_fps=` — perf/scale heartbeat.
- `GUERAIRDEF|` and `GUERVBIED|v1|` — GUER subsystem heartbeats.
- AICOM tick = 1 minute wall-clock (tick/60 = hours) for churn rates.

Absence of an expected token inside the current window is itself a finding — report
"token X absent since MISSINIT", not "feature broken".

## 5. Per-line lint suppression (noqa) — for context when triaging RPT-adjacent code

SQF source files may contain `// noqa: CODE` comments that suppress a specific lint code
on that line (e.g. `// noqa: A3CMD`); bare `// noqa` suppresses all codes on the line.
Stale suppressions where no finding fires are reported as `DEADNOQA` by the lint gate.
`A3PRIVATE` was restored to the gate list by PR #741 after a period of exclusion; stale
`// noqa: A3PRIVATE` annotations from that window should be removed once the underlying
`private _x =` trap is corrected. Full gate command: see `sqf-edit-guard` § 4.

## 6. Clock

The box runs US Pacific (~9h behind Amsterdam). Convert before matching RPT timestamps
to player reports or Discord messages.
