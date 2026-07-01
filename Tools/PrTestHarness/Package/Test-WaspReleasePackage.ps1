[CmdletBinding()]
param(
	[string]$ArchivePath = "",
	[string]$ExpectedCandidate = "release-command-center-20260630",
	[string]$ExpectedGit = "",
	[string[]]$ExpectedMarker = @(),
	[string]$OutDirectory = "",
	[string]$SevenZipPath = "",
	[switch]$Force,
	[switch]$NoFail
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

function ConvertTo-SafePath {
	param([string]$Path)
	$safe = $Path
	if (![string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
		$safe = $safe -replace [regex]::Escape($env:USERPROFILE), "%USERPROFILE%"
	}
	return $safe
}

function ConvertTo-ArchivePath {
	param([string]$Path)
	if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
	return (($Path -replace "\\", "/").TrimStart("/"))
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

function Invoke-SevenZip {
	param([string]$SevenZip, [string[]]$Arguments)
	$oldErrorActionPreference = $ErrorActionPreference
	$ErrorActionPreference = "Continue"
	try {
		$output = & $SevenZip @Arguments 2>&1
		$exitCode = $LASTEXITCODE
	} finally {
		$ErrorActionPreference = $oldErrorActionPreference
	}
	$outputLines = @($output | ForEach-Object { $_.ToString() })
	if ($exitCode -ne 0) {
		throw "7-Zip failed with exit code $exitCode while running: $SevenZip $($Arguments -join ' ')`n$($outputLines -join "`n")"
	}
	return $outputLines
}

function Invoke-GitShortHead {
	param([string]$RepoRoot)
	$output = & git -C $RepoRoot rev-parse --short=10 HEAD 2>$null
	if ($LASTEXITCODE -ne 0 -or !$output) { return "" }
	return (($output | Select-Object -First 1).ToString().Trim())
}

function Read-ArchiveListing {
	param([string]$SevenZip, [string]$Archive)
	$listOutput = Invoke-SevenZip $SevenZip @("l", "-slt", $Archive)
	$entries = New-Object System.Collections.Generic.List[object]
	$current = $null

	foreach ($line in $listOutput) {
		if ($line -match "^Path = (.*)$") {
			if ($null -ne $current -and ![string]::IsNullOrWhiteSpace($current.path)) {
				$entries.Add($current)
			}
			$current = [ordered]@{
				path = ConvertTo-ArchivePath $matches[1]
				isFolder = $false
				attributes = ""
				size = $null
				modified = ""
			}
			continue
		}
		if ($null -eq $current) { continue }
		if ($line -match "^Folder = (.+)$") {
			$current["isFolder"] = ($matches[1].Trim() -eq "+")
		} elseif ($line -match "^Attributes = (.*)$") {
			$current["attributes"] = $matches[1].Trim()
			if ($current["attributes"] -match "D") { $current["isFolder"] = $true }
		} elseif ($line -match "^Size = (\d+)$") {
			$current["size"] = [int64]$matches[1]
		} elseif ($line -match "^Modified = (.+)$") {
			$current["modified"] = $matches[1].Trim()
		}
	}

	if ($null -ne $current -and ![string]::IsNullOrWhiteSpace($current.path)) {
		$entries.Add($current)
	}

	return $entries.ToArray()
}

function Find-EntryRecordBySuffix {
	param([object[]]$Entries, [string]$Suffix)
	$wanted = ConvertTo-ArchivePath $Suffix
	$matches = @($Entries | Where-Object {
		!$_.isFolder -and ($_.path -eq $wanted -or $_.path.EndsWith("/$wanted"))
	})
	if ($matches.Count -eq 0) { return $null }
	return $matches[0]
}

function Add-Gate {
	param(
		[System.Collections.Generic.List[object]]$Gates,
		[string]$Id,
		[string]$Status,
		[string[]]$Missing = @(),
		[string[]]$FailHits = @(),
		[string]$Note = ""
	)
	$Gates.Add([ordered]@{
		id = $Id
		status = $Status
		missing = @($Missing)
		failHits = @($FailHits)
		note = $Note
	})
}

function Escape-MarkdownCell {
	param([string]$Text)
	if ([string]::IsNullOrWhiteSpace($Text)) { return "-" }
	return (($Text -replace "\|", "\|") -replace "`r?`n", " ")
}

function New-SafeTemporaryDirectory {
	$root = [System.IO.Path]::GetTempPath()
	$path = Join-Path $root ("wasp-release-package-" + [System.Guid]::NewGuid().ToString("N"))
	return (New-Item -ItemType Directory -Path $path -Force).FullName
}

function Remove-SafeTemporaryDirectory {
	param([string]$Path)
	if ([string]::IsNullOrWhiteSpace($Path)) { return }
	$resolved = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
	if (!$resolved) { return }
	$tempRoot = [System.IO.Path]::GetTempPath()
	if (!$resolved.Path.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
		throw "Refusing to remove temporary directory outside the system temp path: $($resolved.Path)"
	}
	Remove-Item -LiteralPath $resolved.Path -Recurse -Force
}

function Split-ReleaseMarker {
	param([string]$Marker)
	if ([string]::IsNullOrWhiteSpace($Marker)) {
		return [ordered]@{ valid = $false; schema = ""; candidate = ""; git = ""; terrain = ""; reason = "missing" }
	}
	if ($Marker -match "^WASPRELEASE\|v1\|candidate=([^|]+)\|git=([^|]+)\|terrain=([^|]+)$") {
		return [ordered]@{
			valid = $true
			schema = "WASPRELEASE|v1"
			candidate = $matches[1]
			git = $matches[2]
			terrain = $matches[3]
			reason = ""
		}
	}
	return [ordered]@{ valid = $false; schema = ""; candidate = ""; git = ""; terrain = ""; reason = "malformed" }
}

function Invoke-GitLines {
	param([string]$RepoRoot, [string[]]$Arguments)
	$output = & git -C $RepoRoot @Arguments 2>&1
	$exitCode = $LASTEXITCODE
	$outputLines = @($output | ForEach-Object { $_.ToString() })
	if ($exitCode -ne 0) {
		throw "git failed with exit code $exitCode while running: git -C $RepoRoot $($Arguments -join ' ')`n$($outputLines -join "`n")"
	}
	return $outputLines
}

$repoRoot = Find-RepoRoot
if ([string]::IsNullOrWhiteSpace($ArchivePath)) {
	$ArchivePath = Join-Path $repoRoot "_MISSIONS.7z"
}
if (!(Test-Path -LiteralPath $ArchivePath)) {
	throw "Release package archive not found: $ArchivePath"
}
$ArchivePath = (Resolve-Path -LiteralPath $ArchivePath).Path

$sevenZip = Find-SevenZip $SevenZipPath
if ([string]::IsNullOrWhiteSpace($sevenZip)) {
	throw "7-Zip executable not found. Pass -SevenZipPath or set env:7za."
}

if ([string]::IsNullOrWhiteSpace($ExpectedGit)) {
	$ExpectedGit = Invoke-GitShortHead $repoRoot
}
if ([string]::IsNullOrWhiteSpace($ExpectedGit)) {
	throw "Expected git hash was not provided and could not be read from HEAD."
}

if ([string]::IsNullOrWhiteSpace($OutDirectory)) {
	$OutDirectory = Join-Path (Get-Location).Path "wasp-release-package-manifest"
}
if (Test-Path -LiteralPath $OutDirectory) {
	$OutDirectory = (Resolve-Path -LiteralPath $OutDirectory).Path
} else {
	$OutDirectory = (New-Item -ItemType Directory -Path $OutDirectory -Force).FullName
}

$jsonOut = Join-Path $OutDirectory "release-package-manifest.json"
$markdownOut = Join-Path $OutDirectory "release-package-manifest.md"
if (!$Force) {
	foreach ($candidate in @($jsonOut, $markdownOut)) {
		if (Test-Path -LiteralPath $candidate) { throw "Output already exists: $candidate. Pass -Force to overwrite." }
	}
}

$archiveItem = Get-Item -LiteralPath $ArchivePath
$archiveHash = Get-FileHash -Algorithm SHA256 -LiteralPath $ArchivePath
$entryRecords = @(Read-ArchiveListing $sevenZip $ArchivePath | Where-Object {
	$_.path -and $_.path -notmatch "^[A-Za-z]:"
})

$expectedRoots = @(
	"[55-2hc]warfarev2_073v48co.chernarus",
	"[61-2hc]warfarev2_073v48co.takistan"
)
$topLevelRoots = @($entryRecords | ForEach-Object { ($_.path -split "/")[0] } | Where-Object { $_ } | Select-Object -Unique | Sort-Object)
$missingRoots = @($expectedRoots | Where-Object { $_ -notin $topLevelRoots })
$unexpectedRoots = @($topLevelRoots | Where-Object { $_ -notin $expectedRoots })
$missionFileEntries = @($entryRecords | Where-Object {
	!$_.isFolder -and $_.path -and (($expectedRoots -contains (($_.path -split "/")[0])))
})

$requiredRelativeFiles = @(
	"mission.sqm",
	"version.sqf",
	"description.ext",
	"initJIPCompatible.sqf",
	"stringtable.xml",
	"Client/Init/Init_Client.sqf",
	"Server/Init/Init_Server.sqf",
	"Headless/Init/Init_HC.sqf",
	"Common/Init/Init_Common.sqf",
	"Rsc/Parameters.hpp"
)
$missions = @(
	[ordered]@{ terrain = "chernarus"; archiveRoot = "[55-2hc]warfarev2_073v48co.chernarus"; repoRoot = "Missions/[55-2hc]warfarev2_073v48co.chernarus" },
	[ordered]@{ terrain = "takistan"; archiveRoot = "[61-2hc]warfarev2_073v48co.takistan"; repoRoot = "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan" }
)

$generatedArchiveAllowances = @($missions | ForEach-Object { "$($_.archiveRoot)/version.sqf" })
$gitTrackedArchiveToRepoPath = [ordered]@{}
foreach ($mission in $missions) {
	$trackedFiles = @(Invoke-GitLines $repoRoot @("ls-files", "--", $mission.repoRoot) | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
	foreach ($repoPath in $trackedFiles) {
		$repoPath = ConvertTo-ArchivePath $repoPath
		$prefix = (ConvertTo-ArchivePath $mission.repoRoot) + "/"
		if (!$repoPath.StartsWith($prefix, [System.StringComparison]::Ordinal)) { continue }
		$relativePath = $repoPath.Substring($prefix.Length)
		$archiveEntryPath = "$($mission.archiveRoot)/$relativePath"
		$gitTrackedArchiveToRepoPath[$archiveEntryPath] = $repoPath
	}
}

$archiveMissionFileSet = @{}
foreach ($entry in $missionFileEntries) { $archiveMissionFileSet[$entry.path] = $true }
$missingTrackedPayload = New-Object System.Collections.Generic.List[string]
foreach ($archiveEntryPath in $gitTrackedArchiveToRepoPath.Keys) {
	if (!$archiveMissionFileSet.ContainsKey($archiveEntryPath)) { $missingTrackedPayload.Add($archiveEntryPath) }
}
$unexpectedMissionPayload = New-Object System.Collections.Generic.List[string]
foreach ($archiveEntryPath in $archiveMissionFileSet.Keys) {
	if ($gitTrackedArchiveToRepoPath.Contains($archiveEntryPath)) { continue }
	if ($archiveEntryPath -in $generatedArchiveAllowances) { continue }
	$unexpectedMissionPayload.Add($archiveEntryPath)
}
$entriesToExtract = New-Object System.Collections.Generic.List[string]
$hashMismatches = New-Object System.Collections.Generic.List[string]
foreach ($archiveEntryPath in ($gitTrackedArchiveToRepoPath.Keys | Sort-Object)) {
	if ($archiveMissionFileSet.ContainsKey($archiveEntryPath)) { $entriesToExtract.Add($archiveEntryPath) }
}

$missingRequired = New-Object System.Collections.Generic.List[string]
foreach ($mission in $missions) {
	$requiredFiles = New-Object System.Collections.Generic.List[object]
	foreach ($relativeFile in $requiredRelativeFiles) {
		$suffix = "$($mission.archiveRoot)/$relativeFile"
		$record = Find-EntryRecordBySuffix $entryRecords $suffix
		if ($null -eq $record) {
			$missingRequired.Add($suffix)
			$requiredFiles.Add([ordered]@{
				path = ""
				relativePath = $relativeFile
				status = "missing"
				lengthBytes = $null
				sha256 = ""
			})
			continue
		}
		$entriesToExtract.Add($record.path)
		$requiredFiles.Add([ordered]@{
			path = $record.path
			relativePath = $relativeFile
			status = "present"
			lengthBytes = $record.size
			sha256 = ""
		})
	}
	$mission["requiredFiles"] = $requiredFiles.ToArray()
}

$markerFailures = New-Object System.Collections.Generic.List[string]
$markerValues = @()
$tempDirectory = ""
try {
	$tempDirectory = New-SafeTemporaryDirectory
	if ($entriesToExtract.Count -gt 0) {
		Invoke-SevenZip $sevenZip @("x", "-y", "-o$tempDirectory", $ArchivePath) | Out-Null
	}

	foreach ($mission in $missions) {
		$marker = ""
		$markerLine = ""
		foreach ($file in $mission.requiredFiles) {
			if ($file["status"] -ne "present") { continue }
			$localRelative = $file["path"].Replace("/", [System.IO.Path]::DirectorySeparatorChar)
			$extractedPath = Join-Path $tempDirectory $localRelative
			if (!(Test-Path -LiteralPath $extractedPath)) {
				$file["status"] = "extract-missing"
				$markerFailures.Add("$($mission.terrain):extract-missing:$($file["relativePath"])")
				continue
			}
			$item = Get-Item -LiteralPath $extractedPath
			$file["lengthBytes"] = $item.Length
			$file["sha256"] = (Get-FileHash -Algorithm SHA256 -LiteralPath $extractedPath).Hash
			if ($file["relativePath"] -eq "version.sqf") {
				$content = Get-Content -LiteralPath $extractedPath -Raw
				foreach ($line in ($content -split "`r?`n")) {
					if ($line -match '#define\s+WF_RELEASE_MARKER\s+"([^"]+)"') {
						$markerLine = $line.Trim()
						$marker = $matches[1]
						break
					}
				}
			}
		}

		$parsed = Split-ReleaseMarker $marker
		if (!$parsed.valid) {
			$markerFailures.Add("$($mission.terrain):$($parsed.reason)")
		} else {
			if ($parsed.candidate -ne $ExpectedCandidate) { $markerFailures.Add("$($mission.terrain):candidate:$($parsed.candidate)") }
			if ($parsed.git -ne $ExpectedGit) { $markerFailures.Add("$($mission.terrain):git:$($parsed.git)") }
			if ($parsed.git -in @("unknown", "manual")) { $markerFailures.Add("$($mission.terrain):git-placeholder:$($parsed.git)") }
			if ($parsed.terrain -ne $mission.terrain) { $markerFailures.Add("$($mission.terrain):terrain:$($parsed.terrain)") }
		}
		foreach ($expected in $ExpectedMarker) {
			if ([string]::IsNullOrWhiteSpace($expected)) { continue }
			if ([string]::IsNullOrWhiteSpace($marker) -or !$marker.Contains($expected)) {
				$markerFailures.Add("$($mission.terrain):expected-marker:$expected")
			}
		}
		$mission["marker"] = [ordered]@{
			line = $markerLine
			value = $marker
			parsed = $parsed
		}
		if (![string]::IsNullOrWhiteSpace($marker)) { $markerValues += $marker }
	}

	foreach ($archiveEntryPath in ($gitTrackedArchiveToRepoPath.Keys | Sort-Object)) {
		if (!$archiveMissionFileSet.ContainsKey($archiveEntryPath)) { continue }
		$repoPath = [string]$gitTrackedArchiveToRepoPath[$archiveEntryPath]
		$localRelative = $archiveEntryPath.Replace("/", [System.IO.Path]::DirectorySeparatorChar)
		$extractedPath = Join-Path $tempDirectory $localRelative
		if (!(Test-Path -LiteralPath $extractedPath)) {
			$hashMismatches.Add("$($archiveEntryPath):extract-missing")
			continue
		}
		$headObject = (Invoke-GitLines $repoRoot @("rev-parse", "HEAD:$repoPath") | Select-Object -First 1).Trim()
		$archiveObject = (Invoke-GitLines $repoRoot @("hash-object", "--path=$repoPath", $extractedPath) | Select-Object -First 1).Trim()
		if ($headObject -ne $archiveObject) {
			$hashMismatches.Add("$($archiveEntryPath):head=$headObject archive=$archiveObject")
		}
	}
} finally {
	Remove-SafeTemporaryDirectory $tempDirectory
}

$candidateValues = @($missions | ForEach-Object { $_.marker.parsed.candidate } | Where-Object { $_ } | Select-Object -Unique)
$gitValues = @($missions | ForEach-Object { $_.marker.parsed.git } | Where-Object { $_ } | Select-Object -Unique)
$consistencyFailures = @()
if ($candidateValues.Count -gt 1) { $consistencyFailures += "candidate:$($candidateValues -join ',')" }
if ($gitValues.Count -gt 1) { $consistencyFailures += "git:$($gitValues -join ',')" }

$forbiddenPatterns = @(
	"(^|/)Tools/PrTestHarness(/|$)",
	"(^|/)\.git(/|$)",
	"(^|/)\.claude(/|$)",
	"(^|/)TempZippingDirectory(/|$)",
	"(^|/)Modded_Missions(/|$)",
	"(^|/)Missions(/|$)",
	"(^|/)Missions_Vanilla(/|$)",
	"(^|/)PromptLibrary(/|$)"
)
$forbiddenHits = @()
foreach ($entry in $entryRecords) {
	foreach ($pattern in $forbiddenPatterns) {
		if ($entry.path -match $pattern) { $forbiddenHits += $entry.path; break }
	}
}
$forbiddenHits = @($forbiddenHits | Select-Object -Unique | Sort-Object)

$gates = New-Object System.Collections.Generic.List[object]
Add-Gate $gates "archive-exists" "pass" @() @() "Archive file exists and was readable."
$rootStatus = if ($missingRoots.Count -eq 0 -and $unexpectedRoots.Count -eq 0) { "pass" } else { "fail" }
Add-Gate $gates "archive-roots" $rootStatus $missingRoots $unexpectedRoots "Archive root must contain only the Chernarus and Takistan mission folders."
$requiredStatus = if ($missingRequired.Count -eq 0) { "pass" } else { "missing" }
Add-Gate $gates "required-files" $requiredStatus ($missingRequired.ToArray()) @() "Each terrain must include the core boot, init, stringtable, mission, and parameter files."
$markerStatus = if ($markerFailures.Count -eq 0) { "pass" } else { "fail" }
Add-Gate $gates "release-marker" $markerStatus @() ($markerFailures.ToArray()) "Both generated version.sqf files must carry the expected candidate, HEAD git, and terrain marker."
$consistencyStatus = if ($consistencyFailures.Count -eq 0) { "pass" } else { "fail" }
Add-Gate $gates "marker-consistency" $consistencyStatus @() @($consistencyFailures) "Chernarus and Takistan markers must share candidate and git values."
$forbiddenStatus = if ($forbiddenHits.Count -eq 0) { "pass" } else { "fail" }
Add-Gate $gates "forbidden-content" $forbiddenStatus @() $forbiddenHits "Release package should not include harness, git, fleet, temp, source-root, prompt, or modded-mission folders."
$payloadFailures = @($unexpectedMissionPayload.ToArray()) + @($hashMismatches.ToArray())
$payloadStatus = if ($missingTrackedPayload.Count -eq 0 -and $payloadFailures.Count -eq 0) { "pass" } elseif ($missingTrackedPayload.Count -gt 0) { "missing" } else { "fail" }
Add-Gate $gates "git-tracked-mission-payload" $payloadStatus ($missingTrackedPayload.ToArray()) $payloadFailures "Every archived mission file must be git-tracked at HEAD, except explicit generated allowances, and tracked file contents must hash back to HEAD."

$overallPass = (@($gates | Where-Object { $_.status -ne "pass" }).Count -eq 0)
$manifest = [ordered]@{
	schema = "a2waspwarfare-release-package-provenance-v1"
	generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
	expectedCandidate = $ExpectedCandidate
	expectedGit = $ExpectedGit
	archive = [ordered]@{
		path = ConvertTo-SafePath $ArchivePath
		name = $archiveItem.Name
		lengthBytes = $archiveItem.Length
		lastWriteTime = $archiveItem.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:sszzz")
		sha256 = $archiveHash.Hash
	}
	sevenZip = [ordered]@{
		path = ConvertTo-SafePath $sevenZip
	}
	entryCount = $entryRecords.Count
	topLevelRoots = $topLevelRoots
	missions = $missions
	forbiddenHits = $forbiddenHits
	gitTrackedPayload = [ordered]@{
		expectedTrackedFileCount = $gitTrackedArchiveToRepoPath.Count
		archiveMissionFileCount = $missionFileEntries.Count
		generatedAllowances = $generatedArchiveAllowances
		missingTrackedFiles = $missingTrackedPayload.ToArray()
		unexpectedMissionFiles = $unexpectedMissionPayload.ToArray()
		hashMismatches = $hashMismatches.ToArray()
	}
	gates = $gates.ToArray()
	overall = if ($overallPass) { "pass" } else { "missing_or_failed" }
	privacy = "No mission file contents are emitted except generated release marker strings from version.sqf; local user profile paths are redacted."
}
$manifest | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $jsonOut -Encoding UTF8

$lines = New-Object System.Collections.Generic.List[string]
[void]$lines.Add("# WASP Release Package Provenance")
[void]$lines.Add("")
[void]$lines.Add(("Generated: {0}" -f $manifest.generatedAt))
[void]$lines.Add(("Overall: {0}" -f $manifest.overall))
[void]$lines.Add(("Expected candidate: {0}" -f $manifest.expectedCandidate))
[void]$lines.Add(("Expected git: {0}" -f $manifest.expectedGit))
[void]$lines.Add(("Archive: {0}" -f $manifest.archive.path))
[void]$lines.Add(("Size: {0} bytes" -f $manifest.archive.lengthBytes))
[void]$lines.Add(("SHA256: {0}" -f $manifest.archive.sha256))
[void]$lines.Add(("Entries: {0}" -f $manifest.entryCount))
[void]$lines.Add("")
[void]$lines.Add("## Gate Results")
[void]$lines.Add("")
[void]$lines.Add("| Gate | Status | Missing | Fail Hits |")
[void]$lines.Add("| --- | --- | --- | --- |")
foreach ($gate in $gates) {
	[void]$lines.Add(("| {0} | {1} | {2} | {3} |" -f `
		(Escape-MarkdownCell $gate.id), `
		(Escape-MarkdownCell $gate.status), `
		(Escape-MarkdownCell (($gate.missing | Where-Object { $_ }) -join ", ")), `
		(Escape-MarkdownCell (($gate.failHits | Where-Object { $_ }) -join ", "))))
}
[void]$lines.Add("")
[void]$lines.Add("## Mission Markers")
[void]$lines.Add("")
[void]$lines.Add("| Terrain | Root | Marker |")
[void]$lines.Add("| --- | --- | --- |")
foreach ($mission in $missions) {
	[void]$lines.Add(("| {0} | {1} | {2} |" -f `
		(Escape-MarkdownCell $mission.terrain), `
		(Escape-MarkdownCell $mission.archiveRoot), `
		(Escape-MarkdownCell $mission.marker.value)))
}
[void]$lines.Add("")
[void]$lines.Add("## Required File Hashes")
[void]$lines.Add("")
[void]$lines.Add("| Terrain | Relative Path | Bytes | SHA256 |")
[void]$lines.Add("| --- | --- | ---: | --- |")
foreach ($mission in $missions) {
	foreach ($file in $mission.requiredFiles) {
		[void]$lines.Add(("| {0} | {1} | {2} | {3} |" -f `
			(Escape-MarkdownCell $mission.terrain), `
			(Escape-MarkdownCell $file.relativePath), `
			(Escape-MarkdownCell ([string]$file.lengthBytes)), `
			(Escape-MarkdownCell $file.sha256)))
	}
}
[void]$lines.Add("")
[void]$lines.Add("Privacy: no mission file contents are emitted beyond generated release marker strings; user-profile paths are redacted.")
$lines | Set-Content -LiteralPath $markdownOut -Encoding UTF8

Write-Host "Wrote release package provenance:"
Write-Host $jsonOut
Write-Host $markdownOut

if (!$overallPass -and !$NoFail) { exit 1 }
