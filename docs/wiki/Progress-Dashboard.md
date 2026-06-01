# Progress Dashboard

This is the shared human + AI interface for seeing what Codex, Claude and Codex sub-agents are doing right now.

Keep this page open when parallel documentation work is running. It links to the live board, the event feed and the compact JSON status file so you do not have to click through the sidebar every time.

## At A Glance

| Agent | Status | Current lane | What to expect next |
| --- | --- | --- | --- |
| Codex | Active | `victory-endgame-runtime-atlas` | Mapping victory/endgame runtime, DB/log hooks and mission termination. |
| Faraday | Active read-only scout | `discord-extension-antistack-integration-discovery` | Extension, DiscordBot, AntiStack DB, BattlEye and external trust report; prior economy and gear reports await integration. |
| Mencius | Active read-only scout | `parameters-config-localization-discovery` | Parameters, defaults, includes and localization report; prior client/JIP and respawn/support reports await integration. |
| Claude | Ready-for-review + autonomous-ready | `factory-purchase-authority` | Latest completed reviews: Victory/endgame DR-11..DR-13 and Factory/purchase DR-14..DR-15 in [Deep-review findings](Deep-Review-Findings). |
| Hilbert | Active read-only scout | `abandoned-code-missing-reference-discovery` | Commented compiles, missing scripts, TODOs, dead PV handlers and stale WASP leftovers; prior server runtime report awaits integration. |
| Cicero | Active read-only scout | `ai-headless-delegation-discovery` | Reused after server pass; now reading AI squads, autonomous teams, AI commander and HC delegation. |
| Curie | Active read-only scout | `wiki-ux-phase2-agent-interface-discovery` | Concrete wiki navigation/template/dashboard implementation checklist; prior wiki UX report awaits integration. |
| Meitner | Active read-only scout | `pr1-supply-helicopter-delta-discovery` | PR #1 supply-helicopter branch delta and merge-risk report; prior content-drift report awaits integration. |
| Shared docs | Live | `docs/wiki` mirror plus GitHub wiki | Navigation, worklog, event feed and machine files should move together after validation. |

## One-Link Check

| Need | Open |
| --- | --- |
| Human progress page | [Progress dashboard](Progress-Dashboard) |
| Sub-agent swarm board | [Discovery swarm](Subagent-Discovery-Swarm) |
| Detailed coordination page | [Coordination board](Coordination-Board) |
| Machine progress file | [`agent-status.json`](agent-status.json) |
| Active lanes and ownership | [`agent-collaboration.json`](agent-collaboration.json) |
| Latest event stream | [`agent-events.jsonl`](agent-events.jsonl) |
| Dated narrative notes | [Agent worklog](Agent-Worklog) |

## Current Lanes

| Lane | Owner | Status | Meaning |
| --- | --- | --- | --- |
| `factory-purchase-atlas` | Codex | Integrated | Codex published [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas). |
| `victory-endgame-runtime-atlas` | Codex | Active | Codex is mapping win conditions, game-over flags, endgame broadcast, stats/logging, AntiStack flush and mission termination. |
| `economy-town-factory-upgrade-discovery` | Faraday | Reported, pending integration | Scout report received; Codex should integrate negative supply delta, upgrade authority, resistance supply handler gap and AI supply truck evidence. |
| `gear-loadout-easa-balance-discovery` | Faraday | Reported, pending integration | Scout report received; Codex should integrate EASA generation, gear profile hazards, CRV7PG warning metadata and balance authority gaps. |
| `discord-extension-antistack-integration-discovery` | Faraday | Active | Cheap read-only scout mapping Extension, DiscordBot, AntiStack DB calls, BattlEye filters and external trust boundaries. |
| `client-jip-lifecycle-discovery` | Mencius | Reported, pending integration | Scout report received; Codex should integrate duplicated `Skill_Init`, legacy WASP leftovers, join ACK sensitivity and respawn-loop cost. |
| `respawn-medical-mash-support-discovery` | Mencius | Reported, pending integration | Scout report received; Codex should integrate respawn source precedence, MASH marker half-wiring and support authority notes. |
| `parameters-config-localization-discovery` | Mencius | Active | Cheap read-only scout mapping parameters, defaults, includes, version files and localization/string resources. |
| `server-runtime-scheduler-discovery` | Hilbert | Reported, pending integration | Scout report received; Codex should integrate cleanup loops, FPS publishers, inverse sleep risk and missing supplytruck FSM evidence. |
| `abandoned-code-missing-reference-discovery` | Hilbert | Active | Cheap read-only scout mapping commented compiles, missing scripts, TODO/FIXME, dead PV handlers and stale leftovers. |
| `ai-headless-delegation-discovery` | Cicero | Active | Cheap read-only scout mapping AI teams, AI commander, HC delegation and town AI lifecycle. |
| `wiki-ux-navigation-discovery` | Curie | Reported, pending integration | Scout report received; Codex should add task-oriented navigation, related-page blocks and a dashboard mini-panel. |
| `wiki-ux-phase2-agent-interface-discovery` | Curie | Active | Cheap read-only scout turning wiki UX findings into a concrete implementation checklist. |
| `content-drift-generation-discovery` | Meitner | Reported, pending integration | Scout report received; Codex should integrate source/generated/stale mission folder and generation-rule findings. |
| `pr1-supply-helicopter-delta-discovery` | Meitner | Active | Cheap read-only scout mapping PR #1 supply-helicopter branch delta, deferred AI work and merge risks. |
| `network-pv-boundary-deep-index` | Hilbert | Completed + integrated | Direct PV channels and registered-command forgery risks are now documented. |
| `server-gameplay-loops-deep-index` | Cicero | Completed + integrated | Server runtime atlas added for town/economy/AI/supply/performance loops. |
| `ui-hud-dialogs-deep-index` | Curie | Completed + integrated | Stale upgrade dialog, duplicate IDDs, suspect control config and buy-gear partials are documented. |
| `tooling-integrations-deep-index` | Meitner | Completed + integrated | LoadoutManager run hazards, generated mission rules and extension-to-Discord flow are documented. |
| `autonomous-claude-research` | Claude | Open | Claude can self-select the next subsystem/risk lane and keep going after a pass finishes. |
| `pvf-hardening-review` | Claude | Ready-for-review | Claude published a behavior-preserving PVF dispatch hardening playbook in [Deep-review findings](Deep-Review-Findings). |
| `victory-endgame-review` | Claude | Ready-for-review | Claude published DR-11..DR-13 on winner inversion, broken threeway mode and stale `LogGameEnd`. |
| `factory-purchase-authority` | Claude | Ready-for-review | Claude published DR-14..DR-15 on client-authoritative purchasing and the commander assignment bug. |
| `feature-status-reconciliation` | Codex | Open | Codex should keep folding confirmed findings into owning atlas/risk pages. |

## Update Ritual

| Moment | Codex / Claude action | Human-visible result |
| --- | --- | --- |
| Starting work | Update `agent-collaboration.json` and append a `claim` event. | This dashboard and the coordination board show who owns what. |
| Still working after a long pass | Append a `heartbeat` event. | You can see that an agent is alive and where it is reading. |
| Finding a source-backed issue | Append a `finding` event and add a short worklog note. | The finding is visible even before the full page is integrated. |
| Finishing a lane | Append a `complete` event, update affected pages and note validation status. | The lane moves from active to ready/integrated. |
| Handing off | Append a `handoff` event with the exact next action. | The other agent can pick it up without chat memory. |

## Status Legend

| Status | Meaning |
| --- | --- |
| `active` | Someone is working this lane now. |
| `open` | Available for an agent to claim. |
| `ready-for-review` | Work exists but should be checked before publishing or relying on it. |
| `integrated` | Published into the wiki/docs set and reflected in navigation/context. |
| `blocked` | Needs user input, missing access or an external state change. |

## For Agents

1. Load [`agent-status.json`](agent-status.json), [`agent-collaboration.json`](agent-collaboration.json), [`agent-events.jsonl`](agent-events.jsonl) and [Agent collaboration protocol](Agent-Collaboration-Protocol) before claiming work.
2. Treat `agent-events.jsonl` as append-only.
3. Keep claims bounded by source scope.
4. Never overwrite another agent's page or navigation changes from a stale branch.
5. Publish human notes to [Agent worklog](Agent-Worklog) and machine notes to the JSON files.

## Continue Reading

Previous: [Agent context](Agent-Context) | Next: [Coordination board](Coordination-Board)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
