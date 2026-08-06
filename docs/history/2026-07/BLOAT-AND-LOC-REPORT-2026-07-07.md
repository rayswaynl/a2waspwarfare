# Bloat and LOC Report — 2026-07-07

<!-- GUIDE-REV GR-2026-07-07a — docs only, no runtime/code changes in this file. -->

Snapshot of `origin/master` at commit `3c8994b` (2026-07-07 21:12 CEST). Note: the prior
`BLOAT-AND-LOC-REPORT-2026-07-05.md` measured `claude/build84-cmdcon36`, not `master` —
master is 20 commits ahead of build84-cmdcon36 as of this snapshot, so the deltas below
are directional (same ~79-PR merge day), not a clean same-branch diff.

## Total tracked LOC

| Metric | 2026-07-05 (build84-cmdcon36) | 2026-07-07 (master) | Delta |
|---|---|---|---|
| Files | 4,243 | 4,832 | +589 |
| Text LOC | 524,114 | 575,538 | +51,424 |

## LOC by major directory (2026-07-07, master)

| Directory | Files | LOC | Note |
|---|---|---|---|
| Missions_Vanilla (generated TK+ZG mirrors) | 1,808 | 247,556 | Generated, not source of truth |
| Modded_Missions (7 community maps) | 1,454 | 141,066 | |
| Missions (Chernarus source) | 887 | 126,268 | Source of truth; +112 files / +11,197 LOC vs 2026-07-05's 775/116,181 |
| docs | 302 | 34,868 | |
| Tools | 292 | 20,083 | |
| DiscordBot | 43 | 2,445 | |
| Extension | 16 | 744 | |

~68% of the tracked SQF/HPP corpus is still generated Takistan/Zargabad mirrors
(Missions_Vanilla + the mirrored share of Modded_Missions). The 126k-LOC Chernarus
mission remains the sole edit surface per the mirror-regen workflow.

## LOC by language/extension (2026-07-07, master)

| Extension | Files | LOC | Share of tracked text |
|---|---|---|---|
| .sqf | 3,678 | 432,957 | 75% |
| .hpp | 44 | 40,030 | 7% |
| .md | 293 | 36,720 | 6% |
| .sqm | 5 | 18,371 | 3% |
| .xml | 3 | 18,123 | 3% |
| .cs (Tools/LoadoutManager) | 239 | 9,342 | 2% |
| .py | 20 | 6,784 | 1% |
| .ps1 | 24 | 5,964 | 1% |
| .fsm | 15 | 2,931 | <1% |

SQF's 75% share is unchanged from the 2026-07-05 report (407k/524k then vs 433k/576k
now) — growth is proportional, not concentrated in one language.

## New-code footprint sanity checks

- **Soak stack (PR #880-885)**: +3,668 / -14 LOC total across 5 stacked PRs, 100%
  confined to `Tools/Soak/*`. Zero files touch `Missions/`, `Missions_Vanilla/`, or
  `Modded_Missions/`. Pure tooling growth, does not worsen the SQF/mirror bloat profile.
- **PR #886 (Commander Town Ledger)**: +2,343 / -1 LOC across 22 files — the one PR in
  the current open-PR set that does add to the 126k-LOC Chernarus source tree, but all
  16 new flags are append-only and default 0 (byte-identical mission at flag-off, per
  the PR's own claim).

## Shelve / watch recommendations

| Item | Recommendation | Why |
|---|---|---|
| 74 stale one-shot `docs/design/*STATUS*`/`*NOCHANGE*` analysis docs (4,666 LOC, 40% of `docs/design`) | **Shelve** — archive to `docs/design/archive/` | Zero-risk, flagged 2026-07-05, identical count today (no cleanup action taken in the 2 intervening days); pure documentation weight with no runtime consumers |
| PR #751 (3rd of 3 dice-roll perf candidates) | **Already shelved** (closed, not merged) | Dropped rather than shipped; the 2 that did ship (#749, #750/#757) still need a T3 soak A/B before further perf work builds on them — don't restart #751 until that soak reports |
| AICOMSTAT V1 telemetry family (~168 emitters across 34 files) | **Watch, do not remove yet** | Cutover step 4 (retire V1-only emitters) is correctly gated on steps 1-6 of `TELEMETRY-AND-STATS-V2-PLAN.md` completing first; premature removal would break in-flight consumers |
| `EMPTYGRP`/`GRPEMPTY` parser-prefix mismatch (`server_groupsGC.sqf:559`) | **Watch** | Box-side consumer lives outside these two repos; leaves the groupsGC dashboard gauge silently dead until traced and fixed on the consumer side |
| ASR AI version-label doc drift (`asr_ai3` vs the valid `asr_ai` line for A2 OA 1.64) | **Watch** | PR #454 explicitly deferred this to "lane 68"; still unresolved in `docs/design/OPTIONAL-CLIENT-MODS.md` and `AI-MODS-AND-PATHFINDING.md` as of today — small fix, just unclaimed |

## Stale systems flagged this pass

- **`docs/design/OPTIONAL-CLIENT-MODS.md`** — still labels the bundled build "ASR AI 3
  / asr_ai3_*", which is the Arma 3-only line; the valid A2 OA 1.64 line is Robalo's
  `asr_ai` (v1.16.2). No fix PR landed despite being flagged.
- **`WFBE_C_DASHBOARD_MSGS`** (`Init_CommonConstants.sqf:1741-1743`, consumed by
  `server_dashboard_announcer.sqf`, broadcast to every client every ~14 min) — still
  contains patch-history tip lines ("Build 89 is live...", "SCUD tech is now a two-level
  program...") that violate the owner's no-patch-history redo rule applied elsewhere
  (`Client_TipRotation.sqf`), and are now factually stale (mission briefing name is still
  "WASP Warfare Build 89" while live hotfixes have moved to rc28).
- **`mission.sqm` briefingName**: literally "WASP Warfare Build 89" while origin/master
  has moved well past that label in practice (rc28 hotfix line as of today) — a version-
  label drift, not a functional bug, but compounds the dashboard-message staleness above.
