# Skin-swap Respawn Race Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prevent a suspended skin swap from selecting a newly-created body after the original player has entered the death/respawn lifecycle.

**Architecture:** Keep the existing client-local skin-swap state machine and add one fail-clean cancellation gate immediately after the locality wait and before any group rejoin or `selectPlayer` call. The gate observes the already-owned old body and respawn flag, deletes only the unselected replacement body, releases the re-entry lock, and leaves the normal respawn handler authoritative. No server, HC, deployment, or monitor changes.

**Tech Stack:** Arma 2 OA SQF, Python `unittest` source contracts, `Tools/LoadoutManager` CH-to-TK/ZG mirror generation, `Tools/Lint/check_sqf.py`.

---

### Task 1: Add the failing regression contract

**Files:**
- Create: `Tools/Lint/test_skinswap_respawn_race.py`
- Test: `Tools/Lint/test_skinswap_respawn_race.py`

**Step 1: Write the failing test**

Assert for CH, TK, and ZG that the code between the `_newUnit` locality wait and the first group rejoin contains both death/respawn cancellation signals and fail-clean replacement-body cleanup before the `selectPlayer` call.

**Step 2: Run the focused test**

Run: `python -m pytest Tools/Lint/test_skinswap_respawn_race.py -q`

Expected: FAIL because the current source only checks `_newUnit` null/locality and has no `_oldUnit`/`WFBE_Client_IsRespawning` cancellation gate.

### Task 2: Implement the minimal fail-clean guard

**Files:**
- Modify: `Missions/[55-2hc]warfarev2_073v48co.chernarus/WASP/actions/SkinSelector/SkinSelector_Apply.sqf` after the existing locality guard and before the `_usedSwapGrp` join block.
- Update: `Tools/Lint/vehdel_inventory.json` for the deliberately added fail-clean `deleteVehicle` occurrence.

**Step 1: Add the guard**

If the captured old body is no longer alive, the current player is no longer that body, or `WFBE_Client_IsRespawning` is true, delete the not-yet-selected replacement, delete an empty transient group, clear `WFBE_SkinSelector_InProgress`, log the cancellation, and exit. Do not mutate funds, group membership, or player handlers on this path.

**Step 2: Run the focused test**

Run: `python -m pytest Tools/Lint/test_skinswap_respawn_race.py -q`

Expected: the CH source satisfies the new assertion; the all-variant contract remains red until the generated TK/ZG mirrors are updated in Task 3.

### Task 3: Mirror and verify

**Files:**
- Update: the generated TK and ZG mission mirrors through `Tools/LoadoutManager`.

**Step 1: Generate mirrors**

Run: `dotnet run -c RELEASE` from `Tools/LoadoutManager`.

**Step 2: Run focused and existing contracts**

Run: `python -m pytest Tools/Lint/test_skinswap_respawn_race.py Tools/Lint/test_skinswap_ghost_body.py Tools/Lint/test_skinswap_slot1_rejoin.py -q`

Expected: PASS with zero failures.

**Step 3: Run the required SQF lint gate**

Run: `python Tools/Lint/check_sqf.py --select A3CMD,A3HASH,A3MARKER,A3NUMGATE,A3PRIVATE,A3REVEAL,A3SELECT,A3SORT,A3STRING,BOOLCMP,BRACKET,DBLBOM,DEADNOQA,FLAGGATE,GROUPGETVAR,MILMARKER,NSSETVAR3,PUBVARSV,TRAILCOMMA --no-classname-index`

Expected: `origin/master` currently reproduces 168 pre-existing `A3MARKER` findings; the added-line gate must report `Scanned 3 file(s); findings: 0` with `--diff-from origin/master`.

### Task 4: Draft handoff

Commit the test, CH source, mirrors, and plan on the isolated branch, push it, and open at most one draft PR against `master`. Do not deploy, merge, or alter the live game/server/HC state. Record the commit, PR URL, verification output, current RPT classification, and monitor/HTML hashes in the bounded checkpoint.
