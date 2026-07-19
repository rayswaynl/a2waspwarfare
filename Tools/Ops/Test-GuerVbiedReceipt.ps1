#requires -Version 5.1
<#
.SYNOPSIS
    Guards the GUER VBIED detonation acceptance receipt.

.DESCRIPTION
    The client must not permanently consume its local one-shot latch until the
    server accepts the detonation. A denied, stale, or lost request clears only
    the matching pending receipt so the driver can retry. The server owns a
    separate one-shot receipt to suppress duplicate PV traffic.
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

function Read-Source {
	param([string]$RelativePath)
	$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
	$path = Join-Path $repoRoot $RelativePath
	if (!(Test-Path -LiteralPath $path)) { throw "Source not found: $path" }
	Get-Content -LiteralPath $path -Raw
}

function Assert-Mirror {
	param([string]$RelativePath, [string]$Label)
	$source = Read-Source $RelativePath
	$sourcePrefix = 'Missions\[55-2hc]warfarev2_073v48co.chernarus'
	$tkPrefix = 'Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan'
	$zgPrefix = 'Missions_Vanilla\[61-2hc]warfarev2_073v48co.zargabad'
	$tk = Read-Source ($RelativePath.Replace($sourcePrefix, $tkPrefix))
	$zg = Read-Source ($RelativePath.Replace($sourcePrefix, $zgPrefix))
	if ($source -ceq $tk -and $source -ceq $zg) { Write-Host ("  PASS  {0}" -f $Label) }
	else { Write-Host ("  FAIL  {0}" -f $Label) -ForegroundColor Red; $script:fails++ }
}

$actionPath = "Missions\[55-2hc]warfarev2_073v48co.chernarus\Client\Action\Action_GuerVbiedDetonate.sqf"
$clientPath = "Missions\[55-2hc]warfarev2_073v48co.chernarus\Client\PVFunctions\HandleSpecial.sqf"
$handlerPath = "Missions\[55-2hc]warfarev2_073v48co.chernarus\Server\Functions\Server_HandleSpecial.sqf"
$action = Read-Source $actionPath
$client = Read-Source $clientPath
$handler = Read-Source $handlerPath

Write-Host "Checking client pending receipt"
Assert-Match $action 'wfbe_vbied_pending_token' "action records a client-local pending receipt"
Assert-Match $action '\["RequestSpecial",\s*\["guer-vbied-detonate",\s*_veh,\s*_player,\s*_requestToken\]\]' "request carries the matching receipt"
Assert-Match $action '\[_veh,\s*_requestToken\]\s+Spawn' "action schedules matching-receipt timeout recovery"
Assert-Match $action 'sleep\s+8' "pending receipt has a bounded timeout"
Assert-NotMatch $action 'setVariable\s*\["wfbe_vbied_fired",\s*true\]' "action does not consume its one-shot latch before server acceptance"

Write-Host "Checking authoritative acceptance"
Assert-Match $handler '_requestToken\s*=\s*_args select 3' "server reads the client receipt"
Assert-Match $handler 'wfbe_vbied_server_fired' "server owns a separate one-shot receipt"
Assert-Match $handler 'guer-vbied-result' "server returns an accept or deny result"
Assert-Ordered $handler '_veh setVariable ["wfbe_vbied_server_fired", true]' '[_veh, _driver] spawn' "server commits its one-shot receipt before scheduling the blast"

Write-Host "Checking matched client settlement"
Assert-Match $client 'case "guer-vbied-result"' "client receives the VBIED result"
Assert-Match $client '_vbiedExpected\s*=\s*_vbiedVeh getVariable \["wfbe_vbied_pending_token",\s*""\]' "client loads the pending receipt before settlement"
Assert-Match $client 'if \(_vbiedExpected != _vbiedToken\) exitWith \{\}' "client rejects stale or foreign results"
Assert-Match $client 'if \(_vbiedOK\) then \{\s*_vbiedVeh setVariable \["wfbe_vbied_fired", true\]' "only an accepted matching result consumes the latch"
Assert-Match $client '_vbiedVeh setVariable \["wfbe_vbied_pending_token", ""\]' "matching results clear the pending receipt"

Write-Host "Checking mirrors"
Assert-Mirror $actionPath "detonation action mirrors Chernarus to Takistan and Zargabad"
Assert-Mirror $clientPath "client result handler mirrors Chernarus to Takistan and Zargabad"
Assert-Mirror $handlerPath "server receipt handler mirrors Chernarus to Takistan and Zargabad"

Write-Host ""
if ($script:fails -eq 0) {
	Write-Host "Test-GuerVbiedReceipt: PASS" -ForegroundColor Green
	exit 0
}

Write-Host ("Test-GuerVbiedReceipt: {0} failure(s)" -f $script:fails) -ForegroundColor Red
exit 1
