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
$buildPath = "Missions\[55-2hc]warfarev2_073v48co.chernarus\Client\Functions\Client_BuildUnit.sqf"
$constantsPath = "Missions\[55-2hc]warfarev2_073v48co.chernarus\Common\Init\Init_CommonConstants.sqf"
$listPath = "Missions\[55-2hc]warfarev2_073v48co.chernarus\Client\Functions\Client_UIFillListBuyUnits.sqf"
$menuPath = "Missions\[55-2hc]warfarev2_073v48co.chernarus\Client\GUI\GUI_Menu_BuyUnits.sqf"
$upgradePath = "Missions\[55-2hc]warfarev2_073v48co.chernarus\Client\GUI\GUI_UpgradeMenu.sqf"
$build = Read-Source $buildPath
$constants = Read-Source $constantsPath
$list = Read-Source $listPath
$menu = Read-Source $menuPath
$upgrade = Read-Source $upgradePath

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

Write-Host "Checking speed and high-climb contract"
Assert-Match $constants 'WFBE_C_GUER_VBIED_SPEEDCOEF\s*=\s*1\.25' "truck boost coefficient is 1.25x"
Assert-Match $constants 'WFBE_C_GUER_VBIED_M113_SPEEDCOEF\s*=\s*1\.5' "M113 boost coefficient is owner-tuned to 1.5x"
Assert-Match $build 'wfbe_vbied_speedcoef' "shared boost loop is parameterized per VBIED hull"
Assert-Match $build 'WFBE_HighClimbingEnabled", false, true' "VBIED high climbing defaults off for opt-in"
Assert-Match $build 'wfbe_vbied_climb_action' "bike receives a deduped local high-climb toggle action"
Assert-Match $build 'Client\\Module\\Valhalla\\LowGear_Toggle\.sqf' "VBIED climb action reuses the Valhalla toggle"
Assert-NotMatch $list '2x Speed' "M113 buy-list text no longer promises 2x speed"
Assert-NotMatch $menu 'DOUBLE its normal top speed' "M113 detail text no longer promises double speed"
Assert-NotMatch $upgrade 'M113 driven as a suicide VBIED at ~2x' "M113 upgrade text no longer promises 2x speed"
Assert-Match $list '1\.5x Speed' "M113 buy-list text advertises ~1.5x speed"
Assert-Match $menu 'roughly 1\.5x its normal top speed' "M113 detail text advertises ~1.5x speed"
Assert-Match $upgrade 'M113 driven as a suicide VBIED at ~1\.5x' "M113 upgrade text advertises ~1.5x speed"

Write-Host "Checking mirrors"
Assert-Mirror $actionPath "detonation action mirrors Chernarus to Takistan and Zargabad"
Assert-Mirror $clientPath "client result handler mirrors Chernarus to Takistan and Zargabad"
Assert-Mirror $handlerPath "server receipt handler mirrors Chernarus to Takistan and Zargabad"
Assert-Mirror $buildPath "VBIED speed and climb wiring mirrors Chernarus to Takistan and Zargabad"
Assert-Mirror $constantsPath "VBIED tuning constants mirror Chernarus to Takistan and Zargabad"
Assert-Mirror $listPath "VBIED buy-list copy mirrors Chernarus to Takistan and Zargabad"
Assert-Mirror $menuPath "VBIED detail copy mirrors Chernarus to Takistan and Zargabad"
Assert-Mirror $upgradePath "VBIED upgrade copy mirrors Chernarus to Takistan and Zargabad"

Write-Host ""
if ($script:fails -eq 0) {
	Write-Host "Test-GuerVbiedReceipt: PASS" -ForegroundColor Green
	exit 0
}

Write-Host ("Test-GuerVbiedReceipt: {0} failure(s)" -f $script:fails) -ForegroundColor Red
exit 1
