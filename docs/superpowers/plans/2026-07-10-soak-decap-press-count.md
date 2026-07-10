# DECAP Soak Press Count Fix Plan

> **Scope:** Correct the offline soak scorers and formatter only. Do not modify mission SQF, launch Arma, deploy files, or touch live/test lanes.

**Goal:** Make both AICOM2 soak summaries count the real closer active-press state (`COMMITTED`) and keep the HC-local driver `PRESS` transition separate from server-side closer state records.

**Root cause:** Python routes a driver line found in the server stream to `a2_press`, but its HC ingestion ignores that HC-local line and its closer summary looks for impossible `state == "PRESS"`. The PowerShell scorer repeats the state-count error, leaves a driver line inside its closer collection, and cannot consume a separate HC RPT. Its renderer also uses incompatible hashtable property aggregation under Windows PowerShell 5.1. The live watcher still assumes obsolete SCAN/TRACK/PRESS closer states and treats a driver transition as state `?`.

**Files:**

- Modify: `Tools/Soak/test_analyze_soak.py`
- Modify: `Tools/Soak/analyze_soak.py`
- Modify: `Tools/PrTestHarness/Aicom/Score-AicomRounds.ps1`
- Modify: `Tools/PrTestHarness/Ops/aicom-watch.ps1`
- Modify: `Tools/Soak/README.md`
- Modify: `Tools/Soak/sample_cc44u.rpt`
- Add: `Tools/Soak/sample_cc44u_hc.rpt`

## Task 1: Pin the real grammar with a failing regression test

Split the fixture at the real locality boundary, feeding `sample_cc44u.rpt` to `ingest_server()` and `sample_cc44u_hc.rpt` to `ingest_hc()`. Add assertions that:

- WEST has one `state=COMMIT` transition and one steady `state=COMMITTED` record.
- `decap.press_events` must equal `1` (the steady COMMITTED tick).
- The separate driver event remains independently represented by `press_ticks == 1`.

Confirm the original closer fixture first exposes the zero count, then pin the source-accurate COMMIT/COMMITTED sequence and confirm the realistic HC split fails with `press_ticks` `0 != 1` before changing that ingestion path.

## Task 2: Correct the Python analyzer

In `aicom2_summary().decap_summary()`, count closer records whose state is exactly `COMMITTED`. Teach `ingest_hc()` to recognize the HC-local driver transition without mixing it into closer records.

Run the focused test and the full `Tools/Soak/test_analyze_soak.py` suite.

## Task 3: Bring the PowerShell scorer onto the same contract

Extend its bundled self-test first so the real fixture requires five WEST closer records, one `COMMIT`, one steady `COMMITTED` tick, and one separate driver transition. Confirm the new check fails.

Then:

- route the driver transition out of the closer collection;
- keep legacy posture PRESS telemetry out of the HC driver-transition counter;
- count and label `COMMITTED` closer ticks;
- accept an optional HC RPT and scope it independently before combining parsed telemetry;
- exclude a dead final MISSINIT segment (including its errors) when an earlier played segment has telemetry;
- replace the hashtable property aggregates that fail or render blank on Windows PowerShell 5.1;
- update stale live-grammar documentation and fixture comments.

Run the self-test and fixture score under both Windows PowerShell 5.1 and PowerShell 7.

## Task 4: Correct the live watcher formatter

Extend its self-test to replay both server and HC fixtures. Require the driver line to be highlighted without overwriting the last closer state. Confirm the check fails, then colorize the real closer states and label the driver transition separately.

## Task 5: Verify and review

Run:

- `python -m unittest Tools/Soak/test_analyze_soak.py`
- `python -m py_compile Tools/Soak/analyze_soak.py Tools/Soak/test_analyze_soak.py`
- the fixture summary probe to confirm `press_events=1`, `press_ticks=1`
- PowerShell 5.1 and PowerShell 7 self-tests
- PowerShell 5.1 and PowerShell 7 fixture scores using separately scoped server/HC inputs
- PowerShell 5.1 and PowerShell 7 watcher self-tests
- `git diff --check`
- `git status --short`

Review the full diff, request an independent code review, then commit and publish only this isolated branch as a draft PR against `master` if all checks pass.
