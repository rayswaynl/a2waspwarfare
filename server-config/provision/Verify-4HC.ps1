# Verify-4HC.ps1 - post-start health check for the N-HC topology. Read-only.
# -HcCount 1..4 (default 4) matches the box's configured HC count.
# Checks: 1+N processes up, affinity matches the map, and the server RPT shows N
# HCSIDE|v1|connect registrations after the most recent MISSINIT.
# PowerShell 5.1 compatible.
Param(
    [String]$WaspDir = 'C:\WASP',
    [String]$ServerRpt = "$env:USERPROFILE\AppData\Local\ArmA 2 OA\arma2oaserver.RPT",
    [ValidateRange(1, 4)][Int]$HcCount = 4
)
$ErrorActionPreference = 'Stop'
$pass = 0; $fail = 0

function Check {
    Param([Bool]$Ok, [String]$Label, [String]$Detail = '')
    if ($Ok) { Write-Host ("PASS: {0}" -f $Label); $script:pass++ }
    else { Write-Host ("FAIL: {0} {1}" -f $Label, $Detail); $script:fail++ }
}

# --- processes ---
$server = @(Get-Process arma2oaserver -ErrorAction SilentlyContinue)
Check ($server.Count -eq 1) 'exactly one arma2oaserver.exe' ("(found {0})" -f $server.Count)

$hcProcs = @(Get-CimInstance Win32_Process -Filter "Name='ArmA2OA.exe'")
# Launchers pass -name="HC-AI-Control-N" (quoted); strip quotes before matching.
foreach ($n in 1..$HcCount) {
    $needle = ('-name=HC-AI-Control-{0}' -f $n)
    $match = @($hcProcs | Where-Object { $_.CommandLine -and $_.CommandLine.Replace('"', '').Contains($needle) })
    Check ($match.Count -eq 1) ("HC{0} process ({1})" -f $n, $needle) ("(found {0})" -f $match.Count)
}

# --- affinity (recompute the same map as Set-WaspAffinity.ps1) ---
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$smt = [Int]((Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors / $cpu.NumberOfCores)
function Get-CoreMask {
    Param([Int[]]$PhysicalCores, [Int]$SmtRatio)
    $mask = [Int64]0
    foreach ($p in $PhysicalCores) {
        for ($i = 0; $i -lt $SmtRatio; $i++) { $mask = $mask -bor ([Int64]1 -shl ($p * $SmtRatio + $i)) }
    }
    return $mask
}
$expect = @{ 'server' = (Get-CoreMask @(0, 1) $smt) }
foreach ($n in 1..$HcCount) { $expect[('HC-AI-Control-{0}' -f $n)] = (Get-CoreMask @($n + 1) $smt) }

if ($server.Count -eq 1) {
    Check ([Int64]$server[0].ProcessorAffinity -eq $expect['server']) 'server affinity' ("(have 0x{0:X} want 0x{1:X})" -f [Int64]$server[0].ProcessorAffinity, $expect['server'])
}
foreach ($n in 1..$HcCount) {
    $needle = ('-name=HC-AI-Control-{0}' -f $n)
    $m = @($hcProcs | Where-Object { $_.CommandLine -and $_.CommandLine.Replace('"', '').Contains($needle) })
    if ($m.Count -eq 1) {
        $p = Get-Process -Id $m[0].ProcessId -ErrorAction SilentlyContinue
        if ($null -ne $p) {
            $want = $expect[('HC-AI-Control-{0}' -f $n)]
            Check ([Int64]$p.ProcessorAffinity -eq $want) ("HC{0} affinity" -f $n) ("(have 0x{0:X} want 0x{1:X})" -f [Int64]$p.ProcessorAffinity, $want)
        }
    }
}

# --- server RPT: HC registrations within the current mission window ---
$rpt = Get-Item -LiteralPath $ServerRpt -ErrorAction SilentlyContinue
if ($null -eq $rpt) {
    Check $false 'server RPT present' ("(not found at {0})" -f $ServerRpt)
} else {
    Write-Host ("RPT: {0} ({1:N1} MB)" -f $rpt.FullName, ($rpt.Length / 1MB))
    # A2 OA RPTs never truncate and the server holds the file open for writing:
    # shared-read FileStream + tail window only (plain Get-Content can block/throw
    # against the live writer and reads the whole accumulated file).
    $tailBytes = 8MB
    $fs = [System.IO.FileStream]::new($rpt.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        if ($fs.Length -gt $tailBytes) { $fs.Seek(-$tailBytes, [System.IO.SeekOrigin]::End) | Out-Null }
        $sr = [System.IO.StreamReader]::new($fs)
        $text = $sr.ReadToEnd()
    } finally { $fs.Dispose() }
    $lines = $text -split "`r?`n"
    if ($rpt.Length -gt $tailBytes) { Write-Host ("NOTE: scanning only the last {0} MB of the RPT." -f ($tailBytes / 1MB)) }
    $missinit = -1
    for ($i = $lines.Count - 1; $i -ge 0; $i--) { if ($lines[$i] -match 'MISSINIT') { $missinit = $i; break } }
    if ($missinit -lt 0) { Write-Host 'NOTE: no MISSINIT found - scanning the whole RPT (boot may still be early).'; $missinit = 0 }
    $window = $lines[$missinit..($lines.Count - 1)]
    $connects = @($window | Where-Object { $_ -match 'HCSIDE\|v1\|connect\|' })
    $deferred = @($window | Where-Object { $_ -match 'HCSIDE\|v1\|connect-(failed|deferred)\|' })
    $owners = @($connects | ForEach-Object { if ($_ -match 'owner=(\d+)') { $matches[1] } } | Sort-Object -Unique)
    Check ($owners.Count -ge $HcCount) ("{0} distinct HC owner ids registered after last MISSINIT" -f $HcCount) ("(distinct owners: {0}; connect lines: {1}; failed/deferred: {2})" -f $owners.Count, $connects.Count, $deferred.Count)
    if ($deferred.Count -gt 0) { Write-Host ("NOTE: {0} failed/deferred HC registration line(s) - re-check after the HC reannounce." -f $deferred.Count) }
    # Soft check: once towns activate, delegate_townai_headless perf-audit rows carry the
    # authoritative live-pool size (headless:N). Informational until a delegation fires.
    $deleg = @($window | Where-Object { $_ -match 'delegate_townai_headless' }) | Select-Object -Last 1
    if ($null -ne $deleg -and $deleg -match 'headless:(\d+)') {
        $poolN = [Int]$matches[1]
        if ($poolN -ge $HcCount) { Write-Host ("INFO: delegation pool headless:{0} - all HCs live at last town delegation." -f $poolN) }
        else { Write-Host ("WARN: last town delegation saw headless:{0} (<{1}) - an HC was out of the pool at that moment." -f $poolN, $HcCount) }
    } else {
        Write-Host 'INFO: no delegate_townai_headless row yet (no town delegated in window) - pool-size check pending.'
    }
}

Write-Host ''
Write-Host ("RESULT: {0} pass, {1} fail" -f $pass, $fail)
if ($fail -gt 0) { exit 1 } else { exit 0 }
