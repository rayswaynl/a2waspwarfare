param(
	[Parameter(Mandatory = $true)]
	[string]$ReportPath,
	[switch]$RequireJip,
	[switch]$RequireHeadlessClient,
	[switch]$RequireEdgeGuardRemoval,
	[switch]$RequireBlackMarket
)

$ErrorActionPreference = "Stop"

function Assert-True {
	param([string]$Name, [bool]$Condition)
	if (-not $Condition) { throw $Name }
	Write-Host "ok - $Name"
}

function Get-SectionText {
	param([string]$Content, [string]$Name)
	$pattern = '(?ms)^##\s+' + [regex]::Escape($Name) + '\s*$([\s\S]*?)(?=^##\s+|\z)'
	$match = [regex]::Match($Content, $pattern)
	if (-not $match.Success) { throw "Missing section: $Name" }
	return $match.Groups[1].Value
}

function Get-MarkdownRows {
	param([string]$Section)
	$rows = @()
	foreach ($line in ($Section -split "`r?`n")) {
		$trimmed = $line.Trim()
		if (-not $trimmed.StartsWith("|")) { continue }
		if ($trimmed -match '^\|\s*-+\s*\|') { continue }
		$cells = @($trimmed.Trim("|") -split "\|" | ForEach-Object { $_.Trim() })
		if ($cells.Count -lt 2) { continue }
		$rows += ,$cells
	}
	return @($rows)
}

function Get-TableValue {
	param($Rows, [string]$Key)
	foreach ($row in $Rows) {
		if ($row[0] -eq $Key) { return $row[1] }
	}
	throw "Missing table row: $Key"
}

Assert-True "runtime report exists" (Test-Path -LiteralPath $ReportPath -PathType Leaf)
$content = Get-Content -Raw -LiteralPath $ReportPath
Assert-True "runtime report header present" ($content -match '^# Zargabad Runtime Report')
Assert-True "runtime validator passed in report" ($content -match '- Validator: PASS')
Assert-True "runtime report has no missing key evidence placeholders" (-not $content.Contains("_missing_"))

$gateRows = Get-MarkdownRows (Get-SectionText -Content $content -Name "Gate Snapshot")
Assert-True "runtime gate snapshot has rows" ($gateRows.Count -gt 1)
$missingGates = @($gateRows | Where-Object { $_[0] -ne "Gate" -and $_[1] -eq "MISSING" })
Assert-True "runtime report has no missing required gates" ($missingGates.Count -eq 0)
if ($RequireJip) { Assert-True "runtime report JIP gate passed" ((Get-TableValue -Rows $gateRows -Key "JIP") -eq "PASS") }
if ($RequireHeadlessClient) { Assert-True "runtime report headless-client gate passed" ((Get-TableValue -Rows $gateRows -Key "Headless client") -eq "PASS") }
if ($RequireEdgeGuardRemoval) { Assert-True "runtime report edge-guard-removal gate passed" ((Get-TableValue -Rows $gateRows -Key "Edge guard removal") -eq "PASS") }
if ($RequireBlackMarket) {
	Assert-True "runtime report black-market armed gate passed" ((Get-TableValue -Rows $gateRows -Key "Black-market armed") -eq "PASS")
	Assert-True "runtime report black-market cache gate passed" ((Get-TableValue -Rows $gateRows -Key "Black-market cache") -eq "PASS")
	Assert-True "runtime report black-market cleanup gate passed" ((Get-TableValue -Rows $gateRows -Key "Black-market cleanup") -eq "PASS")
}

$failureRows = Get-MarkdownRows (Get-SectionText -Content $content -Name "Failure Scan")
$foundFailures = @($failureRows | Where-Object { $_[0] -ne "Pattern" -and $_[1] -eq "FOUND" })
Assert-True "runtime report failure scan is clear" ($foundFailures.Count -eq 0)

$noteRows = Get-MarkdownRows (Get-SectionText -Content $content -Name "Claude Notes")
Assert-True "Claude Notes table has rows" ($noteRows.Count -gt 1)
$unfinishedNotes = @($noteRows | Where-Object { $_[0] -ne "Runtime check" -and $_[1] -ne "PASS" })
Assert-True "Claude Notes rows are all PASS" ($unfinishedNotes.Count -eq 0)

Write-Host ""
Write-Host "Zargabad runtime report is complete enough for Codex review."
