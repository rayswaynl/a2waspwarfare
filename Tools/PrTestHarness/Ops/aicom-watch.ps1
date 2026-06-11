#requires -Version 5.1
# AICOM Watchdog - one-pass health check for Hetzner WASP test box.
# Run via scheduled task AicomWatch every 5 minutes.
# Appends one timestamped line to C:\WASP\monitor\monitor.log
# Updates C:\WASP\monitor\state.json with current RPT sizes for next-run delta

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$SRV_RPT  = "C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT"
$HC1_RPT  = "C:\Users\Administrator\AppData\Local\ArmA 2 OA\ArmA2OA.RPT"
$HC2_RPT  = "C:\Sandbox\Administrator\HC2\user\current\AppData\Local\ArmA 2 OA\ArmA2OA.RPT"
$MON_DIR  = "C:\WASP\monitor"
$LOG_FILE = Join-Path $MON_DIR "monitor.log"
$STATE    = Join-Path $MON_DIR "state.json"

if (-not (Test-Path $MON_DIR)) { New-Item -ItemType Directory -Force -Path $MON_DIR | Out-Null }

$ts     = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$alerts = [System.Collections.Generic.List[string]]::new()
$info   = [System.Collections.Generic.List[string]]::new()

function Add-Alert { param($msg) $script:alerts.Add($msg) }
function Add-Info  { param($msg) $script:info.Add($msg)   }

# 1. Process count (expect: 1 server + 2 HC)
$srvProcs  = @(Get-Process -Name "arma2oaserver" -ErrorAction SilentlyContinue)
$hcProcs   = @(Get-Process -Name "ArmA2OA"       -ErrorAction SilentlyContinue)
$procTotal = $srvProcs.Count + $hcProcs.Count

if ($srvProcs.Count -ne 1) { Add-Alert "PROC: server count=$($srvProcs.Count) expected 1" }
if ($hcProcs.Count  -ne 2) { Add-Alert "PROC: HC count=$($hcProcs.Count) expected 2" }
if ($procTotal -eq 3)      { Add-Info  "PROC:OK srv=1 HC=2" }

# 2. TICK freshness
$TICK_SILENCE_MIN = 8

function Get-LastTickElMin {
    param([string]$rptPath)
    if (-not (Test-Path $rptPath)) { return $null }
    try {
        $lines = Get-Content -Path $rptPath -Tail 3000 -ErrorAction Stop
        $tickLines = $lines | Where-Object { $_ -match 'AICOMSTAT\|v1\|TICK\|' }
        if ($tickLines.Count -eq 0) { return $null }
        $last  = $tickLines[-1]
        $clean = $last -replace '^.*AICOMSTAT\|', 'AICOMSTAT|'
        $parts = $clean -split '\|'
        if ($parts.Count -ge 5) { return [int]$parts[4] }
    } catch {}
    return $null
}

function Get-MinSinceWrite {
    param([string]$path)
    if (-not (Test-Path $path)) { return $null }
    $lw = (Get-Item $path -ErrorAction SilentlyContinue).LastWriteTime
    return [Math]::Floor(((Get-Date) - $lw).TotalMinutes)
}

$srvLastTick = Get-LastTickElMin $SRV_RPT
$srvAge      = Get-MinSinceWrite $SRV_RPT

if ($null -eq $srvLastTick) {
    Add-Alert "TICK: no TICK lines in server RPT (possible AI death or new RPT)"
} elseif ($null -eq $srvAge) {
    Add-Alert "TICK: cannot read server RPT age"
} elseif ($srvAge -ge $TICK_SILENCE_MIN) {
    Add-Alert "TICK: server RPT not updated for ${srvAge} min - AI supervisor may be dead"
} else {
    Add-Info "TICK:OK lastElMin=$srvLastTick rptAge=${srvAge}min"
}

# 3. Error block scan - last 2000 lines server RPT
$ERR_THRESHOLD = 20

if (Test-Path $SRV_RPT) {
    $errCount = 0
    $errFiles = @()
    try {
        $tail = Get-Content -Path $SRV_RPT -Tail 2000 -ErrorAction Stop
        $errLines = @($tail | Where-Object { ($_ -match 'Error in expression') -and ($_ -match 'Server\\AI|Client\\Module') })
        $errCount = $errLines.Count
        $errFiles = ($tail | Where-Object { $_ -match 'File mpmissions.*\.(sqf|sqs)' } |
            ForEach-Object { if ($_ -match 'File (mpmissions\S+)') { $matches[1] } } |
            Select-Object -Unique) -join '; '
        if ($errCount -gt $ERR_THRESHOLD) {
            Add-Alert "ERRBLK: ${errCount} error-in-expression lines in last 2000. Files: $errFiles"
        } else {
            Add-Info "ERRBLK:OK ${errCount} errors in 2000 lines"
        }
    } catch {
        Add-Alert "ERRBLK: read failed - $_"
    }
}

# 4. HC RPT growth check vs state.json
$stateObj = [pscustomobject]@{ hc1Size = 0; hc2Size = 0 }
if (Test-Path $STATE) {
    try { $stateObj = Get-Content $STATE -Raw | ConvertFrom-Json } catch {}
}

$newState = @{}

$hcChecks = @(
    [pscustomobject]@{ Label="HC1"; Path=$HC1_RPT; PrevKey="hc1Size" },
    [pscustomobject]@{ Label="HC2"; Path=$HC2_RPT; PrevKey="hc2Size" }
)

foreach ($hc in $hcChecks) {
    $label   = $hc.Label
    $path    = $hc.Path
    $prevKey = $hc.PrevKey

    if (-not (Test-Path $path)) {
        Add-Alert "${label}: RPT missing at $path"
        $newState[$prevKey] = 0
        continue
    }

    $curSize  = (Get-Item $path -ErrorAction SilentlyContinue).Length
    $prevProp = $stateObj.PSObject.Properties[$prevKey]
    $prevSize = if ($prevProp) { [long]$prevProp.Value } else { 0 }
    $newState[$prevKey] = $curSize

    if ($prevSize -eq 0) {
        Add-Info "${label}: RPT size=${curSize} (first run, no baseline)"
    } elseif ($curSize -lt $prevSize) {
        Add-Info "${label}: RPT recreated shrank from $prevSize to $curSize (restart)"
    } elseif ($curSize -eq $prevSize) {
        Add-Alert "${label}: RPT unchanged ${curSize} bytes - HC may be stalled"
    } else {
        $grown = $curSize - $prevSize
        Add-Info "${label}: RPT grew +${grown} bytes OK"
    }
}

$newState | ConvertTo-Json | Set-Content -Path $STATE -Encoding UTF8

# 5. Write log line
if ($alerts.Count -eq 0) {
    $line = "[$ts] OK    | $($info -join ' | ')"
} else {
    $line = "[$ts] ALERT | $($alerts -join ' | ') | INFO: $($info -join ' | ')"
}

Add-Content -Path $LOG_FILE -Value $line -Encoding UTF8
Write-Output $line
