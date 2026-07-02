#requires -Version 5.1
<#
.SYNOPSIS
    Dependency-free validation tests for Set-WaspCpuAffinity.ps1 (no Pester required).
.EXAMPLE
    .\Set-WaspCpuAffinity.Tests.ps1     # exits 0 if all pass, 1 otherwise
#>
$ErrorActionPreference = 'Stop'
$helper = Join-Path $PSScriptRoot 'Set-WaspCpuAffinity.ps1'
$script:fails = 0

function Assert($cond, $name) {
    if ($cond) { Write-Host "  PASS  $name" }
    else { Write-Host "  FAIL  $name" -ForegroundColor Red; $script:fails++ }
}

function Invoke-ExpectThrow([scriptblock]$body) {
    $threw = $false
    try { & $body } catch { $threw = $true }
    return $threw
}

Write-Host "TEST 1: negative server mask is rejected before process discovery"
$threw = Invoke-ExpectThrow { & $helper -ServerMask -1 }
Assert ($threw -eq $true) "T1 throws on negative ServerMask"

Write-Host "TEST 2: negative HC mask is rejected before process discovery"
$threw = Invoke-ExpectThrow { & $helper -HcMasks 1,-2 }
Assert ($threw -eq $true) "T2 throws on negative HcMasks entry"

Write-Host "TEST 3: LogicalProcessorCount rejects masks outside the declared CPU range"
$threw = Invoke-ExpectThrow { & $helper -ServerMask 0x4 -LogicalProcessorCount 2 }
Assert ($threw -eq $true) "T3 throws when CPU2 is outside a 2-logical-CPU range"

Write-Host "TEST 4: overlapping masks warn by default but do not fail"
$script:overlapOutput = @()
$threw = Invoke-ExpectThrow { $script:overlapOutput = @(& $helper -ServerMask 0x3 -HcMasks 0x2 3>&1) }
Assert ($threw -eq $false) "T4 overlap warning is non-fatal"
Assert (($script:overlapOutput | ForEach-Object { $_.ToString() } | Select-String -Pattern 'overlap').Count -gt 0) "T4 overlap warning captured"

Write-Host "TEST 5: StrictDisjoint upgrades overlap to an error"
$threw = Invoke-ExpectThrow { & $helper -ServerMask 0x3 -HcMasks 0x2 -StrictDisjoint }
Assert ($threw -eq $true) "T5 strict overlap throws"

Write-Host "TEST 6: dry-run with no masks is valid"
$threw = Invoke-ExpectThrow { & $helper }
Assert ($threw -eq $false) "T6 no-mask dry run succeeds"

Write-Host ""
if ($script:fails -eq 0) { Write-Host "ALL TESTS PASSED" -ForegroundColor Green; exit 0 }
else { Write-Host "$($script:fails) TEST(S) FAILED" -ForegroundColor Red; exit 1 }
