# Coordination Board

This board lets Codex, Claude and future assistants coordinate without relying on chat memory.

## Shared Goal

Create and maintain a deep developer wiki for `rayswaynl/a2waspwarfare`, covering architecture, mission/server systems, tooling, integrations, performance work, broken/partial/deferred features, PR #1 supply helicopters, and agent-ready development context.

## Roles

| Agent | Current ownership | Expected output |
| --- | --- | --- |
| Codex | Initial wiki implementation, repo/wiki publishing, source inventory, agent context artifact. | Wiki pages, `docs/wiki` mirror, `agent-context.json`, worklog entry. |
| Claude | Independent review/deepening pass, contradiction hunting and subsystem archaeology. | Add findings to `Agent-Worklog.md`; propose or commit targeted wiki improvements without overwriting Codex work. |
| Future agents | Feature-specific docs upkeep and code-change handoffs. | Update relevant wiki pages and `agent-context.json` when architecture or workflows change. |

## Shared Files

- `docs/wiki/Agent-Context.md`: human-readable AI context.
- `docs/wiki/agent-context.json`: machine-readable repo map and safe-development facts.
- `docs/wiki/Claude-Goal.md`: copy/paste `/goal` for Claude.
- `docs/wiki/Claude-Long-Term-Goal.md`: complementary long-running Claude goal.
- `docs/wiki/Documentation-Implementation-Plan.md`: implementation roadmap for future documentation passes.
- `docs/wiki/SQF-Code-Atlas.md`: source-backed compile registry, PVF contract and direct publicVariable map.
- `docs/wiki/Agent-Worklog.md`: append-only agent-visible worklog.
- `docs/wiki/Feature-Status-Register.md`: open risks, partial features and missing features.

## Coordination Rules

- Append worklog entries instead of replacing another agent's notes.
- Link claims to source files or wiki pages.
- Keep gameplay-code changes out of documentation-only branches unless explicitly requested.
- If changing mission code later, edit Chernarus source and run LoadoutManager propagation.
- When an agent finds a contradiction, record it in `Agent-Worklog.md` and update the affected wiki page.

## Review Gates

- Wiki pages link-check cleanly.
- `docs/wiki` mirror matches the wiki pages.
- `agent-context.json` stays valid JSON.
- Any broken/partial feature claim cites concrete source evidence.
- No Arma 3-only scripting assumptions are introduced.

