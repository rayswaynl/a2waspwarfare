[CmdletBinding()]
param(
	[string[]]$RptPath = @(),
	[string[]]$RptDirectory = @(),
	[string[]]$ExpectedMarker = @(),
	[string]$OutDirectory = "",
	[switch]$Recurse,
	[switch]$Force,
	[switch]$NoFail
)

$ErrorActionPreference = "Stop"

function ConvertTo-Array {
	param($Value)
	if ($null -eq $Value) { return @() }
	if ($Value -is [System.Array]) { return @($Value) }
	return @($Value)
}

function Join-Display {
	param($Value)
	$items = @(ConvertTo-Array $Value | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ })
	if ($items.Count -eq 0) { return "-" }
	return ($items -join ", ")
}

function Escape-MarkdownCell {
	param([string]$Text)
	if ($null -eq $Text -or $Text.Length -eq 0) { return "-" }
	return (($Text -replace "\|", "\|") -replace "`r?`n", " ")
}

function Get-CountValue {
	param($Counts, [string]$Name)
	if ($null -eq $Counts) { return 0 }
	$property = $Counts.PSObject.Properties[$Name]
	if ($null -eq $property) { return 0 }
	return [int]$property.Value
}

function Format-TimeValue {
	param($Value)
	if ($null -eq $Value) { return "-" }
	if ($Value -is [datetime]) { return $Value.ToString("yyyy-MM-ddTHH:mm:sszzz") }
	return [string]$Value
}

function Format-SessionSummary {
	param($Sessions)
	$parts = @()
	foreach ($session in (ConvertTo-Array $Sessions)) {
		if ($null -eq $session) { continue }
		$mission = [string]$session.missionName
		$world = [string]$session.worldName
		if ([string]::IsNullOrWhiteSpace($mission) -and [string]::IsNullOrWhiteSpace($world)) { continue }
		$parts += ("{0}/{1}" -f $mission, $world)
	}
	$unique = @($parts | Select-Object -Unique)
	if ($unique.Count -le 6) { return (Join-Display $unique) }
	return ("{0} (+{1} more)" -f (($unique | Select-Object -First 6) -join ", "), ($unique.Count - 6))
}

$scorerPath = Join-Path $PSScriptRoot "Test-WaspReleaseRptEvidence.ps1"
if (!(Test-Path -LiteralPath $scorerPath)) {
	throw "RPT evidence scorer not found: $scorerPath"
}

$scorerParams = @{
	RptPath = @($RptPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
	RptDirectory = @($RptDirectory | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
	ExpectedMarker = @($ExpectedMarker | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
	Json = $true
	NoFail = $true
}
if ($Recurse) { $scorerParams["Recurse"] = $true }

$rawJson = & $scorerPath @scorerParams
$jsonText = ($rawJson | Out-String).Trim()
if ([string]::IsNullOrWhiteSpace($jsonText)) {
	throw "RPT evidence scorer produced no JSON output."
}
$score = $jsonText | ConvertFrom-Json

if ([string]::IsNullOrWhiteSpace($OutDirectory)) {
	$OutDirectory = Join-Path (Get-Location).Path "wasp-release-rpt-summary"
}
$outPath = $OutDirectory
if (Test-Path -LiteralPath $outPath) {
	$outPath = (Resolve-Path -LiteralPath $outPath).Path
} else {
	$outPath = (New-Item -ItemType Directory -Path $outPath -Force).FullName
}

$jsonOut = Join-Path $outPath "release-rpt-summary.json"
$markdownOut = Join-Path $outPath "release-rpt-summary.md"
if (!$Force) {
	foreach ($candidate in @($jsonOut, $markdownOut)) {
		if (Test-Path -LiteralPath $candidate) {
			throw "Output already exists: $candidate. Pass -Force to overwrite."
		}
	}
}

$packet = [ordered]@{
	schema = "a2waspwarfare-release-rpt-summary-v1"
	generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
	scorerScript = "Tools/PrTestHarness/Rpt/Test-WaspReleaseRptEvidence.ps1"
	scorerSchema = $score.schema
	input = [ordered]@{
		rptPathCount = @($RptPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
		rptDirectoryCount = @($RptDirectory | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
		recurse = [bool]$Recurse
		expectedMarker = @($ExpectedMarker | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
	}
	result = $score
	requiredHumanObservations = @(
		"Client fade clears and late-JIP player can move/use HUD after loading.",
		"Human commander takeover pauses autonomous AICOM build/upgrade behavior and revert resumes it.",
		"Supply/cash-run workflow is playable end to end, including JIP cooldown expectations.",
		"Release package/deployment provenance is recorded separately from RPT token scoring."
	)
	privacy = "No raw RPT lines are emitted or copied; scorer paths are user-profile redacted."
}
$packet | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $jsonOut -Encoding UTF8

$lines = New-Object System.Collections.Generic.List[string]
[void]$lines.Add("# WASP Release RPT Summary")
[void]$lines.Add("")
[void]$lines.Add(("Generated: {0}" -f $packet.generatedAt))
[void]$lines.Add(("Overall: {0}" -f $score.overall))
[void]$lines.Add(("Worlds seen: {0}" -f (Join-Display $score.worldsSeen)))
[void]$lines.Add(("Files scored: {0}" -f @(ConvertTo-Array $score.files).Count))
[void]$lines.Add("")
[void]$lines.Add("Privacy: no raw RPT lines are emitted or copied. File paths come from the scorer's redacted path field.")
[void]$lines.Add("")
[void]$lines.Add("## Expected Markers")
[void]$lines.Add("")
$markerProperties = @()
if ($null -ne $score.expectedMarkerCounts) { $markerProperties = @($score.expectedMarkerCounts.PSObject.Properties) }
if ($markerProperties.Count -eq 0) {
	[void]$lines.Add("- None requested.")
} else {
	[void]$lines.Add("| Marker | Count |")
	[void]$lines.Add("| --- | ---: |")
	foreach ($property in $markerProperties) {
		[void]$lines.Add(("| {0} | {1} |" -f (Escape-MarkdownCell ([string]$property.Name)), [int]$property.Value))
	}
}
[void]$lines.Add("")
[void]$lines.Add("## Gate Results")
[void]$lines.Add("")
[void]$lines.Add("| Gate | Status | Missing | Fail Hits |")
[void]$lines.Add("| --- | --- | --- | --- |")
foreach ($gate in (ConvertTo-Array $score.gates)) {
	[void]$lines.Add(("| {0} | {1} | {2} | {3} |" -f `
		(Escape-MarkdownCell ([string]$gate.id)), `
		(Escape-MarkdownCell ([string]$gate.status)), `
		(Escape-MarkdownCell (Join-Display $gate.missing)), `
		(Escape-MarkdownCell (Join-Display $gate.failHits))))
}
[void]$lines.Add("")
[void]$lines.Add("## File Summaries")
[void]$lines.Add("")
[void]$lines.Add("| File | Last Write | Lines | Sessions |")
[void]$lines.Add("| --- | --- | ---: | --- |")
foreach ($file in (ConvertTo-Array $score.files)) {
	[void]$lines.Add(("| {0} | {1} | {2} | {3} |" -f `
		(Escape-MarkdownCell ([string]$file.path)), `
		(Escape-MarkdownCell (Format-TimeValue $file.lastWriteTime)), `
		[int]$file.lineCount, `
		(Escape-MarkdownCell (Format-SessionSummary $file.sessions))))
}
[void]$lines.Add("")
[void]$lines.Add("## Selected Token Counts")
[void]$lines.Add("")
[void]$lines.Add("| Token | Count |")
[void]$lines.Add("| --- | ---: |")
foreach ($key in @("aicomHbWest","aicomHbEast","aicomTickWest","aicomTickEast","aiCommanderActive","aiCommanderAssist","aicomOrder","hcSide","hcStat","hcDeleg","delegStat","teamFoundedViaHC","jipMark","clientRosterRecv","hqMark","townAiHcCleanup","wddmArtilleryAudit","supplyLoaded","supplyCompleted","clientLogicError")) {
	[void]$lines.Add(("| {0} | {1} |" -f $key, (Get-CountValue $score.tokenCounts $key)))
}
[void]$lines.Add("")
[void]$lines.Add("## Human Observations Still Required")
[void]$lines.Add("")
foreach ($observation in $packet.requiredHumanObservations) {
	[void]$lines.Add(("- {0}" -f $observation))
}
[void]$lines.Add("")
if ([string]$score.overall -eq "pass") {
	[void]$lines.Add("Result: scorer gates pass. Pair this with human notes for client playability, commander handoff observations, and package/deployment provenance before calling the release complete.")
} else {
	[void]$lines.Add("Result: scorer gates are still missing or failed. Keep this packet as diagnostic evidence only; collect fresh Chernarus and Takistan RPTs until all gates pass.")
}
$lines | Set-Content -LiteralPath $markdownOut -Encoding UTF8

Write-Host "Wrote release RPT summary:"
Write-Host $jsonOut
Write-Host $markdownOut

if ([string]$score.overall -ne "pass" -and !$NoFail) { exit 1 }
