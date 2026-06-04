# Progress Dashboard

This is the shared human + AI interface for seeing what Codex, Claude and Codex sub-agents are doing right now.

Keep this page open when parallel documentation work is running. It links to the live board, event feed and compact JSON status files without forcing readers through the whole sidebar.

## What this page is

- Shared source-of-truth for lane state, active owners and recently validated work.
- Human + AI handoff surface for current ownership and next action.
- Quick index for where to read next when a lane claims changes.

## Where this dashboard lives

- Wiki page: `docs/wiki/Progress-Dashboard.md`
- Runtime state files: `agent-status.json`, `agent-events.jsonl`, `agent-knowledge.jsonl`
- Coordination board: `Coordination-Board.md`
- Source of truth pointers: [`agent-context.json`](agent-context.json)

## How to use this page

1. Start with **At A Glance** to find active lanes and owners.
2. Read **Latest Batch** for the newest validated status update only.
3. Use **Current Lanes** to separate active docs work, watchlists and future code-owner work.
4. Use [Agent worklog](Agent-Worklog), [Discovery swarm](Subagent-Discovery-Swarm) and [`agent-events.jsonl`](agent-events.jsonl) for historic scout detail.

## Latest Batch

| Lane | Status | Output |
| --- | --- | --- |
| `mini-scout-wave-community-config-ai-ui-tooling` | Published / validated / pushed | Steff asked for more Spark scouts. Three `gpt-5.3-codex-spark` starts hit quota/overflow before evidence, so Codex closed those slots and launched six read-only `gpt-5.4-mini` scouts. One feature-status scout overflowed without evidence; five returned. Community/dev provenance confirmed the existing [Community & Dev](Community-And-Dev) hub and contributor/upstream-remotes evidence. Config/data-model scouting added positional-array and post-load mutation guidance to [Assets/config/localization/parameters](Assets-Config-Localization-And-Parameters-Atlas). UI scouting sharpened [Player UI workflow](Player-UI-Workflow-Map) for buy-gear views/tabs, command-menu map-click flow, help-menu text ownership and respawn discovery. AI/runtime scouting added the spawned-unit follow-up, player-AI watchdog/recovery and AI leader respawn branch split to [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map). Tooling scouting tightened [PerformanceAuditAnalyzer](PerformanceAuditAnalyzer) output wording. Validation passed; content commits are docs `b5a40dd4` / wiki `5699c82`, and final pushed heads after the breadcrumb are docs `82efba3a` / wiki `3a87f2f`. No gameplay source changed. |
| `fallback-mini-scout-wave-feature-lifecycle-economy-pv-ui-tooling` | Harvested / validated / pushed | Steff asked for more Spark scouts, but six `gpt-5.3-codex-spark` starts hit quota until 23:53 before returning evidence. Codex closed those slots and launched six read-only `gpt-5.4-mini` fallback scouts. Bohr mostly confirmed already-canonical Feature Status/dead-chain rows, including RU para-ammo, AntiStack, WASP wheel repair, unitCaching and resistance patrol. Laplace confirmed UI findings are already mostly routed, but `_Sidebar` lacked a click-through UI cluster, so Codex added one. Descartes found a real stale PV inventory sentence in [SQF code atlas](SQF-Code-Atlas) and [Wiki source consistency](Wiki-Source-Consistency-Findings); Codex corrected those. Descartes' `version.sqf` correction was rejected by source check because `initJIPCompatible.sqf` does include `version.sqf` and separately runs `Common/Init/Init_Version.sqf`. Huygens' economy scout produced a compact [Gameplay systems](Gameplay-Systems-Atlas#economy-and-resource-loop) constants table, Hubble sharpened [Networking/PV](Networking-And-Public-Variables#network-helper-layer) transport-vs-authority wording, and Kuhn's tooling scout led to a dedicated [PerformanceAuditAnalyzer](PerformanceAuditAnalyzer) page plus tool/testing links. Validation passed; content commits are docs `b878f7e4` / wiki `bad8646`, and final pushed heads after the breadcrumb are docs `b7f03baf` / wiki `14a3a2d`. No gameplay source changed. |
| `static-reference-triage-lesson` | Published / validated / pushed | Codex source-checked the missing-reference scout's remaining lead and clarified that the [Source inventory](Source-Inventory#static-reference-check) static-reference table mixes live paths with commented/dead archaeology. `description.ext:37` unitCaching, `Init_Towns.sqf:168,174` `respatrol.fsm`, and `WASP/Init_Client.sqf:12` `KeyDown.sqf` are commented/absent references, while `car_wheel_new.sqf` is inactive because its action caller and `WASP_procInitComm` bootstrap are commented. Added [Development lessons](Development-Lessons-Learned#lesson-15-static-reference-hits-are-leads-not-runtime-proof) and `agent-development-lessons.jsonl` so future sweeps do executable-line checks before promoting missing references to release gates. Validation passed and content pushed as docs `a391a0f1` / wiki `9e08393`. No gameplay source changed. |
| `spark-scout-wave-version-lifecycle-tooling-feature-pv-caps` | Published / validated / pushed; scouts closed | Steff asked for another bunch of Spark scouts. Codex launched six `gpt-5.3-codex-spark` read-only scouts for generated `version.sqf` release gating, mission lifecycle/init graph, tooling/integrations, Feature Status depth, PV/PVF authority and player-role/AI-cap formulas; the UI scout failed from output overflow and the player AI-cap scout failed from long-thread compaction. Harvested reports: Peirce confirmed the ignored/generated `version.sqf` release hazard, so Codex added `versionSqfGeneratedInput` to `agent-release-readiness.json` and promoted hard root-gate wording into Tools/build, Source fix propagation, Mission config/version and Source inventory. Averroes confirmed lifecycle docs are mostly strong; Codex added architecture/entrypoint/SQF-atlas callouts for HC timing, JIP stall risk, mixed Common ownership and init hygiene while keeping the source-verified town object count at 40 after recheck. Nash confirmed the PV/PVF index has no undisclosed major channels and that AFK, supply polling, MASH marker, server-FPS compatibility and player-object-list edges are already routed in canonical networking/feature/backlog pages. Bacon's Feature Status pass added missing-file clarity for old map blinking and legacy AT/bomb hooks, plus a supply-mission dead-twin compile caution. Hilbert's tooling report was harvested into machine-readable `toolingAuditGates` for LoadoutManager packaging/copy risk, PerformanceAuditAnalyzer headless/large-log limits, DiscordBot/Extension schema/config risk and BattlEye bundle incompleteness. Fresh commander/economy mostly confirmed canonical docs; its claim that commander reassignment was patched was rejected by local source recheck (`Server_AssignNewCommander.sqf` still sets `_side = _this`). Fresh server-ops/integrations and missing-reference scouts confirmed already-canonical ops/dead-feature coverage; the missing-reference scout's useful `supplyMissionActive` dead-twin caution was already promoted. Fresh construction/factories, UI and respawn/MASH overflowed before evidence and were closed. No gameplay source changed. |
| `dashboard-open-item-cleanup` | Published / validated | Codex compacted this dashboard back into a live status surface, moved old batch detail behind worklog/swarm links, closed the Coverage Ledger sidebar request, and reclassified stale open/ready rows as published, watchlist or future code-owner work. No gameplay source changed. |
| `spark-scout-wave-release-targets-hc-ai-caps-economy` | Published / validated / pushed | Steff asked for more Spark scouts. Codex launched six GPT-5.3-Codex-Spark read-only scouts for player AI caps, support authority, UI/dialog hazards, generated/modded release tiers, town/economy/supply edge cases and HC/locality/FPS, then refilled one freed slot with tooling/integrations and one with mission lifecycle/init. Returned reports were duplicate-aware: Player AI caps confirmed the existing Discord-ready table, HC scout confirmed existing failover/dual-FPS/static-defense gaps, town/economy scout confirmed already-canonical camp flag, patrol latch, side-supply, income-cap and supply-authority rows, and generated/modded scout sharpened release target counts. The content delta is focused in `agent-release-readiness.json` and [Tooling release readiness audit](Tooling-Release-Readiness-Audit): release targets are now split into source Chernarus, maintained Takistan, branch-only Zargabad candidate and per-folder modded blocked/stub tiers with file counts, conflict-marker counts and bootstrap blockers. UI scout also added the missing `Client\Images\wf_*.paa` old-upgrade-dialog asset references to the UI atlas/checklist. Validation passed and content pushed as docs `058427d3` / wiki `4b72809`. No gameplay source changed. |
| `ai-commander-branch-head-refresh-and-spark-scout-wave` | Published / validated | Current branch evidence is recorded: `origin/feat/ai-commander` is `c20ce153`, source-Chernarus-only with 9 files, +416/-5 and no maintained Vanilla changes. The post-`4dba060e` cleanup series only rewrites five `Server/AI/Commander/AI_Commander*.sqf` scripts. `origin/codex/quad-ai-commander` is `d4e0fa38` concept/report evidence only. Returned scout notes remain follow-up leads until source-checked into canonical pages. |
| `fresh-background-spark-scout-wave-buy-menu-harvest` | Published / validated / pushed | Ten fresh background Spark threads were launched after normal subagent startup failed. Five completed reports mostly confirmed existing canonical docs, four were interrupted and one UI thread errored. The only promoted delta was the buy-menu driver-default `profileNamespace` key split, routed through [Factory/purchase](Factory-And-Purchase-Systems-Atlas), [Development lessons](Development-Lessons-Learned), `agent-development-lessons.jsonl` and `agent-feature-status.jsonl`. |

Historic batch rows were intentionally removed from this page. Use [Agent worklog](Agent-Worklog), [Discovery swarm](Subagent-Discovery-Swarm) and [`agent-events.jsonl`](agent-events.jsonl) for the long audit trail.

## At A Glance

| Actor | Status | Current lane | What to expect next |
| --- | --- | --- | --- |
| Codex | Active | `documentation-finisher-loop` | Mini scout wave for community/config/AI/UI/tooling is published; continue bounded source-backed wiki maintenance and keep final-head breadcrumbs current. |
| Codex-2 | Ready | None | Pick a bounded source-backed lane from PVF dispatcher lookup, side-supply clamp first, commander reassignment call-shape repair or remaining supply authority hardening. |
| Claude | Autonomous-ready | `collaboration-follow-autonomous-ready` | Coverage Ledger navigation is wired. Claude can self-select the next bounded source-backed review from the ledger or hardening backlog. |
| Sub-agents | Closed | `mini-scout-wave-community-config-ai-ui-tooling` | Five mini scouts returned and one feature-status scout overflowed without evidence; source-checked deltas were promoted and pushed. |
| Shared docs | Live | GitHub wiki + docs mirror | Wiki and mirror should stay in parity after scoped validation; use event logs and git history for commit IDs. |

## One-Link Check

| Need | Link |
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

| Lane | Owner | Status | Next action |
| --- | --- | --- | --- |
| `documentation-finisher-loop` | Codex | Active / ongoing | Keep the wiki current from source evidence, update machine files on visible status changes, and keep this dashboard compact. |
| `autonomous-claude-research` | Claude | Autonomous-ready | Self-select the next bounded source-backed review from [Codebase coverage ledger](Codebase-Coverage-Ledger) when Claude is active. |
| `feature-status-reconciliation` | Codex / future agent | Watchlist | Fold newly confirmed findings into [Feature status](Feature-Status-Register), owner pages and machine records. No untriaged finding is blocking this dashboard. |
| `implementation-hardening-from-backlog` | Future code owner | Owner decision / code lane | Pick implementation work from [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl) only when Steff asks for gameplay patches or a code owner claims the work. |
| `testing-debugging-release-workflow` | Codex / future tester | Published release gate | Use [Testing workflow](Testing-Debugging-And-Release-Workflow) to distinguish source review, propagated source fixes and actual Arma smoke evidence. |
| `source-propagated-smoke-pending` | Future tester / release owner | Smoke pending | [Client skill init](Client-Skill-Init-Idempotency), [hosted FPS](Hosted-Server-FPS-Loop-Sleep), [supply scan](Supply-Mission-Scan-Narrowing) and [paratrooper markers](Paratrooper-Marker-Revival) are tracked in owner pages and Feature Status; they are not dashboard cleanup blockers. |
| `wasp-marker-wait-cleanup` | Future code owner | Source needs code | [WASP marker wait cleanup](WASP-Marker-Wait-Cleanup) remains a tiny patch-ready opportunity, not an active docs lane. |

## Recently Closed / Reclassified Open Items

- Coverage Ledger navigation request: [Home](Home), [`_Footer.md`](_Footer), [`llms.txt`](llms.txt) and [`agent-context.json`](agent-context.json) already linked it; [`_Sidebar.md`](_Sidebar) now links it too, and the Coordination Board mailbox is marked done.
- OA object-lifecycle command addendum: the old Codex-2 active claim is closed into [Arma 2 OA command version reference](Arma-2-OA-Command-Version-Reference#object-lifecycle-commands--oa-safe-locality-sensitive), covering `createVehicle`, `createUnit`, `deleteVehicle`, `hideObject` / `enableSimulation` and the A3-only `*Global` variants.
- Old `ready-for-review` rows for PVF dispatch, victory/endgame and factory/purchase are no longer dashboard blockers. Their findings are published and integrated; next work is code-owner implementation or validation.
- Historic scout waves are closed, harvested or non-evidence until relaunched. Their detail belongs in [Discovery swarm](Subagent-Discovery-Swarm), [Agent worklog](Agent-Worklog) and [`agent-events.jsonl`](agent-events.jsonl), not in this live dashboard.
- Standing future work remains visible as watchlist/code-owner lanes instead of generic open dashboard spam.

## Recent Published Work

| Batch | Output | Details |
| --- | --- | --- |
| AI commander branch-head refresh | [AI commander audit](AI-Commander-Autonomy-Audit), [Current source snapshot](Current-Source-Status-Snapshot), [Quad AI Commander](Quad-AI-Commander) | Refreshed branch heads and kept branch/design evidence separate from shipped source. |
| HC upstream history | [HC upstream history and lessons](HC-Upstream-History-And-Lessons) | Captured older headless-client branch/comment-message lessons for future HC work. |
| PR8 and drone lesson match | [PR8 and Drone upstream lesson match](PR8-And-Drone-Upstream-Lesson-Match) | Mapped upstream lessons to PR #8 and drone-branch review gates. |
| Quad AI/support/lifecycle/UI/tooling scout harvest | [Quad AI Commander](Quad-AI-Commander), [Support specials](Support-Specials-And-Tactical-Modules-Atlas), [Tools/build](Tools-And-Build-Workflow) | Promoted source-backed non-duplicate deltas and left concept-only evidence clearly labeled. |
| Config/factory/UI/AI/cleanup/upstream scout harvest | [Mission config graph](Mission-Config-Version-Include-Graph), [Factory/purchase](Factory-And-Purchase-Systems-Atlas), [Client UI systems](Client-UI-Systems-Atlas) | Added version/runtime contract, latent `AIBuyUnit` wording, UI cleanup debt and loop-topology notes. |
| Town/respawn/upstream/performance scout harvest | [Gameplay systems](Gameplay-Systems-Atlas), [Respawn/death](Respawn-And-Death-Lifecycle-Atlas), [Performance sweep](Performance-Opportunity-Sweep) | Added respawn penalty, resource cap, capture reward and loop-topology refinements. |
| Commander vote/reassignment playbook | [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook) | Routed commander UI/PV/authority pages through one patch-ready playbook. |
| Economy supply commander audit | [Economy authority first cut](Economy-Authority-First-Cut), [Supply authority cleanup](Supply-Mission-Authority-Cleanup-Playbook) | Completed source-backed economy/commander/supply boundary map and handed implementation choices to code owners. |

## Update Ritual

| Moment | Codex / Claude action | Human-visible result |
| --- | --- | --- |
| Starting work | Update `agent-collaboration.json` and append a `claim` event. | This dashboard and the coordination board show who owns what. |
| Still working after a long pass | Append a `heartbeat` event. | You can see that an agent is alive and where it is reading. |
| Finding a source-backed issue | Append a `finding` event and add a short worklog note. | The finding is visible before the full page is integrated. |
| Finishing a lane | Append a `complete` event, update affected pages and note validation status. | The lane moves from active to ready/integrated. |
| Handing off | Append a `handoff` event with the exact next action. | The next agent can pick it up without chat memory. |

## Status Legend

| Status | Meaning |
| --- | --- |
| `active` | Someone is working this lane now. |
| `watchlist` | Keep synchronized when new evidence appears; no standalone action is currently blocked. |
| `owner decision / code lane` | Documentation is ready; a gameplay/release owner must choose or implement. |
| `published / validated` | Published into the wiki/docs set and reflected in navigation/context. |
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
