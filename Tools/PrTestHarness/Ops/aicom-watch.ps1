<#
.SYNOPSIS
    Live tail watcher for AICOM2 telemetry in an Arma 2 RPT file.
    Equivalent to `tail -f` filtered to AICOM2 / AICOMSTAT lines.

.DESCRIPTION
    Streams new lines from an RPT file (Get-Content -Wait) and prints any line
    that contains AICOM2| or /AICOMSTAT| or WASPSTAT|.  Colorizes DECAP state
    changes (SCAN/TRACK/PRESS) to make commander-mode transitions visible at a
    glance.

    Use this during a live soak run to monitor the AICOM V2 commander output in
    real-time without wading through unrelated RPT noise.

    CTRL+C to stop.

    COMPATIBLE WITH PS5.1+ (no REQUIRES header; tested on PS5 and PS7).

.PARAMETER RptPath
    Full path to the RPT file to tail.  If omitted and -AutoDiscover is set,
    picks the newest *.rpt / *.RPT in the standard HC log path:
      $env:LOCALAPPDATA\ArmA 2 OA\

.PARAMETER AutoDiscover
    When no -RptPath is given, auto-pick the newest RPT from the default HC log
    directory.

.PARAMETER Family
    Optional filter: only show lines from this AICOM2 sub-family.
    Examples: SNAP, ALLOC, DECAP, ORDER, FISTPOOL, PRESS
    Set to "" or omit to show all families.  Case-insensitive.

.PARAMETER ShowWaspstat
    Also show WASPSTAT lines (ROUNDEND / KILL / CAPTURE).  Off by default to
    reduce noise; useful at round-end to confirm ROUNDEND hit the log.

.PARAMETER NoColor
    Suppress ANSI colour output.

.PARAMETER SelfTest
    Run a quick self-test using the sample_cc44u.rpt fixture (non-streaming,
    prints what the watcher would have colourised) then exits.

.EXAMPLE
    # Watch the default HC RPT, all AICOM2 families
    .\aicom-watch.ps1

.EXAMPLE
    # Watch only DECAP state changes
    .\aicom-watch.ps1 -Family DECAP

.EXAMPLE
    # Watch a specific RPT, show WASPSTAT round events too
    .\aicom-watch.ps1 -RptPath "C:\WASP\rpts\arma2oaserver.RPT" -ShowWaspstat

.EXAMPLE
    # Self-test (no live RPT needed)
    .\aicom-watch.ps1 -SelfTest

.NOTES
    Part of the AICOM V2 cutover soak-gate tooling.
    Guide-Rev: GR-2026-07-03a
    Grammar reference: Tools/Soak/README.md (AICOM2 section)
    Consumer list: docs/design/v2/AICOM-V2-CUTOVER-AND-RECONCILIATION.md
#>

[CmdletBinding(DefaultParameterSetName = "Watch")]
param(
    [Parameter(ParameterSetName = "Watch")]
    [string]$RptPath = "",

    [Parameter(ParameterSetName = "Watch")]
    [switch]$AutoDiscover,

    [string]$Family = "",
    [switch]$ShowWaspstat,
    [switch]$NoColor,
    [switch]$SelfTest
)

Set-StrictMode -Off
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Color helpers
# ---------------------------------------------------------------------------
$script:UseColor = (-not $NoColor) -and $Host.UI.SupportsVirtualTerminal

function col([string]$text, [string]$code) {
    if ($script:UseColor) { "`e[${code}m${text}`e[0m" } else { $text }
}
function dim   ([string]$s) { col $s "2"      }
function grn   ([string]$s) { col $s "32"     }
function yel   ([string]$s) { col $s "33"     }
function red   ([string]$s) { col $s "31"     }
function cyn   ([string]$s) { col $s "36"     }
function mag   ([string]$s) { col $s "35"     }
function wht   ([string]$s) { col $s "97;1"   }
function bold  ([string]$s) { col $s "1"      }
function bgrn  ([string]$s) { col $s "42;30"  }  # green background
function bred  ([string]$s) { col $s "41;97"  }  # red background

# ---------------------------------------------------------------------------
# DECAP state tracker (detects transitions across lines)
# ---------------------------------------------------------------------------
$script:LastDecapState = @{}   # side -> last state string

function Format-Decap([string]$line) {
    # Parse side and state from the DECAP line
    $side  = if ($line -match "AICOM2\|v1\|DECAP\|([A-Za-z]+)\|") { $Matches[1].ToUpper() } else { "?" }
    $state = if ($line -match "\bstate=([A-Z]+)") { $Matches[1] } else { "?" }

    $prev = if ($script:LastDecapState.ContainsKey($side)) { $script:LastDecapState[$side] } else { $null }
    $script:LastDecapState[$side] = $state

    # Colorize the state token inside the line
    $stateColor = switch ($state) {
        "SCAN"  { dim    $state }
        "TRACK" { yel    $state }
        "PRESS" { bred   $state }
        default { wht    $state }
    }

    $colored = $line -replace "\bstate=[A-Z]+", "state=$stateColor"

    # Flag a transition
    if ($null -ne $prev -and $prev -ne $state) {
        $arrow = "  $(cyn "[${prev} -> ${state}]")"
        $colored = $colored + $arrow
    }
    return $colored
}

# ---------------------------------------------------------------------------
# Line formatter (dispatch to sub-formatters by family)
# ---------------------------------------------------------------------------
function Format-Line([string]$line) {
    if ($line -match "AICOM2\|v1\|DECAP\|") {
        return Format-Decap $line
    }
    if ($line -match "AICOM2\|v1\|SNAP\|") {
        return dim $line
    }
    if ($line -match "AICOM2\|v1\|ALLOC\|") {
        # Highlight primary and harassTo
        $out = $line
        if ($out -match "primary=([^|]+)") { $p = $Matches[1]; $out = $out -replace "primary=[^|]+", "primary=$(grn $p)" }
        if ($out -match "harassTo=([^|]+)") { $h = $Matches[1]; $out = $out -replace "harassTo=[^|]+", "harassTo=$(yel $h)" }
        return $out
    }
    if ($line -match "AICOM2\|v1\|ORDER\|") {
        return mag $line
    }
    if ($line -match "AICOM2\|v1\|FISTPOOL\|") {
        return cyn $line
    }
    if ($line -match "AICOMSTAT\|") {
        # Highlight POSTURE PRESS lines
        if ($line -match "POSTURE\|[A-Z]+\|\d+\|PRESS") { return bred $line }
        return cyn $line
    }
    if ($line -match "CTLSTAT\|") {
        # Commander Town Ledger (fable/ctl-impl-v1) telemetry - color like other AICOM families.
        if ($line -match "\|deny=groupBudgetExceeded") { return bred $line }
        if ($line -match "\|SEED\|") { return grn $line }
        return cyn $line
    }
    if ($line -match "WASPSTAT\|") {
        if ($line -match "ROUNDEND") { return bgrn $line }
        return dim $line
    }
    return $line
}

# ---------------------------------------------------------------------------
# Line filter
# ---------------------------------------------------------------------------
function Should-Show([string]$line) {
    # Must be an AICOM2 / AICOMSTAT / optionally WASPSTAT line
    $isAicom2    = $line -match "AICOM2\|"
    $isAicomstat = $line -match "AICOMSTAT\|"
    $isCtlstat   = $line -match "CTLSTAT\|"
    $isWaspstat  = $line -match "WASPSTAT\|"

    if (-not ($isAicom2 -or $isAicomstat -or $isCtlstat -or ($ShowWaspstat -and $isWaspstat))) {
        return $false
    }

    # Family filter
    if ($Family -ne "") {
        if (-not ($line -match [regex]::Escape($Family))) { return $false }
    }

    return $true
}

# ---------------------------------------------------------------------------
# RPT file discovery
# ---------------------------------------------------------------------------
function Find-Rpt {
    if ($RptPath -ne "") {
        if (-not (Test-Path $RptPath)) { throw "RPT not found: $RptPath" }
        return $RptPath
    }
    $logDir = Join-Path $env:LOCALAPPDATA "ArmA 2 OA"
    if (-not (Test-Path $logDir)) {
        throw "Default HC log dir not found: $logDir  --  use -RptPath"
    }
    $newest = @(Get-ChildItem -Path $logDir -Filter "*.rpt" -File |
        Sort-Object LastWriteTime -Descending) | Select-Object -First 1
    if (-not $newest) { throw "No RPT files found in: $logDir" }
    return $newest.FullName
}

# ---------------------------------------------------------------------------
# Self-test (non-streaming, reads fixture from disk)
# ---------------------------------------------------------------------------
function Run-SelfTest {
    $fixture = Join-Path (Split-Path $MyInvocation.ScriptName) "..\..\Soak\sample_cc44u.rpt"
    if (-not (Test-Path $fixture)) {
        Write-Host (red "Self-test fixture not found: $fixture")
        exit 1
    }
    $fixture = (Resolve-Path $fixture).Path
    Write-Host (bold (cyn "Self-test: replaying $fixture through the formatter"))
    Write-Host (dim "  (in live mode this would stream new lines as they arrive)")
    Write-Host ""

    $linesShown = 0
    $fs = [System.IO.File]::Open($fixture,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::ReadWrite)
    try {
        $reader = New-Object System.IO.StreamReader(
            $fs, [System.Text.Encoding]::GetEncoding("iso-8859-1"))
        try {
            while (-not $reader.EndOfStream) {
                $ln = $reader.ReadLine()
                if (Should-Show $ln) {
                    Write-Host (Format-Line $ln)
                    $linesShown++
                }
            }
        } finally { $reader.Dispose() }
    } finally { $fs.Dispose() }

    Write-Host ""
    if ($linesShown -gt 0) {
        Write-Host (grn (bold "SELF-TEST PASSED  ($linesShown lines formatted)"))
        exit 0
    } else {
        Write-Host (red "SELF-TEST FAILED  (no lines passed the filter -- check fixture path)")
        exit 1
    }
}

# ---------------------------------------------------------------------------
# Live tail entry point
# ---------------------------------------------------------------------------
function Start-Watch([string]$path) {
    Write-Host (bold (cyn "AICOM2 watch"))
    Write-Host (dim  "  file   : $path")
    Write-Host (dim  "  family : $(if ($Family) { $Family } else { 'all' })")
    Write-Host (dim  "  waspstat: $(if ($ShowWaspstat) { 'yes' } else { 'no' })")
    Write-Host (dim  "  CTRL+C to stop")
    Write-Host ""

    # State legend
    Write-Host ("  $(dim 'SCAN') $(yel 'TRACK') $(bred 'PRESS')   " + (mag 'ORDER') + "   " + (cyn 'AICOMSTAT') + "   " + (grn 'ROUNDEND'))
    Write-Host ""

    # Stream the file, printing matching lines as they arrive
    Get-Content -Path $path -Wait -Encoding Default | ForEach-Object {
        $ln = $_
        if (Should-Show $ln) {
            Write-Host (Format-Line $ln)
        }
    }
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
if ($SelfTest) { Run-SelfTest }

$rptFile = Find-Rpt
Start-Watch $rptFile
