param(
	[Parameter(Mandatory = $true)]
	[string]$ExperitalWorktree,

	[string]$OutputDir = "C:\WASP\pbo-staging",

	[string]$PboToolPath = "",

	[string]$MissionTitle = "WASP Experital TEST"
)

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
$missionSubfolder = "[55-2hc]warfarev2_073v48co.chernarus"
$sourceMission    = Join-Path $ExperitalWorktree "Missions\$missionSubfolder"

# PBO internal folder name must match MPMissions entry on the dedicated server.
# Arma 2 OA MPMissions PBOs are named  <InternalFolderName>.pbo  where the
# internal folder name is exactly what the server shows in rotation.
# We use a dedicated name so this PBO can coexist with the PR8 default PBO
# ([55-2hc]warfarev2_073v48co.chernarus.pbo).
$internalFolderName = "WASP_Experital_TEST.Chernarus"
$pboName            = "$internalFolderName.pbo"
$outputPboPath      = Join-Path $OutputDir $pboName

# ---------------------------------------------------------------------------
# Verify source
# ---------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $sourceMission)) {
	throw "Mission folder not found: $sourceMission"
}

# ---------------------------------------------------------------------------
# STEP 1 — Generate version.sqf (gitignored, required by description.ext)
# ---------------------------------------------------------------------------
# version.sqf is intentionally excluded from git (.gitignore) because the
# mission title and player-count differ per deployment context.
#
# !! WF_DEBUG MUST STAY COMMENTED FOR ANY SERVER DEPLOY (live-verified 2026-06-10):
# !! WF_DEBUG 1 = 900,000 starting funds/supply, EVERY unit's upgrade requirement
# !! stomped to level 1 (all heavy/air unlocked from the start), debug cheat menu +
# !! teleport, 5s respawns, 3s votes, AFK kick disabled. The main-repo local copy
# !! is a DEV copy - do not mirror it blindly. Production reference = the deployed
# !! PR8 mission's version.sqf on the box (both debug defines commented out).
# description.ext and initJIPCompatible.sqf both do #include "version.sqf"
# at preprocessor level — the PBO build ABORTS with "Include file not found"
# if this file is missing.
#
# Format confirmed from main repo reference (a2waspwarfare, 2026-06-10):
#   #define WF_DEBUG 1
#   #define WF_LOG_CONTENT
#   #define IS_CHERNARUS_MAP_DEPENDENT
#   #define IS_NAVAL_MAP
#   #define WF_MAXPLAYERS 55
#   #define WF_MISSIONNAME "..."
#   #define STARTING_DISTANCE 7500
#   #define COMBINEDOPS 1
#   #define WF_RESPAWNDELAY 2
#
# The pack script writes this file directly into the working copy of the
# source mission folder BEFORE handing it to cpbo.  The file is NOT committed.

$versionSqfPath = Join-Path $sourceMission "version.sqf"
Write-Host "Writing version.sqf: $versionSqfPath"

$versionContent = @"
// #define WF_DEBUG 1
// #define WF_LOG_CONTENT
#define IS_CHERNARUS_MAP_DEPENDENT
//#define IS_MOD_MAP_DEPENDENT
#define IS_NAVAL_MAP
//#define IS_AIR_WAR_EVENT
#define WF_MAXPLAYERS 55
#define WF_MISSIONNAME "$MissionTitle"
#define STARTING_DISTANCE 7500
#define COMBINEDOPS 1
#define WF_RESPAWNDELAY 2
"@

Set-Content -LiteralPath $versionSqfPath -Value $versionContent -Encoding ASCII
Write-Host "  version.sqf written (WF_MISSIONNAME = `"$MissionTitle`")"

# ---------------------------------------------------------------------------
# STEP 2 — Locate cpbo / armake2 / MakePbo
# ---------------------------------------------------------------------------
# The existing harness avoids hand-rolled PBOs for local installs (folder copy
# into MPMissions is enough for the Zwanon-profile local dedicated).  For the
# Hetzner dedicated server we do need an actual PBO because remote MPMissions
# expects packed files.
#
# Tool resolution order:
#   1. $PboToolPath param (operator can pass full path)
#   2. cpbo.exe  on PATH  (ships with BI Addon Builder / Arma Tools)
#   3. armake2.exe on PATH (open-source alternative)
#   4. MakePbo.exe on PATH (older BI tool)
#
# If none are found, the script prints clear install instructions and exits 1.

function Find-PboTool {
	param([string]$Explicit)
	if ($Explicit -ne "") {
		if (Test-Path -LiteralPath $Explicit) { return $Explicit }
		throw "Specified PboToolPath not found: $Explicit"
	}
	foreach ($candidate in @("cpbo.exe", "armake2.exe", "MakePbo.exe")) {
		$found = (Get-Command $candidate -ErrorAction SilentlyContinue)
		if ($found) { return $found.Source }
	}
	return $null
}

$pboTool = Find-PboTool $PboToolPath
if ($null -eq $pboTool) {
	Write-Host ""
	Write-Host "ERROR: No PBO packing tool found." -ForegroundColor Red
	Write-Host "Install one of the following and ensure it is on PATH (or pass -PboToolPath):"
	Write-Host "  cpbo.exe   — from BI Addon Builder (free, part of Arma Tools on Steam)"
	Write-Host "               Steam app ID 233800 (Arma 3 Tools) ships cpbo in"
	Write-Host "               'Arma 3 Tools\AddonBuilder\cpbo.exe'"
	Write-Host "  armake2    — https://github.com/KoffeinFlummi/armake2/releases"
	Write-Host "  MakePbo    — from BI Tools 2 (legacy, but works for A2)"
	Write-Host ""
	Write-Host "Quick path addition (session only):"
	Write-Host '  $env:PATH += ";C:\path\to\tool\folder"'
	exit 1
}

$toolName = [System.IO.Path]::GetFileNameWithoutExtension($pboTool).ToLower()
Write-Host "PBO tool: $pboTool ($toolName)"

# ---------------------------------------------------------------------------
# STEP 3 — Create a staging copy with the correct internal folder name
# ---------------------------------------------------------------------------
# Arma 2 OA requires that the folder packed INTO the PBO matches the PBO's
# base name (minus extension).  We stage a temporary copy named
# WASP_Experital_TEST.Chernarus so cpbo packs it with the right identity.
# The source folder is [55-2hc]warfarev2_073v48co.chernarus (the standard
# mission folder with the bracket prefix).

$stagingParent = Join-Path $env:TEMP "WaspExperitalPack"
$stagingMission = Join-Path $stagingParent $internalFolderName

if (Test-Path -LiteralPath $stagingMission) {
	Remove-Item -LiteralPath $stagingMission -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $stagingParent | Out-Null

Write-Host "Staging mission to: $stagingMission"
Copy-Item -LiteralPath $sourceMission -Destination $stagingMission -Recurse -Force

# ---------------------------------------------------------------------------
# STEP 4 — Pack
# ---------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $OutputDir)) {
	New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
}

if (Test-Path -LiteralPath $outputPboPath) {
	Remove-Item -LiteralPath $outputPboPath -Force
}

Write-Host "Packing: $stagingMission -> $outputPboPath"

switch ($toolName) {
	"cpbo" {
		# cpbo -P <source_folder> <output.pbo>
		& $pboTool -P $stagingMission $outputPboPath
	}
	"armake2" {
		# armake2 pack <source_folder> <output.pbo>
		& $pboTool pack $stagingMission $outputPboPath
	}
	"makepbo" {
		# MakePbo <source_folder> <output_directory>
		# MakePbo writes <FolderName>.pbo into the output directory.
		& $pboTool $stagingMission $OutputDir
		$makePboOut = Join-Path $OutputDir "$internalFolderName.pbo"
		if ((Test-Path -LiteralPath $makePboOut) -and ($makePboOut -ne $outputPboPath)) {
			Move-Item -LiteralPath $makePboOut -Destination $outputPboPath -Force
		}
	}
	default {
		throw "Unknown tool '$toolName' — update the switch block in Pack-WaspExperital.ps1"
	}
}

if ($LASTEXITCODE -ne 0) {
	throw "PBO tool exited with code $LASTEXITCODE"
}

# ---------------------------------------------------------------------------
# STEP 5 — Verify and clean up staging
# ---------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $outputPboPath)) {
	throw "PBO not found at expected output path: $outputPboPath"
}

$pboSize = (Get-Item -LiteralPath $outputPboPath).Length
Write-Host ""
Write-Host "Pack complete." -ForegroundColor Green
Write-Host "  PBO:       $outputPboPath"
Write-Host "  Size:      $([math]::Round($pboSize / 1024)) KB"
Write-Host "  Internal:  $internalFolderName"
Write-Host "  Title:     $MissionTitle"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Run Smoke-ExperitalClasscheck.sqf checks (see Experital\Smoke-ExperitalClasscheck.sqf)"
Write-Host "  2. Local dedicated boot smoke (see DEPLOY-EXPERITAL.md)"
Write-Host "  3. Copy $pboName to Hetzner MPMissions (see DEPLOY-EXPERITAL.md)"

Remove-Item -LiteralPath $stagingMission -Recurse -Force -ErrorAction SilentlyContinue
