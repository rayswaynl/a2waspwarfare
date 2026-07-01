[CmdletBinding()]
param(
	[Parameter(Mandatory)] [string]$SourceMapPath,
	[string]$OutDirectory = "",
	[string]$ExpectedCandidate = "release-command-center-20260630",
	[string]$ExpectedGit = "",
	[string]$ExpectedArchiveSha256 = "",
	[switch]$Validate,
	[switch]$RequireSourceRptExists,
	[switch]$Force,
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

function ConvertTo-Array {
	param($Value)
	if ($null -eq $Value) { return @() }
	if ($Value -is [System.Array]) { return @($Value) }
	return @($Value)
}

function Get-JsonValue {
	param($Object, [string]$Name)
	if ($null -eq $Object) { return $null }
	$property = $Object.PSObject.Properties[$Name]
	if ($null -eq $property) { return $null }
	return $property.Value
}

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

function Get-FileSha256Value {
	param([string]$Path)
	if ([string]::IsNullOrWhiteSpace($Path) -or !(Test-Path -LiteralPath $Path -PathType Leaf)) { return "" }
	$sha = [System.Security.Cryptography.SHA256]::Create()
	$fs = [System.IO.File]::Open($Path,
		[System.IO.FileMode]::Open,
		[System.IO.FileAccess]::Read,
		[System.IO.FileShare]::ReadWrite)
	try {
		$hash = $sha.ComputeHash($fs)
		return ([System.BitConverter]::ToString($hash) -replace "-", "").ToUpperInvariant()
	} finally {
		$fs.Dispose()
		$sha.Dispose()
	}
}

function Resolve-InputPath {
	param([string]$Path, [string]$BasePath)
	if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
	$expanded = [System.Environment]::ExpandEnvironmentVariables($Path)
	if ([System.IO.Path]::IsPathRooted($expanded)) {
		return [System.IO.Path]::GetFullPath($expanded)
	}
	return [System.IO.Path]::GetFullPath((Join-Path $BasePath $expanded))
}

function Resolve-OutputPath {
	param([string]$Path)
	if ([string]::IsNullOrWhiteSpace($Path)) {
		$Path = Join-Path (Get-Location).Path "wasp-runtime-rpt-packet"
	}
	$expanded = [System.Environment]::ExpandEnvironmentVariables($Path)
	if ([System.IO.Path]::IsPathRooted($expanded)) {
		return [System.IO.Path]::GetFullPath($expanded)
	}
	return [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $expanded))
}

function ConvertTo-CanonicalTerrain {
	param([string]$Value)
	if ([string]::IsNullOrWhiteSpace($Value)) { return "" }
	$text = $Value.Trim().ToLowerInvariant()
	if ($text -eq "chernarus") { return "chernarus" }
	if ($text -eq "takistan") { return "takistan" }
	return ""
}

function ConvertTo-CanonicalRole {
	param([string]$Value)
	if ([string]::IsNullOrWhiteSpace($Value)) { return "" }
	$text = ($Value.Trim().ToLowerInvariant() -replace "_", "-")
	switch ($text) {
		"server" { return "server" }
		"hc1" { return "HC1" }
		"headless-client-1" { return "HC1" }
		"headlessclient1" { return "HC1" }
		"hc2" { return "HC2" }
		"headless-client-2" { return "HC2" }
		"headlessclient2" { return "HC2" }
		"start-client" { return "start-client" }
		"startclient" { return "start-client" }
		"initial-client" { return "start-client" }
		"late-jip" { return "late-JIP" }
		"latejip" { return "late-JIP" }
		"jip-client" { return "late-JIP" }
		default { return "" }
	}
}

function ConvertTo-JoinPhaseValue {
	param([string]$Value)
	if ([string]::IsNullOrWhiteSpace($Value)) { return "" }
	$text = ($Value.Trim().ToLowerInvariant() -replace "_", "-")
	switch ($text) {
		"launch" { return "start-client" }
		"start" { return "start-client" }
		"round-start" { return "start-client" }
		"start-client" { return "start-client" }
		"initial-client" { return "start-client" }
		"late" { return "late-JIP" }
		"jip" { return "late-JIP" }
		"late-jip" { return "late-JIP" }
		"mid-round" { return "late-JIP" }
		"mid-round-client" { return "late-JIP" }
		default { return "" }
	}
}

function ConvertFrom-SourceDateTime {
	param([string]$Value, [ref]$Result)
	if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
	$styles = [System.Globalization.DateTimeStyles]::AllowWhiteSpaces
	$offsetValue = [System.DateTimeOffset]::MinValue
	if ([System.DateTimeOffset]::TryParse($Value, [System.Globalization.CultureInfo]::InvariantCulture, $styles, [ref]$offsetValue)) {
		$Result.Value = $offsetValue.LocalDateTime
		return $true
	}
	$dateValue = [datetime]::MinValue
	if ([datetime]::TryParse($Value, [System.Globalization.CultureInfo]::InvariantCulture, $styles, [ref]$dateValue)) {
		$Result.Value = $dateValue
		return $true
	}
	return $false
}

function ConvertTo-SourceRecords {
	param($SourceMap)
	$records = New-Object System.Collections.Generic.List[object]
	$flatRecords = Get-JsonValue $SourceMap "records"
	if ($null -ne $flatRecords) {
		foreach ($record in (ConvertTo-Array $flatRecords)) { [void]$records.Add($record) }
		return $records.ToArray()
	}
	$runs = Get-JsonValue $SourceMap "runs"
	if ($null -ne $runs) {
		foreach ($record in (ConvertTo-Array $runs)) { [void]$records.Add($record) }
		return $records.ToArray()
	}
	$terrains = Get-JsonValue $SourceMap "terrains"
	if ($null -ne $terrains) {
		foreach ($terrainRecord in (ConvertTo-Array $terrains)) {
			$terrainName = [string](Get-JsonValue $terrainRecord "terrain")
			$terrainStart = Get-JsonValue $terrainRecord "startTime"
			$rolesValue = Get-JsonValue $terrainRecord "roles"
			foreach ($roleRecord in (ConvertTo-Array $rolesValue)) {
				$copy = [ordered]@{}
				foreach ($property in $roleRecord.PSObject.Properties) { $copy[$property.Name] = $property.Value }
				if ([string]::IsNullOrWhiteSpace([string](Get-JsonValue ([pscustomobject]$copy) "terrain"))) { $copy["terrain"] = $terrainName }
				if ($null -ne $terrainStart -and [string]::IsNullOrWhiteSpace([string](Get-JsonValue ([pscustomobject]$copy) "terrainStartTime"))) { $copy["terrainStartTime"] = $terrainStart }
				[void]$records.Add([pscustomobject]$copy)
			}
		}
	}
	return $records.ToArray()
}

function Add-Problem {
	param($List, [string]$Message)
	[void]$List.Add($Message)
}

$mapPath = Resolve-InputPath $SourceMapPath (Get-Location).Path
if (!(Test-Path -LiteralPath $mapPath -PathType Leaf)) {
	throw "Source map not found. pathHash=$(Get-SafeTextHash $mapPath)"
}
$mapItem = Get-Item -LiteralPath $mapPath
$mapDir = Split-Path -Parent $mapItem.FullName
$sourceMap = Get-Content -Raw -LiteralPath $mapItem.FullName | ConvertFrom-Json
$schema = [string](Get-JsonValue $sourceMap "schema")
if ($schema -ne "a2waspwarfare-runtime-rpt-source-map-v1") {
	throw "Source map schema must be a2waspwarfare-runtime-rpt-source-map-v1."
}

$release = Get-JsonValue $sourceMap "release"
$releaseIdentityFailures = New-Object System.Collections.Generic.List[string]
if ($null -ne $release) {
	$mapCandidate = [string](Get-JsonValue $release "candidate")
	$mapGit = [string](Get-JsonValue $release "git")
	$mapArchiveSha256 = [string](Get-JsonValue $release "archiveSha256")
	if ([string]::IsNullOrWhiteSpace($ExpectedCandidate)) {
		$ExpectedCandidate = $mapCandidate
	} elseif (![string]::IsNullOrWhiteSpace($mapCandidate) -and $mapCandidate -ne $ExpectedCandidate) {
		Add-Problem $releaseIdentityFailures "release.candidate does not match -ExpectedCandidate"
	}
	if ([string]::IsNullOrWhiteSpace($ExpectedGit)) {
		$ExpectedGit = $mapGit
	} elseif (![string]::IsNullOrWhiteSpace($mapGit) -and $mapGit -ne $ExpectedGit) {
		Add-Problem $releaseIdentityFailures "release.git does not match -ExpectedGit"
	}
	if ([string]::IsNullOrWhiteSpace($ExpectedArchiveSha256)) {
		$ExpectedArchiveSha256 = $mapArchiveSha256
	} elseif (![string]::IsNullOrWhiteSpace($mapArchiveSha256) -and !$mapArchiveSha256.Equals($ExpectedArchiveSha256, [System.StringComparison]::OrdinalIgnoreCase)) {
		Add-Problem $releaseIdentityFailures "release.archiveSha256 does not match -ExpectedArchiveSha256"
	}
}
if ($releaseIdentityFailures.Count -gt 0) {
	throw ("Runtime RPT source map release identity mismatch. Failures: {0}." -f ($releaseIdentityFailures.ToArray() -join "; "))
}
if ([string]::IsNullOrWhiteSpace($ExpectedGit)) {
	$repoRoot = Find-RepoRoot
	$ExpectedGit = Invoke-GitValue $repoRoot @("rev-parse", "--short=10", "HEAD")
}
if ([string]::IsNullOrWhiteSpace($ExpectedGit)) {
	throw "Could not determine release git short hash. Pass -ExpectedGit or set release.git in the source map."
}

$outPath = Resolve-OutputPath $OutDirectory
$terrains = @("chernarus", "takistan")
$roles = @("server", "HC1", "HC2", "start-client", "late-JIP")
$topLevelStartTimes = Get-JsonValue $sourceMap "terrainStartTimes"
$rawRecords = @(ConvertTo-SourceRecords $sourceMap)
$preparedRecords = New-Object System.Collections.Generic.List[object]
$missing = New-Object System.Collections.Generic.List[string]
$failHits = New-Object System.Collections.Generic.List[string]

foreach ($record in $rawRecords) {
	$terrain = ConvertTo-CanonicalTerrain ([string](Get-JsonValue $record "terrain"))
	$role = ConvertTo-CanonicalRole ([string](Get-JsonValue $record "role"))
	if ([string]::IsNullOrWhiteSpace($terrain) -or [string]::IsNullOrWhiteSpace($role)) {
		Add-Problem $failHits ("unknown terrain/role in source map record: terrainHash={0} roleHash={1}" -f (Get-SafeTextHash ([string](Get-JsonValue $record "terrain"))), (Get-SafeTextHash ([string](Get-JsonValue $record "role"))))
		continue
	}
	[void]$preparedRecords.Add([pscustomobject]@{
		terrain = $terrain
		role = $role
		record = $record
	})
}

foreach ($prepared in $preparedRecords.ToArray()) {
	$matches = @($preparedRecords.ToArray() | Where-Object { $_.terrain -eq $prepared.terrain -and $_.role -eq $prepared.role })
	if ($matches.Count -gt 1) {
		Add-Problem $failHits ("duplicate source map records for {0}/{1}" -f $prepared.terrain, $prepared.role)
	}
}
foreach ($prepared in $preparedRecords.ToArray()) {
	if ($terrains -notcontains $prepared.terrain -or $roles -notcontains $prepared.role) {
		Add-Problem $failHits ("extra source map record {0}/{1}" -f $prepared.terrain, $prepared.role)
	}
}

$recordLookup = @{}
foreach ($prepared in $preparedRecords.ToArray()) {
	$key = "{0}/{1}" -f $prepared.terrain, $prepared.role
	if (!$recordLookup.ContainsKey($key)) { $recordLookup[$key] = $prepared.record }
}

$resolvedRecords = New-Object System.Collections.Generic.List[object]
foreach ($terrain in $terrains) {
	foreach ($role in $roles) {
		$key = "{0}/{1}" -f $terrain, $role
		if (!$recordLookup.ContainsKey($key)) {
			Add-Problem $missing ("source map record $key")
			continue
		}
		$record = $recordLookup[$key]
		$sourceRaw = [string](Get-JsonValue $record "sourceRptPath")
		$commandLine = [string](Get-JsonValue $record "commandLine")
		$profilePath = [string](Get-JsonValue $record "profilePath")
		$pidValue = Get-JsonValue $record "pid"
		$roleProof = ConvertTo-CanonicalRole ([string](Get-JsonValue $record "roleProof"))
		$joinPhase = ConvertTo-JoinPhaseValue ([string](Get-JsonValue $record "joinPhase"))
		$terrainStartRaw = [string](Get-JsonValue $record "terrainStartTime")
		if ([string]::IsNullOrWhiteSpace($terrainStartRaw)) { $terrainStartRaw = [string](Get-JsonValue $record "startTime") }
		if ([string]::IsNullOrWhiteSpace($terrainStartRaw) -and $null -ne $topLevelStartTimes) { $terrainStartRaw = [string](Get-JsonValue $topLevelStartTimes $terrain) }
		if ([string]::IsNullOrWhiteSpace($sourceRaw)) { Add-Problem $missing ("sourceRptPath for $key") }
		if ([string]::IsNullOrWhiteSpace($commandLine)) { Add-Problem $missing ("commandLine for $key") }
		if ($null -eq $pidValue -or [string]::IsNullOrWhiteSpace([string]$pidValue)) { Add-Problem $missing ("pid for $key") }
		if ([string]::IsNullOrWhiteSpace($terrainStartRaw)) { Add-Problem $missing ("terrainStartTime for $key") }
		if ([string]::IsNullOrWhiteSpace($roleProof)) { Add-Problem $missing ("roleProof for $key") }
		if (($role -eq "start-client" -or $role -eq "late-JIP") -and [string]::IsNullOrWhiteSpace($joinPhase)) { Add-Problem $missing ("joinPhase for $key") }
		if (![string]::IsNullOrWhiteSpace($roleProof) -and $roleProof -ne $role) { Add-Problem $failHits ("roleProof for $key must be $role") }
		if (($role -eq "start-client" -or $role -eq "late-JIP") -and ![string]::IsNullOrWhiteSpace($joinPhase) -and $joinPhase -ne $role) { Add-Problem $failHits ("joinPhase for $key must be $role") }

		$pidInt = 0
		if ($null -ne $pidValue -and ![string]::IsNullOrWhiteSpace([string]$pidValue) -and ![int]::TryParse([string]$pidValue, [ref]$pidInt)) {
			Add-Problem $failHits ("pid for $key is not an integer")
		} elseif ($pidInt -lt 1 -and $null -ne $pidValue -and ![string]::IsNullOrWhiteSpace([string]$pidValue)) {
			Add-Problem $failHits ("pid for $key must be greater than zero")
		}

		$terrainStart = [datetime]::MinValue
		if (![string]::IsNullOrWhiteSpace($terrainStartRaw) -and !(ConvertFrom-SourceDateTime $terrainStartRaw ([ref]$terrainStart))) {
			Add-Problem $failHits ("terrainStartTime for $key is not a datetime")
		}

		$sourcePath = Resolve-InputPath $sourceRaw $mapDir
		if (![string]::IsNullOrWhiteSpace($sourcePath)) {
			if ([System.IO.Path]::GetExtension($sourcePath).ToLowerInvariant() -ne ".rpt") {
				Add-Problem $failHits ("sourceRptPath for $key must point to an .rpt file")
			}
			if (!(Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
				Add-Problem $failHits ("source RPT not found for ${key}: sourceRptPathHash=$(Get-SafeTextHash $sourcePath)")
			}
		}

		$destinationPath = Join-Path (Join-Path $outPath $terrain) ("{0}.rpt" -f $role)
		if (![string]::IsNullOrWhiteSpace($sourcePath) -and $sourcePath.Equals($destinationPath, [System.StringComparison]::OrdinalIgnoreCase)) {
			Add-Problem $failHits ("sourceRptPath and destination packet path are the same for $key")
		}

		[void]$resolvedRecords.Add([ordered]@{
			terrain = $terrain
			role = $role
			sourcePath = $sourcePath
			destinationPath = $destinationPath
			terrainStartTime = $terrainStart
			pid = $pidInt
			commandLine = $commandLine
			profilePath = $profilePath
			roleProof = $roleProof
			joinPhase = $joinPhase
		})
	}
}

if ($missing.Count -gt 0 -or $failHits.Count -gt 0) {
	$message = "Runtime RPT source map is incomplete."
	if ($missing.Count -gt 0) { $message += " Missing: $($missing.ToArray() -join '; ')." }
	if ($failHits.Count -gt 0) { $message += " Failures: $($failHits.ToArray() -join '; ')." }
	throw $message
}

$plannedOutputs = New-Object System.Collections.Generic.List[string]
$ledgerOut = Join-Path $outPath "release-run-ledger.json"
$manifestOut = Join-Path $outPath "runtime-rpt-packet-manifest.json"
[void]$plannedOutputs.Add($ledgerOut)
[void]$plannedOutputs.Add($manifestOut)
foreach ($record in $resolvedRecords.ToArray()) { [void]$plannedOutputs.Add([string]$record.destinationPath) }
if (!$Force) {
	foreach ($candidate in $plannedOutputs.ToArray()) {
		if (Test-Path -LiteralPath $candidate) {
			throw "Output already exists. pathHash=$(Get-SafeTextHash $candidate). Pass -Force to overwrite."
		}
	}
}

[void](New-Item -ItemType Directory -Path $outPath -Force)
foreach ($terrain in $terrains) {
	[void](New-Item -ItemType Directory -Path (Join-Path $outPath $terrain) -Force)
}

$ledgerRecords = New-Object System.Collections.Generic.List[object]
$manifestFiles = New-Object System.Collections.Generic.List[object]
foreach ($record in $resolvedRecords.ToArray()) {
	Copy-Item -LiteralPath ([string]$record.sourcePath) -Destination ([string]$record.destinationPath) -Force
	$sourceItem = Get-Item -LiteralPath ([string]$record.sourcePath)
	$copiedItem = Get-Item -LiteralPath ([string]$record.destinationPath)
	$sourceSha256 = Get-FileSha256Value $sourceItem.FullName
	$copiedSha256 = Get-FileSha256Value $copiedItem.FullName
	$packetPath = "{0}\{1}.rpt" -f $record.terrain, $record.role
	[void]$ledgerRecords.Add([ordered]@{
		terrain = [string]$record.terrain
		role = [string]$record.role
		terrainStartTime = ([datetime]$record.terrainStartTime).ToString("yyyy-MM-ddTHH:mm:sszzz")
		pid = [int]$record.pid
		commandLine = [string]$record.commandLine
		profilePath = [string]$record.profilePath
		sourceRptPath = $sourceItem.FullName
		sourceRptLastWriteTime = $sourceItem.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:sszzz")
		sourceRptSha256 = $sourceSha256
		copiedRptPath = $packetPath
		copiedRptSha256 = $copiedSha256
		copiedLastWriteTime = $copiedItem.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:sszzz")
		roleProof = [string]$record.roleProof
		joinPhase = [string]$record.joinPhase
	})
	[void]$manifestFiles.Add([ordered]@{
		terrain = [string]$record.terrain
		role = [string]$record.role
		copiedRptPath = $packetPath
		copiedPathHash = Get-SafeTextHash $copiedItem.FullName
		copiedRptSha256 = $copiedSha256
		sourceRptPathHash = Get-SafeTextHash $sourceItem.FullName
		sourceRptLastWriteTime = $sourceItem.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:sszzz")
		sourceRptSha256Prefix = if ($sourceSha256.Length -ge 12) { $sourceSha256.Substring(0, 12) } else { "" }
		commandLineRecorded = (![string]::IsNullOrWhiteSpace([string]$record.commandLine))
		commandLineHash = Get-SafeTextHash ([string]$record.commandLine)
		pidRecorded = ([int]$record.pid -gt 0)
		roleProof = [string]$record.roleProof
		joinPhase = [string]$record.joinPhase
		terrainStartTime = ([datetime]$record.terrainStartTime).ToString("yyyy-MM-ddTHH:mm:sszzz")
		lengthBytes = [int64]$copiedItem.Length
	})
}

$ledger = [ordered]@{
	schema = "a2waspwarfare-runtime-run-ledger-v1"
	release = [ordered]@{
		candidate = $ExpectedCandidate
		git = $ExpectedGit
		archiveSha256 = $ExpectedArchiveSha256
	}
	records = $ledgerRecords.ToArray()
}
$ledger | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ledgerOut -Encoding UTF8

$validationResult = $null
if ($Validate) {
	$validatorPath = Join-Path $PSScriptRoot "Test-WaspRuntimeRptPacket.ps1"
	if (!(Test-Path -LiteralPath $validatorPath -PathType Leaf)) {
		throw "Runtime packet validator not found. pathHash=$(Get-SafeTextHash $validatorPath)"
	}
	$validatorArgs = @{
		RptRoot = $outPath
		ExpectedCandidate = $ExpectedCandidate
		ExpectedGit = $ExpectedGit
		RunLedgerPath = $ledgerOut
		Json = $true
		NoFail = $true
	}
	if (![string]::IsNullOrWhiteSpace($ExpectedArchiveSha256)) { $validatorArgs["ExpectedArchiveSha256"] = $ExpectedArchiveSha256 }
	if ($RequireSourceRptExists) { $validatorArgs["RequireSourceRptExists"] = $true }
	$validationJson = & $validatorPath @validatorArgs
	$validatorSucceeded = $?
	if (!$validatorSucceeded) {
		throw "Runtime packet validator failed to execute."
	}
	try {
		$validationResult = $validationJson | ConvertFrom-Json
	} catch {
		throw "Runtime packet validator returned non-JSON output."
	}
}

$manifest = [ordered]@{
	schema = "a2waspwarfare-runtime-rpt-packet-builder-v1"
	generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
	rptRoot = "<rpt-root>"
	rptRootHash = Get-SafeTextHash $outPath
	sourceMapPathHash = Get-SafeTextHash $mapItem.FullName
	release = [ordered]@{
		candidate = $ExpectedCandidate
		git = $ExpectedGit
		archiveSha256 = $ExpectedArchiveSha256
	}
	artifacts = [ordered]@{
		ledgerPath = "release-run-ledger.json"
		manifestPath = "runtime-rpt-packet-manifest.json"
	}
	files = $manifestFiles.ToArray()
	validation = if ($null -eq $validationResult) {
		[ordered]@{
			requested = $false
			overall = "skipped"
		}
	} else {
		[ordered]@{
			requested = $true
			overall = [string]$validationResult.overall
			gates = $validationResult.gates
		}
	}
	privacy = "This manifest omits raw source RPT paths, raw command lines and absolute copied paths. Keep the populated source map and release-run-ledger.json private unless separately redacted."
}
$manifest | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $manifestOut -Encoding UTF8

if ($Json) {
	$manifest | ConvertTo-Json -Depth 14
} else {
	Write-Host "Wrote WASP runtime RPT packet:"
	Write-Host "Root: <rpt-root> (pathHash=$(Get-SafeTextHash $outPath))"
	Write-Host "Ledger: release-run-ledger.json"
	Write-Host "Manifest: runtime-rpt-packet-manifest.json"
	Write-Host ("Copied RPT files: {0}" -f $manifestFiles.Count)
	Write-Host ("Validation: {0}" -f $manifest.validation.overall)
}

if ($Validate -and !$NoFail -and $null -ne $validationResult -and [string]$validationResult.overall -ne "pass") {
	exit 1
}
