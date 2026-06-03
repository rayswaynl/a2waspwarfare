# LLM Agent Entry Pack

Use this page when starting a compact Codex, Claude or other LLM session against this wiki.

## Load Order

| Step | Read | Why |
| --- | --- | --- |
| 1 | [Home](Home) | Main route map and current task paths. |
| 2 | [Agent context](Agent-Context) and [`agent-context.json`](agent-context.json) | Human and machine-readable repo brief. |
| 3 | [Progress dashboard](Progress-Dashboard) and [`agent-status.json`](agent-status.json) | Current lane state and handoffs. |
| 4 | [Coordination board](Coordination-Board), [Agent worklog](Agent-Worklog) and [`agent-events.jsonl`](agent-events.jsonl) | Collision checks and recent activity. |
| 5 | [Current source status snapshot](Current-Source-Status-Snapshot) | Current source/Vanilla truth for recently disputed patch-ready lanes. |
| 6 | [Arma 2 OA external reference guide](Arma-2-OA-External-Reference-Guide) | Official-reference gateway before making engine claims. |
| 7 | [Arma 2 OA compatibility audit](Arma-2-OA-Compatibility-Audit) | Recently checked Arma 3-era assumptions and remaining OA runtime caveats. |

## Safe Defaults

| Rule | Detail |
| --- | --- |
| Source-first | Verify claims against the repo before promoting them to wiki facts. |
| OA-only | Use Arma 2 Operation Arrowhead 1.64 docs, not Arma 3 assumptions. |
| OA syntax | Avoid `remoteExec`, `remoteExecutedOwner`, `isRemoteExecuted`, `allPlayers`, SQF `params`, `isEqualTo`, `private _var = value`, `parseSimpleArray`, `setGroupOwner`, `groupOwner`, modern `select [start,count]` / `select {condition}` forms, `BIS_fnc_MP` and CBA/ACE helpers unless OA availability and repo usage are proven. |
| PV/JIP caveat | `publicVariable` and `setVariable [..., true]` can provide replicated last-value state, but not server authority, event-history replay or full marker/queue collection sync. |
| Docs lane | Keep gameplay/source mission edits out of docs-only work unless explicitly requested. |
| Coordination | Check `agent-collaboration.json` and append events/worklog entries for substantial work. |
| Active claims | If `agent-collaboration.json.activeClaims` lists a command-reference or compatibility lane, leave that lane's named files to its owner unless it signs off or the user redirects. |
| Current status | Treat [Current source status snapshot](Current-Source-Status-Snapshot) as authoritative for disputed source-patched claims until a newer source re-check supersedes it. |
| Append order | Worklog/event timestamps can be non-monotonic; trust append-order supersession notes plus the current snapshot over older or later-looking stale timestamps. |
| Validation | Run `docs\validate-wiki.ps1` after meaningful wiki or machine-context edits; it includes JSON/JSONL parsing. After syncing the GitHub wiki checkout, run `Tools\TestWikiParity.ps1` and the mirror `Tools\ValidateWiki.ps1 -SkipGitDiffCheck` pass. |

## Task Bundles

| Task | Start |
| --- | --- |
| Improve docs structure | [Knowledge platform roadmap](Knowledge-Platform-Roadmap) |
| Reduce duplicate wiki content | [Wiki quality audit](Wiki-Quality-Audit) |
| Prepare hardening work | [Hardening implementation roadmap](Hardening-Implementation-Roadmap) |
| Investigate networking/authority | [Networking and public variables](Networking-And-Public-Variables) and [Server authority migration map](Server-Authority-Migration-Map) |
| Work on performance follow-ups | [Performance opportunity sweep](Performance-Opportunity-Sweep) |

## Continue Reading

Previous: [Home](Home) | Next: [Quickstart](Quickstart-For-Humans-And-Agents)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
