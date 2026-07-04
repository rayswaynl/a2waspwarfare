# Soak Analyzer Salvage Status - 2026-07-03

Scope: fleet lane 26, source audit only. The prompt asks to salvage the useful
parts of the earlier soak-analyzer PRs into the current target: especially the
synthetic RPT regression test, dispatch-distance buckets, and median
dispatch-to-arrival metric.

## Verdict

Lane 26 is already implemented on `origin/claude/build84-cmdcon36`
(`b1608b096eb4a02d7c213d794e22b8bc59df8df0`). No additional analyzer source
change is needed for the prompt as written.

The current canonical files are:

- `Tools/Soak/analyze_soak.py`
- `Tools/Soak/test_analyze_soak.py`

The regression test explicitly says it salvaged PR #139's intent and rewrote the
assertions for the current canonical analyzer API. It pins the AICOM
dispatch/arrival counters, distance-bucket arrival table, median
dispatch-to-arrival, kills, MHQ verbs, WASPSCALE perf and v2-EXT state, and
Build 86 log families.

## Source Evidence

- `Tools/Soak/test_analyze_soak.py:3-9` documents the salvage route from PR
  #139's synthetic-RPT KPI regression-test intent into the current `Soak` class
  API.
- `Tools/Soak/test_analyze_soak.py:61-68` asserts dispatch/arrival counts for
  `<500` and `2000+` distance buckets.
- `Tools/Soak/test_analyze_soak.py:70-72` asserts the median
  dispatch-to-arrival metric.
- `Tools/Soak/analyze_soak.py:585-629` implements `arrival_by_bucket()`,
  bucketing dispatch distance into `<500`, `500-2000`, and `2000+`.
- `Tools/Soak/analyze_soak.py:630-654` implements
  `median_dispatch_to_arrival_min()`.
- `Tools/Soak/analyze_soak.py:1234-1236` includes
  `median_dispatch_to_arrival_min` and `by_bucket` in JSON output.
- Git history contains `89cba0ae5 test(soak): add analyze_soak regression test
  (salvaged from #139)`.

## Verification

`python Tools\Soak\test_analyze_soak.py`

Result:

- 11 tests run.
- 11 passed.
- Covered `test_arrival_by_bucket`, `test_median_dispatch_to_arrival`,
  `test_dispatch_arrival_counters`, `test_build86_families`, and related KPI
  paths.

No mission source, generated mirror, package artifact, live server, or
LoadoutManager output is changed by this audit.
