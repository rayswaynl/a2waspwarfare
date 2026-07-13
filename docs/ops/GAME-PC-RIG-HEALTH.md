# Game-PC Rig Health

This runbook covers the isolated Arma 2 OA 1.64 proving rig at
C:\Users\Game\a2oa-local-1.64. It never targets the live server. The local rig is
limited to LAN/gameplay tests; two-HC topology, collapse repro, bounces and box
campaigns remain box-only.

## Baseline — 2026-07-13

- Checkout: origin/Test-Branche and origin/master both resolve to cf8d83040
  (fix(lane364): add AICOM posture reason telemetry). The repo worktree was clean.
- Smoke command: lab-boot.ps1 -Config lab-server-hc-stock.cfg
  -Tag steward-20260713 -Mission WASP_ProvingGround_fast-smoke_hc-stock.utes
  -Hcs 1 -ListenSecs 120 -LobbySecs 240 -RunSecs 120.
- Baseline: server listened on UDP 2402, reached MISSINIT, reported zero missing
  addon hits, and cleanup left zero Arma processes. The driver verdict was
  NO_RESULT because the intentionally short run produced two samples before
  teardown; this is a boot-health PASS, not a graded scenario result.
- Evidence: C:\Users\Game\a2oa-local-1.64\lab-boot-steward-20260713.log and
  C:\Users\Game\wasp-build\lab-runs\steward-20260713\.

## Weekly recurrence

Tools/RigHealth/Invoke-WaspRigHealth.ps1 runs the same bounded one-HC boot,
then writes the atomic status record
C:\Users\Game\wasp-build\rig-health\weekly-status.json using schema
a2wasp-rig-health-v1. PASS requires listening, MISSINIT, no missing addons, and
zero remaining Arma processes. A missing WASPLAB RESULT is recorded but does
not fail boot health. On FAIL it creates a unique, unready Fleet card with the
driver log and status paths in the message.

The owner-installed recurrence is Tools/RigHealth/Install-WaspRigHealthWeekly.cmd.
It schedules run-hidden.vbs every Sunday at 04:00 local time. This lane did not
register a scheduled task; the installer is provided for the owner because Task
Scheduler elevation and the rig guardrails are owner-controlled.

Manual probe:

    powershell -ExecutionPolicy Bypass -File Tools\RigHealth\Invoke-WaspRigHealth.ps1

## Cards waiting on local runtime

- wasp-movedpct-metric-fix-20260712 — blocked pending a pinned
  c125-n3b package/final handoff or owner re-arming the Game-PC lab rerun.
- wasp-ctl-invest-arm-soak-20260712 — queued but not ready; its local driver
  and baked test mission must be staged before it can enter the runtime queue.
- wasp-flag-lane-forced-path-harness — blocked and intentionally unowned:
  design approval, collision revalidation, task-specific runtime authority and
  independent review are required before any runtime window.

The blocked wasp-perf-ab-soak-2026-07-11 card is excluded: it requires an
exclusive box window and two HCs, outside this local rig's authority.
