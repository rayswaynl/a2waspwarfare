# DECAP and AIRRESP Liveness Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the two armed AICOM closers reachable under the observed no-human match conditions while preserving their bounded, organic sensing model.

**Architecture:** AIRRESP will treat already-fielded, side-owned live airframes as its capability proof, rather than a research level that the AI air-factory route intentionally waives. DECAP will use a wider sensing radius to establish organic contact, but retain a separate, tighter commit radius so only teams near the enemy HQ receive a press stamp.

**Tech Stack:** Arma 2 OA SQF, Python static-contract tests, LoadoutManager mirrors.

---

### Task 1: Pin the liveness contracts

**Files:**
- Create: `Tools/Lint/test_aicom_decap_airresp_liveness.py`
- Test: `Tools/Lint/test_aicom_decap_airresp_liveness.py`

**Step 1:** Assert that AIRRESP derives capability from a live, side-resolved airframe count and emits an explicit skip reason.

**Step 2:** Assert that DECAP has a sensing radius larger than its commit radius and retains the existing scoped press gate.

**Step 3:** Run `python Tools/Lint/test_aicom_decap_airresp_liveness.py`; expect failure on the pre-fix baseline.

### Task 2: Implement the source correction

**Files:**
- Modify: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_AirResp.sqf`
- Modify: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf`

**Step 1:** Count live side-resolved AICOM airframes using the established `vehicles`/crew-or-`wfbe_side` idiom; use that as AIRRESP's air capability condition and record the count plus a truthful skip reason in telemetry.

**Step 2:** Widen only DECAP's sensing defaults; set an explicit smaller commit radius so the action remains locally scoped at the HQ.

**Step 3:** Preserve A2 OA compatibility and CRLF endings with a targeted Python replacement.

### Task 3: Mirror and verify

**Files:**
- Generated mirrors: Takistan and Zargabad copies of the two source files

**Step 1:** Run the new static-contract test red-to-green.

**Step 2:** Run LoadoutManager with `A2WASP_SKIP_ZIP=1`, restore the two per-map templates if needed, and run its `--check` mode.

**Step 3:** Run the mandated SQF lint gate, delimiter checks, mirror hashes, and a focused diff review.

**Step 4:** Commit, push the task branch, create a draft PR against `master`, then close the code-only Fleet card with the required milestone shape.
