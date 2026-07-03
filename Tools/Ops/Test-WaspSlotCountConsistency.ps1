#requires -Version 5.1
<#
.SYNOPSIS
    Validates WF_MAXPLAYERS against playable mission.sqm slots.

.DESCRIPTION
    The mission folder prefix and version.sqf.template define are easy to drift
    away from the actual playable lobby slots. This read-only check compares
    WF_MAXPLAYERS in each maintained template against player declarations in the
    matching mission.sqm.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot
)

$ErrorActionPreference = "Stop"
$script:fails = 0
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $scriptPath = $MyInvocation.MyCommand.Path
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $scriptPath))
}

function Read-RequiredText {
    param([Parameter(Mandatory)] [string]$Path)

    if (!(Test-Path -LiteralPath $Path)) {
        throw "Required file not found: $Path"
    }

    return Get-Content -LiteralPath $Path -Raw
}

function Get-WfMaxPlayers {
    param([Parameter(Mandatory)] [string]$TemplatePath)

    $text = Read-RequiredText $TemplatePath
    $match = [regex]::Match($text, '(?m)^\s*#define\s+WF_MAXPLAYERS\s+([0-9]+)\s*$')
    if (!$match.Success) {
        throw "WF_MAXPLAYERS define not found: $TemplatePath"
    }

    return [int]$match.Groups[1].Value
}

function Remove-LineComments {
    param([Parameter(Mandatory)] [string]$Text)

    $lines = $Text -split "\r?\n"
    return (($lines | ForEach-Object { $_ -replace '//.*$', '' }) -join "`n")
}

function Get-PlayableSlotCount {
    param([Parameter(Mandatory)] [string]$MissionSqmPath)

    $text = Remove-LineComments (Read-RequiredText $MissionSqmPath)
    return ([regex]::Matches($text, '(?m)^\s*player\s*=\s*"[^"]+"\s*;')).Count
}

$terrains = @(
    [pscustomobject]@{
        Name = "Chernarus"
        MissionRoot = "Missions\[55-2hc]warfarev2_073v48co.chernarus"
    },
    [pscustomobject]@{
        Name = "Takistan"
        MissionRoot = "Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan"
    },
    [pscustomobject]@{
        Name = "Zargabad"
        MissionRoot = "Missions_Vanilla\[61-2hc]warfarev2_073v48co.zargabad"
    }
)

$resolvedRoot = [System.IO.Path]::GetFullPath($RepoRoot)

foreach ($terrain in $terrains) {
    $missionRoot = Join-Path $resolvedRoot $terrain.MissionRoot
    $templatePath = Join-Path $missionRoot "version.sqf.template"
    $missionSqmPath = Join-Path $missionRoot "mission.sqm"

    $maxPlayers = Get-WfMaxPlayers $templatePath
    $slotCount = Get-PlayableSlotCount $missionSqmPath

    if ($maxPlayers -eq $slotCount) {
        Write-Host ("  PASS  {0}: WF_MAXPLAYERS={1}, playable slots={2}" -f $terrain.Name, $maxPlayers, $slotCount)
    } else {
        Write-Host ("  FAIL  {0}: WF_MAXPLAYERS={1}, playable slots={2}" -f $terrain.Name, $maxPlayers, $slotCount) -ForegroundColor Red
        $script:fails++
    }
}

Write-Host ""
if ($script:fails -eq 0) {
    Write-Host "Test-WaspSlotCountConsistency: PASS" -ForegroundColor Green
    exit 0
}

Write-Host ("Test-WaspSlotCountConsistency: {0} mismatch(es)" -f $script:fails) -ForegroundColor Red
exit 1
