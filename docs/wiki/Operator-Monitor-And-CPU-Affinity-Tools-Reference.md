# Operator Monitor And CPU Affinity Tools Reference
> Verified 2026-06-21 against `master` `0139a346` (Arma 2 OA 1.64); paths are repo-root relative for `Tools/` and `docs/testing/` sources.

This page covers two small operator-side scripts: `Tools/Monitor/Get-WindowedRpt.ps1`, a reusable current-window RPT reader, and `Tools/Ops/Set-WaspCpuAffinity.ps1`, a dry-run-first CPU-affinity helper for the dedicated server and headless clients (`Tools/Monitor/Get-WindowedRpt.ps1:1-15`; `Tools/Ops/Set-WaspCpuAffinity.ps1:1-17`).

## Tool Inventory

| Tool | Entry point | Primary use | Source evidence |
| --- | --- | --- | --- |
| `Tools/Monitor/Get-WindowedRpt.ps1` | PowerShell function `Get-WindowedRpt` | Read only the RPT lines since the most recent mission or boot marker, then optionally regex-filter and tail the result. | `Tools/Monitor/Get-WindowedRpt.ps1:1-7`, `Tools/Monitor/Get-WindowedRpt.ps1:15-24`, `Tools/Monitor/Get-WindowedRpt.ps1:47-58` |
| `Tools/Ops/Set-WaspCpuAffinity.ps1` | Script parameters `-ServerMask`, `-HcMasks`, `-Apply` | Report or set processor-affinity masks for `arma2oaserver.exe` and headless-client `ArmA2OA.exe` processes. | `Tools/Ops/Set-WaspCpuAffinity.ps1:13-17`, `Tools/Ops/Set-WaspCpuAffinity.ps1:39-44`, `Tools/Ops/Set-WaspCpuAffinity.ps1:71-87` |
| `docs/testing/hc-scaling-test.md` | Test methodology document | Explains why the affinity helper exists in the 0/1/2-HC scaling test, and records that the script is prepped but not applied. | `docs/testing/hc-scaling-test.md:1-8`, `docs/testing/hc-scaling-test.md:55-75`, `docs/testing/hc-scaling-test.md:77-81` |

## Windowed RPT Reader

`Get-WindowedRpt` exists because the script comments treat A2 OA RPT files as append-only during a server lifetime; whole-file greps become slower and can match stale errors from earlier missions (`Tools/Monitor/Get-WindowedRpt.ps1:1-7`). Its intended usage is dot-sourcing the script and calling `Get-WindowedRpt` for a current mission window, an error regex, or a custom boot marker such as `Dedicated host created` (`Tools/Monitor/Get-WindowedRpt.ps1:9-13`).

| Behavior | Details | Source evidence |
| --- | --- | --- |
| Required input | `-RptPath` is mandatory. | `Tools/Monitor/Get-WindowedRpt.ps1:17-18` |
| Default window | `-WindowMarker` defaults to `MISSINIT`, described as the mission init marker stamped at every mission start. | `Tools/Monitor/Get-WindowedRpt.ps1:19-20` |
| Optional filtering | `-Pattern` is an optional regex applied to lines inside the selected window. | `Tools/Monitor/Get-WindowedRpt.ps1:21-22`, `Tools/Monitor/Get-WindowedRpt.ps1:54` |
| Optional tailing | `-Tail` returns at most the requested number of lines from the window end; `0` means all lines. | `Tools/Monitor/Get-WindowedRpt.ps1:23-24`, `Tools/Monitor/Get-WindowedRpt.ps1:55-57` |
| Missing file behavior | If the RPT path is absent, the function warns and returns an empty array. | `Tools/Monitor/Get-WindowedRpt.ps1:27-30` |
| Non-locking read | The script opens the RPT with `FileAccess.Read` and `FileShare.ReadWrite`, then reads it through a `StreamReader`. | `Tools/Monitor/Get-WindowedRpt.ps1:32-43` |
| Window selection | The function scans backward for the last marker match and returns lines from that marker to EOF; if no later marker is found, it returns the full file. | `Tools/Monitor/Get-WindowedRpt.ps1:45-52` |
| Return value | The function returns the selected window after optional regex and tail steps. | `Tools/Monitor/Get-WindowedRpt.ps1:54-58` |

## CPU Affinity Helper

`Set-WaspCpuAffinity.ps1` is prepared for the 0/1/2-HC scaling test, where the test plan compares zero, one, and two headless clients across day-long runs while keeping other lobby parameters constant (`docs/testing/hc-scaling-test.md:1-8`, `docs/testing/hc-scaling-test.md:32-44`). The CPU-affinity section says the main server has 6 P-cores plus E-cores, and the mitigation is to pin the server and headless clients to dedicated P-core sets so the Arma processes do not fight over shared cache (`docs/testing/hc-scaling-test.md:55-60`).

| Behavior | Details | Source evidence |
| --- | --- | --- |
| Dry-run default | The synopsis says the script prints what it would do unless `-Apply` is passed. | `Tools/Ops/Set-WaspCpuAffinity.ps1:17-18`, `Tools/Ops/Set-WaspCpuAffinity.ps1:32-37` |
| Parameters | `-ServerMask` defaults to `0`, `-HcMasks` defaults to an empty array, and `-Apply` controls whether masks are set. | `Tools/Ops/Set-WaspCpuAffinity.ps1:39-44` |
| Server target | The server process target is `arma2oaserver.exe`; if no server mask is provided, a found server is left untouched. | `Tools/Ops/Set-WaspCpuAffinity.ps1:13-15`, `Tools/Ops/Set-WaspCpuAffinity.ps1:71-76` |
| Headless-client target | Headless clients are `ArmA2OA.exe` processes whose command line contains `-client`, sorted by creation date. | `Tools/Ops/Set-WaspCpuAffinity.ps1:13-16`, `Tools/Ops/Set-WaspCpuAffinity.ps1:46-51` |
| HC mask order | The script applies one `-HcMasks` entry per HC in connection order; HCs beyond the supplied masks are left untouched. | `Tools/Ops/Set-WaspCpuAffinity.ps1:28-30`, `Tools/Ops/Set-WaspCpuAffinity.ps1:78-87` |
| Actual write | When `-Apply` is present, `Set-Affinity` writes `ProcessorAffinity` on the process and prints the old and new mask. | `Tools/Ops/Set-WaspCpuAffinity.ps1:53-64` |
| Error handling | Affinity write failures are caught and emitted as PowerShell warnings. | `Tools/Ops/Set-WaspCpuAffinity.ps1:64-66` |
| Mask semantics | Masks are hardware-specific bitmasks over logical processors; bit 0 is CPU0, and the script comment gives a 6-P-core hyperthreading example. | `Tools/Ops/Set-WaspCpuAffinity.ps1:19-23` |
| Test-plan status | The test document marks the affinity script as prepped and not applied. | `docs/testing/hc-scaling-test.md:77-81` |

## Operator Boundaries

| Boundary | Practical reading | Source evidence |
| --- | --- | --- |
| RPT helper scope | `Get-WindowedRpt` reads an existing RPT and returns selected lines; it does not parse PerformanceAudit tables, launch Arma, or restart a server. | `Tools/Monitor/Get-WindowedRpt.ps1:15-24`, `Tools/Monitor/Get-WindowedRpt.ps1:32-58` |
| Affinity helper scope | `Set-WaspCpuAffinity.ps1` discovers existing Arma processes and only changes `ProcessorAffinity` when `-Apply` is present. | `Tools/Ops/Set-WaspCpuAffinity.ps1:46-66`, `Tools/Ops/Set-WaspCpuAffinity.ps1:71-87` |
| Live-host caution | The HC test note says masks are hardware-specific, must be confirmed on the target host, and should not be applied on the live host without a maintenance window and explicit go-ahead. | `docs/testing/hc-scaling-test.md:72-75` |
| Measurement boundary | The HC-scaling plan measures client FPS, server FPS, HC FPS/load, and group-count signals; the affinity helper is one mitigation item inside that test, not the test result. | `docs/testing/hc-scaling-test.md:10-18`, `docs/testing/hc-scaling-test.md:55-63` |

## Quick Commands

| Task | Command shape | Source evidence |
| --- | --- | --- |
| Load the RPT helper | `. C:\WASP\monitor\Get-WindowedRpt.ps1` | `Tools/Monitor/Get-WindowedRpt.ps1:9-10` |
| Read the current mission window | `$lines = Get-WindowedRpt -RptPath $rpt` | `Tools/Monitor/Get-WindowedRpt.ps1:11` |
| Read matching error lines | `$errs = Get-WindowedRpt -RptPath $rpt -Pattern 'Error\|ERROR'` | `Tools/Monitor/Get-WindowedRpt.ps1:12` |
| Read a per-boot window | `$boot = Get-WindowedRpt -RptPath $rpt -WindowMarker 'Dedicated host created'` | `Tools/Monitor/Get-WindowedRpt.ps1:13` |
| Dry-run CPU affinity | `.\Set-WaspCpuAffinity.ps1 -ServerMask 0x0FF -HcMasks 0x300,0xC00` | `Tools/Ops/Set-WaspCpuAffinity.ps1:35-37`, `docs/testing/hc-scaling-test.md:65-69` |
| Apply CPU affinity | `.\Set-WaspCpuAffinity.ps1 -ServerMask 0x0FF -HcMasks 0x300,0xC00 -Apply` | `Tools/Ops/Set-WaspCpuAffinity.ps1:35-37`, `docs/testing/hc-scaling-test.md:65-69` |

## Continue Reading

- [Tools and build workflow](Tools-And-Build-Workflow)
- [Server ops runbook](Server-Ops-Runbook)
- [PerformanceAuditAnalyzer](PerformanceAuditAnalyzer)
- [Headless client scaling and topology](Headless-Client-Scaling-And-Topology)
- [Testing, debugging and release workflow](Testing-Debugging-And-Release-Workflow)
