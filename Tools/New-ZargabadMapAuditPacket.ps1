param(
	[string]$MissionPath = "Missions_Vanilla/[31-2hc]warfarev2_073v48co.zargabad",
	[string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"

function Resolve-RepoPath {
	param([string]$Path)
	$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
	return Join-Path $root $Path
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

function Get-PositionText {
	param($Object)
	return "{0},{1}" -f [math]::Round($Object.X), [math]::Round($Object.Y)
}

function Get-MissionObjects {
	param([string]$SqmPath)
	$objects = @()
	$current = $null
	foreach ($line in Get-Content -LiteralPath $SqmPath) {
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
	return @($objects)
}

function Get-TownInfo {
	param($Town, $Camps, $Defenses)
	$match = [regex]::Match($Town.Init, '\[this,""(?<name>[^""]+)"",.*?,(?<start>\d+),(?<max>\d+),(?<range>\d+),')
	if (-not $match.Success) { throw "Could not parse town init for id [$($Town.Id)]" }
	$campLinks = @($Camps | Where-Object { $_.Sync -contains $Town.Id })
	$defenseLinks = @($Defenses | Where-Object { $_.Sync -contains $Town.Id })
	[pscustomobject]@{
		Id = $Town.Id
		Name = $match.Groups["name"].Value
		StartSV = [int]$match.Groups["start"].Value
		MaxSV = [int]$match.Groups["max"].Value
		Range = [int]$match.Groups["range"].Value
		Camps = $campLinks
		Defenses = $defenseLinks
		X = $Town.X
		Y = $Town.Y
	}
}

function Get-DefenseKind {
	param($Defense)
	$matches = [regex]::Matches($Defense.Init, "['""]([^'""]+)['""]")
	$kinds = @($matches | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ -ne "wfbe_defense_kind" })
	if ($kinds.Count -eq 0) { return "unknown" }
	return ($kinds -join "+")
}

function Get-SqfTemplateEntries {
	param([string]$Content, [string]$VariableName)
	$pattern = [regex]::Escape($VariableName) + '\s*=\s*\[(?<body>[\s\S]*?)\];'
	$match = [regex]::Match($Content, $pattern)
	if (-not $match.Success) { return @() }
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

function Get-WorldPointFromTemplateOffset {
	param($Origin, [double]$Dir, [int]$OffsetX, [int]$OffsetY)
	$radians = $Dir * [math]::PI / 180
	return [pscustomobject]@{
		X = [int][math]::Round($Origin.X + ($OffsetX * [math]::Cos($radians)) + ($OffsetY * [math]::Sin($radians)))
		Y = [int][math]::Round($Origin.Y - ($OffsetX * [math]::Sin($radians)) + ($OffsetY * [math]::Cos($radians)))
	}
}

function Get-TemplateRuntimeAnchors {
	param([string]$Side, $Origin, [double]$Dir, [object[]]$Template)
	return @($Template | ForEach-Object {
		$point = Get-WorldPointFromTemplateOffset -Origin $Origin -Dir $Dir -OffsetX $_.X -OffsetY $_.Y
		[pscustomobject]@{
			Side = $Side
			Class = $_.Class
			X = $point.X
			Y = $point.Y
			Dir = [int][math]::Round(($Dir + $_.Dir) % 360)
			Offset = "$($_.X),$($_.Y)"
		}
	})
}

$missionFullPath = Resolve-RepoPath $MissionPath
$sqmPath = Join-Path $missionFullPath "mission.sqm"
if (-not (Test-Path -LiteralPath $sqmPath)) { throw "mission.sqm not found: $sqmPath" }

$objects = Get-MissionObjects $sqmPath
$towns = @($objects | Where-Object { $_.Vehicle -eq "LocationLogicDepot" })
$camps = @($objects | Where-Object { $_.Vehicle -eq "LocationLogicCamp" })
$airports = @($objects | Where-Object { $_.Vehicle -eq "LocationLogicAirport" })
$starts = @($objects | Where-Object { $_.Vehicle -eq "LocationLogicStart" })
$defenses = @($objects | Where-Object { $_.Vehicle -eq "Logic" -and $_.Init -like "*wfbe_defense_kind*" })
$parsedTowns = @($towns | ForEach-Object { Get-TownInfo -Town $_ -Camps $camps -Defenses $defenses })
$westStart = @($starts | Where-Object { $_.Init -match 'wfbe_default"",\s*west' } | Select-Object -First 1)
$eastStart = @($starts | Where-Object { $_.Init -match 'wfbe_default"",\s*east' } | Select-Object -First 1)
$initZargabadPath = Join-Path $missionFullPath "Server/Init/Init_Zargabad.sqf"
$baseStaticAnchors = @()
if ((Test-Path -LiteralPath $initZargabadPath) -and $westStart.Count -gt 0 -and $eastStart.Count -gt 0) {
	$initZargabad = Get-Content -Raw -LiteralPath $initZargabadPath
	$baseStaticAnchors += Get-TemplateRuntimeAnchors -Side "WEST" -Origin $westStart[0] -Dir 45 -Template (Get-SqfTemplateEntries -Content $initZargabad -VariableName "_westStatics")
	$baseStaticAnchors += Get-TemplateRuntimeAnchors -Side "EAST" -Origin $eastStart[0] -Dir 225 -Template (Get-SqfTemplateEntries -Content $initZargabad -VariableName "_eastStatics")
}

$report = New-Object System.Collections.Generic.List[string]
$report.Add("# Zargabad Map Audit Packet")
$report.Add("")
$report.Add("- Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')")
$report.Add("- Mission: ``$MissionPath``")
$report.Add("- Source: ``$sqmPath``")
$report.Add("- Counts: towns [$($towns.Count)], camps [$($camps.Count)], airports [$($airports.Count)], starts [$($starts.Count)], town defenses [$($defenses.Count)]")
$report.Add("- SV totals: start [$((@($parsedTowns | Measure-Object -Property StartSV -Sum).Sum))], max [$((@($parsedTowns | Measure-Object -Property MaxSV -Sum).Sum))]")
$report.Add("")
$report.Add("## Population Flow")
$report.Add("")
$report.Add("| Objective | Position | Start SV | Max SV | Range | Camps | Defenses | Intent |")
$report.Add("| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |")
foreach ($town in ($parsedTowns | Sort-Object @{Expression = "MaxSV"; Descending = $true}, Name)) {
	$intent = if ($town.MaxSV -ge 75) { "primary population/value anchor" } elseif ($town.MaxSV -ge 50) { "district or market approach" } else { "lower-value flank route" }
	$report.Add("| $($town.Name) | ``$(Get-PositionText $town)`` | $($town.StartSV) | $($town.MaxSV) | $($town.Range) | $($town.Camps.Count) | $($town.Defenses.Count) | $intent |")
}
$report.Add("")
$report.Add("## Camps")
$report.Add("")
$report.Add("| Camp id | Position | Linked town | Distance |")
$report.Add("| ---: | ---: | --- | ---: |")
foreach ($camp in ($camps | Sort-Object Y, X)) {
	$town = @($parsedTowns | Where-Object { $camp.Sync -contains $_.Id } | Select-Object -First 1)
	$distance = if ($town.Count -gt 0) { [math]::Round((Get-FlatDistance $camp $town[0]), 1) } else { -1 }
	$townName = if ($town.Count -gt 0) { $town[0].Name } else { "unlinked" }
	$report.Add("| $($camp.Id) | ``$(Get-PositionText $camp)`` | $townName | $distance |")
}
$report.Add("")
$report.Add("## Town Defenses")
$report.Add("")
$report.Add("| Linked town | Defense id | Kind | Position | Distance | Runtime facing |")
$report.Add("| --- | ---: | --- | ---: | ---: | --- |")
foreach ($town in ($parsedTowns | Sort-Object Name)) {
	foreach ($defense in ($town.Defenses | Sort-Object Id)) {
		$distance = [math]::Round((Get-FlatDistance $defense $town), 1)
		$report.Add("| $($town.Name) | $($defense.Id) | $(Get-DefenseKind $defense) | ``$(Get-PositionText $defense)`` | $distance | toward linked town center |")
	}
}
$report.Add("")
$report.Add("## Starts And Edge Safety")
$report.Add("")
$report.Add("| Start id | Side hint | Position | Azimut | Edge distance |")
$report.Add("| ---: | --- | ---: | ---: | ---: |")
foreach ($start in ($starts | Sort-Object Y, X)) {
	$side = if ($start.Init -match 'wfbe_default"",\s*(west|east|resistance)') { $Matches[1].ToUpperInvariant() } else { "alternate" }
	$azimut = if ($null -ne $start.Azimut) { [math]::Round($start.Azimut, 1) } else { "" }
	$report.Add("| $($start.Id) | $side | ``$(Get-PositionText $start)`` | $azimut | $([math]::Round((Get-EdgeDistance $start 6000), 1)) |")
}
$report.Add("")
$report.Add("## Base Axis And Sightlines")
$report.Add("")
if ($westStart.Count -gt 0 -and $eastStart.Count -gt 0) {
	$baseDistance = [math]::Round((Get-FlatDistance $westStart[0] $eastStart[0]))
	$midX = [math]::Round(($westStart[0].X + $eastStart[0].X) / 2)
	$midY = [math]::Round(($westStart[0].Y + $eastStart[0].Y) / 2)
	$report.Add("- WEST default start: ``$(Get-PositionText $westStart[0])``; EAST default start: ``$(Get-PositionText $eastStart[0])``; flat distance: [$baseDistance]m.")
	$report.Add("- Direct base-axis midpoint: ``$midX,$midY``; central wall origin: ``3425,3375``. These intentionally overlap so the wall interrupts the flat southwest-to-northeast sightline.")
	$report.Add("- Claude should screenshot from each default start toward ``3425,3375`` and from the wall origin back toward both starts, then mark whether fortifications and terrain block trivial spawn pressure.")
	$report.Add("- Base fortification runtime audit should report ``baseFootprint [35,45,74,78]``: commander-clear radius 35m, nearest base static 45m, H-barrier ring 74m-78m from the start logic.")
	if ($baseStaticAnchors.Count -gt 0) {
		$report.Add("")
		$report.Add("| Side | Static | Expected runtime position | Expected facing | Template offset |")
		$report.Add("| --- | --- | ---: | ---: | ---: |")
		foreach ($anchor in $baseStaticAnchors) {
			$report.Add("| $($anchor.Side) | $($anchor.Class) | ``$($anchor.X),$($anchor.Y)`` | $($anchor.Dir) | ``$($anchor.Offset)`` |")
		}
		$report.Add("")
		$report.Add("- Compare these expected anchors against the runtime ``Base static runtime positions WEST ... EAST ...`` RPT line and screenshots before judging base arcs or construction space.")
	}
} else {
	$report.Add("- Default WEST/EAST starts were not found in mission.sqm.")
}
$safeObjects = @($towns) + @($camps) + @($airports) + @($starts)
$edgeSafe = @($safeObjects | Where-Object { (Get-EdgeDistance $_ 6000) -le 325 } | Sort-Object Y, X)
$rimTests = @(
	[pscustomobject]@{ Name = "West illegal rim"; X = 80; Y = 3000; Expected = "remove"; Reason = "outer west rim away from objective safe bubbles" },
	[pscustomobject]@{ Name = "South illegal rim"; X = 3000; Y = 80; Expected = "remove"; Reason = "outer south rim away from objective safe bubbles" },
	[pscustomobject]@{ Name = "East illegal rim"; X = 5900; Y = 3000; Expected = "remove"; Reason = "outer east rim away from East Farms safe bubble" },
	[pscustomobject]@{ Name = "North illegal rim"; X = 3000; Y = 5900; Expected = "remove"; Reason = "outer north rim between legal objective bubbles" },
	[pscustomobject]@{ Name = "North Camp legal rim"; X = 3600; Y = 5900; Expected = "allow"; Reason = "inside North Camp camp safe bubble" },
	[pscustomobject]@{ Name = "Rahim Villa legal rim"; X = 4330; Y = 5900; Expected = "allow"; Reason = "inside Rahim Villa camp safe bubble" },
	[pscustomobject]@{ Name = "East Farms legal rim"; X = 5900; Y = 4340; Expected = "allow"; Reason = "inside East Farms camp safe bubble" }
)
$report.Add("")
$report.Add("Edge-safe objective/start bubbles within 325m of the 6000m border:")
foreach ($logic in $edgeSafe) {
	$name = if ($logic.Vehicle -eq "LocationLogicDepot") { (@($parsedTowns | Where-Object { $_.Id -eq $logic.Id })[0]).Name } else { $logic.Vehicle }
	$report.Add("- $name id [$($logic.Id)] at ``$(Get-PositionText $logic)``, edge distance [$([math]::Round((Get-EdgeDistance $logic 6000), 1))].")
}
$report.Add("")
$report.Add("## Rim Test Points")
$report.Add("")
$report.Add("| Point | Position | Expected | Edge distance | Nearest safe distance | Reason |")
$report.Add("| --- | ---: | --- | ---: | ---: | --- |")
foreach ($point in $rimTests) {
	$nearest = @($safeObjects | ForEach-Object { [pscustomobject]@{ Logic = $_; Distance = [math]::Round((Get-FlatDistance $point $_), 1) } } | Sort-Object Distance | Select-Object -First 1)[0]
	$report.Add("| $($point.Name) | ``$($point.X),$($point.Y)`` | $($point.Expected) | $([math]::Round((Get-EdgeDistance $point 6000), 1)) | $($nearest.Distance) | $($point.Reason) |")
}
$report.Add("")
$report.Add("## Central Wall")
$report.Add("")
$report.Add("- Origin: `3425,3375`; direction: `316`; runtime audit requires 60 H-barrier pieces and `centralWallCrewed [0]`.")
$report.Add("- Intent: uncrewed WDDM-compatible fortification only; it should interrupt flat-map sightlines without adding an armed middle-map kill strip.")
$report.Add("- Gap checkpoints for Claude to walk, drive and screenshot: `4053,2725`, `3789,2998`, `3504,3293`, `3195,3613`, `2903,3915`.")
$report.Add("")
$report.Add("## WDDM Fortification Review")
$report.Add("")
$report.Add("- Use Steff's WDDM tool for proposed wall/base edits: https://rayswaynl.github.io/WDDM/")
$report.Add("- WDDM/``CreateDefenseTemplate`` coordinates are relative to the origin with +Y as front and +X as right; use the template direction as the facing reference.")
$report.Add("- Current central wall WDDM anchor: origin `3425,3375,0`, direction `316`, six H-barrier spans, five pass-through gaps, no crewed weapon pieces.")
$report.Add("- Current base fortification audit target: ``baseFootprint [35,45,74,78]``; preserve commander-clear space before adding more wall or static coverage.")
$report.Add("- Claude should paste any WDDM-exported SQF or coordinate deltas back with screenshots/RPT evidence before Codex changes the template.")
$report.Add("")
$report.Add("## Claude Screenshot Targets")
$report.Add("")
$report.Add("- WEST default start `1500,1550` and EAST default start `5350,5200`: capture spawn-to-spawn and spawn-to-city sightline notes.")
$report.Add("- WEST/EAST base interiors: compare runtime ``baseFootprint [35,45,74,78]`` against screenshots for commander-clear space, static placement, and H-barrier cover.")
$report.Add("- Base-axis midpoint `3425,3375`: screenshot toward both default starts and toward city routes.")
$report.Add("- City/airfield high-value flow: `4075,3950` and `2980,5200`, including their two camp approaches.")
$report.Add("- Central wall gap checkpoints listed above, tested with infantry, light armor and AI pathing.")
$report.Add("- Rim test points listed above: removal points should log `Zargabad_EdgeGuard.sqf: ... removed from edge rim`, while legal points should allow objective-side fights without removal.")
$report.Add("- Any defense row above that faces the wrong route, blocks movement, or spawns on unusable terrain.")

$reportText = $report -join "`r`n"
if ($OutputPath.Trim().Length -gt 0) {
	$parent = Split-Path -Parent $OutputPath
	if ($parent -and -not (Test-Path -LiteralPath $parent)) {
		New-Item -ItemType Directory -Path $parent | Out-Null
	}
	Set-Content -LiteralPath $OutputPath -Value $reportText -Encoding UTF8
	Write-Host "Wrote Zargabad map audit packet: $OutputPath"
} else {
	$reportText
}
