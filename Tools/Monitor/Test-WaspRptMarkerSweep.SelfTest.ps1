[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $PSScriptRoot "Get-WaspRptMarkerSweep.ps1"
if (!(Test-Path -LiteralPath $scriptPath)) {
	throw "Marker sweep script not found: $scriptPath"
}

function Invoke-MarkerSweep {
	param(
		[Parameter(Mandatory)] [string[]]$Arguments,
		[switch]$ExpectFailure
	)
	$output = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath @Arguments 2>&1
	$exitCode = $LASTEXITCODE
	if ($ExpectFailure) {
		if ($exitCode -eq 0) { throw "Expected marker sweep to fail, but exit code was 0. Output: $output" }
	} else {
		if ($exitCode -ne 0) { throw "Expected marker sweep to pass, but exit code was $exitCode. Output: $output" }
	}
	return ($output -join "`n")
}

function Assert-Equal {
	param($Actual, $Expected, [string]$Label)
	if ($Actual -ne $Expected) {
		throw "$Label expected [$Expected], got [$Actual]"
	}
}

function Assert-True {
	param([bool]$Condition, [string]$Label)
	if (!$Condition) { throw $Label }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("wasp-marker-sweep-selftest-" + [Guid]::NewGuid().ToString("N"))
$tempFull = [System.IO.Path]::GetFullPath($tempRoot)
$safeTempPrefix = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd([char[]]@('\','/')) + [System.IO.Path]::DirectorySeparatorChar

try {
	New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

	$serverRpt = Join-Path $tempRoot "server-a.RPT"
	$hcRpt = Join-Path $tempRoot "server-b.RPT"
	Set-Content -LiteralPath $serverRpt -Encoding ASCII -Value @(
		"boot",
		"""WASPRELEASE|v1|candidate=release-command-center-20260630|git=test|terrain=chernarus""",
		"""AICOMSTAT|v1|EVENT|WEST|0|TEAM_FOUNDED""",
		"""HCSTAT|v1|HC-1|fps=45|units=1"""
	)
	Set-Content -LiteralPath $hcRpt -Encoding ASCII -Value @(
		"MISSINIT",
		"""WASPRELEASE|v1|candidate=release-command-center-20260630|git=test|terrain=takistan""",
		"""HCDROP_AICOM_AUDIT|uid=redacted|owner=2""",
		"""HCRECON_AICOM_AUDIT|owner=3"""
	)

	$jsonText = Invoke-MarkerSweep -Arguments @(
		"-RptDirectory", $tempRoot,
		"-Latest", "2",
		"-RequirePattern", "HCDROP_AICOM_AUDIT,HCRECON_AICOM_AUDIT",
		"-Json"
	)
	$result = $jsonText | ConvertFrom-Json
	Assert-Equal $result.schema "a2waspwarfare-rpt-marker-sweep-v1" "schema"
	Assert-Equal $result.fileCount 2 "fileCount"
	Assert-Equal $result.counts.HCDROP_AICOM_AUDIT 1 "HCDROP_AICOM_AUDIT count"
	Assert-Equal $result.counts.HCRECON_AICOM_AUDIT 1 "HCRECON_AICOM_AUDIT count"
	Assert-Equal $result.counts.AICOMSTAT 1 "AICOMSTAT count"
	Assert-Equal $result.counts.HCSTAT 1 "HCSTAT count"
	Assert-Equal @($result.missingRequired).Count 0 "missingRequired count"
	Assert-True ((@($result.samples) | Where-Object { $_.PSObject.Properties.Name -contains "line" }).Count -eq 0) "Default samples must not include raw line text"
	Assert-True ((@($result.samples) | Where-Object { $_.lineHash -and $_.pathLabel }).Count -gt 0) "Samples should include line hashes and public path labels"

	$releaseMarkerText = Invoke-MarkerSweep -Arguments @(
		"-RptDirectory", $tempRoot,
		"-Latest", "2",
		"-ExpectedCandidate", "release-command-center-20260630",
		"-ExpectedGit", "test",
		"-RequireReleaseMarkers",
		"-Json"
	)
	$releaseMarkerResult = $releaseMarkerText | ConvertFrom-Json
	Assert-Equal @($releaseMarkerResult.expectedReleaseMarkers).Count 2 "expectedReleaseMarkers count"
	Assert-Equal $releaseMarkerResult.counts.AICOMSTAT 1 "release marker mode should retain default AICOMSTAT count"
	Assert-Equal $releaseMarkerResult.counts.'WASPRELEASE|v1|candidate=release-command-center-20260630|git=test|terrain=chernarus' 1 "chernarus release marker count"
	Assert-Equal $releaseMarkerResult.counts.'WASPRELEASE|v1|candidate=release-command-center-20260630|git=test|terrain=takistan' 1 "takistan release marker count"
	Assert-Equal @($releaseMarkerResult.missingRequired).Count 0 "release marker missingRequired count"

	[void](Invoke-MarkerSweep -Arguments @(
		"-RptPath", $serverRpt,
		"-ExpectedCandidate", "release-command-center-20260630",
		"-ExpectedGit", "test",
		"-RequireReleaseMarkers"
	) -ExpectFailure)

	[void](Invoke-MarkerSweep -Arguments @(
		"-RptDirectory", $tempRoot,
		"-Latest", "2",
		"-RequireReleaseMarkers"
	) -ExpectFailure)

	$nofailText = Invoke-MarkerSweep -Arguments @(
		"-RptDirectory", $tempRoot,
		"-Latest", "2",
		"-RequirePattern", "DOES_NOT_EXIST",
		"-NoFail"
	)
	Assert-True ($nofailText -match "Missing required: DOES_NOT_EXIST") "-NoFail output should still report missing marker"

	[void](Invoke-MarkerSweep -Arguments @(
		"-RptDirectory", $tempRoot,
		"-Latest", "2",
		"-RequirePattern", "DOES_NOT_EXIST"
	) -ExpectFailure)

	Write-Host "Test-WaspRptMarkerSweep.SelfTest: PASS"
} finally {
	if ((Test-Path -LiteralPath $tempRoot) -and $tempFull.StartsWith($safeTempPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
		Remove-Item -LiteralPath $tempRoot -Recurse -Force
	}
}
