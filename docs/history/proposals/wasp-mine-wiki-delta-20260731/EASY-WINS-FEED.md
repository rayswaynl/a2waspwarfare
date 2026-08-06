# Easy-wins feed from developer-wiki rewrite mine

**Source task:** `wasp-mine-wiki-delta-20260731`  
**Lane:** `grok-main-07311829-night`  
**Rule:** feed concrete page updates only; do not blind-fold the 42-file rewrite.

## Reject list (do not schedule as easy-wins)

Whole-page replace of any of: Home, _Sidebar, Agent-Worklog, Progress-Dashboard, LLM-Agent-Entry-Pack, Feature-Status-Register, Dead-Code-And-Stale-Code-Register, Wiki-Pruning-And-Relevance-Ledger, Source-Fix-Propagation-Queue, Server-Memory-Allocator (wrong title + stale live config), any `agent-*.json` / `agent-*.jsonl`.

Reason: live wiki is larger and newer; fold would regress the ~400-page program.

## Accepted easy-win tickets (max 3)

### EW-1 — Fast-travel fee status (HIGH value, re-anchor required)

- **Target page:** `Client-UI-Systems-Atlas` (preferred) or short child `Fast-Travel-Fee-Status`
- **Sidebar hook:** under Client UI / Tactical menu
- **Intent:** document that fee mode is **implemented**, not missing; remaining work is stale TODO cleanup + economy authority design
- **Delta origin:** `Client-UI-HUD-And-Menus.md` section "Fast Travel Fee Branch Matrix" on `docs/developer-wiki-claude` working tree
- **Must re-verify on origin/master before publish:**
  - `Rsc/Parameters.hpp` — `WFBE_C_GAMEPLAY_FAST_TRAVEL` values
  - `Common/Init/Init_CommonConstants.sqf` — range/price/time constants
  - `Client/GUI/GUI_Menu_Tactical.sqf` — `_ft` / `_ftr`, destination filter when `_ft == 2`, debit path
- **Already spot-checked 2026-07-31:** fee path symbols present on `origin/master` (`_ft`, `_ftr`, fee math). Line numbers from the June delta are **not** trusted.
- **Suggested body shape (sanitize; relative paths only):**

```markdown
# Fast Travel Fee Status

Status: implemented on current Chernarus source (not a missing feature).

| Mode | Parameter value | Player-visible effect |
| --- | ---: | --- |
| Disabled | 0 | Fast travel unavailable |
| Free | 1 | Eligible destinations without debit |
| Fee | 2 | Range + funds filter; distance-based debit on confirm |

Cleanup remaining:
- Remove or rewrite any stale "fee TODO" comments that imply the mode is missing
- Decide whether client-side debit should move into server-authoritative economy work
- Smoke all three modes before release-ready wording

Source anchors: re-fill after `origin/master` line pass (do not copy June line numbers).
```

- **Do not publish:** multi-branch historical matrix rows with old SHAs (`1faf738d`, PR8, etc.) unless re-checked — they add noise for the easy-wins program.

### EW-2 — Upgrade menu shell status (MEDIUM; confirm open vs fixed)

- **Target page:** `Client-UI-Systems-Atlas` or `Abandoned-Feature-Revival-Review` (old upgrade dialog section)
- **Delta origin:** "Old Upgrade Dialog Branch Matrix"
- **Intent:** one short "current truth" table: live menu path vs any stale resource class
- **Spot-check 2026-07-31:** live path is `WFBE_UpgradeMenu` → `GUI_UpgradeMenu.sqf`; no `RscMenu_Upgrade` hit in sampled `Dialogs.hpp`. Likely already cleaned — ticket may close as **document-as-fixed** rather than open work.
- **Publish only after:** one `rg`/`Select-String` pass for `RscMenu_Upgrade` and `GUI_Menu_Upgrade` on Chernarus + generated Vanilla.

### EW-3 — RscClickableText soundPush (LOW; likely CLOSE)

- **Target page:** `UI-IDD-Collision-Repair` or Client UI atlas "known findings"
- **Delta origin:** "Clickable Text Sound Config Branch Matrix" (DR-25b)
- **Spot-check 2026-07-31:** `class RscClickableText` on `origin/master` has `soundPush[] = {"", 0.2, 1};` — **not** the malformed `{, 0.2, 1}` form.
- **Easy-win action:** mark DR-25b **fixed** with the proof line; do not re-open as a bug.

## Explicit non-goals from this mine

- Do not reintroduce June allocator config (mimalloc/tbb as "live") — contradicted by live `Memory-Allocator-Research-And-WaspMalloc` (2026-07-28 system heap + waspmalloc).
- Do not publish dual-IDD 23000 EASA/Economy claim — EASA is idd 24100 on current master.
- Do not truncate Agent-Worklog or Sidebar from the rewrite.

## Handoff contract for wiki easy-wins lane

For each accepted ticket:
1. Re-anchor on current `origin/master` (Chernarus source rule).
2. Draft <= 80 lines.
3. Link from Client UI atlas + _Sidebar if new child page.
4. Public hygiene: no hostnames, IPs, usernames, local absolute paths.
5. Append edit summary to Agent-Worklog when published.

## Evidence pointers (internal)

- Delta worktree branch: `docs/developer-wiki-claude` @ `177381df2c` + unstaged rewrite
- Live wiki clone tip used: `ee738fb` (2026-07-28)
- Full per-page table: `REPORT.md` in this folder
