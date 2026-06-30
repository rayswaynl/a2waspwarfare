param(
	[string]$HostRpt = "$env:LOCALAPPDATA\ArmA 2 OA\ArmA2OA.RPT",
	[string]$HcRpt = "F:\SteamLibrary\steamapps\common\Arma 2 Operation Arrowhead\wasp_hc_profile\ArmA2OA.RPT",
	[int]$Tail = 600,
	[int]$IntervalSeconds = 30,
	[switch]$Once
)

$ErrorActionPreference = "Stop"

$knownNoisePath = Join-Path $PSScriptRoot "KnownNoise.txt"
$missionIssuePath = Join-Path $PSScriptRoot "MissionIssuePatterns.txt"

function Get-PatternList {
	param([string]$Path)
	if (!(Test-Path -LiteralPath $Path)) { return @() }
	return @(Get-Content -LiteralPath $Path | Where-Object { $_.Trim().Length -gt 0 -and -not $_.TrimStart().StartsWith("#") })
}

function Test-Pattern {
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

function Get-RptInfo {
	param([string]$Path)
	if (!(Test-Path -LiteralPath $Path)) {
		return [pscustomobject]@{ Path = $Path; Exists = $false; AgeSeconds = $null; Lines = @() }
	}
	$item = Get-Item -LiteralPath $Path
	$age = [math]::Round(((Get-Date) - $item.LastWriteTime).TotalSeconds)
	$lines = @(Get-Content -LiteralPath $Path -Tail $Tail -ErrorAction SilentlyContinue)
	return [pscustomobject]@{ Path = $Path; Exists = $true; AgeSeconds = $age; Lines = $lines }
}

function Get-ArmaProcessState {
	$processes = @(Get-CimInstance Win32_Process | Where-Object { $_.Name -match '(?i)^arma2oa' })
	$gameProcesses = @($processes | Where-Object { $_.Name -match '(?i)^arma2oa\.exe$' })
	$hostProc = @($gameProcesses | Where-Object { $_.CommandLine -notmatch '(?i)wasp_hc_profile|-client|headless' } | Select-Object -First 1)
	$hcProc = @($gameProcesses | Where-Object { $_.CommandLine -match '(?i)wasp_hc_profile|-client|headless' } | Select-Object -First 1)
	$beProc = @($processes | Where-Object { $_.Name -match '(?i)^arma2oa_be\.exe$' } | Select-Object -First 1)
	return [pscustomobject]@{
		Host = if ($hostProc.Count) { "RUN pid=$($hostProc[0].ProcessId)" } else { "STOP" }
		HC = if ($hcProc.Count) { "RUN pid=$($hcProc[0].ProcessId)" } else { "STOP" }
		BE = if ($beProc.Count) { "RUN pid=$($beProc[0].ProcessId)" } else { "STOP" }
	}
}

function Get-LatestLine {
	param([string[]]$Lines, [string]$Pattern)
	$hit = @($Lines | Where-Object { $_ -match $Pattern } | Select-Object -Last 1)
	if ($hit.Count) { return ($hit[0] -replace "\s+", " ") }
	return ""
}

function Get-LineMetric {
	param([string]$Line, [string]$Name)
	if ($Line -match "\b$([regex]::Escape($Name))=(?<value>-?\d+)") { return [int]$matches["value"] }
	return 0
}

function Get-TriggerCounts {
	param([string[]]$Lines)
	$patterns = [ordered]@{
		"supplyStart" = "SupplyMissionStart\.sqf: Player .* loaded"
		"supplyUnloadStart" = "SupplyMissionUnload\.sqf: Player .* started helicopter unload timer"
		"supplyComplete" = "SupplyMissionCompleted\.sqf: Completion accepted|TRIGGER supplyCompletion"
		"supplyInterdict" = "TRIGGER supplyInterdiction|Logistics interdiction"
		"wddm" = "PROBE wddm|HandleDefense|skipped duplicate"
		"commanderArtillery" = "commanderArtillery=|GetTeamArtillery|HQ-radius"
		"easa" = "EASA|Loadout"
		"vehicleReward" = "AwardBounty|delayedKill|Delayed attribution"
		"aiAudit" = "CLIENT_COMMAND_DONE ai-audit"
		"aiDeep" = "CLIENT_COMMAND_DONE ai-deep-sample"
		"playerExperience" = "PLAYER_EXPERIENCE_AUDIT"
		"perfBurst" = "PERF_BURST"
		"vehicleLoad" = "SPAWN vehicleLoad"
		"factoryAudit" = "FACTORY_AUDIT"
		"serviceSupplyAudit" = "SERVICE_SUPPLY_AUDIT"
		"wddmArtilleryAudit" = "WDDM_ARTILLERY_AUDIT"
		"uiAudit" = "UI_AUDIT"
		"gpsUiAudit" = "GPS_UI_AUDIT"
		"clientGpsState" = "CLIENT_GPS_STATE"
		"clientUiTextState" = "CLIENT_UI_TEXT_STATE"
		"clientServiceClipAudit" = "CLIENT_SERVICE_CLIP_AUDIT"
		"aiDelegationAudit" = "AI_DELEGATION_AUDIT"
		"bughuntAudit" = "BUGHUNT_AUDIT"
		"randomBughuntAudit" = "RANDOM_BUGHUNT_AUDIT"
		"heavyWave" = "SPAWN clientHeavyWave"
		"queueEnqueue" = "QUEUE_ENQUEUE"
		"queueStep" = "QUEUE_STEP"
		"queueEnd" = "QUEUE_END"
		"queueProof" = "QUEUE_PROOF"
		"queueNotTriggered" = "QUEUE_NOT_TRIGGERED"
		"hcReady" = "HC_READY"
		"hcWaitTimeout" = "HC_WAIT_TIMEOUT"
		# Experital-branch positive-activity triggers (2026-06-10): silent failure in these
		# subsystems shows as a zero count during a live watch, not just absence of errors.
		"counterBattery" = "Server_CounterBattery\.sqf:|CB CONTACT"
		"bankIncome" = "Server_BankIncome\.sqf: .*Dividend"
		"bankDestroyed" = "Bank destroyed by"
		"siteClearance" = "Server_SiteClearance\.sqf:"
		"waspstatKill" = "WASPSTAT.*KILL"
		"waspstatCapture" = "WASPSTAT.*CAPTURE"
		"waspstatRoundEnd" = "WASPSTAT.*ROUNDEND"
		"cleanupLoop" = "CLEANUP_LOOP"
		"townCapRegression" = "TOWN_CAP_REGRESSION"
		"townRemanOk" = "TOWN_REMAN_OK"
		"townRemanFail" = "TOWN_REMAN_FAIL"
		"townCapLeak" = "TOWN_CAP_LEAK"
		"townRapidRecapOk" = "TOWN_RAPID_RECAP_OK"
		"townRapidRecapFail" = "TOWN_RAPID_RECAP_FAIL"
	}
	$result = [ordered]@{}
	foreach ($key in $patterns.Keys) {
		$result[$key] = @($Lines | Where-Object { $_ -match $patterns[$key] }).Count
	}
	return $result
}

function Get-NoiseSummary {
	param([string[]]$Lines, [string[]]$KnownNoise, [string[]]$MissionIssues)
	$noisePattern = "(?i)(error in expression|error position|error undefined variable|undefined variable in expression|missing ;|generic error|script .* not found|cannot load|cannot open object|no entry|zero divisor|division by zero|warning message:)"
	$known = @()
	$mission = @()
	$real = @()
	for ($i = 0; $i -lt $Lines.Count; $i++) {
		$line = $Lines[$i]
		if ($line -notmatch $noisePattern) { continue }
		$start = [math]::Max(0, $i - 8)
		$end = [math]::Min($Lines.Count - 1, $i + 8)
		$context = ($Lines[$start..$end] -join "`n")
		if ((Test-Pattern $line $KnownNoise) -or (Test-Pattern $context $KnownNoise)) {
			$known += $line
		} elseif ((Test-Pattern $line $MissionIssues) -or (Test-Pattern $context $MissionIssues)) {
			$mission += $line
		} else {
			$real += $line
		}
	}
	return [pscustomobject]@{
		KnownNoise = $known
		MissionIssue = $mission
		RealIssue = $real
	}
}

$knownNoise = Get-PatternList $knownNoisePath
$missionIssues = Get-PatternList $missionIssuePath

do {
	$proc = Get-ArmaProcessState
	$hostInfo = Get-RptInfo $HostRpt
	$hcInfo = Get-RptInfo $HcRpt
	$allLines = @($hostInfo.Lines + $hcInfo.Lines)

	$selfTest = Get-LatestLine $allLines "WASP-SELFTEST|WASP-PR8-BUILD"
	$perf = Get-LatestLine $allLines "\[WASP-PR8-STRESS\].*PERF #"
	$ai = Get-LatestLine $allLines "\[WASP-PR8-STRESS\].*AI_BEHAVIOR"
	$gps = Get-LatestLine $allLines "\[WASP-PR8-STRESS\].*(GPS_UI_AUDIT|CLIENT_GPS_STATE|CLIENT_UI_TEXT_STATE|CLIENT_SERVICE_CLIP_AUDIT)"
	$bughunt = Get-LatestLine $allLines "\[WASP-PR8-STRESS\].*(BUGHUNT_AUDIT|RANDOM_BUGHUNT_AUDIT|AI_DELEGATION_AUDIT)"
	$queue = Get-LatestLine $allLines "\[WASP-PR8-STRESS\].*(QUEUE_ENQUEUE|QUEUE_BEGIN|QUEUE_STEP|QUEUE_END|QUEUE_STATUS|QUEUE_STOP|QUEUE_PROOF|QUEUE_NOT_TRIGGERED|HC_WAIT_BEGIN|HC_READY|HC_WAIT_TIMEOUT|CLEANUP_LOOP)"
	$triggers = Get-TriggerCounts $allLines
	$noise = Get-NoiseSummary $allLines $knownNoise $missionIssues

	$aiSummary = if ($ai -ne "") {
		"ai samples seen | farStopped=$(Get-LineMetric $ai 'farStopped') leaderFarStopped=$(Get-LineMetric $ai 'leaderFarStopped') noDestination=$(Get-LineMetric $ai 'noDestination') noWaypoint=$(Get-LineMetric $ai 'noWaypoint') emptyGroups=$(Get-LineMetric $ai 'emptyGroups') underStrength=$(Get-LineMetric $ai 'underStrengthGroups')"
	} else {
		"ai quiet"
	}

	$hostRptState = if ($hostInfo.Exists) { "rptAge=$($hostInfo.AgeSeconds)s" } else { "rpt=missing" }
	$hcRptState = if ($hcInfo.Exists) { "rptAge=$($hcInfo.AgeSeconds)s" } else { "rpt=missing" }

	Write-Host ("[PR8 LIVE] host={0} be={1} {2} | hc={3} {4}" -f $proc.Host, $proc.BE, $hostRptState, $proc.HC, $hcRptState)
	if ($selfTest -ne "") { Write-Host ("selftest: {0}" -f $selfTest) }
	if ($perf -ne "") { Write-Host ("stress: {0}" -f $perf) } else { Write-Host "stress: quiet" }
	if ($queue -ne "") { Write-Host ("queue: {0}" -f $queue) } else { Write-Host "queue: quiet" }
	if ($gps -ne "") { Write-Host ("gps/ui: {0}" -f $gps) } else { Write-Host "gps/ui: quiet" }
	if ($bughunt -ne "") { Write-Host ("bughunt: {0}" -f $bughunt) } else { Write-Host "bughunt: quiet" }
	Write-Host $aiSummary
	Write-Host ("triggers: supplyStart={0} unloadStart={1} complete={2} interdict={3} wddm={4} commanderArtillery={5} easa={6} reward={7}" -f $triggers["supplyStart"], $triggers["supplyUnloadStart"], $triggers["supplyComplete"], $triggers["supplyInterdict"], $triggers["wddm"], $triggers["commanderArtillery"], $triggers["easa"], $triggers["vehicleReward"])
	Write-Host ("queueCounts: enqueue={0} step={1} proof={2} end={3} notTriggered={4} hcReady={5} hcTimeout={6} cleanupLoop={7}" -f $triggers["queueEnqueue"], $triggers["queueStep"], $triggers["queueProof"], $triggers["queueEnd"], $triggers["queueNotTriggered"], $triggers["hcReady"], $triggers["hcWaitTimeout"], $triggers["cleanupLoop"])
	Write-Host ("experital: cbr={0} bankIncome={1} bankKill={2} siteClear={3} | waspstat kill={4} cap={5} end={6}" -f $triggers["counterBattery"], $triggers["bankIncome"], $triggers["bankDestroyed"], $triggers["siteClearance"], $triggers["waspstatKill"], $triggers["waspstatCapture"], $triggers["waspstatRoundEnd"])
	Write-Host ("audits: ai={0} aiDelegation={1} aiDeep={2} playerUX={3} factory={4} serviceSupply={5} wddmArtillery={6} ui={7} gpsUI={8} clientGps={9} clip={10} bughunt={11} randomBughunt={12} perfBurst={13} vehicleLoad={14} heavyWave={15}" -f $triggers["aiAudit"], $triggers["aiDelegationAudit"], $triggers["aiDeep"], $triggers["playerExperience"], $triggers["factoryAudit"], $triggers["serviceSupplyAudit"], $triggers["wddmArtilleryAudit"], $triggers["uiAudit"], $triggers["gpsUiAudit"], $triggers["clientGpsState"], $triggers["clientServiceClipAudit"], $triggers["bughuntAudit"], $triggers["randomBughuntAudit"], $triggers["perfBurst"], $triggers["vehicleLoad"], $triggers["heavyWave"])
	Write-Host ("errors: real={0} missionIssue={1} knownNoise={2}" -f $noise.RealIssue.Count, $noise.MissionIssue.Count, $noise.KnownNoise.Count)
	if ($noise.RealIssue.Count -gt 0) { Write-Host ("realIssue: {0}" -f (($noise.RealIssue | Select-Object -Last 1) -replace "\s+", " ")) }
	if ($noise.MissionIssue.Count -gt 0) { Write-Host ("missionIssue: {0}" -f (($noise.MissionIssue | Select-Object -Last 1) -replace "\s+", " ")) }
	if (!$Once) { Start-Sleep -Seconds $IntervalSeconds }
} while (!$Once)
