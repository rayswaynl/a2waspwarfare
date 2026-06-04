# Instructions for Codex

This is the live operating contract for Codex agents working on the A2 Wasp Warfare developer wiki. Historical audit queues are preserved in [Wiki quality audit](Wiki-Quality-Audit), [Deep-review findings](Deep-Review-Findings), [Agent worklog](Agent-Worklog) and [`agent-events.jsonl`](agent-events.jsonl). Do not restart from the old completed queues; use them as evidence archives.

Target engine: **Arma 2 OA 1.64**, not Arma 3.

## Current Goal Loop

1. Check `git status` in the main repo and wiki checkout before editing.
2. Read [Progress dashboard](Progress-Dashboard), [`agent-status.json`](agent-status.json), [Coordination board](Coordination-Board), and the most relevant owner page.
3. Pick the highest-value item in this order:
   - source-backed accuracy problem on a page developers actually open;
   - uncaptured recent research/scout/upstream delta;
   - stale status or branch-scope drift;
   - bloat, duplication or weak navigation;
   - lower-priority citation polish.
4. Source-check claims against repo files, branch heads, or already verified DR records before promoting them.
5. Prefer improving a canonical page over creating a new page.
6. If a page mostly repeats another page, condense it to a gateway and link to the canonical owner.
7. Preserve evidence when compressing: source paths, line refs, branch context, confidence and open gates.
8. Patch `docs/wiki/` first, mirror touched files to the wiki checkout, validate, commit and push scoped batches.

## Relevance Rules

Keep:

- source-cited findings that affect gameplay, authority, release, smoke testing or future development;
- page-level maps that explain where a system lives and how to change it safely;
- compact upstream/community history that explains why the repo looks the way it does;
- machine-readable files used by agents.

Condense or archive:

- completed planning checklists whose actions are already reflected in owner pages;
- repeated introductions to the same DR/security/economy/architecture finding;
- stale scout-wave narration after the useful deltas have been promoted;
- broad "more research needed" text that does not name a source target or owner decision.

Do not delete:

- unique source evidence;
- branch-scope warnings about `master`, maintained Vanilla Takistan, PR #1 / `feat/supply-helicopter`, release branches or modded drift;
- false-positive corrections that prevent future agents from re-opening bad fixes.

Track pruning decisions in [Wiki pruning and relevance ledger](Wiki-Pruning-And-Relevance-Ledger).

## Current Canonical Sources

| Need | Start here |
| --- | --- |
| Live status and ownership | [Progress dashboard](Progress-Dashboard), [`agent-status.json`](agent-status.json) |
| Source-backed bug register | [Deep-review findings](Deep-Review-Findings), [Feature status](Feature-Status-Register) |
| Coverage and remaining depth lanes | [Codebase coverage ledger](Codebase-Coverage-Ledger), [Pending owner decisions](Pending-Owner-Decisions) |
| Architecture and lifecycle | [Architecture overview](Architecture-Overview), [Mission entrypoints](Mission-Entrypoints-And-Lifecycle), [Lifecycle wait-chain](Lifecycle-Wait-Chain) |
| Networking and authority | [Networking/PV](Networking-And-Public-Variables), [Public variable channel index](Public-Variable-Channel-Index), [Server authority map](Server-Authority-Migration-Map) |
| Research intake | [External research reports](External-Research-Reports), [Upstream Miksuu commit intel](Upstream-Miksuu-Commit-Intel), [Miksuu upstream wiki import](Miksuu-Upstream-Wiki-Import) |
| Safe implementation gates | [Testing workflow](Testing-Debugging-And-Release-Workflow), [Source fix propagation queue](Source-Fix-Propagation-Queue), [Tooling release readiness audit](Tooling-Release-Readiness-Audit) |

## False Positives To Preserve

- [Public variable channel index](Public-Variable-Channel-Index) PVF list ranges `:8-20` (server) and `:23-37` (client) are correct.
- DR-15 is **not** a false positive: `RequestNewCommander.sqf:13` passes `[_side, _assigned_commander]`, while `Server_AssignNewCommander.sqf:3-5` treats the whole payload as `_side`.
- Static reference hits are leads, not runtime proof. Confirm executable call sites before promoting missing files to release blockers.
- Do not call a fix shipped on `master` unless `origin/master` proves it. Use branch-scoped status for docs branch, release branch, PR #1, source Chernarus and maintained Vanilla Takistan.

## Validation Gate

For docs batches:

```powershell
powershell -ExecutionPolicy Bypass -File docs\validate-wiki.ps1
git diff --check
```

Also parse JSON/JSONL if touched, check docs/wiki to wiki-checkout parity for touched files, and keep gameplay source unchanged unless Steff explicitly asks for a code patch.

## Continue Reading

Previous: [AI assistant developer guide](AI-Assistant-Developer-Guide) | Next: [Progress dashboard](Progress-Dashboard)

Main map: [Home](Home) | Pruning: [Wiki pruning and relevance ledger](Wiki-Pruning-And-Relevance-Ledger) | Findings: [Deep-review findings](Deep-Review-Findings)
