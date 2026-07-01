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

$fullOutFile = [System.IO.Path]::GetFullPath($OutFile)
if ((Test-Path -LiteralPath $fullOutFile) -and !$Force) {
	throw "Output already exists: $fullOutFile. Use -Force to overwrite."
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

Write-Host ("Wrote WASP runtime evidence manifest template: {0}" -f $fullOutFile)
Write-Host ("Slots: {0} terrain x {1} role = {2}" -f $terrains.Count, $roles.Count, $rows.Count)
