<#
.SYNOPSIS
Validates a redaction-safe WASP runtime evidence manifest.

.DESCRIPTION
The marker sweep proves package markers inside selected RPT files. This validator
checks the higher-level release gate: every required terrain/role slot must be
represented by a marker-sweep JSON artifact that matches the active package tuple.

The manifest format is intentionally small:

{
  "schema": "a2waspwarfare-runtime-evidence-manifest-v1",
  "evidence": [
    {
      "terrain": "chernarus",
      "role": "server",
      "markerSweepPath": "marker-sweep-chernarus-server.json"
    }
  ]
}
#>

[CmdletBinding()]
param(
	[Parameter(Mandatory)] [string]$ManifestPath,
	[Parameter(Mandatory)] [string]$ExpectedCandidate,
	[Parameter(Mandatory)] [string]$ExpectedGit,
	[Parameter(Mandatory)] [string]$ExpectedArchiveSha256,
	[string[]]$RequiredTerrain = @("chernarus", "takistan"),
	[string[]]$RequiredRole = @("server", "hc1", "hc2", "start-client", "late-jip"),
	[switch]$NoFail
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

function Add-Finding {
	param(
		[System.Collections.Generic.List[string]]$Findings,
		[string]$Message
	)
	$Findings.Add($Message) | Out-Null
}

function Read-JsonFile {
	param([Parameter(Mandatory)] [string]$Path)
	if (!(Test-Path -LiteralPath $Path)) { throw "JSON file not found: $Path" }
	return (Get-Content -Raw -LiteralPath $Path) | ConvertFrom-Json
}

function Resolve-ManifestRelativePath {
	param(
		[Parameter(Mandatory)] [string]$BaseDirectory,
		[Parameter(Mandatory)] [string]$Path
	)
	if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
	return [System.IO.Path]::GetFullPath((Join-Path $BaseDirectory $Path))
}

function Get-JsonProperty {
	param(
		[Parameter(Mandatory)] $Object,
		[Parameter(Mandatory)] [string]$Name
	)
	$property = $Object.PSObject.Properties[$Name]
	if ($null -eq $property) { return $null }
	return $property.Value
}

function Get-CountValue {
	param(
		[Parameter(Mandatory)] $Counts,
		[Parameter(Mandatory)] [string]$Name
	)
	$value = Get-JsonProperty -Object $Counts -Name $Name
	if ($null -eq $value) { return 0 }
	return [int]$value
}

$manifestFullPath = [System.IO.Path]::GetFullPath($ManifestPath)
$manifestDirectory = [System.IO.Path]::GetDirectoryName($manifestFullPath)
$manifest = Read-JsonFile -Path $manifestFullPath
$findings = New-Object System.Collections.Generic.List[string]

if ($manifest.schema -ne "a2waspwarfare-runtime-evidence-manifest-v1") {
	Add-Finding $findings ("Manifest schema must be a2waspwarfare-runtime-evidence-manifest-v1, got [{0}]." -f $manifest.schema)
}

$manifestRelease = Get-JsonProperty -Object $manifest -Name "release"
if ($null -ne $manifestRelease) {
	if ((Get-JsonProperty -Object $manifestRelease -Name "candidate") -ne $ExpectedCandidate) {
		Add-Finding $findings "Manifest release.candidate does not match expected candidate."
	}
	if ((Get-JsonProperty -Object $manifestRelease -Name "git") -ne $ExpectedGit) {
		Add-Finding $findings "Manifest release.git does not match expected git."
	}
	if ((Get-JsonProperty -Object $manifestRelease -Name "archiveSha256") -ne $ExpectedArchiveSha256) {
		Add-Finding $findings "Manifest release.archiveSha256 does not match expected archive SHA."
	}
}

$requiredTerrains = @(Expand-List -Values $RequiredTerrain)
$requiredRoles = @(Expand-List -Values $RequiredRole)
if ($requiredTerrains.Count -eq 0) { Add-Finding $findings "At least one required terrain is needed." }
if ($requiredRoles.Count -eq 0) { Add-Finding $findings "At least one required role is needed." }

$evidenceRows = @(Get-JsonProperty -Object $manifest -Name "evidence")
if ($evidenceRows.Count -eq 0) {
	Add-Finding $findings "Manifest has no evidence rows."
}

$slotState = @{}
foreach ($terrain in $requiredTerrains) {
	foreach ($role in $requiredRoles) {
		$slotState["$terrain|$role"] = $false
	}
}

foreach ($row in $evidenceRows) {
	$terrain = ("" + (Get-JsonProperty -Object $row -Name "terrain")).Trim().ToLowerInvariant()
	$role = ("" + (Get-JsonProperty -Object $row -Name "role")).Trim().ToLowerInvariant()
	$sweepPath = "" + (Get-JsonProperty -Object $row -Name "markerSweepPath")
	$slot = "$terrain|$role"

	if ($requiredTerrains -notcontains $terrain) {
		Add-Finding $findings ("Evidence row has unexpected terrain [{0}]." -f $terrain)
		continue
	}
	if ($requiredRoles -notcontains $role) {
		Add-Finding $findings ("Evidence row has unexpected role [{0}] for terrain [{1}]." -f $role, $terrain)
		continue
	}
	if ([string]::IsNullOrWhiteSpace($sweepPath)) {
		Add-Finding $findings ("Evidence row [{0}] is missing markerSweepPath." -f $slot)
		continue
	}

	$resolvedSweepPath = Resolve-ManifestRelativePath -BaseDirectory $manifestDirectory -Path $sweepPath
	$sweep = $null
	try {
		$sweep = Read-JsonFile -Path $resolvedSweepPath
	} catch {
		Add-Finding $findings ("Evidence row [{0}] marker sweep cannot be read: {1}" -f $slot, $_.Exception.Message)
		continue
	}

	$rowFindingCount = $findings.Count
	if ($sweep.schema -ne "a2waspwarfare-rpt-marker-sweep-v1") {
		Add-Finding $findings ("Evidence row [{0}] marker sweep has unexpected schema [{1}]." -f $slot, $sweep.schema)
	}
	if ($sweep.expectedCandidate -ne $ExpectedCandidate) {
		Add-Finding $findings ("Evidence row [{0}] candidate mismatch: expected [{1}], got [{2}]." -f $slot, $ExpectedCandidate, $sweep.expectedCandidate)
	}
	if ($sweep.expectedGit -ne $ExpectedGit) {
		Add-Finding $findings ("Evidence row [{0}] git mismatch: expected [{1}], got [{2}]." -f $slot, $ExpectedGit, $sweep.expectedGit)
	}
	if ($sweep.expectedArchiveSha256 -ne $ExpectedArchiveSha256) {
		Add-Finding $findings ("Evidence row [{0}] archive SHA mismatch." -f $slot)
	}
	if ($sweep.expectedRole -ne $role) {
		Add-Finding $findings ("Evidence row [{0}] role mismatch: expected [{1}], got [{2}]." -f $slot, $role, $sweep.expectedRole)
	}

	$missingRequired = @(Get-JsonProperty -Object $sweep -Name "missingRequired")
	if ($missingRequired.Count -gt 0) {
		Add-Finding $findings ("Evidence row [{0}] marker sweep still has missing required markers: {1}" -f $slot, ($missingRequired -join ", "))
	}

	$terrainMarker = "WASPRELEASE|v1|candidate=$ExpectedCandidate|git=$ExpectedGit|terrain=$terrain"
	$terrainMarkerCount = Get-CountValue -Counts $sweep.counts -Name $terrainMarker
	if ($terrainMarkerCount -le 0) {
		Add-Finding $findings ("Evidence row [{0}] marker sweep lacks terrain marker [{1}]." -f $slot, $terrainMarker)
	}

	if ($findings.Count -eq $rowFindingCount) {
		$slotState[$slot] = $true
	}
}

foreach ($terrain in $requiredTerrains) {
	foreach ($role in $requiredRoles) {
		$slot = "$terrain|$role"
		if (!$slotState[$slot]) {
			Add-Finding $findings ("Missing valid runtime evidence slot [{0}]." -f $slot)
		}
	}
}

if ($findings.Count -eq 0) {
	Write-Host ("Test-WaspRuntimeEvidenceManifest: PASS terrain={0} role={1}" -f ($requiredTerrains -join ","), ($requiredRoles -join ","))
	exit 0
}

Write-Host "Test-WaspRuntimeEvidenceManifest: FAIL"
foreach ($finding in $findings) {
	Write-Host ("  - {0}" -f $finding)
}

if (!$NoFail) { exit 1 }
