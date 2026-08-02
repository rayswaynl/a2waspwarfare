# Mine report: developer-wiki rewrite delta (42 files, 2122+/1265-)

**Task:** `wasp-mine-wiki-delta-20260731`  
**Lane:** `grok-main-07311829-night` (provider grok)  
**Date (UTC):** 2026-07-31  
**Authority:** Owner board 2026-07-31 — MINE FOR WIKI LANE (do not fold blind)  
**Worktree (read-only):** `a2waspwarfare-docs` branch `docs/developer-wiki-claude` @ `177381df2c` (behind origin by 7; dirty unstaged rewrite)  
**Live wiki baseline used:** local clone `a2wasp-wiki` @ `ee738fb` (2026-07-28, ~407 md pages)  
**Source verify base:** `origin/master` of `a2waspwarfare` (spot-checks only; not full tree re-prove)

## Method (what was verified)

1. Confirmed the card's 42-file unstaged delta: `git diff --numstat -- docs/wiki/` = **2122 insertions / 1265 deletions** across 42 paths; plus 4 untracked wiki md files (not in the 42-file numstat but part of the same rewrite working set).
2. Compared every delta leaf name to the live wiki clone (existence, line counts, SHA identity). **Identical to live: 0.**
3. Heading-level and source-anchor-density compare for all md pages.
4. Spot-checked high-value technical claims against `origin/master` Chernarus Rsc/Client GUI sources (fast travel, soundPush, dual IDD EASA/Economy, upgrade menu).
5. Compared untracked `Server-Memory-Allocator.md` to live `Memory-Allocator-Research-And-WaspMalloc.md` (2026-07-28 ground truth).

**Not verified (limits):** full line-by-line re-proof of every sqf:line anchor in every delta page; live GitHub wiki remote `git pull` freshness beyond the local `ee738fb` clone; box runtime/RPT for any playbook status bit.

**Confidence overall:** medium-high for SUPERSEDED / DO-NOT-FOLD calls; medium for STILL-ACCURATE harvest slices that still need re-anchor before wiki publish.

## Executive verdict

| Class | Count (of 42-file set + 4 untracked = 46) | Action for wiki program |
| --- | ---: | --- |
| SUPERSEDED by richer live page | 38 | Do **not** fold. Keep live. |
| STALE (delta wrong vs current master / live config) | 3 | Do not fold. Correct live if needed (already correct for most). |
| STILL-ACCURATE harvest (partial; re-source before publish) | 4 page-slices | Feed as **easy-win patch packs**, not whole-page replace |
| DO-NOT-PUBLISH (agent runtime / coordination dumps) | 7 | Exclude from public wiki easy-wins forever |
| NEW-NAME / wrong title vs live | 1 | Superseded under a different live title |

**Blind-fold risk:** HIGH. The rewrite often *shortens* pages that the live wiki later expanded (Agent-Worklog 28k→1.8k, Sidebar 400→67, Dead-Code 554→57). Folding would **delete** months of post-June wiki work.

## Per-page verdict table

Verdict key:
- **STILL-ACCURATE** — core claims still match current live/source enough to reuse with re-anchor
- **STALE** — claims or status are out of date vs `origin/master` or 2026-07 live config
- **SUPERSEDED** — live wiki page is the canonical home and is richer/newer; do not replace
- **AGENT-RUNTIME** — machine coordination dump; not a developer doc page for public publish
- **HARVEST** — extract named sections only into easy-wins feed

### Markdown pages (modified in the 42-file delta)

| Page | Delta lines | Live lines | Verdict | Easy-win? | Notes |
| --- | ---: | ---: | --- | --- | --- |
| Agent-Worklog.md | 1836 | 28381 | SUPERSEDED | no | Live is the append-only log; delta is a June truncation |
| _Sidebar.md | 67 | 400 | SUPERSEDED | no | Live nav has ~400 lines of program structure |
| Home.md | 66 | 99 | SUPERSEDED | no | Live front door + non-negotiables newer |
| Progress-Dashboard.md | 94 | 163 | SUPERSEDED | no | Live has July batches / closed items |
| LLM-Agent-Entry-Pack.md | 36 | 92 | SUPERSEDED | no | Live load-order richer |
| AI-Assistant-Guide.md | 59 | 29 | SUPERSEDED+ | optional | Delta longer but generic; live is the post-program compact gate — do not overwrite |
| AI-Assistant-Developer-Guide.md | 67 | 71 | SUPERSEDED | no | Same role as live; no unique harvest |
| Coordination-Board.md | 71 | 159 | SUPERSEDED | no | Fleet/board process moved out of wiki |
| Feature-Status-Register.md | 194 | 380 | SUPERSEDED | no | Live has wave PR ledgers |
| Bottleneck-Removal-Queue.md | 74 | 86 | SUPERSEDED | no | Process page; live current |
| Wiki-Quality-Audit.md | 105 | 21 | SUPERSEDED* | harvest-meta only | Delta is older long audit; live pruned to pointer form by design |
| Construction-And-CoIn-Systems-Atlas.md | 23 | 371 | SUPERSEDED | no | Live atlas is the map |
| Gear-Loadout-And-EASA-Atlas.md | 28 | 237 | SUPERSEDED | no | |
| Headless-Delegation-And-Failover-Playbook.md | 27 | 201 | SUPERSEDED | no | |
| Dead-Code (untracked) vs live | 57 | 554 | SUPERSEDED | no | Live has megapass findings |
| Wiki-Pruning-And-Relevance-Ledger (untracked) | 36 | 589 | SUPERSEDED | no | Live decision history |
| Source-Fix-Propagation-Queue (untracked) | 35 | 178 | SUPERSEDED | no | Live has actual queue |
| Town-AI-Vehicle-Despawn-Safety.md | 36 | 145 | SUPERSEDED | no | Live has full DR-45 playbook |
| Paratrooper-Marker-Revival.md | 45 | 115 | SUPERSEDED | no | |
| Arma-2-OA-Compatibility-Audit.md | 78 | 179 | SUPERSEDED | no | |
| Economy-Towns-And-Supply.md | 118 | 173 | SUPERSEDED | no | |
| Server-Gameplay-Runtime-Atlas.md | 72 | 91 | SUPERSEDED | no | |
| Public-Variable-Channel-Index.md | 122 | 140 | SUPERSEDED | no | Live has more channel anchors |
| Networking-And-Public-Variables.md | 179 | 166 | SUPERSEDED | no | Live has source anchors (46 vs 0) |
| PVF-Dispatch-Implementation-Playbook.md | 170 | 258 | SUPERSEDED | no | Live has branch matrix + sender auth boundary |
| Client-Skill-Init-Idempotency.md | 100 | 100 | SUPERSEDED | no | Parity length; live branch status newer |
| Factory-Queue-Counter-Token-Cleanup.md | 90 | 107 | SUPERSEDED | no | |
| Hosted-Server-FPS-Loop-Sleep.md | 95 | 93 | SUPERSEDED | no | Live validation anchors denser |
| WASP-Marker-Wait-Cleanup.md | 104 | 93 | SUPERSEDED | no | Live patch shape + validation |
| Supply-Mission-Scan-Narrowing.md | 122 | 99 | SUPERSEDED* | low | Delta has 2026-06-03 note; treat as historical; re-check class-filter scan before any publish |
| Tools-And-Build-Workflow.md | 157 | 196 | SUPERSEDED | no | Live has operator checklist + inventory |
| SQF-Code-Atlas.md | 229 | 254 | SUPERSEDED | no | |
| AI-Headless-And-Performance.md | 109 | 176 | SUPERSEDED | no | |
| Commander-Reassignment-Call-Shape.md | 101 | 146 | SUPERSEDED | no | |
| Developer-History-And-Upstream-Lessons.md | 196 | 198 | SUPERSEDED | no | Near-equal; live is fine |
| PR8-And-Drone-Upstream-Lesson-Match.md | 53 | 68 | SUPERSEDED | no | |
| Abandoned-Feature-Revival-Review.md | 304 | 269 | SUPERSEDED* | low | Delta slightly longer; no unique H2 headings vs live — no whole-page fold |
| **Client-UI-HUD-And-Menus.md** | **159** | **55** | **HARVEST** | **YES** | Live is a gateway into Client-UI-Systems-Atlas; delta still holds **three branch-matrix sections not found as named headings anywhere on live** (search returned zero hits for those titles). **Re-source required** — several DR claims are STALE on current master (see harvest pack). |
| Server-Memory-Allocator.md (untracked) | 59 | 0 under this title | **STALE / SUPERSEDED** | no (as page) | Live title is `Memory-Allocator-Research-And-WaspMalloc`. Delta still documents **mimalloc/tbb4** as live config; live page (2026-07-28) proves **system heap** and documents waspmalloc. Do not publish delta page. Optional: one sentence cross-link if missing (live already owns the topic). |

### Agent runtime files (modified in the 42-file set) — DO NOT feed easy-wins

| File | Verdict |
| --- | --- |
| agent-collaboration.json | AGENT-RUNTIME — SUPERSEDED dumps; public-repo hygiene risk |
| agent-compatibility-audit.json | AGENT-RUNTIME |
| agent-context.json | AGENT-RUNTIME |
| agent-events.jsonl | AGENT-RUNTIME |
| agent-hardening-backlog.jsonl | AGENT-RUNTIME (may seed backlog IDs privately; not a wiki page body) |
| agent-knowledge.jsonl | AGENT-RUNTIME |
| agent-status.json | AGENT-RUNTIME |

These belong in fleet/agent coordination, not the ~400-page developer wiki program as publish targets.

## Source spot-checks (Client-UI harvest honesty)

Against `origin/master` Chernarus:

| Delta claim | Spot-check result | Harvest implication |
| --- | --- | --- |
| Fast-travel fee modes exist (`WFBE_C_GAMEPLAY_FAST_TRAVEL` 0/1/2, range/price, client debit) | **CONFIRMED present** in `GUI_Menu_Tactical.sqf` (`_ft`/`_ftr`, fee math, destination filter) | Keep narrative: "fee mode is implemented; cleanup is TODO/stale-comment + authority design" — **re-anchor line numbers** before publish |
| Dual IDD 23000 for EASA + Economy (DR-17) | **STALE** — `RscMenu_EASA` is **idd = 24100** with comment "23000 belongs to Economy"; Economy remains 23000 | Do **not** re-publish dual-IDD claim; mark fixed/superseded |
| Malformed `RscClickableText.soundPush[] = {, 0.2, 1}` (DR-25b) | **STALE** — current class uses `soundPush[] = {"", 0.2, 1};` | Do not re-open as open defect |
| Stale `RscMenu_Upgrade` → missing `GUI_Menu_Upgrade.sqf` | **Likely cleaned** — live path is `WFBE_UpgradeMenu` → `GUI_UpgradeMenu.sqf`; no `RscMenu_Upgrade` hit in master Dialogs.hpp sample | Confirm once more before any "open cleanup" wording |
| RHUD / OptionsAvailable coupling | Plausible; not re-traced line-by-line this pass | Treat as research queue, not ship-ready |

## Easy-wins lane feed (concrete page updates)

See sibling file `EASY-WINS-FEED.md` in this folder. Summary of proposed updates (none applied this task — mine only):

1. **Client-UI-Systems-Atlas** (or Client-UI-HUD gateway): add three **re-verified** micro-sections or child pages from the delta matrices, after re-anchor:
   - Fast-travel fee status (implemented; not a missing feature)
   - Upgrade-menu shell status (confirm open vs already cleaned)
   - ClickableText soundPush status (confirm fixed; archive the DR)
2. **Do not** replace Client-UI-HUD-And-Menus.md wholesale with the delta (would drop the gateway architecture).
3. **Do not** fold Home, Sidebar, Agent-Worklog, Progress-Dashboard, or any agent-*.json(l).
4. **Do not** publish `Server-Memory-Allocator.md` under that title; live `Memory-Allocator-Research-And-WaspMalloc` owns the topic and has current config.

## Wiki program positioning (~400 pages / ~90 easy-wins)

This mine does **not** claim membership in the pre-existing 90 easy-win candidate list (list not found as a single durable file under shallow Fleet/handoff search within this invocation). It **adds** at most **1–3** concrete easy-win tickets (UI matrix re-anchor + publish) and **rejects** ~40 whole-page fold candidates that would regress the program.

Recommended easy-win ticket titles (for the wiki easy-wins lane):

1. `wiki-easywin-ui-fasttravel-fee-status-matrix` — re-anchor + publish short status table on Client UI atlas
2. `wiki-easywin-ui-upgrade-shell-status` — confirm master state; close or open cleanup note
3. `wiki-easywin-ui-clickabletext-soundpush-closed` — document DR-25b as fixed with proof line

## Provenance / hygiene

- Worktree **not modified** (read-only mine; no stash).
- No SQF/mission edits.
- No live wiki edits in this task (owner: mine + feed, not fold).
- Public-repo hygiene: harvest pack omits hostnames, LAN IPs, usernames, and absolute machine paths from any suggested wiki body text. Internal evidence may cite relative mission paths only.
- Branch note: `docs/developer-wiki-claude` is behind origin by 7 and carries uncommitted rewrite noise; treat as an **abandoned rewrite worktree**, not a publish branch.

## Files written

- `Docs/Proposals/wasp-mine-wiki-delta-20260731/REPORT.md` (this file)
- `Docs/Proposals/wasp-mine-wiki-delta-20260731/EASY-WINS-FEED.md`
- `Docs/Proposals/wasp-mine-wiki-delta-20260731/VERDICTS.csv`
- Copy under Fleet `Grok-Team/wasp-mine-wiki-delta-20260731/` (same three files)

## Closing recommendation

Task is complete as a **mine + feed** deliverable. No whole-page fold. Easy-wins lane should pick the three UI tickets only after re-anchoring on current `origin/master`.
