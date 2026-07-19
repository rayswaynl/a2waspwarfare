# Purchase Queue Dequeue Layout Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prevent the Purchase Units queue-cancel control from overflowing while preserving its exact dequeue, refund, and counter semantics.

**Architecture:** Update the Chernarus dialog source with a localizable, header-safe cancel label and strengthen only the `MenuAction == 501` client path against absent or malformed parallel queue arrays. Mirror the source through LoadoutManager and lock the UI geometry and dequeue invariants with static regression tests because no Arma client UI harness is available in this worktree.

**Tech Stack:** Arma 2 OA dialog config/SQF, Python `unittest`, LoadoutManager.

---

### Task 1: Write the failing UI and dequeue contracts

**Files:**
- Create: `Tools/Lint/test_purchase_queue_dequeue.py`
- Test: `Tools/Lint/test_purchase_queue_dequeue.py`

**Step 1: Write the failing test**

Assert that IDC 12043 uses a localized label, fits entirely between IDC 12024 and IDC 12019 at 4:3, 16:10, 16:9, and 21:9 with small, normal, and large UI scaling, and that the client dequeue action rejects absent/malformed queues and removes only one identical queue token while keeping refund and counters indexed to the removed order.

**Step 2: Run test to verify it fails**

Run: `python Tools/Lint/test_purchase_queue_dequeue.py`

Expected: FAIL because the current hard-coded `Cancel Last` label is too narrow and the queue token removal removes every equal token.

### Task 2: Make the smallest source-only correction

**Files:**
- Modify: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Dialogs.hpp`
- Modify: `Missions/[55-2hc]warfarev2_073v48co.chernarus/stringtable.xml`
- Modify: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_Menu_BuyUnits.sqf`

**Step 1: Preserve the existing action**

Keep `MenuAction = 501`, the existing queued-order selection rule, refund formula, and counter names unchanged.

**Step 2: Implement localized, bounded layout and guards**

Give IDC 12043 a localized short label, use the available header band without overlapping the queue/cash controls, and validate object, parallel-array shape, and selected numeric values before mutation. Rebuild `queu` by index, like its parallel arrays, so duplicate tokens remove one entry only.

**Step 3: Run the regression test**

Run: `python Tools/Lint/test_purchase_queue_dequeue.py`

Expected: PASS.

### Task 3: Mirror and verify

**Files:**
- Modify via generator: Takistan and Zargabad mirrors of the three Chernarus source files

**Step 1: Generate mirrors**

Run: `$env:A2WASP_SKIP_ZIP=1; dotnet run -c RELEASE` from `Tools/LoadoutManager`.

**Step 2: Restore template drift and verify mirrors**

Restore the two `version.sqf.template` files from `origin/master`, run `dotnet run -c RELEASE -- --check`, then run the full mandatory SQF lint selector, the focused regression tests, delimiter checks, and `git diff --check`.

**Step 3: Commit and open a stacked draft PR**

Commit only the intended source, mirrored, test, and plan files; push the branch; open a draft PR stacked on #1149 with GUIDE-REV `GR-2026-07-08a` and verification evidence.
