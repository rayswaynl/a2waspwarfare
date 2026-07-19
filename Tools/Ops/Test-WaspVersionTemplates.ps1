#requires -Version 5.1
<#
.SYNOPSIS
    Validates tracked fallback version.sqf.template files for the maintained WASP terrains.

.DESCRIPTION
    The generated version.sqf files are ignored; the tracked templates are the
    operator/fallback reference that ships in the repo. This guard enforces the
    deploy-safety invariants that must hold on the live lane at all times:
      * WF_DEBUG must never be left active (WF_DEBUG ON = instant funds + all tiers).
      * A well-formed WASPRELEASE marker line must be present.
      * Chernarus keeps its map-dependent + naval defines active.
      * Desert/non-naval templates keep Chernarus + naval defines inactive.
    Salvaged from PR #126 (release-readiness) onto the live lane; the original
    checked stale master-era values (unpackaged marker, maxplayers 55/61) that do
    not match the live convention of a build-tagged marker in the tracked template.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$script:fails = 0

function Assert-Match {
	param(
		[Parameter(Mandatory)] [string]$Text,
		[Parameter(Mandatory)] [string]$Pattern,
		[Parameter(Mandatory)] [string]$Label
	)
	if ($Text -match $Pattern) {
		Write-Host ("  PASS  {0}" -f $Label)
	} else {
		Write-Host ("  FAIL  {0}" -f $Label) -ForegroundColor Red
		$script:fails++
	}
}

function Assert-NotMatch {
	param(
		[Parameter(Mandatory)] [string]$Text,
		[Parameter(Mandatory)] [string]$Pattern,
		[Parameter(Mandatory)] [string]$Label
	)
	if ($Text -notmatch $Pattern) {
		Write-Host ("  PASS  {0}" -f $Label)
	} else {
		Write-Host ("  FAIL  {0}" -f $Label) -ForegroundColor Red
		$script:fails++
	}
}

function Read-Template {
	param([Parameter(Mandatory)] [string]$RelativePath)
	$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
	$path = Join-Path $repoRoot $RelativePath
	if (!(Test-Path -LiteralPath $path)) {
		throw "Template not found: $path"
	}
	return Get-Content -LiteralPath $path -Raw
}

$chernarus = Read-Template "Missions\[55-2hc]warfarev2_073v48co.chernarus\version.sqf.template"
$takistan = Read-Template "Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan\version.sqf.template"
$zargabad = Read-Template "Missions_Vanilla\[61-2hc]warfarev2_073v48co.zargabad\version.sqf.template"
$baseTerrain = Read-Template "Tools\LoadoutManager\Data\Terrains\BaseTerrain.cs"

# Live convention: the tracked template carries a build-tagged WASPRELEASE marker.
# We validate that the marker line is present and well-formed, not its exact build id.
$markerPattern = '(?m)^#define WF_RELEASE_MARKER "WASPRELEASE\|v1\|candidate=[^"|]+\|git=[^"|]+\|terrain=[^"|]+"\r?$'

Write-Host "Checking LoadoutManager release candidate identity"
Assert-Match $baseTerrain 'private const string ReleaseCandidateId = "wasp-rc2-20260719";' "LoadoutManager stamps the RC2 candidate"
Assert-Match $baseTerrain 'private string DeterminePlayableSlotCount\(\)[\s\S]*?return "36";' "LoadoutManager emits the maintained 36-slot roster"

Write-Host "Checking Chernarus version.sqf.template"
Assert-Match $chernarus $markerPattern "Chernarus release marker line is present and well-formed"
Assert-NotMatch $chernarus '(?m)^#define WF_DEBUG\b' "Chernarus WF_DEBUG is not active"
Assert-Match $chernarus '(?m)^#define IS_CHERNARUS_MAP_DEPENDENT\r?$' "Chernarus map-dependent define is active"
Assert-Match $chernarus '(?m)^#define IS_NAVAL_MAP\r?$' "Chernarus naval define is active"

Write-Host "Checking Takistan version.sqf.template"
Assert-Match $takistan $markerPattern "Takistan release marker line is present and well-formed"
Assert-NotMatch $takistan '(?m)^#define WF_DEBUG\b' "Takistan WF_DEBUG is not active"
Assert-NotMatch $takistan '(?m)^#define IS_CHERNARUS_MAP_DEPENDENT\r?$' "Takistan map-dependent define is not active"
Assert-NotMatch $takistan '(?m)^#define IS_NAVAL_MAP\r?$' "Takistan naval define is not active"
Assert-Match $takistan '(?m)^#define WF_MAXPLAYERS 36\r?$' "Takistan max-player define matches its balanced 36-slot roster"
Assert-Match $takistan '(?m)^#define WF_MISSIONNAME "\[36\] Warfare V48 Takistan"\r?$' "Takistan mission name carries the balanced roster"

Write-Host "Checking Zargabad version.sqf.template"
Assert-Match $zargabad $markerPattern "Zargabad release marker line is present and well-formed"
Assert-NotMatch $zargabad '(?m)^#define WF_DEBUG\b' "Zargabad WF_DEBUG is not active"
Assert-NotMatch $zargabad '(?m)^#define IS_CHERNARUS_MAP_DEPENDENT\r?$' "Zargabad map-dependent define is not active"
Assert-NotMatch $zargabad '(?m)^#define IS_NAVAL_MAP\r?$' "Zargabad naval define is not active"
Assert-Match $zargabad '(?m)^#define WF_MAXPLAYERS 36\r?$' "Zargabad max-player define matches its balanced 36-slot roster"
Assert-Match $zargabad '(?m)^#define WF_MISSIONNAME "\[36\] Warfare V48 Zargabad"\r?$' "Zargabad mission name carries the balanced roster"
Assert-Match $zargabad '(?m)^#define STARTING_DISTANCE 5000\r?$' "Zargabad starting distance matches its map size"

Write-Host ""
if ($script:fails -eq 0) {
	Write-Host "Test-WaspVersionTemplates: PASS" -ForegroundColor Green
	exit 0
}

Write-Host ("Test-WaspVersionTemplates: {0} failure(s)" -f $script:fails) -ForegroundColor Red
exit 1
