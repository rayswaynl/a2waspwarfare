#requires -Version 5.1
<#
.SYNOPSIS
    Validates the active release tuple in PR #126 operator-facing docs.

.DESCRIPTION
    The release package tuple moves often while PR #125 is still runtime-pending.
    This guard keeps PR #126's release ledger and monitor examples aligned with
    the active package identity, while allowing older package hashes only where
    they are outside this narrow current-status surface.
#>
[CmdletBinding()]
param(
	[string]$ExpectedGitFull = "7f81115edf6226791d2156b330b7b38652d7a989",
	[string]$ExpectedGit = "7f81115edf",
	[string]$ExpectedArchiveSha256 = "40883616F483EFBB6BCB4DE9EF0FFB4CC693652F89376DBC045CE1F9C69F17BD",
	[string]$ExpectedPackageSize = "7,162,199",
	[string]$ExpectedWikiCommit = "51faaca",
	[string[]]$StaleArchiveSha256 = @(
		"50AD7B20D82E30AF7C7CD7028D79F8EFC0D48745A209F1D959C1DFE52315C320",
		"F057952E3DEDF4AB7D75FD1B3BEECFF4183506A7B83798241120B2F8D14B5F43"
	)
)

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

function Assert-NotContains {
	param(
		[Parameter(Mandatory)] [string]$Text,
		[Parameter(Mandatory)] [string]$Needle,
		[Parameter(Mandatory)] [string]$Label
	)
	if (!$Text.Contains($Needle)) {
		Write-Host ("  PASS  {0}" -f $Label)
	} else {
		Write-Host ("  FAIL  {0}" -f $Label) -ForegroundColor Red
		$script:fails++
	}
}

$releaseLedger = Read-RepoFile "docs\release\2026-07-01-release-readiness-task.md"
$monitorReadme = Read-RepoFile "Tools\Monitor\README.md"

Write-Host "Checking release-readiness ledger tuple"
Assert-Contains $releaseLedger $ExpectedGitFull "ledger has expected full git identity"
Assert-Contains $releaseLedger $ExpectedGit "ledger has expected git marker"
Assert-Contains $releaseLedger $ExpectedArchiveSha256 "ledger has expected archive SHA"
Assert-Contains $releaseLedger $ExpectedPackageSize "ledger has expected package size"
Assert-Contains $releaseLedger $ExpectedWikiCommit "ledger has expected wiki commit"
Assert-Contains $releaseLedger "Exact Chernarus and Takistan runtime RPT proof is still pending" "ledger still marks runtime proof pending"
Assert-Contains $releaseLedger "not final runtime proof" "ledger does not treat package proof as final runtime proof"

Write-Host "Checking monitor README tuple"
Assert-Contains $monitorReadme $ExpectedGit "monitor README has expected git marker"
Assert-Contains $monitorReadme $ExpectedArchiveSha256 "monitor README has expected archive SHA"
Assert-Contains $monitorReadme $ExpectedPackageSize "monitor README has expected package size"
Assert-Contains $monitorReadme "-ExpectedArchiveSha256 $ExpectedArchiveSha256" "monitor commands use expected archive SHA"

foreach ($stale in $StaleArchiveSha256) {
	if ($stale -ne $ExpectedArchiveSha256) {
		Assert-NotContains $releaseLedger $stale "ledger does not contain stale archive SHA $($stale.Substring(0, 10))"
		Assert-NotContains $monitorReadme $stale "monitor README does not contain stale archive SHA $($stale.Substring(0, 10))"
	}
}

Write-Host ""
if ($script:fails -eq 0) {
	Write-Host "Test-WaspReleaseTupleDocs: PASS" -ForegroundColor Green
	exit 0
}

Write-Host ("Test-WaspReleaseTupleDocs: {0} failure(s)" -f $script:fails) -ForegroundColor Red
exit 1
