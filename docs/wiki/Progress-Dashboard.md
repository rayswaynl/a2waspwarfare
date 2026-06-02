# Progress Dashboard

This is the shared human + AI interface for seeing what Codex, Claude and Codex sub-agents are doing right now.

Keep this page open when parallel documentation work is running. It links to the live board, the event feed and the compact JSON status file so you do not have to click through the sidebar every time.

## Latest Batch

| Lane | Status | Output |
| --- | --- | --- |
| `wiki-quality-dup6-lifecycle-routing` | Published | [Lifecycle wait-chain](Lifecycle-Wait-Chain) now remains the canonical home for lifecycle flags, boot ordering, JIP waits and HC wait hazards; [Server runtime](Server-Gameplay-Runtime-Atlas) and [SQF atlas](SQF-Code-Atlas) route there instead of restating boot/role details. |
| `wiki-quality-dup9-victory-routing` | Published | [Deep-review findings](Deep-Review-Findings) DR-11/DR-36 now own the victory/endgame double-fire mechanism; [Server runtime](Server-Gameplay-Runtime-Atlas), [Hardening roadmap](Hardening-Implementation-Roadmap) and [Feature status](Feature-Status-Register) keep short routing summaries. |
| `wiki-quality-dup5-battleye-routing` | Published | [External integrations](External-Integrations) now owns shipped BattlEye posture; [Feature status](Feature-Status-Register), [Networking/PV](Networking-And-Public-Variables), [Hardening roadmap](Hardening-Implementation-Roadmap) and [Server authority map](Server-Authority-Migration-Map) route there instead of repeating the `kickAFK`/missing-filter evidence. |
| `performance-opportunity-sweep` | Published | [Performance opportunity sweep](Performance-Opportunity-Sweep) ranks PVF dispatch lookup, hosted FPS loops, supply scans, duplicate `Skill_Init`, factory queue churn, WASP marker polling and audit-first cleaner/marker loops. |
| `icbm-authority-playbook-routing` | Published | [ICBM authority](ICBM-Authority-Playbook) turns DR-27 into a patch-ready guide and routes duplicated ICBM/Nuke authority detail from the roadmap, authority map, feature status and navigation into one canonical page. |
| `wiki-quality-merge1-authority-routing` | Published | [Hardening roadmap](Hardening-Implementation-Roadmap) now owns patch order and validation gates; [Server authority map](Server-Authority-Migration-Map) owns authority design principles, flow table and handler checklist. |
| `wiki-quality-dup10-hc-routing` | Published | [AI/headless](AI-Headless-And-Performance) is now the concise HC runtime source router, [Lifecycle wait-chain](Lifecycle-Wait-Chain) owns HC boot timing only, and [HC delegation/failover](Headless-Delegation-And-Failover-Playbook) owns DR-21/DR-42 patch policy. |
| `external-arma2-reference-guide` | Published | [Arma 2 OA external reference guide](Arma-2-OA-External-Reference-Guide) maps official BI docs to Wasp PV/PVEH, JIP, object-var, event-handler, object-scan and performance hotspots. |
| `abandoned-feature-revival-review` | Published | [Abandoned feature revival](Abandoned-Feature-Revival-Review) classifies MASH/paratrooper marker edges, AI supply trucks, UAV 007, WASP legacy actions, stale upgrade UI and modded mission propagation into revive/remove/leave-dormant decisions. |
| `wiki-quality-c3-gameplay-followups` | Published | [Gameplay atlas](Gameplay-Systems-Atlas) no longer has stale open questions; resolved follow-ups now cite DR-15, structure repair consumers, live stagnation flow and range-global ownership. |
| `wiki-quality-dup11-pv-channel-index` | Published | [Public variable channel index](Public-Variable-Channel-Index) is now the canonical direct-PV inventory; [Networking/PV](Networking-And-Public-Variables) and [SQF atlas](SQF-Code-Atlas) link there instead of duplicating tables. |
| `wiki-quality-merge3-lifecycle-split` | Published | [Mission entrypoints](Mission-Entrypoints-And-Lifecycle) now owns include graph/role dispatch; [Lifecycle wait-chain](Lifecycle-Wait-Chain) owns boot ordering, JIP waits and flag dependencies. |
| `wiki-quality-merge2-ui-quickref` | Published | [Client UI/HUD](Client-UI-HUD-And-Menus) is now a compact quick-reference gateway; [Client UI systems atlas](Client-UI-Systems-Atlas) remains the canonical implementation map. |
| `wiki-quality-reduce4-gameplay-gateway` | Published | [Gameplay atlas](Gameplay-Systems-Atlas) now routes economy, construction and factory detail to the canonical atlases while keeping source-backed orientation anchors. |
| `wiki-quality-c6-gameplay-citations` | Published | [Gameplay atlas](Gameplay-Systems-Atlas) now has path:line anchors for town init/capture/AI, economy, commander, upgrades, construction, factories and attack-wave production. |
| `supply-mission-authority-cleanup-playbook` | Published | [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook) turns truck + PR #1 helicopter cargo/reward trust, cooldown casing, dead twin code and idempotency into a patch-ready playbook. |
| `wiki-quality-c6-ai-citations` | Published | [AI/headless](AI-Headless-And-Performance) now has path:line anchors for HC bootstrap, HC registry, town/static delegation, disconnect handling, town-AI cleanup, server FPS and `GetSleepFPS`. |
| `economy-authority-first-cut` | Published | [Economy authority first cut](Economy-Authority-First-Cut) sequences the economy hardening class into side-supply clamp first, then upgrade authority, construction/defense authority and deferred player-buy locality redesign. |
| `wiki-quality-c6-ui-citations` | Published | [Client UI/HUD](Client-UI-HUD-And-Menus) now has path:line anchors for Rsc includes, dialog IDDs, menu routing, RHUD/FPS toggles and respawn marker tracking. |
| `wiki-quality-c4-victory-searchability` | Published | [Feature status](Feature-Status-Register) and [Hardening roadmap](Hardening-Implementation-Roadmap) now cite DR-11 by number for the victory/endgame winner inversion bug. |
| `wiki-quality-c2-atlas-crosslinks` | Published | Atlas pages now link directly to the relevant DR records: gameplay DR-6/11/14/15/22/23, UI DR-16/17/24/25, AI DR-21/42, construction DR-6 and lifecycle DR-37/43a. |
| `pvf-dispatch-implementation-playbook` | Surfaced | [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook) is now mirrored and linked from hardening navigation; it separates DR-1/DR-38 dispatcher lookup hardening from handler authority and direct-PV channels. |
| `wiki-quality-nav-c5` | Published | New canonical pages are wired into Home/sidebar/footer, and `_Sidebar.md` no longer repeats hardening/authority/testing pages under both Ops and Current Work. |
| `wiki-quality-c1-mash-networking` | Published | [Networking/PV](Networking-And-Public-Variables) now matches DR-34: MASH marker networking is dead on both ends, not a live server relay with only a missing receiver. |
| `hc-delegation-failover-playbook` | Published | [HC delegation/failover](Headless-Delegation-And-Failover-Playbook) turns DR-21/DR-42 into an implementation-ready plan for town AI, static-defense HC update-back, HC work records and disconnect policy. |
| `dr42-dr43-reconciliation` | Ready to publish | DR-42 static-defense HC update-back and DR-43 source/version + duplicate-bind cleanups are integrated into [AI/headless](AI-Headless-And-Performance), [Feature status](Feature-Status-Register), [Hardening roadmap](Hardening-Implementation-Roadmap) and [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl). |
| `markdown-research-report-intake` | Ready to publish | [External research reports](External-Research-Reports) and [`external-research-report-manifest.json`](external-research-report-manifest.json) now track nine Markdown deep-research reports as source-check leads. |
| `attack-wave-authority-playbook` | Ready to publish | [Attack-wave authority playbook](Attack-Wave-Authority-Playbook) turns DR-41 into an implementation-ready patch guide, including server recomputation, duplicate rejection, modifier clamps and the all-side-supply spend model. |
| `attack-wave-authority-dr41` | Playbook published | DR-41 is now cross-linked from [Networking/PV](Networking-And-Public-Variables), [Hardening roadmap](Hardening-Implementation-Roadmap), [Economy](Economy-Towns-And-Supply), [Feature status](Feature-Status-Register), [Server authority map](Server-Authority-Migration-Map), [Attack-wave authority playbook](Attack-Wave-Authority-Playbook) and [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl). |
| `server-authority-migration-map` | Published | [Server authority map](Server-Authority-Migration-Map) consolidates client-trusted and payload-trusted gameplay flows into one migration plan. |
| `testing-debugging-release-workflow` | Drafted | [Testing workflow](Testing-Debugging-And-Release-Workflow) and [`agent-test-plan.schema.json`](agent-test-plan.schema.json) define validation levels, smoke packs and machine-readable test evidence. |
| `lifecycle-runtime-readout` | Verified | Anscombe report source-checked against `Missions/[55-2hc]...`; lifecycle pages now document mission-object town init and HC timing caveat. |
| `town-ai-vehicle-despawn-safety` | Published | [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety) turns the confirmed occupied-vehicle delete bug into a source-backed patch plan and validation checklist. |
| `agent-hardening-backlog-and-wave-f-integration` | Published | [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl), [Hardening roadmap](Hardening-Implementation-Roadmap), [Feature status](Feature-Status-Register), [Networking/PV](Networking-And-Public-Variables), [Lifecycle wait-chain](Lifecycle-Wait-Chain), [AI/headless](AI-Headless-And-Performance). |
| External report intake | Published | [`external-research-report-manifest.json`](external-research-report-manifest.json) plus [External research reports](External-Research-Reports). Raw extracted text and Markdown report bodies remain local only. |
| Cheap discovery wave F | Harvested | PV/security, economy, AI/perf, UI, support modules, tooling, PDF triage, town-AI vehicle safety and lifecycle wait-chain checks all returned; no active sub-agent threads remain. |

## At A Glance

| Actor | Status | Current lane | What to expect next |
| --- | --- | --- | --- |
| Codex | Active | `long-running-archivist-continuation` | Keep source-backed docs, machine files and implementation backlog aligned as new findings or gameplay work appear. Latest slice resolved Wiki Quality DUP-6 by routing lifecycle/boot truth-table detail to [Lifecycle wait-chain](Lifecycle-Wait-Chain). |
| Codex-2 | Active | `paratrooper-marker-revival` | Source-checking the paratrooper support marker callback into a minimal revival patch or patch-ready handoff; keeping it separate from broader `RequestSpecial` authority hardening. |
| Claude | Autonomous-ready | `autonomous-claude-research` | Can self-select the next bounded source-backed review lane from the coverage ledger or hardening backlog. |
| Sub-agents | None running | Wave F harvested | Latest scout outputs are summarized in [Discovery swarm](Subagent-Discovery-Swarm); all Wave F agents were closed after harvest. |
| Shared docs | Live | GitHub wiki + `docs/wiki` mirror | Wiki and docs mirror are kept in parity; see `agent-events.jsonl` and git history for commit IDs. |

## One-Link Check

| Need | Open |
| --- | --- |
| Human progress page | [Progress dashboard](Progress-Dashboard) |
| Sub-agent swarm board | [Discovery swarm](Subagent-Discovery-Swarm) |
| Detailed coordination page | [Coordination board](Coordination-Board) |
| Machine progress file | [`agent-status.json`](agent-status.json) |
| Active lanes and ownership | [`agent-collaboration.json`](agent-collaboration.json) |
| Agent-readable knowledge records | [`agent-knowledge.jsonl`](agent-knowledge.jsonl) |
| Agent-readable hardening backlog | [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl) |
| Latest event stream | [`agent-events.jsonl`](agent-events.jsonl) |
| Dated narrative notes | [Agent worklog](Agent-Worklog) |
| External report intake | [External research reports](External-Research-Reports) |
| External report manifest | [`external-research-report-manifest.json`](external-research-report-manifest.json) |

## Current Lanes

| Lane | Owner | Status | Meaning |
| --- | --- | --- | --- |
| `paratrooper-marker-revival` | Codex-2 | Active | Source-check the live paratrooper support sender, existing client marker handler and missing PVF registration; decide whether to patch the small revive or publish a focused handoff. |
| `wiki-quality-dup6-lifecycle-routing` | Codex | Published | [Wiki quality audit](Wiki-Quality-Audit) DUP-6 is resolved: lifecycle flags, boot order, JIP waits and HC wait hazards live in [Lifecycle wait-chain](Lifecycle-Wait-Chain); server/SQF atlases keep concise owner summaries. |
| `wiki-quality-dup9-victory-routing` | Codex | Published | [Wiki quality audit](Wiki-Quality-Audit) DUP-9 is resolved: victory/endgame mechanism detail lives in [Deep-review findings](Deep-Review-Findings) DR-11/DR-36, with concise routing on Server runtime, roadmap and Feature Status. |
| `wiki-quality-dup5-battleye-routing` | Codex | Published | [Wiki quality audit](Wiki-Quality-Audit) DUP-5 is resolved: shipped BattlEye posture lives in [External integrations](External-Integrations), with short routing notes on Feature Status, Networking/PV, roadmap and authority map. |
| `icbm-authority-playbook-routing` | Codex | Published | [Wiki quality audit](Wiki-Quality-Audit) DUP-3 is resolved: DR-27 ICBM/Nuke implementation detail lives in [ICBM authority](ICBM-Authority-Playbook), with short routing summaries elsewhere. |
| `performance-opportunity-sweep` | Codex-2 | Published | [Performance opportunity sweep](Performance-Opportunity-Sweep) ranks PVF dispatch lookup, hosted FPS loops, supply mission scans, duplicate `Skill_Init`, factory queue churn, WASP marker polling and audit-first cleaner/marker loops. |
| `wiki-quality-merge1-authority-routing` | Codex | Published | [Wiki quality audit](Wiki-Quality-Audit) MERGE-1 is resolved: roadmap is the patch-order hub, server-authority map is the design/checklist/table page. |
| `wiki-quality-dup10-hc-routing` | Codex | Published | [Wiki quality audit](Wiki-Quality-Audit) DUP-10 is resolved: HC runtime source routing, lifecycle boot timing and DR-21/DR-42 patch policy now have distinct page ownership. |
| `wiki-quality-c3-gameplay-followups` | Codex | Published | [Wiki quality audit](Wiki-Quality-Audit) C3 is resolved: Gameplay open questions are now source-backed resolved follow-ups. |
| `wiki-quality-dup11-pv-channel-index` | Codex | Published | [Wiki quality audit](Wiki-Quality-Audit) DUP-11 is resolved: direct-PV inventory lives in [Public variable channel index](Public-Variable-Channel-Index). |
| `wiki-quality-merge3-lifecycle-split` | Codex | Published | [Wiki quality audit](Wiki-Quality-Audit) MERGE-3 is resolved: entrypoints and wait-chain now have distinct page ownership. |
| `wiki-quality-merge2-ui-quickref` | Codex | Published | [Wiki quality audit](Wiki-Quality-Audit) MERGE-2 is resolved: the HUD/menus page is a quick-reference gateway into the full UI atlas. |
| `wiki-quality-reduce4-gameplay-gateway` | Codex | Published | [Wiki quality audit](Wiki-Quality-Audit) REDUCE-4 is resolved: Gameplay is now a gateway for detailed economy/construction/factory pages. |
| `wiki-quality-c6-gameplay-citations` | Codex | Published | Final C6 pass is done for [Gameplay atlas](Gameplay-Systems-Atlas); [Wiki quality audit](Wiki-Quality-Audit) C6 is resolved. |
| `supply-mission-authority-cleanup-playbook` | Codex-2 | Published | Use [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook) before merging PR #1 supply helicopters as baseline or patching supply mission loaded-state/cooldown authority. |
| `abandoned-feature-revival-review` | Codex-2 | Published | Use [Abandoned feature revival](Abandoned-Feature-Revival-Review) before reviving old marker/support/UI/modded-mission paths; paratrooper markers are the smallest revive, AI supply trucks need design. |
| `wiki-quality-c6-ai-citations` | Codex | Published | Second C6 pass is done for [AI/headless](AI-Headless-And-Performance). |
| `economy-authority-first-cut` | Codex-2 | Published | Use [Economy authority first cut](Economy-Authority-First-Cut) before patching side-supply clamps, upgrade authority, construction/defense authority or player-buy locality. |
| `wiki-quality-c6-ui-citations` | Codex | Published | First C6 pass is done for [Client UI/HUD](Client-UI-HUD-And-Menus); Gameplay/AI citation uplift remains open. |
| `wiki-quality-c4-victory-searchability` | Codex | Published | [Wiki quality audit](Wiki-Quality-Audit) C4 is resolved: victory/endgame pages now name DR-11 explicitly. |
| `wiki-quality-c2-atlas-crosslinks` | Codex | Published | [Wiki quality audit](Wiki-Quality-Audit) C2 is resolved: high-traffic atlas pages now point to their canonical DR findings. |
| `pvf-dispatch-implementation-playbook` | Codex-2/Codex | Ready for review | Use [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook) before changing `Init_PublicVariables.sqf`, `Server_HandlePVF.sqf` or `Client_HandlePVF.sqf`. |
| `wiki-quality-nav-c5` | Codex | Published | [Variable/naming](Variable-And-Naming-Conventions), [PV channel index](Public-Variable-Channel-Index), [Modules atlas](Modules-Atlas), [Pending owner decisions](Pending-Owner-Decisions) and [Wiki quality audit](Wiki-Quality-Audit) are reachable from the main navigation. |
| `wiki-quality-c1-mash-networking` | Codex | Published | First item from [Wiki quality audit](Wiki-Quality-Audit) is resolved: [Networking/PV](Networking-And-Public-Variables) no longer contradicts DR-34 on MASH markers. |
| `hc-delegation-failover-playbook` | Codex/future AI owner | Playbook published | Use [HC delegation/failover](Headless-Delegation-And-Failover-Playbook) before changing headless town AI, static-defense delegation or disconnect/failover behavior. |
| `dashboard-current-state-cleanup` | Codex | Published | Progress page now shows current state first; historic scout detail lives in swarm/worklog pages. |
| `town-ai-vehicle-despawn-safety` | Codex/future code owner | Playbook published | The confirmed occupied-vehicle deletion bug now has a dedicated implementation playbook; next step is a gameplay patch in the Chernarus source mission when code work is claimed. |
| `attack-wave-authority-dr41` | Future code owner | Playbook published | `ATTACK_WAVE_INIT` is confirmed high-risk; use [Attack-wave authority playbook](Attack-Wave-Authority-Playbook), [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl) and [Server authority map](Server-Authority-Migration-Map) before patching. |
| `server-authority-migration-map` | Codex/future code owner | Published | Use the map before patching PVF dispatch, ICBM, economy, supply, support or BattlEye-sensitive authority flows. |
| `testing-debugging-release-workflow` | Codex/future agent | Drafted | Publish and use the test workflow to distinguish source-only review from hosted/dedicated/JIP/HC smoke evidence. |
| `autonomous-claude-research` | Claude | Open | Claude may claim the next bounded source-backed review lane and continue independently. |
| `feature-status-reconciliation` | Codex/future agent | Open | Fold any newly confirmed findings into owning atlas/risk pages and keep machine files aligned. |
| `implementation-hardening-from-backlog` | Future code owner | Open | Pick work packages from [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl), starting with P0/P1 authority fixes or the confirmed town-AI vehicle safety bug. |

## Recent Published Work

| Batch | Output | Details |
| --- | --- | --- |
| ICBM authority playbook routing | [ICBM authority](ICBM-Authority-Playbook), [Hardening roadmap](Hardening-Implementation-Roadmap), [Server authority map](Server-Authority-Migration-Map), [Feature status](Feature-Status-Register), [Wiki quality audit](Wiki-Quality-Audit) | Turns DR-27 into a source-backed implementation playbook covering Tactical-menu gating, `NukeIncoming`, `RequestSpecial`, `Server_HandleSpecial.sqf` and `NukeDammage`, while keeping summary pages short. |
| Wiki-quality MERGE-1 authority routing | [Hardening roadmap](Hardening-Implementation-Roadmap), [Server authority map](Server-Authority-Migration-Map), [Wiki quality audit](Wiki-Quality-Audit) | Reduces duplicated P0/P1 evidence and phase guidance by making the roadmap the canonical patch-order hub while the authority map owns principles, flow table, handler checklist and design-review routing. |
| Wiki-quality DUP-10 HC routing | [AI/headless](AI-Headless-And-Performance), [Lifecycle wait-chain](Lifecycle-Wait-Chain), [HC delegation/failover](Headless-Delegation-And-Failover-Playbook), [Wiki quality audit](Wiki-Quality-Audit) | Replaces duplicate HC failover discussion with clear page ownership: AI/headless keeps source-route orientation, Lifecycle keeps HC `sleep 20` boot timing, and the playbook owns update-back/work-record/disconnect/late-HC policy. |
| Wiki-quality C3 Gameplay follow-ups | [Gameplay atlas](Gameplay-Systems-Atlas), [Wiki quality audit](Wiki-Quality-Audit) | Replaces stale open questions with resolved source-backed notes for commander assignment DR-15, construction repair logic consumption, factory build drift ownership, supply-income stagnation liveness and range-global ownership. |
| Wiki-quality DUP-11 PV channel index | [Public variable channel index](Public-Variable-Channel-Index), [Networking/PV](Networking-And-Public-Variables), [SQF atlas](SQF-Code-Atlas), [Wiki quality audit](Wiki-Quality-Audit) | Makes the PV channel index the canonical direct-channel table, adds missing server-FPS/HQ/AntiStack rows from the old Networking table, and replaces duplicate atlas tables with cross-links. |
| Wiki-quality MERGE-3 lifecycle split | [Mission entrypoints](Mission-Entrypoints-And-Lifecycle), [Lifecycle wait-chain](Lifecycle-Wait-Chain), [Wiki quality audit](Wiki-Quality-Audit) | Removes duplicated boot timeline/report verification detail from Mission entrypoints, keeps it focused on include graph and per-role init responsibility, and makes Lifecycle wait-chain the canonical boot-order/JIP/flag-dependency page. |
| Wiki-quality MERGE-2 UI quick reference | [Client UI/HUD](Client-UI-HUD-And-Menus), [Client UI systems atlas](Client-UI-Systems-Atlas), [Wiki quality audit](Wiki-Quality-Audit) | Shrinks the HUD/menus page into a source-anchored router for common UI work and leaves detailed dialog/HUD/marker implementation notes in the canonical UI atlas. |
| Wiki-quality REDUCE-4 Gameplay gateway | [Gameplay atlas](Gameplay-Systems-Atlas), [Wiki quality audit](Wiki-Quality-Audit) | Trims duplicated economy, construction and factory explanation from the Gameplay atlas, adds gateway links to the owning atlases, and keeps the source anchors needed for safe orientation. |
| Wiki-quality C6 Gameplay citations | [Gameplay atlas](Gameplay-Systems-Atlas), [Wiki quality audit](Wiki-Quality-Audit) | Adds source anchors for town initialization, starting mode/patrol flags, capture/SV/perf loop, town AI activation/delegation/cleanup, economy resource ticks, commander assignment/votes, upgrade processing, CoIn construction, factory purchase/build paths and attack-wave production. |
| Wiki-quality C6 AI/headless citations | [AI/headless](AI-Headless-And-Performance), [Wiki quality audit](Wiki-Quality-Audit) | Adds source anchors for HC bootstrap/registry/delegation/disconnect, client-FPS delegation, town-AI cleanup, server-FPS publishing and `GetSleepFPS`; this pairs with the UI and Gameplay passes that now resolve C6. |
| Supply mission authority cleanup | [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook), [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl) | Codex-2 turns DR-18/DR-39 plus the PR #1 stacked-`Killed` handler review into a source-backed patch sequence: loaded/tracking state first, then cooldown casing and server cargo validation. |
| Economy authority first cut | [Economy authority first cut](Economy-Authority-First-Cut), [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl) | Codex-2 turns the broad economy authority class into a source-backed patch sequence: side-supply clamp first, then upgrade and construction/defense authority, with player-buy locality deferred as a larger redesign. |
| Wiki-quality C6 UI citations | [Client UI/HUD](Client-UI-HUD-And-Menus), [Wiki quality audit](Wiki-Quality-Audit) | Adds path:line anchors to the lightweight UI overview so it meets the project's source-backed citation standard without duplicating the full UI systems atlas. |
| Wiki-quality C4 victory searchability | [Feature status](Feature-Status-Register), [Hardening roadmap](Hardening-Implementation-Roadmap), [Wiki quality audit](Wiki-Quality-Audit) | Adds explicit DR-11 references to the victory/endgame bug while keeping DR-36 as the mechanism/perf-JIP review. |
| Wiki-quality C2 atlas cross-links | [Gameplay atlas](Gameplay-Systems-Atlas), [Client UI systems atlas](Client-UI-Systems-Atlas), [Client UI/HUD](Client-UI-HUD-And-Menus), [AI/headless](AI-Headless-And-Performance), [Construction atlas](Construction-And-CoIn-Systems-Atlas), [Mission lifecycle](Mission-Entrypoints-And-Lifecycle) | Adds concise links from developer-facing atlas pages to the canonical DR findings, and resolves the stale DR-15 commander open question. |
| PVF dispatch playbook surfaced | [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook), [Hardening roadmap](Hardening-Implementation-Roadmap), [PV channel index](Public-Variable-Channel-Index) | Codex-2's DR-1/DR-38 implementation guide is mirrored and linked into hardening nav. It keeps generic dispatcher hardening separate from registered-handler authority and direct publicVariable channels. |
| Wiki-quality navigation / C5 | [Home](Home), [`_Sidebar.md`](_Sidebar), [`_Footer.md`](_Footer), [Wiki quality audit](Wiki-Quality-Audit) | Wires Claude's canonical glossary/index/atlas/decision pages into navigation and resolves the duplicate Current Work sidebar entries called out by C5. |
| Wiki-quality C1 MASH networking fix | [Networking/PV](Networking-And-Public-Variables), [Wiki quality audit](Wiki-Quality-Audit) | Resolves the stale MASH row called out by Claude: DR-34 says the marker feature is dead on both ends, with an orphaned server PVEH, no live client broadcast and a commented receiver compile. |
| HC delegation/failover playbook | [HC delegation/failover](Headless-Delegation-And-Failover-Playbook), [AI/headless](AI-Headless-And-Performance), [`agent-context.json`](agent-context.json) | Adds the source-backed patch model for DR-21/DR-42: HC registry, town-AI update-back, static-defense one-way gap, work records, disconnect policy and validation scenarios. |
| DR-42/DR-43 reconciliation | [AI/headless](AI-Headless-And-Performance), [Feature status](Feature-Status-Register), [Hardening roadmap](Hardening-Implementation-Roadmap), [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl) | Promotes static-defense HC update-back to confirmed DR-42, marks hosted FPS backlog as a DR-19 duplicate, adds `source-version-sqf-build-gap` and `init-server-duplicate-binds`, and corrects DR-43 to three live duplicate binds plus three commented remnants. |
| Markdown research report intake | [External research reports](External-Research-Reports), [`external-research-report-manifest.json`](external-research-report-manifest.json), [`agent-context.json`](agent-context.json) | Adds sanitized metadata for nine Steff-provided Markdown deep-research reports; treats them as leads until repo evidence confirms them. First source-checked overlap confirms the modded mission tooling/propagation claims already documented in [Tools/build](Tools-And-Build-Workflow). |
| Attack-wave authority playbook | [Attack-wave authority playbook](Attack-Wave-Authority-Playbook), [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl), [`agent-context.json`](agent-context.json) | Adds the DR-41 patch shape future code owners need: treat `ATTACK_WAVE_INIT` as request data, re-derive real side supply server-side, reject bad/duplicate requests, clamp modifier/duration and preserve all-current-side-supply spend unless design changes are approved. |
| DR-41 attack-wave authority | [Networking/PV](Networking-And-Public-Variables), [Hardening roadmap](Hardening-Implementation-Roadmap), [Economy](Economy-Towns-And-Supply), [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl) | Claude's source-verified direct-PV finding is now promoted from scout candidate to confirmed high-priority backlog item. |
| Server authority map | [Server authority map](Server-Authority-Migration-Map) | Source-backed migration table and handler checklist for moving trusted-client flows toward server-owned authority. |
| Testing workflow | [Testing workflow](Testing-Debugging-And-Release-Workflow), [`agent-test-plan.schema.json`](agent-test-plan.schema.json) | Adds validation levels, system test matrix, static checks, RPT logging conventions, smoke packs, release gates and a machine-readable test evidence schema. |
| Lifecycle source verification | [Mission lifecycle](Mission-Entrypoints-And-Lifecycle), [Lifecycle wait-chain](Lifecycle-Wait-Chain) | Verified Anscombe's report, corrected the `Migrations` typo to `Missions`, and promoted mission-object town init plus HC `sleep 20` timing boundary. |
| Town-AI safety playbook | [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety) | Source chain, exact failure condition, SQF-safe guard shape and smoke-test gates for `server_town_ai.sqf:211-216`. |
| Wave F hardening backlog | [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl) | Machine-readable work packages for PVF, ICBM, attack waves, victory, economy, supply, factory queues, markers, hosting, town AI, JIP waits, tooling and UI debt. |
| External report manifest | [`external-research-report-manifest.json`](external-research-report-manifest.json) | Sanitized metadata for the three Steff-provided PDF reports and nine Markdown reports; raw report bodies are local only. |
| Confirmed town-AI vehicle bug | [Feature status](Feature-Status-Register), [AI/headless](AI-Headless-And-Performance) | `server_town_ai.sqf:211-216` can delete an occupied town-AI vehicle if the player is not group leader. |
| Lifecycle wait audit | [Lifecycle wait-chain](Lifecycle-Wait-Chain) | Split retrying join handshakes from no-timeout replicated-variable waits. |
| Hardening roadmap | [Hardening roadmap](Hardening-Implementation-Roadmap) | Human-readable patch order and validation gates for code owners. |

Historic scout rosters and harvested reports live in [Discovery swarm](Subagent-Discovery-Swarm) and [Agent worklog](Agent-Worklog).

## Update Ritual

| Moment | Codex / Claude action | Human-visible result |
| --- | --- | --- |
| Starting work | Update `agent-collaboration.json` and append a `claim` event. | This dashboard and the coordination board show who owns what. |
| Still working after a long pass | Append a `heartbeat` event. | You can see that an agent is alive and where it is reading. |
| Finding a source-backed issue | Append a `finding` event and add a short worklog note. | The finding is visible even before the full page is integrated. |
| Finishing a lane | Append a `complete` event, update affected pages and note validation status. | The lane moves from active to ready/integrated. |
| Handing off | Append a `handoff` event with the exact next action. | The other agent can pick it up without chat memory. |

## Status Legend

| Status | Meaning |
| --- | --- |
| `active` | Someone is working this lane now. |
| `open` | Available for an agent to claim. |
| `ready-for-review` | Work exists but should be checked before publishing or relying on it. |
| `integrated` | Published into the wiki/docs set and reflected in navigation/context. |
| `blocked` | Needs user input, missing access or an external state change. |

## For Agents

1. Load [`agent-status.json`](agent-status.json), [`agent-collaboration.json`](agent-collaboration.json), [`agent-knowledge.jsonl`](agent-knowledge.jsonl), [`agent-events.jsonl`](agent-events.jsonl) and [Agent collaboration protocol](Agent-Collaboration-Protocol) before claiming work.
2. Treat `agent-events.jsonl` as append-only.
3. Keep claims bounded by source scope.
4. Never overwrite another agent's page or navigation changes from a stale branch.
5. Publish human notes to [Agent worklog](Agent-Worklog) and machine notes to the JSON files.

## Continue Reading

Previous: [Agent context](Agent-Context) | Next: [Coordination board](Coordination-Board)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
