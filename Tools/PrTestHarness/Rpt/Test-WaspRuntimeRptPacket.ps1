[CmdletBinding()]
param(
	[Parameter(Mandatory)] [string]$RptRoot,
	[string]$ExpectedCandidate = "release-command-center-20260630",
	[string]$ExpectedGit = "",
	[string]$ExpectedArchiveSha256 = "",
	[string]$RunLedgerPath = "",
	[switch]$RequireSourceRptExists,
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

function ConvertTo-PacketPath {
	param(
		[string]$Path,
		[string]$RootPath
	)
	if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
	$fullPath = [System.IO.Path]::GetFullPath($Path)
	$pathHash = Get-SafeTextHash $fullPath
	if (![string]::IsNullOrWhiteSpace($RootPath)) {
		$rootFull = [System.IO.Path]::GetFullPath($RootPath).TrimEnd([char[]]@('\','/'))
		$prefix = $rootFull + [System.IO.Path]::DirectorySeparatorChar
		if ($fullPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
			$relative = $fullPath.Substring($prefix.Length)
			return ("<rpt-root>\{0} (pathHash={1})" -f $relative, $pathHash)
		}
	}
	return ("<rpt-file>\{0} (pathHash={1})" -f ([System.IO.Path]::GetFileName($fullPath)), $pathHash)
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

function Resolve-LedgerPathValue {
	param([string]$Path, [string]$DefaultBasePath)
	if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
	$expanded = [System.Environment]::ExpandEnvironmentVariables($Path)
	if ([System.IO.Path]::IsPathRooted($expanded)) {
		return [System.IO.Path]::GetFullPath($expanded)
	}
	return [System.IO.Path]::GetFullPath((Join-Path $DefaultBasePath $expanded))
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

function ConvertTo-Sha256Text {
	param([string]$Value)
	if ([string]::IsNullOrWhiteSpace($Value)) { return "" }
	return $Value.Trim().ToUpperInvariant()
}

function Test-IsSha256Text {
	param([string]$Value)
	return (![string]::IsNullOrWhiteSpace($Value) -and $Value -match "^[A-Fa-f0-9]{64}$")
}

function ConvertTo-RoleProofValue {
	param([string]$Value)
	if ([string]::IsNullOrWhiteSpace($Value)) { return "" }
	$text = ($Value.Trim().ToLowerInvariant() -replace "_", "-")
	switch ($text) {
		"server" { return "server" }
		"dedicated-server" { return "server" }
		"hc1" { return "HC1" }
		"headless-client-1" { return "HC1" }
		"headlessclient1" { return "HC1" }
		"hc2" { return "HC2" }
		"headless-client-2" { return "HC2" }
		"headlessclient2" { return "HC2" }
		"start-client" { return "start-client" }
		"startclient" { return "start-client" }
		"initial-client" { return "start-client" }
		"launch-client" { return "start-client" }
		"late-jip" { return "late-JIP" }
		"latejip" { return "late-JIP" }
		"jip-client" { return "late-JIP" }
		"mid-round-client" { return "late-JIP" }
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

function ConvertFrom-LedgerDateTime {
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

function ConvertTo-LedgerRecords {
	param($Ledger)
	$records = New-Object System.Collections.Generic.List[object]
	$flatRecords = Get-JsonValue $Ledger "records"
	if ($null -ne $flatRecords) {
		foreach ($record in (ConvertTo-Array $flatRecords)) { [void]$records.Add($record) }
		return $records.ToArray()
	}
	$runs = Get-JsonValue $Ledger "runs"
	if ($null -ne $runs) {
		foreach ($record in (ConvertTo-Array $runs)) { [void]$records.Add($record) }
		return $records.ToArray()
	}
	$terrains = Get-JsonValue $Ledger "terrains"
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

function Test-WaspRuntimeRunLedger {
	param(
		[string]$LedgerPath,
		[string]$RootPath,
		[string]$ExpectedGit,
		[string]$ExpectedCandidate,
		[string]$ExpectedArchiveSha256,
		[object[]]$ExpectedFiles,
		[hashtable]$ExplicitStartTimes
	)
	$missing = New-Object System.Collections.Generic.List[string]
	$failHits = New-Object System.Collections.Generic.List[string]
	$recordResults = New-Object System.Collections.Generic.List[object]
	$ledgerStartTimes = @{}

	if ([string]::IsNullOrWhiteSpace($LedgerPath)) {
		[void]$missing.Add("RunLedgerPath")
		return [ordered]@{
			status = "missing"
			path = ""
			missing = $missing.ToArray()
			failHits = $failHits.ToArray()
			startTimes = $ledgerStartTimes
			records = $recordResults.ToArray()
		}
	}

	if (!(Test-Path -LiteralPath $LedgerPath)) {
		[void]$missing.Add("run ledger file")
		return [ordered]@{
			status = "missing"
			path = ConvertTo-PacketPath -Path $LedgerPath -RootPath $RootPath
			missing = $missing.ToArray()
			failHits = $failHits.ToArray()
			startTimes = $ledgerStartTimes
			records = $recordResults.ToArray()
		}
	}

	$ledgerItem = Get-Item -LiteralPath $LedgerPath
	$ledgerDir = Split-Path -Parent $ledgerItem.FullName
	try {
		$ledger = Get-Content -Raw -LiteralPath $ledgerItem.FullName | ConvertFrom-Json
	} catch {
		[void]$failHits.Add("run ledger JSON parse failed")
		return [ordered]@{
			status = "fail"
			path = ConvertTo-PacketPath -Path $ledgerItem.FullName -RootPath $RootPath
			missing = $missing.ToArray()
			failHits = $failHits.ToArray()
			startTimes = $ledgerStartTimes
			records = $recordResults.ToArray()
		}
	}

	$schema = [string](Get-JsonValue $ledger "schema")
	if ($schema -ne "a2waspwarfare-runtime-run-ledger-v1") {
		[void]$failHits.Add("schema must be a2waspwarfare-runtime-run-ledger-v1")
	}
	$release = Get-JsonValue $ledger "release"
	if ($null -ne $release) {
		$ledgerGit = [string](Get-JsonValue $release "git")
		$ledgerCandidate = [string](Get-JsonValue $release "candidate")
		$ledgerArchiveSha256 = [string](Get-JsonValue $release "archiveSha256")
		if (![string]::IsNullOrWhiteSpace($ledgerGit) -and $ledgerGit -ne $ExpectedGit) {
			[void]$failHits.Add("release.git '$ledgerGit' does not match expected '$ExpectedGit'")
		}
		if (![string]::IsNullOrWhiteSpace($ledgerCandidate) -and $ledgerCandidate -ne $ExpectedCandidate) {
			[void]$failHits.Add("release.candidate '$ledgerCandidate' does not match expected '$ExpectedCandidate'")
		}
		if (![string]::IsNullOrWhiteSpace($ExpectedArchiveSha256)) {
			if ([string]::IsNullOrWhiteSpace($ledgerArchiveSha256)) {
				[void]$failHits.Add("release.archiveSha256 is required when ExpectedArchiveSha256 is supplied")
			} elseif (!$ledgerArchiveSha256.Equals($ExpectedArchiveSha256, [System.StringComparison]::OrdinalIgnoreCase)) {
				[void]$failHits.Add("release.archiveSha256 does not match expected package SHA256")
			}
		}
	} elseif (![string]::IsNullOrWhiteSpace($ExpectedArchiveSha256)) {
		[void]$failHits.Add("release object with archiveSha256 is required when ExpectedArchiveSha256 is supplied")
	}

	$records = @(ConvertTo-LedgerRecords $ledger)
	if ($records.Count -eq 0) {
		[void]$missing.Add("records")
	}

	$sourcePaths = New-Object System.Collections.Generic.List[string]
	$sourceShaValues = New-Object System.Collections.Generic.List[object]
	$copiedShaValues = New-Object System.Collections.Generic.List[object]
	$processKeysByTerrain = @{}
	$topLevelStartTimes = Get-JsonValue $ledger "terrainStartTimes"
	$expectedKeys = @{}
	foreach ($expected in $ExpectedFiles) { $expectedKeys[("{0}/{1}" -f $expected.terrain, $expected.role)] = $true }
	foreach ($record in $records) {
		$recordKey = "{0}/{1}" -f ([string](Get-JsonValue $record "terrain")).ToLowerInvariant(), ([string](Get-JsonValue $record "role"))
		if (!$expectedKeys.ContainsKey($recordKey)) {
			[void]$failHits.Add("extra ledger record $recordKey")
		}
	}
	foreach ($expected in $ExpectedFiles) {
		$terrain = [string]$expected.terrain
		$role = [string]$expected.role
		$expectedCopiedPath = [System.IO.Path]::GetFullPath([string]$expected.path)
		$matches = @($records | Where-Object { ([string](Get-JsonValue $_ "terrain")).ToLowerInvariant() -eq $terrain -and ([string](Get-JsonValue $_ "role")) -eq $role })
		if ($matches.Count -eq 0) {
			[void]$missing.Add("ledger record $terrain/$role")
			continue
		}
		if ($matches.Count -gt 1) {
			[void]$failHits.Add("duplicate ledger records for $terrain/$role")
		}
		$record = $matches[0]
		$sourceRaw = [string](Get-JsonValue $record "sourceRptPath")
		$copiedRaw = [string](Get-JsonValue $record "copiedRptPath")
		$commandLine = [string](Get-JsonValue $record "commandLine")
		$pidValue = Get-JsonValue $record "pid"
		$copiedLastWriteRaw = [string](Get-JsonValue $record "copiedLastWriteTime")
		$sourceLastWriteRaw = [string](Get-JsonValue $record "sourceRptLastWriteTime")
		$sourceSha256 = ConvertTo-Sha256Text ([string](Get-JsonValue $record "sourceRptSha256"))
		$copiedSha256 = ConvertTo-Sha256Text ([string](Get-JsonValue $record "copiedRptSha256"))
		$roleProof = ConvertTo-RoleProofValue ([string](Get-JsonValue $record "roleProof"))
		$joinPhase = ConvertTo-JoinPhaseValue ([string](Get-JsonValue $record "joinPhase"))
		$terrainStartRaw = [string](Get-JsonValue $record "terrainStartTime")
		if ([string]::IsNullOrWhiteSpace($terrainStartRaw)) { $terrainStartRaw = [string](Get-JsonValue $record "startTime") }
		if ([string]::IsNullOrWhiteSpace($terrainStartRaw) -and $null -ne $topLevelStartTimes) { $terrainStartRaw = [string](Get-JsonValue $topLevelStartTimes $terrain) }

		if ([string]::IsNullOrWhiteSpace($sourceRaw)) { [void]$missing.Add("sourceRptPath for $terrain/$role") }
		if ([string]::IsNullOrWhiteSpace($copiedRaw)) { [void]$missing.Add("copiedRptPath for $terrain/$role") }
		if ([string]::IsNullOrWhiteSpace($commandLine)) { [void]$missing.Add("commandLine for $terrain/$role") }
		if ($null -eq $pidValue -or [string]::IsNullOrWhiteSpace([string]$pidValue)) { [void]$missing.Add("pid for $terrain/$role") }
		if ([string]::IsNullOrWhiteSpace($terrainStartRaw)) { [void]$missing.Add("terrainStartTime for $terrain/$role") }
		if ([string]::IsNullOrWhiteSpace($sourceLastWriteRaw)) { [void]$missing.Add("sourceRptLastWriteTime for $terrain/$role") }
		if ([string]::IsNullOrWhiteSpace($sourceSha256)) { [void]$missing.Add("sourceRptSha256 for $terrain/$role") }
		if ([string]::IsNullOrWhiteSpace($copiedSha256)) { [void]$missing.Add("copiedRptSha256 for $terrain/$role") }
		if ([string]::IsNullOrWhiteSpace($roleProof)) { [void]$missing.Add("roleProof for $terrain/$role") }
		if (($role -eq "start-client" -or $role -eq "late-JIP") -and [string]::IsNullOrWhiteSpace($joinPhase)) { [void]$missing.Add("joinPhase for $terrain/$role") }
		if (![string]::IsNullOrWhiteSpace($sourceSha256) -and !(Test-IsSha256Text $sourceSha256)) { [void]$failHits.Add("sourceRptSha256 for $terrain/$role must be a SHA256 hex value") }
		if (![string]::IsNullOrWhiteSpace($copiedSha256) -and !(Test-IsSha256Text $copiedSha256)) { [void]$failHits.Add("copiedRptSha256 for $terrain/$role must be a SHA256 hex value") }
		if (![string]::IsNullOrWhiteSpace($roleProof) -and $roleProof -ne $role) { [void]$failHits.Add("roleProof for $terrain/$role must be $role") }
		if (($role -eq "start-client" -or $role -eq "late-JIP") -and ![string]::IsNullOrWhiteSpace($joinPhase) -and $joinPhase -ne $role) { [void]$failHits.Add("joinPhase for $terrain/$role must be $role") }
		if (Test-IsSha256Text $sourceSha256) { [void]$sourceShaValues.Add([pscustomobject]@{ sha = $sourceSha256; key = "$terrain/$role" }) }
		if (Test-IsSha256Text $copiedSha256) { [void]$copiedShaValues.Add([pscustomobject]@{ sha = $copiedSha256; key = "$terrain/$role" }) }

		$sourcePath = Resolve-LedgerPathValue $sourceRaw $ledgerDir
		$copiedPath = Resolve-LedgerPathValue $copiedRaw $RootPath
		if (![string]::IsNullOrWhiteSpace($sourcePath)) {
			[void]$sourcePaths.Add($sourcePath.ToLowerInvariant())
			if ([System.IO.Path]::GetExtension($sourcePath).ToLowerInvariant() -ne ".rpt") { [void]$failHits.Add("sourceRptPath for $terrain/$role must point to an .rpt file") }
			if ($RequireSourceRptExists -and !(Test-Path -LiteralPath $sourcePath)) { [void]$failHits.Add("source RPT does not exist for ${terrain}/${role}: sourceRptPathHash=$(Get-SafeTextHash $sourcePath)") }
		}
		if (![string]::IsNullOrWhiteSpace($copiedPath) -and $copiedPath.ToLowerInvariant() -ne $expectedCopiedPath.ToLowerInvariant()) {
			[void]$failHits.Add("copiedRptPath for $terrain/$role does not match packet path")
		}
		if (![string]::IsNullOrWhiteSpace($sourcePath) -and $sourcePath.Equals($copiedPath, [System.StringComparison]::OrdinalIgnoreCase)) {
			[void]$failHits.Add("sourceRptPath and copiedRptPath are the same for $terrain/$role")
		}
		if ((Test-Path -LiteralPath $expectedCopiedPath -PathType Leaf) -and !(Test-IsSha256Text $copiedSha256)) {
			[void]$failHits.Add("copiedRptSha256 for $terrain/$role is required before copied file hash can be verified")
		} elseif ((Test-Path -LiteralPath $expectedCopiedPath -PathType Leaf) -and (Get-FileSha256Value $expectedCopiedPath) -ne $copiedSha256) {
			[void]$failHits.Add("copiedRptSha256 for $terrain/$role does not match copied file")
		}
		if ($RequireSourceRptExists -and ![string]::IsNullOrWhiteSpace($sourcePath) -and (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
			$actualSourceItem = Get-Item -LiteralPath $sourcePath
			$actualSourceSha256 = Get-FileSha256Value $sourcePath
			if ((Test-IsSha256Text $sourceSha256) -and $actualSourceSha256 -ne $sourceSha256) {
				[void]$failHits.Add("sourceRptSha256 for $terrain/$role does not match source file")
			}
			if ((Test-IsSha256Text $copiedSha256) -and $actualSourceSha256 -ne $copiedSha256) {
				[void]$failHits.Add("source RPT content does not match copied packet file for $terrain/$role")
			}
			if (![string]::IsNullOrWhiteSpace($sourceLastWriteRaw)) {
				$recordedSourceLastWrite = [datetime]::MinValue
				if ((ConvertFrom-LedgerDateTime $sourceLastWriteRaw ([ref]$recordedSourceLastWrite)) -and [Math]::Abs(($actualSourceItem.LastWriteTime - $recordedSourceLastWrite).TotalSeconds) -gt 2) {
					[void]$failHits.Add("sourceRptLastWriteTime for $terrain/$role does not match source file")
				}
			}
		}

		$pidInt = 0
		if ($null -ne $pidValue -and ![int]::TryParse([string]$pidValue, [ref]$pidInt)) {
			[void]$failHits.Add("pid for $terrain/$role is not an integer")
		} elseif ($pidInt -lt 1 -and $null -ne $pidValue -and ![string]::IsNullOrWhiteSpace([string]$pidValue)) {
			[void]$failHits.Add("pid for $terrain/$role must be greater than zero")
		} elseif ($pidInt -gt 0) {
			if (!$processKeysByTerrain.ContainsKey($terrain)) { $processKeysByTerrain[$terrain] = New-Object System.Collections.Generic.List[string] }
			$processKey = "$pidInt|$(Get-SafeTextHash $commandLine)"
			[void]$processKeysByTerrain[$terrain].Add($processKey)
		}

		$terrainStart = [datetime]::MinValue
		if (![string]::IsNullOrWhiteSpace($terrainStartRaw)) {
			if (!(ConvertFrom-LedgerDateTime $terrainStartRaw ([ref]$terrainStart))) {
				[void]$failHits.Add("terrainStartTime for $terrain/$role is not a datetime")
			} else {
				if (!$ledgerStartTimes.ContainsKey($terrain)) {
					$ledgerStartTimes[$terrain] = $terrainStart
				} elseif ([Math]::Abs(($ledgerStartTimes[$terrain] - $terrainStart).TotalSeconds) -gt 2) {
					[void]$failHits.Add("terrainStartTime differs across $terrain ledger records")
				}
				if ($ExplicitStartTimes.ContainsKey($terrain) -and $null -ne $ExplicitStartTimes[$terrain] -and [Math]::Abs(($ExplicitStartTimes[$terrain] - $terrainStart).TotalSeconds) -gt 2) {
					[void]$failHits.Add("explicit $terrain start time does not match ledger")
				}
			}
		}

		$sourceLastWrite = [datetime]::MinValue
		if (![string]::IsNullOrWhiteSpace($sourceLastWriteRaw)) {
			if (!(ConvertFrom-LedgerDateTime $sourceLastWriteRaw ([ref]$sourceLastWrite))) {
				[void]$failHits.Add("sourceRptLastWriteTime for $terrain/$role is not a datetime")
			} elseif ($terrainStart -ne [datetime]::MinValue -and $sourceLastWrite -le $terrainStart) {
				[void]$failHits.Add("sourceRptLastWriteTime for $terrain/$role is not after terrainStartTime")
			}
		}

		$copiedLastWrite = [datetime]::MinValue
		if (![string]::IsNullOrWhiteSpace($copiedLastWriteRaw)) {
			if (!(ConvertFrom-LedgerDateTime $copiedLastWriteRaw ([ref]$copiedLastWrite))) {
				[void]$failHits.Add("copiedLastWriteTime for $terrain/$role is not a datetime")
			} elseif (Test-Path -LiteralPath $expectedCopiedPath) {
				$actualLastWrite = (Get-Item -LiteralPath $expectedCopiedPath).LastWriteTime
				if ([Math]::Abs(($actualLastWrite - $copiedLastWrite).TotalSeconds) -gt 2) {
					[void]$failHits.Add("copiedLastWriteTime for $terrain/$role does not match copied file")
				}
			}
		}

		[void]$recordResults.Add([ordered]@{
			terrain = $terrain
			role = $role
			sourceRptRecorded = (![string]::IsNullOrWhiteSpace($sourcePath))
			sourceRptPathHash = Get-SafeTextHash $sourcePath
			copiedRptPath = ConvertTo-PacketPath -Path $copiedPath -RootPath $RootPath
			pidRecorded = ($pidInt -gt 0)
			commandLineRecorded = (![string]::IsNullOrWhiteSpace($commandLine))
			terrainStartTime = if ($terrainStart -eq [datetime]::MinValue) { "" } else { $terrainStart.ToString("yyyy-MM-ddTHH:mm:sszzz") }
			sourceRptLastWriteTime = if ($sourceLastWrite -eq [datetime]::MinValue) { "" } else { $sourceLastWrite.ToString("yyyy-MM-ddTHH:mm:sszzz") }
			sourceRptSha256Recorded = (Test-IsSha256Text $sourceSha256)
			copiedRptSha256Recorded = (Test-IsSha256Text $copiedSha256)
			copiedLastWriteTime = if ($copiedLastWrite -eq [datetime]::MinValue) { "" } else { $copiedLastWrite.ToString("yyyy-MM-ddTHH:mm:sszzz") }
			roleProof = $roleProof
			joinPhase = $joinPhase
		})
	}

	$duplicateSourcePaths = @($sourcePaths.ToArray() | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
	foreach ($duplicate in $duplicateSourcePaths) {
		[void]$failHits.Add("duplicate original source RPT path hash: $(Get-SafeTextHash $duplicate)")
	}
	foreach ($group in @($sourceShaValues.ToArray() | Group-Object -Property sha | Where-Object { $_.Count -gt 1 })) {
		$roles = @($group.Group | ForEach-Object { $_.key }) -join ","
		[void]$failHits.Add("duplicate original source RPT content hash: contentHash=$($group.Name.Substring(0, 12)) roles=$roles")
	}
	foreach ($group in @($copiedShaValues.ToArray() | Group-Object -Property sha | Where-Object { $_.Count -gt 1 })) {
		$roles = @($group.Group | ForEach-Object { $_.key }) -join ","
		[void]$failHits.Add("duplicate copied RPT content hash: contentHash=$($group.Name.Substring(0, 12)) roles=$roles")
	}
	foreach ($terrainName in $processKeysByTerrain.Keys) {
		$duplicateProcessKeys = @($processKeysByTerrain[$terrainName].ToArray() | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
		foreach ($duplicateProcessKey in $duplicateProcessKeys) {
			$processParts = $duplicateProcessKey -split "\|", 2
			$duplicatePid = $processParts[0]
			$duplicateCommandLineHash = if ($processParts.Count -gt 1) { $processParts[1] } else { "" }
			[void]$failHits.Add("duplicate process evidence for ${terrainName}: pid=$duplicatePid commandLineHash=$duplicateCommandLineHash")
		}
	}

	$status = if ($failHits.Count -gt 0) { "fail" } elseif ($missing.Count -gt 0) { "missing" } else { "pass" }
	return [ordered]@{
		status = $status
		path = ConvertTo-PacketPath -Path $ledgerItem.FullName -RootPath $RootPath
		missing = $missing.ToArray()
		failHits = $failHits.ToArray()
		startTimes = $ledgerStartTimes
		records = $recordResults.ToArray()
	}
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

function Test-WindowContainsAny {
	param([string[]]$Lines, [string[]]$Needles)
	foreach ($needle in $Needles) {
		if (Test-WindowContains -Lines $Lines -Needle $needle) { return $true }
	}
	return $false
}

function ConvertTo-BooleanValue {
	param([string]$Value)
	if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
	$text = ($Value -replace '"', '').Trim().ToLowerInvariant()
	if ($text -eq "true") { return $true }
	if ($text -eq "false") { return $false }
	return $null
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

$ledgerResult = Test-WaspRuntimeRunLedger -LedgerPath $RunLedgerPath -RootPath $rootPath -ExpectedGit $ExpectedGit -ExpectedCandidate $ExpectedCandidate -ExpectedArchiveSha256 $ExpectedArchiveSha256 -ExpectedFiles $expectedFiles.ToArray() -ExplicitStartTimes $startTimes
foreach ($terrain in $terrains) {
	if ($null -eq $startTimes[$terrain] -and $ledgerResult.startTimes.ContainsKey($terrain)) {
		$startTimes[$terrain] = $ledgerResult.startTimes[$terrain]
	}
}

$fileResults = New-Object System.Collections.Generic.List[object]
$missingFiles = @()
$markerWorldFailures = @()
$roleIdentityFailures = @()
$roleProofFailures = @()
$freshnessFailures = @()
$freshnessMissing = @()
$resolvedPaths = @()
$copiedContentEvidence = New-Object System.Collections.Generic.List[object]
$hcProofTokens = @(
	"initJIPCompatible.sqf: Detected an headless client.",
	"Init_HC.sqf: Running the headless client initialization.",
	"Init_HC.sqf: HC "
)
$clientProofTokens = @(
	"initJIPCompatible.sqf: Executing the Client Initialization.",
	"Init_Client.sqf: Client initialization begins"
)

foreach ($expected in $expectedFiles) {
	$terrain = [string]$expected.terrain
	$role = [string]$expected.role
	$path = [string]$expected.path
	if (!(Test-Path -LiteralPath $path)) {
		$missingFiles += ("{0}/{1}.rpt" -f $terrain, $role)
		$fileResults.Add([ordered]@{
			terrain = $terrain
			role = $role
			path = ConvertTo-PacketPath -Path $path -RootPath $rootPath
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
	$copiedFileSha256 = Get-FileSha256Value $item.FullName
	if (Test-IsSha256Text $copiedFileSha256) {
		[void]$copiedContentEvidence.Add([pscustomobject]@{ sha = $copiedFileSha256; key = "$terrain/$role" })
	}
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
	if ($window.found) {
		$windowLines = [string[]]$window.lines
		$isServerValue = ConvertTo-BooleanValue ([string]$window.isServer)
		$isDedicatedValue = ConvertTo-BooleanValue ([string]$window.isDedicated)
		$hasHcLocalProof = Test-WindowContainsAny -Lines $windowLines -Needles $hcProofTokens
		$hasClientLocalProof = Test-WindowContainsAny -Lines $windowLines -Needles $clientProofTokens
		if ($null -eq $isServerValue -or $null -eq $isDedicatedValue) {
			$roleIdentityFailures += ("{0}/{1}: missing isServer/isDedicated in MISSINIT" -f $terrain, $role)
		} elseif ($role -eq "server") {
			if (!$isServerValue -or !$isDedicatedValue) {
				$roleIdentityFailures += ("{0}/{1}: expected dedicated server RPT, got isServer={2} isDedicated={3}" -f $terrain, $role, $window.isServer, $window.isDedicated)
			}
		} elseif ($isServerValue -or $isDedicatedValue) {
			$roleIdentityFailures += ("{0}/{1}: non-server role has isServer={2} isDedicated={3}" -f $terrain, $role, $window.isServer, $window.isDedicated)
		}
		if ($role -eq "HC1" -or $role -eq "HC2") {
			if (!$hasHcLocalProof) {
				$roleProofFailures += ("{0}/{1}: missing HC-local startup proof" -f $terrain, $role)
			}
			if ($hasClientLocalProof) {
				$roleProofFailures += ("{0}/{1}: HC role contains player-client startup proof" -f $terrain, $role)
			}
		} elseif ($role -eq "start-client" -or $role -eq "late-JIP") {
			if (!$hasClientLocalProof) {
				$roleProofFailures += ("{0}/{1}: missing player-client startup proof" -f $terrain, $role)
			}
			if ($hasHcLocalProof) {
				$roleProofFailures += ("{0}/{1}: client role contains HC-local startup proof" -f $terrain, $role)
			}
		}
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
		path = ConvertTo-PacketPath -Path $item.FullName -RootPath $rootPath
		pathHash = Get-SafeTextHash $item.FullName
		contentHash = if ((Test-IsSha256Text $copiedFileSha256)) { $copiedFileSha256.Substring(0, 12) } else { "" }
		lastWriteTime = $item.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:sszzz")
		lengthBytes = $item.Length
		lineCount = $lines.Count
		startupWindowStartLine = [int]$window.startLine
		missInitLine = [int]$window.missInitLine
		missionName = [string]$window.missionName
		worldName = [string]$window.worldName
		isServer = [string]$window.isServer
		isDedicated = [string]$window.isDedicated
		expectedMarker = $marker
		expectedMarkerFound = [bool]$markerPresent
		worldMatchesTerrain = [bool]$worldOk
		hasHcLocalProof = if ($window.found) { [bool]$hasHcLocalProof } else { $false }
		hasClientLocalProof = if ($window.found) { [bool]$hasClientLocalProof } else { $false }
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
	if ($expectedResolved -notcontains $file.ToLowerInvariant()) { $extraFiles += (ConvertTo-PacketPath -Path $file -RootPath $rootPath) }
}
$duplicatePaths = @($resolvedPaths | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
$duplicateContentFailures = @()
foreach ($group in @($copiedContentEvidence.ToArray() | Group-Object -Property sha | Where-Object { $_.Count -gt 1 })) {
	$roles = @($group.Group | ForEach-Object { $_.key }) -join ","
	$duplicateContentFailures += ("contentHash={0} roles={1}" -f $group.Name.Substring(0, 12), $roles)
}
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
		failHits = @($duplicatePaths | ForEach-Object { ConvertTo-PacketPath -Path $_ -RootPath $rootPath })
		note = "Each role/terrain RPT must be a distinct copied file; original source paths are checked in the runtime run ledger."
	},
	[ordered]@{
		id = "no-duplicate-rpt-content"
		status = if ($duplicateContentFailures.Count -eq 0) { "pass" } else { "fail" }
		missing = @()
		failHits = $duplicateContentFailures
		note = "Each role/terrain RPT must have distinct content; copied files with matching hashes fail even when filenames differ."
	},
	[ordered]@{
		id = "runtime-run-ledger"
		status = $ledgerResult.status
		missing = @($ledgerResult.missing)
		failHits = @($ledgerResult.failHits)
		note = "Requires a JSON run ledger with unique original source RPT paths, source LastWriteTime/SHA256, copied packet paths/SHA256, command lines, PIDs and per-terrain launch start times."
	},
	[ordered]@{
		id = "per-file-marker-world"
		status = if ($markerWorldFailures.Count -eq 0) { "pass" } else { "fail" }
		missing = @()
		failHits = $markerWorldFailures
		note = "Each file's latest startup window must contain the terrain-specific WASPRELEASE marker and matching MISSINIT worldName."
	},
	[ordered]@{
		id = "per-role-identity"
		status = if ($roleIdentityFailures.Count -eq 0) { "pass" } else { "fail" }
		missing = @()
		failHits = $roleIdentityFailures
		note = "Server files must report isServer=true/isDedicated=true in MISSINIT; HC and client role files must not."
	},
	[ordered]@{
		id = "per-role-proof"
		status = if ($roleProofFailures.Count -eq 0) { "pass" } else { "fail" }
		missing = @()
		failHits = $roleProofFailures
		note = "HC files must contain HC-local startup proof, player-client files must contain client-local startup proof, and copied roles must match private ledger roleProof/joinPhase metadata."
	},
	[ordered]@{
		id = "per-terrain-freshness-cutoffs"
		status = if ($freshnessMissing.Count -eq 0 -and $freshnessFailures.Count -eq 0) { "pass" } elseif ($freshnessFailures.Count -gt 0) { "fail" } else { "missing" }
		missing = @($freshnessMissing | ForEach-Object { "{0} start time" -f $_ })
		failHits = $freshnessFailures
		note = "Use -RunLedgerPath or explicit terrain start times; copied RPT LastWriteTime must be after launch, while source RPT freshness is enforced by the runtime run ledger."
	}
)

$overallPass = (@($gates | Where-Object { $_.status -ne "pass" }).Count -eq 0)
$result = [ordered]@{
	schema = "a2waspwarfare-runtime-rpt-packet-v1"
	generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
	rptRoot = "<rpt-root>"
	rptRootHash = Get-SafeTextHash $rootPath
	expectedCandidate = $ExpectedCandidate
	expectedGit = $ExpectedGit
	expectedArchiveSha256 = $ExpectedArchiveSha256
	expectedMarkers = [ordered]@{
		chernarus = $expectedMarkers.chernarus
		takistan = $expectedMarkers.takistan
	}
	startTimes = [ordered]@{
		chernarus = if ($null -eq $startTimes.chernarus) { "" } else { $startTimes.chernarus.ToString("yyyy-MM-ddTHH:mm:sszzz") }
		takistan = if ($null -eq $startTimes.takistan) { "" } else { $startTimes.takistan.ToString("yyyy-MM-ddTHH:mm:sszzz") }
	}
	runLedger = [ordered]@{
		path = $ledgerResult.path
		status = $ledgerResult.status
		records = $ledgerResult.records
	}
	files = $fileResults.ToArray()
	gates = $gates
	overall = if ($overallPass) { "pass" } else { "missing_or_failed" }
	privacy = "No raw RPT lines, absolute copied paths, original source RPT paths, or raw command lines are emitted; packet paths are RPT-root-relative labels with short path hashes."
}

if ($Json) {
	$result | ConvertTo-Json -Depth 12
} else {
	Write-Host "WASP runtime RPT packet matrix check"
	Write-Host "Root: <rpt-root> (pathHash=$(Get-SafeTextHash $rootPath))"
	Write-Host "Expected git: $ExpectedGit"
	if (![string]::IsNullOrWhiteSpace($ExpectedArchiveSha256)) { Write-Host "Expected archive SHA256: $ExpectedArchiveSha256" }
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
