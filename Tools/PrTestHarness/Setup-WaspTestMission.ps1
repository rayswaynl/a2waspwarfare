<#
.SYNOPSIS
	Get a WASP Warfare release build ready to play-test on this PC.

.DESCRIPTION
	1. Finds the repo root.
	2. Runs Tools\LoadoutManager (regenerates Chernarus -> Takistan and writes the
	   required generated `version.sqf` into both mission folders).
	3. Verifies the Chernarus `version.sqf` was produced.
	4. Copies the Chernarus mission folder into your Arma 2 OA MPMissions folder so you
	   can host it from the in-game multiplayer browser.

	Requirements on this PC: .NET SDK (`dotnet`) for LoadoutManager, and Arma 2:
	Operation Arrowhead installed. 7-Zip (`7za`) is optional — without it the mission is
	still generated/copied; only the `_MISSIONS.7z` server package is skipped.

.EXAMPLE
	pwsh Tools\PrTestHarness\Setup-WaspTestMission.ps1
	pwsh Tools\PrTestHarness\Setup-WaspTestMission.ps1 -MpMissions "D:\Games\ArmA 2 OA\MPMissions"
	pwsh Tools\PrTestHarness\Setup-WaspTestMission.ps1 -SkipPack   # don't even attempt the 7z pack
#>
param(
	[string]$MpMissions = "",
	[switch]$SkipPack
)
$ErrorActionPreference = "Stop"

# --- 1. find repo root (marker: Missions\...chernarus + Tools\LoadoutManager + AGENTS.md) ---
$dir = [System.IO.DirectoryInfo](Resolve-Path $PSScriptRoot)
$missionRel = "Missions\[55-2hc]warfarev2_073v48co.chernarus"
while ($dir -ne $null) {
	if ((Test-Path -LiteralPath (Join-Path $dir.FullName $missionRel)) -and
		(Test-Path -LiteralPath (Join-Path $dir.FullName "Tools\LoadoutManager")) -and
		(Test-Path -LiteralPath (Join-Path $dir.FullName "AGENTS.md"))) { break }
	$dir = $dir.Parent
}
if ($dir -eq $null) { throw "Could not find the repo root (need Missions\...chernarus + Tools\LoadoutManager + AGENTS.md above this script)." }
$repo = $dir.FullName
$cher = Join-Path $repo $missionRel
Write-Host "Repo root: $repo" -ForegroundColor Cyan

# --- 2. run LoadoutManager (regen + generate version.sqf) ---
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
	throw "dotnet (.NET SDK) is not on PATH. Install it, or run LoadoutManager manually, then re-run with the copy step."
}
if ($SkipPack) { $env:A2WASP_SKIP_ZIP = "1"; Write-Host "Packing disabled (A2WASP_SKIP_ZIP=1)." -ForegroundColor DarkGray }
Write-Host "Running LoadoutManager (regen Chernarus -> Takistan + version.sqf)..." -ForegroundColor Cyan
Push-Location $repo
try { & dotnet run --project "Tools\LoadoutManager\LoadoutManager.csproj" }
finally { Pop-Location }

# --- 3. verify the generated boot input ---
$ver = Join-Path $cher "version.sqf"
if (-not (Test-Path -LiteralPath $ver)) {
	throw "LoadoutManager finished but $ver was not generated. The mission will not boot without it — check the LoadoutManager output above."
}
Write-Host "version.sqf generated OK." -ForegroundColor Green

# --- 4. resolve the MPMissions target ---
if ([string]::IsNullOrWhiteSpace($MpMissions)) {
	$candidates = @(
		(Join-Path $env:USERPROFILE "Documents\ArmA 2 OA\MPMissions"),
		(Join-Path $env:USERPROFILE "Documents\ArmA 2\MPMissions")
	)
	$MpMissions = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
	if (-not $MpMissions) {
		Write-Host "Could not auto-detect an MPMissions folder. Mission is generated at:" -ForegroundColor Yellow
		Write-Host "  $cher" -ForegroundColor Yellow
		Write-Host "Re-run with -MpMissions '<your Arma MPMissions path>' to auto-copy, or copy that folder there yourself." -ForegroundColor Yellow
		return
	}
}
$dest = Join-Path $MpMissions (Split-Path $cher -Leaf)
Write-Host "Copying mission -> $dest" -ForegroundColor Cyan
Copy-Item -LiteralPath $cher -Destination $MpMissions -Recurse -Force

Write-Host "`nReady. In Arma 2: Operation Arrowhead:" -ForegroundColor Green
Write-Host "  Multiplayer -> New -> (host LAN/internet) -> map Chernarus -> the [55-2hc] Warfare mission -> Play." -ForegroundColor Green
Write-Host "Test focus (June finalize): WF-menu GPS button shows the mini-map; commander build menu shows the" -ForegroundColor DarkGray
Write-Host "AA/Artillery/Mixed Light+Heavy positions (+ build them); buy a crewless/Depot vehicle (must cost money," -ForegroundColor DarkGray
Write-Host "not be free); officer skill menu + respawn screen have no MASH entries." -ForegroundColor DarkGray
