# Performance Capture Foundation Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development to implement this plan task-by-task.

**Goal:** Add a deterministic, sealable run-manifest contract and a read-only Windows process-metrics sidecar with fixtures, tests, overhead evidence, and rollback documentation.

**Architecture:** A dependency-free Python validator enforces the draft-07 manifest schema plus cross-field invariants and canonical SHA-256 sealing. A PowerShell 5.1-compatible collector validates explicit process identities, samples CIM/process counters without target mutation, and writes CSV plus identity and overhead sidecars.

**Tech Stack:** Python 3.11+ stdlib, Windows PowerShell 5.1/PowerShell 7, CIM `Win32_Process` and `Win32_PerfFormattedData_PerfProc_*`, JSON/CSV, `unittest`, plain-assertion PowerShell tests.

---

### Task 1: Pin the exact manifest schema

**Files:**
- Create: `Tools/PerfCapture/run-manifest.schema.json`
- Create: `Tools/PerfCapture/fixtures/valid-pending/MANIFEST.json`
- Create: `Tools/PerfCapture/fixtures/valid-final/MANIFEST.json`
- Create: `Tools/PerfCapture/tests/test_validate_run_manifest.py`

**Step 1: Write failing tests**

Add tests that import `validate_run_manifest`, load the valid fixtures, and
assert the wished-for `validate_manifest()` API returns no errors. Add mutations
for a missing field, extra field, duplicate role/specimen, bad specimen
reference, bad artifact folder name, invalid time order, and inconsistent
pending/valid/invalid state.

**Step 2: Verify RED**

Run: `python Tools\PerfCapture\tests\test_validate_run_manifest.py`

Expected: import failure because `validate_run_manifest.py` does not exist.

**Step 3: Add the schema and fixtures**

Define every object with `additionalProperties:false`, require every field, use
null for unavailable/not-yet-attained values, and include every identity family
required by the performance master plan.

### Task 2: Implement validation and immutable sealing

**Files:**
- Create: `Tools/PerfCapture/validate_run_manifest.py`
- Modify: `Tools/PerfCapture/tests/test_validate_run_manifest.py`

**Step 1: Implement minimal validation**

Implement draft-07 keywords used by the schema (`type`, `required`,
`properties`, `additionalProperties`, `items`, `const`, `enum`, `pattern`,
`minimum`, `minItems`, and date-time format) plus cross-field invariants.

CLI:

```text
python validate_run_manifest.py MANIFEST.json [--schema FILE] [--finalize]
```

`--finalize` must require non-pending status, atomically write canonical JSON,
and atomically create `MANIFEST.sha256`. Existing seals must be verified and
must never be silently replaced.

**Step 2: Verify GREEN**

Run: `python Tools\PerfCapture\tests\test_validate_run_manifest.py`

Expected: all validator and sealing tests pass.

**Step 3: Commit the manifest contract**

Commit only schema, fixtures, validator, tests, and the already-reviewed design.

### Task 3: Specify collector output before implementing it

**Files:**
- Create: `Tools/PerfCapture/Collect-ProcessMetrics.Tests.ps1`

**Step 1: Write the integration test**

The test starts three hidden, test-owned sleeping PowerShell processes for
server/HC/client roles, creates a matching pending manifest in its artifact
directory, then invokes the absent collector for two short samples. It asserts:

- fixed CSV columns and two rows for each declared role;
- identity JSON contains executable/command/module hashes or explicit errors;
- overhead JSON contains timing, CPU, deadline, and output-size fields;
- the helper process is still running after collection;
- PID/start/hash mismatch is rejected before metrics are written.

**Step 2: Verify RED**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File Tools\PerfCapture\Collect-ProcessMetrics.Tests.ps1`

Expected: failure because `Collect-ProcessMetrics.ps1` does not exist.

### Task 4: Implement the read-only Windows collector

**Files:**
- Create: `Tools/PerfCapture/Collect-ProcessMetrics.ps1`
- Modify: `Tools/PerfCapture/Collect-ProcessMetrics.Tests.ps1`

**Step 1: Implement identity preflight**

Validate the manifest, resolve only declared PIDs, verify start time/executable
SHA/command SHA/affinity, hash accessible modules once, and write ordered
`process-identity.json`. Do not expose an unredacted command line.

**Step 2: Implement minimal sampling**

Sample the declared targets in stable role order. Preserve unavailable values as
empty CSV fields with status/error columns. Use a monotonic stopwatch for
elapsed time and interval scheduling.

**Step 3: Implement overhead and mutation guards**

Measure collector CPU/wall/query/module-hash/output costs, count missed
deadlines, and verify the manifest hash is unchanged at the end.

**Step 4: Verify GREEN in both shells**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File Tools\PerfCapture\Collect-ProcessMetrics.Tests.ps1
pwsh -NoProfile -File Tools\PerfCapture\Collect-ProcessMetrics.Tests.ps1
```

Expected: all assertions pass and every test-owned helper is cleaned up.

### Task 5: Document, measure, and review

**Files:**
- Create: `Tools/PerfCapture/README.md`
- Create: `Tools/PerfCapture/OVERHEAD.md`

**Step 1: Write operator documentation**

Document schema fields, pending-to-final lifecycle, explicit target identity,
output columns and sources, null semantics, command-line redaction/hash policy,
sampling examples, artifact layout, limitations, and rollback.

**Step 2: Run representative benign-process overhead measurement**

Use the integration harness at a one-second interval for enough samples to
report query p50/p95/max, collector CPU, deadline misses, and bytes/sample.
Record measured host-independent results and label them as a local benign-process
measurement, not Arma workload overhead.

**Step 3: Run full verification**

Run Python tests, PowerShell 5.1/7 tests, manifest fixture validation, `git diff
--check`, public-repo hygiene scans, focused secret/credential scans, and the
repo SQF lint gate (expect no new findings because no SQF is changed).

**Step 4: Request independent review**

Give a read-only reviewer the task requirements, base/head SHAs, actual diff,
and test evidence. Fix every Critical/Important finding and rerun verification.

**Step 5: Deliver**

Commit without attribution trailers, push the task branch, create a draft PR to
`master` with GUIDE-REV `GR-2026-07-08a`, and close the Fleet task with PR/test
evidence. Do not merge or deploy.
