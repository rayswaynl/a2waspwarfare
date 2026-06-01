# Progress Dashboard

This is the shared human + AI interface for seeing what Codex, Claude and Codex sub-agents are doing right now.

Keep this page open when parallel documentation work is running. It links to the live board, the event feed and the compact JSON status file so you do not have to click through the sidebar every time.

## At A Glance

| Agent | Status | Current lane | What to expect next |
| --- | --- | --- | --- |
| Codex | Integrating fleet results | `fleet-deep-index` | Validate, commit and publish first-wave sub-agent documentation updates. |
| Claude | Ready-for-review + autonomous-ready | `pvf-hardening-review` | Claude's PVF hardening playbook is ready for code-owner review; Claude may claim another bounded lane next. |
| Hilbert | Completed + integrated | `network-pv-boundary-deep-index` | PV/direct publicVariable risks integrated into Networking, Feature Status and agent context. |
| Cicero | Completed + integrated | `server-gameplay-loops-deep-index` | Server runtime findings integrated into [Server runtime atlas](Server-Gameplay-Runtime-Atlas) and Feature Status. |
| Curie | Completed + integrated | `ui-hud-dialogs-deep-index` | UI/dialog risks integrated into Client UI atlas and Feature Status. |
| Meitner | Completed + integrated | `tooling-integrations-deep-index` | Tooling/integration findings integrated into Tools, Integrations, Content Structure and agent context. |
| Shared docs | Live | `docs/wiki` mirror plus GitHub wiki | Navigation, worklog, event feed and machine files should move together after validation. |

## One-Link Check

| Need | Open |
| --- | --- |
| Human progress page | [Progress dashboard](Progress-Dashboard) |
| Detailed coordination page | [Coordination board](Coordination-Board) |
| Machine progress file | [`agent-status.json`](agent-status.json) |
| Active lanes and ownership | [`agent-collaboration.json`](agent-collaboration.json) |
| Latest event stream | [`agent-events.jsonl`](agent-events.jsonl) |
| Dated narrative notes | [Agent worklog](Agent-Worklog) |

## Current Lanes

| Lane | Owner | Status | Meaning |
| --- | --- | --- | --- |
| `factory-purchase-atlas` | Codex | Integrated | Codex published [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas). |
| `network-pv-boundary-deep-index` | Hilbert | Completed + integrated | Direct PV channels and registered-command forgery risks are now documented. |
| `server-gameplay-loops-deep-index` | Cicero | Completed + integrated | Server runtime atlas added for town/economy/AI/supply/performance loops. |
| `ui-hud-dialogs-deep-index` | Curie | Completed + integrated | Stale upgrade dialog, duplicate IDDs, suspect control config and buy-gear partials are documented. |
| `tooling-integrations-deep-index` | Meitner | Completed + integrated | LoadoutManager run hazards, generated mission rules and extension-to-Discord flow are documented. |
| `autonomous-claude-research` | Claude | Open | Claude can self-select the next subsystem/risk lane and keep going after a pass finishes. |
| `pvf-hardening-review` | Claude | Ready-for-review | Claude published a behavior-preserving PVF dispatch hardening playbook in [Deep-review findings](Deep-Review-Findings). |
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
