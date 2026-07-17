<#
.SYNOPSIS
    Regression contract for commander-team marker-feed cleanup.

.DESCRIPTION
    A commander-team feed entry is [leader, sideID, dir, team].  The leader
    slot is a cache which can become null after a leader handoff on an
    HC-owned team; the group in slot 3 is the durable identity.  When one
    team ends, cleanup must remove only that team and must not drop another
    live team's entry just because its former leader is gone.
#>

$ErrorActionPreference = "Stop"

$source = Join-Path $PSScriptRoot "..\..\..\Missions\[55-2hc]warfarev2_073v48co.chernarus\Server\Functions\Server_HandleSpecial.sqf"
if (!(Test-Path -LiteralPath $source)) { throw "Server handler not found: $source" }

$text = Get-Content -Raw -LiteralPath $source
$match = [regex]::Match($text, '(?s)case "aicom-team-ended": \{(.*?)(?=\n\s*//--- Patch a commander team''s arrow heading)')
if (!$match.Success) { throw "Could not isolate aicom-team-ended cleanup block." }

$ended = $match.Groups[1].Value
$expected = 'if \(!isNull \(_x select 3\) && \{\(_x select 3\) != _cteam\}\) then \{_caicomNew = _caicomNew \+ \[_x\]\};'
if ($ended -notmatch $expected) {
    throw "FAIL: aicom-team-ended must keep other entries by live team (slot 3), not cached leader (slot 0)."
}
if ($ended -match 'if \(!isNull \(_x select 0\)') {
    throw "FAIL: aicom-team-ended still uses cached leader slot 0 as the feed liveness gate."
}

Write-Host "Test-CommanderTeamMarkerFeed: PASS"
