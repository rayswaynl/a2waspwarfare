[CmdletBinding()]
param(
	[string]$PackageManifestPath = "",
	[string]$ExpectedCandidate = "release-command-center-20260630",
	[string]$ReleaseGit = "",
	[string]$OutDirectory = "",
	[switch]$AllowNonHeadReleaseGit,
	[switch]$Force
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

function Get-SafeTextHash {
	param([string]$Text)
	if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
	$sha = [System.Security.Cryptography.SHA256]::Create()
	try {
		$bytes = [System.Text.Encoding]::UTF8.GetBytes($Text.ToLowerInvariant())
		$hash = $sha.ComputeHash($bytes)
		return ([System.BitConverter]::ToString($hash) -replace "-", "").Substring(0, 12)
	} finally {
		$sha.Dispose()
	}
}

function Resolve-ManifestArchivePath {
	param([string]$Path, [string]$RepoRoot)
	if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
	$expanded = [System.Environment]::ExpandEnvironmentVariables($Path)
	if ([System.IO.Path]::IsPathRooted($expanded)) {
		return [System.IO.Path]::GetFullPath($expanded)
	}
	return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $expanded))
}

function Get-FileSha256Value {
	param([string]$Path)
	if ([string]::IsNullOrWhiteSpace($Path) -or !(Test-Path -LiteralPath $Path -PathType Leaf)) { return "" }
	return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Escape-MarkdownCell {
	param([string]$Text)
	if ($null -eq $Text -or $Text.Length -eq 0) { return "-" }
	return (($Text -replace "\|", "\|") -replace "`r?`n", " ")
}

function ConvertTo-Array {
	param($Value)
	if ($null -eq $Value) { return @() }
	if ($Value -is [System.Array]) { return @($Value) }
	return @($Value)
}

function Invoke-GitValue {
	param([string]$RepoRoot, [string[]]$Arguments)
	$output = & git -C $RepoRoot @Arguments 2>$null
	if ($LASTEXITCODE -ne 0 -or !$output) { return "" }
	return (($output | Select-Object -First 1).ToString().Trim())
}

function Add-Gate {
	param($List, [string]$Id, [string]$Status, [string]$Note)
	[void]$List.Add([ordered]@{
		id = $Id
		status = $Status
		note = $Note
	})
}

function Resolve-PackageManifestPath {
	param([string]$Requested, [string]$RepoRoot)
	$candidates = @()
	if (![string]::IsNullOrWhiteSpace($Requested)) { $candidates += $Requested }
	$candidates += @(
		(Join-Path (Get-Location).Path "wasp-release-package-manifest\release-package-manifest.json"),
		(Join-Path $RepoRoot "wasp-release-package-manifest\release-package-manifest.json")
	)
	foreach ($candidate in $candidates) {
		if (![string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) {
			return (Resolve-Path -LiteralPath $candidate).Path
		}
	}
	throw "Package manifest not found. Run Tools\PrTestHarness\Package\Test-WaspReleasePackage.ps1 first or pass -PackageManifestPath."
}

function Get-MissionMarker {
	param($Manifest, [string]$Terrain)
	foreach ($mission in (ConvertTo-Array $Manifest.missions)) {
		if ([string]$mission.terrain -eq $Terrain) { return [string]$mission.marker.value }
	}
	return ""
}

$repoRoot = Find-RepoRoot
if ([string]::IsNullOrWhiteSpace($ReleaseGit)) {
	$ReleaseGit = Invoke-GitValue $repoRoot @("rev-parse", "--short=10", "HEAD")
}
if ([string]::IsNullOrWhiteSpace($ReleaseGit)) {
	throw "Could not determine release git short hash. Pass -ReleaseGit explicitly."
}

$fullHead = Invoke-GitValue $repoRoot @("rev-parse", "HEAD")
$branch = Invoke-GitValue $repoRoot @("branch", "--show-current")
$manifestPath = Resolve-PackageManifestPath $PackageManifestPath $repoRoot
$manifestMarkdownPath = [System.IO.Path]::ChangeExtension($manifestPath, ".md")
$manifestMarkdownExists = (Test-Path -LiteralPath $manifestMarkdownPath -PathType Leaf)
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$manifestArchivePath = Resolve-ManifestArchivePath ([string]$manifest.archive.path) $repoRoot
$manifestArchiveExists = (![string]::IsNullOrWhiteSpace($manifestArchivePath) -and (Test-Path -LiteralPath $manifestArchivePath -PathType Leaf))
$manifestArchiveLength = if ($manifestArchiveExists) { [int64](Get-Item -LiteralPath $manifestArchivePath).Length } else { -1 }
$manifestArchiveSha256 = Get-FileSha256Value $manifestArchivePath
$expectedArchiveLength = [int64]$manifest.archive.lengthBytes
$expectedArchiveSha256 = ([string]$manifest.archive.sha256).ToUpperInvariant()

$expectedMarkers = [ordered]@{
	chernarus = "WASPRELEASE|v1|candidate=$ExpectedCandidate|git=$ReleaseGit|terrain=chernarus"
	takistan = "WASPRELEASE|v1|candidate=$ExpectedCandidate|git=$ReleaseGit|terrain=takistan"
}

$actualMarkers = [ordered]@{
	chernarus = Get-MissionMarker $manifest "chernarus"
	takistan = Get-MissionMarker $manifest "takistan"
}

$gates = New-Object System.Collections.Generic.List[object]
Add-Gate $gates "package-manifest-present" "pass" "Package manifest was loaded."
Add-Gate $gates "package-manifest-markdown-present" ($(if ($manifestMarkdownExists) { "pass" } else { "fail" })) "Sibling release-package-manifest.md must travel with the JSON handoff artifact."
Add-Gate $gates "package-overall-pass" ($(if ([string]$manifest.overall -eq "pass") { "pass" } else { "fail" })) "Package manifest overall status must be pass."
Add-Gate $gates "candidate-match" ($(if ([string]$manifest.expectedCandidate -eq $ExpectedCandidate) { "pass" } else { "fail" })) "Package candidate must match the handoff candidate."
Add-Gate $gates "git-match" ($(if ([string]$manifest.expectedGit -eq $ReleaseGit) { "pass" } else { "fail" })) "Package git marker must match the current handoff git short hash."
Add-Gate $gates "release-git-matches-head" ($(if ($AllowNonHeadReleaseGit -or $fullHead.StartsWith($ReleaseGit, [System.StringComparison]::OrdinalIgnoreCase)) { "pass" } else { "fail" })) "Release git should be the current HEAD prefix unless -AllowNonHeadReleaseGit is explicitly used."
Add-Gate $gates "chernarus-marker-match" ($(if ($actualMarkers.chernarus -eq $expectedMarkers.chernarus) { "pass" } else { "fail" })) "Chernarus package marker must match the exact runtime marker."
Add-Gate $gates "takistan-marker-match" ($(if ($actualMarkers.takistan -eq $expectedMarkers.takistan) { "pass" } else { "fail" })) "Takistan package marker must match the exact runtime marker."
Add-Gate $gates "archive-file-present" ($(if ($manifestArchiveExists) { "pass" } else { "fail" })) "Manifest archive path must resolve to a readable local package archive before runtime handoff."
Add-Gate $gates "archive-length-match" ($(if ($manifestArchiveExists -and $manifestArchiveLength -eq $expectedArchiveLength) { "pass" } else { "fail" })) "Local package archive length must still match the package manifest."
Add-Gate $gates "archive-sha256-match" ($(if ($manifestArchiveExists -and $manifestArchiveSha256 -eq $expectedArchiveSha256) { "pass" } else { "fail" })) "Local package archive SHA256 must still match the package manifest."
Add-Gate $gates "runtime-evidence" "pending" "Fresh dual-terrain dedicated-server RPT evidence is still required."
Add-Gate $gates "deployment-approval" "pending" "Live server upload/restart/rollback still requires Steff approval."

$blockingFailures = @($gates.ToArray() | Where-Object { [string]$_.status -eq "fail" })
$handoffStatus = if ($blockingFailures.Count -eq 0) { "ready_for_runtime_collection" } else { "needs_package_or_marker_fix" }

if ([string]::IsNullOrWhiteSpace($OutDirectory)) {
	$OutDirectory = Join-Path (Get-Location).Path "wasp-release-handoff"
}
$outPath = $OutDirectory
if (Test-Path -LiteralPath $outPath) {
	$outPath = (Resolve-Path -LiteralPath $outPath).Path
} else {
	$outPath = (New-Item -ItemType Directory -Path $outPath -Force).FullName
}

$jsonOut = Join-Path $outPath "release-handoff.json"
$markdownOut = Join-Path $outPath "release-handoff.md"
$ledgerTemplateOut = Join-Path $outPath "runtime-run-ledger.template.json"
$sourceMapTemplateOut = Join-Path $outPath "runtime-rpt-source-map.template.json"
$manifestJsonOut = Join-Path $outPath "release-package-manifest.json"
$manifestMarkdownOut = Join-Path $outPath "release-package-manifest.md"
if (!$Force) {
	foreach ($candidate in @($jsonOut, $markdownOut, $ledgerTemplateOut, $sourceMapTemplateOut, $manifestJsonOut, $manifestMarkdownOut)) {
		if (Test-Path -LiteralPath $candidate) {
			throw "Output already exists: $candidate. Pass -Force to overwrite."
		}
	}
}

$markerArrayCommand = @(
	'$expectedReleaseMarkers = @(',
	('  "{0}",' -f $expectedMarkers.chernarus),
	('  "{0}"' -f $expectedMarkers.takistan),
	')'
) -join "`n"

$runLedgerRecords = New-Object System.Collections.Generic.List[object]
$sourceMapRecords = New-Object System.Collections.Generic.List[object]
foreach ($terrain in @("chernarus", "takistan")) {
	foreach ($role in @("server", "HC1", "HC2", "start-client", "late-JIP")) {
		$joinPhase = if ($role -eq "start-client" -or $role -eq "late-JIP") { $role } else { "" }
		[void]$runLedgerRecords.Add([ordered]@{
			terrain = $terrain
			role = $role
			terrainStartTime = "<$terrain-launch-time>"
			pid = "<process-pid>"
			commandLine = "<redacted-command-line>"
			profilePath = "<profile-or-log-root>"
			sourceRptPath = "<original-source-rpt-path>"
			sourceRptLastWriteTime = "<original-source-rpt-last-write-time>"
			sourceRptSha256 = "<original-source-rpt-sha256>"
			copiedRptPath = "$terrain\$role.rpt"
			copiedRptSha256 = "<copied-packet-rpt-sha256>"
			roleProof = $role
			joinPhase = $joinPhase
		})
		[void]$sourceMapRecords.Add([ordered]@{
			terrain = $terrain
			role = $role
			roleProof = $role
			joinPhase = $joinPhase
			terrainStartTime = "<$terrain-launch-time>"
			pid = "<process-pid>"
			commandLine = "<redacted-command-line>"
			profilePath = "<profile-or-log-root>"
			sourceRptPath = "<original-source-rpt-path>"
		})
	}
}

$packet = [ordered]@{
	schema = "a2waspwarfare-release-handoff-v1"
	generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
	status = $handoffStatus
	release = [ordered]@{
		candidate = $ExpectedCandidate
		git = $ReleaseGit
		fullHead = $fullHead
		branch = $branch
		repoRoot = "<repo-root>"
		repoRootHash = Get-SafeTextHash $repoRoot
	}
	package = [ordered]@{
		manifestPath = "release-package-manifest.json"
		manifestMarkdownPath = if ($manifestMarkdownExists) { "release-package-manifest.md" } else { "" }
		sourceManifestPathHash = Get-SafeTextHash $manifestPath
		overall = [string]$manifest.overall
		expectedGit = [string]$manifest.expectedGit
		archiveName = [string]$manifest.archive.name
		archivePath = ("<package-archive>\{0}" -f [string]$manifest.archive.name)
		archivePathHash = Get-SafeTextHash $manifestArchivePath
		lengthBytes = [int64]$manifest.archive.lengthBytes
		sha256 = [string]$manifest.archive.sha256
		entryCount = [int]$manifest.entryCount
		topLevelRoots = @(ConvertTo-Array $manifest.topLevelRoots)
	}
	expectedRuntimeMarkers = $expectedMarkers
	actualPackageMarkers = $actualMarkers
	gates = $gates.ToArray()
	commands = [ordered]@{
		markerArray = $markerArrayCommand
		runtimePacketBuilder = "& .\Tools\PrTestHarness\Rpt\New-WaspRuntimeRptPacket.ps1 -SourceMapPath `"<private-runtime-rpt-source-map.json>`" -OutDirectory `"<release-candidate-rpts>`" -ExpectedCandidate $ExpectedCandidate -ExpectedGit $ReleaseGit -ExpectedArchiveSha256 $expectedArchiveSha256 -Validate -RequireSourceRptExists -Force"
		runtimePacket = "& .\Tools\PrTestHarness\Rpt\Test-WaspRuntimeRptPacket.ps1 -RptRoot `"<release-candidate-rpts>`" -ExpectedCandidate $ExpectedCandidate -ExpectedGit $ReleaseGit -ExpectedArchiveSha256 $expectedArchiveSha256 -RunLedgerPath `"<release-candidate-rpts>\release-run-ledger.json`" -RequireSourceRptExists"
		runtimeScorer = "& .\Tools\PrTestHarness\Rpt\Test-WaspReleaseRptEvidence.ps1 -RptDirectory `"<release-candidate-rpts>`" -Recurse -ExpectedMarker `$expectedReleaseMarkers"
		runtimeSummary = "& .\Tools\PrTestHarness\Rpt\New-WaspReleaseRptSummary.ps1 -RptDirectory `"<release-candidate-rpts>`" -Recurse -ExpectedMarker `$expectedReleaseMarkers -RuntimePacketManifestPath `"<release-candidate-rpts>\runtime-rpt-packet-manifest.json`" -OutDirectory `"<release-candidate-rpts>\summary`" -Force"
		packageProof = "pwsh -NoProfile -ExecutionPolicy Bypass -File Tools\PrTestHarness\Package\Test-WaspReleasePackage.ps1 -ArchivePath .\_MISSIONS.7z -ExpectedCandidate $ExpectedCandidate -ExpectedGit $ReleaseGit -OutDirectory .\wasp-release-package-manifest -Force"
	}
	runtimeRptSourceMapTemplate = [ordered]@{
		schema = "a2waspwarfare-runtime-rpt-source-map-v1"
		release = [ordered]@{
			candidate = $ExpectedCandidate
			git = $ReleaseGit
			archiveSha256 = $expectedArchiveSha256
		}
		records = $sourceMapRecords.ToArray()
	}
	runtimeRunLedgerTemplate = [ordered]@{
		schema = "a2waspwarfare-runtime-run-ledger-v1"
		release = [ordered]@{
			candidate = $ExpectedCandidate
			git = $ReleaseGit
			archiveSha256 = $expectedArchiveSha256
		}
		records = $runLedgerRecords.ToArray()
	}
	runtimeChecklist = @(
		"Fill a private runtime-rpt-source-map.json from runtime-rpt-source-map.template.json, then run New-WaspRuntimeRptPacket.ps1 to copy the exact ten source RPTs, write release-run-ledger.json and emit runtime-rpt-packet-manifest.json.",
		"Exactly ten copied RPT files exist: chernarus/{server,HC1,HC2,start-client,late-JIP}.rpt and takistan/{server,HC1,HC2,start-client,late-JIP}.rpt.",
		"No extra RPT files, duplicate copied paths, or duplicate copied/source RPT content hashes are present in the release-candidate RPT root.",
		"Each role file's latest startup window contains the terrain-matching WASPRELEASE marker, MISSINIT worldName, and role proof: server files report isServer=true/isDedicated=true, HC files contain HC-local startup proof, and player-client files contain client-local startup proof.",
		"Every scored current-mission window keeps the startup ## Mission Name banner; files without that banner fail the all-files-have-startup-banner scorer gate.",
		"Run ledger validates with Test-WaspRuntimeRptPacket.ps1 -RunLedgerPath -RequireSourceRptExists: terrain launch times, exact roleProof/joinPhase metadata, original source RPT paths, source LastWriteTime/SHA256, copied paths/SHA256, command lines and PIDs are present; source RPT LastWriteTime must be after terrain launch time; source and copied RPT hashes must match; no original source RPT path is reused across roles.",
		"Run ledger release.archiveSha256 matches the approved package SHA256 passed to Test-WaspRuntimeRptPacket.ps1 -ExpectedArchiveSha256.",
		"Release RPT summary is generated with -RuntimePacketManifestPath and records validation.requested=true, validation.overall=pass and the exact ten copied RPT files from runtime-rpt-packet-manifest.json before summary overall can pass.",
		"WFBE_C_AI_DELEGATION=2 for the release pass.",
		"Current-mission RPT windows have no generic stop-condition errors.",
		"Every scored RPT resolves to one runtime terrain and the per-terrain-runtime-evidence gate passes, proving Chernarus and Takistan each contribute the core semantic evidence families.",
		"AICOM side discovery, heartbeat, WEST/EAST ticks, AICOMSTAT event, TEAM_FOUNDED, CMDRSTAT and at least one autonomous action/progress token such as ASSAULT_DISPATCH, COMBATSTAT, FRONT, POSTURE or SNAP.",
		"Takistan WEST AICOM founding proof includes AICOMGATE|WEST|infFallback from the exact release candidate before the founding issue is called fixed.",
		"HC registry proof has at least two non-zero-owner CIV HCSIDE connect rows and zero HCSIDE connect-skip or non-CIV HC connect rows.",
		"HC delegation/locality, town cleanup, WDDM/static/artillery, supply and JIP/HUD evidence families."
	)
	deploymentChecklist = @(
		"Steff explicitly approves live server package placement and restart.",
		"Current live mission/package is backed up before replacement.",
		"Pre-deploy live package hash or mission archive hash is recorded when available.",
		"Exact live target path is recorded in private ops notes, not public wiki.",
		"Server restart or mission rotation reload timestamp is recorded.",
		"Post-deploy RPT shows the exact Chernarus and Takistan release markers."
	)
	rollbackChecklist = @(
		"Stop/reload the Arma 2 OA server deliberately.",
		"Restore the timestamped pre-deploy mission/package backup.",
		"Restart server and HCs.",
		"Confirm old build/marker or expected prior package evidence in RPT.",
		"Record rollback timestamp and result in private ops notes."
	)
	safeToPublish = @(
		"release-handoff.json",
		"release-handoff.md",
		"runtime-rpt-source-map.template.json",
		"runtime-rpt-packet-manifest.json after runtime collection",
		"release-package-manifest.json",
		"release-package-manifest.md",
		"release-rpt-summary.json after runtime collection",
		"release-rpt-summary.md after runtime collection"
	)
	privateDataPolicy = "Do not publish raw RPTs, UIDs, IPs, player names, local profile paths, server paths, SSH/server usernames, hostnames, credentials, environment variables, or private deploy commands."
}

$packet | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $jsonOut -Encoding UTF8
$packet.runtimeRptSourceMapTemplate | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $sourceMapTemplateOut -Encoding UTF8
$packet.runtimeRunLedgerTemplate | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ledgerTemplateOut -Encoding UTF8
if ([System.IO.Path]::GetFullPath($manifestPath) -ne [System.IO.Path]::GetFullPath($manifestJsonOut)) {
	Copy-Item -LiteralPath $manifestPath -Destination $manifestJsonOut -Force
}
if ($manifestMarkdownExists -and [System.IO.Path]::GetFullPath($manifestMarkdownPath) -ne [System.IO.Path]::GetFullPath($manifestMarkdownOut)) {
	Copy-Item -LiteralPath $manifestMarkdownPath -Destination $manifestMarkdownOut -Force
}

$lines = New-Object System.Collections.Generic.List[string]
[void]$lines.Add("# WASP Release Handoff")
[void]$lines.Add("")
[void]$lines.Add(("Generated: {0}" -f $packet.generatedAt))
[void]$lines.Add(("Status: {0}" -f $packet.status))
[void]$lines.Add(("Branch: {0}" -f $packet.release.branch))
[void]$lines.Add(("Head: {0}" -f $packet.release.fullHead))
[void]$lines.Add(("Candidate: {0}" -f $packet.release.candidate))
[void]$lines.Add("")
[void]$lines.Add("## Package")
[void]$lines.Add("")
[void]$lines.Add(("Manifest: {0}" -f $packet.package.manifestPath))
[void]$lines.Add(("Overall: {0}" -f $packet.package.overall))
[void]$lines.Add(("Archive: {0}" -f $packet.package.archivePath))
[void]$lines.Add(("Size: {0} bytes" -f $packet.package.lengthBytes))
[void]$lines.Add(("SHA256: {0}" -f $packet.package.sha256))
[void]$lines.Add(("Entries: {0}" -f $packet.package.entryCount))
[void]$lines.Add("")
[void]$lines.Add("## Expected Runtime Markers")
[void]$lines.Add("")
foreach ($terrain in @("chernarus", "takistan")) {
	[void]$lines.Add(('- {0}: `{1}`' -f $terrain, $packet.expectedRuntimeMarkers[$terrain]))
}
[void]$lines.Add("")
[void]$lines.Add("## Gate Status")
[void]$lines.Add("")
[void]$lines.Add("| Gate | Status | Note |")
[void]$lines.Add("| --- | --- | --- |")
foreach ($gate in $packet.gates) {
	[void]$lines.Add(("| {0} | {1} | {2} |" -f (Escape-MarkdownCell $gate.id), (Escape-MarkdownCell $gate.status), (Escape-MarkdownCell $gate.note)))
}
[void]$lines.Add("")
[void]$lines.Add("## Runtime Commands")
[void]$lines.Add("")
[void]$lines.Add('```powershell')
[void]$lines.Add($packet.commands.markerArray)
[void]$lines.Add("")
[void]$lines.Add($packet.commands.runtimePacketBuilder)
[void]$lines.Add("")
[void]$lines.Add($packet.commands.runtimePacket)
[void]$lines.Add("")
[void]$lines.Add($packet.commands.runtimeScorer)
[void]$lines.Add("")
[void]$lines.Add($packet.commands.runtimeSummary)
[void]$lines.Add('```')
[void]$lines.Add("")
[void]$lines.Add("## Runtime RPT Source Map Template")
[void]$lines.Add("")
[void]$lines.Add('Copy this to a private `runtime-rpt-source-map.json`, replace placeholders, then run the packet builder. Keep the populated source map private.')
[void]$lines.Add("")
[void]$lines.Add('```json')
[void]$lines.Add(($packet.runtimeRptSourceMapTemplate | ConvertTo-Json -Depth 10))
[void]$lines.Add('```')
[void]$lines.Add("")
[void]$lines.Add("## Runtime Run Ledger Template")
[void]$lines.Add("")
[void]$lines.Add('The packet builder writes this as `release-run-ledger.json` beside the copied RPT packet. If assembling manually, replace every placeholder before running the packet checker.')
[void]$lines.Add("")
[void]$lines.Add('```json')
[void]$lines.Add(($packet.runtimeRunLedgerTemplate | ConvertTo-Json -Depth 10))
[void]$lines.Add('```')
[void]$lines.Add("")
[void]$lines.Add("## Runtime Checklist")
[void]$lines.Add("")
foreach ($item in $packet.runtimeChecklist) {
	[void]$lines.Add(("- {0}" -f $item))
}
[void]$lines.Add("")
[void]$lines.Add("## Deployment Approval Checklist")
[void]$lines.Add("")
foreach ($item in $packet.deploymentChecklist) {
	[void]$lines.Add(("- {0}" -f $item))
}
[void]$lines.Add("")
[void]$lines.Add("## Rollback Checklist")
[void]$lines.Add("")
foreach ($item in $packet.rollbackChecklist) {
	[void]$lines.Add(("- {0}" -f $item))
}
[void]$lines.Add("")
[void]$lines.Add("## Safe To Publish")
[void]$lines.Add("")
foreach ($item in $packet.safeToPublish) {
	[void]$lines.Add(("- {0}" -f $item))
}
[void]$lines.Add("")
[void]$lines.Add(("Privacy: {0}" -f $packet.privateDataPolicy))
$lines | Set-Content -LiteralPath $markdownOut -Encoding UTF8

Write-Host "Wrote release handoff:"
Write-Host $jsonOut
Write-Host $markdownOut
Write-Host $sourceMapTemplateOut
Write-Host $ledgerTemplateOut
Write-Host $manifestJsonOut
if ($manifestMarkdownExists) { Write-Host $manifestMarkdownOut }

if ($blockingFailures.Count -gt 0) { exit 1 }
