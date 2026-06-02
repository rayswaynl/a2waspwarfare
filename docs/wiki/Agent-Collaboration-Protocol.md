# Agent Collaboration Protocol

This page is the working agreement for Codex, Claude and future assistants. It exists so parallel review work can stay useful instead of turning into branch archaeology.

## Goal

Keep the documentation and source analysis moving in parallel while preserving source-backed evidence, avoiding duplicate work and making every handoff readable by both humans and LLMs.

## Source Of Truth

| Need | File |
| --- | --- |
| One-page progress view | [Progress dashboard](Progress-Dashboard) |
| Compact progress snapshot | [`agent-status.json`](agent-status.json) |
| Human coordination | [Coordination board](Coordination-Board) |
| Append-only narrative log | [Agent worklog](Agent-Worklog) |
| Machine-readable repo context | [`agent-context.json`](agent-context.json) |
| Machine-readable collaboration state | [`agent-collaboration.json`](agent-collaboration.json) |
| Machine-readable source knowledge records | [`agent-knowledge.jsonl`](agent-knowledge.jsonl) |
| Append-only event feed | [`agent-events.jsonl`](agent-events.jsonl) |
| Claude-focused instructions | [Claude long-term goal](Claude-Long-Term-Goal) |
| Independent review findings | [Deep-review findings](Deep-Review-Findings) |

## Roles

| Agent | Primary lane | Avoid |
| --- | --- | --- |
| Codex | Wiki structure, navigation, source atlas pages, publishing, validation, final integration. | Blindly merging stale Claude branches over newer navigation. |
| Claude | Autonomous adversarial review, contradiction hunting, subsystem archaeology, source-cited findings and focused deep-dive pages. | Rewriting broad navigation/publishing pages or Codex-owned atlas structure without handoff. |
| Future agents | Focused feature/docs/code work from the current board. | Trusting chat memory over the synced files above. |

## Claim Protocol

Before starting a substantial pass:

1. Read [Quickstart](Quickstart-For-Humans-And-Agents), [Agent context](Agent-Context), [`agent-context.json`](agent-context.json), this page and [Coordination board](Coordination-Board).
2. Add or update one claim in [`agent-collaboration.json`](agent-collaboration.json).
3. Append a `claim` event to [`agent-events.jsonl`](agent-events.jsonl).
4. Work in a lane that does not overlap another active claim unless the board says it is a review lane.
5. If visible ownership changes, update [Progress dashboard](Progress-Dashboard) and [`agent-status.json`](agent-status.json).
6. When done, append to [Agent worklog](Agent-Worklog), add a `complete` event and update affected wiki pages.

Claims are intentionally lightweight. They are there to prevent duplicated sweeps and stale merges, not to create ceremony.

Claude may self-select the next lane from open risks, undocumented subsystems or stale assumptions. Codex does not need to pre-assign every pass. Broad navigation, mirror parity and primary tour ordering remain Codex-owned unless the user says otherwise.

## Event Types

Use one JSON object per line in `agent-events.jsonl`.

| Type | When |
| --- | --- |
| `claim` | Agent starts a bounded pass. |
| `heartbeat` | Agent is still working after a long pass. |
| `finding` | Agent confirms a source-backed issue or contradiction. |
| `handoff` | Agent leaves work for another agent. |
| `complete` | Agent finishes a bounded pass. |
| `sync` | Codex or Claude integrates another agent's work. |

Example:

```json
{"ts":"2026-06-01T21:23:39+02:00","agent":"Codex","type":"claim","lane":"construction-coin-atlas","status":"active","summary":"Deep-read construction and CoIn flow; publish atlas and update risks."}
```

## Knowledge Records

`agent-knowledge.jsonl` is the agent-friendly development artifact. It is appendable JSONL, but it is not an event log. Use it for durable facts and leads that future assistants should be able to query without re-reading every wiki page.

Required fields:

| Field | Meaning |
| --- | --- |
| `id` | Stable unique record id. |
| `type` | `source_document`, `topic_cluster`, `claim`, `gap`, `crosswalk` or `handoff`. |
| `topic` | Short topic bucket such as `pv-network-trust` or `ui-hud-dialogs`. |
| `summary` | One narrow claim or lead. |
| `sourceRefs` | Paths plus page/line where available. |
| `wikiTargets` | Pages that own the topic. |
| `provenanceClass` | `repo_verified`, `wiki_corroborated`, `external_corroboration` or `hypothesis`. |
| `status` | `indexed`, `confirmed`, `open`, `needs_repo_check`, `integrated` or `deferred`. |
| `confidence` | `high`, `medium` or `low`. |
| `nextAction` | Exact action for the next agent. |

Rule: external PDFs can corroborate, but they do not create canonical claims by themselves. A `claim` should be `repo_verified`; otherwise keep it as a `gap` or `hypothesis`.

## Branch And Merge Rules

| Situation | Rule |
| --- | --- |
| Claude branch is older than `docs/developer-wiki-index` | Cherry-pick findings or copy specific pages; do not merge away newer pages. |
| Wiki has direct commits not in docs mirror | Copy wiki pages back into `docs/wiki`, then validate parity. |
| Docs mirror has new pages | Copy to wiki before publishing; validate internal links. |
| Two agents touched the same topic | Preserve both source-cited findings, then reconcile in the owning atlas page. |
| A finding lacks a source path | Keep it in worklog as a hypothesis until verified. |
| Claude finishes a lane and sees another high-value lane | Claim the next lane and continue, as long as it is bounded and source-backed. |

## Handoff Format

Use this shape in `agent-collaboration.json` and summarize it in [Agent worklog](Agent-Worklog):

| Field | Meaning |
| --- | --- |
| `lane` | Short stable name, for example `pvf-hardening-review`. |
| `owner` | `Codex`, `Claude` or another agent name. |
| `status` | `active`, `blocked`, `ready-for-review`, `integrated`, `deferred`. |
| `sourceScope` | Paths, pages or branches being reviewed. |
| `outputs` | Pages/files expected from the pass. |
| `handoff` | Exact next action for another agent. |

## Review Gates

Before publishing or telling Steff the docs are synced:

- `docs/wiki` and the wiki checkout match for shared files.
- `agent-context.json` and `agent-collaboration.json` parse as JSON.
- Internal wiki links resolve to existing pages or files.
- New broken/partial-feature claims cite concrete source evidence.
- New scripting claims avoid Arma 3-only behavior.
- `Agent-Worklog.md` has a dated entry for the pass.
- `Progress-Dashboard.md` and `agent-status.json` reflect current active lanes when ownership changes.

## Continue Reading

Previous: [Coordination board](Coordination-Board) | Next: [Agent worklog](Agent-Worklog)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
