<#
.SYNOPSIS
  Read-only Windows process metrics collector for a validated performance run.

.DESCRIPTION
  Observes only the process roles/PIDs declared in MANIFEST.json. Before
  sampling, it fails closed on PID reuse, executable hash, command-line hash, or
  affinity drift. It never starts, stops, reprioritizes, re-affinitizes, or
  injects into a target process.

  Outputs (fixed names): process-metrics.csv, process-identity.json, and
  collector-overhead.json.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$ManifestPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory,

    [ValidateRange(1, 86400)]
    [int]$SampleCount = 60,

    [ValidateRange(0.05, 3600.0)]
    [double]$IntervalSeconds = 1.0
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$validator = Join-Path $PSScriptRoot 'validate_run_manifest.py'
$metricsPath = Join-Path $OutputDirectory 'process-metrics.csv'
$identityPath = Join-Path $OutputDirectory 'process-identity.json'
$overheadPath = Join-Path $OutputDirectory 'collector-overhead.json'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Format-Utc([datetime]$Value) {
    return $Value.ToUniversalTime().ToString(
        'yyyy-MM-ddTHH:mm:ss.fffZ',
        [Globalization.CultureInfo]::InvariantCulture
    )
}

function Get-BytesSha256([byte[]]$Bytes) {
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($algorithm.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant()
    } finally {
        $algorithm.Dispose()
    }
}

function Get-TextSha256([string]$Text) {
    return Get-BytesSha256 ([System.Text.Encoding]::UTF8.GetBytes($Text))
}

function Get-FileSha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
}

function Write-Json([string]$Path, [object]$Value) {
    $json = $Value | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, $utf8NoBom)
}

function Get-Percentile([double[]]$Values, [double]$Percentile) {
    if ($null -eq $Values -or $Values.Count -eq 0) { return $null }
    $sorted = @($Values | Sort-Object)
    if ($sorted.Count -eq 1) { return [math]::Round([double]$sorted[0], 3) }
    $position = ($Percentile / 100.0) * ($sorted.Count - 1)
    $lower = [math]::Floor($position)
    $upper = [math]::Ceiling($position)
    if ($lower -eq $upper) { return [math]::Round([double]$sorted[$lower], 3) }
    $weight = $position - $lower
    $value = ([double]$sorted[$lower] * (1.0 - $weight)) + ([double]$sorted[$upper] * $weight)
    return [math]::Round($value, 3)
}

function Get-NumericOrNull([object]$Value) {
    if ($null -eq $Value) { return $null }
    try { return [double]$Value } catch { return $null }
}

function Get-Int64OrNull([object]$Value) {
    if ($null -eq $Value) { return $null }
    try { return [int64]$Value } catch { return $null }
}

function Get-CimProperty([object]$Object, [string]$Name) {
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Get-ProcessStartUtc([object]$CimProcess) {
    return ([datetime](Get-CimProperty $CimProcess 'CreationDate')).ToUniversalTime()
}

function Get-ModuleInventory([System.Diagnostics.Process]$Process) {
    $modules = New-Object System.Collections.Generic.List[object]
    $paths = @()
    try {
        $paths = @(
            $Process.Modules |
                ForEach-Object { $_.FileName } |
                Where-Object { $_ } |
                Sort-Object -Unique
        )
    } catch {
        $modules.Add([pscustomobject][ordered]@{
            path = $null
            file_name = $null
            sha256 = $null
            size_bytes = $null
            version = $null
            error = $_.Exception.Message
        })
        return $modules.ToArray()
    }

    foreach ($path in $paths) {
        $hash = $null
        $size = $null
        $version = $null
        $errorMessage = $null
        try {
            $item = Get-Item -LiteralPath $path -ErrorAction Stop
            $size = [int64]$item.Length
            $version = [string]$item.VersionInfo.FileVersion
            $hash = Get-FileSha256 $item.FullName
        } catch {
            $errorMessage = $_.Exception.Message
        }
        $modules.Add([pscustomobject][ordered]@{
            path = [string]$path
            file_name = [System.IO.Path]::GetFileName([string]$path)
            sha256 = $hash
            size_bytes = $size
            version = $version
            error = $errorMessage
        })
    }
    return $modules.ToArray()
}

function Convert-ToExpectedUtc([string]$Value) {
    return [DateTimeOffset]::Parse(
        $Value,
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::AssumeUniversal
    ).UtcDateTime
}

function Get-Rate([object]$Current, [object]$Previous, [double]$Seconds) {
    if ($null -eq $Current -or $null -eq $Previous -or $Seconds -le 0) { return $null }
    $delta = [double]$Current - [double]$Previous
    if ($delta -lt 0) { return $null }
    return [math]::Round($delta / $Seconds, 6)
}

function New-SampleRow(
    [int]$Index,
    [double]$ElapsedSeconds,
    [object]$Target,
    [object]$RawProcess,
    [int]$LogicalProcessorCount
) {
    $status = 'ok'
    $errorMessage = ''
    $live = $null
    if ($null -eq $RawProcess) {
        $status = 'process-unavailable'
        $errorMessage = 'Win32_Process row unavailable; target may have exited'
    } else {
        try {
            $actualSampleStart = Get-ProcessStartUtc $RawProcess
            $expectedSampleStart = Convert-ToExpectedUtc ([string]$Target.start_utc)
            if ([math]::Abs(($actualSampleStart - $expectedSampleStart).TotalSeconds) -gt 1.5) {
                $status = 'identity-mismatch'
                $errorMessage = 'Process creation time changed during capture (possible PID reuse)'
                $RawProcess = $null
            } else {
                $live = Get-Process -Id ([int]$Target.pid) -ErrorAction Stop
                $actualSampleAffinity = [uint64]$live.ProcessorAffinity.ToInt64()
                $expectedSampleAffinity = [Convert]::ToUInt64(([string]$Target.affinity_mask_hex).Substring(2), 16)
                if ($actualSampleAffinity -ne $expectedSampleAffinity) {
                    $status = 'identity-mismatch'
                    $errorMessage = 'Process affinity changed during capture'
                    $RawProcess = $null
                    $live = $null
                }
            }
        } catch {
            $status = 'process-unavailable'
            $errorMessage = $_.Exception.Message
            $RawProcess = $null
            $live = $null
        }
    }

    $kernelTicks = Get-Int64OrNull (Get-CimProperty $RawProcess 'KernelModeTime')
    $userTicks = Get-Int64OrNull (Get-CimProperty $RawProcess 'UserModeTime')
    $kernelSeconds = if ($null -eq $kernelTicks) { $null } else { [math]::Round($kernelTicks / 10000000.0, 7) }
    $userSeconds = if ($null -eq $userTicks) { $null } else { [math]::Round($userTicks / 10000000.0, 7) }
    $totalSeconds = if ($null -eq $kernelSeconds -or $null -eq $userSeconds) { $null } else { [math]::Round($kernelSeconds + $userSeconds, 7) }

    $pageFaults = Get-Int64OrNull (Get-CimProperty $RawProcess 'PageFaults')
    $readOps = Get-Int64OrNull (Get-CimProperty $RawProcess 'ReadOperationCount')
    $writeOps = Get-Int64OrNull (Get-CimProperty $RawProcess 'WriteOperationCount')
    $otherOps = Get-Int64OrNull (Get-CimProperty $RawProcess 'OtherOperationCount')
    $readBytes = Get-Int64OrNull (Get-CimProperty $RawProcess 'ReadTransferCount')
    $writeBytes = Get-Int64OrNull (Get-CimProperty $RawProcess 'WriteTransferCount')
    $otherBytes = Get-Int64OrNull (Get-CimProperty $RawProcess 'OtherTransferCount')

    $roleKey = [string]$Target.role
    $previous = $null
    if ($script:previousCounters.ContainsKey($roleKey)) {
        $previous = $script:previousCounters[$roleKey]
    }
    $deltaSeconds = if ($null -eq $previous) { $null } else { $ElapsedSeconds - [double]$previous.elapsed_seconds }
    $cpuPercent = if ($null -eq $previous -or $null -eq $totalSeconds) {
        $null
    } else {
        Get-Rate $totalSeconds $previous.cpu_total_seconds $deltaSeconds | ForEach-Object { [math]::Round($_ * 100.0, 6) }
    }
    $cpuLogicalCores = if ($null -eq $cpuPercent) { $null } else { [math]::Round($cpuPercent / 100.0, 6) }
    $cpuTotalCapacity = if ($null -eq $cpuPercent) { $null } else { [math]::Round($cpuPercent / $LogicalProcessorCount, 6) }

    $affinity = $null
    if ($null -ne $live) {
        try { $affinity = ('0x{0:X}' -f [uint64]$live.ProcessorAffinity.ToInt64()) } catch { $affinity = $null }
    }

    $privateBytes = if ($null -eq $live) { $null } else { [int64]$live.PrivateMemorySize64 }
    $workingSet = if ($null -eq $live) {
        Get-Int64OrNull (Get-CimProperty $RawProcess 'WorkingSetSize')
    } else {
        [int64]$live.WorkingSet64
    }
    $virtualBytes = if ($null -eq $live) {
        Get-Int64OrNull (Get-CimProperty $RawProcess 'VirtualSize')
    } else {
        [int64]$live.VirtualMemorySize64
    }
    $commitBytes = Get-Int64OrNull (Get-CimProperty $RawProcess 'PrivatePageCount')

    $pageFaultRate = if ($null -eq $previous) { $null } else { Get-Rate $pageFaults $previous.page_faults $deltaSeconds }
    $readOpsRate = if ($null -eq $previous) { $null } else { Get-Rate $readOps $previous.read_ops $deltaSeconds }
    $writeOpsRate = if ($null -eq $previous) { $null } else { Get-Rate $writeOps $previous.write_ops $deltaSeconds }
    $otherOpsRate = if ($null -eq $previous) { $null } else { Get-Rate $otherOps $previous.other_ops $deltaSeconds }
    $readBytesRate = if ($null -eq $previous) { $null } else { Get-Rate $readBytes $previous.read_bytes $deltaSeconds }
    $writeBytesRate = if ($null -eq $previous) { $null } else { Get-Rate $writeBytes $previous.write_bytes $deltaSeconds }
    $otherBytesRate = if ($null -eq $previous) { $null } else { Get-Rate $otherBytes $previous.other_bytes $deltaSeconds }

    $script:previousCounters[$roleKey] = [pscustomobject]@{
        elapsed_seconds = $ElapsedSeconds
        cpu_total_seconds = $totalSeconds
        page_faults = $pageFaults
        read_ops = $readOps
        write_ops = $writeOps
        other_ops = $otherOps
        read_bytes = $readBytes
        write_bytes = $writeBytes
        other_bytes = $otherBytes
    }

    return [pscustomobject][ordered]@{
        schema_version = 'a2wasp-process-metrics-v1'
        run_id = [string]$script:manifest.run_id
        sample_index = $Index
        sample_utc = Format-Utc ([datetime]::UtcNow)
        monotonic_seconds = [math]::Round($ElapsedSeconds, 6)
        role = $roleKey
        pid = [int]$Target.pid
        process_start_utc = [string]$Target.start_utc
        sample_status = $status
        error = $errorMessage
        cpu_total_seconds = $totalSeconds
        cpu_user_seconds = $userSeconds
        cpu_kernel_seconds = $kernelSeconds
        cpu_percent = $cpuPercent
        cpu_logical_core_equivalents = $cpuLogicalCores
        cpu_percent_total_capacity = $cpuTotalCapacity
        logical_processor_count = $LogicalProcessorCount
        affinity_mask_hex = $affinity
        thread_count = Get-Int64OrNull (Get-CimProperty $RawProcess 'ThreadCount')
        handle_count = Get-Int64OrNull (Get-CimProperty $RawProcess 'HandleCount')
        context_switches_per_second = $null
        context_switches_available = $false
        working_set_bytes = $workingSet
        private_bytes = $privateBytes
        commit_bytes = $commitBytes
        virtual_bytes = $virtualBytes
        page_faults_total = $pageFaults
        page_faults_per_second = $pageFaultRate
        io_read_operations_total = $readOps
        io_write_operations_total = $writeOps
        io_other_operations_total = $otherOps
        io_read_bytes_total = $readBytes
        io_write_bytes_total = $writeBytes
        io_other_bytes_total = $otherBytes
        io_read_operations_per_second = $readOpsRate
        io_write_operations_per_second = $writeOpsRate
        io_other_operations_per_second = $otherOpsRate
        io_read_bytes_per_second = $readBytesRate
        io_write_bytes_per_second = $writeBytesRate
        io_other_bytes_per_second = $otherBytesRate
    }
}

if (-not (Test-Path -LiteralPath $validator -PathType Leaf)) {
    throw "Manifest validator is missing: $validator"
}

$validationOutput = @(& python $validator $ManifestPath 2>&1)
if ($LASTEXITCODE -ne 0) {
    throw "Manifest validation failed: $($validationOutput -join [Environment]::NewLine)"
}

$manifestRaw = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $ManifestPath))
$manifestStartSha = Get-BytesSha256 $manifestRaw
$script:manifest = Get-Content -Raw -LiteralPath $ManifestPath | ConvertFrom-Json

if ([string]$script:manifest.validation.status -ne 'pending') {
    throw 'Capture requires a pending manifest; completed manifests are immutable'
}

$manifestDirectory = [string](Resolve-Path -LiteralPath (Split-Path -Parent $ManifestPath))
$resolvedOutputDirectory = [string](Resolve-Path -LiteralPath $OutputDirectory -ErrorAction SilentlyContinue)
if (
    [string]::IsNullOrWhiteSpace($resolvedOutputDirectory) -or
    -not [string]::Equals(
        $manifestDirectory.TrimEnd([char[]]@('\', '/')),
        $resolvedOutputDirectory.TrimEnd([char[]]@('\', '/')),
        [System.StringComparison]::OrdinalIgnoreCase
    )
) {
    throw 'MANIFEST.json must be inside the output directory'
}

$expectedLeaf = [string]$script:manifest.artifact_directory
$actualLeaf = [System.IO.Path]::GetFileName($resolvedOutputDirectory.TrimEnd([char[]]@('\', '/')))
if ($actualLeaf -ne $expectedLeaf) {
    throw "Output directory leaf '$actualLeaf' does not match manifest artifact_directory '$expectedLeaf'"
}

$targets = @($script:manifest.process_topology | Sort-Object role)
if ($targets.Count -eq 0) { throw 'Manifest contains no process_topology targets' }
$logicalProcessorCount = [int]$script:manifest.host.cpu.logical_processors
if ($logicalProcessorCount -lt 1) { throw 'Manifest logical processor count must be positive' }

$specimens = @{}
foreach ($specimen in @($script:manifest.specimens)) {
    $specimens[[string]$specimen.id] = $specimen
}

$collectorProcess = Get-Process -Id $PID
$collectorCpuStart = $collectorProcess.TotalProcessorTime.TotalSeconds
$wall = [System.Diagnostics.Stopwatch]::StartNew()
$moduleWatch = [System.Diagnostics.Stopwatch]::StartNew()
$identityTargets = New-Object System.Collections.Generic.List[object]

foreach ($target in $targets) {
    $pidValue = [int]$target.pid
    $cim = Get-CimInstance Win32_Process -Filter "ProcessId=$pidValue" -ErrorAction Stop
    if ($null -eq $cim) { throw "Target $($target.role) PID $pidValue is unavailable" }
    $live = Get-Process -Id $pidValue -ErrorAction Stop

    $actualStart = Get-ProcessStartUtc $cim
    $expectedStart = Convert-ToExpectedUtc ([string]$target.start_utc)
    if ([math]::Abs(($actualStart - $expectedStart).TotalSeconds) -gt 1.5) {
        throw "Target $($target.role) PID $pidValue start time mismatch (possible PID reuse)"
    }

    $executablePath = [string](Get-CimProperty $cim 'ExecutablePath')
    if ([string]::IsNullOrWhiteSpace($executablePath)) { $executablePath = [string]$live.Path }
    if ([string]::IsNullOrWhiteSpace($executablePath)) {
        throw "Target $($target.role) PID $pidValue executable path is unavailable"
    }
    $actualExecutableSha = Get-FileSha256 $executablePath
    $specimenId = [string]$target.executable_specimen_id
    if (-not $specimens.ContainsKey($specimenId)) {
        throw "Target $($target.role) references missing executable specimen '$specimenId'"
    }
    $expectedExecutableSha = [string]$specimens[$specimenId].sha256
    if ($actualExecutableSha -ne $expectedExecutableSha) {
        throw "Target $($target.role) executable hash mismatch"
    }

    $commandLine = [string](Get-CimProperty $cim 'CommandLine')
    $actualCommandSha = Get-TextSha256 $commandLine
    if ($actualCommandSha -ne [string]$target.command_line_sha256) {
        throw "Target $($target.role) command line hash mismatch"
    }

    $actualAffinity = [uint64]$live.ProcessorAffinity.ToInt64()
    $expectedAffinityText = [string]$target.affinity_mask_hex
    $expectedAffinity = [Convert]::ToUInt64($expectedAffinityText.Substring(2), 16)
    if ($actualAffinity -ne $expectedAffinity) {
        throw "Target $($target.role) affinity mismatch"
    }

    $modules = @(Get-ModuleInventory $live)
    $identityTargets.Add([pscustomobject][ordered]@{
        role = [string]$target.role
        pid = $pidValue
        process_start_utc = Format-Utc $actualStart
        executable_path = $executablePath
        executable_sha256 = $actualExecutableSha
        executable_specimen_id = $specimenId
        command_line_redacted = [string]$target.command_line_redacted
        command_line_sha256 = $actualCommandSha
        affinity_mask_hex = ('0x{0:X}' -f $actualAffinity)
        context_switches_source = 'unavailable: no bounded low-overhead per-process source'
        modules = @($modules)
    })
}
$moduleWatch.Stop()

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
foreach ($path in @($metricsPath, $identityPath, $overheadPath)) {
    if (Test-Path -LiteralPath $path) { throw "Refusing to overwrite existing artifact: $path" }
}

$identity = [pscustomobject][ordered]@{
    schema_version = 'a2wasp-process-identity-v1'
    run_id = [string]$script:manifest.run_id
    captured_utc = Format-Utc ([datetime]::UtcNow)
    manifest_sha256 = $manifestStartSha
    collector_sha256 = Get-FileSha256 $PSCommandPath
    targets = $identityTargets.ToArray()
}
Write-Json $identityPath $identity

$queryDurations = New-Object System.Collections.Generic.List[double]
$deadlineMisses = 0
$samplesWritten = 0
$script:previousCounters = @{}
$targetFilter = (@($targets | ForEach-Object { "ProcessId=$([int]$_.pid)" }) -join ' OR ')
$sampleWatch = [System.Diagnostics.Stopwatch]::StartNew()
$writer = New-Object System.IO.StreamWriter($metricsPath, $false, $utf8NoBom)
$headerWritten = $false

try {
    for ($sampleIndex = 0; $sampleIndex -lt $SampleCount; $sampleIndex++) {
        $scheduledSeconds = $sampleIndex * $IntervalSeconds
        $remainingMilliseconds = ($scheduledSeconds - $sampleWatch.Elapsed.TotalSeconds) * 1000.0
        if ($remainingMilliseconds -gt 1.0) {
            Start-Sleep -Milliseconds ([int][math]::Floor($remainingMilliseconds))
        }
        while ($sampleWatch.Elapsed.TotalSeconds -lt $scheduledSeconds) {
            [System.Threading.Thread]::SpinWait(50)
        }
        if (
            $sampleIndex -gt 0 -and
            $sampleWatch.Elapsed.TotalSeconds -gt ($scheduledSeconds + [math]::Max(0.001, $IntervalSeconds * 0.05))
        ) {
            $deadlineMisses++
        }

        $query = [System.Diagnostics.Stopwatch]::StartNew()
        $rawProcesses = @(Get-CimInstance Win32_Process -Filter $targetFilter -ErrorAction SilentlyContinue)
        foreach ($target in $targets) {
            $pidValue = [int]$target.pid
            $raw = @($rawProcesses | Where-Object { [int](Get-CimProperty $_ 'ProcessId') -eq $pidValue }) | Select-Object -First 1
            $row = New-SampleRow -Index $sampleIndex -ElapsedSeconds $sampleWatch.Elapsed.TotalSeconds -Target $target -RawProcess $raw -LogicalProcessorCount $logicalProcessorCount
            $lines = @($row | ConvertTo-Csv -NoTypeInformation)
            if (-not $headerWritten) {
                $writer.WriteLine($lines[0])
                $headerWritten = $true
            }
            $writer.WriteLine($lines[1])
            $samplesWritten++
        }
        $writer.Flush()
        $query.Stop()
        $queryDurations.Add($query.Elapsed.TotalMilliseconds)
    }
} finally {
    $writer.Dispose()
    $sampleWatch.Stop()
}

$wall.Stop()
$collectorProcess.Refresh()
$collectorCpuSeconds = [math]::Max(0.0, $collectorProcess.TotalProcessorTime.TotalSeconds - $collectorCpuStart)
$collectorCorePercent = if ($wall.Elapsed.TotalSeconds -gt 0) {
    [math]::Round(($collectorCpuSeconds / $wall.Elapsed.TotalSeconds) * 100.0, 6)
} else { 0.0 }
$collectorTotalPercent = [math]::Round($collectorCorePercent / $logicalProcessorCount, 6)

$manifestEndSha = Get-BytesSha256 ([System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $ManifestPath)))
$manifestChanged = $manifestEndSha -ne $manifestStartSha
$outputBytesBeforeOverhead = [int64](
    (Get-Item -LiteralPath $metricsPath).Length +
    (Get-Item -LiteralPath $identityPath).Length
)

$overhead = [pscustomobject][ordered]@{
    schema_version = 'a2wasp-collector-overhead-v1'
    run_id = [string]$script:manifest.run_id
    measured_utc = Format-Utc ([datetime]::UtcNow)
    targets = $targets.Count
    samples_requested = $SampleCount
    samples_written = $samplesWritten
    interval_seconds = $IntervalSeconds
    wall_seconds = [math]::Round($wall.Elapsed.TotalSeconds, 6)
    collector_cpu_seconds = [math]::Round($collectorCpuSeconds, 6)
    collector_cpu_logical_core_percent = $collectorCorePercent
    collector_cpu_total_capacity_percent = $collectorTotalPercent
    collector_peak_working_set_bytes = [int64]$collectorProcess.PeakWorkingSet64
    module_hash_wall_ms = [math]::Round($moduleWatch.Elapsed.TotalMilliseconds, 3)
    query_duration_ms_p50 = Get-Percentile $queryDurations.ToArray() 50
    query_duration_ms_p95 = Get-Percentile $queryDurations.ToArray() 95
    query_duration_ms_max = if ($queryDurations.Count -eq 0) { $null } else { [math]::Round([double](($queryDurations | Measure-Object -Maximum).Maximum), 3) }
    deadline_misses = $deadlineMisses
    output_bytes_before_overhead = $outputBytesBeforeOverhead
    bytes_per_process_sample = if ($samplesWritten -gt 0) { [math]::Round($outputBytesBeforeOverhead / [double]$samplesWritten, 3) } else { $null }
    manifest_sha256_before = $manifestStartSha
    manifest_sha256_after = $manifestEndSha
    manifest_changed_during_capture = [bool]$manifestChanged
}
Write-Json $overheadPath $overhead

if ($manifestChanged) {
    throw 'Manifest changed during capture; run identity is invalid'
}

Write-Host ("Captured {0} process samples for run {1} -> {2}" -f $samplesWritten, $script:manifest.run_id, $OutputDirectory)
