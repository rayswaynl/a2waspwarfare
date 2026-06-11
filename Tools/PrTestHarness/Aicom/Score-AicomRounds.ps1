<#
.SYNOPSIS
    Parse AICOMSTAT telemetry from an Arma 2 RPT file and produce a per-session
    scoring table + markdown digest.

.DESCRIPTION
    Reads AICOMSTAT pipe-delimited lines produced by the AI Commander V0.6
    telemetry system.  Supports three record types:
        AICOMSTAT|v1|TICK|<side>|<elapsed_min>|<townsHeld>|<supply>|<funds>|<foundedTeams>|<editorTeams>|<upgLevelsCsv>
        AICOMSTAT|v1|EVENT|<side>|<elapsed_min>|<eventType>|<detail>
        AICOMSTAT|v1|END|<side>|<duration_min>|<winner>|<doctrine>|<townsHeld>|<fundsLeft>

    SESSION BOUNDARY DETECTION
    Because an RPT file spans multiple server restarts, a single RPT may contain
    telemetry for several independent mission sessions.  Sessions are detected
    per-side by watching for ElMin RESETS: a TICK whose ElMin is LOWER than the
    previous TICK's ElMin for the same side marks the start of a new session.
    Each session is scored independently.

    UPGRADE DECODING
    The colon-separated upgrade-levels CSV (UpgCsv) is decoded via a static
    index-to-name table.  Only slots with a non-zero level are shown.
    Defaults cover slots 0-3; mission-specific slots appear as Upg<N>.
    Override the table via -UpgradeNames.

    PASS/FAIL GATE
    When -MinTeamsFounded, -MinTicksPerSide, or -MaxErrorBlocks are provided,
    the LATEST session is evaluated against those thresholds.  Any failure
    prints a FAIL reason and the script exits with code 1 (useful in CI/deploy
    automation).  Without those params the script always exits 0.

.PARAMETER RptPath
    Full path to the Arma 2 RPT file to parse.

.PARAMETER DigestDir
    Directory where the markdown digest will be written.
    Default: C:\WASP\aicom-eval

.PARAMETER UpgradeNames
    Hashtable mapping upgrade slot index (int or string) to a display name.
    Defaults: 0=Barracks, 1=Light, 2=Heavy, 3=Air.
    Extra slots are rendered as Upg<N>.

.PARAMETER MinTeamsFounded
    Gate: the latest session must have at least this many founded teams.
    Omit (or pass 0) to skip this check.

.PARAMETER MinTicksPerSide
    Gate: each side in the latest session must have at least this many TICK
    records.  Omit (or pass 0) to skip this check.

.PARAMETER MaxErrorBlocks
    Gate: the number of distinct EVENT records of type ERROR in the latest
    session must not exceed this value.  Omit (or pass -1) to skip.

.EXAMPLE
    .\Score-AicomRounds.ps1 -RptPath "C:\WASP\rpts\arma2oaserver_2026-06-11.rpt"

.EXAMPLE
    # Deploy gate: at least 3 teams founded, 5 TICKs per side, no more than 2 error events
    .\Score-AicomRounds.ps1 -RptPath "C:\WASP\rpts\arma2oaserver.rpt" `
        -MinTeamsFounded 3 -MinTicksPerSide 5 -MaxErrorBlocks 2
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RptPath,
    [string]$DigestDir = "C:\WASP\aicom-eval",
    [hashtable]$UpgradeNames = @{
        0 = "Barracks"
        1 = "Light"
        2 = "Heavy"
        3 = "Air"
    },
    [int]$MinTeamsFounded  = 0,
    [int]$MinTicksPerSide  = 0,
    [int]$MaxErrorBlocks   = -1
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Helper: decode UpgCsv into human-readable string
# Format: "level0:level1:level2:..." (colon-separated integers)
# Only non-zero slots are shown. Slot index mapped via $UpgradeNames.
# ---------------------------------------------------------------------------
function Decode-UpgCsv {
    param([string]$csv)
    if ([string]::IsNullOrWhiteSpace($csv)) { return "" }
    $parts = $csv -split ':'
    $decoded = [System.Collections.Generic.List[string]]::new()
    for ($i = 0; $i -lt $parts.Count; $i++) {
        $level = 0
        if (-not [int]::TryParse($parts[$i].Trim(), [ref]$level)) { continue }
        if ($level -eq 0) { continue }
        $name = if ($UpgradeNames.ContainsKey($i)) { $UpgradeNames[$i] } else { "Upg$i" }
        $decoded.Add("${name}:L${level}")
    }
    if ($decoded.Count -eq 0) { return "(none)" }
    return $decoded -join ', '
}

# ---------------------------------------------------------------------------
# 1.  Read the RPT and extract AICOMSTAT lines
# ---------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $RptPath)) {
    Write-Error "RPT file not found: $RptPath"
    return
}

$allLines  = Get-Content -LiteralPath $RptPath -Encoding UTF8
$statLines = $allLines | Where-Object { $_ -match 'AICOMSTAT\|v1\|' } |
    ForEach-Object { $_ -replace '^.*AICOMSTAT\|', 'AICOMSTAT|' }

if ($statLines.Count -eq 0) {
    Write-Warning "No AICOMSTAT lines found in: $RptPath"
    return
}

Write-Host "Found $($statLines.Count) AICOMSTAT lines."

# ---------------------------------------------------------------------------
# 2.  Parse into typed records (in RPT order, preserving line index)
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
                    Side         = $parts[3]
                    ElMin        = [int]$parts[4]
                    TownsHeld    = [int]$parts[5]
                    Supply       = [int]$parts[6]
                    Funds        = [int]$parts[7]
                    FoundedTeams = [int]$parts[8]
                    EditorTeams  = [int]$parts[9]
                    UpgCsv       = $parts[10]
                    # Session index assigned below
                    SessionIdx   = 0
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
                    SessionIdx = 0
                })
            }
        }
        'END' {
            if ($parts.Count -ge 9) {
                $ends.Add(@{
                    Side        = $parts[3]
                    DurationMin = [int]$parts[4]
                    Winner      = $parts[5]
                    Doctrine    = $parts[6]
                    TownsHeld   = [int]$parts[7]
                    FundsLeft   = [int]$parts[8]
                    SessionIdx  = 0
                })
            }
        }
    }
}

Write-Host "  TICK=$($ticks.Count)  EVENT=$($events.Count)  END=$($ends.Count)"

# ---------------------------------------------------------------------------
# 3.  Assign session indices PER SIDE
#     A TICK whose ElMin < previous TICK's ElMin for the same side = new session.
#     Events and ENDs are assigned to the session index active at their ElMin
#     for their side (last-TICK session that is <= ElMin, or session 0).
# ---------------------------------------------------------------------------
$sideLastElMin    = @{}   # side -> last seen ElMin
$sideSessionIdx   = @{}   # side -> current session index
$sideTickSessions = @{}   # side -> ordered list of (elMin, sessionIdx) for binary search

foreach ($t in $ticks) {
    $side  = $t.Side
    $elMin = $t.ElMin

    if (-not $sideLastElMin.ContainsKey($side)) {
        $sideLastElMin[$side]    = $elMin
        $sideSessionIdx[$side]   = 0
        $sideTickSessions[$side] = [System.Collections.Generic.List[object]]::new()
    } elseif ($elMin -lt $sideLastElMin[$side]) {
        # ElMin reset = new session
        $sideSessionIdx[$side]++
        Write-Host "  Session boundary detected for $side at ElMin=$elMin (was $($sideLastElMin[$side])) -> session $($sideSessionIdx[$side])"
    }
    $sideLastElMin[$side] = $elMin
    $t.SessionIdx = $sideSessionIdx[$side]
    $sideTickSessions[$side].Add([pscustomobject]@{ ElMin = $elMin; SessionIdx = $t.SessionIdx })
}

# Helper: find session index for an ElMin value given a side's tick-session list
function Get-SessionForElMin {
    param([string]$side, [int]$elMin)
    if (-not $sideTickSessions.ContainsKey($side)) { return 0 }
    $list = $sideTickSessions[$side]
    $best = 0
    foreach ($entry in $list) {
        if ($entry.ElMin -le $elMin) { $best = $entry.SessionIdx }
        else { break }
    }
    return $best
}

foreach ($e in $events) {
    $e.SessionIdx = Get-SessionForElMin $e.Side $e.ElMin
}
foreach ($e in $ends) {
    $e.SessionIdx = Get-SessionForElMin $e.Side $e.ElMin
}

# ---------------------------------------------------------------------------
# 4.  Discover all (side, sessionIdx) pairs present in TICKs
# ---------------------------------------------------------------------------
$sessionKeys = [System.Collections.Generic.HashSet[string]]::new()
foreach ($t in $ticks)  { [void]$sessionKeys.Add("$($t.Side):$($t.SessionIdx)") }
foreach ($e in $ends)   { [void]$sessionKeys.Add("$($e.Side):$($e.SessionIdx)") }

# Build per-key lists
$ticksByKey  = @{}
$eventsByKey = @{}
$endsByKey   = @{}

foreach ($t in $ticks) {
    $k = "$($t.Side):$($t.SessionIdx)"
    if (-not $ticksByKey.ContainsKey($k))  { $ticksByKey[$k]  = [System.Collections.Generic.List[hashtable]]::new() }
    $ticksByKey[$k].Add($t)
}
foreach ($e in $events) {
    $k = "$($e.Side):$($e.SessionIdx)"
    if (-not $eventsByKey.ContainsKey($k)) { $eventsByKey[$k] = [System.Collections.Generic.List[hashtable]]::new() }
    $eventsByKey[$k].Add($e)
}
foreach ($e in $ends) {
    $k = "$($e.Side):$($e.SessionIdx)"
    if (-not $endsByKey.ContainsKey($k))   { $endsByKey[$k]   = [System.Collections.Generic.List[hashtable]]::new() }
    $endsByKey[$k].Add($e)
}

# ---------------------------------------------------------------------------
# 5.  Build session summaries
#     Global row number across all (side, session) pairs, sorted by side then sessionIdx
# ---------------------------------------------------------------------------
$rowList = [System.Collections.Generic.List[hashtable]]::new()

$sortedKeys = $sessionKeys | Sort-Object

foreach ($key in $sortedKeys) {
    $split   = $key -split ':'
    $side    = $split[0]
    $sessIdx = [int]$split[1]

    $myTicks  = if ($ticksByKey.ContainsKey($key))  { $ticksByKey[$key]  } else { @() }
    $myEvents = if ($eventsByKey.ContainsKey($key)) { $eventsByKey[$key] } else { @() }
    $myEnds   = if ($endsByKey.ContainsKey($key))   { $endsByKey[$key]   } else { @() }

    # END record (take last one if multiple)
    $endRec = $null
    if ($myEnds.Count -gt 0) {
        $myEnds_arr = @($myEnds)
        $endRec = $myEnds_arr[-1]
    }

    # Towns curve from TICKs
    $townsCurve = ""
    $tickCount  = $myTicks.Count
    if ($tickCount -gt 0) {
        $sorted = @($myTicks | Sort-Object { $_.ElMin })
        $tStart = $sorted[0].TownsHeld
        $tMid   = $sorted[[Math]::Floor($sorted.Count / 2)].TownsHeld
        $tEnd   = $sorted[-1].TownsHeld
        $townsCurve = "start=$tStart / mid=$tMid / end=$tEnd"
    }

    # Decode upgrades from last TICK
    $upgDecoded = ""
    if ($tickCount -gt 0) {
        $lastTick   = @($myTicks | Sort-Object { $_.ElMin })[-1]
        $upgDecoded = Decode-UpgCsv $lastTick.UpgCsv
    }

    # Max foundedTeams
    $maxFounded = 0
    foreach ($t in $myTicks) { if ($t.FoundedTeams -gt $maxFounded) { $maxFounded = $t.FoundedTeams } }

    # Event counts
    $eventCounts = @{}
    $errorCount  = 0
    foreach ($ev in $myEvents) {
        if (-not $eventCounts.ContainsKey($ev.EventType)) { $eventCounts[$ev.EventType] = 0 }
        $eventCounts[$ev.EventType]++
        if ($ev.EventType -eq 'ERROR') { $errorCount++ }
    }
    $evSummary = ($eventCounts.GetEnumerator() | Sort-Object Name |
        ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ', '

    $rowList.Add(@{
        Side        = $side
        SessionIdx  = $sessIdx
        Duration    = if ($endRec) { $endRec.DurationMin } else { "?" }
        Winner      = if ($endRec) { $endRec.Winner }      else { "(no END)" }
        Doctrine    = if ($endRec) { $endRec.Doctrine }    else { "?" }
        TownsEnd    = if ($endRec) { $endRec.TownsHeld }   else { "?" }
        FundsLeft   = if ($endRec) { $endRec.FundsLeft }   else { "?" }
        TownsCurve  = $townsCurve
        UpgDecoded  = $upgDecoded
        MaxFounded  = $maxFounded
        Events      = $evSummary
        ErrorCount  = $errorCount
        TickCount   = $tickCount
    })
}

# Assign sequential display row numbers
$rowNum = 0
foreach ($r in $rowList) {
    $rowNum++
    $r.RowNum = $rowNum
}

# ---------------------------------------------------------------------------
# 6.  Print table to console
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "=== AICOM SESSION SCORING TABLE ==="
Write-Host ("{0,-4} {1,-8} {2,-5} {3,-6} {4,-12} {5,-6} {6,-5} {7,-6} {8,-10} {9}" -f
    "#","Side","Sess","DurMin","Winner","Doctri","Towns","Funds","Founded","Upgrades")
Write-Host ("-" * 100)
foreach ($r in $rowList) {
    Write-Host ("{0,-4} {1,-8} {2,-5} {3,-6} {4,-12} {5,-6} {6,-5} {7,-6} {8,-10} {9}" -f
        $r.RowNum, $r.Side, $r.SessionIdx, $r.Duration, $r.Winner,
        $r.Doctrine, $r.TownsEnd, $r.FundsLeft, $r.MaxFounded, $r.UpgDecoded)
}

# ---------------------------------------------------------------------------
# 7.  Write markdown digest
# ---------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $DigestDir)) { New-Item -ItemType Directory -Force -Path $DigestDir | Out-Null }
$dateTag    = Get-Date -Format "yyyy-MM-dd"
$digestPath = Join-Path $DigestDir "digest-$dateTag.md"

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("# AICOM Session Scoring Digest — $dateTag")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("**Source RPT:** ``$RptPath``")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Summary Table")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| # | Side | Sess | DurMin | Winner | Doctrine | TownsEnd | FundsLeft | FoundedMax | TownsCurve | Upgrades | Events |")
[void]$sb.AppendLine("|---|------|------|--------|--------|----------|----------|-----------|------------|------------|----------|--------|")
foreach ($r in $rowList) {
    $row = "| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} | {9} | {10} | {11} |" -f
        $r.RowNum, $r.Side, $r.SessionIdx, $r.Duration, $r.Winner, $r.Doctrine,
        $r.TownsEnd, $r.FundsLeft, $r.MaxFounded, $r.TownsCurve, $r.UpgDecoded, $r.Events
    [void]$sb.AppendLine($row)
}
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Per-Session Detail")
[void]$sb.AppendLine("")
foreach ($r in $rowList) {
    [void]$sb.AppendLine("### Row $($r.RowNum) — $($r.Side) session $($r.SessionIdx) — $($r.Duration) min")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("- **Winner:** $($r.Winner)")
    [void]$sb.AppendLine("- **Doctrine:** $($r.Doctrine)")
    [void]$sb.AppendLine("- **Towns held at end:** $($r.TownsEnd)")
    [void]$sb.AppendLine("- **Funds left:** $($r.FundsLeft)")
    [void]$sb.AppendLine("- **Max founded teams:** $($r.MaxFounded)")
    [void]$sb.AppendLine("- **Towns curve (start/mid/end):** $($r.TownsCurve)")
    [void]$sb.AppendLine("- **Upgrades at end:** $($r.UpgDecoded)")
    [void]$sb.AppendLine("- **TICK samples:** $($r.TickCount)")
    [void]$sb.AppendLine("- **Events:** $($r.Events)")
    [void]$sb.AppendLine("")
}
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("*Generated by Score-AicomRounds.ps1*")

[System.IO.File]::WriteAllText($digestPath, $sb.ToString(), [System.Text.Encoding]::UTF8)
Write-Host ""
Write-Host "Digest written to: $digestPath"

# ---------------------------------------------------------------------------
# 8.  Pass/fail gate — evaluated against the LATEST session only
# ---------------------------------------------------------------------------
$gateRequested = ($MinTeamsFounded -gt 0) -or ($MinTicksPerSide -gt 0) -or ($MaxErrorBlocks -ge 0)

if (-not $gateRequested) { exit 0 }

Write-Host ""
Write-Host "=== PASS/FAIL GATE (latest session) ==="

# Latest session = highest SessionIdx across all rows
$latestSessIdx = ($rowList | ForEach-Object { $_.SessionIdx } | Measure-Object -Maximum).Maximum
$latestRows    = @($rowList | Where-Object { $_.SessionIdx -eq $latestSessIdx })

$fails = [System.Collections.Generic.List[string]]::new()

if ($MinTeamsFounded -gt 0) {
    $maxFounded = ($latestRows | ForEach-Object { $_.MaxFounded } | Measure-Object -Maximum).Maximum
    if ($null -eq $maxFounded -or $maxFounded -lt $MinTeamsFounded) {
        $fails.Add("MinTeamsFounded: got=$maxFounded required>=$MinTeamsFounded")
    } else {
        Write-Host "  PASS MinTeamsFounded: $maxFounded >= $MinTeamsFounded"
    }
}

if ($MinTicksPerSide -gt 0) {
    foreach ($row in $latestRows) {
        if ($row.TickCount -lt $MinTicksPerSide) {
            $fails.Add("MinTicksPerSide [$($row.Side)]: got=$($row.TickCount) required>=$MinTicksPerSide")
        } else {
            Write-Host "  PASS MinTicksPerSide [$($row.Side)]: $($row.TickCount) >= $MinTicksPerSide"
        }
    }
}

if ($MaxErrorBlocks -ge 0) {
    $totalErrors = ($latestRows | ForEach-Object { $_.ErrorCount } | Measure-Object -Sum).Sum
    if ($null -eq $totalErrors) { $totalErrors = 0 }
    if ($totalErrors -gt $MaxErrorBlocks) {
        $fails.Add("MaxErrorBlocks: got=$totalErrors allowed<=$MaxErrorBlocks")
    } else {
        Write-Host "  PASS MaxErrorBlocks: $totalErrors <= $MaxErrorBlocks"
    }
}

if ($fails.Count -gt 0) {
    Write-Host ""
    Write-Host "GATE RESULT: FAIL"
    foreach ($f in $fails) { Write-Host "  FAIL: $f" }
    exit 1
} else {
    Write-Host ""
    Write-Host "GATE RESULT: PASS"
    exit 0
}
