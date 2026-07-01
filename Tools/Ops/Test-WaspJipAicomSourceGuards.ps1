#requires -Version 5.1
<#
.SYNOPSIS
    Guards maintained Chernarus/Takistan JIP and AI Commander source markers.

.DESCRIPTION
    PR #126 adds runtime-proof instrumentation and join-in-progress catch-up
    paths that must remain present in both maintained terrains. This static
    guard catches accidental terrain drift before packaging or RPT collection.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$script:fails = 0
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

function Read-RepoFile {
	param([Parameter(Mandatory)] [string]$RelativePath)
	$path = Join-Path $repoRoot $RelativePath
	if (!(Test-Path -LiteralPath $path)) {
		throw "File not found: $path"
	}
	return Get-Content -LiteralPath $path -Raw
}

function Assert-Contains {
	param(
		[Parameter(Mandatory)] [string]$Text,
		[Parameter(Mandatory)] [string]$Needle,
		[Parameter(Mandatory)] [string]$Label
	)
	if ($Text.Contains($Needle)) {
		Write-Host ("  PASS  {0}" -f $Label)
	} else {
		Write-Host ("  FAIL  {0}" -f $Label) -ForegroundColor Red
		$script:fails++
	}
}

function Assert-TokenSet {
	param(
		[Parameter(Mandatory)] [string]$RelativePath,
		[Parameter(Mandatory)] [string[]]$Tokens,
		[Parameter(Mandatory)] [string]$Label
	)
	$text = Read-RepoFile $RelativePath
	Write-Host "Checking $Label"
	foreach ($token in $Tokens) {
		Assert-Contains $text $token "$Label has $token"
	}
}

function Assert-NoRawAicomGroupBoolReads {
	param(
		[Parameter(Mandatory)] [string]$RelativeRoot,
		[Parameter(Mandatory)] [string]$Label
	)
	$path = Join-Path $repoRoot (Join-Path $RelativeRoot "Server\AI\Commander")
	$files = Get-ChildItem -LiteralPath $path -Filter "*.sqf" -File | Where-Object { $_.Name -notlike "*.DRAFT.sqf" }
	$pattern = 'getVariable\s+\["wfbe_aicom_(hc|founded|disband)",\s*false\]'
	Write-Host "Checking $Label active AI Commander group bool reads"
	foreach ($file in $files) {
		$text = Get-Content -LiteralPath $file.FullName -Raw
		if ($text -match $pattern) {
			Write-Host ("  FAIL  {0} still has raw wfbe_aicom group bool read" -f $file.Name) -ForegroundColor Red
			$script:fails++
		}
	}
	if ($script:fails -eq 0) {
		Write-Host ("  PASS  {0} active AI Commander group bool reads use WFBE_CO_FNC_GroupGetBool" -f $Label)
	}
}

$terrainRoots = @(
	@{
		Label = "Chernarus"
		Root = "Missions\[55-2hc]warfarev2_073v48co.chernarus"
	},
	@{
		Label = "Takistan"
		Root = "Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan"
	}
)

$joinCatchupTokens = @(
	"WFBE_ACTIVE_AICOM_TEAMS",
	"WFBE_ACTIVE_PATROLS",
	"WFBE_ACTIVE_GUER_AIR",
	"WFBE_GUER_PLAYER_KILLS",
	"WFBE_GUER_VEHICLE_TIER",
	"WFBE_GUER_FOB_AVAIL",
	"WFBE_PopTier",
	"WFBE_AICOM_INTENT_%1",
	"WFBE_AICOM_OBJNAME_%1",
	"WFBE_AICOM_OBJPOS_%1",
	"WFBE_AICOM_ACTIVE_%1",
	"WFBE_AICOM_FOCUS_NAME_%1",
	"WFBE_AICOM_TEAMS_%1",
	"WFBE_AICOM_FUNDS_%1",
	"publicVariableClient"
)

$jipRosterTokens = @(
	"CLIENTROSTER|RECV",
	"CLIENTROSTER|POLL-ADOPT",
	"WFBE_JIP_ROSTER_COUNT",
	"WFBE_JIP_ROSTER_PRIMS"
)

$hcDropTokens = @(
	"HCDROP_AICOM_AUDIT",
	"wfbe_aicom_last_heading_t",
	"headingFresh",
	"headingStale",
	"headingUnknown"
)

$hcReconnectTokens = @(
	"HCRECON_AICOM_AUDIT",
	"wfbe_aicom_last_heading_t",
	"headingFresh",
	"headingStale",
	"headingUnknown"
)

foreach ($terrain in $terrainRoots) {
	$root = $terrain.Root
	$label = $terrain.Label
	Assert-TokenSet (Join-Path $root "Server\Functions\Server_OnPlayerConnected.sqf") $joinCatchupTokens "$label join-time AI/state catch-up"
	Assert-TokenSet (Join-Path $root "initJIPCompatible.sqf") $jipRosterTokens "$label client roster adoption"
	Assert-TokenSet (Join-Path $root "Server\Functions\Server_OnPlayerDisconnected.sqf") $hcDropTokens "$label HC disconnect audit"
	Assert-TokenSet (Join-Path $root "Server\Functions\Server_HandleSpecial.sqf") $hcReconnectTokens "$label HC reconnect audit"
	Assert-NoRawAicomGroupBoolReads $root $label
}

Write-Host ""
if ($script:fails -eq 0) {
	Write-Host "Test-WaspJipAicomSourceGuards: PASS" -ForegroundColor Green
	exit 0
}

Write-Host ("Test-WaspJipAicomSourceGuards: {0} failure(s)" -f $script:fails) -ForegroundColor Red
exit 1
