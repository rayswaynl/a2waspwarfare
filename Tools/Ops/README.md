# WASP Ops Helper Runbook

These scripts are operator-side helpers for local server administration. They do not
launch Arma, deploy PBOs, touch mission source, or change live state unless their own
`-Apply` switch is passed.

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
