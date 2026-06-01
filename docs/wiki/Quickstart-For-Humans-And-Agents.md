# Quickstart For Humans And Agents

This page is the low-friction route into the repo. Use it before editing mission code or asking an AI assistant to implement changes.

## Thirty-Second Orientation

| Fact | Value |
| --- | --- |
| Repo | `rayswaynl/a2waspwarfare` |
| Runtime | Arma 2: Operation Arrowhead 1.64 |
| Mission type | Warfare / CTI TvT PvE |
| Source mission | `Missions/[55-2hc]warfarev2_073v48co.chernarus` |
| Generated targets | `Missions_Vanilla/*`, `Modded_Missions/*` |
| Generator | `Tools/LoadoutManager` |
| AI context | [`agent-context.json`](agent-context.json) |

## If You Are Human

1. Read [Home](Home) for the map.
2. Read [Mission entrypoints](Mission-Entrypoints-And-Lifecycle) to understand startup.
3. Read [SQF code atlas](SQF-Code-Atlas) before changing functions, PVF commands or init files.
4. Read [Feature status register](Feature-Status-Register) before reviving old code.
5. Check [Agent worklog](Agent-Worklog) for the latest Codex/Claude findings.

## If You Are An LLM

Load these first, in order:

1. [`agent-context.json`](agent-context.json)
2. [Agent context](Agent-Context)
3. [SQF code atlas](SQF-Code-Atlas)
4. [Documentation implementation plan](Documentation-Implementation-Plan)
5. [Feature status register](Feature-Status-Register)
6. [Agent worklog](Agent-Worklog)

Then inspect source before making claims. Do not infer Arma 3 behavior. If you add high-level facts, update `agent-context.json`.

## Safe Edit Checklist

| Before editing | Why |
| --- | --- |
| Confirm whether the target is source or generated | Generated mission folders may be overwritten by LoadoutManager. |
| Use `-LiteralPath` on Windows | `[55-2hc]` breaks wildcard-based PowerShell paths. |
| Find owner side | Server, client, common and headless paths have different locality/network rules. |
| Check PV/publicVariable behavior | Network changes can affect hosted, dedicated and JIP behavior. |
| Check performance loops | Marker, AI, town and UI loops are live-server sensitive. |
| Record docs impact | Update the wiki and `Agent-Worklog.md` when architecture changes. |

## Common Tasks

| Task | Start with |
| --- | --- |
| Add or change a PVF command | [SQF code atlas](SQF-Code-Atlas), [Networking and public variables](Networking-And-Public-Variables) |
| Change supply missions | [Supply mission architecture](Supply-Mission-Architecture), [Economy, towns and supply](Economy-Towns-And-Supply) |
| Change commander/upgrades | [Core systems index](Core-Systems-Index), [Feature status register](Feature-Status-Register) |
| Change UI or buy menus | [Client UI, HUD and menus](Client-UI-HUD-And-Menus) |
| Change AI/headless behavior | [AI, headless and performance](AI-Headless-And-Performance) |
| Touch generated missions | [Tools and build workflow](Tools-And-Build-Workflow), [Content structure and maps](Content-Structure-And-Maps) |

## Agent Collaboration

| Agent | Best role |
| --- | --- |
| Codex | Maintains the living atlas, agent context, publishing flow and implementation handoffs. |
| Claude | Independently reviews, challenges assumptions, finds hidden coupling and deepens subsystem evidence. |
| Future agents | Start from `agent-context.json`, inspect source and append findings to `Agent-Worklog.md`. |

Use [Claude long-term goal](Claude-Long-Term-Goal) when spinning up Claude as a persistent counterpart.

