# Server Ops Runbook

This page is the operator entrypoint for running, packaging and observing Wasp Warfare. It links the operational pieces from [Tools and build workflow](Tools-And-Build-Workflow), [External integrations](External-Integrations), [Testing/debugging/release workflow](Testing-Debugging-And-Release-Workflow) and [Self-host testing field notes](Self-Host-Testing-Field-Notes).

## What Ships In The Repo

| Area | Repo artifact | Operator meaning |
| --- | --- | --- |
| Mission source | `Missions/[55-2hc]warfarev2_073v48co.chernarus` | Source mission for gameplay edits and source-backed docs. |
| Generated maintained mission | `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan` | LoadoutManager copy/generation target. Use the skip-list rules before hand-editing it. |
| Build/generation tool | `Tools/LoadoutManager` | Generates EASA/balance/version outputs, copies Chernarus to maintained Vanilla and optionally packages `_MISSIONS.7z`. |
| Performance parser | `Tools/PerformanceAuditAnalyzer` | Parses existing `[Performance Audit]` RPT/log files into CSV, Markdown, HTML and Word-friendly reports; it is not a shipped live tailer service. |
| Discord status bot | `DiscordBot` | Reads `database.json` through `Preferences.Instance.DataSourcePath` or `C:\a2waspwarfare\Data` and updates Discord status every 60 seconds when `token.txt` and `preferences.json` are supplied outside git. |
| Global stats extension | `Extension` | Legacy .NET Framework 4.8 x86 Arma extension that writes `C:\a2waspwarfare\Data\database.json`. |
| BattlEye stub | `BattlEyeFilter/publicvariable.txt` | Contains only the `kickAFK` publicVariable rule. It is AFK plumbing, not a complete public-server filter set. |

## What Is Not In The Repo

| Missing artifact | Why it matters |
| --- | --- |
| `server.cfg` / `basic.cfg` | Server identity, password, mission rotation, difficulty and network tuning are operator-owned. |
| Complete BattlEye filter bundle | The repo only ships `publicvariable.txt` for `kickAFK`; no `scripts.txt`, `createvehicle.txt`, `setvariable.txt` or similar production bundle is present. |
| Restart/deploy/launch wrapper | A repo scan found no tracked restart/deploy/copy/launch wrapper script. Use documented tools/manual deployment unless a new script is added later. |
| `DiscordBot/token.txt` and `DiscordBot/preferences.json` | Required for bot runtime and intentionally ignored. |
| Separate `A2WaspDatabase` extension | AntiStack uses this out-of-repo DLL; the in-repo `Extension` project is the global game stats writer. |
| Production `BEpath`, extension install path and profile/RPT locations | Needed before release or live-server support claims are reproducible. |

## Deployment Inventory Fields

Before calling a host reproducible, record these owner-provided paths/versions in the deployment notes:

| Artifact | Record |
| --- | --- |
| Arma server config | Absolute paths for `server.cfg`, `basic.cfg`, profile directory and active mission/PBO location. |
| BattlEye | Active `BEpath`, `publicvariable.txt`, `scripts.txt` and any command-specific filters such as `createvehicle.txt`, `setvariable.txt`, `setdamage.txt`, `deletevehicle.txt` and `mpeventhandler.txt`. |
| Extensions | Installed x86 `a2waspwarfare_Extension` DLL path/version and separate `A2WaspDatabase` DLL path/version when AntiStack is enabled. |
| DiscordBot | Runtime folder, `token.txt`, `preferences.json`, selected `DataSourcePath` and readable `database.json` location. |
| Logs | Server RPT path, client RPT capture plan, extension logs and DiscordBot logs. |

## Release Artifact Checklist

1. Generate/copy missions with LoadoutManager from a repo root that contains `Missions`, `Missions_Vanilla` and `Tools/LoadoutManager/LoadoutManager.csproj`, or from a normal `a2waspwarfare` clone.
2. Set `A2WASP_SKIP_ZIP=1` for propagation-only runs. Configure `7za` only when producing `_MISSIONS.7z`.
3. Inspect generated `version.sqf` files before packing. They are git-ignored generated inputs; release config should deliberately set `WF_DEBUG` and `WF_LOG_CONTENT`.
4. Copy or package mission folders only after source Chernarus and maintained Vanilla scope are clear.
5. Deploy BattlEye filters from the actual server `BEpath`. Do not assume the repo's `kickAFK` filter is comprehensive.
6. Deploy `a2waspwarfare_Extension` and the separate `A2WaspDatabase` only with their expected x86/.NET Framework/runtime dependencies.
7. Provide DiscordBot `token.txt`, `preferences.json` and a readable `database.json` data source outside git. `database.json` can fall back to default bot data if absent, but `preferences.json` is read before the token check in the current bot startup path. The active status reader uses `Preferences.Instance.DataSourcePath` / default data path; `FileConfiguration.cs` is a secondary config helper and should not be treated as the one source of truth until integration cleanup picks a single path.
8. Preserve rollback copies of the previous mission package and server configuration.

## Runtime Telemetry Contracts

| Signal | Source | Consumer / proof |
| --- | --- | --- |
| `SERVER_FPS_GUI` | `Server/GUI/serverFpsGUI.sqf:1-7` | RHUD reads it in `Client/Client_UpdateRHUD.sqf:113`. |
| `WFBE_VAR_SERVER_FPS` | `Server/Module/serverFPS/monitorServerFPS.sqf:1-6` | Compatibility channel; no current source Chernarus player-UI reader was found. |
| Client delegation FPS | `Client/FSM/updateavailableactions.fsm:121`; `Server/Functions/Server_HandleSpecial.sqf:75` | Stored as `WFBE_AI_DELEGATION_<uid>` and used by `Server_FNC_Delegation.sqf`. |
| Performance audit RPT rows | `Common/Functions/Common_PerformanceAudit.sqf:118-119` | Literal `[Performance Audit]` rows parsed by `Tools/PerformanceAuditAnalyzer/Analyze-PerformanceAudit.ps1`. |
| Global game stats | `Server/CallExtensions/GlobalGameStats.sqf:5` -> `Extension/src/BaseExtensionClass/Implementations/GLOBALGAMESTATS.cs:13` | Writes `C:\a2waspwarfare\Data\database.json`; DiscordBot polls and updates every 60 seconds. |

Operational caveats:

- Collect the server RPT for server-scope performance and each client RPT for client/RHUD/UI performance. Client and server performance audit writers are local to their own RPTs.
- The performance-audit contract is `[Performance Audit]`, not `PERF_RECORD`, and current tooling is parser/launcher only rather than a daemon that tails live RPTs.
- `GlobalGameStats.sqf` subtracts one assumed headless client from player count; smoke no-HC and multi-HC deployments before relying on Discord player counts.
- `origin/feat/player-stats` has a branch-only `StatsService`/`stats.json` flow. Current source uses the global `database.json` status path.

## Dedicated Versus Listen Server

`initJIPCompatible.sqf:52` sets `isHostedServer` for single-player or listen-server hosts, then branches server/client/headless init at `:61`, `:70`, `:218` and `:224`.

Use [Self-host testing field notes](Self-Host-Testing-Field-Notes) for local listen-server gotchas: clear `%LOCALAPPDATA%\ArmA 2 OA\Tmp<PORT>\__cur_mp.pbo`, keep HC password flags symmetrical, and attribute RPT warnings by line order rather than frame number.

Use dedicated smoke for authority, BattlEye, AntiStack, extension and publicVariable behavior. Use listen-server smoke for fast UI/gameplay iteration only, and do not call a fix release-ready until the required [Testing/debugging/release workflow](Testing-Debugging-And-Release-Workflow) smoke level is recorded.

## Continue Reading

Previous: [Tools and build workflow](Tools-And-Build-Workflow) | Next: [External integrations](External-Integrations)

Related: [Testing/debugging/release workflow](Testing-Debugging-And-Release-Workflow) | [Self-host testing field notes](Self-Host-Testing-Field-Notes) | [AntiStack database extension audit](AntiStack-Database-Extension-Audit)
