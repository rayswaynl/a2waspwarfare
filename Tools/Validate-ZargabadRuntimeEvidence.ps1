param(
	[Parameter(Mandatory = $true)]
	[string[]]$RptPath,
	[switch]$RequireJip,
	[switch]$RequireHeadlessClient,
	[switch]$RequireEdgeGuardRemoval,
	[switch]$RequireBlackMarket,
	[switch]$AllowKnownDisconnectScoreErrors
)

$ErrorActionPreference = "Stop"

function Get-RptFiles {
	param([string[]]$Paths)
	$files = @()
	foreach ($path in $Paths) {
		if (Test-Path -LiteralPath $path -PathType Container) {
			$files += Get-ChildItem -LiteralPath $path -Recurse -File -Filter "*.rpt"
			continue
		}
		if (Test-Path -LiteralPath $path -PathType Leaf) {
			$files += Get-Item -LiteralPath $path
			continue
		}
		throw "RPT path not found: $path"
	}
	return @($files | Sort-Object FullName -Unique)
}

function Assert-Pattern {
	param([string]$Name, [string]$Content, [string]$Pattern)
	if ($Content -notmatch $Pattern) {
		throw "Missing runtime evidence: $Name"
	}
	Write-Host "ok - $Name"
}

function Assert-NoPattern {
	param([string]$Name, [string]$Content, [string]$Pattern)
	$matches = [regex]::Matches($Content, $Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
	if ($matches.Count -gt 0) {
		$sample = ($matches | Select-Object -First 5 | ForEach-Object { $_.Value.Trim() }) -join " | "
		throw "Runtime failure pattern found: $Name :: $sample"
	}
	Write-Host "ok - no $Name"
}

$files = Get-RptFiles $RptPath
if ($files.Count -eq 0) {
	throw "No RPT files found"
}

Write-Host "Inspecting RPT evidence:"
$files | ForEach-Object { Write-Host " - $($_.FullName)" }

$content = ($files | ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName }) -join "`n"
if ($AllowKnownDisconnectScoreErrors) {
	$content = [regex]::Replace($content, 'Server_PlayerDisconnected\.sqf: Player \[[^\r\n]+has no score to be saved upon disconnection[^\r\n]*', '')
	$content = [regex]::Replace($content, 'Server_PlayerDisconnected\.sqf: Player \[[^\r\n]+has disconnected[^\r\n]*', '')
}

Assert-Pattern "Zargabad mission/world appears in RPT" $content '(?i)zargabad'
Assert-Pattern "server initialization begins" $content 'Init_Server\.sqf: Server initialization begins'
Assert-Pattern "town starting mode completes" $content 'Init_Server\.sqf: Town starting mode is done'
Assert-Pattern "Zargabad fortifications and central wall init runs" $content 'Init_Zargabad\.sqf: Spawn fortifications, central wall gaps, and side defenses are placed'
Assert-Pattern "Zargabad town defense logic orientation runs" $content 'Init_Zargabad\.sqf: Oriented \[33\] town defense logics toward linked town centers'
Assert-Pattern "Zargabad edge guard initializes" $content 'Zargabad_EdgeGuard\.sqf: outer \[[0-9]+\]m rim timeout \[[0-9]+\]s safe range \[[0-9]+\]m'
Assert-Pattern "runtime audit reports town/camp/airport/defense and SV totals" $content 'Zargabad_RuntimeAudit\.sqf: towns \[13\] camps \[19\] airports \[1\] defenses \[33\] startSV \[185\] maxSV \[648\]'
Assert-Pattern "runtime audit reports Zargabad base and fortification counts" $content 'Zargabad_RuntimeAudit\.sqf: bases WEST .* EAST .* distance \[[0-9]+\] westStatic \[4\] eastStatic \[4\] baseWalls \[13\] centralWallPieces \[60\] centralWallOrigin \[3425,3375\] centralWallDir \[316\] centralWallGaps .*4053.*2725.*3789.*2998.*3504.*3293.*3195.*3613.*2903.*3915'
Assert-Pattern "runtime audit reports Zargabad base static templates" $content 'Zargabad_RuntimeAudit\.sqf: baseStaticTemplates WEST .*M2StaticMG_US_EP1.*TOW_TriPod_US_EP1.*Stinger_Pod_US_EP1.* EAST .*KORD_high_TK_EP1.*Metis_TK_EP1.*Igla_AA_pod_TK_EP1'
Assert-Pattern "runtime evidence reports Zargabad base static runtime positions" $content 'Init_Zargabad\.sqf: Base static runtime positions WEST .*M2StaticMG_US_EP1.*TOW_TriPod_US_EP1.*Stinger_Pod_US_EP1.* EAST .*KORD_high_TK_EP1.*Metis_TK_EP1.*Igla_AA_pod_TK_EP1'
Assert-Pattern "runtime audit reports Zargabad economy and range constants" $content 'Zargabad_RuntimeAudit\.sqf: economy supplyCap \[[0-9]+\] teamSupplyCap \[30000\] fastTravelMax \[1800\] respawnCampRange \[400\].*supportRange \[55\].*baseDefenseAI \[56\] baseDefenseRange \[500\] edgeGuard \[120,325,45\] weapons missileRange \[2000\] uavRange \[800\] townRanges \[45,500,350\] purchaseHangar \[35\] countermeasures \[16,24\]'
Assert-Pattern "runtime audit reports Zargabad factory restrictions" $content 'Zargabad_RuntimeAudit\.sqf: factoryCounts WEST L/H/A/AP \[[0-9]+,3,7,2\] EAST L/H/A/AP \[[0-9]+,4,3,3\] forbiddenNormal \[\]'
Assert-Pattern "runtime audit reports exact Zargabad compact factory lists" $content 'Zargabad_RuntimeAudit\.sqf: factoryLists WEST H .*M2A2_EP1.*M2A3_EP1.*BAF_FV510_D.* A .*MH6J_EP1.*UH60M_EP1.*UH60M_MEV_EP1.*CH_47F_EP1.*CH_47F_BAF.*BAF_Merlin_HC3_D.*AH6J_EP1.* EAST H .*M113_TK_EP1.*BMP2_TK_EP1.*T34_TK_EP1.*BMP3.* A .*UH1H_TK_EP1.*Mi17_TK_EP1.*Mi17_medevac_RU.*An2_TK_EP1'
Assert-Pattern "runtime audit reports Zargabad price multipliers and samples" $content 'Zargabad_RuntimeAudit\.sqf: priceMultipliers .*0\.9.*1\.1.*1\.2.*1\.35.*1\.5.*0\.95.*priceSamples .*US_Soldier_EP1.*M1126_ICV_M2_EP1.*M2A2_EP1.*MH6J_EP1.*C130J_US_EP1'
Assert-Pattern "black-market feature arms after town init" $content 'Zargabad_BlackMarket\.sqf: armed near Zargabad Airfield positions .*3930.*3995.*4100.*3825.*4235.*4040.*4970.*3890.*3310.*3865.* delay \[600,960\] hold \[300\]'
Assert-Pattern "server initialization ends" $content 'Init_Server\.sqf: Server initialization ended'

if ($RequireJip) {
	Assert-Pattern "JIP/player join evidence" $content 'Server_PlayerConnected\.sqf: Player \[[^\r\n]+\] \[[^\r\n]+\] has joined the game|JIP Information have been stored'
}
if ($RequireHeadlessClient) {
	Assert-Pattern "headless client connection evidence" $content 'Server_HandleSpecial\.sqf: Headless client is now connected'
}
if ($RequireEdgeGuardRemoval) {
	Assert-Pattern "edge guard removal evidence" $content 'Zargabad_EdgeGuard\.sqf: \[[^\r\n]+\] removed from edge rim'
}
if ($RequireBlackMarket) {
	Assert-Pattern "black-market cache event evidence" $content 'Zargabad_BlackMarket\.sqf: \[[^\r\n]+\] cache \[[^\r\n]+\] surfaced near'
	Assert-Pattern "black-market cache cleanup evidence" $content 'Zargabad_BlackMarket\.sqf: cache \[[^\r\n]+\] cleanup released near'
}

Assert-NoPattern "missing script or include file" $content 'Script [^\r\n]+ not found|Include file [^\r\n]+ not found'
Assert-NoPattern "Arma expression errors" $content 'Error in expression|Error position:|Undefined variable in expression'
Assert-NoPattern "missing mission dependency" $content 'You cannot play/edit this mission|Cannot load mission|No entry [^\r\n]+zargabad|No entry [^\r\n]+WFBE_[^\r\n]+ZARGABAD'
Assert-NoPattern "Zargabad file load failures" $content 'Cannot open [^\r\n]+Zargabad|Cannot open [^\r\n]+zargabad'

Write-Host ""
Write-Host "Zargabad runtime evidence passed."
