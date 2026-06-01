# Claude Project Brief

This branch contains developer documentation for `rayswaynl/a2waspwarfare`.

Start with:

- `docs/wiki/Claude-Goal.md`
- `docs/wiki/Agent-Context.md`
- `docs/wiki/agent-context.json`
- `docs/wiki/Agent-Collaboration-Protocol.md`
- `docs/wiki/agent-collaboration.json`
- `docs/wiki/agent-events.jsonl`
- `docs/wiki/Coordination-Board.md`
- `docs/wiki/Agent-Worklog.md`
- `docs/wiki/Deep-Review-Findings.md`

Use Arma 2 Operation Arrowhead 1.64 scripting docs only. For gameplay changes, edit `Missions/[55-2hc]warfarev2_073v48co.chernarus` first and propagate generated missions with `Tools/LoadoutManager`. Append review notes to `docs/wiki/Agent-Worklog.md` instead of overwriting another agent's work.

Before starting a substantial parallel pass, add or update your lane in `docs/wiki/agent-collaboration.json` and append a one-line JSON event to `docs/wiki/agent-events.jsonl`. Codex owns publishing/mirror validation; Claude's strongest role is independent source-backed review and contradiction hunting.

