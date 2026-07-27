# USV Gate Recycle Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ensure a USV flotilla quiet-despawn cannot leave the carrier-approach gate in a terminal state when activity resumes.

**Architecture:** Reset the flotilla-wide quiet timer immediately after evaluating an active gate and before pruning existing boats. This guarantees a newly active tick clears stale terminal state before either despawn or refill logic can consume it. The source remains Chernarus-only; LoadoutManager mirrors the edit.

**Tech Stack:** Arma 2 OA SQF, Python static contract tests, LoadoutManager.

---

### Task 1: Encode the gate-recycle contract

**Files:**
- Create: `Tools/Lint/test_usv_gate_recycle.py`
- Test: `Tools/Lint/test_usv_gate_recycle.py`

**Step 1: Write the failing test**

Assert that the `_gateActive` branch clears `_gateInactiveTime` before the prune section and that the old post-prune timer update is absent.

**Step 2: Run test to verify it fails**

Run: `python Tools/Lint/test_usv_gate_recycle.py`
Expected: FAIL because the current reset is after prune.

### Task 2: Reset timer at the gate boundary

**Files:**
- Modify: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Server_USVFlotilla.sqf:190-281`

**Step 1: Write minimal implementation**

Move the timer update to immediately after gate-edge bookkeeping, retaining the same inactive increment and removing the later duplicate.

**Step 2: Run test to verify it passes**

Run: `python Tools/Lint/test_usv_gate_recycle.py`
Expected: PASS.

### Task 3: Mirror and verify

**Files:**
- Modify via mirror: `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Server_USVFlotilla.sqf`
- Modify via mirror: `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/Server_USVFlotilla.sqf`

**Step 1: Mirror source edit**

Run: `dotnet run -c RELEASE` from `Tools/LoadoutManager`.

**Step 2: Verify**

Run the USV static contract, waypoint validator, targeted SQF lint, and bracket/flag-off/mirror checks.
