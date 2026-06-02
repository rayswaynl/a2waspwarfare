# Wiki Quality Audit — Codex-Lane Punch-List

> Claude-owned audit (2026-06-02). A one-stop punch-list of wiki-quality items that fall in **Codex's lane** (navigation, atlas pages, page structure, mirror parity). Claude already fixed the items in its own lane (ledger accuracy, DR-11 severity, DR-36 disambiguation, `agent-context.json` systems map, and the new connective pages). This page lists the **dedup → cross-link**, **page-merge**, and **accuracy** work for Codex to action on the atlas/nav pages it owns. Method: three parallel source-grounded audits (duplication, accuracy, gaps). No broken internal links were found (positive). Canonical-home principle: keep one source-of-truth per fact and replace the copies with a cross-link.

## A. Duplicated content → replace copies with a cross-link

Each row: the fact, its **canonical home**, and the pages carrying a redundant near-copy that should become a link.

| # | Topic | Canonical home | Redundant copies to replace with a link |
| --- | --- | --- | --- |
| DUP-1 | PVF `Call Compile` trust boundary / dispatch RCE | [Deep-review findings](Deep-Review-Findings) DR-1 (+ Round 3 playbook) | Done 2026-06-02/Codex: [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook) + DR-1/DR-38 remain canonical; [Networking](Networking-And-Public-Variables), [Feature Status](Feature-Status-Register), [Public Variable Channel Index](Public-Variable-Channel-Index), and agent context route to them instead of re-expanding patch shape. |
| DUP-2 | Client-authoritative economy synthesis table (build/buy/sell/supply/upgrade/ICBM/gear) | [Economy](Economy-Towns-And-Supply) synthesis table + DR-6/14/16/22/23/27/28 evidence | Done 2026-06-02/Codex: [Economy](Economy-Towns-And-Supply#authority-model) remains the class synthesis and [Economy authority first cut](Economy-Authority-First-Cut) remains the patch-sequencing page; [Feature status](Feature-Status-Register), [Client UI/HUD](Client-UI-HUD-And-Menus#gear-easa-and-service-authority), and active agent context now route there instead of restating the full economy class. |
| DUP-3 | ICBM/Nuke client-authoritative chain (DR-27) | [Deep-review findings](Deep-Review-Findings) DR-27 | done 2026-06-02/Codex: Networking, Feature Status and Modules Atlas now keep source-route/module notes and route payload proof, impact and fix shape to DR-27 |
| DUP-4 | Generated-mission drift / LoadoutManager skip-list | [Tools and build](Tools-And-Build-Workflow) (rules + status table) and DR-4/DR-32 for analysis | done 2026-06-02/Codex: Tools keeps source-line skip-list rules plus a compact generated-mission status table; detailed modded drift counts stay in DR-32 |
| DUP-5 | BattlEye posture (22-byte `kickAFK` stub, no `scripts.txt`) | [External integrations](External-Integrations) BattlEye section + DR-30 | done 2026-06-02/Codex: External Integrations keeps the source-backed repo posture; Feature Status, Networking and roadmap/migration pages now route there instead of repeating the filter inventory |
| DUP-6 | Lifecycle / boot wait-chain + role truth table | [Lifecycle wait-chain](Lifecycle-Wait-Chain) | done 2026-06-02/Codex: [Mission entrypoints](Mission-Entrypoints-And-Lifecycle) keeps entrypoint/init-owner summaries, [SQF atlas](SQF-Code-Atlas#init-owners) links to Lifecycle for role truth table and branch ordering |
| DUP-7 | Supply-mission cooldown casing (DR-18, `lastSupplyMissionRun`) | [Deep-review findings](Deep-Review-Findings) DR-18 + [Supply mission arch](Supply-Mission-Architecture) | done 2026-06-02/Codex: Economy/Feature Status/Implementation Plan now route to Supply Mission Architecture + DR-18 instead of carrying separate mismatch explanations |
| DUP-8 | Construction authority (DR-6, class-existence-only checks) | [Deep-review findings](Deep-Review-Findings) DR-6 | done 2026-06-02/Codex: Gameplay atlas keeps construction call-path anchors, Economy Authority First Cut keeps implementation sequencing, and both route exploit proof/validation rationale to DR-6 |
| DUP-9 | Victory/endgame double-fire (DR-11/DR-36) | [Deep-review findings](Deep-Review-Findings) DR-11 + DR-36 | done 2026-06-02/Codex: Gameplay atlas, Lifecycle, Feature Status and Implementation Plan now route victory-loop correctness readers to DR-11/DR-36 instead of carrying separate mechanism summaries |
| DUP-10 | HC delegation, no failover (DR-21) | [Deep-review findings](Deep-Review-Findings) DR-21 | done 2026-06-02/Codex: [AI/headless](AI-Headless-And-Performance#hc-delegation-routing) keeps routing/source anchors, [Lifecycle wait-chain](Lifecycle-Wait-Chain) stays boot-order-only, and DR-21 remains the canonical failover analysis |
| DUP-11 | Direct public-variable channel table | the new [Public variable channel index](Public-Variable-Channel-Index) | done 2026-06-02/Codex: [Networking](Networking-And-Public-Variables) and [SQF atlas](SQF-Code-Atlas) now point to the index instead of maintaining duplicate command/channel inventories |

## B. Overlapping pages → merge or reduce to summary + cross-link

- **MERGE-1 (highest value) — done 2026-06-02/Codex:** [Implementation plan](Documentation-Implementation-Plan#workstream-0-authority-hardening-and-handler-validation) now carries the authority principles, handler validation checklist and route table. Focused source/patch bodies stay in [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook), [Economy authority first cut](Economy-Authority-First-Cut), [Networking](Networking-And-Public-Variables#authority-surfaces-to-audit-together), [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook) and [External integrations](External-Integrations#battleye-filter).
- **MERGE-2 — done 2026-06-02/Codex:** [Client UI HUD and menus](Client-UI-HUD-And-Menus) is now the current compact UI implementation map and quick-reference gateway. No larger client UI atlas exists in the mirror; if one lands later, fold this page into its quick-reference section.
- **MERGE-3 — done 2026-06-02/Codex:** [Mission entrypoints](Mission-Entrypoints-And-Lifecycle) owns the `description.ext` include graph, `initJIPCompatible.sqf`, mission-object town init and per-role init responsibilities. [Lifecycle wait-chain](Lifecycle-Wait-Chain) owns machine roles, boot ordering, global flag dependencies, JIP waits and HC timing caveats.
- **REDUCE-4 — done 2026-06-02/Codex:** [Gameplay atlas](Gameplay-Systems-Atlas) keeps source anchors and gateway summaries for economy, construction and factories while routing detailed authority/economy sequencing to [Economy](Economy-Towns-And-Supply), [Economy authority first cut](Economy-Authority-First-Cut) and DR-6/DR-14/DR-22/DR-23.

## C. Accuracy fixes (Codex pages)

- **C1 (HIGH) — stale, contradicts a finding:** [Networking](Networking-And-Public-Variables) MASH row says the server relay is "live" and cites DR-3. DR-34 superseded this: the feature is **dead on both ends** (trigger never broadcast + receiver commented `Init_Client.sqf:132` + orphaned server PVEH). Update the row to DR-34 and drop "server relay live". (Feature-Status-Register is already correct — they currently disagree.) **Status:** resolved by Codex on 2026-06-02; Networking now cites DR-34 and describes the orphaned server PVEH instead of a live relay.
- **C2 (HIGH) — orphaned findings, zero DR cross-links on atlas pages a developer actually opens — done 2026-06-02/Codex:** Added cross-links:
  - [Gameplay atlas](Gameplay-Systems-Atlas): DR-6 (construction), DR-14 (purchase authority), DR-11 (victory inversion), DR-22 (supply windfall), DR-23 (upgrade forgery), DR-15 (commander-assign bug).
  - [Client UI HUD and menus](Client-UI-HUD-And-Menus): DR-16, DR-17, DR-24, DR-25a/b.
  - [AI/headless](AI-Headless-And-Performance): DR-21, DR-42.
  - [Gameplay atlas: construction](Gameplay-Systems-Atlas#construction-and-base-structures): DR-6 (currently links DR-1 only).
  - [Mission entrypoints](Mission-Entrypoints-And-Lifecycle): DR-37, DR-43a.
- **C3 — stale "Open Questions" — done 2026-06-02/Codex:** [Gameplay atlas](Gameplay-Systems-Atlas) now records `Server_AssignNewCommander` as confirmed DR-15 instead of an open question.
- **C4 — searchability — done 2026-06-02/Codex:** [Feature status](Feature-Status-Register) and [Implementation plan](Documentation-Implementation-Plan) now cite **DR-11** by number for the victory bug.
- **C5 — not applicable in current mirror:** `_Sidebar.md` / `_Footer.md` are no longer present in `docs/wiki`; current navigation is driven by [Home](Home), per-page Continue Reading blocks and `agent-context.json`. No duplicate sidebar entries remain to edit.
- **C6 — thin citations — done 2026-06-02/Codex:** [Client UI HUD and menus](Client-UI-HUD-And-Menus) now has source line anchors for resource includes, dialog `onLoad` wiring, buy-unit client authority, gear template helpers, UI defects, RHUD/FPS HUD and marker loops. [AI/headless](AI-Headless-And-Performance) now has source line anchors for delegation setup, HC registration/disconnect, town-AI spawn/despawn, player-AI watchdog/recovery, performance audit rows, server FPS publishers and `GetSleepFPS`. [Gameplay atlas](Gameplay-Systems-Atlas) now has source line anchors for town initialization/capture loops, economy/resource flow, commander voting, upgrades, construction, factories/unit production and victory/endgame behavior.

## D. Already fixed by Claude (this program) — no Codex action

- Ledger: matrix timestamp → 2026-06-02; legend clarified (reviewed-clean vs reviewed-with-finding); Modules + Markers/cleaners Map cells downgraded to 🟡 (Modules returns to ✅ when the module atlas lands).
- Deep-Review-Findings: DR-11 severity normalized to High; DR-36 dual-purpose disambiguation note.
- `agent-context.json` `systems` map: +5 missing ledger subsystems.
- New Claude/connective pages are now present and wired into Home / `agent-context.json`: [Variable and naming conventions](Variable-And-Naming-Conventions), [Public variable channel index](Public-Variable-Channel-Index), [Modules atlas](Modules-Atlas), [Pending owner decisions](Pending-Owner-Decisions), [PVF dispatch implementation playbook](PVF-Dispatch-Implementation-Playbook) and this audit page. `_Sidebar.md` / `_Footer.md` are not present in the mirror.

## How to consume

Work A→B→C in priority order; C1/C2 are the highest reader-impact (a developer browsing an atlas currently never meets the relevant finding). Each dedup edit should *remove* the copy and leave a one-line cross-link to the canonical home, so a future finding update only edits one page.

## Continue Reading

Canonical findings: [Deep-review findings](Deep-Review-Findings) | Scoreboard: [Codebase coverage ledger](Codebase-Coverage-Ledger) | Map: [Home](Home)
