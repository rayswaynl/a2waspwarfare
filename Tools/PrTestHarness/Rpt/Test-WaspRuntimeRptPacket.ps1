[CmdletBinding()]
param(
	[Parameter(Mandatory)] [string]$RptRoot,
	[string]$ExpectedCandidate = "release-command-center-20260630",
	[string]$ExpectedGit = "",
	[datetime]$ChernarusStartTime,
	[datetime]$TakistanStartTime,
	[switch]$Json,
	[switch]$NoFail
)

$ErrorActionPreference = "Stop"

function Find-RepoRoot {
	$dir = (Get-Item -LiteralPath $PSScriptRoot).FullName
	while ($true) {
		$mission = Join-Path $dir "Missions\[55-2hc]warfarev2_073v48co.chernarus"
		$loadout = Join-Path $dir "Tools\LoadoutManager"
		if ((Test-Path -LiteralPath $mission) -and (Test-Path -LiteralPath $loadout)) { return $dir }
		$parent = Split-Path -Parent $dir
		if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $dir) { throw "Could not find repository root from $PSScriptRoot" }
		$dir = $parent
	}
}

function Invoke-GitValue {
	param([string]$RepoRoot, [string[]]$Arguments)
	$output = & git -C $RepoRoot @Arguments 2>$null
	if ($LASTEXITCODE -ne 0 -or !$output) { return "" }
	return (($output | Select-Object -First 1).ToString().Trim())
}

function ConvertTo-SafePath {
	param([string]$Path)
	if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
	$safe = $Path
	if (![string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
		$safe = $safe -replace [regex]::Escape($env:USERPROFILE), "%USERPROFILE%"
	}
	return $safe
}

function ConvertTo-Array {
	param($Value)
	if ($null -eq $Value) { return @() }
	if ($Value -is [System.Array]) { return @($Value) }
	return @($Value)
}

function Get-RptLines {
	param([string]$Path)
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

function Get-StartupWindow {
	param([string[]]$Lines)
	$missInitIndex = -1
	for ($i = $Lines.Count - 1; $i -ge 0; $i--) {
		if ($Lines[$i] -match "MISSINIT:") {
			$missInitIndex = $i
			break
		}
	}
	if ($missInitIndex -lt 0) {
		return [ordered]@{
			found = $false
			startLine = 1
			missInitLine = 0
			lines = @()
			worldName = ""
			missionName = ""
			isServer = ""
			isDedicated = ""
		}
	}
	$startIndex = $missInitIndex
	for ($j = $missInitIndex; $j -ge ([Math]::Max(0, $missInitIndex - 20)); $j--) {
		if ($Lines[$j] -match "## Mission Name") {
			$startIndex = $j
			break
		}
	}
	$windowLines = @($Lines[$startIndex..($Lines.Count - 1)])
	$missInit = $Lines[$missInitIndex]
	$session = [ordered]@{
		missionName = ""
		worldName = ""
		isMultiplayer = ""
		isServer = ""
		isDedicated = ""
	}
	if ($missInit -match "MISSINIT: missionName=([^,]+), worldName=([^,]+), isMultiplayer=([^,]+), isServer=([^,]+), isDedicated=([^\]]+)") {
		$session.missionName = $matches[1].Trim()
		$session.worldName = $matches[2].Trim()
		$session.isMultiplayer = $matches[3].Trim()
		$session.isServer = $matches[4].Trim()
		$session.isDedicated = ($matches[5] -replace '"', '').Trim()
	}
	return [ordered]@{
		found = $true
		startLine = $startIndex + 1
		missInitLine = $missInitIndex + 1
		lines = $windowLines
		missionName = $session.missionName
		worldName = $session.worldName
		isMultiplayer = $session.isMultiplayer
		isServer = $session.isServer
		isDedicated = $session.isDedicated
	}
}

function Test-WindowContains {
	param([string[]]$Lines, [string]$Needle)
	foreach ($line in $Lines) {
		if ($line.Contains($Needle)) { return $true }
	}
	return $false
}

if (!(Test-Path -LiteralPath $RptRoot)) {
	throw "RPT root not found: $RptRoot"
}
$rootItem = Get-Item -LiteralPath $RptRoot
if (!$rootItem.PSIsContainer) {
	throw "RptRoot must be a directory containing chernarus and takistan subdirectories: $RptRoot"
}
$rootPath = $rootItem.FullName

if ([string]::IsNullOrWhiteSpace($ExpectedGit)) {
	$repoRoot = Find-RepoRoot
	$ExpectedGit = Invoke-GitValue $repoRoot @("rev-parse", "--short=10", "HEAD")
}
if ([string]::IsNullOrWhiteSpace($ExpectedGit)) {
	throw "Could not determine release git short hash. Pass -ExpectedGit explicitly."
}

$terrains = @("chernarus", "takistan")
$roles = @("server", "HC1", "HC2", "start-client", "late-JIP")
$expectedMarkers = @{
	chernarus = "WASPRELEASE|v1|candidate=$ExpectedCandidate|git=$ExpectedGit|terrain=chernarus"
	takistan = "WASPRELEASE|v1|candidate=$ExpectedCandidate|git=$ExpectedGit|terrain=takistan"
}
$startTimes = @{
	chernarus = if ($PSBoundParameters.ContainsKey("ChernarusStartTime")) { $ChernarusStartTime } else { $null }
	takistan = if ($PSBoundParameters.ContainsKey("TakistanStartTime")) { $TakistanStartTime } else { $null }
}

$expectedFiles = New-Object System.Collections.Generic.List[object]
foreach ($terrain in $terrains) {
	foreach ($role in $roles) {
		$expectedFiles.Add([ordered]@{
			terrain = $terrain
			role = $role
			path = Join-Path (Join-Path $rootPath $terrain) ("{0}.rpt" -f $role)
		})
	}
}

$fileResults = New-Object System.Collections.Generic.List[object]
$missingFiles = @()
$markerWorldFailures = @()
$freshnessFailures = @()
$freshnessMissing = @()
$resolvedPaths = @()

foreach ($expected in $expectedFiles) {
	$terrain = [string]$expected.terrain
	$role = [string]$expected.role
	$path = [string]$expected.path
	if (!(Test-Path -LiteralPath $path)) {
		$missingFiles += ("{0}/{1}.rpt" -f $terrain, $role)
		$fileResults.Add([ordered]@{
			terrain = $terrain
			role = $role
			path = ConvertTo-SafePath $path
			status = "missing"
		})
		continue
	}
	$item = Get-Item -LiteralPath $path
	if ($item.PSIsContainer) {
		$missingFiles += ("{0}/{1}.rpt is a directory" -f $terrain, $role)
		continue
	}
	$resolvedPaths += $item.FullName.ToLowerInvariant()
	$lines = Get-RptLines -Path $item.FullName
	$window = Get-StartupWindow -Lines $lines
	$marker = [string]$expectedMarkers[$terrain]
	$markerPresent = if ($window.found) { Test-WindowContains -Lines ([string[]]$window.lines) -Needle $marker } else { $false }
	$worldOk = ([string]$window.worldName).ToLowerInvariant() -eq $terrain
	if (!$window.found) {
		$markerWorldFailures += ("{0}/{1}: missing MISSINIT" -f $terrain, $role)
	} elseif (!$worldOk) {
		$markerWorldFailures += ("{0}/{1}: worldName={2}" -f $terrain, $role, $window.worldName)
	}
	if (!$markerPresent) {
		$markerWorldFailures += ("{0}/{1}: missing expected marker" -f $terrain, $role)
	}
	$startTime = $startTimes[$terrain]
	$freshnessStatus = "not_checked"
	if ($null -eq $startTime) {
		$freshnessMissing += $terrain
	} elseif ($item.LastWriteTime -le $startTime) {
		$freshnessStatus = "stale"
		$freshnessFailures += ("{0}/{1}: LastWriteTime {2} <= start {3}" -f $terrain, $role, $item.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:sszzz"), $startTime.ToString("yyyy-MM-ddTHH:mm:sszzz"))
	} else {
		$freshnessStatus = "pass"
	}
	$fileResults.Add([ordered]@{
		terrain = $terrain
		role = $role
		path = ConvertTo-SafePath $item.FullName
		lastWriteTime = $item.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:sszzz")
		lengthBytes = $item.Length
		lineCount = $lines.Count
		startupWindowStartLine = [int]$window.startLine
		missInitLine = [int]$window.missInitLine
		missionName = [string]$window.missionName
		worldName = [string]$window.worldName
		expectedMarker = $marker
		expectedMarkerFound = [bool]$markerPresent
		worldMatchesTerrain = [bool]$worldOk
		freshness = $freshnessStatus
	})
}

$allRptFiles = @([System.IO.Directory]::EnumerateFiles($rootPath, "*.rpt", [System.IO.SearchOption]::AllDirectories))
$allRptFiles += @([System.IO.Directory]::EnumerateFiles($rootPath, "*.RPT", [System.IO.SearchOption]::AllDirectories))
$allRptResolved = @($allRptFiles | ForEach-Object { (Get-Item -LiteralPath $_).FullName } | Select-Object -Unique)
$expectedResolved = @($expectedFiles | ForEach-Object {
	if (Test-Path -LiteralPath $_.path) { (Get-Item -LiteralPath $_.path).FullName.ToLowerInvariant() }
})
$extraFiles = @()
foreach ($file in $allRptResolved) {
	if ($expectedResolved -notcontains $file.ToLowerInvariant()) { $extraFiles += (ConvertTo-SafePath $file) }
}
$duplicatePaths = @($resolvedPaths | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
$freshnessMissing = @($freshnessMissing | Select-Object -Unique)

$gates = @(
	[ordered]@{
		id = "exact-ten-file-matrix"
		status = if ($missingFiles.Count -eq 0) { "pass" } else { "missing" }
		missing = $missingFiles
		failHits = @()
		note = "Requires chernarus/{server,HC1,HC2,start-client,late-JIP}.rpt and takistan/{server,HC1,HC2,start-client,late-JIP}.rpt."
	},
	[ordered]@{
		id = "no-extra-rpt-files"
		status = if ($extraFiles.Count -eq 0) { "pass" } else { "fail" }
		missing = @()
		failHits = $extraFiles
		note = "Rejects stray RPT files that could let aggregate scoring hide missing roles."
	},
	[ordered]@{
		id = "no-duplicate-copied-paths"
		status = if ($duplicatePaths.Count -eq 0) { "pass" } else { "fail" }
		missing = @()
		failHits = @($duplicatePaths | ForEach-Object { ConvertTo-SafePath $_ })
		note = "Each role/terrain RPT must be a distinct copied file; original source paths are checked in the runtime run ledger."
	},
	[ordered]@{
		id = "per-file-marker-world"
		status = if ($markerWorldFailures.Count -eq 0) { "pass" } else { "fail" }
		missing = @()
		failHits = $markerWorldFailures
		note = "Each file's latest startup window must contain the terrain-specific WASPRELEASE marker and matching MISSINIT worldName."
	},
	[ordered]@{
		id = "per-terrain-freshness-cutoffs"
		status = if ($freshnessMissing.Count -eq 0 -and $freshnessFailures.Count -eq 0) { "pass" } elseif ($freshnessFailures.Count -gt 0) { "fail" } else { "missing" }
		missing = @($freshnessMissing | ForEach-Object { "{0} start time" -f $_ })
		failHits = $freshnessFailures
		note = "Pass -ChernarusStartTime and -TakistanStartTime from the runtime run ledger; copied RPT LastWriteTime must be after that terrain's launch start."
	}
)

$overallPass = (@($gates | Where-Object { $_.status -ne "pass" }).Count -eq 0)
$result = [ordered]@{
	schema = "a2waspwarfare-runtime-rpt-packet-v1"
	generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
	rptRoot = ConvertTo-SafePath $rootPath
	expectedCandidate = $ExpectedCandidate
	expectedGit = $ExpectedGit
	expectedMarkers = [ordered]@{
		chernarus = $expectedMarkers.chernarus
		takistan = $expectedMarkers.takistan
	}
	startTimes = [ordered]@{
		chernarus = if ($null -eq $startTimes.chernarus) { "" } else { $startTimes.chernarus.ToString("yyyy-MM-ddTHH:mm:sszzz") }
		takistan = if ($null -eq $startTimes.takistan) { "" } else { $startTimes.takistan.ToString("yyyy-MM-ddTHH:mm:sszzz") }
	}
	files = $fileResults.ToArray()
	gates = $gates
	overall = if ($overallPass) { "pass" } else { "missing_or_failed" }
	privacy = "No raw RPT lines are emitted; paths are user-profile redacted."
}

if ($Json) {
	$result | ConvertTo-Json -Depth 12
} else {
	Write-Host "WASP runtime RPT packet matrix check"
	Write-Host "Root: $(ConvertTo-SafePath $rootPath)"
	Write-Host "Expected git: $ExpectedGit"
	Write-Host ""
	Write-Host "Gate results:"
	foreach ($gate in $gates) {
		$detail = ""
		if ($gate.missing.Count -gt 0) { $detail += " missing=$($gate.missing -join ',')" }
		if ($gate.failHits.Count -gt 0) { $detail += " failHits=$($gate.failHits -join ',')" }
		Write-Host ("{0,-30} {1,-8}{2}" -f $gate.id, $gate.status, $detail)
	}
	Write-Host ""
	Write-Host "Files:"
	foreach ($file in $fileResults) {
		Write-Host ("{0}/{1,-12} marker={2} world={3} fresh={4}" -f $file.terrain, $file.role, $file.expectedMarkerFound, $file.worldMatchesTerrain, $file.freshness)
	}
	Write-Host ""
	if ($overallPass) {
		Write-Host "PASS: runtime RPT packet has the exact role/terrain matrix, markers, worlds and freshness cutoffs." -ForegroundColor Green
	} else {
		Write-Host "FAIL: runtime RPT packet is missing required role/terrain proof or freshness." -ForegroundColor Red
	}
}

if (!$overallPass -and !$NoFail) { exit 1 }
