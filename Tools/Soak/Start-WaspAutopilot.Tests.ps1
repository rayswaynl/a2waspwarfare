<#
  Dependency-free assertion tests for Start-WaspAutopilot.ps1. Exit 0 pass / 1 fail.
  Exercises the grade-mode loop against the checked-in sample RPTs: plan, grade+conform, processed-set
  dedup, and the overlap guard.
#>
$ErrorActionPreference = 'Stop'
$here     = $PSScriptRoot
$script   = Join-Path $here 'Start-WaspAutopilot.ps1'
$validate = Join-Path $here 'validate_ledger.py'
$stateF   = Join-Path $here 'farm-state.json'
$recF     = Join-Path $here 'recommendations.jsonl'

$fail = 0
function Assert([bool]$c, [string]$m) { if ($c) { Write-Host "  ok   $m" } else { Write-Host "  FAIL $m" -ForegroundColor Red; $script:fail++ } }

$work  = Join-Path ([IO.Path]::GetTempPath()) ("wasp-ap-test-" + [guid]::NewGuid().ToString('N'))
$inbox = Join-Path $work 'inbox'; $results = Join-Path $work 'results'
New-Item -ItemType Directory -Force -Path $inbox | Out-Null
Copy-Item (Join-Path $here 'sample_build86.rpt') (Join-Path $inbox 'run1.RPT')
Copy-Item (Join-Path $here 'sample_cc44u.rpt')    (Join-Path $inbox 'run2.RPT')
$led  = Join-Path $work 'l.jsonl'
$find = Join-Path $work 'f.jsonl'
$rep  = Join-Path $work 'rep.html'
Remove-Item $stateF -ErrorAction SilentlyContinue

try {
    Write-Host "[1] -DryRun plan (no side effects)"
    $plan = (& $script -Inbox $inbox -Scenario idle-soak -LedgerPath $led -ResultsDir $results -FindingsPath $find -ReportPath $rep -DryRun) | Out-String
    Assert ($plan -match 'AUTOPILOT PLAN') "prints a plan"
    Assert ($plan -match 'run1.RPT' -and $plan -match 'run2.RPT') "lists inbox RPTs"
    Assert (-not (Test-Path $led)) "DryRun wrote no ledger"

    Write-Host "`n[2] live pass grades + ledger conforms"
    $r = & $script -Inbox $inbox -Scenario idle-soak -LedgerPath $led -ResultsDir $results -FindingsPath $find -ReportPath $rep
    Assert ($r.graded -eq 2)               "graded 2 RPTs"
    Assert ($r.skipped -eq 0)              "0 skip/fail"
    Assert (Test-Path $rep)                "chart report written"
    $rows = @([IO.File]::ReadAllLines($led) | Where-Object { $_.Trim() -and -not $_.StartsWith('#') })
    Assert ($rows.Count -eq 2)             "two ledger rows (distinct stampIds, no same-second collision)"
    $conf = & python $validate $led 2>&1 | Out-String
    Assert ($conf -match 'CONFORMANCE OK') "ledger conforms (roundend flattened to string)"
    Assert ($r.findings -ge 1)             "at least one finding emitted (hc-split INCONCLUSIVE, honest)"

    Write-Host "`n[3] processed-set dedup on re-run"
    $r2 = & $script -Inbox $inbox -Scenario idle-soak -LedgerPath $led -ResultsDir $results -FindingsPath $find -ReportPath $rep
    Assert ($r2.graded -eq 0)              "re-run grades 0 new (processed-set dedup)"

    Write-Host "`n[4] overlap guard"
    $ep = [long]((((Get-Date).ToUniversalTime()) - [datetime]::new(1970, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)).TotalSeconds)
    @{ running = $true; startedEpoch = $ep; startedUtc = (Get-Date).ToUniversalTime().ToString('o'); host = 'x' } | ConvertTo-Json | Set-Content $stateF -Encoding utf8
    $g = (& $script -Inbox $inbox -Scenario idle-soak -LedgerPath (Join-Path $work 'l2.jsonl') -ResultsDir (Join-Path $work 'r2') -FindingsPath (Join-Path $work 'f2.jsonl')) | Out-String
    Assert ($g -match 'OVERLAP GUARD') "second concurrent pass refuses (guard honors UTC 'Z')"
    Assert (-not (Test-Path (Join-Path $work 'l2.jsonl'))) "guarded pass wrote nothing"
}
finally {
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $stateF, $recF -ErrorAction SilentlyContinue
}

Write-Host ""
if ($fail -gt 0) { Write-Host "FAILED ($fail)" -ForegroundColor Red; exit 1 }
Write-Host "PASSED" -ForegroundColor Green; exit 0
