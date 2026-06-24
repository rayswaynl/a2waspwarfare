# Progress Dashboard

This is the shared human + AI interface for seeing what Codex, Claude and Codex sub-agents are doing right now.

Keep this page open when parallel documentation work is running. It links to the live board, event feed and compact JSON status files without forcing readers through the whole sidebar.

## What this page is

- Shared source-of-truth for lane state, active owners and recently validated work.
- Human + AI handoff surface for current ownership and next action.
- Quick index for where to read next when a lane claims changes.

## Where this dashboard lives

- Wiki page: `Progress-Dashboard.md` in the GitHub wiki; repo mirror path is `docs/wiki/Progress-Dashboard.md` only on branches/checkouts that carry the mirror.
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
| `b745-b747-current-head-refresh-2026-06-24` | Published / validated | Refreshed B74.5/B74.7.1 current-head docs after fetch-before-commit showed `origin/claude/b745` advanced again to `29ca9519`. [Feature status](Feature-Status-Register), [Current source status](Current-Source-Status-Snapshot#2026-06-24-b745-branch-intake), [AI commander autonomy](AI-Commander-Autonomy-Audit#b745--b7471-aicom-follow-up), [Player join/disconnect](Player-Join-Disconnect-And-AntiStack-Lifecycle#branch-intel---b745b747-jip-enrollment), [Client UI systems](Client-UI-Systems-Atlas#current-branch-scope), [Performance opportunity sweep](Performance-Opportunity-Sweep), [Testing workflow](Testing-Debugging-And-Release-Workflow#branch-only-feature-smoke-pack) and [Pruning ledger](Wiki-Pruning-And-Relevance-Ledger) now route B74.7/B74.7.1 as two clean source-Chernarus-only current-head commits over B74.6: 5 files / +41 / -11, no `Missions_Vanilla`, `Modded_Missions` or `Tools` payload. The branch remains broad over stable, 133 files / +4130 / -4398 over `origin/master@f8a76de34`, and B74.7/B74.7.1 need EAST/JIP enrollment, FPS picker and AICOM eight-team cap smoke before merge/release wording. No gameplay source changed. |
| `pr80-vote-para-guards-intake-2026-06-24` | Published / validated | Routed open draft PR #80 / `origin/claude/trello-vote-para-guards@92101abe` as branch-only maintained-root commander/support evidence. [PR cleanup](PR-Cleanup-And-Integration-Lab#2026-06-24-pr-80-voteparatrooper-guard-intake), [Feature status](Feature-Status-Register), [Current source status](Current-Source-Status-Snapshot#2026-06-24-pr80-vote-para-guards-intake), [Commander vote](Commander-Vote-And-Reassignment-Playbook#current-branch-scope), [Support specials](Support-Specials-And-Tactical-Modules-Atlas#pr-80-voteparatrooper-guard-branch-intel), [Testing workflow](Testing-Debugging-And-Release-Workflow#branch-only-feature-smoke-pack) and [Pruning ledger](Wiki-Pruning-And-Relevance-Ledger) now record PR #80 as one clean commit on current stable `origin/master@f8a76de34`, 10 maintained-root files / +148 / -14, no `Modded_Missions` or `Tools` payload. Commander random tied-player selection and paratrooper AI-cap guard remain branch-only until maintained-root smoke proves outcome, opt-out and server-backstop behavior. No gameplay source changed. |
| `pr83-wiki-wins-batch-intake-2026-06-24` | Published / validated | Refreshed the PR board and classified open draft PR #83 / `origin/claude/wiki-wins-batch@a61823265` as a branch-only Chernarus-source bundle. [PR cleanup](PR-Cleanup-And-Integration-Lab#2026-06-24-pr-83-wiki-wins-batch-intake), [Feature status](Feature-Status-Register), [Current source status](Current-Source-Status-Snapshot#2026-06-24-pr83-wiki-wins-batch-intake), [Testing workflow](Testing-Debugging-And-Release-Workflow#branch-only-feature-smoke-pack) and [Pruning ledger](Wiki-Pruning-And-Relevance-Ledger) now record the current open PR set: #83, #80, #74, #72, #66, #63, #59, #54, #53 and #9; previous open #43/#40 are closed. PR #83 is clean on base `origin/master@f8a76de34`, 46 source-Chernarus files / +124 / -86, no `Missions_Vanilla`, `Modded_Missions` or `Tools` payload, and still needs owner-sized smoke plus LoadoutManager/Vanilla scope decisions before merge/release wording. No gameplay source changed. |
| `b745-b746-current-head-refresh-2026-06-24` | Published / validated | Refreshed B74.5/B74.6 branch-intake and owner-route docs after `origin/claude/b745` advanced to current head `712a7a668`. [Feature status](Feature-Status-Register), [Current source status](Current-Source-Status-Snapshot#2026-06-24-b745-branch-intake), [Client UI systems](Client-UI-Systems-Atlas#current-branch-scope), [Respawn/death lifecycle](Respawn-And-Death-Lifecycle-Atlas#death-handler-responsibilities), [Performance opportunity sweep](Performance-Opportunity-Sweep) and [Testing workflow](Testing-Debugging-And-Release-Workflow#branch-only-feature-smoke-pack) now route the single B74.6 delta separately from the older B74.5 bundle. Full current branch is 132 files over `origin/master@f8a76de34`; `b996bcb3..712a7a668` is one clean 9-file client RPT/FPS regression-fix commit. Source Chernarus gets RHUD/common helper nil guards plus death-camera guards; maintained Vanilla and touched full modded forks get death-camera guards only. No gameplay source changed. |
| `attack-wave-authority-current-b742-refresh-2026-06-24` | Published / validated | Refreshed [Attack-wave authority](Attack-Wave-Authority-Playbook#branch--root-matrix), [Feature status](Feature-Status-Register), [Source Fix queue](Source-Fix-Propagation-Queue), [Server authority map](Server-Authority-Migration-Map) and [Public variable channel index](Public-Variable-Channel-Index) so DR-41 now includes current B74.2 `origin/claude/b74.2-aicom@21b62b04`. Docs/source `HEAD@426de4570993` is unchanged from `a764d51107de` for checked attack-wave request/detail/client-price paths. Current stable/B74.1, B74.2, B69, B74, Miksuu, perf and historical refs all keep `ATTACK_WAVE_INIT` client `_supply`/`_side` trust and `ATTACK_WAVE_DETAILS` detail-payload trust in both maintained roots; B74.2 only line-drifts source-Chernarus buy-menu/constants context. No gameplay source changed. |
Older published batches are intentionally omitted from this table. Use [Agent worklog](Agent-Worklog), [Discovery swarm](Subagent-Discovery-Swarm), [`agent-status.json`](agent-status.json), [`agent-events.jsonl`](agent-events.jsonl) and git history for the long audit trail.

## At A Glance

| Actor | Status | Current lane | What to expect next |
| --- | --- | --- | --- |
| Codex | Ready | `documentation-finisher-loop` | Latest bounded pass `b745-b747-current-head-refresh-2026-06-24` is published/validated; next work should claim a new narrow source-backed docs lane before editing. |
| FPS scout window | Returned / harvested | `old-be-current-wasp-fps-opportunity-scout-2` | Final report returned at `C:\Users\Steff\Documents\Codex\2026-06-05\wasp-old-mission-fps-opportunity-window\outputs\Old-BE-vs-Current-Wasp-FPS-Opportunity-Scout.md` and has been compacted into the old-BE, performance, testing and Feature Status owner pages. |
| Codex-2 | Ready | None | Pick a bounded source-backed lane from PVF dispatcher lookup, commander reassignment call-shape repair, remaining supply authority hardening, or another current-head status refresh. |
| Claude | Autonomous-ready | `collaboration-follow-autonomous-ready` | Coverage Ledger navigation is wired. Claude can self-select the next bounded source-backed review from the ledger or hardening backlog. |
| Supported docs agents | First batch published / historical | `research-catchup-synthesis-default-supported`, `relevance-pruning-and-archive-default-supported` | Earlier account-default helper chats produced catch-up and pruning/archive work. Relaunch or resume only for a fresh narrow lane; they are not live dashboard blockers. |
| Read-only pruning scouts | Returned / harvested | `ui-runtime-bloat-scout`, `wiki-navigation-chain-scout` | UI/runtime lead is promoted; small navigation fixes are promoted; remaining archive-page caveat note is already satisfied by archive page headers. |
| Sub-agents | Returned / closed | `navigation-parity-and-scout-wave-2026-06-04` | Supports, UI, tooling and AI scouts returned; most findings confirmed existing owner pages. Economy scout was closed without output and is not evidence. |
| Shared docs | Latest wiki payload mirrored here | GitHub wiki + `docs/wiki` mirror | This workspace mirrored live wiki `origin/master@4d4014a` into `docs/wiki` for the latest reference pages, nav routes and context files. If another active gameplay branch lacks `docs/wiki`, work in a standalone wiki checkout and record that branch-specific caveat before parity claims. |

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
| Compact machine index | [`agent-machine-index.json`](agent-machine-index.json) |
| Agent release readiness ledger | [Agent release readiness ledger](Agent-Release-Readiness-Ledger) |
| Latest event stream | [`agent-events.jsonl`](agent-events.jsonl) |
| Dated narrative notes | [Agent worklog](Agent-Worklog) |
| External report intake | [External research reports](External-Research-Reports) |
| External report manifest | [`external-research-report-manifest.json`](external-research-report-manifest.json) |
| Pruning and relevance decisions | [Wiki pruning and relevance ledger](Wiki-Pruning-And-Relevance-Ledger) |

## Current Lanes

This table is only for active, autonomous-ready, watchlist or future owner lanes. Published documentation batches are recorded in **Latest Batch**, [Agent worklog](Agent-Worklog), [`agent-status.json`](agent-status.json), [`agent-events.jsonl`](agent-events.jsonl) and git history.

| Lane | Owner | Status | Next action |
| --- | --- | --- | --- |
| `documentation-finisher-loop` | Codex | Ongoing / ready | Latest bounded pass `b745-b747-current-head-refresh-2026-06-24` is published/validated; next work should claim a new narrow source-backed docs lane before editing. |
| `autonomous-claude-research` | Claude | Autonomous-ready | Self-select the next bounded source-backed review from [Codebase coverage ledger](Codebase-Coverage-Ledger) when Claude is active. |
| `feature-status-reconciliation` | Codex / future agent | Watchlist | Fold newly confirmed findings into [Feature status](Feature-Status-Register), owner pages and machine records. No untriaged finding is blocking this dashboard. |
| `indicator-exploration-backlog` | Codex / future UI scout | Matrix seeded; status counters refreshed | Use the seeded [indicator surface matrix](Client-UI-Systems-Atlas#indicator-surface-matrix) to pick the next family after the status-counter split, then do branch/root validation, owner-page integration or pruning; do not restart a broad "all indicators" checklist. |
| `implementation-hardening-from-backlog` | Future code owner | Owner decision / code lane | Pick implementation work from [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl) only when Steff asks for gameplay patches or a code owner claims the work. |
| `testing-debugging-release-workflow` | Codex / future tester | Published release gate | Use [Testing workflow](Testing-Debugging-And-Release-Workflow) to distinguish source review, propagated source fixes and actual Arma smoke evidence. |
| `source-propagated-smoke-pending` | Future tester / release owner | Smoke pending | [Client skill init](Client-Skill-Init-Idempotency), [hosted FPS](Hosted-Server-FPS-Loop-Sleep), [supply scan](Supply-Mission-Scan-Narrowing), [paratrooper markers](Paratrooper-Marker-Revival) and [commander-built ARTY](Construction-And-CoIn-Systems-Atlas) are tracked in owner pages and Feature Status; they are not dashboard cleanup blockers. |
| `wasp-marker-wait-cleanup` | Future code owner | Target-specific source/smoke work | [WASP marker wait cleanup](WASP-Marker-Wait-Cleanup) remains patch-ready on docs/source, current Miksuu, perf and historical old-shape refs; current B74-shaped, client-fps and live map refs need marker-dialog smoke rather than the one-line sleep reopened. |

## July Update To-Do

| # | Item | Dev branch | Scope | LOC estimate | Status | Validation gate |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Hosted Server FPS Loop Fix | planned `dev/july-update-hosted-server-fps-loop-fix` | Adopt/verify the DR-19 hosted/listen busy-spin fix for the July update target. Choose the target branch shape deliberately: current stable/B74.1 `origin/master@f8a76de34` already uses one guarded `SERVER_FPS_GUI` publisher, while docs/source keeps two guarded compatibility publishers. | ~5-20 LOC for a two-publisher loop guard on old-shape refs; ~20-50 LOC if cleanup/consolidation is included. | Queued for July update, but no current remote `origin/dev/july-update-hosted-server-fps-loop-fix` head was found on 2026-06-22. Create or restore the branch before code work. | Target-branch-specific: current-stable-shaped branch keeps dedicated `SERVER_FPS_GUI` publishing and no monitor loop; docs/source-shaped branch keeps `SERVER_FPS_GUI` plus `WFBE_VAR_SERVER_FPS`. In all cases, hosted/listen runs do not spin FPS publisher loops and Chernarus/maintained Vanilla parity is named before release wording. |
| 2 | Takistan Airfield FPV Drone Bay | `origin/dev/july-2026-update@e3f530ed` planning route; no current `origin/dev/july-takistan-airfield-fpv-drone` head found on 2026-06-22 | Add neutral captured-airfield objectives on Takistan. Use runway-edge capture placement plus a bunker/camp-gated Drone Bay near each hangar; unlock player-funded FPV drones with UAV/EASA progression, one active drone per player, side-wide cap, center-map boundary kill, no base sniping and AA/radar counterplay. Normal aircraft hangar use stays ungated. | ~350-700 LOC prototype; ~1000-1800 LOC for a July-quality server-authoritative Takistan-only version, plus `mission.sqm` object edits. | Queued as planning only. Closed draft PR [#21](https://github.com/rayswaynl/a2waspwarfare/pull/21) routes `dev/july-2026-update@e3f530ed` to `release/2026-06-feature-bundle`; `docs/july-2026-update.md` is a roadmap scaffold and states no gameplay code yet. The old per-feature branch name is not a current remote head. | Create or restore an implementation branch before code work, then run Takistan boot/capture/JIP smoke; economy smoke for `$50` per player per cycle; UAV/EASA gate smoke; server-side ownership/funds/cap/tier/range rejection tests; base-protection and AA/radar counterplay smoke. |

## Recently Closed / Reclassified Open Items

- AICOM/PR board route: [PR cleanup and integration lab](PR-Cleanup-And-Integration-Lab) was refreshed on 2026-06-24. Current open PRs are #83, #80, #74, #72, #66, #63, #59, #54, #53 and #9. PR #43 and PR #40 are closed as of 2026-06-22; older rows calling them open are historical. PR #35 and deploy-child PR #34/#36-#39/#41 remain closed history; PR #29 and PR #31 merged on 2026-06-17; PR #9 remains the separate Zargabad map/content lane.
- Salvage payout/loop branch scope: [Construction and CoIn systems](Construction-And-CoIn-Systems-Atlas#salvage-branch-matrix), [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue) now treat salvage as inherited current-source/current-stable debt: docs branch `fb8d4ebc`, current stable `origin/master@0139a346`, current Miksuu `b8389e748243`, perf `0076040f` and historical release commit `a96fdda2` all keep the lowercase payout call, `||` loop and client-local deletion/reward shape; current origin has no live `release/*` or `feat/*salvage*` head.
- Camp flag texture branch scope: [Towns/camps/capture](Towns-Camps-And-Capture-Atlas), [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue) now distinguish current stable/B74.1/B74.2/B69/B74/release/naval independent-capture fixes from docs checkout/Miksuu/perf old-owner shapes; `origin/fix/wildcard-w4w5-outer-capture@ead7e854` is marker/handler context only, and repair-side world-flag refresh remains code-owner work everywhere checked.
- Coverage Ledger navigation request: [Home](Home), [`_Footer.md`](_Footer), [`llms.txt`](llms.txt) and [`agent-context.json`](agent-context.json) already linked it; [`_Sidebar.md`](_Sidebar) now links it too, and the Coordination Board mailbox is marked done.
- Dead-code OA compatibility scan refresh: [Dead/stale code register](Dead-Code-And-Stale-Code-Register) and `docs/analysis/dead-code-oa-compatibility-scan.json` now reflect the latest docs tree; the scan still reports `0` code-risk implementation hits.
- Final old-BE/current-Wasp FPS scout: `old-be-current-wasp-fps-opportunity-scout-2` returned and was harvested into [Old WarfareBE comparison](Old-WarfareBE-Performance-Comparison), [Performance sweep](Performance-Opportunity-Sweep), [Testing workflow](Testing-Debugging-And-Release-Workflow#full-server-fps-opportunity-pack) and [Feature status](Feature-Status-Register). It is no longer a live lane.
- Old FPS provenance cleanup: [Old WarfareBE comparison](Old-WarfareBE-Performance-Comparison) already routes current Wasp truth through source paths and [Current source status snapshot](Current-Source-Status-Snapshot); it is no longer a Latest Batch row.
- OA object-lifecycle command addendum: the old Codex-2 active claim is closed into [Arma 2 OA command version reference](Arma-2-OA-Command-Version-Reference#object-lifecycle-commands--oa-safe-locality-sensitive), covering `createVehicle`, `createUnit`, `deleteVehicle`, `hideObject` / `enableSimulation` and the A3-only `*Global` variants.
- Old BE/FPS helper windows are harvested and no longer live dashboard lanes. Their outputs route through [Old WarfareBE comparison](Old-WarfareBE-Performance-Comparison), [Player AI caps](Player-AI-Caps-And-Role-Balance), [Performance sweep](Performance-Opportunity-Sweep), [Testing workflow](Testing-Debugging-And-Release-Workflow#full-server-fps-opportunity-pack), [Feature status](Feature-Status-Register), [Agent worklog](Agent-Worklog) and [`agent-events.jsonl`](agent-events.jsonl).
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
