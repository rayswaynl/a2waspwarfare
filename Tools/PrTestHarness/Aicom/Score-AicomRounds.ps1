<#
.SYNOPSIS
    Parse AICOMSTAT telemetry from an Arma 2 RPT file and produce a per-round
    scoring table + markdown digest.

.DESCRIPTION
    Reads AICOMSTAT pipe-delimited lines produced by the AI Commander V0.6
    telemetry system.  Supports three record types:
        AICOMSTAT|v1|TICK|<side>|<elapsed_min>|<townsHeld>|<supply>|<funds>|<foundedTeams>|<editorTeams>|<upgLevelsCsv>
        AICOMSTAT|v1|EVENT|<side>|<elapsed_min>|<eventType>|<detail>
        AICOMSTAT|v1|END|<side>|<duration_min>|<winner>|<doctrine>|<townsHeld>|<fundsLeft>

    A "round" is demarcated by END records.  TICK records between two END marks
    belong to the same round.

.PARAMETER RptPath
    Full path to the Arma 2 RPT file to parse.

.PARAMETER DigestDir
    Directory where the markdown digest will be written.
    Default: C:\WASP\aicom-eval

.EXAMPLE
    .\Score-AicomRounds.ps1 -RptPath "C:\WASP\rpts\arma2oaserver_2026-06-11.rpt"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RptPath,
    [string]$DigestDir = "C:\WASP\aicom-eval"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# 1.  Read the RPT and extract AICOMSTAT lines
# ---------------------------------------------------------------------------
if (-not (Test-Path $RptPath)) {
    Write-Error "RPT file not found: $RptPath"
    return
}

$allLines = Get-Content -Path $RptPath -Encoding UTF8
$statLines = $allLines | Where-Object { $_ -match 'AICOMSTAT\|v1\|' } |
    ForEach-Object { $_ -replace '^.*AICOMSTAT\|', 'AICOMSTAT|' }

if ($statLines.Count -eq 0) {
    Write-Warning "No AICOMSTAT lines found in: $RptPath"
    return
}

Write-Host "Found $($statLines.Count) AICOMSTAT lines."

# ---------------------------------------------------------------------------
# 2.  Parse into typed records
# ---------------------------------------------------------------------------
$ticks  = [System.Collections.Generic.List[hashtable]]::new()
$events = [System.Collections.Generic.List[hashtable]]::new()
$ends   = [System.Collections.Generic.List[hashtable]]::new()

foreach ($line in $statLines) {
    $parts = $line -split '\|'
    if ($parts.Count -lt 3) { continue }
    $type = $parts[2]
    switch ($type) {
        'TICK' {
            if ($parts.Count -ge 11) {
                $ticks.Add(@{
                    Side        = $parts[3]
                    ElMin       = [int]$parts[4]
                    TownsHeld   = [int]$parts[5]
                    Supply      = [int]$parts[6]
                    Funds       = [int]$parts[7]
                    FoundedTeams= [int]$parts[8]
                    EditorTeams = [int]$parts[9]
                    UpgCsv      = $parts[10]
                })
            }
        }
        'EVENT' {
            if ($parts.Count -ge 7) {
                $events.Add(@{
                    Side       = $parts[3]
                    ElMin      = [int]$parts[4]
                    EventType  = $parts[5]
                    Detail     = $parts[6]
                })
            }
        }
        'END' {
            if ($parts.Count -ge 9) {
                $ends.Add(@{
                    Side       = $parts[3]
                    DurationMin= [int]$parts[4]
                    Winner     = $parts[5]
                    Doctrine   = $parts[6]
                    TownsHeld  = [int]$parts[7]
                    FundsLeft  = [int]$parts[8]
                })
            }
        }
    }
}

Write-Host "  TICK=$($ticks.Count)  EVENT=$($events.Count)  END=$($ends.Count)"

# ---------------------------------------------------------------------------
# 3.  Group into rounds.  Strategy: each END record closes a round;
#     TICK/EVENT records are assigned to the round whose END's DurationMin
#     is >= their ElMin (nearest END that could contain them, per side).
# ---------------------------------------------------------------------------
$rounds = [System.Collections.Generic.List[hashtable]]::new()
$roundIdx = 0

# Build per-side end boundaries  (sorted ascending by DurationMin)
$sideEnds = @{}
foreach ($e in $ends) {
    if (-not $sideEnds.ContainsKey($e.Side)) { $sideEnds[$e.Side] = [System.Collections.Generic.List[hashtable]]::new() }
    $sideEnds[$e.Side].Add($e)
}
foreach ($s in $sideEnds.Keys) {
    $sideEnds[$s] = $sideEnds[$s] | Sort-Object { $_.DurationMin }
}

# Assign each TICK to a (side, roundIndex) bucket
$tickBuckets  = @{}   # key = "side:roundIdx"
$eventBuckets = @{}

function Get-RoundIdx($side, $elMin) {
    if (-not $sideEnds.ContainsKey($side)) { return 0 }
    $boundaries = $sideEnds[$side]
    for ($i = 0; $i -lt $boundaries.Count; $i++) {
        if ($elMin -le $boundaries[$i].DurationMin) { return $i }
    }
    return $boundaries.Count - 1
}

foreach ($t in $ticks) {
    $ri  = Get-RoundIdx $t.Side $t.ElMin
    $key = "$($t.Side):$ri"
    if (-not $tickBuckets.ContainsKey($key)) { $tickBuckets[$key] = [System.Collections.Generic.List[hashtable]]::new() }
    $tickBuckets[$key].Add($t)
}
foreach ($e in $events) {
    $ri  = Get-RoundIdx $e.Side $e.ElMin
    $key = "$($e.Side):$ri"
    if (-not $eventBuckets.ContainsKey($key)) { $eventBuckets[$key] = [System.Collections.Generic.List[hashtable]]::new() }
    $eventBuckets[$key].Add($e)
}

# ---------------------------------------------------------------------------
# 4.  Build round summaries
# ---------------------------------------------------------------------------
$roundRows = [System.Collections.Generic.List[hashtable]]::new()
$globalRound = 0

foreach ($side in ($sideEnds.Keys | Sort-Object)) {
    $boundaries = $sideEnds[$side]
    for ($ri = 0; $ri -lt $boundaries.Count; $ri++) {
        $endRec = $boundaries[$ri]
        $key    = "$($side):$ri"

        # Towns curve from TICK records for this round
        $myTicks = if ($tickBuckets.ContainsKey($key)) { $tickBuckets[$key] } else { @() }
        $townsCurve = ""
        if ($myTicks.Count -gt 0) {
            $sorted  = $myTicks | Sort-Object { $_.ElMin }
            $tStart  = $sorted[0].TownsHeld
            $tMid    = $sorted[[Math]::Floor($sorted.Count / 2)].TownsHeld
            $tEnd    = $sorted[-1].TownsHeld
            $townsCurve = "start=$tStart / mid=$tMid / end=$tEnd"
        }

        # Max upgrade levels reached (last TICK's UpgCsv)
        $maxUpgrades = ""
        if ($myTicks.Count -gt 0) {
            $lastTick = ($myTicks | Sort-Object { $_.ElMin })[-1]
            $maxUpgrades = $lastTick.UpgCsv
        }

        # Max foundedTeams
        $maxFounded = 0
        foreach ($t in $myTicks) { if ($t.FoundedTeams -gt $maxFounded) { $maxFounded = $t.FoundedTeams } }

        # Event counts
        $myEvents = if ($eventBuckets.ContainsKey($key)) { $eventBuckets[$key] } else { @() }
        $eventCounts = @{}
        foreach ($ev in $myEvents) {
            if (-not $eventCounts.ContainsKey($ev.EventType)) { $eventCounts[$ev.EventType] = 0 }
            $eventCounts[$ev.EventType]++
        }
        $evSummary = ($eventCounts.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ', '

        $globalRound++
        $roundRows.Add(@{
            Round       = $globalRound
            Side        = $side
            Duration    = $endRec.DurationMin
            Winner      = $endRec.Winner
            Doctrine    = $endRec.Doctrine
            TownsEnd    = $endRec.TownsHeld
            FundsLeft   = $endRec.FundsLeft
            TownsCurve  = $townsCurve
            MaxUpgrades = $maxUpgrades
            MaxFounded  = $maxFounded
            Events      = $evSummary
            TickCount   = $myTicks.Count
        })
    }
}

# ---------------------------------------------------------------------------
# 5.  Print table to console
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "=== AICOM ROUND SCORING TABLE ==="
Write-Host ("{0,-5} {1,-8} {2,-6} {3,-12} {4,-6} {5,-5} {6,-6} {7,-10}" -f
    "Round","Side","DurMin","Winner","Doctri","Towns","Funds","Founded")
Write-Host ("-" * 80)
foreach ($r in $roundRows) {
    Write-Host ("{0,-5} {1,-8} {2,-6} {3,-12} {4,-6} {5,-5} {6,-6} {7,-10}" -f
        $r.Round, $r.Side, $r.Duration, $r.Winner, $r.Doctrine, $r.TownsEnd, $r.FundsLeft, $r.MaxFounded)
}

# ---------------------------------------------------------------------------
# 6.  Write markdown digest
# ---------------------------------------------------------------------------
if (-not (Test-Path $DigestDir)) { New-Item -ItemType Directory -Force -Path $DigestDir | Out-Null }
$dateTag = Get-Date -Format "yyyy-MM-dd"
$digestPath = Join-Path $DigestDir "digest-$dateTag.md"

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("# AICOM Round Scoring Digest — $dateTag")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("**Source RPT:** ``$RptPath``")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Summary Table")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| Round | Side | DurMin | Winner | Doctrine | TownsEnd | FundsLeft | FoundedMax | TownsCurve | Events |")
[void]$sb.AppendLine("|-------|------|--------|--------|----------|----------|-----------|------------|------------|--------|")
foreach ($r in $roundRows) {
    $row = "| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} | {9} |" -f
        $r.Round, $r.Side, $r.Duration, $r.Winner, $r.Doctrine,
        $r.TownsEnd, $r.FundsLeft, $r.MaxFounded, $r.TownsCurve, $r.Events
    [void]$sb.AppendLine($row)
}
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Per-Round Detail")
[void]$sb.AppendLine("")
foreach ($r in $roundRows) {
    [void]$sb.AppendLine("### Round $($r.Round) — $($r.Side) — $($r.Duration) min")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("- **Winner:** $($r.Winner)")
    [void]$sb.AppendLine("- **Doctrine:** $($r.Doctrine)")
    [void]$sb.AppendLine("- **Towns held at end:** $($r.TownsEnd)")
    [void]$sb.AppendLine("- **Funds left:** $($r.FundsLeft)")
    [void]$sb.AppendLine("- **Max founded teams:** $($r.MaxFounded)")
    [void]$sb.AppendLine("- **Towns curve (start/mid/end):** $($r.TownsCurve)")
    [void]$sb.AppendLine("- **Final upgrade levels (csv):** $($r.MaxUpgrades)")
    [void]$sb.AppendLine("- **TICK samples:** $($r.TickCount)")
    [void]$sb.AppendLine("- **Events:** $($r.Events)")
    [void]$sb.AppendLine("")
}
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("*Generated by Score-AicomRounds.ps1 — task 48*")

[System.IO.File]::WriteAllText($digestPath, $sb.ToString(), [System.Text.Encoding]::UTF8)
Write-Host ""
Write-Host "Digest written to: $digestPath"
