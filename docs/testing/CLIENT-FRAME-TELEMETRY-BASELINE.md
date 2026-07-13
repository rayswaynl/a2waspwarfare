# Client frame telemetry baseline

This adds a default-off, measurement-only client stream for Arma 2: Operation Arrowhead 1.64.
It is deliberately local to each player RPT: the probe does not publish frame samples, alter
simulation, or send a per-sample network message.

## Enablement

Set the lobby parameter `WFBE_C_CLIENT_FRAME_TELEMETRY` to `1` for a measurement run. The
default is `0`. `WFBE_C_CLIENT_FRAME_TELEMETRY_INTERVAL` controls report cadence and defaults to
60 seconds. The existing coarse `WFBE_C_CLIENT_FPS_REPORT` default is also corrected to `0` so
client measurement is opt-in at the lobby boundary.

The client samples the inverse `diag_fps` frame-time proxy at a 250 ms scheduled cadence. Once
per report it writes one `CLIENTFRAME|v1|` line containing frame samples and context: frame-time
p50/p95/p99 can therefore be calculated offline, long frames at 50/100 ms, the FPS 1-percent-low
proxy, map/GPS/dialog state, entity/vehicle/marker counts, view distance, terrain grid, and
time-to-playable. Hardware tier, process CPU, and working set are intentionally `external`/`na`
in the mission line because OA 1.64 has no supported SQF process or hardware query.

## Offline report

```powershell
python Tools\PerformanceAuditAnalyzer\analyze_client_frame_telemetry.py `
  .\logs\client.rpt `
  --output .\results\client-frame-summary.json `
  --runtime .\results\client-runtime.jsonl
```

The JSON follows `Tools/PerformanceAuditAnalyzer/client_frame_telemetry.schema.json` and the
tool writes a compact Markdown report beside it. `p01LowProxy = 1000 / p99(frameMs)` is a
frame-time-derived proxy, not a replacement for a present-time capture or a GPU overlay.

For process/memory correlation, run the optional same-machine collector while the game runs:

```powershell
powershell -ExecutionPolicy Bypass -File Tools\PerformanceAuditAnalyzer\Collect-ClientRuntime.ps1 `
  -OutputPath .\results\client-runtime.jsonl -IntervalSec 5
```

The collector records Arma 2 OA working set, process CPU, a reproducible coarse hardware tier,
core count, and physical memory. The analyzer only joins rows when the RPT exposes wall-clock
timestamps and the sidecar has a sample within 30 seconds; otherwise it reports correlation as
unavailable instead of inventing alignment.

## Overhead proof

The flag-off path exits before creating the sampler loop, so it adds no scheduled VM, `diag_fps`
read, RPT line, network message, or entity scan. The enabled loop performs one `diag_fps` read
and one sleep per 250 ms sample; `allUnits`, `vehicles`, and marker registry counts occur once
per report, not per sample. It emits one local line per report interval. The focused Python tests
cover percentile math, long-frame accounting, sidecar matching, the no-data/offline path, and
CLI schema output:

```powershell
python -m unittest Tools\PerformanceAuditAnalyzer\test_client_frame_telemetry.py
```

An on/off A/B soak should use identical map, player/AI load, view distance, terrain grid, and
hardware, then compare the existing `PerformanceAudit` script totals alongside the new frame
percentiles. This lane does not claim an in-game FPS delta without that paired runtime run.
