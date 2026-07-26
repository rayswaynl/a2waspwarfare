# Set-WaspAffinity.ps1 - pin server + HC1..HC4 to dedicated physical cores (idempotent)
# Map (8-core CPU): server = physical 0-1, HC1..HC4 = physical 2..5, OS keeps 6-7.
# SMT-aware: with SMT on, a physical core owns 2 consecutive logical CPUs.
# HC processes are identified by their -name=HC-AI-Control-N command line.
# PowerShell 5.1 compatible. Run elevated. Safe to re-run any time.
$ErrorActionPreference = 'Stop'

$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$cores = [Int]$cpu.NumberOfCores
$logical = [Int](Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
$smt = [Int]($logical / $cores)
if ($cores -lt 6) { Write-Warning ("Only {0} physical cores - map needs 6; falling back to no-op." -f $cores); exit 1 }
Write-Host ("CPU: {0} physical, {1} logical (SMT x{2})" -f $cores, $logical, $smt)

function Get-CoreMask {
    Param([Int[]]$PhysicalCores, [Int]$SmtRatio)
    $mask = [Int64]0
    foreach ($p in $PhysicalCores) {
        for ($i = 0; $i -lt $SmtRatio; $i++) { $mask = $mask -bor ([Int64]1 -shl ($p * $SmtRatio + $i)) }
    }
    return $mask
}

$plan = @(
    @{ Label = 'server'; Cores = @(0, 1); Priority = 'High' },
    @{ Label = 'HC-AI-Control-1'; Cores = @(2); Priority = 'AboveNormal' },
    @{ Label = 'HC-AI-Control-2'; Cores = @(3); Priority = 'AboveNormal' },
    @{ Label = 'HC-AI-Control-3'; Cores = @(4); Priority = 'AboveNormal' },
    @{ Label = 'HC-AI-Control-4'; Cores = @(5); Priority = 'AboveNormal' }
)

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
Write-Host ("DONE Set-WaspAffinity ({0} pins applied)" -f $applied)
if ($applied -lt 5) { exit 1 }
