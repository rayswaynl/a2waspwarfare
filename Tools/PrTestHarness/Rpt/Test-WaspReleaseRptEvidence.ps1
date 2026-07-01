[CmdletBinding()]
param(
	[string[]]$RptPath = @(),
	[string[]]$RptDirectory = @(),
	[string[]]$ExpectedMarker = @(),
	[string]$WindowMarker = "MISSINIT|## (Mission Name|Build|LOG CONTENT)",
	[switch]$Recurse,
	[switch]$Json,
	[switch]$NoFail
)

$ErrorActionPreference = "Stop"

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

function ConvertTo-PublicRptLabel {
	param(
		[Parameter(Mandatory)] [string]$Path,
		[string[]]$Roots = @()
	)
	if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
	$fullPath = [System.IO.Path]::GetFullPath($Path)
	$pathHash = Get-SafeTextHash $fullPath
	foreach ($root in $Roots) {
		if ([string]::IsNullOrWhiteSpace($root)) { continue }
		$rootPath = [System.IO.Path]::GetFullPath($root)
		if ((Test-Path -LiteralPath $rootPath -PathType Leaf)) {
			$rootPath = Split-Path -Parent $rootPath
		}
		$rootPath = $rootPath.TrimEnd([char[]]@('\','/'))
		$prefix = $rootPath + [System.IO.Path]::DirectorySeparatorChar
		if ($fullPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
			$relative = $fullPath.Substring($prefix.Length)
			return ("<rpt-root>\{0} (pathHash={1})" -f $relative, $pathHash)
		}
	}
	return ("<rpt-file>\{0} (pathHash={1})" -f ([System.IO.Path]::GetFileName($fullPath)), $pathHash)
}

function Get-RptFiles {
	$files = New-Object System.Collections.Generic.List[string]
	foreach ($path in $RptPath) {
		if ([string]::IsNullOrWhiteSpace($path)) { continue }
		if (!(Test-Path -LiteralPath $path)) { throw "RPT not found: $path" }
		$item = Get-Item -LiteralPath $path
		if ($item.PSIsContainer) { throw "RptPath must be a file, got directory: $path" }
		$files.Add($item.FullName)
	}
	foreach ($dir in $RptDirectory) {
		if ([string]::IsNullOrWhiteSpace($dir)) { continue }
		if (!(Test-Path -LiteralPath $dir)) { throw "RPT directory not found: $dir" }
		$searchOption = if ($Recurse) { [System.IO.SearchOption]::AllDirectories } else { [System.IO.SearchOption]::TopDirectoryOnly }
		foreach ($file in [System.IO.Directory]::EnumerateFiles((Resolve-Path -LiteralPath $dir).Path, "*.rpt", $searchOption)) {
			$files.Add($file)
		}
		foreach ($file in [System.IO.Directory]::EnumerateFiles((Resolve-Path -LiteralPath $dir).Path, "*.RPT", $searchOption)) {
			$files.Add($file)
		}
	}
	return @($files | Select-Object -Unique)
}

function Get-RptLineWindow {
	param(
		[Parameter(Mandatory)] [string]$Path,
		[Parameter(Mandatory)] [string]$Marker
	)

	$fs = [System.IO.File]::Open($Path,
		[System.IO.FileMode]::Open,
		[System.IO.FileAccess]::Read,
		[System.IO.FileShare]::ReadWrite)
	try {
		$reader = New-Object System.IO.StreamReader($fs)
		try { $content = $reader.ReadToEnd() } finally { $reader.Dispose() }
	} finally {
		$fs.Dispose()
	}

	$allLines = @($content -split "`r?`n")
	$startIndex = 0
	$markerFound = $false
	for ($i = $allLines.Count - 1; $i -ge 0; $i--) {
		if ($allLines[$i] -match $Marker) {
			$startIndex = $i
			$markerFound = $true
			break
		}
	}

	# Keep the full startup banner when the final hit is MISSINIT/Build/LOG CONTENT.
	# The release marker is logged between Build and MISSINIT, so starting at MISSINIT
	# alone would incorrectly hide the exact candidate marker from the evidence window.
	if ($Marker -eq "MISSINIT|## (Mission Name|Build|LOG CONTENT)" -and $allLines[$startIndex] -match "MISSINIT|## (Build|LOG CONTENT)") {
		for ($j = $startIndex; $j -ge ([Math]::Max(0, $startIndex - 20)); $j--) {
			if ($allLines[$j] -match "## Mission Name") {
				$startIndex = $j
				break
			}
		}
	}

	$windowLines = if ($startIndex -gt 0) { @($allLines[$startIndex..($allLines.Count - 1)]) } else { @($allLines) }
	return [ordered]@{
		lines = $windowLines
		rawLineCount = $allLines.Count
		windowStartLine = $startIndex + 1
		windowLineCount = $windowLines.Count
		windowMarkerFound = $markerFound
	}
}

function New-Counts {
	param([object[]]$Specs)
	$counts = [ordered]@{}
	foreach ($spec in $Specs) { $counts[$spec.Name] = 0 }
	return $counts
}

function Add-Counts {
	param($Target, $Source)
	foreach ($key in @($Source.Keys)) {
		if (!$Target.Contains($key)) { $Target[$key] = 0 }
		$Target[$key] += [int]$Source.Item($key)
	}
}

function Test-AnyCount {
	param($Counts, [string[]]$Keys)
	foreach ($key in $Keys) {
		if ($Counts.Contains($key) -and [int]$Counts[$key] -gt 0) { return $true }
	}
	return $false
}

function Test-TokenGate {
	param($Gate, $Counts)
	$missing = @()
	$failHits = @()
	foreach ($key in @($Gate.required)) {
		if (!$Counts.Contains($key) -or [int]$Counts[$key] -eq 0) { $missing += $key }
	}
	if ($Gate.Contains("minCounts")) {
		foreach ($key in @($Gate.minCounts.Keys)) {
			$actual = if ($Counts.Contains($key)) { [int]$Counts[$key] } else { 0 }
			$minimum = [int]$Gate.minCounts[$key]
			if ($actual -lt $minimum) { $missing += ("{0}>={1} (actual {2})" -f $key, $minimum, $actual) }
		}
	}
	if ($Gate.Contains("anyOf")) {
		foreach ($group in @($Gate.anyOf)) {
			$matched = $false
			foreach ($key in @($group.keys)) {
				if ($Counts.Contains($key) -and [int]$Counts[$key] -gt 0) {
					$matched = $true
					break
				}
			}
			if (!$matched) {
				$missing += ("{0}: one of {1}" -f $group.label, (($group.keys) -join ","))
			}
		}
	}
	foreach ($key in @($Gate.fail)) {
		if ($Counts.Contains($key) -and [int]$Counts[$key] -gt 0) { $failHits += $key }
	}
	$status = "pass"
	if ($failHits.Count -gt 0) { $status = "fail" }
	elseif ($missing.Count -gt 0) { $status = "missing" }
	return [ordered]@{
		status = $status
		missing = $missing
		failHits = $failHits
	}
}

$stopSpecs = @(
	[pscustomobject]@{ Name = "errorInExpression"; Pattern = "Error in expression" },
	[pscustomobject]@{ Name = "undefinedVariable"; Pattern = "Undefined variable" },
	[pscustomobject]@{ Name = "noEntry"; Pattern = "No entry" },
	[pscustomobject]@{ Name = "missingSemicolon"; Pattern = "Missing ;" },
	[pscustomobject]@{ Name = "genericError"; Pattern = "Generic error" },
	[pscustomobject]@{ Name = "errorPosition"; Pattern = "Error position" },
	[pscustomobject]@{ Name = "unknownCommand"; Pattern = "Unknown command" },
	[pscustomobject]@{ Name = "cannotLoadTexture"; Pattern = "Cannot load texture" },
	[pscustomobject]@{ Name = "cannotOpenObject"; Pattern = "Cannot open object" }
)

$tokenSpecs = @(
	[pscustomobject]@{ Name = "aicomHbWest"; Pattern = "AICOMHB\|v1\|west\|" },
	[pscustomobject]@{ Name = "aicomHbEast"; Pattern = "AICOMHB\|v1\|east\|" },
	[pscustomobject]@{ Name = "aicomTickWest"; Pattern = "AICOMSTAT\|v1\|TICK\|west\|" },
	[pscustomobject]@{ Name = "aicomTickEast"; Pattern = "AICOMSTAT\|v1\|TICK\|east\|" },
	[pscustomobject]@{ Name = "aicomEvent"; Pattern = "AICOMSTAT\|v2\|EVENT" },
	[pscustomobject]@{ Name = "aicomTeamFounded"; Pattern = "AICOMSTAT\|v[12]\|EVENT\|.*\|TEAM_FOUNDED" },
	[pscustomobject]@{ Name = "aicomAssaultDispatch"; Pattern = "AICOMSTAT\|v2\|EVENT\|.*\|ASSAULT_DISPATCH" },
	[pscustomobject]@{ Name = "aicomCombatStatus"; Pattern = "COMBATSTAT" },
	[pscustomobject]@{ Name = "aicomFront"; Pattern = "AICOMSTAT\|v1\|FRONT\|" },
	[pscustomobject]@{ Name = "aicomPosture"; Pattern = "AICOMSTAT\|v1\|POSTURE\|" },
	[pscustomobject]@{ Name = "aicomSnapshot"; Pattern = "AICOM2\|v1\|SNAP\|" },
	[pscustomobject]@{ Name = "aiCommanderActive"; Pattern = "AI commander ACTIVE" },
	[pscustomobject]@{ Name = "aiCommanderAssist"; Pattern = "AI commander ASSIST" },
	[pscustomobject]@{ Name = "aicomOrder"; Pattern = "AICOM2\|v1\|ORDER\|aicom-ai-command" },
	[pscustomobject]@{ Name = "cmdrStat"; Pattern = "CMDRSTAT\|v1" },
	[pscustomobject]@{ Name = "srvPerf"; Pattern = "SRVPERF\|v1" },
	[pscustomobject]@{ Name = "grpBudget"; Pattern = "GRPBUDGET\|v1" },
	[pscustomobject]@{ Name = "watchdogRestart"; Pattern = "WATCHDOG\|restart-stale-hb" },
	[pscustomobject]@{ Name = "hqKilled"; Pattern = "Server_OnHQKilled\.sqf|Server_OnHQKilled" },
	[pscustomobject]@{ Name = "roundEnd"; Pattern = "WASPSTAT\|v1\|.*ROUNDEND" },
	[pscustomobject]@{ Name = "jipMark"; Pattern = "B63 JIP-MARK" },
	[pscustomobject]@{ Name = "teamsRebc"; Pattern = "B74\.2\.4 TEAMS-REBC" },
	[pscustomobject]@{ Name = "rosterPush"; Pattern = "B74\.2\.5 ROSTER-PUSH" },
	[pscustomobject]@{ Name = "jipFunds"; Pattern = "JIPFUNDS" },
	[pscustomobject]@{ Name = "clientRosterRecv"; Pattern = "CLIENTROSTER\|RECV" },
	[pscustomobject]@{ Name = "clientRosterPollAdopt"; Pattern = "CLIENTROSTER\|POLL-ADOPT" },
	[pscustomobject]@{ Name = "hqMark"; Pattern = "HQ-MARK" },
	[pscustomobject]@{ Name = "connectBailB746"; Pattern = "B746 CONNECT BAIL" },
	[pscustomobject]@{ Name = "connectBailB747"; Pattern = "B747\.2 CONNECT BAIL" },
	[pscustomobject]@{ Name = "stampMissB762"; Pattern = "B762 STAMP-ON-DEMAND MISS" },
	[pscustomobject]@{ Name = "hcSide"; Pattern = "HCSIDE\|v1" },
	[pscustomobject]@{ Name = "hcConnect"; Pattern = "HCSIDE\|v1\|connect\|" },
	[pscustomobject]@{ Name = "hcConnectCivilian"; Pattern = "HCSIDE\|v1\|connect\|.*owner=[1-9][0-9]*\|side=(CIV|civilian)" },
	[pscustomobject]@{ Name = "hcConnectNonCivilian"; Pattern = "HCSIDE\|v1\|connect\|.*\|side=(WEST|EAST|GUER|LOGIC)" },
	[pscustomobject]@{ Name = "hcConnectSkip"; Pattern = "HCSIDE\|v1\|connect-skip" },
	[pscustomobject]@{ Name = "hcStat"; Pattern = "HCSTAT\|v1" },
	[pscustomobject]@{ Name = "hcDeleg"; Pattern = "HCDELEG\|v1" },
	[pscustomobject]@{ Name = "delegStat"; Pattern = "DELEGSTAT\|v1" },
	[pscustomobject]@{ Name = "teamFoundedViaHC"; Pattern = "TEAM_FOUNDED\|via=HC" },
	[pscustomobject]@{ Name = "hcConnectFailed"; Pattern = "connect-failed|connect-deferred|HCDISPATCH_REAP|No owner|local - update is ignored" },
	[pscustomobject]@{ Name = "townActivated"; Pattern = "server_town_ai\.sqf: Town .* ACTIVATED" },
	[pscustomobject]@{ Name = "townDeactivated"; Pattern = "server_town_ai\.sqf: Town .* DEACTIVATED" },
	[pscustomobject]@{ Name = "townAiHcCleanup"; Pattern = "TOWN_AI_HC_CLEANUP" },
	[pscustomobject]@{ Name = "townCleanupKeptZero"; Pattern = "keptGroups:0" },
	[pscustomobject]@{ Name = "townGroupCleanupAfter"; Pattern = "TOWN_GROUP_COUNT cleanup_after" },
	[pscustomobject]@{ Name = "gcStat"; Pattern = "GCSTAT\|v1" },
	[pscustomobject]@{ Name = "emptyGrp"; Pattern = "EMPTYGRP\|v1" },
	[pscustomobject]@{ Name = "clientEmptyGroupCleanup"; Pattern = "CLIENT_EMPTY_GROUP_CLEANUP\|v1" },
	[pscustomobject]@{ Name = "townCleanupFail"; Pattern = "TOWN_GROUP_COUNT create_failed|TOWN_AI_HC_CLEANUP group_not_empty|keptGroups:[1-9]|GRPBUDGET\|v1\|WARN" },
	[pscustomobject]@{ Name = "wddmArtilleryAudit"; Pattern = "WDDM_ARTILLERY_AUDIT" },
	[pscustomobject]@{ Name = "wddmArtillerySide"; Pattern = "WDDM_ARTILLERY_SIDE" },
	[pscustomobject]@{ Name = "structureBuiltReserve"; Pattern = "STRUCTURE_BUILT\|struct=Reserve" },
	[pscustomobject]@{ Name = "structureBuiltArtilleryRadar"; Pattern = "STRUCTURE_BUILT\|struct=ArtilleryRadar" },
	[pscustomobject]@{ Name = "artyThreatArmed"; Pattern = "ARTY_THREAT_ARMED" },
	[pscustomobject]@{ Name = "artyReq"; Pattern = "AICOM2\|v1\|ARTYREQ" },
	[pscustomobject]@{ Name = "fireMission"; Pattern = "FIRE_MISSION" },
	[pscustomobject]@{ Name = "supplyLoaded"; Pattern = "SupplyMissionStart\.sqf: Player .* loaded" },
	[pscustomobject]@{ Name = "supplyUnloadTimer"; Pattern = "SupplyMissionUnload\.sqf: Player .* started helicopter unload timer" },
	[pscustomobject]@{ Name = "supplyCompleted"; Pattern = "SupplyMissionCompleted\.sqf: Completion accepted|TRIGGER supplyCompletion" },
	[pscustomobject]@{ Name = "supplyInterdiction"; Pattern = "TRIGGER supplyInterdiction|Logistics interdiction" },
	[pscustomobject]@{ Name = "serviceSupplyAudit"; Pattern = "SERVICE_SUPPLY_AUDIT" },
	[pscustomobject]@{ Name = "heliTerrainGuardOn"; Pattern = "server_heli_terrain_guard\.sqf: AI-heli terrain guard ON" },
	[pscustomobject]@{ Name = "clientLogicError"; Pattern = "WFBE_Client_Logic setVariable|Undefined variable.*WFBE_Client_Logic" }
)

$gateSpecs = @(
	[ordered]@{
		id = "terrain-coverage"
		required = @()
		fail = @()
		note = "Requires evidence from both Chernarus and Takistan sessions."
	},
	[ordered]@{
		id = "aicom-no-human"
		required = @("aicomHbWest","aicomHbEast","aicomTickWest","aicomTickEast","aiCommanderActive","aicomEvent","aicomTeamFounded","cmdrStat","srvPerf","grpBudget")
		anyOf = @(
			[ordered]@{
				label = "aicom-action-or-progress"
				keys = @("aicomAssaultDispatch","aicomCombatStatus","aicomFront","aicomPosture","aicomSnapshot")
			}
		)
		fail = @("watchdogRestart")
		note = "No-human AI commander heartbeat/tick/progress gate; requires team founding plus at least one autonomous AICOM action/progress token."
	},
	[ordered]@{
		id = "human-takeover-revert"
		required = @("aiCommanderAssist","aicomOrder","aiCommanderActive")
		fail = @()
		note = "Human commander assist/order/revert evidence; still needs human observation for autonomous pause/resume."
	},
	[ordered]@{
		id = "hq-death-and-jip"
		required = @("jipMark","teamsRebc","rosterPush","jipFunds","clientRosterRecv","clientRosterPollAdopt","hqMark")
		fail = @("connectBailB746","connectBailB747","stampMissB762")
		note = "Late-JIP enrollment and HUD/marker evidence; client fade/playability remains observational."
	},
	[ordered]@{
		id = "hc-delegation-locality"
		required = @("hcSide","hcStat","hcDeleg","delegStat","teamFoundedViaHC")
		fail = @("hcConnectFailed")
		note = "HC connection, delegation, and remote founding evidence."
	},
	[ordered]@{
		id = "hc-registry-civilian"
		required = @()
		minCounts = @{ hcConnectCivilian = 2 }
		fail = @("hcConnectFailed","hcConnectNonCivilian","hcConnectSkip")
		note = "Requires at least two successful HCSIDE connect rows with non-zero owner and CIV side; generic preseat/reseat lines do not satisfy the registry gate."
	},
	[ordered]@{
		id = "town-ai-cleanup"
		required = @("townActivated","townDeactivated","townAiHcCleanup","townCleanupKeptZero","townGroupCleanupAfter","gcStat")
		fail = @("townCleanupFail")
		note = "Town activation/deactivation and cleanup evidence."
	},
	[ordered]@{
		id = "wddm-static-artillery"
		required = @("wddmArtilleryAudit","wddmArtillerySide","structureBuiltReserve","structureBuiltArtilleryRadar","artyThreatArmed")
		fail = @()
		note = "WDDM/static defense and artillery discoverability evidence. FIRE_MISSION is reported separately."
	},
	[ordered]@{
		id = "supply-truck-heli"
		required = @("supplyLoaded","supplyUnloadTimer","supplyCompleted","serviceSupplyAudit")
		fail = @()
		note = "Supply load/unload/completion/service audit evidence; cash-run/JIP cooldown still needs human-readable notes."
	}
)

$runtimeTerrains = @("chernarus","takistan")
$perTerrainRuntimeGateIds = @(
	"aicom-no-human",
	"hq-death-and-jip",
	"hc-delegation-locality",
	"hc-registry-civilian",
	"town-ai-cleanup",
	"wddm-static-artillery",
	"supply-truck-heli"
)
$perTerrainRuntimeGateSpecs = @($gateSpecs | Where-Object { $perTerrainRuntimeGateIds -contains [string]$_.id })

$files = Get-RptFiles
if ($files.Count -eq 0) {
	Write-Host "FAIL: pass -RptPath or -RptDirectory with at least one RPT." -ForegroundColor Red
	exit 1
}
$publicRptRoots = @()
foreach ($dir in $RptDirectory) {
	if (![string]::IsNullOrWhiteSpace($dir) -and (Test-Path -LiteralPath $dir)) {
		$publicRptRoots += (Resolve-Path -LiteralPath $dir).Path
	}
}

$totalCounts = New-Counts $tokenSpecs
$totalStopCounts = New-Counts $stopSpecs
$totalStopMatches = 0
$terrainCounts = [ordered]@{}
foreach ($terrain in $runtimeTerrains) { $terrainCounts[$terrain] = New-Counts $tokenSpecs }
$fileSummaries = @()
$worlds = New-Object System.Collections.Generic.HashSet[string]
$markerCounts = [ordered]@{}
foreach ($marker in $ExpectedMarker) {
	if (![string]::IsNullOrWhiteSpace($marker)) { $markerCounts[$marker] = 0 }
}

foreach ($file in $files) {
	$item = Get-Item -LiteralPath $file
	$window = Get-RptLineWindow -Path $item.FullName -Marker $WindowMarker
	$lines = @($window.lines)
	$fileCounts = New-Counts $tokenSpecs
	$fileStopCounts = New-Counts $stopSpecs
	$fileTerrainHits = New-Object System.Collections.Generic.List[string]
	$sessions = @()
	$builds = @()
	$startupMissionBannerFound = $false
	$startupBuildBannerFound = $false
	for ($i = 0; $i -lt $lines.Count; $i++) {
		$line = $lines[$i]
		$absoluteLine = [int]$window.windowStartLine + $i
		if ($line -match "## Mission Name") { $startupMissionBannerFound = $true }
		if ($line -match "WASPRELEASE\|v1\|.*\|terrain=(chernarus|takistan)") {
			$terrain = $matches[1].Trim().ToLowerInvariant()
			[void]$worlds.Add($terrain)
			$fileTerrainHits.Add($terrain)
		}
		if ($line -match "MISSINIT: missionName=([^,]+), worldName=([^,]+), isMultiplayer=([^,]+), isServer=([^,]+), isDedicated=([^\]]+)") {
			$world = $matches[2].Trim().ToLowerInvariant()
			[void]$worlds.Add($world)
			if ($runtimeTerrains -contains $world) { $fileTerrainHits.Add($world) }
			$sessions += [ordered]@{
				line = $absoluteLine
				missionName = $matches[1]
				worldName = $matches[2]
				isMultiplayer = $matches[3]
				isServer = $matches[4]
				isDedicated = ($matches[5] -replace '"', '').Trim()
			}
		}
		if ($line -match "SID=[^ ]+ MAP=([^ ]+)") {
			$world = $matches[1].Trim().ToLowerInvariant()
			[void]$worlds.Add($world)
			if ($runtimeTerrains -contains $world) { $fileTerrainHits.Add($world) }
		}
		if ($line -match "## Build: (.+)") {
			$startupBuildBannerFound = $true
			$builds += [ordered]@{ line = $absoluteLine; build = ($matches[1] -replace '"', '').Trim() }
		}
		foreach ($marker in @($markerCounts.Keys)) {
			if ($line.Contains($marker)) { $markerCounts[$marker]++ }
		}
		foreach ($spec in $stopSpecs) {
			if ($line -match $spec.Pattern) {
				$fileStopCounts[$spec.Name]++
				$totalStopCounts[$spec.Name]++
				$totalStopMatches++
			}
		}
		foreach ($spec in $tokenSpecs) {
			if ($line -match $spec.Pattern) { $fileCounts[$spec.Name]++ }
		}
	}
	Add-Counts $totalCounts $fileCounts
	$scoredTerrains = @($fileTerrainHits.ToArray() | Select-Object -Unique)
	if ($scoredTerrains.Count -eq 1) {
		Add-Counts $terrainCounts[$scoredTerrains[0]] $fileCounts
	}
	$fileSummaries += [ordered]@{
		path = ConvertTo-PublicRptLabel -Path $item.FullName -Roots $publicRptRoots
		pathHash = Get-SafeTextHash $item.FullName
		lastWriteTime = $item.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:sszzz")
		lengthBytes = $item.Length
		rawLineCount = [int]$window.rawLineCount
		lineCount = $lines.Count
		windowMarker = $WindowMarker
		windowMarkerFound = [bool]$window.windowMarkerFound
		windowStartLine = [int]$window.windowStartLine
		startupMissionBannerFound = [bool]$startupMissionBannerFound
		startupBuildBannerFound = [bool]$startupBuildBannerFound
		scoredTerrains = $scoredTerrains
		sessions = $sessions
		builds = $builds
		stopCounts = $fileStopCounts
		stopMatchCount = ($fileStopCounts.Values | Measure-Object -Sum).Sum
		tokenCounts = $fileCounts
	}
}

$gateResults = @()
$stopFailHits = @()
foreach ($key in @($totalStopCounts.Keys)) {
	if ([int]$totalStopCounts[$key] -gt 0) { $stopFailHits += ("{0}={1}" -f $key, $totalStopCounts[$key]) }
}
$gateResults += [ordered]@{
	id = "no-stop-condition-matches"
	status = if ($totalStopMatches -eq 0) { "pass" } else { "fail" }
	missing = @()
	failHits = $stopFailHits
	note = "Generic RPT stop-condition scan in current-mission windows only; no raw RPT lines are emitted."
}
$filesWithoutStartupBanner = @($fileSummaries | Where-Object { -not $_.startupMissionBannerFound })
$gateResults += [ordered]@{
	id = "all-files-have-startup-banner"
	status = if ($filesWithoutStartupBanner.Count -eq 0) { "pass" } else { "fail" }
	missing = @($filesWithoutStartupBanner | ForEach-Object { $_.path })
	failHits = @()
	note = "Each scored current-mission window must retain the startup Mission Name banner before release evidence is accepted."
}
$filesWithoutSingleTerrain = @($fileSummaries | Where-Object { @($_.scoredTerrains).Count -ne 1 })
$gateResults += [ordered]@{
	id = "all-files-have-single-runtime-terrain"
	status = if ($filesWithoutSingleTerrain.Count -eq 0) { "pass" } else { "fail" }
	missing = @($filesWithoutSingleTerrain | ForEach-Object { $_.path })
	failHits = @()
	note = "Each scored RPT window must resolve to exactly one release terrain before per-terrain runtime evidence is accepted."
}
if ($markerCounts.Count -gt 0) {
	$missingMarkers = @()
	foreach ($marker in @($markerCounts.Keys)) {
		if ([int]$markerCounts[$marker] -eq 0) { $missingMarkers += $marker }
	}
	$gateResults += [ordered]@{
		id = "expected-marker"
		status = if ($missingMarkers.Count -eq 0) { "pass" } else { "missing" }
		missing = $missingMarkers
		failHits = @()
		note = "Expected branch/commit/build marker coverage."
	}
}
foreach ($gate in $gateSpecs) {
	$missing = @()
	$failHits = @()
	if ($gate.id -eq "terrain-coverage") {
		foreach ($world in $runtimeTerrains) {
			if (!$worlds.Contains($world)) { $missing += $world }
		}
	} else {
		$assessment = Test-TokenGate -Gate $gate -Counts $totalCounts
		$missing = $assessment.missing
		$failHits = $assessment.failHits
	}
	$status = "pass"
	if ($failHits.Count -gt 0) { $status = "fail" }
	elseif ($missing.Count -gt 0) { $status = "missing" }
	$gateResults += [ordered]@{
		id = $gate.id
		status = $status
		missing = $missing
		failHits = $failHits
		note = $gate.note
	}
	if ($gate.id -eq "terrain-coverage") {
		$perTerrainMissing = @()
		$perTerrainFailHits = @()
		foreach ($terrain in $runtimeTerrains) {
			foreach ($terrainGate in $perTerrainRuntimeGateSpecs) {
				$terrainAssessment = Test-TokenGate -Gate $terrainGate -Counts $terrainCounts[$terrain]
				foreach ($item in @($terrainAssessment.missing)) {
					$perTerrainMissing += ("{0}:{1}:{2}" -f $terrain, $terrainGate.id, $item)
				}
				foreach ($item in @($terrainAssessment.failHits)) {
					$perTerrainFailHits += ("{0}:{1}:{2}" -f $terrain, $terrainGate.id, $item)
				}
			}
		}
		$perTerrainStatus = "pass"
		if ($perTerrainFailHits.Count -gt 0) { $perTerrainStatus = "fail" }
		elseif ($perTerrainMissing.Count -gt 0) { $perTerrainStatus = "missing" }
		$gateResults += [ordered]@{
			id = "per-terrain-runtime-evidence"
			status = $perTerrainStatus
			missing = $perTerrainMissing
			failHits = $perTerrainFailHits
			note = "Requires core AICOM, JIP, HC, town-cleanup, WDDM/static/artillery and supply evidence independently for Chernarus and Takistan."
		}
	}
}

$overallPass = (@($gateResults | Where-Object { $_.status -ne "pass" }).Count -eq 0)
$result = [ordered]@{
	schema = "a2waspwarfare-release-rpt-evidence-v1"
	generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
	windowMarker = $WindowMarker
	files = $fileSummaries
	worldsSeen = @($worlds)
	expectedMarkerCounts = $markerCounts
	tokenCounts = $totalCounts
	perTerrainTokenCounts = $terrainCounts
	stopCounts = $totalStopCounts
	stopMatchCount = $totalStopMatches
	gates = $gateResults
	overall = if ($overallPass) { "pass" } else { "missing_or_failed" }
	privacy = "No raw RPT lines or absolute paths are emitted; file labels are RPT-root-relative when possible and include short path hashes."
}

if ($Json) {
	$result | ConvertTo-Json -Depth 10
} else {
	Write-Host "WASP release RPT evidence check"
	Write-Host "Files: $($files.Count)"
	Write-Host "Window marker: $WindowMarker"
	Write-Host "Worlds seen: $((@($worlds) | Sort-Object) -join ', ')"
	Write-Host "Stop-condition matches: $totalStopMatches"
	if ($markerCounts.Count -gt 0) {
		Write-Host "Expected markers:"
		foreach ($marker in $markerCounts.Keys) {
			Write-Host ("{0,-28} {1}" -f $marker, $markerCounts[$marker])
		}
	}
	Write-Host ""
	Write-Host "Gate results:"
	foreach ($gate in $gateResults) {
		$detail = ""
		if ($gate.missing.Count -gt 0) { $detail += " missing=$($gate.missing -join ',')" }
		if ($gate.failHits.Count -gt 0) { $detail += " failHits=$($gate.failHits -join ',')" }
		Write-Host ("{0,-26} {1,-8}{2}" -f $gate.id, $gate.status, $detail)
	}
	Write-Host ""
	Write-Host "Selected token counts:"
	foreach ($key in @("aicomHbWest","aicomHbEast","aicomTickWest","aicomTickEast","aicomEvent","aicomTeamFounded","aicomAssaultDispatch","aicomCombatStatus","aicomFront","aicomPosture","aicomSnapshot","aiCommanderActive","hcSide","hcConnect","hcConnectCivilian","hcConnectNonCivilian","hcConnectSkip","hcStat","hcDeleg","delegStat","teamFoundedViaHC","jipMark","clientRosterRecv","hqMark","townAiHcCleanup","wddmArtilleryAudit","supplyLoaded","supplyCompleted","clientLogicError")) {
		Write-Host ("{0,-28} {1}" -f $key, $totalCounts[$key])
	}
	Write-Host ""
	if ($overallPass) {
		Write-Host "PASS: release RPT evidence gates have matching tokens." -ForegroundColor Green
	} else {
		Write-Host "FAIL: release RPT evidence is missing or has fail-token hits." -ForegroundColor Red
	}
}

if (!$overallPass -and !$NoFail) { exit 1 }
