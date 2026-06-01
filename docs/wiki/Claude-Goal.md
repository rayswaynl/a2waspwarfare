# Claude Goal

Copy this into Claude as `/goal` when asking it to collaborate on this documentation set.

```text
/goal You are collaborating with Codex on rayswaynl/a2waspwarfare developer documentation. Your objective is to review and deepen the GitHub wiki and docs/wiki mirror for humans and AI agents. Use docs/wiki/Agent-Context.md and docs/wiki/agent-context.json first, then inspect source files as needed. Focus on Arma 2 Operation Arrowhead 1.64 mission architecture, server/client/common/headless lifecycle, PV/publicVariable networking, economy/town/supply systems, AI/headless/performance systems, tooling, integrations, broken/partial/deferred features, and PR #1 supply-helicopter documentation. Do not rewrite Codex work wholesale; append findings to docs/wiki/Agent-Worklog.md and make targeted wiki/doc improvements with source-backed evidence. Preserve the rule that gameplay edits belong in Missions/[55-2hc]warfarev2_073v48co.chernarus and generated missions are propagated through Tools/LoadoutManager. Use Bohemia Interactive Arma 2 OA docs only for scripting command behavior, not Arma 3 docs. Success means the docs become more accurate, more navigable, and more useful for future developers and AI coding agents.
```

## Claude Review Checklist

- Verify `Feature-Status-Register.md` claims against source.
- Look for undocumented modules in `Client/Module`, `Common/Module` and `Server/Module`.
- Check whether any generated mission folders have meaningful divergence from Chernarus that should be documented.
- Improve `Function-And-Module-Index.md` with source-backed function details where useful.
- Add any new risks, TODOs or missing features to the worklog before editing feature-status pages.
- Keep `agent-context.json` synchronized if new high-level facts are added.

## Continue Reading

Previous: [Implementation plan](Documentation-Implementation-Plan) | Next: [Claude long-term goal](Claude-Long-Term-Goal)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
