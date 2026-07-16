# WASP Ops Helper Runbook

These scripts are operator-side helpers for local server administration. They do not
launch Arma, deploy PBOs, touch mission source, or change live state unless their own
`-Apply` switch is passed.

## Full Deploy Pipeline

Use `Deploy-Wasp.ps1` — the ONE reusable, idempotent deploy pipeline that replaces the
~150 single-use throwaway deploy scripts. It composes the existing helpers
(`Set-MissionTemplate.ps1`, the `WaspServiceRestart` task, `Tools/LoadoutManager`) to run the
whole chain: build/mirror → pack → archive+copy → repoint cfg → restart → verify, with a real
rolling rollback archive.

```powershell
.\Deploy-Wasp.ps1 -Build cmdcon48aicom -ActiveMap ch          # dry run (writes nothing)
.\Deploy-Wasp.ps1 -Build cmdcon48aicom -ActiveMap ch -Apply   # real deploy (owner, on the box)
.\Deploy-Wasp.ps1 -ActiveMap ch -Rollback -Apply              # restore previous known-good PBO
```

It is safe by default (dry run without `-Apply`) and is built so the 2026-06-23 "cfg guard
threw after the service was stopped" incident cannot recur — the cfg is repointed while the
server is still up, and the restart task is the only stop/start. Full design, the flagged
external PBO-packer dependency (Mikero), and the rollback model are in
[`docs/ops/DEPLOY-PIPELINE.md`](../../docs/ops/DEPLOY-PIPELINE.md).

## Mission Template Repoint

Use `Set-MissionTemplate.ps1` to update the active `template = "...";` line in a server
cfg after a build name changes:

```powershell
.\Set-MissionTemplate.ps1 `
    -CfgPath <path-to-server.cfg> `
    -MissionName '[55-2hc]warfarev2_073v48co_b86.chernarus'
```

Run it once without `-Apply` first. The helper distinguishes a missing template line
from an already-correct same-build redeploy, so repeated dry runs and applies are safe.

## CPU Affinity

Use `Set-WaspCpuAffinity.ps1` to dry-run or apply processor-affinity masks for the
dedicated server and headless clients:

```powershell
.\Set-WaspCpuAffinity.ps1 -ServerMask 0x0FF -HcMasks 0x300,0xC00
.\Set-WaspCpuAffinity.ps1 -ServerMask 0x0FF -HcMasks 0x300,0xC00 -Apply
```

Masks are hardware-specific logical-CPU bitmasks. Use `0` or omit a mask to leave a
target untouched. Negative masks are rejected.

## Windowed RPT Reads

The companion monitor helper lives in `Tools/Monitor/Get-WindowedRpt.ps1`. Dot-source it
when an ops script needs only the current mission or boot window from an append-only RPT:

```powershell
. ..\Monitor\Get-WindowedRpt.ps1
$errors = Get-WindowedRpt -RptPath C:\WASP\arma2oaserver.RPT -Pattern 'Error|ERROR'
```

`-Tail` returns the last N selected lines, and `-WindowMarker` can switch from the
default `MISSINIT` mission window to a boot marker such as `Dedicated host created`.

## Public Stats Generator

`Update-PublicStats.ps1` is a **mirror of the live on-box script**, not a script meant to
be run from this checkout. It is deployed at `C:\WASP\Update-PublicStats.ps1` on the
Hetzner production box, runs every 5 minutes via the `WaspStatsUpdate` scheduled task,
and parses the live `arma2oaserver.RPT` into `C:\WASP\web\stats.json` — the feed behind
the public stats page (miksuu.com `/api/wasp-stats`).

It was pulled from the box and committed here on 2026-07-08 purely to protect it from
silent regression: the box copy had drifted ahead of the repo (it had already gained a
`directorLedger` key that no repo copy tracked), so a future repo-driven redeploy of
`C:\WASP\` could have clobbered it with a stale version. This repo copy is the record of
that on-box state — the box remains the actual runtime. If you change this file, deploy
the change to the box by hand and keep this copy in sync; there is no automated
deploy/activation step wired up for it yet.

## Slot Count Consistency

Use `Test-WaspSlotCountConsistency.ps1` to audit the tracked maintained mission
folders for lobby-slot drift:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\Ops\Test-WaspSlotCountConsistency.ps1
```

The check compares `WF_MAXPLAYERS` in each `version.sqf.template` with the playable
`player="...";` declarations in the matching `mission.sqm`. It is read-only and exits
nonzero when a terrain drifts.

## Local Checks

Run the dependency-free tests before using or changing the helpers:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\Ops\Set-MissionTemplate.Tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\Ops\Set-WaspCpuAffinity.Tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\Ops\Test-WaspSlotCountConsistency.Tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\Monitor\Get-WindowedRpt.Tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\Monitor\Test-WaspRptMarkerSweep.SelfTest.ps1
```
