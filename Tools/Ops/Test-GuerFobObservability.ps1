#requires -Version 5.1
<#
.SYNOPSIS
    Guards the server-authoritative GUER FOB build outcome contract.

.DESCRIPTION
    A client can optimistically display "Building FOB ..." before the server
    validates token and placement state.  This static contract test ensures the
    authoritative PVF leaves an always-on RPT breadcrumb for each request,
    rejection, and acceptance, and that server-side rejections produce a
    caller-only result handled by the client.
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

function Read-Source {
	param([Parameter(Mandatory)] [string]$RelativePath)

	$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
	$path = Join-Path $repoRoot $RelativePath
	if (!(Test-Path -LiteralPath $path)) {
		throw "Source not found: $path"
	}

	return Get-Content -LiteralPath $path -Raw
}

$request = Read-Source "Missions\[55-2hc]warfarev2_073v48co.chernarus\Server\PVFunctions\RequestFOBStructure.sqf"
$client = Read-Source "Missions\[55-2hc]warfarev2_073v48co.chernarus\Client\PVFunctions\HandleSpecial.sqf"

Write-Host "Checking GUER FOB server outcome observability"
Assert-Match $request 'GUERFOB\|v1\|request' "server writes an always-on request marker"
Assert-Match $request 'GUERFOB\|v1\|reject' "server writes an always-on rejection marker"
Assert-Match $request 'GUERFOB\|v1\|accept' "server writes an always-on acceptance marker"
Assert-Match $request 'reason=malformed-payload' "malformed payload rejection is observable"
Assert-Match $request 'reason=short-payload' "short payload rejection is observable"
Assert-Match $request '\["guer-fob-result",\s*false,' "server sends a flat caller-only rejected result"

Write-Host "Checking GUER FOB client feedback"
Assert-Match $client 'case\s+"guer-fob-result"\s*:' "client handles the GUER FOB result"
Assert-Match $client 'hint _fobMsg' "client shows the authoritative rejection message"

Write-Host ""
if ($script:fails -eq 0) {
	Write-Host "Test-GuerFobObservability: PASS" -ForegroundColor Green
	exit 0
}

Write-Host ("Test-GuerFobObservability: {0} failure(s)" -f $script:fails) -ForegroundColor Red
exit 1
