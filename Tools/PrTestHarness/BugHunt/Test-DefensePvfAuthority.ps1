<#
.SYNOPSIS
    Static contract for the server-authoritative RequestDefense PVF protocol.

.DESCRIPTION
    A defense request must validate its client-provided envelope before selecting
    any element or entering the construction path.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$mission = Join-Path $repoRoot 'Missions\[55-2hc]warfarev2_073v48co.chernarus'
$serverPath = Join-Path $mission 'Server\PVFunctions\RequestDefense.sqf'
$server = [System.IO.File]::ReadAllText($serverPath)

function Require-Text {
    param([string]$Text, [string]$Needle, [string]$Label)
    if ($Text.IndexOf($Needle, [System.StringComparison]::Ordinal) -lt 0) {
        throw "Missing ${Label}: $Needle"
    }
}

Require-Text $server 'RequestDefense.sqf: rejected non-array payload' 'non-array rejection'
Require-Text $server 'RequestDefense.sqf: rejected short payload' 'short payload rejection'
Require-Text $server 'RequestDefense.sqf: rejected invalid placement payload' 'placement type rejection'
Require-Text $server 'RequestDefense.sqf: rejected invalid requester' 'requester validation'

$firstSelect = $server.IndexOf('_this select 0', [System.StringComparison]::Ordinal)
$firstGuard = $server.IndexOf('RequestDefense.sqf: rejected non-array payload', [System.StringComparison]::Ordinal)
if ($firstSelect -lt 0 -or $firstGuard -lt 0 -or $firstGuard -gt $firstSelect) {
    throw 'RequestDefense must reject malformed envelopes before selecting payload elements.'
}

Write-Host 'PASS: defense PVF validates its request envelope before construction.' -ForegroundColor Green
