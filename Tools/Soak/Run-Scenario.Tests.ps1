<#
  Dependency-free assertion tests for Run-Scenario.ps1. Exit 0 pass / 1 fail.
  Exercises the plan (-DryRun) path and the grade (-FromRpt) path against the checked-in sample RPT.
#>
$ErrorActionPreference = 'Stop'
$here    = $PSScriptRoot
$script  = Join-Path $here 'Run-Scenario.ps1'
$sample  = Join-Path $here 'sample_build86.rpt'
$validate= Join-Path $here 'validate_ledger.py'

$fail = 0
function Assert([bool]$cond, [string]$msg) {
    if ($cond) { Write-Host "  ok   $msg" } else { Write-Host "  FAIL $msg" -ForegroundColor Red; $script:fail++ }
}

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("wasp-scenario-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $work | Out-Null
$ledger  = Join-Path $work 'soak-ledger.jsonl'
$results = Join-Path $work 'results'

try {
    Write-Host "[1] -DryRun renders a plan (no side effects)"
    $plan = (& $script -Name defend-town -DryRun) | Out-String
    Assert ($plan -match 'SCENARIO\s+defend-town')  "plan names the scenario"
    Assert ($plan -match '55-2hc.*chernarus')        "plan shows resolved template"
    Assert ($plan -match 'LAUNCH PLAN')              "plan shows launch commands"
    Assert ($plan -match 'ASSERTS')                  "plan lists asserts"
    Assert (-not (Test-Path $ledger))                "DryRun wrote no ledger"

    Write-Host "`n[2] -FromRpt grades the sample -> FAIL (boot-smoke SELFTEST evidence is absent)"
    $r = & $script -Name idle-soak -FromRpt $sample -LedgerPath $ledger -ResultsDir $results
    Assert ($r.verdict -eq 'FAIL')                   "idle-soak boot-smoke verdict FAIL ($($r.verdict))"
    Assert ($r.metrics.serverFpsMedian -eq 42)       "metrics.serverFpsMedian = 42"
    Assert ($r.metrics.aiTotPeak -eq 105)            "metrics.aiTotPeak = 105"
    Assert (-not [string]::IsNullOrWhiteSpace($r.ledgerRowId)) "ledgerRowId set ($($r.ledgerRowId))"
    Assert (Test-Path (Join-Path $results "$($r.runId).json")) "Run-Result JSON written"
    Assert ($r.bootSmoke.ran -eq $true)              "boot-smoke ran"
    Assert ($r.bootSmoke.verdict -eq 'FAIL')         "boot-smoke FAIL propagated"

    Write-Host "`n[3] ledger row is well-formed + carries scenario notes"
    Assert (Test-Path $ledger)                       "ledger created"
    $row = ([System.IO.File]::ReadAllLines($ledger) | Where-Object { $_.Trim() -and -not $_.StartsWith('#') } | Select-Object -First 1) | ConvertFrom-Json
    Assert ($row.status -eq 'POSTED_LEDGER_ONLY')    "row status POSTED_LEDGER_ONLY"
    Assert (($row.notes -join ' ') -match 'scenario=idle-soak') "row notes record the scenario"
    Assert ($row.lenses.overall -eq 'FAIL')          "row lens overall FAIL"
    $vout = & python $validate $ledger 2>&1 | Out-String
    Assert ($vout -match 'CONFORMANCE OK')           "ledger conforms to run_result.schema.json"

    Write-Host "`n[4] boot-smoke hard FAIL outranks a missed watch assert"
    $r2 = & $script -Name big-assault -FromRpt $sample -LedgerPath $ledger -ResultsDir $results
    Assert ($r2.verdict -eq 'FAIL')                  "big-assault verdict FAIL ($($r2.verdict))"
    $missed = @($r2.asserts | Where-Object { $_.pass -eq $false })
    Assert ($missed.Count -ge 1)                      "at least one assert recorded as missed"
    $aiMiss = @($missed | Where-Object { $_.metric -eq 'aiTotPeak' })
    Assert ($aiMiss.Count -eq 1 -and $aiMiss[0].actual -eq 105) "aiTotPeak miss captured with actual value (105)"

    Write-Host "`n[5] second grade increments ledger rowId (shared file)"
    $rows = @([System.IO.File]::ReadAllLines($ledger) | Where-Object { $_.Trim() -and -not $_.StartsWith('#') })
    Assert ($rows.Count -eq 2)                        "two rows in the ledger after two grades"
}
finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
if ($fail -gt 0) { Write-Host "FAILED ($fail)" -ForegroundColor Red; exit 1 }
Write-Host "PASSED" -ForegroundColor Green; exit 0
