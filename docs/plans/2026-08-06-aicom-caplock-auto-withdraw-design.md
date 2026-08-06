# Capture-Locked Automatic Withdrawal Guard Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prevent the server's automatic understrength withdrawal evaluator from overwriting an active capture-drain order while preserving explicit, combat-contextual rally requests.

**Architecture:** `WFBE_CO_FNC_CapLock` remains the single authority for whether a team is protected. The automatic `_gwAlive < _gwMinAlive` trigger in `AI_Commander_Strategy.sqf` gains one lazy negative CapLock guard; the earlier `_gwWant` path remains unchanged so the HC depot-breakoff producer and the default-off loss-retreat latch can still request a rally deliberately. Chernarus stays the source and LoadoutManager generates Takistan and Zargabad mirrors.

**Tech Stack:** Arma 2 OA SQF, Python/pytest source-contract tests, .NET LoadoutManager, git/GitHub draft stacked PR.

---

## Design choice

Recommended: gate only the automatic understrength branch. This directly covers the observed `want=false` rally and retains the existing contextual escape path, where the HC sees live resistance, raises `wfbe_aicom_wantrally`, and clears the capture lock as it aborts the depot hold.

Rejected alternatives:

- Gate the entire withdrawal evaluator: this would also suppress explicit `wantrally` safety requests and could strand a genuinely out-fought remnant.
- Clear CapLock before every automatic rally: this would formalize the observed capture interruption instead of enforcing the documented “immune to new orders” contract.

## Task 1: Add the regression contract

**Files:**
- Create: `Tools/Lint/test_aicom_capture_lock_withdrawal.py`
- Inspect: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Strategy.sqf:956-962`

1. Add a three-terrain source-contract test asserting that the automatic understrength condition includes `!([_gwTeam] Call WFBE_CO_FNC_CapLock)`.
2. Assert separately that `if (_gwWant) then {_gwTrigger = true};` remains before that automatic branch.
3. Run `python -m pytest Tools/Lint/test_aicom_capture_lock_withdrawal.py -q`.
4. Expected RED: all terrain cases fail because the CapLock guard is absent.

## Task 2: Implement the minimal guard

**Files:**
- Modify: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Strategy.sqf:956-962`
- Generated mirrors: the corresponding Takistan and Zargabad files.

1. Add one lazy CapLock predicate to the automatic understrength trigger only.
2. Run LoadoutManager with `A2WASP_SKIP_ZIP=1`.
3. Restore TK/ZG `version.sqf.template` from the stacked base when needed.
4. Re-run the new test and PR #2244's rally-allocation test; expected GREEN.

## Task 3: Verify and publish the draft stack

1. Run the repository's selected SQF lint gate, bracket-delta checks, mirror hashes, `git diff --check`, and focused pytest files.
2. Confirm the effective stack delta contains only this design, one test, and the three mirrored Strategy files.
3. Commit without a co-author trailer, push the branch, and open a draft PR with base `codex/aicom-plan-dependency-r171-20260806`, explicitly declaring “stacked on #2244”, GUIDE-REV `GR-2026-07-08a`, live evidence, mirror status, and no deploy/runtime mutation.
