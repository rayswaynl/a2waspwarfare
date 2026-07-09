<#
  Dependency-free assertion tests for Append-LedgerRow.ps1 (no Pester).
  Exits 0 on pass, 1 on first failure. Mirrors the existing Tools/Ops/*.Tests.ps1 style
  so it can wire into the CI "PowerShell tool tests (blocking)" step.

  Covers the SPEC-SOAK-LEDGER-CONTRACT.md test matrix:
    - monotonic rowId across appends
    - skip row => KPI values are null, not zero
    - duplicate successful stampId is rejected (nothing appended)
    - '#' comment lines are preserved and skipped by the reader
    - every row carries schema = a2wasp-soak-ledger-row-v1
  Plus: analyzer-JSON -> row field mapping against the real sample RPT, and the
  single-element notes array survives serialization (5.1 collapse guard).
#>
$ErrorActionPreference = 'Stop'
$here     = $PSScriptRoot
$script   = Join-Path $here 'Append-LedgerRow.ps1'
$analyzer = Join-Path $here 'analyze_soak.py'
$sample   = Join-Path $here 'sample_build86.rpt'

$fail = 0
function Assert([bool]$cond, [string]$msg) {
    if ($cond) { Write-Host "  ok   $msg" }
    else { Write-Host "  FAIL $msg" -ForegroundColor Red; $script:fail++ }
}
function Read-Rows([string]$path) {
    $rows = @()
    foreach ($ln in [System.IO.File]::ReadAllLines($path)) {
        $t = $ln.Trim(); if ($t.Length -eq 0 -or $t.StartsWith('#')) { continue }
        $rows += ($t | ConvertFrom-Json)
    }
    return $rows
}

# ---- scratch workspace -----------------------------------------------------
$work   = Join-Path ([System.IO.Path]::GetTempPath()) ("wasp-ledger-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $work | Out-Null
$ledger = Join-Path $work 'soak-ledger.jsonl'
$aJson  = Join-Path $work 'analyze.json'

try {
    # deploy stamps
    $stampA = Join-Path $work 'stampA.json'
    $stampB = Join-Path $work 'stampB.json'
    @{ stampId='candA-20260707-000000Z'; candidate='candA'; terrain='chernarus'; role='deploy-candidate'; pboName='candA.chernarus.pbo'; operator='Ray' } | ConvertTo-Json | Set-Content -LiteralPath $stampA -Encoding utf8
    @{ stampId='candB-20260707-000100Z'; candidate='candB'; terrain='zargabad';  role='deploy-candidate'; pboName='candB.zargabad.pbo';  operator='Ray' } | ConvertTo-Json | Set-Content -LiteralPath $stampB -Encoding utf8

    # real analyzer JSON from the checked-in sample RPT
    & python $analyzer $sample --json 2>$null | Out-File -LiteralPath $aJson -Encoding utf8
    Assert ((Test-Path $aJson) -and ((Get-Item $aJson).Length -gt 0)) "analyze_soak.py produced analyzer JSON"

    Write-Host "`n[1] monotonic rowId + analyzer mapping"
    $id1 = & $script -LedgerPath $ledger -Status POSTED -StampPath $stampA -AnalyzeJsonPath $aJson
    $id2 = & $script -LedgerPath $ledger -Status POSTED -StampPath $stampB -AnalyzeJsonPath $aJson
    Assert ($id1 -match '^\d{8}-0001$') "first rowId ends -0001 ($id1)"
    Assert ($id2 -match '^\d{8}-0002$') "second rowId ends -0002 ($id2)"

    $rows = Read-Rows $ledger
    Assert ($rows.Count -eq 2) "two data rows present"
    $r1 = $rows[0]
    Assert ($r1.analyzer.perf.serverFpsMedian -eq 42)   "perf.serverFpsMedian mapped from fps[] (=42)"
    Assert ($r1.analyzer.perf.aiTotPeak -eq 105)        "perf.aiTotPeak mapped from ai_tot[] (=105)"
    Assert ($r1.analyzer.perf.guerPeak -eq 10)          "perf.guerPeak mapped from guer[] (=10)"
    Assert ($r1.analyzer.hold.maxTownsWest -eq 12)      "hold.maxTownsWest mapped from max_towns.WEST (=12)"
    Assert ($r1.analyzer.hold.maxTownsEast -eq 0)       "hold.maxTownsEast mapped (=0, real zero)"
    Assert ($r1.analyzer.churn.frontChangesWest -eq 1)  "churn.frontChangesWest mapped from front_changes.WEST (=1)"
    Assert ($r1.analyzer.warStateExt.present -eq $false) "warStateExt.present mapped (=false)"
    Assert ($r1.analyzer.perf.hc2FpsMedian -eq $null)   "perf.hc2FpsMedian null when hc2fps all-null"

    Write-Host "`n[2] skip row => KPI null, not zero"
    $id3 = & $script -LedgerPath $ledger -Status SKIP_BOX_DOWN -StampPath $stampA -AllowDuplicateSkip -Note 'box unreachable'
    $rows = Read-Rows $ledger
    $r3 = $rows | Where-Object { $_.rowId -eq $id3 }
    Assert ($null -ne $r3) "skip row appended ($id3)"
    Assert ($r3.analyzer.perf.serverFpsMedian -eq $null) "skip perf.serverFpsMedian is null (not 0)"
    Assert ($r3.analyzer.hold.captures -eq $null)        "skip hold.captures is null (not 0)"
    Assert ($r3.lenses.overall -eq 'SKIP')               "skip lenses.overall = SKIP"
    Assert (@($r3.notes).Count -eq 1 -and $r3.notes[0] -eq 'box unreachable') "single-element notes survives as array"

    Write-Host "`n[3] duplicate successful stampId rejected"
    $before = (Read-Rows $ledger).Count
    $threw = $false
    try { & $script -LedgerPath $ledger -Status POSTED -StampPath $stampA -AnalyzeJsonPath $aJson | Out-Null }
    catch { $threw = $true }
    $after = (Read-Rows $ledger).Count
    Assert $threw "duplicate POSTED stampId throws"
    Assert ($after -eq $before) "nothing appended on rejected duplicate ($before -> $after)"

    Write-Host "`n[4] header + schema invariants"
    $firstLine = ([System.IO.File]::ReadAllLines($ledger))[0]
    Assert ($firstLine.StartsWith('#')) "first line is the '#' header comment"
    $rows = Read-Rows $ledger
    Assert (($rows | Where-Object { $_.schema -ne 'a2wasp-soak-ledger-row-v1' }).Count -eq 0) "every row schema = a2wasp-soak-ledger-row-v1"
    Assert (($rows | Where-Object { $_.rowId -notmatch '^\d{8}-\d{4}$' }).Count -eq 0) "every rowId matches YYYYMMDD-NNNN"

    Write-Host "`n[5] non-skip row without a stamp is rejected"
    $threw = $false
    try { & $script -LedgerPath $ledger -Status POSTED | Out-Null } catch { $threw = $true }
    Assert $threw "POSTED without -StampPath throws"
}
finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
if ($fail -gt 0) { Write-Host "FAILED ($fail assertion(s))" -ForegroundColor Red; exit 1 }
Write-Host "PASSED" -ForegroundColor Green; exit 0
