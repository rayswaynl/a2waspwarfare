[CmdletBinding()]
param(
	[string[]]$RptPath = @(),
	[string[]]$RptDirectory = @(),
	[string[]]$ExpectedMarker = @(),
	[string]$OutDirectory = "",
	[string]$RuntimePacketManifestPath = "",
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

function Get-SafeTextHash {
	param([string]$Text)
	if ([string]::IsNullOrEmpty($Text)) { return "" }
	$sha = [System.Security.Cryptography.SHA256]::Create()
	try {
		$bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
		$hash = $sha.ComputeHash($bytes)
		return (($hash | ForEach-Object { $_.ToString("x2") }) -join "").Substring(0, 12)
	} finally {
		$sha.Dispose()
	}
}

function Get-JsonValue {
	param($Object, [string]$Name)
	if ($null -eq $Object) { return $null }
	$property = $Object.PSObject.Properties[$Name]
	if ($null -eq $property) { return $null }
	return $property.Value
}

function ConvertTo-BoolFlag {
	param($Value)
	if ($null -eq $Value) { return $false }
	if ($Value -is [bool]) { return [bool]$Value }
	$text = ([string]$Value).Trim().ToLowerInvariant()
	return ($text -eq "true")
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

function Test-RuntimePacketManifestProof {
	param([string]$Path)
	$missing = New-Object System.Collections.Generic.List[string]
	$failHits = New-Object System.Collections.Generic.List[string]
	$result = [ordered]@{
		status = "not_requested"
		requested = $false
		manifestPath = ""
		manifestPathHash = ""
		schema = ""
		validationRequested = $false
		validationOverall = ""
		fileCount = 0
		missing = @()
		failHits = @()
		note = "Pass -RuntimePacketManifestPath to bind this summary to the ten-file packet validator proof."
	}
	if ([string]::IsNullOrWhiteSpace($Path)) {
		return $result
	}
	$result.requested = $true
	$result.manifestPath = "<runtime-rpt-packet-manifest>"
	$result.manifestPathHash = Get-SafeTextHash $Path
	if (!(Test-Path -LiteralPath $Path -PathType Leaf)) {
		[void]$missing.Add("runtime-rpt-packet-manifest.json")
		$result.status = "missing"
		$result.missing = $missing.ToArray()
		return $result
	}
	try {
		$manifest = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
	} catch {
		[void]$failHits.Add("runtime packet manifest JSON parse failed")
		$result.status = "fail"
		$result.failHits = $failHits.ToArray()
		return $result
	}
	$schema = [string](Get-JsonValue $manifest "schema")
	$result.schema = $schema
	if ($schema -ne "a2waspwarfare-runtime-rpt-packet-builder-v1") {
		[void]$failHits.Add("schema must be a2waspwarfare-runtime-rpt-packet-builder-v1")
	}
	$validation = Get-JsonValue $manifest "validation"
	$validationRequested = ConvertTo-BoolFlag (Get-JsonValue $validation "requested")
	$validationOverall = [string](Get-JsonValue $validation "overall")
	$result.validationRequested = $validationRequested
	$result.validationOverall = $validationOverall
	$result.fileCount = @(ConvertTo-Array (Get-JsonValue $manifest "files")).Count
	if (!$validationRequested) {
		[void]$failHits.Add("runtime packet manifest validation.requested must be true")
	}
	if ($validationOverall -ne "pass") {
		[void]$failHits.Add("runtime packet manifest validation.overall must be pass")
	}
	if ([int]$result.fileCount -ne 10) {
		[void]$failHits.Add("runtime packet manifest must list the exact ten copied RPT files")
	}
	$result.status = if ($missing.Count -gt 0) { "missing" } elseif ($failHits.Count -gt 0) { "fail" } else { "pass" }
	$result.missing = $missing.ToArray()
	$result.failHits = $failHits.ToArray()
	$result.note = "Summary is bound to the packet builder/checker manifest, including ten-file matrix, run-ledger, archive SHA, source/copy hash, freshness and role-proof validation."
	return $result
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
$runtimePacketProof = Test-RuntimePacketManifestProof -Path $RuntimePacketManifestPath
$summaryOverall = if ([string]$score.overall -eq "pass" -and ([string]$runtimePacketProof.status -eq "not_requested" -or [string]$runtimePacketProof.status -eq "pass")) { "pass" } else { "missing_or_failed" }

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
	overall = $summaryOverall
	scorerScript = "Tools/PrTestHarness/Rpt/Test-WaspReleaseRptEvidence.ps1"
	scorerSchema = $score.schema
	input = [ordered]@{
		rptPathCount = @($RptPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
		rptDirectoryCount = @($RptDirectory | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
		recurse = [bool]$Recurse
		expectedMarker = @($ExpectedMarker | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
		runtimePacketManifestProvided = ![string]::IsNullOrWhiteSpace($RuntimePacketManifestPath)
	}
	result = $score
	runtimePacketProof = $runtimePacketProof
	requiredHumanObservations = @(
		"Client fade clears and late-JIP player can move/use HUD after loading.",
		"Human commander takeover pauses autonomous AICOM build/upgrade behavior and revert resumes it.",
		"Supply/cash-run workflow is playable end to end, including JIP cooldown expectations.",
		"Release package/deployment provenance is recorded separately from RPT token scoring."
	)
	privacy = "No raw RPT lines or absolute RPT paths are emitted or copied; scorer paths are public RPT-root-relative labels with short path hashes."
}
$packet | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $jsonOut -Encoding UTF8

$lines = New-Object System.Collections.Generic.List[string]
[void]$lines.Add("# WASP Release RPT Summary")
[void]$lines.Add("")
[void]$lines.Add(("Generated: {0}" -f $packet.generatedAt))
[void]$lines.Add(("Overall: {0}" -f $packet.overall))
[void]$lines.Add(("Scorer overall: {0}" -f $score.overall))
[void]$lines.Add(("Runtime packet proof: {0}" -f $packet.runtimePacketProof.status))
[void]$lines.Add(("Worlds seen: {0}" -f (Join-Display $score.worldsSeen)))
[void]$lines.Add(("Files scored: {0}" -f @(ConvertTo-Array $score.files).Count))
[void]$lines.Add("")
[void]$lines.Add("Privacy: no raw RPT lines or absolute RPT paths are emitted or copied. File paths come from the scorer's public RPT-root-relative labels with short path hashes.")
[void]$lines.Add("")
[void]$lines.Add("## Runtime Packet Proof")
[void]$lines.Add("")
[void]$lines.Add(("Status: {0}" -f $packet.runtimePacketProof.status))
[void]$lines.Add(("Manifest: {0}" -f $packet.runtimePacketProof.manifestPath))
[void]$lines.Add(("Manifest path hash: {0}" -f (Join-Display $packet.runtimePacketProof.manifestPathHash)))
[void]$lines.Add(("Schema: {0}" -f (Join-Display $packet.runtimePacketProof.schema)))
[void]$lines.Add(("Validation requested: {0}" -f $packet.runtimePacketProof.validationRequested))
[void]$lines.Add(("Validation overall: {0}" -f (Join-Display $packet.runtimePacketProof.validationOverall)))
[void]$lines.Add(("Files in manifest: {0}" -f $packet.runtimePacketProof.fileCount))
if (@(ConvertTo-Array $packet.runtimePacketProof.missing).Count -gt 0) {
	[void]$lines.Add(("Missing: {0}" -f (Join-Display $packet.runtimePacketProof.missing)))
}
if (@(ConvertTo-Array $packet.runtimePacketProof.failHits).Count -gt 0) {
	[void]$lines.Add(("Failures: {0}" -f (Join-Display $packet.runtimePacketProof.failHits)))
}
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
foreach ($key in @("aicomHbWest","aicomHbEast","aicomTickWest","aicomTickEast","aicomEvent","aicomTeamFounded","aicomAssaultDispatch","aicomCombatStatus","aicomFront","aicomPosture","aicomSnapshot","aicomWestInfFallback","aiCommanderActive","aiCommanderAssist","aicomOrder","hcSide","hcConnect","hcConnectCivilian","hcConnectNonCivilian","hcConnectSkip","hcStat","hcDeleg","delegStat","teamFoundedViaHC","jipMark","clientRosterRecv","hqMark","townAiHcCleanup","wddmArtilleryAudit","supplyLoaded","supplyCompleted","clientLogicError")) {
	[void]$lines.Add(("| {0} | {1} |" -f $key, (Get-CountValue $score.tokenCounts $key)))
}
[void]$lines.Add("")
$chernarusCounts = $null
$takistanCounts = $null
if ($null -ne $score.perTerrainTokenCounts) {
	$chernarusProperty = $score.perTerrainTokenCounts.PSObject.Properties["chernarus"]
	$takistanProperty = $score.perTerrainTokenCounts.PSObject.Properties["takistan"]
	if ($null -ne $chernarusProperty) { $chernarusCounts = $chernarusProperty.Value }
	if ($null -ne $takistanProperty) { $takistanCounts = $takistanProperty.Value }
}
if ($null -ne $chernarusCounts -or $null -ne $takistanCounts) {
	[void]$lines.Add("## Per-Terrain Selected Token Counts")
	[void]$lines.Add("")
	[void]$lines.Add("| Token | Chernarus | Takistan |")
	[void]$lines.Add("| --- | ---: | ---: |")
	foreach ($key in @("aicomHbWest","aicomHbEast","aicomTickWest","aicomTickEast","aicomEvent","aicomTeamFounded","aicomAssaultDispatch","aicomCombatStatus","aicomFront","aicomPosture","aicomSnapshot","aicomWestInfFallback","aiCommanderActive","hcConnectCivilian","hcStat","hcDeleg","delegStat","teamFoundedViaHC","jipMark","clientRosterRecv","hqMark","townAiHcCleanup","wddmArtilleryAudit","supplyLoaded","supplyCompleted")) {
		[void]$lines.Add(("| {0} | {1} | {2} |" -f $key, (Get-CountValue $chernarusCounts $key), (Get-CountValue $takistanCounts $key)))
	}
	[void]$lines.Add("")
}
[void]$lines.Add("## Human Observations Still Required")
[void]$lines.Add("")
foreach ($observation in $packet.requiredHumanObservations) {
	[void]$lines.Add(("- {0}" -f $observation))
}
[void]$lines.Add("")
if ([string]$packet.overall -eq "pass") {
	[void]$lines.Add("Result: scorer gates and supplied runtime packet proof pass. Pair this with human notes for client playability, commander handoff observations, and package/deployment provenance before calling the release complete.")
} else {
	[void]$lines.Add("Result: scorer gates or supplied runtime packet proof are still missing or failed. Keep this packet as diagnostic evidence only; collect fresh Chernarus and Takistan RPTs until all gates pass.")
}
$lines | Set-Content -LiteralPath $markdownOut -Encoding UTF8

Write-Host "Wrote release RPT summary:"
Write-Host $jsonOut
Write-Host $markdownOut

if ([string]$packet.overall -ne "pass" -and !$NoFail) { exit 1 }
