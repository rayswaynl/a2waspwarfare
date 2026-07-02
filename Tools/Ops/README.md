# WASP Ops Scripts

Small PowerShell helpers for live-ops chores. They are intended to be run manually by an operator and default to dry-run behavior where they can affect the server.

## Safety Rules

- Run dry runs first. `Set-MissionTemplate.ps1` and `Set-WaspCpuAffinity.ps1` only write or apply when `-Apply` is present.
- Do not run these against the live host during a match unless the operator has explicitly approved the maintenance action.
- Keep masks and paths box-specific. Commit reusable helper changes here, not private server paths.

## Mission Template Repoint

Use this after a mission PBO name changes and the active `server.cfg` mission template line must be updated.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\Ops\Set-MissionTemplate.ps1 `
  -CfgPath C:\WASP\server.cfg `
  -MissionName '[55-2hc]warfarev2_073v48co_b86.chernarus'
```

Add `-Apply` only after the dry run reports the intended single match. Same-build redeploys are treated as successful no-ops.

## CPU Affinity

Use this only after confirming the logical CPU layout on the target box. `-LogicalProcessorCount` catches masks that point outside the declared CPU range, and `-StrictDisjoint` fails when server/HC masks overlap.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\Ops\Set-WaspCpuAffinity.ps1 `
  -ServerMask 0x0FF `
  -HcMasks 0x300,0xC00 `
  -LogicalProcessorCount 12 `
  -StrictDisjoint
```

Add `-Apply` only during an approved maintenance window.

## Windowed RPT Reads

`Tools\Monitor\Get-WindowedRpt.ps1` is dot-sourced by monitor scripts that need only the current mission window from an appended RPT.

```powershell
. .\Tools\Monitor\Get-WindowedRpt.ps1
$currentErrors = Get-WindowedRpt -RptPath C:\WASP\arma2oaserver.RPT -Pattern 'Error|ERROR'
```

The helper reads with `ReadWrite` sharing so it does not block a running Arma process.

## Local Checks

Run these before changing the helpers:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\Ops\Set-MissionTemplate.Tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\Ops\Set-WaspCpuAffinity.Tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\Monitor\Get-WindowedRpt.Tests.ps1
```
