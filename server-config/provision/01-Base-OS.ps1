# 01-Base-OS.ps1 - baseline OS settings for the WASP 4-HC box (idempotent)
# PowerShell 5.1 compatible. Run elevated.
$ErrorActionPreference = 'Stop'

Write-Host '== Power plan: High Performance =='
$high = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
powercfg /setactive $high
if ($LASTEXITCODE -ne 0) { Write-Warning 'powercfg failed - set High Performance manually.' }
else { Write-Host 'OK: High Performance active.' }

Write-Host '== Firewall: Arma 2 OA server + HC ports (UDP 2302-2306) =='
$ruleName = 'WASP A2OA UDP 2302-2306'
$existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
if ($null -eq $existing) {
    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol UDP -LocalPort 2302-2306 -Action Allow | Out-Null
    Write-Host 'OK: inbound rule created.'
} else {
    Write-Host 'OK: rule already present.'
}

Write-Host '== Defender exclusions: game + WASP trees (keeps real-time protection ON) =='
# A2OA writes RPT/profile files constantly and loads thousands of pbo/paa files;
# real-time scanning of those trees costs measurable IO. Exclude the trees, not Defender.
$exclusions = @(
    'C:\Program Files (x86)\Steam\steamapps\common\Arma 2',
    'C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead',
    'C:\WASP'
)
try {
    $current = @((Get-MpPreference -ErrorAction Stop).ExclusionPath)
    foreach ($e in $exclusions) {
        if ($current -notcontains $e) { Add-MpPreference -ExclusionPath $e; Write-Host ("Excluded: {0}" -f $e) }
        else { Write-Host ("Already excluded: {0}" -f $e) }
    }
} catch { Write-Warning 'Defender preference cmdlets unavailable - add the exclusions manually if Defender is active.' }

Write-Host '== Report (no changes): VBS / HVCI state =='
# Report-only per procurement brief; disabling VBS is an owner decision recorded elsewhere.
try {
    $dg = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -ErrorAction Stop
    Write-Host ("VirtualizationBasedSecurityStatus: {0} (0=off 1=enabled-not-running 2=running)" -f $dg.VirtualizationBasedSecurityStatus)
    Write-Host ("SecurityServicesRunning: {0}" -f ($dg.SecurityServicesRunning -join ','))
} catch { Write-Host 'VBS query unavailable (class missing) - treat as off.' }

Write-Host '== Report: CPU topology =='
$cs = Get-CimInstance Win32_ComputerSystem
$cpu = Get-CimInstance Win32_Processor
Write-Host ("CPU: {0}" -f $cpu.Name.Trim())
Write-Host ("Physical cores: {0}  Logical CPUs: {1}  (SMT {2})" -f $cpu.NumberOfCores, $cs.NumberOfLogicalProcessors, $(if ($cs.NumberOfLogicalProcessors -gt $cpu.NumberOfCores) { 'ON' } else { 'OFF' }))
if ($cpu.NumberOfCores -lt 6) { Write-Warning 'Fewer than 6 physical cores - the 4-HC affinity map needs at least 6.' }

Write-Host '== Report: RAM + disks =='
Write-Host ("RAM: {0:N0} GB" -f ($cs.TotalPhysicalMemory / 1GB))
Get-CimInstance Win32_DiskDrive | ForEach-Object { Write-Host ("Disk: {0}  {1:N0} GB" -f $_.Model, ($_.Size / 1GB)) }

Write-Host 'DONE 01-Base-OS'
