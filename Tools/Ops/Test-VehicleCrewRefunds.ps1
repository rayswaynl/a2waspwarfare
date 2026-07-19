#requires -Version 5.1
<#
.SYNOPSIS
    Guards paid vehicle-crew delivery when individual AI creation fails.
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

function Get-Section {
	param([string]$Text, [string]$StartMarker, [string]$EndMarker, [string]$Label)
	$start = $Text.IndexOf($StartMarker, [System.StringComparison]::Ordinal)
	$end = if ($start -lt 0) { -1 } else { $Text.IndexOf($EndMarker, $start + $StartMarker.Length, [System.StringComparison]::Ordinal) }
	if ($start -lt 0 -or $end -lt 0 -or $end -le $start) { throw "Section markers missing for $Label" }
	$Text.Substring($start, $end - $start)
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
		Menu = Read-Source (Join-Path $root "Client\GUI\GUI_Menu_BuyUnits.sqf")
		Build = Read-Source (Join-Path $root "Client\Functions\Client_BuildUnit.sqf")
		Icbm = Read-Source (Join-Path $root "Common\Functions\Common_RequestIcbmTelPurchase.sqf")
	}
}

$ch = $sources[0]
$driverBlock = Get-Section $ch.Build "//--- Driver." "//--- Gunner." "driver"
$gunnerBlock = Get-Section $ch.Build "//--- Gunner." "//--- Commander." "gunner"
$commanderBlock = Get-Section $ch.Build "//--- Commander." "//--- Extra vehicle turrets." "commander"
$turretBlock = Get-Section $ch.Build "//--- Extra vehicle turrets." "[sideJoinedText,'UnitsCreated'" "turret"

Write-Host "Checking paid crew receipt propagation"
Assert-Match $ch.Menu '\[profilenamespace getvariable "wfbe_c_driver_enabled_by_default"\s*,_gunner,_commander,_extracrew,_isLocked,_crewCostPerHead\]' "vehicle descriptor carries the charged per-seat price"
Assert-Match $ch.Menu '_params = if \(_isInfantry\) then \{\[_closest,_unit,\[\],_type,_cpt,_clientPaidCost\]\} else \{\[_closest,_unit,\[.*?\],_type,_cpt,_clientPaidCost\]\};' "outer purchase contract remains six fields"
Assert-Match $ch.Icbm '\{count _params != 6\}' "SCUD authorization still requires the six-field outer contract"
Assert-Match $ch.Build 'Private \[.*"_crewCostPerHead".*"_crewCreated".*\];' "build worker declares crew receipt and actual-created counter"
Assert-Match $ch.Build '_crewCostPerHead = if \(\(count _vehi\) > 5\) then \{_vehi select 5\} else \{0\};' "legacy five-field vehicle descriptors remain safe"
Assert-Match $ch.Build 'if \(!_driver && !_gunner && !_commander && !_extracrew\) exitWith \{\};' "extra-turret-only orders do not take the crewless exit"

Write-Host "Checking per-seat failed delivery refunds"
$seatBlocks = @(
	[PSCustomObject]@{ Name = "driver"; Block = $driverBlock; Move = "moveInDriver _vehicle" },
	[PSCustomObject]@{ Name = "gunner"; Block = $gunnerBlock; Move = "moveInGunner _vehicle" },
	[PSCustomObject]@{ Name = "commander"; Block = $commanderBlock; Move = "moveInCommander _vehicle" },
	[PSCustomObject]@{ Name = "turret"; Block = $turretBlock; Move = "moveInTurret [_vehicle, _x]" }
)
foreach ($seat in $seatBlocks) {
	Assert-Match $seat.Block 'if \(isNull _soldier\) then \{\s*if \(_crewCostPerHead > 0\) then \{_crewCostPerHead Call ChangePlayerFunds;?\};' "$($seat.Name) refunds the exact seat receipt when unit creation fails"
	Assert-Ordered $seat.Block "if (isNull _soldier) then {" $seat.Move "$($seat.Name) only enters the seat after the null guard"
	Assert-Ordered $seat.Block "if (isNull _soldier) then {" "_spawnedUnits = _spawnedUnits + [_soldier];" "$($seat.Name) only reaches waypoint handoff after the null guard"
}
Assert-Count $ch.Build 'if \(isNull _soldier\) then \{' 4 "exactly the four paid crew creation paths refund individually"
Assert-Count $ch.Build '_crewCreated = _crewCreated \+ 1;' 4 "only successful crew seats increment actual delivery"
Assert-Match $ch.Build '\[sideJoinedText,''UnitsCreated'',_crewCreated\] Call UpdateStatistics;' "statistics record actual delivered crew rather than requested seats"

Write-Host "Checking generated mirror parity"
foreach ($source in $sources | Select-Object -Skip 1) {
	$label = if ($source.Root -like '*takistan*') { 'Takistan' } else { 'Zargabad' }
	Assert-EqualNormalized $ch.Menu $source.Menu "$label buy menu mirrors Chernarus"
	Assert-EqualNormalized $ch.Build $source.Build "$label build worker mirrors Chernarus"
	Assert-EqualNormalized $ch.Icbm $source.Icbm "$label SCUD authorization remains mirrored"
}

Write-Host ""
if ($script:fails -eq 0) {
	Write-Host "Test-VehicleCrewRefunds: PASS" -ForegroundColor Green
	exit 0
}

Write-Host ("Test-VehicleCrewRefunds: {0} failure(s)" -f $script:fails) -ForegroundColor Red
exit 1
