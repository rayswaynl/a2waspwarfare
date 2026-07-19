#requires -Version 5.1
<#
.SYNOPSIS
    Guards the GUER Commissar Counter-Attack no-op payment gate.

.DESCRIPTION
    The current Director has no target-bound retake materializer. Until one is
    designed, the server must reject the panel's `counter` verb before cooldown,
    scarcity, wallet, pending-order, or contract state can change. The existing
    client result channel renders the denial; no client authority is added.
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

function Read-Source {
	param([string]$RelativePath)
	$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
	$path = Join-Path $repoRoot $RelativePath
	if (!(Test-Path -LiteralPath $path)) { throw "Source not found: $path" }
	Get-Content -LiteralPath $path -Raw
}

$ch = Read-Source "Missions\[55-2hc]warfarev2_073v48co.chernarus\Server\PVFunctions\RequestGDirPanel.sqf"
$tk = Read-Source "Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan\Server\PVFunctions\RequestGDirPanel.sqf"
$zg = Read-Source "Missions_Vanilla\[61-2hc]warfarev2_073v48co.zargabad\Server\PVFunctions\RequestGDirPanel.sqf"

$denyAnchor = 'if (_verb == "counter") exitWith {'
$cooldownAnchor = '//--- Gate 4: anti-spam - per-town cooldown.'
$debitAnchor = '//--- Town fund covers price first, shortfall from personal wallet.'
$pendingAnchor = '//--- Emit GDIR_ORDER for the Director tick to consume.'

Write-Host "Checking no-op counter payment gate"
Assert-Match $ch 'if \(_verb == "counter"\) exitWith \{' "server has a top-level counter deny"
Assert-Match $ch 'deny=counterUnavailable' "server emits a no-charge counter-unavailable marker"
Assert-Match $ch 'GDirPanelResult", \["deny", "Counter-attack contracts are unavailable until a retake unit is available\.' "server uses the existing denial result channel"
Assert-Ordered $ch $denyAnchor $cooldownAnchor "counter deny occurs before cooldown state"
Assert-Ordered $ch $denyAnchor $debitAnchor "counter deny occurs before fund debit"
Assert-Ordered $ch $denyAnchor $pendingAnchor "counter deny occurs before pending-order and contract state"

Write-Host "Checking generated mirror parity"
Assert-EqualNormalized $ch $tk "Takistan mirrors Chernarus counter gate"
Assert-EqualNormalized $ch $zg "Zargabad mirrors Chernarus counter gate"

Write-Host ""
if ($script:fails -eq 0) {
	Write-Host "Test-GuerCounterContractGate: PASS" -ForegroundColor Green
	exit 0
}

Write-Host ("Test-GuerCounterContractGate: {0} failure(s)" -f $script:fails) -ForegroundColor Red
exit 1
