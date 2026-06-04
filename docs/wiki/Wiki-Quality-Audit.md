# Wiki Quality Audit — Codex-Lane Punch-List

> Claude-owned audit (2026-06-02). A one-stop punch-list of wiki-quality items that fall in **Codex's lane** (navigation, atlas pages, page structure, mirror parity). Claude already fixed the items in its own lane (ledger accuracy, DR-11 severity, DR-36 disambiguation, `agent-context.json` systems map, and the new connective pages). This page lists the **dedup → cross-link**, **page-merge**, and **accuracy** work for Codex to action on the atlas/nav pages it owns. Method: three parallel source-grounded audits (duplication, accuracy, gaps). No broken internal links were found (positive). Canonical-home principle: keep one source-of-truth per fact and replace the copies with a cross-link.

## A. Duplicated content → replace copies with a cross-link

Each row: the fact, its **canonical home**, and the pages carrying a redundant near-copy that should become a link.

| # | Topic | Canonical home | Redundant copies to replace with a link |
| --- | --- | --- | --- |
| DUP-1 | PVF `Call Compile` trust boundary / dispatch RCE | [Deep-review findings](Deep-Review-Findings) DR-1 (+ Round 3 playbook) | [Hardening roadmap](Hardening-Implementation-Roadmap) P0; [Server authority map](Server-Authority-Migration-Map) PVF row; [Networking](Networking-And-Public-Variables) (keep summary, it already links) |
| DUP-2 | Client-authoritative economy synthesis table (build/buy/sell/supply/upgrade/ICBM/gear) | [Economy](Economy-Towns-And-Supply) synthesis table + DR-6/14/16/22/23/27/28 evidence | [Hardening roadmap](Hardening-Implementation-Roadmap) P1; [Server authority map](Server-Authority-Migration-Map); [Feature status](Feature-Status-Register); [Gear/EASA atlas](Gear-Loadout-And-EASA-Atlas) |
| DUP-3 | ICBM/Nuke client-authoritative chain (DR-27) | [ICBM authority playbook](ICBM-Authority-Playbook) + [Deep-review findings](Deep-Review-Findings) DR-27 | **Resolved by Codex on 2026-06-02:** DR-27 implementation detail now lives in [ICBM authority](ICBM-Authority-Playbook); [Hardening roadmap](Hardening-Implementation-Roadmap), [Server authority map](Server-Authority-Migration-Map) and [Feature status](Feature-Status-Register) keep short summaries and route there. |
| DUP-4 | Generated-mission drift / LoadoutManager skip-list | [Tools and build](Tools-And-Build-Workflow) (operational rules + status table) and [Deep-review findings](Deep-Review-Findings) DR-4/DR-32 for analysis | Resolved 2026-06-02 by Codex: [Tools/build](Tools-And-Build-Workflow) now states page ownership and routes full drift evidence to DR-4/DR-32; [Content structure](Content-Structure-And-Maps) is reduced to folder orientation plus a link to the operational rules. |
| DUP-5 | BattlEye posture (22-byte `kickAFK` stub, no `scripts.txt`) | [External integrations](External-Integrations) BattlEye section + DR-30 | **Resolved by Codex on 2026-06-02:** [External integrations](External-Integrations) owns shipped BattlEye posture; [Feature status](Feature-Status-Register), [Networking](Networking-And-Public-Variables), roadmap and authority map now keep short routing notes. |
| DUP-6 | Lifecycle / boot wait-chain + role truth table | [Lifecycle wait-chain](Lifecycle-Wait-Chain) | Resolved 2026-06-02 by Codex: [Server runtime atlas](Server-Gameplay-Runtime-Atlas) and [SQF atlas](SQF-Code-Atlas) now route lifecycle flags/boot/JIP/HC wait detail to the canonical wait-chain page; [Mission entrypoints](Mission-Entrypoints-And-Lifecycle) remains include graph / role-dispatch orientation. |
| DUP-7 | Supply-mission cooldown casing (DR-18, `lastSupplyMissionRun`) | [Deep-review findings](Deep-Review-Findings) DR-18 + [Supply mission arch](Supply-Mission-Architecture) | Resolved 2026-06-02 by Codex: [Economy](Economy-Towns-And-Supply), [Server runtime atlas](Server-Gameplay-Runtime-Atlas), [Feature status](Feature-Status-Register) and [Hardening roadmap](Hardening-Implementation-Roadmap) now route casing details to DR-18 / Supply architecture / Supply authority cleanup instead of repeating the mismatch evidence. |
| DUP-8 | Construction authority (DR-6, class-existence-only checks) | [Deep-review findings](Deep-Review-Findings) DR-6 + [Construction atlas](Construction-And-CoIn-Systems-Atlas) for runtime map | Resolved 2026-06-02 by Codex: Construction atlas now states page ownership and routes exact proof to DR-6; Gameplay, Feature status, Hardening roadmap and Server authority map route to DR-6 / Construction atlas instead of repeating class-existence evidence. |
| DUP-9 | Victory/endgame double-fire (DR-11/DR-36) | [Deep-review findings](Deep-Review-Findings) DR-11 + DR-36 | **Resolved by Codex on 2026-06-02:** [Server runtime atlas](Server-Gameplay-Runtime-Atlas), [Hardening roadmap](Hardening-Implementation-Roadmap) and [Feature status](Feature-Status-Register) now route to DR-11/DR-36 instead of repeating the full guard/precedence mechanism. |
| DUP-10 | HC delegation, no failover (DR-21) | [Deep-review findings](Deep-Review-Findings) DR-21 + [Headless delegation and failover](Headless-Delegation-And-Failover-Playbook) for patch shape | **Resolved by Codex on 2026-06-02:** [AI/headless](AI-Headless-And-Performance) now keeps a concise HC runtime source router, [Lifecycle wait-chain](Lifecycle-Wait-Chain) owns only boot timing/wait-chain risk, and [Headless delegation and failover](Headless-Delegation-And-Failover-Playbook) owns DR-21/DR-42 implementation policy. |
| DUP-11 | Direct public-variable channel table | the new [Public variable channel index](Public-Variable-Channel-Index) | **Resolved by Codex on 2026-06-02:** [Networking](Networking-And-Public-Variables) and [SQF atlas](SQF-Code-Atlas) now point at the index instead of carrying duplicate direct-channel tables; the index also picked up server-FPS, HQ state/marker and AntiStack/no-player rows from the old Networking table. |

## B. Overlapping pages → merge or reduce to summary + cross-link

- **MERGE-1 (highest value):** [Hardening roadmap](Hardening-Implementation-Roadmap) ≈ [Server authority map](Server-Authority-Migration-Map) — ~70% overlap (same P0/P1 work packages, same evidence tables). Consolidate into one page: the Migration-Map's *Authority Principles* + *Handler Validation Checklist* as the design preamble, the Roadmap's *prioritized work packages* as the body. Keep focused sub-playbooks (e.g. [Attack-wave authority](Attack-Wave-Authority-Playbook)) linking back. **Status:** resolved by Codex on 2026-06-02; both legacy routes now point to [Documentation implementation plan](Documentation-Implementation-Plan) plus focused authority playbooks, so the overlap no longer creates competing current pages.
- **MERGE-2:** [Client UI HUD and menus](Client-UI-HUD-And-Menus) ⊂ [Client UI systems atlas](Client-UI-Systems-Atlas) — the HUD/menus page was a strict subset. Make one page the active map and keep the other as a route. **Status:** resolved by Codex on 2026-06-02; [Client UI systems atlas](Client-UI-Systems-Atlas) is now the legacy route, and [Client UI HUD and menus](Client-UI-HUD-And-Menus) owns the active UI/HUD/menu map with source anchors.
- **MERGE-3:** [Mission entrypoints](Mission-Entrypoints-And-Lifecycle) ≈ [Lifecycle wait-chain](Lifecycle-Wait-Chain) — ~50% overlap. Keep the entrypoints page for the `description.ext` include graph + mission-object init layer; move the boot timeline/flag-dependency content to the wait-chain page and cross-link. **Status:** resolved by Codex on 2026-06-02; Mission entrypoints keeps include graph, role dispatch, mission-object town init and per-role responsibility notes, while Lifecycle wait-chain is the canonical boot-order/JIP/flag-dependency page.
- **REDUCE-4:** [Gameplay atlas](Gameplay-Systems-Atlas) construction/factory/economy sections re-summarize the dedicated atlases — reduce to brief gateway summaries + cross-links to [Construction atlas](Construction-And-CoIn-Systems-Atlas), [Factory atlas](Factory-And-Purchase-Systems-Atlas), [Economy](Economy-Towns-And-Supply). **Status:** resolved by Codex on 2026-06-02; Gameplay now keeps orientation/source anchors while routing detailed economy authority, CoIn construction and factory queue/config mechanics to their canonical atlases.

## C. Accuracy fixes (Codex pages)

- **C1 (HIGH) — stale, contradicts a finding:** [Networking](Networking-And-Public-Variables) MASH row says the server relay is "live" and cites DR-3. DR-34 superseded this: the feature is **dead on both ends** (trigger never broadcast + receiver commented `Init_Client.sqf:132` + orphaned server PVEH). Update the row to DR-34 and drop "server relay live". (Feature-Status-Register is already correct — they currently disagree.) **Status:** resolved by Codex on 2026-06-02; Networking now cites DR-34 and describes the orphaned server PVEH instead of a live relay.
- **C2 (HIGH) — orphaned findings, zero DR cross-links on atlas pages a developer actually opens.** Add cross-links:
  - [Gameplay atlas](Gameplay-Systems-Atlas): DR-6 (construction), DR-14 (purchase authority), DR-11 (victory inversion), DR-22 (supply windfall), DR-23 (upgrade forgery), DR-15 (commander-assign bug).
  - [Client UI systems atlas](Client-UI-Systems-Atlas) / [Client UI HUD and menus](Client-UI-HUD-And-Menus): DR-16, DR-17, DR-24, DR-25a/b.
  - [AI/headless](AI-Headless-And-Performance): DR-21, DR-42.
  - [Construction atlas](Construction-And-CoIn-Systems-Atlas): DR-6 (currently links DR-1 only).
  - [Mission entrypoints](Mission-Entrypoints-And-Lifecycle): DR-37, DR-43a.
- **Status:** C2 resolved by Codex on 2026-06-02; the listed atlas pages now carry concise DR cross-links to the canonical [Deep-review findings](Deep-Review-Findings) records.
- **C3 — stale "Open Questions":** [Gameplay atlas](Gameplay-Systems-Atlas) "Open Questions For Claude" lists items already answered — `Server_AssignNewCommander` call-shape is DR-15 (confirmed bug); client/server build drift is partly DR-33. Resolve or remove. **Status:** resolved by Codex on 2026-06-02; Gameplay now has a resolved follow-up table for DR-15, `wfbe_structures_logic` repair consumers, client/server build drift ownership, live supply-income stagnation and base-structure marker vs range-global dependencies.
- **C4 — searchability:** [Feature status](Feature-Status-Register) and [Hardening roadmap](Hardening-Implementation-Roadmap) describe the victory bug but never cite **DR-11** by number; add it. **Status:** resolved by Codex on 2026-06-02; both pages now cite DR-11 by number alongside DR-36's mechanism.
- **C5 — sidebar dup entries:** [`_Sidebar.md`] lists Hardening-roadmap / Server-authority-map / Attack-wave-authority / Testing-workflow under **both** "Ops" and "Current Work". De-duplicate. **Status:** resolved by Codex on 2026-06-02; Current Work now stays focused on coordination/review pages, while Ops owns hardening/authority/testing pages.
- **C6 — thin citations:** [Client UI HUD and menus](Client-UI-HUD-And-Menus) (no `path:line` citations at all), parts of [Gameplay atlas](Gameplay-Systems-Atlas) (file-level only) and [AI/headless](AI-Headless-And-Performance) — raise toward the project's `path:line` standard. **Status:** resolved by Codex on 2026-06-02; UI/HUD now has path:line anchors for resource includes, dialog IDDs/controllers, RHUD/FPS toggles and respawn marker tracking; AI/headless cites HC bootstrap, delegation, town-AI cleanup, server-FPS and `GetSleepFPS`; Gameplay cites town init/capture/AI, economy, commander, upgrades, construction and factory source anchors.

## D. Already fixed by Claude (this program) — no Codex action

- Ledger: matrix timestamp → 2026-06-02; legend clarified (reviewed-clean vs reviewed-with-finding); Modules + Markers/cleaners Map cells downgraded to 🟡 (Modules returns to ✅ when the module atlas lands).
- Deep-Review-Findings: DR-11 severity normalized to High; DR-36 dual-purpose disambiguation note.
- `agent-context.json` `systems` map: +5 missing ledger subsystems.
- New Claude pages this program: [Variable and naming conventions](Variable-And-Naming-Conventions), [Public variable channel index](Public-Variable-Channel-Index), [Modules atlas](Modules-Atlas), [Pending owner decisions](Pending-Owner-Decisions) (and this audit page). **Status:** wired into `_Sidebar.md`, `_Footer.md`, Home and `agent-context.json` by Codex on 2026-06-02.

## How to consume

Work A→B→C in priority order; C1/C2 are the highest reader-impact (a developer browsing an atlas currently never meets the relevant finding). Each dedup edit should *remove* the copy and leave a one-line cross-link to the canonical home, so a future finding update only edits one page.

## Round 2 (2026-06-02) — full 60-page audit follow-up (Codex-lane items)

A second full audit (all 60 pages, accuracy/consistency/coverage). Wiki is healthy: **no broken links, no orphan pages, DR severities consistent everywhere, dedup landed cleanly.** Claude-lane fixes already applied (DR-8→DR-6 xref in the conventions page; `Server_HandlePVF.sqf`/`Client_HandlePVF.sqf` path clarity; DR-45 filed for the town-AI passenger-vehicle bug; DR-44 cross-linked). Remaining items are on **Codex's pages**:

**Accuracy (correctness) — do first:**
- ✅ **R2-1 resolved (Medium):** [Client UI systems atlas](Client-UI-Systems-Atlas) is now a redirect route, and [Client UI HUD and menus](Client-UI-HUD-And-Menus) has the corrected mapping: DR-16 = structure-sale client-authority, DR-17 = duplicate dialog IDD 23000, DR-24 = dead `RscMenu_Upgrade`, DR-25a/b = duplicate title IDD 10200 plus malformed `soundPush[]`, and gear/EASA/service authority = DR-28.
- ✅ **R2-2 resolved (Medium):** [SQF atlas](SQF-Code-Atlas) now presents compile counts as a 2026-06-02 point-in-time recount with the regeneration command and a DR-5 caveat.
- ✅ **R2-3 resolved (Medium):** [SQF atlas](SQF-Code-Atlas) now cites DR-34 definitively: MASH map markers are dead/abandoned; MASH tents remain a separate deployable officer feature.

**Orphaned cross-links (add the DR where a developer would look):**
- ✅ **R2-4 resolved:** **DR-44** (`wfbe_supply_temp_<side>` forgery) is now surfaced from [Economy](Economy-Towns-And-Supply), [Networking](Networking-And-Public-Variables), [Public variable channel index](Public-Variable-Channel-Index), [Server runtime atlas](Server-Gameplay-Runtime-Atlas) and [Feature status](Feature-Status-Register), with detailed proof kept in [Deep-review findings](Deep-Review-Findings).
- ✅ **R2-5 resolved:** **DR-20** (HQ-killed duplicate processing / score exploit) is now visible from [Construction atlas](Construction-And-CoIn-Systems-Atlas), [Gameplay atlas](Gameplay-Systems-Atlas) and [Server runtime atlas](Server-Gameplay-Runtime-Atlas), with full proof kept in [Deep-review findings](Deep-Review-Findings).
- ✅ **R2-6 resolved:** [WASP overlay](WASP-Overlay) already cited **DR-40** by number; [Server runtime atlas](Server-Gameplay-Runtime-Atlas) now names the hosted/listen FPS busy loop as **DR-19**.
- ✅ **R2-7 resolved:** **DR-45** is now cross-linked from [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety) and [AI/headless](AI-Headless-And-Performance), with the detailed source proof kept in [Deep-review findings](Deep-Review-Findings) Round 36.

**Thin citations (lower priority):** ✅ resolved by Codex on 2026-06-02; [Core systems index](Core-Systems-Index), [Architecture overview](Architecture-Overview) and [Content structure and maps](Content-Structure-And-Maps) now include representative `path:line` source-anchor tables.

**Current-work reconcile (Codex status pages):**
- ✅ **R2-8 resolved (Medium):** [Coordination board](Coordination-Board) now separates current roles/snapshot from the historical lane ledger, names Claude as collaboration-follow with latest DR-45, and marks the old scout/victory lanes as harvested history rather than active claims.
- ✅ **R2-9 resolved (Low):** [Progress dashboard](Progress-Dashboard) no longer carries the stale "At A Glance" Claude row and now routes current bottlenecks through [Bottleneck removal queue](Bottleneck-Removal-Queue).
- ✅ **R2-10 resolved (Low):** `_Sidebar.md` no longer lists `Headless-Delegation-And-Failover-Playbook` twice; the sidebar now adds only the current bottleneck queue route.

**Do NOT "fix" (audit false positives, verified at source):** the `Public-Variable-Channel-Index` PVF line ranges `:8-20`/`:23-37` are correct; an audit pass miscounted blank lines. DR-15's `_side = _this` line number is correct, but the code is still the current-source-unpatched caller-shape bug; use [Commander reassignment call shape](Commander-Reassignment-Call-Shape) and [Current source status snapshot](Current-Source-Status-Snapshot) before changing that lane.

## Continue Reading

Canonical findings: [Deep-review findings](Deep-Review-Findings) | Scoreboard: [Codebase coverage ledger](Codebase-Coverage-Ledger) | Map: [Home](Home)

## E. Compact bootstrap split (2026-06-03)

| Topic | Canonical home | Route pages to remove duplication |
| --- | --- | --- |
| LLM bootstrap vs execution guidance | [AI-Assistant-Guide](AI-Assistant-Guide) | [AI-Assistant-Developer-Guide](AI-Assistant-Developer-Guide) remains execution rules; Home/_Sidebar/llms.txt now use the compact bootstrap page as first read. |

### Why this was split

- The large developer guide (`AI-Assistant-Developer-Guide`) carried both bootstrap and execution guidance; agents were loading it directly and missing critical click-through targets.
- The compact `AI-Assistant-Guide` now acts as the first-touch page and then routes into execution/playbook/atlas pages.
- This keeps future LLM onboarding stable as feature docs evolve and avoids duplicate bootstrap text.

## F. LLM-onboarding duplication watch (2026-06-03)

| Topic | Canonical home | Route pages to remove duplication |
| --- | --- | --- |
| bootstrap vs execution guidance | [AI-Assistant-Guide](AI-Assistant-Guide) | [AI-Assistant-Developer-Guide](AI-Assistant-Developer-Guide), [Home](Home), [`llms.txt`](llms.txt), [_Sidebar.md](_Sidebar.md), [Progress-Dashboard](Progress-Dashboard) now keep a compact first-read path and remove duplicate bootstrap language. |

### Resolved watchpoint (2026-06-04)

- The onboarding watchpoint is resolved as of `docs-knowledge-clickthrough-2026-06-04-1022`: duplicate "how to start" language did not reappear in `AI-Assistant-Guide`, `AI-Assistant-Developer-Guide`, `Home`, or `llms.txt`.
- Keep onboarding routing centralized in `AI-Assistant-Guide`; execution rules and proof routes stay in atlases/subsystem playbooks.
