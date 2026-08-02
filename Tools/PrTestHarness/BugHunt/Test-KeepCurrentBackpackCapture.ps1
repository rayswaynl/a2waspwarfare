<#
.SYNOPSIS
    Regression contract for respawn-menu "Keep Current" backpack cargo capture.

.DESCRIPTION
    The game runtime is unavailable in CI, so this checks the source-level handoff
    that the respawn handler actually consumes: the captured custom-gear tuple must
    preserve both weapon and magazine cargo from the current backpack.  The matching
    Common_EquipBackpack routine restores those two slots on respawn.
#>
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
)

$ErrorActionPreference = 'Stop'
$mission = Join-Path $RepoRoot 'Missions\[55-2hc]warfarev2_073v48co.chernarus'
$respawnMenu = Join-Path $mission 'Client\GUI\GUI_RespawnMenu.sqf'
$equipBackpack = Join-Path $mission 'Common\Functions\Common_EquipBackpack.sqf'

$respawnText = [System.IO.File]::ReadAllText($respawnMenu)
$captureStart = $respawnText.IndexOf('if (!WFBE_RespawnDefaultGear && {isNil {player getVariable "wfbe_custom_gear"}}) then {')
if ($captureStart -lt 0) { throw 'Keep Current capture block was not found.' }
$captureEnd = $respawnText.IndexOf('player setVariable ["wfbe_custom_gear_cost", 0];', $captureStart)
if ($captureEnd -lt 0) { throw 'Keep Current capture block has no custom-gear cost assignment.' }
$capture = $respawnText.Substring($captureStart, $captureEnd - $captureStart)

if ($capture -notmatch '_capBpContent\s*=\s*if\s*\(!isNull _capBpObj\)\s*then\s*\{\s*\[\s*getWeaponCargo\s+_capBpObj\s*,\s*getMagazineCargo\s+_capBpObj\s*\]\s*\}') {
    throw 'Keep Current does not capture both weapon and magazine backpack cargo.'
}
if ($capture -notmatch 'player\s+setVariable\s+\["wfbe_custom_gear",\s*\[\(weapons player\) - \[_capBp\],\s*magazines player,\s*_capBp,\s*_capBpContent,') {
    throw 'Keep Current does not persist captured backpack cargo in wfbe_custom_gear.'
}

$restoreText = [System.IO.File]::ReadAllText($equipBackpack)
if ($restoreText -notmatch '\(_backpack_content select 0\) select 0' -or $restoreText -notmatch '\(_backpack_content select 1\) select 0') {
    throw 'Common_EquipBackpack no longer restores the expected two-slot cargo tuple.'
}

Write-Host 'PASS: Keep Current captures backpack weapon and magazine cargo for respawn restore.' -ForegroundColor Green
