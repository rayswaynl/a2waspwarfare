param(
    [string]$SourcePath = (Join-Path $PSScriptRoot '..\..\..\Missions\[55-2hc]warfarev2_073v48co.chernarus\Client\GUI\GUI_BuyGearMenu.sqf')
)

$source = Get-Content -LiteralPath $SourcePath -Raw
$start = $source.IndexOf('if (_purchase) then {')
$end = $source.IndexOf('//--- Create a template', $start)

if ($start -lt 0 -or $end -lt $start) {
    throw 'Could not locate the buy-gear purchase block.'
}

$purchase = $source.Substring($start, $end - $start)
$required = @(
    'if (_has_veh_changed) then',
    '_vehicleCargo = vehicle _target',
    'if (isNull _vehicleCargo || {!alive _vehicleCargo} || {player distance _vehicleCargo > (missionNamespace getVariable "WFBE_C_PLAYERS_GEAR_VEHICLE_RANGE")}) then {_vehicleCommitAllowed = false};',
    'if (_vehicleCommitAllowed) then',
    '[vehicle _target, _gear_sel_vehicle] Call WFBE_CO_FNC_EquipVehicle'
)

foreach ($fragment in $required) {
    if (-not $purchase.Contains($fragment)) {
        throw "Missing vehicle cargo purchase range-gate fragment: $fragment"
    }
}

$guard = $purchase.IndexOf($required[2])
$allowed = $purchase.IndexOf($required[3])
$equip = $purchase.IndexOf($required[4])

if ($guard -lt 0 -or $allowed -lt 0 -or $equip -lt 0 -or $guard -ge $allowed -or $allowed -ge $equip) {
    throw 'Vehicle cargo guard must run before the allowed commit and Common_EquipVehicle.'
}

Write-Host 'PASS: vehicle cargo purchase is range-gated before Common_EquipVehicle.'
