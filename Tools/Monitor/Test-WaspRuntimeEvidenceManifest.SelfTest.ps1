[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $PSScriptRoot "Test-WaspRuntimeEvidenceManifest.ps1"
if (!(Test-Path -LiteralPath $scriptPath)) {
	throw "Runtime evidence manifest validator not found: $scriptPath"
}

function Invoke-ManifestTest {
	param(
		[Parameter(Mandatory)] [string[]]$Arguments,
		[switch]$ExpectFailure
	)
	$output = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath @Arguments 2>&1
	$exitCode = $LASTEXITCODE
	if ($ExpectFailure) {
		if ($exitCode -eq 0) { throw "Expected manifest validator to fail, but exit code was 0. Output: $output" }
	} else {
		if ($exitCode -ne 0) { throw "Expected manifest validator to pass, but exit code was $exitCode. Output: $output" }
	}
	return ($output -join "`n")
}

function Write-JsonFile {
	param(
		[Parameter(Mandatory)] [string]$Path,
		[Parameter(Mandatory)] $Value
	)
	$json = $Value | ConvertTo-Json -Depth 8
	$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
	[System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, $utf8NoBom)
}

function New-Sweep {
	param(
		[Parameter(Mandatory)] [string]$Terrain,
		[string]$Git = "testgit",
		[string]$Archive = "ABCDEF0123456789",
		[string[]]$MissingRequired = @()
	)
	$marker = "WASPRELEASE|v1|candidate=test-candidate|git=$Git|terrain=$Terrain"
	$counts = [ordered]@{}
	$counts[$marker] = 1
	return [pscustomobject][ordered]@{
		schema = "a2waspwarfare-rpt-marker-sweep-v1"
		expectedCandidate = "test-candidate"
		expectedGit = $Git
		expectedArchiveSha256 = $Archive
		counts = [pscustomobject]$counts
		missingRequired = $MissingRequired
	}
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("wasp-runtime-evidence-selftest-" + [Guid]::NewGuid().ToString("N"))
$tempFull = [System.IO.Path]::GetFullPath($tempRoot)
$safeTempPrefix = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd([char[]]@('\','/')) + [System.IO.Path]::DirectorySeparatorChar

try {
	New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

	$roles = @("server", "hc1")
	$terrains = @("chernarus", "takistan")
	$rows = New-Object System.Collections.Generic.List[object]
	foreach ($terrain in $terrains) {
		foreach ($role in $roles) {
			$name = "sweep-$terrain-$role.json"
			Write-JsonFile -Path (Join-Path $tempRoot $name) -Value (New-Sweep -Terrain $terrain)
			$rows.Add([pscustomobject][ordered]@{
				terrain = $terrain
				role = $role
				markerSweepPath = $name
			}) | Out-Null
		}
	}

	$validManifest = Join-Path $tempRoot "valid-manifest.json"
	Write-JsonFile -Path $validManifest -Value ([pscustomobject][ordered]@{
		schema = "a2waspwarfare-runtime-evidence-manifest-v1"
		evidence = $rows.ToArray()
	})

	[void](Invoke-ManifestTest -Arguments @(
		"-ManifestPath", $validManifest,
		"-ExpectedCandidate", "test-candidate",
		"-ExpectedGit", "testgit",
		"-ExpectedArchiveSha256", "ABCDEF0123456789",
		"-RequiredTerrain", "chernarus,takistan",
		"-RequiredRole", "server,hc1"
	))

	$missingManifest = Join-Path $tempRoot "missing-manifest.json"
	Write-JsonFile -Path $missingManifest -Value ([pscustomobject][ordered]@{
		schema = "a2waspwarfare-runtime-evidence-manifest-v1"
		evidence = @($rows[0])
	})
	$missingText = Invoke-ManifestTest -Arguments @(
		"-ManifestPath", $missingManifest,
		"-ExpectedCandidate", "test-candidate",
		"-ExpectedGit", "testgit",
		"-ExpectedArchiveSha256", "ABCDEF0123456789",
		"-RequiredTerrain", "chernarus,takistan",
		"-RequiredRole", "server,hc1"
	) -ExpectFailure
	if ($missingText -notmatch "Missing valid runtime evidence slot") {
		throw "Expected missing-slot failure text, got: $missingText"
	}

	$badSweepName = "bad-sweep.json"
	Write-JsonFile -Path (Join-Path $tempRoot $badSweepName) -Value (New-Sweep -Terrain "chernarus" -Git "wronggit")
	$badManifest = Join-Path $tempRoot "bad-manifest.json"
	Write-JsonFile -Path $badManifest -Value ([pscustomobject][ordered]@{
		schema = "a2waspwarfare-runtime-evidence-manifest-v1"
		evidence = @([pscustomobject][ordered]@{
			terrain = "chernarus"
			role = "server"
			markerSweepPath = $badSweepName
		})
	})
	$badText = Invoke-ManifestTest -Arguments @(
		"-ManifestPath", $badManifest,
		"-ExpectedCandidate", "test-candidate",
		"-ExpectedGit", "testgit",
		"-ExpectedArchiveSha256", "ABCDEF0123456789",
		"-RequiredTerrain", "chernarus",
		"-RequiredRole", "server"
	) -ExpectFailure
	if ($badText -notmatch "git mismatch") {
		throw "Expected git-mismatch failure text, got: $badText"
	}

	$releaseMismatchManifest = Join-Path $tempRoot "release-mismatch-manifest.json"
	Write-JsonFile -Path $releaseMismatchManifest -Value ([pscustomobject][ordered]@{
		schema = "a2waspwarfare-runtime-evidence-manifest-v1"
		release = [pscustomobject][ordered]@{
			candidate = "test-candidate"
			git = "wronggit"
			archiveSha256 = "ABCDEF0123456789"
		}
		evidence = @([pscustomobject][ordered]@{
			terrain = "chernarus"
			role = "server"
			markerSweepPath = "sweep-chernarus-server-mismatch.json"
		})
	})
	Write-JsonFile -Path (Join-Path $tempRoot "sweep-chernarus-server-mismatch.json") -Value (New-Sweep -Terrain "chernarus")
	$releaseMismatchText = Invoke-ManifestTest -Arguments @(
		"-ManifestPath", $releaseMismatchManifest,
		"-ExpectedCandidate", "test-candidate",
		"-ExpectedGit", "testgit",
		"-ExpectedArchiveSha256", "ABCDEF0123456789",
		"-RequiredTerrain", "chernarus",
		"-RequiredRole", "server"
	) -ExpectFailure
	if ($releaseMismatchText -notmatch "release.git") {
		throw "Expected release.git mismatch failure text, got: $releaseMismatchText"
	}

	$missingRequiredSweepName = "missing-required-sweep.json"
	Write-JsonFile -Path (Join-Path $tempRoot $missingRequiredSweepName) -Value (New-Sweep -Terrain "chernarus" -MissingRequired @("HCSTAT"))
	$missingRequiredManifest = Join-Path $tempRoot "missing-required-manifest.json"
	Write-JsonFile -Path $missingRequiredManifest -Value ([pscustomobject][ordered]@{
		schema = "a2waspwarfare-runtime-evidence-manifest-v1"
		evidence = @([pscustomobject][ordered]@{
			terrain = "chernarus"
			role = "server"
			markerSweepPath = $missingRequiredSweepName
		})
	})
	$missingRequiredText = Invoke-ManifestTest -Arguments @(
		"-ManifestPath", $missingRequiredManifest,
		"-ExpectedCandidate", "test-candidate",
		"-ExpectedGit", "testgit",
		"-ExpectedArchiveSha256", "ABCDEF0123456789",
		"-RequiredTerrain", "chernarus",
		"-RequiredRole", "server"
	) -ExpectFailure
	if ($missingRequiredText -notmatch "missing required markers") {
		throw "Expected missing-required failure text, got: $missingRequiredText"
	}

	Write-Host "Test-WaspRuntimeEvidenceManifest.SelfTest: PASS"
} finally {
	if ((Test-Path -LiteralPath $tempRoot) -and $tempFull.StartsWith($safeTempPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
		Remove-Item -LiteralPath $tempRoot -Recurse -Force
	}
}
