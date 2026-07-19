#requires -Version 5.1
<#
.SYNOPSIS
    Guards failure-atomic delivery of paid GDIR defensive vehicles.

.DESCRIPTION
    A GDIR vehicle order is a server-owned supplement: client/HC garrison
    delegation never consumes it. The server atomically claims a pending order,
    materializes one exact hull through Common_CreateTownUnits, and commits only
    when that result proves a living, driven vehicle. A negative result is
    cleaned up and restored to pending without a second debit.
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

function Assert-NotMatch {
	param([string]$Text, [string]$Pattern, [string]$Label)
	if ($Text -notmatch $Pattern) { Write-Host ("  PASS  {0}" -f $Label) }
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

$roots = @(
	"Missions\[55-2hc]warfarev2_073v48co.chernarus",
	"Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan",
	"Missions_Vanilla\[61-2hc]warfarev2_073v48co.zargabad"
)

$sources = @()
foreach ($root in $roots) {
	$sources += [PSCustomObject]@{
		Root = $root
		Town = Read-Source (Join-Path $root "Common\Functions\Common_CreateTownUnits.sqf")
		Panel = Read-Source (Join-Path $root "Server\PVFunctions\RequestGDirPanel.sqf")
		TownAI = Read-Source (Join-Path $root "Server\FSM\server_town_ai.sqf")
	}
}

$ch = $sources[0]
$preflightAnchor = "//--- GDIR vehicle preflight: validate before any debit."
$debitAnchor = "//--- Town fund covers price first, shortfall from personal wallet."
$directCallAnchor = "[_town, _side, [], [], [], [_gdirVehOrderId, _gdirVehTier, _gdirVehClass]] Call WFBE_CO_FNC_CreateTownUnits"
$directCallPattern = [regex]::Escape($directCallAnchor)
$recoveryAnchor = "//--- GDIR vehicle recovery: a prior server loop can only leave inflight after interruption."
$recoveryCleanupAnchor = "//--- Recovery cannot retry while a tagged paid asset still survives."
$deliveryMarkerAnchor = "//--- Persist this paid attempt only after its normal garrison setup is complete."

Write-Host "Checking no-charge vehicle order admission"
Assert-Match $ch.Panel 'AICOMV2_GDIR_VEHICLE_ORDER' "panel persists a server-owned vehicle order record"
Assert-Match $ch.Panel 'AICOMV2_GDIR_VEHICLE_ORDER_SEQ' "panel assigns a server-side order sequence"
Assert-Match $ch.Panel 'AICOMV2_GDIR_VEHICLE", 0\]\) > 0' "panel checks the vehicle gate"
Assert-Match $ch.Panel '_gdirVehNewTier < 1' "panel rejects malformed vehicle tiers"
Assert-Match $ch.Panel 'AICOMV2_GDIR_VEHICLE_TIER' "panel recognizes a legacy pending tier without charging again"
Assert-Match $ch.Panel 'A vehicle order .* already pending delivery' "panel denies duplicate pending orders"
Assert-Ordered $ch.Panel $preflightAnchor $debitAnchor "vehicle gate and pending-order checks run before debit"
Assert-Ordered $ch.Panel 'AICOMV2_GDIR_VEHICLE_ORDER", [_gdirVehOrderId, _gdirVehNewTier, "pending"]' 'product=%3|tier=%4|order=%5|price=%6' "panel records the order before accepting the purchase"
Assert-NotMatch $ch.Panel 'AICOMV2_GDIR_VEHICLE_TIER", _gdirVehNewTier, true' "new vehicle orders do not recreate the old public scalar contract"

Write-Host "Checking server-owned materialization receipt"
Assert-Match $ch.Town 'count _this\s*>\s*5' "town worker accepts an optional delivery descriptor"
Assert-Match $ch.Town '_gdirDeliveryResult\s*=\s*\[\]' "town worker initializes an optional delivery receipt"
Assert-Match $ch.Town '_gdirDeliveryIndex\s*=\s*count _groups' "town worker identifies its one appended vehicle template"
Assert-Match $ch.Town 'count _vehicles == 1' "receipt requires exactly one vehicle from the paid template"
Assert-Match $ch.Town 'alive _gdirDeliveryVehicle' "receipt requires a living delivery hull"
Assert-Match $ch.Town 'typeOf _gdirDeliveryVehicle\) == _gdirDeliveryClass' "receipt requires the exact ordered class"
Assert-Match $ch.Town '!isNull _gdirDeliveryDriver' "receipt requires a driver"
Assert-Match $ch.Town '_gdirDeliveryDriver in _crews' "receipt requires the driver from the paid template"
Assert-Match $ch.Town 'vehicle _gdirDeliveryDriver\) == _gdirDeliveryVehicle' "receipt confirms the driver occupies the ordered hull"
Assert-Match $ch.Town 'AICOMV2_GDIR_VEHICLE_ATTEMPT_HULL' "town worker persists the one attempted paid hull for interrupted-call recovery"
Assert-Match $ch.Town 'AICOMV2_GDIR_VEHICLE_ATTEMPT_TEAM' "town worker persists the one attempted paid team for interrupted-call recovery"
Assert-Match $ch.Town 'AICOMV2_GDIR_VEHICLE_ORDER_ID' "town worker stamps paid assets with their order identity"
Assert-Ordered $ch.Town '_team allowFleeing 0;' $deliveryMarkerAnchor "recovery markers wait for normal team initialization"
Assert-Ordered $ch.Town 'forEach _vehicles;' $deliveryMarkerAnchor "recovery markers wait for vehicle empty-handler and taxi setup"
Assert-Match $ch.Town 'deleteVehicle _x.*forEach \(_units \+ _crews \+ _vehicles\)' "failed partial delivery is cleaned up locally"
Assert-Match $ch.Town 'if \(!isNull _team\) then \{deleteGroup _team\}' "failed partial delivery group is removed"
Assert-Match $ch.Town '\[_town_teams, _town_vehicles, _gdirDeliveryResult\]' "legacy two-slot return remains intact with an appended receipt"
Assert-NotMatch $ch.Town 'AICOMV2_GDIR_VEHICLE_INFLIGHT' "common worker does not use a cross-HC public lease"

Write-Host "Checking server commit-or-retry ownership"
Assert-Match $ch.TownAI 'AICOMV2_GDIR_VEHICLE_ORDER' "server town loop reads the server-owned order"
Assert-Match $ch.TownAI 'AICOMV2_GDIR_VEHICLE_TIER' "server town loop migrates an old scalar order safely"
Assert-Ordered $ch.TownAI $recoveryAnchor 'for "_i" from 0 to ((count towns) - 1) step 1 do' "server recovers an interrupted claim before each town activation sweep"
Assert-Match $ch.TownAI 'if \(_gdirVehRecoveryState == "inflight"\) then' "server recognizes a stranded materialization claim"
Assert-Match $ch.TownAI 'AICOMV2_GDIR_VEHICLE_ORDER", \[_gdirVehRecoveryOrderId, _gdirVehRecoveryTier, "pending"\]' "server makes an unmaterialized stranded order retryable without a new debit"
Assert-Match $ch.TownAI '_gdirVehRecoveryHull getVariable \["AICOMV2_GDIR_VEHICLE_ORDER_ID", -1\]\) == _gdirVehRecoveryOrderId' "recovery recognizes only the exact paid hull for the interrupted order"
Assert-Match $ch.TownAI '_gdirVehRecoveryTeam getVariable "AICOMV2_GDIR_VEHICLE_ORDER_ID"' "recovery reads the paid-team identity with A2-safe group getVariable syntax"
Assert-NotMatch $ch.TownAI '_gdirVehRecoveryTeam getVariable \["AICOMV2_GDIR_VEHICLE_ORDER_ID", -1\]' "recovery avoids the A2-unsafe group default-value form"
Assert-Match $ch.TownAI '_gdirVehRecoverySideId == WFBE_C_GUER_ID \|\| \{_gdirVehRecoverySideId == WFBE_C_UNKNOWN_ID\}' "recovery commits only while the town is still GUER-or-unknown owned"
Assert-Match $ch.TownAI 'typeOf _gdirVehRecoveryHull\) == _gdirVehRecoveryClass' "recovery revalidates the ordered hull class before committing"
Assert-Match $ch.TownAI 'vehicle _gdirVehRecoveryDriver\) == _gdirVehRecoveryHull' "recovery revalidates that the recovered hull has its driver"
Assert-Match $ch.TownAI 'if !\(_gdirVehRecoveryTeam in _gdirVehRecoveryTeams\) then' "recovery appends the recovered team idempotently"
Assert-Match $ch.TownAI 'if !\(_gdirVehRecoveryHull in _gdirVehRecoveryVehicles\) then' "recovery appends the recovered hull idempotently"
Assert-Match $ch.TownAI 'GDIR_VEHICLE_RECOVERED_COMMIT' "recovery commits a tagged live hull instead of duplicating it"
Assert-Ordered $ch.TownAI $recoveryCleanupAnchor 'GDIR_VEHICLE_RECOVERED_RETRY' "recovery tears down an invalid tagged attempt before it can retry"
Assert-Match $ch.TownAI 'deleteVehicle _gdirVehRecoveryHull' "recovery deletes an invalid tagged hull before retrying"
Assert-Match $ch.TownAI 'deleteGroup _gdirVehRecoveryTeam' "recovery deletes an invalid tagged team before retrying"
Assert-Match $ch.TownAI 'GDIR_VEHICLE_RECOVERY_HELD' "recovery holds an unsafe-to-delete tagged asset instead of duplicating it"
Assert-Match $ch.TownAI 'GDIR_VEHICLE_RECOVERED_RETRY' "recovery retries only when no tagged live hull remains"
Assert-Match $ch.TownAI '[_gdirVehOrderId, _gdirVehTier, "inflight"]' "server marks the order inflight before materialization"
Assert-Match $ch.TownAI $directCallPattern "server invokes a separate, empty-input supplement instead of delegating it"
Assert-Ordered $ch.TownAI '[_gdirVehOrderId, _gdirVehTier, "inflight"]' $directCallAnchor "server claims before the supplement call can yield"
Assert-Match $ch.TownAI 'GDIR_VEHICLE_DELIVERED' "server logs the committed receipt"
Assert-Match $ch.TownAI 'GDIR_VEHICLE_RETRY' "server logs a retryable negative receipt"
Assert-Match $ch.TownAI 'AICOMV2_GDIR_VEHICLE_ORDER", \[\]' "server clears the record only on a delivered receipt"
Assert-Match $ch.TownAI 'AICOMV2_GDIR_VEHICLE_ORDER", \[_gdirVehOrderId, _gdirVehTier, "pending"\]' "server restores the same pending order after a negative receipt"

Write-Host "Checking generated mirror parity"
foreach ($source in $sources | Select-Object -Skip 1) {
	$label = if ($source.Root -like '*takistan*') { 'Takistan' } else { 'Zargabad' }
	Assert-EqualNormalized $ch.Town $source.Town "$label mirrors the town delivery receipt"
	Assert-EqualNormalized $ch.Panel $source.Panel "$label mirrors the order admission contract"
	Assert-EqualNormalized $ch.TownAI $source.TownAI "$label mirrors the server commit-or-retry owner"
}

Write-Host ""
if ($script:fails -eq 0) {
	Write-Host "Test-GdirVehicleDeliveryAtomic: PASS" -ForegroundColor Green
	exit 0
}

Write-Host ("Test-GdirVehicleDeliveryAtomic: {0} failure(s)" -f $script:fails) -ForegroundColor Red
exit 1
