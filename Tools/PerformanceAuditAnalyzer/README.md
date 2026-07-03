# Performance Audit Analyzer

Author: Marty

Parses Arma 2 Warfare RPT lines containing `[Performance Audit]` and exports Excel-friendly CSV files plus a Markdown report.

The analyzer separates appended RPT content by audit session. New logs use `SID=...`; older logs without `SID` are grouped into `LEGACY_001`, `LEGACY_002`, etc. when `NAME=session EXTRA=state:start` is detected.

Shared RPT input, delimiter, CSV export and HTML-escape helpers live in `Tools/RptParsing`.

## Easy Usage

Double-click:

```text
Start-PerformanceAuditAnalyzer.cmd
```

Then choose:

1. `RPT file` to analyze one log file.
2. `Folder` to analyze all `.rpt`, `.log` and `.txt` files in a folder.
3. The tool automatically creates an output folder next to the selected RPT file, or inside the selected input folder.

The output folder opens automatically when the analysis is complete.

## Command Line Usage

Analyze one RPT file:

```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\PerformanceAuditAnalyzer\Analyze-PerformanceAudit.ps1 -InputPath ".\logs\arma2oa.rpt" -OutputPath ".\PerformanceAuditResults"
```

Analyze a whole RPT folder:

```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\PerformanceAuditAnalyzer\Analyze-PerformanceAudit.ps1 -InputPath "C:\Users\Marty\AppData\Local\ArmA 2 OA" -OutputPath ".\PerformanceAuditResults" -Recurse
```

The default CSV separator is `;`, which is convenient for French Excel. Use `-CsvDelimiter Comma` if needed.

## Outputs

```text
performance_raw.csv
performance_pivot_ready.csv
performance_extra_fields.csv
performance_timeline.csv
performance_by_script.csv
performance_spikes.csv
performance_fps_context.csv
performance_by_player.csv
performance_by_map.csv
performance_by_session.csv
performance_report.md
performance_report.html
performance_interpretation.html
performance_report_word.doc
```

## Useful Excel Files

- `performance_pivot_ready.csv`: one normalized row per audit log line, best for pivot tables. Script-specific `EXTRA` values are expanded into `extra_*` columns.
- `performance_extra_fields.csv`: same expanded data, useful when you want to filter directly on fields such as `extra_init`, `extra_global`, `extra_trackedKind`, `extra_delegated` or `extra_scanned`.
- `performance_timeline.csv`: snapshot/session rows for FPS-over-time charts.
- `performance_by_script.csv`: script cost ranking using calls, total ms, weighted average ms and spikes.
- `performance_spikes.csv`: script rows where `MAX_MS` is above the selected threshold.
- `performance_fps_context.csv`: FPS grouped by AI range, map, scope and player.
- `performance_by_session.csv`: one overview row per detected session/map/scope, useful to compare appended RPT sessions before and after mission updates.

Most CSV files include `session_index`, `session_key`, `session_start`, `session_start_source` and `sid` columns so multiple games appended into the same RPT can be filtered separately in Excel. If the RPT contains a full real date/time prefix, the analyzer uses it. New audit logs also write a dedicated session anchor row with SID, tick and frame. Because Arma 2 OA SQF has no real OS wall-clock command like Arma 3 `systemTime`, the mission-side anchor intentionally does not export mission date/time, which would be misleading when every match starts with the same configured mission date.

## Readable Reports

- `performance_report.html`: colored visual report, best opened in a browser.
- The HTML report starts with `Session Overview`, then adds `Session X - Detailed Script Cost` and `Session X - Detailed Spikes` sections for each detected game session.
- The HTML report includes `FPS By AI Load`, which shows FPS grouped by AI count ranges so version-to-version scaling can be checked without opening CSV files.
- The HTML report includes dedicated sections for unit/global init probes, marker/AAR probes, town AI delegation, client scaling probes, and server maintenance probes.
- `performance_interpretation.html`: a readable guide explaining what each metric means and how to prioritize optimization candidates.
- `performance_report_word.doc`: the same visual report saved with a Word-friendly extension.
- `performance_report.md`: plain Markdown report, useful for quick text sharing.
