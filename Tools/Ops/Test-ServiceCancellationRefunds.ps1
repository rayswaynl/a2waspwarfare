#requires -Version 5.1
<#
.SYNOPSIS
    Guards exact client-fund refunds when a paid service worker cannot complete.
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

function Assert-Count {
	param([string]$Text, [string]$Pattern, [int]$Expected, [string]$Label)
	$actual = ([regex]::Matches($Text, $Pattern)).Count
	if ($actual -eq $Expected) { Write-Host ("  PASS  {0}" -f $Label) }
	else { Write-Host ("  FAIL  {0} (expected {1}, got {2})" -f $Label, $Expected, $actual) -ForegroundColor Red; $script:fails++ }
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
		Menu = Read-Source (Join-Path $root "Client\GUI\GUI_Menu_Service.sqf")
		Repair = Read-Source (Join-Path $root "Client\Functions\Client_SupportRepair.sqf")
		Refuel = Read-Source (Join-Path $root "Client\Functions\Client_SupportRefuel.sqf")
		Rearm = Read-Source (Join-Path $root "Client\Functions\Client_SupportRearm.sqf")
		Heal = Read-Source (Join-Path $root "Client\Functions\Client_SupportHeal.sqf")
	}
}

$ch = $sources[0]
Write-Host "Checking service charge snapshots"
Assert-Match $ch.Menu 'if \(_action == "REFUEL" && \{_veh getVariable \["stopped", false\]\}\) exitWith \{0\};' "stopped refuel is excluded before a price is charged"
Assert-Match $ch.Menu '_batch = _batch \+ \[\[_veh,_supports,_priceOne\]\];' "batch records each unit's exact charged price"
Assert-Match $ch.Menu '_priceOne = _item select 2;' "batch dispatcher restores the per-unit price"
Assert-Match $ch.Menu '_prices = _prices \+ \[\[_x,_priceOne\]\];' "full service records each action's exact charged price"
Assert-Match $ch.Menu '\[_actions,_price,_prices\]' "full service returns its action-price ledger"
Assert-Match $ch.Menu '_prices = _this select 4;' "full-service dispatcher accepts the action-price ledger"
Assert-Match $ch.Menu '_priceOne = \[_action,_prices\] Call _martyServiceGetSnapshotPrice;' "full-service dispatcher resolves the snapshot price by action"
foreach ($service in @("Rearm","Repair","Refuel","Heal")) {
	$pattern = '\[_veh,_supports,_typeRepair,_spType,_priceOne\] Spawn Support' + $service + '\};'
	Assert-Count $ch.Menu $pattern 2 "$service receives its snapshot from both batch and full dispatch"
}
Assert-Match $ch.Menu '\[_veh,_nearSupport select _curSel,_typeRepair,_spType,_rearmPrice\] Spawn SupportRearm;' "single rearm passes its charged price"
Assert-Match $ch.Menu '\[_veh,_nearSupport select _curSel,_typeRepair,_spType,_repairPrice\] Spawn SupportRepair;' "single repair passes its charged price"
Assert-Match $ch.Menu '\[_veh,_nearSupport select _curSel,_typeRepair,_spType,_refuelPrice\] Spawn SupportRefuel;' "single refuel passes its charged price"
Assert-Match $ch.Menu '\[_veh,_nearSupport select _curSel,_typeRepair,_spType,_healPrice\] Spawn SupportHeal;' "single heal passes its charged price"

Write-Host "Checking terminal worker refunds"
foreach ($worker in @(
	[PSCustomObject]@{ Name = 'repair'; Text = $ch.Repair },
	[PSCustomObject]@{ Name = 'refuel'; Text = $ch.Refuel },
	[PSCustomObject]@{ Name = 'rearm'; Text = $ch.Rearm },
	[PSCustomObject]@{ Name = 'heal'; Text = $ch.Heal }
)) {
	Assert-Match $worker.Text 'Private \[.*''_price''.*\];' "$($worker.Name) worker declares a price snapshot"
	Assert-Match $worker.Text '_price = if \(\(count _this\) > 4\) then \{_this select 4\} else \{0\};' "$($worker.Name) treats the refund snapshot as an optional fifth argument"
	Assert-Count $worker.Text 'if \(_cts == 0 && \{_price > 0\}\) then \{_price Call ChangePlayerFunds;\};' 1 "$($worker.Name) refunds exactly once on a terminal cancellation"
}
Assert-Match $ch.Repair 'if \(_veh getVariable \["wfbe_repair_inProgress", false\]\) exitWith \{if \(_price > 0\) then \{_price Call ChangePlayerFunds;\};hint "Repair already in progress\."\};' "repair race refunds before its immediate exit"
Assert-Match $ch.Refuel 'if \(_get\) exitWith \{if \(_price > 0\) then \{_price Call ChangePlayerFunds;\};hint "Quit the stealth mode !";\};' "stopped refuel refunds if the state changes after charge"
Assert-Match $ch.Rearm 'if \(\(typeOf _veh\) iskindOf "Air" && _nearIsDP\) exitWith \{if \(_price > 0\) then \{_price Call ChangePlayerFunds;\};Hint "You can''t rearm air in town"\};' "rearm preflight refunds any already-paid race"

Write-Host "Checking generated mirror parity"
foreach ($source in $sources | Select-Object -Skip 1) {
	$label = if ($source.Root -like '*takistan*') { 'Takistan' } else { 'Zargabad' }
	Assert-EqualNormalized $ch.Menu $source.Menu "$label service menu mirrors Chernarus"
	Assert-EqualNormalized $ch.Repair $source.Repair "$label repair worker mirrors Chernarus"
	Assert-EqualNormalized $ch.Refuel $source.Refuel "$label refuel worker mirrors Chernarus"
	Assert-EqualNormalized $ch.Rearm $source.Rearm "$label rearm worker mirrors Chernarus"
	Assert-EqualNormalized $ch.Heal $source.Heal "$label heal worker mirrors Chernarus"
}

Write-Host ""
if ($script:fails -eq 0) {
	Write-Host "Test-ServiceCancellationRefunds: PASS" -ForegroundColor Green
	exit 0
}

Write-Host ("Test-ServiceCancellationRefunds: {0} failure(s)" -f $script:fails) -ForegroundColor Red
exit 1
