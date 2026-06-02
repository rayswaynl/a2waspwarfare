# Quickstart For Humans And Agents

This is the first-10-minutes path for `rayswaynl/a2waspwarfare`. It is for orientation, not a replacement for source checks.

## Read First

1. `AGENTS.md`
2. `CLAUDE.md`, if present in the worktree
3. [Agent context](Agent-Context) and [`agent-context.json`](agent-context.json)
4. [Home](Home), then [Architecture overview](Architecture-Overview)
5. [Codebase coverage ledger](Codebase-Coverage-Ledger) and [Deep-review findings](Deep-Review-Findings) before touching risky systems

## Worktree Map

- Mission/source worktree: `C:\Users\Steff\a2waspwarfare`
- Docs/wiki mirror worktree: `C:\Users\Steff\a2waspwarfare-docs`
- Source mission: `Missions/[55-2hc]warfarev2_073v48co.chernarus`
- Generated vanilla mission: `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan`
- Generator: `Tools/LoadoutManager`

## Non-Negotiables

- Use Arma 2 Operation Arrowhead 1.64 references, not Arma 3 assumptions.
- Gameplay edits start in the Chernarus source mission.
- After mission code edits, run `dotnet run` from `Tools/LoadoutManager`; missing `7za` only blocks packaging.
- For skip-listed generated files, `LoadoutManager` is not enough. See [Tools and build workflow](Tools-And-Build-Workflow).
- External references explain engine behavior; repo source proves what this fork actually does.

## Fast Source Checks

```powershell
git status --short
git branch --show-current
git log --oneline -5
rg -n "publicVariable|addPublicVariableEventHandler|publicVariableServer" Missions/[55-2hc]warfarev2_073v48co.chernarus
rg -n "Compile preprocessFile|execFSM|callExtension" Missions/[55-2hc]warfarev2_073v48co.chernarus
```

## Risk Trail

- PVF and direct-public-variable authority: [Networking and public variables](Networking-And-Public-Variables), DR-1 and DR-41 in [Deep-review findings](Deep-Review-Findings).
- Economy/client-authoritative spend paths: [Economy, towns and supply](Economy-Towns-And-Supply), [Gameplay systems atlas](Gameplay-Systems-Atlas), DR-6, DR-14, DR-16, DR-22, DR-23, DR-27, DR-28 and DR-41.
- Generated mission drift and `version.sqf`: [Tools and build workflow](Tools-And-Build-Workflow), DR-4, DR-32 and DR-43.
- Headless/client/server lifecycle: [Mission entrypoints and lifecycle](Mission-Entrypoints-And-Lifecycle), [Lifecycle wait-chain reference](Lifecycle-Wait-Chain), [AI, headless and performance](AI-Headless-And-Performance).

## Documentation Edits

- Append to [Agent worklog](Agent-Worklog) after each completed lane.
- Keep [Coordination board](Coordination-Board) current for active or completed lanes.
- Update [`agent-context.json`](agent-context.json) when page lists, high-level facts or durable risks change.
- Run a link/JSON check before handing off.

## Continue Reading

- [External Arma 2 OA reference index](External-Arma-2-OA-Reference-Index)
- [Feature status register](Feature-Status-Register)
- [Current work: supply helicopters PR #1](Current-Work-Supply-Helicopters-PR1)
- [Documentation implementation plan](Documentation-Implementation-Plan)
