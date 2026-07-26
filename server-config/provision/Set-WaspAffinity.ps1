# Set-WaspAffinity.ps1 - pin server + HC1..HC<N> to dedicated physical cores (idempotent)
# Map (8-core CPU, 4 HCs): server = physical 0-1, HC1..HC4 = physical 2..5, OS keeps the rest.
# -HcCount 1..4 (default 4) matches the box's configured HC count; the map scales with it
# (an N-HC box needs 2+N physical cores, so 2 HCs fit a 4-core box).
# SMT-aware: with SMT on, a physical core owns 2 consecutive logical CPUs.
# HC processes are identified by their -name=HC-AI-Control-N command line.
# PowerShell 5.1 compatible. Run elevated. Safe to re-run any time.
Param(
    [ValidateRange(1, 4)][Int]$HcCount = 4
)
$ErrorActionPreference = 'Stop'

$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$cores = [Int]$cpu.NumberOfCores
$logical = [Int](Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
$smt = [Int]($logical / $cores)
$needCores = 2 + $HcCount
if ($cores -lt $needCores) { Write-Warning ("Only {0} physical cores - map for {1} HC(s) needs {2}; falling back to no-op." -f $cores, $HcCount, $needCores); exit 1 }
Write-Host ("CPU: {0} physical, {1} logical (SMT x{2}); pinning server + {3} HC(s)" -f $cores, $logical, $smt, $HcCount)

function Get-CoreMask {
    Param([Int[]]$PhysicalCores, [Int]$SmtRatio)
    $mask = [Int64]0
    foreach ($p in $PhysicalCores) {
        for ($i = 0; $i -lt $SmtRatio; $i++) { $mask = $mask -bor ([Int64]1 -shl ($p * $SmtRatio + $i)) }
    }
    return $mask
}

$plan = @(
    @{ Label = 'server'; Cores = @(0, 1); Priority = 'High' }
)
foreach ($n in 1..$HcCount) {
    $plan += @{ Label = ('HC-AI-Control-{0}' -f $n); Cores = @($n + 1); Priority = 'AboveNormal' }
}

# Resolve PIDs: server by exe name; HCs by command-line -name= match (works for
# Sandboxie-hosted processes too - they are visible in the host process list).
$hcProcs = @(Get-CimInstance Win32_Process -Filter "Name='ArmA2OA.exe'")
$applied = 0
foreach ($entry in $plan) {
    $procIds = @()
    if ($entry.Label -eq 'server') {
        $procIds = @(Get-Process arma2oaserver -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
    } else {
        # Launchers pass -name="HC-AI-Control-N" (quoted); strip quotes before matching
        # or the needle never hits.
        $needle = ('-name={0}' -f $entry.Label)
        $procIds = @($hcProcs | Where-Object { $_.CommandLine -and $_.CommandLine.Replace('"', '').Contains($needle) } | Select-Object -ExpandProperty ProcessId)
    }
    if ($procIds.Count -eq 0) { Write-Warning ("NOT RUNNING: {0}" -f $entry.Label); continue }
    if ($procIds.Count -gt 1) { Write-Warning ("{0}: {1} matching processes - pinning all." -f $entry.Label, $procIds.Count) }
    $mask = Get-CoreMask -PhysicalCores $entry.Cores -SmtRatio $smt
    foreach ($procId in $procIds) {
        $p = Get-Process -Id $procId -ErrorAction SilentlyContinue
        if ($null -eq $p) { continue }
        $p.ProcessorAffinity = [IntPtr]$mask
        $p.PriorityClass = $entry.Priority
        Write-Host ("PINNED: {0} (pid {1}) -> physical {2} mask 0x{3:X} priority {4}" -f $entry.Label, $procId, ($entry.Cores -join ','), $mask, $entry.Priority)
        $applied++
    }
}
$needPins = 1 + $HcCount
Write-Host ("DONE Set-WaspAffinity ({0} of {1} pins applied)" -f $applied, $needPins)
if ($applied -lt $needPins) { exit 1 }
