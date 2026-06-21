# PerformanceAuditAnalyzer

`Tools/PerformanceAuditAnalyzer` is the offline parser for Arma 2 OA RPT/log files that contain `[Performance Audit]` records. It is a read-only analysis tool, not a live server tailer or shipped mission runtime component.

Mission-side rows are produced by the local `PerformanceAudit_*` writer family, which is indexed in [Function and module index](Function-And-Module-Index#common-function-families). Server and clients write their own RPT rows; the analyzer only parses logs collected after the mission-side parameter/instrumentation was active.

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

The analyzer currently emits 14 named machine-readable and human-readable reports: raw/pivot/extra-fields/timeline/script/spike/FPS/player/map/session CSVs, Markdown, HTML, interpretation HTML and a Word-friendly `performance_report_word.doc` copy of the HTML report (`Analyze-PerformanceAudit.ps1:1361-1395`).

Session grouping is explicit. Logs with `SID=...` fields are grouped by that SID, while older records are assigned legacy session keys; the exported session CSV includes `session_index`, `session_key`, `session_start`, `session_start_source` and `sid` (`Analyze-PerformanceAudit.ps1:308-312`, `:1281-1295`).

Use the outputs after changes to town loops, AI delegation, supply scanning, server FPS logic, UI polling loops or any other performance-sensitive system.

## Caveats

- The GUI launcher is desktop-only because it loads `System.Windows.Forms`; call `Analyze-PerformanceAudit.ps1` directly for automation or server-log work.
- The script creates the output directory before proving that useful input exists, so no-input runs can leave folders behind.
- The input pass uses `Get-Content | ForEach-Object`; very large RPTs should be treated as latency/memory-sensitive until streaming behavior is improved and measured.
- The analyzer only sees logs that already contain `[Performance Audit]` records. Missing instrumentation in mission code means missing report rows, not proof that a path is cheap.
- The `.doc` output is produced by copying the HTML report to `performance_report_word.doc` (`Analyze-PerformanceAudit.ps1:1395`). Treat it as Word-friendly HTML, not a native Word document generator.

## Continue Reading

Previous: [Tools/build](Tools-And-Build-Workflow) | Next: [Performance opportunity sweep](Performance-Opportunity-Sweep)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
