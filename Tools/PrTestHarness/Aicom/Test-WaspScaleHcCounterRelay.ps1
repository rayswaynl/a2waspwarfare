[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$missionRoot = Join-Path $repoRoot 'Missions\[55-2hc]warfarev2_073v48co.chernarus'
$relay = '["RequestSpecial", ["waspscale-counter-delta", "wfbe_waspscale_recov"]] Call WFBE_CO_FNC_SendToServer'
$recovEmitters = @{
    'Common\Functions\Common_AICOM_AutoFlip.sqf' = 1
    'Common\Functions\Common_RunUnstuckRecovery.sqf' = 1
    'Common\Functions\Common_RunCommanderTeam.sqf' = 3
}

foreach ($relativePath in $recovEmitters.Keys) {
    $content = Get-Content -Raw -LiteralPath (Join-Path $missionRoot $relativePath)
    $relayCount = [regex]::Matches($content, [regex]::Escape($relay)).Count
    if ($relayCount -ne $recovEmitters[$relativePath]) {
        throw "Expected $($recovEmitters[$relativePath]) HC-to-server recov relays in $relativePath; found $relayCount"
    }
}

$mhqReloc = Get-Content -Raw -LiteralPath (Join-Path $missionRoot 'Server\AI\Commander\AI_Commander_MHQReloc.sqf')
$mhqRelay = '["RequestSpecial", ["waspscale-counter-delta", "wfbe_waspscale_mhqrel"]] Call WFBE_CO_FNC_SendToServer'
if ($mhqReloc -notmatch [regex]::Escape($mhqRelay)) {
    throw 'Missing HC-to-server mhqrel relay in AI_Commander_MHQReloc.sqf'
}

$handleSpecial = Get-Content -Raw -LiteralPath (Join-Path $missionRoot 'Server\Functions\Server_HandleSpecial.sqf')
if ($handleSpecial -notmatch 'case "waspscale-counter-delta"') {
    throw 'Missing waspscale-counter-delta server landing case'
}
if ($handleSpecial -notmatch 'wfbe_waspscale_recov') {
    throw 'Server landing case does not allow wfbe_waspscale_recov'
}
if ($handleSpecial -notmatch 'wfbe_waspscale_mhqrel') {
    throw 'Server landing case does not allow wfbe_waspscale_mhqrel'
}

$publicVariables = Get-Content -Raw -LiteralPath (Join-Path $missionRoot 'Common\Init\Init_PublicVariables.sqf')
if ($publicVariables -notmatch 'RequestSpecial') {
    throw 'RequestSpecial is absent from the server PVF registration/allowlist'
}

Write-Output 'PASS: WASPSCALE HC counter relay static contract holds.'
