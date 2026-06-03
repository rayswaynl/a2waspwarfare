param(
	[Parameter(Mandatory = $true)]
	[string[]]$RptPath,
	[string]$OutputPath = "",
	[switch]$RequireJip,
	[switch]$RequireHeadlessClient,
	[switch]$RequireEdgeGuardRemoval,
	[switch]$RequireEdgeGuardSafeAllow,
	[switch]$RequireNamedRimPoints,
	[switch]$RequireBlackMarket,
	[switch]$AllowKnownDisconnectScoreErrors
)

$ErrorActionPreference = "Stop"

function Get-RptFiles {
	param([string[]]$Paths)
	$files = @()
	foreach ($path in $Paths) {
		if (Test-Path -LiteralPath $path -PathType Container) {
			$files += Get-ChildItem -LiteralPath $path -Recurse -File -Filter "*.rpt"
			continue
		}
		if (Test-Path -LiteralPath $path -PathType Leaf) {
			$files += Get-Item -LiteralPath $path
			continue
		}
		throw "RPT path not found: $path"
	}
	return @($files | Sort-Object FullName -Unique)
}

function Get-EvidenceLines {
	param([string[]]$Lines, [string]$Pattern, [int]$Max = 5)
	$matches = @($Lines | Where-Object { $_ -match $Pattern } | Select-Object -First $Max)
	if ($matches.Count -eq 0) { return @("_missing_") }
	return $matches
}

function Get-GateState {
	param([string[]]$Lines, [string]$Pattern, [bool]$Required)
	$hasEvidence = @($Lines | Where-Object { $_ -match $Pattern } | Select-Object -First 1).Count -gt 0
	if ($hasEvidence) { return "PASS" }
	if ($Required) { return "MISSING" }
	return "OPTIONAL"
}

$files = Get-RptFiles $RptPath
if ($files.Count -eq 0) { throw "No RPT files found" }

$content = ($files | ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName }) -join "`n"
if ($AllowKnownDisconnectScoreErrors) {
	$content = [regex]::Replace($content, 'Server_PlayerDisconnected\.sqf: Player \[[^\r\n]+has no score to be saved upon disconnection[^\r\n]*', '')
	$content = [regex]::Replace($content, 'Server_PlayerDisconnected\.sqf: Player \[[^\r\n]+has disconnected[^\r\n]*', '')
}
$lines = @($content -split "`r?`n")

$validator = Join-Path $PSScriptRoot "Validate-ZargabadRuntimeEvidence.ps1"
$validatorParams = @{
	RptPath = $RptPath
}
if ($RequireJip) { $validatorParams.RequireJip = $true }
if ($RequireHeadlessClient) { $validatorParams.RequireHeadlessClient = $true }
if ($RequireEdgeGuardRemoval) { $validatorParams.RequireEdgeGuardRemoval = $true }
if ($RequireEdgeGuardSafeAllow) { $validatorParams.RequireEdgeGuardSafeAllow = $true }
if ($RequireNamedRimPoints) { $validatorParams.RequireNamedRimPoints = $true }
if ($RequireBlackMarket) { $validatorParams.RequireBlackMarket = $true }
if ($AllowKnownDisconnectScoreErrors) { $validatorParams.AllowKnownDisconnectScoreErrors = $true }

$validatorPassed = $true
$validatorOutput = @()
try {
	$validatorOutput = @(& $validator @validatorParams *>&1 | ForEach-Object { $_.ToString() })
} catch {
	$validatorPassed = $false
	$validatorOutput += $_.Exception.Message
}

$gates = @(
	[ordered]@{ Name = "Zargabad world"; Pattern = '(?i)zargabad'; Required = $true },
	[ordered]@{ Name = "Server init begins"; Pattern = 'Init_Server\.sqf: Server initialization begins'; Required = $true },
	[ordered]@{ Name = "Town init done"; Pattern = 'Init_Server\.sqf: Town starting mode is done'; Required = $true },
	[ordered]@{ Name = "Zargabad init done"; Pattern = 'Init_Zargabad\.sqf: Spawn fortifications, central wall gaps, and side defenses are placed'; Required = $true },
	[ordered]@{ Name = "Town defense orientation"; Pattern = 'Init_Zargabad\.sqf: Oriented \[33\] town defense logics toward linked town centers'; Required = $true },
	[ordered]@{ Name = "Edge guard init"; Pattern = 'Zargabad_EdgeGuard\.sqf: outer \[[0-9]+\]m rim timeout \[[0-9]+\]s safe range \[[0-9]+\]m'; Required = $true },
	[ordered]@{ Name = "Runtime count/SV audit"; Pattern = 'Zargabad_RuntimeAudit\.sqf: towns \[13\] camps \[19\] airports \[1\] defenses \[33\] startSV \[185\] maxSV \[648\]'; Required = $true },
	[ordered]@{ Name = "Runtime base/fortification audit"; Pattern = 'Zargabad_RuntimeAudit\.sqf: bases WEST .* EAST .* distance \[[0-9]+\] westStatic \[4\] eastStatic \[4\] baseWalls \[13\] baseFootprint \[35,45,74,78\] centralWallPieces \[60\] centralWallCrewed \[0\].*centralWallGaps .*4053.*2725.*3789.*2998.*3504.*3293.*3195.*3613.*2903.*3915'; Required = $true },
	[ordered]@{ Name = "Runtime base static template audit"; Pattern = 'Zargabad_RuntimeAudit\.sqf: baseStaticTemplates WEST .*M2StaticMG_US_EP1.*TOW_TriPod_US_EP1.*Stinger_Pod_US_EP1.* EAST .*KORD_high_TK_EP1.*Metis_TK_EP1.*Igla_AA_pod_TK_EP1'; Required = $true },
	[ordered]@{ Name = "Base static runtime positions"; Pattern = 'Init_Zargabad\.sqf: Base static runtime positions WEST .*M2StaticMG_US_EP1.*TOW_TriPod_US_EP1.*Stinger_Pod_US_EP1.* EAST .*KORD_high_TK_EP1.*Metis_TK_EP1.*Igla_AA_pod_TK_EP1'; Required = $true },
	[ordered]@{ Name = "Runtime factory audit"; Pattern = 'Zargabad_RuntimeAudit\.sqf: factoryCounts WEST L/H/A/AP \[[0-9]+,3,7,2\] EAST L/H/A/AP \[[0-9]+,4,3,3\] forbiddenNormal \[\]'; Required = $true },
	[ordered]@{ Name = "Runtime compact factory lists"; Pattern = 'Zargabad_RuntimeAudit\.sqf: factoryLists WEST H .*M2A2_EP1.*M2A3_EP1.*BAF_FV510_D.* A .*MH6J_EP1.*UH60M_EP1.*UH60M_MEV_EP1.*CH_47F_EP1.*CH_47F_BAF.*BAF_Merlin_HC3_D.*AH6J_EP1.* EAST H .*M113_TK_EP1.*BMP2_TK_EP1.*T34_TK_EP1.*BMP3.* A .*UH1H_TK_EP1.*Mi17_TK_EP1.*Mi17_medevac_RU.*An2_TK_EP1'; Required = $true },
	[ordered]@{ Name = "Runtime price audit"; Pattern = 'Zargabad_RuntimeAudit\.sqf: priceMultipliers .*priceSamples'; Required = $true },
	[ordered]@{ Name = "Runtime economy/range/weapons audit"; Pattern = 'Zargabad_RuntimeAudit\.sqf: economy supplyCap .*teamSupplyCap \[30000\].*edgeGuard \[120,325,45\] weapons missileRange \[2000\] uavRange \[800\] townRanges \[45,500,350\] purchaseHangar \[35\] countermeasures \[16,24\]'; Required = $true },
	[ordered]@{ Name = "Black-market armed"; Pattern = 'Zargabad_BlackMarket\.sqf: armed near Zargabad Airfield positions .* delay \[600,960\] hold \[300\]'; Required = $true },
	[ordered]@{ Name = "JIP"; Pattern = 'Server_PlayerConnected\.sqf: Player \[[^\r\n]+\] \[[^\r\n]+\] has joined the game|JIP Information have been stored'; Required = [bool]$RequireJip },
	[ordered]@{ Name = "Headless client"; Pattern = 'Server_HandleSpecial\.sqf: Headless client is now connected'; Required = [bool]$RequireHeadlessClient },
	[ordered]@{ Name = "Edge guard removal"; Pattern = 'Zargabad_EdgeGuard\.sqf: \[[^\r\n]+\] removed from edge rim'; Required = [bool]$RequireEdgeGuardRemoval },
	[ordered]@{ Name = "Edge guard safe allow"; Pattern = 'Zargabad_EdgeGuard\.sqf: \[[^\r\n]+\] allowed at safe edge rim'; Required = [bool]$RequireEdgeGuardSafeAllow },
	[ordered]@{ Name = "Named rim points"; Pattern = 'Zargabad_EdgeGuard\.sqf: \[[^\r\n]+\] (removed from edge rim|allowed at safe edge rim)'; Required = [bool]$RequireNamedRimPoints },
	[ordered]@{ Name = "Black-market cache"; Pattern = 'Zargabad_BlackMarket\.sqf: \[[^\r\n]+\] cache \[[^\r\n]+\] surfaced near'; Required = [bool]$RequireBlackMarket },
	[ordered]@{ Name = "Black-market cleanup"; Pattern = 'Zargabad_BlackMarket\.sqf: cache \[[^\r\n]+\] cleanup released near'; Required = [bool]$RequireBlackMarket },
	[ordered]@{ Name = "Server init ends"; Pattern = 'Init_Server\.sqf: Server initialization ended'; Required = $true }
)

$failurePatterns = @(
	[ordered]@{ Name = "Missing script/include"; Pattern = 'Script [^\r\n]+ not found|Include file [^\r\n]+ not found' },
	[ordered]@{ Name = "Expression errors"; Pattern = 'Error in expression|Error position:|Undefined variable in expression' },
	[ordered]@{ Name = "Missing dependency"; Pattern = 'You cannot play/edit this mission|Cannot load mission|No entry [^\r\n]+zargabad|No entry [^\r\n]+WFBE_[^\r\n]+ZARGABAD' },
	[ordered]@{ Name = "Zargabad file load failures"; Pattern = 'Cannot open [^\r\n]+Zargabad|Cannot open [^\r\n]+zargabad' }
)

$report = New-Object System.Collections.Generic.List[string]
$report.Add("# Zargabad Runtime Report")
$report.Add("")
$report.Add("- Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')")
$report.Add("- Validator: $(if ($validatorPassed) { 'PASS' } else { 'FAIL' })")
$report.Add("- RPT files:")
foreach ($file in $files) { $report.Add(('  - `{0}`' -f $file.FullName)) }
$report.Add("")
$report.Add("## Gate Snapshot")
$report.Add("")
$report.Add("| Gate | State |")
$report.Add("| --- | --- |")
foreach ($gate in $gates) {
	$report.Add("| $($gate.Name) | $(Get-GateState -Lines $lines -Pattern $gate.Pattern -Required $gate.Required) |")
}
$report.Add("")
$report.Add("## Failure Scan")
$report.Add("")
$report.Add("| Pattern | State |")
$report.Add("| --- | --- |")
foreach ($failure in $failurePatterns) {
	$state = if (@($lines | Where-Object { $_ -match $failure.Pattern } | Select-Object -First 1).Count -gt 0) { "FOUND" } else { "clear" }
	$report.Add("| $($failure.Name) | $state |")
}
$report.Add("")
$report.Add("## Key Evidence")
foreach ($item in @(
	[ordered]@{ Name = "Init"; Pattern = 'Init_Server\.sqf: Server initialization|Init_Server\.sqf: Town starting mode|Init_Zargabad\.sqf' },
	[ordered]@{ Name = "Edge guard"; Pattern = 'Zargabad_EdgeGuard\.sqf' },
	[ordered]@{ Name = "Runtime audit"; Pattern = 'Zargabad_RuntimeAudit\.sqf' },
	[ordered]@{ Name = "JIP/HC"; Pattern = 'Server_PlayerConnected\.sqf|JIP Information|Server_HandleSpecial\.sqf' },
	[ordered]@{ Name = "Mystery feature"; Pattern = 'Zargabad_BlackMarket\.sqf' }
)) {
	$report.Add("")
	$report.Add("### $($item.Name)")
	foreach ($line in Get-EvidenceLines -Lines $lines -Pattern $item.Pattern) {
		$report.Add("- $line")
	}
}
$report.Add("")
$report.Add("## Claude Notes")
$report.Add("")
$report.Add("Use `PASS`, `FAIL`, or `UNCERTAIN`. Every `PASS` row must include concrete evidence; every `FAIL` or `UNCERTAIN` row must include coordinates, screenshot filenames, RPT line excerpts, or exact repro steps.")
$report.Add("")
$report.Add("| Runtime check | Verdict | Evidence / notes |")
$report.Add("| --- | --- | --- |")
$report.Add("| Hosted/dedicated context | UNCERTAIN |  |")
$report.Add("| Map audit packet attached | UNCERTAIN | Include `zargabad-map-audit.md` when reporting coordinates, screenshots, pathing, or sightline findings. |")
$report.Add("| Base safety and spawn sightlines | UNCERTAIN |  |")
$report.Add("| Base static runtime positions and arcs | UNCERTAIN | Compare the Init_Zargabad base static runtime positions line plus runtime baseFootprint [35,45,74,78] against screenshots/coordinates, manning, usable arcs, and commander construction space. |")
$report.Add("| Base-axis midpoint and wall origin | UNCERTAIN | Check `3425,3375` from both default starts and back toward both starts. |")
$report.Add("| Central wall gaps and pathing | UNCERTAIN | Test `4053,2725`, `3789,2998`, `3504,3293`, `3195,3613`, and `2903,3915`. |")
$report.Add("| Side hills and rim behavior | UNCERTAIN | Use `-RequireNamedRimPoints`: removal near 80,3000; 3000,80; 5900,3000; 3000,5900, and `allowed at safe edge rim` near 3600,5900; 4330,5900; 5900,4340. |")
$report.Add("| Town defense facing and movement blocking | UNCERTAIN |  |")
$report.Add("| Priority defense mix arcs | UNCERTAIN | Use map audit Town Defenses rows: city MG/nest+GL+AT; airfield MG/nest+AT+2xAA; North/South District, Northwest Base and Rahim Villa MG-or-nest+AT; Northwest Base AA. Flag bad arcs, blocked routes or unusable terrain. |")
$report.Add("| Economy and factory pricing feel | UNCERTAIN |  |")
$report.Add("| Weapon/range pressure | UNCERTAIN | Confirm missile range 2000, UAV 800, town defense/mortar/patrol ranges 45/500/350, hangar 35, countermeasures 16/24 feel right on Zargabad. |")
$report.Add("| Mystery feature behavior | UNCERTAIN |  |")
$report.Add("| Recommended Codex action | UNCERTAIN | Keep / tune / revert / investigate:  |")
$report.Add("")
$report.Add("Codex should accept Claude's finding when this report includes concrete RPT evidence, coordinates, screenshots, or repeatable repro steps. If the report proves a mission issue, update mission code or validators before asking Claude to repeat the same pass.")
$report.Add("")
$report.Add("## Validator Output")
$report.Add("")
$report.Add('```text')
foreach ($line in $validatorOutput) { $report.Add($line) }
$report.Add('```')

$reportText = $report -join "`r`n"
if ($OutputPath.Trim().Length -gt 0) {
	$parent = Split-Path -Parent $OutputPath
	if ($parent -and -not (Test-Path -LiteralPath $parent)) {
		New-Item -ItemType Directory -Path $parent | Out-Null
	}
	Set-Content -LiteralPath $OutputPath -Value $reportText -Encoding UTF8
	Write-Host "Wrote Zargabad runtime report: $OutputPath"
} else {
	$reportText
}

if (-not $validatorPassed) { exit 1 }
