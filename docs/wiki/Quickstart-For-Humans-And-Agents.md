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
| AI context | [`agent-entrypoint.json`](agent-entrypoint.json), [`agent-context.json`](agent-context.json) |
| Progress view | [Progress dashboard](Progress-Dashboard), [`agent-status.json`](agent-status.json) |

## If You Are Human

1. Read [Home](Home) for the map.
2. Read [Mission entrypoints](Mission-Entrypoints-And-Lifecycle) to understand startup.
3. Read [Lifecycle wait-chain](Lifecycle-Wait-Chain) before reordering init or wait barriers.
4. Read [Join/disconnect lifecycle](Player-Join-Disconnect-And-AntiStack-Lifecycle) before touching JIP, reconnect, AntiStack, AFK or player-object state.
5. Read [Parameters/build inputs](Mission-Parameters-Localization-And-Generated-Build-Inputs) before changing mission params, generated includes or LoadoutManager behavior.
6. Read [SQF code atlas](SQF-Code-Atlas) before changing functions, PVF commands or init files.
7. Read [Gameplay systems atlas](Gameplay-Systems-Atlas) before touching towns, economy, commander, upgrades, construction or factories.
8. Read [Support/specials/modules atlas](Support-Specials-And-Tactical-Modules-Atlas) before changing paratroopers, paradrops, UAV, artillery, ICBM, MASH, ZetaCargo, service or tactical supports.
9. Read [Marker cleanup/restoration atlas](Marker-Cleanup-Restoration-Systems-Atlas) before changing marker visibility, cleanup loops or restorer cadence.
10. Read [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas) before changing buy menus, factory lists, unit metadata or vehicle spawn logic.
11. Read [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas) before changing town loops, economy/resources, AI commander state, supply mission authority or server performance loops.
12. Read [WASP overlay](WASP-Overlay) before changing project-specific additions under `WASP/`.
13. Read [Feature status register](Feature-Status-Register) before reviving old code.
14. Read [Hardening implementation roadmap](Hardening-Implementation-Roadmap) before patching Auth/PV, economy, victory, supply or BattlEye-sensitive behavior.
15. Check [Progress dashboard](Progress-Dashboard) for current Codex/Claude lanes.
16. Check [Agent worklog](Agent-Worklog) for the latest Codex/Claude findings.

## If You Are An LLM

Load these first, in order:

1. [`agent-entrypoint.json`](agent-entrypoint.json)
2. [`agent-context.json`](agent-context.json)
3. [`agent-status.json`](agent-status.json)
4. [`agent-collaboration.json`](agent-collaboration.json)
5. [`agent-release-readiness.json`](agent-release-readiness.json)
6. [Agent context](Agent-Context)
7. [Progress dashboard](Progress-Dashboard)
8. [Agent collaboration protocol](Agent-Collaboration-Protocol)
9. [SQF code atlas](SQF-Code-Atlas)
10. [Gameplay systems atlas](Gameplay-Systems-Atlas)
11. [Construction and CoIn systems atlas](Construction-And-CoIn-Systems-Atlas)
12. [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas)
13. [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas)
14. [Lifecycle wait-chain](Lifecycle-Wait-Chain)
15. [WASP overlay](WASP-Overlay)
16. [Documentation implementation plan](Documentation-Implementation-Plan)
17. [Feature status register](Feature-Status-Register)
18. [Hardening implementation roadmap](Hardening-Implementation-Roadmap)
19. [Agent worklog](Agent-Worklog)

Then inspect source before making claims. Do not infer Arma 3 behavior. Update `agent-entrypoint.json` only for bootstrap/status-convention changes; update `agent-context.json` for the larger context snapshot.

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
| Harden security/authority paths | [Feature status register](Feature-Status-Register), [Hardening implementation roadmap](Hardening-Implementation-Roadmap), [Deep-review findings](Deep-Review-Findings) |
| Change supply missions | [Supply mission architecture](Supply-Mission-Architecture), [Economy, towns and supply](Economy-Towns-And-Supply) |
| Change support/special modules | [Support/specials/modules atlas](Support-Specials-And-Tactical-Modules-Atlas), [Server authority map](Server-Authority-Migration-Map) |
| Change marker or cleanup loops | [Marker cleanup/restoration atlas](Marker-Cleanup-Restoration-Systems-Atlas), [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas) |
| Change commander/upgrades | [Core systems index](Core-Systems-Index), [Feature status register](Feature-Status-Register) |
| Change town capture/economy/construction/factories | [Gameplay systems atlas](Gameplay-Systems-Atlas), [Construction and CoIn systems atlas](Construction-And-CoIn-Systems-Atlas), [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas), [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas) |
| Add or change a purchasable unit/vehicle | [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas), [Client UI systems atlas](Client-UI-Systems-Atlas) |
| Change UI or buy menus | [Client UI, HUD and menus](Client-UI-HUD-And-Menus), [Client UI systems atlas](Client-UI-Systems-Atlas) |
| Change AI/headless behavior | [AI, headless and performance](AI-Headless-And-Performance), [AI commander autonomy audit](AI-Commander-Autonomy-Audit), [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas) |
| Change WASP custom scripts | [WASP overlay](WASP-Overlay), [Feature status register](Feature-Status-Register) |
| Touch generated missions or parameters | [Parameters/build inputs](Mission-Parameters-Localization-And-Generated-Build-Inputs), [Tools and build workflow](Tools-And-Build-Workflow), [Content structure and maps](Content-Structure-And-Maps) |
| Check source-fix release readiness | [Source fix propagation queue](Source-Fix-Propagation-Queue), [`agent-release-readiness.json`](agent-release-readiness.json), [Testing workflow](Testing-Debugging-And-Release-Workflow) |
| See what Codex and Claude are doing | [Progress dashboard](Progress-Dashboard), [`agent-status.json`](agent-status.json), [`agent-events.jsonl`](agent-events.jsonl) |

## Agent Collaboration

| Agent | Best role |
| --- | --- |
| Codex | Maintains the living atlas, agent context, publishing flow, coordination protocol and implementation handoffs. |
| Claude | Independently reviews, challenges assumptions, finds hidden coupling and records source-backed findings through the collaboration protocol. |
| Future agents | Start from `agent-entrypoint.json`, inspect source and append findings to `Agent-Worklog.md` or the relevant JSONL evidence stream. |

Use [Progress dashboard](Progress-Dashboard) for current status, [Agent collaboration protocol](Agent-Collaboration-Protocol) for claim/handoff rules and [Claude long-term goal](Claude-Long-Term-Goal) when spinning up Claude as a persistent counterpart.

## Continue Reading

Previous: [Home](Home) | Next: [Architecture overview](Architecture-Overview)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent entry: [`agent-entrypoint.json`](agent-entrypoint.json) | Agent file: [`agent-context.json`](agent-context.json)
