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
| `salvage-w10-branch-status-refresh-2026-06-22` | Published / validated | Refreshed [Construction and CoIn salvage](Construction-And-CoIn-Systems-Atlas#salvage-branch-matrix), [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue), [AI commander treasury accessors](AI-Commander-Treasury-Fund-Accessors) and machine rows after fresh fetch exposed live `origin/claude/salvage-w10-manfilter@2e0242b3`. Docs/source `HEAD@98eb9607` is unchanged from `fb8d4ebc` for checked manual/truck salvage files; current stable `origin/master@0139a346`, current B69 `8d465fce`, adjacent B74 `b23f557f`, current Miksuu `b8389e748243`, perf `0076040f` and historical `a96fdda2` still keep lowercase `ChangePlayerfunds`, `updatesalvage.sqf:10` OR-loop and client-local delete/reward in both maintained roots. The live salvage branch is older B39/GUER-based evidence with merge-base `8fac20df`; it changes only `AI_Commander_Wildcard.sqf` in both maintained roots, adding `!(_wk isKindOf "Man")` to inert W10 at `:794`, and does not rescue manual/truck payout or authority. No gameplay source changed. |
| `attack-wave-authority-current-b69-head-refresh-2026-06-22` | Published / validated | Refreshed [Attack-wave authority playbook](Attack-Wave-Authority-Playbook#branch--root-matrix), [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue), [Public variable channel index](Public-Variable-Channel-Index), [Server authority migration map](Server-Authority-Migration-Map) and machine rows with current B69 `origin/claude/b69@8d465fce` evidence. Docs/source `HEAD@1c1ea559` is unchanged from `f3e157f2` for checked attack-wave request/detail/client-price paths. Current stable `origin/master@0139a346`, current B69, current Miksuu `b8389e748243`, perf `0076040f`, historical `a96fdda2`, historical `c20ce153` and historical `994150da` all keep `ATTACK_WAVE_INIT` side/supply trust plus `ATTACK_WAVE_DETAILS` side/modifier/duration trust in both maintained roots. B69 path deltas `0a1ccb4d..8d465fce` and `b8530477..8d465fce` are empty for checked attack-wave request/detail/client-price paths. Adjacent B74 `origin/claude/b74-aicom-spend@b23f557fc912` changes only Chernarus constants among checked attack-wave paths and keeps the same request/detail trust. No gameplay source changed. |
| `commander-reassignment-current-b69-head-refresh-2026-06-22` | Published / validated | Refreshed [Commander reassignment call shape](Commander-Reassignment-Call-Shape#current-branch-matrix), [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook#current-branch-scope), [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue) and machine rows with current B69 `origin/claude/b69@8d465fce` evidence. Docs/source `HEAD@337ed166` is unchanged from `b44aaaf8` for checked reassignment paths and still uses `_side = _this` in both maintained roots. Current stable `origin/master@0139a346`, current B69, current Miksuu `b8389e748243`, perf `0076040f`, historical `a96fdda2` and historical `c20ce153` fix the helper shape in maintained roots, while duplicate reassignment notifications, visible-name UI selection, requester authority and stable/B69 full modded fork drift remain open. No gameplay source changed. |
| `send-message-direct-compile-current-b69-head-refresh-2026-06-22` | Published / validated | Refreshed [Public variable channel index](Public-Variable-Channel-Index#send_message-direct-compile-branch-matrix), [Networking and public variables](Networking-And-Public-Variables), [Hardening implementation roadmap](Hardening-Implementation-Roadmap), [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue) and machine rows with current B69 `origin/claude/b69@8d465fce` evidence. Docs/source `HEAD@40c477be` is unchanged from `16247fc8f` for checked Chernarus/Vanilla `SEND_MESSAGE` paths. Current stable `origin/master@0139a346`, current B69, current Miksuu `b8389e748243` and perf `0076040f` all still keep direct `SEND_MESSAGE` registration at `updateclient.sqf:12` plus receiver/helper `call compile` at `Client_onEventHandler_SEND_MESSAGE.sqf:27` and `Common_SendMessage.sqf:26,37-38` in both maintained roots; B69 path deltas `0a1ccb4d..8d465fce` and `b8530477..8d465fce` are empty. No gameplay source changed. |
| `mash-marker-current-b69-head-refresh-2026-06-22` | Published / validated | Refreshed [Respawn and death lifecycle](Respawn-And-Death-Lifecycle-Atlas#mash-split-live-respawn-dead-marker-relay), [Abandoned feature revival](Abandoned-Feature-Revival-Review#mash-markers), [Public variable channel index](Public-Variable-Channel-Index), [Feature status](Feature-Status-Register), [Dead/stale code register](Dead-Code-And-Stale-Code-Register) and machine rows with current B69 `origin/claude/b69@8d465fce` evidence. Docs/source `HEAD@2b513921` is unchanged from `db3015f18ea3` for checked maintained-root MASH paths. Current stable `origin/master@0139a346`, historical `a96fdda2` and current B69 expose only the `Skill_Apply.sqf:43` deploy-removed cue and no maintained-root `Client/Module/MASH`, `Server/Module/MASH` or `Skill_Officer.sqf` paths; B69 diffs from `0a1ccb4d` and `80d3267c` touch `Init_Client.sqf` but contain no MASH-related hunks. No gameplay source changed. |
Older published batches are intentionally omitted from this table. Use [Agent worklog](Agent-Worklog), [Discovery swarm](Subagent-Discovery-Swarm), [`agent-status.json`](agent-status.json), [`agent-events.jsonl`](agent-events.jsonl) and git history for the long audit trail.

## At A Glance

| Actor | Status | Current lane | What to expect next |
| --- | --- | --- | --- |
| Codex | Ready | `documentation-finisher-loop` | Latest published lane: `salvage-w10-branch-status-refresh-2026-06-22`. Continue bounded source-backed docs passes from this dashboard, the refreshed [PR cleanup lab](PR-Cleanup-And-Integration-Lab), Feature Status, Source Fix queue and pruning ledger. |
| FPS scout window | Returned / harvested | `old-be-current-wasp-fps-opportunity-scout-2` | Final report returned at `C:\Users\Steff\Documents\Codex\2026-06-05\wasp-old-mission-fps-opportunity-window\outputs\Old-BE-vs-Current-Wasp-FPS-Opportunity-Scout.md` and has been compacted into the old-BE, performance, testing and Feature Status owner pages. |
| Codex-2 | Ready | None | Pick a bounded source-backed lane from PVF dispatcher lookup, commander reassignment call-shape repair, remaining supply authority hardening, or another current-head status refresh. |
| Claude | Autonomous-ready | `collaboration-follow-autonomous-ready` | Coverage Ledger navigation is wired. Claude can self-select the next bounded source-backed review from the ledger or hardening backlog. |
| Supported docs agents | First batch published / historical | `research-catchup-synthesis-default-supported`, `relevance-pruning-and-archive-default-supported` | Earlier account-default helper chats produced catch-up and pruning/archive work. Relaunch or resume only for a fresh narrow lane; they are not live dashboard blockers. |
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
| `documentation-finisher-loop` | Codex | Active / ongoing | Use this dashboard, [Coordination board](Coordination-Board), [Wiki pruning ledger](Wiki-Pruning-And-Relevance-Ledger), [Feature status](Feature-Status-Register), [Pending owner decisions](Pending-Owner-Decisions), machine status files and fresh source evidence as the live open-task route. |
| `autonomous-claude-research` | Claude | Autonomous-ready | Self-select the next bounded source-backed review from [Codebase coverage ledger](Codebase-Coverage-Ledger) when Claude is active. |
| `feature-status-reconciliation` | Codex / future agent | Watchlist | Fold newly confirmed findings into [Feature status](Feature-Status-Register), owner pages and machine records. No untriaged finding is blocking this dashboard. |
| `indicator-exploration-backlog` | Codex / future UI scout | Matrix seeded; status counters refreshed | Use the seeded [indicator surface matrix](Client-UI-Systems-Atlas#indicator-surface-matrix) to pick the next family after the status-counter split, then do branch/root validation, owner-page integration or pruning; do not restart a broad "all indicators" checklist. |
| `implementation-hardening-from-backlog` | Future code owner | Owner decision / code lane | Pick implementation work from [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl) only when Steff asks for gameplay patches or a code owner claims the work. |
| `testing-debugging-release-workflow` | Codex / future tester | Published release gate | Use [Testing workflow](Testing-Debugging-And-Release-Workflow) to distinguish source review, propagated source fixes and actual Arma smoke evidence. |
| `source-propagated-smoke-pending` | Future tester / release owner | Smoke pending | [Client skill init](Client-Skill-Init-Idempotency), [hosted FPS](Hosted-Server-FPS-Loop-Sleep), [supply scan](Supply-Mission-Scan-Narrowing), [paratrooper markers](Paratrooper-Marker-Revival) and [commander-built ARTY](Construction-And-CoIn-Systems-Atlas) are tracked in owner pages and Feature Status; they are not dashboard cleanup blockers. |
| `wasp-marker-wait-cleanup` | Future code owner | Source needs code | [WASP marker wait cleanup](WASP-Marker-Wait-Cleanup) remains a tiny patch-ready opportunity, not an active docs lane. |

## July Update To-Do

| # | Item | Dev branch | Scope | LOC estimate | Status | Validation gate |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Hosted Server FPS Loop Fix | planned `dev/july-update-hosted-server-fps-loop-fix` | Adopt/verify the DR-19 hosted/listen busy-spin fix for the July update target. Choose the target branch shape deliberately: current stable `origin/master@0139a346` already uses one guarded `SERVER_FPS_GUI` publisher, while docs/source keeps two guarded compatibility publishers. | ~5-20 LOC for a two-publisher loop guard on old-shape refs; ~20-50 LOC if cleanup/consolidation is included. | Queued for July update, but no current remote `origin/dev/july-update-hosted-server-fps-loop-fix` head was found on 2026-06-22. Create or restore the branch before code work. | Target-branch-specific: current-stable-shaped branch keeps dedicated `SERVER_FPS_GUI` publishing and no monitor loop; docs/source-shaped branch keeps `SERVER_FPS_GUI` plus `WFBE_VAR_SERVER_FPS`. In all cases, hosted/listen runs do not spin FPS publisher loops and Chernarus/maintained Vanilla parity is named before release wording. |
| 2 | Takistan Airfield FPV Drone Bay | `origin/dev/july-2026-update@e3f530ed` planning route; no current `origin/dev/july-takistan-airfield-fpv-drone` head found on 2026-06-22 | Add neutral captured-airfield objectives on Takistan. Use runway-edge capture placement plus a bunker/camp-gated Drone Bay near each hangar; unlock player-funded FPV drones with UAV/EASA progression, one active drone per player, side-wide cap, center-map boundary kill, no base sniping and AA/radar counterplay. Normal aircraft hangar use stays ungated. | ~350-700 LOC prototype; ~1000-1800 LOC for a July-quality server-authoritative Takistan-only version, plus `mission.sqm` object edits. | Queued as planning only. Closed draft PR [#21](https://github.com/rayswaynl/a2waspwarfare/pull/21) routes `dev/july-2026-update@e3f530ed` to `release/2026-06-feature-bundle`; `docs/july-2026-update.md` is a roadmap scaffold and states no gameplay code yet. The old per-feature branch name is not a current remote head. | Create or restore an implementation branch before code work, then run Takistan boot/capture/JIP smoke; economy smoke for `$50` per player per cycle; UAV/EASA gate smoke; server-side ownership/funds/cap/tier/range rejection tests; base-protection and AA/radar counterplay smoke. |

## Recently Closed / Reclassified Open Items

- AICOM deploy PR board route: [PR cleanup and integration lab](PR-Cleanup-And-Integration-Lab) was refreshed on 2026-06-21. PR #35 and deploy-child PR #34/#36-#39/#41 are closed history, PR #29 and PR #31 merged on 2026-06-17, PR #40 remains open but stacked on a closed base, PR #43 is the current open master-target soak/proposals route and PR #9 remains the separate Zargabad map/content lane.
- Salvage payout/loop branch scope: [Construction and CoIn systems](Construction-And-CoIn-Systems-Atlas#salvage-branch-matrix), [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue) now treat salvage as inherited current-source/current-stable debt: docs branch `fb8d4ebc`, current stable `origin/master@0139a346`, current Miksuu `b8389e748243`, perf `0076040f` and historical release commit `a96fdda2` all keep the lowercase payout call, `||` loop and client-local deletion/reward shape; current origin has no live `release/*` or `feat/*salvage*` head.
- Camp flag texture branch scope: [Towns/camps/capture](Towns-Camps-And-Capture-Atlas), [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue) now distinguish stable/release independent-capture fixes from docs checkout/Miksuu/perf old-owner shapes; repair-side world-flag refresh remains code-owner work everywhere checked.
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
