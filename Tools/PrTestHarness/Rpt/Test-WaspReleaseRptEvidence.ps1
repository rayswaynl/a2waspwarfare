[CmdletBinding()]
param(
	[string[]]$RptPath = @(),
	[string[]]$RptDirectory = @(),
	[string[]]$ExpectedMarker = @(),
	[switch]$Recurse,
	[switch]$Json,
	[switch]$NoFail
)

$ErrorActionPreference = "Stop"

function ConvertTo-SafePath {
	param([string]$Path)
	$safe = $Path
	if (![string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
		$safe = $safe -replace [regex]::Escape($env:USERPROFILE), "%USERPROFILE%"
	}
	return $safe
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

function New-Counts {
	param([object[]]$Specs)
	$counts = [ordered]@{}
	foreach ($spec in $Specs) { $counts[$spec.Name] = 0 }
	return $counts
}

function Add-Counts {
	param($Target, $Source)
	foreach ($key in $Source.Keys) {
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

$tokenSpecs = @(
	[pscustomobject]@{ Name = "aicomHbWest"; Pattern = "AICOMHB\|v1\|west\|" },
	[pscustomobject]@{ Name = "aicomHbEast"; Pattern = "AICOMHB\|v1\|east\|" },
	[pscustomobject]@{ Name = "aicomTickWest"; Pattern = "AICOMSTAT\|v1\|TICK\|west\|" },
	[pscustomobject]@{ Name = "aicomTickEast"; Pattern = "AICOMSTAT\|v1\|TICK\|east\|" },
	[pscustomobject]@{ Name = "aicomEvent"; Pattern = "AICOMSTAT\|v2\|EVENT" },
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
		required = @("aicomHbWest","aicomHbEast","aicomTickWest","aicomTickEast","aiCommanderActive","cmdrStat","srvPerf","grpBudget")
		fail = @("watchdogRestart")
		note = "No-human AI commander heartbeat/tick/progress gate."
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

$files = Get-RptFiles
if ($files.Count -eq 0) {
	Write-Host "FAIL: pass -RptPath or -RptDirectory with at least one RPT." -ForegroundColor Red
	exit 1
}

$totalCounts = New-Counts $tokenSpecs
$fileSummaries = @()
$worlds = New-Object System.Collections.Generic.HashSet[string]
$markerCounts = [ordered]@{}
foreach ($marker in $ExpectedMarker) {
	if (![string]::IsNullOrWhiteSpace($marker)) { $markerCounts[$marker] = 0 }
}

foreach ($file in $files) {
	$item = Get-Item -LiteralPath $file
	$lines = @(Get-Content -LiteralPath $file)
	$fileCounts = New-Counts $tokenSpecs
	$sessions = @()
	$builds = @()
	for ($i = 0; $i -lt $lines.Count; $i++) {
		$line = $lines[$i]
		if ($line -match "MISSINIT: missionName=([^,]+), worldName=([^,]+), isMultiplayer=([^,]+), isServer=([^,]+), isDedicated=([^\]]+)") {
			$world = $matches[2].Trim().ToLowerInvariant()
			[void]$worlds.Add($world)
			$sessions += [ordered]@{
				line = $i + 1
				missionName = $matches[1]
				worldName = $matches[2]
				isMultiplayer = $matches[3]
				isServer = $matches[4]
				isDedicated = ($matches[5] -replace '"', '').Trim()
			}
		}
		if ($line -match "SID=[^ ]+ MAP=([^ ]+)") {
			[void]$worlds.Add($matches[1].Trim().ToLowerInvariant())
		}
		if ($line -match "## Build: (.+)") {
			$builds += [ordered]@{ line = $i + 1; build = ($matches[1] -replace '"', '').Trim() }
		}
		foreach ($marker in $markerCounts.Keys) {
			if ($line.Contains($marker)) { $markerCounts[$marker]++ }
		}
		foreach ($spec in $tokenSpecs) {
			if ($line -match $spec.Pattern) { $fileCounts[$spec.Name]++ }
		}
	}
	Add-Counts $totalCounts $fileCounts
	$fileSummaries += [ordered]@{
		path = ConvertTo-SafePath $item.FullName
		lastWriteTime = $item.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:sszzz")
		lengthBytes = $item.Length
		lineCount = $lines.Count
		sessions = $sessions
		builds = $builds
		tokenCounts = $fileCounts
	}
}

$gateResults = @()
if ($markerCounts.Count -gt 0) {
	$missingMarkers = @()
	foreach ($marker in $markerCounts.Keys) {
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
		foreach ($world in @("chernarus","takistan")) {
			if (!$worlds.Contains($world)) { $missing += $world }
		}
	} else {
		foreach ($key in $gate.required) {
			if (!$totalCounts.Contains($key) -or [int]$totalCounts[$key] -eq 0) { $missing += $key }
		}
		foreach ($key in $gate.fail) {
			if ($totalCounts.Contains($key) -and [int]$totalCounts[$key] -gt 0) { $failHits += $key }
		}
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
}

$overallPass = (@($gateResults | Where-Object { $_.status -ne "pass" }).Count -eq 0)
$result = [ordered]@{
	schema = "a2waspwarfare-release-rpt-evidence-v1"
	generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
	files = $fileSummaries
	worldsSeen = @($worlds)
	expectedMarkerCounts = $markerCounts
	tokenCounts = $totalCounts
	gates = $gateResults
	overall = if ($overallPass) { "pass" } else { "missing_or_failed" }
	privacy = "No raw RPT lines are emitted; paths are user-profile redacted."
}

if ($Json) {
	$result | ConvertTo-Json -Depth 10
} else {
	Write-Host "WASP release RPT evidence check"
	Write-Host "Files: $($files.Count)"
	Write-Host "Worlds seen: $((@($worlds) | Sort-Object) -join ', ')"
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
	foreach ($key in @("aicomHbWest","aicomHbEast","aicomTickWest","aicomTickEast","aiCommanderActive","hcSide","hcStat","hcDeleg","delegStat","teamFoundedViaHC","jipMark","clientRosterRecv","hqMark","townAiHcCleanup","wddmArtilleryAudit","supplyLoaded","supplyCompleted","clientLogicError")) {
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
