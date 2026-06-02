# AI Assistant Developer Guide

This page is written for Codex, Claude and future coding agents.

## Always Start Here

1. Read `AGENTS.md`.
2. Read [Quickstart for humans and agents](Quickstart-For-Humans-And-Agents).
3. Check for `CLAUDE.md` and `JOURNAL.md`; follow them if present.
4. Check `git status`, current branch, recent commits and remote.
5. Treat `Missions/[55-2hc]warfarev2_073v48co.chernarus` as the mission source for gameplay edits.
6. Use Bohemia Interactive Arma 2 OA scripting docs, not Arma 3 docs.
7. Use [External Arma 2 OA reference index](External-Arma-2-OA-Reference-Index) when grounding engine behavior, then verify repo behavior in source.
8. Use [`agent-context.json`](agent-context.json), [`agent-status.json`](agent-status.json) and [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl) as the refreshed machine-readable context set.

## Safe Edit Rules

- Edit source mission files under Chernarus, then run `Tools/LoadoutManager` to propagate.
- Do not edit generated Takistan/modded mission folders as the primary source of truth.
- Do not change live-server modes, extension/database behavior, or anti-stack behavior without explicit confirmation.
- Keep diffs small in server init, PVF registration, economy and purchase/spawn paths.
- Preserve `WF_Debug`-gated logging style for debug detail and use small always-on `INFORMATION`/`WARNING` logs only for tester-visible state transitions.

## Common Pitfalls

- Arma 2 OA SQF differs from Arma 3; avoid using newer commands unless verified for OA 1.64.
- When adapting snippets, reject Arma 3-only syntax such as `params`, `isEqualTo`, `remoteExec`, `BIS_fnc_MP` and `parseSimpleArray` unless an official OA command page proves availability.
- External references explain engine primitives; they do not prove this fork's server authority, payload validation or JIP behavior.
- Machine files can outlive renamed or retired wiki pages; verify against `agent-context.json` and the current page list before routing work from any artifact not listed there.
- Hosted server paths often need local handler calls as well as public-variable dispatch.
- Client-side UI/marker loops are performance-sensitive.
- `publicVariable` payloads can become a network performance issue.
- LoadoutManager has very deep paths; Windows clones may require Git `core.longpaths=true`.
- `7za` missing does not block copy-only generation, but does block packaging.

## Feature Work Checklist

- Locate the authoritative function registration in `Init_Common.sqf`, `Init_Client.sqf`, `Init_Server.sqf` or `Init_PublicVariables.sqf`.
- Identify whether state is client-owned, server-owned, common config or generated tool data.
- For networking, read [Public variable channel index](Public-Variable-Channel-Index) before changing PVF or direct publicVariable channels.
- For modules and naming, use [Modules atlas](Modules-Atlas) and [Variable and naming conventions](Variable-And-Naming-Conventions) instead of re-deriving prefixes from scratch.
- For known hardening choices, read [Pending owner decisions](Pending-Owner-Decisions) before splitting a finding into new backlog items.
- Add or reuse constants in `Init_CommonConstants.sqf` only when the value is truly shared.
- For networked features, prefer `Common_SendToServer`, `Common_SendToClient` or `Common_SendToClients`.
- Run/read targeted searches for duplicate hardcoded arrays before adding new ones.
- Verify with source mission first, then propagate generated mission folders.

## High-Value Search Patterns

```powershell
Set-Location C:\Users\Steff\a2waspwarfare
$SourceMission = 'Missions/[55-2hc]warfarev2_073v48co.chernarus'
if (-not (Test-Path -LiteralPath $SourceMission)) { throw "Missing source mission: $SourceMission" }

rg -n "WFBE_C_MY_FEATURE|MyFeature|publicVariable|addPublicVariableEventHandler" $SourceMission
rg -n "Compile preprocessFile|execVM|execFSM" $SourceMission
rg -n "TODO|FIXME|DoNotUse|GAME_CRASH|disabled|commented" $SourceMission Tools
```

When using PowerShell cmdlets against mission paths with brackets, prefer `-LiteralPath`. Native tools such as `rg` can use the `$SourceMission` variable directly.

## Recommended Verification

- For documentation-only changes: run `powershell -ExecutionPolicy Bypass -File .\Tools\ValidateWiki.ps1`.
- For mission code changes: run `dotnet run` in `Tools/LoadoutManager`; tolerate missing `7za` only for packaging.
- For performance changes: collect RPT with Performance Audit and run `Tools/PerformanceAuditAnalyzer`.
- For network changes: test dedicated-server and hosted/local branches if the code has `isServer`, `isDedicated`, `isHostedServer` or `local player` conditions.

