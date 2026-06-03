param(
	[Parameter(Mandatory = $true)]
	[string]$ReportPath,
	[switch]$RequireJip,
	[switch]$RequireHeadlessClient,
	[switch]$RequireEdgeGuardRemoval,
	[switch]$RequireEdgeGuardSafeAllow,
	[switch]$RequireNamedRimPoints,
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

function Get-NoteEvidence {
	param($Rows, [string]$Key)
	foreach ($row in $Rows) {
		if ($row[0] -eq $Key) {
			if ($row.Count -lt 3) { return "" }
			return $row[2]
		}
	}
	throw "Missing Claude Notes row: $Key"
}

function Assert-NoteEvidence {
	param($Rows, [string]$Key, [string]$Pattern)
	$evidence = Get-NoteEvidence -Rows $Rows -Key $Key
	Assert-True "Claude Notes $Key evidence is specific" ([regex]::IsMatch($evidence, $Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase))
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
if ($RequireEdgeGuardSafeAllow) { Assert-True "runtime report edge-guard-safe-allow gate passed" ((Get-TableValue -Rows $gateRows -Key "Edge guard safe allow") -eq "PASS") }
if ($RequireNamedRimPoints) {
	Assert-True "runtime report named-rim-points gate passed" ((Get-TableValue -Rows $gateRows -Key "Named rim points") -eq "PASS")
	Assert-True "runtime report named rim validator output present" ($content -match 'named rim point West illegal rim removed' -and $content -match 'named rim point East Farms legal rim allowed')
}
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
$expectedNoteRows = @(
	"Hosted/dedicated context",
	"Map audit packet attached",
	"Base safety and spawn sightlines",
	"Base static runtime positions and arcs",
	"Base-axis midpoint and wall origin",
	"Central wall gaps and pathing",
	"Side hills and rim behavior",
	"Town defense facing and movement blocking",
	"Priority defense mix arcs",
	"Economy and factory pricing feel",
	"Weapon/range pressure",
	"Mystery feature behavior",
	"Recommended Codex action"
)
$actualNoteRows = @{}
foreach ($row in $noteRows) {
	if ($row[0] -ne "Runtime check") { $actualNoteRows[$row[0]] = $true }
}
$missingNoteRows = @($expectedNoteRows | Where-Object { -not $actualNoteRows.ContainsKey($_) })
Assert-True "Claude Notes required rows are present" ($missingNoteRows.Count -eq 0)
$unfinishedNotes = @($noteRows | Where-Object { $_[0] -ne "Runtime check" -and $_[1] -ne "PASS" })
Assert-True "Claude Notes rows are all PASS" ($unfinishedNotes.Count -eq 0)
$notesWithoutEvidence = @($noteRows | Where-Object {
	$_[0] -ne "Runtime check" -and (
		$_.Count -lt 3 -or
		[string]::IsNullOrWhiteSpace($_[2]) -or
		$_[2] -match '^(?i:pass|ok|n/?a|none)$'
	)
})
Assert-True "Claude Notes PASS rows include evidence" ($notesWithoutEvidence.Count -eq 0)

$coordinateOrScreenshot = '(\b[0-9]{2,4}\s*,\s*[0-9]{2,4}\b|\[[0-9]{2,4}\s*,\s*[0-9]{2,4}|[A-Za-z0-9_. -]+\.(png|jpg|jpeg))'
Assert-NoteEvidence -Rows $noteRows -Key "Hosted/dedicated context" -Pattern '(hosted|dedicated|server|RPT|Arma)'
Assert-NoteEvidence -Rows $noteRows -Key "Map audit packet attached" -Pattern 'zargabad-map-audit\.md'
Assert-NoteEvidence -Rows $noteRows -Key "Base safety and spawn sightlines" -Pattern $coordinateOrScreenshot
Assert-NoteEvidence -Rows $noteRows -Key "Base static runtime positions and arcs" -Pattern '(baseFootprint|base static|Init_Zargabad|static).*([0-9]{2,4}\s*,\s*[0-9]{2,4}|[0-9]{1,3}\])'
Assert-NoteEvidence -Rows $noteRows -Key "Base-axis midpoint and wall origin" -Pattern '(3425\s*,\s*3375|base-axis|wall origin)'
Assert-NoteEvidence -Rows $noteRows -Key "Central wall gaps and pathing" -Pattern '(4053\s*,\s*2725|3789\s*,\s*2998|3504\s*,\s*3293|3195\s*,\s*3613|2903\s*,\s*3915|\.png|\.jpg|\.jpeg)'
Assert-NoteEvidence -Rows $noteRows -Key "Side hills and rim behavior" -Pattern '(80\s*,\s*3000|3000\s*,\s*80|5900\s*,\s*3000|3000\s*,\s*5900|3600\s*,\s*5900|4330\s*,\s*5900|5900\s*,\s*4340|removed from edge rim|allowed at safe edge rim)'
Assert-NoteEvidence -Rows $noteRows -Key "Town defense facing and movement blocking" -Pattern $coordinateOrScreenshot
Assert-NoteEvidence -Rows $noteRows -Key "Priority defense mix arcs" -Pattern '(City|Airfield|North District|South District|Northwest Base|Rahim Villa|MG|AT|AA|GL|[0-9]{2,4}\s*,\s*[0-9]{2,4}|\.png|\.jpg|\.jpeg)'
Assert-NoteEvidence -Rows $noteRows -Key "Economy and factory pricing feel" -Pattern '(economy|factory|price|supply|income|SV|RPT|Zargabad_RuntimeAudit|[0-9])'
Assert-NoteEvidence -Rows $noteRows -Key "Weapon/range pressure" -Pattern '(missile|UAV|range|countermeasure|hangar|2000|800|45|500|350|35|16|24)'
Assert-NoteEvidence -Rows $noteRows -Key "Mystery feature behavior" -Pattern '(black-market|black market|cache|Airfield|Zargabad_BlackMarket|armed|cleanup)'
Assert-NoteEvidence -Rows $noteRows -Key "Recommended Codex action" -Pattern '(keep|tune|revert|investigate|patch|retest)'

Write-Host ""
Write-Host "Zargabad runtime report is complete enough for Codex review."
