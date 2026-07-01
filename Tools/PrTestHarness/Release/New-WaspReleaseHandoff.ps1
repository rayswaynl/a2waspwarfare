[CmdletBinding()]
param(
	[string]$PackageManifestPath = "",
	[string]$ExpectedCandidate = "release-command-center-20260630",
	[string]$ReleaseGit = "",
	[string]$OutDirectory = "",
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

function ConvertTo-SafePath {
	param([string]$Path)
	if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
	$safe = $Path
	if (![string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
		$safe = $safe -replace [regex]::Escape($env:USERPROFILE), "%USERPROFILE%"
	}
	return $safe
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
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json

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
Add-Gate $gates "package-overall-pass" ($(if ([string]$manifest.overall -eq "pass") { "pass" } else { "fail" })) "Package manifest overall status must be pass."
Add-Gate $gates "candidate-match" ($(if ([string]$manifest.expectedCandidate -eq $ExpectedCandidate) { "pass" } else { "fail" })) "Package candidate must match the handoff candidate."
Add-Gate $gates "git-match" ($(if ([string]$manifest.expectedGit -eq $ReleaseGit) { "pass" } else { "fail" })) "Package git marker must match the current handoff git short hash."
Add-Gate $gates "chernarus-marker-match" ($(if ($actualMarkers.chernarus -eq $expectedMarkers.chernarus) { "pass" } else { "fail" })) "Chernarus package marker must match the exact runtime marker."
Add-Gate $gates "takistan-marker-match" ($(if ($actualMarkers.takistan -eq $expectedMarkers.takistan) { "pass" } else { "fail" })) "Takistan package marker must match the exact runtime marker."
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
if (!$Force) {
	foreach ($candidate in @($jsonOut, $markdownOut, $ledgerTemplateOut)) {
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
foreach ($terrain in @("chernarus", "takistan")) {
	foreach ($role in @("server", "HC1", "HC2", "start-client", "late-JIP")) {
		[void]$runLedgerRecords.Add([ordered]@{
			terrain = $terrain
			role = $role
			terrainStartTime = "<$terrain-launch-time>"
			pid = "<process-pid>"
			commandLine = "<redacted-command-line>"
			profilePath = "<profile-or-log-root>"
			sourceRptPath = "<original-source-rpt-path>"
			copiedRptPath = "$terrain\$role.rpt"
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
		repoRoot = ConvertTo-SafePath $repoRoot
	}
	package = [ordered]@{
		manifestPath = ConvertTo-SafePath $manifestPath
		overall = [string]$manifest.overall
		expectedGit = [string]$manifest.expectedGit
		archiveName = [string]$manifest.archive.name
		archivePath = ConvertTo-SafePath ([string]$manifest.archive.path)
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
		runtimePacket = "& .\Tools\PrTestHarness\Rpt\Test-WaspRuntimeRptPacket.ps1 -RptRoot `"<release-candidate-rpts>`" -ExpectedGit $ReleaseGit -RunLedgerPath `"<release-candidate-rpts>\release-run-ledger.json`""
		runtimeScorer = "& .\Tools\PrTestHarness\Rpt\Test-WaspReleaseRptEvidence.ps1 -RptDirectory `"<release-candidate-rpts>`" -Recurse -ExpectedMarker `$expectedReleaseMarkers"
		runtimeSummary = "& .\Tools\PrTestHarness\Rpt\New-WaspReleaseRptSummary.ps1 -RptDirectory `"<release-candidate-rpts>`" -Recurse -ExpectedMarker `$expectedReleaseMarkers -OutDirectory `"<release-candidate-rpts>\summary`" -Force"
		packageProof = "pwsh -NoProfile -ExecutionPolicy Bypass -File Tools\PrTestHarness\Package\Test-WaspReleasePackage.ps1 -ArchivePath .\_MISSIONS.7z -ExpectedCandidate $ExpectedCandidate -ExpectedGit $ReleaseGit -OutDirectory .\wasp-release-package-manifest -Force"
	}
	runtimeRunLedgerTemplate = [ordered]@{
		schema = "a2waspwarfare-runtime-run-ledger-v1"
		release = [ordered]@{
			candidate = $ExpectedCandidate
			git = $ReleaseGit
			archiveSha256 = [string]$manifest.archive.sha256
		}
		records = $runLedgerRecords.ToArray()
	}
	runtimeChecklist = @(
		"Exactly ten copied RPT files exist: chernarus/{server,HC1,HC2,start-client,late-JIP}.rpt and takistan/{server,HC1,HC2,start-client,late-JIP}.rpt.",
		"No extra RPT files or duplicate copied paths are present in the release-candidate RPT root.",
		"Each role file's latest startup window contains the terrain-matching WASPRELEASE marker and MISSINIT worldName.",
		"Run ledger validates with Test-WaspRuntimeRptPacket.ps1 -RunLedgerPath: terrain launch times, original source RPT paths, copied paths, command lines and PIDs are present; copied RPT LastWriteTime values are read from the copied files and must be after their terrain launch time; no original source RPT path is reused across roles.",
		"WFBE_C_AI_DELEGATION=2 for the release pass.",
		"Current-mission RPT windows have no generic stop-condition errors.",
		"AICOM side discovery, heartbeat, tick and progress tokens for WEST and EAST.",
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
		"release-package-manifest.json",
		"release-package-manifest.md",
		"release-rpt-summary.json after runtime collection",
		"release-rpt-summary.md after runtime collection"
	)
	privateDataPolicy = "Do not publish raw RPTs, UIDs, IPs, player names, local profile paths, server paths, SSH/server usernames, hostnames, credentials, environment variables, or private deploy commands."
}

$packet | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $jsonOut -Encoding UTF8
$packet.runtimeRunLedgerTemplate | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ledgerTemplateOut -Encoding UTF8

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
[void]$lines.Add($packet.commands.runtimePacket)
[void]$lines.Add("")
[void]$lines.Add($packet.commands.runtimeScorer)
[void]$lines.Add("")
[void]$lines.Add($packet.commands.runtimeSummary)
[void]$lines.Add('```')
[void]$lines.Add("")
[void]$lines.Add("## Runtime Run Ledger Template")
[void]$lines.Add("")
[void]$lines.Add("Save this as `release-run-ledger.json` beside the RPT packet and replace placeholders before running the packet checker.")
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
Write-Host $ledgerTemplateOut

if ($blockingFailures.Count -gt 0) { exit 1 }
