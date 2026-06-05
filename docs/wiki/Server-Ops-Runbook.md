# Server Ops Runbook

This page is the operator entrypoint for running, packaging and observing Wasp Warfare. It links the operational pieces from [Tools and build workflow](Tools-And-Build-Workflow), [External integrations](External-Integrations), [Testing/debugging/release workflow](Testing-Debugging-And-Release-Workflow) and [Self-host testing field notes](Self-Host-Testing-Field-Notes).

If you arrived from a broad "server runtime and operations" prompt, start with [Server runtime and operations](Server-Runtime-And-Operations) to choose between this runbook, gameplay runtime loops, integration trust boundaries and release/testing gates.

## What Ships In The Repo

| Area | Repo artifact | Operator meaning |
| --- | --- | --- |
| Mission source | `Missions/[55-2hc]warfarev2_073v48co.chernarus` | Source mission for gameplay edits and source-backed docs. |
| Generated maintained mission | `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan` | LoadoutManager copy/generation target. Use the skip-list rules before hand-editing it. |
| Build/generation tool | `Tools/LoadoutManager` | Generates EASA/balance/version outputs, copies Chernarus to maintained Vanilla and optionally packages `_MISSIONS.7z`. |
| Offline performance parser | `Tools/PerformanceAuditAnalyzer` | Parses existing `[Performance Audit]` RPT/log files; see [Tools/build](Tools-And-Build-Workflow). |
| Discord/status integration | `DiscordBot`, `Extension`, `BattlEyeFilter/publicvariable.txt` | Runtime status, global stats and AFK filter stub; see [External integrations](External-Integrations). |

## What Is Not In The Repo

| Missing artifact | Why it matters |
| --- | --- |
| `server.cfg` / `basic.cfg` | Server identity, password, mission rotation, difficulty and network tuning are operator-owned. |
| Complete BattlEye filter bundle | The repo only ships `publicvariable.txt` for `kickAFK`; no `scripts.txt`, `createvehicle.txt`, `setvariable.txt` or similar production bundle is present. |
| Server restart/deploy wrapper | A repo scan found no tracked server restart/deploy/copy wrapper script. `Tools/PerformanceAuditAnalyzer` does ship local desktop/helper launchers, but those start the offline log analyzer only. Use documented tools/manual deployment unless a new server wrapper is added later. |
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
4. Copy or package mission folders only after source Chernarus and maintained Vanilla scope are clear. LoadoutManager sync can delete destination-only files/directories (`FileManager.cs:116-119,123-136`), so snapshot generated mission trees before propagation and do not hand-edit generated targets as if they were durable source.
5. Deploy BattlEye filters from the actual server `BEpath`. Do not assume the repo's `kickAFK` filter is comprehensive.
6. Deploy `a2waspwarfare_Extension` and the separate `A2WaspDatabase` only with their expected x86/.NET Framework/runtime dependencies.
7. Provide DiscordBot `token.txt`, a valid parseable `preferences.json` and a readable `database.json` data source outside git. `database.json` can fall back to default bot data if absent, but `preferences.json` is read before the token check in the current bot startup path; malformed or JSON-null preferences can also break later command/status paths because runtime code assumes `Preferences.Instance` is non-null. The active status reader uses `Preferences.Instance.DataSourcePath` / default data path; `FileConfiguration.cs` and `botconfig.json` are secondary helper paths and should not be treated as the one source of truth until integration cleanup picks a single path. Because `botconfig.json` is not currently ignored, do not put live secrets or production-only paths there casually.
8. Preserve rollback copies of the previous mission package and server configuration.

## Runtime Telemetry Contracts

| Signal family | Operational contract | Canonical detail |
| --- | --- | --- |
| Server FPS | Dedicated publishers feed RHUD/server-FPS compatibility state; hosted/listen loop behavior is a release-scope smoke item. | [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep), [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas) |
| Client delegation FPS | Player clients report FPS for delegation mode 1; do not trust it as a security signal. | [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map), [Headless delegation/failover](Headless-Delegation-And-Failover-Playbook) |
| Performance audit rows | Collect server and client RPTs; the parser consumes literal `[Performance Audit]` rows, not a live daemon stream. | [Tools/build](Tools-And-Build-Workflow), [PerformanceAuditAnalyzer](PerformanceAuditAnalyzer) |
| Global stats / Discord status | In-repo extension writes `database.json`; DiscordBot polls the selected data path; AntiStack uses a separate missing DB extension. | [External integrations](External-Integrations), [AntiStack database extension audit](AntiStack-Database-Extension-Audit) |

Operational caveats:

- Collect the server RPT for server-scope performance and each client RPT for client/RHUD/UI performance. Client and server performance audit writers are local to their own RPTs.
- `GlobalGameStats.sqf` subtracts one assumed headless client from player count; smoke no-HC and multi-HC deployments before relying on Discord player counts.
- `origin/feat/player-stats` has a branch-only `StatsService`/`stats.json` flow. Current source uses the global `database.json` status path.

## Dedicated Versus Listen Server

`initJIPCompatible.sqf:52` sets `isHostedServer` for single-player or listen-server hosts, then branches server/client/headless init at `:61`, `:70`, `:218` and `:224`.

Use [Self-host testing field notes](Self-Host-Testing-Field-Notes) for local listen-server gotchas: clear `%LOCALAPPDATA%\ArmA 2 OA\Tmp<PORT>\__cur_mp.pbo`, keep HC password flags symmetrical, and attribute RPT warnings by line order rather than frame number.

Use dedicated smoke for authority, BattlEye, AntiStack, extension and publicVariable behavior. Use listen-server smoke for fast UI/gameplay iteration only, and do not call a fix release-ready until the required [Testing/debugging/release workflow](Testing-Debugging-And-Release-Workflow) smoke level is recorded.

## Continue Reading

Previous: [Tools and build workflow](Tools-And-Build-Workflow) | Next: [External integrations](External-Integrations)

Related: [Testing/debugging/release workflow](Testing-Debugging-And-Release-Workflow) | [Self-host testing field notes](Self-Host-Testing-Field-Notes) | [AntiStack database extension audit](AntiStack-Database-Extension-Audit)
