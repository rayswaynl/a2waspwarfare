#requires -Version 5.1
<#
.SYNOPSIS
    Guards oilfield GUER raid accounting when engine unit creation fails.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$script:fails = 0

function Assert-Match {
	param([string]$Text, [string]$Pattern, [string]$Label)
	if ($Text -match $Pattern) { Write-Host ("  PASS  {0}" -f $Label) }
	else { Write-Host ("  FAIL  {0}" -f $Label) -ForegroundColor Red; $script:fails++ }
}

function Assert-Ordered {
	param([string]$Text, [string]$First, [string]$Second, [string]$Label)
	$firstIndex = $Text.IndexOf($First, [System.StringComparison]::Ordinal)
	$secondIndex = $Text.IndexOf($Second, [System.StringComparison]::Ordinal)
	if ($firstIndex -ge 0 -and $secondIndex -ge 0 -and $firstIndex -lt $secondIndex) {
		Write-Host ("  PASS  {0}" -f $Label)
	} else {
		Write-Host ("  FAIL  {0}" -f $Label) -ForegroundColor Red
		$script:fails++
	}
}

function Assert-EqualNormalized {
	param([string]$Left, [string]$Right, [string]$Label)
	$leftNormalized = $Left -replace "`r`n", "`n"
	$rightNormalized = $Right -replace "`r`n", "`n"
	if ($leftNormalized -ceq $rightNormalized) { Write-Host ("  PASS  {0}" -f $Label) }
	else { Write-Host ("  FAIL  {0}" -f $Label) -ForegroundColor Red; $script:fails++ }
}

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$roots = @(
	"Missions\[55-2hc]warfarev2_073v48co.chernarus",
	"Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan",
	"Missions_Vanilla\[61-2hc]warfarev2_073v48co.zargabad"
)
$sources = @()
foreach ($root in $roots) {
	$path = Join-Path $repoRoot (Join-Path $root "Server\Server_Oilfields.sqf")
	if (!(Test-Path -LiteralPath $path)) { throw "Source not found: $path" }
	$sources += [PSCustomObject]@{ Root = $root; Text = Get-Content -LiteralPath $path -Raw }
}
$source = $sources[0].Text

Write-Host "Checking canonical oilfield GUER raid spawn accounting"
Assert-Match $source 'private \[.*"_created".*\];' "raid spawner declares a created-unit counter"
Assert-Match $source '_created = 0;' "raid counter starts at zero"
Assert-Match $source 'if \(!isNull _u\) then \{\s*_u setVariable \["WFBE_IsTownDefenderAI", true, true\];\s*_created = _created \+ 1;\s*\};' "only successful units increment the counter"
Assert-Match $source '(?s)if \(_created < 1\) exitWith \{\s*deleteGroup _grp;.*?GUERRAID.*?created=0.*?\};' "zero-unit raid deletes its empty group and records the failure"
Assert-Ordered $source 'if (_created < 1) exitWith {' '[_grp, _nodePos, 90] Call AIPatrol;' "zero-unit guard runs before patrol setup"
Assert-Ordered $source 'if (_created < 1) exitWith {' 'missionNamespace setVariable ["WFBE_OILFIELD_GUER_LAST", time];' "zero-unit guard runs before cooldown state"
Assert-Match $source 'OILFIELD\|v2\|GUERRAID\|t=%1\|requested=%2\|created=%3\|from=%4' "success telemetry reports requested and created counts"
Assert-Match $source 'GUER raid \(%1/%2 raiders\) dispatched' "operator log reports actual versus requested count"

foreach ($terrain in $sources | Select-Object -Skip 1) {
	$label = if ($terrain.Root -like '*takistan*') { 'Takistan' } else { 'Zargabad' }
	Assert-EqualNormalized $source $terrain.Text "$label oilfield handler mirrors Chernarus"
}

Write-Host ""
if ($script:fails -eq 0) {
	Write-Host "Test-OilfieldGuerRaidSpawnAccounting: PASS" -ForegroundColor Green
	exit 0
}

Write-Host ("Test-OilfieldGuerRaidSpawnAccounting: {0} failure(s)" -f $script:fails) -ForegroundColor Red
exit 1
