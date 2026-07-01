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

function New-TestPacket {
	param(
		[Parameter(Mandatory)] [string]$Root,
		[Parameter(Mandatory)] [string[]]$SemanticTerrains
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
				foreach ($token in @(
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
					"WDDM_ARTILLERY_AUDIT",
					"WDDM_ARTILLERY_SIDE",
					"STRUCTURE_BUILT|struct=Reserve",
					"STRUCTURE_BUILT|struct=ArtilleryRadar",
					"ARTY_THREAT_ARMED",
					"SupplyMissionStart.sqf: Player Tester loaded",
					"SupplyMissionUnload.sqf: Player Tester started helicopter unload timer",
					"SupplyMissionCompleted.sqf: Completion accepted",
					"SERVICE_SUPPLY_AUDIT"
				)) {
					[void]$lines.Add($token)
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
	if ([string]$bothTerrains.overall -ne "pass" -or [string]$perTerrainGate.status -ne "pass") {
		throw ("Expected mirrored Chernarus/Takistan semantic packet to pass; overall={0}, perTerrain={1}" -f $bothTerrains.overall, $perTerrainGate.status)
	}
	$summaryOut = Join-Path $root "summary"
	& $summaryPath -RptDirectory $root -Recurse -ExpectedMarker (Get-ExpectedMarkers) -OutDirectory $summaryOut -Force
	$summaryMarkdown = Join-Path $summaryOut "release-rpt-summary.md"
	if (!(Test-Path -LiteralPath $summaryMarkdown -PathType Leaf)) {
		throw "Expected summary Markdown was not written."
	}
	$summaryText = Get-Content -Raw -LiteralPath $summaryMarkdown
	if ($summaryText -notmatch "Per-Terrain Selected Token Counts") {
		throw "Expected summary Markdown to include per-terrain token counts."
	}

	Write-Host "PASS: per-terrain runtime evidence self-test"
} finally {
	if (Test-Path -LiteralPath $root) {
		Remove-Item -LiteralPath $root -Recurse -Force
	}
}
