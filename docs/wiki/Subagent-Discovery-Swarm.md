# Subagent Discovery Swarm

This page tracks the cheap read-only Codex discovery agents currently digging through `a2waspwarfare`.

The swarm is intentionally evidence-first: agents read source, report path/line-backed findings, and avoid editing docs or mission code. Codex integrates the useful findings into the wiki, `agent-context.json`, the coverage ledger and the feature-status register after review.

## Current Pool

| Agent | Lane | Status | Expected output |
| --- | --- | --- | --- |
| Codex | `integration-backlog-batch-a` | Active integrator | Scout wave harvested; integrate PV/network trust and external integration/AntiStack first, then publish clean batches. |
| Sagan | `external-pdf-analytisch-rapport` | Report received | External PDF digest captured in [External research reports](External-Research-Reports). |
| Helmholtz | `external-pdf-analyse` | Report received | External PDF digest captured in [External research reports](External-Research-Reports). |
| Parfit | `external-pdf-diepgaande-analyse` | Report received | External PDF digest captured in [External research reports](External-Research-Reports). |
| Turing | `generated-output-parity-check-v2` | Report received | Source/generated/modded mission drift, docs mirror parity and generation-rule report. |
| Dirac | `assets-audio-textures-identity-v2` | Report received | Music, sounds, textures, identities, load screens, briefing assets and missing/stale asset report. |
| Gibbs | `server-config-hosting-be-v2` | Report received | Server configs, BattlEye filters, ServerInfo, hosting/deploy assumptions and ops-risk report. |
| Plato | `loadoutmanager-generator-deeper-v2` | Report received | LoadoutManager internals, terrain copy rules, generated SQF and package workflow report. |
| Epicurus | `towns-camps-depots-economy-v2` | Report received | Town capture, camps/depots, supply values, occupation and economy edge report. |
| Hooke | `support-artillery-uav-paradrop-v2` | Report received | Artillery, ICBM, UAV, IRS, countermeasures, paradrop/paratroopers, mines and tactical support report. |
| Carson | `cleanup-maintenance-runtime-v2` | Report received | Garbage collector, empty vehicles, mines, craters, ruins, building restorer and object lifecycle report. |
| Aquinas | `stringtable-localization-copy-v2` | Report received | Stringtable/UI text, side messages, hints, stale copy and localization gap report. |
| Russell | `server-fsm-runtime-orchestration-v2` | Report received | Server FSM/runtime orchestration, cleanup, victory/disconnect/FPS and missing-FSM report. |
| Galileo | `common-pv-network-authority-v2` | Report received | Common/PV/network authority, SendToClient/Server, funds/message and JIP-safety report. |
| Ptolemy | `boot-include-parameter-graph-v2` | Report received | Boot/include graph, init order, parameters, constants and version/include report. |
| Boole | `commander-construction-factory-v2` | Report received | Commander, CoIn, construction, factories, service points, base destruction and buy queue report. |
| Faraday | `discord-extension-antistack-integration-discovery` | Report received | Extension, DiscordBot, AntiStack DB, BattlEye and external trust report. |
| Mencius | `parameters-config-localization-discovery` | Report received | Parameters, defaults, includes, version files and localization report. |
| Hilbert | `abandoned-code-missing-reference-discovery` | Report received | Commented compiles, missing scripts, TODOs, dead PV handlers and stale leftovers report. |
| Cicero | `ai-headless-delegation-discovery` | Report received | AI squads, autonomous teams, AI commander, HC delegation and town AI report. |
| Curie | `wiki-ux-phase2-agent-interface-discovery` | Report received | Concrete implementation checklist for human + LLM wiki UX improvements. |
| Meitner | `pr1-supply-helicopter-delta-discovery` | Report received | PR #1 supply-helicopter branch delta, deferred AI work and merge-risk report. |
| Archimedes/James | `pv-matrix-second-pass-v2` | Report received | Full PV matrix plus compact wiki table layout. |
| Wegener | `ai-commander-autonomy-second-pass-v2` | Report received | AI commander/autonomous team scheduler and dormant-worker evidence. |
| Rawls | `wiki-agent-artifact-schema-v2` | Report received | Agent-readable artifact schema proposal. |
| Goodall | `known-broken-reference-second-pass-v2` | Report received | Unified missing/stale/broken reference register. |
| Euclid | `modded-presentation-parity-v2` | Report received | Modded presentation/media/help parity report. |
| Aristotle | `supply-mission-authority-matrix-v2` | Report received | Master + PR #1 supply mission authority matrix. |

## Rotation Queue

The cheap scout wave is currently harvested. Do not spawn more scouts until at least one integration batch has landed.

| Priority | Lane | Scope |
| --- | --- | --- |
| 1 | `integration-backlog-batch-a` | PV/network trust, PV matrix, direct non-PVF events, and command-forgery cross-links. |
| 2 | `integration-backlog-batch-b` | External integrations: AntiStack DB, in-repo Extension, DiscordBot, BattlEye and missing hosting files. |
| 3 | `integration-backlog-batch-c` | Construction/factory/economy authority and commander/AI partials. |
| 4 | `integration-backlog-batch-d` | Supply mission master + PR #1 matrix, support markers and broken-reference register. |

## Reports Waiting For Integration

| Lane | Agent | Status | Integration targets |
| --- | --- | --- | --- |
| `client-jip-lifecycle-discovery` | Mencius | Report received | [Mission lifecycle](Mission-Entrypoints-And-Lifecycle), [Lifecycle wait-chain](Lifecycle-Wait-Chain), [Client UI systems atlas](Client-UI-Systems-Atlas), [Feature status](Feature-Status-Register), [`agent-context.json`](agent-context.json). |
| `economy-town-factory-upgrade-discovery` | Faraday | Report received | [Economy/towns/supply](Economy-Towns-And-Supply), [Factory/purchase atlas](Factory-And-Purchase-Systems-Atlas), [Server runtime atlas](Server-Gameplay-Runtime-Atlas), [Feature status](Feature-Status-Register), [`agent-context.json`](agent-context.json). |
| `gear-loadout-easa-balance-discovery` | Faraday | Integrated locally; publish pending | [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas), [Client UI systems atlas](Client-UI-Systems-Atlas), [Tools/build](Tools-And-Build-Workflow), [Feature status](Feature-Status-Register), [`agent-context.json`](agent-context.json). |
| `external-pdf-research-intake` | Sagan/Helmholtz/Parfit | Captured; source reconciliation pending | [External research reports](External-Research-Reports), [Feature status](Feature-Status-Register), [Deep-review findings](Deep-Review-Findings), [`agent-context.json`](agent-context.json). |
| `discord-extension-antistack-integration-discovery` | Faraday | Integrated | [External integrations](External-Integrations), [Networking/PV](Networking-And-Public-Variables), [Feature status](Feature-Status-Register), [`agent-context.json`](agent-context.json). |
| `respawn-medical-mash-support-discovery` | Mencius | Report received | [Gameplay atlas](Gameplay-Systems-Atlas), [Client UI systems atlas](Client-UI-Systems-Atlas), [Feature status](Feature-Status-Register), [`agent-context.json`](agent-context.json). |
| `server-runtime-scheduler-discovery` | Hilbert | Report received | [Server runtime atlas](Server-Gameplay-Runtime-Atlas), [AI/performance](AI-Headless-And-Performance), [Feature status](Feature-Status-Register), [`agent-context.json`](agent-context.json). |
| `abandoned-code-missing-reference-discovery` | Hilbert | Report received | [Feature status](Feature-Status-Register), [Mission lifecycle](Mission-Entrypoints-And-Lifecycle), [Networking/PV](Networking-And-Public-Variables), [`agent-context.json`](agent-context.json). |
| `server-fsm-runtime-orchestration-v2` | Russell | Report received | [Server runtime atlas](Server-Gameplay-Runtime-Atlas), [Lifecycle wait-chain](Lifecycle-Wait-Chain), [Feature status](Feature-Status-Register), [`agent-context.json`](agent-context.json). |
| `common-pv-network-authority-v2` | Galileo | Integrated | [Networking/PV](Networking-And-Public-Variables), [Deep-review findings](Deep-Review-Findings), [Function/module index](Function-And-Module-Index), [`agent-context.json`](agent-context.json). |
| `boot-include-parameter-graph-v2` | Ptolemy | Report received | [Mission lifecycle](Mission-Entrypoints-And-Lifecycle), [Lifecycle wait-chain](Lifecycle-Wait-Chain), [SQF code atlas](SQF-Code-Atlas), [`agent-context.json`](agent-context.json). |
| `commander-construction-factory-v2` | Boole | Report received | [Construction/CoIn atlas](Construction-And-CoIn-Systems-Atlas), [Factory/purchase atlas](Factory-And-Purchase-Systems-Atlas), [Client UI systems atlas](Client-UI-Systems-Atlas), [`agent-context.json`](agent-context.json). |
| `towns-camps-depots-economy-v2` | Epicurus | Report received | [Economy/towns/supply](Economy-Towns-And-Supply), [Gameplay atlas](Gameplay-Systems-Atlas), [Server runtime atlas](Server-Gameplay-Runtime-Atlas), [`agent-context.json`](agent-context.json). |
| `support-artillery-uav-paradrop-v2` | Hooke | Report received | [Gameplay atlas](Gameplay-Systems-Atlas), [Client UI systems atlas](Client-UI-Systems-Atlas), [Networking/PV](Networking-And-Public-Variables), [`agent-context.json`](agent-context.json). |
| `cleanup-maintenance-runtime-v2` | Carson | Report received | [Server runtime atlas](Server-Gameplay-Runtime-Atlas), [AI/performance](AI-Headless-And-Performance), [Feature status](Feature-Status-Register), [`agent-context.json`](agent-context.json). |
| `stringtable-localization-copy-v2` | Aquinas | Report received | [Content/maps](Content-Structure-And-Maps), [Client UI systems atlas](Client-UI-Systems-Atlas), [Feature status](Feature-Status-Register), [`agent-context.json`](agent-context.json). |
| `wiki-ux-navigation-discovery` | Curie | Report received | [Home](Home), [Quickstart](Quickstart-For-Humans-And-Agents), [Progress dashboard](Progress-Dashboard), [`agent-context.json`](agent-context.json). |
| `wiki-ux-phase2-agent-interface-discovery` | Curie | Report received | [Home](Home), [Progress dashboard](Progress-Dashboard), [Agent collaboration protocol](Agent-Collaboration-Protocol), [`agent-context.json`](agent-context.json). |
| `content-drift-generation-discovery` | Meitner | Report received | [Content/maps](Content-Structure-And-Maps), [Tools/build](Tools-And-Build-Workflow), [Feature status](Feature-Status-Register), [`agent-context.json`](agent-context.json). |
| `pr1-supply-helicopter-delta-discovery` | Meitner | Report received | [Supply mission architecture](Supply-Mission-Architecture), [Current supply-heli PR](Current-Work-Supply-Helicopters-PR1), [Feature status](Feature-Status-Register), [`agent-context.json`](agent-context.json). |
| `pv-matrix-second-pass-v2` | Archimedes/James | Integrated | [Networking/PV](Networking-And-Public-Variables), [Function/module index](Function-And-Module-Index), [`agent-context.json`](agent-context.json). |
| `ai-commander-autonomy-second-pass-v2` | Wegener | Report received | [AI/headless/performance](AI-Headless-And-Performance), [Server runtime atlas](Server-Gameplay-Runtime-Atlas), [Feature status](Feature-Status-Register). |
| `wiki-agent-artifact-schema-v2` | Rawls | Report received | [Agent collaboration protocol](Agent-Collaboration-Protocol), [Agent context](Agent-Context), [`agent-context.json`](agent-context.json). |
| `known-broken-reference-second-pass-v2` | Goodall | Report received | [Feature status](Feature-Status-Register), [Mission lifecycle](Mission-Entrypoints-And-Lifecycle), [Client UI systems atlas](Client-UI-Systems-Atlas), [Content/maps](Content-Structure-And-Maps). |
| `modded-presentation-parity-v2` | Euclid | Report received | [Content/maps](Content-Structure-And-Maps), [Client UI systems atlas](Client-UI-Systems-Atlas), [Source inventory](Source-Inventory). |
| `supply-mission-authority-matrix-v2` | Aristotle | Report received | [Supply mission architecture](Supply-Mission-Architecture), [Current supply-heli PR](Current-Work-Supply-Helicopters-PR1), [Feature status](Feature-Status-Register). |

## Integration Rules

- Scouts do not edit files, commit, push or publish.
- Codex should trust scout source citations, then spot-check high-risk claims before adding them to user-facing docs.
- Findings should land in the owning atlas page first, then in [Feature status](Feature-Status-Register), [Coverage ledger](Codebase-Coverage-Ledger), [Agent worklog](Agent-Worklog) and machine files if relevant.
- If Claude is working the same subsystem, prefer adding a handoff note instead of overwriting Claude-owned review pages.

## Continue Reading

Previous: [Progress dashboard](Progress-Dashboard) | Next: [Coordination board](Coordination-Board)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-status.json`](agent-status.json)
