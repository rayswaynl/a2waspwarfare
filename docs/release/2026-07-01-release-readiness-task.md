# 2026-07-01 Release Readiness Task

Owner: Codex multi-agent loop
Scope: Chernarus and Takistan release readiness for `rayswaynl/a2waspwarfare`

## Goal

Prepare the updated WASP Warfare mission release for both maintained vanilla terrains:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan`

The working standard is source parity, runtime evidence, and wiki/player documentation that match the same release candidate. This ledger is intentionally narrow: it records findings, blockers, and next actions while the code and wiki work continue in focused follow-up commits.

## Active PR Map

As of 2026-07-01 08:16 UTC:

- PR #123, `[codex] running release findings log`, branch `codex/release-findings`: docs-only running findings log for release proof.
- PR #124, `[codex] Release r8 integration findings for July 2`, branch `release/2026-07-02-stackcheck-r8`: r8 stack candidate with package hashes and NO-GO until exact runtime proof.
- PR #125, `[codex] Prepare WASP release command center`, branch `codex/release-command-center-20260630`: broad release command-center candidate with tooling, package provenance, AICOM work, and runtime collection gates.
- This branch, `codex/release-readiness-20260701`: multi-agent task ledger and first-pass findings from the current release-readiness sweep.

## Agent Lanes

- AI commander/core logic audit: inspect loops, cadence, network/public-variable pressure, stuck-team recovery, AICOM v2 behavior, and Chernarus/Takistan divergence.
- Docs/wiki audit: compare repo docs, player guide, mission briefing, and wiki pages against current release behavior.
- External source reconnaissance: inventory Jerry files, Miksuu original repo/dump, BI documentation/forums, public server stats, and SSH/RPT access blockers.

## Source Ledger

| Source | Current status | Use in this loop |
| --- | --- | --- |
| `rayswaynl/a2waspwarfare` | Cloned locally; branch created from `origin/master` at `6cbf6f6a5`. | Primary code, docs, tools, release branches, PR evidence. |
| `rayswaynl/a2waspwarfare.wiki` | Cloned locally. | Wiki freshness and release-doc synchronization. |
| `Miksuu/a2waspwarfare` | Public repo reachable; local clone exists at `work/miksuu-original`, remote `https://github.com/Miksuu/a2waspwarfare.git`, HEAD `b8389e74` from 2026-06-09. Checkout hit Windows long-path failure on one very long LoadoutManager filename. | Historical/original mission comparison where files are present; full comparison needs long-path-safe checkout or sparse checkout. |
| Jerry mission dump | Public index reachable; Arma2 section reports 1498 files / 24.23 GB and Arma2 OA reports 535 files / 29.42 GB. Exact useful query: `https://bidentify.jerryhopper.com/api/search/WarfareV2_073`. Key package lead: `WarfareV2_073LiteCO.zip`, which lists Takistan, Zargabad, and Chernarus PBOs. | Historical Benny/Warfare 0.73 baseline, hashes, archive contents, and downloadable reference PBOs once a specific comparison is needed. |
| Miksuu Google Drive mission dump | Not fetched yet. Password `armedassault` is known, but no exact folder URL was discovered from public/local notes beyond the user-provided Drive view. | Requires Drive/browser download handling; add only after exact candidate packages are identified. |
| BI official Arma 2 OA scripting docs | Required reference per `AGENTS.md`; `publicVariable` and `createVehicle` docs were reachable. | Use to check A2/OA command compatibility and multiplayer caveats; avoid Arma 3-only commands. |
| BI forums | bIdentify provenance thread is reachable. Specific Warfare/Benny threads were not found from broad search. | Use for Warfare BE/AI commander/performance history once exact thread names or URLs are available. |
| `https://miksuu.com/wasp` | Public page reachable; advertises live frontline, economy, AI commander, server performance, and records. | Source for dashboard/wiki expectations and runtime metric names. |
| `https://miksuu.com/leaderboard` | Public leaderboard reachable; current scrape shows 33 players and no AI-commander round data yet. | Cross-check stats pipeline and AI commander telemetry visibility. |
| `https://miksuu.com/api/wasp-stats` | Public API reachable but returned `online:false`, `stale:true` during the sweep. | Compare public API freshness against server-side stats files. |
| `http://78.46.107.142:8080/` | Direct page timed out in this environment. | Dashboard/runtime status source; verify from an environment that can reach the port. |
| SSH RPTs on Game PC / Hetzner | Read-only `livehost` alias was discoverable and worked. Backing stats files exist under `C:/WASP/web`; latest server-side stats showed `generatedAt: 2026-07-01T08:23:06Z`, server online, Chernarus, 2 players, and 2 headless clients. | Deeper RPT harvesting needs explicit scope: which RPT window, which terrain/build, and whether to copy logs locally. |

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
   - Action: partially mitigated. `GRPBUDGET|WARN` is now edge-triggered with a `GRPBUDGET|RECOVER` latch reset, while AI Commander team-founder group-cap warnings are throttled to once per side per 15 minutes while the cap remains exceeded. The lower-level `Common_CreateGroup.sqf` emergency-GC and `grpNull` warnings, plus the `Common_CreateTeam.sqf` template-skip follow-up, are now debounced to one report per side/machine every five minutes. `WFBE_PopTier` now gets a targeted join-time `publicVariableClient` catch-up so late joiners do not default their AI cap/RHUD scaling to low-pop tier until the next population-tier change. Still defer exact-funds quantization and broad JIP rebroadcast changes until live RPT evidence proves they are worth the compatibility risk.

8. There is still a watched-command compatibility lead in wildcard code.
   - `Server/Functions/AI_Commander_Wildcard.sqf:325` documents the allDead replacement for lucky salvage.
   - The same file still has `allMissionObjects "AllVehicles"` around line 909 in both maintained terrains.
   - Action: resolved without relying on the unverified command. W10 Lucky Salvage is already removed from the active deck (`_wW10 = 0`), but the inert switch body now also uses the same `allDead` sweep as the eligibility proxy, eliminating the broad `allMissionObjects "AllVehicles"` scan from both maintained terrains.

9. Existing release PRs already agree on the main gate: source/static checks are not enough.
   - PR #124 and PR #125 both require exact-build RPT evidence for Chernarus and Takistan.
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
   - Read-only SSH stats files were fresher and showed the server online on Chernarus with 2 players and 2 HCs.
   - Action: include public API freshness and dashboard backing-file freshness in the release/server-ops checks.

12. Latest RPT candidates exist but need scoped harvesting.
   - `C:/WASP/rpt-archive/arma2oaserver-recover-20260701-0019.RPT`
   - `C:/WASP/rpt-archive/arma2oaserver-seatheal2-20260701-0009.RPT`
   - `C:/WASP/rpt-archive/arma2oaserver-seatheal1-20260630-2359.RPT`
   - `C:/WASP/rpt-archive/arma2oaserver-preFIXch-20260630-1952.RPT`
   - Action: only copy/analyze private RPTs after the owner confirms the target build/window and privacy scope.

## Working Backlog

- Decide whether this branch stays as a small findings PR or merges into PR #123/#125 after review.
- Re-run a focused Chernarus/Takistan source parity scan for AICOM/core files after each code change.
- Fix confirmed documentation mismatches in repo docs first, then push matching wiki updates only after source wording is stable.
- Mine the Miksuu original repo with a long-path-safe or sparse checkout for mission-level diffs.
- Select concrete Jerry/Miksuu dump packages before downloading large archives.
- Collect or import RPT evidence only after explicit approval for SSH/server access.

## Validation Expectations

Minimum pre-release evidence:

- `Tools/LoadoutManager` run after Chernarus edits, with Takistan regenerated.
- Static A2/OA watched-token scan for both maintained missions.
- Diff check for generated drift between Chernarus and Takistan outside intentional terrain differences.
- Exact package hash recorded for the release candidate.
- RPT matrix for both terrains covering server, HC1, HC2, start-client, and late-JIP, unless owner approves a smaller matrix.
- Wiki pages updated to match the final candidate, not an intermediate branch.
