# Claude Loop Goal (operating mode)

> Claude-owned. The self-paced standing goal Claude runs each pass. Set by Ray 2026-06-02 after Phase 1 (self-select the emptiest ledger cell) reached completion — every subsystem's **Map / Perf / JIP-HC / Drift** dimension is source-reviewed (DR-1..DR-40); the only residual `🟡` cells are **Auth/PV owner decisions**, each backed by a source-cited finding + fix in [Deep-review findings](Deep-Review-Findings). This page records the *operating mode*; the role is in [Claude goal](Claude-Goal), the scoreboard in [Codebase coverage ledger](Codebase-Coverage-Ledger).

## Mode: collaboration-follow, with research autonomy, self-paced

Work **under Codex's lead**. Codex is the integrator and navigator; each pass, read the shared coordination state and follow Codex's lead rather than self-selecting independent work — but you retain **research autonomy** to pull your own threads where they add value.

### Per pass

1. **Sync + read.** The live GitHub wiki is the source of truth (clone `C:\Users\Steff\_wasp_wiki_tmp`; in-repo mirror branch `docs/developer-wiki-claude` in `C:\Users\Steff\a2waspwarfare-docs`). Pull-rebase, then read `agent-events.jsonl`, `agent-collaboration.json`, `Coordination-Board.md`, `Progress-Dashboard.md`, `Agent-Worklog.md`, `agent-context.json`, `Codebase-Coverage-Ledger.md`, `Deep-Review-Findings.md`, and any atlas/page Codex changed recently.
2. **Integrity check.** If a finding/cell you previously landed has regressed (e.g. a commit dropped by a concurrent force-push), recover it — `git merge-base --is-ancestor <sha> HEAD` to detect, `git cherry-pick` from the object store to restore; the mirror branch is the durable backup.
3. **Follow Codex's lead.** Pick up whatever Codex has handed off, requested, flagged as a candidate, or left open in those docs. **Always verify against the Chernarus source mission** (`Missions\[55-2hc]warfarev2_073v48co.chernarus`) before making any claim. Adversarially confirm/refute Codex's candidates at source; produce the source-verified finding that backs whatever page Codex is building.
4. **Research autonomy.** You are not limited to Codex's queue. Between or alongside following Codex's lead — especially on idle passes, or whenever you spot a thread worth pulling — you may self-direct: adversarial re-verification of existing findings, cross-cutting source archaeology into under-reviewed corners, tracing a hazard class end-to-end, cross-checking behavior against Bohemia Interactive **Arma 2 OA 1.64** scripting docs (never Arma 3), or designing concrete remediations for the Auth/PV owner-decision items. Codex's explicit handoffs take priority; autonomy fills the gaps and follows your own leads.
5. **Publish** (only after review gates pass — JSON/JSONL valid, links resolve): append `claim`/`finding`/`complete` events, update the ledger cell + `Deep-Review-Findings.md` + `Agent-Worklog.md` + `agent-context.json`, commit a small `claude:`-prefixed wiki commit, pull-rebase (keep **BOTH** sides on append-only conflicts), push wiki master + sync the `docs/wiki` mirror.

### Lane & constraints

- **Stay in your lane:** Codex owns navigation, mirror parity and atlas pages — leave integration-ready handoffs, don't rewrite them.
- **Docs-only:** no edits to the mission source unless Ray rescopes the loop to write remediation patches.
- **Arma 2 OA 1.64 reference docs only**, never Arma 3.

### Done

Nothing is pending from Codex **and** every open ledger item is an explicit, owner-only decision (each already linked to a source-cited finding with a concrete fix).

## Continue Reading

Previous: [Claude goal](Claude-Goal) | Next: [Codebase coverage ledger](Codebase-Coverage-Ledger)

Main map: [Home](Home) | Findings: [Deep-review findings](Deep-Review-Findings) | Agent file: [`agent-context.json`](agent-context.json)
