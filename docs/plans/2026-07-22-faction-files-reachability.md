# Faction File Reachability Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prevent a pull request from silently modifying faction configuration files that the affected terrain cannot dynamically load.

**Architecture:** Add a small dependency-free lint command which maps each maintained terrain to its fixed reachable faction set. In diff mode it resolves changed paths through Git and fails only when a changed Root, Defenses, Groups, or Artillery faction file cannot be loaded on that terrain.

**Tech Stack:** Python 3 standard library, `unittest`, Git.

---

### Task 1: Specify the reachability mapping

**Files:**
- Create: `Tools/Lint/test_faction_reachability.py`
- Create: `Tools/Lint/check_faction_reachability.py`

**Step 1: Write failing tests**

Cover live Takistan and Chernarus paths, dead paths in Root/Defenses/Groups/Artillery, and non-faction paths.

**Step 2: Run test to verify it fails**

Run: `python Tools/Lint/test_faction_reachability.py`
Expected: FAIL because the checker module does not exist.

**Step 3: Write minimal implementation**

Parse maintained mission paths, compare the faction token with the terrain’s fixed load set, and expose a CLI that checks explicit paths or a Git diff.

**Step 4: Run test to verify it passes**

Run: `python Tools/Lint/test_faction_reachability.py`
Expected: PASS.

### Task 2: Make the check usable in the existing lint workflow

**Files:**
- Modify: `Tools/Lint/README.md`

**Step 1: Document the diff command**

Add one focused usage example and explain that it covers terrain-divergent faction files.

**Step 2: Verify against the current branch**

Run: `python Tools/Lint/check_faction_reachability.py --diff-from origin/master`
Expected: no unreachable faction-file changes.

### Task 3: Verify the mission and mirror constraints

**Files:**
- Test: `Tools/Lint/test_faction_reachability.py`

**Step 1: Run focused and repository lint gates**

Run the focused unit tests, the reachability diff check, and the required SQF lint selection.

**Step 2: Confirm no mission source changed**

Run: `git diff --check origin/master...HEAD` and inspect the final diff. Because this change is tooling-only, no LoadoutManager mirror run is required.
