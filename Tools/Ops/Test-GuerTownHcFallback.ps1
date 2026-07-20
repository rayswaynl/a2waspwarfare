#requires -Version 5.1
<#
.SYNOPSIS
    Regression contract for town-garrison fallback when a registered HC is no longer routable.

.DESCRIPTION
    A dead/locality-transferred HC leader can still be non-null and alive while owner leader is
    zero.  The town FSM must use the same owner-aware liveness contract as the delegation helper:
    otherwise it suppresses its existing server CreateTownUnits fallback and the helper drops the
    dispatch.  The checked defaults make this a normal GUER town-garrison path, not an opt-in edge
    case.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$script:fails = 0

function Assert-Match {
	param(
		[Parameter(Mandatory)] [string]$Text,
		[Parameter(Mandatory)] [string]$Pattern,
		[Parameter(Mandatory)] [string]$Label
	)

	if ($Text -match $Pattern) {
		Write-Host ("  PASS  {0}" -f $Label)
	} else {
		Write-Host ("  FAIL  {0}" -f $Label) -ForegroundColor Red
		$script:fails++
	}
}

function Assert-Ordered {
	param(
		[Parameter(Mandatory)] [string]$Text,
		[Parameter(Mandatory)] [string]$First,
		[Parameter(Mandatory)] [string]$Second,
		[Parameter(Mandatory)] [string]$Label
	)

	$firstIndex = $Text.IndexOf($First, [System.StringComparison]::Ordinal)
	$secondIndex = if ($firstIndex -ge 0) {
		$Text.IndexOf($Second, $firstIndex + $First.Length, [System.StringComparison]::Ordinal)
	} else {
		-1
	}

	if ($firstIndex -ge 0 -and $secondIndex -gt $firstIndex) {
		Write-Host ("  PASS  {0}" -f $Label)
	} else {
		Write-Host ("  FAIL  {0}" -f $Label) -ForegroundColor Red
		$script:fails++
	}
}

function Read-Source {
	param([Parameter(Mandatory)] [string]$RelativePath)
	$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
	$path = Join-Path $repoRoot $RelativePath
	if (!(Test-Path -LiteralPath $path)) {
		throw "Source not found: $path"
	}
	return Get-Content -LiteralPath $path -Raw
}

function Get-Block {
	param(
		[Parameter(Mandatory)] [string]$Text,
		[Parameter(Mandatory)] [string]$StartToken,
		[Parameter(Mandatory)] [string]$EndToken,
		[Parameter(Mandatory)] [string]$Label
	)

	$start = $Text.IndexOf($StartToken, [System.StringComparison]::Ordinal)
	$end = if ($start -ge 0) {
		$Text.IndexOf($EndToken, $start, [System.StringComparison]::Ordinal)
	} else {
		-1
	}
	if ($start -lt 0 -or $end -le $start) {
		throw "Could not isolate $Label"
	}
	return $Text.Substring($start, $end - $start)
}

$townAi = Read-Source "Missions\[55-2hc]warfarev2_073v48co.chernarus\Server\FSM\server_town_ai.sqf"
$delegateHeadless = Read-Source "Missions\[55-2hc]warfarev2_073v48co.chernarus\Server\Functions\Server_DelegateAITownHeadless.sqf"
$parameters = Read-Source "Missions\[55-2hc]warfarev2_073v48co.chernarus\Rsc\Parameters.hpp"
$commonInit = Read-Source "Missions\[55-2hc]warfarev2_073v48co.chernarus\Common\Init\Init_Common.sqf"

$headlessCase = Get-Block $townAi "case 2: { //--- Headless Client delegation." "//--- Use Server AI." "the headless delegation case"

Write-Host "Checking default-path coverage"
Assert-Match $parameters '(?s)class\s+WFBE_C_AI_DELEGATION\s*\{.*?default\s*=\s*2\s*;.*?\};' "Lobby defaults AI delegation to headless clients"
Assert-Match $parameters '(?s)class\s+WFBE_C_TOWNS_DEFENDER\s*\{.*?default\s*=\s*2\s*;.*?\};' "Lobby defaults town defenders to medium"
Assert-Match $commonInit 'WFBE_DEFENDER\s*=\s*resistance\s*;' "Default defender side is resistance"

Write-Host "Checking a shared routable-HC contract"
$ownerAwareLiveness = '(?s)!isNull\s+_x\s*&&\s*\{\s*!isNull\s+leader\s+_x\s*\}\s*&&\s*\{\s*alive\s+leader\s+_x\s*\}\s*&&\s*\{\s*\(owner\s+\(leader\s+_x\)\)\s*>\s*0\s*\}'
Assert-Match $delegateHeadless $ownerAwareLiveness "Delegation helper rejects zero-owner HC leaders"
Assert-Match $headlessCase ('(?s)_liveHCs\s*=\s*\{\s*' + $ownerAwareLiveness + '\s*\}\s*count') "Town FSM preflight rejects zero-owner HC leaders"

Write-Host "Checking that a rejected HC preserves the existing server fallback"
Assert-Match $headlessCase 'if\s*\(\s*_liveHCs\s*>\s*0\s*\)\s*then' "Delegation remains conditional on a routable HC"
Assert-Ordered $headlessCase "if (_liveHCs > 0) then {" "_use_server = false;" "Only a passing HC preflight disables server creation"
Assert-Match $townAi '(?s)if\s*\(\s*_use_server\s*\)\s*then\s*\{\s*_retVal\s*=\s*\[_town,\s*_side,\s*_groups,\s*_positions,\s*_teams\]\s*Call\s*WFBE_CO_FNC_CreateTownUnits' "Server CreateTownUnits fallback remains present"

Write-Host ""
if ($script:fails -eq 0) {
	Write-Host "Test-GuerTownHcFallback: PASS" -ForegroundColor Green
	exit 0
}

Write-Host ("Test-GuerTownHcFallback: {0} failure(s)" -f $script:fails) -ForegroundColor Red
exit 1
