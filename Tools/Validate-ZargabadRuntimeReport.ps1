param(
	[Parameter(Mandatory = $true)]
	[string]$ReportPath,
	[switch]$RequireJip,
	[switch]$RequireHeadlessClient,
	[switch]$RequireEdgeGuardRemoval,
	[switch]$RequireEdgeGuardSafeAllow,
	[switch]$RequireNamedRimPoints,
	[switch]$RequireBlackMarket,
	[string]$EvidenceRoot = ""
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

function Get-ScreenshotReferences {
	param($Rows)
	$refs = New-Object System.Collections.Generic.List[string]
	foreach ($row in $Rows) {
		if ($row[0] -eq "Runtime check" -or $row.Count -lt 3) { continue }
		$evidence = $row[2]
		foreach ($match in [regex]::Matches($evidence, '(?i)!?\[[^\]]*\]\(([^)]+\.(png|jpg|jpeg))\)')) {
			$refs.Add($match.Groups[1].Value.Trim(" `"'"))
		}
		foreach ($match in [regex]::Matches($evidence, '(?i)(?<![\w:/\\.-])([A-Za-z]:[^\s\|<>"'']+\.(png|jpg|jpeg)|[A-Za-z0-9_.-]+([\\/][A-Za-z0-9_.-]+)*\.(png|jpg|jpeg))')) {
			$refs.Add($match.Groups[1].Value.Trim(" `"'"))
		}
	}
	return @($refs | Where-Object { $_ -notmatch '^(?i:https?://)' } | Sort-Object -Unique)
}

function Test-ScreenshotReference {
	param([string]$Reference, [string[]]$Roots)
	if ([System.IO.Path]::IsPathRooted($Reference)) {
		return (Test-Path -LiteralPath $Reference -PathType Leaf)
	}
	foreach ($root in $Roots) {
		$fullPath = Join-Path $root $Reference
		if (Test-Path -LiteralPath $fullPath -PathType Leaf) { return $true }
	}
	return $false
}

Assert-True "runtime report exists" (Test-Path -LiteralPath $ReportPath -PathType Leaf)
$reportFile = Get-Item -LiteralPath $ReportPath
$content = Get-Content -Raw -LiteralPath $ReportPath
Assert-True "runtime report header present" ($content -match '^# Zargabad Runtime Report')
Assert-True "runtime validator passed in report" ($content -match '- Validator: PASS')
Assert-True "runtime report has no missing key evidence placeholders" (-not $content.Contains("_missing_"))

$gateRows = Get-MarkdownRows (Get-SectionText -Content $content -Name "Gate Snapshot")
Assert-True "runtime gate snapshot has rows" ($gateRows.Count -gt 1)
$expectedGateRows = @(
	"Zargabad world",
	"Server init begins",
	"Town init done",
	"Zargabad init done",
	"Town defense orientation",
	"Edge guard init",
	"Runtime count/SV audit",
	"Runtime base/fortification audit",
	"Runtime base static template audit",
	"Base static runtime positions",
	"Runtime factory audit",
	"Runtime compact factory lists",
	"Runtime price audit",
	"Runtime economy/range/weapons audit",
	"Black-market armed",
	"JIP",
	"Headless client",
	"Edge guard removal",
	"Edge guard safe allow",
	"Named rim points",
	"Black-market cache",
	"Black-market cleanup",
	"Server init ends"
)
$actualGateRows = @{}
foreach ($row in $gateRows) {
	if ($row[0] -ne "Gate") { $actualGateRows[$row[0]] = $true }
}
$missingGateRows = @($expectedGateRows | Where-Object { -not $actualGateRows.ContainsKey($_) })
Assert-True "runtime gate snapshot required rows are present" ($missingGateRows.Count -eq 0)
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
$expectedFailureRows = @(
	"Missing script/include",
	"Expression errors",
	"Missing dependency",
	"Zargabad file load failures",
	"WFBE class/loadout validation errors",
	"Vehicle/object creation failures"
)
$actualFailureRows = @{}
foreach ($row in $failureRows) {
	if ($row[0] -ne "Pattern") { $actualFailureRows[$row[0]] = $true }
}
$missingFailureRows = @($expectedFailureRows | Where-Object { -not $actualFailureRows.ContainsKey($_) })
Assert-True "runtime failure scan required rows are present" ($missingFailureRows.Count -eq 0)
$foundFailures = @($failureRows | Where-Object { $_[0] -ne "Pattern" -and $_[1] -eq "FOUND" })
Assert-True "runtime report failure scan is clear" ($foundFailures.Count -eq 0)

$noteRows = Get-MarkdownRows (Get-SectionText -Content $content -Name "Claude Notes")
Assert-True "Claude Notes table has rows" ($noteRows.Count -gt 1)
$expectedNoteRows = @(
	"Hosted boot context",
	"Dedicated boot context",
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
Assert-NoteEvidence -Rows $noteRows -Key "Hosted boot context" -Pattern '(hosted|listen|local host|local-host|non-dedicated).*(RPT|Init_Server|server initialization ended|Arma)|((RPT|Init_Server|server initialization ended|Arma).*(hosted|listen|local host|local-host|non-dedicated))'
Assert-NoteEvidence -Rows $noteRows -Key "Dedicated boot context" -Pattern '(dedicated|arma2oaserver|server\.exe).*(RPT|Init_Server|server initialization ended|Arma)|((RPT|Init_Server|server initialization ended|Arma).*(dedicated|arma2oaserver|server\.exe))'
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

if ($EvidenceRoot.Trim().Length -gt 0) {
	Assert-True "runtime report evidence root exists" (Test-Path -LiteralPath $EvidenceRoot -PathType Container)
	$resolvedEvidenceRoot = (Resolve-Path -LiteralPath $EvidenceRoot).Path
	$evidenceRoots = @($resolvedEvidenceRoot, $reportFile.Directory.FullName)
	$screenshotRefs = @(Get-ScreenshotReferences -Rows $noteRows)
	Assert-True "Claude Notes screenshot references are present when evidence root is supplied" ($screenshotRefs.Count -gt 0)
	$missingScreenshotRefs = @($screenshotRefs | Where-Object { -not (Test-ScreenshotReference -Reference $_ -Roots $evidenceRoots) })
	Assert-True "Claude Notes screenshot references exist under evidence root" ($missingScreenshotRefs.Count -eq 0)
}

Write-Host ""
Write-Host "Zargabad runtime report is complete enough for Codex review."
