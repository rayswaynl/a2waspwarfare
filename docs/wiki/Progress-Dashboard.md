# Progress Dashboard

This is the shared human + AI interface for seeing what Codex, Claude and Codex sub-agents are doing right now.

Keep this page open when parallel documentation work is running. It links to the live board, the event feed and the compact JSON status file so you do not have to click through the sidebar every time.

## Latest Batch

| Lane | Status | Output |
| --- | --- | --- |
| `agent-hardening-backlog-and-wave-f-integration` | Published | [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl), [Hardening roadmap](Hardening-Implementation-Roadmap), [Feature status](Feature-Status-Register), [Networking/PV](Networking-And-Public-Variables), [Lifecycle wait-chain](Lifecycle-Wait-Chain), [AI/headless](AI-Headless-And-Performance). |
| External report intake | Published | [`external-research-report-manifest.json`](external-research-report-manifest.json) plus [External research reports](External-Research-Reports). Raw extracted text remains local cache only. |
| Cheap discovery wave F | Harvested | PV/security, economy, AI/perf, UI, support modules, tooling, PDF triage, town-AI vehicle safety and lifecycle wait-chain checks all returned; no active sub-agent threads remain. |

## At A Glance

| Actor | Status | Current lane | What to expect next |
| --- | --- | --- | --- |
| Codex | Active | `long-running-archivist-continuation` | Keep source-backed docs, machine files and implementation backlog aligned as new findings or gameplay work appear. |
| Claude | Autonomous-ready | `autonomous-claude-research` | Can self-select the next bounded source-backed review lane from the coverage ledger or hardening backlog. |
| Sub-agents | None running | Wave F harvested | Latest scout outputs are summarized in [Discovery swarm](Subagent-Discovery-Swarm); all Wave F agents were closed after harvest. |
| Shared docs | Live | GitHub wiki + `docs/wiki` mirror | Wiki and docs mirror are kept in parity; see `agent-events.jsonl` and git history for commit IDs. |

## One-Link Check

| Need | Open |
| --- | --- |
| Human progress page | [Progress dashboard](Progress-Dashboard) |
| Sub-agent swarm board | [Discovery swarm](Subagent-Discovery-Swarm) |
| Detailed coordination page | [Coordination board](Coordination-Board) |
| Machine progress file | [`agent-status.json`](agent-status.json) |
| Active lanes and ownership | [`agent-collaboration.json`](agent-collaboration.json) |
| Agent-readable knowledge records | [`agent-knowledge.jsonl`](agent-knowledge.jsonl) |
| Agent-readable hardening backlog | [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl) |
| Latest event stream | [`agent-events.jsonl`](agent-events.jsonl) |
| Dated narrative notes | [Agent worklog](Agent-Worklog) |
| External PDF intake | [External research reports](External-Research-Reports) |
| External PDF manifest | [`external-research-report-manifest.json`](external-research-report-manifest.json) |

## Current Lanes

| Lane | Owner | Status | Meaning |
| --- | --- | --- | --- |
| `dashboard-current-state-cleanup` | Codex | Published | Progress page now shows current state first; historic scout detail lives in swarm/worklog pages. |
| `autonomous-claude-research` | Claude | Open | Claude may claim the next bounded source-backed review lane and continue independently. |
| `feature-status-reconciliation` | Codex/future agent | Open | Fold any newly confirmed findings into owning atlas/risk pages and keep machine files aligned. |
| `implementation-hardening-from-backlog` | Future code owner | Open | Pick work packages from [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl), starting with P0/P1 authority fixes or the confirmed town-AI vehicle safety bug. |

## Recent Published Work

| Batch | Output | Details |
| --- | --- | --- |
| Wave F hardening backlog | [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl) | Machine-readable work packages for PVF, ICBM, attack waves, victory, economy, supply, factory queues, markers, hosting, town AI, JIP waits, tooling and UI debt. |
| External report manifest | [`external-research-report-manifest.json`](external-research-report-manifest.json) | Sanitized metadata for the three Steff-provided PDF reports; raw extracted text is local cache only. |
| Confirmed town-AI vehicle bug | [Feature status](Feature-Status-Register), [AI/headless](AI-Headless-And-Performance) | `server_town_ai.sqf:211-216` can delete an occupied town-AI vehicle if the player is not group leader. |
| Lifecycle wait audit | [Lifecycle wait-chain](Lifecycle-Wait-Chain) | Split retrying join handshakes from no-timeout replicated-variable waits. |
| Hardening roadmap | [Hardening roadmap](Hardening-Implementation-Roadmap) | Human-readable patch order and validation gates for code owners. |

Historic scout rosters and harvested reports live in [Discovery swarm](Subagent-Discovery-Swarm) and [Agent worklog](Agent-Worklog).

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

1. Load [`agent-status.json`](agent-status.json), [`agent-collaboration.json`](agent-collaboration.json), [`agent-knowledge.jsonl`](agent-knowledge.jsonl), [`agent-events.jsonl`](agent-events.jsonl) and [Agent collaboration protocol](Agent-Collaboration-Protocol) before claiming work.
2. Treat `agent-events.jsonl` as append-only.
3. Keep claims bounded by source scope.
4. Never overwrite another agent's page or navigation changes from a stale branch.
5. Publish human notes to [Agent worklog](Agent-Worklog) and machine notes to the JSON files.

## Continue Reading

Previous: [Agent context](Agent-Context) | Next: [Coordination board](Coordination-Board)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
