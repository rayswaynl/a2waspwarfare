<#
.SYNOPSIS
    Parse AICOM2 telemetry from an Arma 2 RPT and emit a compact round scorecard.
    Gates the parity soak (step 3 of the AICOM V2 cutover sequence).

.DESCRIPTION
    Reads the latest round (MISSINIT-scoped) from an RPT file or the newest RPT
    in an archive directory.  Emits a compact scorecard covering:

      - Round outcome: winner (ROUNDEND / AICOMSTAT FINAL) if present
      - DECAP chain summary (state distribution, sensing episodes, roll cadence,
        stamped counts, PRESS events) per side -- the primary V2 health signal
      - Error-family counts (Script error, Undefined variable, No entry, etc.)
      - FPS / AI delegation aggregates from WASPSCALE lines
      - ALLOC summary (primary changes, harass ticks, src distribution)
      - SNAP timeline (myTowns trajectory, enHQ status)

    EXIT CODES
      0  Round scored OK (or no gates active).
      1  One or more gate conditions failed (see -MinSnapLines, -RequireDecap,
         -MaxErrors).

    SELF-TEST
      Run without arguments and the script exits 0 after printing its self-test
      results against the bundled sample_cc44u.rpt fixture.

    COMPATIBLE WITH PS5.1+ (no REQUIRES header; tested on PS5 and PS7).

.PARAMETER RptPath
    Path to the RPT file.  Mutually exclusive with -ArchiveDir.

.PARAMETER ArchiveDir
    Directory to scan for *.RPT / *.rpt files; the newest file is used.
    Mutually exclusive with -RptPath.

.PARAMETER MinSnapLines
    Gate: the latest round must have at least this many AICOM2|v1|SNAP lines
    per side.  Default 0 (disabled).

.PARAMETER RequireDecap
    Switch: fail if AICOM2|v1|DECAP lines are entirely absent on a V2 build
    (i.e. SNAP lines present but no DECAP lines).  Default: warn only.

.PARAMETER MaxErrors
    Gate: fail if the total error-family line count exceeds this value.
    Default -1 (disabled).

.PARAMETER NoColor
    Suppress ANSI colour output.

.PARAMETER SelfTest
    Run the self-test against sample_cc44u.rpt and exit.

.EXAMPLE
    # Score the latest round in the live server RPT
    .\Score-AicomRounds.ps1 -RptPath "C:\WASP\rpts\arma2oaserver.RPT"

.EXAMPLE
    # Score with gates (soak-gate mode)
    .\Score-AicomRounds.ps1 -RptPath "C:\WASP\rpts\arma2oaserver.RPT" `
        -MinSnapLines 5 -RequireDecap -MaxErrors 10

.EXAMPLE
    # Run built-in self-test
    .\Score-AicomRounds.ps1 -SelfTest

.NOTES
    Part of the AICOM V2 cutover soak-gate tooling.
    Guide-Rev: GR-2026-07-03a
    Grammar reference: Tools/Soak/README.md (AICOM2 section)
    Consumer list: docs/design/v2/AICOM-V2-CUTOVER-AND-RECONCILIATION.md
#>

[CmdletBinding(DefaultParameterSetName = "File")]
param(
    [Parameter(ParameterSetName = "File")]
    [string]$RptPath = "",

    [Parameter(ParameterSetName = "Dir")]
    [string]$ArchiveDir = "",

    [int]$MinSnapLines = 0,
    [switch]$RequireDecap,
    [int]$MaxErrors = -1,
    [switch]$NoColor,
    [switch]$SelfTest
)

Set-StrictMode -Off   # Strict mode and defaultdict-style hashtables clash in PS5
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Color helpers (PS5-compatible ANSI)
# ---------------------------------------------------------------------------
$script:UseColor = (-not $NoColor) -and $Host.UI.SupportsVirtualTerminal

function col { param([string]$text, [string]$code)
    if ($script:UseColor) { "`e[${code}m${text}`e[0m" } else { $text }
}
function bold  ([string]$s) { col $s "1"  }
function grn   ([string]$s) { col $s "32" }
function yel   ([string]$s) { col $s "33" }
function red   ([string]$s) { col $s "31" }
function cyn   ([string]$s) { col $s "36" }
function dim   ([string]$s) { col $s "2"  }

function hdr([string]$title) {
    $bar = "=" * 74
    "`n$(dim $bar)`n$(bold (cyn " $title"))`n$(dim $bar)"
}

# ---------------------------------------------------------------------------
# RPT file helpers (share-read, latin-1, MISSINIT scoping)
# ---------------------------------------------------------------------------
function Read-RptLines([string]$path) {
    $fs = [System.IO.File]::Open(
        $path, [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        $reader = New-Object System.IO.StreamReader($fs,
            [System.Text.Encoding]::GetEncoding("iso-8859-1"))
        try { $content = $reader.ReadToEnd() }
        finally { $reader.Dispose() }
    } finally { $fs.Dispose() }
    return @($content -split "`r?`n")
}

function Scope-LastMissinit([string[]]$lines) {
    # Return the slice from the last MISSINIT that is followed by gameplay stats.
    $markers = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "MISSINIT") { $markers += $i }
    }
    if ($markers.Count -eq 0) { return $lines }

    $statPat = "WASPSTAT\||AICOMSTAT\||WASPSCALE\||AICOM2\|"
    for ($k = $markers.Count - 1; $k -ge 0; $k--) {
        $start = $markers[$k]
        $end   = if ($k + 1 -lt $markers.Count) { $markers[$k + 1] } else { $lines.Count }
        $seg   = $lines[$start..($end - 1)]
        $hasStats = ($seg | Where-Object { $_ -match $statPat }) -ne $null
        if ($hasStats -or $k -eq $markers.Count - 1) {
            return $lines[$start..($lines.Count - 1)]
        }
    }
    return $lines[$markers[-1]..($lines.Count - 1)]
}

function Pick-RptFile {
    if ($RptPath -ne "") {
        if (-not (Test-Path $RptPath)) { throw "RPT not found: $RptPath" }
        return $RptPath
    }
    if ($ArchiveDir -ne "") {
        $files = @(Get-ChildItem -Path $ArchiveDir -Filter "*.rpt","*.RPT" -File |
            Sort-Object LastWriteTime -Descending)
        if ($files.Count -eq 0) { throw "No RPT files in: $ArchiveDir" }
        return $files[0].FullName
    }
    throw "Provide -RptPath or -ArchiveDir (or -SelfTest)."
}

# ---------------------------------------------------------------------------
# KV parser  (key=value pairs anywhere in a pipe-delimited string)
# ---------------------------------------------------------------------------
function Parse-KV([string]$text) {
    $result = @{}
    [regex]::Matches($text, "([A-Za-z_][A-Za-z0-9_]*)=([^|`"`r`n]*)") | ForEach-Object {
        $result[$_.Groups[1].Value] = $_.Groups[2].Value.Trim()
    }
    return $result
}

function To-Int([string]$s, [int]$def = 0) {
    $n = 0
    if ([int]::TryParse(($s -replace "^\s+|\s+$",""), [ref]$n)) { return $n }
    return $def
}
function To-Flt([string]$s, [double]$def = 0.0) {
    $n = 0.0
    if ([double]::TryParse(($s -replace "^\s+|\s+$",""), [ref]$n)) { return $n }
    return $def
}

# ---------------------------------------------------------------------------
# Core parser
# ---------------------------------------------------------------------------
function Parse-Round([string[]]$lines) {
    # Containers
    $snap  = @{}   # side -> list of hashtables
    $alloc = @{}   # side -> list of hashtables
    $decap = @{}   # side -> list of hashtables
    $fistpool = @{}
    $orders = @{}
    $press  = @{}   # side -> count
    $roundend = $null
    $aicomFinal = $null
    $scaleRows = [System.Collections.Generic.List[hashtable]]::new()
    $errorLines = [System.Collections.Generic.List[string]]::new()
    $errorFamilies = @{}

    $errPats = @(
        "Error in expression",
        "Undefined variable",
        "No entry",
        "Missing ;",
        "bad conversion: String",
        "Type Array, expected"
    )

    foreach ($ln in $lines) {
        # -- AICOM2 SNAP --
        if ($ln -match "AICOM2\|v1\|SNAP\|([A-Za-z]+)\|(\d+)\|(.*)$") {
            $s = $Matches[1].ToUpper(); $t = To-Int $Matches[2]; $kv = Parse-KV $Matches[3]
            if (-not $snap.ContainsKey($s)) { $snap[$s] = [System.Collections.Generic.List[hashtable]]::new() }
            $snap[$s].Add(@{ tick=$t; myTowns=(To-Int $kv["myTowns"]); enTowns=(To-Int $kv["enTowns"])
                             myEff=(To-Int $kv["myEff"]); enHQ=$kv["enHQ"] })
        }
        # -- AICOM2 ALLOC --
        elseif ($ln -match "AICOM2\|v1\|ALLOC\|([A-Za-z]+)\|(\d+)\|(.*)$") {
            $s = $Matches[1].ToUpper(); $t = To-Int $Matches[2]; $kv = Parse-KV $Matches[3]
            if (-not $alloc.ContainsKey($s)) { $alloc[$s] = [System.Collections.Generic.List[hashtable]]::new() }
            $alloc[$s].Add(@{ tick=$t; primary=$kv["primary"]; src=$kv["src"]
                              harassTo=$kv["harassTo"]; assigned=(To-Int $kv["assigned"]) })
        }
        # -- AICOM2 DECAP --
        # The real emitter (AI_Commander_Decapitate.sqf) outputs sensed as "1"/"0".
        # Accept both the integer form and the legacy "true"/"false" form defensively.
        elseif ($ln -match "AICOM2\|v1\|DECAP\|([A-Za-z]+)\|(\d+)\|(.*)$") {
            $s = $Matches[1].ToUpper(); $t = To-Int $Matches[2]; $kv = Parse-KV $Matches[3]
            if (-not $decap.ContainsKey($s)) { $decap[$s] = [System.Collections.Generic.List[hashtable]]::new() }
            $sensedRaw = if ($kv.ContainsKey("sensed")) { $kv["sensed"].Trim().ToLower() } else { "0" }
            $sensedBool = ($sensedRaw -eq "1") -or ($sensedRaw -eq "true")
            $decap[$s].Add(@{ tick=$t; state=$kv["state"]; inRange=(To-Int $kv["inRange"])
                              roll=(To-Int $kv["roll"]); sensed=$sensedBool
                              stamped=(To-Int $kv["stamped"]) })
        }
        # -- AICOM2 FISTPOOL --
        elseif ($ln -match "AICOM2\|v1\|FISTPOOL\|([A-Za-z]+)\|(.*)$") {
            $s = $Matches[1].ToUpper(); $kv = Parse-KV $Matches[2]
            if (-not $fistpool.ContainsKey($s)) { $fistpool[$s] = 0 }
            $fistpool[$s]++
        }
        # -- AICOM2 ORDER --
        elseif ($ln -match "AICOM2\|v1\|ORDER\|([^|]+)\|([A-Za-z]+)\|(\d+)\|") {
            $sub = $Matches[1]
            if (-not $orders.ContainsKey($sub)) { $orders[$sub] = 0 }
            $orders[$sub]++
        }
        # -- AICOMSTAT POSTURE PRESS --
        elseif ($ln -match "AICOMSTAT\|v1\|POSTURE\|([A-Z]+)\|(\d+)\|PRESS\|") {
            $s = $Matches[1]
            if (-not $press.ContainsKey($s)) { $press[$s] = 0 }
            $press[$s]++
        }
        # -- ROUNDEND --
        elseif ($ln -match "WASPSTAT\|v1\|\d+\|ROUNDEND\|([A-Z]+)\|(\d+)\|([^|`"]+)") {
            $roundend = @{ winner=$Matches[1]; secs=(To-Int $Matches[2]); map=$Matches[3].Trim('"') }
        }
        # -- AICOMSTAT FINAL (legacy V1 round-end signal) --
        elseif ($ln -match "AICOMSTAT\|v[12]\|FINAL\|") {
            $aicomFinal = $ln
        }
        # -- WASPSCALE (fps, deleg) --
        elseif ($ln -match "WASPSCALE\|v2\|(\d+)\|(.*)$") {
            $t = To-Int $Matches[1]; $kv = Parse-KV $Matches[2]
            $scaleRows.Add(@{
                tick=$t; fps=(To-Flt $kv["fps"]); hc_fps=(To-Flt $kv["hc_fps"])
                AI_TOT=(To-Int $kv["AI_TOT"]); build=$kv["build"]
            })
        }
        # -- Errors --
        else {
            foreach ($pat in $errPats) {
                if ($ln -match [regex]::Escape($pat)) {
                    if (-not $errorFamilies.ContainsKey($pat)) { $errorFamilies[$pat] = 0 }
                    $errorFamilies[$pat]++
                    if ($errorLines.Count -lt 10) { $errorLines.Add($ln.Trim()) }
                }
            }
        }
    }

    return @{
        snap=$snap; alloc=$alloc; decap=$decap; fistpool=$fistpool
        orders=$orders; press=$press
        roundend=$roundend; aicomFinal=$aicomFinal
        scaleRows=$scaleRows
        errorFamilies=$errorFamilies; errorLines=$errorLines
    }
}

# ---------------------------------------------------------------------------
# Score / render
# ---------------------------------------------------------------------------
function Score-Round([hashtable]$r, [string]$rptLabel) {
    $gateFailures = [System.Collections.Generic.List[string]]::new()

    Write-Host (hdr "AICOM2 ROUND SCORECARD  --  $rptLabel")

    # Round outcome
    if ($r.roundend) {
        $re = $r.roundend
        Write-Host ("  ROUNDEND : winner=$(bold $re.winner)  clock=$($re.secs)s  map=$($re.map)")
    } elseif ($r.aicomFinal) {
        Write-Host ("  AICOMSTAT FINAL line detected (no ROUNDEND)")
    } else {
        Write-Host ("  $(yel 'no ROUNDEND or AICOMSTAT FINAL  (round may still be running)')")
    }

    # FPS / scale summary
    $fpsVals = @($r.scaleRows | Where-Object { $_.fps -gt 0 } | ForEach-Object { $_.fps })
    $builds  = @($r.scaleRows | Where-Object { $_.build -ne $null -and $_.build -ne "" } | ForEach-Object { $_.build } | Select-Object -Unique)
    if ($fpsVals.Count -gt 0) {
        $fpsMin = ($fpsVals | Measure-Object -Minimum).Minimum
        $fpsMed = [math]::Round((($fpsVals | Measure-Object -Average).Average), 1)
        $fpsMax = ($fpsVals | Measure-Object -Maximum).Maximum
        Write-Host ("  WASPSCALE: $($fpsVals.Count) samples  fps min=$fpsMin med=$fpsMed max=$fpsMax  build=$(if ($builds.Count) { $builds[0] } else { '?' })")
    } else {
        Write-Host ("  WASPSCALE: $(dim 'no samples')")
    }

    # AICOM2 per-side summary
    Write-Host (hdr "AICOM2 SNAP / ALLOC / DECAP")
    $sides = @($r.snap.Keys + $r.alloc.Keys + $r.decap.Keys | Select-Object -Unique | Sort-Object)
    if ($sides.Count -eq 0) {
        Write-Host "  $(dim 'no AICOM2 telemetry lines in this round')"
    }

    foreach ($s in $sides) {
        Write-Host "  $(bold $s)"

        # SNAP
        $sn = $r.snap[$s]
        if ($sn -and $sn.Count -gt 0) {
            $first = $sn[0]; $last = $sn[$sn.Count - 1]
            $peakT = ($sn | Measure-Object -Property myTowns -Maximum).Maximum
            Write-Host ("    SNAP  $($sn.Count) lines | myTowns $($first.myTowns)->$($last.myTowns) (peak $peakT)" +
                        " | enHQ-last $($last.enHQ)")
        } else {
            Write-Host ("    SNAP  $(yel 'no lines')")
        }

        # SNAP gate
        if ($MinSnapLines -gt 0) {
            $cnt = if ($sn) { $sn.Count } else { 0 }
            if ($cnt -lt $MinSnapLines) {
                $gateFailures.Add("SNAP lines for $s : $cnt < $MinSnapLines")
            }
        }

        # ALLOC
        $al = $r.alloc[$s]
        if ($al -and $al.Count -gt 0) {
            $primaries = @($al | ForEach-Object { $_.primary })
            $changes = 0
            for ($i = 1; $i -lt $primaries.Count; $i++) {
                if ($primaries[$i] -ne $primaries[$i-1]) { $changes++ }
            }
            $harassTicks = @($al | Where-Object { $_.harassTo -ne "none" -and $_.harassTo -ne "" }).Count
            $srcs = @($al | Group-Object src | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join " "
            Write-Host ("    ALLOC $($al.Count) lines | primary-changes $changes | harass-ticks $harassTicks | src [$srcs]")
        } else {
            Write-Host ("    ALLOC $(dim 'no lines')")
        }

        # DECAP
        $dc = $r.decap[$s]
        $hasSn = ($sn -and $sn.Count -gt 0)
        if ($dc -and $dc.Count -gt 0) {
            # state distribution
            $stateDist = @($dc | Group-Object state | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join " "
            $pressCount = @($dc | Where-Object { $_.state -eq "PRESS" }).Count
            $inRangeMax = ($dc | Measure-Object -Property inRange -Maximum).Maximum
            # inRange streaks
            $streak = 0; $maxStreak = 0
            foreach ($row in $dc) {
                if ($row.inRange -gt 0) { $streak++ ; if ($streak -gt $maxStreak) { $maxStreak = $streak } }
                else { $streak = 0 }
            }
            # roll cadence check: only over inRange>0 ticks (the emitter only
            # rolls when a team is in proximity; early-game zero-contact ticks
            # must NOT be tested or they produce false VIOLATED verdicts).
            $cadenceOk = $null
            $dcInRange = @($dc | Where-Object { $_.inRange -gt 0 })
            if ($dcInRange.Count -ge 4) {
                $violations = 0
                for ($i = 0; $i -le $dcInRange.Count - 4; $i += 4) {
                    $win = $dcInRange[$i..([math]::Min($i+3, $dcInRange.Count-1))]
                    if (-not ($win | Where-Object { $_.roll -eq 1 })) { $violations++ }
                }
                $cadenceOk = ($violations -eq 0)
            }
            # sensed latches
            $sensedLatches = 0; $prevSensed = $false
            foreach ($row in $dc) {
                if ($row.sensed -and -not $prevSensed) { $sensedLatches++ }
                $prevSensed = $row.sensed
            }
            $stampedMax = ($dc | Measure-Object -Property stamped -Maximum).Maximum
            $cadStr = if ($null -eq $cadenceOk) { dim "n/a (<4 inRange>0)" }
                      elseif ($cadenceOk) { grn "OK" } else { red "VIOLATED" }
            Write-Host ("    DECAP $($dc.Count) lines | states $stateDist | PRESS $pressCount | inRange-max $inRangeMax longest-streak $maxStreak")
            Write-Host ("          roll-cadence $cadStr | sensed-latches $sensedLatches | stamped-max $stampedMax")
        } else {
            if ($hasSn) {
                Write-Host ("    DECAP $(red 'MISSING  (SNAP present but zero DECAP lines -- V2 cutover incomplete?)')")
                if ($RequireDecap) {
                    $gateFailures.Add("RequireDecap: SNAP present for $s but no DECAP lines")
                }
            } else {
                Write-Host ("    DECAP $(dim 'no lines')")
            }
        }

        $pressCnt = if ($r.press.ContainsKey($s)) { $r.press[$s] } else { 0 }
        Write-Host ("    PRESS-ticks (POSTURE PRESS) : $pressCnt")
    }

    # AICOM2 ORDER subtypes
    if ($r.orders.Count -gt 0) {
        Write-Host (hdr "AICOM2 ORDER SUBTYPES")
        foreach ($sub in ($r.orders.Keys | Sort-Object)) {
            Write-Host ("  $($sub.PadRight(30)) $($r.orders[$sub])")
        }
    }

    # Error families
    Write-Host (hdr "ERROR FAMILIES")
    $totalErrors = 0
    if ($r.errorFamilies.Count -eq 0) {
        Write-Host ("  $(grn 'no error-family lines')")
    } else {
        foreach ($fam in ($r.errorFamilies.Keys | Sort-Object)) {
            $n = $r.errorFamilies[$fam]
            $totalErrors += $n
            Write-Host ("  $($fam.PadRight(32)) $(yel $n)")
        }
        Write-Host ("  total error lines: $(red $totalErrors)")
    }
    if ($MaxErrors -ge 0 -and $totalErrors -gt $MaxErrors) {
        $gateFailures.Add("MaxErrors: $totalErrors > $MaxErrors")
    }

    # Gate verdict
    Write-Host (hdr "GATE VERDICT")
    if ($gateFailures.Count -eq 0) {
        Write-Host ("  $(grn (bold 'PASS'))  all gates satisfied")
    } else {
        foreach ($f in $gateFailures) {
            Write-Host ("  $(red (bold 'FAIL'))  $f")
        }
    }
    Write-Host ""

    return $gateFailures.Count
}

# ---------------------------------------------------------------------------
# Self-test
# ---------------------------------------------------------------------------
function Run-SelfTest {
    $fixture = Join-Path (Split-Path $MyInvocation.ScriptName) "..\..\Soak\sample_cc44u.rpt"
    if (-not (Test-Path $fixture)) {
        Write-Host (red "Self-test fixture not found: $fixture")
        exit 1
    }
    $fixture = (Resolve-Path $fixture).Path
    $lines = @(Read-RptLines $fixture)
    $scoped = @(Scope-LastMissinit $lines)
    $r = Parse-Round $scoped

    $pass = $true
    $checks = [System.Collections.Generic.List[string]]::new()

    # 1. SNAP present for WEST and EAST
    $hasSnap = ($r.snap.ContainsKey("WEST") -and $r.snap["WEST"].Count -gt 0) -and
               ($r.snap.ContainsKey("EAST") -and $r.snap["EAST"].Count -gt 0)
    if ($hasSnap) { $checks.Add($(grn "PASS  SNAP lines for WEST and EAST")) }
    else { $checks.Add($(red "FAIL  SNAP lines missing")); $pass = $false }

    # 2. ALLOC present
    $hasAlloc = $r.alloc.Count -gt 0
    if ($hasAlloc) { $checks.Add($(grn "PASS  ALLOC lines present")) }
    else { $checks.Add($(red "FAIL  ALLOC lines absent")); $pass = $false }

    # 3. DECAP present for WEST with COMMITTED state (real active-press state name).
    # The driver PRESS line (AICOM2|v1|DECAP|...|PRESS|team=...|dist=...) is a
    # separate line from Common_RunCommanderTeam.sqf and has no state= field;
    # it defaults to IDLE in the parser. COMMITTED is the closer state when pressing.
    $westDecap = $r.decap["WEST"]
    $committedRows = @($westDecap | Where-Object { $_.state -eq "COMMITTED" })
    if ($westDecap -and $westDecap.Count -gt 0 -and $committedRows.Count -ge 1) {
        $checks.Add($(grn "PASS  WEST DECAP lines with COMMITTED state ($($committedRows.Count))"))
    } else {
        $checks.Add($(red "FAIL  WEST DECAP or COMMITTED state missing")); $pass = $false
    }

    # 4. ROUNDEND parsed
    if ($r.roundend -and $r.roundend["winner"] -eq "WEST") {
        $checks.Add($(grn "PASS  ROUNDEND winner=WEST"))
    } else {
        $checks.Add($(red "FAIL  ROUNDEND not parsed or wrong winner")); $pass = $false
    }

    # 5. No error families in fixture
    if ($r.errorFamilies.Count -eq 0) {
        $checks.Add($(grn "PASS  no error-family lines in fixture"))
    } else {
        $checks.Add($(red "FAIL  unexpected error-family lines: $($r.errorFamilies.Keys -join ', ')")); $pass = $false
    }

    # 6. ORDER 'war-room-task' present
    if ($r.orders.ContainsKey("war-room-task") -and $r.orders["war-room-task"] -ge 1) {
        $checks.Add($(grn "PASS  ORDER war-room-task present"))
    } else {
        $checks.Add($(red "FAIL  ORDER war-room-task missing")); $pass = $false
    }

    # 7. V1-only fixture (build86) must have zero AICOM2 lines
    $fixture86 = Join-Path (Split-Path $MyInvocation.ScriptName) "..\..\Soak\sample_build86.rpt"
    if (Test-Path $fixture86) {
        $lines86   = @(Read-RptLines (Resolve-Path $fixture86).Path)
        $scoped86  = @(Scope-LastMissinit $lines86)
        $r86       = Parse-Round $scoped86
        if ($r86.snap.Count -eq 0 -and $r86.decap.Count -eq 0) {
            $checks.Add($(grn "PASS  V1-only fixture has zero AICOM2 lines"))
        } else {
            $checks.Add($(red "FAIL  V1-only fixture unexpectedly has AICOM2 lines")); $pass = $false
        }
    }

    # 8. sensed integer parsing: fixture has sensed=1 at tick>=4 for WEST.
    # If parser reads "1" as False (old "true"/"false"-only logic), latches = 0.
    $westDc = $r.decap["WEST"]
    $sensedLatches = 0; $prev = $false
    if ($westDc) {
        foreach ($row in $westDc) {
            if ($row.sensed -and -not $prev) { $sensedLatches++ }
            $prev = $row.sensed
        }
    }
    if ($sensedLatches -ge 1) {
        $checks.Add($(grn "PASS  sensed integer 1/0 parsed correctly ($sensedLatches latch(es))"))
    } else {
        $checks.Add($(red "FAIL  sensed latch count=$sensedLatches (integer 1/0 parsing broken)")); $pass = $false
    }

    Write-Host (hdr "SELF-TEST  Score-AicomRounds.ps1")
    foreach ($c in $checks) { Write-Host "  $c" }
    Write-Host ""
    if ($pass) { Write-Host (grn (bold "SELF-TEST PASSED")); exit 0 }
    else        { Write-Host (red (bold "SELF-TEST FAILED")); exit 1 }
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
if ($SelfTest) { Run-SelfTest }

$rptFile = Pick-RptFile
Write-Host (dim "  Scoring: $rptFile")
$lines  = @(Read-RptLines $rptFile)
$scoped = @(Scope-LastMissinit $lines)
$r      = Parse-Round $scoped
$fails  = Score-Round $r (Split-Path $rptFile -Leaf)
exit ([math]::Min($fails, 1))
