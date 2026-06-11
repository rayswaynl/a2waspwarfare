param(
	[Parameter(Mandatory = $true)]
	[string]$SourceMissionRoot,

	[Parameter(Mandatory = $true)]
	[string]$DestinationMissionRoot,

	[string]$Overlay = "pr8-stress",
	[string]$MissionTitle = "TEST PR Stress",
	[string]$HcCachePath = "",
	[switch]$Force,
	[switch]$ClearHcCache
)

$ErrorActionPreference = "Stop"

function Resolve-OrCreateParent {
	param([string]$Path)
	$parent = Split-Path -Parent $Path
	if (-not (Test-Path -LiteralPath $parent)) {
		New-Item -ItemType Directory -Force -Path $parent | Out-Null
	}
	(Resolve-Path -LiteralPath $parent).Path
}

function Assert-SafeMissionDestination {
	param([string]$Path)
	$parent = Resolve-OrCreateParent $Path
	$leaf = Split-Path -Leaf $Path
	if ([string]::IsNullOrWhiteSpace($leaf)) {
		throw "DestinationMissionRoot must include a mission folder name."
	}
	if ($parent -notmatch "(?i)\\MPMissions$") {
		throw "Destination parent must be an MPMissions folder: $parent"
	}
	Join-Path $parent $leaf
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$overlayRoot = Join-Path $scriptRoot "Overlays\$Overlay"
if (-not (Test-Path -LiteralPath $overlayRoot)) {
	throw "Unknown overlay '$Overlay'. Expected folder: $overlayRoot"
}

$source = (Resolve-Path -LiteralPath $SourceMissionRoot).Path
$destination = Assert-SafeMissionDestination $DestinationMissionRoot

if (Test-Path -LiteralPath $destination) {
	if (-not $Force) {
		throw "Destination already exists. Re-run with -Force to replace it: $destination"
	}
	$resolvedDestination = (Resolve-Path -LiteralPath $destination).Path
	if ($resolvedDestination -notmatch "(?i)\\MPMissions\\[^\\]+$") {
		throw "Refusing to remove unsafe destination: $resolvedDestination"
	}
	Remove-Item -LiteralPath $resolvedDestination -Recurse -Force
}

Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force
Copy-Item -LiteralPath (Join-Path $overlayRoot "init.sqf") -Destination (Join-Path $destination "init.sqf") -Force

$destTest = Join-Path $destination "test"
if (Test-Path -LiteralPath $destTest) {
	$resolvedTest = (Resolve-Path -LiteralPath $destTest).Path
	if ($resolvedTest -notmatch "(?i)\\MPMissions\\[^\\]+\\test$") {
		throw "Refusing to remove unsafe test folder: $resolvedTest"
	}
	Remove-Item -LiteralPath $resolvedTest -Recurse -Force
}
Copy-Item -LiteralPath (Join-Path $overlayRoot "test") -Destination $destTest -Recurse -Force

if ($MissionTitle -ne "") {
	$missionSqm = Join-Path $destination "mission.sqm"
	if (Test-Path -LiteralPath $missionSqm) {
		$text = Get-Content -Raw -LiteralPath $missionSqm
		$text = $text -replace 'briefingName="[^"]*";', "briefingName=`"$MissionTitle`";"
		$text = $text -replace 'briefingDescription="[^"]*";', 'briefingDescription="Auto-starts WASP-PR8-STRESS: FPS, HC, AI behavior, supply, WDDM, service/EASA checks.";'
		Set-Content -LiteralPath $missionSqm -Value $text -Encoding ASCII
	}

	$version = Join-Path $destination "version.sqf"
	if (Test-Path -LiteralPath $version) {
		$text = Get-Content -Raw -LiteralPath $version
		$text = $text -replace '#define WF_MISSIONNAME "[^"]*"', "#define WF_MISSIONNAME `"$MissionTitle`""
		Set-Content -LiteralPath $version -Value $text -Encoding ASCII
	}

	$briefing = Join-Path $destination "briefing.html"
	if (Test-Path -LiteralPath $briefing) {
		$text = Get-Content -Raw -LiteralPath $briefing
		$text = $text -replace "(?is)<title>.*?</title>", "<title>$MissionTitle</title>"
		Set-Content -LiteralPath $briefing -Value $text -Encoding ASCII
	}
}

if ($ClearHcCache -and $HcCachePath -ne "") {
	if (Test-Path -LiteralPath $HcCachePath) {
		Remove-Item -LiteralPath $HcCachePath -Force
	}
}

Write-Host "Installed WASP PR test harness"
Write-Host "source:      $source"
Write-Host "destination: $destination"
Write-Host "overlay:     $Overlay"
Write-Host "title:       $MissionTitle"
