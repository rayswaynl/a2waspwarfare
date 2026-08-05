<#
.SYNOPSIS
    Regression test for fractional helicopter EASA price modifiers.

.DESCRIPTION
    Exercises the actual compiled private price helper through reflection.  Helicopter
    modifiers deliberately contain fractions (for example Hellfire 0.833333 and
    Sidewinder 5.714285), so price calculation must multiply before integer rounding.
#>
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
)

$ErrorActionPreference = 'Stop'
$manager = Join-Path $RepoRoot 'Tools\LoadoutManager'
Push-Location $manager
try {
    $buildOutput = & dotnet build -c RELEASE --nologo 2>&1
    if ($LASTEXITCODE -ne 0) {
        $buildOutput | ForEach-Object { Write-Host $_ }
        throw "LoadoutManager build failed with exit $LASTEXITCODE."
    }
} finally {
    Pop-Location
}

$dll = Join-Path $manager 'bin\RELEASE\net8.0\LoadoutManager.dll'
$assembly = [System.Reflection.Assembly]::LoadFrom($dll)
$aircraftType = $assembly.GetType('BaseAircraft', $true)
$ammoType = $assembly.GetType('AmmunitionType', $true)
$aircraft = [Activator]::CreateInstance($assembly.GetType('AH1Z', $true))
$method = $aircraftType.GetMethod('CalculateLoadoutTotalPrice', [System.Reflection.BindingFlags]'Instance,NonPublic')
if ($null -eq $method) { throw 'Aircraft price helper was not found.' }

function Assert-ModifierPrice {
    param([string]$AmmoName, [int]$BasePrice, [int]$Expected)
    $ammo = [System.Enum]::Parse($ammoType, $AmmoName)
    $actual = [int]$method.Invoke($aircraft, @($ammo, $BasePrice))
    if ($actual -ne $Expected) {
        throw "Expected $AmmoName price $Expected from base $BasePrice, got $actual."
    }
}

Assert-ModifierPrice -AmmoName 'EIGHTROUNDHELLFIRE' -BasePrice 1200 -Expected 1000
Assert-ModifierPrice -AmmoName 'TWOROUNDSIDEWINDER' -BasePrice 1400 -Expected 8000
Assert-ModifierPrice -AmmoName 'SIXROUNDFAB250' -BasePrice 600 -Expected 900

Write-Host 'PASS: fractional helicopter price modifiers retain their fractional value.' -ForegroundColor Green
