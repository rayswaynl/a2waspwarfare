#requires -Version 5.1
<#
.SYNOPSIS
    Guards the failure-atomic GUER FOB construction-start and completion contract.

.DESCRIPTION
    A GUER delivery truck must not lose its matching FOB token or be consumed
    merely because the generic construction worker cannot acquire its
    LocationLogicStart or cannot create its final factory. This static contract
    reserves the FOB token until the worker publishes a one-shot construction-
    start result, then commits the delivery truck, active marker, and ledger
    only after a separate final-site receipt. It also keeps the client preview
    and server gate aligned with the configured factory footprint.
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

function Assert-NotMatch {
	param(
		[Parameter(Mandatory)] [string]$Text,
		[Parameter(Mandatory)] [string]$Pattern,
		[Parameter(Mandatory)] [string]$Label
	)

	if ($Text -notmatch $Pattern) {
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
	$secondIndex = $Text.IndexOf($Second, [System.StringComparison]::Ordinal)
	if ($firstIndex -ge 0 -and $secondIndex -ge 0 -and $firstIndex -lt $secondIndex) {
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

$request = Read-Source "Missions\\[55-2hc]warfarev2_073v48co.chernarus\\Server\\PVFunctions\\RequestFOBStructure.sqf"
$small = Read-Source "Missions\\[55-2hc]warfarev2_073v48co.chernarus\\Server\\Construction\\Construction_SmallSite.sqf"
$medium = Read-Source "Missions\\[55-2hc]warfarev2_073v48co.chernarus\\Server\\Construction\\Construction_MediumSite.sqf"
$constants = Read-Source "Missions\\[55-2hc]warfarev2_073v48co.chernarus\\Common\\Init\\Init_CommonConstants.sqf"
$action = Read-Source "Missions\\[55-2hc]warfarev2_073v48co.chernarus\\Client\\Action\\Action_BuildFOB.sqf"
$initUnit = Read-Source "Missions\\[55-2hc]warfarev2_073v48co.chernarus\\Common\\Init\\Init_Unit.sqf"

Write-Host "Checking failure-atomic server start"
Assert-Match $request '_startResultKey\s*=\s*Format \["wfbe_guer_fob_start_' "handler creates a per-request start-result key"
Assert-Match $request 'missionNamespace setVariable \[_startResultKey,\s*\[0,\s*""\]\]' "handler records a pending start result before debit"
Assert-Match $request 'reason=missing-start-logic' "handler logs an explicit start-logic rejection"
Assert-Match $request '\["guer-fob-result",\s*false,\s*"FOB build rejected: construction could not start' "handler tells the caller that the token was restored and truck preserved"
Assert-Match $request '_completionResultKey\s*=\s*Format \["wfbe_guer_fob_complete_' "handler creates a per-request completion-result key"
Assert-Match $request 'missionNamespace setVariable \[_completionResultKey,\s*\[0,\s*""\]\]' "handler records a pending completion result before construction"
Assert-Match $request '\[_classname,\s*resistance,\s*_pos,\s*_dir,\s*_index,\s*_startResultKey,\s*_completionResultKey\]\s+ExecVM' "handler passes start and completion keys to construction"
Assert-Match $request 'waitUntil\s*\{' "handler waits for a terminal construction-start result"
Assert-Match $request 'scriptDone _buildHandle' "handler treats a terminated worker as a failed start"
Assert-Match $request '_currentAvail\s*=\s*\+\s*\(missionNamespace getVariable \["WFBE_GUER_FOB_AVAIL"' "rollback re-reads the current token state"
Assert-Ordered $request 'missionNamespace setVariable [_startResultKey, [0, ""]]' '_avail set [_idx, (_avail select _idx) - 1]' "pending result is registered before token debit"
Assert-Match $request 'wfbe_guer_fob_pending' "handler marks the delivery truck pending while construction runs"
Assert-Match $request '_truck getVariable \["wfbe_guer_fob_pending",\s*false\]' "handler rejects a second request for a pending delivery truck"
Assert-Match $request 'typeOf _truck != \(_fobTrucks select _idx\)' "handler confirms that the truck matches the requested FOB type"
Assert-Match $request '_completionSite\s*=\s*_completionResult select 1' "completion watcher receives the registered factory from the worker receipt"
Assert-Match $request 'alive _completionSite' "completion watcher verifies that the completed factory still lives"
Assert-Match $request '_completionRegistered' "completion watcher verifies that the completed factory remains registered"
Assert-Ordered $request '_completionSite = _completionResult select 1' '"WildcardMarker"' "marker creation follows final factory liveness and registration verification"
Assert-Ordered $request 'if ((_completionResult select 0) == 1)' "deleteVehicle _truck" "truck consumption waits for a final construction receipt"
Assert-Ordered $request 'if ((_completionResult select 0) == 1)' '"WildcardMarker"' "active FOB marker waits for a final construction receipt"
Assert-Ordered $request 'if ((_completionResult select 0) == 1)' 'WFBE_GUER_FOB_ACTIVE' "active FOB ledger waits for a final construction receipt"
Assert-Match $request 'reason=construction-completion-failed' "handler leaves an explicit final-construction rollback marker"
Assert-Match $request 'wfbe_is_guer_fob",\s*true,\s*true' "final rollback restores a surviving delivery truck"
Assert-Match $initUnit "wfbe_is_guer_fob', false" "truck action and respawn availability stay gated on the committed FOB flag"

Write-Host "Checking direct construction-logic ownership"
foreach ($worker in @(@($small, "SmallSite"), @($medium, "MediumSite"))) {
	$source = $worker[0]
	$name = $worker[1]
	Assert-Match $source 'count _this\) > 5' ("{0} accepts an optional start-result key" -f $name)
	Assert-Match $source '_startResultKey\s*=' ("{0} reads the start-result key" -f $name)
	Assert-Match $source 'count _this\) > 6' ("{0} accepts an optional completion-result key" -f $name)
	Assert-Match $source '_completionResultKey\s*=' ("{0} reads the completion-result key" -f $name)
	Assert-Match $source '_nearLogic\s*=\s*_group\s+createUnit\s+\["LocationLogicStart"' ("{0} directly captures a newly created logic" -f $name)
	Assert-Match $source 'CONSTRUCTION\|v1\|reject\|reason=missing-start-logic' ("{0} leaves an RPT marker if logic creation fails" -f $name)
	Assert-Match $source 'missionNamespace setVariable \[_startResultKey,\s*\[-1,' ("{0} reports a start failure to the requester" -f $name)
	Assert-Match $source 'missionNamespace setVariable \[_startResultKey,\s*\[1,\s*""\]\]' ("{0} reports a successful construction start" -f $name)
	Assert-Match $source 'if \(isNull _site\) exitWith' ("{0} explicitly handles final factory creation failure" -f $name)
	Assert-Match $source 'CONSTRUCTION\|v1\|reject\|reason=final-site-create-failed' ("{0} leaves an RPT marker if final factory creation fails" -f $name)
	Assert-Match $source 'missionNamespace setVariable \[_completionResultKey,\s*\[-1,' ("{0} reports a final factory failure to the requester" -f $name)
	Assert-Match $source 'missionNamespace setVariable \[_completionResultKey,\s*\[1,\s*_site\]\]' ("{0} reports its final factory object to the requester" -f $name)
	Assert-Match $source 'if \(isNull _site\) exitWith \{[\s\S]*?deleteVehicle _nearLogic[\s\S]*?deleteGroup _group' ("{0} tears down the mode-1 construction logic when final creation fails" -f $name)
	Assert-Match $source '_constructionLogicLost\s*=\s*false' ("{0} tracks destruction of its in-progress construction logic" -f $name)
	Assert-Match $source 'CONSTRUCTION\|v1\|reject\|reason=construction-logic-destroyed' ("{0} emits a terminal result when a nuke removes its construction logic" -f $name)
	Assert-Ordered $source '_constructionLogicLost = true' 'reason=construction-logic-destroyed' ("{0} cleans up and reports only after detecting a destroyed construction logic" -f $name)
	Assert-Match $source 'waitUntil \{time >= _timeNextUpdate \|\| \{isNull _nearLogic\}\}' ("{0} stops timed construction as soon as its logic is destroyed" -f $name)
	Assert-NotMatch $source 'nearEntities\s+\[\["LocationLogicStart"\]' ("{0} does not re-discover the logic by proximity" -f $name)
	Assert-Ordered $source 'if (isNull _nearLogic) exitWith' '_construct = Compile PreprocessFile' ("{0} checks logic before spawning construction props" -f $name)
	Assert-Ordered $source '_site = createVehicle' 'if (isNull _site) exitWith' ("{0} checks the final factory before using it" -f $name)
	Assert-Ordered $source 'if (isNull _site) exitWith' '_site setDir _direction' ("{0} never uses a null final factory" -f $name)
}

Write-Host "Checking shared footprint gate"
Assert-Match $constants '_flatRadius\s*=' "shared gate derives a flat-ground radius"
Assert-Match $constants 'typeName \(_this select 0\)\) == "ARRAY"' "shared gate accepts an optional position/radius pair"
Assert-Match $constants '_pos isFlatEmpty \[_flatRadius' "shared gate applies the supplied radius"
Assert-Match $request 'STRUCTUREDISTANCES' "server derives the actual factory footprint"
Assert-Match $request '\[_pos,\s*_flatRadius\]\s+Call\s+WFBE_FNC_GuerFobBlocked' "server uses the configured footprint"
Assert-Match $action 'STRUCTUREDISTANCES' "client derives the actual factory footprint"
Assert-Match $action '\[_pos,\s*_flatRadius\]\s+Call\s+WFBE_FNC_GuerFobBlocked' "client uses the configured footprint"

Write-Host ""
if ($script:fails -eq 0) {
	Write-Host "Test-GuerFobConstructionAtomic: PASS" -ForegroundColor Green
	exit 0
}

Write-Host ("Test-GuerFobConstructionAtomic: {0} failure(s)" -f $script:fails) -ForegroundColor Red
exit 1
