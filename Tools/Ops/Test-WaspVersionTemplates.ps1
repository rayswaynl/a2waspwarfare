#requires -Version 5.1
<#
.SYNOPSIS
    Validates tracked fallback version.sqf.template files for the maintained WASP terrains.

.DESCRIPTION
    The generated version.sqf files are ignored and carry the real package marker.
    These tracked templates are fallback/operator references, so they must never look
    like an exact release package and must keep terrain-specific defines correct.
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

$fakeMarkerPattern = '(?m)^#define WF_RELEASE_MARKER "WASPRELEASE\|v1\|candidate=unpackaged\|git=missing-version\|terrain=manual"\r?$'

Write-Host "Checking Chernarus version.sqf.template"
Assert-Match $chernarus $fakeMarkerPattern "Chernarus fallback marker is explicitly unpackaged"
Assert-NotMatch $chernarus '(?m)^#define WF_DEBUG\b' "Chernarus WF_DEBUG is not active"
Assert-Match $chernarus '(?m)^#define IS_CHERNARUS_MAP_DEPENDENT\r?$' "Chernarus map-dependent define is active"
Assert-Match $chernarus '(?m)^#define IS_NAVAL_MAP\r?$' "Chernarus naval define is active"
Assert-Match $chernarus '(?m)^#define WF_MAXPLAYERS 55\r?$' "Chernarus max players is 55"
Assert-Match $chernarus '(?m)^#define WF_MISSIONNAME "\[55\] Warfare V48 Chernarus"\r?$' "Chernarus mission name is correct"
Assert-NotMatch $chernarus 'candidate=release-command-center-20260630|git=(?!missing-version)' "Chernarus template does not contain an exact package identity"

Write-Host "Checking Takistan version.sqf.template"
Assert-Match $takistan $fakeMarkerPattern "Takistan fallback marker is explicitly unpackaged"
Assert-NotMatch $takistan '(?m)^#define WF_DEBUG\b' "Takistan WF_DEBUG is not active"
Assert-Match $takistan '(?m)^//#define IS_CHERNARUS_MAP_DEPENDENT\r?$' "Takistan Chernarus map-dependent define is commented"
Assert-Match $takistan '(?m)^//#define IS_NAVAL_MAP\r?$' "Takistan naval define is commented"
Assert-Match $takistan '(?m)^#define WF_MAXPLAYERS 61\r?$' "Takistan max players is 61"
Assert-Match $takistan '(?m)^#define WF_MISSIONNAME "\[61\] Warfare V48 Takistan"\r?$' "Takistan mission name is correct"
Assert-NotMatch $takistan 'candidate=release-command-center-20260630|git=(?!missing-version)' "Takistan template does not contain an exact package identity"

Write-Host ""
if ($script:fails -eq 0) {
	Write-Host "Test-WaspVersionTemplates: PASS" -ForegroundColor Green
	exit 0
}

Write-Host ("Test-WaspVersionTemplates: {0} failure(s)" -f $script:fails) -ForegroundColor Red
exit 1
