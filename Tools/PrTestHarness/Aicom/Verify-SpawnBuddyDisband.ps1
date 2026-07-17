<#
.SYNOPSIS
    Static regression gate for the opt-in initial-spawn AI-squadmate removal.

.DESCRIPTION
    Checks the source contract that prevents the #1120 follow-up regressions:
    the flag is lobby-armable, the slot-order and removal paths share one
    delayed decision point, and removal deletes the unwanted local AI instead
    of creating an idle/leaked group.
#>

[CmdletBinding()]
param(
    [string]$MissionRoot = ""
)

$ErrorActionPreference = "Stop"
if ($MissionRoot -eq "") {
    $MissionRoot = Join-Path $PSScriptRoot "..\..\..\Missions\[55-2hc]warfarev2_073v48co.chernarus"
}

$client = Get-Content -Raw -LiteralPath (Join-Path $MissionRoot "Client\Init\Init_Client.sqf")
$params = Get-Content -Raw -LiteralPath (Join-Path $MissionRoot "Rsc\Parameters.hpp")
$removeStart = $client.IndexOf("if (_spawnBuddyDisband) then {")
$removeEnd = if ($removeStart -ge 0) { $client.IndexOf("} else {", $removeStart) } else { -1 }
$removePath = if ($removeEnd -gt $removeStart) { $client.Substring($removeStart, $removeEnd - $removeStart) } else { "" }

$checks = @(
    @{ Name = "lobby parameter exists"; Pass = $params -match '(?s)class\s+WFBE_C_SPAWN_BUDDY_DISBAND\s*\{.*?default\s*=\s*0\s*;' },
    @{ Name = "one delayed spawn-buddy decision point"; Pass = ([regex]::Matches($client, 'SPAWN-BUDDY-DISBAND')).Count -eq 1 },
    @{ Name = "slot ordering and removal are mutually exclusive"; Pass = $client -match '(?s)if\s*\(_spawnBuddyDisband\)\s*then\s*\{.*?deleteVehicle.*?\}\s*else\s*\{.*?_slot1Others\s+joinSilent' },
    @{ Name = "removal does not create a group"; Pass = $removePath -match 'deleteVehicle' -and $removePath -notmatch 'createGroup' }
)

$failed = @($checks | Where-Object { -not $_.Pass })
$checks | ForEach-Object {
    $status = if ($_.Pass) { "PASS" } else { "FAIL" }
    Write-Host ("[{0}] {1}" -f $status, $_.Name)
}

if ($failed.Count -gt 0) { exit 1 }
Write-Host "Spawn-buddy regression contract verified."
