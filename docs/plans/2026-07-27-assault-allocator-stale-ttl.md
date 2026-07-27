# Assault Allocator Stale TTL Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Release an assault team from a stale AICOM allocator record so its next AssignTowns pass can select and dispatch a live target.

**Architecture:** `AI_Commander_AssignTowns.sqf` owns the read-side TTL check for the allocator's per-team target and tick. Its stale branch will clear both values immediately after the existing diagnostic, preserving the allocator's normal fresh-record path while making a stale record a one-pass condition. A static contract will pin that state transition and confirm generated terrain mirrors stay identical.

**Tech Stack:** Arma 2 OA SQF, Python `unittest`, LoadoutManager terrain mirroring.

---

### Task 1: Pin the stale-record release contract

**Files:**
- Modify: `Tools/Lint/test_assault_retarget_churn.py:55-65`
- Test: `Tools/Lint/test_assault_retarget_churn.py`

**Step 1: Write the failing test**

```python
def test_stale_allocator_record_is_cleared_after_its_single_diagnostic(self):
    stale = self.assign.index("|ALLOC_TICK_STALE|")
    release = self.assign.index(
        '_team setVariable ["wfbe_aicom_alloc_target", nil];', stale
    )
    self.assertLess(stale, release)
    self.assertIn(
        '_team setVariable ["wfbe_aicom_alloc_tick", nil];',
        self.assign[release:],
    )
```

**Step 2: Run test to verify it fails**

Run: `python Tools/Lint/test_assault_retarget_churn.py`

Expected: FAIL because the pre-fix stale branch emits the event without clearing the allocator target/tick pair.

### Task 2: Release expired allocator state

**Files:**
- Modify: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_AssignTowns.sqf:1003-1006`
- Test: `Tools/Lint/test_assault_retarget_churn.py`

**Step 1: Write minimal implementation**

```sqf
_team setVariable ["wfbe_aicom_alloc_target", nil];
_team setVariable ["wfbe_aicom_alloc_tick", nil];
```

**Step 2: Run test to verify it passes**

Run: `python Tools/Lint/test_assault_retarget_churn.py`

Expected: PASS.

### Task 3: Mirror and verify the mission output

**Files:**
- Generated: `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/AI/Commander/AI_Commander_AssignTowns.sqf`
- Generated: `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/AI/Commander/AI_Commander_AssignTowns.sqf`

**Step 1: Mirror from Chernarus**

Run: `dotnet run -c RELEASE` from `Tools/LoadoutManager`.

**Step 2: Verify**

Run the required SQF lint gate, bracket-delta check, static regression test, template checks, and `git diff --check`.
