<#
.SYNOPSIS
Writes a redaction-safe WASP runtime evidence manifest template.

.DESCRIPTION
The runtime evidence validator expects one marker-sweep JSON artifact per required
terrain/role slot. This helper writes the full default matrix so operators do not
hand-copy ten rows before collecting exact-build RPT evidence.
#>

[CmdletBinding()]
param(
	[Parameter(Mandatory)] [string]$OutFile,
	[Parameter(Mandatory)] [string]$ExpectedCandidate,
	[Parameter(Mandatory)] [string]$ExpectedGit,
	[Parameter(Mandatory)] [string]$ExpectedArchiveSha256,
	[string[]]$RequiredTerrain = @("chernarus", "takistan"),
	[string[]]$RequiredRole = @("server", "hc1", "hc2", "start-client", "late-jip"),
	[string]$MarkerSweepFilePattern = "marker-sweep-{terrain}-{role}.json",
	[string]$CommandOutFile = "",
	[string]$RptPathPattern = "<rpt-root>\{terrain}\{role}.rpt",
	[switch]$Force
)

$ErrorActionPreference = "Stop"

function Expand-List {
	param([string[]]$Values)
	$items = New-Object System.Collections.Generic.List[string]
	foreach ($value in $Values) {
		if ([string]::IsNullOrWhiteSpace($value)) { continue }
		foreach ($part in ($value -split ",")) {
			$trimmed = $part.Trim().ToLowerInvariant()
			if (![string]::IsNullOrWhiteSpace($trimmed)) { $items.Add($trimmed) }
		}
	}
	return @($items.ToArray() | Select-Object -Unique)
}

$terrains = @(Expand-List -Values $RequiredTerrain)
$roles = @(Expand-List -Values $RequiredRole)
if ($terrains.Count -eq 0) { throw "At least one terrain is required." }
if ($roles.Count -eq 0) { throw "At least one role is required." }
if ([string]::IsNullOrWhiteSpace($MarkerSweepFilePattern)) { throw "MarkerSweepFilePattern cannot be empty." }
if (![string]::IsNullOrWhiteSpace($CommandOutFile) -and [string]::IsNullOrWhiteSpace($RptPathPattern)) {
	throw "RptPathPattern cannot be empty when CommandOutFile is set."
}

$fullOutFile = [System.IO.Path]::GetFullPath($OutFile)
if ((Test-Path -LiteralPath $fullOutFile) -and !$Force) {
	throw "Output already exists: $fullOutFile. Use -Force to overwrite."
}
$fullCommandOutFile = ""
if (![string]::IsNullOrWhiteSpace($CommandOutFile)) {
	$fullCommandOutFile = [System.IO.Path]::GetFullPath($CommandOutFile)
	if ((Test-Path -LiteralPath $fullCommandOutFile) -and !$Force) {
		throw "Command output already exists: $fullCommandOutFile. Use -Force to overwrite."
	}
}

$rows = New-Object System.Collections.Generic.List[object]
foreach ($terrain in $terrains) {
	foreach ($role in $roles) {
		$sweepPath = $MarkerSweepFilePattern.Replace("{terrain}", $terrain).Replace("{role}", $role)
		$rows.Add([pscustomobject][ordered]@{
			terrain = $terrain
			role = $role
			markerSweepPath = $sweepPath
		}) | Out-Null
	}
}

$manifest = [pscustomobject][ordered]@{
	schema = "a2waspwarfare-runtime-evidence-manifest-v1"
	generatedAtUtc = (Get-Date).ToUniversalTime().ToString("s") + "Z"
	release = [pscustomobject][ordered]@{
		candidate = $ExpectedCandidate
		git = $ExpectedGit
		archiveSha256 = $ExpectedArchiveSha256
	}
	evidence = $rows.ToArray()
}

$outDirectory = [System.IO.Path]::GetDirectoryName($fullOutFile)
if (![string]::IsNullOrWhiteSpace($outDirectory) -and !(Test-Path -LiteralPath $outDirectory)) {
	New-Item -ItemType Directory -Force -Path $outDirectory | Out-Null
}

$json = $manifest | ConvertTo-Json -Depth 8
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($fullOutFile, $json + [Environment]::NewLine, $utf8NoBom)

if (![string]::IsNullOrWhiteSpace($fullCommandOutFile)) {
	$commandDirectory = [System.IO.Path]::GetDirectoryName($fullCommandOutFile)
	if (![string]::IsNullOrWhiteSpace($commandDirectory) -and !(Test-Path -LiteralPath $commandDirectory)) {
		New-Item -ItemType Directory -Force -Path $commandDirectory | Out-Null
	}

	$commandLines = New-Object System.Collections.Generic.List[string]
	$commandLines.Add("# Fill in private RPT paths locally. Do not commit populated private paths or raw RPT contents.") | Out-Null
	foreach ($row in @($rows.ToArray())) {
		$rptPath = $RptPathPattern.Replace("{terrain}", $row.terrain).Replace("{role}", $row.role)
		$sweepPath = "" + $row.markerSweepPath
		$commandLines.Add(("powershell -ExecutionPolicy Bypass -File .\Tools\Monitor\Get-WaspRptMarkerSweep.ps1 ``")) | Out-Null
		$commandLines.Add(("  -RptPath ""{0}"" ``" -f $rptPath)) | Out-Null
		$commandLines.Add(("  -ExpectedCandidate {0} ``" -f $ExpectedCandidate)) | Out-Null
		$commandLines.Add(("  -ExpectedGit {0} ``" -f $ExpectedGit)) | Out-Null
		$commandLines.Add(("  -ExpectedArchiveSha256 {0} ``" -f $ExpectedArchiveSha256)) | Out-Null
		$commandLines.Add(("  -ExpectedRole {0} ``" -f $row.role)) | Out-Null
		$commandLines.Add(("  -ExpectedTerrain {0} ``" -f $row.terrain)) | Out-Null
		$commandLines.Add("  -RequireReleaseMarkers ``") | Out-Null
		$commandLines.Add("  -Json ``") | Out-Null
		$commandLines.Add(("  -OutFile ""{0}""" -f $sweepPath)) | Out-Null
		$commandLines.Add("") | Out-Null
	}
	[System.IO.File]::WriteAllText($fullCommandOutFile, (($commandLines.ToArray()) -join [Environment]::NewLine) + [Environment]::NewLine, $utf8NoBom)
	Write-Host ("Wrote WASP marker-sweep command template: {0}" -f $fullCommandOutFile)
}

Write-Host ("Wrote WASP runtime evidence manifest template: {0}" -f $fullOutFile)
Write-Host ("Slots: {0} terrain x {1} role = {2}" -f $terrains.Count, $roles.Count, $rows.Count)
