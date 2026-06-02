# Agent Collaboration Protocol

This page is the current coordination contract for Codex, Claude and future agents working in the `docs/wiki` mirror. It keeps the richer machine files useful without making every agent parse the whole event history before a small docs pass.

## Read Order

Start here when choosing or resuming a lane:

1. [Agent context](Agent-Context) for project rules and source-of-truth paths.
2. `agent-status.json` for current active agents and recent machine-readable status.
3. [Coordination board](Coordination-Board) for human-readable active and completed lanes.
4. [Agent worklog](Agent-Worklog) for append-only detail and provenance.
5. `agent-events.jsonl` and `agent-collaboration.json` only when you need claim/event history or another agent appears to be active on the same lane.

## Lane Rules

Use bounded lanes. A good lane has one owner, a small source or wiki scope, clear outputs, and a validation note. Avoid broad claims such as "fix networking docs" unless you immediately narrow them to a concrete route, finding or page.

Before editing a lane that could overlap another agent:

- Check `agent-status.json` `agents.*.currentLane`.
- Check the top of [Coordination board](Coordination-Board).
- Check the tail of `agent-events.jsonl` for recent `claim`, `finding`, `complete` and `handoff` events.

If another agent owns the same lane, do not overwrite it. Pick a non-conflicting page-quality, routing, validation or source-check lane instead. If you must touch the same topic, make it a clearly separate reconcile/handoff and say what you did not change.

## What To Update

For small docs-only edits:

- Update the edited page.
- Append a concise [Agent worklog](Agent-Worklog) entry.
- Add or update the [Coordination board](Coordination-Board) row if the lane affects routing, handoff status or future work.

For machine-context or handoff changes:

- Update `agent-context.json` when page routes, rules, high-level system facts or future-agent behavior change.
- Update `agent-status.json` when active agents, recent lanes, source-of-truth surfaces or compact status changes.
- Update `agent-hardening-backlog.jsonl` when an implementation-sized future code task changes.

For code or source-backed gameplay changes:

- Edit the Chernarus source mission first.
- Propagate generated missions with `Tools/LoadoutManager` when appropriate.
- Record source-only checks separately from Arma hosted/dedicated/JIP/HC smoke.

## Event Files

`agent-events.jsonl` and `agent-collaboration.json` preserve imported and concurrent-agent state. They are useful for collision checks and machine history, but the board and worklog should remain readable enough for a human to resume the project without decoding every event row.

## Validation

After meaningful docs or machine-context edits, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\ValidateWiki.ps1
```

The validator checks JSON/JSONL parsing, page-list parity, Markdown links, selected machine references, exact machine references, retired route hygiene and `git diff --check`.

## Continue Reading

Previous: [Coordination board](Coordination-Board) | Next: [Agent worklog](Agent-Worklog)

Main map: [Home](Home) | Machine context: [`agent-context.json`](agent-context.json) | Status: [`agent-status.json`](agent-status.json)
