# Fable Active Completion Map — 2026-07-07

<!-- GUIDE-REV GR-2026-07-07a — docs only, no runtime/code changes in this file. -->

Survey of every V2-pack wish tracked as of 2026-07-07, evidence-grounded against
`origin/master`, `claude/build84-cmdcon36`, and the sibling web/bot/deck repos. Status
values: **BUILT** (shipped and evidenced), **PARTIAL** (some of the wish exists, a
gap remains), **MISSING** (no code/asset found). `ownerBlocked` marks items where the
remaining gap is a decision, not code.

## Summary

| Status | Count | Share |
|---|---|---|
| BUILT | 27 | 52% |
| PARTIAL | 19 | 37% |
| MISSING | 6 | 12% |
| **Total surveyed wishes** | **52** | |

By cluster (BUILT / PARTIAL / MISSING):

| Cluster | BUILT | PARTIAL | MISSING | Items |
|---|---|---|---|---|
| aicom-behavior | 2 | 2 | 1 | 5 |
| ai-logistics | 5 | 1 | 0 | 6 |
| mission-ui | 5 | 2 | 0 | 7 |
| spawns-placement | 1 | 1 | 0 | 2 |
| telemetry-tips | 1 | 2 | 0 | 3 |
| website | 4 | 1 | 1 | 6 |
| discord | 3 | 1 | 0 | 4 |
| infra-hc-asr | 2 | 3 | 3 | 8 |
| control-bloat | 4 | 6 | 1 | 11 |

## Top safe-to-build-now items

Ranked by leverage; all are `buildClass: safe-code-now` and **not** owner-blocked —
each extends an already-approved/shipped pattern, so no new design decision is needed
before implementation:

1. **No ATVs/bikes in AI compositions** (`aicom-behavior`) — flag `WFBE_C_AICOM_NO_BIKES`
   default 1, mirrors the existing StaticWeapon strip in `AI_Commander_Teams.sqf`. S effort.
2. **Player construction slope/tree/road gates** (`spawns-placement`) — port the proven
   `AI_Commander_Base.sqf` TP-19 idiom (`isFlatEmpty`/`nearRoads`/tree clearance + nudge)
   into `Server_ConstructPosition.sqf`/`RequestDefense.sqf`/`RequestStructure.sqf` and the
   client CoIn ghost. M effort, 3 files x 3 map mirrors.
3. **Aircraft spawn safety-scan port to AI path** (`ai-logistics`) — port PR #769's
   pre-create `isFlatEmpty` candidate scan (player-side only today) into
   `AI_Commander_Teams.sqf`'s AI-founding spawn resolver. M effort.
4. **Softest-lane push after town loss** (`aicom-behavior`) — bounded additive
   `_softBonus` to neutral/GUER-capturable town scores for 2-3 ticks post-loss, layered
   onto `AI_Commander_Allocate.sqf`'s existing scorer. M effort.
5. **Dashboard-announcer residual patch-history tips** (`telemetry-tips`) — trim
   `WFBE_C_DASHBOARD_MSGS` in `Init_CommonConstants.sqf` to match the already-shipped
   `Client_TipRotation.sqf` evergreen/no-patch-history style. S effort.
6. **Archive 74 stale STATUS/NOCHANGE docs** (`control-bloat`) — zero-risk move to
   `docs/design/archive/`, flagged since 2026-07-05, still untouched (4,666 LOC, 40% of
   `docs/design`). S effort.

## Cluster: aicom-behavior

| Wish | Status | Evidence | buildClass | Effort | ownerBlocked |
|---|---|---|---|---|---|
| Town-first capture doctrine (camps before town-center/depot) | BUILT | `Common_RunCommanderTeam.sqf:1907-2019`, gated `WFBE_C_AICOM_ASSAULT_HOLD` | already-done | S | No |
| Organic base-sensing (#713 re-scope: ~3km proximity + dice roll, not omniscient) | BUILT | `AI_Commander_Decapitate.sqf` + `Init_CommonConstants.sqf:749-752` (`WFBE_C_AICOM2_DECAP_SENSE_RADIUS`/`_INTERVAL`/`_CHANCE`); `WFBE_C_AICOM2_DECAP_ENABLE` flipped 1 (live) in d21c610bf | already-done | M | No |
| Softest-lane push after town loss | PARTIAL | Anti-dogpile repick penalty exists (`AI_Commander_Allocate.sqf:148-185`); no loss-triggered `_softBonus` found | safe-code-now | M | No |
| Air-vs-ground response split (air more flexible/organic, not omniscient) | PARTIAL | Only incidental air/ground exclusion in DECAP sensing; "near enemy base" for air undefined; GUER-only air-response system (`Server_GuerAirDef.sqf`) doesn't cover main sides | research-first | L | Yes |
| Balanced composition — no ATVs/bikes | MISSING | Spec fully written (`AICOM-V2-UNIT-MICRO-LAYER-SPEC.md` WO-5, flag `WFBE_C_AICOM_NO_BIKES`); zero code hits | safe-code-now | S | No |

## Cluster: ai-logistics

| Wish | Status | Evidence | buildClass | Effort | ownerBlocked |
|---|---|---|---|---|---|
| Infinite fuel for AI commander units | BUILT | `Common_RunCommanderTeam.sqf:880-889`, `WFBE_C_AICOM_AUTOFUEL` default 1 | already-done | S | No |
| Stuck/damage-driven repair-rearm | BUILT | `Common_AICOMServiceTick.sqf:101-157` + PR #731 `WFBE_C_AICOM_STUCK_REPAIR` default 1 | already-done | S | No |
| Driver-killed replacement + smoke + continue | BUILT | `Common_RunCommanderTeam.sqf:1004-1017` (crew swap-in), `:1490-1527` (smoke) | already-done | S | No |
| Dismount-repair-tire feasibility (research) | BUILT | `AICOM-V2-UNIT-MICRO-LAYER-SPEC.md` §3/§9 — verdict: not achievable in vanilla A2 OA without a repair truck; full-hull `setDamage 0` confirmed sufficient | already-done | S | No |
| Helicopters/planes spawn at owned AF or safe open space | PARTIAL | Position logic BUILT (`AI_Commander_Teams.sqf:1157-1213`); PR #769's pre-create slope/clearance safety scan exists only in the **player** buy path, not ported to AI founding | safe-code-now | M | No |
| Sea/air scenario: AN-2+Mi-24 pair -> 3x Mi-24 in one group | BUILT | PR #729 merged, `WFBE_C_NAVAL_CAP_THREE_HINDS` default 1 (`Init_NavalHVT.sqf`); **caveat**: later PR #822's `WFBE_C_NAVAL_CAP_L39` also defaults 1 and takes precedence, so live CAP is currently 2x L39 jets, not 3x Mi-24 | already-done | S | Yes (composition precedence is a 1-flag owner call) |

## Cluster: mission-ui

| Wish | Status | Evidence | buildClass | Effort | ownerBlocked |
|---|---|---|---|---|---|
| "Cancel Last" text/button alignment near Factory Queue | BUILT | PR #719, `Dialogs.hpp:2319-2334` | already-done | S | No |
| RHUD factory-queue alignment + overflow + 2-upgrade cap | BUILT | PR #719 + PR #825 calibration, `Titles.hpp:533-542`, `Client_UpdateRHUD.sqf:200` | already-done | S | No |
| Team menu clean-slate repurpose (owner asked for proposal only) | BUILT (spec) | `TEAM-MENU-PROPOSAL-2026-07-06.md`, Option A "Coordination Strip" recommended | spec-doc | S | Yes (building Option A is the follow-on) |
| SCUD/Scout drivable-on-Chernarus + Tactical Center integration | PARTIAL | TEL is auto-spawn/non-drivable and already Tactical-Center-integrated (BUILT half); buyable/drivable TK-hull SCUD confirmed `worldName=="Takistan"`-gated in 6 files (MISSING half); no "Scout" vehicle exists in source — asset name genuinely ambiguous | research-first | M | Yes |
| Factory upgrades menu icon consistency | PARTIAL | PR #719 filled 12/18 blanks; 6 of 24 `WFBE_C_UPGRADES_IMAGES` entries still blank, no clean asset fit found | owner-decision | S | Yes |
| Remove earplugs button; verify name-tags toggle works | BUILT | PR #719 removed `CA_EAR_Button`; TAGS wired `GUI_Menu.sqf:355-360`; unrelated WF-menu parse-kill (A3-only `ctrlSetTooltip`) hotfixed RC28 (3c8994bcf, today) | already-done | S | No |
| HQ team map markers point to destination, not facing | BUILT | PR #730, `updateteamsmarkers.sqf`; flag `WFBE_C_TEAMMARKER_DEST_DIR` flipped default 1 in d21c610bf (live) | already-done | S | No |

## Cluster: spawns-placement

| Wish | Status | Evidence | buildClass | Effort | ownerBlocked |
|---|---|---|---|---|---|
| Strategic-factory player spawns snap to road, mirroring AI path | BUILT | PR #723, `Server_BuyUnit.sqf` player branch, `WFBE_C_PLAYER_SPAWN_ON_ROADS` default 1 (all 3 map mirrors) | already-done | S | No |
| Factory/base construction must not place on roads/in trees; nudge instead of block/float | PARTIAL | AI side BUILT (PR #733, `AI_Commander_Base.sqf:223-465`, slope/tree/road gates + radial nudge); player CoIn ghost has slope-only gate, no tree/road check, no nudge; `Server_ConstructPosition.sqf`/`RequestDefense.sqf`/`RequestStructure.sqf` (WDDM "Strategic" path) have zero terrain validation and no server-side re-check | safe-code-now | M | No |

## Cluster: telemetry-tips

| Wish | Status | Evidence | buildClass | Effort | ownerBlocked |
|---|---|---|---|---|---|
| Full RPT-emitter classification + `TELEMETRY-AND-STATS-V2-PLAN.md` | BUILT | Doc + `MATCH\|v1\|` emitters + `Score-AicomRounds.ps1`/`aicom-watch.ps1`/`analyze_soak.py` + website ingestion routes/admin dashboard all present and consistent | already-done | S | No |
| Remove noisy/unconsumed V1 telemetry (168 AICOMSTAT emitters, EMPTYGRP/GRPEMPTY mismatch) | PARTIAL | Cutover step 4 correctly not yet run (gated on steps 1-6 per plan); 34 files still emit `AICOMSTAT\|`; box-side consumer for the GRPEMPTY rename unverifiable from these repos | research-first | M | No |
| In-game tips redo — useful-only, veteran-aware, no patch-history | PARTIAL | `Client_TipRotation.sqf` is a genuine 50-tip ground-up redo matching the brief; residual `WFBE_C_DASHBOARD_MSGS` pool (`server_dashboard_announcer.sqf`) still has patch-history lines ("Build 89 is live...") the redo missed, now also stale vs rc28 | safe-code-now | S | No |

## Cluster: website

| Wish | Status | Evidence | buildClass | Effort | ownerBlocked |
|---|---|---|---|---|---|
| Homepage 2nd-block reframe (PvP + living AI world) | BUILT | PR #62 merged, `page.tsx` section 02 eyebrow/header rewritten | already-done | S | No |
| Homepage scale facts (40+ towns / 32 players / AI count / round length) | PARTIAL | Towns/players/round-length match; AI count on site is "400+" (Q10-approved) vs spec text's "500+" — unclear if spec is stale or a newer decision | owner-decision | S | Yes |
| Two-theatres (Chernarus/Takistan) section made more graphic | MISSING | Section is plain bordered text, no map art exists anywhere in the web repo | research-first | M | No |
| Server-section link to optional-mods guide | BUILT | PR #51, `servers-howto.mdx:9` links `/guides/mods-and-modpack` | already-done | S | No |
| Stats/Command Center full remake (`/stats` canonical, public/admin split, dataviz) | BUILT | `/wasp` now redirects to `/stats`; `StatsConsole` with `isLiveAdmin` gating, ISR + polling; PR #63, live per news post 2026-07-07 | already-done | L | No |
| Guides updated to current live V2 features | BUILT | PR #74 merged, 6 guides + new `squad-ai-behaviors.mdx`; PR's own "needs owner input" flags 4 small residual gaps (GUER Director A-Life, FPV drone, kill-tier thresholds, ZG note) | already-done | M | No |

## Cluster: discord

| Wish | Status | Evidence | buildClass | Effort | ownerBlocked |
|---|---|---|---|---|---|
| Interest/notification/dev self-assign role panels | BUILT | `rolepicker.py` cog, PR #73 finalized Tier 1; creating the actual Discord roles/panels is a manual owner checklist step | already-done | S | Yes (ops step) |
| Stats-based roles (playtime/captures/veteran), no pay-to-win, opt-out respected | BUILT | `stats_roles.py` + `thresholds.py` + migration 0021, purely stat-derived, opt-out checked every sweep; owner still needs to run the migration + set real thresholds after 2-3 weeks of data | already-done | S | Yes (ops step) |
| Dedicated roles-channel | PARTIAL | No code enforces a `#roles` channel; panels take an arbitrary channel param — pure Discord server-settings step | owner-decision | S | Yes (ops step) |
| Collapsible category depth (reduce clutter) | BUILT | `category_visibility.py` cog, `/visibility hide\|show\|list`, works immediately post-deploy | already-done | S | No |

## Cluster: infra-hc-asr

| Wish | Status | Evidence | buildClass | Effort | ownerBlocked |
|---|---|---|---|---|---|
| Verify HC launch line actually loads ASR AI mod (Action 0 blocker) | MISSING | `hc_launch.cmd` is off-repo/live-box-only; never verified; highest-value single fact to establish | research-first | S | No |
| Reconcile ASR AI version label (asr_ai vs asr_ai3) + audit per-unit skill tuning | MISSING | Docs still say "ASR AI 3" (A3-only line, wrong for A2 OA 1.64); PR #454 explicitly deferred this to "lane 68", no follow-up found; live userconfig not in repo | research-first | S | No |
| ASR-AI fired-handler null-shooter race spamming RPT | BUILT | PR #798 merged, `Common_AsrFiredGuard.sqf` post-sleep re-check on all 3 maps; runtime RPT confirmation still open per PR body | already-done | S | No |
| HC delegation routing + AICOM2/DECAP HC-locality correctness | PARTIAL | `Server_PickLeastLoadedHC.sqf` + PR #794 allowlist fix both live; no end-to-end audit of DECAP press-order surviving a delegation hop across the 2-HC split | research-first | M | No |
| Aircraft/heli terrain guard ported to HC | BUILT | PR #454, `Init_HC.sqf:245-251` starts `Common_AICOM_HeliTerrainGuard.sqf` from the HC too | already-done | S | No |
| groupsGC / server-loop performance pack | PARTIAL | 2 of 3 dice-roll perf candidates merged (#749, #750/#757); #751 (3rd) closed, not shipped; shipped 2 still need T3 soak A/B | research-first | M | Yes |
| Reconcile mission `setSkill` layering vs ASR AI's `CfgAISkill` (double-tuning risk) | MISSING | 4+ mission call sites set the same sub-skills ASR AI randomizes independently; no reconciliation doc/code found | research-first | S | No |
| AI mod trial (SLX aircraft steering) | PARTIAL | Runbook merged (PR #160); trial itself (install + soak) not run — correctly owner-gated runtime change | owner-decision | S | Yes |

## Cluster: control-bloat

| Wish | Status | Evidence | buildClass | Effort | ownerBlocked |
|---|---|---|---|---|---|
| PR #880 soak-ledger data spine | PARTIAL (merge-candidate) | MERGEABLE, base=`claude/build84-cmdcon36`, +871/-0, only pre-existing docs-sync CI failure unrelated to diff | already-done | S | No |
| PR #882 scenario catalog + Run-Scenario driver | PARTIAL (merge-candidate, stacked on #880) | MERGEABLE, CLEAN, +691/-0 | already-done | S | No |
| PR #883 dependency-free SVG chart report | PARTIAL (merge-candidate, stacked on #882) | MERGEABLE, CLEAN, +509/-2 | already-done | S | No |
| PR #884 experiment engine core | PARTIAL (merge-candidate, stacked on #883) | MERGEABLE, CLEAN, +819/-6; MDE thresholds self-described as owner-sign-off-pending | owner-decision | M | Yes |
| PR #885 autopilot loop | PARTIAL (merge-candidate, stacked on #884) | MERGEABLE, CLEAN, +778/-6; surface-only by design, no auto-apply | already-done | S | No |
| PR #886 Commander Town Ledger (CTL) | PARTIAL (merge-candidate) | MERGEABLE, +2343/-1 across 22 files, all 16 flags append-only and default 0 | already-done | M | No |
| Total tracked LOC, `origin/master` | BUILT | 4,832 files / 575,538 LOC (measured 2026-07-07) | already-done | S | No |
| LOC by major directory | BUILT | `Missions/` (Chernarus source) 887 files/126,268 LOC, up from 775/116,181 two days prior (+112 files/+11,197 LOC) | already-done | S | No |
| SQF mission LOC by extension | BUILT | `.sqf` 3,678 files/432,957 LOC = 75% of tracked text LOC, unchanged proportion vs 2026-07-05 | already-done | S | No |
| Stale one-shot STATUS/NOCHANGE docs (bloat candidate) | MISSING | 74 files/4,666 LOC, identical count to the 2026-07-05 report — flagged, not archived, still open | safe-code-now | S | No |
| Soak-stack (#880-885) net LOC footprint sanity check | BUILT | +3,668/-14 total, 100% confined to `Tools/Soak/*`, zero mission-tree/mirror growth | already-done | S | No |
