# HC-scaling performance test (0 / 1 / 2 HC) + client-FPS focus

Plan agreed in the OCD deploy thread (Miksuu / Zwanon / Net_2 / Marty), 2026-06-15:
**run a day each of 0 HC, 1 HC, and 2 HC on the *main* server** to measure the real
performance impact, and **focus FPS optimisation on the client side first** (Marty:
"HC is not the issue with FPS, clients are; the server is stable over time").

This doc is the methodology so the test produces clean, comparable data.

## 1. What we measure

| Signal | Source | Notes |
|---|---|---|
| **Client FPS** | `FPSREPORT\|v1\|` (NEW, this branch) | per-player avg+min FPS, tagged with `hc=`, `dnMode=`, `daytime=`, `players=`. The headline metric. |
| Server FPS | `srvFps=` / `SRVPERF\|`, `serverFpsGUI` | already emitted; for context (Marty: stays stable). |
| HC FPS / load | `HCSTAT\|v1\|<name>\|fps=..\|units=..` | per-HC self-report; shows HC offload. |
| Group counts / leak | `GCSTAT\|v1\|`, `group audit [SIDE] N/144` | the Force & Group Health dashboard block. |

### Client FPS telemetry (`FPSREPORT`)
Enabled per-mission from the **admin lobby**: set **`Client FPS telemetry = Enabled`**
(`WFBE_C_CLIENT_FPS_REPORT`, default Off; interval `WFBE_C_CLIENT_FPS_REPORT_INTERVAL`, default 60s).
Each player client samples `diag_fps` (avg of 5×1s + worst) and publishes it; the server logs:

```
FPSREPORT|v1|uid=..|fps=<avg>|fpsMin=<worst>|players=<n>|hc=<0|1|2>|dnMode=<0|1>|daytime=<0-24>|sun=<0-1>|srvFps=<n>|t=<min>|name=<player>
```

`hc=` is the live headless-client count at report time, so the 0/1/2-HC days bucket cleanly
even if one RPT spans multiple launches. `dnMode` = the `WFBE_DAYNIGHT_ENABLED` cycle param;
`daytime`/`sun` let you also split day vs night within a run.

## 2. Test protocol

1. Build the mission with `dotnet run -c SERVER_DEBUG` (activates `logcontent` so the full RPT is captured).
2. Hold **every other lobby param constant** across the three days (towns, AI caps, delegation, day/night,
   view distance). The ONLY variable is the HC count.
   - **Day A — 0 HC**: launch the server only (no MiksuuHC / MiksuuHC2). Delegation falls back to client/server.
   - **Day B — 1 HC**: server + one HC. Marty's recommended starting point.
   - **Day C — 2 HC**: server + two HCs (current config).
   - (optional **3 HC** later — only on the main server; the test box's low core count can't host it.)
3. Enable `Client FPS telemetry` in the lobby each day. Keep `WFBE_C_AI_DELEGATION` as-is per day
   (it auto-forces to 2 when HCs are present, 0 when none — that's expected and part of what we're measuring).
4. Let each day run a representative window (peak hours + an AI-only stretch). Archive the RPT per day.

## 3. Analysis

- Bucket `FPSREPORT` lines by `hc=` (and optionally `dnMode`/`daytime`), compare **avg & min client FPS**.
  A simple `Select-String 'FPSREPORT' | group hc=` over each day's RPT gives the comparison; the
  `PerformanceAuditAnalyzer` (`Tools/PerformanceAuditAnalyzer`) can fold it into its FPS-by-load report.
- The live dashboard (`78.46.107.142:8080`) is being extended with an **FPS-by-HC** view so the
  comparison is readable at a glance once data flows (see `Update-PublicStats.ps1` / `index.html` on the box).
- Expected (Marty's hypothesis): client FPS is ~flat across HC counts → HC is not the client-FPS lever;
  the work then moves to client-side optimisation (view distance, marker/UI loops, particle/JSRS load, etc.).

## 4. CPU affinity (Net_2's concern)

The main server is **6 P-cores + E-cores** (E-cores unsuitable for sim threads). Net_2's worry: adding HCs
multiplies context switches and makes the server + HCs fight over shared CPU cache. Mitigation = pin each
Arma process to dedicated P-cores via processor affinity, ideally **disjoint** sets so they don't thrash
the same cache.

`Tools/Ops/Set-WaspCpuAffinity.ps1` applies this (defaults to a dry run). Example for 6 P-cores
(logical 0-11 with HT) giving the server cores 0-3 and one HC core each:

```powershell
# DRY RUN first (prints what it WOULD do):
.\Set-WaspCpuAffinity.ps1 -ServerMask 0x0FF -HcMasks 0x300,0xC00
# Apply:
.\Set-WaspCpuAffinity.ps1 -ServerMask 0x0FF -HcMasks 0x300,0xC00 -Apply
```

> Masks are hardware-specific — confirm which logical processors are P-cores on the main server first
> (`Get-CimInstance Win32_Processor` + Task Manager → Performance → CPU, or `coreinfo`). DO NOT apply
> on the live host without a maintenance window and a tested mask. Per [[hetzner-deploy-consent-policy]],
> the affinity change is prepped here but applied only on explicit go-ahead.

## 5. Status / ownership
- `FPSREPORT` telemetry + `hc=` tag: **DONE** on `deploy/2026-06-12-aicom-experital`.
- Dashboard FPS-by-HC view: in progress (box-side).
- Affinity script: prepped (`Tools/Ops/Set-WaspCpuAffinity.ps1`), NOT applied.
- Main-server config parity (rcon, network optimisation) pending the payment-provider fix (Miksuu).
