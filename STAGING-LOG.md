# Staging Rollup Log — 2026-07-27

Branch: `staging/update-20260727`, based on `origin/master` @ `bcd35dbb47`.

## Merged (41 PRs + 1 follow-up commit)

### Phase A — docs (9, all clean)
1480, 1482, 1503 (after 1482), 1487, 1490, 1491, 1494, 1495, 1501

### Phase B — fixes (11, all clean)
1493, 1488, 1489, 1486, 1485, 1497, 1502, 1507, 1428, 1400, 1505

### Phase C — security chain, exact order (6, all clean)
1409, 1421, 1434, 1402, 1423, 1430 (supersedes #1394). Excluded 1394, 1395 per instructions (superseded by 1430/1436).

### Phase D — flag-gated (8, 2 with folded conflicts)
1407, 1398, 1393, 1392, 1492, 1498, 1499 (conflict folded), 1506 (conflict folded — see below).

### Phase E — owner-authorized inclusions (6 + 1 follow-up commit)
1496, 1411, 1397, 1396, 1500, 1504, then a follow-up commit flipping `WFBE_C_USV_FLOTILLA_ENABLE` default 1->0.

### Phase F — best-effort (1 landed, as a no-op)
1371: `git merge` reported "Already up to date" — its tip commit was already an ancestor of staging HEAD (content already pulled in transitively by an earlier merge). No new commit created for it.

## Folded conflicts

1. **PR #1499** (`Init_CommonConstants.sqf`, all 3 mirrors): both this PR's `WFBE_C_SIDE_PATROL_FRONT_BIAS` flag block and PR #1492's (already-merged) `WFBE_C_AICOM_AIR_BOMBS` flag block were appended at the same file location. No semantic interaction — kept both blocks, byte-identical across chernarus/takistan/zargabad.
2. **PR #1506** (`Client_HandlePVF.sqf`'s `_hcAllowed` array, all 3 mirrors) — the collision flagged in advance: PR #1498 (merged earlier) added the `"aicom-team-merge"` key, PR #1506 independently added `"sidepatrol-watchdog"`. Folded both keys into the single array, byte-identical across all 3 mirrors.

## Follow-up commit

`WFBE_C_USV_FLOTILLA_ENABLE` default flipped 1->0 in `Init_CommonConstants.sqf` (all 3 mirrors) after merging #1504. Verified via grep that no other definition site remained at `= 1` (only log-message strings reference `=1`, which are harmless). Commit message: "staging: default WFBE_C_USV_FLOTILLA_ENABLE 1->0 - USV flotilla stays dark until owner soak-arms (waypoint water-safety unverified in engine)".

## Skipped / Excluded

**Excluded per explicit instructions (not attempted):**
- 1394, 1395 — superseded by #1430/#1436 (Phase C exclusion)
- 1262 — owner REQUEST-CHANGES stands
- 1342, 1343 — competing duplicate implementations, skip both
- 1344, 1260, 1249, 1436, 1464 — large/divergent, not for this rollup

**Attempted, aborted on real conflict (Phase F):**
- **1399** — `git merge --abort`. 9 conflict hunks across `Common_AttackWaveActivate.sqf`, `Server_AttackWave.sqf`, `AttackWave.sqf` (all 3 mirrors) deeply overlapping with the already-merged security hardening from #1423/#1428. Requires security judgment, not a mechanical fold.
- **1401** — skipped, contingent on #1399 per instructions ("only if 1399 landed").
- **1373** — `git merge --abort`. Master already contains a superset implementation: the exact staleness-ceiling guard #1373 proposes is already integrated *and* extended with requester-binding (comments in `Server_AttackWave.sqf` explicitly document combining "[#1350/#1373]" with "[#1399]" already). Merging the stale #1373 branch would regress functionality by stripping the already-integrated `_requester` threading.
- **1278** — `git merge --abort`. Three `add/add` conflicts in `Tools/PrTestHarness/**/*.ps1` with hundreds of lines of whole-file divergence each — not trivial hunks.
- **1404** — `git merge --abort`. Deep divergence in `supplyMissionCompleted.sqf` (all 3 mirrors): both HEAD and the PR independently hardened the same economy function with different validation approaches (registry tracking vs. different guard style). Security-sensitive, requires judgment.
- **1439** — `git merge --abort`. HEAD already contains this exact fix: the `wfbe_is_guer_fob` exemption is already present in `Server_HandleEmptyVehicle.sqf`'s `_timer` calc (comment: "guer-fob-empty-exempt"). The PR's stale branch would regress the already-integrated `_reapAttempts`/remote-delete retry mechanism back to a simpler immediate-delete path.
- **1293** — `git merge --abort`. 17+ conflicted files per mirror across core AI commander logic; predates and conflicts with the already-merged `RealPlayersNear` hardening (#1488/#1493).
- **1286** — `git merge --abort`. Same pattern/root cause as #1293 (same 11 conflicted files per mirror).

## Verification

1. **`git diff origin/master --check`**: clean, no whitespace/conflict-marker issues.
2. **Conflict marker scan** (`^<<<<<<< `, `^=======$`, `^>>>>>>> `, tree-wide): zero matches. (A broad substring grep for `<<<<<<<`/`=======`/`>>>>>>>` initially flagged decorative `//===` comment banners inside `Init_CommonConstants.sqf` and pre-existing `<<<<<<<<`/`>>>>>>>>` 8-char historical-merge artifacts already present on `origin/master` itself in several `Modded_Missions/*` files — neither are real conflict markers, and the latter were never touched by this rollup. Confirmed via `git show origin/master:<path>` that they predate this branch.)
3. **CRLF preservation**: verified byte-level on all 6 manually-edited files (the 2 folds x 3 mirrors, one of which was also the flag-flip target) — zero LF-only line endings in any of them.
4. **`python -m pytest Tools/Lint -q`**: **470 passed, 10 failed.** Compared directly against a clean `origin/master` baseline worktree (no rollup changes): baseline is **433 passed, 8 failed**. The 8 baseline failures are unchanged and pre-existing — unrelated WIP tests for features not in this rollup at all (`test_aicap_midhigh_trim`, `test_cargo_airdrop_stage_a/b`, `test_handlespecial_cases`, `test_overrun_razer_reachability`, `test_territorial_hud_contract`, `test_veh_delete_probe` x2). The 2 *new* failures on staging are legitimate side effects of real bug fixes in this rollup outrunning stale test assertions already present in master (not something this rollup should silently patch):
   - `test_realplayersnear_vetoes.py` expects the literal (buggy) forward-slash compile path `"Common/Functions/Common_RealPlayersNear.sqf"` in `Init_Common.sqf`. PR #1493 correctly fixed this to a backslash path (`Common\Functions\Common_RealPlayersNear.sqf`) — forward slashes break `preprocessFileLineNumbers` inside a PBO. The test needs updating to match the fix; out of scope for this rollup to edit.
   - `test_naval_cap_pilot_fallback.py` expects the fallback CAP pilot classname to be the generic `"GUE_Soldier"`. PR #1507 correctly changed it to the specific `"GUE_Soldier_Pilot"` per its stated purpose (resolve naval GUER CAP pilot spawns to WFBE_GUERRESPILOT). Same situation — test is stale relative to the fix.
5. **LoadoutManager mirror-drift check** (`dotnet run -c RELEASE -- --check` in `Tools/LoadoutManager`): **"Takistan drift: none (mirror check passed)."** / **"Zargabad drift: none (mirror check passed)."** Dry-run only, confirmed no worktree files were touched (`git status --short` showed only this log file, untracked, both before and after).
6. **Commit count**: `git log --oneline origin/master..HEAD` = **90 commits** ahead of `origin/master` (includes all individual PR-branch commits pulled in by each merge, not just the 41 merge/follow-up commits made by this rollup).

## Caveat — unflagged hardening merged in this rollup (owner-authorized, Phase E)

Per explicit owner instruction to include as much as possible for this draft, the following Phase E PRs are **unflagged** (i.e., not gated behind a default-0 flag — they change live behavior unconditionally once this staging PR merges): **#1496** (perf/airdef), **#1411**, **#1397**, **#1396**. Review these specifically before merge.

## Warning

**Merging this staging PR will mark all 41 contained PRs (#1480, #1482, #1503, #1487, #1490, #1491, #1494, #1495, #1501, #1493, #1488, #1489, #1486, #1485, #1497, #1502, #1507, #1428, #1400, #1505, #1409, #1421, #1434, #1402, #1423, #1430, #1407, #1398, #1393, #1392, #1492, #1498, #1499, #1506, #1496, #1411, #1397, #1396, #1500, #1504, #1371) as merged on GitHub.**
