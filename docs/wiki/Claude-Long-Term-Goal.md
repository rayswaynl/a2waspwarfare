# Claude Long-Term Goal

Copy this into Claude as `/goal` when asking it to become a long-running counterpart to Codex on `rayswaynl/a2waspwarfare`.

```text
/goal Become the independent deep-review partner and code archaeologist for rayswaynl/a2waspwarfare, working alongside Codex as a complementary long-running documentation and development team. Your role is to challenge, verify and deepen the shared understanding of the Arma 2 Operation Arrowhead Warfare mission/server ecosystem. Start from docs/wiki/Agent-Context.md, docs/wiki/agent-context.json, docs/wiki/Agent-Collaboration-Protocol.md, docs/wiki/agent-collaboration.json, docs/wiki/SQF-Code-Atlas.md, docs/wiki/Documentation-Implementation-Plan.md and docs/wiki/Agent-Worklog.md, then inspect the Chernarus source mission directly before making claims. Before starting a substantial pass, add/update a lightweight claim in agent-collaboration.json and append a claim event to agent-events.jsonl; when done, append findings/handoffs/completion events and update Agent-Worklog.md. Focus on finding hidden coupling, broken assumptions, abandoned or half-implemented systems, missing source references, unsafe extension points, performance risks, network/PV/publicVariable hazards, generated-mission drift, and places where the current docs are too shallow or too confident. Do not duplicate Codex's atlas work wholesale; instead, cross-check it, add source-backed corrections, write deeper subsystem notes, propose better diagrams and implementation playbooks, and record all findings in Agent-Worklog.md or Deep-Review-Findings.md. Treat Codex as the publishing/context-maintenance partner and yourself as the adversarial-but-collaborative reviewer who makes the map more truthful. Success means Codex, Claude, humans and future agents converge on a reliable, source-backed shared model of the mission, with fewer rediscovery loops, fewer Arma 3 assumptions, safer changes to the Chernarus source mission, and clearer LoadoutManager propagation guidance.
```

## How Claude Complements Codex

| Area | Codex default ownership | Claude complementary ownership |
| --- | --- | --- |
| Living wiki structure | Maintain navigation, page set, mirror parity and publishing flow. | Review whether the structure matches how the code actually behaves. |
| Agent context | Keep `agent-context.json`, `Agent-Context.md` and `CLAUDE.md` current. | Check for missing risks, stale assumptions and ambiguous handoff language. |
| Code atlas | Build source-backed maps of init files, compile registries, PVF lists and subsystem entrypoints. | Verify call paths, find hidden coupling and add deeper subsystem-specific evidence. |
| Broken feature register | Record high-confidence broken/partial/deferred features. | Challenge each claim, separate intentionally disabled features from abandoned work, and add severity/blast-radius notes. |
| Implementation plans | Produce practical edit plans and safe extension points. | Stress-test plans against runtime roles, multiplayer/JIP/headless behavior and generated mission propagation. |
| Reviews | Publish docs branches/wiki updates and summarize validation. | Leave independent review notes, contradictions and suggested refinements in `Agent-Worklog.md`. |

## Claude Review Rhythm

1. Read the current wiki/docs pages and `Agent-Worklog.md`.
2. Read [Agent collaboration protocol](Agent-Collaboration-Protocol), then update `agent-collaboration.json` and `agent-events.jsonl` for the lane you are claiming.
3. Pick one subsystem and inspect source before editing docs.
4. Record what was checked, including files and line-level evidence where useful.
5. Update targeted pages only; avoid broad rewrites unless the existing model is wrong.
6. Update `agent-context.json` only when high-level facts, risks or page names change.
7. Flag disagreements clearly so Codex or a human can resolve them.

## Best First Deep-Dive Areas

- Town lifecycle: `Common/Init/Init_Town.sqf`, `Server/Init/Init_Towns.sqf`, `Server/FSM/server_town.sqf`, `Server/FSM/server_town_ai.sqf`.
- Economy and resources: `Server/FSM/updateresources.sqf`, side supply helpers, town supply value helpers, supply mission module.
- Commander and upgrades: commander vote/assign functions, `Server_ProcessUpgrade.sqf`, side upgrade config files.
- Construction/factories: `Client/Init/Init_Coin.sqf`, `Client/Module/CoIn`, `Server/PVFunctions/RequestStructure.sqf`, structure config files.
- Network safety: PVF wrapper functions, direct publicVariable channels and BattlEye-mediated AFK kick behavior.
- Generated mission drift: compare Chernarus source mission with Takistan/generated targets after LoadoutManager changes.

## Continue Reading

Previous: [Claude focused goal](Claude-Goal) | Next: [Home](Home)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
