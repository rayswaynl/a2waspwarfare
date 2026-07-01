[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$scorerPath = Join-Path $PSScriptRoot "Test-WaspReleaseRptEvidence.ps1"
if (!(Test-Path -LiteralPath $scorerPath -PathType Leaf)) {
	throw "RPT evidence scorer not found: $scorerPath"
}
$summaryPath = Join-Path $PSScriptRoot "New-WaspReleaseRptSummary.ps1"
if (!(Test-Path -LiteralPath $summaryPath -PathType Leaf)) {
	throw "RPT evidence summary generator not found: $summaryPath"
}

function Get-ExpectedMarkers {
	return @(
		"WASPRELEASE|v1|candidate=per-terrain-self-test|git=selftest01|terrain=chernarus",
		"WASPRELEASE|v1|candidate=per-terrain-self-test|git=selftest01|terrain=takistan"
	)
}

function Get-TestArchiveSha256 {
	return "22223333444455556666777788889999AAAABBBBCCCCDDDDEEEEFFFF00001111"
}

function Get-SafePathHash {
	param([string]$Path)
	if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
	$fullPath = [System.IO.Path]::GetFullPath([System.Environment]::ExpandEnvironmentVariables($Path))
	$sha = [System.Security.Cryptography.SHA256]::Create()
	try {
		$bytes = [System.Text.Encoding]::UTF8.GetBytes($fullPath.ToLowerInvariant())
		$hash = $sha.ComputeHash($bytes)
		return ([System.BitConverter]::ToString($hash) -replace "-", "").Substring(0, 12)
	} finally {
		$sha.Dispose()
	}
}

function Get-FileSha256Value {
	param([string]$Path)
	if ([string]::IsNullOrWhiteSpace($Path) -or !(Test-Path -LiteralPath $Path -PathType Leaf)) { return "" }
	$sha = [System.Security.Cryptography.SHA256]::Create()
	$fs = [System.IO.File]::Open($Path,
		[System.IO.FileMode]::Open,
		[System.IO.FileAccess]::Read,
		[System.IO.FileShare]::ReadWrite)
	try {
		$hash = $sha.ComputeHash($fs)
		return ([System.BitConverter]::ToString($hash) -replace "-", "").ToUpperInvariant()
	} finally {
		$fs.Dispose()
		$sha.Dispose()
	}
}

function Get-RuntimePacketPassGates {
	$gateIds = @(
		"exact-ten-file-matrix",
		"no-extra-rpt-files",
		"no-duplicate-copied-paths",
		"no-duplicate-rpt-content",
		"runtime-run-ledger",
		"per-file-marker-world",
		"per-role-identity",
		"per-role-proof",
		"per-terrain-freshness-cutoffs"
	)
	return @($gateIds | ForEach-Object {
		[ordered]@{
			id = $_
			status = "pass"
			missing = @()
			failHits = @()
		}
	})
}

function New-TestPacket {
	param(
		[Parameter(Mandatory)] [string]$Root,
		[Parameter(Mandatory)] [string[]]$SemanticTerrains,
		[switch]$IncludeTakistanInfFallback,
		[switch]$IncludeChernarusInfFallback,
		[switch]$IncludeTakistanEastInfFallback,
		[switch]$OmitEastAicomProgress
	)

	$roles = @("server","HC1","HC2","start-client","late-JIP")
	foreach ($terrain in @("chernarus","takistan")) {
		$terrainDir = Join-Path $Root $terrain
		[void](New-Item -ItemType Directory -Path $terrainDir -Force)
		foreach ($role in $roles) {
			$isServer = if ($role -eq "server") { "true" } else { "false" }
			$isDedicated = if ($role -eq "server") { "true" } else { "false" }
			$lines = New-Object System.Collections.Generic.List[string]
			[void]$lines.Add("## Mission Name: [test]warfarev2_073v48co.$terrain")
			[void]$lines.Add("## Build: per-terrain-self-test")
			[void]$lines.Add("WASPRELEASE|v1|candidate=per-terrain-self-test|git=selftest01|terrain=$terrain")
			[void]$lines.Add("MISSINIT: missionName=[test]warfarev2_073v48co.$terrain, worldName=$terrain, isMultiplayer=true, isServer=$isServer, isDedicated=$isDedicated]")
			[void]$lines.Add("ROLEPROOF|$role|$terrain")
			if ($role -eq "server" -and ($SemanticTerrains -contains $terrain)) {
				$semanticTokens = @(
					"AICOMHB|v1|west|ok",
					"AICOMHB|v1|east|ok",
					"AICOMSTAT|v1|TICK|west|1|0|0|0|0|0|",
					"AICOMSTAT|v1|TICK|east|1|0|0|0|0|0|",
					"AICOMSTAT|v2|EVENT|west|1|TEAM_FOUNDED|team=alpha",
					"AICOMSTAT|v2|EVENT|west|1|ASSAULT_DISPATCH|town=alpha",
					"AI commander ACTIVE",
					"AI commander ASSIST",
					"AICOM2|v1|ORDER|aicom-ai-command",
					"CMDRSTAT|v1",
					"SRVPERF|v1",
					"GRPBUDGET|v1",
					"B63 JIP-MARK",
					"B74.2.4 TEAMS-REBC",
					"B74.2.5 ROSTER-PUSH",
					"JIPFUNDS",
					"CLIENTROSTER|RECV",
					"CLIENTROSTER|POLL-ADOPT",
					"HQ-MARK",
					"HCSIDE|v1",
					"HCSIDE|v1|connect|role=HC1|owner=11|side=CIV",
					"HCSIDE|v1|connect|role=HC2|owner=12|side=civilian",
					"HCSTAT|v1",
					"HCDELEG|v1",
					"DELEGSTAT|v1",
					"TEAM_FOUNDED|via=HC",
					"server_town_ai.sqf: Town Alpha ACTIVATED",
					"server_town_ai.sqf: Town Alpha DEACTIVATED",
					"TOWN_AI_HC_CLEANUP",
					"keptGroups:0",
					"TOWN_GROUP_COUNT cleanup_after",
					"GCSTAT|v1",
					"STRUCTURE_BUILT|struct=Reserve",
					"STRUCTURE_BUILT|struct=ArtilleryRadar",
					"ARTY_THREAT_ARMED",
					"SupplyMissionStart.sqf: Player Tester loaded",
					"SupplyMissionUnload.sqf: Player Tester started helicopter unload timer",
					"SupplyMissionCompleted.sqf: Completion accepted"
				)
				if (!$OmitEastAicomProgress) {
					$semanticTokens += @(
						"AICOMSTAT|v2|EVENT|east|1|TEAM_FOUNDED|team=bravo",
						"AICOMSTAT|v2|EVENT|east|1|ASSAULT_DISPATCH|town=bravo"
					)
				}
				foreach ($token in $semanticTokens) {
					[void]$lines.Add($token)
				}
				if ($terrain -eq "chernarus" -and $IncludeChernarusInfFallback) {
					[void]$lines.Add("AICOMGATE|WEST|infFallback|admitted tmpl CDF_InfantrySquad maskSum=0 sideUpg=[0,0,0,0] (wrong terrain for Takistan gate)")
				}
				if ($terrain -eq "takistan" -and $IncludeTakistanEastInfFallback) {
					[void]$lines.Add("AICOMGATE|EAST|infFallback|admitted tmpl TK_INS_InfantrySquad maskSum=0 sideUpg=[0,0,0,0] (wrong side for WEST gate)")
				}
				if ($terrain -eq "takistan" -and $IncludeTakistanInfFallback) {
					[void]$lines.Add("AICOMGATE|WEST|infFallback|admitted tmpl BIS_US_InfantrySquad maskSum=1 sideUpg=[0,0,0,0] (no upgrade-0 infantry eligible)")
				}
			}
			Set-Content -LiteralPath (Join-Path $terrainDir "$role.rpt") -Value $lines -Encoding UTF8
		}
	}
}

function Invoke-Score {
	param([Parameter(Mandatory)] [string]$Root)
	$expectedMarkers = Get-ExpectedMarkers
	$json = & $scorerPath -RptDirectory $Root -Recurse -ExpectedMarker $expectedMarkers -Json -NoFail
	return (($json | Out-String).Trim() | ConvertFrom-Json)
}

function Write-RuntimePacketManifest {
	param(
		[Parameter(Mandatory)] [string]$Path,
		[bool]$ValidationRequested,
		[Parameter(Mandatory)] [string]$ValidationOverall,
		[string]$FileVariant = "valid",
		[string]$ReleaseCandidate = "per-terrain-self-test",
		[string]$ReleaseGit = "selftest01",
		[string]$ArchiveSha256 = (Get-TestArchiveSha256),
		[string]$RptRoot = $root,
		[string]$RptRootHash = (Get-SafePathHash $root),
		[switch]$IncludeValidationGates
	)
	$files = @(
		[ordered]@{ terrain = "chernarus"; role = "server"; copiedRptPath = "chernarus\server.rpt" },
		[ordered]@{ terrain = "chernarus"; role = "HC1"; copiedRptPath = "chernarus\HC1.rpt" },
		[ordered]@{ terrain = "chernarus"; role = "HC2"; copiedRptPath = "chernarus\HC2.rpt" },
		[ordered]@{ terrain = "chernarus"; role = "start-client"; copiedRptPath = "chernarus\start-client.rpt" },
		[ordered]@{ terrain = "chernarus"; role = "late-JIP"; copiedRptPath = "chernarus\late-JIP.rpt" },
		[ordered]@{ terrain = "takistan"; role = "server"; copiedRptPath = "takistan\server.rpt" },
		[ordered]@{ terrain = "takistan"; role = "HC1"; copiedRptPath = "takistan\HC1.rpt" },
		[ordered]@{ terrain = "takistan"; role = "HC2"; copiedRptPath = "takistan\HC2.rpt" },
		[ordered]@{ terrain = "takistan"; role = "start-client"; copiedRptPath = "takistan\start-client.rpt" },
		[ordered]@{ terrain = "takistan"; role = "late-JIP"; copiedRptPath = "takistan\late-JIP.rpt" }
	)
	if ($FileVariant -eq "wrong-file-set") {
		$files[7] = [ordered]@{ terrain = "takistan"; role = "HC2"; copiedRptPath = "takistan\wrong-HC2.rpt" }
	}
	$manifestFiles = @($files | ForEach-Object {
		$copiedPath = [string]$_["copiedRptPath"]
		$actualPath = [System.IO.Path]::GetFullPath((Join-Path $RptRoot $copiedPath))
		[ordered]@{
			terrain = [string]$_["terrain"]
			role = [string]$_["role"]
			copiedRptPath = $copiedPath
			copiedPathHash = Get-SafePathHash $actualPath
			copiedRptSha256 = Get-FileSha256Value $actualPath
		}
	})
	if ($FileVariant -eq "stale-hash") {
		$manifestFiles[0]["copiedRptSha256"] = "0000000000000000000000000000000000000000000000000000000000000000"
	}
	$manifest = [ordered]@{
		schema = "a2waspwarfare-runtime-rpt-packet-builder-v1"
		generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
		rptRoot = "<rpt-root>"
		rptRootHash = $RptRootHash
		release = [ordered]@{
			candidate = $ReleaseCandidate
			git = $ReleaseGit
			archiveSha256 = $ArchiveSha256
		}
		artifacts = [ordered]@{
			ledgerPath = "release-run-ledger.json"
			manifestPath = "runtime-rpt-packet-manifest.json"
		}
		files = $manifestFiles
		validation = [ordered]@{
			requested = $ValidationRequested
			overall = $ValidationOverall
			gates = if ($IncludeValidationGates) { @(Get-RuntimePacketPassGates) } else { @() }
		}
		privacy = "self-test"
	}
	$dir = Split-Path -Parent $Path
	[void](New-Item -ItemType Directory -Path $dir -Force)
	$manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Invoke-BoundSummary {
	param(
		[Parameter(Mandatory)] [string]$Root,
		[Parameter(Mandatory)] [string]$OutDirectory,
		[string]$RuntimePacketManifestPath = ""
	)
	$expectedMarkers = Get-ExpectedMarkers
	$params = @{
		RptDirectory = @($Root)
		Recurse = $true
		ExpectedMarker = $expectedMarkers
		ExpectedCandidate = "per-terrain-self-test"
		ExpectedGit = "selftest01"
		ExpectedArchiveSha256 = (Get-TestArchiveSha256)
		RequireRuntimePacketManifest = $true
		OutDirectory = $OutDirectory
		Force = $true
		NoFail = $true
	}
	if (![string]::IsNullOrWhiteSpace($RuntimePacketManifestPath)) {
		$params["RuntimePacketManifestPath"] = $RuntimePacketManifestPath
	}
	& $summaryPath @params | Out-Null
	return (Get-Content -Raw -LiteralPath (Join-Path $OutDirectory "release-rpt-summary.json") | ConvertFrom-Json)
}

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("wasp-release-rpt-evidence-selftest-" + [System.Guid]::NewGuid().ToString("N"))
try {
	[void](New-Item -ItemType Directory -Path $root -Force)
	New-TestPacket -Root $root -SemanticTerrains @("chernarus")
	$chernarusOnly = Invoke-Score -Root $root
	$perTerrainGate = @($chernarusOnly.gates | Where-Object { [string]$_.id -eq "per-terrain-runtime-evidence" }) | Select-Object -First 1
	if ($null -eq $perTerrainGate) { throw "Missing per-terrain-runtime-evidence gate." }
	$takistanMissing = @($perTerrainGate.missing | Where-Object { [string]$_ -like "takistan:*" })
	if ([string]$chernarusOnly.overall -ne "missing_or_failed" -or [string]$perTerrainGate.status -ne "missing" -or $takistanMissing.Count -eq 0) {
		throw "Expected Chernarus-only semantic packet to fail the Takistan per-terrain runtime gate."
	}

	Remove-Item -LiteralPath $root -Recurse -Force
	[void](New-Item -ItemType Directory -Path $root -Force)
	New-TestPacket -Root $root -SemanticTerrains @("chernarus","takistan")
	$bothTerrains = Invoke-Score -Root $root
	$perTerrainGate = @($bothTerrains.gates | Where-Object { [string]$_.id -eq "per-terrain-runtime-evidence" }) | Select-Object -First 1
	$fallbackGate = @($bothTerrains.gates | Where-Object { [string]$_.id -eq "takistan-west-aicom-infantry-fallback" }) | Select-Object -First 1
	if ([string]$bothTerrains.overall -ne "missing_or_failed" -or [string]$perTerrainGate.status -ne "pass" -or [string]$fallbackGate.status -ne "missing") {
		throw ("Expected mirrored packet without Takistan WEST fallback to fail only the fallback gate; overall={0}, perTerrain={1}, fallback={2}" -f $bothTerrains.overall, $perTerrainGate.status, $fallbackGate.status)
	}

	Remove-Item -LiteralPath $root -Recurse -Force
	[void](New-Item -ItemType Directory -Path $root -Force)
	New-TestPacket -Root $root -SemanticTerrains @("chernarus","takistan") -IncludeChernarusInfFallback
	$wrongTerrainFallback = Invoke-Score -Root $root
	$fallbackGate = @($wrongTerrainFallback.gates | Where-Object { [string]$_.id -eq "takistan-west-aicom-infantry-fallback" }) | Select-Object -First 1
	if ([string]$wrongTerrainFallback.overall -ne "missing_or_failed" -or [string]$fallbackGate.status -ne "missing") {
		throw ("Expected Chernarus-only fallback marker not to satisfy Takistan WEST fallback gate; overall={0}, fallback={1}" -f $wrongTerrainFallback.overall, $fallbackGate.status)
	}

	Remove-Item -LiteralPath $root -Recurse -Force
	[void](New-Item -ItemType Directory -Path $root -Force)
	New-TestPacket -Root $root -SemanticTerrains @("chernarus","takistan") -IncludeTakistanEastInfFallback
	$wrongSideFallback = Invoke-Score -Root $root
	$fallbackGate = @($wrongSideFallback.gates | Where-Object { [string]$_.id -eq "takistan-west-aicom-infantry-fallback" }) | Select-Object -First 1
	if ([string]$wrongSideFallback.overall -ne "missing_or_failed" -or [string]$fallbackGate.status -ne "missing") {
		throw ("Expected Takistan EAST fallback marker not to satisfy Takistan WEST fallback gate; overall={0}, fallback={1}" -f $wrongSideFallback.overall, $fallbackGate.status)
	}

	Remove-Item -LiteralPath $root -Recurse -Force
	[void](New-Item -ItemType Directory -Path $root -Force)
	New-TestPacket -Root $root -SemanticTerrains @("chernarus","takistan") -IncludeTakistanInfFallback -OmitEastAicomProgress
	$missingEastAicom = Invoke-Score -Root $root
	$aicomGate = @($missingEastAicom.gates | Where-Object { [string]$_.id -eq "aicom-no-human" }) | Select-Object -First 1
	if ($null -eq $aicomGate) { throw "Missing aicom-no-human gate." }
	$eastMissing = @($aicomGate.missing | Where-Object { [string]$_ -match "aicomTeamFoundedEast|east-action-or-progress" })
	if ([string]$missingEastAicom.overall -ne "missing_or_failed" -or [string]$aicomGate.status -ne "missing" -or $eastMissing.Count -eq 0) {
		throw ("Expected no-human AICOM gate to fail without EAST founding/progress; overall={0}, aicom={1}, missing={2}" -f $missingEastAicom.overall, $aicomGate.status, (($aicomGate.missing | Out-String).Trim()))
	}

	Remove-Item -LiteralPath $root -Recurse -Force
	[void](New-Item -ItemType Directory -Path $root -Force)
	New-TestPacket -Root $root -SemanticTerrains @("chernarus","takistan") -IncludeTakistanInfFallback
	$bothTerrains = Invoke-Score -Root $root
	$perTerrainGate = @($bothTerrains.gates | Where-Object { [string]$_.id -eq "per-terrain-runtime-evidence" }) | Select-Object -First 1
	$fallbackGate = @($bothTerrains.gates | Where-Object { [string]$_.id -eq "takistan-west-aicom-infantry-fallback" }) | Select-Object -First 1
	if ([string]$bothTerrains.overall -ne "pass" -or [string]$perTerrainGate.status -ne "pass" -or [string]$fallbackGate.status -ne "pass") {
		throw ("Expected mirrored Chernarus/Takistan semantic packet with Takistan WEST fallback to pass; overall={0}, perTerrain={1}, fallback={2}" -f $bothTerrains.overall, $perTerrainGate.status, $fallbackGate.status)
	}

	$badManifest = Join-Path $root "packet-failed\runtime-rpt-packet-manifest.json"
	Write-RuntimePacketManifest -Path $badManifest -ValidationRequested $false -ValidationOverall "skipped"
	$badSummary = Invoke-BoundSummary -Root $root -OutDirectory (Join-Path $root "summary-bad") -RuntimePacketManifestPath $badManifest
	if ([string]$badSummary.overall -ne "missing_or_failed" -or [string]$badSummary.runtimePacketProof.status -ne "fail") {
		throw ("Expected summary to fail when runtime packet manifest validation is skipped; summary={0}, packetProof={1}" -f $badSummary.overall, $badSummary.runtimePacketProof.status)
	}

	$wrongFilesManifest = Join-Path $root "packet-wrong-files\runtime-rpt-packet-manifest.json"
	Write-RuntimePacketManifest -Path $wrongFilesManifest -ValidationRequested $true -ValidationOverall "pass" -FileVariant "wrong-file-set"
	$wrongFilesSummary = Invoke-BoundSummary -Root $root -OutDirectory (Join-Path $root "summary-wrong-files") -RuntimePacketManifestPath $wrongFilesManifest
	if ([string]$wrongFilesSummary.overall -ne "missing_or_failed" -or [string]$wrongFilesSummary.runtimePacketProof.status -ne "fail") {
		throw ("Expected summary to fail when runtime packet manifest has ten files but wrong copied paths; summary={0}, packetProof={1}" -f $wrongFilesSummary.overall, $wrongFilesSummary.runtimePacketProof.status)
	}

	$staleManifest = Join-Path $root "packet-stale-release\runtime-rpt-packet-manifest.json"
	Write-RuntimePacketManifest -Path $staleManifest -ValidationRequested $true -ValidationOverall "pass" -ReleaseGit "stalegit01"
	$staleSummary = Invoke-BoundSummary -Root $root -OutDirectory (Join-Path $root "summary-stale-release") -RuntimePacketManifestPath $staleManifest
	if ([string]$staleSummary.overall -ne "missing_or_failed" -or [string]$staleSummary.runtimePacketProof.status -ne "fail") {
		throw ("Expected summary to fail when runtime packet manifest release identity is stale; summary={0}, packetProof={1}" -f $staleSummary.overall, $staleSummary.runtimePacketProof.status)
	}

	$missingSummary = Invoke-BoundSummary -Root $root -OutDirectory (Join-Path $root "summary-missing-required")
	if ([string]$missingSummary.overall -ne "missing_or_failed" -or [string]$missingSummary.runtimePacketProof.status -ne "missing") {
		throw ("Expected summary to fail when required runtime packet manifest is missing; summary={0}, packetProof={1}" -f $missingSummary.overall, $missingSummary.runtimePacketProof.status)
	}

	$emptyGatesManifest = Join-Path $root "packet-empty-gates\runtime-rpt-packet-manifest.json"
	Write-RuntimePacketManifest -Path $emptyGatesManifest -ValidationRequested $true -ValidationOverall "pass"
	$emptyGatesSummary = Invoke-BoundSummary -Root $root -OutDirectory (Join-Path $root "summary-empty-gates") -RuntimePacketManifestPath $emptyGatesManifest
	if ([string]$emptyGatesSummary.overall -ne "missing_or_failed" -or [string]$emptyGatesSummary.runtimePacketProof.status -ne "fail") {
		throw ("Expected summary to fail when runtime packet manifest claims pass but has no validation gates; summary={0}, packetProof={1}" -f $emptyGatesSummary.overall, $emptyGatesSummary.runtimePacketProof.status)
	}

	$wrongRootManifest = Join-Path $root "packet-wrong-root\runtime-rpt-packet-manifest.json"
	Write-RuntimePacketManifest -Path $wrongRootManifest -ValidationRequested $true -ValidationOverall "pass" -IncludeValidationGates -RptRootHash (Get-SafePathHash (Join-Path $root "other-rpt-root"))
	$wrongRootSummary = Invoke-BoundSummary -Root $root -OutDirectory (Join-Path $root "summary-wrong-root") -RuntimePacketManifestPath $wrongRootManifest
	if ([string]$wrongRootSummary.overall -ne "missing_or_failed" -or [string]$wrongRootSummary.runtimePacketProof.status -ne "fail") {
		throw ("Expected summary to fail when runtime packet manifest rptRootHash does not match the scored RPT root; summary={0}, packetProof={1}" -f $wrongRootSummary.overall, $wrongRootSummary.runtimePacketProof.status)
	}

	$staleHashManifest = Join-Path $root "packet-stale-hash\runtime-rpt-packet-manifest.json"
	Write-RuntimePacketManifest -Path $staleHashManifest -ValidationRequested $true -ValidationOverall "pass" -IncludeValidationGates -FileVariant "stale-hash"
	$staleHashSummary = Invoke-BoundSummary -Root $root -OutDirectory (Join-Path $root "summary-stale-hash") -RuntimePacketManifestPath $staleHashManifest
	if ([string]$staleHashSummary.overall -ne "missing_or_failed" -or [string]$staleHashSummary.runtimePacketProof.status -ne "fail") {
		throw ("Expected summary to fail when runtime packet manifest copiedRptSha256 does not match the scored RPT file; summary={0}, packetProof={1}" -f $staleHashSummary.overall, $staleHashSummary.runtimePacketProof.status)
	}

	$goodManifest = Join-Path $root "packet-good\runtime-rpt-packet-manifest.json"
	Write-RuntimePacketManifest -Path $goodManifest -ValidationRequested $true -ValidationOverall "pass" -IncludeValidationGates
	$goodSummary = Invoke-BoundSummary -Root $root -OutDirectory (Join-Path $root "summary-good") -RuntimePacketManifestPath $goodManifest
	if ([string]$goodSummary.overall -ne "pass" -or [string]$goodSummary.runtimePacketProof.status -ne "pass") {
		throw ("Expected summary to pass when scorer and runtime packet manifest pass; summary={0}, packetProof={1}, failures={2}" -f $goodSummary.overall, $goodSummary.runtimePacketProof.status, (($goodSummary.runtimePacketProof.failHits | Out-String).Trim()))
	}

	$summaryOut = Join-Path $root "summary"
	& $summaryPath -RptDirectory $root -Recurse -ExpectedMarker (Get-ExpectedMarkers) -RuntimePacketManifestPath $goodManifest -ExpectedCandidate "per-terrain-self-test" -ExpectedGit "selftest01" -ExpectedArchiveSha256 (Get-TestArchiveSha256) -RequireRuntimePacketManifest -OutDirectory $summaryOut -Force
	$summaryMarkdown = Join-Path $summaryOut "release-rpt-summary.md"
	if (!(Test-Path -LiteralPath $summaryMarkdown -PathType Leaf)) {
		throw "Expected summary Markdown was not written."
	}
	$summaryText = Get-Content -Raw -LiteralPath $summaryMarkdown
	if ($summaryText -notmatch "Per-Terrain Selected Token Counts") {
		throw "Expected summary Markdown to include per-terrain token counts."
	}
	if ($summaryText -notmatch "Runtime Packet Proof") {
		throw "Expected summary Markdown to include runtime packet proof."
	}

	Write-Host "PASS: per-terrain and Takistan WEST fallback runtime evidence self-test"
} finally {
	if (Test-Path -LiteralPath $root) {
		Remove-Item -LiteralPath $root -Recurse -Force
	}
}
