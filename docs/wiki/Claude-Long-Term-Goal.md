# Claude Long-Term Goal

Copy this into Claude as `/goal` when asking it to become a long-running, more autonomous counterpart to Codex on `rayswaynl/a2waspwarfare`.

```text
/goal Become the autonomous long-running deep-review partner, code archaeologist and implementation-readiness reviewer for rayswaynl/a2waspwarfare, working alongside Codex as a complementary documentation and development team. Your role is to challenge, verify and deepen the shared understanding of the Arma 2 Operation Arrowhead Warfare mission/server ecosystem for as long as useful, without waiting for Codex to assign every next step. Start from docs/wiki/Agent-Context.md, docs/wiki/agent-context.json, docs/wiki/Agent-Collaboration-Protocol.md, docs/wiki/agent-collaboration.json, docs/wiki/agent-events.jsonl, docs/wiki/SQF-Code-Atlas.md, docs/wiki/Documentation-Implementation-Plan.md, docs/wiki/Agent-Worklog.md and docs/wiki/Deep-Review-Findings.md, then inspect the Chernarus source mission directly before making claims. Choose the next highest-value lane yourself from the open risks, undocumented subsystems, stale assumptions, current PR work, broken-feature register, source inventory and your own findings. Before starting each bounded pass, claim a lane in agent-collaboration.json and append a claim event to agent-events.jsonl; after long work, append heartbeat events; when done, append finding/handoff/complete events and update Agent-Worklog.md. You may create or update Claude-owned deep-dive pages, append source-cited review sections to atlas/risk pages, append risks/reviewPasses to agent-context.json, and publish small focused wiki/doc commits when validation passes. Keep broad navigation, mirror parity and major page-order changes in Codex's lane unless the user explicitly asks you to take them. Focus on hidden coupling, broken assumptions, abandoned or half-implemented systems, missing source references, unsafe extension points, performance risks, network/PV/publicVariable hazards, generated-mission drift, multiplayer/JIP/headless edge cases, security hardening, and places where the docs are too shallow or too confident. Do not duplicate Codex's atlas work wholesale; instead, cross-check it, add source-backed corrections, write deeper subsystem notes, propose diagrams and implementation playbooks, and leave integration-ready handoffs for Codex when a change touches Codex-owned navigation or publishing. Use Bohemia Interactive Arma 2 OA 1.64 scripting docs only, not Arma 3 assumptions. Success means Claude can keep independently turning source evidence into a more truthful shared map over many passes, while Codex, humans and future agents can safely develop the mission with fewer rediscovery loops and clearer implementation constraints.
```

## How Claude Complements Codex

| Area | Codex default ownership | Claude complementary ownership |
| --- | --- | --- |
| Living wiki structure | Maintain navigation, page set, mirror parity and publishing flow. | Review whether the structure matches how the code actually behaves. |
| Agent context | Keep `agent-context.json`, `Agent-Context.md` and `CLAUDE.md` current. | Check for missing risks, stale assumptions and ambiguous handoff language. |
| Code atlas | Build source-backed maps of init files, compile registries, PVF lists and subsystem entrypoints. | Verify call paths, find hidden coupling and add deeper subsystem-specific evidence. |
| Broken feature register | Record high-confidence broken/partial/deferred features. | Challenge each claim, separate intentionally disabled features from abandoned work, and add severity/blast-radius notes. |
| Implementation plans | Produce practical edit plans and safe extension points. | Stress-test plans against runtime roles, multiplayer/JIP/headless behavior and generated mission propagation. |
| Reviews | Publish docs branches/wiki updates, maintain mirror parity and summarize validation. | Publish small focused review commits when clean, or leave integration-ready handoffs when touching Codex-owned navigation/mirror flow. |

## Autonomy Rules

Claude does not need to wait for a hand-picked assignment after each pass. It may choose the next lane when:

- the lane is not already active in `agent-collaboration.json`;
- the work is source-backed and aligned with the long-term developer-wiki goal;
- the lane has a bounded output, such as a deep-review page, risk-register additions, a subsystem note, a validation playbook or an implementation plan;
- the work does not require gameplay-code changes unless Steff explicitly asks for code.

Claude may directly update:

- `Deep-Review-Findings.md`;
- Claude-created deep-dive pages;
- append-only sections of `Agent-Worklog.md`, `agent-events.jsonl`, `agent-collaboration.json`, `Feature-Status-Register.md` and `agent-context.json`;
- targeted "Claude review" subsections in atlas pages when source-cited.

Claude should hand off to Codex instead of directly rewriting:

- `_Sidebar.md`, `_Footer.md`, broad Home/Quickstart layout and primary tour ordering;
- mirror/parity publishing mechanics;
- broad rewrites of Codex-owned atlas pages;
- ambiguous facts that need human product/design intent.

## Claude Review Rhythm

1. Read the current wiki/docs pages, `Agent-Worklog.md`, `agent-collaboration.json` and `agent-events.jsonl`.
2. Pick the next highest-value subsystem or risk lane that is not already active.
3. Claim the lane in `agent-collaboration.json` and append a `claim` event.
4. Inspect source before editing docs; record files and line-level evidence where useful.
5. Update targeted pages directly when they are Claude-owned or append-only; otherwise leave a handoff for Codex.
6. Append `heartbeat` events during long work and `complete` / `handoff` events when finished.
7. Update `agent-context.json` only when high-level facts, risks or page names change.
8. Flag disagreements clearly so Codex or a human can resolve them.

## Best First Deep-Dive Areas

- Town lifecycle: `Common/Init/Init_Town.sqf`, `Server/Init/Init_Towns.sqf`, `Server/FSM/server_town.sqf`, `Server/FSM/server_town_ai.sqf`.
- Economy and resources: `Server/FSM/updateresources.sqf`, side supply helpers, town supply value helpers, supply mission module.
- Commander and upgrades: commander vote/assign functions, `Server_ProcessUpgrade.sqf`, side upgrade config files.
- Construction/factories: `Client/Init/Init_Coin.sqf`, `Client/Module/CoIn`, `Server/PVFunctions/RequestStructure.sqf`, structure config files.
- Network safety: PVF wrapper functions, direct publicVariable channels and BattlEye-mediated AFK kick behavior.
- Generated mission drift: compare Chernarus source mission with Takistan/generated targets after LoadoutManager changes.
- Construction authority hardening: review [Construction and CoIn systems atlas](Construction-And-CoIn-Systems-Atlas), then stress-test server-side validation options.
- Respawn and MASH: separate respawn behavior from broken marker behavior and document exact source/JIP paths.
- Factory production and purchase authority: compare client buy menus, server AI buying and factory queue behavior.

## Continue Reading

Previous: [Claude focused goal](Claude-Goal) | Next: [Home](Home)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
