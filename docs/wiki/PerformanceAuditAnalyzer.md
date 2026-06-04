# PerformanceAuditAnalyzer

`Tools/PerformanceAuditAnalyzer` is the offline parser for Arma 2 OA RPT/log files that contain `[Performance Audit]` records. It is a read-only analysis tool, not a live server tailer or shipped mission runtime component.

## Entry Points

| Entry point | Use |
| --- | --- |
| `Tools/PerformanceAuditAnalyzer/Start-PerformanceAuditAnalyzer.cmd` | Friendly launcher for the desktop picker. |
| `Tools/PerformanceAuditAnalyzer/Start-PerformanceAuditAnalyzer.ps1` | PowerShell GUI picker; loads Windows Forms, so use it only on an interactive desktop. |
| `Tools/PerformanceAuditAnalyzer/Analyze-PerformanceAudit.ps1` | Direct script for headless or repeatable analysis of one log file or folder. |

Example:

```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\PerformanceAuditAnalyzer\Analyze-PerformanceAudit.ps1 -InputPath ".\logs\arma2oa.rpt" -OutputPath ".\PerformanceAuditResults"
```

## Outputs

The analyzer currently emits 14 named machine-readable and human-readable reports: raw/pivot/extra-fields/timeline/script/spike/FPS/player/map/session CSVs, Markdown, HTML, interpretation HTML and a Word-friendly `.doc` report (`Analyze-PerformanceAudit.ps1:1361-1393`).

Use the outputs after changes to town loops, AI delegation, supply scanning, server FPS logic, UI polling loops or any other performance-sensitive system.

## Caveats

- The GUI launcher is desktop-only because it loads `System.Windows.Forms`; call `Analyze-PerformanceAudit.ps1` directly for automation or server-log work.
- The script creates the output directory before proving that useful input exists, so no-input runs can leave folders behind.
- The input pass uses `Get-Content | ForEach-Object`; very large RPTs should be treated as latency/memory-sensitive until streaming behavior is improved and measured.
- The analyzer only sees logs that already contain `[Performance Audit]` records. Missing instrumentation in mission code means missing report rows, not proof that a path is cheap.

## Continue Reading

Previous: [Tools/build](Tools-And-Build-Workflow) | Next: [Performance opportunity sweep](Performance-Opportunity-Sweep)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
