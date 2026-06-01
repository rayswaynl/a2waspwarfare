# Subagent Discovery Swarm

This page tracks the cheap read-only Codex discovery agents currently digging through `a2waspwarfare`.

The swarm is intentionally evidence-first: agents read source, report path/line-backed findings, and avoid editing docs or mission code. Codex integrates the useful findings into the wiki, `agent-context.json`, the coverage ledger and the feature-status register after review.

## Current Pool

| Agent | Lane | Status | Expected output |
| --- | --- | --- | --- |
| Codex | `victory-endgame-runtime-atlas` | Active integrator | New victory/endgame atlas plus nav/context/risk updates. |
| Faraday | `gear-loadout-easa-balance-discovery` | Active read-only scout | Gear templates, EASA, loadout generation and balance metadata report. |
| Mencius | `respawn-medical-mash-support-discovery` | Active read-only scout | MASH, medical/support actions, service flows and marker wiring report. |
| Hilbert | `server-runtime-scheduler-discovery` | Active read-only scout | Server loops, FSMs, scheduler, FPS, cleanup and town-processing report. |
| Cicero | `ai-headless-delegation-discovery` | Active read-only scout | AI squads, autonomous teams, AI commander, HC delegation and town AI report. |
| Curie | `wiki-ux-navigation-discovery` | Active read-only scout | Wiki navigation, click-through, LLM affordance and broken-link report. |
| Meitner | `content-drift-generation-discovery` | Active read-only scout | Source/generated/stale mission folders, assets and drift report. |

## Rotation Queue

When a scout finishes, Codex should assign the next bounded lane from this queue:

| Priority | Lane | Scope |
| --- | --- | --- |
| 1 | `discord-extension-antistack-integration-discovery` | Extension handoff, DiscordBot, AntiStack DB calls, callExtension contracts and missing DLL behavior. |
| 2 | `parameters-config-localization-discovery` | `description.ext`, parameters, stringtables/localization, version/includes and mission tuning knobs. |
| 3 | `abandoned-code-missing-reference-discovery` | Commented compiles, missing scripts, TODO/FIXME, dead PV handlers and stale/generated code. |
| 4 | `pr1-supply-helicopter-delta-discovery` | PR #1 branch delta against `master`, deferred supply-heli AI work and merge risks. |

## Reports Waiting For Integration

| Lane | Agent | Status | Integration targets |
| --- | --- | --- | --- |
| `client-jip-lifecycle-discovery` | Mencius | Report received | [Mission lifecycle](Mission-Entrypoints-And-Lifecycle), [Lifecycle wait-chain](Lifecycle-Wait-Chain), [Client UI systems atlas](Client-UI-Systems-Atlas), [Feature status](Feature-Status-Register), [`agent-context.json`](agent-context.json). |
| `economy-town-factory-upgrade-discovery` | Faraday | Report received | [Economy/towns/supply](Economy-Towns-And-Supply), [Factory/purchase atlas](Factory-And-Purchase-Systems-Atlas), [Server runtime atlas](Server-Gameplay-Runtime-Atlas), [Feature status](Feature-Status-Register), [`agent-context.json`](agent-context.json). |

## Integration Rules

- Scouts do not edit files, commit, push or publish.
- Codex should trust scout source citations, then spot-check high-risk claims before adding them to user-facing docs.
- Findings should land in the owning atlas page first, then in [Feature status](Feature-Status-Register), [Coverage ledger](Codebase-Coverage-Ledger), [Agent worklog](Agent-Worklog) and machine files if relevant.
- If Claude is working the same subsystem, prefer adding a handoff note instead of overwriting Claude-owned review pages.

## Continue Reading

Previous: [Progress dashboard](Progress-Dashboard) | Next: [Coordination board](Coordination-Board)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-status.json`](agent-status.json)
