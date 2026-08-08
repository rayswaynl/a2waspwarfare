$ErrorActionPreference = 'Stop'

$sourcePath = Join-Path $PSScriptRoot 'Update-PublicStats.ps1'
$probeRoot = Join-Path ([IO.Path]::GetTempPath()) ('wasp-public-stats-window-test-' + [guid]::NewGuid().ToString('N'))
$webDir = Join-Path $probeRoot 'web'
$rptPath = Join-Path $probeRoot 'missing.RPT'
$monitorLog = Join-Path $probeRoot 'monitor.log'
$deployLog = Join-Path $probeRoot 'deploy.log'
$evalDir = Join-Path $probeRoot 'eval'
$statsPath = Join-Path $webDir 'stats.json'
$historyDir = Join-Path $webDir 'history'

function Invoke-PublicStatsProbe {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $sourcePath `
        -RptPath $rptPath -WebDir $webDir -MonitorLog $monitorLog -DeployLog $deployLog `
        -EvalDir $evalDir -MissionLabel WASP 2>&1
}

try {
    New-Item -ItemType Directory -Force -Path $probeRoot | Out-Null

    $firstOutput = @(Invoke-PublicStatsProbe | ForEach-Object { $_.ToString() })
    $firstStats = Get-Content -Raw -LiteralPath $statsPath | ConvertFrom-Json
    if (-not ($firstStats.PSObject.Properties.Name -contains 'warmingUp') -or -not $firstStats.warmingUp) {
        throw 'first no-MISSINIT run did not leave a warming-up placeholder'
    }
    $firstSnapshots = @(Get-ChildItem -LiteralPath $historyDir -Filter 'snap-*.json' -File -ErrorAction SilentlyContinue)
    if ($firstSnapshots.Count -ne 0) {
        throw "no-MISSINIT run wrote $($firstSnapshots.Count) history snapshot(s)"
    }

    # Seed a stale no-MISSINIT snapshot plus an existing public file. The publication
    # gate must not promote the stale empty snapshot or overwrite the existing story.
    $oldEpoch = [int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - 300
    $oldSnapshot = Join-Path $historyDir ("snap-$oldEpoch.json")
    $stale = [ordered]@{
        generatedAt = 'stale-no-missinit-fixture'; dataDelaySeconds = 120; warmingUp = $false
        server = [ordered]@{ online = $false; uptimeMin = $null; playersOnline = $null; headlessClients = 0; map = 'Chernarus'; mapId = 'chernarus'; arm = $null }
    } | ConvertTo-Json -Depth 5
    [IO.File]::WriteAllText($oldSnapshot, $stale, (New-Object Text.UTF8Encoding($false)))
    $baseline = [ordered]@{ marker = 'keep-existing-public-story'; generatedAt = 'baseline' } | ConvertTo-Json -Depth 3
    [IO.File]::WriteAllText($statsPath, $baseline, (New-Object Text.UTF8Encoding($false)))

    $secondOutput = @(Invoke-PublicStatsProbe | ForEach-Object { $_.ToString() })
    $secondStats = Get-Content -Raw -LiteralPath $statsPath | ConvertFrom-Json
    if ([string]$secondStats.marker -ne 'keep-existing-public-story') {
        throw 'no-MISSINIT run overwrote existing stats.json from an aged snapshot'
    }
    $secondSnapshots = @(Get-ChildItem -LiteralPath $historyDir -Filter 'snap-*.json' -File -ErrorAction SilentlyContinue)
    if ($secondSnapshots.Count -ne 1 -or $secondSnapshots[0].Name -ne (Split-Path -Leaf $oldSnapshot)) {
        throw 'no-MISSINIT run changed the delayed history stream'
    }
    if (-not (($secondOutput -join "`n") -match 'no current MISSINIT window')) {
        throw 'no-MISSINIT run did not report the publication hold'
    }

    # A real current window still enters the delayed stream. This guards the fix
    # against accidentally disabling normal publication alongside the no-window hold.
    Remove-Item -LiteralPath $webDir -Recurse -Force
    New-Item -ItemType Directory -Force -Path $webDir | Out-Null
    [IO.File]::WriteAllText($rptPath, 'MISSINIT: worldName=chernarus,missionName=[55] Test`r`n', (New-Object Text.UTF8Encoding($false)))
    $validOutput = @(Invoke-PublicStatsProbe | ForEach-Object { $_.ToString() })
    $validSnapshots = @(Get-ChildItem -LiteralPath (Join-Path $webDir 'history') -Filter 'snap-*.json' -File -ErrorAction SilentlyContinue)
    if ($validSnapshots.Count -ne 1) {
        throw 'current MISSINIT window did not create a delayed history snapshot'
    }

    Write-Output 'PASS: no-MISSINIT runs warm up without snapshots and never publish stale empty data.'
} finally {
    if (Test-Path -LiteralPath $probeRoot) {
        Remove-Item -LiteralPath $probeRoot -Recurse -Force
    }
}
