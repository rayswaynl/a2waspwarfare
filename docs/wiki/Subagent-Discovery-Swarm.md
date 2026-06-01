# Subagent Discovery Swarm

This page tracks the cheap read-only Codex discovery agents currently digging through `a2waspwarfare`.

The swarm is intentionally evidence-first: agents read source, report path/line-backed findings, and avoid editing docs or mission code. Codex integrates the useful findings into the wiki, `agent-context.json`, the coverage ledger and the feature-status register after review.

## Current Pool

| Agent | Lane | Status | Expected output |
| --- | --- | --- | --- |
| Codex | `victory-endgame-runtime-atlas` | Active integrator | New victory/endgame atlas plus nav/context/risk updates. |
| Faraday | `discord-extension-antistack-integration-discovery` | Active read-only scout | Extension, DiscordBot, AntiStack DB, BattlEye and external trust report. |
| Mencius | `parameters-config-localization-discovery` | Active read-only scout | Parameters, defaults, includes, version files and localization report. |
| Hilbert | `abandoned-code-missing-reference-discovery` | Active read-only scout | Commented compiles, missing scripts, TODOs, dead PV handlers and stale leftovers report. |
| Cicero | `ai-headless-delegation-discovery` | Active read-only scout | AI squads, autonomous teams, AI commander, HC delegation and town AI report. |
| Curie | `wiki-ux-phase2-agent-interface-discovery` | Active read-only scout | Concrete implementation checklist for human + LLM wiki UX improvements. |
| Meitner | `pr1-supply-helicopter-delta-discovery` | Active read-only scout | PR #1 supply-helicopter branch delta, deferred AI work and merge-risk report. |

## Rotation Queue

When a scout finishes, Codex should assign the next bounded lane from this queue:

| Priority | Lane | Scope |
| --- | --- | --- |
| 1 | `cleanup-maintenance-runtime-discovery` | Garbage, empty vehicles, mines, ruins, craters, building restore and object lifecycle cleanup. |
| 2 | `support-artillery-uav-paradrop-discovery` | Tactical supports, artillery, UAV, paradrops, ICBM and related PV/safety gates. |
| 3 | `stringtable-copyediting-discovery` | User-facing text, localization gaps, stale help text and agent-readable wording improvements. |
| 4 | `generated-output-parity-check` | Compare wiki mirror, source mission and generated mission files for drift after docs integration. |

## Reports Waiting For Integration

| Lane | Agent | Status | Integration targets |
| --- | --- | --- | --- |
| `client-jip-lifecycle-discovery` | Mencius | Report received | [Mission lifecycle](Mission-Entrypoints-And-Lifecycle), [Lifecycle wait-chain](Lifecycle-Wait-Chain), [Client UI systems atlas](Client-UI-Systems-Atlas), [Feature status](Feature-Status-Register), [`agent-context.json`](agent-context.json). |
| `economy-town-factory-upgrade-discovery` | Faraday | Report received | [Economy/towns/supply](Economy-Towns-And-Supply), [Factory/purchase atlas](Factory-And-Purchase-Systems-Atlas), [Server runtime atlas](Server-Gameplay-Runtime-Atlas), [Feature status](Feature-Status-Register), [`agent-context.json`](agent-context.json). |
| `gear-loadout-easa-balance-discovery` | Faraday | Report received | [Client UI systems atlas](Client-UI-Systems-Atlas), [Tools/build](Tools-And-Build-Workflow), [Feature status](Feature-Status-Register), [`agent-context.json`](agent-context.json). |
| `respawn-medical-mash-support-discovery` | Mencius | Report received | [Gameplay atlas](Gameplay-Systems-Atlas), [Client UI systems atlas](Client-UI-Systems-Atlas), [Feature status](Feature-Status-Register), [`agent-context.json`](agent-context.json). |
| `server-runtime-scheduler-discovery` | Hilbert | Report received | [Server runtime atlas](Server-Gameplay-Runtime-Atlas), [AI/performance](AI-Headless-And-Performance), [Feature status](Feature-Status-Register), [`agent-context.json`](agent-context.json). |
| `wiki-ux-navigation-discovery` | Curie | Report received | [Home](Home), [Quickstart](Quickstart-For-Humans-And-Agents), [Progress dashboard](Progress-Dashboard), [`agent-context.json`](agent-context.json). |
| `content-drift-generation-discovery` | Meitner | Report received | [Content/maps](Content-Structure-And-Maps), [Tools/build](Tools-And-Build-Workflow), [Feature status](Feature-Status-Register), [`agent-context.json`](agent-context.json). |

## Integration Rules

- Scouts do not edit files, commit, push or publish.
- Codex should trust scout source citations, then spot-check high-risk claims before adding them to user-facing docs.
- Findings should land in the owning atlas page first, then in [Feature status](Feature-Status-Register), [Coverage ledger](Codebase-Coverage-Ledger), [Agent worklog](Agent-Worklog) and machine files if relevant.
- If Claude is working the same subsystem, prefer adding a handoff note instead of overwriting Claude-owned review pages.

## Continue Reading

Previous: [Progress dashboard](Progress-Dashboard) | Next: [Coordination board](Coordination-Board)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-status.json`](agent-status.json)
