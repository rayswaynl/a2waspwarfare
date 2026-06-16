# Wiki Quality Audit — Codex-Lane Punch-List (closed / archival)

> Claude-owned audit (2026-06-02), **closed 2026-06-05**. This was a one-stop punch-list of wiki-quality items in Codex's lane: dedup→cross-link (DUP-1..DUP-11), page-merge (MERGE-1..3, REDUCE-4), accuracy fixes (C1..C6) and a second full-60-page follow-up (R2-1..R2-10). **Every item was actioned by Codex by 2026-06-05.** The page is retained only as provenance of what was deduped and merged; it is not an open backlog.

For current work use [Progress dashboard](Progress-Dashboard), [Wiki pruning and relevance ledger](Wiki-Pruning-And-Relevance-Ledger), [Feature status](Feature-Status-Register) and the owner pages. Canonical evidence lives in [Deep-review findings](Deep-Review-Findings); the live operating contract is [Instructions for Codex](Instructions-For-Codex).

## What this audit established (preserved)

- **Canonical-home principle:** keep one source-of-truth per fact, replace copies with a cross-link. The dedup landed across the networking/economy/lifecycle/HC/victory/construction families; details of each route are in the [Wiki pruning and relevance ledger](Wiki-Pruning-And-Relevance-Ledger) and the owner pages.
- **Result of two full audits:** no broken internal links, no orphan pages, DR severities consistent across pages.

## False positives — do NOT "fix"

These were verified at source and must not be re-opened (also recorded in [Instructions for Codex](Instructions-For-Codex#false-positives-to-preserve)):

- [Public variable channel index](Public-Variable-Channel-Index) PVF line ranges `:8-20` (server) and `:23-37` (client) are **correct** — an audit pass miscounted blank lines.
- DR-15 is **not** a false positive: `RequestNewCommander.sqf:13` passes `[_side, _assigned_commander]` while `Server_AssignNewCommander.sqf:3-5` treats the whole payload as `_side` and indexes element 1 as commander. DR-15 remains patch-ready/source-unpatched; see [Commander reassignment call shape](Commander-Reassignment-Call-Shape).

## Continue Reading

Canonical findings: [Deep-review findings](Deep-Review-Findings) | Scoreboard: [Codebase coverage ledger](Codebase-Coverage-Ledger) | Map: [Home](Home)
