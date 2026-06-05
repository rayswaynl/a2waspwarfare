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
| `wiki-backlog-asset-bootstrap-pass` | Published / validated | Added repeatable asset/media/bootstrap scanner evidence to [Dead/stale code register](Dead-Code-And-Stale-Code-Register) and [Assets/config/localization/parameters](Assets-Config-Localization-And-Parameters-Atlas): 9 mission roots, 2774 text files, 5860 path records, 21 missing bootstrap files all under `Modded_Missions`, and guardrails for OA addon paths plus map-conditional texture false positives. Added fresh pruning backlog leads to [Wiki pruning and relevance ledger](Wiki-Pruning-And-Relevance-Ledger). No gameplay source changed. |
| `july-update-planning` | Queued / dev branch created | Steff added **Hosted Server FPS Loop Fix** to the July update to-do list. Dev branch: `dev/july-update-hosted-server-fps-loop-fix`. Scope is the DR-19 hosted/listen busy-spin fix plus dedicated FPS publish smoke; no gameplay source changed by this dashboard note. |
| `dead-code-oa-compatibility-pass` | Published / validated | Added repo-wide OA compatibility evidence to [Dead/stale code register](Dead-Code-And-Stale-Code-Register) and [Arma 2 OA compatibility audit](Arma-2-OA-Compatibility-Audit): 3199 text files scanned, 22 risky patterns checked, 0 live code-risk implementation hits for A3-style APIs, and 1132 OA-safe inverse-trap hits (`diag_tickTime`, `uiSleep`, `setVehicleInit`, `processInitCommands`) documented as not-dead guardrails. No gameplay source changed. |
| `dead-code-mission-copy-divergence-pass` | Published / validated | Added mission-copy divergence evidence to [Dead/stale code register](Dead-Code-And-Stale-Code-Register): 9 mission roots, 690 unique mission-relative paths, 548 identical copied paths, 139 diverged copied paths, 18 conflict-marker files. Source/Vanilla divergence is mostly intentional map/generated data; `Modded_Missions` is quarantined as stale fork territory until regenerated or explicitly maintained. No gameplay source changed. |
| `dead-code-sqf-reachability-pass` | Published / validated | Added quoted-SQF-path reachability evidence to [Dead/stale code register](Dead-Code-And-Stale-Code-Register): 2705 SQF files catalogued, 4358 quoted SQF path references, 453 raw unreferenced leads, and source-checked findings for AI supply truck, groupsMonitor, air-vehicle modifier hook, AT reload hook, IRS warning helpers, Reaktiv and TaskSystem. Added false-positive guardrails for dynamic Skill, construction, AI respawn and MHQ lock paths. No gameplay source changed. |
| `dead-code-parameter-config-pass` | Published / validated / pushed | Added mission parameter/config scan evidence to [Dead/stale code register](Dead-Code-And-Stale-Code-Register): visible `WFBE_C_AI_MAX` has no current runtime consumer; visible `WFBE_C_UNITS_CLEAN_TIMEOUT` is bypassed by active body/empty-vehicle cleanup paths and only survives in a commented old split line; dynamic economy start parameters are marked as exact-name scan false positives. No gameplay source changed. |
| `dead-code-ui-rsc-pass` | Published / validated / pushed | Added UI/Rsc scan evidence to [Dead/stale code register](Dead-Code-And-Stale-Code-Register): missing `RscMenu_Upgrade` handler target, active economy IDC drift `23004/23005/23006`, duplicate reachable IDDs `23000` and `10200`, comment-only retired parameters IDC `22005`, plus false-positive guardrails for engine/BIS/display IDCs. No gameplay source changed. |
| `dead-code-pv-channel-pass` | Published / validated / pushed | Added direct public-variable scan evidence to [Dead/stale code register](Dead-Code-And-Stale-Code-Register) and [Public variable channel index](Public-Variable-Channel-Index): comment-only legacy `WFBE_*` direct PV names, `SERVER_FPS_GUI` / `WFBE_VAR_SERVER_FPS` compatibility drift, receiver-only `ICBM_launched` handler, plus false-positive guardrails for dynamic supply temp channels and state broadcasts. No gameplay source changed. |
| `dead-code-integrations-and-tooling-pass` | Published / validated / pushed | Deepened [Dead/stale code register](Dead-Code-And-Stale-Code-Register) with DiscordBot, Extension, BattlEye and LoadoutManager findings: dormant config/helper paths, unsafe dormant JSON helpers, commented extension deserialization scaffold, game-status arg-shape drift, DiscordBot/LoadoutManager terrain metadata drift, AFK-only BattlEye footprint and warning-marked CRV7PG loadout data. Validation passed. No gameplay source changed. |
| `dead-code-register` | Published / validated / pushed | Added [Dead/stale code register](Dead-Code-And-Stale-Code-Register) plus `docs/analysis/dead-code-findings.jsonl` and the repeatable reference scan. Current pass classifies stale comments, broken UI residue, MASH marker relay, latent `AIBuyUnit`, modded conflict markers, generated `version.sqf` and modded packaging scope. Validation passed. No gameplay source changed. |
| `pruning-ledger-completion-audit` | Published / validated / pushed | Codex audited [Wiki pruning and relevance ledger](Wiki-Pruning-And-Relevance-Ledger) against the current wiki state. P0/P1/P2 pruning rows are now recorded as completed, archive pages carry historical/current-truth caveats, and future gameplay hardening/release smoke/code-owner tasks are separated from the pruning goal. Validation passed. No gameplay source changed. |
| `ui-runtime-quickref-pruning` | Published / validated / pushed | Most recent published pruning batch: UI/runtime gateways route to canonical owner pages and no longer repeat detailed proof. |

Older published batches are intentionally omitted from this table. Use [Agent worklog](Agent-Worklog), [Discovery swarm](Subagent-Discovery-Swarm), [`agent-status.json`](agent-status.json), [`agent-events.jsonl`](agent-events.jsonl) and git history for the long audit trail.

## At A Glance

| Actor | Status | Current lane | What to expect next |
| --- | --- | --- | --- |
| Codex | Active | `documentation-finisher-loop` | Asset/bootstrap scanner and fresh pruning backlog leads are validated; continue from fresh source evidence or code-owner requests. |
| Codex-2 | Ready | None | Pick a bounded source-backed lane from PVF dispatcher lookup, side-supply clamp first, commander reassignment call-shape repair or remaining supply authority hardening. |
| Claude | Autonomous-ready | `collaboration-follow-autonomous-ready` | Coverage Ledger navigation is wired. Claude can self-select the next bounded source-backed review from the ledger or hardening backlog. |
| Supported docs agents | Active | `research-catchup-synthesis-default-supported`, `relevance-pruning-and-archive-default-supported` | Two account-default supported high-reasoning helper chats are running catch-up synthesis and relevance pruning. The earlier named-model starts are treated as failed/non-evidence. |
| Read-only pruning scouts | Returned / harvested | `ui-runtime-bloat-scout`, `wiki-navigation-chain-scout` | UI/runtime lead is promoted; small navigation fixes are promoted; remaining archive-page caveat note is already satisfied by archive page headers. |
| Sub-agents | Returned / closed | `navigation-parity-and-scout-wave-2026-06-04` | Supports, UI, tooling and AI scouts returned; most findings confirmed existing owner pages. Economy scout was closed without output and is not evidence. |
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
| Agent release readiness ledger | [Agent release readiness ledger](Agent-Release-Readiness-Ledger) |
| Latest event stream | [`agent-events.jsonl`](agent-events.jsonl) |
| Dated narrative notes | [Agent worklog](Agent-Worklog) |
| External report intake | [External research reports](External-Research-Reports) |
| External report manifest | [`external-research-report-manifest.json`](external-research-report-manifest.json) |
| Pruning and relevance decisions | [Wiki pruning and relevance ledger](Wiki-Pruning-And-Relevance-Ledger) |

## Current Lanes

| Lane | Owner | Status | Next action |
| --- | --- | --- | --- |
| `wiki-backlog-asset-bootstrap-pass` | Codex | Published / validated | Commit/push docs-only changes, then continue future backlog work from fresh source evidence. |
| `dead-code-oa-compatibility-pass` | Codex | Published / validated | Push wiki/docs-only changes, then continue the broader dead-code goal from fresh source evidence. |
| `dead-code-mission-copy-divergence-pass` | Codex | Published / validated | Continue the broader dead-code goal from fresh source evidence. |
| `dead-code-sqf-reachability-pass` | Codex | Published / validated | Continue the broader dead-code goal from fresh source evidence. |
| `dead-code-parameter-config-pass` | Codex | Published / validated / pushed | Continue deeper source passes for additional dead-code families if the goal remains active. |
| `dead-code-ui-rsc-pass` | Codex | Published / validated / pushed | Continue deeper source passes for additional dead-code families if the goal remains active. |
| `dead-code-pv-channel-pass` | Codex | Published / validated / pushed | Continue deeper source passes for additional dead-code families if the goal remains active. |
| `dead-code-integrations-and-tooling-pass` | Codex | Published / validated / pushed | Continue deeper source passes for additional dead-code families if the goal remains active. |
| `dead-code-register` | Codex | Published / validated / pushed | Continue deeper source passes for additional dead-code families if the goal remains active. |
| `pruning-ledger-completion-audit` | Codex | Published / validated / pushed | Ledger records all pruning-backlog rows as completed and dashboard is compacted to current-state use. |
| `documentation-finisher-loop` | Codex | Active / ongoing | Keep the wiki current from source evidence after this pruning goal closes. |
| `ui-runtime-quickref-pruning` | Codex | Published / validated / pushed | UI/runtime gateways route to canonical owners and no longer repeat detailed proof. |
| `feature-status-residue-pruning` | Codex | Published / validated / pushed | Feature Status now routes harvested scout history to owner pages, fixes stale PR #1 handler wording and keeps AI supply logistics branch/config scope visible. |
| `core-gameplay-gateway-pruning` | Codex | Published / validated / pushed | Core index is a route map and Gameplay systems routes duplicated economy/commander/upgrade/construction/factory detail to owner pages. |
| `miksuu-archive-sidebar-pruning` | Codex | Published / validated / pushed | Preserve imported Miksuu archive pages but route sidebar users through the archive index, community context and source-check pages. |
| `scout-pruning-leads` | Codex sub-agents | Harvested / closed | Fermat, Herschel, Confucius and Carson leads have been promoted, rejected or marked already satisfied in the ledger/worklog. |
| `autonomous-claude-research` | Claude | Autonomous-ready | Self-select the next bounded source-backed review from [Codebase coverage ledger](Codebase-Coverage-Ledger) when Claude is active. |
| `feature-status-reconciliation` | Codex / future agent | Watchlist | Fold newly confirmed findings into [Feature status](Feature-Status-Register), owner pages and machine records. No untriaged finding is blocking this dashboard. |
| `implementation-hardening-from-backlog` | Future code owner | Owner decision / code lane | Pick implementation work from [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl) only when Steff asks for gameplay patches or a code owner claims the work. |
| `testing-debugging-release-workflow` | Codex / future tester | Published release gate | Use [Testing workflow](Testing-Debugging-And-Release-Workflow) to distinguish source review, propagated source fixes and actual Arma smoke evidence. |
| `source-propagated-smoke-pending` | Future tester / release owner | Smoke pending | [Client skill init](Client-Skill-Init-Idempotency), [hosted FPS](Hosted-Server-FPS-Loop-Sleep), [supply scan](Supply-Mission-Scan-Narrowing) and [paratrooper markers](Paratrooper-Marker-Revival) are tracked in owner pages and Feature Status; they are not dashboard cleanup blockers. |
| `wasp-marker-wait-cleanup` | Future code owner | Source needs code | [WASP marker wait cleanup](WASP-Marker-Wait-Cleanup) remains a tiny patch-ready opportunity, not an active docs lane. |

## July Update To-Do

| # | Item | Dev branch | Scope | LOC estimate | Status | Validation gate |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Hosted Server FPS Loop Fix | `dev/july-update-hosted-server-fps-loop-fix` | Adopt/verify the DR-19 hosted/listen busy-spin fix for the July update target. Keep the low-risk early `!isDedicated` exit shape for FPS publisher loops; decide separately whether to consolidate the two FPS variables. | ~5-20 LOC for the loop guard; ~20-50 LOC if cleanup/consolidation is included. | Queued for July update. Remote dev branch created from `origin/master`. | Dedicated server still publishes `SERVER_FPS_GUI` / `WFBE_VAR_SERVER_FPS`; hosted/listen runs do not spin the FPS publisher loops; Chernarus and maintained Vanilla parity are named before release wording. |

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

Previous: [Agent context](Agent-Context) | Next: [Bottleneck removal queue](Bottleneck-Removal-Queue)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
