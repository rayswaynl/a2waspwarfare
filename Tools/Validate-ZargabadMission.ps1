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

function Get-ParameterDefault {
	param([string]$Content, [string]$Name)
	$pattern = 'class\s+' + [regex]::Escape($Name) + '\s*\{[\s\S]*?default\s*=\s*([^;]+);'
	$match = [regex]::Match($Content, $pattern)
	if (-not $match.Success) { throw "Could not find parameter default for [$Name]" }
	return $match.Groups[1].Value.Trim()
}

function Get-DefenseKinds {
	param($Defense)
	$matches = [regex]::Matches($Defense.Init, "['""]([^'""]+)['""]")
	return @($matches | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ -ne "wfbe_defense_kind" })
}

function Test-TownHasAnyDefenseKind {
	param($Town, [string[]]$Kinds)
	return @($Town.DefenseKindList | Where-Object { $_ -in $Kinds }).Count -gt 0
}

function Get-TownDefenseKindCount {
	param($Town, [string]$Kind)
	return @($Town.DefenseKindList | Where-Object { $_ -eq $Kind }).Count
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

function Get-NumberPairs {
	param([string]$Line)
	return @([regex]::Matches($Line, '\[(-?\d+),(-?\d+)\]') | ForEach-Object {
		[pscustomobject]@{ A = [int]$_.Groups[1].Value; B = [int]$_.Groups[2].Value }
	})
}

function Get-Numbers {
	param([string]$Line)
	return @([regex]::Matches($Line, '-?\d+') | ForEach-Object { [int]$_.Value })
}

function Get-SqfTemplateEntries {
	param([string]$Content, [string]$VariableName)
	$pattern = [regex]::Escape($VariableName) + '\s*=\s*\[(?<body>[\s\S]*?)\];'
	$match = [regex]::Match($Content, $pattern)
	if (-not $match.Success) { throw "Could not find SQF template variable [$VariableName]" }
	return @([regex]::Matches($match.Groups["body"].Value, '\["(?<class>[^"]+)",\[(?<x>-?\d+),(?<y>-?\d+),(?<z>-?\d+)\],(?<dir>-?\d+)\]') | ForEach-Object {
		[pscustomobject]@{
			Class = $_.Groups["class"].Value
			X = [int]$_.Groups["x"].Value
			Y = [int]$_.Groups["y"].Value
			Z = [int]$_.Groups["z"].Value
			Dir = [int]$_.Groups["dir"].Value
		}
	})
}

function Assert-TemplateMatches {
	param([string]$Name, [object[]]$Actual, [object[]]$Expected)
	Assert-Equal "$Name template row count" $Actual.Count $Expected.Count
	for ($i = 0; $i -lt $Expected.Count; $i++) {
		Assert-Equal "$Name row $i class" $Actual[$i].Class $Expected[$i].Class
		Assert-Equal "$Name row $i x" $Actual[$i].X $Expected[$i].X
		Assert-Equal "$Name row $i y" $Actual[$i].Y $Expected[$i].Y
		Assert-Equal "$Name row $i z" $Actual[$i].Z $Expected[$i].Z
		Assert-Equal "$Name row $i dir" $Actual[$i].Dir $Expected[$i].Dir
	}
}

function Assert-RuntimeAnchorsMatch {
	param([string]$Name, [object[]]$Actual, [object[]]$Expected)
	Assert-Equal "$Name runtime anchor row count" $Actual.Count $Expected.Count
	for ($i = 0; $i -lt $Expected.Count; $i++) {
		Assert-Equal "$Name runtime row $i class" $Actual[$i].Class $Expected[$i].Class
		Assert-Equal "$Name runtime row $i x" $Actual[$i].X $Expected[$i].X
		Assert-Equal "$Name runtime row $i y" $Actual[$i].Y $Expected[$i].Y
		Assert-Equal "$Name runtime row $i dir" $Actual[$i].Dir $Expected[$i].Dir
	}
}

function Get-WorldPointFromTemplateOffset {
	param($Origin, [double]$Dir, [int]$OffsetX, [int]$OffsetY)
	$radians = $Dir * [math]::PI / 180
	return [pscustomobject]@{
		X = [int][math]::Round($Origin.X + ($OffsetX * [math]::Cos($radians)) + ($OffsetY * [math]::Sin($radians)))
		Y = [int][math]::Round($Origin.Y - ($OffsetX * [math]::Sin($radians)) + ($OffsetY * [math]::Cos($radians)))
	}
}

function Get-TemplateRuntimeAnchors {
	param($Origin, [double]$Dir, [object[]]$Template)
	return @($Template | ForEach-Object {
		$point = Get-WorldPointFromTemplateOffset -Origin $Origin -Dir $Dir -OffsetX $_.X -OffsetY $_.Y
		$staticDir = ($Dir + $_.Dir) % 360
		[pscustomobject]@{
			Class = $_.Class
			X = $point.X
			Y = $point.Y
			Dir = [int][math]::Round($staticDir)
		}
	})
}

$missionFullPath = Resolve-RepoPath $MissionPath
$sourceMissionFullPath = Resolve-RepoPath $SourceMissionPath
$sqmPath = Join-Path $missionFullPath "mission.sqm"
$parametersPath = Join-Path $missionFullPath "Rsc/Parameters.hpp"

Assert-True "mission.sqm exists" (Test-Path -LiteralPath $sqmPath)
Assert-True "Zargabad Parameters.hpp exists" (Test-Path -LiteralPath $parametersPath)

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
$rimTestPoints = @(
	[pscustomobject]@{ Name = "West illegal rim"; X = 80; Y = 3000; Expected = "remove" },
	[pscustomobject]@{ Name = "South illegal rim"; X = 3000; Y = 80; Expected = "remove" },
	[pscustomobject]@{ Name = "East illegal rim"; X = 5900; Y = 3000; Expected = "remove" },
	[pscustomobject]@{ Name = "North illegal rim"; X = 3000; Y = 5900; Expected = "remove" },
	[pscustomobject]@{ Name = "North Camp legal rim"; X = 3600; Y = 5900; Expected = "allow" },
	[pscustomobject]@{ Name = "Rahim Villa legal rim"; X = 4330; Y = 5900; Expected = "allow" },
	[pscustomobject]@{ Name = "East Farms legal rim"; X = 5900; Y = 4340; Expected = "allow" }
)
$badRimTests = @()
foreach ($point in $rimTestPoints) {
	$edgeDistance = Get-EdgeDistance -LogicObject $point -Boundary 6000
	$nearestSafeDistance = (@($safeZoneObjects | ForEach-Object { Get-FlatDistance $point $_ }) | Measure-Object -Minimum).Minimum
	if ($edgeDistance -gt 120) { $badRimTests += "$($point.Name): outside edge band" }
	if ($point.Expected -eq "remove" -and $nearestSafeDistance -le 325) { $badRimTests += "$($point.Name): remove point inside safe bubble" }
	if ($point.Expected -eq "allow" -and $nearestSafeDistance -gt 325) { $badRimTests += "$($point.Name): allow point outside safe bubble" }
}
Assert-Equal "rim test point geometry mismatches" $badRimTests.Count 0

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
	$defenseKindList = @($defenseLinks | ForEach-Object { Get-DefenseKinds $_ })
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
		DefenseKindList = $defenseKindList
		DefenseKinds = @($defenseKindList | Sort-Object -Unique)
		MinDefenseDistance = if ($defenseDistances.Count -gt 0) { ($defenseDistances | Measure-Object -Minimum).Minimum } else { -1 }
		MaxDefenseDistance = if ($defenseDistances.Count -gt 0) { ($defenseDistances | Measure-Object -Maximum).Maximum } else { -1 }
		X = $town.X
		Y = $town.Y
	}
}

$expectedTownPlacement = @(
	[pscustomobject]@{ Name = "Zargabad City Center"; X = 4075; Y = 3950; StartSV = 30; MaxSV = 95; Range = 380; Tier = "primary" },
	[pscustomobject]@{ Name = "Zargabad Airfield"; X = 2980; Y = 5200; StartSV = 20; MaxSV = 75; Range = 300; Tier = "primary" },
	[pscustomobject]@{ Name = "Zargabad North District"; X = 4140; Y = 4750; StartSV = 15; MaxSV = 60; Range = 240; Tier = "district" },
	[pscustomobject]@{ Name = "Zargabad South District"; X = 4170; Y = 3150; StartSV = 15; MaxSV = 60; Range = 240; Tier = "district" },
	[pscustomobject]@{ Name = "East Market"; X = 4960; Y = 3940; StartSV = 15; MaxSV = 55; Range = 190; Tier = "district" },
	[pscustomobject]@{ Name = "Northwest Base"; X = 2500; Y = 5600; StartSV = 15; MaxSV = 55; Range = 220; Tier = "district" },
	[pscustomobject]@{ Name = "Rahim Villa"; X = 4450; Y = 5750; StartSV = 15; MaxSV = 50; Range = 180; Tier = "district" },
	[pscustomobject]@{ Name = "West Suburbs"; X = 3300; Y = 3800; StartSV = 10; MaxSV = 40; Range = 160; Tier = "flank" },
	[pscustomobject]@{ Name = "North Camp"; X = 3600; Y = 5650; StartSV = 10; MaxSV = 38; Range = 150; Tier = "flank" },
	[pscustomobject]@{ Name = "East Farms"; X = 5650; Y = 4300; StartSV = 10; MaxSV = 30; Range = 130; Tier = "flank" },
	[pscustomobject]@{ Name = "South Farms"; X = 4320; Y = 2050; StartSV = 10; MaxSV = 30; Range = 130; Tier = "flank" },
	[pscustomobject]@{ Name = "Southern Outskirts"; X = 3000; Y = 1850; StartSV = 10; MaxSV = 30; Range = 130; Tier = "flank" },
	[pscustomobject]@{ Name = "West Farms"; X = 2250; Y = 3350; StartSV = 10; MaxSV = 30; Range = 130; Tier = "flank" }
)
foreach ($expectedTown in $expectedTownPlacement) {
	$town = @($parsedTowns | Where-Object { $_.Name -eq $expectedTown.Name })
	Assert-Equal "$($expectedTown.Name) placement row count" $town.Count 1
	Assert-NearPosition "$($expectedTown.Name) stays at intended population anchor" $town[0] $expectedTown.X $expectedTown.Y 5
	Assert-Equal "$($expectedTown.Name) start SV" $town[0].StartSV $expectedTown.StartSV
	Assert-Equal "$($expectedTown.Name) max SV" $town[0].MaxSV $expectedTown.MaxSV
	Assert-Equal "$($expectedTown.Name) capture range" $town[0].Range $expectedTown.Range
}
$primaryTowns = @($expectedTownPlacement | Where-Object { $_.Tier -eq "primary" } | ForEach-Object { $_.Name })
$districtTowns = @($expectedTownPlacement | Where-Object { $_.Tier -eq "district" } | ForEach-Object { $_.Name })
$flankTowns = @($expectedTownPlacement | Where-Object { $_.Tier -eq "flank" } | ForEach-Object { $_.Name })
Assert-Equal "primary population/value anchor count" @($parsedTowns | Where-Object { $_.Name -in $primaryTowns -and $_.MaxSV -ge 75 }).Count 2
Assert-Equal "district or market value anchor count" @($parsedTowns | Where-Object { $_.Name -in $districtTowns -and $_.MaxSV -ge 50 -and $_.MaxSV -le 60 }).Count 5
Assert-Equal "lower-value flank route count" @($parsedTowns | Where-Object { $_.Name -in $flankTowns -and $_.MaxSV -le 40 }).Count 6

Assert-Equal "town start SV total" (@($parsedTowns | Measure-Object -Property StartSV -Sum).Sum) 185
Assert-Equal "town max SV total" (@($parsedTowns | Measure-Object -Property MaxSV -Sum).Sum) 648
Assert-Equal "towns without camps" @($parsedTowns | Where-Object { $_.Camps -lt 1 }).Count 0
Assert-Equal "town-linked camp count" (@($parsedTowns | Measure-Object -Property Camps -Sum).Sum) 19
Assert-Equal "camps outside 90m-225m population flow band" @($parsedTowns | Where-Object { $_.MinCampDistance -lt 90 -or $_.MaxCampDistance -gt 225 }).Count 0
$expectedCampPlacement = @(
	[pscustomobject]@{ Id = 101; X = 3925; Y = 4060; Town = "Zargabad City Center"; Min = 170; Max = 200 },
	[pscustomobject]@{ Id = 102; X = 4245; Y = 3860; Town = "Zargabad City Center"; Min = 170; Max = 205 },
	[pscustomobject]@{ Id = 107; X = 4010; Y = 4840; Town = "Zargabad North District"; Min = 145; Max = 170 },
	[pscustomobject]@{ Id = 108; X = 4270; Y = 4670; Town = "Zargabad North District"; Min = 145; Max = 170 },
	[pscustomobject]@{ Id = 112; X = 4050; Y = 3060; Town = "Zargabad South District"; Min = 140; Max = 160 },
	[pscustomobject]@{ Id = 113; X = 4310; Y = 3250; Town = "Zargabad South District"; Min = 160; Max = 185 },
	[pscustomobject]@{ Id = 117; X = 3190; Y = 3870; Town = "West Suburbs"; Min = 120; Max = 145 },
	[pscustomobject]@{ Id = 120; X = 5070; Y = 4010; Town = "East Market"; Min = 120; Max = 145 },
	[pscustomobject]@{ Id = 123; X = 2810; Y = 5270; Town = "Zargabad Airfield"; Min = 170; Max = 200 },
	[pscustomobject]@{ Id = 124; X = 3130; Y = 5080; Town = "Zargabad Airfield"; Min = 170; Max = 205 },
	[pscustomobject]@{ Id = 129; X = 4330; Y = 5860; Town = "Rahim Villa"; Min = 150; Max = 175 },
	[pscustomobject]@{ Id = 130; X = 4570; Y = 5680; Town = "Rahim Villa"; Min = 125; Max = 150 },
	[pscustomobject]@{ Id = 134; X = 2370; Y = 5670; Town = "Northwest Base"; Min = 135; Max = 160 },
	[pscustomobject]@{ Id = 135; X = 2630; Y = 5530; Town = "Northwest Base"; Min = 135; Max = 160 },
	[pscustomobject]@{ Id = 139; X = 3600; Y = 5775; Town = "North Camp"; Min = 115; Max = 135 },
	[pscustomobject]@{ Id = 142; X = 5770; Y = 4340; Town = "East Farms"; Min = 115; Max = 140 },
	[pscustomobject]@{ Id = 145; X = 4230; Y = 1960; Town = "South Farms"; Min = 115; Max = 140 },
	[pscustomobject]@{ Id = 148; X = 2150; Y = 3400; Town = "West Farms"; Min = 105; Max = 125 },
	[pscustomobject]@{ Id = 151; X = 3100; Y = 1790; Town = "Southern Outskirts"; Min = 105; Max = 130 }
)
foreach ($expectedCamp in $expectedCampPlacement) {
	$camp = @($camps | Where-Object { $_.Id -eq $expectedCamp.Id })
	Assert-Equal "camp $($expectedCamp.Id) placement row count" $camp.Count 1
	Assert-NearPosition "camp $($expectedCamp.Id) stays at intended approach anchor" $camp[0] $expectedCamp.X $expectedCamp.Y 5
	$linkedTown = @($parsedTowns | Where-Object { $camp[0].Sync -contains $_.Id })
	Assert-Equal "camp $($expectedCamp.Id) linked town count" $linkedTown.Count 1
	Assert-Equal "camp $($expectedCamp.Id) linked town" $linkedTown[0].Name $expectedCamp.Town
	$distance = [math]::Round((Get-FlatDistance $camp[0] $linkedTown[0]), 1)
	Assert-True "camp $($expectedCamp.Id) approach distance in named band" ($distance -ge $expectedCamp.Min -and $distance -le $expectedCamp.Max)
}
$twoApproachTownNames = @("Zargabad City Center", "Zargabad Airfield", "Zargabad North District", "Zargabad South District", "Northwest Base", "Rahim Villa")
$namedTwoApproachFailures = @()
foreach ($townName in $twoApproachTownNames) {
	if (@($expectedCampPlacement | Where-Object { $_.Town -eq $townName }).Count -ne 2) { $namedTwoApproachFailures += $townName }
}
Assert-Equal "named two-approach population anchor failures" $namedTwoApproachFailures.Count 0
Assert-Equal "towns without defenses" @($parsedTowns | Where-Object { $_.Defenses -lt 1 }).Count 0
$expectedDefensePlacement = @(
	[pscustomobject]@{ Id = 103; X = 3865; Y = 4000; Town = "Zargabad City Center"; Kinds = @("MGNest"); Min = 200; Max = 230 },
	[pscustomobject]@{ Id = 104; X = 4285; Y = 3910; Town = "Zargabad City Center"; Kinds = @("MGNest"); Min = 200; Max = 230 },
	[pscustomobject]@{ Id = 105; X = 4075; Y = 4130; Town = "Zargabad City Center"; Kinds = @("MG"); Min = 165; Max = 195 },
	[pscustomobject]@{ Id = 109; X = 3960; Y = 4800; Town = "Zargabad North District"; Kinds = @("MGNest"); Min = 175; Max = 200 },
	[pscustomobject]@{ Id = 110; X = 4320; Y = 4730; Town = "Zargabad North District"; Kinds = @("MG"); Min = 170; Max = 195 },
	[pscustomobject]@{ Id = 114; X = 4000; Y = 3120; Town = "Zargabad South District"; Kinds = @("MGNest"); Min = 160; Max = 185 },
	[pscustomobject]@{ Id = 115; X = 4340; Y = 3220; Town = "Zargabad South District"; Kinds = @("MG"); Min = 170; Max = 195 },
	[pscustomobject]@{ Id = 118; X = 3150; Y = 3860; Town = "West Suburbs"; Kinds = @("MGNest"); Min = 150; Max = 175 },
	[pscustomobject]@{ Id = 121; X = 5115; Y = 3995; Town = "East Market"; Kinds = @("MGNest"); Min = 150; Max = 180 },
	[pscustomobject]@{ Id = 125; X = 2750; Y = 5230; Town = "Zargabad Airfield"; Kinds = @("MG"); Min = 220; Max = 245 },
	[pscustomobject]@{ Id = 126; X = 3200; Y = 5140; Town = "Zargabad Airfield"; Kinds = @("AA"); Min = 215; Max = 240 },
	[pscustomobject]@{ Id = 127; X = 3040; Y = 5370; Town = "Zargabad Airfield"; Kinds = @("MGNest"); Min = 170; Max = 195 },
	[pscustomobject]@{ Id = 131; X = 4280; Y = 5830; Town = "Rahim Villa"; Kinds = @("MGNest"); Min = 175; Max = 200 },
	[pscustomobject]@{ Id = 132; X = 4620; Y = 5710; Town = "Rahim Villa"; Kinds = @("MGNest"); Min = 160; Max = 190 },
	[pscustomobject]@{ Id = 136; X = 2310; Y = 5640; Town = "Northwest Base"; Kinds = @("MG"); Min = 180; Max = 210 },
	[pscustomobject]@{ Id = 137; X = 2680; Y = 5560; Town = "Northwest Base"; Kinds = @("AA"); Min = 170; Max = 200 },
	[pscustomobject]@{ Id = 140; X = 3650; Y = 5815; Town = "North Camp"; Kinds = @("MGNest"); Min = 160; Max = 185 },
	[pscustomobject]@{ Id = 143; X = 5820; Y = 4370; Town = "East Farms"; Kinds = @("MGNest"); Min = 170; Max = 200 },
	[pscustomobject]@{ Id = 146; X = 4190; Y = 1920; Town = "South Farms"; Kinds = @("MGNest"); Min = 170; Max = 200 },
	[pscustomobject]@{ Id = 149; X = 2100; Y = 3425; Town = "West Farms"; Kinds = @("MGNest"); Min = 155; Max = 180 },
	[pscustomobject]@{ Id = 152; X = 3145; Y = 1760; Town = "Southern Outskirts"; Kinds = @("MGNest"); Min = 160; Max = 185 },
	[pscustomobject]@{ Id = 153; X = 4070; Y = 3765; Town = "Zargabad City Center"; Kinds = @("AT"); Min = 175; Max = 200 },
	[pscustomobject]@{ Id = 154; X = 3920; Y = 3940; Town = "Zargabad City Center"; Kinds = @("MG", "GL"); Min = 145; Max = 170 },
	[pscustomobject]@{ Id = 155; X = 4140; Y = 4585; Town = "Zargabad North District"; Kinds = @("AT"); Min = 155; Max = 175 },
	[pscustomobject]@{ Id = 156; X = 4170; Y = 3355; Town = "Zargabad South District"; Kinds = @("AT"); Min = 195; Max = 215 },
	[pscustomobject]@{ Id = 157; X = 2910; Y = 5400; Town = "Zargabad Airfield"; Kinds = @("AA"); Min = 200; Max = 225 },
	[pscustomobject]@{ Id = 158; X = 3230; Y = 5010; Town = "Zargabad Airfield"; Kinds = @("AT"); Min = 300; Max = 325 },
	[pscustomobject]@{ Id = 159; X = 4450; Y = 5605; Town = "Rahim Villa"; Kinds = @("AT"); Min = 135; Max = 155 },
	[pscustomobject]@{ Id = 160; X = 2500; Y = 5440; Town = "Northwest Base"; Kinds = @("AT"); Min = 150; Max = 170 },
	[pscustomobject]@{ Id = 161; X = 2440; Y = 5720; Town = "Northwest Base"; Kinds = @("MGNest"); Min = 120; Max = 145 },
	[pscustomobject]@{ Id = 162; X = 3535; Y = 5560; Town = "North Camp"; Kinds = @("AT"); Min = 100; Max = 125 },
	[pscustomobject]@{ Id = 163; X = 5540; Y = 4210; Town = "East Farms"; Kinds = @("AT"); Min = 130; Max = 155 },
	[pscustomobject]@{ Id = 164; X = 4410; Y = 2140; Town = "South Farms"; Kinds = @("AT"); Min = 115; Max = 140 }
)
$expectedDefenseIds = @($expectedDefensePlacement | ForEach-Object { $_.Id })
Assert-Equal "exact defense anchor row count" $expectedDefensePlacement.Count 33
Assert-Equal "unexpected defense logic ids" @($defenses | Where-Object { $_.Id -notin $expectedDefenseIds }).Count 0
foreach ($expectedDefense in $expectedDefensePlacement) {
	$defense = @($defenses | Where-Object { $_.Id -eq $expectedDefense.Id })
	Assert-Equal "defense $($expectedDefense.Id) placement row count" $defense.Count 1
	Assert-NearPosition "defense $($expectedDefense.Id) stays at intended firing anchor" $defense[0] $expectedDefense.X $expectedDefense.Y 5
	$linkedTown = @($parsedTowns | Where-Object { $defense[0].Sync -contains $_.Id })
	Assert-Equal "defense $($expectedDefense.Id) linked town count" $linkedTown.Count 1
	Assert-Equal "defense $($expectedDefense.Id) linked town" $linkedTown[0].Name $expectedDefense.Town
	$actualKinds = @((Get-DefenseKinds $defense[0]) | Sort-Object)
	$expectedKinds = @($expectedDefense.Kinds | Sort-Object)
	Assert-True "defense $($expectedDefense.Id) kind mix" (Test-SequenceEqual -Actual $actualKinds -Expected $expectedKinds)
	$distance = [math]::Round((Get-FlatDistance $defense[0] $linkedTown[0]), 1)
	Assert-True "defense $($expectedDefense.Id) approach distance in named band" ($distance -ge $expectedDefense.Min -and $distance -le $expectedDefense.Max)
}
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
$cityCenter = ($parsedTowns | Where-Object { $_.Name -eq "Zargabad City Center" })
$airfield = ($parsedTowns | Where-Object { $_.Name -eq "Zargabad Airfield" })
Assert-True "city center defense mix covers infantry and armor approaches" ((Test-TownHasAnyDefenseKind -Town $cityCenter -Kinds @("MG", "MGNest")) -and (Test-TownHasAnyDefenseKind -Town $cityCenter -Kinds @("GL")) -and (Test-TownHasAnyDefenseKind -Town $cityCenter -Kinds @("AT")))
Assert-True "airfield defense mix covers infantry armor and aircraft approaches" ((Test-TownHasAnyDefenseKind -Town $airfield -Kinds @("MG", "MGNest")) -and (Test-TownHasAnyDefenseKind -Town $airfield -Kinds @("AT")) -and ((Get-TownDefenseKindCount -Town $airfield -Kind "AA") -ge 2))
foreach ($townName in @("Zargabad North District", "Zargabad South District", "Northwest Base", "Rahim Villa")) {
	$town = ($parsedTowns | Where-Object { $_.Name -eq $townName })
	Assert-True "$townName defense mix covers infantry and armor approaches" ((Test-TownHasAnyDefenseKind -Town $town -Kinds @("MG", "MGNest")) -and (Test-TownHasAnyDefenseKind -Town $town -Kinds @("AT")))
}
$priorityDefenseTowns = @("Zargabad City Center", "Zargabad Airfield", "Zargabad North District", "Zargabad South District", "Northwest Base", "Rahim Villa")
Assert-Equal "priority objectives with single-kind defense mix" @($parsedTowns | Where-Object { $_.Name -in $priorityDefenseTowns -and $_.DefenseKinds.Count -lt 2 }).Count 0
Assert-True "Northwest Base defense mix covers northern air approach" ((Get-TownDefenseKindCount -Town ($parsedTowns | Where-Object { $_.Name -eq "Northwest Base" }) -Kind "AA") -ge 1)

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
$expectedStartPlacement = @(
	[pscustomobject]@{ Id = 37; Role = "WEST default southwest base"; X = 1500; Y = 1550; Azimut = 45; MinEdge = 1450; MaxEdge = 1550 },
	[pscustomobject]@{ Id = 43; Role = "WEST alternate south-west approach"; X = 2300; Y = 2500; Azimut = 45; MinEdge = 2250; MaxEdge = 2350 },
	[pscustomobject]@{ Id = 39; Role = "WEST alternate northwest road"; X = 1550; Y = 5200; Azimut = 90; MinEdge = 750; MaxEdge = 850 },
	[pscustomobject]@{ Id = 38; Role = "EAST default northeast base"; X = 5350; Y = 5200; Azimut = 225; MinEdge = 600; MaxEdge = 700 },
	[pscustomobject]@{ Id = 41; Role = "EAST alternate north-east approach"; X = 5450; Y = 5050; Azimut = 225; MinEdge = 500; MaxEdge = 600 },
	[pscustomobject]@{ Id = 42; Role = "EAST alternate south-east approach"; X = 5520; Y = 2450; Azimut = 270; MinEdge = 430; MaxEdge = 530 },
	[pscustomobject]@{ Id = 40; Role = "northern alternate airfield flank"; X = 2450; Y = 5750; Azimut = 135; MinEdge = 200; MaxEdge = 300 },
	[pscustomobject]@{ Id = 44; Role = "northern alternate city flank"; X = 4000; Y = 5750; Azimut = 180; MinEdge = 200; MaxEdge = 300 },
	[pscustomobject]@{ Id = 36; Role = "Resistance central init"; X = 4100; Y = 3950; Azimut = $null; MinEdge = 1850; MaxEdge = 1950 }
)
$expectedStartIds = @($expectedStartPlacement | ForEach-Object { $_.Id })
Assert-Equal "exact start anchor row count" $expectedStartPlacement.Count 9
Assert-Equal "unexpected start logic ids" @($starts | Where-Object { $_.Id -notin $expectedStartIds }).Count 0
foreach ($expectedStart in $expectedStartPlacement) {
	$start = @($starts | Where-Object { $_.Id -eq $expectedStart.Id })
	Assert-Equal "start $($expectedStart.Id) placement row count" $start.Count 1
	Assert-NearPosition "start $($expectedStart.Id) stays at $($expectedStart.Role)" $start[0] $expectedStart.X $expectedStart.Y 5
	if ($null -ne $expectedStart.Azimut) {
		Assert-True "start $($expectedStart.Id) heading" ([math]::Abs($start[0].Azimut - $expectedStart.Azimut) -le 0.1)
	}
	$edgeDistance = [math]::Round((Get-EdgeDistance -LogicObject $start[0] -Boundary 6000), 1)
	Assert-True "start $($expectedStart.Id) edge-distance band" ($edgeDistance -ge $expectedStart.MinEdge -and $edgeDistance -le $expectedStart.MaxEdge)
}
Assert-Equal "north-edge alternate start count" @($starts | Where-Object { $_.Y -ge 5700 -and $_.Y -le 5800 }).Count 2
Assert-Equal "east-flank default-or-alternate start count" @($starts | Where-Object { $_.X -ge 5300 -and $_.X -le 5550 }).Count 3
Assert-True "alternate starts stay out of the 120m kill rim" (@($starts | Where-Object { (Get-EdgeDistance -LogicObject $_ -Boundary 6000) -lt 120 }).Count -eq 0)
Assert-True "alternate starts avoid city core overlap" (@($starts | Where-Object { (Get-FlatDistance $_ $resistanceStart) -lt 900 -and $_.Id -ne $resistanceStart.Id }).Count -eq 0)

$boundarySource = Get-Content -Raw -LiteralPath (Join-Path $sourceMissionFullPath "Common/Init/Init_Boundaries.sqf")
Assert-True "source declares 6000m Zargabad boundary" ($boundarySource -match "case 'zargabad': \{_boundariesXY = 6000\};")

$parametersSource = Get-Content -Raw -LiteralPath $parametersPath
$expectedParameterDefaults = [ordered]@{
	WFBE_C_BASE_DEFENSE_MANNING_RANGE = "500"
	WFBE_C_ECONOMY_FUNDS_START_EAST = "12800"
	WFBE_C_ECONOMY_FUNDS_START_WEST = "12800"
	WFBE_C_ECONOMY_SUPPLY_START_EAST = "4800"
	WFBE_C_ECONOMY_SUPPLY_START_WEST = "4800"
	WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT = "30000"
	WFBE_C_GAMEPLAY_MISSILES_RANGE = "2000"
	WFBE_C_TOWNS_DEFENDER = "3"
	WFBE_C_TOWNS_OCCUPATION = "2"
	WFBE_C_TOWNS_BUILD_PROTECTION_RANGE = "300"
	WFBE_C_TOWNS_VEHICLES_LOCK_DEFENDER = "1"
}
foreach ($parameter in $expectedParameterDefaults.GetEnumerator()) {
	Assert-Equal "Zargabad parameter default $($parameter.Key)" (Get-ParameterDefault -Content $parametersSource -Name $parameter.Key) $parameter.Value
}
$terrainGeneratorSource = Get-Content -Raw -LiteralPath (Resolve-RepoPath "Tools/LoadoutManager/Data/Terrains/BaseTerrain.cs")
Assert-True "LoadoutManager carries Zargabad low-pop parameter defaults" (Test-ContainsAll -Content $terrainGeneratorSource -Needles @('["WFBE_C_ECONOMY_FUNDS_START_EAST"] = "12800"', '["WFBE_C_ECONOMY_SUPPLY_START_WEST"] = "4800"', '["WFBE_C_GAMEPLAY_MISSILES_RANGE"] = "2000"', '["WFBE_C_TOWNS_DEFENDER"] = "3"', '["WFBE_C_TOWNS_VEHICLES_LOCK_DEFENDER"] = "1"'))

$expectedBaseWallTemplate = @(
	[pscustomobject]@{ Class = "Land_HBarrier_large"; X = -55; Y = -55; Z = 0; Dir = 45 },
	[pscustomobject]@{ Class = "Land_HBarrier_large"; X = -30; Y = -70; Z = 0; Dir = 15 },
	[pscustomobject]@{ Class = "Land_HBarrier_large"; X = 0; Y = -76; Z = 0; Dir = 0 },
	[pscustomobject]@{ Class = "Land_HBarrier_large"; X = 30; Y = -70; Z = 0; Dir = 345 },
	[pscustomobject]@{ Class = "Land_HBarrier_large"; X = 55; Y = -55; Z = 0; Dir = 315 },
	[pscustomobject]@{ Class = "Land_HBarrier_large"; X = 70; Y = -25; Z = 0; Dir = 270 },
	[pscustomobject]@{ Class = "Land_HBarrier_large"; X = 70; Y = 25; Z = 0; Dir = 270 },
	[pscustomobject]@{ Class = "Land_HBarrier_large"; X = 55; Y = 55; Z = 0; Dir = 225 },
	[pscustomobject]@{ Class = "Land_HBarrier_large"; X = 25; Y = 70; Z = 0; Dir = 180 },
	[pscustomobject]@{ Class = "Land_HBarrier_large"; X = -25; Y = 70; Z = 0; Dir = 180 },
	[pscustomobject]@{ Class = "Land_HBarrier_large"; X = -55; Y = 55; Z = 0; Dir = 135 },
	[pscustomobject]@{ Class = "Land_HBarrier_large"; X = -70; Y = 25; Z = 0; Dir = 90 },
	[pscustomobject]@{ Class = "Land_HBarrier_large"; X = -70; Y = -25; Z = 0; Dir = 90 }
)
$expectedWestStaticTemplate = @(
	[pscustomobject]@{ Class = "M2StaticMG_US_EP1"; X = -45; Y = 0; Z = 0; Dir = 270 },
	[pscustomobject]@{ Class = "M2StaticMG_US_EP1"; X = 45; Y = 0; Z = 0; Dir = 90 },
	[pscustomobject]@{ Class = "TOW_TriPod_US_EP1"; X = 0; Y = 58; Z = 0; Dir = 0 },
	[pscustomobject]@{ Class = "Stinger_Pod_US_EP1"; X = 0; Y = -58; Z = 0; Dir = 180 }
)
$expectedEastStaticTemplate = @(
	[pscustomobject]@{ Class = "KORD_high_TK_EP1"; X = -45; Y = 0; Z = 0; Dir = 270 },
	[pscustomobject]@{ Class = "KORD_high_TK_EP1"; X = 45; Y = 0; Z = 0; Dir = 90 },
	[pscustomobject]@{ Class = "Metis_TK_EP1"; X = 0; Y = 58; Z = 0; Dir = 0 },
	[pscustomobject]@{ Class = "Igla_AA_pod_TK_EP1"; X = 0; Y = -58; Z = 0; Dir = 180 }
)
$expectedWestRuntimeStaticAnchors = @(
	[pscustomobject]@{ Class = "M2StaticMG_US_EP1"; X = 1468; Y = 1582; Dir = 315 },
	[pscustomobject]@{ Class = "M2StaticMG_US_EP1"; X = 1532; Y = 1518; Dir = 135 },
	[pscustomobject]@{ Class = "TOW_TriPod_US_EP1"; X = 1541; Y = 1591; Dir = 45 },
	[pscustomobject]@{ Class = "Stinger_Pod_US_EP1"; X = 1459; Y = 1509; Dir = 225 }
)
$expectedEastRuntimeStaticAnchors = @(
	[pscustomobject]@{ Class = "KORD_high_TK_EP1"; X = 5382; Y = 5168; Dir = 135 },
	[pscustomobject]@{ Class = "KORD_high_TK_EP1"; X = 5318; Y = 5232; Dir = 315 },
	[pscustomobject]@{ Class = "Metis_TK_EP1"; X = 5309; Y = 5159; Dir = 225 },
	[pscustomobject]@{ Class = "Igla_AA_pod_TK_EP1"; X = 5391; Y = 5241; Dir = 45 }
)

foreach ($path in @($sourceMissionFullPath, $missionFullPath)) {
	$initZargabad = Get-Content -Raw -LiteralPath (Join-Path $path "Server/Init/Init_Zargabad.sqf")
	Assert-True "$path launches Zargabad edge guard" ($initZargabad -like '*Zargabad_EdgeGuard.sqf*')
	Assert-True "$path launches Zargabad black market" ($initZargabad -like '*Zargabad_BlackMarket.sqf*')
	Assert-True "$path launches Zargabad runtime audit" ($initZargabad -like '*Zargabad_RuntimeAudit.sqf*')
	Assert-True "$path builds WDDM-compatible central wall" ($initZargabad -like '*WFBE_ZARGABAD_CENTRAL_WALL*' -and $initZargabad -like '*CreateDefenseTemplate*')
	Assert-True "$path marks central wall as uncrewed fortification" ($initZargabad -match 'WFBE_ZARGABAD_CENTRAL_WALL_CREWED_COUNT", 0' -and $initZargabad -notmatch '_centralWall = _centralWall \+ \[\["(M2StaticMG|KORD|TOW|Metis|Stinger|Igla|ZU23|SPG9)')
	Assert-True "$path orients Zargabad town defense logics" ($initZargabad.Contains('WFBE_ZARGABAD_TOWN_DEFENSE_ORIENTED_COUNT') -and $initZargabad.Contains('atan2') -and $initZargabad.Contains('_synced setDir _dir;') -and $initZargabad.Contains('Oriented [%1] town defense logics'))
	Assert-True "$path central wall has pass-through gaps" ($initZargabad -match '\[-1180,-1018\][\s\S]*\[-790,-628\][\s\S]*\[-420,-258\][\s\S]*\[30,192\][\s\S]*\[470,632\][\s\S]*\[870,1032\]')
	Assert-True "$path records central wall gap checkpoints" ($initZargabad -match 'WFBE_ZARGABAD_CENTRAL_WALL_GAP_OFFSETS' -and $initZargabad -match '\[-904,-524,-114,331,751\]' -and $initZargabad -match 'WFBE_ZARGABAD_CENTRAL_WALL_GAPS')
	$centralWallSpanLine = @($initZargabad -split "`r?`n" | Where-Object { $_ -match '^\s*_centralWallSpans\s*=' } | Select-Object -First 1)[0]
	$centralWallGapLine = @($initZargabad -split "`r?`n" | Where-Object { $_ -match '^\s*_centralWallGapOffsets\s*=' } | Select-Object -First 1)[0]
	$centralWallSpans = Get-NumberPairs $centralWallSpanLine
	$centralWallGapOffsets = Get-Numbers $centralWallGapLine
	$centralWallPieceCount = 0
	$centralWallGapWidths = @()
	$centralWallGapsCentered = $true
	for ($spanIndex = 0; $spanIndex -lt $centralWallSpans.Count; $spanIndex++) {
		$span = $centralWallSpans[$spanIndex]
		$centralWallPieceCount += [int]([math]::Floor(($span.B - $span.A) / 18) + 1)
		if ($spanIndex -gt 0) {
			$previous = $centralWallSpans[$spanIndex - 1]
			$gapWidth = $span.A - $previous.B
			$centralWallGapWidths += $gapWidth
			$gapOffset = $centralWallGapOffsets[$spanIndex - 1]
			if ($gapOffset -le $previous.B -or $gapOffset -ge $span.A) { $centralWallGapsCentered = $false }
		}
	}
	Assert-Equal "$path central wall span count" $centralWallSpans.Count 6
	Assert-Equal "$path central wall gap checkpoint count" $centralWallGapOffsets.Count 5
	Assert-Equal "$path central wall template piece count" $centralWallPieceCount 60
	Assert-True "$path central wall pass-through gaps are bounded" ((@($centralWallGapWidths | Where-Object { $_ -lt 180 -or $_ -gt 320 }).Count -eq 0) -and $centralWallGapsCentered)
	Assert-True "$path central wall is centered and diagonal" ($initZargabad -match '\[3425,3375,0\][\s\S]*setDir 316;')
	Assert-True "$path records Zargabad base audit counts" ($initZargabad -match 'WFBE_ZARGABAD_BASE_WALL_COUNT' -and $initZargabad -match 'WFBE_ZARGABAD_BASE_STATIC_COUNT_%1' -and $initZargabad -match 'WFBE_ZARGABAD_BASE_POS_%1')
	Assert-True "$path records Zargabad base fortification footprint" ($initZargabad -match 'WFBE_ZARGABAD_BASE_FORTIFICATION_FOOTPRINT", \[35,45,74,78\]' -and $initZargabad -match '\[-55,-55,0\]' -and $initZargabad -match '\[70,25,0\]' -and $initZargabad -match '\[0,-76,0\]')
	Assert-True "$path records Zargabad base static templates" ($initZargabad -match 'WFBE_ZARGABAD_BASE_STATIC_TEMPLATE_WEST' -and $initZargabad -match 'M2StaticMG_US_EP1' -and $initZargabad -match 'TOW_TriPod_US_EP1' -and $initZargabad -match 'Stinger_Pod_US_EP1' -and $initZargabad -match 'WFBE_ZARGABAD_BASE_STATIC_TEMPLATE_EAST' -and $initZargabad -match 'KORD_high_TK_EP1' -and $initZargabad -match 'Metis_TK_EP1' -and $initZargabad -match 'Igla_AA_pod_TK_EP1')
	$baseWallTemplate = Get-SqfTemplateEntries -Content $initZargabad -VariableName "_baseWalls"
	$westStaticTemplate = Get-SqfTemplateEntries -Content $initZargabad -VariableName "_westStatics"
	$eastStaticTemplate = Get-SqfTemplateEntries -Content $initZargabad -VariableName "_eastStatics"
	Assert-TemplateMatches "$path base H-barrier ring" $baseWallTemplate $expectedBaseWallTemplate
	Assert-TemplateMatches "$path WEST base statics" $westStaticTemplate $expectedWestStaticTemplate
	Assert-TemplateMatches "$path EAST base statics" $eastStaticTemplate $expectedEastStaticTemplate
	Assert-RuntimeAnchorsMatch "$path WEST base statics" (Get-TemplateRuntimeAnchors -Origin $westStart -Dir 45 -Template $westStaticTemplate) $expectedWestRuntimeStaticAnchors
	Assert-RuntimeAnchorsMatch "$path EAST base statics" (Get-TemplateRuntimeAnchors -Origin $eastStart -Dir 225 -Template $eastStaticTemplate) $expectedEastRuntimeStaticAnchors
	Assert-True "$path base anti-armor statics face the base-axis center" ($initZargabad -match '_westStatics[\s\S]*"TOW_TriPod_US_EP1",\[0,58,0\],0[\s\S]*"Stinger_Pod_US_EP1",\[0,-58,0\],180' -and $initZargabad -match '_eastStatics[\s\S]*"Metis_TK_EP1",\[0,58,0\],0[\s\S]*"Igla_AA_pod_TK_EP1",\[0,-58,0\],180')
	Assert-True "$path normalizes Zargabad base static facing evidence" ($initZargabad -match '_staticDir = _dir \+ \(_x select 2\)' -and $initZargabad -match 'if \(_staticDir >= 360\) then \{_staticDir = _staticDir - 360\}' -and $initZargabad -match '_def setDir _staticDir')
	Assert-True "$path records Zargabad base static runtime positions" ($initZargabad -match 'WFBE_ZARGABAD_BASE_STATIC_POSITIONS_%1' -and $initZargabad -match '_staticPositions = _staticPositions \+' -and $initZargabad -match 'Base static runtime positions WEST %1 EAST %2')
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
$runtimeEvidenceTool = Join-Path (Resolve-RepoPath "Tools") "Validate-ZargabadRuntimeEvidence.ps1"
$runtimeReportTool = Join-Path (Resolve-RepoPath "Tools") "New-ZargabadRuntimeReport.ps1"
$runtimeReportValidatorTool = Join-Path (Resolve-RepoPath "Tools") "Validate-ZargabadRuntimeReport.ps1"
$mapAuditPacketTool = Join-Path (Resolve-RepoPath "Tools") "New-ZargabadMapAuditPacket.ps1"
$claudeBriefTool = Join-Path (Resolve-RepoPath "Tools") "New-ZargabadClaudeBrief.ps1"

Assert-True "source mystery feature under 100 non-empty LOC" ((Get-NonEmptyLineCount $sourceBlackMarket) -le 100)
Assert-True "generated mystery feature under 100 non-empty LOC" ((Get-NonEmptyLineCount $generatedBlackMarket) -le 100)
$blackMarketSource = Get-Content -Raw -LiteralPath $sourceBlackMarket
Assert-True "mystery feature is airfield ownership gated" ($blackMarketSource -match 'Zargabad Airfield' -and $blackMarketSource -match 'sideID' -and $blackMarketSource -match 'WFBE_C_WEST_ID, WFBE_C_EAST_ID')
Assert-True "mystery feature reuses side para-ammo arrays" ($blackMarketSource -match 'WFBE_%1PARAAMMO')
Assert-True "mystery feature uses smoke and trash cleanup lifecycle" ($blackMarketSource -match 'SmokeShellYellow' -and $blackMarketSource -match 'wfbe_trashable", false' -and $blackMarketSource -match 'deleteVehicle _smoke' -and $blackMarketSource -match 'wfbe_trashable", true')
Assert-True "mystery feature waits for server town init and logs armed evidence" ($blackMarketSource -match 'townInitServer' -and $blackMarketSource -match 'armed near Zargabad Airfield positions %1 delay \[600,960\] hold \[300\]')
Assert-True "mystery feature logs cache spawn and cleanup evidence" ($blackMarketSource -match 'surfaced near' -and $blackMarketSource -match 'cleanup released')
Assert-True "mystery feature has five bounded cache positions" (Test-ContainsAll -Content $blackMarketSource -Needles @("[3930,3995,0]", "[4100,3825,0]", "[4235,4040,0]", "[4970,3890,0]", "[3310,3865,0]"))
Assert-True "source edge guard under 100 non-empty LOC" ((Get-NonEmptyLineCount $sourceEdgeGuard) -le 100)
Assert-True "generated edge guard under 100 non-empty LOC" ((Get-NonEmptyLineCount $generatedEdgeGuard) -le 100)
$edgeGuardSource = Get-Content -Raw -LiteralPath $sourceEdgeGuard
Assert-True "edge guard watches objective safe-zone types" ($edgeGuardSource -match '"LocationLogicStart", "LocationLogicDepot", "LocationLogicCamp", "LocationLogicAirport"')
Assert-True "edge guard removes ground rim abuse but skips aircraft" ($edgeGuardSource -match '!\(_vehicle isKindOf "Air"\)' -and $edgeGuardSource -match '_edge && !_safe' -and $edgeGuardSource -match 'setDamage 1')
Assert-True "edge guard logs legal safe-rim allowance" ($edgeGuardSource -match 'allowed at safe edge rim' -and $edgeGuardSource -match 'WFBE_Zargabad_EdgeSafeLogged')
Assert-True "source runtime audit under 100 non-empty LOC" ((Get-NonEmptyLineCount $sourceRuntimeAudit) -le 100)
Assert-True "generated runtime audit under 100 non-empty LOC" ((Get-NonEmptyLineCount $generatedRuntimeAudit) -le 100)

$runtimeAuditSource = Get-Content -Raw -LiteralPath $sourceRuntimeAudit
Assert-True "runtime audit logs counts and SV totals" ($runtimeAuditSource -match 'towns \[%1\] camps \[%2\] airports \[%3\] defenses \[%4\] startSV \[%5\] maxSV \[%6\]')
Assert-True "runtime audit logs Zargabad base and fortification counts" ($runtimeAuditSource -match 'bases WEST %1 EAST %2 distance \[%3\] westStatic \[%4\] eastStatic \[%5\] baseWalls \[%6\] baseFootprint %7 centralWallPieces \[%8\]')
Assert-True "runtime audit logs base fortification footprint evidence" ($runtimeAuditSource -match 'WFBE_ZARGABAD_BASE_FORTIFICATION_FOOTPRINT')
Assert-True "runtime audit logs uncrewed central wall evidence" ($runtimeAuditSource -match 'centralWallCrewed \[%9\]')
Assert-True "runtime audit logs central wall gap checkpoints" ($runtimeAuditSource -match 'centralWallGaps %10')
Assert-True "runtime audit logs Zargabad base static templates" ($runtimeAuditSource -match 'baseStaticTemplates WEST %1 EAST %2')
Assert-True "runtime audit logs Zargabad economy, range, and weapon-pressure constants" ($runtimeAuditSource -match 'supplyCap \[%1\] teamSupplyCap \[%2\] fastTravelMax \[%3\] respawnCampRange \[%4\].*edgeGuard \[%10,%11,%12\] weapons missileRange \[%13\] uavRange \[%14\] townRanges \[%15,%16,%17\] purchaseHangar \[%18\] countermeasures \[%19,%20\]')
Assert-True "runtime audit logs Zargabad factory restrictions" ($runtimeAuditSource -match 'factoryCounts WEST L/H/A/AP')
Assert-True "runtime audit logs exact Zargabad factory lists" ($runtimeAuditSource -match 'factoryLists WEST H %1 A %2 EAST H %3 A %4')
Assert-True "runtime audit checks expanded forbidden normal factory set" ($runtimeAuditSource -match 'M1A1' -and $runtimeAuditSource -match 'T90' -and $runtimeAuditSource -match 'Ka52' -and $runtimeAuditSource -match 'Su34' -and $runtimeAuditSource -match 'F35B')
Assert-True "runtime audit logs Zargabad price multipliers and samples" ($runtimeAuditSource -match 'priceMultipliers %1 priceSamples %2')

Assert-True "runtime report tool exists" (Test-Path -LiteralPath $runtimeReportTool)
$runtimeReportSource = Get-Content -Raw -LiteralPath $runtimeReportTool
$runtimeEvidenceSource = Get-Content -Raw -LiteralPath $runtimeEvidenceTool
Assert-True "runtime evidence validator checks named rim points" ($runtimeEvidenceSource -match 'RequireNamedRimPoints' -and $runtimeEvidenceSource -match 'West illegal rim removed' -and $runtimeEvidenceSource -match 'East Farms legal rim allowed')
Assert-True "runtime report tool wraps runtime validator" ($runtimeReportSource -match 'Validate-ZargabadRuntimeEvidence\.ps1')
Assert-True "runtime report tool checks town defense orientation" ($runtimeReportSource -match 'Town defense orientation')
Assert-True "runtime report tool checks base static runtime positions" ($runtimeReportSource -match 'Base static runtime positions')
Assert-True "runtime report tool checks base fortification footprint" ($runtimeReportSource -match 'baseFootprint \\\[35,45,74,78\\\]')
Assert-True "runtime report tool checks uncrewed central wall" ($runtimeReportSource -match 'centralWallCrewed \\\[0\\\]')
Assert-True "runtime report tool checks edge safe-rim allow gate" ($runtimeReportSource -match 'RequireEdgeGuardSafeAllow' -and $runtimeReportSource -match 'Edge guard safe allow' -and $runtimeReportSource -match 'allowed at safe edge rim')
Assert-True "runtime report tool checks named rim point gate" ($runtimeReportSource -match 'RequireNamedRimPoints' -and $runtimeReportSource -match 'Named rim points')
Assert-True "runtime report tool checks black-market arming" ($runtimeReportSource -match 'Black-market armed')
Assert-True "runtime report tool emits Claude notes" ($runtimeReportSource -match '## Claude Notes')
Assert-True "runtime report tool asks Claude for priority defense mix arcs" ($runtimeReportSource -match 'Priority defense mix arcs' -and $runtimeReportSource -match 'city MG/nest\+GL\+AT' -and $runtimeReportSource -match 'airfield MG/nest\+AT\+2xAA')
Assert-True "runtime report tool emits validator output" ($runtimeReportSource -match '## Validator Output')
Assert-True "runtime report validator tool exists" (Test-Path -LiteralPath $runtimeReportValidatorTool)
$runtimeReportValidatorSource = Get-Content -Raw -LiteralPath $runtimeReportValidatorTool
Assert-True "runtime report validator requires all Claude Notes rows" ($runtimeReportValidatorSource -match 'Claude Notes required rows are present' -and $runtimeReportValidatorSource -match 'Base safety and spawn sightlines' -and $runtimeReportValidatorSource -match 'Economy and factory pricing feel')
Assert-True "runtime report validator requires Claude Notes PASS rows" ($runtimeReportValidatorSource -match 'Claude Notes rows are all PASS')
Assert-True "runtime report validator requires evidence on PASS rows" ($runtimeReportValidatorSource -match 'Claude Notes PASS rows include evidence')
Assert-True "runtime report validator requires row-specific Claude evidence" ($runtimeReportValidatorSource -match 'Claude Notes .* evidence is specific' -and $runtimeReportValidatorSource -match 'zargabad-map-audit\\.md' -and $runtimeReportValidatorSource -match 'Recommended Codex action')
Assert-True "runtime report validator requires complete gate and failure scan rows" ($runtimeReportValidatorSource -match 'runtime gate snapshot required rows are present' -and $runtimeReportValidatorSource -match 'runtime failure scan required rows are present' -and $runtimeReportValidatorSource -match 'Vehicle/object creation failures')
Assert-True "runtime report validator rejects missing gates and found failures" ($runtimeReportValidatorSource -match 'runtime report has no missing required gates' -and $runtimeReportValidatorSource -match 'runtime report failure scan is clear')
Assert-True "runtime report validator checks optional runtime gates" ($runtimeReportValidatorSource -match 'RequireJip' -and $runtimeReportValidatorSource -match 'RequireHeadlessClient' -and $runtimeReportValidatorSource -match 'RequireEdgeGuardRemoval' -and $runtimeReportValidatorSource -match 'RequireEdgeGuardSafeAllow' -and $runtimeReportValidatorSource -match 'RequireNamedRimPoints' -and $runtimeReportValidatorSource -match 'RequireBlackMarket')
Assert-True "runtime report validator checks black-market arming gate" ($runtimeReportValidatorSource -match 'runtime report black-market armed gate passed')
Assert-True "runtime evidence validator rejects class and vehicle creation failures" ($runtimeEvidenceSource -match 'WFBE class or loadout validation errors' -and $runtimeEvidenceSource -match 'vehicle or object creation failures')
Assert-True "runtime report failure scan rejects class and vehicle creation failures" ($runtimeReportSource -match 'WFBE class/loadout validation errors' -and $runtimeReportSource -match 'Vehicle/object creation failures')
Assert-True "map audit packet tool exists" (Test-Path -LiteralPath $mapAuditPacketTool)
$mapAuditPacketSource = Get-Content -Raw -LiteralPath $mapAuditPacketTool
Assert-True "map audit packet emits population flow table" ($mapAuditPacketSource -match '## Population Flow')
Assert-True "map audit packet emits camp and defense coordinates" ($mapAuditPacketSource -match '## Camps' -and $mapAuditPacketSource -match '## Town Defenses')
Assert-True "map audit packet emits base-axis sightline section" ($mapAuditPacketSource -match '## Base Axis And Sightlines' -and $mapAuditPacketSource -match 'central wall origin')
Assert-True "map audit packet emits base fortification footprint" ($mapAuditPacketSource -match 'baseFootprint \[35,45,74,78\]' -and $mapAuditPacketSource -match 'commander-clear radius')
Assert-True "map audit packet emits base static anchor table" ($mapAuditPacketSource -match 'Expected runtime position' -and $mapAuditPacketSource -match 'Base static runtime positions WEST \.\.\. EAST \.\.\.')
Assert-True "map audit packet emits rim test points" ($mapAuditPacketSource -match '## Rim Test Points' -and $mapAuditPacketSource -match 'West illegal rim' -and $mapAuditPacketSource -match 'East Farms legal rim')
Assert-True "map audit packet emits WDDM fortification review" ($mapAuditPacketSource -match '## WDDM Fortification Review' -and $mapAuditPacketSource -match 'https://rayswaynl\.github\.io/WDDM/' -and $mapAuditPacketSource -match '\+Y as front' -and $mapAuditPacketSource -match '\+X as right')
Assert-True "map audit packet emits Claude screenshot targets" ($mapAuditPacketSource -match '## Claude Screenshot Targets')
Assert-True "map audit packet emits central wall gap checkpoints" ($mapAuditPacketSource -match '4053,2725' -and $mapAuditPacketSource -match '2903,3915')
Assert-True "map audit packet emits uncrewed central wall focus" ($mapAuditPacketSource -match 'centralWallCrewed \[0\]' -and $mapAuditPacketSource -match 'uncrewed WDDM-compatible fortification')
$mapAuditPacketOutput = (& $mapAuditPacketTool) -join "`n"
Assert-True "map audit packet runs and reports Zargabad counts" ($mapAuditPacketOutput -match '# Zargabad Map Audit Packet' -and $mapAuditPacketOutput -match 'Counts: towns \[13\], camps \[19\], airports \[1\], starts \[9\], town defenses \[33\]')
Assert-True "map audit packet runs and reports core screenshot targets" ($mapAuditPacketOutput -match 'Zargabad City Center' -and $mapAuditPacketOutput -match 'Claude Screenshot Targets' -and $mapAuditPacketOutput -match '4053,2725' -and $mapAuditPacketOutput -match 'central wall origin' -and $mapAuditPacketOutput -match 'West illegal rim' -and $mapAuditPacketOutput -match 'East Farms legal rim' -and $mapAuditPacketOutput -match 'WDDM Fortification Review')
Assert-True "map audit packet runs and reports exact base static anchors" ($mapAuditPacketOutput -match 'TOW_TriPod_US_EP1' -and $mapAuditPacketOutput -match '1541,1591' -and $mapAuditPacketOutput -match 'Metis_TK_EP1' -and $mapAuditPacketOutput -match '5309,5159')
Assert-True "map audit packet runs and reports alternate start roles" ($mapAuditPacketOutput -match 'WEST alternate northwest road' -and $mapAuditPacketOutput -match 'EAST alternate south-east approach' -and $mapAuditPacketOutput -match 'Northern alternate airfield flank')
Assert-True "Claude brief tool exists" (Test-Path -LiteralPath $claudeBriefTool)
$claudeBriefSource = Get-Content -Raw -LiteralPath $claudeBriefTool
Assert-True "Claude brief tool emits coordination cadence" ($claudeBriefSource -match '## Coordination Cadence')
Assert-True "Claude brief tool requires post-commit updates" ($claudeBriefSource -match 'after every commit or material mission/tooling change')
Assert-True "Claude brief tool listens to evidence-backed findings" ($claudeBriefSource -match 'RPT excerpts, screenshots, coordinates, or repeatable repro steps')
Assert-True "Claude brief tool emits retest focus" ($claudeBriefSource -match '## Retest Focus')
Assert-True "Claude brief tool emits rim test point retest focus" ($claudeBriefSource -match 'rim test points')
Assert-True "Claude brief tool emits base footprint retest focus" ($claudeBriefSource -match 'baseFootprint evidence')
Assert-True "Claude brief tool emits WDDM review focus" ($claudeBriefSource -match 'WDDM fortification review' -and $claudeBriefSource -match 'https://rayswaynl\.github\.io/WDDM/')
Assert-True "Claude brief tool emits uncrewed wall retest focus" ($claudeBriefSource -match 'uncrewed central-wall evidence')
Assert-True "Claude brief tool emits mystery armed retest focus" ($claudeBriefSource -match 'Mystery feature: confirm the armed RPT line after town init')
Assert-True "Claude brief tool emits base static runtime position retest focus" ($claudeBriefSource -match 'Base statics: compare the Init_Zargabad base static runtime positions line' -and $claudeBriefSource -match 'Base static runtime positions WEST \.\.\. EAST \.\.\.')
Assert-True "Claude brief tool emits defense mix retest focus" ($claudeBriefSource -match 'Town defenses: retest priority defense mix arcs')
Assert-True "Claude brief tool carries stop/go ownership" ($claudeBriefSource -match 'Codex owns the stop/go call')
Assert-True "Claude brief tool points to map audit packet" ($claudeBriefSource -match 'New-ZargabadMapAuditPacket\.ps1')
Assert-True "Claude brief tool points to runtime report" ($claudeBriefSource -match 'New-ZargabadRuntimeReport\.ps1')
Assert-True "Claude brief tool points to runtime validator" ($claudeBriefSource -match 'Validate-ZargabadRuntimeEvidence\.ps1')
Assert-True "Claude brief tool points to runtime report validator" ($claudeBriefSource -match 'Validate-ZargabadRuntimeReport\.ps1')

$takistanZargabadModule = Resolve-RepoPath "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Module/Zargabad"
Assert-True "Takistan has no generated Zargabad module spillover" (-not (Test-Path -LiteralPath $takistanZargabadModule))

Write-Host ""
Write-Host "Zargabad town/SV summary:"
$parsedTowns | Sort-Object MaxSV -Descending | Format-Table Name, StartSV, MaxSV, Range, Camps, MinCampDistance, MaxCampDistance, Defenses, MinDefenseDistance, MaxDefenseDistance, X, Y -AutoSize
