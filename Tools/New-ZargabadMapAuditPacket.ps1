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
$safeObjects = @($towns) + @($camps) + @($airports) + @($starts)
$edgeSafe = @($safeObjects | Where-Object { (Get-EdgeDistance $_ 6000) -le 325 } | Sort-Object Y, X)
$report.Add("")
$report.Add("Edge-safe objective/start bubbles within 325m of the 6000m border:")
foreach ($logic in $edgeSafe) {
	$name = if ($logic.Vehicle -eq "LocationLogicDepot") { (@($parsedTowns | Where-Object { $_.Id -eq $logic.Id })[0]).Name } else { $logic.Vehicle }
	$report.Add("- $name id [$($logic.Id)] at ``$(Get-PositionText $logic)``, edge distance [$([math]::Round((Get-EdgeDistance $logic 6000), 1))].")
}
$report.Add("")
$report.Add("## Central Wall")
$report.Add("")
$report.Add("- Origin: `3425,3375`; direction: `316`; runtime audit requires 60 H-barrier pieces.")
$report.Add("- Gap checkpoints for Claude to walk, drive and screenshot: `4053,2725`, `3789,2998`, `3504,3293`, `3195,3613`, `2903,3915`.")
$report.Add("")
$report.Add("## Claude Screenshot Targets")
$report.Add("")
$report.Add("- WEST default start `1500,1550` and EAST default start `5350,5200`: capture spawn-to-spawn and spawn-to-city sightline notes.")
$report.Add("- City/airfield high-value flow: `4075,3950` and `2980,5200`, including their two camp approaches.")
$report.Add("- Central wall gap checkpoints listed above, tested with infantry, light armor and AI pathing.")
$report.Add("- Edge-safe north/east objectives listed above, especially any place that still permits unfair side-hill overwatch.")
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
