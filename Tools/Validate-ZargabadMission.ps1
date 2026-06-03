param(
	[string]$MissionPath = "Missions_Vanilla/[31-2hc]warfarev2_073v48co.zargabad",
	[string]$SourceMissionPath = "Missions/[55-2hc]warfarev2_073v48co.chernarus"
)

$ErrorActionPreference = "Stop"

function Resolve-RepoPath {
	param([string]$Path)
	$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
	return Join-Path $root $Path
}

function Assert-Equal {
	param([string]$Name, $Actual, $Expected)
	if ($Actual -ne $Expected) {
		throw "$Name expected [$Expected], got [$Actual]"
	}
	Write-Host "ok - $Name = $Actual"
}

function Assert-True {
	param([string]$Name, [bool]$Condition)
	if (-not $Condition) {
		throw "$Name failed"
	}
	Write-Host "ok - $Name"
}

function Get-NonEmptyLineCount {
	param([string]$Path)
	return @((Get-Content -LiteralPath $Path) | Where-Object { $_.Trim().Length -gt 0 }).Count
}

$missionFullPath = Resolve-RepoPath $MissionPath
$sourceMissionFullPath = Resolve-RepoPath $SourceMissionPath
$sqmPath = Join-Path $missionFullPath "mission.sqm"

Assert-True "mission.sqm exists" (Test-Path -LiteralPath $sqmPath)

$objects = @()
$current = $null
foreach ($line in Get-Content -LiteralPath $sqmPath) {
	if ($line -match '^\s*position\[\]=\{([-0-9.]+),([-0-9.]+),([-0-9.]+)\};') {
		$current = [ordered]@{
			X = [double]$Matches[1]
			Z = [double]$Matches[2]
			Y = [double]$Matches[3]
			Id = $null
			Vehicle = $null
			Text = ""
			Init = ""
			Sync = @()
		}
		continue
	}

	if ($null -eq $current) { continue }

	if ($line -match '^\s*id=(\d+);') { $current.Id = [int]$Matches[1] }
	if ($line -match '^\s*vehicle="([^"]+)";') { $current.Vehicle = $Matches[1] }
	if ($line -match '^\s*text="([^"]*)";') { $current.Text = $Matches[1] }
	if ($line -match '^\s*init="(.*)";') { $current.Init = $Matches[1] }
	if ($line -match '^\s*synchronizations\[\]=\{([^}]*)\};') {
		$current.Sync = @($Matches[1] -split "," | Where-Object { $_.Trim().Length -gt 0 } | ForEach-Object { [int]$_.Trim() })
	}
	if ($line -match '^\s*\};\s*$' -and $null -ne $current.Id -and $null -ne $current.Vehicle) {
		$objects += [pscustomobject]$current
		$current = $null
	}
}

$ids = @($objects | ForEach-Object { $_.Id })
$duplicateIds = @($ids | Group-Object | Where-Object { $_.Count -gt 1 })
Assert-Equal "duplicate mission object ids" $duplicateIds.Count 0

$idSet = @{}
$ids | ForEach-Object { $idSet[$_] = $true }
$missingSyncIds = @()
foreach ($object in $objects) {
	foreach ($syncId in $object.Sync) {
		if (-not $idSet.ContainsKey($syncId)) {
			$missingSyncIds += [pscustomobject]@{ SourceId = $object.Id; MissingSyncId = $syncId }
		}
	}
}
Assert-Equal "missing synchronization target ids" $missingSyncIds.Count 0

$towns = @($objects | Where-Object { $_.Vehicle -eq "LocationLogicDepot" })
$camps = @($objects | Where-Object { $_.Vehicle -eq "LocationLogicCamp" })
$airports = @($objects | Where-Object { $_.Vehicle -eq "LocationLogicAirport" })
$starts = @($objects | Where-Object { $_.Vehicle -eq "LocationLogicStart" })
$defenses = @($objects | Where-Object { $_.Vehicle -eq "Logic" -and $_.Init -like "*wfbe_defense_kind*" })

Assert-Equal "town count" $towns.Count 13
Assert-Equal "camp count" $camps.Count 19
Assert-Equal "airport count" $airports.Count 1
Assert-Equal "start logic count" $starts.Count 9
Assert-Equal "town defense logic count" $defenses.Count 33

$logicObjects = @($towns + $camps + $airports + $starts + $defenses)
$outOfBounds = @($logicObjects | Where-Object { $_.X -lt 0 -or $_.X -gt 6000 -or $_.Y -lt 0 -or $_.Y -gt 6000 })
Assert-Equal "out-of-6000 Zargabad logic positions" $outOfBounds.Count 0

$parsedTowns = @()
foreach ($town in $towns) {
	$match = [regex]::Match($town.Init, '\[this,""(?<name>[^""]+)"",.*?,(?<start>\d+),(?<max>\d+),(?<range>\d+),')
	if (-not $match.Success) {
		throw "Could not parse town init for id [$($town.Id)] text [$($town.Text)]"
	}
	$campLinks = @($camps | Where-Object { $_.Sync -contains $town.Id })
	$defenseLinks = @($defenses | Where-Object { $_.Sync -contains $town.Id })
	$parsedTowns += [pscustomobject]@{
		Id = $town.Id
		Name = $match.Groups["name"].Value
		StartSV = [int]$match.Groups["start"].Value
		MaxSV = [int]$match.Groups["max"].Value
		Range = [int]$match.Groups["range"].Value
		Camps = $campLinks.Count
		Defenses = $defenseLinks.Count
		X = $town.X
		Y = $town.Y
	}
}

Assert-Equal "town start SV total" (@($parsedTowns | Measure-Object -Property StartSV -Sum).Sum) 185
Assert-Equal "town max SV total" (@($parsedTowns | Measure-Object -Property MaxSV -Sum).Sum) 648
Assert-Equal "towns without camps" @($parsedTowns | Where-Object { $_.Camps -lt 1 }).Count 0
Assert-Equal "towns without defenses" @($parsedTowns | Where-Object { $_.Defenses -lt 1 }).Count 0
Assert-True "city center is highest max SV" (($parsedTowns | Sort-Object MaxSV -Descending | Select-Object -First 1).Name -eq "Zargabad City Center")
Assert-True "airfield is second highest max SV" (($parsedTowns | Sort-Object MaxSV -Descending | Select-Object -Skip 1 -First 1).Name -eq "Zargabad Airfield")

$boundarySource = Get-Content -Raw -LiteralPath (Join-Path $sourceMissionFullPath "Common/Init/Init_Boundaries.sqf")
Assert-True "source declares 6000m Zargabad boundary" ($boundarySource -match "case 'zargabad': \{_boundariesXY = 6000\};")

foreach ($path in @($sourceMissionFullPath, $missionFullPath)) {
	$initZargabad = Get-Content -Raw -LiteralPath (Join-Path $path "Server/Init/Init_Zargabad.sqf")
	Assert-True "$path launches Zargabad edge guard" ($initZargabad -like '*Zargabad_EdgeGuard.sqf*')
	Assert-True "$path launches Zargabad black market" ($initZargabad -like '*Zargabad_BlackMarket.sqf*')
	Assert-True "$path launches Zargabad runtime audit" ($initZargabad -like '*Zargabad_RuntimeAudit.sqf*')
	Assert-True "$path builds WDDM-compatible central wall" ($initZargabad -like '*WFBE_ZARGABAD_CENTRAL_WALL*' -and $initZargabad -like '*CreateDefenseTemplate*')
	Assert-True "$path central wall has pass-through gaps" ($initZargabad -match '\[-1180,-1018\][\s\S]*\[-790,-628\][\s\S]*\[-420,-258\][\s\S]*\[30,192\][\s\S]*\[470,632\][\s\S]*\[870,1032\]')
	Assert-True "$path central wall is centered and diagonal" ($initZargabad -match '\[3425,3375,0\][\s\S]*setDir 316;')
	$constants = Get-Content -Raw -LiteralPath (Join-Path $path "Common/Init/Init_CommonConstants.sqf")
	Assert-True "$path edge guard constants are present" ($constants -match "WFBE_C_ZARGABAD_EDGE_GUARD_BAND = 120;[\s\S]*WFBE_C_ZARGABAD_EDGE_GUARD_SAFE_RANGE = 325;[\s\S]*WFBE_C_ZARGABAD_EDGE_GUARD_TIMEOUT = 45;")
	$commonInit = Get-Content -Raw -LiteralPath (Join-Path $path "Common/Init/Init_Common.sqf")
	Assert-True "$path declares Zargabad price multipliers" ($commonInit -match 'WFBE_ZARGABAD_PRICE_MULTIPLIERS[\s\S]*\["BARRACKS",0\.9\][\s\S]*\["LIGHT",1\.1\][\s\S]*\["HEAVY",1\.2\][\s\S]*\["AIRCRAFT",1\.35\][\s\S]*\["AIRPORT",1\.5\][\s\S]*\["DEPOT",0\.95\]')
}

$sourceBlackMarket = Join-Path $sourceMissionFullPath "Server/Module/Zargabad/Zargabad_BlackMarket.sqf"
$generatedBlackMarket = Join-Path $missionFullPath "Server/Module/Zargabad/Zargabad_BlackMarket.sqf"
$sourceEdgeGuard = Join-Path $sourceMissionFullPath "Server/Module/Zargabad/Zargabad_EdgeGuard.sqf"
$generatedEdgeGuard = Join-Path $missionFullPath "Server/Module/Zargabad/Zargabad_EdgeGuard.sqf"
$sourceRuntimeAudit = Join-Path $sourceMissionFullPath "Server/Module/Zargabad/Zargabad_RuntimeAudit.sqf"
$generatedRuntimeAudit = Join-Path $missionFullPath "Server/Module/Zargabad/Zargabad_RuntimeAudit.sqf"
$runtimeReportTool = Join-Path (Resolve-RepoPath "Tools") "New-ZargabadRuntimeReport.ps1"

Assert-True "source mystery feature under 100 non-empty LOC" ((Get-NonEmptyLineCount $sourceBlackMarket) -le 100)
Assert-True "generated mystery feature under 100 non-empty LOC" ((Get-NonEmptyLineCount $generatedBlackMarket) -le 100)
Assert-True "source edge guard under 100 non-empty LOC" ((Get-NonEmptyLineCount $sourceEdgeGuard) -le 100)
Assert-True "generated edge guard under 100 non-empty LOC" ((Get-NonEmptyLineCount $generatedEdgeGuard) -le 100)
Assert-True "source runtime audit under 100 non-empty LOC" ((Get-NonEmptyLineCount $sourceRuntimeAudit) -le 100)
Assert-True "generated runtime audit under 100 non-empty LOC" ((Get-NonEmptyLineCount $generatedRuntimeAudit) -le 100)

$runtimeAuditSource = Get-Content -Raw -LiteralPath $sourceRuntimeAudit
Assert-True "runtime audit logs counts and SV totals" ($runtimeAuditSource -match 'towns \[%1\] camps \[%2\] airports \[%3\] defenses \[%4\] startSV \[%5\] maxSV \[%6\]')
Assert-True "runtime audit logs Zargabad economy and range constants" ($runtimeAuditSource -match 'supplyCap \[%1\] teamSupplyCap \[%2\] fastTravelMax \[%3\] respawnCampRange \[%4\].*edgeGuard \[%10,%11,%12\]')
Assert-True "runtime audit logs Zargabad factory restrictions" ($runtimeAuditSource -match 'factoryCounts WEST L/H/A/AP')
Assert-True "runtime audit logs Zargabad price multipliers and samples" ($runtimeAuditSource -match 'priceMultipliers %1 priceSamples %2')

Assert-True "runtime report tool exists" (Test-Path -LiteralPath $runtimeReportTool)
$runtimeReportSource = Get-Content -Raw -LiteralPath $runtimeReportTool
Assert-True "runtime report tool wraps runtime validator" ($runtimeReportSource -match 'Validate-ZargabadRuntimeEvidence\.ps1')
Assert-True "runtime report tool emits Claude notes" ($runtimeReportSource -match '## Claude Notes')
Assert-True "runtime report tool emits validator output" ($runtimeReportSource -match '## Validator Output')

$takistanZargabadModule = Resolve-RepoPath "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Module/Zargabad"
Assert-True "Takistan has no generated Zargabad module spillover" (-not (Test-Path -LiteralPath $takistanZargabadModule))

Write-Host ""
Write-Host "Zargabad town/SV summary:"
$parsedTowns | Sort-Object MaxSV -Descending | Format-Table Name, StartSV, MaxSV, Range, Camps, Defenses, X, Y -AutoSize
