param(
	[string]$RptPath = "",
	[string]$LogDirectory = "",
	[string]$AllowListPath = "",
	[string[]]$AllowPattern = @(),
	[string]$MissionIssuePatternPath = "",
	[int]$Tail = 0,
	[switch]$CurrentRun,
	[switch]$LiveSummary,
	[switch]$Json
)

$ErrorActionPreference = "Stop"

function Get-LatestRpt {
	param([string[]]$Directories)
	$candidates = @()
	foreach ($dir in $Directories) {
		if ([string]::IsNullOrWhiteSpace($dir)) { continue }
		if (!(Test-Path -LiteralPath $dir)) { continue }
		$candidates += Get-ChildItem -LiteralPath $dir -Filter "*.rpt" | Where-Object { -not $_.PSIsContainer }
	}
	if ($candidates.Count -eq 0) { return $null }
	return $candidates | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

function Test-AllowedNoise {
	param([string]$Line, [string[]]$Patterns)
	foreach ($pattern in $Patterns) {
		if ([string]::IsNullOrWhiteSpace($pattern)) { continue }
		if ($Line -match $pattern) { return $true }
		foreach ($candidate in ($Line -split "`r?`n")) {
			if ($candidate -match $pattern) { return $true }
		}
	}
	return $false
}

function Test-MissionIssue {
	param([string]$Line, [string[]]$Patterns)
	foreach ($pattern in $Patterns) {
		if ([string]::IsNullOrWhiteSpace($pattern)) { continue }
		if ($Line -match $pattern) { return $true }
		foreach ($candidate in ($Line -split "`r?`n")) {
			if ($candidate -match $pattern) { return $true }
		}
	}
	return $false
}

function Get-LineMetric {
	param([string]$Line, [string]$Name)
	if ($Line -match "\b$([regex]::Escape($Name))=(?<value>-?\d+)") {
		return [int]$matches["value"]
	}
	return $null
}

if ([string]::IsNullOrWhiteSpace($RptPath)) {
	$dirs = @()
	if (![string]::IsNullOrWhiteSpace($LogDirectory)) {
		$dirs += $LogDirectory
	} else {
		$dirs += (Join-Path $env:LOCALAPPDATA "ArmA 2 OA")
		$dirs += (Join-Path $env:LOCALAPPDATA "ArmA 2")
		$dirs += (Join-Path $env:USERPROFILE "AppData\Local\ArmA 2 OA")
	}
	$latest = Get-LatestRpt $dirs
	if ($null -eq $latest) {
		Write-Host "FAIL: no .rpt file found. Pass -RptPath or -LogDirectory." -ForegroundColor Red
		exit 1
	}
	$RptPath = $latest.FullName
}

$RptPath = (Resolve-Path -LiteralPath $RptPath).Path
if ([string]::IsNullOrWhiteSpace($AllowListPath)) {
	$AllowListPath = Join-Path $PSScriptRoot "KnownNoise.txt"
}
if ([string]::IsNullOrWhiteSpace($MissionIssuePatternPath)) {
	$MissionIssuePatternPath = Join-Path $PSScriptRoot "MissionIssuePatterns.txt"
}

$allow = @()
if (Test-Path -LiteralPath $AllowListPath) {
	$allow += Get-Content -LiteralPath $AllowListPath | Where-Object { $_.Trim().Length -gt 0 -and -not $_.TrimStart().StartsWith("#") }
}
$allow += $AllowPattern

$missionIssuePatterns = @()
if (Test-Path -LiteralPath $MissionIssuePatternPath) {
	$missionIssuePatterns += Get-Content -LiteralPath $MissionIssuePatternPath | Where-Object { $_.Trim().Length -gt 0 -and -not $_.TrimStart().StartsWith("#") }
}

$allLines = @(Get-Content -LiteralPath $RptPath)
$lines = $allLines
if ($Tail -gt 0 -and $allLines.Count -gt $Tail) {
	$lines = @($allLines | Select-Object -Last $Tail)
}

$currentRunId = ""
if ($CurrentRun) {
	$runHits = @($lines | Where-Object { $_ -match "\[WASP-PR8-STRESS\].*run=(?<run>[^\s]+)" })
	if ($runHits.Count -gt 0) {
		$lastRun = $runHits[-1]
		[void]($lastRun -match "\[WASP-PR8-STRESS\].*run=(?<run>[^\s]+)")
		$currentRunId = $matches["run"]
		for ($i = 0; $i -lt $lines.Count; $i++) {
			if ($lines[$i] -match "\[WASP-PR8-STRESS\].*run=$([regex]::Escape($currentRunId))") {
				$lines = @($lines[$i..($lines.Count - 1)])
				break
			}
		}
	}
}
$stressLines = @($lines | Where-Object { $_ -like "*[WASP-PR8-STRESS]*" })

$required = [ordered]@{
	"online" = "=== harness online"
	"profile" = "PROFILE selected="
	"phase-begin" = "PHASE_BEGIN"
	"snapshot" = "SNAPSHOT"
	"ai-behavior" = "AI_BEHAVIOR"
	"snapshot-side" = "SNAPSHOT_SIDE"
	"town-snapshot" = "TOWN_SNAPSHOT"
	"town-groups" = "TOWN_GROUPS"
	"town-pressure" = "TOWN_PRESSURE"
	"town-capture" = "TOWN_CAPTURE_FORCE"
	"town-camp-capture" = "TOWN_CAMP_CAPTURE_FORCE"
	"town-restore" = "TOWN_RESTORE"
	"action-matrix" = "ACTION_MATRIX"
	"supply-completion" = "TRIGGER supplyCompletion"
	"supply-interdiction" = "TRIGGER supplyInterdiction"
	"team-funds" = "TRIGGER teamFunds"
	"delayed-kill" = "PROBE delayedKill"
	"reinforcement" = "SPAWN reinforcement"
	"factory-audit" = "FACTORY_AUDIT"
	"service-supply-audit" = "SERVICE_SUPPLY_AUDIT"
	"wddm-artillery-audit" = "WDDM_ARTILLERY_AUDIT"
	"perf" = "PERF #"
	"noisecheck" = "NOISECHECK"
	"evidence" = "EVIDENCE"
}

$coverage = [ordered]@{}
$missing = @()
foreach ($key in $required.Keys) {
	$count = @($stressLines | Where-Object { $_ -like "*$($required[$key])*" }).Count
	$coverage[$key] = $count
	if ($count -eq 0) { $missing += $key }
}

$featureTriggerPatterns = [ordered]@{
	"wddm-probe" = "PROBE wddm"
	"hq-walls" = "hqWalls="
	"commander-artillery" = "commanderArtillery="
	"supply-completion" = "TRIGGER supplyCompletion"
	"supply-interdiction" = "TRIGGER supplyInterdiction"
	"team-funds" = "TRIGGER teamFunds"
	"town-capture" = "TOWN_CAPTURE_FORCE"
	"town-restore" = "TOWN_RESTORE"
	"client-command" = "CLIENT_COMMAND"
	"client-wave" = "SPAWN clientWave"
	"client-heavy-wave" = "SPAWN clientHeavyWave"
	"ai-audit" = "CLIENT_COMMAND_DONE ai-audit"
	"perf-burst" = "PERF_BURST"
	"vehicle-load" = "SPAWN vehicleLoad"
	"factory-audit" = "FACTORY_AUDIT"
	"service-supply-audit" = "SERVICE_SUPPLY_AUDIT"
	"wddm-artillery-audit" = "WDDM_ARTILLERY_AUDIT"
	"ui-audit" = "UI_AUDIT"
	"gps-ui-audit" = "GPS_UI_AUDIT"
	"client-gps-state" = "CLIENT_GPS_STATE"
	"client-ui-text-state" = "CLIENT_UI_TEXT_STATE"
	"client-service-clip-audit" = "CLIENT_SERVICE_CLIP_AUDIT"
	"ai-delegation-audit" = "AI_DELEGATION_AUDIT"
	"bughunt-audit" = "BUGHUNT_AUDIT"
	"random-bughunt-audit" = "RANDOM_BUGHUNT_AUDIT"
	"ai-deep-sample" = "CLIENT_COMMAND_DONE ai-deep-sample"
	"player-experience-audit" = "PLAYER_EXPERIENCE_AUDIT"
	"town-pressure-cleanup" = "TOWN_PRESSURE_CLEANUP"
	"queue-enqueue" = "QUEUE_ENQUEUE"
	"queue-step" = "QUEUE_STEP"
	"queue-proof" = "QUEUE_PROOF"
	"queue-end" = "QUEUE_END"
	"queue-not-triggered" = "QUEUE_NOT_TRIGGERED"
	"hc-ready" = "HC_READY"
	"hc-wait-timeout" = "HC_WAIT_TIMEOUT"
	"cleanup-loop" = "CLEANUP_LOOP"
	"dialog-auto-probe" = "DIALOG_AUTO_PROBE"
	"town-cap-regression-begin" = "TOWN_CAP_REGRESSION_BEGIN"
	"town-cap-force" = "TOWN_CAP_FORCE"
	"town-reman-ok" = "TOWN_REMAN_OK"
	"town-reman-fail" = "TOWN_REMAN_FAIL"
	"town-cap-leak" = "TOWN_CAP_LEAK"
	"town-cap-organic-result" = "TOWN_CAP_ORGANIC_RESULT"
	"town-cap-regression-end" = "TOWN_CAP_REGRESSION_END"
	"town-rapid-recap-ok" = "TOWN_RAPID_RECAP_OK"
	"town-rapid-recap-fail" = "TOWN_RAPID_RECAP_FAIL"
}
$featureTriggers = [ordered]@{}
foreach ($key in $featureTriggerPatterns.Keys) {
	$featureTriggers[$key] = @($stressLines | Where-Object { $_ -like "*$($featureTriggerPatterns[$key])*" }).Count
}

$fpsValues = @()
foreach ($line in $stressLines) {
	if ($line -match "PERF #\d+.*fps=(?<fps>[0-9]+(\.[0-9]+)?)") {
		$fpsValues += [double]$matches["fps"]
	}
}

$fpsMin = $null
$fpsAvg = $null
$fpsMax = $null
if ($fpsValues.Count -gt 0) {
	$fstats = $fpsValues | Measure-Object -Minimum -Average -Maximum
	$fpsMin = [math]::Round($fstats.Minimum, 1)
	$fpsAvg = [math]::Round($fstats.Average, 1)
	$fpsMax = [math]::Round($fstats.Maximum, 1)
}

$aiBehaviorLines = @($stressLines | Where-Object { $_ -like "*AI_BEHAVIOR*" })
$aiBehavior = [ordered]@{
	samples = $aiBehaviorLines.Count
	maxTrackedGroups = 0
	maxEmptyGroups = 0
	maxNoWaypoint = 0
	maxTrackedUnits = 0
	maxAliveTracked = 0
	maxStopped = 0
	maxReady = 0
	maxNoDestination = 0
	maxFarStopped = 0
	maxUnderStrengthGroups = 0
	maxLeaderFarStopped = 0
}
foreach ($line in $aiBehaviorLines) {
	foreach ($name in @("trackedGroups","emptyGroups","noWaypoint","underStrengthGroups","trackedUnits","aliveTracked","stopped","ready","noDestination","farStopped","leaderFarStopped")) {
		$value = Get-LineMetric $line $name
		if ($null -eq $value) { continue }
		$key = "max" + $name.Substring(0,1).ToUpperInvariant() + $name.Substring(1)
		if ($aiBehavior.Contains($key) -and $value -gt $aiBehavior[$key]) {
			$aiBehavior[$key] = $value
		}
	}
}

$aiSymptomPatterns = [ordered]@{
	"path-planning-region" = "Out of path-planning region"
	"wrong-unit-index" = "Wrong unit index"
	"unit-not-in-cargo" = "Unit is not in cargo"
	"local-update-ignored" = "local - update is ignored"
	"no-owner" = "\bNo owner\b"
	"ai-create-failure" = "(?i)cannot create ai|cannot create non-ai vehicle"
}
$aiSymptoms = [ordered]@{}
foreach ($key in $aiSymptomPatterns.Keys) {
	$aiSymptoms[$key] = @($lines | Where-Object { $_ -match $aiSymptomPatterns[$key] }).Count
}

$noisePattern = "(?i)(error in expression|error position|error undefined variable|undefined variable in expression|missing ;|generic error|script .* not found|cannot load|cannot open object|no entry|zero divisor|division by zero|warning message:)"
$unexpected = @()
$knownNoise = @()
$missionIssues = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
	$line = $lines[$i]
	if ($line -match $noisePattern) {
		$start = [math]::Max(0, $i - 8)
		$end = [math]::Min($lines.Count - 1, $i + 8)
		$context = ($lines[$start..$end] -join "`n")
		if ((Test-AllowedNoise $line $allow) -or (Test-AllowedNoise $context $allow)) {
			$knownNoise += $line
		} elseif ((Test-MissionIssue $line $missionIssuePatterns) -or (Test-MissionIssue $context $missionIssuePatterns)) {
			$missionIssues += $line
		} else {
			$unexpected += $line
		}
	}
}

$latestPerf = @($stressLines | Where-Object { $_ -like "*PERF #*" } | Select-Object -Last 1)
$latestAiBehavior = @($aiBehaviorLines | Select-Object -Last 1)
$summaryObject = [pscustomobject]@{
	rptPath = $RptPath
	currentRunId = $currentRunId
	lineCount = $lines.Count
	stressLineCount = $stressLines.Count
	latestPerf = if ($latestPerf.Count) { $latestPerf[0] } else { "" }
	latestAiBehavior = if ($latestAiBehavior.Count) { $latestAiBehavior[0] } else { "" }
	perfSamples = $fpsValues.Count
	fpsMin = $fpsMin
	fpsAvg = $fpsAvg
	fpsMax = $fpsMax
	aiBehaviorMax = $aiBehavior
	aiSymptoms = $aiSymptoms
	featureTriggers = $featureTriggers
	knownNoiseCount = $knownNoise.Count
	missionIssueCount = $missionIssues.Count
	unexpectedNoiseCount = $unexpected.Count
	coverage = $coverage
	missing = $missing
}

if ($Json) {
	$summaryObject | ConvertTo-Json -Depth 8
	exit 0
}

if ($LiveSummary) {
	Write-Host ("stress: lines={0} perf={1} fps={2}/{3}/{4} | ai samples={5} farStopped={6} leaderFarStopped={7} noDest={8} noWp={9} empty={10} underStrength={11}" -f $stressLines.Count, $fpsValues.Count, $fpsMin, $fpsAvg, $fpsMax, $aiBehavior.samples, $aiBehavior.maxFarStopped, $aiBehavior.maxLeaderFarStopped, $aiBehavior.maxNoDestination, $aiBehavior.maxNoWaypoint, $aiBehavior.maxEmptyGroups, $aiBehavior.maxUnderStrengthGroups)
	Write-Host ("triggers: supplyCompletion={0} supplyInterdiction={1} teamFunds={2} townCapture={3} clientWave={4} heavyWave={5} vehicleLoad={6}" -f $featureTriggers["supply-completion"], $featureTriggers["supply-interdiction"], $featureTriggers["team-funds"], $featureTriggers["town-capture"], $featureTriggers["client-wave"], $featureTriggers["client-heavy-wave"], $featureTriggers["vehicle-load"])
	Write-Host ("queue: enqueue={0} step={1} proof={2} end={3} notTriggered={4} hcReady={5} hcTimeout={6} cleanupLoop={7}" -f $featureTriggers["queue-enqueue"], $featureTriggers["queue-step"], $featureTriggers["queue-proof"], $featureTriggers["queue-end"], $featureTriggers["queue-not-triggered"], $featureTriggers["hc-ready"], $featureTriggers["hc-wait-timeout"], $featureTriggers["cleanup-loop"])
	Write-Host ("audits: ai={0} aiDelegation={1} aiDeep={2} playerUX={3} factory={4} serviceSupply={5} wddmArtillery={6} ui={7} gpsUI={8} dialogAutoProbe={9} bughunt={10} randomBughunt={11} perfBurst={12}" -f $featureTriggers["ai-audit"], $featureTriggers["ai-delegation-audit"], $featureTriggers["ai-deep-sample"], $featureTriggers["player-experience-audit"], $featureTriggers["factory-audit"], $featureTriggers["service-supply-audit"], $featureTriggers["wddm-artillery-audit"], $featureTriggers["ui-audit"], $featureTriggers["gps-ui-audit"], $featureTriggers["dialog-auto-probe"], $featureTriggers["bughunt-audit"], $featureTriggers["random-bughunt-audit"], $featureTriggers["perf-burst"])
	Write-Host ("errors: real={0} missionIssue={1} knownNoise={2}" -f $unexpected.Count, $missionIssues.Count, $knownNoise.Count)
	if ($missionIssues.Count -gt 0) { Write-Host ("missionIssue: {0}" -f (($missionIssues | Select-Object -Last 1) -replace "\s+", " ")) }
	if ($unexpected.Count -gt 0) { Write-Host ("realIssue: {0}" -f (($unexpected | Select-Object -Last 1) -replace "\s+", " ")) }
	exit 0
}

Write-Host "WASP PR8 stress RPT analysis"
Write-Host "RPT: $RptPath"
Write-Host "Stress lines: $($stressLines.Count)"
Write-Host "Perf samples: $($fpsValues.Count)  FPS min/avg/max: $fpsMin / $fpsAvg / $fpsMax"
Write-Host "AI behavior samples: $($aiBehavior.samples)  maxTrackedGroups=$($aiBehavior.maxTrackedGroups) maxTrackedUnits=$($aiBehavior.maxTrackedUnits) maxAliveTracked=$($aiBehavior.maxAliveTracked) maxFarStopped=$($aiBehavior.maxFarStopped)"
Write-Host "AI behavior detail: maxEmptyGroups=$($aiBehavior.maxEmptyGroups) maxNoWaypoint=$($aiBehavior.maxNoWaypoint) maxUnderStrengthGroups=$($aiBehavior.maxUnderStrengthGroups) maxLeaderFarStopped=$($aiBehavior.maxLeaderFarStopped) maxStopped=$($aiBehavior.maxStopped) maxReady=$($aiBehavior.maxReady) maxNoDestination=$($aiBehavior.maxNoDestination)"
Write-Host ""
foreach ($key in $coverage.Keys) {
	$status = if ($coverage[$key] -gt 0) { "OK" } else { "MISSING" }
	Write-Host ("{0,-20} {1,7} {2}" -f $key, $coverage[$key], $status)
}

Write-Host ""
Write-Host "AI/pathing symptom counts:"
foreach ($key in $aiSymptoms.Keys) {
	Write-Host ("{0,-24} {1,7}" -f $key, $aiSymptoms[$key])
}

Write-Host ""
Write-Host "Feature trigger counts:"
foreach ($key in $featureTriggers.Keys) {
	Write-Host ("{0,-24} {1,7}" -f $key, $featureTriggers[$key])
}

$townCapLeakLines = @($stressLines | Where-Object { $_ -like "*TOWN_CAP_LEAK*" })
$maxTownTeamsAlive = 0
foreach ($line in $townCapLeakLines) {
	$val = Get-LineMetric $line "townTeamsAlive"
	if ($null -ne $val -and $val -gt $maxTownTeamsAlive) { $maxTownTeamsAlive = $val }
}
Write-Host ""
Write-Host ("Town cap regression: remanOk={0} remanFail={1} maxTownTeamsAlive={2}" -f $featureTriggers["town-reman-ok"], $featureTriggers["town-reman-fail"], $maxTownTeamsAlive)

if ($missionIssues.Count -gt 0) {
	Write-Host ""
	Write-Host "Mission-side issues:" -ForegroundColor Yellow
	$missionIssues | Select-Object -First 40 | ForEach-Object { Write-Host $_ }
	if ($missionIssues.Count -gt 40) { Write-Host "... plus $($missionIssues.Count - 40) more line(s)." }
}

if ($unexpected.Count -gt 0) {
	Write-Host ""
	Write-Host "Unexpected RPT noise:" -ForegroundColor Yellow
	$unexpected | Select-Object -First 40 | ForEach-Object { Write-Host $_ }
	if ($unexpected.Count -gt 40) { Write-Host "... plus $($unexpected.Count - 40) more line(s)." }
}

$failed = ($stressLines.Count -eq 0) -or ($missing.Count -gt 0) -or ($fpsValues.Count -eq 0) -or ($unexpected.Count -gt 0) -or ($missionIssues.Count -gt 0)
if ($failed) {
	Write-Host ""
	Write-Host "FAIL: missing=$($missing -join ',') missionIssues=$($missionIssues.Count) unexpectedNoise=$($unexpected.Count)" -ForegroundColor Red
	exit 1
}

Write-Host ""
Write-Host "PASS: required WASP PR8 stress evidence found and RPT noise is clean." -ForegroundColor Green
