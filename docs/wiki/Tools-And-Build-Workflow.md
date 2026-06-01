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

Repo instruction: after mission edits, run from `Tools/LoadoutManager` with `dotnet run`. If .NET SDK is missing, stop and tell the user. In the current code path, generation/copy work runs before packaging, but `dotnet run` always reaches `ZipManager.DoZipOperations()`. If `7za` is missing, the run can still have produced useful copied/generated files before the final packaging failure.

Local workspace warning: `FileManager.FindA2WaspWarfareDirectory` searches ancestors for a folder literally named `a2waspwarfare` and throws if it cannot find one. This Codex checkout is under `work\a`, so `dotnet run` is not runnable here without using a correctly named checkout/worktree or changing that lookup.

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

A recursive diff at the current commit confirms Takistan differs from Chernarus **only** in exactly these files — propagation is consistent and there is no accidental drift, but the skip-list is a standing silent-divergence trap. If you edit a skip-listed gameplay file (most importantly `mission.sqm` and `WASP/unsort/StartVeh.sqf`), edit **both** missions. See [Deep-review findings](Deep-Review-Findings) DR-4.

**Modded missions are not maintained by `dotnet run`.** The modded-terrain propagation call is commented out at `SqfFileGenerators/SqfFileGenerator.cs:132`, so `Modded_Missions/*` are far behind Chernarus (Napf/eden/lingor are ~280-350 files behind; smd_sahrani_a2/tavi/dingor/isladuala are 1-4-file stubs). Treat them as non-authoritative until that path is re-enabled and regenerated.

## Tooling Project Inventory

| Project | Runtime | Entry point | Inputs | Outputs / side effects | Notes |
| --- | --- | --- | --- | --- | --- |
| `Tools/LoadoutManager` | .NET 8 executable | `Program.cs` -> `SqfFileGenerator.GenerateCommonBalanceInitAndTheEasaFileForEachTerrain()` | Terrain/loadout data classes, source Chernarus mission, terrain skip lists. | Generated `EASA_Init.sqf`, `Common_BalanceInit.sqf`, aircraft-name helper, per-terrain `version.sqf`, copied Takistan mission and `_MISSIONS.7z`. | Requires ancestor folder named `a2waspwarfare`; always attempts packaging. |
| `Tools/PerformanceAuditAnalyzer` | PowerShell | `Analyze-PerformanceAudit.ps1`, GUI launcher | Arma RPT lines containing `[Performance Audit]`. | CSV, Markdown, HTML and Word-friendly performance reports. | Safe read-only analyzer for logs. |
| `DiscordBot` | .NET 9 executable | `DiscordBot/src/ProgramRuntime.cs` | `preferences.json`, `token.txt`, extension `database.json`. | Discord channel name, bot presence and status embed updates every 60 seconds. | Missing token/preferences are expected in repo; do not invent secrets. |
| `Extension` | .NET Framework 4.8 Arma extension | `_RVExtension@12` export | Arma `callExtension` arguments from mission scripts. | Writes `C:\a2waspwarfare\Data\database.json` for DiscordBot. | Uses legacy NuGet/MSBuild package layout. |
| `Mods/mkswf_sidewinder_reload_time_fix` | Arma addon config | `CfgWeapons.hpp` | Sidewinder launcher class config. | Sets `magazineReloadTime = 1` for Sidewinder launchers. | External addon fragment, not mission SQF. |

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
- `ZipManager` packages mission directories after copy/generation and currently zips only `Missions` plus `Missions_Vanilla`, not `Modded_Missions`.
- Missing `7za` causes the final packaging step to throw; inspect generated/copied files before assuming the whole run did nothing.
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

## Continue Reading

Previous: [Client UI systems atlas](Client-UI-Systems-Atlas) | Next: [External integrations](External-Integrations)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
