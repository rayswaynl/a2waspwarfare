[CmdletBinding()]
param(
	[switch]$KeepTemp
)

$ErrorActionPreference = "Stop"

$handoffPath = Join-Path $PSScriptRoot "New-WaspReleaseHandoff.ps1"
if (!(Test-Path -LiteralPath $handoffPath -PathType Leaf)) {
	throw "Release handoff generator not found: $handoffPath"
}

$candidate = "release-command-center-20260630"
$releaseGit = "selftest36"
$terrains = @("chernarus", "takistan")

function Assert-True {
	param([bool]$Condition, [string]$Message)
	if (!$Condition) { throw $Message }
}

function Assert-Equal {
	param([string]$Actual, [string]$Expected, [string]$Message)
	if ($Actual -ne $Expected) {
		throw ("{0} Expected '{1}', got '{2}'." -f $Message, $Expected, $Actual)
	}
}

function Assert-Contains {
	param([string]$Text, [string]$Expected, [string]$Message)
	if ($Text -notmatch [regex]::Escape($Expected)) {
		throw ("{0} Missing '{1}' in '{2}'." -f $Message, $Expected, $Text)
	}
}

function Get-Gate {
	param($Packet, [string]$Id)
	$matches = @($Packet.gates | Where-Object { [string]$_.id -eq $Id })
	if ($matches.Count -eq 0) { throw "Gate '$Id' not found in handoff packet." }
	return $matches[0]
}

function Assert-GateStatus {
	param($Packet, [string]$Id, [string]$ExpectedStatus)
	$gate = Get-Gate -Packet $Packet -Id $Id
	Assert-Equal ([string]$gate.status) $ExpectedStatus "Unexpected status for gate '$Id'."
}

function Get-CurrentPowerShellExe {
	$path = (Get-Process -Id $PID).Path
	if (![string]::IsNullOrWhiteSpace($path) -and (Test-Path -LiteralPath $path -PathType Leaf)) { return $path }
	if ($PSVersionTable.PSEdition -eq "Core") { return "pwsh" }
	return "powershell"
}

function Invoke-HandoffChild {
	param([string[]]$Arguments)
	$exe = Get-CurrentPowerShellExe
	$output = & $exe -NoProfile -ExecutionPolicy Bypass -File $handoffPath @Arguments 2>&1
	return [ordered]@{
		exitCode = $LASTEXITCODE
		output = @($output)
	}
}

function New-TestPackageManifest {
	param(
		[Parameter(Mandatory)] [string]$Root,
		[Parameter(Mandatory)] [string]$ArchivePath
	)
	$archiveItem = Get-Item -LiteralPath $ArchivePath
	$archiveSha256 = (Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256).Hash.ToUpperInvariant()
	$missions = New-Object System.Collections.Generic.List[object]
	foreach ($terrain in $terrains) {
		[void]$missions.Add([ordered]@{
			terrain = $terrain
			marker = [ordered]@{
				value = "WASPRELEASE|v1|candidate=$candidate|git=$releaseGit|terrain=$terrain"
			}
		})
	}
	$manifest = [ordered]@{
		schema = "a2waspwarfare-release-package-manifest-v1"
		generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
		overall = "pass"
		expectedCandidate = $candidate
		expectedGit = $releaseGit
		archive = [ordered]@{
			path = $ArchivePath
			name = "_MISSIONS.7z"
			lengthBytes = [int64]$archiveItem.Length
			sha256 = $archiveSha256
		}
		entryCount = 1882
		topLevelRoots = @(
			"[55-2hc]warfarev2_073v48co.chernarus",
			"[61-2hc]warfarev2_073v48co.takistan"
		)
		missions = $missions.ToArray()
	}
	$manifestPath = Join-Path $Root "release-package-manifest.json"
	$manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
	Set-Content -LiteralPath (Join-Path $Root "release-package-manifest.md") -Encoding UTF8 -Value @(
		"# Synthetic Release Package Manifest",
		"",
		"Candidate: $candidate",
		"Git: $releaseGit",
		"SHA256: $archiveSha256"
	)
	return [ordered]@{
		path = $manifestPath
		sha256 = $archiveSha256
		lengthBytes = [int64]$archiveItem.Length
	}
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("wasp-release-handoff-selftest-" + [guid]::NewGuid().ToString("N"))
try {
	[void](New-Item -ItemType Directory -Path $tempRoot -Force)
	$archivePath = Join-Path $tempRoot "_MISSIONS.7z"
	Set-Content -LiteralPath $archivePath -Encoding UTF8 -Value @(
		"synthetic WASP release archive payload",
		"chernarus + takistan handoff self-test"
	)
	$manifestInfo = New-TestPackageManifest -Root $tempRoot -ArchivePath $archivePath
	$outDir = Join-Path $tempRoot "handoff"

	& $handoffPath -PackageManifestPath $manifestInfo.path -ExpectedCandidate $candidate -ReleaseGit $releaseGit -OutDirectory $outDir -AllowNonHeadReleaseGit -Force | Out-Null

	$jsonPath = Join-Path $outDir "release-handoff.json"
	$markdownPath = Join-Path $outDir "release-handoff.md"
	$sourceMapTemplatePath = Join-Path $outDir "runtime-rpt-source-map.template.json"
	$runLedgerTemplatePath = Join-Path $outDir "runtime-run-ledger.template.json"
	$copiedManifestJson = Join-Path $outDir "release-package-manifest.json"
	$copiedManifestMarkdown = Join-Path $outDir "release-package-manifest.md"
	foreach ($path in @($jsonPath, $markdownPath, $sourceMapTemplatePath, $runLedgerTemplatePath, $copiedManifestJson, $copiedManifestMarkdown)) {
		Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "Expected handoff artifact was not written: $path"
	}

	$packet = Get-Content -Raw -LiteralPath $jsonPath | ConvertFrom-Json
	Assert-Equal ([string]$packet.schema) "a2waspwarfare-release-handoff-v1" "Unexpected handoff schema."
	Assert-Equal ([string]$packet.status) "ready_for_runtime_collection" "Happy-path handoff should be ready for runtime collection."
	Assert-Equal ([string]$packet.release.candidate) $candidate "Release candidate mismatch."
	Assert-Equal ([string]$packet.release.git) $releaseGit "Release git mismatch."
	Assert-Equal ([string]$packet.package.sha256) $manifestInfo.sha256 "Package SHA mismatch."
	Assert-Equal ([string]$packet.runtimeRptSourceMapTemplate.release.archiveSha256) $manifestInfo.sha256 "Source-map template archive SHA mismatch."
	Assert-Equal ([string]$packet.runtimeRunLedgerTemplate.release.archiveSha256) $manifestInfo.sha256 "Run-ledger template archive SHA mismatch."
	Assert-Equal ([string]$packet.expectedRuntimeMarkers.chernarus) "WASPRELEASE|v1|candidate=$candidate|git=$releaseGit|terrain=chernarus" "Chernarus marker mismatch."
	Assert-Equal ([string]$packet.expectedRuntimeMarkers.takistan) "WASPRELEASE|v1|candidate=$candidate|git=$releaseGit|terrain=takistan" "Takistan marker mismatch."

	foreach ($gateId in @(
		"package-manifest-present",
		"package-manifest-markdown-present",
		"package-overall-pass",
		"candidate-match",
		"git-match",
		"release-git-matches-head",
		"chernarus-marker-match",
		"takistan-marker-match",
		"archive-file-present",
		"archive-length-match",
		"archive-sha256-match"
	)) {
		Assert-GateStatus -Packet $packet -Id $gateId -ExpectedStatus "pass"
	}
	foreach ($gateId in @("runtime-approval", "runtime-evidence", "deployment-approval")) {
		Assert-GateStatus -Packet $packet -Id $gateId -ExpectedStatus "pending"
	}
	$failedGates = @($packet.gates | Where-Object { [string]$_.status -eq "fail" })
	Assert-Equal ([string]$failedGates.Count) "0" "Happy-path handoff should not contain failed gates."

	Assert-Contains ([string]$packet.commands.runtimePacketBuilder) "-ExpectedCandidate $candidate" "Packet-builder command should bind candidate."
	Assert-Contains ([string]$packet.commands.runtimePacketBuilder) "-ExpectedGit $releaseGit" "Packet-builder command should bind git."
	Assert-Contains ([string]$packet.commands.runtimePacketBuilder) "-ExpectedArchiveSha256 $($manifestInfo.sha256)" "Packet-builder command should bind archive SHA."
	Assert-Contains ([string]$packet.commands.runtimePacketBuilder) "-RequireSourceRptExists" "Packet-builder command should require source RPTs."
	Assert-Contains ([string]$packet.commands.runtimePacket) "-RunLedgerPath" "Packet validator command should include run ledger."
	Assert-Contains ([string]$packet.commands.runtimePacket) "-ExpectedCandidate $candidate" "Packet validator command should bind candidate."
	Assert-Contains ([string]$packet.commands.runtimePacket) "-ExpectedGit $releaseGit" "Packet validator command should bind git."
	Assert-Contains ([string]$packet.commands.runtimePacket) "-ExpectedArchiveSha256 $($manifestInfo.sha256)" "Packet validator command should bind archive SHA."
	Assert-Contains ([string]$packet.commands.runtimePacket) "-RequireSourceRptExists" "Packet validator command should require source RPTs."
	Assert-Contains ([string]$packet.commands.runtimeSummary) "-RuntimePacketManifestPath" "Runtime summary command should include packet manifest path."
	Assert-Contains ([string]$packet.commands.runtimeSummary) "-ExpectedCandidate $candidate" "Runtime summary command should bind candidate."
	Assert-Contains ([string]$packet.commands.runtimeSummary) "-ExpectedGit $releaseGit" "Runtime summary command should bind git."
	Assert-Contains ([string]$packet.commands.runtimeSummary) "-ExpectedArchiveSha256 $($manifestInfo.sha256)" "Runtime summary command should bind archive SHA."
	Assert-Contains ([string]$packet.commands.runtimeSummary) "-RequireRuntimePacketManifest" "Runtime summary command should require packet manifest."

	$runtimeChecklistText = (($packet.runtimeChecklist | Out-String).Trim())
	Assert-Contains $runtimeChecklistText "Steff explicitly approves local Arma launch" "Runtime checklist should preserve approval boundary."
	Assert-Contains $runtimeChecklistText "validation.overall=pass" "Runtime checklist should require passing packet validation."
	Assert-Contains $runtimeChecklistText "all required packet-validator gates passing" "Runtime checklist should require packet validator gate proof."
	Assert-Contains $runtimeChecklistText "rptRootHash" "Runtime checklist should bind packet manifest to the scored RPT root."
	Assert-Contains $runtimeChecklistText "copiedRptSha256" "Runtime checklist should bind packet manifest hashes to scored RPT files."
	Assert-Contains $runtimeChecklistText "source-map release.candidate" "Runtime checklist should bind source-map release candidate."
	Assert-Contains $runtimeChecklistText "release.git" "Runtime checklist should bind release git."
	Assert-Contains $runtimeChecklistText "release.archiveSha256" "Runtime checklist should bind release summary to packet proof."

	$sourceMapTemplate = Get-Content -Raw -LiteralPath $sourceMapTemplatePath | ConvertFrom-Json
	$runLedgerTemplate = Get-Content -Raw -LiteralPath $runLedgerTemplatePath | ConvertFrom-Json
	Assert-Equal ([string]$sourceMapTemplate.release.candidate) $candidate "Written source-map template candidate mismatch."
	Assert-Equal ([string]$sourceMapTemplate.release.git) $releaseGit "Written source-map template git mismatch."
	Assert-Equal ([string]$sourceMapTemplate.release.archiveSha256) $manifestInfo.sha256 "Written source-map template archive SHA mismatch."
	Assert-Equal ([string]$runLedgerTemplate.release.candidate) $candidate "Written run-ledger template candidate mismatch."
	Assert-Equal ([string]$runLedgerTemplate.release.git) $releaseGit "Written run-ledger template git mismatch."
	Assert-Equal ([string]$runLedgerTemplate.release.archiveSha256) $manifestInfo.sha256 "Written run-ledger template archive SHA mismatch."
	Assert-Equal ([string](@($sourceMapTemplate.records).Count)) "10" "Source-map template should include ten runtime RPT records."
	Assert-Equal ([string](@($runLedgerTemplate.records).Count)) "10" "Run-ledger template should include ten runtime RPT records."

	$copiedManifest = Get-Content -Raw -LiteralPath $copiedManifestJson | ConvertFrom-Json
	Assert-Equal ([string]$copiedManifest.archive.sha256) $manifestInfo.sha256 "Copied package manifest SHA mismatch."

	$badArchiveRoot = Join-Path $tempRoot "bad-archive"
	[void](New-Item -ItemType Directory -Path $badArchiveRoot -Force)
	$badArchivePath = Join-Path $badArchiveRoot "_MISSIONS.7z"
	[System.IO.File]::WriteAllBytes($badArchivePath, [byte[]](65, 66, 67, 68))
	$badManifestInfo = New-TestPackageManifest -Root $badArchiveRoot -ArchivePath $badArchivePath
	[System.IO.File]::WriteAllBytes($badArchivePath, [byte[]](65, 66, 67, 69))
	$badOutDir = Join-Path $badArchiveRoot "handoff"
	$badResult = Invoke-HandoffChild @(
		"-PackageManifestPath", $badManifestInfo.path,
		"-ExpectedCandidate", $candidate,
		"-ReleaseGit", $releaseGit,
		"-OutDirectory", $badOutDir,
		"-AllowNonHeadReleaseGit",
		"-Force"
	)
	Assert-Equal ([string]$badResult.exitCode) "1" "Stale package handoff must exit nonzero."
	$badPacketPath = Join-Path $badOutDir "release-handoff.json"
	Assert-True (Test-Path -LiteralPath $badPacketPath -PathType Leaf) "Failed handoff should still write the diagnostic packet."
	$badPacket = Get-Content -Raw -LiteralPath $badPacketPath | ConvertFrom-Json
	Assert-Equal ([string]$badPacket.status) "needs_package_or_marker_fix" "Stale package handoff should not be runtime-ready."
	Assert-GateStatus -Packet $badPacket -Id "archive-length-match" -ExpectedStatus "pass"
	Assert-GateStatus -Packet $badPacket -Id "archive-sha256-match" -ExpectedStatus "fail"

	Write-Host "WASP release handoff self-test PASS."
} finally {
	if ($KeepTemp) {
		Write-Host "Kept temp fixture root: $tempRoot"
	} elseif (Test-Path -LiteralPath $tempRoot) {
		Remove-Item -LiteralPath $tempRoot -Recurse -Force
	}
}
