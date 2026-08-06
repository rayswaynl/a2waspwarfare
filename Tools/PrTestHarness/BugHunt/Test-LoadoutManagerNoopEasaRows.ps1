<#
.SYNOPSIS
    Rejects EASA rows that charge for the generated factory payload.

.DESCRIPTION
    Exercises the generated EASA catalog.  A selectable row identical to the factory
    payload makes GUI_Menu_EASA remove and re-add the same weapons/magazines, then
    debit its price.
#>
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
)

$ErrorActionPreference = 'Stop'
$easaPath = Join-Path $RepoRoot 'Missions\[55-2hc]warfarev2_073v48co.chernarus\Client\Module\EASA\EASA_Init.sqf'
if (!(Test-Path -LiteralPath $easaPath)) { throw "Generated EASA catalog was not found: $easaPath" }

$easa = Get-Content -Raw -LiteralPath $easaPath
$vehicle = ''
$factoryPayload = ''
$duplicates = @()

foreach ($line in ($easa -split "`r?`n")) {
    if ($line -match "_easaVehi = _easaVehi \+ \['([^']+)'\]") {
        $vehicle = $Matches[1]
        $factoryPayload = ''
        continue
    }

    if ($line -match "_easaDefault = _easaDefault \+ \[\[(\[[^\]]*\],\[[^\]]*\])\]\]") {
        $factoryPayload = $Matches[1]
        continue
    }

    if ($factoryPayload -ne '' -and $line -match "^\[(\d+),'[^']*',(\[[^\]]*\],\[[^\]]*\])\]\],?$") {
        $rowPayload = $Matches[2].Substring(1)
        if ($rowPayload -eq $factoryPayload) {
            $duplicates += "$vehicle (`$$($Matches[1]))"
        }
    }
}

if ($duplicates.Count -gt 0) {
    throw "Generated EASA catalog contains paid factory-loadout no-op rows: $($duplicates -join ', ')."
}

Write-Host 'PASS: generated EASA rows exclude the factory payload.' -ForegroundColor Green
