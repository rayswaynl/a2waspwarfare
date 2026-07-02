#requires -Version 5.1
<#
.SYNOPSIS
    Pin the Arma 2 OA dedicated server + its headless clients to chosen CPU cores
    (processor affinity), to keep sim threads on P-cores and off E-cores and to stop
    the server + HCs fighting over shared CPU cache. PREPARED for the main-server
    0/1/2-HC scaling test (see docs/testing/hc-scaling-test.md).

.DESCRIPTION
    Net_2's concern: on the 6-P-core (+ E-core) main server, adding HCs multiplies
    context switches and cache contention. Giving each Arma process a dedicated,
    ideally DISJOINT, set of P-cores mitigates that.

    Targets:
      - the server  : arma2oaserver.exe
      - each HC     : ArmA2OA.exe whose command line contains '-client' (the HC clients)

    SAFE BY DEFAULT: prints what it would do unless -Apply is passed.

    Affinity masks are bitmasks over LOGICAL processors (bit 0 = CPU0). They are
    HARDWARE-SPECIFIC: confirm which logical CPUs are P-cores on the target box first
    (Task Manager > Performance > CPU, or sysinternals coreinfo). Example for 6 P-cores
    with hyperthreading (logical 0-11): server 0x0FF (CPUs 0-7), HC1 0x300 (CPUs 8-9),
    HC2 0xC00 (CPUs 10-11).

.PARAMETER ServerMask
    Affinity bitmask for arma2oaserver.exe (e.g. 0x0FF). If omitted or 0, the server is left untouched.
    Negative masks are rejected because processor-affinity masks are unsigned bit fields.

.PARAMETER HcMasks
    One affinity bitmask per HC, in connection order (e.g. 0x300,0xC00). HCs beyond the
    supplied masks are left untouched. A 0 entry leaves that HC untouched. Negative masks
    are rejected because processor-affinity masks are unsigned bit fields.

.PARAMETER Apply
    Actually set the affinities. Without this switch the script only reports (dry run).

.EXAMPLE
    .\Set-WaspCpuAffinity.ps1 -ServerMask 0x0FF -HcMasks 0x300,0xC00          # dry run
    .\Set-WaspCpuAffinity.ps1 -ServerMask 0x0FF -HcMasks 0x300,0xC00 -Apply   # apply
#>
[CmdletBinding()]
param(
    [ValidateScript({
        if ($_ -lt 0) { throw 'Affinity masks must be non-negative. Use 0 to leave a target untouched.' }
        $true
    })]
    [int64]$ServerMask = 0,
    [ValidateScript({
        if ($_ -lt 0) { throw 'Affinity masks must be non-negative. Use 0 to leave a target untouched.' }
        $true
    })]
    [int64[]]$HcMasks = @(),
    [switch]$Apply
)

function Get-HcProcesses {
    # HC clients = ArmA2OA.exe with '-client' on the command line. Win32_Process exposes CommandLine.
    Get-CimInstance Win32_Process -Filter "Name='ArmA2OA.exe'" |
        Where-Object { $_.CommandLine -and $_.CommandLine -match '-client' } |
        Sort-Object CreationDate
}

function Set-Affinity([int]$ProcId, [int64]$Mask, [string]$Label) {
    try {
        $p = Get-Process -Id $ProcId -ErrorAction Stop
        $old = [int64]$p.ProcessorAffinity
        if (-not $Apply) {
            Write-Host ("DRYRUN  {0} (PID {1})  affinity {2:X} -> {3:X}" -f $Label, $ProcId, $old, $Mask)
            return
        }
        $p.ProcessorAffinity = [IntPtr]$Mask
        $new = [int64]((Get-Process -Id $ProcId).ProcessorAffinity)
        Write-Host ("APPLIED {0} (PID {1})  affinity {2:X} -> {3:X}" -f $Label, $ProcId, $old, $new)
    } catch {
        Write-Warning ("{0} (PID {1}): {2}" -f $Label, $ProcId, $_.Exception.Message)
    }
}

Write-Host ("=== Set-WaspCpuAffinity ({0}) ===" -f $(if ($Apply) { 'APPLY' } else { 'DRY RUN - pass -Apply to commit' }))

# --- server ---
$srv = Get-CimInstance Win32_Process -Filter "Name='arma2oaserver.exe'"
if ($srv) {
    if ($ServerMask -ne 0) { foreach ($s in $srv) { Set-Affinity $s.ProcessId $ServerMask 'server' } }
    else { Write-Host "server: found but no -ServerMask given (left untouched)" }
} else { Write-Host "server: arma2oaserver.exe NOT running" }

# --- HCs ---
$hcs = @(Get-HcProcesses)
Write-Host ("HCs found: {0}" -f $hcs.Count)
for ($i = 0; $i -lt $hcs.Count; $i++) {
    if ($i -lt $HcMasks.Count -and $HcMasks[$i] -ne 0) {
        Set-Affinity $hcs[$i].ProcessId $HcMasks[$i] ("HC$($i + 1)")
    } else {
        Write-Host ("HC$($i + 1) (PID $($hcs[$i].ProcessId)): no mask supplied (left untouched)")
    }
}
