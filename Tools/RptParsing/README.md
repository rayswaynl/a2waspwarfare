# RPT Parsing Helpers

Shared PowerShell helpers for offline RPT analyzers.

The module provides common plumbing used by `Tools/PerformanceAuditAnalyzer` and `Tools/RptTownDefenseAnalyzer`:

- CSV delimiter mapping for `Semicolon`, `Comma`, and `Tab`.
- `.rpt`, `.log`, and `.txt` input resolution for files, folders, and wildcard paths.
- basic server/HC role inference from file names.
- HTML text escaping for report builders.
- row counting, plain CSV export and CSV export with the existing Town Defense `no_rows` sentinel.

Run the self-test from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\RptParsing\RptParsing.Tests.ps1
```
