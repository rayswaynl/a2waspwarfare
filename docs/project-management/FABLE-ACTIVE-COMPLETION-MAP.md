# FABLE Active Completion Map

Run: 2026-07-05 completion push. Control file: `FABLE_ULTRACODE_MASTER_INSTRUCTIONS_V2_2026-07-05.md` (this directory).
Agent A: Claude (Fable), Main PC session. **Status: WAVE 1 BUILT & REVIEWED** — TP-1→PR miksuu#60, TP-2→#720, TP-3→#719, TP-4→#718 (all draft, Agent-A-approved; see `FABLE-BUILD-LOG-2026-07-05.md`). Owner-question gate open (`OWNER-QUESTIONS-BEFORE-BUILD.md`); TP-5 waits on Q1.

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

## 11. HC/ASR/performance audit task map (production research-only; lab prototype present)

### Confirmed live incident — HC delegation collapse (2026-07-09/10)
The earlier "GUER/server-local crowding" hypothesis is superseded by stronger live + source evidence. During the live 1.2.0 match the dedicated server carried **85–93% of `allUnits`** while both HCs were effectively idle (`DELEGSTAT remotePct` reached 7%); server FPS sagged about 47 → 30 under load and later recovered. The processes remained up, so this is degraded-but-up and **not** a Peach+ wake condition.

Confirmed mechanisms (source paths and line numbers verified unchanged at live git `b9af9b96`):

- `Common_SendToClient.sqf:24,29`, `Common_SendToClients.sqf:15,18`, and `Common_SendToServerOptimized.sqf:15` build and `compile` a fresh SQF transport envelope for every send. This is a confirmed hot-path defect and credible bus/scheduler-pressure contributor; the fraction of the live collapse it caused still needs a controlled compile-free A/B test before being called causal in isolation.
- Town activation fans one message per group with no sender-side pacing (`Server_DelegateAITownHeadless.sqf:46-56`). The HC's max-three guard runs only after those packets have crossed the bus, and its 10 s soft timeout can admit a fourth-or-later batch (`Client_DelegateTownAI.sqf:21-30,71-72`).
- HC endpoint health is not authoritative. The picker accepts any non-null, live leader (`Server_PickLeastLoadedHC.sqf:31-40`), while registration pruning does not require owner `>2`, freshness, or unique owner across all surviving rows (`Server_HandleSpecial.sqf:1198-1226`). Duplicate owner rows are under-counted because the load tally credits only the first `_owners find` match (`Server_PickLeastLoadedHC.sqf:43-56`). `Common_SendToClient` accepts `_id > 0`, although owner 2 is the dedicated server, so a stale endpoint can be routed to a machine without the HC client handler (`Common_SendToClient.sqf:16-24`).
- The only death alert is structurally blind to this incident: `server_groupsGC.sqf:560-569` warns only when `_delegRemote == 0`. `remote` means merely "not local to the server" across all `allUnits`; it is not an HC-owned-AI census and can include human players and HC avatars. Therefore 7% can be a functional zero-HC-AI collapse without satisfying the alert.
- Lost/new groups are sticky in OA; there is no safe shipped mechanism that continuously migrates an existing AI group between HCs. A restart/reconnect can therefore leave load on the dedicated server even after the registry looks live. Exact ownership paths still require the forced-HC-bounce rig test below.

### Proving ground + cooperative scheduler v0 — **LAB ONLY / DO NOT MERGE**

`Tools/ProvingGround` now generates isolated Utes or current-map test missions, owner-aware `WASPLAB|v1` telemetry, RPT monitor/compare tools and a default-off cooperative scheduler v0. V0 runs only on the server and controls only synthetic lab group creation, path continuations and bounded Common_Send pressure. It uses four linearly scanned lane arrays, a 32-job cap, a separate heartbeat and the code's current 1/0.75/0.5/0.25 ms advisory launch budgets. It does **not** contain a timing wheel, shared snapshot service, HC-local scheduler, HC creation backpressure or any migrated production loop.

Matched build arms are:

```text
python Tools\ProvingGround\build.py scheduler-ramp --variant sched-off --scheduler-mode off --force
python Tools\ProvingGround\build.py scheduler-ramp --variant sched-shadow --scheduler-mode shadow --force
python Tools\ProvingGround\build.py scheduler-ramp --variant sched-active --scheduler-mode active --force
```

Shadow versus off measures dispatcher overhead. Active versus off also changes work timing by spreading creation and path continuations, so it is a scheduler-plus-pacing test. No gain is verified: the planning hypothesis is 0–5% median movement and 5–15% better p5/min FPS during bursty lab work, with neutral or negative results possible when engine AI dominates. The live 47→30→recovery observation is not a scheduler forecast.

All AI remains continuously materialized and fully engine-simulated. There is no simulation gating, frozen/virtualized force, external movement/combat simulation or production ownership change. Synthetic groups are deliberately server-local to stress the dedicated process; production should keep authority on the server while creating eligible combat/town groups on healthy HCs. Current lab `hcPct` uses registered valid-looking owner IDs but still has no delegation-eligibility classification. For bus-enabled recipes, validated LabPong ACK rows now add a ten-second fresh-endpoint count and returned HC `diag_fps`: `SAMPLE` exposes `hcFresh`/`hcFpsMin`, while `RESULT` records `busFreshEndpoints`/`hcFpsSamples`/`hcFpsMin`; monitor and comparer promote the result. The default `minHcFps=25` missing/stale/floor gates apply only with `busRate > 0` and `expectedHcs > 0`; no-bus recipes still require HC RPTs, and 25 is a safety floor rather than the ≥40 scale target.

The builder forces `busRate=0` for `expectedHcs=0`: the HC round-trip bus has no legal target. `hc0` remains the server-only ownership/fallback baseline for the 0/1/2-HC and bounce matrix, not bus-throughput or HC-FPS evidence.

No DLL or sidecar is included. A2 OA is x86 and cannot directly load an x64 DLL. A future, separate research PR may test an x86 extension—or an optional x86 bridge to an x64 sidecar—only for bounded pure-data advisory work with immutable messages and no engine pointers. LAA status and allocator choices are also separate memory-headroom/stability A/Bs, not promised FPS upgrades. See `Tools/ProvingGround/README.md`, `docs/design/WASP-RUNTIME-SCHEDULER.md` and `docs/testing/WASP-AI-SCALE-AND-SERVER-PERF-PLAN.md`.

Staged repair train (separate draft PRs; do not arm from documentation):

1. **Truthful health first:** emit `DELEGHEALTH|v2` every 60 s with server-AI and AI-per-owner counts, fresh/eligible HC endpoints, queue/in-flight state, and hysteretic states. Candidate thresholds after minute 5 and at least 40 eligible AI: degraded `<60%` on HCs for three samples; collapsed `<25%` for two samples or no fresh HC; clear `>75%` for three. This remains an ops/document alert, not a Peach+ page.
2. **Compile-free transport + route rejection:** replace the per-send compiled envelope with A2-safe `missionNamespace setVariable` plus the existing named public-variable operations; reject remote client owner IDs `<=2` and rate-limit `HCROUTE_DROP` telemetry. Preserve the hosted-server local path byte-for-byte in behavior.
3. **Owner-keyed fresh registry:** keep one newest row per owner with HC object/group/netId, heartbeat timestamp, FPS, local units and groups; require non-null/alive/CIV/owner `>2` and a bounded TTL (candidate 150 s) in one shared `GetFreshHCs` selector used by every delegate path. If selection fails, do not silently fall back to registry index 0.
4. **Flow-controlled, idempotent heavy dispatch:** put town/AICOM creation behind a bounded server queue (initial candidate: one send/250 ms globally, at most two accepted-but-incomplete batches per HC). Add dispatch IDs, accept/completion ACKs, receiver de-duplication and bounded retries; never blind-retry an unknown-completion batch because that can duplicate units/economy.
5. **Sticky failure policy:** no speculative OA group migration. Define bounded server fallback or safe retire/recreate/refund rules only after the editor rig proves ownership and combat/economy invariants; town AI may remain server-local until normal deactivation and then reactivate on a healthy HC.

Verification gates: lint every touched SQF with the project A2 selector and mirror mission-source changes across Chernarus/Takistan/Zargabad; then run identical 0/1/2-HC small-map scenarios through cold start, burst town activation, HC-A bounce/rejoin, HC-B bounce/rejoin and a 50 → 200 → 400 AI ramp. For stages 2–4 require zero invalid-owner sends, zero duplicate dispatch completion, bounded queue depth, truthful owner counts, both HCs accepting work after recovery, and an A/B reduction in send CPU/traffic without missing AI. Stage 5 additionally needs a long soak plus in-editor checks for group locality, waypoints, kill ownership, cleanup and refunds. **No runtime HC architecture change ships from this map alone.**

Remaining audit inputs: stuck-team terrain traps (B 1-1-K/L `PATROL_UNSTUCK` loops); `antistack_main` 500–600 ms (known, document/A-B rather than blind-edit); Zargabad error flood (TP-2 fixes); client 15–21 FPS @460 AI (VD/AI-budget tuning input); HC `-mod=@adwasp` + `-malloc` verification. Production output remains an audit/recommendation lane until each repair clears its gate; the generated lab prototype remains explicitly DO NOT MERGE/DEPLOY until its editor and dedicated 0/1/2-HC gates pass and the owner removes that status.

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
