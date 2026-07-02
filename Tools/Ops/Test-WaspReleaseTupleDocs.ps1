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
	[string]$ExpectedBranchHeadFull = "4893faaa5dc7942f04e9993fb93fb44c8425cc98",
	[string]$ExpectedGitFull = "4893faaa5dc7942f04e9993fb93fb44c8425cc98",
	[string]$ExpectedGit = "4893faaa5d",
	[string]$ExpectedArchiveSha256 = "22F5AEE4BAF78FCB417A5C7CB7C76B2E1C67B7968541F95EB47527E0AF2A085E",
	[string]$ExpectedPackageSize = "7,166,685",
	[string]$ExpectedWikiCommit = "9d22444",
	[string[]]$StaleArchiveSha256 = @(
		"190475B4E8967B04F454A20748FE0A95E09C470821FD7304B06B3EDBED34AF4A",
		"1C58A4A3FD2CBE90C7BF0F37062C1035D0DAD82C1875A801E639CC870EAC2C4B",
		"3DB01AC1656329ECCAE9896CE9442680D5D904C563DD44590FFBD20954CF7B87",
		"703F71E6C9F7E2FEB5323ADE32B5A4AFF7A2B277FC8B5BBE2687F5ED91601BED",
		"40883616F483EFBB6BCB4DE9EF0FFB4CC693652F89376DBC045CE1F9C69F17BD",
		"50AD7B20D82E30AF7C7CD7028D79F8EFC0D48745A209F1D959C1DFE52315C320",
		"F057952E3DEDF4AB7D75FD1B3BEECFF4183506A7B83798241120B2F8D14B5F43",
		"D323434629AB90F90CDD4C4874F164422F38B94075101861F8B1E726C76FE81E",
		"76A5EE569DDA8E1486A16A7C20DF44E3332170F7590A2AE3008C6058E32E25DA",
		"E887E7920AAE620A7DFCB20FFD17FFAB5F16DF8B1F40D58E73173DB9CD236B77",
		"8D06CDA3AEF8A200CFC49306E41CC6FE25FE72015451F8D264BB14D753F8BD90",
		"35B864A10626B8AA92F4C7A7729E1CF889310A8DA8E3BAEE58C09BA2BFC5053E",
		"B5A0C795F3825F082082EBA6A1D162C91699DF94601195D04AA4B55DC7361BF9",
		"D5CA434E1CD80FFF8C787889FE54C8E63365B5587DCEE093E365D5CC2EC4195B",
		"ECC6F9D51DD9BD459677863E585F313921E55BAE905C83431EB7EB7596E7D416",
		"0EFED527088FE4EBD0F0C94702DE9A1818972EE9741597F8B400E9B78268A74C",
		"DF37FA9EBEC4F650A7A37CB6C2ED0842C59860CAE18617BB61A3C56010E603CE",
		"F4F19086A4D51881C61B16CA024FE1C586478161672C7EFE268F5A42C4852B7A",
		"0AC507E1F80F95C4802F2002AC48079B7C4CFE697C770BBE3375242EE0CB5D9C",
		"E7B12EDA71DF0F4941CD2E6A92188D27D62E6C2C4B5B181C88A6EB3D65131A9E"
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
Assert-Contains $releaseLedger $ExpectedBranchHeadFull "ledger has expected current branch head"
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
Assert-Contains $monitorReadme "-ArchivePath" "monitor README recommends archive path hash binding"
Assert-Contains $monitorReadme "expectedTerrain" "monitor README documents terrain stamp validation"

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
