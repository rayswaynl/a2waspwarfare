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

# Live convention: the tracked template carries a build-tagged WASPRELEASE marker.
# We validate that the marker line is present and well-formed, not its exact build id.
$markerPattern = '(?m)^#define WF_RELEASE_MARKER "WASPRELEASE\|v1\|candidate=[^"|]+\|git=[^"|]+\|terrain=[^"|]+"\r?$'

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
Assert-Match $takistan '(?m)^#define WF_MAXPLAYERS 61\r?$' "Takistan max-player define is 61"
Assert-Match $takistan '(?m)^#define WF_MISSIONNAME "\[61\] Warfare V48 Takistan"\r?$' "Takistan mission name is Takistan"

Write-Host ""
if ($script:fails -eq 0) {
	Write-Host "Test-WaspVersionTemplates: PASS" -ForegroundColor Green
	exit 0
}

Write-Host ("Test-WaspVersionTemplates: {0} failure(s)" -f $script:fails) -ForegroundColor Red
exit 1
