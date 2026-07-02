#requires -Version 5.1
<#
.SYNOPSIS
    Dependency-free validation tests for Set-WaspCpuAffinity.ps1.
.EXAMPLE
    .\Set-WaspCpuAffinity.Tests.ps1
#>
$ErrorActionPreference = 'Stop'
$helper = Join-Path $PSScriptRoot 'Set-WaspCpuAffinity.ps1'
$script:fails = 0

function Assert($cond, $name) {
    if ($cond) { Write-Host "  PASS  $name" }
    else { Write-Host "  FAIL  $name" -ForegroundColor Red; $script:fails++ }
}

function Invoke-AffinityHelper([scriptblock]$Body) {
    try {
        & $Body | Out-Null
        return [pscustomobject]@{ Threw = $false; Message = '' }
    } catch {
        return [pscustomobject]@{ Threw = $true; Message = $_.Exception.Message }
    }
}

Write-Host "TEST 1: server mask 0 is accepted as leave-untouched"
$r = Invoke-AffinityHelper { & $helper -ServerMask 0 -HcMasks @() }
Assert (-not $r.Threw) "T1 no throw for zero server mask"

Write-Host "TEST 2: positive dry-run masks are accepted without -Apply"
$r = Invoke-AffinityHelper { & $helper -ServerMask 255 -HcMasks @(768, 3072) }
Assert (-not $r.Threw) "T2 no throw for positive dry-run masks"

Write-Host "TEST 3: negative server mask is rejected before process discovery"
$r = Invoke-AffinityHelper { & $helper -ServerMask -1 }
Assert ($r.Threw) "T3 throws on negative ServerMask"
Assert ($r.Message -match 'non-negative') "T3 error mentions non-negative masks"

Write-Host "TEST 4: negative HC mask is rejected before process discovery"
$r = Invoke-AffinityHelper { & $helper -HcMasks @(-1) }
Assert ($r.Threw) "T4 throws on negative HcMasks entry"
Assert ($r.Message -match 'non-negative') "T4 error mentions non-negative masks"

Write-Host "TEST 5: zero HC entries are accepted as per-HC leave-untouched markers"
$r = Invoke-AffinityHelper { & $helper -HcMasks @(0, 768) }
Assert (-not $r.Threw) "T5 no throw for mixed zero and positive HC masks"

Write-Host ""
if ($script:fails -eq 0) { Write-Host "ALL TESTS PASSED" -ForegroundColor Green; exit 0 }
else { Write-Host "$($script:fails) TEST(S) FAILED" -ForegroundColor Red; exit 1 }
