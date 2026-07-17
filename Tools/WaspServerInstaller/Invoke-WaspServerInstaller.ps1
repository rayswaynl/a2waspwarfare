#requires -Version 5.1
<#
.SYNOPSIS
  Easy config-driven WASP main-server installer (owner-facing).

.DESCRIPTION
  Actions:
    NewConfig   - write a config JSON (interactive or from example)
    Catalog     - print curated flag catalog + layer notes
    Validate    - validate config
    DryRun      - render + diff against install root (no writes)
    Apply       - write rendered server.cfg/basic.cfg/launchers/flag-plan into install root
    Affinity    - print computed affinity plan only

  Reconciles with HetznerInstaller (PR #1102) + Deploy-Wasp.ps1 + server-config snapshots.
  NEVER targets the live main server. difficulty is always Veteran.

.EXAMPLE
  .\Invoke-WaspServerInstaller.ps1 -Action NewConfig -ConfigPath .\my-server.json
  .\Invoke-WaspServerInstaller.ps1 -Action Validate -ConfigPath .\my-server.json
  .\Invoke-WaspServerInstaller.ps1 -Action DryRun -ConfigPath .\my-server.json -InstallRoot D:\scratch\wasp-main
  .\Invoke-WaspServerInstaller.ps1 -Action Apply -ConfigPath .\my-server.json -InstallRoot D:\scratch\wasp-main -PasswordAdmin (Read-Host -AsSecureString)
#>
[CmdletBinding()]
param(
    [ValidateSet('NewConfig','Catalog','Validate','DryRun','Apply','Affinity')]
    [string]$Action = 'Validate',

    [string]$ConfigPath,

    [string]$InstallRoot,

    [string]$Password,

    [string]$PasswordAdmin,

    [switch]$Interactive,

    [switch]$Json,

    [int]$LogicalProcessors = 0
)

$ErrorActionPreference = 'Stop'
Import-Module -Force (Join-Path $PSScriptRoot 'WaspServerInstaller.psm1')

function Write-WsiOut($obj) {
    if ($Json) { $obj | ConvertTo-Json -Depth 12; return }
    if ($obj -is [string]) { Write-Host $obj; return }
    $obj | Format-List | Out-String | Write-Host
}

switch ($Action) {
    'NewConfig' {
        if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
            $ConfigPath = Join-Path (Get-Location) 'wasp-server.json'
        }
        if ($Interactive) {
            $p = Invoke-WsiInteractiveNewConfig -OutPath $ConfigPath
            Write-WsiOut ([pscustomobject]@{ Ok = $true; ConfigPath = $p })
        } else {
            $cfg = New-WsiDefaultConfig
            if ($InstallRoot) { $cfg.paths.installRoot = $InstallRoot }
            Save-WsiConfig -Config $cfg -Path $ConfigPath | Out-Null
            Write-WsiOut ([pscustomobject]@{ Ok = $true; ConfigPath = $ConfigPath; Note = 'Copied from example; edit then Validate/DryRun/Apply' })
        }
    }
    'Catalog' {
        $cat = Get-WsiFlagCatalog
        if ($Json) { $cat | ConvertTo-Json -Depth 12 }
        else {
            Write-Host "Flag catalog schema $($cat.schemaVersion)"
            Write-Host $cat.layerNote
            Write-Host ''
            foreach ($f in $cat.flags) {
                Write-Host ("[{0}] {1}  layer={2}  default={3}" -f $f.id, $f.title, $f.layer, $f.safeDefault)
                Write-Host ("    {0}" -f $f.description)
            }
        }
    }
    'Validate' {
        if ([string]::IsNullOrWhiteSpace($ConfigPath)) { throw '-ConfigPath required' }
        $cfg = Read-WsiJsonFile -Path $ConfigPath
        if ($InstallRoot) { $cfg.paths.installRoot = $InstallRoot }
        $r = Test-WsiConfig -Config $cfg -RequireInstallRoot:$false
        if (-not $r.Ok) { Write-WsiOut $r; exit 2 }
        Write-WsiOut $r
    }
    'Affinity' {
        if ([string]::IsNullOrWhiteSpace($ConfigPath)) { throw '-ConfigPath required' }
        $cfg = Read-WsiJsonFile -Path $ConfigPath
        $plan = Get-WsiAffinityPlan -Config $cfg -LogicalCount $LogicalProcessors
        Write-Host $plan.MathComment
        if ($Json) { $plan | ConvertTo-Json -Depth 8 }
    }
    'DryRun' {
        if ([string]::IsNullOrWhiteSpace($ConfigPath)) { throw '-ConfigPath required' }
        $cfg = Read-WsiJsonFile -Path $ConfigPath
        if ($InstallRoot) { $cfg.paths.installRoot = $InstallRoot }
        $v = Test-WsiConfig -Config $cfg -RequireInstallRoot
        if (-not $v.Ok) { Write-WsiOut $v; exit 2 }
        $bundle = New-WsiRenderBundle -Config $cfg -Password $Password -PasswordAdmin $PasswordAdmin -LogicalCount $LogicalProcessors
        $root = [string]$cfg.paths.installRoot
        $diffs = @()
        if (Test-Path -LiteralPath $root) {
            $diffs = Compare-WsiRenderToDisk -Bundle $bundle -InstallRoot $root
        } else {
            $diffs = @($bundle.Files.Keys | ForEach-Object { [pscustomobject]@{ Path = $_; Status = 'MISSING'; Detail = 'install root absent — would create all' } })
        }
        $out = [pscustomobject]@{
            Ok = $true
            Action = 'DryRun'
            InstallRoot = $root
            FileCount = $bundle.Files.Count
            Affinity = $bundle.Affinity.MathComment
            Diffs = $diffs
            TelemetryMode = [string]$cfg.telemetry.mode
            Difficulty = 'Veteran'
        }
        Write-WsiOut $out
        if (-not $Json) {
            Write-Host "`nDiff summary:"
            $diffs | Format-Table -AutoSize | Out-String | Write-Host
        }
    }
    'Apply' {
        if ([string]::IsNullOrWhiteSpace($ConfigPath)) { throw '-ConfigPath required' }
        $cfg = Read-WsiJsonFile -Path $ConfigPath
        if ($InstallRoot) { $cfg.paths.installRoot = $InstallRoot }
        $v = Test-WsiConfig -Config $cfg -RequireInstallRoot
        if (-not $v.Ok) { Write-WsiOut $v; exit 2 }
        $root = [string]$cfg.paths.installRoot
        if ($root -match '(?i)^[cC]:\\WASP(\\|$)' -and $env:WASP_INSTALLER_ALLOW_LIVE_SHAPED -ne '1') {
            throw "Refusing Apply to live-shaped path $root (set WASP_INSTALLER_ALLOW_LIVE_SHAPED=1 only with owner authority)"
        }
        $bundle = New-WsiRenderBundle -Config $cfg -Password $Password -PasswordAdmin $PasswordAdmin -LogicalCount $LogicalProcessors
        if (-not (Test-Path -LiteralPath $root)) {
            New-Item -ItemType Directory -Force -Path $root | Out-Null
        }
        $wrote = Install-WsiRenderBundle -Bundle $bundle -InstallRoot $root -Apply
        $out = [pscustomobject]@{
            Ok = $true
            Action = 'Apply'
            InstallRoot = $root
            Wrote = $wrote
            Affinity = $bundle.Affinity.ServerMaskHex
            HcMasks = $bundle.Affinity.HcMaskHex
            Next = @(
                'Review flag-plan/README.md — lobby flags need Deploy-Wasp repack or lobby UI',
                'Pack/deploy mission via Tools/Ops/Deploy-Wasp.ps1 when ready (owner)',
                'Optional fence handoff: Tools/HetznerInstaller (PR #1102)',
                'Optional post-boot: Tools/Ops/Set-WaspCpuAffinity.ps1'
            )
        }
        Write-WsiOut $out
    }
    default { throw "Unknown action $Action" }
}
