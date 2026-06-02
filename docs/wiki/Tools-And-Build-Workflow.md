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

## Propagation rules & the skip-list trap (verified)

"Edit Chernarus, then run `dotnet run`" is correct for **most** files but **silently incomplete** for a fixed skip-list. `LoadoutManager` copies Chernarus → Takistan via `FileManagement/FileManager.cs`, which **never overwrites** certain files and **never copies** certain directories. A change made in Chernarus to any of these does **not** reach Takistan and must be hand-mirrored in both missions:

| Not propagated (Chernarus → Takistan) | Mechanism | Why |
| --- | --- | --- |
| `mission.sqm` | `ShouldSkipFile` | Map-specific editor data. |
| `version.sqf` | `ShouldSkipFile` + git-ignored | Generated per-terrain. |
| `Client/GUI/GUI_Menu_Help.sqf` | skip + post-copy name patch | Mission name differs per terrain. |
| `WASP/unsort/StartVeh.sqf` | `ShouldSkipFile` | Per-map starting vehicles. |
| `texHeaders.bin`, `loadScreen.jpg` | `ShouldSkipFile` | Binary/terrain assets. |
| `Common/Config/Core_Artillery/*` | directory blacklist (`co.takistan`) | Takistan keeps its own artillery configs. |
| `Server/Config/*` | directory blacklist | Map-specific server config. |
| `Textures/*` | directory blacklist | Per-terrain textures. |
| `Server/Init/Init_Server.sqf` | copied **then patched** | `SET_MAP 1 → 2` rewrite post-copy. |

A recursive diff at the current commit confirms Takistan differs from Chernarus **only** in exactly these files — i.e. propagation is consistent and there is no accidental drift, but the skip-list is a standing silent-divergence trap. If you edit a skip-listed gameplay file (most importantly `mission.sqm` and `WASP/unsort/StartVeh.sqf`), edit **both** missions. See [Deep-review findings](Deep-Review-Findings) DR-4.

`version.sqf` is a special source-completeness trap (DR-43a). `description.ext:39` and `initJIPCompatible.sqf:4` include it, but no committed `version.sqf` exists in the repo. `Tools/LoadoutManager/Data/Terrains/BaseTerrain.cs` generates it per terrain, while `FileManagement/FileManager.cs` skips copying it. A fresh raw checkout is therefore not directly loadable from the mission folder until LoadoutManager has generated `version.sqf` or a deploy step has supplied it.

DR-43b also found redundant server init compiles in `Server/Init/Init_Server.sqf`: `LogGameEnd`, `PlayerObjectsList` and `AwardScorePlayer` are actively compiled twice, while nearby AFK/FPS/MASH duplicates include commented older binds. Runtime impact is trivial, but the pattern is a maintenance trap because a future divergent duplicate bind would silently let the later line win. Code-owner cleanup: de-duplicate the active binds and keep the commented history out of hot init once the intended wiring is clear. See [Deep-review findings](Deep-Review-Findings) DR-43.

**Modded missions are not maintained by `dotnet run`.** The modded-terrain propagation call is commented out at `SqfFileGenerators/SqfFileGenerator.cs:132`, so `Modded_Missions/*` are far behind Chernarus (Napf/eden/lingor are ~280-350 files behind; smd_sahrani_a2/tavi/dingor/isladuala are 1-4-file stubs). Treat them as non-authoritative until that path is re-enabled and regenerated.

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

