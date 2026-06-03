# AI Assistant Guide

Minimal first-touch page for humans and AI agents working on docs and orchestration in this repository.

## What this page is

- A compact bootstrap for discovery and safety.
- A map to the fastest trusted starting path before touching source.
- A low-risk place to confirm current truth before opening legacy or historical notes.

## Where it lives

- Wiki: `docs/wiki/AI-Assistant-Guide.md`
- Machine sources: [`agent-status.json`](agent-status.json), [`agent-events.jsonl`](agent-events.jsonl), [`agent-knowledge.jsonl`](agent-knowledge.jsonl), [`agent-collaboration.json`](agent-collaboration.json)
- Runtime source: `Missions/[55-2hc]warfarev2_073v48co.chernarus`

## Read order (fastest path)

1. [Home](Home) for map and task lanes.
2. [AI Assistant Developer Guide](AI-Assistant-Developer-Guide) for editing rules and safe edit constraints.
3. [Current source status snapshot](Current-Source-Status-Snapshot) for what is truly live in Chernarus.
4. [Feature status register](Feature-Status-Register) for patch-ready/open/hardening lanes.
5. [SQF code atlas](SQF-Code-Atlas) if you need compile-owner or runtime entrypoints.
6. [Wiki quality audit](Wiki-Quality-Audit) for bloat/duplication status.

## What it depends on

- Current-source truth must be checked before any lane claim is trusted.
- Feature risk claims in this file route to:
  - [Deep-review findings](Deep-Review-Findings)
  - [Public variable channel index](Public-Variable-Channel-Index)
  - [Feature status register](Feature-Status-Register)
  - Subsystem-specific atlases.
- Verification behavior: run `Tools/ValidateWiki.ps1` after meaningful wiki changes.

## What depends on this page

- Any Codex/Claude/LMM lane that starts with documentation, navigation, or cross-linking.
- New agents or scripts needing a deterministic boot sequence.
- Future "what should I do first" prompts.

## High-risk notes

- Gameplay source truth shifts quickly; this page is a routing surface, not an implementation spec.
- `AI-Assistant-Developer-Guide` includes rules and safety checks, while this page stays compact.
- If a fact conflicts with source-backed code, use [Current source status snapshot](Current-Source-Status-Snapshot) and source line anchors first.


## What it depends on / runs / risks

### Where it lives

- Wiki page: `AI-Assistant-Guide.md`
- Runtime source: `Missions/[55-2hc]warfarev2_073v48co.chernarus`
- Machine records: `agent-status.json`, `agent-events.jsonl`, `agent-knowledge.jsonl`

### How this page runs

- Human/agent bootstrap path.
- Validation path: `Tools/ValidateWiki.ps1` after docs changes, plus machine-parity updates when mirror checkout is updated.

### What depends on this page

- Any new wiki-only lane that needs deterministic onboarding.
- Coordination and handoff workflows via [AI-Assistant-Developer-Guide](AI-Assistant-Developer-Guide).

### What is risky

- Starting directly at subsystem pages may skip current lane state and active claims.
- Treat this as a read-path page, not an implementation specification.

### Where to go next

- [Progress dashboard](Progress-Dashboard) -> active claims + bottleneck context.
- [Feature status register](Feature-Status-Register) -> current risk ranking.
- [SQF Code Atlas](SQF-Code-Atlas) -> source registry for runtime/compile entrypoints.

## Continue reading

Previous: [Home](Home) | Next: [AI Assistant Developer Guide](AI-Assistant-Developer-Guide)

Main map: [Feature status](Feature-Status-Register) | Agent file: [`agent-context.json`](agent-context.json)
