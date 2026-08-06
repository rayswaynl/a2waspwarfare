# AICOM Focus Stale-Town Guard Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prevent a deferred `wfbe_aicom_focus` object reference from overriding the allocator after that town is no longer in the current capturable-town snapshot.

**Architecture:** Keep the existing raw-object focus record and TTL unchanged. Preserve the full current capturable-town snapshot in `_focusTowns` before the allocator narrows `_tgtTowns` for expansion preference, then require focus object identity membership in `_focusTowns` at the read boundary. This rejects captured/replaced town objects without rejecting a valid enemy focus merely because it is outside the narrowed expansion pool.

**Tech Stack:** Arma 2 OA SQF, Python static regression contracts, PowerShell, .NET LoadoutManager mirror generation, repository SQF lint.

---

### Task 1: Write the failing mirror contract

**Files:**
- Create: `Tools/Lint/test_aicom_focus_target_freshness.py`
- Test: `Tools/Lint/test_aicom_focus_target_freshness.py`

**Step 1: Write the failing test**

Add a static contract that loads the CH, TK, and ZG `Server/AI/Commander/AI_Commander_Allocate.sqf` files and requires the full snapshot to be assigned to `_focusTowns` before `_tgtTowns` can be narrowed. Require the focus gate to contain `&& {_focusTgt in _focusTowns}` after the existing fresh check and before the side check. Compare raw file bytes so mirror parity is exact after generation.

**Step 2: Run test to verify it fails**

Run:

```powershell
python Tools/Lint/test_aicom_focus_target_freshness.py
```

Expected: FAIL because the current allocator has no preserved full snapshot variable and no `_focusTowns` identity-membership predicate.

### Task 2: Add the minimal allocator read guard

**Files:**
- Modify: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Allocate.sqf:178-181`
- Generated mirrors: `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/AI/Commander/AI_Commander_Allocate.sqf`, `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/AI/Commander/AI_Commander_Allocate.sqf`

**Step 1: Implement the minimal code change**

Add `_focusTowns` to the private locals, assign it directly from `WFBE_SNAP_TGTTOWNOBJS`, assign `_tgtTowns = _focusTowns` for the existing allocator behavior, and change the focus read gate to `&& {_focusTgt in _focusTowns}`. Do not clear the stored focus, change its TTL, alter the writer, add telemetry, or change live configuration. Edit CH only and preserve CRLF; regenerate TK/ZG through `Tools/LoadoutManager`.

**Step 2: Run the focused test**

Run:

```powershell
python Tools/Lint/test_aicom_focus_target_freshness.py
```

Expected: PASS for all three mission copies.

### Task 3: Run source and mirror verification

**Files:**
- Verify: all files in the previous tasks and the unchanged monitor artifacts.

**Step 1: Regenerate mission mirrors**

Run:

```powershell
Set-Location Tools/LoadoutManager
dotnet run -c RELEASE
```

Expected: the generator completes successfully and produces the CH-derived TK/ZG copies.

**Step 2: Run the focused test and SQF lint**

Run:

```powershell
Set-Location ../..
python Tools/Lint/test_aicom_focus_target_freshness.py
python Tools/Lint/check_sqf.py --select A3CMD,A3HASH,A3MARKER,A3NUMGATE,A3PRIVATE,A3REVEAL,A3SELECT,A3SORT,A3STRING,BAREEXIT,BOOLCMP,BRACKET,DBLBOM,DEADNOQA,FLAGGATE,GROUPGETVAR,MILMARKER,NSSETVAR3,PUBVARSV,TRAILCOMMA --no-classname-index
```

Expected: focused contract PASS; repository lint reports only the known baseline findings, with no new finding in changed files.

**Step 3: Verify mirror parity and diff scope**

Compare the three allocator file hashes, inspect `git diff --check`, confirm the diff is limited to the plan, one regression contract, and the single source hunk plus generated mirrors, and confirm no live monitor HTML/state file changed.

### Task 4: Request independent review and publish one draft PR

**Files:**
- Verify: the final diff and test evidence.

**Step 1: Review the diff against this plan**

Confirm the guard only rejects stale focus objects and leaves current capturable focus behavior unchanged. Note the existing open allocator PR #2244 as a possible future cherry-pick conflict, but do not modify or merge it.

**Step 2: Create at most one draft PR**

After fresh verification and independent review, commit the bounded change and open one GitHub draft PR against `master`. Never deploy or merge, and leave the existing RPT monitor and HTML story untouched.

**Step 3: Record the checkpoint**

Write `outputs/wasp-deep-dive-2026-08-06-aicom-stale-entity-r183.md` with source line evidence, current process-backed RPT evidence, stale/orphan HC classification, test/lint/hash results, PR URL, and explicit no-deploy/no-merge status.
