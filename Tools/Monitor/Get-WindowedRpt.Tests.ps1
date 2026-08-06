#requires -Version 5.1
<#
.SYNOPSIS
    Dependency-free tests for Get-WindowedRpt.ps1.
.EXAMPLE
    .\Get-WindowedRpt.Tests.ps1
#>
$ErrorActionPreference = 'Stop'
$helper = Join-Path $PSScriptRoot 'Get-WindowedRpt.ps1'
. $helper

$script:fails = 0
$enc = [System.Text.Encoding]::ASCII

function Assert($cond, $name) {
    if ($cond) { Write-Host "  PASS  $name" }
    else { Write-Host "  FAIL  $name" -ForegroundColor Red; $script:fails++ }
}

function New-RptFile([string[]]$Lines) {
    $p = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($p, ($Lines -join "`r`n"), $enc)
    return $p
}

Write-Host "TEST 1: default window starts at the last MISSINIT marker"
$p = New-RptFile @(
    'old boot line',
    'MISSINIT first mission',
    'first mission stale error',
    'MISSINIT second mission',
    'alpha',
    'ERROR beta',
    'gamma'
)
$r = @(Get-WindowedRpt -RptPath $p)
Assert (($r -join '|') -eq 'MISSINIT second mission|alpha|ERROR beta|gamma') "T1 last mission window only"
Remove-Item $p -Force

Write-Host "TEST 2: Pattern filters inside the selected window only"
$p = New-RptFile @(
    'ERROR stale before marker',
    'MISSINIT current',
    'alpha',
    'ERROR current',
    'gamma'
)
$r = @(Get-WindowedRpt -RptPath $p -Pattern 'ERROR')
Assert (($r -join '|') -eq 'ERROR current') "T2 stale pre-window match excluded"
Remove-Item $p -Force

Write-Host "TEST 3: Tail returns the last N selected lines"
$p = New-RptFile @(
    'MISSINIT current',
    'one',
    'two',
    'three'
)
$r = @(Get-WindowedRpt -RptPath $p -Tail 2)
Assert (($r -join '|') -eq 'two|three') "T3 tail keeps final two lines"
Remove-Item $p -Force

Write-Host "TEST 4: custom boot marker can select a boot window"
$p = New-RptFile @(
    'stale',
    'Dedicated host created',
    'boot line',
    'MISSINIT mission',
    'mission line'
)
$r = @(Get-WindowedRpt -RptPath $p -WindowMarker 'Dedicated host created')
Assert (($r -join '|') -eq 'Dedicated host created|boot line|MISSINIT mission|mission line') "T4 custom marker window"
Remove-Item $p -Force

Write-Host "TEST 5: missing RPT returns an empty array"
$missing = Join-Path ([System.IO.Path]::GetTempPath()) ('missing-' + [guid]::NewGuid().ToString() + '.rpt')
$r = @(Get-WindowedRpt -RptPath $missing -WarningAction SilentlyContinue)
Assert ($r.Count -eq 0) "T5 missing file is empty result"

Write-Host "TEST 6: negative Tail is rejected"
$p = New-RptFile @('MISSINIT current', 'one')
$threw = $false
try { $null = Get-WindowedRpt -RptPath $p -Tail -1 } catch { $threw = $true }
Assert ($threw) "T6 throws on negative Tail"
Remove-Item $p -Force

Write-Host "TEST 7: empty WindowMarker is rejected"
$p = New-RptFile @('MISSINIT current', 'one')
$threw = $false
try { $null = Get-WindowedRpt -RptPath $p -WindowMarker '' } catch { $threw = $true }
Assert ($threw) "T7 throws on empty WindowMarker"
Remove-Item $p -Force

Write-Host "TEST 8: RequireWindowMarker fails closed when the marker is absent"
$p = New-RptFile @('old boot line', 'ERROR stale-session')
$threw = $false
$r = @()
try { $r = @(Get-WindowedRpt -RptPath $p -RequireWindowMarker -WarningAction SilentlyContinue) } catch { $threw = $true }
Assert (-not $threw -and $r.Count -eq 0) "T8 missing required marker returns an empty window"
Remove-Item $p -Force

Write-Host "TEST 9: default missing-marker fallback remains compatible"
$p = New-RptFile @('early boot line', 'early boot warning')
$r = @(Get-WindowedRpt -RptPath $p -WarningAction SilentlyContinue)
Assert ($r.Count -eq 2) "T9 default mode retains the legacy whole-file fallback"
Remove-Item $p -Force

Write-Host "TEST 10: boot-smoke uses the fail-closed window mode"
$smokePath = Join-Path $PSScriptRoot '..\Smoke\Test-WaspBootSmoke.ps1'
$smokeText = Get-Content -LiteralPath $smokePath -Raw
Assert ($smokeText -match 'Get-WindowedRpt\s+-RptPath\s+\$ServerRpt\s+-RequireWindowMarker') "T10 boot-smoke requires a current window marker"

Write-Host ""
if ($script:fails -eq 0) { Write-Host "ALL TESTS PASSED" -ForegroundColor Green; exit 0 }
else { Write-Host "$($script:fails) TEST(S) FAILED" -ForegroundColor Red; exit 1 }
