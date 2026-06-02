# Wiki Quality Audit — Codex-Lane Punch-List

> Claude-owned audit (2026-06-02). A one-stop punch-list of wiki-quality items that fall in **Codex's lane** (navigation, atlas pages, page structure, mirror parity). Claude already fixed the items in its own lane (ledger accuracy, DR-11 severity, DR-36 disambiguation, `agent-context.json` systems map, and the new connective pages). This page lists the **dedup → cross-link**, **page-merge**, and **accuracy** work for Codex to action on the atlas/nav pages it owns. Method: three parallel source-grounded audits (duplication, accuracy, gaps). No broken internal links were found (positive). Canonical-home principle: keep one source-of-truth per fact and replace the copies with a cross-link.

## A. Duplicated content → replace copies with a cross-link

Each row: the fact, its **canonical home**, and the pages carrying a redundant near-copy that should become a link.

| # | Topic | Canonical home | Redundant copies to replace with a link |
| --- | --- | --- | --- |
| DUP-1 | PVF `Call Compile` trust boundary / dispatch RCE | [Deep-review findings](Deep-Review-Findings) DR-1 (+ Round 3 playbook) | [Hardening roadmap](Hardening-Implementation-Roadmap) P0; [Server authority map](Server-Authority-Migration-Map) PVF row; [Networking](Networking-And-Public-Variables) (keep summary, it already links) |
| DUP-2 | Client-authoritative economy synthesis table (build/buy/sell/supply/upgrade/ICBM/gear) | [Economy](Economy-Towns-And-Supply) synthesis table + DR-6/14/16/22/23/27/28 evidence | [Hardening roadmap](Hardening-Implementation-Roadmap) P1; [Server authority map](Server-Authority-Migration-Map); [Feature status](Feature-Status-Register); [Gear/EASA atlas](Gear-Loadout-And-EASA-Atlas) |
| DUP-3 | ICBM/Nuke client-authoritative chain (DR-27) | [Deep-review findings](Deep-Review-Findings) DR-27 | [Hardening roadmap](Hardening-Implementation-Roadmap) P0-ICBM; [Server authority map](Server-Authority-Migration-Map) ICBM row; keep one-line summaries elsewhere |
| DUP-4 | Generated-mission drift / LoadoutManager skip-list | [Tools and build](Tools-And-Build-Workflow) (rules + status table) and DR-4/DR-32 for analysis | [Tools and build](Tools-And-Build-Workflow) prose that restates DR-32 → link DR-32 instead |
| DUP-5 | BattlEye posture (22-byte `kickAFK` stub, no `scripts.txt`) | [External integrations](External-Integrations) BattlEye section + DR-30 | [Feature status](Feature-Status-Register); [Networking](Networking-And-Public-Variables); roadmap/migration references |
| DUP-6 | Lifecycle / boot wait-chain + role truth table | [Lifecycle wait-chain](Lifecycle-Wait-Chain) | [Mission entrypoints](Mission-Entrypoints-And-Lifecycle) (see MERGE-3); [Server runtime atlas](Server-Gameplay-Runtime-Atlas) boot section; [SQF atlas](SQF-Code-Atlas) init-owners |
| DUP-7 | Supply-mission cooldown casing (DR-18, `lastSupplyMissionRun`) | [Deep-review findings](Deep-Review-Findings) DR-18 + [Supply mission arch](Supply-Mission-Architecture) | [Economy](Economy-Towns-And-Supply); [Server runtime atlas](Server-Gameplay-Runtime-Atlas); [Feature status](Feature-Status-Register); [Hardening roadmap](Hardening-Implementation-Roadmap) — say "see DR-18" |
| DUP-8 | Construction authority (DR-6, class-existence-only checks) | [Deep-review findings](Deep-Review-Findings) DR-6 | [Construction atlas](Construction-And-CoIn-Systems-Atlas); [Gameplay atlas](Gameplay-Systems-Atlas); roadmap/migration/feature-status |
| DUP-9 | Victory/endgame double-fire (DR-11/DR-36) | [Deep-review findings](Deep-Review-Findings) DR-11 + DR-36 | [Server runtime atlas](Server-Gameplay-Runtime-Atlas); [Hardening roadmap](Hardening-Implementation-Roadmap); [Feature status](Feature-Status-Register) |
| DUP-10 | HC delegation, no failover (DR-21) | [Deep-review findings](Deep-Review-Findings) DR-21 | [AI/headless](AI-Headless-And-Performance); [Lifecycle wait-chain](Lifecycle-Wait-Chain) |
| DUP-11 | Direct public-variable channel table | the new [Public variable channel index](Public-Variable-Channel-Index) | point [Networking](Networking-And-Public-Variables) (2 tables) and [SQF atlas](SQF-Code-Atlas) (direct-channel table) at the index |

## B. Overlapping pages → merge or reduce to summary + cross-link

- **MERGE-1 (highest value):** [Hardening roadmap](Hardening-Implementation-Roadmap) ≈ [Server authority map](Server-Authority-Migration-Map) — ~70% overlap (same P0/P1 work packages, same evidence tables). Consolidate into one page: the Migration-Map's *Authority Principles* + *Handler Validation Checklist* as the design preamble, the Roadmap's *prioritized work packages* as the body. Keep focused sub-playbooks (e.g. [Attack-wave authority](Attack-Wave-Authority-Playbook)) linking back.
- **MERGE-2:** [Client UI HUD and menus](Client-UI-HUD-And-Menus) ⊂ [Client UI systems atlas](Client-UI-Systems-Atlas) — the HUD/menus page is a strict subset. Make it a "Quick Reference" header section of the atlas, or a redirect.
- **MERGE-3:** [Mission entrypoints](Mission-Entrypoints-And-Lifecycle) ≈ [Lifecycle wait-chain](Lifecycle-Wait-Chain) — ~50% overlap. Keep the entrypoints page for the `description.ext` include graph + mission-object init layer; move the boot timeline/flag-dependency content to the wait-chain page and cross-link.
- **REDUCE-4:** [Gameplay atlas](Gameplay-Systems-Atlas) construction/factory/economy sections re-summarize the dedicated atlases — reduce to brief gateway summaries + cross-links to [Construction atlas](Construction-And-CoIn-Systems-Atlas), [Factory atlas](Factory-And-Purchase-Systems-Atlas), [Economy](Economy-Towns-And-Supply).

## C. Accuracy fixes (Codex pages)

- **C1 (HIGH) — stale, contradicts a finding:** [Networking](Networking-And-Public-Variables) MASH row says the server relay is "live" and cites DR-3. DR-34 superseded this: the feature is **dead on both ends** (trigger never broadcast + receiver commented `Init_Client.sqf:132` + orphaned server PVEH). Update the row to DR-34 and drop "server relay live". (Feature-Status-Register is already correct — they currently disagree.) **Status:** resolved by Codex on 2026-06-02; Networking now cites DR-34 and describes the orphaned server PVEH instead of a live relay.
- **C2 (HIGH) — orphaned findings, zero DR cross-links on atlas pages a developer actually opens.** Add cross-links:
  - [Gameplay atlas](Gameplay-Systems-Atlas): DR-6 (construction), DR-14 (purchase authority), DR-11 (victory inversion), DR-22 (supply windfall), DR-23 (upgrade forgery), DR-15 (commander-assign bug).
  - [Client UI systems atlas](Client-UI-Systems-Atlas) / [Client UI HUD and menus](Client-UI-HUD-And-Menus): DR-16, DR-17, DR-24, DR-25a/b.
  - [AI/headless](AI-Headless-And-Performance): DR-21, DR-42.
  - [Construction atlas](Construction-And-CoIn-Systems-Atlas): DR-6 (currently links DR-1 only).
  - [Mission entrypoints](Mission-Entrypoints-And-Lifecycle): DR-37, DR-43a.
- **Status:** C2 resolved by Codex on 2026-06-02; the listed atlas pages now carry concise DR cross-links to the canonical [Deep-review findings](Deep-Review-Findings) records.
- **C3 — stale "Open Questions":** [Gameplay atlas](Gameplay-Systems-Atlas) "Open Questions For Claude" lists items already answered — `Server_AssignNewCommander` call-shape is DR-15 (confirmed bug); client/server build drift is partly DR-33. Resolve or remove. **Status:** partially resolved by Codex on 2026-06-02; DR-15 is now called out as confirmed instead of unknown. The remaining structure-repair/resource/build-drift questions still need source-backed follow-up.
- **C4 — searchability:** [Feature status](Feature-Status-Register) and [Hardening roadmap](Hardening-Implementation-Roadmap) describe the victory bug but never cite **DR-11** by number; add it. **Status:** resolved by Codex on 2026-06-02; both pages now cite DR-11 by number alongside DR-36's mechanism.
- **C5 — sidebar dup entries:** [`_Sidebar.md`] lists Hardening-roadmap / Server-authority-map / Attack-wave-authority / Testing-workflow under **both** "Ops" and "Current Work". De-duplicate. **Status:** resolved by Codex on 2026-06-02; Current Work now stays focused on coordination/review pages, while Ops owns hardening/authority/testing pages.
- **C6 — thin citations:** [Client UI HUD and menus](Client-UI-HUD-And-Menus) (no `path:line` citations at all), parts of [Gameplay atlas](Gameplay-Systems-Atlas) (file-level only) and [AI/headless](AI-Headless-And-Performance) — raise toward the project's `path:line` standard.

## D. Already fixed by Claude (this program) — no Codex action

- Ledger: matrix timestamp → 2026-06-02; legend clarified (reviewed-clean vs reviewed-with-finding); Modules + Markers/cleaners Map cells downgraded to 🟡 (Modules returns to ✅ when the module atlas lands).
- Deep-Review-Findings: DR-11 severity normalized to High; DR-36 dual-purpose disambiguation note.
- `agent-context.json` `systems` map: +5 missing ledger subsystems.
- New Claude pages this program: [Variable and naming conventions](Variable-And-Naming-Conventions), [Public variable channel index](Public-Variable-Channel-Index), [Modules atlas](Modules-Atlas), [Pending owner decisions](Pending-Owner-Decisions) (and this audit page). **Status:** wired into `_Sidebar.md`, `_Footer.md`, Home and `agent-context.json` by Codex on 2026-06-02.

## How to consume

Work A→B→C in priority order; C1/C2 are the highest reader-impact (a developer browsing an atlas currently never meets the relevant finding). Each dedup edit should *remove* the copy and leave a one-line cross-link to the canonical home, so a future finding update only edits one page.

## Continue Reading

Canonical findings: [Deep-review findings](Deep-Review-Findings) | Scoreboard: [Codebase coverage ledger](Codebase-Coverage-Ledger) | Map: [Home](Home)
