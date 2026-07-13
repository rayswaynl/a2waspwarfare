# Collector overhead measurement

## Representative local result

Measured 2026-07-13 with Windows PowerShell 5.1 on a 16-logical-processor
Windows host. Three benign, test-owned sleeping PowerShell processes represented
the `server`, `hc-01`, and `client-01` roles. This is a collector-cost smoke test,
not an Arma workload result.

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File Tools\PerfCapture\Collect-ProcessMetrics.Tests.ps1 `
  -CaptureSamples 30 -CaptureIntervalSeconds 1 -KeepArtifacts
```

Measured `collector-overhead.json`:

| Metric | Result |
| --- | ---: |
| Targets | 3 |
| One-second intervals requested | 30 |
| Process rows written | 90 |
| Wall time | 32.711627 s |
| Collector CPU time | 3.359375 s |
| Average collector CPU, one-core scale | 10.269666% (about 0.103 core) |
| Average collector CPU, total-machine scale | 0.641854% |
| Peak collector working set | 189,734,912 bytes |
| One-time module hash time | 3,188.111 ms |
| Query duration p50 | 500.934 ms |
| Query duration p95 | 612.024 ms |
| Query duration max | 665.891 ms |
| Deadline misses | 0 |
| CSV + identity bytes before overhead JSON | 198,968 bytes |
| Bytes per process row | 2,210.756 bytes |
| Manifest changed during capture | false |

The task defines no universal pass threshold, so this report does not invent
one. Compare `collector-overhead.json` with the minimum effect of each experiment
and invalidate the run if instrumentation cost is comparable to the claimed
gain.

## Design investigation

An earlier implementation queried
`Win32_PerfFormattedData_PerfProc_Thread` for context-switch rates. Both raw and
formatted thread classes exceeded a bounded 15-second query even with a single
PID filter, which is incompatible with a one-second sidecar. The production
collector therefore derives CPU/fault/I/O rates from cumulative
`Win32_Process` values and emits context switches as explicitly unavailable.

The first multi-role implementation also queried `Win32_Process` once per PID.
The three-role test demonstrated that this could exceed the interval. It now
uses one WQL query restricted to exactly the declared PIDs; the repeated
three-role measurement above had zero deadline misses.

## Interpretation limits

- Module hashing is a one-time identity cost included in total wall/CPU but not
  in per-sample query percentiles.
- Sleeping PowerShell processes do not reproduce Arma module count, working set,
  I/O, or contention. Repeat the overhead measurement beside every named Arma
  regime.
- Results are local evidence for this tool revision, not a performance claim
  about the game or another machine.
