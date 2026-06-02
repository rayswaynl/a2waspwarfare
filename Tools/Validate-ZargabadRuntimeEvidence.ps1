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
Assert-Pattern "Zargabad edge guard initializes" $content 'Zargabad_EdgeGuard\.sqf: outer \[[0-9]+\]m rim timeout \[[0-9]+\]s safe range \[[0-9]+\]m'
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
}

Assert-NoPattern "missing script or include file" $content 'Script [^\r\n]+ not found|Include file [^\r\n]+ not found'
Assert-NoPattern "Arma expression errors" $content 'Error in expression|Error position:|Undefined variable in expression'
Assert-NoPattern "missing mission dependency" $content 'You cannot play/edit this mission|Cannot load mission|No entry [^\r\n]+zargabad|No entry [^\r\n]+WFBE_[^\r\n]+ZARGABAD'
Assert-NoPattern "Zargabad file load failures" $content 'Cannot open [^\r\n]+Zargabad|Cannot open [^\r\n]+zargabad'

Write-Host ""
Write-Host "Zargabad runtime evidence passed."
