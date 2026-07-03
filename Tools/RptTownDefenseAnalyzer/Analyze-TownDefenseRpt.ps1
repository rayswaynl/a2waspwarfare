<#
	Author: Marty
	Description:
		Parse Arma 2 Warfare RPT logs and summarize town defense spawning, HC cleanup, and group saturation diagnostics.

	Examples:
		.\Analyze-TownDefenseRpt.ps1 -ServerRpt ".\server.rpt" -HcRpt ".\headless.rpt"
		.\Analyze-TownDefenseRpt.ps1 -InputPath ".\logs" -Recurse -OutputPath ".\TownDefenseRptResults"
#>

[CmdletBinding()]
param(
	[string[]]$InputPath = @(),

	[string]$ServerRpt,

	[string]$HcRpt,

	[string]$OutputPath = ".\TownDefenseRptResults",

	[switch]$Recurse,

	[ValidateSet("Semicolon", "Comma", "Tab")]
	[string]$CsvDelimiter = "Semicolon"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$sharedRptParsing = Join-Path $PSScriptRoot "..\RptParsing\RptParsing.psm1"
Import-Module $sharedRptParsing -Force

function Get-InputFiles {
	param(
		$Paths,
		$ExplicitRole
	)

	return @(Resolve-WaspRptInputFiles -Path $Paths -Recurse:$Recurse -ExplicitRole $ExplicitRole -RoleResolver ${function:Get-RoleFromPath} |
		ForEach-Object { [pscustomobject]@{ Path = $_.Path; Role = $_.Role } })
}

function Get-RoleFromPath {
	param([string]$Path)

	$name = [System.IO.Path]::GetFileName($Path).ToLowerInvariant()
	if ($name -match 'headless|(^|[_\-.])hc([_\-.]|$)') { return "HC" }
	if ($name -match 'server') { return "SERVER" }
	return "UNKNOWN"
}

function New-Row {
	param(
		[string]$Kind,
		[string]$SourceRole,
		[string]$SourceFile,
		[int]$LineNumber,
		[string]$Line
	)

	return [ordered]@{
		kind = $Kind
		source_role = $SourceRole
		source_file = $SourceFile
		line_number = $LineNumber
		line = $Line.Trim()
	}
}

function Get-Int {
	param([string]$Value)
	return [int]::Parse($Value, [System.Globalization.CultureInfo]::InvariantCulture)
}

function Test-HasProperty {
	param(
		$Object,
		[string]$Name
	)

	if ($null -eq $Object) { return $false }
	return ($Object.PSObject.Properties.Name -contains $Name)
}

function Add-LineMatch {
	param(
		[string]$Line,
		[string]$Role,
		[string]$File,
		[int]$LineNumber
	)

	$match = [regex]::Match($Line, 'TD Debug build:\s*([0-9]{4}-[0-9]{2}-[0-9]{2}\s+[0-9]{2}:[0-9]{2})')
	if ($match.Success) {
		$row = New-Row "build" $Role $File $LineNumber $Line
		$row["build"] = $match.Groups[1].Value
		$script:Builds.Add([pscustomobject]$row)
		return
	}

	$match = [regex]::Match($Line, 'Common_CreateTownUnits\.sqf: Town \[(.*?)\] held by \[(.*?)\] was activated witha total of \[(\d+)\] units')
	if ($match.Success) {
		$row = New-Row "activation" $Role $File $LineNumber $Line
		$row["town"] = $match.Groups[1].Value
		$row["side"] = $match.Groups[2].Value
		$row["units"] = Get-Int $match.Groups[3].Value
		$row["empty"] = ((Get-Int $match.Groups[3].Value) -eq 0)
		$script:Activations.Add([pscustomobject]$row)
		return
	}

	$match = [regex]::Match($Line, 'Common_CreateTeam\.sqf: Team template for side \[(.*?)\].*no valid group could be created\. Templates:(\d+)')
	if ($match.Success) {
		$row = New-Row "create_failed" $Role $File $LineNumber $Line
		$row["side"] = $match.Groups[1].Value
		$row["templates"] = Get-Int $match.Groups[2].Value
		$script:CreateFailures.Add([pscustomobject]$row)
		return
	}

	$match = [regex]::Match($Line, 'TOWN_GROUP_COUNT\s+(\S+)\s+machine:(\S+)(?:\s+town:(.*?)\s+side:|\s+side:)(\S+)\s+sideGroups:(\d+)\s+total:(\d+)\s+west:(\d+)\s+east:(\d+)\s+guer:(\d+)\s+civ:(\d+)\s+logic:(\d+)\s+unknown:(\d+)')
	if ($match.Success) {
		$row = New-Row "group_count" $Role $File $LineNumber $Line
		$row["event"] = $match.Groups[1].Value
		$row["machine"] = $match.Groups[2].Value
		$row["town"] = $match.Groups[3].Value
		$row["side"] = $match.Groups[4].Value
		$row["side_groups"] = Get-Int $match.Groups[5].Value
		$row["total_groups"] = Get-Int $match.Groups[6].Value
		$row["west"] = Get-Int $match.Groups[7].Value
		$row["east"] = Get-Int $match.Groups[8].Value
		$row["guer"] = Get-Int $match.Groups[9].Value
		$row["civ"] = Get-Int $match.Groups[10].Value
		$row["logic"] = Get-Int $match.Groups[11].Value
		$row["unknown"] = Get-Int $match.Groups[12].Value
		$script:GroupCounts.Add([pscustomobject]$row)
		return
	}

	$match = [regex]::Match($Line, 'TOWN_AI_HC_CLEANUP\s+registered\s+town:(.*?)\s+side:(\S+)\s+groups:(\d+)\s+vehicles:(\d+)\s+registry:(\d+)')
	if ($match.Success) {
		$row = New-Row "cleanup_registered" $Role $File $LineNumber $Line
		$row["town"] = $match.Groups[1].Value
		$row["side"] = $match.Groups[2].Value
		$row["groups"] = Get-Int $match.Groups[3].Value
		$row["vehicles"] = Get-Int $match.Groups[4].Value
		$row["registry"] = Get-Int $match.Groups[5].Value
		$script:Cleanup.Add([pscustomobject]$row)
		return
	}

	$match = [regex]::Match($Line, 'TOWN_AI_HC_CLEANUP\s+server_update\s+town:(.*?)\s+teams:(\d+)\s+vehicles:(\d+)\s+totalTeams:(\d+)\s+totalVehicles:(\d+)')
	if ($match.Success) {
		$row = New-Row "cleanup_server_update" $Role $File $LineNumber $Line
		$row["town"] = $match.Groups[1].Value
		$row["teams"] = Get-Int $match.Groups[2].Value
		$row["vehicles"] = Get-Int $match.Groups[3].Value
		$row["total_teams"] = Get-Int $match.Groups[4].Value
		$row["total_vehicles"] = Get-Int $match.Groups[5].Value
		$script:Cleanup.Add([pscustomobject]$row)
		return
	}

	$match = [regex]::Match($Line, 'TOWN_AI_HC_CLEANUP\s+done\s+town:(.*?)\s+side:(\S+)\s+groups:(\d+)\s+deletedGroups:(\d+)\s+deletedUnits:(\d+)\s+keptGroups:(\d+)\s+registryBefore:(\d+)\s+registryAfter:(\d+)')
	if ($match.Success) {
		$row = New-Row "cleanup_done" $Role $File $LineNumber $Line
		$row["town"] = $match.Groups[1].Value
		$row["side"] = $match.Groups[2].Value
		$row["groups"] = Get-Int $match.Groups[3].Value
		$row["deleted_groups"] = Get-Int $match.Groups[4].Value
		$row["deleted_units"] = Get-Int $match.Groups[5].Value
		$row["kept_groups"] = Get-Int $match.Groups[6].Value
		$row["registry_before"] = Get-Int $match.Groups[7].Value
		$row["registry_after"] = Get-Int $match.Groups[8].Value
		$script:Cleanup.Add([pscustomobject]$row)
		return
	}

	$match = [regex]::Match($Line, 'TOWN_AI_HC_CLEANUP\s+group_not_empty\s+town:(.*?)\s+side:(\S+)\s+group:(.*?)\s+remainingUnits:(\d+)')
	if ($match.Success) {
		$row = New-Row "cleanup_group_not_empty" $Role $File $LineNumber $Line
		$row["town"] = $match.Groups[1].Value
		$row["side"] = $match.Groups[2].Value
		$row["group"] = $match.Groups[3].Value
		$row["remaining_units"] = Get-Int $match.Groups[4].Value
		$script:Cleanup.Add([pscustomobject]$row)
		return
	}

	$match = [regex]::Match($Line, 'Client_DelegateTownAI\.sqf: Received a town delegation request from the server for \[(.*?)\] \[(.*?)\]')
	if ($match.Success) {
		$row = New-Row "delegation_received" $Role $File $LineNumber $Line
		$row["side"] = $match.Groups[1].Value
		$row["town"] = $match.Groups[2].Value
		$script:Delegation.Add([pscustomobject]$row)
		return
	}
}

function Add-ReportLine {
	param([System.Collections.Generic.List[string]]$Lines, [string]$Text = "")
	$Lines.Add($Text)
}

function Get-CountBySideText {
	param([object[]]$Rows)

	$sides = @("WEST", "EAST", "GUER", "RESISTANCE", "CIV", "UNKNOWN")
	$parts = New-Object System.Collections.Generic.List[string]
	foreach ($side in $sides) {
		$count = Get-ItemCount ($Rows | Where-Object { (Test-HasProperty $_ "side") -and $_.side -eq $side })
		if ($count -gt 0) { $parts.Add("$side=$count") }
	}

	$other = Get-ItemCount ($Rows | Where-Object { (Test-HasProperty $_ "side") -and $_.side -notin $sides })
	if ($other -gt 0) { $parts.Add("OTHER=$other") }
	if ($parts.Count -eq 0) { return "none" }
	return ($parts -join ", ")
}

function Add-HtmlTable {
	param(
		[System.Collections.Generic.List[string]]$Lines,
		[string]$Title,
		[object[]]$Rows,
		[string[]]$Columns
	)

	$Lines.Add("<section>")
	$Lines.Add("<h2>$(ConvertTo-HtmlText $Title)</h2>")
	if ((Get-ItemCount $Rows) -eq 0) {
		$Lines.Add("<p class=""muted"">No rows.</p>")
		$Lines.Add("</section>")
		return
	}

	$Lines.Add("<div class=""table-wrap""><table>")
	$Lines.Add("<thead><tr>")
	foreach ($column in $Columns) {
		$Lines.Add("<th>$(ConvertTo-HtmlText $column)</th>")
	}
	$Lines.Add("</tr></thead><tbody>")

	foreach ($row in $Rows) {
		$Lines.Add("<tr>")
		foreach ($column in $Columns) {
			$value = ""
			if ($row.PSObject.Properties.Name -contains $column) {
				$value = $row.$column
			}
			$cellClass = if ($value -is [int] -or $value -is [double] -or $value -is [decimal]) { "number" } else { "" }
			$Lines.Add("<td class=""$cellClass"">$(ConvertTo-HtmlText $value)</td>")
		}
		$Lines.Add("</tr>")
	}

	$Lines.Add("</tbody></table></div>")
	$Lines.Add("</section>")
}

function Write-HtmlReport {
	param(
		[string]$Path,
		[string]$Verdict,
		[string]$Reason,
		[object[]]$Inputs,
		[object[]]$BuildRows,
		[object[]]$ActivationRows,
		[object[]]$EmptyRows,
		[object[]]$FailureRows,
		[object[]]$GroupRows,
		[object[]]$CleanupRows,
		[object[]]$DelegationRows,
		[object[]]$InterpretationRows
	)

	$eastWestActivationsHtml = Get-ItemCount ($ActivationRows | Where-Object { (Test-HasProperty $_ "side") -and $_.side -in @("EAST", "WEST") })
	$guerActivationsHtml = Get-ItemCount ($ActivationRows | Where-Object { (Test-HasProperty $_ "side") -and $_.side -in @("GUER", "RESISTANCE") })
	$maxWestGroupsHtml = if ((Get-ItemCount $GroupRows) -gt 0) { ($GroupRows | Measure-Object -Property west -Maximum).Maximum } else { 0 }
	$maxEastGroupsHtml = if ((Get-ItemCount $GroupRows) -gt 0) { ($GroupRows | Measure-Object -Property east -Maximum).Maximum } else { 0 }
	$maxGuerGroupsHtml = if ((Get-ItemCount $GroupRows) -gt 0) { ($GroupRows | Measure-Object -Property guer -Maximum).Maximum } else { 0 }
	$verdictClass = switch ($Verdict) {
		"OK" { "ok" }
		"FAILURE" { "failure" }
		default { "incomplete" }
	}

	$lines = New-Object System.Collections.Generic.List[string]
	$generatedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

	$lines.Add("<!doctype html>")
	$lines.Add("<html><head><meta charset=""utf-8"">")
	$lines.Add("<title>Town Defense RPT Report</title>")
	$lines.Add("<style>")
	$lines.Add("body{font-family:Segoe UI,Arial,sans-serif;margin:0;background:#f5f7fb;color:#1f2933}")
	$lines.Add("header{background:#18212f;color:#fff;padding:22px 30px}")
	$lines.Add("h1{margin:0;font-size:26px} h2{margin:0 0 12px 0;font-size:19px} section{background:#fff;margin:18px 24px;padding:18px;border:1px solid #d9e0ea;border-radius:8px}")
	$lines.Add(".subtitle{margin-top:6px;color:#c9d4e5}.verdict{display:inline-block;margin-top:14px;padding:8px 12px;border-radius:6px;font-weight:700}.ok{background:#d7f2df;color:#14532d}.incomplete{background:#fff3c4;color:#7c4a03}.failure{background:#ffd6d6;color:#8a1f1f}")
	$lines.Add(".cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(190px,1fr));gap:12px;margin:18px 24px}.card{background:#fff;border:1px solid #d9e0ea;border-radius:8px;padding:14px}.card .label{color:#627084;font-size:12px;text-transform:uppercase}.card .value{font-size:26px;font-weight:700;margin-top:5px}")
	$lines.Add(".table-wrap{overflow-x:auto}table{border-collapse:collapse;width:100%;font-size:13px}th,td{border-bottom:1px solid #e5e9f0;padding:7px 9px;text-align:left;vertical-align:top}th{background:#eef3f8;color:#334155}.number{text-align:right;font-variant-numeric:tabular-nums}.muted{color:#687588}code{background:#eef3f8;padding:2px 5px;border-radius:4px}")
	$lines.Add("</style></head><body>")
	$lines.Add("<header><h1>Town Defense RPT Report</h1><div class=""subtitle"">Generated $generatedAt</div><div class=""verdict $verdictClass"">$(ConvertTo-HtmlText $Verdict)</div><p>$(ConvertTo-HtmlText $Reason)</p></header>")

	$lines.Add("<div class=""cards"">")
	$summaryCards = @(
		@("Activations", (Get-ItemCount $ActivationRows)),
		@("EAST/WEST", $eastWestActivationsHtml),
		@("GUER/RES", $guerActivationsHtml),
		@("Empty Towns", (Get-ItemCount $EmptyRows)),
		@("createGroup Failures", (Get-ItemCount $FailureRows)),
		@("Group Count Rows", (Get-ItemCount $GroupRows)),
		@("Max WEST Groups", $maxWestGroupsHtml),
		@("Max EAST Groups", $maxEastGroupsHtml),
		@("Max GUER Groups", $maxGuerGroupsHtml),
		@("Cleanup Rows", (Get-ItemCount $CleanupRows)),
		@("Delegation Rows", (Get-ItemCount $DelegationRows))
	)
	foreach ($card in $summaryCards) {
		$lines.Add("<div class=""card""><div class=""label"">$(ConvertTo-HtmlText ($card[0]))</div><div class=""value"">$(ConvertTo-HtmlText ($card[1]))</div></div>")
	}
	$lines.Add("</div>")

	Add-HtmlTable $lines "Inputs" $Inputs @("Role","Path")
	Add-HtmlTable $lines "Builds" $BuildRows @("source_role","build","source_file","line_number")
	Add-HtmlTable $lines "Group Saturation Diagnostics" $GroupRows @("event","machine","town","side","side_groups","total_groups","west","east","guer","civ","logic","unknown","source_role","source_file","line_number")
	Add-HtmlTable $lines "Empty Town Activations" $EmptyRows @("source_role","town","side","units","source_file","line_number")
	Add-HtmlTable $lines "createGroup Failures" $FailureRows @("source_role","side","templates","source_file","line_number")
	Add-HtmlTable $lines "HC Cleanup" $CleanupRows @("kind","source_role","town","side","groups","deleted_groups","deleted_units","kept_groups","vehicles","registry","source_file","line_number")
	Add-HtmlTable $lines "Delegation Requests" $DelegationRows @("source_role","town","side","source_file","line_number")
	Add-HtmlTable $lines "Interpretation" $InterpretationRows @("message")

	$lines.Add("</body></html>")
	[System.IO.File]::WriteAllLines($Path, $lines, [System.Text.Encoding]::UTF8)
}

$script:Builds = New-Object System.Collections.Generic.List[object]
$script:Activations = New-Object System.Collections.Generic.List[object]
$script:CreateFailures = New-Object System.Collections.Generic.List[object]
$script:GroupCounts = New-Object System.Collections.Generic.List[object]
$script:Cleanup = New-Object System.Collections.Generic.List[object]
$script:Delegation = New-Object System.Collections.Generic.List[object]

$inputs = New-Object System.Collections.Generic.List[object]
if ($ServerRpt) { (Get-InputFiles @($ServerRpt) "SERVER") | ForEach-Object { $inputs.Add($_) } }
if ($HcRpt) { (Get-InputFiles @($HcRpt) "HC") | ForEach-Object { $inputs.Add($_) } }
if ((Get-ItemCount $InputPath) -gt 0) { (Get-InputFiles $InputPath $null) | ForEach-Object { $inputs.Add($_) } }

if ($inputs.Count -eq 0) {
	throw "No input RPT was provided. Use -ServerRpt, -HcRpt, or -InputPath."
}

$uniqueInputs = @($inputs.ToArray() | Sort-Object Path, Role -Unique)

foreach ($inputInfo in $uniqueInputs) {
	$lineNumber = 0
	Get-Content -LiteralPath $inputInfo.Path -ReadCount 1000 | ForEach-Object {
		foreach ($line in $_) {
			$lineNumber++
			Add-LineMatch -Line $line -Role $inputInfo.Role -File $inputInfo.Path -LineNumber $lineNumber
		}
	}
}

$resolvedOutput = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
	[System.IO.Path]::GetFullPath($OutputPath)
} else {
	[System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $OutputPath))
}
New-Item -ItemType Directory -Force -Path $resolvedOutput | Out-Null
$delimiter = Get-CsvDelimiter $CsvDelimiter

$activationRows = @($script:Activations.ToArray())
$emptyRows = @($activationRows | Where-Object { $_.empty })
$failureRows = @($script:CreateFailures.ToArray())
$groupRows = @($script:GroupCounts.ToArray())
$cleanupRows = @($script:Cleanup.ToArray())
$delegationRows = @($script:Delegation.ToArray())
$buildRows = @($script:Builds.ToArray())

$eastWestActivations = @($activationRows | Where-Object { $_.side -in @("EAST", "WEST") })
$guerActivations = @($activationRows | Where-Object { $_.side -in @("GUER", "RESISTANCE") })
$keptCleanup = @($cleanupRows | Where-Object { $_.kind -eq "cleanup_done" -and $_.kept_groups -gt 0 })
$groupNotEmpty = @($cleanupRows | Where-Object { $_.kind -eq "cleanup_group_not_empty" })
$missingGroupCountForEmpty = ((Get-ItemCount $emptyRows) -gt 0 -and (Get-ItemCount $groupRows) -eq 0)
$missingGroupCountForFailure = ((Get-ItemCount $failureRows) -gt 0 -and (Get-ItemCount $groupRows) -eq 0)
$townDefenseSignalCount = (Get-ItemCount $activationRows) + (Get-ItemCount $failureRows) + (Get-ItemCount $groupRows) + (Get-ItemCount $cleanupRows) + (Get-ItemCount $delegationRows)

$verdict = "OK"
$verdictReason = "No empty town defense activation and no createGroup failure were detected."
if ($townDefenseSignalCount -eq 0) {
	$verdict = "INCOMPLETE"
	$verdictReason = "No town defense log line was found in the selected RPT. The file is probably the wrong RPT, a short/truncated extract, or from a period before town AI activation."
} elseif ((Get-ItemCount $emptyRows) -gt 0 -or (Get-ItemCount $failureRows) -gt 0 -or (Get-ItemCount $keptCleanup) -gt 0 -or (Get-ItemCount $groupNotEmpty) -gt 0) {
	$verdict = "FAILURE"
	$verdictReason = "Town defense spawning or cleanup anomalies were detected."
} elseif ((Get-ItemCount $eastWestActivations) -eq 0) {
	$verdict = "INCOMPLETE"
	$verdictReason = "No EAST/WEST town defense activation was found; this does not validate the reported production symptom."
} elseif ((Get-ItemCount $guerActivations) -gt 0 -and (Get-ItemCount $eastWestActivations) -lt 3) {
	$verdict = "INCOMPLETE"
	$verdictReason = "Only a small number of EAST/WEST activations was found; the test may not be representative."
}

$report = New-Object System.Collections.Generic.List[string]
Add-ReportLine $report "# Town Defense RPT Report"
Add-ReportLine $report
Add-ReportLine $report "Verdict: $verdict"
Add-ReportLine $report "Reason: $verdictReason"
Add-ReportLine $report
Add-ReportLine $report "## Inputs"
foreach ($inputInfo in $uniqueInputs) {
	Add-ReportLine $report "- $($inputInfo.Role): $($inputInfo.Path)"
}
Add-ReportLine $report
Add-ReportLine $report "## Build"
if ((Get-ItemCount $buildRows) -gt 0) {
	$buildRows | Sort-Object source_file, line_number | ForEach-Object {
		Add-ReportLine $report "- $($_.source_role) $($_.build) at $([System.IO.Path]::GetFileName($_.source_file)):$($_.line_number)"
	}
} else {
	Add-ReportLine $report "- No `TD Debug build` line found."
}
Add-ReportLine $report
Add-ReportLine $report "## Summary"
Add-ReportLine $report "- Activations: $(Get-ItemCount $activationRows) ($(Get-CountBySideText $activationRows))"
Add-ReportLine $report "- EAST/WEST activations: $(Get-ItemCount $eastWestActivations)"
Add-ReportLine $report "- GUER/RESISTANCE activations: $(Get-ItemCount $guerActivations)"
Add-ReportLine $report "- Empty town activations: $(Get-ItemCount $emptyRows)"
Add-ReportLine $report "- createGroup failures: $(Get-ItemCount $failureRows)"
Add-ReportLine $report "- TOWN_GROUP_COUNT rows: $(Get-ItemCount $groupRows)"
Add-ReportLine $report "- Delegation requests: $(Get-ItemCount $delegationRows) ($(Get-CountBySideText $delegationRows))"
Add-ReportLine $report "- Cleanup rows: $(Get-ItemCount $cleanupRows)"
Add-ReportLine $report

if ((Get-ItemCount $groupRows) -gt 0) {
	$maxSideGroups = ($groupRows | Measure-Object -Property side_groups -Maximum).Maximum
	$maxTotalGroups = ($groupRows | Measure-Object -Property total_groups -Maximum).Maximum
	$maxWestGroups = ($groupRows | Measure-Object -Property west -Maximum).Maximum
	$maxEastGroups = ($groupRows | Measure-Object -Property east -Maximum).Maximum
	$maxGuerGroups = ($groupRows | Measure-Object -Property guer -Maximum).Maximum
	Add-ReportLine $report "## Group Saturation Diagnostics"
	Add-ReportLine $report "- Max sideGroups observed: $maxSideGroups"
	Add-ReportLine $report "- Max total groups observed: $maxTotalGroups"
	Add-ReportLine $report "- Max WEST groups observed: $maxWestGroups"
	Add-ReportLine $report "- Max EAST groups observed: $maxEastGroups"
	Add-ReportLine $report "- Max GUER groups observed: $maxGuerGroups"
	Add-ReportLine $report
	$groupRows | Sort-Object source_file, line_number | Select-Object -Last 10 | ForEach-Object {
		Add-ReportLine $report "- $($_.event) $($_.machine) town:$($_.town) side:$($_.side) sideGroups:$($_.side_groups) total:$($_.total_groups) west:$($_.west) east:$($_.east) guer:$($_.guer) at $([System.IO.Path]::GetFileName($_.source_file)):$($_.line_number)"
	}
	Add-ReportLine $report
}

if ((Get-ItemCount $emptyRows) -gt 0) {
	Add-ReportLine $report "## Empty Town Activations"
	$emptyRows | Sort-Object source_file, line_number | ForEach-Object {
		Add-ReportLine $report "- $($_.source_role) town:$($_.town) side:$($_.side) at $([System.IO.Path]::GetFileName($_.source_file)):$($_.line_number)"
	}
	Add-ReportLine $report
}

if ((Get-ItemCount $failureRows) -gt 0) {
	Add-ReportLine $report "## createGroup Failures"
	$failureRows | Sort-Object source_file, line_number | ForEach-Object {
		Add-ReportLine $report "- $($_.source_role) side:$($_.side) templates:$($_.templates) at $([System.IO.Path]::GetFileName($_.source_file)):$($_.line_number)"
	}
	Add-ReportLine $report
}

if ((Get-ItemCount $cleanupRows) -gt 0) {
	$doneRows = @($cleanupRows | Where-Object { $_.kind -eq "cleanup_done" })
	$deletedGroups = 0
	$deletedUnits = 0
	$keptGroups = 0
	if ((Get-ItemCount $doneRows) -gt 0) {
		$deletedGroups = ($doneRows | Measure-Object -Property deleted_groups -Sum).Sum
		$deletedUnits = ($doneRows | Measure-Object -Property deleted_units -Sum).Sum
		$keptGroups = ($doneRows | Measure-Object -Property kept_groups -Sum).Sum
	}
	Add-ReportLine $report "## HC Cleanup"
	Add-ReportLine $report "- cleanup_done rows: $(Get-ItemCount $doneRows)"
	Add-ReportLine $report "- deleted groups: $deletedGroups"
	Add-ReportLine $report "- deleted units: $deletedUnits"
	Add-ReportLine $report "- kept groups: $keptGroups"
	Add-ReportLine $report "- group_not_empty rows: $(Get-ItemCount $groupNotEmpty)"
	Add-ReportLine $report
}

Add-ReportLine $report "## Interpretation"
$interpretationRows = New-Object System.Collections.Generic.List[object]
if ($townDefenseSignalCount -eq 0) {
	$message = "No town defense log line was found. Select the full server/HC RPT instead of a short extract, or analyze a time window where towns were actually activated."
	$interpretationRows.Add([pscustomobject]@{ message = $message })
	Add-ReportLine $report "- $message"
}
if ($missingGroupCountForEmpty) {
	$message = "Empty town activations exist but no TOWN_GROUP_COUNT row was found. This usually means the analyzed RPT is not from the newest mission build, or the line comes from an older appended session."
	$interpretationRows.Add([pscustomobject]@{ message = $message })
	Add-ReportLine $report "- $message"
}
if ($missingGroupCountForFailure) {
	$message = "createGroup failures exist but no TOWN_GROUP_COUNT row was found. This usually means the analyzed RPT is not from the newest mission build, or the line comes from an older appended session."
	$interpretationRows.Add([pscustomobject]@{ message = $message })
	Add-ReportLine $report "- $message"
}
if ((Get-ItemCount $groupRows) -eq 0 -and (Get-ItemCount $activationRows) -gt 0) {
	$message = "Town activations exist but no TOWN_GROUP_COUNT row was found. This usually means the analyzed RPT is from a build before continuous group count logging."
	$interpretationRows.Add([pscustomobject]@{ message = $message })
	Add-ReportLine $report "- $message"
}
if ((Get-ItemCount $groupRows) -eq 0 -and (Get-ItemCount $activationRows) -eq 0 -and (Get-ItemCount $emptyRows) -eq 0 -and (Get-ItemCount $failureRows) -eq 0) {
	$message = "No TOWN_GROUP_COUNT row is expected because no town defense activation or group creation failure was detected."
	$interpretationRows.Add([pscustomobject]@{ message = $message })
	Add-ReportLine $report "- $message"
}
if ((Get-ItemCount $eastWestActivations) -eq 0) {
	$message = "The log is not enough to validate the BLUFOR/OPFOR town defense issue because no EAST/WEST town activation was detected."
	$interpretationRows.Add([pscustomobject]@{ message = $message })
	Add-ReportLine $report "- $message"
}
if ((Get-ItemCount $groupRows) -gt 0) {
	$message = "If sideGroups is near 144 for EAST or WEST, the Arma 2 OA per-side group limit is probably the direct reason for empty town defense spawns."
	$interpretationRows.Add([pscustomobject]@{ message = $message })
	Add-ReportLine $report "- $message"
}

$reportText = $report -join [Environment]::NewLine
$reportPath = Join-Path $resolvedOutput "town_defense_report.md"
$reportText | Set-Content -LiteralPath $reportPath -Encoding UTF8
$reportText | Set-Content -LiteralPath (Join-Path $resolvedOutput "town_defense_report.txt") -Encoding UTF8

$inputRows = @($uniqueInputs | ForEach-Object { [pscustomobject]@{ Role = $_.Role; Path = $_.Path } })
$htmlBuildRows = @($buildRows | ForEach-Object {
	[pscustomobject]@{
		source_role = $_.source_role
		build = $_.build
		source_file = [System.IO.Path]::GetFileName($_.source_file)
		line_number = $_.line_number
	}
})
$htmlRowsWithFile = {
	param([object[]]$Rows)
	return @($Rows | ForEach-Object {
		$row = $_ | Select-Object *
		if ($row.PSObject.Properties.Name -contains "source_file") {
			$row.source_file = [System.IO.Path]::GetFileName($row.source_file)
		}
		$row
	})
}

$htmlReportPath = Join-Path $resolvedOutput "town_defense_report.html"
Write-HtmlReport `
	-Path $htmlReportPath `
	-Verdict $verdict `
	-Reason $verdictReason `
	-Inputs $inputRows `
	-BuildRows $htmlBuildRows `
	-ActivationRows (& $htmlRowsWithFile $activationRows) `
	-EmptyRows (& $htmlRowsWithFile $emptyRows) `
	-FailureRows (& $htmlRowsWithFile $failureRows) `
	-GroupRows (& $htmlRowsWithFile $groupRows) `
	-CleanupRows (& $htmlRowsWithFile $cleanupRows) `
	-DelegationRows (& $htmlRowsWithFile $delegationRows) `
	-InterpretationRows @($interpretationRows.ToArray())

Export-Rows $activationRows (Join-Path $resolvedOutput "town_defense_activations.csv") $delimiter
Export-Rows $failureRows (Join-Path $resolvedOutput "town_defense_create_failures.csv") $delimiter
Export-Rows $groupRows (Join-Path $resolvedOutput "town_defense_group_counts.csv") $delimiter
Export-Rows $cleanupRows (Join-Path $resolvedOutput "town_defense_cleanup.csv") $delimiter
Export-Rows $delegationRows (Join-Path $resolvedOutput "town_defense_delegation.csv") $delimiter
Export-Rows $buildRows (Join-Path $resolvedOutput "town_defense_builds.csv") $delimiter

$summary = [pscustomobject]@{
	verdict = $verdict
	reason = $verdictReason
	input_count = (Get-ItemCount $uniqueInputs)
	build_count = (Get-ItemCount $buildRows)
	activation_count = (Get-ItemCount $activationRows)
	east_west_activation_count = (Get-ItemCount $eastWestActivations)
	guer_activation_count = (Get-ItemCount $guerActivations)
	empty_activation_count = (Get-ItemCount $emptyRows)
	create_group_failure_count = (Get-ItemCount $failureRows)
	group_count_rows = (Get-ItemCount $groupRows)
	max_west_groups = if ((Get-ItemCount $groupRows) -gt 0) { ($groupRows | Measure-Object -Property west -Maximum).Maximum } else { 0 }
	max_east_groups = if ((Get-ItemCount $groupRows) -gt 0) { ($groupRows | Measure-Object -Property east -Maximum).Maximum } else { 0 }
	max_guer_groups = if ((Get-ItemCount $groupRows) -gt 0) { ($groupRows | Measure-Object -Property guer -Maximum).Maximum } else { 0 }
	cleanup_rows = (Get-ItemCount $cleanupRows)
	delegation_rows = (Get-ItemCount $delegationRows)
	output_path = $resolvedOutput
}
$summary | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $resolvedOutput "town_defense_summary.json") -Encoding UTF8

Write-Host $reportText
Write-Host ""
Write-Host "Output written to: $resolvedOutput"
