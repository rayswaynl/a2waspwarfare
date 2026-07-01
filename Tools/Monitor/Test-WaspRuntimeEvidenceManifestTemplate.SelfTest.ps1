[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$templateScript = Join-Path $PSScriptRoot "New-WaspRuntimeEvidenceManifestTemplate.ps1"
$validatorScript = Join-Path $PSScriptRoot "Test-WaspRuntimeEvidenceManifest.ps1"
foreach ($path in @($templateScript, $validatorScript)) {
	if (!(Test-Path -LiteralPath $path)) { throw "Required script not found: $path" }
}

function Invoke-Template {
	param(
	[Parameter(Mandatory)] [string[]]$Arguments,
	[switch]$ExpectFailure
	)
	$oldErrorActionPreference = $ErrorActionPreference
	$ErrorActionPreference = "Continue"
	try {
		$output = & powershell -NoProfile -ExecutionPolicy Bypass -File $templateScript @Arguments 2>&1
		$exitCode = $LASTEXITCODE
	} finally {
		$ErrorActionPreference = $oldErrorActionPreference
	}
	if ($ExpectFailure) {
		if ($exitCode -eq 0) { throw "Expected template generator to fail, but exit code was 0. Output: $output" }
	} else {
		if ($exitCode -ne 0) { throw "Expected template generator to pass, but exit code was $exitCode. Output: $output" }
	}
	return ($output -join "`n")
}

function Write-Sweep {
	param(
		[Parameter(Mandatory)] [string]$Path,
		[Parameter(Mandatory)] [string]$Terrain,
		[Parameter(Mandatory)] [string]$Role
	)
	$marker = "WASPRELEASE|v1|candidate=test-candidate|git=testgit|terrain=$Terrain"
	$counts = [ordered]@{}
	$counts[$marker] = 1
	$value = [pscustomobject][ordered]@{
		schema = "a2waspwarfare-rpt-marker-sweep-v1"
		expectedCandidate = "test-candidate"
		expectedGit = "testgit"
		expectedArchiveSha256 = "ABCDEF0123456789"
		expectedRole = $Role
		counts = [pscustomobject]$counts
		missingRequired = @()
	}
	$json = $value | ConvertTo-Json -Depth 8
	$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
	[System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, $utf8NoBom)
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("wasp-runtime-evidence-template-selftest-" + [Guid]::NewGuid().ToString("N"))
$tempFull = [System.IO.Path]::GetFullPath($tempRoot)
$safeTempPrefix = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd([char[]]@('\','/')) + [System.IO.Path]::DirectorySeparatorChar

try {
	New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

	$manifestPath = Join-Path $tempRoot "runtime-evidence.json"
	$commandPath = Join-Path $tempRoot "marker-sweep-commands.ps1"
	[void](Invoke-Template -Arguments @(
		"-OutFile", $manifestPath,
		"-ExpectedCandidate", "test-candidate",
		"-ExpectedGit", "testgit",
		"-ExpectedArchiveSha256", "ABCDEF0123456789",
		"-RequiredTerrain", "chernarus,takistan",
		"-RequiredRole", "server,hc1",
		"-CommandOutFile", $commandPath
	))

	$manifest = (Get-Content -Raw -LiteralPath $manifestPath) | ConvertFrom-Json
	if ($manifest.schema -ne "a2waspwarfare-runtime-evidence-manifest-v1") { throw "Unexpected manifest schema." }
	if ($manifest.release.git -ne "testgit") { throw "Manifest release git not recorded." }
	if (@($manifest.evidence).Count -ne 4) { throw "Expected four manifest rows." }
	$hasTakistanHc1 = $false
	foreach ($row in @($manifest.evidence)) {
		if (("" + $row.terrain) -eq "takistan" -and ("" + $row.role) -eq "hc1") { $hasTakistanHc1 = $true }
	}
	if (!$hasTakistanHc1) {
		throw "Expected Takistan HC1 row."
	}
	if (!(Test-Path -LiteralPath $commandPath)) { throw "Expected marker-sweep command template to exist." }
	$commandText = Get-Content -Raw -LiteralPath $commandPath
	if ($commandText -notmatch "marker-sweep-takistan-hc1.json") { throw "Expected Takistan HC1 marker-sweep output path in command template." }
	if ($commandText -notmatch "-ExpectedTerrain takistan") { throw "Expected per-terrain marker sweep command." }
	if ($commandText -notmatch "-ExpectedRole hc1") { throw "Expected per-role marker sweep command." }
	if ($commandText -notmatch "Do not commit populated private paths") { throw "Expected privacy warning in command template." }

	foreach ($row in @($manifest.evidence)) {
		Write-Sweep -Path (Join-Path $tempRoot $row.markerSweepPath) -Terrain $row.terrain -Role $row.role
	}

	$validatorOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $validatorScript `
		-ManifestPath $manifestPath `
		-ExpectedCandidate test-candidate `
		-ExpectedGit testgit `
		-ExpectedArchiveSha256 ABCDEF0123456789 `
		-RequiredTerrain chernarus,takistan `
		-RequiredRole server,hc1 2>&1
	if ($LASTEXITCODE -ne 0) { throw "Generated manifest should validate, output: $validatorOutput" }

	[void](Invoke-Template -Arguments @(
		"-OutFile", $manifestPath,
		"-ExpectedCandidate", "test-candidate",
		"-ExpectedGit", "testgit",
		"-ExpectedArchiveSha256", "ABCDEF0123456789"
	) -ExpectFailure)

	Write-Host "Test-WaspRuntimeEvidenceManifestTemplate.SelfTest: PASS"
} finally {
	if ((Test-Path -LiteralPath $tempRoot) -and $tempFull.StartsWith($safeTempPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
		Remove-Item -LiteralPath $tempRoot -Recurse -Force
	}
}
