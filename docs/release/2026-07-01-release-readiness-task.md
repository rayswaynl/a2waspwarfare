# 2026-07-01 Release Readiness Task

Owner: Codex multi-agent loop
Scope: Chernarus and Takistan release readiness for `rayswaynl/a2waspwarfare`

## Goal

Prepare the updated WASP Warfare mission release for both maintained vanilla terrains:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan`

The working standard is source parity, runtime evidence, and wiki/player documentation that match the same release candidate. This ledger is intentionally narrow: it records findings, blockers, and next actions while the code and wiki work continue in focused follow-up commits.

## Active PR Map

As of 2026-07-01 after the PR #125 HC-top-up draft-worker source refresh:

- `origin/master`: current observed head `7fd310c63`, moved since PR #126 base only by deleting stale top-level `B57-SOAK-PROPOSALS.md` and `GUER_TECH.md`; GitHub still reports PR #126 clean/mergeable.
- PR #123, `[codex] running release findings log`, branch `codex/release-findings`: docs-only running findings log for release proof. Current head observed: `d238d0ad4`.
- PR #124, `[codex] Release r8 integration findings for July 2`, branch `release/2026-07-02-stackcheck-r8`: r8 stack candidate with package hashes and NO-GO until exact runtime proof.
- PR #125, `[codex] Prepare WASP release command center`, branch `codex/release-command-center-20260630`: broad release command-center candidate with tooling, package provenance, AICOM work, and runtime collection gates. Latest source head observed: `153a513fb`; the latest source-only deltas remove the uncompiled AICOM HC top-up draft worker/wiring from both maintained terrains, remove stale supervisor private declarations, and tighten the static smoke guard for forbidden draft tokens. Last package/handoff proof still binds to `c0d2b42ef5`: PR #125 and the public wiki record `_MISSIONS.7z` SHA256 `A99EC513243EC161319B6AE16BB5A9A5308541FF03B6148D60FBE208D4E04AAC`, `1,879` entries, `7,139,450` bytes, handoff status `ready_for_runtime_collection`. Do not collect runtime proof for `153a513fb` until that head is repackaged; otherwise intentionally freeze collection on `c0d2b42ef5`.
- PR #131, `[codex] Fix placement preview static gate`, branch `codex/fix-b724-placement-static`: focused static-gate follow-up for the latest master placement-preview blocker. Current branch head observed: `bc297a632` after a force-update onto `origin/master@7fd310c63`; prior findings artifact `outputs/a2waspwarfare-pr131-2178b20d-server-debug-missions.7z` with SHA256 `4B6E14D5528B5037C6387832B4A8A4DBF555EA251748E9D3A349BB83E93CD95D` remains packaging/tooling proof only for old head `2178b20d3`, not exact current-head proof unless refreshed or explicitly accepted as same mission delta.
- This branch, `codex/release-readiness-20260701`: multi-agent task ledger and AICOM guardrail/proof-instrumentation lane. HC audit source is through `f20ddfc83`, the first livehost proof-gap ledger was pushed at `5b2e29c1c`, and the local proof-instrumented archive SHA256 `C0220856B624ABDA4204D1A6C554505C54C4B75541B6900D2725E08C522763CD` remains PR #126 companion evidence only; use the chosen PR #125 package tuple for active runtime collection unless the owner intentionally cuts a new package from this lane. GitHub reports PR #126 open, draft, clean, and mergeable.

## Agent Lanes

- AI commander/core logic audit: inspect loops, cadence, network/public-variable pressure, stuck-team recovery, AICOM v2 behavior, and Chernarus/Takistan divergence.
- Docs/wiki audit: compare repo docs, player guide, mission briefing, and wiki pages against current release behavior.
- External source reconnaissance: inventory Jerry files, Miksuu original repo/dump, BI documentation/forums, public server stats, and SSH/RPT access blockers.

## Source Ledger

| Source | Current status | Use in this loop |
| --- | --- | --- |
| `rayswaynl/a2waspwarfare` | Local PR #126 refresh worktree is based on `origin/master` through `b7241a35f` plus the rebased release-readiness stack. Current `origin/master` is `7fd310c63`; the branch is not rebased onto the two latest master doc deletions, but GitHub reports PR #126 clean/mergeable. The original branch root was `6cbf6f6a5`; the HC audit source commit is `f20ddfc83`. | Primary code, docs, tools, release branches, PR evidence. |
| `rayswaynl/a2waspwarfare.wiki` | Cloned locally and synced through wiki commit `6be0a72`, which records the PR #125 source-head/package-proof gap, the PR #126 livehost marker-sweep caveat, and HC audit source through `f20ddfc83`. PR #125 has since moved to source head `153a513fb`; update the wiki from `source-head-moved/package-pending` to a fresh package tuple only after a new package/handoff is recorded. Wiki commit hashes are not release identities; use the package/git/archive tuple and RPT markers for release proof. | Wiki freshness and release-doc synchronization. |
| `Miksuu/a2waspwarfare` | Public repo reachable; local clone exists at `work/miksuu-original`, remote `https://github.com/Miksuu/a2waspwarfare.git`, HEAD `b8389e74` from 2026-06-09. Checkout hit Windows long-path failure on one very long LoadoutManager filename. | Historical/original mission comparison where files are present; full comparison needs long-path-safe checkout or sparse checkout. |
| Jerry mission dump | Public index reachable; Arma2 section reports 1498 files / 24.23 GB and Arma2 OA reports 535 files / 29.42 GB. Exact useful query: `https://bidentify.jerryhopper.com/api/search/WarfareV2_073`. Key package lead: `WarfareV2_073LiteCO.zip`, which lists Takistan, Zargabad, and Chernarus PBOs. | Historical Benny/Warfare 0.73 baseline, hashes, archive contents, and downloadable reference PBOs once a specific comparison is needed. |
| Miksuu Google Drive mission dump | Not fetched yet. Password `armedassault` is known, but no exact folder URL was discovered from public/local notes beyond the user-provided Drive view. | Requires Drive/browser download handling; add only after exact candidate packages are identified. |
| BI official Arma 2 OA scripting docs | Required reference per `AGENTS.md`; `publicVariable` and `createVehicle` docs were reachable. | Use to check A2/OA command compatibility and multiplayer caveats; avoid Arma 3-only commands. |
| BI forums | bIdentify provenance thread is reachable. Specific Warfare/Benny threads were not found from broad search. | Use for Warfare BE/AI commander/performance history once exact thread names or URLs are available. |
| `https://miksuu.com/wasp` | Public page reachable; advertises live frontline, economy, AI commander, server performance, and records. | Source for dashboard/wiki expectations and runtime metric names. |
| `https://miksuu.com/leaderboard` | Public leaderboard reachable; current scrape shows 33 players and no AI-commander round data yet. | Cross-check stats pipeline and AI commander telemetry visibility. |
| `https://miksuu.com/api/wasp-stats` | Public API reachable but returned `online:false`, `stale:true` during the sweep. | Compare public API freshness against server-side stats files. |
| `http://78.46.107.142:8080/` | Direct page timed out in this environment. | Dashboard/runtime status source; verify from an environment that can reach the port. |
| SSH RPTs on Game PC / Hetzner | Read-only `livehost` alias was discoverable and worked. Backing stats files exist under `C:/WASP/web`; latest server-side stats observed `generatedAt: 2026-07-01T16:08:17Z`, server online, Chernarus, 1 player, 2 headless clients, server FPS last/avg `47/46`, HC delegation `89%`, live group sources including `aicom` and `aicom_paradrop`. Latest RPT sweep still shows live `AICOMSTAT`/`HCSTAT` and `release-command-center-20260630` markers but no PR #126 `HCDROP_AICOM_AUDIT`/`HCRECON_AICOM_AUDIT` markers and no `0eb72ca47`/`c148d0d6`/`f20ddfc83`/archive-SHA marker. | Current live telemetry is useful health evidence, but not exact PR #126 runtime proof. |

## First Findings

1. AI commander retreat order mode casing mismatch.
   - `AI_Commander_Produce.sqf` emitted `"DEFENSE"` for retreat-and-reform.
   - The HC/shared executor branches on exact lowercase `"defense"` in `Common_RunCommanderTeam.sqf`.
   - Impact: depleted teams ordered home could fall through to the generic assault behavior instead of the intended tight defense branch.
   - Action: fixed in Chernarus by emitting lowercase `"defense"`; Takistan must be regenerated by LoadoutManager.

2. AI cap tier lookup was only lower-clamped.
   - `AI_Commander_Produce.sqf` and `AI_Commander_Teams.sqf` selected `WFBE_C_TOTAL_AI_MAX_BY_TIER` with `WFBE_PopTier max 0`, but no upper clamp.
   - Normal published tiers are 0-3, but a bad override, shorter array, or future tier could throw a select error and break production/founding.
   - Action: fixed in Chernarus with array-empty fallback plus upper clamp; Takistan must be regenerated by LoadoutManager.

3. Wiki/player guide stale on AI commander status.
   - `Guides/CommanderGuide/commanderGuide.md:35` still says the AI commander feature was removed and replaced with "No commander".
   - Current mission briefing says the commander can be a player or the AI Commander in both Chernarus and Takistan at `briefing.sqf:75`.
   - Action: repo commander guide updated; wiki `Commanders-Handbook` already reflects the AI Commander fallback and needs a release-readiness landing page.

4. Briefing content has inconsistent economy numbers.
   - `briefing.html:19` says the bank pays `$5,000 per 5 minutes` and enemy bank destruction pays `+$40,000 side supply`.
   - `briefing.sqf:104` says the bank pays `$6,000 total every 5 minutes`; `briefing.sqf:160` says enemy bank destruction awards `+10,000 side supply`.
   - This mismatch exists in both maintained terrains.
   - Source truth confirmed in both maintained terrains: build cost 9,500 supply, placement accepted at `>= 800 m` from HQ/base-area centers, one bank per side, `$6,000` pool every 300 seconds split among living players while HQ is deployed, enemy-bank destruction pays `+10,000` side supply and `$25,000` to the killer.
   - Action: HTML briefing, repo patchlog, and stale bank-income source comment updated; Takistan must be regenerated by LoadoutManager.

5. AICOM v2 is now default-on for live tryout and must get exact runtime proof.
   - `WFBE_C_AICOM2_ALLOCATE_ENABLE = 1` in both `Common/Init/Init_CommonConstants.sqf:513`.
   - Intent HUD is default-on at `Init_CommonConstants.sqf:587`.
   - Paratroops are default-on at `Init_CommonConstants.sqf:468`.
   - HC merge remains dark at `Init_CommonConstants.sqf:758`.
   - Action: runtime proof must include AICOM intent/objective, team founding, paratroop gating, no stuck-team regressions, and both terrains.

6. AICOM supervisor watchdog can overlap after a long stall.
   - The watchdog respawns a commander supervisor when heartbeat age exceeds the timeout, but does not prove the old supervisor is dead.
   - Impact: a long synchronous stall could allow the old supervisor to resume after the watchdog spawned a replacement, causing double order/funds writers.
   - Action: patched in both maintained terrains. Initial supervisors now store a per-side script handle and owner generation; watchdog recovery terminates the stale handle, bumps the owner generation, and passes it to the replacement. Any stale supervisor that somehow resumes exits before its next tick and skips round-end logging. Runtime proof still needs an RPT line showing `WATCHDOG|restart-stale-hb` followed by no duplicate commander writers.

7. Public variable and log cadence need soak review.
   - Commander funds can publicVariable every 15s when exact funds change.
   - GUER stipend and air-defense state rebroadcasts are intentionally JIP-durable but chatty.
   - Pending HC dispatch and group-cap warnings can repeat heavily in long RPTs.
   - Action: partially mitigated. `GRPBUDGET|WARN` is now edge-triggered with a `GRPBUDGET|RECOVER` latch reset, while AI Commander team-founder group-cap warnings are throttled to once per side per 15 minutes while the cap remains exceeded. The lower-level `Common_CreateGroup.sqf` emergency-GC and `grpNull` warnings, plus the `Common_CreateTeam.sqf` template-skip follow-up, are now debounced to one report per side/machine every five minutes. `WFBE_PopTier` now gets a targeted join-time `publicVariableClient` catch-up so late joiners do not default their AI cap/RHUD scaling to low-pop tier until the next population-tier change. The side-keyed `WFBE_AICOM_*` intent/objective/active/focus/team/funds HUD variables now also get targeted join-time catch-up, keeping command-console, RHUD and friendly objective-marker state current for late joiners without making the strategy publisher chatty. Still defer exact-funds quantization and broad JIP rebroadcast changes until live RPT evidence proves they are worth the compatibility risk.

8. There is still a watched-command compatibility lead in wildcard code.
   - `Server/Functions/AI_Commander_Wildcard.sqf:325` documents the allDead replacement for lucky salvage.
   - The same file still has `allMissionObjects "AllVehicles"` around line 909 in both maintained terrains.
   - Action: resolved without relying on the unverified command. W10 Lucky Salvage is already removed from the active deck (`_wW10 = 0`), but the inert switch body now also uses the same `allDead` sweep as the eligibility proxy, eliminating the broad `allMissionObjects "AllVehicles"` scan from both maintained terrains.

9. Existing release PRs already agree on the main gate: source/static checks are not enough.
   - PR #124, PR #125, PR #126, and the PR #131 findings all require exact-build RPT evidence for Chernarus and Takistan.
   - PR #125 now has package/handoff proof for `c0d2b42ef5` / `_MISSIONS.7z` SHA256 `A99EC513243EC161319B6AE16BB5A9A5308541FF03B6148D60FBE208D4E04AAC`, but that is still package/tooling proof, not final runtime proof, and it does not prove later source head `153a513fb`. PR #126 and PR #131 artifacts remain companion/tooling proof unless explicitly promoted into the active package lane.
   - Action: do not mark release ready until server, HC1, HC2, start-client, and late-JIP evidence exists for both terrains or the required role matrix is explicitly reduced by the owner.

10. Wiki release structure needs a public-facing cleanup pass.
   - Add/update a July 2026 landing page for Chernarus and maintained Vanilla Takistan.
   - Label branch-only and WIP pages so they do not look production-ready.
   - Reconcile `_guer-build/DEPLOY-RUNBOOK.md` with later Takistan slice docs.
   - Add a server-operator page and a unified RPT/performance tools page.
   - Note that generated `version.sqf` is gitignored and must be part of pack/smoke/release validation.
   - Action: partially mitigated. The July 2026 landing page and sidebar entry are live, and Home/Sidebar now route readers to the current RPT release gate instead of the stale PR-harness anchor. The July page links the operator checklist, deployment inventory, ten-file RPT matrix, redaction-safe summary gate, and final release checklist. `AI-Commander-Execution-Loop-Reference` and `AI-Commander-Logging-And-AICOMSTAT-Telemetry` now carry PR #126 supersession notes so their old "branch-only/reverted" banners do not mislead release readers. Server ops and testing workflow pages already exist and document `version.sqf`, package provenance, and RPT gates; remaining work is pruning/labeling older branch/WIP pages.

11. Public stats and server-side stats disagreed during reconnaissance.
   - Public `/api/wasp-stats` reported stale/offline.
   - Read-only SSH stats files were fresher; the latest `C:/WASP/web/stats.json` observed at `2026-07-01T13:42:08Z` showed Chernarus online with 4 players, 2 HCs, server FPS last/avg `47/46`, HC delegation `93%`, and active commander-intel/pop-tier data.
   - Follow-up SSH stats at `2026-07-01T16:08:17Z` showed Chernarus still online with 1 player, 2 HCs, server FPS last/avg `47/46`, HC delegation `89%`, HC1/HC2 FPS `47/46`, active `aicom` group sources on both sides, and `aicom_paradrop` group source on WEST. This is live health context only because the RPT package/build markers still identify older command-center windows.
   - Action: include public API freshness and dashboard backing-file freshness in the release/server-ops checks, and keep exact build provenance separate from dashboard health.

12. Latest RPT candidates exist and were marker-swept without copying private logs.
   - `C:/WASP/rpt-archive/arma2oaserver-rot-ch-20260701-0538.RPT`
   - `C:/WASP/rpt-archive/arma2oaserver-deploy34-20260701-0356.RPT`
   - `C:/WASP/rpt-archive/arma2oaserver-deploy33-20260701-0341.RPT`
   - `C:/WASP/rpt-archive/arma2oaserver-deploy32-20260701-0303.RPT`
   - `C:/WASP/rpt-archive/arma2oaserver-deploy31-20260701-0247.RPT`
   - `C:/WASP/rpt-archive/arma2oaserver-recover-20260701-0019.RPT`
   - `C:/WASP/rpt-archive/arma2oaserver-seatheal2-20260701-0009.RPT`
   - `C:/WASP/rpt-archive/arma2oaserver-seatheal1-20260630-2359.RPT`
   - `C:/WASP/rpt-archive/arma2oaserver-preFIXch-20260630-1952.RPT`
   - Latest 8 RPTs contain many `AICOMSTAT` and `HCSTAT` lines, plus `WASPRELEASE|v1|candidate=release-command-center-20260630|git=5b1640cf88|terrain=takistan` and `git=6e0e324b79` samples.
   - Latest 8 RPTs contain no `HCDROP_AICOM_AUDIT`, `HCRECON_AICOM_AUDIT`, `HCSIDE|v1|disconnect`, `HCSIDE|v1|reconnect`, `HCDISPATCH`, `WF_RELEASE_MARKER`, `2178b20d`, `7e97c78b`, `f20ddfc83`, or `C0220856B624ABDA4204D1A6C554505C54C4B75541B6900D2725E08C522763CD` markers.
   - Follow-up marker sweep after PR #126 reached `0eb72ca47` still found 0 for `HCDROP_AICOM_AUDIT`, `HCRECON_AICOM_AUDIT`, `HCSIDE|v1|disconnect`, `HCSIDE|v1|reconnect`, `HCDISPATCH`, `WF_RELEASE_MARKER`, `0eb72ca47`, `c148d0d6`, `f20ddfc83`, `C0220856B624ABDA4204D1A6C554505C54C4B75541B6900D2725E08C522763CD`, `c0d2b42ef5`, `dda838639`, `153a513fb`, or `A99EC513243EC161319B6AE16BB5A9A5308541FF03B6148D60FBE208D4E04AAC`.
   - Action: these live logs confirm useful pre-instrumentation AICOM/HC health, but cannot satisfy the PR #126 exact-build HC-drop audit gate. Added `Tools/Monitor/Get-WaspRptMarkerSweep.ps1` so future livehost/archive checks can repeat this marker sweep with path hashes and line hashes instead of copied logs or raw lines. Added `Tools/Monitor/Test-WaspRptMarkerSweep.SelfTest.ps1`; synthetic validation passes for required-marker success, missing-marker `-NoFail`, missing-marker hard fail, comma-separated required markers, and default no-raw-line samples. Only copy/analyze broader private RPT contents after the owner confirms target build/window and privacy scope.

13. HC-disconnect adoption is still a release-risk lead.
   - `Server_OnPlayerDisconnected.sqf` removes a disconnected HC from future delegation registries, but does not yet prove already-running HC-owned AICOM teams have been re-adopted by the server after locality migrates.
   - `Common_RunCommanderTeam.sqf` marks HC teams with `wfbe_aicom_hc`; `AI_Commander_Produce.sqf` and `AI_Commander_Execute.sqf` treat HC teams differently from server-local teams.
   - Action: proof-first instrumentation added. `aicom-team-heading` now stamps `wfbe_aicom_last_heading_t` on each HC commander team, HC disconnects emit immediate plus 60-second `HCDROP_AICOM_AUDIT` lines, and HC reconnect registration emits `HCRECON_AICOM_AUDIT` lines with live HC-team counts, owner survivors, and fresh/stale/unknown heading heartbeat counts. Defer behavior-changing re-adoption until those RPT lines prove whether existing HC teams become inert.

## Working Backlog

- Decide whether this branch stays as a small findings PR or merges into PR #123/#125 after review.
- Re-run a focused Chernarus/Takistan source parity scan for AICOM/core files after each code change.
- Fix confirmed documentation mismatches in repo docs first, then push matching wiki updates only after source wording is stable.
- Mine the Miksuu original repo with a long-path-safe or sparse checkout for mission-level diffs.
- Select concrete Jerry/Miksuu dump packages before downloading large archives.
- Collect or import RPT evidence only after explicit approval for SSH/server access.
- Run a focused HC disconnect/reconnect proof pass and capture `HCSIDE|disconnect`, `HCDROP_AICOM_AUDIT`, `HCRECON_AICOM_AUDIT`, `HCSTAT`, `AICOMSTAT|...|HCDISPATCH`, and post-drop heading/marker continuity before changing HC team re-adoption behavior.
- Use `Tools/Monitor/Get-WaspRptMarkerSweep.ps1` for redaction-safe first-pass livehost/archive RPT marker counts before deciding whether any private RPT copies are needed.
- Re-run `Tools/Monitor/Test-WaspRptMarkerSweep.SelfTest.ps1` after edits to the marker-sweep helper.

## Validation Expectations

Minimum pre-release evidence:

- `Tools/LoadoutManager` run after Chernarus edits, with Takistan regenerated.
- Static A2/OA watched-token scan for both maintained missions.
- Diff check for generated drift between Chernarus and Takistan outside intentional terrain differences.
- Exact package hash recorded for the release candidate.
- RPT matrix for both terrains covering server, HC1, HC2, start-client, and late-JIP, unless owner approves a smaller matrix.
- Wiki pages updated to match the final candidate, not an intermediate branch.
