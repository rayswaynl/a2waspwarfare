# Tools And Build Workflow

## LoadoutManager

`Tools/LoadoutManager` is a .NET 8 executable. `Program.cs` calls `SqfFileGenerator.GenerateCommonBalanceInitAndTheEasaFileForEachTerrain()`.

Responsibilities:

- generate common balance/EASA SQF files for terrains;
- copy source mission files from Chernarus to vanilla/modded target missions;
- adjust terrain-specific map parameters such as Takistan `SET_MAP`;
- optionally package missions with 7-Zip.

Build configurations:

- `DEBUG`
- `SERVER_DEBUG`
- `RELEASE`
- `AIRWAR_DEBUG`
- `AIRWAR_SERVER_DEBUG`
- `AIRWAR_RELEASE`

Repo instruction: after mission edits, run from `Tools/LoadoutManager` with `dotnet run`. If .NET SDK is missing, stop and tell the user. If `7za` is missing, copying can still be useful; packaging is the only blocked part.

## PerformanceAuditAnalyzer

`Tools/PerformanceAuditAnalyzer` parses Arma 2 RPT lines containing `[Performance Audit]` and exports CSV/Markdown/HTML/Word-friendly reports.

Important outputs include:

- `performance_raw.csv`
- `performance_pivot_ready.csv`
- `performance_extra_fields.csv`
- `performance_timeline.csv`
- `performance_by_script.csv`
- `performance_spikes.csv`
- `performance_fps_context.csv`
- `performance_by_player.csv`
- `performance_by_map.csv`
- `performance_by_session.csv`
- `performance_report.md`
- `performance_report.html`

Use it after performance-sensitive mission changes or live-server audits.

## Packaging And Deployment Notes

- `7za` environment variable points to `7za.exe`.
- `ZipManager` packages mission directories after copy/generation.
- The source Chernarus mission is copied to target terrain folders. Avoid manual changes in generated targets unless the generator is being updated.

## Development Commands

```powershell
cd Tools\LoadoutManager
dotnet run
dotnet run -c SERVER_DEBUG
```

```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\PerformanceAuditAnalyzer\Analyze-PerformanceAudit.ps1 -InputPath ".\logs\arma2oa.rpt" -OutputPath ".\PerformanceAuditResults"
```

