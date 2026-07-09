<#
.SYNOPSIS
  Grade-mode autopilot pass: grade an inbox of RPTs, run ready A/B experiments, refresh charts, and
  surface flag recommendations. Read-only w.r.t. the game; never spawns Arma, never deploys.

.DESCRIPTION
  One pass of the closed loop the design calls for, in the mode that works TODAY (no live boot):

    inbox RPTs --Run-Scenario -FromRpt--> ledger rows (incl. SKIP_/FAIL_ on bad RPTs)
               --run_experiment.py------> findings (INCONCLUSIVE until n>=5 per arm -- honest)
               --chart_soak.py----------> refreshed HTML report
               --Get-FlagRecommendation-> surface-only recommendation deck

  Overlap-guarded via farm-state.json (won't run two passes at once). Intended to be driven by a BOX
  scheduled task -- NEVER a Claude cron. -DryRun prints the plan with no side effects.

  Live boot + self-generated matched replicates (which turn most INCONCLUSIVE findings decisive) are
  the sandbox-boot track; this orchestrator front-swaps to that with no change to the measure/decide
  /report/recommend path.

.NOTES
  A2-OA-1.64 project tooling; no mission code, no SQF, no flag. Guide rev GR-2026-07-03a.
#>
[CmdletBinding()]
param(
    [string] $Inbox,
    [string] $Scenario = 'idle-soak',
    [string] $HcInboxSuffix = '.hc.RPT',
    [string] $LedgerPath,
    [string] $ResultsDir,
    [string] $FindingsPath,
    [string] $ReportPath,
    [switch] $Report,
    [switch] $Peach,
    [switch] $DryRun,
    [int]    $OverlapGuardMinutes = 30
)
$ErrorActionPreference = 'Stop'
$soakDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($LedgerPath))   { $LedgerPath   = Join-Path $soakDir 'soak-ledger.jsonl' }
if ([string]::IsNullOrWhiteSpace($ResultsDir))   { $ResultsDir   = Join-Path $soakDir 'results' }
if ([string]::IsNullOrWhiteSpace($FindingsPath)) { $FindingsPath = Join-Path $soakDir 'findings.jsonl' }
if ([string]::IsNullOrWhiteSpace($ReportPath))   { $ReportPath   = Join-Path $ResultsDir 'soak-report.html' }
$stateF     = Join-Path $soakDir 'farm-state.json'
$processedF = Join-Path $ResultsDir 'processed.json'
$runScen    = Join-Path $soakDir 'Run-Scenario.ps1'
$runExp     = Join-Path $soakDir 'run_experiment.py'
$charter    = Join-Path $soakDir 'chart_soak.py'
$recommender= Join-Path $soakDir 'Get-FlagRecommendation.ps1'

function Now { (Get-Date).ToUniversalTime() }
# Epoch seconds for overlap timing. ISO strings are unsafe here: ConvertFrom-Json auto-parses them
# into local [datetime]s, and re-parsing double-shifts by the machine's UTC offset. A plain number
# round-trips through JSON unchanged.
function NowEpoch { [long]((( (Get-Date).ToUniversalTime() ) - [datetime]::new(1970, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)).TotalSeconds) }
function Save-Json($obj, $path) {
    $enc = New-Object System.Text.UTF8Encoding($false)
    $json = if ($PSVersionTable.PSVersion.Major -ge 6) { $obj | ConvertTo-Json -Depth 12 }
            else { Add-Type -AssemblyName System.Web.Extensions; (New-Object System.Web.Script.Serialization.JavaScriptSerializer).Serialize($obj) }
    [System.IO.File]::WriteAllText($path, $json, $enc)
}
function Load-Json($path) { if (Test-Path -LiteralPath $path) { try { return ([System.IO.File]::ReadAllText($path) | ConvertFrom-Json) } catch {} } return $null }

# ---- inbox discovery ----
$rpts = @()
if (-not [string]::IsNullOrWhiteSpace($Inbox) -and (Test-Path -LiteralPath $Inbox)) {
    $rpts = @(Get-ChildItem -LiteralPath $Inbox -Filter '*.RPT' -ErrorAction SilentlyContinue |
              Where-Object { $_.Name -notlike "*$HcInboxSuffix" } | Sort-Object Name)
}
$processed = @{}
$pj = Load-Json $processedF
if ($pj) { foreach ($p in $pj.PSObject.Properties.Name) { $processed[$p] = $true } }
$todo = @($rpts | Where-Object { -not $processed[$_.Name] })

if ($DryRun) {
    Write-Output "AUTOPILOT PLAN (dry run -- no side effects)"
    Write-Output "  inbox        : $Inbox"
    Write-Output "  RPTs to grade: $($todo.Count) new / $($rpts.Count) total (scenario '$Scenario')"
    foreach ($r in $todo) { Write-Output "     - $($r.Name)" }
    Write-Output "  experiments  : hc-split-benefit (serverFpsMedian, hcCount=1 vs 2)"
    Write-Output "  outputs      : ledger=$LedgerPath  findings=$FindingsPath  report=$ReportPath"
    Write-Output "  recommender  : surface-only deck (owner decides)"
    return
}

# ---- overlap guard (epoch-based; see NowEpoch note) ----
$state = Load-Json $stateF
if ($state -and $state.running -and $state.startedEpoch) {
    $ageMin = ((NowEpoch) - [long]$state.startedEpoch) / 60.0
    if ($ageMin -lt $OverlapGuardMinutes) {
        Write-Output "OVERLAP GUARD: a pass started $([int]$ageMin) min ago is still marked running; refusing. (clear farm-state.json to override)"
        return
    }
}
Save-Json ([ordered]@{ running = $true; startedEpoch = (NowEpoch); startedUtc = (Now).ToString('o'); host = $env:COMPUTERNAME }) $stateF

$graded = 0; $skipped = 0
try {
    New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null

    # ---- phase 1: grade the inbox ----
    foreach ($r in $todo) {
        $hc = Join-Path (Split-Path $r.FullName -Parent) ($r.BaseName + $HcInboxSuffix)
        $sp = @{ Name = $Scenario; FromRpt = $r.FullName; LedgerPath = $LedgerPath; ResultsDir = $ResultsDir }
        if (Test-Path -LiteralPath $hc) { $sp.HcRpt = $hc }
        try {
            $res = & $runScen @sp
            if ($res -and $res.verdict -like 'SKIP_*') { $skipped++ } elseif ($res -and $res.verdict -like 'FAIL_*') { $skipped++ } else { $graded++ }
        } catch { Write-Host "  grade error on $($r.Name): $_"; $skipped++ }
        $processed[$r.Name] = (Now).ToString('o')
    }
    Save-Json $processed $processedF

    # ---- phase 2: run ready A/B experiments (grade-derivable arms) ----
    # hc-split-benefit: serverFpsMedian at hcCount=1 vs 2. INCONCLUSIVE until n>=5 per arm (honest).
    & python $runExp --results $ResultsDir --findings $FindingsPath --experiment 'hc-split-benefit' `
        --scenario 'hc-split' --metric 'serverFpsMedian' --arm-a 'hcCount=1' --arm-b 'hcCount=2' `
        --regime 'hc-split/serverFpsMedian' --emit 2>$null | Out-Null

    # ---- phase 3: refresh charts (always -- the report is the owner-facing artifact) ----
    & python $charter --ledger $LedgerPath --results $ResultsDir --findings $FindingsPath --out $ReportPath 2>$null | Out-Null

    # ---- phase 4: surface recommendations ----
    & $recommender -FindingsPath $FindingsPath -OutPath (Join-Path $soakDir 'recommendations.jsonl') | Out-Null
}
finally {
    Save-Json ([ordered]@{ running = $false; finishedUtc = (Now).ToString('o'); host = $env:COMPUTERNAME }) $stateF
}

# ---- summary ----
$findingCount = 0; if (Test-Path $FindingsPath) { $findingCount = @([System.IO.File]::ReadAllLines($FindingsPath) | Where-Object { $_.Trim() -and -not $_.StartsWith('#') }).Count }
$msg = "Autopilot pass: graded $graded RPT(s), $skipped skip/fail, $findingCount finding(s). report=$ReportPath"
Write-Host ""
Write-Host $msg
if ($Peach) {
    $peachTool = 'C:\Users\Game\wasp-build\peach-dm.ps1'
    if (Test-Path -LiteralPath $peachTool) {
        try { & pwsh -NoProfile -File $peachTool -Text "[autopilot] $msg" | Out-Null; Write-Host "  (Peach DM sent)" } catch { Write-Host "  (Peach DM failed: $_)" }
    }
    # ...and to the WASP Discord channel via the "Warfare Handler" bot (best-effort; no-op until the
    # bot is granted View+Send on the channel).
    $whTool = 'C:\Users\Game\wasp-build\warfare-handler-post.ps1'
    if (Test-Path -LiteralPath $whTool) {
        try { & pwsh -NoProfile -File $whTool -Text "[autopilot] $msg" | Out-Null } catch {}
    }
}
return [ordered]@{ graded = $graded; skipped = $skipped; findings = $findingCount; report = $ReportPath }
