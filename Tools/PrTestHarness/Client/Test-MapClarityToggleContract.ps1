$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot '..\..\..\Missions\[55-2hc]warfarev2_073v48co.chernarus'
$profile = Get-Content -LiteralPath (Join-Path $root 'Client\Init\Init_ProfileVariables.sqf') -Raw
$settings = Get-Content -LiteralPath (Join-Path $root 'WASP\actions\Settings\Settings_Open.sqf') -Raw
$dialog = Get-Content -LiteralPath (Join-Path $root 'Rsc\Dialogs.hpp') -Raw
$unitLoop = Get-Content -LiteralPath (Join-Path $root 'Common\Common_MarkerLoop.sqf') -Raw
$teamLoop = Get-Content -LiteralPath (Join-Path $root 'Client\FSM\updateteamsmarkers.sqf') -Raw
$aicomLoop = Get-Content -LiteralPath (Join-Path $root 'Client\FSM\updateaicommarkers.sqf') -Raw
$rings = Get-Content -LiteralPath (Join-Path $root 'Client\Functions\Client_ArtyRangeRings.sqf') -Raw

foreach ($key in 'WFBE_SHOW_UNIT_DOTS', 'WFBE_SHOW_TEAM_ARROWS', 'WFBE_SHOW_RANGE_RINGS') {
    if ($profile -notmatch [regex]::Escape($key)) { throw "Missing persisted default-on profile key: $key" }
    if ($settings -notmatch [regex]::Escape($key)) { throw "Missing Settings persistence for: $key" }
}
foreach ($label in 'Unit Dots: ON', 'Team Arrows: ON', 'Range Rings: ON') {
    if ($dialog -notmatch [regex]::Escape($label)) { throw "Missing Settings control: $label" }
}
foreach ($contract in @(
    @{Text=$unitLoop; Gate='WFBE_CL_ShowUnitDots'; Name='unit-dot marker loop'},
    @{Text=$teamLoop; Gate='WFBE_CL_ShowTeamArrows'; Name='team-arrow marker loop'},
    @{Text=$aicomLoop; Gate='WFBE_CL_ShowTeamArrows'; Name='AICOM-arrow marker loop'},
    @{Text=$rings; Gate='WFBE_CL_ShowRangeRings'; Name='artillery-range marker loop'}
)) {
    if ($contract.Text -notmatch $contract.Gate) { throw "Missing local visibility gate in $($contract.Name): $($contract.Gate)" }
}
Write-Output 'Test-MapClarityToggleContract: PASS'
