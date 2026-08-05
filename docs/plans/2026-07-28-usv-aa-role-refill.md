# USV AA Role Refill Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refill a missing configured USV combat role before continuing the normal round-robin selection.

**Architecture:** The maintain block will scan the live flotilla registry for each configured role. If a configured role is absent, it becomes the next spawn role; otherwise the existing count-based round-robin fallback remains. The source worker is mirrored to Takistan and Zargabad by LoadoutManager.

**Tech Stack:** Arma 2 OA SQF, Python source-contract regression tests, .NET LoadoutManager.

---

### Task 1: Prove the role-gap regression

**Files:**
- Create: `Tools/Lint/test_usv_role_refill.py`
- Test: `Tools/Lint/test_usv_role_refill.py`

**Step 1:** Add a contract requiring a role-presence scan that selects a missing role before the existing round-robin fallback.

**Step 2:** Run `python Tools\\Lint\\test_usv_role_refill.py`; expect failure because the worker only uses the flotilla length to choose its next role.

### Task 2: Implement the minimal refill selection

**Files:**
- Modify: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Server_USVFlotilla.sqf:270-280`

**Step 1:** Scan the live registry for each configured role and select the first missing one.

**Step 2:** Preserve the existing round-robin selection only when all configured roles are represented.

**Step 3:** Run the role-refill regression and existing USV checks.

### Task 3: Mirror and validate

**Files:**
- Modify: `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Server_USVFlotilla.sqf`
- Modify: `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/Server_USVFlotilla.sqf`

**Step 1:** Run LoadoutManager with packing skipped, then its drift check.

**Step 2:** Run the focused SQF lint and bracket checks for all three mirrored workers.
