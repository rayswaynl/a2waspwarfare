[CmdletBinding()]
param(
	[switch]$KeepTemp
)

$ErrorActionPreference = "Stop"

$here = $PSScriptRoot
$builder = Join-Path $here "New-WaspRuntimeRptPacket.ps1"
$validator = Join-Path $here "Test-WaspRuntimeRptPacket.ps1"
$candidate = "release-command-center-20260630"
$expectedGit = "selftest34"
$expectedArchiveSha256 = "111122223333444455556666777788889999AAAABBBBCCCCDDDDEEEEFFFF0000"
$terrains = @("chernarus", "takistan")
$roles = @("server", "HC1", "HC2", "start-client", "late-JIP")

function Assert-True {
	param([bool]$Condition, [string]$Message)
	if (!$Condition) { throw $Message }
}

function Assert-Equal {
	param([string]$Actual, [string]$Expected, [string]$Message)
	if ($Actual -ne $Expected) {
		throw ("{0} Expected '{1}', got '{2}'." -f $Message, $Expected, $Actual)
	}
}

function Get-Gate {
	param($Validation, [string]$Id)
	$matches = @($Validation.gates | Where-Object { [string]$_.id -eq $Id })
	if ($matches.Count -eq 0) { throw "Gate '$Id' not found in validation result." }
	return $matches[0]
}

function ConvertFrom-JsonOutput {
	param([object[]]$Output)
	return (($Output | Out-String) | ConvertFrom-Json)
}

function Write-TestFile {
	param([string]$Path, [string[]]$Lines)
	$dir = Split-Path -Parent $Path
	[void](New-Item -ItemType Directory -Path $dir -Force)
	$Lines | Set-Content -LiteralPath $Path -Encoding UTF8
}

function New-RptLines {
	param(
		[string]$Terrain,
		[string]$Role,
		[string]$Variant
	)
	$isServer = "false"
	$isDedicated = "false"
	if ($Role -eq "server") {
		$isServer = "true"
		$isDedicated = "true"
	}
	$marker = "WASPRELEASE|v1|candidate=$candidate|git=$expectedGit|terrain=$Terrain"
	$unique = "$Terrain-$Role-$Variant"
	if ($Variant -eq "duplicate-content" -and $Terrain -eq "chernarus" -and ($Role -eq "HC1" -or $Role -eq "HC2")) {
		$unique = "chernarus-duplicated-hc-content"
	}
	$lines = New-Object System.Collections.Generic.List[string]
	[void]$lines.Add("Synthetic prelude for $unique")
	[void]$lines.Add("## Mission Name: synthetic-$Terrain")
	[void]$lines.Add($marker)
	[void]$lines.Add("MISSINIT: missionName=synthetic-$Terrain, worldName=$Terrain, isMultiplayer=true, isServer=$isServer, isDedicated=$isDedicated]")
	if ($Role -eq "HC1" -or $Role -eq "HC2") {
		[void]$lines.Add("initJIPCompatible.sqf: Detected an headless client.")
		[void]$lines.Add("Init_HC.sqf: Running the headless client initialization.")
	} elseif ($Role -eq "start-client" -or $Role -eq "late-JIP") {
		if ($Variant -eq "wrong-client-proof" -and $Terrain -eq "takistan" -and $Role -eq "late-JIP") {
			[void]$lines.Add("Init_HC.sqf: Running the headless client initialization.")
		} else {
			[void]$lines.Add("initJIPCompatible.sqf: Executing the Client Initialization.")
			[void]$lines.Add("Init_Client.sqf: Client initialization begins")
		}
	}
	[void]$lines.Add("UNIQUE_RUNTIME_LINE|$unique")
	return $lines.ToArray()
}

function New-SourceMapFixture {
	param(
		[string]$Root,
		[string]$Variant
	)
	$sourceRoot = Join-Path $Root "source-rpts"
	$terrainStart = (Get-Date).AddMinutes(-10).ToString("yyyy-MM-ddTHH:mm:sszzz")
	$records = New-Object System.Collections.Generic.List[object]
	foreach ($terrain in $terrains) {
		foreach ($role in $roles) {
			$sourcePath = Join-Path (Join-Path $sourceRoot $terrain) ("{0}.rpt" -f $role)
			Write-TestFile -Path $sourcePath -Lines (New-RptLines -Terrain $terrain -Role $role -Variant $Variant)
			(Get-Item -LiteralPath $sourcePath).LastWriteTime = (Get-Date).AddMinutes(-1)
			$joinPhase = ""
			if ($role -eq "start-client" -or $role -eq "late-JIP") { $joinPhase = $role }
			[void]$records.Add([ordered]@{
				terrain = $terrain
				role = $role
				roleProof = $role
				joinPhase = $joinPhase
				terrainStartTime = $terrainStart
				pid = if ($terrain -eq "chernarus") { 3000 + $records.Count } else { 4000 + $records.Count }
				commandLine = "arma2oa-server.exe -synthetic $terrain $role"
				profilePath = "<synthetic-profile>"
				sourceRptPath = $sourcePath
			})
		}
	}
	$sourceMap = [ordered]@{
		schema = "a2waspwarfare-runtime-rpt-source-map-v1"
		release = [ordered]@{
			candidate = $candidate
			git = $expectedGit
			archiveSha256 = $expectedArchiveSha256
		}
		records = $records.ToArray()
	}
	$mapPath = Join-Path $Root "runtime-rpt-source-map.json"
	$sourceMap | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $mapPath -Encoding UTF8
	return $mapPath
}

function Invoke-BuilderFixture {
	param(
		[string]$MapPath,
		[string]$OutDirectory,
		[switch]$NoFail
	)
	if ($NoFail) {
		return ConvertFrom-JsonOutput (& $builder -SourceMapPath $MapPath -OutDirectory $OutDirectory -ExpectedCandidate $candidate -ExpectedGit $expectedGit -ExpectedArchiveSha256 $expectedArchiveSha256 -Validate -RequireSourceRptExists -Force -Json -NoFail)
	}
	return ConvertFrom-JsonOutput (& $builder -SourceMapPath $MapPath -OutDirectory $OutDirectory -ExpectedCandidate $candidate -ExpectedGit $expectedGit -ExpectedArchiveSha256 $expectedArchiveSha256 -Validate -RequireSourceRptExists -Force -Json)
}

function Invoke-ValidatorFixture {
	param(
		[string]$PacketRoot,
		[switch]$NoFail
	)
	$ledgerPath = Join-Path $PacketRoot "release-run-ledger.json"
	if ($NoFail) {
		return ConvertFrom-JsonOutput (& $validator -RptRoot $PacketRoot -ExpectedCandidate $candidate -ExpectedGit $expectedGit -ExpectedArchiveSha256 $expectedArchiveSha256 -RunLedgerPath $ledgerPath -RequireSourceRptExists -Json -NoFail)
	}
	return ConvertFrom-JsonOutput (& $validator -RptRoot $PacketRoot -ExpectedCandidate $candidate -ExpectedGit $expectedGit -ExpectedArchiveSha256 $expectedArchiveSha256 -RunLedgerPath $ledgerPath -RequireSourceRptExists -Json)
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("wasp-runtime-packet-selftest-" + [guid]::NewGuid().ToString("N"))
try {
	[void](New-Item -ItemType Directory -Path $tempRoot -Force)

	$happyRoot = Join-Path $tempRoot "happy"
	$happyMap = New-SourceMapFixture -Root $happyRoot -Variant "happy"
	$happyPacket = Join-Path $happyRoot "packet"
	$happyManifest = Invoke-BuilderFixture -MapPath $happyMap -OutDirectory $happyPacket
	Assert-Equal ([string]$happyManifest.validation.overall) "pass" "Happy-path builder validation failed."
	$happyValidation = Invoke-ValidatorFixture -PacketRoot $happyPacket
	Assert-Equal ([string]$happyValidation.overall) "pass" "Happy-path packet validation failed."

	$duplicateRoot = Join-Path $tempRoot "duplicate"
	$duplicateMap = New-SourceMapFixture -Root $duplicateRoot -Variant "duplicate-content"
	$duplicatePacket = Join-Path $duplicateRoot "packet"
	$duplicateManifest = Invoke-BuilderFixture -MapPath $duplicateMap -OutDirectory $duplicatePacket -NoFail
	Assert-Equal ([string]$duplicateManifest.validation.overall) "missing_or_failed" "Duplicate-content fixture should fail validation."
	Assert-Equal ([string](Get-Gate -Validation $duplicateManifest.validation -Id "no-duplicate-rpt-content").status) "fail" "Duplicate-content gate did not fail."

	$wrongRoleRoot = Join-Path $tempRoot "wrong-role"
	$wrongRoleMap = New-SourceMapFixture -Root $wrongRoleRoot -Variant "wrong-client-proof"
	$wrongRolePacket = Join-Path $wrongRoleRoot "packet"
	$wrongRoleManifest = Invoke-BuilderFixture -MapPath $wrongRoleMap -OutDirectory $wrongRolePacket -NoFail
	Assert-Equal ([string]$wrongRoleManifest.validation.overall) "missing_or_failed" "Wrong-role fixture should fail validation."
	Assert-Equal ([string](Get-Gate -Validation $wrongRoleManifest.validation -Id "per-role-proof").status) "fail" "Per-role proof gate did not fail."

	$ledgerObject = Get-Content -Raw -LiteralPath (Join-Path $happyPacket "release-run-ledger.json") | ConvertFrom-Json
	$ledgerObject.release.archiveSha256 = ""
	$ledgerObject | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $happyPacket "release-run-ledger.json") -Encoding UTF8
	$archiveValidation = Invoke-ValidatorFixture -PacketRoot $happyPacket -NoFail
	Assert-Equal ([string]$archiveValidation.overall) "missing_or_failed" "Missing archive SHA fixture should fail validation."
	Assert-Equal ([string](Get-Gate -Validation $archiveValidation -Id "runtime-run-ledger").status) "fail" "Runtime run-ledger gate did not fail when archive SHA was missing."

	Write-Host "WASP runtime RPT packet self-test PASS."
} finally {
	if ($KeepTemp) {
		Write-Host "Kept temp fixture root: $tempRoot"
	} elseif (Test-Path -LiteralPath $tempRoot) {
		Remove-Item -LiteralPath $tempRoot -Recurse -Force
	}
}
