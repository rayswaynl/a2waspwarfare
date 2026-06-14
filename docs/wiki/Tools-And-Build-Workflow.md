# Tools And Build Workflow

For the release-readiness and integration risk audit that sits on top of this workflow, see [Tooling release readiness audit](Tooling-Release-Readiness-Audit).

Page ownership: this page owns the operational LoadoutManager rules, skip-list and generated-mission status table. [Source fix propagation queue](Source-Fix-Propagation-Queue) owns the current source/Vanilla propagation and smoke-gate ledger. Full drift evidence and file-count analysis live in [Deep-review findings](Deep-Review-Findings) DR-4 and DR-32; keep only the actionable build/propagation rules here.

## LoadoutManager

`Tools/LoadoutManager` is a .NET 8 executable. `Program.cs` calls `SqfFileGenerator.GenerateCommonBalanceInitAndTheEasaFileForEachTerrain()`.

Responsibilities:

- generate common balance/EASA SQF files for terrains;
- copy source mission files from Chernarus to maintained vanilla target missions;
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

Upstream history warning: the second-wave [Developer history and upstream lessons](Developer-History-And-Upstream-Lessons) pass found concrete tooling hazards: current packaging is source Chernarus plus generated Vanilla/Takistan only, `Modded_Missions` packaging/generation is commented out, `ZipManager` depends on env var `7za`, `version.sqf` load order was reverted once, Takistan DB map ID needed generator-side post-copy repair, and sound generation assumes `ClassName-volume.ogg` filenames. Treat LoadoutManager console output plus `git diff --stat` as the release check, not a blind "DONE" signal.

Local workspace note: `FileManager.FindA2WaspWarfareDirectory` now supports both an ancestor folder literally named `a2waspwarfare` and a normal repo root containing `Missions`, `Missions_Vanilla` and `Tools/LoadoutManager/LoadoutManager.csproj`. This lets Codex checkouts such as `work\a` run the tool without renaming the workspace.

## Operator Checklist

Before running tooling or deployment-adjacent pieces, check these first:

| Item | Why it matters |
| --- | --- |
| Checkout path resolves to the repo root. | LoadoutManager accepts either an ancestor named `a2waspwarfare` or root markers: `Missions`, `Missions_Vanilla` and `Tools/LoadoutManager/LoadoutManager.csproj`. |
| `A2WASP_SKIP_ZIP=1` is set for propagation-only runs. | Skips `_MISSIONS.7z` packaging and avoids a packaging-only `7za` dependency during docs/code propagation work. |
| `7za` is configured and available if packaging is required. | Required only when producing `_MISSIONS.7z` release archives. |
| Existing `_MISSIONS.7z` is disposable or backed up before packaging. | `ZipManager.cs:26-33` deletes the existing archive before proving a new archive was created, while `ZipManager.cs:77-91` prints `7za` output without an exit-code gate. Keep a rollback copy before release packing. |
| `version.sqf` exists for every claimed target root. | It is generated and git-ignored, but included by `description.ext` and `initJIPCompatible.sqf`; `Rsc/Header.hpp` consumes its `WF_RESPAWNDELAY`, `WF_MISSIONNAME` and `WF_MAXPLAYERS` defines. Missing `version.sqf` blocks pack/test/release claims for that root. |
| Generated aircraft damage insertion markers still exist. | `BaseTerrain.cs:84-86` writes `Common_ModifyAirVehicle.sqf` through marker replacement, and `FileManager.cs:224-247` only logs missing marker content. A marker drift can produce a soft generator warning instead of a clear release failure. |
| `Missions_Vanilla` is not confused with the `VANILLA` macro. | The folder name is a generated target label; the `#ifndef VANILLA` preprocessor gate in `description.ext` / `Rsc/Header.hpp` controls OA/CO config behavior inside mission headers. |
| `stringtable.xml` and `loadScreen.jpg` exist for the mission being packed/tested. | They are ordinary runtime assets for playable mission roots; modded forks may lack them even when their `description.ext` includes generated/sound/music dependencies. |
| Generated `version.sqf` has the intended release flags. | Prepared/generated files can contain debug/log-enabled values; inspect `WF_DEBUG` and `WF_LOG_CONTENT` before packaging a public release. |
| DiscordBot has real `preferences.json` and `token.txt` outside git. | Missing token/config is expected in repo and is not a mission-code failure. Current bot startup touches `preferences.json` through `GameData.LoadFromFile()` before the clean missing-token exit, so provide preferences before debugging token-only failures. |
| AntiStack has the separate `A2WaspDatabase` DLL if enabled. | The in-repo `Extension` project is `a2waspwarfare_Extension` / `GLOBALGAMESTATS`, not the AntiStack database extension. |
| Deployment inventory records actual server artifacts and config paths. | Track `a2waspwarfare_Extension`, separate `A2WaspDatabase`, `token.txt`, `preferences.json`, production `BEpath`, and any external `server.cfg`/`basic.cfg` before calling a host reproducible. |
| The in-repo `Extension` is built with legacy MSBuild tooling. | It targets .NET Framework 4.8 x86 with `RGiesecke.DllExport`/`UnmanagedExports` packages under `../packages`; do not treat it as a normal SDK-style `dotnet build` project. |
| Do not expect server/deploy wrapper scripts in the scoped release folders. | A scoped scout found no `.cmd`, `.ps1`, `.bat` or `.sh` files under `Tools/LoadoutManager`, `DiscordBot`, `Extension` or `BattlEyeFilter`; use the documented `dotnet`/MSBuild/manual deployment flow unless new scripts are added later. `Tools/PerformanceAuditAnalyzer` is the exception: it has local analyzer launchers, not server deployment wrappers. |

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

Takistan blacklist caveat: `FileManager.cs:22-37` applies the directory blacklist when the destination path contains `co.takistan`. If future generated target names change away from that substring, re-test the blacklist before trusting artillery/config/texture propagation behavior.

Sync blast radius: LoadoutManager also deletes destination files and directories that do not exist in the source copy (`FileManager.cs:116-119,123-136`). Treat generated mission trees as disposable outputs. Manual edits or extra assets placed only in `Missions_Vanilla/*` can be removed by a later propagation run unless the generator/source tree owns them.

Soft-copy failure caveat: `FileManager.cs:72-83` catches `IOException` during individual file copies, prints `Error copying file: ...`, and then continues the run. A LoadoutManager run can therefore finish with partial copy failures in console output. For release or propagation claims, inspect the console log and `git diff --stat`; do not rely only on process completion.

Generated root gate: for any release, smoke or pack claim, verify the root-specific `version.sqf` file exists and matches the target terrain before moving on. At minimum, source Chernarus should carry `WF_MAXPLAYERS 55`, `WF_MISSIONNAME "[55] Warfare V48 Chernarus"` and its intended Chernarus/naval flags; maintained Vanilla Takistan should carry `WF_MAXPLAYERS 61`, `WF_MISSIONNAME "[61] Warfare V48 Takistan"` and the intended non-Chernarus/non-naval flag shape. `git status --ignored --short -- "Missions/[55-2hc]warfarev2_073v48co.chernarus/version.sqf" "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/version.sqf"` should show ignored-present files in a prepared local checkout; a clean checkout needs LoadoutManager generation first. The machine-readable gate is `agent-release-readiness.json` `versionSqfGeneratedInput`.

**Modded missions are not maintained by the current `dotnet run` path.** The modded-terrain propagation call is commented out at `SqfFileGenerators/SqfFileGenerator.cs:132`, and `ZipManager.cs:16` packages only `Missions` plus `Missions_Vanilla`. Treat `Modded_Missions/*` as non-authoritative until the owner chooses regenerate-from-source or maintained-fork policy; see DR-32 for the full tier analysis.

## Generated Mission Status Table

This is the operational summary of DR-32's three maintenance tiers. Use it before assuming a fix in Chernarus reaches every mission folder.

| Target | Current status | Development consequence |
| --- | --- | --- |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus` | Source of truth. | Apply gameplay and documentation evidence here first. |
| `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan` | Faithful generated/copy target. Current drift is map-config and terrain assets only; logic files are byte-identical to Chernarus outside the documented skip-list and `SET_MAP` patch. | Source fixes should propagate through LoadoutManager, except skip-listed files that need hand-mirroring. All DR findings in Chernarus apply to vanilla Takistan unless the changed file is map-specific. |
| `Modded_Missions/napf`, `Modded_Missions/eden`, `Modded_Missions/lingor` | Divergent hand-edited partial forks with 100+ logic-file differences, including security-sensitive runtime/PVF/victory/upgrade/HQ paths. Wave S confirmed they are not drop-in runnable from the checkout, and the 2026-06-04 modded scout tightened this to boot-incomplete: `eden` lacks tracked `version.sqf`, `stringtable.xml`, `loadScreen.jpg`, sound and music descriptions; `Napf` lacks tracked `mission.sqm`, `version.sqf`, `stringtable.xml`, `loadScreen.jpg`, sound and music descriptions; `lingor` lacks tracked `mission.sqm`, `description.ext`, `initJIPCompatible.sqf`, `version.sqf`, `stringtable.xml`, `loadScreen.jpg`, sound/music descriptions and textures. All three still compile missing `Common/Functions/Common_GetTotalCamps.sqf` from `Common/Init/Init_Common.sqf:52-53,127-128`. A 2026-06-03 marker scan also found unresolved merge-conflict markers in 18 files across these forks. | Source fixes do not automatically reach these missions. Pick a maintenance model before shipping them: regenerate from hardened source or maintain as explicit forks with separate audits, generated/runtime inputs and conflict-marker cleanup. |
| `Modded_Missions/sahrani`, `Modded_Missions/dingor`, `Modded_Missions/tavi`, `Modded_Missions/isladuala` | Abandoned/non-runnable stubs with only a small fraction of the real mission tree; `dingor` also has a `description.ext` that includes missing `version.sqf`. | Complete or delete before presenting them as supported missions. |

## Tooling Project Inventory

| Project | Runtime | Entry point | Inputs | Outputs / side effects | Notes |
| --- | --- | --- | --- | --- | --- |
| `Tools/LoadoutManager` | .NET 8 executable | `Program.cs` -> `SqfFileGenerator.GenerateCommonBalanceInitAndTheEasaFileForEachTerrain()` | Terrain/loadout data classes, source Chernarus mission, terrain skip lists. | Generated `EASA_Init.sqf`, `Common_BalanceInit.sqf`, aircraft-name helper, per-terrain `version.sqf`, copied Takistan mission and optional `_MISSIONS.7z`. | Accepts named-root or repo-marker root discovery; set `A2WASP_SKIP_ZIP=1` to skip packaging. |
| `Tools/PerformanceAuditAnalyzer` | PowerShell | `Analyze-PerformanceAudit.ps1`, GUI launcher | Existing Arma RPT/log files containing `[Performance Audit]`. | CSV, Markdown, HTML and Word-friendly performance reports. | Safe read-only analyzer for logs; no shipped live tailer service was found in the tree. See [PerformanceAuditAnalyzer](PerformanceAuditAnalyzer). |
| `DiscordBot` | .NET 9 executable | `DiscordBot/src/ProgramRuntime.cs` | `preferences.json`, `token.txt`, extension `database.json`. | Discord channel name, bot presence and status embed updates every 60 seconds. | Missing token/preferences are expected in repo; active status reads `Preferences.Instance.DataSourcePath` or the default data path, while `FileConfiguration.cs` is secondary until config ownership is cleaned up. |
| `Extension` | .NET Framework 4.8 x86 Arma extension | `_RVExtension@12` export | Arma `callExtension` arguments from mission scripts. | Writes `C:\a2waspwarfare\Data\database.json` for DiscordBot. | Legacy Visual Studio/MSBuild target using `RGiesecke.DllExport`/`UnmanagedExports` from `../packages`; preserve x86. |
| `Mods/mkswf_sidewinder_reload_time_fix` | Arma addon config | `CfgWeapons.hpp` | Sidewinder launcher class config. | Sets `magazineReloadTime = 1` for Sidewinder launchers. | External addon fragment, not mission SQF. |

## Local Build Verification 2026-06-03

| Project | Local result | Notes |
| --- | --- | --- |
| `Tools/LoadoutManager/LoadoutManager.csproj` | `dotnet build -v minimal` succeeded with 86 nullable warnings and 0 errors. | Warnings are mostly non-nullable initialization / possible null-reference warnings in data classes and zip helper paths. Build success does not run mission generation or packaging. |
| `DiscordBot/DiscordBot.csproj` | `dotnet build -v minimal` succeeded with 0 warnings and 0 errors. | Runtime still requires ignored `token.txt` and `preferences.json` plus a valid `database.json` source. |
| `Extension/Extension.csproj` | `dotnet build -v minimal` failed locally with `MSB3644`: .NET Framework 4.8 reference assemblies were not found. | Treat as local toolchain missing targeting pack, not proof the legacy extension source is broken. Use Visual Studio/MSBuild with the .NET Framework 4.8 developer pack and x86/package layout before release claims. |

## PerformanceAuditAnalyzer

Dedicated page: [PerformanceAuditAnalyzer](PerformanceAuditAnalyzer).

`Tools/PerformanceAuditAnalyzer` parses existing Arma 2 RPT/log files containing `[Performance Audit]` and exports CSV/Markdown/HTML/Word-friendly reports. It has a GUI picker plus command-line script, but the current tree does not ship a live RPT tailer, background telemetry service or server restart/deploy helper.

Operational caveats from the 2026-06-04 tooling scout:

- `Analyze-PerformanceAudit.ps1:1224-1228` creates the output directory before it confirms any input files, so failed/no-input runs can still leave output folders behind.
- `Analyze-PerformanceAudit.ps1:1248` reads each input with `Get-Content | ForEach-Object`; useful for normal RPTs, but very large logs should be treated as memory/latency-sensitive until streaming behavior is improved and tested.
- `Start-PerformanceAuditAnalyzer.ps1:11-12,119-120` loads `System.Windows.Forms` and opens the picker dialog, so the launcher is desktop/interactive only. Use `Analyze-PerformanceAudit.ps1` directly for automation, CI or headless server log processing.

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
- `performance_interpretation.html`
- `performance_report_word.doc`

Use it after performance-sensitive mission changes or live-server audits.

## Packaging And Deployment Notes

- `7za` environment variable points to `7za.exe`.
- `ZipManager` packages mission directories after copy/generation and currently zips only `Missions` plus `Missions_Vanilla`, not `Modded_Missions`.
- Missing `7za` causes the final packaging step to throw unless `A2WASP_SKIP_ZIP=1` is set; inspect generated/copied files before assuming the whole run did nothing.
- Packaging success is not a strong release proof by itself: `ZipManager.cs:26-33` deletes an existing `_MISSIONS.7z`, `ZipManager.cs:34-44` stages a temp mission-copy directory, and `ZipManager.cs:77-92` starts `7za` and prints output but does not currently gate success on the process exit code. Confirm `_MISSIONS.7z` exists, has the expected mission folders and was produced by a successful 7-Zip run before calling a release archive complete.
- File replacement warnings can still hard-fail later: `BaseTerrain.cs:275-301` logs "File not found!" for a missing expected file and then still calls `File.ReadAllText` on the same path. Treat missing replacement targets as real generator failures, not harmless warnings.
- Generated aircraft damage insertion is marker-based: `BaseTerrain.cs:84-86` wires `Common_ModifyAirVehicle.sqf`, and `FileManager.cs:224-247` prints missing-content warnings without failing the run. Keep a marker-contract check in release validation before changing generated aircraft damage logic.
- The source Chernarus mission is copied to target terrain folders, and extra destination-only files/directories can be deleted during sync (`FileManager.cs:116-119,123-136`). Avoid manual changes in generated targets unless the generator is being updated; snapshot generated mission trees before risky propagation runs.
- `The specified content was not found in the file.` during the current run comes from the terrain help-menu title replacement path and did not stop Chernarus/Takistan generation/copy.
- For the exact `version.sqf` -> `description.ext` / `Rsc/Header.hpp` / `initJIPCompatible.sqf` contract, use [Mission config/version include graph](Mission-Config-Version-Include-Graph).

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
