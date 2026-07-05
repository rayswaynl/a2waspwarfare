# FABLE Active Completion Map

Run: 2026-07-05 completion push. Control file: `FABLE_ULTRACODE_MASTER_INSTRUCTIONS_V2_2026-07-05.md` (this directory).
Agent A: Claude (Fable), Main PC session. **Status: DISCOVERY COMPLETE — owner-question gate open** (`OWNER-QUESTIONS-BEFORE-BUILD.md`). Ungated packets (TP-1…TP-4) are cleared for Agent B now; TP-5 waits on Q1.

## Working State (Agent A)
- Worktree `C:\Users\Steff\a2wasp-fable-push`, branch `claude/fable-completion-push`, base `claude/build84-cmdcon36`, PR #717.
- Discovery workflow `wf_a00082ab-7ef` complete: 14 agents, 505 tool calls, ~1.0 M tokens. Artifacts: `PR-TRIAGE-2026-07-05.md`, `RPT-EVIDENCE-2026-07-05.md`, `TELEMETRY-AND-STATS-V2-PLAN.md`, `BLOAT-AND-LOC-REPORT-2026-07-05.md`, `OWNER-QUESTIONS-BEFORE-BUILD.md`.

## Standing decisions this run inherits (verified in-session)
1. **V2 one-shot cutover**: V1 commander code + telemetry mapped → shelved → removed (`docs/design/v2/AICOM-V2-CUTOVER-AND-RECONCILIATION.md`, PR #716). Unified grammar = `AICOM2|v1|` growing v3 features.
2. **No omniscient AI base rush** (owner 2026-07-05): town-first, road-following; base/HQ pressure only via organic ~3 km proximity + periodic dice-roll; air faster but not psychic; victory via real overrun.
3. **GUER Director (#715) approved incl. relief waves, post-cutover.** D2 resolved, D1 open. Not bundled into cutover.
4. Telemetry cleaner-not-louder; public stats never leak live tactical intel.
5. Mission rules: A2 OA 1.64 only, Chernarus source + LoadoutManager mirrors, draft PRs, default-off flags, no GUER volume nerf, no HC architecture changes without approval.

## 1. PR triage summary
**a2waspwarfare (125 open):** 49 MERGE-CANDIDATE · 23 STACKED (PVF-hardening batch on build84) · 19 DOCS-ONLY-REFERENCE · 10 NEEDS-REBASE · 8 IMPLEMENT-IN-ONE-SHOT (V1-commander fixes → fold into V2 build) · 6 SHELVE · 5 OWNER-DECISION (#269, #515, #614, #703, #713) · 2 SUPERSEDED (#129, #553) · 2 DUPLICATE (#694→#697, #700-inventory→#707) · 1 DISCARD (#261, owner-rejected). Full table: `PR-TRIAGE-2026-07-05.md`.
**miksuu (4 open):** #49 merge-ready · #56 brand tokens NEEDS-REBASE (**foundation for the visual overhaul — land early**) · #51 gated on `.bikey` whitelist ops · #57 guild-architect ready, gated on prod-guild decisions. ⚠️ **main CI RED since ≥07-04** on two pre-existing failures (web: leaderboard/wasp-command-hero test fixtures missing `claimed`/`server` fields; bot: `test_battlemetrics_offline_or_removed` assertion) — fix is TP-1.

## 2. AICOM V2 reconciliation summary
Live lane (`AICOM2_Snapshot/Allocate`, M0–M5) is the base; spec pack re-anchors onto it; one grammar ships (cutover brief). RPT evidence confirms AICOM2 telemetry healthy on the live box. Pre-soak gaps found: `AICOM2|` has **zero tool consumers**; `Score-AicomRounds.ps1`/`aicom-watch.ps1` **don't exist yet**; GRPBUDGET/SRVPERF emitters live inside `AI_Commander.sqf` and must relocate before shelve (TP-4).

## 3. Recommendation on PR #713 — **NEEDS-REWORK (re-scope, don't shelve)**
Opus high-effort review confirmed all six owner-intent conflicts: HQ position is global server knowledge from tick 1 (`WFBE_SNAP_ENHQPOS` via `GetSideHQ`, no perception/proximity/randomness gate); COMMIT redirects **every** offensive team map-wide and overwrites `wfbe_aicom_targets = [_enHQ]`. Salvage ~60–70%: latch state machine + ARM_TICKS hysteresis + MIN_COMMIT lockout, shadow-mode telemetry, per-team stamp loop, snapshot reuse. Replace: ARM trigger → proximity (SENSE_RADIUS 3000 m CH/TK / 2000 m ZG, per-map) + dice roll (35%/~4 min) with dominance as additional gate; COMMIT scope → nearby teams only; delete global targets overwrite; demote MAX_ENTOWNS to secondary safety. ~30 lines changed + 6 constants/map. The anti-stall problem it solves is real (ZG 116→1 evidence) — the lane is right, the mechanism was wrong. **Gated on Q1.**

## 4. Recommendation on PR #715 — approved, post-cutover (unchanged)
Docs merge-ready; D1 (retake dial) open; live evidence baseline: GUER already fields 33–44 groups in live play.

## 5. Telemetry cleanup plan
See `TELEMETRY-AND-STATS-V2-PLAN.md`: ~40 families censused; AICOMSTAT (168 emitters) PORT-then-retire; AICOM2 = unified base; KEEP set (WASPSTAT/WASPSCALE wire-stable, groupsGC, GUER systems, client diagnostics); defects: EMPTYGRP/GRPEMPTY consumer mismatch (dashboard gauge dead), missing soak-gate scripts.

## 6. Stats V2 / after-match integration plan
Plan §§3–7: `MATCH|v1|` match-facts family → box ingest → Postgres → after-match builder → test Discord (bot consumes DB/outbox, never raw RPT) → public `/stats` + `/admin/telemetry`. Public/admin matrix proposed (Q3).

## 7. Website overhaul task map (miksuus-warfare)
Order: (a) TP-1 CI green; (b) land #56 brand tokens (rebase); (c) motion kit per `miksuus_warfare_claude_visual_motion_brief.txt` — asset inventory done (mark.svg chevron, hind/tank silhouettes + 4 pitch SVGs, hero-poster, role cards; brand tokens verified `--mw-*` in brand/tokens.css: gunmetal #14171b, steel #2a2f36, olive #5c6536, bone #e7e3d6, orange #d9763c, chalk #f2efe8, west #5d82a3, east #a8503f) → `brand/assets-inventory.md` + motion-tokens + AmbientOpsLayer/BrandWatermark/LiveValue/TownControlBar/TheatreMapPanel/WarLogEvent/AfterActionReportCard/DiscordEmbedPreview + brand-lab page; (d) homepage second-block reframe (PvP + living world, 40+ towns / 32 players / 500+ AI / 2–8 h) + graphic theaters section + optional-mods card; (e) `/stats` Command Center rebuild w/ public/admin split (Q2/Q3); (f) guides refresh (in-game Help = source of truth; drop map-notes duplicate). Dedicated `og-wasp.jpg` quick win.

## 8. Discord roles/guild task map
Foundation exists: #57 guild-architect (tested on test guild) + bot `rolepicker` cog. Order: fix CI → owner enables Community feature + boost-2 icons (manual) → interest/notification/dev roles via rolepicker → stats-based roles reading Stats V2 DB (thresholds owner-set later; no pay-to-win, opt-out respected) → category-collapse via role gates. BOT.md is stale (says 14 cogs, loads 17; chat_relay/live_status/link_steam undocumented) — docs fix rides along.

## 9. Game UI/HUD task map (all recon'd to exact files)
| Item | Files | Status |
|---|---|---|
| Cancel Last alignment | `Rsc/Dialogs.hpp` IDC 12043/12024 | TP-3 |
| RHUD queue align + overflow "(+N more)" | `Rsc/Titles.hpp` IDC 1374/1368-71, `Client_UpdateRHUD.sqf` | TP-3 |
| Earplugs removal | `Dialogs.hpp` IDC 11022 + `GUI_Menu.sqf` MenuAction 22 | TP-3 |
| TAGS toggle | works (traced `WFBE_NameTagsEnabled` → Init_Client loop); Q: default ON? persist? | TP-3 (persist to profile) |
| Factory upgrade icons | `Labels_Upgrades.sqf` WFBE_C_UPGRADES_IMAGES — 6/24 filled; existing PAAs cover most gaps | TP-3 |
| Team menu repurpose | VD/TG redundant w/ Settings v2 → remaining = coherent squad-mgmt set; proposal doc next round | design lane |
| HQ marker direction | facing-mode already fixed; destination-mode = new feature | Q6 |
| Tips redo | `Client_TipRotation.sqf` — 50 hardcoded tips, flag-gated, 15-min cadence | content packet next round |

## 10. AI commander behavior task map
TP-5 (#713 re-scope, gated Q1) → then, from the master file's owner wishes onto V2 lanes: softest-lane push (416/420), composition breadth incl. no-ATV rule (417 + D4), infinite AI fuel + stuck-driven rearm/repair (421 + micro-extensions pacing/fire-discipline/economy-of-force/air-insertion — approved 07-04), transport depth (Code Archaeologist first), aircraft spawn polish (already airfield-aware; add isFlatEmpty fallback), strategic-spawn road-snap for players (proven AI path exists — copy + flag `WFBE_C_PLAYER_SPAWN_ON_ROADS`), base placement safety (AICOMPLACE evidence exists), no deception systems.

## 11. HC/ASR/performance audit task map (research-only)
Evidence to chase: HC delegation collapse in live 07-05 (remotePct 92–95% → 21–37%) — hypothesis: GUER/server-local group crowding; stuck-team terrain traps (B 1-1-K/L PATROL_UNSTUCK loops); `antistack_main` 500–600 ms (known, document); Zargabad error flood (TP-2 fixes); client 15–21 FPS @460 AI (VD/AI-budget tuning input). Plus pending from memory: HC `-mod=@adwasp` + `-malloc` verification. Output = audit/recommendation PR, **no runtime changes**.

## 12. Owner questions
`OWNER-QUESTIONS-BEFORE-BUILD.md` — Q1 (#713 params) gates TP-5; Q2 (naming) gates routing work; Q4 (An-2) gates one edit; Q7 (PR closures/merges) gates queue hygiene. Defaults documented; non-questions building now.

## 13. Agent B task packets

### Task Packet 1 — Miksuu main CI red → green
Repo: `rayswaynl/miksuus-website-discord-bot` · Base: `main` · **UNGATED**
Objective: both CI failures fixed: (a) web typecheck — `tests/leaderboard.test.ts` fixtures missing required `claimed` on StatRow/LeaderRow and `tests/wasp-command-hero.test.tsx` missing `server` prop (Stats V2 schema drift); (b) bot — `tests/test_status_parse.py::test_battlemetrics_offline_or_removed` assertion vs current parser.
Owner intent: CI red means stop — nothing web-side ships until green. Fix tests to match shipped schema (the schema is correct; the fixtures are stale). Allowed: the named test files + minimal fixture helpers. Forbidden: runtime code changes to "make tests pass" — if the parser is actually wrong, escalate. Checks: `npm run lint/test/typecheck:tests/build` in web/, `pytest -q` in bot/. Acceptance: CI green on the PR. Rollback: revert commit.

### Task Packet 2 — Zargabad looping script error (60,791 hits/match)
Repo: `a2waspwarfare` · Base: `claude/build84-cmdcon36` · **UNGATED**
Objective: locate and fix the looping error from RPT evidence: undefined `_playerskill`/`_teamskill`/`_totalskillopfor`/`_base` in a sleep-loop touching `wfbe_camp_bunker` (camp/bunker score-monitor). Research first: grep those symbols in Chernarus source; reproduce the expression fragments from `C:\WASP\rpt-archive\arma2oaserver-deploy44q-20260704-1011.RPT` (re-read as text). Also fold in the recurring kill-EH `[_shooter,_k]` nil-guard (1–11/session, every session).
Rules: minimal guards/initialization, no behavior redesign; A2-safe lint; ZG likely inherits from generated mirror — **fix in Chernarus source, mirror via LoadoutManager, verify the guilty file diffs in all three**. Checks: lint gates, bracket delta 0, grep-proof the symbols are initialized on all paths. Acceptance: draft PR with evidence block (RPT lines → file:line → fix). Escalate if the loop turns out to be inside V1 commander code scheduled for cutover (then it becomes an IMPLEMENT-IN-ONE-SHOT note instead).

### Task Packet 3 — Mission UI batch 1 (playtest items, exact files known)
Repo: `a2waspwarfare` · Base: `claude/build84-cmdcon36` · **UNGATED**
Objective, per `uiRecon` (completion map §9): (1) Cancel-Last alignment — Dialogs.hpp IDC 12024→ST_LEFT pairing per fix sketch; (2) RHUD BuildQueue width to label+value span + "(+N more)" overflow suffix in Client_UpdateRHUD.sqf; (3) remove earplugs button + MenuAction-22 block; (4) TAGS toggle: persist `WFBE_NameTagsEnabled` to profileNamespace + restore on spawn; (5) fill blank `WFBE_C_UPGRADES_IMAGES` entries from existing PAAs (assignments in recon; verify each PAA exists on disk before referencing).
Rules: cosmetic scope only, no new flags needed except none; re-read every file as text before editing (pxpipe builder rule); Titles.hpp edits are medium-risk (always-on RHUD) — verify control count assumptions in Client_UpdateRHUD.sqf (`count _controls` guard). Checks: lint, bracket delta 0, mirrors via LoadoutManager + template restore, boot-smoke if available. Acceptance: draft PR, one commit per item, screenshots optional post-deploy. Escalate if GUI_Menu_Team index-based logic breaks on control removal (that item is NOT in this packet — team menu is design-lane).

### Task Packet 4 — Telemetry host relocation (cutover prerequisite)
Repo: `a2waspwarfare` · Base: `claude/build84-cmdcon36` · **UNGATED**
Objective: move `GRPBUDGET` (3 emitters) and `SRVPERF` (1 emitter) emission out of `Server/AI/Commander/AI_Commander.sqf` into `Server/FSM/server_groupsGC.sqf` (or a minimal standalone loop) with **byte-identical line format and cadence** (GRPBUDGET per-side 300 s + WARN/RECOVER conditionals; SRVPERF 300 s).
Rules: telemetry-only PR; no removal of the old emitters until the new host is verified emitting (transition window may double-emit behind a flag `WFBE_C_TELEM_HOST_V2` default 0 — flag-off = current behavior). Checks: lint, mirrors, local micro-soak grep: identical line shape from new host. Acceptance: draft PR + a MIGRATION-MAP note (this is cutover-brief telemetry-consumer work item 1). Escalate if cadence coupling to `_ltStat` makes extraction non-trivial — report options instead of hacking.

### Task Packet 5 — #713 re-scope: organic base sensing ⛔ GATED ON Q1
Repo: `a2waspwarfare` · Base: PR #713 branch (`fable/aicom-v2-l1`) · Effort: ULTRA
Objective: implement the re-scope in completion map §3 with owner's Q1 answers (radius/chance/cadence/LOS/action). Keep: latch machine, hysteresis, MIN_COMMIT, shadow telemetry (`AICOM2|v1|DECAP` grows fields `sense=1|roll=…|inRange=N`), stamp loop + garrison/hold exclusions. Replace trigger + scope per proposal; add per-map constants (`WFBE_C_AICOM2_DECAP_SENSE_RADIUS/INTERVAL/CHANCE`) in Init_CommonConstants map blocks; delete global targets overwrite; demote MAX_ENTOWNS to secondary (≈5).
Rules: flag stays default-0 shadow; **no enable**; A2-safe (no A3 helpers); deterministic tests where possible (T1-style harness fixtures for the latch transitions). Checks: lint (A3CMD/GROUPGETVAR/BRACKET/NSSETVAR3 = 0 all maps), bracket delta 0, mirrors + template restore, flag-off boot-smoke: MISSINIT + DECAP telemetry present, 0 filtered errors. Acceptance: updated PR #713 (or stacked PR) whose body maps each owner-intent conflict → its resolution. Escalate on: any need to touch Common_RunCommanderTeam driver semantics (that's the next increment), or if the latch can't be made proximity-aware without new per-tick position scans (perf).

## Verified-source log (pxpipe policy)
- PR data: `gh pr view/list`, both repos, this session. RPT: direct text reads on livehost + Main PC paths listed in RPT-EVIDENCE. Telemetry census: grep over `C:\Users\Steff\a2wasp-fable-push` Chernarus source + Tools/. UI/spawn recon: files read in full, listed per item (workflow transcript). Miksuu: git fetch + origin/main reads; brand hexes read from `brand/tokens.css`. LOC: `git ls-files` + line counts, both repos. #713: `gh pr diff 713` + snapshot/allocator source on `fable/aicom-v2-l1`.
