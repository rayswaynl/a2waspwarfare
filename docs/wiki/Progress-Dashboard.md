# Progress Dashboard

This is the shared human + AI interface for seeing what Codex, Claude and Codex sub-agents are doing right now.

Keep this page open when parallel documentation work is running. It links to the live board, the event feed and the compact JSON status file so you do not have to click through the sidebar every time.

## Latest Batch

| Lane | Status | Output |
| --- | --- | --- |
| `attack-wave-authority-playbook` | Ready to publish | [Attack-wave authority playbook](Attack-Wave-Authority-Playbook) turns DR-41 into an implementation-ready patch guide, including server recomputation, duplicate rejection, modifier clamps and the all-side-supply spend model. |
| `attack-wave-authority-dr41` | Playbook published | DR-41 is now cross-linked from [Networking/PV](Networking-And-Public-Variables), [Hardening roadmap](Hardening-Implementation-Roadmap), [Economy](Economy-Towns-And-Supply), [Feature status](Feature-Status-Register), [Server authority map](Server-Authority-Migration-Map), [Attack-wave authority playbook](Attack-Wave-Authority-Playbook) and [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl). |
| `server-authority-migration-map` | Published | [Server authority map](Server-Authority-Migration-Map) consolidates client-trusted and payload-trusted gameplay flows into one migration plan. |
| `testing-debugging-release-workflow` | Drafted | [Testing workflow](Testing-Debugging-And-Release-Workflow) and [`agent-test-plan.schema.json`](agent-test-plan.schema.json) define validation levels, smoke packs and machine-readable test evidence. |
| `lifecycle-runtime-readout` | Verified | Anscombe report source-checked against `Missions/[55-2hc]...`; lifecycle pages now document mission-object town init and HC timing caveat. |
| `town-ai-vehicle-despawn-safety` | Published | [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety) turns the confirmed occupied-vehicle delete bug into a source-backed patch plan and validation checklist. |
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
| `town-ai-vehicle-despawn-safety` | Codex/future code owner | Playbook published | The confirmed occupied-vehicle deletion bug now has a dedicated implementation playbook; next step is a gameplay patch in the Chernarus source mission when code work is claimed. |
| `attack-wave-authority-dr41` | Future code owner | Playbook published | `ATTACK_WAVE_INIT` is confirmed high-risk; use [Attack-wave authority playbook](Attack-Wave-Authority-Playbook), [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl) and [Server authority map](Server-Authority-Migration-Map) before patching. |
| `server-authority-migration-map` | Codex/future code owner | Published | Use the map before patching PVF dispatch, ICBM, economy, supply, support or BattlEye-sensitive authority flows. |
| `testing-debugging-release-workflow` | Codex/future agent | Drafted | Publish and use the test workflow to distinguish source-only review from hosted/dedicated/JIP/HC smoke evidence. |
| `autonomous-claude-research` | Claude | Open | Claude may claim the next bounded source-backed review lane and continue independently. |
| `feature-status-reconciliation` | Codex/future agent | Open | Fold any newly confirmed findings into owning atlas/risk pages and keep machine files aligned. |
| `implementation-hardening-from-backlog` | Future code owner | Open | Pick work packages from [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl), starting with P0/P1 authority fixes or the confirmed town-AI vehicle safety bug. |

## Recent Published Work

| Batch | Output | Details |
| --- | --- | --- |
| Attack-wave authority playbook | [Attack-wave authority playbook](Attack-Wave-Authority-Playbook), [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl), [`agent-context.json`](agent-context.json) | Adds the DR-41 patch shape future code owners need: treat `ATTACK_WAVE_INIT` as request data, re-derive real side supply server-side, reject bad/duplicate requests, clamp modifier/duration and preserve all-current-side-supply spend unless design changes are approved. |
| DR-41 attack-wave authority | [Networking/PV](Networking-And-Public-Variables), [Hardening roadmap](Hardening-Implementation-Roadmap), [Economy](Economy-Towns-And-Supply), [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl) | Claude's source-verified direct-PV finding is now promoted from scout candidate to confirmed high-priority backlog item. |
| Server authority map | [Server authority map](Server-Authority-Migration-Map) | Source-backed migration table and handler checklist for moving trusted-client flows toward server-owned authority. |
| Testing workflow | [Testing workflow](Testing-Debugging-And-Release-Workflow), [`agent-test-plan.schema.json`](agent-test-plan.schema.json) | Adds validation levels, system test matrix, static checks, RPT logging conventions, smoke packs, release gates and a machine-readable test evidence schema. |
| Lifecycle source verification | [Mission lifecycle](Mission-Entrypoints-And-Lifecycle), [Lifecycle wait-chain](Lifecycle-Wait-Chain) | Verified Anscombe's report, corrected the `Migrations` typo to `Missions`, and promoted mission-object town init plus HC `sleep 20` timing boundary. |
| Town-AI safety playbook | [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety) | Source chain, exact failure condition, SQF-safe guard shape and smoke-test gates for `server_town_ai.sqf:211-216`. |
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
