# Documentation Implementation Plan

The execution roadmap for the developer wiki. The initial build-out is **complete** — every workstream below shipped its first pass and now has a canonical owner page. This page is kept as a compact map of *what was planned and where it landed*; do day-to-day work on the owner pages, not here.

## Goal

Maintain an extensive, source-backed developer documentation set for `rayswaynl/a2waspwarfare` covering architecture, runtime lifecycle, mission/server systems, functions, optimizations, broken/partial features and safe development conventions.

## Published Artifacts

- GitHub wiki: canonical rendered documentation.
- `docs/wiki`: repo mirror for review, diffs and AI context loading.
- `docs/wiki/agent-context.json`: compact machine-readable map for agents.
- `CLAUDE.md` / [LLM agent entry pack](LLM-Agent-Entry-Pack): root handoff for Claude and other assistants.

## Workstream status and owners

| # | Workstream | Status | Canonical owner page(s) |
| --- | --- | --- | --- |
| 1 | Architecture coverage | Initial pass complete | [Architecture overview](Architecture-Overview), [Mission entrypoints](Mission-Entrypoints-And-Lifecycle), [Lifecycle wait-chain](Lifecycle-Wait-Chain) |
| 2 | Function & module indexing | Compile/PVF atlas done; per-function indexing ongoing | [SQF code atlas](SQF-Code-Atlas), [Function and module index](Function-And-Module-Index) |
| 3 | Broken / partial / deferred features | First register complete; verify rows at source before treating as a backlog | [Feature status](Feature-Status-Register), [Deep-review findings](Deep-Review-Findings), [Hardening roadmap](Hardening-Implementation-Roadmap) |
| 4 | PR #1 supply helicopters | Documented, pending code merge/review | [Current supply heli PR](Current-Work-Supply-Helicopters-PR1), [Supply mission architecture](Supply-Mission-Architecture) |
| 5 | Tooling, build & external runtime | Initial pass complete | [Tools and build workflow](Tools-And-Build-Workflow), [PerformanceAuditAnalyzer](PerformanceAuditAnalyzer), [External integrations](External-Integrations) |
| 6 | Agent collaboration | Coordination files in place | [Agent collaboration protocol](Agent-Collaboration-Protocol), [Coordination board](Coordination-Board), [`agent-context.json`](agent-context.json) |
| 7 | Mission hardening plans | First roadmap published | [Hardening implementation roadmap](Hardening-Implementation-Roadmap), [Pending owner decisions](Pending-Owner-Decisions) |

The operating contract (relevance rules, validation gates, "definition of done" for a docs pass) is owned by [Instructions for Codex](Instructions-For-Codex); the live loop is [Claude loop goal](Claude-Loop-Goal). This page no longer restates them.

## Continue Reading

Previous: [Deep-review findings](Deep-Review-Findings) | Next: [Claude focused goal](Claude-Goal)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
