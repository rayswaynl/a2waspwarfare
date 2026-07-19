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
if ($unitLoop -notmatch [regex]::Escape('_unitDotVisibleLast = _entry select 19')) {
    throw 'Unit-dot marker loop does not cache each marker visibility state.'
}
if ($unitLoop -notmatch [regex]::Escape('if ((count _entry) > 19) then {_unitDotVisibleLast = _entry select 19}')) {
    throw 'Unit-dot marker loop reads its optional visibility cache without a safe entry-length guard.'
}
if ($unitLoop -notmatch [regex]::Escape('if (_showUnitDots != _unitDotVisibleLast)')) {
    throw 'Unit-dot marker loop does not apply alpha only when local visibility changes.'
}
if ($unitLoop -notmatch [regex]::Escape('(_entry select 1) setMarkerAlphaLocal _showUnitDots')) {
    throw 'Unit-dot marker loop does not restore the marker alpha from the local visibility state.'
}
if ($unitLoop -notmatch '(?s)deleteMarkerLocal _markerName;\s*createMarkerLocal \[_markerName, _currentPos\];\s*_entry set \[19, -1\];') {
    throw 'Unit-dot marker loop does not invalidate cached visibility after rebuilding a marker.'
}
Write-Output 'Test-MapClarityToggleContract: PASS'
