#requires -Version 5.1
<#
.SYNOPSIS
    Dependency-free tests for Get-WindowedRpt.ps1 (no Pester required).
.EXAMPLE
    .\Get-WindowedRpt.Tests.ps1     # exits 0 if all pass, 1 otherwise
#>
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Get-WindowedRpt.ps1')
$script:fails = 0
$enc = [System.Text.Encoding]::ASCII

function Assert($cond, $name) {
    if ($cond) { Write-Host "  PASS  $name" }
    else { Write-Host "  FAIL  $name" -ForegroundColor Red; $script:fails++ }
}

function New-Rpt([string[]]$lines) {
    $p = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($p, ($lines -join "`r`n"), $enc)
    return $p
}

Write-Host "TEST 1: missing RPT returns an empty array"
$missing = @(Get-WindowedRpt -RptPath (Join-Path ([System.IO.Path]::GetTempPath()) 'wasp_missing_windowed_rpt_test.rpt') -WarningAction SilentlyContinue)
Assert ($missing.Count -eq 0) "T1 missing file returns no lines"

$p = New-Rpt @(
    'boot line',
    'MISSINIT old match',
    'old warning',
    'MISSINIT current match',
    'current ok',
    'Error current'
)

Write-Host "TEST 2: the last MISSINIT marker opens the current window"
$lines = @(Get-WindowedRpt -RptPath $p)
Assert ($lines.Count -eq 3) "T2 current window has marker plus two current lines"
Assert ($lines[0] -eq 'MISSINIT current match') "T2 starts at the last marker"
Assert (($lines -contains 'old warning') -eq $false) "T2 excludes old-session lines"

Write-Host "TEST 3: Pattern filters within the current window"
$errs = @(Get-WindowedRpt -RptPath $p -Pattern 'Error')
Assert ($errs.Count -eq 1) "T3 one current error"
Assert ($errs[0] -eq 'Error current') "T3 current error text returned"

Write-Host "TEST 4: Tail limits the end of the current window"
$tail = @(Get-WindowedRpt -RptPath $p -Tail 1)
Assert ($tail.Count -eq 1) "T4 one tail line"
Assert ($tail[0] -eq 'Error current') "T4 tail is the final current line"

Remove-Item $p -Force

Write-Host "TEST 5: marker on the first line still returns the full file"
$p = New-Rpt @('MISSINIT first', 'line a', 'line b')
$lines = @(Get-WindowedRpt -RptPath $p)
Assert ($lines.Count -eq 3) "T5 full file returned"
Remove-Item $p -Force

Write-Host "TEST 6: negative Tail is rejected by parameter validation"
$p = New-Rpt @('MISSINIT first', 'line a')
$threw = $false
try { Get-WindowedRpt -RptPath $p -Tail -1 } catch { $threw = $true }
Assert ($threw -eq $true) "T6 throws on negative Tail"

Write-Host "TEST 7: empty WindowMarker is rejected by parameter validation"
$threw = $false
try { Get-WindowedRpt -RptPath $p -WindowMarker '' } catch { $threw = $true }
Assert ($threw -eq $true) "T7 throws on empty WindowMarker"
Remove-Item $p -Force

Write-Host ""
if ($script:fails -eq 0) { Write-Host "ALL TESTS PASSED" -ForegroundColor Green; exit 0 }
else { Write-Host "$($script:fails) TEST(S) FAILED" -ForegroundColor Red; exit 1 }
