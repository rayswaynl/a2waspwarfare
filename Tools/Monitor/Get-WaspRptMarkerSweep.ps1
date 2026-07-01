<#
.SYNOPSIS
Counts release-proof markers in Arma 2 OA RPT files without copying or dumping logs.

.DESCRIPTION
This helper is intentionally small and privacy-conscious. It scans explicit RPT files
or the newest files in one or more RPT directories, counts important WASP release,
AI commander, and headless-client markers, and reports path/line hashes by default.

Use -IncludeLineText only when the log owner accepts that marker lines may contain
names, UIDs, owner IDs, positions, or other operational details.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File .\Tools\Monitor\Get-WaspRptMarkerSweep.ps1 `
  -RptDirectory C:\WASP\rpt-archive -Latest 8 -Json

.EXAMPLE
powershell -ExecutionPolicy Bypass -File .\Tools\Monitor\Get-WaspRptMarkerSweep.ps1 `
  -RptDirectory C:\WASP\rpt-archive `
  -RequirePattern HCDROP_AICOM_AUDIT,HCRECON_AICOM_AUDIT `
  -Json

.EXAMPLE
powershell -ExecutionPolicy Bypass -File .\Tools\Monitor\Get-WaspRptMarkerSweep.ps1 `
  -RptDirectory C:\WASP\rpt-archive `
  -ExpectedCandidate release-command-center-20260630 `
  -ExpectedGit b3f4d3664f `
  -RequireReleaseMarkers `
  -Json
#>

[CmdletBinding()]
param(
	[string[]]$RptPath = @(),
	[string[]]$RptDirectory = @(),
	[int]$Latest = 8,
	[string[]]$Pattern = @(),
	[string[]]$RequirePattern = @(),
	[string]$ExpectedCandidate = "",
	[string]$ExpectedGit = "",
	[string[]]$ExpectedTerrain = @("chernarus", "takistan"),
	[switch]$RequireReleaseMarkers,
	[string]$WindowMarker = "",
	[int]$SampleLimit = 3,
	[switch]$Recurse,
	[switch]$Regex,
	[switch]$IncludeLineText,
	[switch]$NoFail,
	[switch]$Json
)

$ErrorActionPreference = "Stop"

function Get-SafeTextHash {
	param([string]$Text)
	if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
	$sha = [System.Security.Cryptography.SHA256]::Create()
	try {
		$bytes = [System.Text.Encoding]::UTF8.GetBytes($Text.ToLowerInvariant())
		$hash = $sha.ComputeHash($bytes)
		return ([System.BitConverter]::ToString($hash) -replace "-", "").Substring(0, 12)
	} finally {
		$sha.Dispose()
	}
}

function ConvertTo-PublicRptLabel {
	param([Parameter(Mandatory)] [string]$Path)
	$fullPath = [System.IO.Path]::GetFullPath($Path)
	return ("{0} (pathHash={1})" -f ([System.IO.Path]::GetFileName($fullPath)), (Get-SafeTextHash $fullPath))
}

function Get-RptCandidateFiles {
	$items = New-Object System.Collections.Generic.List[object]

	foreach ($path in $RptPath) {
		if ([string]::IsNullOrWhiteSpace($path)) { continue }
		if (!(Test-Path -LiteralPath $path)) { throw "RPT not found: $path" }
		$item = Get-Item -LiteralPath $path
		if ($item.PSIsContainer) { throw "RptPath must be a file, got directory: $path" }
		$items.Add($item)
	}

	foreach ($dir in $RptDirectory) {
		if ([string]::IsNullOrWhiteSpace($dir)) { continue }
		if (!(Test-Path -LiteralPath $dir)) { throw "RPT directory not found: $dir" }
		$searchOption = if ($Recurse) { [System.IO.SearchOption]::AllDirectories } else { [System.IO.SearchOption]::TopDirectoryOnly }
		$resolved = (Resolve-Path -LiteralPath $dir).Path
		foreach ($file in [System.IO.Directory]::EnumerateFiles($resolved, "*.rpt", $searchOption)) {
			$items.Add((Get-Item -LiteralPath $file))
		}
		foreach ($file in [System.IO.Directory]::EnumerateFiles($resolved, "*.RPT", $searchOption)) {
			$items.Add((Get-Item -LiteralPath $file))
		}
	}

	$selected = @($items |
		Sort-Object FullName -Unique |
		Sort-Object LastWriteTimeUtc -Descending)
	if ($Latest -gt 0 -and $selected.Count -gt $Latest) {
		$selected = @($selected | Select-Object -First $Latest)
	}
	return $selected
}

function Read-RptLines {
	param([Parameter(Mandatory)] [string]$Path)
	$fs = [System.IO.File]::Open($Path,
		[System.IO.FileMode]::Open,
		[System.IO.FileAccess]::Read,
		[System.IO.FileShare]::ReadWrite)
	try {
		$reader = New-Object System.IO.StreamReader($fs)
		try { $content = $reader.ReadToEnd() } finally { $reader.Dispose() }
	} finally {
		$fs.Dispose()
	}
	return @($content -split "`r?`n")
}

function Get-RptWindow {
	param(
		[string[]]$Lines,
		[string]$Marker
	)
	$startIndex = 0
	$markerFound = $false
	if (![string]::IsNullOrWhiteSpace($Marker)) {
		for ($i = $Lines.Count - 1; $i -ge 0; $i--) {
			if ($Lines[$i] -match $Marker) {
				$startIndex = $i
				$markerFound = $true
				break
			}
		}
	}
	$windowLines = if ($startIndex -gt 0) { @($Lines[$startIndex..($Lines.Count - 1)]) } else { @($Lines) }
	return [ordered]@{
		lines = $windowLines
		windowStartLine = $startIndex + 1
		windowLineCount = $windowLines.Count
		windowMarkerFound = $markerFound
	}
}

function Test-LineMatch {
	param(
		[string]$Line,
		[string]$Needle,
		[bool]$UseRegex
	)
	if ($UseRegex) { return ($Line -match $Needle) }
	return ($Line.IndexOf($Needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)
}

function Expand-PatternArgument {
	param([string[]]$Values)
	$expanded = New-Object System.Collections.Generic.List[string]
	foreach ($value in $Values) {
		if ([string]::IsNullOrWhiteSpace($value)) { continue }
		foreach ($part in ($value -split ",")) {
			$trimmed = $part.Trim()
			if (![string]::IsNullOrWhiteSpace($trimmed)) { $expanded.Add($trimmed) }
		}
	}
	return $expanded.ToArray()
}

function New-ExpectedReleaseMarkers {
	param(
		[string]$Candidate,
		[string]$Git,
		[string[]]$Terrain
	)
	$markers = New-Object System.Collections.Generic.List[string]
	if ([string]::IsNullOrWhiteSpace($Candidate) -or [string]::IsNullOrWhiteSpace($Git)) {
		return $markers.ToArray()
	}
	foreach ($terrainName in (Expand-PatternArgument -Values $Terrain)) {
		$trimmedTerrain = $terrainName.Trim().ToLowerInvariant()
		if ([string]::IsNullOrWhiteSpace($trimmedTerrain)) { continue }
		$markers.Add(("WASPRELEASE|v1|candidate={0}|git={1}|terrain={2}" -f $Candidate.Trim(), $Git.Trim(), $trimmedTerrain))
	}
	return $markers.ToArray()
}

$defaultPatterns = @(
	"WASPRELEASE",
	"WF_RELEASE_MARKER",
	"HCDROP_AICOM_AUDIT",
	"HCRECON_AICOM_AUDIT",
	"HCSIDE|v1|disconnect",
	"HCSIDE|v1|reconnect",
	"HCDISPATCH",
	"HCSTAT",
	"AICOMSTAT",
	"WATCHDOG|restart-stale-hb",
	"GRPBUDGET|WARN",
	"Error in expression",
	"Undefined variable",
	"No entry",
	"Missing ;"
)

$Pattern = @(Expand-PatternArgument -Values $Pattern)
$RequirePattern = @(Expand-PatternArgument -Values $RequirePattern)
$hasExplicitPattern = $Pattern.Count -gt 0
$expectedReleaseMarkers = @(New-ExpectedReleaseMarkers -Candidate $ExpectedCandidate -Git $ExpectedGit -Terrain $ExpectedTerrain)

$patterns = @()
if ($hasExplicitPattern) { $patterns += $Pattern } else { $patterns += $defaultPatterns }
foreach ($marker in $expectedReleaseMarkers) {
	if ($patterns -notcontains $marker) { $patterns += $marker }
	if ($RequireReleaseMarkers -and ($RequirePattern -notcontains $marker)) { $RequirePattern += $marker }
}
foreach ($required in $RequirePattern) {
	if (![string]::IsNullOrWhiteSpace($required) -and ($patterns -notcontains $required)) {
		$patterns += $required
	}
}
$patterns = @($patterns | Where-Object { ![string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)

$files = @(Get-RptCandidateFiles)
if ($files.Count -eq 0) { throw "No RPT files selected. Pass -RptPath or -RptDirectory." }

$aggregate = [ordered]@{}
$samples = New-Object System.Collections.Generic.List[object]
foreach ($patternName in $patterns) { $aggregate[$patternName] = 0 }

$fileResults = New-Object System.Collections.Generic.List[object]

foreach ($file in $files) {
	$allLines = @(Read-RptLines -Path $file.FullName)
	$window = Get-RptWindow -Lines $allLines -Marker $WindowMarker
	$fileCounts = [ordered]@{}
	foreach ($patternName in $patterns) { $fileCounts[$patternName] = 0 }

	$lineNumber = [int]$window.windowStartLine
	foreach ($line in @($window.lines)) {
		foreach ($patternName in $patterns) {
			if (Test-LineMatch -Line $line -Needle $patternName -UseRegex ([bool]$Regex)) {
				$fileCounts[$patternName] = [int]$fileCounts[$patternName] + 1
				$aggregate[$patternName] = [int]$aggregate[$patternName] + 1
				$currentSamples = @($samples | Where-Object { $_.pattern -eq $patternName })
				if ($currentSamples.Count -lt $SampleLimit) {
					$row = [ordered]@{
						pattern = $patternName
						pathLabel = ConvertTo-PublicRptLabel -Path $file.FullName
						lineNumber = $lineNumber
						lineHash = Get-SafeTextHash $line
					}
					if ($IncludeLineText) { $row["line"] = $line }
					$samples.Add([pscustomobject]$row)
				}
			}
		}
		$lineNumber++
	}

	$fileResults.Add([pscustomobject][ordered]@{
		pathLabel = ConvertTo-PublicRptLabel -Path $file.FullName
		lastWriteTimeUtc = $file.LastWriteTimeUtc.ToString("s") + "Z"
		length = $file.Length
		rawLineCount = $allLines.Count
		windowStartLine = $window.windowStartLine
		windowLineCount = $window.windowLineCount
		windowMarkerFound = $window.windowMarkerFound
		counts = $fileCounts
	})
}

$missingRequired = @()
foreach ($required in $RequirePattern) {
	if ([string]::IsNullOrWhiteSpace($required)) { continue }
	if (!$aggregate.Contains($required) -or [int]$aggregate[$required] -eq 0) {
		$missingRequired += $required
	}
}

$patternMode = "literal"
if ($Regex) { $patternMode = "regex" }

$result = [pscustomobject][ordered]@{
	schema = "a2waspwarfare-rpt-marker-sweep-v1"
	generatedAtUtc = (Get-Date).ToUniversalTime().ToString("s") + "Z"
	patternMode = $patternMode
	fileCount = $files.Count
	latestLimit = $Latest
	windowMarker = $WindowMarker
	expectedCandidate = $ExpectedCandidate
	expectedGit = $ExpectedGit
	expectedReleaseMarkers = $expectedReleaseMarkers
	counts = $aggregate
	missingRequired = $missingRequired
	files = $fileResults.ToArray()
	samples = $samples.ToArray()
}

if ($Json) {
	$result | ConvertTo-Json -Depth 8
} else {
	Write-Host ("WASP RPT marker sweep: files={0} mode={1}" -f $result.fileCount, $result.patternMode)
	if ($missingRequired.Count -gt 0) {
		Write-Host ("Missing required: {0}" -f ($missingRequired -join ", "))
	}
	$result.counts.GetEnumerator() | Sort-Object Name | Format-Table -AutoSize
}

if ($missingRequired.Count -gt 0 -and !$NoFail) {
	exit 1
}
