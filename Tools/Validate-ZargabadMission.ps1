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

function Get-FlatDistance {
	param($A, $B)
	return [math]::Sqrt([math]::Pow($A.X - $B.X, 2) + [math]::Pow($A.Y - $B.Y, 2))
}

function Get-EdgeDistance {
	param($LogicObject, [double]$Boundary)
	$x = [double]$LogicObject.X
	$y = [double]$LogicObject.Y
	return (@($x, $y, ($Boundary - $x), ($Boundary - $y)) | Measure-Object -Minimum).Minimum
}

function Test-ContainsAll {
	param([string]$Content, [string[]]$Needles)
	foreach ($needle in $Needles) {
		if (-not $Content.Contains($needle)) { return $false }
	}
	return $true
}

function Get-ZargabadOverrideUnits {
	param([string]$Content, [string]$Factory)
	$pattern = 'if\s*\(IS_zargabad_lowpop_map\)\s*then\s*\{\s*_u\s*=\s*\[([^\]]*)\];\s*\};\s*missionNamespace\s+setVariable\s+\[Format\s+\["WFBE_%1' + [regex]::Escape($Factory) + 'UNITS"'
	$match = [regex]::Match($Content, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
	if (-not $match.Success) { return @() }
	return @([regex]::Matches($match.Groups[1].Value, "['""]([^'""]+)['""]") | ForEach-Object { $_.Groups[1].Value })
}

function Test-SequenceEqual {
	param([string[]]$Actual, [string[]]$Expected)
	if ($Actual.Count -ne $Expected.Count) { return $false }
	for ($i = 0; $i -lt $Expected.Count; $i++) {
		if ($Actual[$i] -ne $Expected[$i]) { return $false }
	}
	return $true
}

function Assert-NearPosition {
	param([string]$Name, $Object, [double]$X, [double]$Y, [double]$Tolerance)
	$distance = [math]::Sqrt([math]::Pow($Object.X - $X, 2) + [math]::Pow($Object.Y - $Y, 2))
	Assert-True $Name ($distance -le $Tolerance)
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
			Azimut = $null
			Text = ""
			Init = ""
			Sync = @()
		}
		continue
	}

	if ($null -eq $current) { continue }

	if ($line -match '^\s*id=(\d+);') { $current.Id = [int]$Matches[1] }
	if ($line -match '^\s*azimut=([-0-9.]+);') { $current.Azimut = [double]$Matches[1] }
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
$safeZoneObjects = @($towns + $camps + $airports + $starts)
$killRimObjects = @($safeZoneObjects | Where-Object { (Get-EdgeDistance -LogicObject $_ -Boundary 6000) -lt 120 })
$edgeSafeObjects = @($safeZoneObjects | Where-Object { (Get-EdgeDistance -LogicObject $_ -Boundary 6000) -le 325 })
Assert-Equal "objective safe-zone logics inside edge guard kill rim" $killRimObjects.Count 0
Assert-Equal "bounded edge-safe objective/start logic count" $edgeSafeObjects.Count 7
Assert-Equal "edge-safe logics limited to north/east flank" @($edgeSafeObjects | Where-Object { $_.Y -lt 5680 -and $_.X -lt 5770 }).Count 0

$campTownLinkCounts = @($camps | ForEach-Object {
	$camp = $_
	[pscustomobject]@{ Id = $camp.Id; TownLinks = @($towns | Where-Object { $camp.Sync -contains $_.Id }).Count }
})
Assert-Equal "camps linked to exactly one town" @($campTownLinkCounts | Where-Object { $_.TownLinks -ne 1 }).Count 0

$parsedTowns = @()
foreach ($town in $towns) {
	$match = [regex]::Match($town.Init, '\[this,""(?<name>[^""]+)"",.*?,(?<start>\d+),(?<max>\d+),(?<range>\d+),')
	if (-not $match.Success) {
		throw "Could not parse town init for id [$($town.Id)] text [$($town.Text)]"
	}
	$campLinks = @($camps | Where-Object { $_.Sync -contains $town.Id })
	$defenseLinks = @($defenses | Where-Object { $_.Sync -contains $town.Id })
	$campDistances = @($campLinks | ForEach-Object {
		[math]::Round([math]::Sqrt([math]::Pow($_.X - $town.X, 2) + [math]::Pow($_.Y - $town.Y, 2)), 1)
	})
	$defenseDistances = @($defenseLinks | ForEach-Object {
		[math]::Round([math]::Sqrt([math]::Pow($_.X - $town.X, 2) + [math]::Pow($_.Y - $town.Y, 2)), 1)
	})
	$parsedTowns += [pscustomobject]@{
		Id = $town.Id
		Name = $match.Groups["name"].Value
		StartSV = [int]$match.Groups["start"].Value
		MaxSV = [int]$match.Groups["max"].Value
		Range = [int]$match.Groups["range"].Value
		Camps = $campLinks.Count
		Defenses = $defenseLinks.Count
		CampDistances = $campDistances
		MinCampDistance = if ($campDistances.Count -gt 0) { ($campDistances | Measure-Object -Minimum).Minimum } else { -1 }
		MaxCampDistance = if ($campDistances.Count -gt 0) { ($campDistances | Measure-Object -Maximum).Maximum } else { -1 }
		DefenseDistances = $defenseDistances
		MinDefenseDistance = if ($defenseDistances.Count -gt 0) { ($defenseDistances | Measure-Object -Minimum).Minimum } else { -1 }
		MaxDefenseDistance = if ($defenseDistances.Count -gt 0) { ($defenseDistances | Measure-Object -Maximum).Maximum } else { -1 }
		X = $town.X
		Y = $town.Y
	}
}

Assert-Equal "town start SV total" (@($parsedTowns | Measure-Object -Property StartSV -Sum).Sum) 185
Assert-Equal "town max SV total" (@($parsedTowns | Measure-Object -Property MaxSV -Sum).Sum) 648
Assert-Equal "towns without camps" @($parsedTowns | Where-Object { $_.Camps -lt 1 }).Count 0
Assert-Equal "town-linked camp count" (@($parsedTowns | Measure-Object -Property Camps -Sum).Sum) 19
Assert-Equal "camps outside 90m-225m population flow band" @($parsedTowns | Where-Object { $_.MinCampDistance -lt 90 -or $_.MaxCampDistance -gt 225 }).Count 0
Assert-Equal "towns without defenses" @($parsedTowns | Where-Object { $_.Defenses -lt 1 }).Count 0
Assert-True "city center is highest max SV" (($parsedTowns | Sort-Object MaxSV -Descending | Select-Object -First 1).Name -eq "Zargabad City Center")
Assert-True "airfield is second highest max SV" (($parsedTowns | Sort-Object MaxSV -Descending | Select-Object -Skip 1 -First 1).Name -eq "Zargabad Airfield")
foreach ($townName in @("Zargabad City Center", "Zargabad Airfield", "Zargabad North District", "Zargabad South District", "Northwest Base", "Rahim Villa")) {
	Assert-True "$townName has two camp approaches" (($parsedTowns | Where-Object { $_.Name -eq $townName }).Camps -ge 2)
}
Assert-Equal "defenses outside 325m town approach band" @($parsedTowns | Where-Object { $_.MaxDefenseDistance -gt 325 }).Count 0
Assert-Equal "defenses piled inside 90m town core" @($parsedTowns | Where-Object { $_.MinDefenseDistance -lt 90 }).Count 0
Assert-True "city center has beefy defense coverage" (($parsedTowns | Where-Object { $_.Name -eq "Zargabad City Center" }).Defenses -ge 5)
Assert-True "airfield has beefy defense coverage" (($parsedTowns | Where-Object { $_.Name -eq "Zargabad Airfield" }).Defenses -ge 5)
foreach ($townName in @("Zargabad North District", "Zargabad South District", "Northwest Base", "Rahim Villa")) {
	Assert-True "$townName has layered defense coverage" (($parsedTowns | Where-Object { $_.Name -eq $townName }).Defenses -ge 3)
}

$westStart = @($starts | Where-Object { $_.Init -match 'wfbe_default"", west' })
$eastStart = @($starts | Where-Object { $_.Init -match 'wfbe_default"", east' })
$resistanceStart = @($starts | Where-Object { $_.Init -match 'wfbe_default"", resistance' })
Assert-Equal "default WEST start count" $westStart.Count 1
Assert-Equal "default EAST start count" $eastStart.Count 1
Assert-Equal "default Resistance start count" $resistanceStart.Count 1
$westStart = $westStart[0]
$eastStart = $eastStart[0]
$resistanceStart = $resistanceStart[0]
Assert-NearPosition "default WEST start remains southwest" $westStart 1500 1550 5
Assert-NearPosition "default EAST start remains northeast" $eastStart 5350 5200 5
Assert-NearPosition "default Resistance start remains central" $resistanceStart 4100 3950 5
Assert-True "WEST start points toward center" ([math]::Abs($westStart.Azimut - 45) -le 0.1)
Assert-True "EAST start points toward center" ([math]::Abs($eastStart.Azimut - 225) -le 0.1)
Assert-True "WEST/EAST starts are separated for spawn safety" ((Get-FlatDistance $westStart $eastStart) -ge 5000)

$boundarySource = Get-Content -Raw -LiteralPath (Join-Path $sourceMissionFullPath "Common/Init/Init_Boundaries.sqf")
Assert-True "source declares 6000m Zargabad boundary" ($boundarySource -match "case 'zargabad': \{_boundariesXY = 6000\};")

foreach ($path in @($sourceMissionFullPath, $missionFullPath)) {
	$initZargabad = Get-Content -Raw -LiteralPath (Join-Path $path "Server/Init/Init_Zargabad.sqf")
	Assert-True "$path launches Zargabad edge guard" ($initZargabad -like '*Zargabad_EdgeGuard.sqf*')
	Assert-True "$path launches Zargabad black market" ($initZargabad -like '*Zargabad_BlackMarket.sqf*')
	Assert-True "$path launches Zargabad runtime audit" ($initZargabad -like '*Zargabad_RuntimeAudit.sqf*')
	Assert-True "$path builds WDDM-compatible central wall" ($initZargabad -like '*WFBE_ZARGABAD_CENTRAL_WALL*' -and $initZargabad -like '*CreateDefenseTemplate*')
	Assert-True "$path orients Zargabad town defense logics" ($initZargabad.Contains('WFBE_ZARGABAD_TOWN_DEFENSE_ORIENTED_COUNT') -and $initZargabad.Contains('atan2') -and $initZargabad.Contains('_synced setDir _dir;') -and $initZargabad.Contains('Oriented [%1] town defense logics'))
	Assert-True "$path central wall has pass-through gaps" ($initZargabad -match '\[-1180,-1018\][\s\S]*\[-790,-628\][\s\S]*\[-420,-258\][\s\S]*\[30,192\][\s\S]*\[470,632\][\s\S]*\[870,1032\]')
	Assert-True "$path central wall is centered and diagonal" ($initZargabad -match '\[3425,3375,0\][\s\S]*setDir 316;')
	Assert-True "$path records Zargabad base audit counts" ($initZargabad -match 'WFBE_ZARGABAD_BASE_WALL_COUNT' -and $initZargabad -match 'WFBE_ZARGABAD_BASE_STATIC_COUNT_%1' -and $initZargabad -match 'WFBE_ZARGABAD_BASE_POS_%1')
	Assert-True "$path records Zargabad base static templates" ($initZargabad -match 'WFBE_ZARGABAD_BASE_STATIC_TEMPLATE_WEST' -and $initZargabad -match 'M2StaticMG_US_EP1' -and $initZargabad -match 'TOW_TriPod_US_EP1' -and $initZargabad -match 'Stinger_Pod_US_EP1' -and $initZargabad -match 'WFBE_ZARGABAD_BASE_STATIC_TEMPLATE_EAST' -and $initZargabad -match 'KORD_high_TK_EP1' -and $initZargabad -match 'Metis_TK_EP1' -and $initZargabad -match 'Igla_AA_pod_TK_EP1')
	$constants = Get-Content -Raw -LiteralPath (Join-Path $path "Common/Init/Init_CommonConstants.sqf")
	$economyRangeConstants = @(
		"WFBE_C_ARTILLERY_INTERVALS = [700, 650, 600, 550, 500, 450, 400];",
		"WFBE_C_ECONOMY_SUPPLY_MAX_TEAM_LIMIT = 30000;",
		"WFBE_C_GAMEPLAY_FAST_TRAVEL_RANGE_MAX = 1800;",
		"WFBE_C_PLAYERS_UAV_SPOTTING_RANGE = 800;",
		"WFBE_C_RESPAWN_CAMPS_RANGE = 400;",
		"WFBE_C_RESPAWN_RANGES = [150, 225, 325];",
		"WFBE_C_STRUCTURES_COMMANDCENTER_RANGE = 3200;",
		"WFBE_C_TOWNS_BUILD_PROTECTION_RANGE = 300;",
		"WFBE_C_TOWNS_DEFENSE_RANGE = 45;",
		"WFBE_C_TOWNS_MORTARS_RANGE_MAX = 500;",
		"WFBE_C_TOWNS_PATROL_RANGE = 350;",
		"WFBE_C_UNITS_PURCHASE_HANGAR_RANGE = 35;",
		"WFBE_C_UNITS_REPAIR_TRUCK_RANGE = 35;",
		"WFBE_C_UNITS_SALVAGER_SCAVENGE_RANGE = 45;",
		"WFBE_C_UNITS_SUPPORT_RANGE = 55;"
	)
	$aiCapConstants = @(
		"WFBE_C_AI_MAX = 8;",
		"WFBE_C_BASE_DEFENSE_MAX_AI = 56;",
		"WFBE_C_BASE_DEFENSE_MANNING_RANGE = 500;",
		"WFBE_C_BASE_PROTECTION_RANGE = 900;",
		"WFBE_C_PLAYERS_AI_MAX = 10;",
		"WFBE_C_PLAYERS_SKILL_SOLDIER_UNITS_MAX = 4;",
		"WFBE_C_UNITS_COUNTERMEASURE_CHOPPERS = 16;",
		"WFBE_C_UNITS_COUNTERMEASURE_PLANES = 24;"
	)
	Assert-True "$path applies Zargabad smaller-map economy and range constants" (Test-ContainsAll -Content $constants -Needles $economyRangeConstants)
	Assert-True "$path applies Zargabad smaller-map AI and base-defense caps" (Test-ContainsAll -Content $constants -Needles $aiCapConstants)
	Assert-True "$path edge guard constants are present" ($constants -match "WFBE_C_ZARGABAD_EDGE_GUARD_BAND = 120;[\s\S]*WFBE_C_ZARGABAD_EDGE_GUARD_SAFE_RANGE = 325;[\s\S]*WFBE_C_ZARGABAD_EDGE_GUARD_TIMEOUT = 45;")
	$commonInit = Get-Content -Raw -LiteralPath (Join-Path $path "Common/Init/Init_Common.sqf")
	Assert-True "$path declares Zargabad price multipliers" ($commonInit -match 'WFBE_ZARGABAD_PRICE_MULTIPLIERS[\s\S]*\["BARRACKS",0\.9\][\s\S]*\["LIGHT",1\.1\][\s\S]*\["HEAVY",1\.2\][\s\S]*\["AIRCRAFT",1\.35\][\s\S]*\["AIRPORT",1\.5\][\s\S]*\["DEPOT",0\.95\]')
	$westUnits = Get-Content -Raw -LiteralPath (Join-Path $path "Common/Config/Core_Units/Units_CO_US.sqf")
	$eastUnits = Get-Content -Raw -LiteralPath (Join-Path $path "Common/Config/Core_Units/Units_CO_RU.sqf")
	$westHeavy = Get-ZargabadOverrideUnits -Content $westUnits -Factory "HEAVY"
	$westAircraft = Get-ZargabadOverrideUnits -Content $westUnits -Factory "AIRCRAFT"
	$eastHeavy = Get-ZargabadOverrideUnits -Content $eastUnits -Factory "HEAVY"
	$eastAircraft = Get-ZargabadOverrideUnits -Content $eastUnits -Factory "AIRCRAFT"
	Assert-True "$path applies exact WEST Zargabad heavy list" (Test-SequenceEqual -Actual $westHeavy -Expected @("M2A2_EP1","M2A3_EP1","BAF_FV510_D"))
	Assert-True "$path applies exact EAST Zargabad heavy list" (Test-SequenceEqual -Actual $eastHeavy -Expected @("M113_TK_EP1","BMP2_TK_EP1","T34_TK_EP1","BMP3"))
	Assert-True "$path applies exact WEST Zargabad aircraft list" (Test-SequenceEqual -Actual $westAircraft -Expected @("MH6J_EP1","UH60M_EP1","UH60M_MEV_EP1","CH_47F_EP1","CH_47F_BAF","BAF_Merlin_HC3_D","AH6J_EP1"))
	Assert-True "$path applies exact EAST Zargabad aircraft list" (Test-SequenceEqual -Actual $eastAircraft -Expected @("UH1H_TK_EP1","Mi17_TK_EP1","Mi17_medevac_RU","An2_TK_EP1"))
	$forbiddenNormalFactoryUnits = @("M1A1","M1A1_US_DES_EP1","MLRS","MLRS_DES_EP1","M1A2_TUSK_MG","M1A2_US_TUSK_MG_EP1","M6_EP1","ZSU_INS","ZSU_TK_EP1","T55_TK_EP1","T72_RU","T72_TK_EP1","T90","2S6M_Tunguska","AW159_Lynx_BAF","Mi24_D_CZ_ACR","Mi24_D_TK_EP1","Mi24_P","Mi24_V","Ka52","Ka52Black","AH64D","AH64D_EP1","BAF_Apache_AH1_D","AH1Z","L39_TK_EP1","Su25_Ins","Su25_TK_EP1","Su39","Su34","A10","A10_US_EP1","AV8B","AV8B2","F35B","C130J_US_EP1")
	$normalFactoryUnits = @($westHeavy + $westAircraft + $eastHeavy + $eastAircraft)
	$forbiddenFound = @($normalFactoryUnits | Where-Object { $_ -in $forbiddenNormalFactoryUnits })
	Assert-Equal "$path forbidden heavy/attack normal-factory units" $forbiddenFound.Count 0
}

$sourceBlackMarket = Join-Path $sourceMissionFullPath "Server/Module/Zargabad/Zargabad_BlackMarket.sqf"
$generatedBlackMarket = Join-Path $missionFullPath "Server/Module/Zargabad/Zargabad_BlackMarket.sqf"
$sourceEdgeGuard = Join-Path $sourceMissionFullPath "Server/Module/Zargabad/Zargabad_EdgeGuard.sqf"
$generatedEdgeGuard = Join-Path $missionFullPath "Server/Module/Zargabad/Zargabad_EdgeGuard.sqf"
$sourceRuntimeAudit = Join-Path $sourceMissionFullPath "Server/Module/Zargabad/Zargabad_RuntimeAudit.sqf"
$generatedRuntimeAudit = Join-Path $missionFullPath "Server/Module/Zargabad/Zargabad_RuntimeAudit.sqf"
$runtimeReportTool = Join-Path (Resolve-RepoPath "Tools") "New-ZargabadRuntimeReport.ps1"
$claudeBriefTool = Join-Path (Resolve-RepoPath "Tools") "New-ZargabadClaudeBrief.ps1"

Assert-True "source mystery feature under 100 non-empty LOC" ((Get-NonEmptyLineCount $sourceBlackMarket) -le 100)
Assert-True "generated mystery feature under 100 non-empty LOC" ((Get-NonEmptyLineCount $generatedBlackMarket) -le 100)
$blackMarketSource = Get-Content -Raw -LiteralPath $sourceBlackMarket
Assert-True "mystery feature is airfield ownership gated" ($blackMarketSource -match 'Zargabad Airfield' -and $blackMarketSource -match 'sideID' -and $blackMarketSource -match 'WFBE_C_WEST_ID, WFBE_C_EAST_ID')
Assert-True "mystery feature reuses side para-ammo arrays" ($blackMarketSource -match 'WFBE_%1PARAAMMO')
Assert-True "mystery feature uses smoke and trash cleanup lifecycle" ($blackMarketSource -match 'SmokeShellYellow' -and $blackMarketSource -match 'wfbe_trashable", false' -and $blackMarketSource -match 'deleteVehicle _smoke' -and $blackMarketSource -match 'wfbe_trashable", true')
Assert-True "mystery feature logs cache spawn and cleanup evidence" ($blackMarketSource -match 'surfaced near' -and $blackMarketSource -match 'cleanup released')
Assert-True "mystery feature has five bounded cache positions" (Test-ContainsAll -Content $blackMarketSource -Needles @("[3930,3995,0]", "[4100,3825,0]", "[4235,4040,0]", "[4970,3890,0]", "[3310,3865,0]"))
Assert-True "source edge guard under 100 non-empty LOC" ((Get-NonEmptyLineCount $sourceEdgeGuard) -le 100)
Assert-True "generated edge guard under 100 non-empty LOC" ((Get-NonEmptyLineCount $generatedEdgeGuard) -le 100)
$edgeGuardSource = Get-Content -Raw -LiteralPath $sourceEdgeGuard
Assert-True "edge guard watches objective safe-zone types" ($edgeGuardSource -match '"LocationLogicStart", "LocationLogicDepot", "LocationLogicCamp", "LocationLogicAirport"')
Assert-True "edge guard removes ground rim abuse but skips aircraft" ($edgeGuardSource -match '!\(_vehicle isKindOf "Air"\)' -and $edgeGuardSource -match '_edge && !_safe' -and $edgeGuardSource -match 'setDamage 1')
Assert-True "source runtime audit under 100 non-empty LOC" ((Get-NonEmptyLineCount $sourceRuntimeAudit) -le 100)
Assert-True "generated runtime audit under 100 non-empty LOC" ((Get-NonEmptyLineCount $generatedRuntimeAudit) -le 100)

$runtimeAuditSource = Get-Content -Raw -LiteralPath $sourceRuntimeAudit
Assert-True "runtime audit logs counts and SV totals" ($runtimeAuditSource -match 'towns \[%1\] camps \[%2\] airports \[%3\] defenses \[%4\] startSV \[%5\] maxSV \[%6\]')
Assert-True "runtime audit logs Zargabad base and fortification counts" ($runtimeAuditSource -match 'bases WEST %1 EAST %2 distance \[%3\] westStatic \[%4\] eastStatic \[%5\] baseWalls \[%6\] centralWallPieces \[%7\]')
Assert-True "runtime audit logs Zargabad base static templates" ($runtimeAuditSource -match 'baseStaticTemplates WEST %1 EAST %2')
Assert-True "runtime audit logs Zargabad economy and range constants" ($runtimeAuditSource -match 'supplyCap \[%1\] teamSupplyCap \[%2\] fastTravelMax \[%3\] respawnCampRange \[%4\].*edgeGuard \[%10,%11,%12\]')
Assert-True "runtime audit logs Zargabad factory restrictions" ($runtimeAuditSource -match 'factoryCounts WEST L/H/A/AP')
Assert-True "runtime audit checks expanded forbidden normal factory set" ($runtimeAuditSource -match 'M1A1' -and $runtimeAuditSource -match 'T90' -and $runtimeAuditSource -match 'Ka52' -and $runtimeAuditSource -match 'Su34' -and $runtimeAuditSource -match 'F35B')
Assert-True "runtime audit logs Zargabad price multipliers and samples" ($runtimeAuditSource -match 'priceMultipliers %1 priceSamples %2')

Assert-True "runtime report tool exists" (Test-Path -LiteralPath $runtimeReportTool)
$runtimeReportSource = Get-Content -Raw -LiteralPath $runtimeReportTool
Assert-True "runtime report tool wraps runtime validator" ($runtimeReportSource -match 'Validate-ZargabadRuntimeEvidence\.ps1')
Assert-True "runtime report tool checks town defense orientation" ($runtimeReportSource -match 'Town defense orientation')
Assert-True "runtime report tool emits Claude notes" ($runtimeReportSource -match '## Claude Notes')
Assert-True "runtime report tool emits validator output" ($runtimeReportSource -match '## Validator Output')
Assert-True "Claude brief tool exists" (Test-Path -LiteralPath $claudeBriefTool)
$claudeBriefSource = Get-Content -Raw -LiteralPath $claudeBriefTool
Assert-True "Claude brief tool emits retest focus" ($claudeBriefSource -match '## Retest Focus')
Assert-True "Claude brief tool carries stop/go ownership" ($claudeBriefSource -match 'Codex owns the stop/go call')
Assert-True "Claude brief tool points to runtime report" ($claudeBriefSource -match 'New-ZargabadRuntimeReport\.ps1')
Assert-True "Claude brief tool points to runtime validator" ($claudeBriefSource -match 'Validate-ZargabadRuntimeEvidence\.ps1')

$takistanZargabadModule = Resolve-RepoPath "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Module/Zargabad"
Assert-True "Takistan has no generated Zargabad module spillover" (-not (Test-Path -LiteralPath $takistanZargabadModule))

Write-Host ""
Write-Host "Zargabad town/SV summary:"
$parsedTowns | Sort-Object MaxSV -Descending | Format-Table Name, StartSV, MaxSV, Range, Camps, MinCampDistance, MaxCampDistance, Defenses, MinDefenseDistance, MaxDefenseDistance, X, Y -AutoSize
