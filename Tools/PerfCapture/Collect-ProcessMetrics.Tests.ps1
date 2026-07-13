<#
  Dependency-free integration tests for Collect-ProcessMetrics.ps1.

  The tests observe three test-owned sleeping PowerShell processes. They prove the
  collector emits the fixed CSV/JSON contracts, fails closed on identity drift,
  and does not stop or mutate the target process.
#>
[CmdletBinding()]
param(
    [ValidateRange(2, 300)]
    [int]$CaptureSamples = 2,

    [ValidateRange(0.1, 10.0)]
    [double]$CaptureIntervalSeconds = 1.0,

    [switch]$KeepArtifacts
)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$collector = Join-Path $here 'Collect-ProcessMetrics.ps1'
$validator = Join-Path $here 'validate_run_manifest.py'
$fixture = Join-Path $here 'fixtures\valid-pending\MANIFEST.json'
$fail = 0

function Assert([bool]$Condition, [string]$Message) {
    if ($Condition) {
        Write-Host "  ok   $Message"
    } else {
        Write-Host "  FAIL $Message" -ForegroundColor Red
        $script:fail++
    }
}

function Get-TextSha256([string]$Text) {
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        return ([BitConverter]::ToString($algorithm.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    } finally {
        $algorithm.Dispose()
    }
}

function Format-Utc([datetime]$Value) {
    return $Value.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
}

function New-TestManifest([System.Diagnostics.Process[]]$Processes, [string]$Destination) {
    $document = Get-Content -Raw -LiteralPath $fixture | ConvertFrom-Json
    $now = [datetime]::UtcNow
    $date = $now.ToString('yyyyMMdd', [Globalization.CultureInfo]::InvariantCulture)

    $document.created_utc = Format-Utc ($now.AddSeconds(-1))
    $document.date_utc = $date
    $document.artifact_directory = "${date}_$($document.regime)_$($document.scenario)_$($document.arm)_$($document.run_id)_$($document.build_id)"
    $document.timing.start_utc = Format-Utc $now
    $document.timing.warmup_end_utc = Format-Utc ($now.AddSeconds(1))
    $document.timing.end_utc = $null

    $firstLive = Get-Process -Id $Processes[0].Id -ErrorAction Stop
    $exe = Get-Item -LiteralPath $firstLive.Path
    $exeSpecimen = @($document.specimens | Where-Object { $_.id -eq 'arma2oa-exe' })[0]
    $exeSpecimen.path = $exe.FullName
    $exeSpecimen.sha256 = (Get-FileHash -LiteralPath $exe.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $exeSpecimen.size_bytes = [int64]$exe.Length

    $roleNames = @('server', 'hc-01', 'client-01')
    $topology = @()
    for ($index = 0; $index -lt $Processes.Count; $index++) {
        $process = $Processes[$index]
        $cim = Get-CimInstance Win32_Process -Filter "ProcessId=$($process.Id)" -ErrorAction Stop
        $live = Get-Process -Id $process.Id -ErrorAction Stop
        $topology += [pscustomobject][ordered]@{
            role = $roleNames[$index]
            pid = [int]$process.Id
            start_utc = Format-Utc ([datetime]$cim.CreationDate)
            executable_specimen_id = 'arma2oa-exe'
            command_line_redacted = [string]$cim.CommandLine
            command_line_sha256 = Get-TextSha256 ([string]$cim.CommandLine)
            affinity_mask_hex = ('0x{0:X}' -f [uint64]$live.ProcessorAffinity.ToInt64())
            mod_order = @()
        }
    }
    $document.process_topology = @($topology)
    $document.mission.expected_hcs = 1
    $document.mission.player_count = 1
    $document.mission.mod_order = @()
    $document.workload.requested.hcs = 1
    $document.workload.requested.players = 1

    $document | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Destination -Encoding UTF8
    return $document
}

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("wasp-perf-capture-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null
$helpers = @()

try {
    $shell = (Get-Process -Id $PID).Path
    $helperLifetime = [math]::Max(30, [math]::Ceiling(($CaptureSamples * $CaptureIntervalSeconds) + 20))
    foreach ($role in @('server', 'hc', 'client')) {
        $helpers += Start-Process -FilePath $shell -ArgumentList @('-NoProfile', '-Command', "Start-Sleep -Seconds $helperLifetime") -PassThru -WindowStyle Hidden
    }

    $deadline = [datetime]::UtcNow.AddSeconds(10)
    do {
        Start-Sleep -Milliseconds 100
        $observable = @($helpers | Where-Object { Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue })
    } while ($observable.Count -ne 3 -and [datetime]::UtcNow -lt $deadline)
    Assert ($observable.Count -eq 3) 'three test helpers became observable through Win32_Process'

    $manifestSeed = Join-Path $work 'MANIFEST.seed.json'
    $document = New-TestManifest -Processes $helpers -Destination $manifestSeed
    $output = Join-Path $work $document.artifact_directory
    New-Item -ItemType Directory -Path $output -Force | Out-Null
    $manifest = Join-Path $output 'MANIFEST.json'
    Move-Item -LiteralPath $manifestSeed -Destination $manifest
    & python $validator $manifest | Out-Host
    Assert ($LASTEXITCODE -eq 0) 'dynamic pending manifest validates'

    Write-Host "`n[1] manifest placement fails closed"
    $misplacedRoot = Join-Path $work 'misplaced-manifest'
    New-Item -ItemType Directory -Path $misplacedRoot -Force | Out-Null
    $misplacedManifest = Join-Path $misplacedRoot 'MANIFEST.json'
    Copy-Item -LiteralPath $manifest -Destination $misplacedManifest
    $misplacedOutput = Join-Path (Join-Path $work 'different-parent') $document.artifact_directory
    $threw = $false
    try {
        & $collector -ManifestPath $misplacedManifest -OutputDirectory $misplacedOutput -SampleCount 1 -IntervalSeconds 0.1
    } catch {
        $threw = $true
        Assert ($_.Exception.Message -match 'inside the output directory') 'placement error explains the run-directory contract'
    }
    Assert $threw 'manifest outside the output directory is rejected'
    Assert (-not (Test-Path -LiteralPath (Join-Path $misplacedOutput 'process-metrics.csv'))) 'placement mismatch writes no metrics CSV'

    Write-Host "`n[2] completed lifecycle fails closed"
    $completedOutput = Join-Path (Join-Path $work 'completed-lifecycle') $document.artifact_directory
    New-Item -ItemType Directory -Path $completedOutput -Force | Out-Null
    $completedManifest = Join-Path $completedOutput 'MANIFEST.json'
    $completed = Get-Content -Raw -LiteralPath $manifest | ConvertFrom-Json
    $completed.validation.status = 'invalid'
    $completed.validation.invalid_reasons = @('Synthetic completed-run fixture')
    $completed.timing.end_utc = Format-Utc ([datetime]::UtcNow.AddSeconds(2))
    $completed | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $completedManifest -Encoding UTF8
    & python $validator $completedManifest | Out-Host
    Assert ($LASTEXITCODE -eq 0) 'completed invalid fixture validates structurally'
    $threw = $false
    try {
        & $collector -ManifestPath $completedManifest -OutputDirectory $completedOutput -SampleCount 1 -IntervalSeconds 0.1
    } catch {
        $threw = $true
        Assert ($_.Exception.Message -match 'pending manifest') 'lifecycle error explains pending-only capture'
    }
    Assert $threw 'completed manifest is rejected before recapture'
    Assert (-not (Test-Path -LiteralPath (Join-Path $completedOutput 'process-metrics.csv'))) 'completed lifecycle writes no metrics CSV'

    Write-Host "`n[3] read-only capture contract"
    try {
        & $collector -ManifestPath $manifest -OutputDirectory $output -SampleCount $CaptureSamples -IntervalSeconds $CaptureIntervalSeconds
    } catch {
        Write-Host ("collector stack: " + $_.ScriptStackTrace) -ForegroundColor Yellow
        throw
    }

    $csvPath = Join-Path $output 'process-metrics.csv'
    $identityPath = Join-Path $output 'process-identity.json'
    $overheadPath = Join-Path $output 'collector-overhead.json'
    Assert (Test-Path -LiteralPath $csvPath) 'process-metrics.csv written'
    Assert (Test-Path -LiteralPath $identityPath) 'process-identity.json written'
    Assert (Test-Path -LiteralPath $overheadPath) 'collector-overhead.json written'

    $rows = @(Import-Csv -LiteralPath $csvPath)
    $expectedRows = $CaptureSamples * 3
    Assert ($rows.Count -eq $expectedRows) "$expectedRows requested process samples written"
    foreach ($role in @('server', 'hc-01', 'client-01')) {
        Assert (@($rows | Where-Object { $_.role -eq $role }).Count -eq $CaptureSamples) "$role is present on every sample"
    }
    Assert (@($rows | Where-Object { $_.sample_status -eq 'ok' }).Count -eq $expectedRows) 'all live-process samples are ok'
    Assert ((@($rows | Select-Object -First 3 -ExpandProperty role) -join '|') -eq 'client-01|hc-01|server') 'roles are emitted in stable lexical order'

    $expectedColumns = @(
        'schema_version', 'run_id', 'sample_index', 'sample_utc', 'monotonic_seconds',
        'role', 'pid', 'process_start_utc', 'sample_status', 'error',
        'cpu_total_seconds', 'cpu_user_seconds', 'cpu_kernel_seconds', 'cpu_percent',
        'cpu_logical_core_equivalents', 'cpu_percent_total_capacity',
        'logical_processor_count', 'affinity_mask_hex', 'thread_count', 'handle_count',
        'context_switches_per_second', 'context_switches_available',
        'working_set_bytes', 'private_bytes', 'commit_bytes', 'virtual_bytes',
        'page_faults_total', 'page_faults_per_second',
        'io_read_operations_total', 'io_write_operations_total', 'io_other_operations_total',
        'io_read_bytes_total', 'io_write_bytes_total', 'io_other_bytes_total',
        'io_read_operations_per_second', 'io_write_operations_per_second', 'io_other_operations_per_second',
        'io_read_bytes_per_second', 'io_write_bytes_per_second', 'io_other_bytes_per_second'
    )
    $actualColumns = @($rows[0].PSObject.Properties.Name)
    Assert (($actualColumns -join '|') -eq ($expectedColumns -join '|')) 'CSV columns match the frozen order'

    $identity = Get-Content -Raw -LiteralPath $identityPath | ConvertFrom-Json
    Assert ($identity.schema_version -eq 'a2wasp-process-identity-v1') 'identity schema version is explicit'
    Assert ($identity.run_id -eq $document.run_id) 'identity carries run ID'
    Assert (@($identity.targets).Count -eq 3) 'three declared target identities emitted'
    Assert ($identity.targets[0].executable_sha256 -eq $document.specimens[0].sha256) 'executable identity hash matches manifest'
    Assert ($identity.targets[0].command_line_sha256 -eq $document.process_topology[0].command_line_sha256) 'raw command line represented only by matching hash'
    Assert (@($identity.targets[0].modules).Count -gt 0) 'module inventory captured once'
    Assert (@($identity.targets[0].modules | Where-Object { $_.sha256 }).Count -gt 0) 'at least one accessible module hash captured'

    $overhead = Get-Content -Raw -LiteralPath $overheadPath | ConvertFrom-Json
    Assert ($overhead.schema_version -eq 'a2wasp-collector-overhead-v1') 'overhead schema version is explicit'
    Assert ($overhead.samples_requested -eq $CaptureSamples) 'overhead records requested samples'
    Assert ($overhead.samples_written -eq $expectedRows) 'overhead records written process samples'
    Assert ($null -ne $overhead.query_duration_ms_p50) 'overhead records query p50'
    Assert ($null -ne $overhead.query_duration_ms_p95) 'overhead records query p95'
    Assert ($null -ne $overhead.collector_cpu_logical_core_percent) 'overhead records collector CPU'
    Assert ($overhead.manifest_changed_during_capture -eq $false) 'manifest stayed unchanged during capture'
    $wallBound = ($CaptureSamples * $CaptureIntervalSeconds) + 10
    Assert ($overhead.wall_seconds -lt $wallBound) 'benign capture avoids slow global counter providers'
    Assert ($overhead.query_duration_ms_p95 -lt ($CaptureIntervalSeconds * 900)) 'three-role query p95 fits inside 90% of the sample interval'

    foreach ($helper in $helpers) {
        $helper.Refresh()
        Assert (-not $helper.HasExited) "collector leaves target PID $($helper.Id) running"
    }

    Write-Host "`n[4] identity mismatch fails closed"
    $badRoot = Join-Path $work 'bad-identity'
    New-Item -ItemType Directory -Path $badRoot -Force | Out-Null
    $badOutput = Join-Path $badRoot $document.artifact_directory
    New-Item -ItemType Directory -Path $badOutput -Force | Out-Null
    $badManifest = Join-Path $badOutput 'MANIFEST.json'
    $bad = Get-Content -Raw -LiteralPath $manifest | ConvertFrom-Json
    $bad.process_topology[0].command_line_sha256 = ('0' * 64)
    $bad | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $badManifest -Encoding UTF8
    $threw = $false
    try {
        & $collector -ManifestPath $badManifest -OutputDirectory $badOutput -SampleCount 1 -IntervalSeconds 0.1
    } catch {
        $threw = $true
        Assert ($_.Exception.Message -match 'command line hash mismatch') 'mismatch error names command line hash'
    }
    Assert $threw 'identity mismatch throws before capture'
    Assert (-not (Test-Path -LiteralPath (Join-Path $badOutput 'process-metrics.csv'))) 'identity mismatch writes no metrics CSV'

} finally {
    foreach ($helper in $helpers) {
        $helper.Refresh()
        if (-not $helper.HasExited) {
            Stop-Process -Id $helper.Id -Force -ErrorAction SilentlyContinue
        }
    }
    if ($KeepArtifacts) {
        Write-Host "KEPT_ARTIFACTS=$work"
    } else {
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($fail -gt 0) {
    Write-Host "`nFAILED: $fail assertion(s)" -ForegroundColor Red
    exit 1
}

Write-Host "`nALL TESTS PASSED"
exit 0
