# Get-WindowedRpt.ps1 - shared windowed-RPT reader (claude-inbox#2 item 4).
#
# A2 OA RPT files NEVER truncate during a server's lifetime; whole-file greps get
# slower every boot and match stale errors from earlier missions. This helper
# returns ONLY the lines since the most recent mission init marker, reading the
# file with ReadWrite share so it never locks the RPT out from under the running
# server.
#
# Usage (dot-source from AicomWatch / post-deploy-verify.ps1):
#   . C:\WASP\monitor\Get-WindowedRpt.ps1
#   $lines = Get-WindowedRpt -RptPath $rpt                      # current-mission window
#   $errs  = Get-WindowedRpt -RptPath $rpt -Pattern 'Error|ERROR'
#   $boot  = Get-WindowedRpt -RptPath $rpt -WindowMarker 'Dedicated host created' # per-boot window

function Get-WindowedRpt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $RptPath,
        # Regex marker that opens the window; default matches the mission startup banners.
        [string] $WindowMarker = 'MISSINIT|## (Mission Name|Build|LOG CONTENT)',
        # Optional regex applied to lines inside the window.
        [string] $Pattern,
        # Return at most this many lines from the end of the window (0 = all).
        [int] $Tail = 0
    )

    if (-not (Test-Path -LiteralPath $RptPath)) {
        Write-Warning "Get-WindowedRpt: RPT not found: $RptPath"
        return @()
    }

    # ReadWrite share: the dedicated server holds the RPT open for writing; a plain
    # Get-Content can fail or block. FileStream with ReadWrite share never interferes.
    $fs = [System.IO.File]::Open($RptPath,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::ReadWrite)
    try {
        $sr = New-Object System.IO.StreamReader($fs)
        try { $content = $sr.ReadToEnd() } finally { $sr.Dispose() }
    } finally {
        $fs.Dispose()
    }

    $all = $content -split "`r?`n"

    # Find the LAST window marker; window = everything after it.
    $start = 0
    for ($i = $all.Count - 1; $i -ge 0; $i--) {
        if ($all[$i] -match $WindowMarker) { $start = $i; break }
    }

    # The current mission writes a three-line startup banner. If the last marker
    # is Build/LOG CONTENT, include the preceding Mission Name so evidence keeps
    # the full map/build/logging header.
    if ($WindowMarker -eq 'MISSINIT|## (Mission Name|Build|LOG CONTENT)' -and $all[$start] -match '## (Build|LOG CONTENT)') {
        for ($j = $start; $j -ge ([Math]::Max(0, $start - 20)); $j--) {
            if ($all[$j] -match '## Mission Name') { $start = $j; break }
        }
    }

    $window = if ($start -gt 0) { $all[$start..($all.Count - 1)] } else { $all }

    if ($Pattern) { $window = @($window | Where-Object { $_ -match $Pattern }) }
    if ($Tail -gt 0 -and $window.Count -gt $Tail) {
        $window = $window[($window.Count - $Tail)..($window.Count - 1)]
    }
    return $window
}
