[CmdletBinding()]
param(
	[string]$ArchivePath = "",
	[string]$ExpectedCandidate = "release-command-center-20260630",
	[string]$ExpectedGit = "",
	[string]$SevenZipPath = ""
)

$ErrorActionPreference = "Stop"

function Find-RepoRoot {
	$dir = (Get-Item -LiteralPath $PSScriptRoot).FullName
	while ($true) {
		$mission = Join-Path $dir "Missions\[55-2hc]warfarev2_073v48co.chernarus"
		$loadout = Join-Path $dir "Tools\LoadoutManager"
		if ((Test-Path -LiteralPath $mission) -and (Test-Path -LiteralPath $loadout)) { return $dir }
		$parent = Split-Path -Parent $dir
		if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $dir) { throw "Could not find repository root from $PSScriptRoot" }
		$dir = $parent
	}
}

function Find-SevenZip {
	param([string]$Requested)
	$candidates = @()
	if (![string]::IsNullOrWhiteSpace($Requested)) { $candidates += $Requested }
	if (![string]::IsNullOrWhiteSpace($env:7za)) { $candidates += $env:7za }
	foreach ($name in @("7za", "7z")) {
		$cmd = Get-Command $name -ErrorAction SilentlyContinue
		if ($cmd) { $candidates += $cmd.Source }
	}
	$candidates += @(
		"C:\Program Files\7-Zip\7z.exe",
		"C:\Program Files\7-Zip\7za.exe",
		"C:\Program Files (x86)\7-Zip\7z.exe",
		"C:\Program Files (x86)\7-Zip\7za.exe",
		"C:\ProgramData\chocolatey\bin\7z.exe",
		"C:\ProgramData\chocolatey\bin\7za.exe"
	)
	foreach ($candidate in ($candidates | Where-Object { ![string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)) {
		if (Test-Path -LiteralPath $candidate) { return (Resolve-Path -LiteralPath $candidate).Path }
	}
	return ""
}

function Invoke-NativeChecked {
	param([string]$Exe, [string[]]$Arguments)
	$oldErrorActionPreference = $ErrorActionPreference
	$ErrorActionPreference = "Continue"
	try {
		$output = & $Exe @Arguments 2>&1
		$exitCode = $LASTEXITCODE
	} finally {
		$ErrorActionPreference = $oldErrorActionPreference
	}
	$outputLines = @($output | ForEach-Object { $_.ToString() })
	if ($exitCode -ne 0) {
		throw "Command failed with exit code $exitCode`: $Exe $($Arguments -join ' ')`n$($outputLines -join "`n")"
	}
	return $outputLines
}

function Invoke-PackageValidator {
	param(
		[string]$ValidatorPath,
		[string]$Archive,
		[string]$OutDirectory,
		[string]$Candidate,
		[string]$Git,
		[switch]$NoFail
	)
	$pwsh = (Get-Process -Id $PID).Path
	if ([string]::IsNullOrWhiteSpace($pwsh)) { $pwsh = "powershell.exe" }
	$args = @(
		"-NoProfile",
		"-ExecutionPolicy", "Bypass",
		"-File", $ValidatorPath,
		"-ArchivePath", $Archive,
		"-ExpectedCandidate", $Candidate,
		"-ExpectedGit", $Git,
		"-OutDirectory", $OutDirectory,
		"-Force"
	)
	if ($NoFail) { $args += "-NoFail" }
	Invoke-NativeChecked $pwsh $args | Out-Null
	return (Get-Content -Raw -LiteralPath (Join-Path $OutDirectory "release-package-manifest.json") | ConvertFrom-Json)
}

function Assert-Condition {
	param([bool]$Condition, [string]$Message)
	if (!$Condition) { throw $Message }
}

$repoRoot = Find-RepoRoot
$validatorPath = Join-Path $PSScriptRoot "Test-WaspReleasePackage.ps1"
if ([string]::IsNullOrWhiteSpace($ArchivePath)) {
	$ArchivePath = Join-Path $repoRoot "_MISSIONS.7z"
}
if (!(Test-Path -LiteralPath $ArchivePath)) {
	throw "Release package archive not found for package self-test: $ArchivePath"
}
$ArchivePath = (Resolve-Path -LiteralPath $ArchivePath).Path

if ([string]::IsNullOrWhiteSpace($ExpectedGit)) {
	$ExpectedGit = ((& git -C $repoRoot rev-parse --short=10 HEAD) | Select-Object -First 1).ToString().Trim()
	if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($ExpectedGit)) { throw "Could not read current HEAD short hash." }
}

$sevenZip = Find-SevenZip $SevenZipPath
if ([string]::IsNullOrWhiteSpace($sevenZip)) { throw "7-Zip executable not found. Pass -SevenZipPath or set env:7za." }

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("wasp-release-package-selftest-" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
	$goodOut = Join-Path $tempRoot "good"
	$good = Invoke-PackageValidator $validatorPath $ArchivePath $goodOut $ExpectedCandidate $ExpectedGit
	Assert-Condition ([string]$good.overall -eq "pass") "Expected current release package to pass package provenance self-test."
	$goodPayloadGate = @($good.gates | Where-Object { $_.id -eq "git-tracked-mission-payload" } | Select-Object -First 1)
	Assert-Condition ($goodPayloadGate.Count -eq 1 -and [string]$goodPayloadGate[0].status -eq "pass") "Expected current package payload gate to pass."

	$badExtraArchive = Join-Path $tempRoot "bad-extra.7z"
	Copy-Item -LiteralPath $ArchivePath -Destination $badExtraArchive -Force
	$extraRoot = Join-Path $tempRoot "[55-2hc]warfarev2_073v48co.chernarus"
	New-Item -ItemType Directory -Path $extraRoot -Force | Out-Null
	Set-Content -LiteralPath (Join-Path $extraRoot "stray-untracked-release-file.txt") -Value "package self-test stray file" -Encoding ASCII
	Push-Location $tempRoot
	try {
		Invoke-NativeChecked $sevenZip @("a", "-y", $badExtraArchive, "[55-2hc]warfarev2_073v48co.chernarus\stray-untracked-release-file.txt") | Out-Null
	} finally {
		Pop-Location
	}
	$badExtra = Invoke-PackageValidator $validatorPath $badExtraArchive (Join-Path $tempRoot "bad-extra") $ExpectedCandidate $ExpectedGit -NoFail
	$badExtraGate = @($badExtra.gates | Where-Object { $_.id -eq "git-tracked-mission-payload" } | Select-Object -First 1)
	Assert-Condition ([string]$badExtra.overall -ne "pass") "Expected package with stray untracked file to fail overall."
	Assert-Condition ($badExtraGate.Count -eq 1 -and [string]$badExtraGate[0].status -eq "fail") "Expected package with stray untracked file to fail payload gate."
	Assert-Condition (@($badExtra.gitTrackedPayload.unexpectedMissionFiles | Where-Object { $_ -like "*stray-untracked-release-file.txt" }).Count -eq 1) "Expected stray untracked file to be reported."

	$badHashArchive = Join-Path $tempRoot "bad-hash.7z"
	Copy-Item -LiteralPath $ArchivePath -Destination $badHashArchive -Force
	$hashRoot = Join-Path $tempRoot "[55-2hc]warfarev2_073v48co.chernarus"
	New-Item -ItemType Directory -Path $hashRoot -Force | Out-Null
	Set-Content -LiteralPath (Join-Path $hashRoot "description.ext") -Value "package self-test stale tracked content" -Encoding ASCII
	Push-Location $tempRoot
	try {
		Invoke-NativeChecked $sevenZip @("a", "-y", $badHashArchive, "[55-2hc]warfarev2_073v48co.chernarus\description.ext") | Out-Null
	} finally {
		Pop-Location
	}
	$badHash = Invoke-PackageValidator $validatorPath $badHashArchive (Join-Path $tempRoot "bad-hash") $ExpectedCandidate $ExpectedGit -NoFail
	$badHashGate = @($badHash.gates | Where-Object { $_.id -eq "git-tracked-mission-payload" } | Select-Object -First 1)
	Assert-Condition ([string]$badHash.overall -ne "pass") "Expected package with stale tracked content to fail overall."
	Assert-Condition ($badHashGate.Count -eq 1 -and [string]$badHashGate[0].status -eq "fail") "Expected package with stale tracked content to fail payload gate."
	Assert-Condition (@($badHash.gitTrackedPayload.hashMismatches | Where-Object { $_ -like "*description.ext*" }).Count -eq 1) "Expected stale tracked content to be reported as a hash mismatch."

	Write-Host "PASS package self-test: git-tracked mission payload gate rejects stray and stale archive content."
} finally {
	if (Test-Path -LiteralPath $tempRoot) {
		Remove-Item -LiteralPath $tempRoot -Recurse -Force
	}
}
