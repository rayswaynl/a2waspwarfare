# Tooling Release Readiness Audit

This page records the current tooling, generated-mission, integration and release-readiness map from source. Use it before claiming generated propagation, packaging, public-server hardening, Discord/extension safety or release completeness.

Canonical companion pages are [Tools/build workflow](Tools-And-Build-Workflow), [Source fix propagation queue](Source-Fix-Propagation-Queue), [`agent-release-readiness.json`](agent-release-readiness.json), [Testing/debugging/release workflow](Testing-Debugging-And-Release-Workflow), [Mission parameters/build inputs](Mission-Parameters-Localization-And-Generated-Build-Inputs), [External integrations](External-Integrations), [Integration trust boundary audit](Integration-Trust-Boundary-Audit) and [AntiStack DB audit](AntiStack-Database-Extension-Audit).

## Tooling Architecture Map

| Area | Current source state |
| --- | --- |
| Source mission | `Missions/[55-2hc]warfarev2_073v48co.chernarus` is the edit source; `CLAUDE.md:10` and `Testing-Debugging-And-Release-Workflow.md:7` agree. |
| LoadoutManager entry | `.NET 8`; `Tools/LoadoutManager/Program.cs:6` calls `SqfFileGenerator.GenerateCommonBalanceInitAndTheEasaFileForEachTerrain()`. |
| Active propagation | Current generator writes Chernarus and Vanilla Takistan: `Tools/LoadoutManager/SqfFileGenerators/SqfFileGenerator.cs:128-129`. |
| Inactive modded propagation | Modded write call is commented and TODO remains: `SqfFileGenerator.cs:132-133`; packaging only includes `Missions` and `Missions_Vanilla` at `ZipManager.cs:16`. |
| Generated outputs | EASA init, balance init, aircraft-name helper, damage-model insert, `Sounds/description.ext` and per-terrain `version.sqf`: `BaseTerrain.cs:32-102`, `:346-364`. |
| Fresh-checkout generated input | `version.sqf` is included by mission files but git-ignored: `.gitignore:1`, `:23`; `description.ext:39`; `initJIPCompatible.sqf:4`. |
| Takistan copy rules | `FileManager.ShouldSkipFile()` excludes `mission.sqm`, `version.sqf`, help, `texHeaders.bin`, `StartVeh.sqf`, non-modded `loadScreen.jpg`: `FileManager.cs:89-101`. |
| Takistan blacklist | Directory blacklist includes `Textures`, `Server\Config`, `Core_Artillery`: `FileManager.cs:20-36`. |
| Current comparable drift | Read-only spot check found Chernarus -> Takistan comparable drift bounded to expected map/asset extras plus `Server/Init/Init_Server.sqf` `SET_MAP` `1` vs `2` at about `:613`. |
| Modded drift posture | Modded folders remain divergent/stub/fork-like; do not treat them as maintained generated outputs while `SqfFileGenerator.cs:132-133` remains commented. |
| PerformanceAuditAnalyzer | Read-only RPT parser for `[Performance Audit]`, `SID`, legacy sessions and CSV/HTML/Markdown reports: `Tools/PerformanceAuditAnalyzer/Analyze-PerformanceAudit.ps1:14-18`, `:282`, `:1295`, `:1361-1393`. |

## Release Consistency Findings

| Priority | Finding | Evidence | Action |
| --- | --- | --- | --- |
| P1 | Canonical release ledger says the five tracked source fixes are Chernarus source-patched, maintained Vanilla propagated and Arma smoke pending. | `agent-release-readiness.json:33-44`, `:54-130`; `Source-Fix-Propagation-Queue.md:25-45`; `Feature-Status-Register.md:40`, `:111`, `:118`, `:126` | Treat runtime smoke, not propagation, as the remaining release gate. |
| P1 | `agent-status.json` still has stale prose for some propagated lanes. | Status rows around the propagated fix lanes say Vanilla propagation pending while release readiness says propagated. | Update wording to "Vanilla propagated; Arma smoke pending" in the next status cleanup. |
| P1 | Fresh-checkout boot/package hazard is real. | `version.sqf` is git-ignored/generated but included by mission boot files. | Add a machine-readable release gate for generated `version.sqf`. |
| P1 | Docs CI validates wiki structure, not build/drift/security. | `.github/workflows/docs.yml:25-46`; `docs/validate-wiki.ps1:63-111` | Add separate build/drift/security checks rather than overloading docs validation. |
| P2 | Modded release posture is cautious and source-consistent. | `Tools-And-Build-Workflow.md:63`, `:72-74`; `agent-release-readiness.json:14-15`; `SqfFileGenerator.cs:132-133`; `ZipManager.cs:16` | Keep Modded_Missions out of generated-propagation claims unless generation is intentionally restored. |

## Integration Risk Table

| Boundary | Trust issue | Risk | Source refs |
| --- | --- | --- | --- |
| DiscordBot JSON intake | Reads `database.json` with `TypeNameHandling.All` despite a flat DTO. | High local-write-gated RCE in token-holding bot process. | `DiscordBot/src/ExtensionData/GameData/GameData.cs:32-56`; `GameStatusUpdater.cs:9`, `:84`; `CommandHandler.cs:211`; `ProgramRuntime.cs:15`. |
| DiscordBot config/secrets | `token.txt` and `preferences.json` are ignored; sample contains real-looking IDs and prod-style paths. | Low/medium governance issue, no token committed. | `DiscordBot/.gitignore:7`, `:9`; `preferences_sample.json:3-8`; `Preferences.cs:24-43`. |
| DiscordBot server-info display | JSON controls map/player count/channel name; invalid map/player shape can break updates. | Medium reliability/spoofing inside trusted data path. | `GameData.cs:80-156`; `GameStatusUpdater.cs:92-119`. |
| `GLOBALGAMESTATS` extension | SQF output discarded, enum-gated selector, `TypeNameHandling.None`; but hardcoded path, `async void`, `File.Replace` race and stale arg shapes remain. | Medium reliability, low current SQF-RCE risk. | `GlobalGameStats.sqf:20-22`; `ExtensionMethods.cs:10-35`; `SerializationManager.cs:12-55`; `GameData.cs:29`. |
| AntiStack DB extension | Separate absent `A2WaspDatabase`; default enabled; wrappers `call compile` extension strings and assume array shape. | High deployment/runtime trust risk. | `Init_CommonConstants.sqf:171`; `Parameters.hpp:547-551`; `callDatabaseRetrieve.sqf:24-40`; `callDatabaseRequestSideTotalSkill.sqf:30-64`; `callDatabaseSendPlayerList.sqf:58-65`. |
| BattlEye filters | Shipped filter is AFK `kickAFK` plumbing only; no `scripts.txt`, `server.cfg` or `basic.cfg` bundle. | Medium release-claim risk, not comprehensive public-server hardening. | `BattlEyeFilter/publicvariable.txt:2`; `Client/FSM/updateclient.sqf:153-160`; `External-Integrations.md:96-104`. |

## Validation Commands

```powershell
# Existing structural docs check.
.\docs\validate-wiki.ps1

# Fresh-checkout ignored/generated file check.
git ls-files --others --ignored --exclude-standard

# Propagation in a scratch/CI workspace, then inspect diffs.
$env:A2WASP_SKIP_ZIP = "1"
dotnet run --project Tools\LoadoutManager\LoadoutManager.csproj

# Build gates worth adding outside docs validation.
dotnet build Tools\LoadoutManager\LoadoutManager.csproj -c DEBUG
dotnet build DiscordBot\DiscordBot.csproj

# Security grep gates.
rg -n "TypeNameHandling\.(All|Auto)" DiscordBot Extension
rg -n '"A2WaspDatabase" callExtension|call compile' Missions/*/Server/Module/AntiStack

# BattlEye claim gate.
rg --files | rg "(^|/)(publicvariable\.txt|scripts\.txt|server\.cfg|basic\.cfg)$"
```

## Backlog Seeds

| Priority | Correction |
| --- | --- |
| P1 | Update stale `agent-status.json` lane prose to "Vanilla propagated; Arma smoke pending." |
| P1 | Add `versionSqfGeneratedInput` or equivalent to `agent-release-readiness.json`. |
| P1 | Add generated drift checker to CI or a separate release validator. |
| P2 | Expand `agent-release-readiness.json` generated-targets from wildcard `Modded_Missions/*` to tiered states: maintained Vanilla, divergent forks, skeletal stubs. |
| P2 | Record current Takistan comparable drift and modded drift posture in [Tools/build workflow](Tools-And-Build-Workflow) or [Source fix propagation queue](Source-Fix-Propagation-Queue). |
| P2 | Note that `DiscordBot/FileConfiguration.cs` exists while active status JSON reader uses `Preferences.Instance.DataSourcePath ?? C:\a2waspwarfare\Data`. |
| P3 | Replace concrete `preferences_sample.json` snowflakes with placeholders. |

## Continue Reading

Previous: [Tools/build workflow](Tools-And-Build-Workflow) | Next: [Testing/debugging/release workflow](Testing-Debugging-And-Release-Workflow)

Related: [External integrations](External-Integrations) | [Integration trust boundary audit](Integration-Trust-Boundary-Audit) | [AntiStack DB audit](AntiStack-Database-Extension-Audit)
