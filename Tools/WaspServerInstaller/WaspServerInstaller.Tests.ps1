#requires -Version 5.1
# Simple self-test (no Pester dependency). Exit 0 on success.
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
Import-Module -Force (Join-Path $here 'WaspServerInstaller.psm1')

$failures = New-Object System.Collections.Generic.List[string]
function Assert-True($cond, $msg) {
    if (-not $cond) { $failures.Add($msg) }
}

# 1) Example config validates
$cfg = New-WsiDefaultConfig
$cfg.paths.installRoot = Join-Path $env:TEMP ("wasp-wsi-test-" + [guid]::NewGuid().ToString('N'))
$v = Test-WsiConfig -Config $cfg -RequireInstallRoot
Assert-True $v.Ok ("example config should validate: $($v.Errors -join '; ')")

# 2) Difficulty lock
$cfgBad = New-WsiDefaultConfig
$cfgBad.server.difficulty = 'Regular'
$v2 = Test-WsiConfig -Config $cfgBad
Assert-True (-not $v2.Ok) 'Regular difficulty must fail validation'

# 3) Telemetry modes produce distinct flag plans
$cfg.telemetry.mode = 'on'
$pOn = Get-WsiTelemetryFlagPlan -Config $cfg
$cfg.telemetry.mode = 'off'
$pOff = Get-WsiTelemetryFlagPlan -Config $cfg
$cfg.telemetry.mode = 'stats-only'
$pStats = Get-WsiTelemetryFlagPlan -Config $cfg
Assert-True ($pOn['WFBE_C_STATLOG'].value -eq 1) 'on => STATLOG 1'
Assert-True ($pOff['WFBE_C_STATLOG'].value -eq 0) 'off => STATLOG 0'
Assert-True ($pStats['WFBE_C_STATLOG'].value -eq 0) 'stats-only => STATLOG 0'
Assert-True ($pStats['WFBE_C_PLAYERSTAT_ENABLED'].value -eq 1) 'stats-only => PLAYERSTAT 1'
Assert-True ($pStats['WFBE_C_STATS_ENABLED'].value -eq $true -or $pStats['WFBE_C_STATS_ENABLED'].value -eq 1 -or $pStats['WFBE_C_STATS_ENABLED'].value -eq 'True') 'stats-only => STATS_ENABLED on'

# 4) Affinity disjoint on 12 logical CPUs, 2 HC
$cfg.telemetry.mode = 'on'
$cfg.headlessClients.count = 2
$aff = Get-WsiAffinityPlan -Config $cfg -LogicalCount 12
Assert-True ($aff.ServerMask -ne 0) 'server mask non-zero'
Assert-True ($aff.HcMasks.Count -eq 2) 'two HC masks'
$overlap = $aff.ServerMask -band $aff.HcMasks[0]
Assert-True ($overlap -eq 0) 'server and HC1 masks disjoint'
$overlap2 = $aff.ServerMask -band $aff.HcMasks[1]
Assert-True ($overlap2 -eq 0) 'server and HC2 masks disjoint'
$overlap3 = $aff.HcMasks[0] -band $aff.HcMasks[1]
Assert-True ($overlap3 -eq 0) 'HC masks disjoint'

# 5) Render contains Veteran + basic.cfg JIP values
$bundle = New-WsiRenderBundle -Config $cfg -LogicalCount 12
$serverCfg = [string]$bundle.Files['profiles-main/server.cfg']
$basicCfg = [string]$bundle.Files['profiles-main/basic.cfg']
Assert-True ($serverCfg -match 'difficulty = "Veteran"') 'server.cfg Veteran lock'
Assert-True ($basicCfg -match 'MaxSizeGuaranteed=512') 'basic.cfg JIP fix 512'
Assert-True ($bundle.Files.Contains('hc_launch.cmd')) 'hc1 launcher'
Assert-True ($bundle.Files.Contains('hc2_launch.cmd')) 'hc2 launcher'
Assert-True ($bundle.Files.Contains('flag-plan/flag-plan.json')) 'flag plan'

# 6) Apply to scratch + DryRun SAME
$root = [string]$cfg.paths.installRoot
$wrote = Install-WsiRenderBundle -Bundle $bundle -InstallRoot $root -Apply
Assert-True ($wrote.Count -ge 5) 'wrote multiple files'
$diffs = Compare-WsiRenderToDisk -Bundle $bundle -InstallRoot $root
$notSame = @($diffs | Where-Object { $_.Status -ne 'SAME' })
Assert-True ($notSame.Count -eq 0) ("post-apply diffs should be empty: $($notSame | ConvertTo-Json)")

# 7) Live-shaped path refused by Validate unless env
$cfgLive = New-WsiDefaultConfig
$cfgLive.paths.installRoot = 'C:\WASP\profiles-pr8'
$vLive = Test-WsiConfig -Config $cfgLive -RequireInstallRoot
Assert-True (-not $vLive.Ok) 'C:\WASP path should fail closed'

# cleanup scratch
try { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue } catch {}

if ($failures.Count -gt 0) {
    Write-Host "FAIL ($($failures.Count))"
    $failures | ForEach-Object { Write-Host " - $_" }
    exit 1
}
Write-Host "PASS all WaspServerInstaller self-tests"
exit 0
