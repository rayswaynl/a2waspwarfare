# LoadoutManager Build Configurations and Generated Defines

> Source-verified 2026-06-21 against master 0139a346. Paths relative to the repo root (note each root: Tools/, Extension/, DiscordBot/, Modded_Missions/, or the Chernarus mission dir). Arma 2 OA 1.64.

LoadoutManager is a .NET 8 console tool (`Tools/LoadoutManager/`), not runtime mission SQF. One job of every generation run is to (re)write each terrain's `version.sqf` from code, and three of that file's `#define` lines are toggled purely by which **build configuration** you compile/run under. The other wiki pages name the six configs (build-workflow page) or describe the runtime behavior the defines unlock (mission-parameters page); this page is the bridge: a config -> define matrix sourced to the generator methods that emit each line.

The tool exposes exactly six configurations, declared in the project file: `DEBUG;SERVER_DEBUG;RELEASE;AIRWAR_DEBUG;AIRWAR_SERVER_DEBUG;AIRWAR_RELEASE` (`Tools/LoadoutManager/LoadoutManager.csproj:8`). The csproj sets no explicit `DefineConstants`, so each configuration name doubles as the preprocessor symbol the SDK defines at compile time; the generator's `#if`/`#elif` blocks branch on those symbols. You select one with `dotnet run -c <Configuration>` (`Tools/LoadoutManager/README.md:37`).

## Where the defines are generated

`GenerateAndWriteVersionSqf()` composes the whole `version.sqf` body via string interpolation and inlines three method results: `wfDebug`, `wfLogContent`, and `isAirWarEvent` (`Tools/LoadoutManager/Data/Terrains/BaseTerrain.cs:359-381`). The composed string is written to disk by the caller at `BaseTerrain.cs:115` (`WriteToFile(_destinationDirection, GenerateAndWriteVersionSqf(), @"\version.sqf")`). Each of the three toggled lines comes from its own private method:

| Generated `#define` | Generator method | Source |
| --- | --- | --- |
| `WF_DEBUG 1` | `GenerateWFDebug()` | `BaseTerrain.cs:383-392` |
| `WF_LOG_CONTENT` | `GenerateWFLogContent()` | `BaseTerrain.cs:394-403` |
| `IS_AIR_WAR_EVENT` | `GenerateIsAirWarEvent()` | `BaseTerrain.cs:405-412` |

The remaining `version.sqf` lines (`IS_CHERNARUS_MAP_DEPENDENT`, `IS_MOD_MAP_DEPENDENT`, `IS_NAVAL_MAP`, `WF_MAXPLAYERS`, `WF_MISSIONNAME`, `STARTING_DISTANCE`, `COMBINEDOPS`, `WF_RESPAWNDELAY`) are driven by per-terrain data, not by the build config, and are out of scope here (`BaseTerrain.cs:370-380`).

## Config -> define matrix

For each method, an emitted line means the `#define` is active; a commented line (`// #define ...`) means it is present but inert. The branch logic verbatim:

- `GenerateWFDebug`: `#if DEBUG || AIRWAR_DEBUG` returns `#define WF_DEBUG 1`; the `#elif SERVER_DEBUG || AIRWAR_SERVER_DEBUG` and `#else` branches both return `// #define WF_DEBUG 1` (`BaseTerrain.cs:385-391`).
- `GenerateWFLogContent`: both `#if DEBUG || AIRWAR_DEBUG` and `#elif SERVER_DEBUG || AIRWAR_SERVER_DEBUG` return `#define WF_LOG_CONTENT`; only `#else` returns `// #define WF_LOG_CONTENT` (`BaseTerrain.cs:396-402`).
- `GenerateIsAirWarEvent`: `#if AIRWAR_DEBUG || AIRWAR_SERVER_DEBUG || AIRWAR_RELEASE` returns `#define IS_AIR_WAR_EVENT`; `#else` returns `//#define IS_AIR_WAR_EVENT` (`BaseTerrain.cs:407-411`).

Resolving those three branches for each of the six configs:

| Build config | `WF_DEBUG 1` | `WF_LOG_CONTENT` | `IS_AIR_WAR_EVENT` |
| --- | --- | --- | --- |
| `DEBUG` | ON | ON | off |
| `SERVER_DEBUG` | off | ON | off |
| `RELEASE` | off | off | off |
| `AIRWAR_DEBUG` | ON | ON | ON |
| `AIRWAR_SERVER_DEBUG` | off | ON | ON |
| `AIRWAR_RELEASE` | off | off | ON |

Read by define: `WF_DEBUG` is ON only under `DEBUG` and `AIRWAR_DEBUG`; `WF_LOG_CONTENT` is ON under the four `*_DEBUG` configs and off under both `RELEASE` configs; `IS_AIR_WAR_EVENT` is ON under exactly the three `AIRWAR_*` configs. So the `AIRWAR_*` family mirrors the plain family one-for-one on the first two defines and additionally flips the air-war define on.

## What each define does (runtime side, for context)

These are the consumers that justify the matrix; full runtime semantics live on the mission-parameters and version-include pages.

| Define | Effect when active | Verified consumer |
| --- | --- | --- |
| `WF_DEBUG 1` | Developer smoke-test mode (instant funds, all tiers). The tracked template warns it is "smoke-test ONLY, never a deploy" (`version.sqf.template:2-3`). | Mission code gates on `WF_DEBUG`; never ship it ON. |
| `WF_LOG_CONTENT` | Enables `WF_LOG` content output into the RPT log. The generator carries a maintainer note that you must *comment* the line, not just change its value, to disable logging (`BaseTerrain.cs:356`). | RPT logging in mission scripts. |
| `IS_AIR_WAR_EVENT` | Sets the air-war event baseline; at runtime `initJIPCompatible.sqf:168` reads `#ifdef IS_AIR_WAR_EVENT` to default `IS_air_war_event = true` when the air-event parameter is left on "default" (case 0). | `Missions/[55-2hc]warfarev2_073v48co.chernarus/initJIPCompatible.sqf:163-178` |

`IS_air_war_event` then gates content downstream; e.g. ICBM is suppressed while the event is active: `WFBE_C_MODULE_WFBE_ICBM > 0 && !(IS_air_war_event)` (`.../Common/Config/Core_Upgrades/Upgrades_USMC.sqf:17`, mirrored in the tactical menu at `.../Client/GUI/GUI_Menu_Tactical.sqf:252`). Note the layering: the build-time `#define IS_AIR_WAR_EVENT` only sets the *default*; the runtime `WFBE_AIR_EVENT_ENABLED` parameter (cases 1/2) can still force the event off or on regardless of how the mission was built (`initJIPCompatible.sqf:166-178`).

## Why the build config is the only lever

`version.sqf` is git-ignored for every terrain; the repo's root `.gitignore` ignores each `.../version.sqf` and explicitly re-includes only `version.sqf.template` as the tracked reference (`.gitignore:1-15`). The live file is fully (re)generated by LoadoutManager on every run (`BaseTerrain.cs:115`) and then pulled into the mission build via `#include "version.sqf"` in the mission header (`Missions/[55-2hc]warfarev2_073v48co.chernarus/description.ext:38`). Consequences:

- Hand-editing a generated `version.sqf` is futile for these three defines: the next generation overwrites it. The defines are controlled at the source by the chosen `-c <Configuration>`.
- `dotnet run` with no `-c` defaults to `DEBUG`, which is the one config that emits `WF_DEBUG 1` (and `WF_LOG_CONTENT`). That output must never reach a public deploy. The build-workflow checklist already flags inspecting `WF_DEBUG`/`WF_LOG_CONTENT` before packaging (`Tools-And-Build-Workflow.md:51`); this page explains that the fix is to pick a non-`DEBUG` config rather than to scrub the file.
- The committed `version.sqf.template` shows the intended public posture for these lines: `WF_DEBUG` and `WF_LOG_CONTENT` both commented off, `IS_AIR_WAR_EVENT` commented off (`version.sqf.template:4-9`) - i.e. the output of a `RELEASE` build.

## Practical config selection

| Goal | Config | Result |
| --- | --- | --- |
| Local developer smoke test | `DEBUG` | `WF_DEBUG 1` + `WF_LOG_CONTENT` ON; never deploy. |
| Diagnose a live server with logs | `SERVER_DEBUG` | logging ON, `WF_DEBUG` off (safe to run on server per `README.md:45`). |
| Standard public release | `RELEASE` | all three defines off (matches `version.sqf.template`). |
| Air-war event, with logs | `AIRWAR_SERVER_DEBUG` | event ON + logging ON, no `WF_DEBUG`. |
| Air-war event, public | `AIRWAR_RELEASE` | event ON only; clean release otherwise. |
| Air-war event, dev smoke test | `AIRWAR_DEBUG` | event ON + `WF_DEBUG` + logging; dev-only. |

The README describes the same six configs only as deployment-tier labels and never states which defines each flips (`README.md:43-49`); the matrix above is the missing mapping.

## Continue Reading

- [Tools and build workflow](Tools-And-Build-Workflow)
- [Mission parameters, localization and generated build inputs](Mission-Parameters-Localization-And-Generated-Build-Inputs)
- [Mission config/version include graph](Mission-Config-Version-Include-Graph)
- [LoadoutManager data model contributor guide](LoadoutManager-Data-Model-Contributor-Guide)
- [Miksuu wiki archive: LoadoutManager](Miksuu-Wiki-Archive-LoadoutManager)
