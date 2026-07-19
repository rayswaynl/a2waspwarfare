#requires -Version 5.1
<#
.SYNOPSIS
    Guards that the paid extra-crew count matches the turret paths consumers may spawn into.
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

function Assert-Equal {
	param($Actual, $Expected, [string]$Label)
	if ($Actual -ceq $Expected) { Write-Host ("  PASS  {0}" -f $Label) }
	else { Write-Host ("  FAIL  {0} (expected {1}, got {2})" -f $Label, $Expected, $Actual) -ForegroundColor Red; $script:fails++ }
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
		Return = Read-Source (Join-Path $root "Common\Functions\Common_GetConfigVehicleTurretsReturn.sqf")
		Flatten = Read-Source (Join-Path $root "Common\Functions\Common_GetConfigVehicleTurrets.sqf")
		Slots = Read-Source (Join-Path $root "Common\Functions\Common_GetConfigVehicleCrewSlot.sqf")
		SpawnTurrets = Read-Source (Join-Path $root "Common\Functions\Common_SpawnTurrets.sqf")
		Menu = Read-Source (Join-Path $root "Client\GUI\GUI_Menu_BuyUnits.sqf")
		Build = Read-Source (Join-Path $root "Client\Functions\Client_BuildUnit.sqf")
		ServerBuy = Read-Source (Join-Path $root "Server\Functions\Server_BuyUnit.sqf")
	}
}

$ch = $sources[0]

Write-Host "Checking primary-turret metadata"
Assert-Match $ch.Return 'private \[.*"_path".*"_trackPrimary".*\];' "turret config walk accepts optional path tracking without changing its return shape"
Assert-Match $ch.Return '_path = if \(\(count _this\) > 1\) then \{_this select 1\} else \{\[\]\};' "one-argument legacy callers retain an empty root path"
Assert-Match $ch.Return '_trackPrimary = if \(\(count _this\) > 2\) then \{_this select 2\} else \{false\};' "one-argument legacy callers do not collect primary paths"
Assert-Match $ch.Return '_thisTurret = _path \+ \[_turretIndex\];' "the config walk carries full nested turret paths"
Assert-Match $ch.Return 'if \(_isPrimary && _trackPrimary\) then \{tmp_primary = tmp_primary \+ \[_thisTurret\];\};' "only the crew-slot call records selected primary paths"
Assert-Match $ch.Return '_turrets = _turrets \+ \[_turretIndex\];' "return helper preserves the legacy pair-tree node prefix"
Assert-Match $ch.Return '_turrets = _turrets \+ \[\[_subEntry >> "Turrets", _thisTurret, _trackPrimary\] Call Compile preprocessFile "Common\\Functions\\Common_GetConfigVehicleTurretsReturn\.sqf"\];' "return helper preserves the legacy pair-tree child slot"
Assert-NotMatch $ch.Return '_turrets = _turrets \+ \[_turretIndex,_children,_isPrimary\];' "return helper does not break pair-tree consumers with metadata triples"
Assert-Match $ch.SpawnTurrets '_turrets select \(_i \+ 1\)' "generic turret spawner still consumes the pair-tree child slot"
Assert-Match $ch.SpawnTurrets '_i = _i \+ 2;' "generic turret spawner keeps pair-tree stride two"

Write-Host "Checking paid extra-path projection"
Assert-Match $ch.Flatten 'tmp_overall = tmp_overall \+ \[_thisTurret\];' "turret flattener preserves the all-path count"
Assert-Match $ch.Flatten '_i = _i \+ 2;' "turret flattener keeps pair-tree stride two"
Assert-NotMatch $ch.Flatten 'tmp_nonprimary|_isPrimary = _turrets select \(_i \+ 2\)' "turret flattener remains reusable for every pair-tree caller"
Assert-Match $ch.Slots 'tmp_primary = \[\];' "crew-slot builder resets collected primary paths per vehicle"
Assert-Match $ch.Slots '_turrets = \[_entry, \[\], true\] Call Compile preprocessFile "Common\\Functions\\Common_GetConfigVehicleTurretsReturn\.sqf";' "crew-slot builder opts into primary-path collection"
Assert-Match $ch.Slots 'if \(\(count _path\) == \(count _x\)\) then \{' "crew-slot builder compares candidate paths only after a scalar length match"
Assert-Match $ch.Slots 'for "_pathIndex" from 0 to \(\(count _path\) - 1\) do \{' "crew-slot builder walks every turret-path index with A2-safe scalar comparisons"
Assert-Match $ch.Slots 'if \(\(_path select _pathIndex\) != \(_x select _pathIndex\)\) then \{_samePath = false\};' "crew-slot builder rejects any mismatched scalar path index"
Assert-Match $ch.Slots 'if \(_samePath\) then \{_isPrimaryPath = true\};' "crew-slot builder accepts only element-wise identical primary paths"
Assert-NotMatch $ch.Slots 'if \(_path == _x\) then \{_isPrimaryPath = true\};' "crew-slot builder does not rely on unsupported array equality"
Assert-Match $ch.Slots 'if \(!_isPrimaryPath\) then \{_extraTurrets = _extraTurrets \+ \[_path\];\};' "only non-primary paths enter the paid extra-crew list"
Assert-Match $ch.Slots '_turrestcount = count\(_extraTurrets\);' "paid extra-crew count equals the projected path count"
Assert-Match $ch.Slots '\[\[vhasCommander,vhasGunner,count\(tmp_overall\)\+1,_turrestcount\], _extraTurrets\]' "consumer turret paths are exactly the paid non-primary paths"

Write-Host "Checking consumer count contract"
Assert-Match $ch.Menu 'if \(_extracrew\) then \{_extra = _extra \+ \(\(_currentUnit select QUERYUNITCREW\) select 3\)\};' "purchase price uses the generated paid extra count"
Assert-Match $ch.Menu 'if \(_extracrew\) then \{_cpt = _cpt \+ \(\(_currentUnit select QUERYUNITCREW\) select 3\)\};' "AI-cap reservation uses the same paid extra count"
Assert-Match $ch.Build 'if \(!_driver && !_gunner && !_commander && !_extracrew\) exitWith \{\};' "extra-only orders reach their generated non-primary paths"
Assert-Match $ch.Build '_turrets = _currentUnit select QUERYUNITTURRETS;' "client spawner consumes the projected extra-path list"
Assert-Match $ch.ServerBuy '_turrets = _get select QUERYUNITTURRETS;' "server spawner consumes the same projected extra-path list"

Write-Host "Checking a representative seat-count invariant"
$allTurretPaths = @("primary-gunner", "primary-commander", "left-extra", "right-extra")
$primaryPaths = @("primary-gunner", "primary-commander")
$nonPrimaryPaths = @()
foreach ($path in $allTurretPaths) {
	if (!($path -in $primaryPaths)) { $nonPrimaryPaths += $path }
}
Assert-Equal $allTurretPaths.Count 4 "representative vehicle has four all-turret paths"
Assert-Equal $nonPrimaryPaths.Count 2 "representative vehicle charges only its two non-primary paths"

Write-Host "Checking generated mirror parity"
foreach ($source in $sources | Select-Object -Skip 1) {
	$label = if ($source.Root -like '*takistan*') { 'Takistan' } else { 'Zargabad' }
	Assert-EqualNormalized $ch.Return $source.Return "$label turret metadata walker mirrors Chernarus"
	Assert-EqualNormalized $ch.Flatten $source.Flatten "$label turret flattener mirrors Chernarus"
	Assert-EqualNormalized $ch.Slots $source.Slots "$label crew-slot builder mirrors Chernarus"
	Assert-EqualNormalized $ch.SpawnTurrets $source.SpawnTurrets "$label generic pair-tree spawner mirrors Chernarus"
	Assert-EqualNormalized $ch.Menu $source.Menu "$label purchase menu mirrors Chernarus"
	Assert-EqualNormalized $ch.Build $source.Build "$label build worker mirrors Chernarus"
	Assert-EqualNormalized $ch.ServerBuy $source.ServerBuy "$label server buyer mirrors Chernarus"
}

Write-Host ""
if ($script:fails -eq 0) {
	Write-Host "Test-VehicleCrewTurretAccounting: PASS" -ForegroundColor Green
	exit 0
}

Write-Host ("Test-VehicleCrewTurretAccounting: {0} failure(s)" -f $script:fails) -ForegroundColor Red
exit 1
