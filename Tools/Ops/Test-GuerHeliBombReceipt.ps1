#requires -Version 5.1
<#
.SYNOPSIS
    Guards the GUER Barrel Bomb pre-release refund receipt.

.DESCRIPTION
    A paid Barrel Bomb call is committed only when its first real shell exists.
    Missing cargo, partial transporter creation, inbound loss, or inbound timeout
    must settle the server-owned receipt once: refund the exact debited team/cost
    and use the existing false result so the caller's optimistic cooldown clears.
    Post-release return loss is intentionally not a refund path.
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

$handler = Read-Source "Missions\\[55-2hc]warfarev2_073v48co.chernarus\\Server\\Functions\\Server_HandleSpecial.sqf"
$support = Read-Source "Missions\\[55-2hc]warfarev2_073v48co.chernarus\\Server\\Support\\Support_GuerHeliDrop.sqf"

Write-Host "Checking server-owned debit receipt"
Assert-Match $handler '_receiptKey\s*=\s*Format \["wfbe_guer_helibomb_receipt_' "server creates a unique Barrel Bomb receipt key"
Assert-Match $handler 'missionNamespace setVariable \[_receiptKey,\s*\[0,\s*_team,\s*_cost,\s*_player' "server records the exact team, cost, and caller before debit"
Assert-Ordered $handler 'missionNamespace setVariable [_receiptKey, [0, _team, _cost, _player' '[_team, -_cost] Call WFBE_CO_FNC_ChangeTeamFunds' "receipt exists before funds move"
Assert-Match $handler '\[nil,\s*resistance,\s*_pos,\s*_team,\s*_receiptKey\]\s+Spawn\s+KAT_GuerHeliDrop' "server passes only its receipt key to the worker"

Write-Host "Checking exactly-once pre-release settlement"
Assert-Match $support 'count _this\) > 4' "worker accepts an optional receipt key"
Assert-Match $support '_settleReceipt\s*=\s*\{' "worker owns a settlement helper"
Assert-Match $support 'isNil\s*\{' "receipt compare-and-consume is unscheduled"
Assert-Match $support 'GUERHELIBOMB\|v1\|refund\|reason=' "pre-release failure leaves an always-on refund marker"
Assert-Match $support '\[_receiptTeam,\s*_receiptCost\]\s+Call\s+WFBE_CO_FNC_ChangeTeamFunds' "refund uses the stored team and stored cost"
Assert-Match $support 'guer-helibomb-result' "failure uses the existing caller result channel"
Assert-Match $support 'if \(isNil ._cargoType.\) exitWith \{\[_receiptKey, false,' "undefined cargo settles instead of silently exiting"
Assert-Match $support '_failureReason\s*=\s*"transport-destroyed"' "vehicle loss has a terminal pre-release reason"
Assert-Match $support '_failureReason\s*=\s*"pilot-dead"' "pilot loss has a terminal pre-release reason"
Assert-Match $support '_failureReason\s*=\s*"transit-timeout"' "inbound timeout has a terminal pre-release reason"
Assert-Match $support 'if !\(isNull _sp\) then \{' "a real shell is required before commit"
Assert-Ordered $support 'if !(isNull _sp) then {' '[_receiptKey, true,' "receipt commits only after a valid shell"

Write-Host "Checking post-release counterplay boundary"
$returnSection = $support.Substring($support.IndexOf("//--- Fly home."))
if ($returnSection -notmatch '\[_receiptKey, false,') { Write-Host "  PASS  return-leg exits do not refund a released strike" }
else { Write-Host "  FAIL  return-leg exits must not refund a released strike" -ForegroundColor Red; $script:fails++ }

Write-Host ""
if ($script:fails -eq 0) {
	Write-Host "Test-GuerHeliBombReceipt: PASS" -ForegroundColor Green
	exit 0
}

Write-Host ("Test-GuerHeliBombReceipt: {0} failure(s)" -f $script:fails) -ForegroundColor Red
exit 1
