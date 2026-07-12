<#
  Dependency-free assertion tests for Get-ScenarioSpec.ps1. Exit 0 pass / 1 fail.
#>
$ErrorActionPreference = 'Stop'
$here   = $PSScriptRoot
$script = Join-Path $here 'Get-ScenarioSpec.ps1'

$fail = 0
function Assert([bool]$cond, [string]$msg) {
    if ($cond) { Write-Host "  ok   $msg" } else { Write-Host "  FAIL $msg" -ForegroundColor Red; $script:fail++ }
}

Write-Host "[1] -List"
$list = & $script -List | Out-String
Assert ($list -match 'defend-town') "-List includes defend-town"
Assert ($list -match 'hc-split')    "-List includes hc-split"

Write-Host "`n[2] single scenario resolves + template"
$d = & $script -Name defend-town
Assert ($d.runs.Count -eq 1)                            "defend-town has 1 run"
Assert ($d.runs[0].map -eq 'chernarus')                "map = chernarus"
Assert ($d.runs[0].template -eq '[55-2hc]warfarev2_073v48co.chernarus') "template resolved"
Assert ($d.runs[0].popPin -eq 6)                       "popPin = 6"
Assert ($d.runs[0].hcCount -eq 1)                      "hcCount = 1"

Write-Host "`n[3] popPin sweep (load-ramp)"
$lr = & $script -Name load-ramp
Assert ($lr.runs.Count -eq 4)                          "load-ramp expands to 4 runs"
Assert ($lr.runs[0].runLabel -eq 'pin3')               "first sweep label pin3"
Assert ($lr.runs[3].popPin -eq 14)                     "last sweep popPin 14"
Assert (($lr.runs | ForEach-Object { $_.hcCount } | Sort-Object -Unique).Count -eq 1) "hcCount constant across popPin sweep"

Write-Host "`n[4] hcCount sweep (hc-split)"
$hs = & $script -Name hc-split
Assert ($hs.runs.Count -eq 2)                          "hc-split expands to 2 runs"
Assert ($hs.runs[0].hcCount -eq 1 -and $hs.runs[1].hcCount -eq 2) "hcCount sweeps 1 then 2"
Assert (($hs.runs[0].popPin -eq $hs.runs[1].popPin))   "popPin constant across HC sweep"
Assert ($hs.runs[0].map -eq 'zargabad')                "hc-split map = zargabad"

Write-Host "`n[5] overrides"
$o = & $script -Name defend-town -Map zargabad -PopPin 9 -HcCount 2
Assert ($o.runs[0].map -eq 'zargabad')                 "-Map override applied"
Assert ($o.runs[0].template -eq '[61-2hc]warfarev2_073v48co.zargabad') "template follows override map"
Assert ($o.runs[0].popPin -eq 9)                       "-PopPin override applied"
Assert ($o.runs[0].hcCount -eq 2)                      "-HcCount override applied"

Write-Host "`n[6] flags + requires"
$al = & $script -Name a-life-probe
Assert ($al.base.flags['WFBE_C_GUER_DIRECTOR'] -eq 1)  "a-life-probe sets WFBE_C_GUER_DIRECTOR=1"
$fp = & $script -Name flight-probe
Assert (@($fp.requires) -contains 'WFBE_C_TEST_VERBS')  "flight-probe requires WFBE_C_TEST_VERBS"

Write-Host "`n[7] unknown scenario throws"
$threw = $false
try { & $script -Name nope-nope | Out-Null } catch { $threw = $true }
Assert $threw "unknown scenario name throws"

Write-Host ""
if ($fail -gt 0) { Write-Host "FAILED ($fail)" -ForegroundColor Red; exit 1 }
Write-Host "PASSED" -ForegroundColor Green; exit 0
