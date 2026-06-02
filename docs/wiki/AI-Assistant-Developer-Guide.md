# AI Assistant Developer Guide

This page is written for Codex, Claude and future coding agents.

## Always Start Here

1. Read `AGENTS.md`.
2. Read `CLAUDE.md` when present; it is the short launchpad for agent coordination in this repo.
3. Read `Agent-Collaboration-Protocol.md`, `agent-collaboration.json` and `agent-events.jsonl` before parallel work.
4. Check `git status`, current branch, recent commits and remote.
5. Treat `Missions/[55-2hc]warfarev2_073v48co.chernarus` as the mission source for gameplay edits.
6. Use [Arma 2 OA external reference guide](Arma-2-OA-External-Reference-Guide) and Bohemia Interactive Arma 2 OA scripting docs, not Arma 3 docs.

## Safe Edit Rules

- Edit source mission files under Chernarus, then run `Tools/LoadoutManager` to propagate.
- Do not edit generated Takistan/modded mission folders as the primary source of truth.
- Do not change live-server modes, extension/database behavior, or anti-stack behavior without explicit confirmation.
- Keep diffs small in server init, PVF registration, economy and purchase/spawn paths.
- Preserve `WF_Debug`-gated logging style for debug detail and use small always-on `INFORMATION`/`WARNING` logs only for tester-visible state transitions.

## Common Pitfalls

- Arma 2 OA SQF differs from Arma 3; avoid using newer commands unless verified for OA 1.64.
- `remoteExec`, CfgFunctions-era assumptions and Arma 3-only command variants are not valid drop-ins for this mission's OA-era PV/PVEH model.
- Hosted server paths often need local handler calls as well as public-variable dispatch.
- Client-side UI/marker loops are performance-sensitive.
- `publicVariable` payloads can become a network performance issue.
- `addEventHandler` stacks handlers; reusable vehicles/units need guards or stored handler IDs before adding another handler.
- `setVariable [..., true]` publishes object/group state, but it does not make client-written authority data trustworthy.
- LoadoutManager has very deep paths; Windows clones may require Git `core.longpaths=true`.
- `7za` missing does not block copy-only generation, but does block packaging.

## Feature Work Checklist

- Locate the authoritative function registration in `Init_Common.sqf`, `Init_Client.sqf`, `Init_Server.sqf` or `Init_PublicVariables.sqf`.
- For Auth/PV, economy, victory, supply or BattlEye-sensitive patches, read [Hardening implementation roadmap](Hardening-Implementation-Roadmap) and [Server authority migration map](Server-Authority-Migration-Map) before editing. For attack-wave work, also read [Attack-wave authority playbook](Attack-Wave-Authority-Playbook); it records the direct-PV DR-41 failure and the current all-side-supply spend model.
- For any gameplay patch, record the validation level using [Testing workflow](Testing-Debugging-And-Release-Workflow) and [`agent-test-plan.schema.json`](agent-test-plan.schema.json). Mark source-only review separately from in-game smoke tests.
- Identify whether state is client-owned, server-owned, common config or generated tool data.
- Add or reuse constants in `Init_CommonConstants.sqf` only when the value is truly shared.
- For networked features, prefer `Common_SendToServer`, `Common_SendToClient` or `Common_SendToClients`.
- Cross-check engine behavior in [Arma 2 OA external reference guide](Arma-2-OA-External-Reference-Guide) when touching public variables, PVEHs, object vars, event handlers, object scans, JIP waits, UI marker loops or performance instrumentation.
- Run/read targeted searches for duplicate hardcoded arrays before adding new ones.
- Verify with source mission first, then propagate generated mission folders.

## High-Value Search Patterns

```powershell
rg -n "WFBE_C_MY_FEATURE|MyFeature|publicVariable|addPublicVariableEventHandler" Missions/[55-2hc]warfarev2_073v48co.chernarus
rg -n "Compile preprocessFile|execVM|execFSM" Missions/[55-2hc]warfarev2_073v48co.chernarus
rg -n "TODO|FIXME|DoNotUse|GAME_CRASH|disabled|commented" Missions/[55-2hc]warfarev2_073v48co.chernarus Tools
```

## Recommended Verification

- For documentation-only changes: link check and diff review.
- For mission code changes: run `dotnet run` in `Tools/LoadoutManager`; tolerate missing `7za` only for packaging.
- For performance changes: collect RPT with Performance Audit and run `Tools/PerformanceAuditAnalyzer`.
- For network changes: test dedicated-server and hosted/local branches if the code has `isServer`, `isDedicated`, `isHostedServer` or `local player` conditions.

## Continue Reading

Previous: [Arma 2 OA external reference guide](Arma-2-OA-External-Reference-Guide) | Next: [Agent context](Agent-Context)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
