<#
    Deterministic weekly health probe for the isolated Game-PC WASP rig.

    The probe measures boot health only: the dedicated server must listen,
    reach MISSINIT, and leave no Arma processes behind. A short proving-ground
    run is intentional; a missing WASPLAB RESULT is recorded but does not make
    a successful boot unhealthy.
#>
[CmdletBinding()]
param(
    [string]$RigRoot = 'C:\Users\Game\a2oa-local-1.64',
    [string]$Config = 'lab-server-hc-stock.cfg',
    [string]$Mission = 'WASP_ProvingGround_fast-smoke_hc-stock.utes',
    [int]$Hcs = 1,
    [int]$ListenSecs = 120,
    [int]$LobbySecs = 240,
    [int]$RunSecs = 120,
    [string]$ArtDir = 'C:\Users\Game\wasp-build\lab-runs',
    [string]$StatusPath = 'C:\Users\Game\wasp-build\rig-health\weekly-status.json',
    [string]$FleetRoot = 'C:\wasp-share\Mijn vualt\Fleet',
    [string]$FleetScript = 'C:\wasp-share\Mijn vualt\Fleet\Tools\Fleet.ps1',
    [string]$FleetAgent = 'codex-gaming-lane-2',
    [string]$Tag = ''
)

$ErrorActionPreference = 'Stop'
$started = Get-Date
if ([string]::IsNullOrWhiteSpace($Tag)) {
    $Tag = 'weekly-' + $started.ToString('yyyyMMdd-HHmmss')
}

$labBoot = Join-Path $RigRoot 'lab-boot.ps1'
$driverLog = Join-Path $RigRoot ("lab-boot-{0}.log" -f $Tag)
$artifactDir = Join-Path $ArtDir $Tag
$runLog = Join-Path (Split-Path -Parent $StatusPath) ("run-{0}.log" -f $Tag)

function Write-StatusFile {
    param([hashtable]$Value)

    $parent = Split-Path -Parent $StatusPath
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    $temp = $StatusPath + '.tmp-' + [Guid]::NewGuid().ToString('N')
    [IO.File]::WriteAllText($temp, ($Value | ConvertTo-Json -Depth 8) + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $temp -Destination $StatusPath -Force
}

function Get-FirstMatch {
    param([string[]]$Lines, [string]$Pattern)
    return ($Lines | Where-Object { $_ -match $Pattern } | Select-Object -First 1)
}

$driverExit = 1
$runLines = New-Object 'System.Collections.Generic.List[string]'
$driverArgs = @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $labBoot,
    '-Config', $Config, '-Tag', $Tag, '-Mission', $Mission, '-Hcs', $Hcs,
    '-ListenSecs', $ListenSecs, '-LobbySecs', $LobbySecs, '-RunSecs', $RunSecs,
    '-ArtDir', $ArtDir
)

try {
    if (-not (Test-Path -LiteralPath $labBoot)) { throw "lab-boot.ps1 not found: $labBoot" }
    & powershell.exe @driverArgs 2>&1 | ForEach-Object {
        $line = [string]$_
        $runLines.Add($line)
        Write-Output $line
    }
    $driverExit = $LASTEXITCODE
} catch {
    $runLines.Add('probe exception: ' + $_.Exception.Message)
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $runLog) | Out-Null
$runLines | Set-Content -LiteralPath $runLog -Encoding UTF8

$driverLines = @()
if (Test-Path -LiteralPath $driverLog) {
    $driverLines = @(Get-Content -LiteralPath $driverLog -ErrorAction SilentlyContinue)
}
$allLines = @($runLines + $driverLines)
$missinitLine = Get-FirstMatch $allLines 'MISSINIT ->'
$listeningLine = Get-FirstMatch $allLines 'server listening=True'
$resultLine = Get-FirstMatch $allLines 'WASPLAB\|v1\|RESULT'
$finalLine = Get-FirstMatch $allLines 'RESULT \['
$abortLine = Get-FirstMatch $allLines '(?i)\b(ERROR|ABORT|FAIL):'

$driverVerdict = ''
$remaining = -1
if ($finalLine -match 'RESULT \[[^]]+\]:\s+([A-Z_]+)\s+arma_remaining=(\d+)') {
    $driverVerdict = $matches[1]
    $remaining = [int]$matches[2]
}

$serverRpt = Join-Path $artifactDir 'arma2oaserver.RPT'
$missingAddons = @()
if (Test-Path -LiteralPath $serverRpt) {
    $missingAddons = @(Select-String -LiteralPath $serverRpt -Pattern 'Missing addons' -SimpleMatch | ForEach-Object Line)
}

$bootHealthy = ($null -ne $listeningLine) -and ($null -ne $missinitLine) -and ($null -eq $abortLine) -and ($remaining -eq 0) -and ($missingAddons.Count -eq 0)
$status = if ($bootHealthy) { 'PASS' } else { 'FAIL' }
$fleetCardId = ''
$fleetCardResult = 'not-needed'

if ($status -eq 'FAIL') {
    $fleetCardId = 'rig-health-fail-' + $started.ToString('yyyyMMdd-HHmmss')
    if (Test-Path -LiteralPath $FleetScript) {
        $message = "Automated local rig health probe failed. agent=$FleetAgent tag=$Tag bootHealthy=$bootHealthy driverVerdict=$driverVerdict driverExit=$driverExit log=$driverLog status=$StatusPath"
        try {
            $fleetArgs = @(
                '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $FleetScript,
                'new', '-Root', $FleetRoot, '-Id', $fleetCardId,
                '-Title', "WASP local rig health FAIL $Tag", '-Project', 'a2waspwarfare',
                '-Machine', 'gaming', '-Priority', 80, '-Message', $message
            )
            & powershell.exe @fleetArgs 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { $fleetCardResult = 'created' } else { $fleetCardResult = 'create-failed-exit-' + $LASTEXITCODE }
        } catch {
            $fleetCardResult = 'create-failed-' + $_.Exception.Message
        }
    } else {
        $fleetCardResult = 'fleet-script-not-found'
    }
}

$ended = Get-Date
$record = [ordered]@{
    schema = 'a2wasp-rig-health-v1'
    status = $status
    startedUtc = $started.ToUniversalTime().ToString('o')
    endedUtc = $ended.ToUniversalTime().ToString('o')
    durationSec = [math]::Round(($ended - $started).TotalSeconds, 1)
    host = $env:COMPUTERNAME
    tag = $Tag
    rigRoot = $RigRoot
    config = $Config
    mission = $Mission
    hcs = $Hcs
    driverExit = $driverExit
    driverVerdict = $driverVerdict
    resultObserved = ($null -ne $resultLine)
    listeningObserved = ($null -ne $listeningLine)
    missinitObserved = ($null -ne $missinitLine)
    missingAddonCount = $missingAddons.Count
    armaRemaining = $remaining
    cleanupHealthy = ($remaining -eq 0)
    driverLog = $driverLog
    runLog = $runLog
    artifactDir = $artifactDir
    serverRpt = $serverRpt
    fleetCardId = $fleetCardId
    fleetCardResult = $fleetCardResult
}
Write-StatusFile $record

Write-Output ('RIG_HEALTH[{0}] tag={1} driverVerdict={2} missinit={3} cleanup={4} fleet={5}' -f $status, $Tag, $driverVerdict, ($null -ne $missinitLine), ($remaining -eq 0), $fleetCardResult)
if ($status -eq 'FAIL') { exit 1 }
exit 0
