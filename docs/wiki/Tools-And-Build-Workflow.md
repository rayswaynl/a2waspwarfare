# Tools And Build Workflow

Page ownership: this page owns the operational LoadoutManager rules, skip-list and generated-mission status table. [Source fix propagation queue](Source-Fix-Propagation-Queue) owns the current source/Vanilla propagation and smoke-gate ledger. Full drift evidence and file-count analysis live in [Deep-review findings](Deep-Review-Findings) DR-4 and DR-32; keep only the actionable build/propagation rules here.

## LoadoutManager

`Tools/LoadoutManager` is a .NET 8 executable. `Program.cs` calls `SqfFileGenerator.GenerateCommonBalanceInitAndTheEasaFileForEachTerrain()`.

Responsibilities:

- generate common balance/EASA SQF files for terrains;
- copy source mission files from Chernarus to vanilla/modded target missions;
- adjust terrain-specific map parameters such as Takistan `SET_MAP`;
- optionally package missions with 7-Zip.

The generated aircraft loadout and balance pipeline is mapped in [Gear, loadout and EASA atlas](Gear-Loadout-And-EASA-Atlas). In short: change aircraft loadouts in `Tools/LoadoutManager/Data/Vehicles/Aircrafts/**`, then inspect generated `Client/Module/EASA/EASA_Init.sqf` and `Common/Functions/Common_BalanceInit.sqf`.

Build configurations:

- `DEBUG`
- `SERVER_DEBUG`
- `RELEASE`
- `AIRWAR_DEBUG`
- `AIRWAR_SERVER_DEBUG`
- `AIRWAR_RELEASE`

Repo instruction: after mission edits, run from `Tools/LoadoutManager` with `dotnet run`, or from the repo root with `dotnet run --project Tools\LoadoutManager\LoadoutManager.csproj`. If .NET SDK is missing, stop and tell the user. For propagation-only runs, set `A2WASP_SKIP_ZIP=1` so generation/copy completes without requiring `7za` or creating `_MISSIONS.7z`.

Local workspace note: `FileManager.FindA2WaspWarfareDirectory` now supports both an ancestor folder literally named `a2waspwarfare` and a normal repo root containing `Missions`, `Missions_Vanilla` and `Tools/LoadoutManager/LoadoutManager.csproj`. This lets Codex checkouts such as `work\a` run the tool without renaming the workspace.

## Operator Checklist

Before running tooling or deployment-adjacent pieces, check these first:

| Item | Why it matters |
| --- | --- |
| Checkout path resolves to the repo root. | LoadoutManager accepts either an ancestor named `a2waspwarfare` or root markers: `Missions`, `Missions_Vanilla` and `Tools/LoadoutManager/LoadoutManager.csproj`. |
| `A2WASP_SKIP_ZIP=1` is set for propagation-only runs. | Skips `_MISSIONS.7z` packaging and avoids a packaging-only `7za` dependency during docs/code propagation work. |
| `7za` is configured and available if packaging is required. | Required only when producing `_MISSIONS.7z` release archives. |
| `version.sqf` exists for the mission being packed/tested. | It is generated and git-ignored, but included by `description.ext` and `initJIPCompatible.sqf`. |
| DiscordBot has real `preferences.json` and `token.txt` outside git. | Missing token/config is expected in repo and is not a mission-code failure. |
| AntiStack has the separate `A2WaspDatabase` DLL if enabled. | The in-repo `Extension` project is `a2waspwarfare_Extension` / `GLOBALGAMESTATS`, not the AntiStack database extension. |

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

A recursive diff in [Deep-review findings](Deep-Review-Findings) DR-4 confirmed vanilla Takistan has no accidental drift outside this skip-list/blacklist and the `SET_MAP` rewrite. If you edit a skip-listed gameplay file, especially `mission.sqm` or `WASP/unsort/StartVeh.sqf`, hand-mirror it instead of assuming `dotnet run` will propagate it.

**Modded missions are not maintained by the current `dotnet run` path.** The modded-terrain propagation call is commented out at `SqfFileGenerators/SqfFileGenerator.cs:132`, and `ZipManager.cs:10` packages only `Missions` plus `Missions_Vanilla`. Treat `Modded_Missions/*` as non-authoritative until the owner chooses regenerate-from-source or maintained-fork policy; see DR-32 for the full tier analysis.

## Generated Mission Status Table

This is the operational summary of DR-32's three maintenance tiers. Use it before assuming a fix in Chernarus reaches every mission folder.

| Target | Current status | Development consequence |
| --- | --- | --- |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus` | Source of truth. | Apply gameplay and documentation evidence here first. |
| `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan` | Faithful generated/copy target. Current drift is map-config and terrain assets only; logic files are byte-identical to Chernarus outside the documented skip-list and `SET_MAP` patch. | Source fixes should propagate through LoadoutManager, except skip-listed files that need hand-mirroring. All DR findings in Chernarus apply to vanilla Takistan unless the changed file is map-specific. |
| `Modded_Missions/napf`, `Modded_Missions/eden`, `Modded_Missions/lingor` | Divergent hand-edited forks with 100+ logic-file differences, including security-sensitive runtime/PVF/victory/upgrade/HQ paths. | Source fixes do not automatically reach these missions. Pick a maintenance model before shipping them: regenerate from hardened source or maintain as explicit forks with separate audits. |
| `Modded_Missions/sahrani`, `Modded_Missions/dingor`, `Modded_Missions/tavi`, `Modded_Missions/isladuala` | Abandoned/non-runnable stubs with only a small fraction of the real mission tree. | Complete or delete before presenting them as supported missions. |

## Tooling Project Inventory

| Project | Runtime | Entry point | Inputs | Outputs / side effects | Notes |
| --- | --- | --- | --- | --- | --- |
| `Tools/LoadoutManager` | .NET 8 executable | `Program.cs` -> `SqfFileGenerator.GenerateCommonBalanceInitAndTheEasaFileForEachTerrain()` | Terrain/loadout data classes, source Chernarus mission, terrain skip lists. | Generated `EASA_Init.sqf`, `Common_BalanceInit.sqf`, aircraft-name helper, per-terrain `version.sqf`, copied Takistan mission and optional `_MISSIONS.7z`. | Accepts named-root or repo-marker root discovery; set `A2WASP_SKIP_ZIP=1` to skip packaging. |
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
- Missing `7za` causes the final packaging step to throw unless `A2WASP_SKIP_ZIP=1` is set; inspect generated/copied files before assuming the whole run did nothing.
- The source Chernarus mission is copied to target terrain folders. Avoid manual changes in generated targets unless the generator is being updated.
- `The specified content was not found in the file.` during the current run comes from the terrain help-menu title replacement path and did not stop Chernarus/Takistan generation/copy.

## Development Commands

```powershell
cd Tools\LoadoutManager
dotnet run
dotnet run -c SERVER_DEBUG
```

```powershell
$env:A2WASP_SKIP_ZIP = "1"
dotnet run --project Tools\LoadoutManager\LoadoutManager.csproj
```

```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\PerformanceAuditAnalyzer\Analyze-PerformanceAudit.ps1 -InputPath ".\logs\arma2oa.rpt" -OutputPath ".\PerformanceAuditResults"
```

## Continue Reading

Previous: [Client UI systems atlas](Client-UI-Systems-Atlas) | Next: [External integrations](External-Integrations)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
