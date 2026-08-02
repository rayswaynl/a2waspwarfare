#requires -Version 5.1
<#
  Dependency-free regression test for Start-WaspAutopilot's per-RPT retry contract.
  The temp harness makes the grader throw once, then succeed; a thrown grade must
  not enter processed.json or the second pass will silently skip that RPT forever.
#>
$ErrorActionPreference = 'Stop'

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

function Assert([bool]$Condition, [string]$Message) {
    if ($Condition) { Write-Host "  PASS  $Message" }
    else { throw "FAIL  $Message" }
}

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("wasp-autopilot-retry-" + [Guid]::NewGuid().ToString('N'))
$inbox = Join-Path $root 'inbox'
$results = Join-Path $root 'results'
$script = Join-Path $root 'Start-WaspAutopilot.ps1'
$stubScenario = Join-Path $root 'Get-ScenarioSpec.ps1'
$stubRun = Join-Path $root 'Run-Scenario.ps1'
$stubExperiment = Join-Path $root 'run_experiment.py'
$stubChart = Join-Path $root 'chart_soak.py'
$stubRecommendation = Join-Path $root 'Get-FlagRecommendation.ps1'
$rpt = Join-Path $inbox 'match.RPT'

try {
    New-Item -ItemType Directory -Force -Path $inbox | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Start-WaspAutopilot.ps1') -Destination $script
    Write-Utf8NoBom $rpt 'synthetic RPT'
    Write-Utf8NoBom $stubScenario @'
param([string]$Name, [string]$ScenariosPath)
[pscustomobject]@{ name = 'stub'; runs = @([pscustomobject]@{ runLabel = 'single' }) }
'@
    Write-Utf8NoBom $stubExperiment 'pass'
    Write-Utf8NoBom $stubChart 'pass'
    Write-Utf8NoBom $stubRecommendation @'
param([string]$FindingsPath, [string]$OutPath)
if ($OutPath) { [System.IO.File]::WriteAllText($OutPath, '') }
'@

    Write-Utf8NoBom $stubRun @'
param([string]$Name, [string]$FromRpt, [string]$LedgerPath, [string]$ResultsDir, [string]$HcRpt)
throw 'synthetic transient grader failure'
'@

    $null = & powershell -NoProfile -ExecutionPolicy Bypass -File $script `
        -Inbox $inbox -Scenario stub -LedgerPath (Join-Path $root 'ledger.jsonl') `
        -ResultsDir $results -FindingsPath (Join-Path $root 'findings.jsonl') `
        -ReportPath (Join-Path $root 'report.html')
    $processedPath = Join-Path $results 'processed.json'
    $processedAfterFailure = if (Test-Path -LiteralPath $processedPath) { Get-Content -Raw -LiteralPath $processedPath | ConvertFrom-Json } else { $null }
    Assert (($null -eq $processedAfterFailure) -or !($processedAfterFailure.PSObject.Properties.Name -contains 'match.RPT')) 'a thrown grader is not marked processed'

    Write-Utf8NoBom $stubRun @'
param([string]$Name, [string]$FromRpt, [string]$LedgerPath, [string]$ResultsDir, [string]$HcRpt)
[pscustomobject]@{ verdict = 'PASS' }
'@

    $second = (& powershell -NoProfile -ExecutionPolicy Bypass -File $script `
        -Inbox $inbox -Scenario stub -LedgerPath (Join-Path $root 'ledger.jsonl') `
        -ResultsDir $results -FindingsPath (Join-Path $root 'findings.jsonl') `
        -ReportPath (Join-Path $root 'report.html') | Out-String)
    Assert ($second -match 'graded 1 RPT') 'the next pass retries the RPT after a thrown grade'

    Write-Host 'ALL TESTS PASSED' -ForegroundColor Green
    exit 0
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
