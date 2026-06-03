param(
	[Parameter(Mandatory = $true)]
	[string[]]$RptPath,
	[string]$OutputPath = "",
	[switch]$RequireJip,
	[switch]$RequireHeadlessClient,
	[switch]$RequireEdgeGuardRemoval,
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
	[ordered]@{ Name = "Runtime base/fortification audit"; Pattern = 'Zargabad_RuntimeAudit\.sqf: bases WEST .* EAST .* distance \[[0-9]+\] westStatic \[4\] eastStatic \[4\] baseWalls \[13\] centralWallPieces \[60\]'; Required = $true },
	[ordered]@{ Name = "Runtime factory audit"; Pattern = 'Zargabad_RuntimeAudit\.sqf: factoryCounts WEST L/H/A/AP \[[0-9]+,3,7,2\] EAST L/H/A/AP \[[0-9]+,4,3,3\] forbiddenNormal \[\]'; Required = $true },
	[ordered]@{ Name = "Runtime price audit"; Pattern = 'Zargabad_RuntimeAudit\.sqf: priceMultipliers .*priceSamples'; Required = $true },
	[ordered]@{ Name = "Runtime economy audit"; Pattern = 'Zargabad_RuntimeAudit\.sqf: economy supplyCap .*teamSupplyCap \[30000\].*edgeGuard \[120,325,45\]'; Required = $true },
	[ordered]@{ Name = "JIP"; Pattern = 'Server_PlayerConnected\.sqf: Player \[[^\r\n]+\] \[[^\r\n]+\] has joined the game|JIP Information have been stored'; Required = [bool]$RequireJip },
	[ordered]@{ Name = "Headless client"; Pattern = 'Server_HandleSpecial\.sqf: Headless client is now connected'; Required = [bool]$RequireHeadlessClient },
	[ordered]@{ Name = "Edge guard removal"; Pattern = 'Zargabad_EdgeGuard\.sqf: \[[^\r\n]+\] removed from edge rim'; Required = [bool]$RequireEdgeGuardRemoval },
	[ordered]@{ Name = "Black-market cache"; Pattern = 'Zargabad_BlackMarket\.sqf: \[[^\r\n]+\] cache \[[^\r\n]+\] surfaced near'; Required = [bool]$RequireBlackMarket },
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
$report.Add("Use `PASS`, `FAIL`, or `UNCERTAIN`. Add coordinates, screenshot filenames, RPT line excerpts, or exact repro steps for every `FAIL` or `UNCERTAIN` row.")
$report.Add("")
$report.Add("| Runtime check | Verdict | Evidence / notes |")
$report.Add("| --- | --- | --- |")
$report.Add("| Hosted/dedicated context | UNCERTAIN |  |")
$report.Add("| Base safety and spawn sightlines | UNCERTAIN |  |")
$report.Add("| Central wall gaps and pathing | UNCERTAIN |  |")
$report.Add("| Side hills and rim behavior | UNCERTAIN |  |")
$report.Add("| Town defense facing and movement blocking | UNCERTAIN |  |")
$report.Add("| Economy and factory pricing feel | UNCERTAIN |  |")
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
