[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)]
	[string]$OutputPath,
	[int]$IntervalSec = 5,
	[int]$DurationSec = 0,
	[switch]$Once
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

if ($IntervalSec -lt 1) { throw "IntervalSec must be at least 1." }
$parent = Split-Path -Parent $OutputPath
if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }

$logicalCores = [Environment]::ProcessorCount
$physicalMemoryGb = $null
try {
	$computer = Get-CimInstance Win32_ComputerSystem
	$physicalMemoryGb = [math]::Round(([double]$computer.TotalPhysicalMemory / 1GB), 2)
} catch {
	$physicalMemoryGb = $null
}

$hardwareTier = "unknown"
if ($null -ne $physicalMemoryGb) {
	if ($logicalCores -le 4 -or $physicalMemoryGb -le 8) { $hardwareTier = "low" }
	elseif ($logicalCores -le 8 -or $physicalMemoryGb -le 16) { $hardwareTier = "mid" }
	else { $hardwareTier = "high" }
}

$previous = @{}
$started = Get-Date
while ($true) {
	$now = Get-Date
	$process = Get-Process -Name "arma2oa","arma2oaserver" -ErrorAction SilentlyContinue | Select-Object -First 1
	$cpuPct = $null
	$workingSetMb = $null
	$processName = $null
	$procId = $null
	if ($null -ne $process) {
		$processName = $process.ProcessName
		$procId = $process.Id
		$workingSetMb = [math]::Round(([double]$process.WorkingSet64 / 1MB), 2)
		$key = [string]$process.Id
		if ($previous.ContainsKey($key)) {
			$old = $previous[$key]
			$cpuDelta = ($process.TotalProcessorTime - $old.cpu).TotalSeconds
			$wallDelta = ($now - $old.time).TotalSeconds
			if ($wallDelta -gt 0) { $cpuPct = [math]::Round(($cpuDelta / $wallDelta / $logicalCores) * 100, 2) }
		}
		$previous = @{ ([string]$process.Id) = @{ cpu = $process.TotalProcessorTime; time = $now } }
	} else {
		$previous = @{}
	}

	$row = [ordered]@{
		wallTime = $now.ToUniversalTime().ToString("o")
		processName = $processName
		pid = $procId
		processCpuPct = $cpuPct
		workingSetMb = $workingSetMb
		hardwareTier = $hardwareTier
		logicalCores = $logicalCores
		physicalMemoryGb = $physicalMemoryGb
	}
	ConvertTo-Json $row -Compress | Add-Content -LiteralPath $OutputPath -Encoding UTF8

	if ($Once) { break }
	if ($DurationSec -gt 0 -and (($now - $started).TotalSeconds -ge $DurationSec)) { break }
	Start-Sleep -Seconds $IntervalSec
}
