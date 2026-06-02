# Coordination Board

This board lets Codex, Claude and future assistants coordinate without relying on chat memory.

## Shared Goal

Create and maintain a deep developer wiki for `rayswaynl/a2waspwarfare`, covering architecture, mission/server systems, tooling, integrations, performance work, broken/partial/deferred features, PR #1 supply helicopters, and agent-ready development context.

## Roles

| Agent | Current ownership | Expected output |
| --- | --- | --- |
| Codex | Initial wiki implementation, repo/wiki publishing, source inventory, agent context artifact. | Wiki pages, `docs/wiki` mirror, `agent-context.json`, worklog entry. |
| Claude | Independent review/deepening pass after Codex publish. | Add findings to `Agent-Worklog.md`; propose or commit wiki improvements without overwriting Codex work. |
| Future agents | Feature-specific docs upkeep and code-change handoffs. | Update relevant wiki pages and `agent-context.json` when architecture or workflows change. |

## Shared Files

- `docs/wiki/Agent-Context.md`: human-readable AI context.
- `docs/wiki/agent-context.json`: machine-readable repo map and safe-development facts.
- `docs/wiki/Claude-Goal.md`: copy/paste `/goal` for Claude.
- `docs/wiki/Documentation-Implementation-Plan.md`: implementation roadmap for future documentation passes.
- `docs/wiki/Agent-Worklog.md`: append-only agent-visible worklog.
- `docs/wiki/Feature-Status-Register.md`: open risks, partial features and missing features.
- `Tools/ValidateWiki.ps1`: docs/machine-context validation gate.

## Active Lanes

| Date | Agent | Lane | Status |
| --- | --- | --- | --- |
| 2026-06-02 | Codex | `external-reference-gateway-upgrade` | Complete: expanded `Arma-2-OA-External-Reference-Guide.md` into a compact first-stop router for official BI OA command docs, Wasp subsystem pages and common engine-claim mistakes. |
| 2026-06-02 | Codex | `collaboration-protocol-gateway-upgrade` | Complete: expanded `Agent-Collaboration-Protocol.md` into a concise read-order, collision-check, update-surface and validation guide. |
| 2026-06-02 | Codex | `wiki-mirror-route-parity-repair` | Complete: added gateway pages/files for concurrently restored route links, refreshed `agent-context.json` page arrays and restored full `Tools/ValidateWiki.ps1` pass. |
| 2026-06-02 | Codex | `agent-status-concurrent-state-reconcile` | Complete: reconciled with the newer `agent-status.json` shape; `agents.Codex` and `agents.Codex-2` are intentional separate status surfaces, so no active-agent cleanup is pending. |
| 2026-06-02 | Codex | `supply-scan-patch-status-reconcile` | Complete: reconciled docs and machine context with current Chernarus source plus Vanilla Takistan `["Base_WarfareBUAVterminal"]` scan patch; Arma smoke remains. |
| 2026-06-02 | Codex | `backlog-supply-scan-candidate-sync` | Complete: synced `agent-hardening-backlog.jsonl` supply cleanup entry with the exact `["Base_WarfareBUAVterminal"]` scan candidate and validation notes. |
| 2026-06-02 | Codex | `supply-scan-class-filter-handoff` | Complete: grounded supply command-center scan narrowing in source and BI nearestObjects/isKindOf docs; later source/Vanilla patch status is captured by `supply-scan-patch-status-reconcile`. |
| 2026-06-02 | Codex | `hosted-fps-current-status-reconcile` | Complete: reconciled AI/headless, performance sweep and machine context with the source/Vanilla hosted-FPS early-exit patch; Arma smoke remains. |
| 2026-06-02 | Codex | `tool-command-smoke-notes` | Complete: locally verified LoadoutManager build and PerformanceAuditAnalyzer command shape, then documented remaining real generation/RPT audit gates. |
| 2026-06-02 | Codex | `windows-safe-search-snippets` | Complete: updated Quickstart and AI guide source-search examples to use `$SourceMission` plus `Test-Path -LiteralPath` for bracketed mission paths. |
| 2026-06-02 | Codex | `home-route-map-compression` | Complete: compressed Home into task-oriented routes and moved current source/Vanilla patch follow-ups into a clean current-state block. |
| 2026-06-02 | Codex | `deep-review-current-status-notes` | Complete: added current-status notes to DR-2 and related handoffs so paratrooper marker registration is source/Vanilla patched, smoke pending. |
| 2026-06-02 | Codex | `atlas-source-status-reconcile` | Complete: updated SQF atlas and AI/headless wording to match current paratrooper PVF and duplicate `Skill_Init` source/Vanilla patch state. |
| 2026-06-02 | Codex | `wiki-validation-exact-machine-refs` | Complete: strengthened `Tools/ValidateWiki.ps1` to validate exact machine-file references to wiki pages, agent JSON/JSONL files and repo PowerShell tools. |
| 2026-06-02 | Codex | `client-skill-context-reconcile` | Complete: reconciled Function/Module, Performance Sweep and machine context with the source/Vanilla duplicate `Skill_Init` cleanup; Arma smoke remains. |
| 2026-06-02 | Codex | `coordination-routing-refresh` | Complete: updated live coordination guidance away from retired auxiliary coordination files and toward current board/worklog/status/backlog artifacts. |
| 2026-06-02 | Codex | `wiki-validation-page-parity` | Complete: strengthened `Tools/ValidateWiki.ps1` to require `agent-context.json` page-list parity with the actual wiki mirror and validate repo tool references. |
| 2026-06-02 | Codex | `wiki-validation-tooling` | Complete: added `Tools/ValidateWiki.ps1` and routed docs-only handoff validation through one reusable command. |
| 2026-06-02 | Codex | `machine-file-refresh` | Complete: replaced stale `agent-status.json` and `agent-hardening-backlog.jsonl` with concise current machine artifacts and wired them back into `agent-context.json`. |
| 2026-06-02 | Codex | `machine-file-authority-note` | Complete: fixed duplicate `agent-context.json` machine-file listing and clarified that local untracked `agent-hardening-backlog.jsonl` / `agent-status.json` are legacy or inactive unless refreshed against the current mirror. |
| 2026-06-02 | Codex | `paratrooper-marker-context-reconcile` | Complete: reconciled abandoned-feature and machine-context notes with current source/Vanilla `HandleParatrooperMarkerCreation` registration; remaining work is Arma smoke and modded-mission propagation cleanup. |
| 2026-06-02 | Codex | `antistack-trust-loop-drilldown` | Complete: added AntiStack external DB trust, response parsing, polling, scoring/player-list loops, join/disconnect/endgame persistence, skill compensation and launch-ACK routing notes. |
| 2026-06-02 | Codex | `pvf-handler-payload-drilldown` | Complete: added registered server-bound PVF payload trust/mutation notes for construction/MHQ repair, RequestSpecial tags, upgrades, score mutation, commander/vote, team updates, vehicle lock/auto-wall and join handshake. |
| 2026-06-02 | Codex | `direct-pv-handler-drilldown` | Complete: added handler-family trust/mutation notes for attack-wave, side-supply temp, supply missions, supply value/cooldown pulls, AntiStack launch ACK, AFK/BattlEye, marker/message/display events and server-origin status broadcasts. |
| 2026-06-02 | Codex | `server-module-risk-classes` | Complete: separated Server/Module into direct PV/PVEH receivers, AntiStack external DB trust boundary, AntiStack scheduled loops, supply mission authority/performance, NEURO AI taxi and FPS/dormant duplicate wiring surfaces. |
| 2026-06-02 | Codex | `client-module-risk-classes` | Complete: separated Client/Module into server-bound PV/PVEH channels, construction/loadout authority surfaces, skill/action world mutators, local vehicle/effects modules, UI/control-loop modules and dormant/verify-first edges. |
| 2026-06-02 | Codex | `common-module-risk-classes` | Complete: separated Common/Module into CIPHER utility/setup, IRS countermeasure/effects, Arty ordnance/world-object simulation and dormant/verify-first Reaktiv damage-model surfaces. |
| 2026-06-02 | Codex | `server-function-risk-classes` | Complete: separated Server/Functions into PVF/direct-PV handlers, economy/upgrade state, AI/team purchase and vehicle lifecycle, structure/HQ lifecycle, AI delegation/town defense, player lifecycle/persistence and lookup helper risk classes. |
| 2026-06-02 | Codex | `client-function-risk-classes` | Complete: separated Client/Functions into lookup, UI/marker, economy/service, purchase/world creation, PVF receive, HC delegation, player-AI/action and profile/template risk classes. |
| 2026-06-02 | Codex | `performance-opportunity-sweep-integration` | Complete: integrated the performance sweep into Home, AI/headless, roadmap and agent context while keeping patch order centralized. |
| 2026-06-02 | Codex | `common-function-risk-classes` | Complete: separated Common/Functions lookup helpers from PVF wrappers, direct-PV helpers, shared-state mutators, world mutators, marker/message helpers and profile/audit persistence. |
| 2026-06-02 | Codex | `external-arma2-oa-reference-index` | Complete: added compact official-reference map and linked it from onboarding/networking. |
| 2026-06-02 | Codex | `external-oa-command-guardrails` | Complete: corrected the stale `isEqualTo` OA claim and added command-availability guardrails for PVF hardening docs. |
| 2026-06-02 | Codex | `server-cleanup-restorer-map` | Complete: mapped server garbage/empty-vehicle collectors plus dropped-item/crater/ruin/mine cleaners and building restorer into AI/headless, closing the ledger Map partial. |
| 2026-06-02 | Codex | `stale-link-quickstart-navigation` | Complete: repaired stale internal links, added quickstart, and aligned `agent-context.json` page list. |
| 2026-06-02 | Codex | `codex-handoff-integration-dr39-dr43` | Complete: folded DR-39/40/42/43 handoffs into focused topic pages and `agent-context.json`. |
| 2026-06-02 | Codex | `authority-runtime-handoff-integration` | Complete: folded DR-27/28/31/34/36/37/38/41 into networking, economy, UI, integrations, lifecycle, status and agent context. |
| 2026-06-02 | Codex | `atlas-accuracy-crosslinks-c1-c4` | Complete: resolved Wiki-Quality-Audit C1-C4 with DR cross-links, stale question cleanup and victory searchability. |
| 2026-06-02 | Codex | `new-connective-page-navigation` | Complete: wired modules/naming/PV-channel/owner-decision/PVF-playbook pages into Home, AI guide and `agent-context.json`. |
| 2026-06-02 | Codex | `ui-thin-citation-c6` | Complete: raised Client UI page to source-line citation standard for menus, gear, RHUD, marker loops and known UI defects. |
| 2026-06-02 | Codex | `ai-headless-thin-citation-c6` | Complete: raised AI/headless page to source-line citation standard for delegation, HC lifecycle, town AI, watchdog/recovery and performance audit surfaces. |
| 2026-06-02 | Codex | `gameplay-atlas-thin-citation-c6` | Complete: raised Gameplay atlas to source-line citation standard for town/capture/economy/commander/upgrades/construction/factories/victory and closed verified open questions. |
| 2026-06-02 | Codex | `direct-pv-channel-dedup-dup11` | Complete: made Public variable channel index the canonical PVF/direct-channel inventory and reduced duplicate tables in Networking and SQF atlas. |
| 2026-06-02 | Codex | `loadoutmanager-drift-dedup-dup4` | Complete: kept Tools as the source-line rule/status home for generated missions while pointing detailed modded drift counts to DR-32. |
| 2026-06-02 | Codex | `hc-failover-dedup-dup10` | Complete: kept DR-21 as the canonical HC no-failover analysis while AI/headless and lifecycle pages now act as routing/source-anchor pages. |
| 2026-06-02 | Codex | `lifecycle-waitchain-dedup-dup6` | Complete: kept Lifecycle wait-chain as the canonical role/boot-order page and reduced duplicate flag/role summaries in Mission entrypoints and SQF atlas. |
| 2026-06-02 | Codex | `supply-cooldown-dedup-dup7` | Complete: kept DR-18 plus Supply Mission Architecture as the canonical cooldown casing home and reduced Economy/Status/Plan to links. |
| 2026-06-02 | Codex | `battleye-posture-dedup-dup5` | Complete: kept External Integrations + DR-30 as the canonical BattlEye posture home and reduced Networking/Feature Status/roadmap pages to routing notes. |
| 2026-06-02 | Codex | `construction-authority-dedup-dup8` | Complete: kept DR-6 as the canonical construction-authority proof while Gameplay atlas and Economy Authority First Cut now route to it from call-path/sequence notes. |
| 2026-06-02 | Codex | `victory-endgame-dedup-dup9` | Complete: kept DR-11/DR-36 as the canonical victory correctness home while Gameplay atlas, Lifecycle, Feature Status and Plan route to them. |
| 2026-06-02 | Codex | `icbm-authority-dedup-dup3` | Complete: kept DR-27 as the canonical ICBM authority proof while Networking, Feature Status and Modules Atlas route to it. |
| 2026-06-02 | Codex | `pvf-dispatch-dedup-dup1` | Complete: kept PVF dispatch playbook + DR-1/DR-38 as canonical generic dispatcher hardening home while first-stop pages route to it. |
| 2026-06-02 | Codex | `economy-authority-dedup-dup2` | Complete: kept Economy as the client-authoritative class synthesis and Economy Authority First Cut as patch sequencing while Feature Status, Client UI/HUD and agent context route to them. |
| 2026-06-02 | Codex | `authority-plan-merge1` | Complete: consolidated the retired server-authority map concept into Documentation Implementation Plan Workstream 0 with authority principles, handler validation checklist and links to focused playbooks. |
| 2026-06-02 | Codex | `lifecycle-entrypoints-merge3` | Complete: split page ownership so Mission Entrypoints covers front doors/object init and Lifecycle Wait-Chain covers role truth table, boot ordering, flags, JIP waits and HC timing. |
| 2026-06-02 | Codex | `ui-quick-reference-merge2` | Complete: kept Client UI/HUD as the current compact UI implementation map and quick-reference gateway; no separate UI atlas remains in the mirror. |
| 2026-06-02 | Codex | `gameplay-gateway-reduce4` | Complete: reduced Gameplay atlas economy/construction/factory duplication to source-anchor gateway summaries that route details to Economy, Economy Authority First Cut and DR findings. |
| 2026-06-02 | Codex | `function-index-source-map` | Complete: upgraded Function and Module Index with source-backed compile registry owners and high-impact function routing table. |
| 2026-06-02 | Codex | `feature-status-triage-view` | Complete: added severity/blast-radius triage view to Feature Status and routed each bucket to canonical owner pages. |

## Coordination Rules

- Append worklog entries instead of replacing another agent's notes.
- Link claims to source files or wiki pages.
- Keep gameplay-code changes out of documentation-only branches unless explicitly requested.
- If changing mission code later, edit Chernarus source and run LoadoutManager propagation.
- When an agent finds a contradiction, record it in `Agent-Worklog.md` and update the affected wiki page.

## Review Gates

- Wiki pages link-check cleanly.
- `docs/wiki` mirror matches the wiki pages.
- `agent-context.json` stays valid JSON.
- Any broken/partial feature claim cites concrete source evidence.
- No Arma 3-only scripting assumptions are introduced.

