# AI Assistant Developer Guide

This page is written for Codex, Claude and future coding agents.

## What this page is

This page is the execution playbook for humans and AI agents who are already in the repository and need to *do* edits. It is not the first page to open for pure bootstrap: start at [AI Assistant Guide](AI-Assistant-Guide) first.

## Where this page lives

- Wiki page: `docs/wiki/AI-Assistant-Developer-Guide.md`
- Machine source-of-truth pointers: [`agent-context.json`](agent-context.json), [`agent-status.json`](agent-status.json), [`agent-knowledge.jsonl`](agent-knowledge.jsonl)
- Runtime source lives in: `Missions/[55-2hc]warfarev2_073v48co.chernarus`

## How this page runs in your workflow

- Start with source validation files before editing behavior:
  - [`Current source status snapshot`](Current-Source-Status-Snapshot)
  - `agent-knowledge.jsonl` entries covering active findings
  - [`agent-events.jsonl`](agent-events.jsonl) for latest open/complete claims
- Use this page for:
  - edit safety constraints,
  - recurring engine assumptions (OA vs A3),
  - and where to go for focused subsystem drill-down.
- For LLM bootstrap and page routing only, use [AI Assistant Guide](AI-Assistant-Guide).

## Related systems and source files

- Gameplay system orientation:
  - [SQF code atlas](SQF-Code-Atlas)
  - [Feature status register](Feature-Status-Register)
  - [SQF Code Atlas: Source owners list](SQF-Code-Atlas#init-owners)
- Hardening paths:
  - [Hardening implementation roadmap](Hardening-Implementation-Roadmap)
  - [Server authority migration map](Server-Authority-Migration-Map)
  - [Pending owner decisions](Pending-Owner-Decisions)
- Reliability and review:
  - [Testing, debugging and release workflow](Testing-Debugging-And-Release-Workflow)
  - [Current source status snapshot](Current-Source-Status-Snapshot)

## Risk notes for this page

- This page can become stale faster than source if edits happen in source quickly; rely on the two files above before acting on lane state.
- Keep this page evidence-backed and route new findings back to their canonical pages rather than duplicating full proofs.

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
- When adapting snippets, reject Arma 3-era or non-OA-proven syntax such as `params`, `isEqualTo`, `remoteExec`, `remoteExecCall`, `remoteExecutedOwner`, `isRemoteExecuted`, `allPlayers`, `parseSimpleArray`, `setGroupOwner`, `groupOwner`, modern `select [start,count]` / `select {condition}` forms and `BIS_fnc_MP` unless an official OA command/function page proves availability. This mission already uses OA public-variable/PVF wrappers instead of `BIS_fnc_MP`.
- Use [Arma 2 OA compatibility audit](Arma-2-OA-Compatibility-Audit) when checking whether a scripting example is safe for OA 1.64.
- External references explain engine primitives; they do not prove this fork's server authority, payload validation or JIP behavior.
- `publicVariable` and `setVariable [..., true]` can replicate last-value state, but they do not provide server authority, event-history replay or full marker/queue collection sync.
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

