<#
.SYNOPSIS
  Plan or grade a named WASP sandbox scenario, emitting a Standard Run-Result JSON + a soak-ledger row.

.DESCRIPTION
  Two modes (this tool never spawns Arma itself -- live boot orchestration is the sandbox-boot
  track; keeping the driver spawn-free makes it safe and fully testable):

    -DryRun   Resolve the scenario and print the run plan: config, the server/HC launch command
              lines it *would* use, the flags to inject, and the threshold asserts. No side effects.

    -FromRpt  Grade an already-produced server RPT (+ optional -HcRpt): run analyze_soak.py, compute
              the flat metrics the asserts reference, evaluate the verdict, run the boot-smoke gate if
              present, write results/<runId>.json, append a soak-ledger row, and (optionally) DM a
              plain-English summary to the owner via Peach.

  Metrics referenced by scenario asserts (see scenarios.json): serverFpsMedian, serverFpsMin,
  hcFpsMedian, hc2FpsMedian, aiTotPeak, guerPeak, captures, arrivalPct, maxTownsWest, maxTownsEast, hours.

.NOTES
  A2-OA-1.64 project tooling; no mission code touched. Guide rev GR-2026-07-03a.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $Name,
    [string] $RunLabel,
    [switch] $DryRun,
    [string] $FromRpt,
    [string] $HcRpt,
    [string] $ScenariosPath,
    [string] $LedgerPath,
    [string] $ResultsDir,
    [string] $StampPath,
    [string] $Map,
    [int]    $HcCount = -999,
    [int]    $PopPin  = -999,
    [int]    $DurationMin = -999,
    # rig paths used only to render the launch plan (no process is started here)
    [string] $RigRoot   = 'C:\Users\Game\a2oa-local-1.64',
    [string] $A2Content = 'C:\Users\Game\a2-co\Arma 2',
    [switch] $Peach,
    [switch] $Report,
    [string] $ReportPath
)

$ErrorActionPreference = 'Stop'
$soakDir  = $PSScriptRoot
$specTool = Join-Path $soakDir 'Get-ScenarioSpec.ps1'
$analyzer = Join-Path $soakDir 'analyze_soak.py'
$appender = Join-Path $soakDir 'Append-LedgerRow.ps1'
if ([string]::IsNullOrWhiteSpace($ScenariosPath)) { $ScenariosPath = Join-Path $soakDir 'scenarios.json' }
if ([string]::IsNullOrWhiteSpace($LedgerPath))    { $LedgerPath    = Join-Path $soakDir 'soak-ledger.jsonl' }
if ([string]::IsNullOrWhiteSpace($ResultsDir))    { $ResultsDir    = Join-Path $soakDir 'results' }

# ---- helpers ---------------------------------------------------------------
function Get-Median($values) {
    $nums = @(); foreach ($v in @($values)) { if ($null -ne $v) { $nums += [double]$v } }
    if ($nums.Count -eq 0) { return $null }
    $sorted = $nums | Sort-Object; $n = $sorted.Count
    if ($n % 2 -eq 1) { return [double]$sorted[[int](($n - 1) / 2)] }
    return (([double]$sorted[$n/2 - 1] + [double]$sorted[$n/2]) / 2.0)
}
function Get-Min($values) { $nums=@(); foreach($v in @($values)){ if($null -ne $v){$nums+=[double]$v} }; if($nums.Count -eq 0){return $null}; return ($nums | Measure-Object -Minimum).Minimum }
function Get-Max($values) { $nums=@(); foreach($v in @($values)){ if($null -ne $v){$nums+=[double]$v} }; if($nums.Count -eq 0){return $null}; return ($nums | Measure-Object -Maximum).Maximum }
function Round1($x){ if($null -eq $x){return $null} return [math]::Round([double]$x,1) }
function ToJson($obj){
    if ($PSVersionTable.PSVersion.Major -ge 6) { return ($obj | ConvertTo-Json -Depth 30) }
    Add-Type -AssemblyName System.Web.Extensions -ErrorAction Stop
    $ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    $ser.MaxJsonLength = [int]::MaxValue; return $ser.Serialize($obj)
}
function FlagPairs($flags){
    $out = @(); if ($null -eq $flags) { return $out }
    if ($flags -is [System.Collections.IDictionary]) { foreach ($k in $flags.Keys) { $out += "$k=$($flags[$k])" } }
    else { foreach ($p in $flags.PSObject.Properties) { $out += "$($p.Name)=$($p.Value)" } }
    return $out
}

# ---- resolve scenario ------------------------------------------------------
$specArgs = @{ Name = $Name; ScenariosPath = $ScenariosPath }
if (-not [string]::IsNullOrWhiteSpace($Map)) { $specArgs.Map = $Map }
if ($HcCount -ne -999)     { $specArgs.HcCount = $HcCount }
if ($PopPin  -ne -999)     { $specArgs.PopPin = $PopPin }
if ($DurationMin -ne -999) { $specArgs.DurationMin = $DurationMin }
$spec = & $specTool @specArgs

# choose the run (by label, else the first)
$run = $spec.runs[0]
if (-not [string]::IsNullOrWhiteSpace($RunLabel)) {
    $match = $spec.runs | Where-Object { $_.runLabel -eq $RunLabel }
    if (-not $match) { throw "No run labelled '$RunLabel' in scenario '$Name'. Have: $(($spec.runs | ForEach-Object { $_.runLabel }) -join ', ')" }
    $run = $match
}

$mods = '"' + ($A2Content + ';expansion;@CBA_CO;@adwasp;@admkswf') + '"'
$serverExe = Join-Path $RigRoot 'ArmA2OA.exe'
$serverCmd = "`"$serverExe`" -server -port=2402 -config=$RigRoot\sandbox-server.cfg -cfg=$RigRoot\sandbox-basic.cfg -profiles=$RigRoot\prof -mod=$mods -world=empty"
$hcCmds = @()
for ($i = 1; $i -le [int]$run.hcCount; $i++) {
    $hcCmds += "`"$serverExe`" -client -connect=127.0.0.1:2402 -profiles=$RigRoot\hcprof$i -name=HC$i -mod=$mods"
}
$flagPairs = FlagPairs $run.flags
$flagPairs += "WFBE_C_TEST_POPTIER_PIN=$($run.popPin)"

# ---- DRY RUN: print the plan ----------------------------------------------
if ($DryRun -or (-not $FromRpt)) {
    Write-Output ""
    Write-Output "SCENARIO  $($spec.name)   [run: $($run.runLabel)]"
    Write-Output "  $($spec.description)"
    Write-Output ""
    Write-Output "CONFIG"
    Write-Output "  map/template : $($run.map)  ->  $($run.template)"
    Write-Output "  HC count     : $($run.hcCount)"
    Write-Output "  popPin       : $($run.popPin)   (WFBE_C_TEST_POPTIER_PIN)"
    Write-Output "  duration     : $($run.durationMin) min"
    Write-Output "  flags        : $([string]::Join('  ', $flagPairs))"
    if (@($spec.requires).Count -gt 0) {
        Write-Output "  REQUIRES     : $([string]::Join(', ', @($spec.requires)))  <-- verify these harness capabilities are deployed"
    }
    Write-Output ""
    Write-Output "LAUNCH PLAN  (rendered only; this tool does not spawn Arma -- run these via the sandbox-boot track)"
    Write-Output "  server: $serverCmd"
    foreach ($h in $hcCmds) { Write-Output "  hc    : $h" }
    Write-Output ""
    Write-Output "NOTE: flag injection (popPin + scenario flags) requires the TESTBENCH param wiring (test-harness PR-2);"
    Write-Output "      until then set them as lobby Param defaults or via a server-side test init."
    Write-Output ""
    Write-Output "ASSERTS"
    foreach ($as in @($spec.asserts)) {
        Write-Output ("  [{0,-5}] {1} {2} {3}" -f $as.severity, $as.metric, $as.op, $as.threshold)
    }
    Write-Output ""
    Write-Output "To grade a produced RPT:  Run-Scenario.ps1 -Name $($spec.name) -FromRpt <server.RPT> [-HcRpt <ArmA2OA.RPT>]"
    return
}

# ---- FROM RPT: grade -------------------------------------------------------
New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null

$nowUtc    = (Get-Date).ToUniversalTime()
# Millisecond resolution + the source RPT basename so grading two different RPTs in the same second
# (as the autopilot does) can never collide on stampId. The processed-set handles same-RPT re-grades.
$srcTag    = if ([string]::IsNullOrWhiteSpace($FromRpt)) { 'run' } else { [System.IO.Path]::GetFileNameWithoutExtension($FromRpt) }
$stampUtc  = $nowUtc.ToString('yyyyMMdd-HHmmssfff') + 'Z'
$runId     = "$($spec.name)-$($run.runLabel)-$srcTag-$stampUtc"
$aJsonPath = Join-Path $ResultsDir "$runId.analyze.json"

# Synthesize a stamp so a FAILURE row can still be attributed (the ledger MUST record failed/
# truncated/crashed soaks -- a silent throw would leave no trace, which the design forbids).
function New-RunStamp {
    if (-not [string]::IsNullOrWhiteSpace($StampPath)) { return $StampPath }
    $sp = Join-Path $ResultsDir "$runId.stamp.json"
    $so = [ordered]@{ stampId = $runId; candidate = $run.map; terrain = $run.map
                      role = "scenario:$($spec.name)"; pboName = $run.template; operator = 'sandbox'; git = $null }
    [System.IO.File]::WriteAllText($sp, (ToJson $so), (New-Object System.Text.UTF8Encoding($false)))
    return $sp
}
function Complete-Fail([string]$status, [string]$note) {
    $sp = New-RunStamp
    try {
        $fa = @{ LedgerPath = $LedgerPath; Status = $status; StampPath = $sp; ServerRptPath = $FromRpt
                 AllowDuplicateSkip = $true; Note = @("scenario=$($spec.name)", "run=$($run.runLabel)", $note) }
        & $appender @fa | Out-Null
    } catch { Write-Host "  (ledger $status append failed: $_)" }
    Write-Host "RESULT  $status   ($note)"
    return [ordered]@{ schema = 'a2wasp-run-result-v1'; runId = $runId; scenario = $spec.name
                       source = 'FromRpt'; verdict = $status; note = $note; ledgerRowId = $null }
}

# missing RPT -> SKIP row (box down / no capture), not a silent throw
if (-not (Test-Path -LiteralPath $FromRpt)) { return (Complete-Fail 'SKIP_BOX_DOWN' "server RPT not found: $FromRpt") }

# 1) analyzer
$aArgs = @($analyzer, $FromRpt)
if (-not [string]::IsNullOrWhiteSpace($HcRpt)) { $aArgs += @('--hc', $HcRpt) }
$aArgs += '--json'
$aText = & python @aArgs 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($aText)) { return (Complete-Fail 'FAIL_ANALYZER' "analyze_soak.py produced no output for $FromRpt") }
[System.IO.File]::WriteAllText($aJsonPath, ($aText -join "`n"), (New-Object System.Text.UTF8Encoding($false)))
$a = $aText | ConvertFrom-Json

# 2) flat metrics
# roundend is an object {winner,secs,map} when a round ended; take the winner side as the string.
$roundWinner = $null
if ($null -ne $a.roundend) { $roundWinner = if ($a.roundend -is [string]) { $a.roundend } elseif ($a.roundend.PSObject.Properties['winner']) { $a.roundend.winner } else { [string]$a.roundend } }
$metrics = @{
    serverFpsMedian = Round1 (Get-Median $a.perf.fps)
    serverFpsMin    = Get-Min $a.perf.fps
    hcFpsMedian     = Round1 (Get-Median $a.perf.hc_fps)
    hc2FpsMedian    = Round1 (Get-Median $a.perf.hc2fps)
    aiTotPeak       = Get-Max $a.perf.ai_tot
    guerPeak        = Get-Max $a.perf.guer
    captures        = $a.hold.captures
    arrivalPct      = $a.arrival.arrival_pct
    maxTownsWest    = $a.hold.max_towns.WEST
    maxTownsEast    = $a.hold.max_towns.EAST
    hours           = $a.hours
    roundWinner     = $roundWinner
}

# 3) evaluate asserts
$assertResults = @()
$rank = @{ 'PASS' = 0; 'WATCH' = 1; 'FAIL' = 2 }
$verdict = 'PASS'
foreach ($as in @($spec.asserts)) {
    $val = $metrics[$as.metric]
    $pass = $null
    if ($null -ne $val) {
        switch ($as.op) {
            'ge' { $pass = ($val -ge $as.threshold) }
            'le' { $pass = ($val -le $as.threshold) }
            'gt' { $pass = ($val -gt $as.threshold) }
            'lt' { $pass = ($val -lt $as.threshold) }
            'eq' { $pass = ($val -eq $as.threshold) }
            default { $pass = $null }
        }
    }
    $assertResults += [ordered]@{ metric=$as.metric; op=$as.op; threshold=$as.threshold; actual=$val; severity=$as.severity; pass=$pass }
    if ($pass -eq $false) {
        $v = if ($as.severity -eq 'fail') { 'FAIL' } else { 'WATCH' }
        if ($rank[$v] -gt $rank[$verdict]) { $verdict = $v }
    } elseif ($null -eq $pass -and $as.severity -eq 'fail') {
        if ($rank['WATCH'] -gt $rank[$verdict]) { $verdict = 'WATCH' }   # a hard gate we could not confirm
    }
}

# 4) opportunistic boot-smoke gate (present only once test-harness PR-4 lands on this base)
$bootSmoke = $null
$bootTool = Join-Path (Split-Path -Parent $soakDir) 'Smoke\Test-WaspBootSmoke.ps1'
if (Test-Path -LiteralPath $bootTool) {
    try {
        $bsJson = & $bootTool -ServerRpt $FromRpt -Json 2>$null
        if ($bsJson) {
            $bs = ($bsJson | ConvertFrom-Json)
            $bootSmoke = [ordered]@{ ran = $true; verdict = $bs.verdict; tool = $bootTool }
            if ($bs.verdict -eq 'FAIL' -and $rank['FAIL'] -gt $rank[$verdict]) { $verdict = 'FAIL' }
        }
    } catch { $bootSmoke = [ordered]@{ ran = $true; verdict = 'ERROR'; tool = $bootTool; error = "$_" } }
} else {
    $bootSmoke = [ordered]@{ ran = $false; verdict = $null; tool = $bootTool; note = 'boot-smoke gate not on this base (test-harness PR-4)' }
}

# 5) synthesize a stamp if none supplied, and a lens JSON reflecting the verdict
$tmpStamp = $null
if ([string]::IsNullOrWhiteSpace($StampPath)) {
    $tmpStamp = Join-Path $ResultsDir "$runId.stamp.json"
    $stampObj = [ordered]@{
        stampId = $runId; candidate = $a.build; terrain = $run.map
        role = "scenario:$($spec.name)"; pboName = $run.template; operator = 'sandbox'; git = $null
    }
    [System.IO.File]::WriteAllText($tmpStamp, (ToJson $stampObj), (New-Object System.Text.UTF8Encoding($false)))
    $StampPath = $tmpStamp
}
$hcRptArg = $null
if (-not [string]::IsNullOrWhiteSpace($HcRpt)) { $hcRptArg = $HcRpt }

$perfLensFailed = $assertResults | Where-Object { $_.metric -like '*Fps*' -and $_.pass -eq $false }
$worstLens  = 'perf'; if ($verdict -eq 'PASS')            { $worstLens  = $null }
$errorsLens = 'PASS'; if ($bootSmoke.verdict -eq 'FAIL')  { $errorsLens = 'FAIL' }
$perfLens   = 'PASS'; if ($perfLensFailed)                { $perfLens   = $verdict }
$lensObj = [ordered]@{
    overall   = $verdict
    worstLens = $worstLens
    release   = 'PASS'
    errors    = $errorsLens
    war       = 'PASS'
    perf      = $perfLens
    summary   = "scenario $($spec.name)/$($run.runLabel): $verdict over $(@($assertResults).Count) assert(s)."
}
$lensPath = Join-Path $ResultsDir "$runId.lens.json"
[System.IO.File]::WriteAllText($lensPath, (ToJson $lensObj), (New-Object System.Text.UTF8Encoding($false)))

# 6) append the ledger row
$ledgerStatus = 'POSTED_LEDGER_ONLY'
$appendArgs = @{
    LedgerPath = $LedgerPath; Status = $ledgerStatus; StampPath = $StampPath
    AnalyzeJsonPath = $aJsonPath; LensJsonPath = $lensPath; ServerRptPath = $FromRpt
    Note = @("scenario=$($spec.name)", "run=$($run.runLabel)", "verdict=$verdict")
}
if ($null -ne $hcRptArg) { $appendArgs.HcRptPath = $hcRptArg }
$rowId = & $appender @appendArgs

# 7) write the Standard Run-Result JSON
$result = [ordered]@{
    schema      = 'a2wasp-run-result-v1'
    runId       = $runId
    createdAtUtc = $nowUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
    scenario    = $spec.name
    description = $spec.description
    source      = 'FromRpt'
    config      = [ordered]@{
        map = $run.map; template = $run.template; mods = $mods
        hcCount = $run.hcCount; popPin = $run.popPin; durationMin = $run.durationMin
        flags = $run.flags; requires = @($spec.requires)
    }
    metrics     = [ordered]@{
        serverFpsMedian = $metrics.serverFpsMedian; serverFpsMin = $metrics.serverFpsMin
        hcFpsMedian = $metrics.hcFpsMedian; hc2FpsMedian = $metrics.hc2FpsMedian
        aiTotPeak = $metrics.aiTotPeak; guerPeak = $metrics.guerPeak
        captures = $metrics.captures; arrivalPct = $metrics.arrivalPct
        maxTownsWest = $metrics.maxTownsWest; maxTownsEast = $metrics.maxTownsEast
        hours = $metrics.hours; roundWinner = $metrics.roundWinner
    }
    asserts     = $assertResults
    verdict     = $verdict
    bootSmoke   = $bootSmoke
    ledgerRowId = $rowId
    artifacts   = [ordered]@{
        analyzeJson = $aJsonPath; lensJson = $lensPath
        serverRpt = $FromRpt; hcRpt = $hcRptArg
        resultJson = (Join-Path $ResultsDir "$runId.json")
    }
}
$resultPath = Join-Path $ResultsDir "$runId.json"
[System.IO.File]::WriteAllText($resultPath, (ToJson $result), (New-Object System.Text.UTF8Encoding($false)))

# 8) regenerate the HTML chart report (opt-in). Charts are always emitted from the accumulated
#    ledger + results so each grade refreshes the same self-contained report file.
$reportOut = $null
if ($Report) {
    $charter = Join-Path $soakDir 'chart_soak.py'
    if ([string]::IsNullOrWhiteSpace($ReportPath)) { $ReportPath = Join-Path $ResultsDir 'soak-report.html' }
    try {
        & python $charter --ledger $LedgerPath --results $ResultsDir --out $ReportPath 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { $reportOut = $ReportPath; $result.artifacts.report = $ReportPath
            [System.IO.File]::WriteAllText($resultPath, (ToJson $result), (New-Object System.Text.UTF8Encoding($false))) }
    } catch { Write-Host "  (chart report failed: $_)" }
}

# 9) plain-English summary (console always; Peach on request)
$sfx = if ($null -ne $metrics.serverFpsMedian) { $metrics.serverFpsMedian } else { 'n/a' }
$msg = "Scenario $($spec.name) [$($run.runLabel)] on $($run.map) ($($run.hcCount)HC, pin$($run.popPin)): $verdict. " +
       "server FPS median $sfx, AI peak $($metrics.aiTotPeak), captures $($metrics.captures), arrival $($metrics.arrivalPct)%. rowId $rowId."
Write-Host ""
Write-Host "RESULT  $verdict   ($resultPath)"
Write-Host "  $msg"
if ($reportOut) { Write-Host "  chart report: $reportOut" }

if ($Peach) {
    $peachTool = 'C:\Users\Game\wasp-build\peach-dm.ps1'
    if (Test-Path -LiteralPath $peachTool) {
        try { & pwsh -NoProfile -File $peachTool -Text "[sandbox] $msg" | Out-Null; Write-Host "  (Peach DM sent)" }
        catch { Write-Host "  (Peach DM failed: $_)" }
    } else { Write-Host "  (Peach tool not found at $peachTool)" }
    # ...and to the WASP Discord channel via the "Warfare Handler" bot (best-effort; no-op until the
    # bot is granted View+Send on the channel). Machine-local helper; owns the token + channel id.
    $whTool = 'C:\Users\Game\wasp-build\warfare-handler-post.ps1'
    if (Test-Path -LiteralPath $whTool) {
        try { & pwsh -NoProfile -File $whTool -Text "[sandbox] $msg" | Out-Null } catch {}
    }
}
return $result
