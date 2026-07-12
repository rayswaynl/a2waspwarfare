<#
.SYNOPSIS
    Watch a stresstest run: server/HC FPS vs AI_TOT, this harness's own SPAWN_BATCH markers,
    group-budget pressure, and process stability - and print where the cliff is.

.DESCRIPTION
    Parses the mission's own always-on RPT telemetry (no new instrumentation needed):
      - WASPSCALE|v2|... (Server\AI\Commander\AI_Commander.sqf) - fps, hc_fps, AI_TOT, groups,
        emitted on a ~300s SRVPERF throttle.
      - STRESSTEST|v1|SPAWN_BATCH / SPAWN_COMPLETE / CAPPED / ABORT (this harness's
        Server_DebugStressSpawn.sqf, plain diag_log - always visible regardless of WF_LOG_CONTENT).
      - GRPBUDGET|v1|WARN (Server\AI\Commander\AI_Commander.sqf) - per-side group count nearing
        Arma 2 OA's 144/side hard cap.
      - "Common_CreateGroup.sqf: emergency GC" (Common\Functions\Common_CreateGroup.sqf, via the
        always-on AICOMLog) - the per-side 140-group cap this harness's own spawns will hit first
        if the run is pushed far enough; a natural, already-instrumented cliff signal.

    Runs either as a one-shot summary over the RPT as it stands (-Follow:$false, default) or
    continuously tailing new lines (-Follow) with a live process-count check each poll.

.PARAMETER RptPath
    Path to arma2oaserver.RPT on the box being monitored.

.PARAMETER FpsFloor
    Flag a sample as a cliff candidate when server fps drops at or below this value.

.PARAMETER FpsDropPct
    Flag a sample as a cliff candidate when fps drops by at least this fraction (0-1) of the
    rolling max-so-far fps seen in this run.

.EXAMPLE
    .\monitor.ps1 -RptPath 'C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT'

.EXAMPLE
    .\monitor.ps1 -RptPath 'C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT' -Follow -PollSeconds 30
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string]$RptPath,
    [switch]$Follow,
    [int]$PollSeconds = 30,
    [double]$FpsFloor = 20,
    [double]$FpsDropPct = 0.3
)

$ErrorActionPreference = 'Stop'

function ConvertFrom-PipeKV {
    <# Parses 'KEY|v1|123|a=1|b=2|c=text' style lines into a hashtable of the k=v segments,
       plus '_tag' (KEY) and '_version' (v1) when present. Tolerant of segments with no '='. #>
    param([string]$Line)
    $parts = $Line -split '\|'
    $result = @{}
    if ($parts.Count -ge 1) { $result['_tag'] = $parts[0] }
    if ($parts.Count -ge 2 -and $parts[1] -match '^v\d+$') { $result['_version'] = $parts[1] }
    foreach ($p in $parts) {
        $eq = $p.IndexOf('=')
        if ($eq -gt 0) {
            $key = $p.Substring(0, $eq)
            $val = $p.Substring($eq + 1)
            $result[$key] = $val
        }
    }
    return $result
}

function Show-Samples {
    param([string[]]$Lines, [ref]$RollingMaxFps)

    $waspscale = @()
    $stresstest = @()
    $budgetWarn = @()
    $gcWarn = @()

    foreach ($line in $Lines) {
        if ($line -match 'WASPSCALE\|v2\|') {
            $kv = ConvertFrom-PipeKV $line
            $waspscale += [pscustomobject]@{
                MinuteMark = $kv['_tag'] # placeholder, overwritten below
                Fps        = [double]($kv['fps'])
                HcFps      = [double]($kv['hc_fps'])
                AiTot      = [int]($kv['AI_TOT'])
                Groups     = [int]($kv['groups'])
                Players    = $kv['players']
                Raw        = $line
            }
        } elseif ($line -match 'STRESSTEST\|v1\|') {
            $kv = ConvertFrom-PipeKV $line
            $stresstest += [pscustomobject]@{
                Event = ($line -split '\|')[2]
                N      = $kv['n']
                Target = $kv['target']
                Elapsed = $kv['elapsedSec']
                Raw    = $line
            }
        } elseif ($line -match 'GRPBUDGET\|v1\|WARN') {
            $budgetWarn += $line
        } elseif ($line -match 'Common_CreateGroup\.sqf: emergency GC') {
            $gcWarn += $line
        }
    }

    if ($stresstest.Count -gt 0) {
        Write-Output "--- STRESSTEST markers (this harness) ---"
        $stresstest | ForEach-Object { Write-Output ("  {0,-14} n={1,-5} target={2,-5} elapsedSec={3}" -f $_.Event, $_.N, $_.Target, $_.Elapsed) }
    }

    if ($waspscale.Count -gt 0) {
        Write-Output "--- WASPSCALE samples (fps / hc_fps / AI_TOT / groups) ---"
        $cliffPrinted = $false
        foreach ($s in $waspscale) {
            if ($s.Fps -gt $RollingMaxFps.Value) { $RollingMaxFps.Value = $s.Fps }
            $dropPct = if ($RollingMaxFps.Value -gt 0) { 1 - ($s.Fps / $RollingMaxFps.Value) } else { 0 }
            $isCliff = ($s.Fps -le $FpsFloor) -or ($dropPct -ge $FpsDropPct)
            $marker = if ($isCliff) { '  <-- CLIFF' } else { '' }
            Write-Output ("  fps={0,-5} hc_fps={1,-5} AI_TOT={2,-5} groups={3,-4} players={4}{5}" -f $s.Fps, $s.HcFps, $s.AiTot, $s.Groups, $s.Players, $marker)
            if ($isCliff -and -not $cliffPrinted) {
                $cliffPrinted = $true
                Write-Warning ("First cliff sample: fps={0} (floor={1}, drop={2:P0} of rolling max {3}) at AI_TOT={4} groups={5}" -f $s.Fps, $FpsFloor, $dropPct, $RollingMaxFps.Value, $s.AiTot, $s.Groups)
            }
        }
    }

    if ($budgetWarn.Count -gt 0) {
        Write-Output "--- GRPBUDGET WARN (per-side group count nearing the 144 hard cap) ---"
        $budgetWarn | ForEach-Object { Write-Output "  $_" }
    }

    if ($gcWarn.Count -gt 0) {
        Write-Output "--- Common_CreateGroup emergency GC (per-side 140 cap this harness's own spawns hit first) ---"
        $gcWarn | ForEach-Object { Write-Output "  $_" }
    }
}

function Get-ProcStability {
    $procs = Get-Process -Name arma2oaserver, ArmA2OA -ErrorAction SilentlyContinue
    $count = if ($procs) { $procs.Count } else { 0 }
    Write-Output ("--- Process stability: {0}/3 up ---" -f $count)
    $procs | ForEach-Object { Write-Output "  $($_.ProcessName) PID=$($_.Id) Start=$($_.StartTime)" }
    return $count
}

if (-not (Test-Path -LiteralPath $RptPath)) {
    throw "RPT not found at $RptPath"
}

$rollingMaxFps = 0.0

if (-not $Follow) {
    Write-Output "=== STRESSTEST MONITOR (one-shot) - $RptPath ==="
    $allLines = Get-Content -LiteralPath $RptPath
    Show-Samples -Lines $allLines -RollingMaxFps ([ref]$rollingMaxFps)
    Get-ProcStability | Out-Null
    Write-Output "=== MONITOR DONE ==="
    return
}

Write-Output "=== STRESSTEST MONITOR (following, poll every ${PollSeconds}s, Ctrl+C to stop) - $RptPath ==="
$lastLineCount = 0
while ($true) {
    $allLines = Get-Content -LiteralPath $RptPath
    if ($allLines.Count -gt $lastLineCount) {
        $newLines = $allLines[$lastLineCount..($allLines.Count - 1)]
        Show-Samples -Lines $newLines -RollingMaxFps ([ref]$rollingMaxFps)
        $lastLineCount = $allLines.Count
    }
    Get-ProcStability | Out-Null
    Start-Sleep $PollSeconds
}
