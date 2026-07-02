<#
	Author: Marty
	Description:
		Parse Arma 2 Warfare [Performance Audit] RPT lines and export Excel-friendly CSV summaries.

	Examples:
		.\Analyze-PerformanceAudit.ps1 -InputPath "C:\Users\Marty\AppData\Local\ArmA 2 OA" -OutputPath ".\PerformanceAuditResults" -Recurse
		.\Analyze-PerformanceAudit.ps1 -InputPath ".\arma2oa.rpt" -OutputPath ".\PerformanceAuditResults"
#>

[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)]
	[string]$InputPath,

	[string]$OutputPath = ".\PerformanceAuditResults",

	[switch]$Recurse,

	[ValidateSet("Semicolon", "Comma", "Tab")]
	[string]$CsvDelimiter = "Semicolon",

	[int]$SpikeThresholdMs = 25
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$sharedRptParsing = Join-Path $PSScriptRoot "..\RptParsing\RptParsing.psm1"
Import-Module $sharedRptParsing -Force

$script:InvariantCulture = [System.Globalization.CultureInfo]::InvariantCulture

function ConvertTo-AuditNumber {
	param($Value)

	if ($null -eq $Value -or $Value -eq "") { return $null }

	$number = 0.0
	if ([double]::TryParse([string]$Value, [System.Globalization.NumberStyles]::Float, $script:InvariantCulture, [ref]$number)) {
		return $number
	}

	return $null
}

function Get-RptDateTimePrefix {
	param([string]$Line)

	$match = [regex]::Match($Line, '^\s*(\d{4})[-/](\d{1,2})[-/](\d{1,2})[ T,]+(\d{1,2}):(\d{2}):(\d{2})')
	if ($match.Success) {
		return [datetime]::new(
			[int]$match.Groups[1].Value,
			[int]$match.Groups[2].Value,
			[int]$match.Groups[3].Value,
			[int]$match.Groups[4].Value,
			[int]$match.Groups[5].Value,
			[int]$match.Groups[6].Value
		)
	}

	$match = [regex]::Match($Line, '^\s*(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})[ T,]+(\d{1,2}):(\d{2}):(\d{2})')
	if ($match.Success) {
		$year = [int]$match.Groups[3].Value
		if ($year -lt 100) { $year += 2000 }

		return [datetime]::new(
			$year,
			[int]$match.Groups[2].Value,
			[int]$match.Groups[1].Value,
			[int]$match.Groups[4].Value,
			[int]$match.Groups[5].Value,
			[int]$match.Groups[6].Value
		)
	}

	return $null
}

function Get-RptTimeOfDayPrefix {
	param([string]$Line)

	$match = [regex]::Match($Line, '^\s*(\d{1,2}):(\d{2}):(\d{2})\b')
	if (!$match.Success) { return $null }

	return [timespan]::new(
		[int]$match.Groups[1].Value,
		[int]$match.Groups[2].Value,
		[int]$match.Groups[3].Value
	)
}

function Get-AuditValue {
	param(
		[hashtable]$Fields,
		[string]$Name,
		$Default = $null
	)

	if ($Fields.ContainsKey($Name)) { return $Fields[$Name] }
	return $Default
}

function Get-Percentile {
	param(
		[double[]]$Values,
		[double]$Percentile
	)

	if ($null -eq $Values -or $Values.Count -eq 0) { return $null }

	$sorted = @($Values | Sort-Object)
	if ($sorted.Count -eq 1) { return [math]::Round($sorted[0], 2) }

	$rank = ($Percentile / 100.0) * ($sorted.Count - 1)
	$lower = [math]::Floor($rank)
	$upper = [math]::Ceiling($rank)

	if ($lower -eq $upper) { return [math]::Round($sorted[$lower], 2) }

	$weight = $rank - $lower
	$value = ($sorted[$lower] * (1 - $weight)) + ($sorted[$upper] * $weight)
	return [math]::Round($value, 2)
}

function Get-Average {
	param([object[]]$Values)

	$numbers = @($Values | Where-Object { $null -ne $_ } | ForEach-Object { [double]$_ })
	if ($numbers.Count -eq 0) { return $null }

	return [math]::Round((($numbers | Measure-Object -Average).Average), 2)
}

function Get-Sum {
	param([object[]]$Values)

	$numbers = @($Values | Where-Object { $null -ne $_ } | ForEach-Object { [double]$_ })
	if ($numbers.Count -eq 0) { return 0 }

	return [math]::Round((($numbers | Measure-Object -Sum).Sum), 2)
}

function Get-Max {
	param([object[]]$Values)

	$numbers = @($Values | Where-Object { $null -ne $_ } | ForEach-Object { [double]$_ })
	if ($numbers.Count -eq 0) { return $null }

	return [math]::Round((($numbers | Measure-Object -Maximum).Maximum), 2)
}

function Get-Min {
	param([object[]]$Values)

	$numbers = @($Values | Where-Object { $null -ne $_ } | ForEach-Object { [double]$_ })
	if ($numbers.Count -eq 0) { return $null }

	return [math]::Round((($numbers | Measure-Object -Minimum).Minimum), 2)
}

function Get-AIBin {
	param($AI)

	if ($null -eq $AI) { return "unknown" }

	$value = [int]$AI
	if ($value -lt 100) { return "000-099" }
	if ($value -lt 150) { return "100-149" }
	if ($value -lt 200) { return "150-199" }
	if ($value -lt 250) { return "200-249" }
	if ($value -lt 300) { return "250-299" }
	return "300+"
}

function ConvertFrom-AuditExtra {
	param([string]$Extra)

	$fields = @{}
	if ([string]::IsNullOrWhiteSpace($Extra)) { return $fields }

	foreach ($part in ($Extra -split ";")) {
		if ([string]::IsNullOrWhiteSpace($part)) { continue }

		$separator = $part.IndexOf(":")
		if ($separator -le 0) { continue }

		$key = $part.Substring(0, $separator).Trim()
		$value = $part.Substring($separator + 1).Trim()

		if (![string]::IsNullOrWhiteSpace($key)) {
			$fields[$key] = $value
		}
	}

	return $fields
}

function Get-AuditAnchorSessionStart {
	param([object]$Row)

	if ($null -eq $Row -or $Row.script -ne "session") { return $null }

	$extraFields = ConvertFrom-AuditExtra ([string]$Row.extra)
	if (!$extraFields.ContainsKey("state") -or $extraFields["state"] -ne "anchor") { return $null }

	if ($extraFields.ContainsKey("realTime")) {
		$realTime = [string]$extraFields["realTime"]
		if ($realTime -match '^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}') {
			return [pscustomobject]@{
				session_start = $realTime.Substring(0, 19).Replace("T", " ")
				session_start_source = "audit_session_anchor_realtime"
			}
		}
	}

	$diagTick = if ($extraFields.ContainsKey("diagTick")) { $extraFields["diagTick"] } else { "" }
	$frame = if ($extraFields.ContainsKey("frame")) { $extraFields["frame"] } else { "" }

	return [pscustomobject]@{
		session_start = "anchor tick $diagTick frame $frame"
		session_start_source = "audit_session_anchor_no_realtime"
	}
}

function New-ExpandedAuditRows {
	param(
		[object[]]$Rows,
		[string[]]$ExtraKeys
	)

	$expandedRows = foreach ($row in $Rows) {
		$extraFields = ConvertFrom-AuditExtra ([string]$row.extra)
		$properties = [ordered]@{}

		foreach ($property in $row.PSObject.Properties) {
			$properties[$property.Name] = $property.Value
		}

		foreach ($key in $ExtraKeys) {
			$columnName = "extra_$key"
			$properties[$columnName] = if ($extraFields.ContainsKey($key)) { $extraFields[$key] } else { "" }
		}

		[pscustomobject]$properties
	}

	return @($expandedRows)
}

function New-ProbeDetailRows {
	param(
		[object[]]$Rows,
		[string[]]$Scripts,
		[string[]]$ExtraKeys,
		[int]$Limit = 80
	)

	$filteredRows = @($Rows | Where-Object { $_.script -in $Scripts })
	$expandedRows = New-ExpandedAuditRows $filteredRows $ExtraKeys
	return @($expandedRows | Sort-Object max_ms, timestamp_index -Descending | Select-Object -First $Limit)
}

function ConvertFrom-PerformanceAuditLine {
	param(
		[string]$Line,
		[string]$SourceFile,
		[string]$SourceFileLastWriteTime,
		[int]$LineNumber,
		[int]$Index,
		[string]$RptTimestamp,
		[string]$RptTimestampSource
	)

	if ($Line -notlike "*[Performance Audit]*") { return $null }

	$fields = @{}
	$matches = [regex]::Matches($Line, '([A-Z_]+)=("([^"]*)"|\S+)')
	foreach ($match in $matches) {
		$key = $match.Groups[1].Value
		if ($match.Groups[3].Success) {
			$fields[$key] = $match.Groups[3].Value
		} else {
			$fields[$key] = $match.Groups[2].Value.Trim('"')
		}
	}

	if ($fields.Count -eq 0) { return $null }

	$calls = ConvertTo-AuditNumber (Get-AuditValue $fields "CALLS")
	$avgMs = ConvertTo-AuditNumber (Get-AuditValue $fields "AVG_MS")
	$totalMs = $null
	if ($null -ne $calls -and $null -ne $avgMs) {
		$totalMs = [math]::Round(($calls * $avgMs), 2)
	}

	$maxMs = ConvertTo-AuditNumber (Get-AuditValue $fields "MAX_MS")

	return [pscustomobject]@{
		timestamp_index = $Index
		session_index = $null
		session_key = $null
		session_start = ""
		session_start_source = ""
		sid = Get-AuditValue $fields "SID"
		rpt_timestamp = $RptTimestamp
		rpt_timestamp_source = $RptTimestampSource
		source_file_last_write_time = $SourceFileLastWriteTime
		source_file = $SourceFile
		line_number = $LineNumber
		map = Get-AuditValue $fields "MAP"
		scope = Get-AuditValue $fields "SCOPE"
		player = Get-AuditValue $fields "PLAYER"
		uid = Get-AuditValue $fields "UID"
		script = Get-AuditValue $fields "NAME"
		fps = ConvertTo-AuditNumber (Get-AuditValue $fields "FPS")
		players = ConvertTo-AuditNumber (Get-AuditValue $fields "PLAYERS")
		ai = ConvertTo-AuditNumber (Get-AuditValue $fields "AI")
		units = ConvertTo-AuditNumber (Get-AuditValue $fields "UNITS")
		vehicles = ConvertTo-AuditNumber (Get-AuditValue $fields "VEHICLES")
		teams = ConvertTo-AuditNumber (Get-AuditValue $fields "TEAMS")
		towns_active = ConvertTo-AuditNumber (Get-AuditValue $fields "TOWNS_ACTIVE")
		markers = ConvertTo-AuditNumber (Get-AuditValue $fields "MARKERS")
		vd = ConvertTo-AuditNumber (Get-AuditValue $fields "VD")
		pvd = ConvertTo-AuditNumber (Get-AuditValue $fields "PVD")
		tfps = ConvertTo-AuditNumber (Get-AuditValue $fields "TFPS")
		ptg = ConvertTo-AuditNumber (Get-AuditValue $fields "PTG")
		dnc = ConvertTo-AuditNumber (Get-AuditValue $fields "DNC")
		daytime = ConvertTo-AuditNumber (Get-AuditValue $fields "DAYTIME")
		fog = ConvertTo-AuditNumber (Get-AuditValue $fields "FOG")
		overcast = ConvertTo-AuditNumber (Get-AuditValue $fields "OVERCAST")
		rain = ConvertTo-AuditNumber (Get-AuditValue $fields "RAIN")
		calls = $calls
		avg_ms = $avgMs
		max_ms = $maxMs
		total_ms = $totalMs
		spike_10ms = if ($null -ne $maxMs -and $maxMs -ge 10) { 1 } else { 0 }
		spike_25ms = if ($null -ne $maxMs -and $maxMs -ge 25) { 1 } else { 0 }
		spike_50ms = if ($null -ne $maxMs -and $maxMs -ge 50) { 1 } else { 0 }
		spike_100ms = if ($null -ne $maxMs -and $maxMs -ge 100) { 1 } else { 0 }
		ai_bin = Get-AIBin (ConvertTo-AuditNumber (Get-AuditValue $fields "AI"))
		extra = Get-AuditValue $fields "EXTRA"
		raw_line = $Line
	}
}

function Get-InputFiles {
	param([string]$Path)

	return @(Resolve-WaspRptInputFiles -Path @($Path) -Recurse:$Recurse | ForEach-Object { $_.FileInfo })
}

function Get-FpsClass {
	param($Fps)

	if ($null -eq $Fps) { return "" }
	if ([double]$Fps -lt 20) { return "critical" }
	if ([double]$Fps -lt 30) { return "warning" }
	return "ok"
}

function Get-SpikeClass {
	param($MaxMs)

	if ($null -eq $MaxMs) { return "" }
	if ([double]$MaxMs -ge 100) { return "critical" }
	if ([double]$MaxMs -ge 50) { return "warning" }
	if ([double]$MaxMs -ge 25) { return "notice" }
	return ""
}

function Add-HtmlTable {
	param(
		[System.Collections.Generic.List[string]]$Lines,
		[string]$Title,
		[string]$Description,
		[object[]]$Rows,
		[string[]]$Columns,
		[hashtable]$Labels,
		[string]$Kind = ""
	)

	$Lines.Add("<section>")
	$Lines.Add("<h2>$(ConvertTo-HtmlText $Title)</h2>")
	if (![string]::IsNullOrWhiteSpace($Description)) {
		$Lines.Add("<p class=""section-note"">$(ConvertTo-HtmlText $Description)</p>")
	}

	if ($null -eq $Rows -or $Rows.Count -eq 0) {
		$Lines.Add("<p class=""empty"">No data available for this section.</p>")
		$Lines.Add("</section>")
		return
	}

	$Lines.Add("<table>")
	$Lines.Add("<thead><tr>")
	foreach ($column in $Columns) {
		$label = if ($Labels.ContainsKey($column)) { $Labels[$column] } else { $column }
		$Lines.Add("<th>$(ConvertTo-HtmlText $label)</th>")
	}
	$Lines.Add("</tr></thead>")
	$Lines.Add("<tbody>")

	foreach ($row in $Rows) {
		$rowClass = ""
		if ($Kind -eq "fps") { $rowClass = Get-FpsClass $row.fps }
		if ($Kind -eq "spike") { $rowClass = Get-SpikeClass $row.max_ms }
		if ($Kind -eq "map") { $rowClass = Get-FpsClass $row.min_fps }

		$Lines.Add("<tr class=""$rowClass"">")
		foreach ($column in $Columns) {
			$value = $row.$column
			$cellClass = if ($value -is [int] -or $value -is [double] -or $value -is [decimal]) { "number" } else { "" }
			$Lines.Add("<td class=""$cellClass"">$(ConvertTo-HtmlText $value)</td>")
		}
		$Lines.Add("</tr>")
	}

	$Lines.Add("</tbody>")
	$Lines.Add("</table>")
	$Lines.Add("</section>")
}

function New-ScriptSummary {
	param([object[]]$Rows)

	$scriptRows = @($Rows | Where-Object { $_.script -and $_.script -notin @("snapshot", "session") })
	$summary = foreach ($group in ($scriptRows | Group-Object session_key, map, scope, script)) {
		$items = @($group.Group)
		$totalCalls = Get-Sum ($items | ForEach-Object { $_.calls })
		$totalMs = Get-Sum ($items | ForEach-Object { $_.total_ms })
		$weightedAvg = $null
		if ($totalCalls -gt 0) { $weightedAvg = [math]::Round(($totalMs / $totalCalls), 2) }

		[pscustomobject]@{
			session_index = $items[0].session_index
			session_key = $items[0].session_key
			session_start = $items[0].session_start
			session_start_source = $items[0].session_start_source
			sid = $items[0].sid
			map = $items[0].map
			scope = $items[0].scope
			script = $items[0].script
			samples = $items.Count
			total_calls = $totalCalls
			total_ms = $totalMs
			weighted_avg_ms = $weightedAvg
			max_ms = Get-Max ($items | ForEach-Object { $_.max_ms })
			avg_fps = Get-Average ($items | ForEach-Object { $_.fps })
			min_fps = Get-Min ($items | ForEach-Object { $_.fps })
			avg_players = Get-Average ($items | ForEach-Object { $_.players })
			max_players = Get-Max ($items | ForEach-Object { $_.players })
			avg_ai = Get-Average ($items | ForEach-Object { $_.ai })
			max_ai = Get-Max ($items | ForEach-Object { $_.ai })
			avg_markers = Get-Average ($items | ForEach-Object { $_.markers })
			max_markers = Get-Max ($items | ForEach-Object { $_.markers })
			spike_rows_10ms = Get-Sum ($items | ForEach-Object { $_.spike_10ms })
			spike_rows_25ms = Get-Sum ($items | ForEach-Object { $_.spike_25ms })
			spike_rows_50ms = Get-Sum ($items | ForEach-Object { $_.spike_50ms })
			spike_rows_100ms = Get-Sum ($items | ForEach-Object { $_.spike_100ms })
		}
	}

	return @($summary | Sort-Object total_ms -Descending)
}

function New-Timeline {
	param([object[]]$Rows)

	return @($Rows | Where-Object { $_.script -eq "snapshot" -or $_.script -eq "session" } | Select-Object `
		timestamp_index, session_index, session_key, session_start, session_start_source, sid, rpt_timestamp, rpt_timestamp_source, source_file_last_write_time, source_file, line_number, map, scope, player, uid, script, fps, players, ai, ai_bin, units, vehicles, teams, towns_active, markers, vd, pvd, tfps, ptg, dnc, daytime, fog, overcast, rain, extra)
}

function New-SpikeTable {
	param(
		[object[]]$Rows,
		[int]$ThresholdMs
	)

	return @($Rows |
		Where-Object { $_.script -and $_.script -notin @("snapshot", "session") -and $null -ne $_.max_ms -and $_.max_ms -ge $ThresholdMs } |
		Sort-Object max_ms -Descending |
		Select-Object timestamp_index, session_index, session_key, session_start, session_start_source, sid, rpt_timestamp, rpt_timestamp_source, source_file_last_write_time, source_file, line_number, map, scope, player, uid, script, fps, players, ai, ai_bin, units, vehicles, markers, vd, dnc, daytime, fog, overcast, rain, calls, avg_ms, max_ms, total_ms, extra)
}

function New-FpsContext {
	param([object[]]$TimelineRows)

	$groups = $TimelineRows | Where-Object { $_.script -eq "snapshot" } | Group-Object session_key, map, scope, player, ai_bin
	$summary = foreach ($group in $groups) {
		$items = @($group.Group)
		[pscustomobject]@{
			session_index = $items[0].session_index
			session_key = $items[0].session_key
			session_start = $items[0].session_start
			session_start_source = $items[0].session_start_source
			sid = $items[0].sid
			map = $items[0].map
			scope = $items[0].scope
			player = $items[0].player
			uid = $items[0].uid
			ai_bin = $items[0].ai_bin
			samples = $items.Count
			avg_fps = Get-Average ($items | ForEach-Object { $_.fps })
			min_fps = Get-Min ($items | ForEach-Object { $_.fps })
			p10_fps = Get-Percentile ([double[]]@($items | Where-Object { $null -ne $_.fps } | ForEach-Object { [double]$_.fps })) 10
			p90_fps = Get-Percentile ([double[]]@($items | Where-Object { $null -ne $_.fps } | ForEach-Object { [double]$_.fps })) 90
			avg_players = Get-Average ($items | ForEach-Object { $_.players })
			max_players = Get-Max ($items | ForEach-Object { $_.players })
			avg_ai = Get-Average ($items | ForEach-Object { $_.ai })
			max_ai = Get-Max ($items | ForEach-Object { $_.ai })
			avg_units = Get-Average ($items | ForEach-Object { $_.units })
			avg_vehicles = Get-Average ($items | ForEach-Object { $_.vehicles })
			avg_markers = Get-Average ($items | ForEach-Object { $_.markers })
			avg_vd = Get-Average ($items | ForEach-Object { $_.vd })
			dnc = $items[0].dnc
		}
	}

	return @($summary | Sort-Object session_index, map, scope, player, ai_bin)
}

function New-PlayerSummary {
	param([object[]]$TimelineRows)

	$groups = $TimelineRows | Where-Object { $_.script -eq "snapshot" } | Group-Object session_key, map, scope, player, uid
	$summary = foreach ($group in $groups) {
		$items = @($group.Group)
		[pscustomobject]@{
			session_index = $items[0].session_index
			session_key = $items[0].session_key
			session_start = $items[0].session_start
			session_start_source = $items[0].session_start_source
			sid = $items[0].sid
			map = $items[0].map
			scope = $items[0].scope
			player = $items[0].player
			uid = $items[0].uid
			samples = $items.Count
			avg_fps = Get-Average ($items | ForEach-Object { $_.fps })
			min_fps = Get-Min ($items | ForEach-Object { $_.fps })
			p10_fps = Get-Percentile ([double[]]@($items | Where-Object { $null -ne $_.fps } | ForEach-Object { [double]$_.fps })) 10
			p90_fps = Get-Percentile ([double[]]@($items | Where-Object { $null -ne $_.fps } | ForEach-Object { [double]$_.fps })) 90
			avg_players = Get-Average ($items | ForEach-Object { $_.players })
			max_players = Get-Max ($items | ForEach-Object { $_.players })
			avg_ai = Get-Average ($items | ForEach-Object { $_.ai })
			max_ai = Get-Max ($items | ForEach-Object { $_.ai })
			avg_markers = Get-Average ($items | ForEach-Object { $_.markers })
			max_markers = Get-Max ($items | ForEach-Object { $_.markers })
			avg_vd = Get-Average ($items | ForEach-Object { $_.vd })
		}
	}

	return @($summary | Sort-Object avg_fps)
}

function New-MapSummary {
	param([object[]]$TimelineRows)

	$groups = $TimelineRows | Where-Object { $_.script -eq "snapshot" } | Group-Object session_key, map, scope
	$summary = foreach ($group in $groups) {
		$items = @($group.Group)
		[pscustomobject]@{
			session_index = $items[0].session_index
			session_key = $items[0].session_key
			session_start = $items[0].session_start
			session_start_source = $items[0].session_start_source
			sid = $items[0].sid
			map = $items[0].map
			scope = $items[0].scope
			samples = $items.Count
			avg_fps = Get-Average ($items | ForEach-Object { $_.fps })
			min_fps = Get-Min ($items | ForEach-Object { $_.fps })
			p10_fps = Get-Percentile ([double[]]@($items | Where-Object { $null -ne $_.fps } | ForEach-Object { [double]$_.fps })) 10
			p50_fps = Get-Percentile ([double[]]@($items | Where-Object { $null -ne $_.fps } | ForEach-Object { [double]$_.fps })) 50
			p90_fps = Get-Percentile ([double[]]@($items | Where-Object { $null -ne $_.fps } | ForEach-Object { [double]$_.fps })) 90
			avg_players = Get-Average ($items | ForEach-Object { $_.players })
			max_players = Get-Max ($items | ForEach-Object { $_.players })
			avg_ai = Get-Average ($items | ForEach-Object { $_.ai })
			max_ai = Get-Max ($items | ForEach-Object { $_.ai })
			avg_units = Get-Average ($items | ForEach-Object { $_.units })
			avg_vehicles = Get-Average ($items | ForEach-Object { $_.vehicles })
			avg_markers = Get-Average ($items | ForEach-Object { $_.markers })
			avg_vd = Get-Average ($items | ForEach-Object { $_.vd })
		}
	}

	return @($summary | Sort-Object session_index, map, scope)
}

function Write-MarkdownReport {
	param(
		[string]$Path,
		[object[]]$Rows,
		[object[]]$TimelineRows,
		[object[]]$ScriptSummary,
		[object[]]$Spikes,
		[object[]]$FpsContext,
		[object[]]$PlayerSummary,
		[object[]]$MapSummary
	)

	$lines = New-Object System.Collections.Generic.List[string]
	$lines.Add("# Performance Audit Report")
	$lines.Add("")
	$lines.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
	$lines.Add("")
	$lines.Add("## Input Summary")
	$lines.Add("")
	$lines.Add("- Audit rows: $($Rows.Count)")
	$lines.Add("- Timeline rows: $($TimelineRows.Count)")
	$lines.Add("- Script summary rows: $($ScriptSummary.Count)")
	$lines.Add("- Spike rows: $($Spikes.Count)")
	$lines.Add("")

	$lines.Add("## Map / Scope FPS")
	$lines.Add("")
	$lines.Add("| Session | Session anchor | Map | Scope | Samples | Avg FPS | Min FPS | P10 FPS | P50 FPS | P90 FPS | Avg AI | Max AI | Avg Markers |")
	$lines.Add("|---:|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
	foreach ($row in $MapSummary) {
		$lines.Add("| $($row.session_index) | $($row.session_start) | $($row.map) | $($row.scope) | $($row.samples) | $($row.avg_fps) | $($row.min_fps) | $($row.p10_fps) | $($row.p50_fps) | $($row.p90_fps) | $($row.avg_ai) | $($row.max_ai) | $($row.avg_markers) |")
	}
	$lines.Add("")

	$lines.Add("## Top Scripts By Total Cost")
	$lines.Add("")
	$lines.Add("| Session | Session anchor | Map | Scope | Script | Samples | Calls | Total ms | Weighted avg ms | Max ms | Spike rows >=25ms |")
	$lines.Add("|---:|---|---|---|---|---:|---:|---:|---:|---:|---:|")
	foreach ($row in ($ScriptSummary | Select-Object -First 15)) {
		$lines.Add("| $($row.session_index) | $($row.session_start) | $($row.map) | $($row.scope) | $($row.script) | $($row.samples) | $($row.total_calls) | $($row.total_ms) | $($row.weighted_avg_ms) | $($row.max_ms) | $($row.spike_rows_25ms) |")
	}
	$lines.Add("")

	$lines.Add("## Top Spikes")
	$lines.Add("")
	$lines.Add("| Session | Session anchor | Map | Scope | Player | Script | FPS | Players | AI | Markers | Calls | Avg ms | Max ms | Extra |")
	$lines.Add("|---:|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|")
	foreach ($row in ($Spikes | Select-Object -First 20)) {
		$extra = ([string]$row.extra).Replace("|", "/")
		$lines.Add("| $($row.session_index) | $($row.session_start) | $($row.map) | $($row.scope) | $($row.player) | $($row.script) | $($row.fps) | $($row.players) | $($row.ai) | $($row.markers) | $($row.calls) | $($row.avg_ms) | $($row.max_ms) | $extra |")
	}
	$lines.Add("")

	$lines.Add("## Worst FPS Snapshots")
	$lines.Add("")
	$lines.Add("| Session | Map | Scope | Player | FPS | Players | AI | Units | Vehicles | Markers | VD | DNC | Daytime | Fog | Overcast | Rain |")
	$lines.Add("|---:|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
	foreach ($row in ($TimelineRows | Where-Object { $_.script -eq "snapshot" } | Sort-Object fps | Select-Object -First 20)) {
		$lines.Add("| $($row.session_index) | $($row.map) | $($row.scope) | $($row.player) | $($row.fps) | $($row.players) | $($row.ai) | $($row.units) | $($row.vehicles) | $($row.markers) | $($row.vd) | $($row.dnc) | $($row.daytime) | $($row.fog) | $($row.overcast) | $($row.rain) |")
	}
	$lines.Add("")

	$lines.Add("## Player Summary")
	$lines.Add("")
	$lines.Add("| Session | Map | Scope | Player | Samples | Avg FPS | Min FPS | P10 FPS | Avg AI | Max AI | Avg VD |")
	$lines.Add("|---:|---|---|---|---:|---:|---:|---:|---:|---:|---:|")
	foreach ($row in $PlayerSummary) {
		$lines.Add("| $($row.session_index) | $($row.map) | $($row.scope) | $($row.player) | $($row.samples) | $($row.avg_fps) | $($row.min_fps) | $($row.p10_fps) | $($row.avg_ai) | $($row.max_ai) | $($row.avg_vd) |")
	}

	[System.IO.File]::WriteAllLines($Path, $lines, [System.Text.Encoding]::UTF8)
}

function Write-HtmlReport {
	param(
		[string]$Path,
		[object[]]$Rows,
		[object[]]$TimelineRows,
		[object[]]$ScriptSummary,
		[object[]]$Spikes,
		[object[]]$PlayerSummary,
		[object[]]$MapSummary
	)

	$lines = New-Object System.Collections.Generic.List[string]
	$generatedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
	$snapshotRows = @($TimelineRows | Where-Object { $_.script -eq "snapshot" })
	$worstSnapshots = @($snapshotRows | Sort-Object fps | Select-Object -First 20)
	$topScripts = @($ScriptSummary | Select-Object -First 15)
	$topSpikes = @($Spikes | Select-Object -First 20)
	$fpsByAiLoad = @($FpsContext | Sort-Object session_index, map, scope, player, ai_bin)
	$sessionIndexes = @($Rows | Sort-Object session_index | Select-Object -ExpandProperty session_index -Unique)
	$minFps = Get-Min ($snapshotRows | ForEach-Object { $_.fps })
	$avgFps = Get-Average ($snapshotRows | ForEach-Object { $_.fps })
	$maxAi = Get-Max ($snapshotRows | ForEach-Object { $_.ai })
	$maxPlayers = Get-Max ($snapshotRows | ForEach-Object { $_.players })
	$totalScriptMs = Get-Sum ($ScriptSummary | ForEach-Object { $_.total_ms })
	$sessionCount = @($Rows | Group-Object session_key).Count
	$newProbeScripts = @(
		"createunit","createvehicle","createteam","createtownunits",
		"init_unit_client_setup","init_unit_marker_spawn",
		"markerupdate_start","markerupdate_unit","markerupdate_hq","markerupdate_end",
		"paratrooper_marker_spawn",
		"aar_marker_start","aar_marker_update","aar_marker_end",
		"delegate_townai_server","delegate_townai_client","delegate_townai_headless",
		"town_patrol","town_defenses_units",
		"updatetownmarkers","player_ai_watchdog",
		"cleaner_droppeditems","cleaner_craters","cleaner_ruins","cleaner_mines","restorer_buildings",
		"create_static_defense_units","create_resbase_units"
	)
	$probeCoverage = @($ScriptSummary | Where-Object { $_.script -in $newProbeScripts } | Sort-Object scope, script)
	$unitCreationAudit = New-ProbeDetailRows `
		-Rows $Rows `
		-Scripts @("createunit","createvehicle","createteam","createtownunits","init_unit_client_setup","init_unit_marker_spawn","create_static_defense_units","create_resbase_units") `
		-ExtraKeys @("type","side","global","trackInf","init","leaderPlayer","isMan","unitGlobalForwarded","town","groups","teams","units","vehicles","crews","markerType","refresh","sideMatch","aar","groupPlayer","blinkingEH","cycleMs") `
		-Limit 100
	$markerAudit = New-ProbeDetailRows `
		-Rows $Rows `
		-Scripts @("markerupdate_start","markerupdate_unit","markerupdate_hq","markerupdate_end","paratrooper_marker_spawn","aar_marker_start","aar_marker_update","aar_marker_end") `
		-ExtraKeys @("markerType","trackedKind","trackedType","type","side","refresh","trackDeath","activeMarkers","activeAAR","visible","textUpdates","upgrade","radarInRange","groupPlayer") `
		-Limit 100
	$delegationAudit = New-ProbeDetailRows `
		-Rows $Rows `
		-Scripts @("delegate_townai_server","delegate_townai_client","delegate_townai_headless","town_patrol","town_defenses_units") `
		-ExtraKeys @("town","side","groups","teams","delegators","delegated","fallbackGroups","fallbackVehicles","headless","vehicles","defenses","spawned","removed","mode","changed","focus","alive","units","cycleMs") `
		-Limit 100
	$clientScalingAudit = New-ProbeDetailRows `
		-Rows $Rows `
		-Scripts @("updatetownmarkers","player_ai_watchdog") `
		-ExtraKeys @("towns","groupUnits","visible","textWrites","distanceChecks","map","gps","watched","recovered") `
		-Limit 100
	$maintenanceAudit = New-ProbeDetailRows `
		-Rows $Rows `
		-Scripts @("cleaner_droppeditems","cleaner_craters","cleaner_ruins","cleaner_mines","restorer_buildings") `
		-ExtraKeys @("scanned","deleted","weaponholders","mines","mineE","small","long","tracked","restored","cycleMs") `
		-Limit 100

	$labels = @{
		session_index = "Session"
		session_key = "Session id"
		session_start = "Session anchor"
		session_start_source = "Anchor source"
		sid = "SID"
		rpt_timestamp = "RPT timestamp"
		rpt_timestamp_source = "RPT time source"
		source_file_last_write_time = "Source file date"
		map = "Map"
		scope = "Scope"
		player = "Player"
		script = "Script"
		samples = "Samples"
		total_calls = "Calls"
		total_ms = "Total ms"
		weighted_avg_ms = "Weighted avg ms"
		max_ms = "Max ms"
		spike_rows_25ms = "Spikes >=25ms"
		spike_rows_50ms = "Spikes >=50ms"
		spike_rows_100ms = "Spikes >=100ms"
		fps = "FPS"
		players = "Players"
		ai = "AI"
		units = "Units"
		vehicles = "Vehicles"
		markers = "Markers"
		vd = "View distance"
		dnc = "Day/night"
		daytime = "Daytime"
		fog = "Fog"
		overcast = "Overcast"
		rain = "Rain"
		avg_fps = "Avg FPS"
		min_fps = "Min FPS"
		p10_fps = "P10 FPS"
		p50_fps = "P50 FPS"
		p90_fps = "P90 FPS"
		avg_ai = "Avg AI"
		max_ai = "Max AI"
		avg_markers = "Avg markers"
		avg_vd = "Avg VD"
		avg_players = "Avg players"
		max_players = "Max players"
		avg_units = "Avg units"
		avg_vehicles = "Avg vehicles"
		ai_bin = "AI load"
		calls = "Calls"
		avg_ms = "Avg ms"
		extra = "Extra"
		extra_type = "Type"
		extra_side = "Side"
		extra_global = "Global"
		extra_trackInf = "Track infantry"
		extra_init = "Init mode"
		extra_leaderPlayer = "Leader player"
		extra_isMan = "Is man"
		extra_unitGlobalForwarded = "Unit global forwarded"
		extra_town = "Town"
		extra_groups = "Groups"
		extra_teams = "Teams"
		extra_units = "Units"
		extra_vehicles = "Vehicles"
		extra_crews = "Crews"
		extra_markerType = "Marker type"
		extra_refresh = "Refresh"
		extra_sideMatch = "Side match"
		extra_aar = "AAR started"
		extra_groupPlayer = "Player group"
		extra_blinkingEH = "Blinking EH"
		extra_cycleMs = "Cycle ms"
		extra_trackedKind = "Tracked kind"
		extra_trackedType = "Tracked type"
		extra_trackDeath = "Track death"
		extra_activeMarkers = "Active markers"
		extra_activeAAR = "Active AAR"
		extra_visible = "Visible"
		extra_textUpdates = "Text updates"
		extra_upgrade = "Upgrade"
		extra_radarInRange = "Radar in range"
		extra_delegators = "Delegators"
		extra_delegated = "Delegated"
		extra_fallbackGroups = "Fallback groups"
		extra_fallbackVehicles = "Fallback vehicles"
		extra_headless = "Headless"
		extra_defenses = "Defenses"
		extra_spawned = "Spawned"
		extra_removed = "Removed"
		extra_mode = "Mode"
		extra_changed = "Changed"
		extra_focus = "Focus"
		extra_alive = "Alive"
		extra_towns = "Towns"
		extra_groupUnits = "Group units"
		extra_textWrites = "Text writes"
		extra_distanceChecks = "Distance checks"
		extra_map = "Map open"
		extra_gps = "GPS open"
		extra_watched = "Watched"
		extra_recovered = "Recovered"
		extra_scanned = "Scanned"
		extra_deleted = "Deleted"
		extra_weaponholders = "Weaponholders"
		extra_mines = "Mines"
		extra_mineE = "MineE"
		extra_small = "Small"
		extra_long = "Long"
		extra_tracked = "Tracked"
		extra_restored = "Restored"
	}

	$lines.Add("<!doctype html>")
	$lines.Add("<html>")
	$lines.Add("<head>")
	$lines.Add("<meta charset=""utf-8"">")
	$lines.Add("<title>Performance Audit Report</title>")
	$lines.Add("<style>")
	$lines.Add("body{font-family:'Segoe UI',Arial,sans-serif;margin:0;background:#f4f6f8;color:#1f2933;}")
	$lines.Add(".page{max-width:1280px;margin:0 auto;padding:28px;}")
	$lines.Add(".hero{background:#12324a;color:white;padding:28px 34px;border-radius:10px;margin-bottom:22px;}")
	$lines.Add(".hero h1{margin:0 0 8px 0;font-size:30px;}")
	$lines.Add(".hero p{margin:0;color:#d8e6ef;font-size:14px;}")
	$lines.Add(".cards{display:grid;grid-template-columns:repeat(5,1fr);gap:12px;margin-bottom:22px;}")
	$lines.Add(".card{background:white;border:1px solid #d9e2ec;border-radius:8px;padding:14px;}")
	$lines.Add(".card .label{font-size:12px;text-transform:uppercase;color:#627d98;font-weight:700;}")
	$lines.Add(".card .value{font-size:24px;font-weight:700;margin-top:6px;color:#102a43;}")
	$lines.Add("section{background:white;border:1px solid #d9e2ec;border-radius:8px;margin-bottom:20px;padding:18px;}")
	$lines.Add("h2{font-size:20px;margin:0 0 8px 0;color:#102a43;}")
	$lines.Add(".section-note{margin:0 0 14px 0;color:#52606d;line-height:1.45;}")
	$lines.Add(".empty{color:#829ab1;font-style:italic;}")
	$lines.Add("table{border-collapse:collapse;width:100%;font-size:12px;}")
	$lines.Add("th{background:#d9e8f5;color:#102a43;text-align:left;padding:8px;border:1px solid #bcccdc;position:sticky;top:0;}")
	$lines.Add("td{padding:7px 8px;border:1px solid #d9e2ec;vertical-align:top;}")
	$lines.Add("td.number{text-align:right;font-variant-numeric:tabular-nums;}")
	$lines.Add("tr:nth-child(even){background:#f8fbfd;}")
	$lines.Add("tr.ok{background:#edf8f1;}")
	$lines.Add("tr.notice{background:#fffbea;}")
	$lines.Add("tr.warning{background:#fff3e6;}")
	$lines.Add("tr.critical{background:#ffe8e8;}")
	$lines.Add(".legend{display:flex;gap:10px;flex-wrap:wrap;margin-top:10px;}")
	$lines.Add(".pill{border-radius:999px;padding:5px 10px;font-size:12px;border:1px solid #bcccdc;background:#f8fbfd;}")
	$lines.Add(".footer{color:#627d98;font-size:12px;margin:18px 0;}")
	$lines.Add(".guide-callout{background:#fffbea;border:1px solid #f0b429;border-left:6px solid #f0b429;border-radius:8px;margin-bottom:22px;padding:16px 18px;}")
	$lines.Add(".guide-callout h2{margin:0 0 6px 0;color:#8d2b0b;}")
	$lines.Add(".guide-callout p{margin:0 0 12px 0;color:#513c06;line-height:1.45;}")
	$lines.Add(".guide-link{display:inline-block;background:#12324a;color:white;text-decoration:none;font-weight:700;border-radius:6px;padding:9px 13px;}")
	$lines.Add("@media print{body{background:white}.page{padding:0}.hero,section,.card{break-inside:avoid}.cards{grid-template-columns:repeat(3,1fr)}th{position:static}}")
	$lines.Add("</style>")
	$lines.Add("</head>")
	$lines.Add("<body>")
	$lines.Add("<div class=""page"">")
	$lines.Add("<div class=""hero"">")
	$lines.Add("<h1>Performance Audit Report</h1>")
	$lines.Add("<p>Generated $generatedAt. This report summarizes Arma 2 Warfare audit logs and highlights FPS context, script cost and execution spikes.</p>")
	$lines.Add("</div>")

	$lines.Add("<section class=""guide-callout"">")
	$lines.Add("<h2>Read This First</h2>")
	$lines.Add("<p>This report contains several kinds of metrics. Some indicate probable active script cost, some indicate call volume, and some can include waiting time. Open the interpretation guide before drawing optimization conclusions.</p>")
	$lines.Add("<a class=""guide-link"" href=""performance_interpretation.html"">Open interpretation guide</a>")
	$lines.Add("</section>")

	$lines.Add("<div class=""cards"">")
	$lines.Add("<div class=""card""><div class=""label"">Audit rows</div><div class=""value"">$($Rows.Count)</div></div>")
	$lines.Add("<div class=""card""><div class=""label"">Sessions</div><div class=""value"">$sessionCount</div></div>")
	$lines.Add("<div class=""card""><div class=""label"">Average FPS</div><div class=""value"">$avgFps</div></div>")
	$lines.Add("<div class=""card""><div class=""label"">Minimum FPS</div><div class=""value"">$minFps</div></div>")
	$lines.Add("<div class=""card""><div class=""label"">Max AI / Players</div><div class=""value"">$maxAi / $maxPlayers</div></div>")
	$lines.Add("</div>")

	$lines.Add("<section>")
	$lines.Add("<h2>How To Read This Report</h2>")
	$lines.Add("<p class=""section-note"">Start with <strong>Session Overview</strong> when the RPT contains several appended games, then compare <strong>Session X - Detailed Script Cost</strong> between runs. After that, use <strong>Map / Scope FPS</strong>, <strong>Top Scripts By Total Cost</strong>, <strong>Top Spikes</strong> and <strong>Worst FPS Snapshots</strong> for global context.</p>")
	$lines.Add("<div class=""legend""><span class=""pill"">Green: acceptable FPS or low spike</span><span class=""pill"">Yellow/orange: warning</span><span class=""pill"">Red: critical FPS or spike</span><span class=""pill"">Total ms = calls * avg ms</span></div>")
	$lines.Add("</section>")

	Add-HtmlTable `
		-Lines $lines `
		-Title "Session Overview" `
		-Description "One RPT can contain several appended games. This table separates each detected session and shows the best available session anchor. New audit logs write a dedicated anchor row with SID, tick and frame. It intentionally does not display mission date/time because fixed mission dates are misleading." `
		-Rows $MapSummary `
		-Columns @("session_index","session_start","session_start_source","map","scope","samples","avg_fps","min_fps","p10_fps","p50_fps","p90_fps","avg_ai","max_ai","avg_markers","avg_vd") `
		-Labels $labels `
		-Kind "map"

	foreach ($sessionIndex in $sessionIndexes) {
		$sessionRows = @($Rows | Where-Object { $_.session_index -eq $sessionIndex })
		if ($sessionRows.Count -eq 0) { continue }

		$sessionStart = $sessionRows[0].session_start
		$sessionSource = $sessionRows[0].session_start_source
		$sessionTopScripts = @($ScriptSummary | Where-Object { $_.session_index -eq $sessionIndex } | Sort-Object total_ms -Descending | Select-Object -First 25)
		$sessionTopSpikes = @($Spikes | Where-Object { $_.session_index -eq $sessionIndex } | Sort-Object max_ms -Descending | Select-Object -First 20)

		Add-HtmlTable `
			-Lines $lines `
			-Title "Session $sessionIndex - Detailed Script Cost" `
			-Description "Detailed script ranking for session $sessionIndex, anchor $sessionStart ($sessionSource). Use this section to compare the same script before and after mission updates without mixing appended RPT sessions." `
			-Rows $sessionTopScripts `
			-Columns @("session_index","session_start","map","scope","script","samples","total_calls","total_ms","weighted_avg_ms","max_ms","spike_rows_25ms","spike_rows_50ms","spike_rows_100ms","avg_fps","min_fps","avg_ai","max_ai","avg_markers") `
			-Labels $labels `
			-Kind "spike"

		Add-HtmlTable `
			-Lines $lines `
			-Title "Session $sessionIndex - Detailed Spikes" `
			-Description "Largest spike rows for session $sessionIndex only. These rows are useful when checking whether a recently optimized script still produces visible stalls in this specific game." `
			-Rows $sessionTopSpikes `
			-Columns @("session_index","session_start","map","scope","player","script","fps","players","ai","markers","vd","calls","avg_ms","max_ms","extra") `
			-Labels $labels `
			-Kind "spike"
	}

	Add-HtmlTable `
		-Lines $lines `
		-Title "Map / Scope FPS" `
		-Description "Global FPS context grouped by session, map and locality. P10 means 10 percent of snapshots were at or below that FPS; it is useful for measuring bad moments without relying only on the absolute minimum." `
		-Rows $MapSummary `
		-Columns @("session_index","session_start","map","scope","samples","avg_fps","min_fps","p10_fps","p50_fps","p90_fps","avg_ai","max_ai","avg_markers") `
		-Labels $labels `
		-Kind "map"

	Add-HtmlTable `
		-Lines $lines `
		-Title "FPS By AI Load" `
		-Description "FPS grouped by AI count ranges for each session/player. This is the easiest way to see whether client performance collapses as the mission grows. P10 FPS is the most useful comfort indicator because it ignores one-off minimum outliers but still captures bad moments." `
		-Rows $fpsByAiLoad `
		-Columns @("session_index","session_start","map","scope","player","ai_bin","samples","avg_fps","min_fps","p10_fps","p90_fps","avg_players","max_players","avg_ai","max_ai","avg_units","avg_vehicles","avg_markers","avg_vd") `
		-Labels $labels `
		-Kind "map"

	Add-HtmlTable `
		-Lines $lines `
		-Title "Top Scripts By Total Cost" `
		-Description "Scripts ranked by cumulative measured cost. A script can be important either because it is expensive once, or because it runs very often. Weighted average is total_ms divided by total calls." `
		-Rows $topScripts `
		-Columns @("session_index","session_start","map","scope","script","samples","total_calls","total_ms","weighted_avg_ms","max_ms","spike_rows_25ms") `
		-Labels $labels `
		-Kind "spike"

	Add-HtmlTable `
		-Lines $lines `
		-Title "Top Spikes" `
		-Description "Largest MAX_MS rows. These rows identify rare but visible stalls. The Extra column gives script-specific context such as marker operations, AI counts, town counts or network writes." `
		-Rows $topSpikes `
		-Columns @("session_index","session_start","map","scope","player","script","fps","players","ai","markers","calls","avg_ms","max_ms","extra") `
		-Labels $labels `
		-Kind "spike"

	Add-HtmlTable `
		-Lines $lines `
		-Title "Worst FPS Snapshots" `
		-Description "Lowest FPS snapshots and their mission context. This helps correlate bad FPS with AI count, player count, view distance, markers, day/night and weather." `
		-Rows $worstSnapshots `
		-Columns @("session_index","session_start","map","scope","player","fps","players","ai","units","vehicles","markers","vd","dnc","daytime","fog","overcast","rain") `
		-Labels $labels `
		-Kind "fps"

	Add-HtmlTable `
		-Lines $lines `
		-Title "Player Summary" `
		-Description "Client-oriented summary. Compare players to separate mission-wide performance issues from one client machine or settings profile." `
		-Rows $PlayerSummary `
		-Columns @("session_index","session_start","map","scope","player","samples","avg_fps","min_fps","p10_fps","avg_ai","max_ai","avg_vd") `
		-Labels $labels `
		-Kind "map"

	Add-HtmlTable `
		-Lines $lines `
		-Title "New Audit Probe Coverage" `
		-Description "All dedicated probes added for the current FPS investigation. This table confirms that each probe is visible in the HTML report, even when it is not expensive enough to appear in the global Top Scripts table." `
		-Rows $probeCoverage `
		-Columns @("session_index","map","scope","script","samples","total_calls","total_ms","weighted_avg_ms","max_ms","spike_rows_25ms") `
		-Labels $labels `
		-Kind "spike"

	Add-HtmlTable `
		-Lines $lines `
		-Title "Unit Creation And Global Init Details" `
		-Description "Focused view for CreateTeam/CreateUnit/CreateVehicle and Init_Unit. Use Global, Init mode, Track infantry, Side match and Unit global forwarded to identify whether AI creation is starting client-side unit initialization or marker scripts unexpectedly." `
		-Rows $unitCreationAudit `
		-Columns @("session_index","map","scope","script","fps","players","ai","calls","avg_ms","max_ms","extra_town","extra_type","extra_side","extra_global","extra_trackInf","extra_init","extra_leaderPlayer","extra_isMan","extra_unitGlobalForwarded","extra_units","extra_vehicles","extra_crews","extra_markerType","extra_refresh","extra_sideMatch","extra_aar","extra_groupPlayer","extra_blinkingEH","extra_cycleMs") `
		-Labels $labels `
		-Kind "spike"

	Add-HtmlTable `
		-Lines $lines `
		-Title "Marker And AAR Details" `
		-Description "Focused view for marker script starts, periodic marker updates, paratrooper markers and anti-air radar markers. Use Active markers, Tracked kind/type and Refresh to see whether marker loops scale with AI, vehicles or aircraft." `
		-Rows $markerAudit `
		-Columns @("session_index","map","scope","script","fps","players","ai","markers","calls","avg_ms","max_ms","extra_markerType","extra_trackedKind","extra_trackedType","extra_type","extra_side","extra_refresh","extra_trackDeath","extra_activeMarkers","extra_activeAAR","extra_visible","extra_textUpdates","extra_upgrade","extra_radarInRange","extra_groupPlayer") `
		-Labels $labels `
		-Kind "spike"

	Add-HtmlTable `
		-Lines $lines `
		-Title "Town AI Delegation And Defense Details" `
		-Description "Focused view for town AI delegation, server fallback, headless client handoff, per-town patrol scripts and town defense operators. Use Delegated versus Fallback groups to see where AI is actually created." `
		-Rows $delegationAudit `
		-Columns @("session_index","map","scope","script","fps","players","ai","calls","avg_ms","max_ms","extra_town","extra_side","extra_groups","extra_teams","extra_delegators","extra_delegated","extra_fallbackGroups","extra_fallbackVehicles","extra_headless","extra_vehicles","extra_defenses","extra_spawned","extra_removed","extra_mode","extra_changed","extra_focus","extra_alive","extra_units","extra_cycleMs") `
		-Labels $labels `
		-Kind "spike"

	Add-HtmlTable `
		-Lines $lines `
		-Title "Client Scaling Probes" `
		-Description "Focused view for client-side loops that can scale with town count or player AI group size. Distance checks and text writes are especially useful when FPS drops while view distance is fixed." `
		-Rows $clientScalingAudit `
		-Columns @("session_index","map","scope","player","script","fps","players","ai","calls","avg_ms","max_ms","extra_towns","extra_groupUnits","extra_visible","extra_textWrites","extra_distanceChecks","extra_map","extra_gps","extra_watched","extra_recovered") `
		-Labels $labels `
		-Kind "spike"

	Add-HtmlTable `
		-Lines $lines `
		-Title "Server Maintenance Probes" `
		-Description "Focused view for cleaners and restorers. These are usually periodic spike candidates rather than permanent FPS causes, but scanned/deleted/restored counts make their impact visible." `
		-Rows $maintenanceAudit `
		-Columns @("session_index","map","scope","script","calls","avg_ms","max_ms","extra_scanned","extra_deleted","extra_weaponholders","extra_mines","extra_mineE","extra_small","extra_long","extra_tracked","extra_restored","extra_cycleMs") `
		-Labels $labels `
		-Kind "spike"

	$lines.Add("<section>")
	$lines.Add("<h2>Generated Files</h2>")
	$lines.Add("<p class=""section-note"">Use <strong>performance_by_session.csv</strong> for the session overview, then <strong>performance_by_script.csv</strong> and <strong>performance_spikes.csv</strong> filtered by Session to compare before/after runs. Use <strong>performance_pivot_ready.csv</strong> for Excel pivot tables and charts; it includes parsed <strong>extra_*</strong> columns from script-specific audit context. The older Markdown report is still generated for quick text sharing.</p>")
	$lines.Add("</section>")

	$lines.Add("<p class=""footer"">Total script cost represented in summaries: $totalScriptMs ms. Report generated by Performance Audit Analyzer.</p>")
	$lines.Add("</div>")
	$lines.Add("</body>")
	$lines.Add("</html>")

	[System.IO.File]::WriteAllLines($Path, $lines, [System.Text.Encoding]::UTF8)
}

function Write-InterpretationGuide {
	param([string]$Path)

	$generatedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
	$lines = New-Object System.Collections.Generic.List[string]

	$lines.Add("<!doctype html>")
	$lines.Add("<html>")
	$lines.Add("<head>")
	$lines.Add("<meta charset=""utf-8"">")
	$lines.Add("<title>Performance Audit Interpretation Guide</title>")
	$lines.Add("<style>")
	$lines.Add("body{font-family:'Segoe UI',Arial,sans-serif;margin:0;background:#f4f6f8;color:#1f2933;line-height:1.55;}")
	$lines.Add(".page{max-width:1120px;margin:0 auto;padding:28px;}")
	$lines.Add(".hero{background:#12324a;color:white;padding:28px 34px;border-radius:10px;margin-bottom:22px;}")
	$lines.Add(".hero h1{margin:0 0 8px 0;font-size:30px;}")
	$lines.Add(".hero p{margin:0;color:#d8e6ef;font-size:14px;}")
	$lines.Add(".back{display:inline-block;margin-top:14px;background:white;color:#12324a;text-decoration:none;font-weight:700;border-radius:6px;padding:8px 12px;}")
	$lines.Add("section{background:white;border:1px solid #d9e2ec;border-radius:8px;margin-bottom:20px;padding:20px;}")
	$lines.Add("h2{font-size:21px;margin:0 0 10px 0;color:#102a43;}")
	$lines.Add("h3{font-size:16px;margin:18px 0 6px 0;color:#243b53;}")
	$lines.Add("p{margin:0 0 12px 0;}")
	$lines.Add("ul{margin:8px 0 0 20px;padding:0;}")
	$lines.Add("li{margin:6px 0;}")
	$lines.Add("table{border-collapse:collapse;width:100%;font-size:13px;margin-top:10px;}")
	$lines.Add("th{background:#d9e8f5;color:#102a43;text-align:left;padding:9px;border:1px solid #bcccdc;}")
	$lines.Add("td{padding:8px 9px;border:1px solid #d9e2ec;vertical-align:top;}")
	$lines.Add("tr:nth-child(even){background:#f8fbfd;}")
	$lines.Add(".warn{background:#fffbea;border-left:6px solid #f0b429;}")
	$lines.Add(".ok{background:#edf8f1;border-left:6px solid #3ebd6b;}")
	$lines.Add(".bad{background:#ffe8e8;border-left:6px solid #d64545;}")
	$lines.Add("code{background:#edf2f7;border-radius:4px;padding:1px 4px;}")
	$lines.Add("</style>")
	$lines.Add("</head>")
	$lines.Add("<body>")
	$lines.Add("<div class=""page"">")
	$lines.Add("<div class=""hero"">")
	$lines.Add("<h1>Performance Audit Interpretation Guide</h1>")
	$lines.Add("<p>Generated $generatedAt. Use this page before interpreting the report tables.</p>")
	$lines.Add("<a class=""back"" href=""performance_report.html"">Back to performance report</a>")
	$lines.Add("</div>")

	$lines.Add("<section class=""warn"">")
	$lines.Add("<h2>Important Rule</h2>")
	$lines.Add("<p>Do not rank scripts by a single number. A high total can mean many cheap calls. A high max can be one rare spike. A long elapsed time can include scheduled sleeps or database waiting. Optimization priority should combine repeated spikes, weighted average, gameplay context, and whether the code runs on client or server.</p>")
	$lines.Add("</section>")

	$lines.Add("<section>")
	$lines.Add("<h2>What Each Indicator Means</h2>")
	$lines.Add("<table>")
	$lines.Add("<thead><tr><th>Indicator</th><th>Meaning</th><th>How to use it</th></tr></thead>")
	$lines.Add("<tbody>")
	$lines.Add("<tr><td><code>Samples</code></td><td>Number of audit summary rows where the script or context appears.</td><td>Shows how often the audit observed that script. It is not the exact number of script executions.</td></tr>")
	$lines.Add("<tr><td><code>Calls</code></td><td>Total measured calls reported by the instrumentation during the sampled period.</td><td>High calls can indicate hot code, but it is only a problem if average or spikes are also meaningful.</td></tr>")
	$lines.Add("<tr><td><code>Total ms</code></td><td>Estimated cumulative time, generally <code>calls * avg ms</code>.</td><td>Good for finding scripts that consume time over the whole session. Do not use it alone for blame.</td></tr>")
	$lines.Add("<tr><td><code>Weighted avg ms</code></td><td>Total measured time divided by total calls.</td><td>Best first signal for per-call cost. Higher values mean each call is more expensive.</td></tr>")
	$lines.Add("<tr><td><code>Max ms</code></td><td>Highest measured value seen for that script.</td><td>Good for finding visible stalls. Client-side max above 25-50 ms deserves attention; repeated 100 ms spikes are serious.</td></tr>")
	$lines.Add("<tr><td><code>Spike rows</code></td><td>Number of audit rows where max time crossed 10, 25, 50 or 100 ms.</td><td>Separates one-off noise from repeated risk. Repeated spikes matter more than one isolated spike.</td></tr>")
	$lines.Add("<tr><td><code>P10 FPS</code></td><td>10 percent of snapshots were at or below this FPS.</td><td>Better than minimum FPS for measuring bad moments without overreacting to one outlier.</td></tr>")
	$lines.Add("<tr><td><code>AI bin</code></td><td>FPS grouped by AI count ranges.</td><td>Shows whether performance degrades as the mission grows.</td></tr>")
	$lines.Add("<tr><td><code>DNC / Daytime / Weather</code></td><td>Day/night cycle and weather context.</td><td>Use this to compare FPS under different environment states when enough samples exist.</td></tr>")
	$lines.Add("<tr><td><code>Session anchor</code></td><td>Identifier shown at the start of each detected game session.</td><td>Use this to compare appended RPT sessions before and after mission updates. New logs show the audit anchor tick/frame instead of mission date/time, because fixed mission dates can be misleading.</td></tr>")
	$lines.Add("<tr><td><code>Anchor source</code></td><td>How the analyzer determined the session anchor.</td><td><code>rpt_datetime_prefix</code> means a real timestamp was present in the RPT text. <code>audit_session_anchor_no_realtime</code> means the mission-side audit anchor was found, but Arma 2 OA did not expose real OS time. <code>rpt_time_prefix_file_date_estimate</code> and <code>source_file_last_write_fallback</code> are weaker fallbacks.</td></tr>")
	$lines.Add("</tbody>")
	$lines.Add("</table>")
	$lines.Add("</section>")

	$lines.Add("<section>")
	$lines.Add("<h2>How To Prioritize</h2>")
	$lines.Add("<table>")
	$lines.Add("<thead><tr><th>Priority</th><th>Typical signs</th><th>Recommended action</th></tr></thead>")
	$lines.Add("<tbody>")
	$lines.Add("<tr><td><strong>P0</strong></td><td>Repeated spikes above 50-100 ms, high weighted average, and direct client/server gameplay impact.</td><td>Investigate first. Add toggles, reduce frequency, cache results, or split work over time.</td></tr>")
	$lines.Add("<tr><td><strong>P1</strong></td><td>High cumulative total, moderate weighted average, occasional spikes, or clear scaling with AI/players/markers.</td><td>Optimize after P0, especially if it runs often during combat.</td></tr>")
	$lines.Add("<tr><td><strong>P2</strong></td><td>Huge call volume but tiny weighted average and no spikes.</td><td>Monitor. Optimize only if easy or if it becomes noisy at larger scale.</td></tr>")
	$lines.Add("<tr><td><strong>Monitoring</strong></td><td>Large elapsed time that may include sleep, polling, extension/database wait, or scheduled yielding.</td><td>Do not call it an FPS cause until active time is separated from wait time.</td></tr>")
	$lines.Add("</tbody>")
	$lines.Add("</table>")
	$lines.Add("</section>")

	$lines.Add("<section class=""ok"">")
	$lines.Add("<h2>Client-Side Reading</h2>")
	$lines.Add("<p>Client-side scripts can directly affect a player's FPS. Prioritize repeated spikes and scripts that run during map/UI/marker updates. A script with many tiny calls is usually less dangerous than a script with fewer calls but repeated 50-100 ms spikes.</p>")
	$lines.Add("<h3>Common interpretation</h3>")
	$lines.Add("<ul>")
	$lines.Add("<li><code>bookkeep_blinking_icons</code>: strong suspect when it shows repeated spikes. It is a good candidate for a client-side WF menu option.</li>")
	$lines.Add("<li><code>updateteamsmarkers</code>: important when cumulative cost is high or spikes appear; usually a frequency/caching candidate.</li>")
	$lines.Add("<li><code>markerupdate_unit</code>: high call volume alone is not enough. If weighted average and max stay very low, it is not a first priority.</li>")
	$lines.Add("</ul>")
	$lines.Add("</section>")

	$lines.Add("<section class=""ok"">")
	$lines.Add("<h2>Server-Side Reading</h2>")
	$lines.Add("<p>Server-side scripts can affect simulation, networking and delayed gameplay. Server FPS alone may look stable if the server is capped, so read script spikes and mission context too.</p>")
	$lines.Add("<h3>Common interpretation</h3>")
	$lines.Add("<ul>")
	$lines.Add("<li><code>server_town_ai</code>: high priority when it shows repeated spikes, because it is mission/AI logic and can scale with active towns and AI counts.</li>")
	$lines.Add("<li><code>server_town_camp</code>: usually a volume monitor. Many calls are acceptable if weighted average and max remain low.</li>")
	$lines.Add("<li><code>antistack_main</code> / <code>antistack_flush</code>: treat as monitored unless active time is separated from database wait, polling and sleeps.</li>")
	$lines.Add("</ul>")
	$lines.Add("</section>")

	$lines.Add("<section class=""bad"">")
	$lines.Add("<h2>Common Mistakes To Avoid</h2>")
	$lines.Add("<ul>")
	$lines.Add("<li>Do not say a script is the cause only because <code>Total ms</code> is high.</li>")
	$lines.Add("<li>Do not treat scheduled wait time or database polling as active CPU cost without a dedicated active-time measurement.</li>")
	$lines.Add("<li>Do not compare client and server rows as if they measured the same impact. Client rows affect local FPS; server rows affect simulation and network timing.</li>")
	$lines.Add("<li>Do not trust a single session blindly. Re-test after optimizations and compare the same map, player count, AI count and view distance.</li>")
	$lines.Add("</ul>")
	$lines.Add("</section>")

	$lines.Add("</div>")
	$lines.Add("</body>")
	$lines.Add("</html>")

	[System.IO.File]::WriteAllLines($Path, $lines, [System.Text.Encoding]::UTF8)
}

$delimiter = Get-CsvDelimiter $CsvDelimiter
$outputDirectory = New-Item -ItemType Directory -Force -Path $OutputPath
$files = @(Get-InputFiles $InputPath)

if ($files.Count -eq 0) {
	throw "No input files found for: $InputPath"
}

Write-Host "Reading $($files.Count) file(s)..."

$rows = New-Object System.Collections.Generic.List[object]
$index = 0
$sidIndexes = @{}
$nextSidIndex = 0
$legacySessionIndex = 0
$lastRowWasSessionStart = $false
$sessionStarts = @{}

foreach ($file in $files) {
	$lineNumber = 0
	$lastRowWasSessionStart = $false
	$fileLastWriteTime = $file.LastWriteTime
	$fileLastWriteText = $fileLastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
	$currentRptDate = $null
	$lastRptTimeOfDay = $null
	Get-Content -LiteralPath $file.FullName | ForEach-Object {
		$lineNumber++
		if ($_ -like "*[Performance Audit]*") {
			$index++
			$rptTimestamp = ""
			$rptTimestampSource = ""
			$rptDateTimePrefix = Get-RptDateTimePrefix $_
			if ($null -ne $rptDateTimePrefix) {
				$currentRptDate = $rptDateTimePrefix.Date
				$lastRptTimeOfDay = $rptDateTimePrefix.TimeOfDay
				$rptTimestamp = $rptDateTimePrefix.ToString("yyyy-MM-dd HH:mm:ss")
				$rptTimestampSource = "rpt_datetime_prefix"
			} else {
				$rptTimeOfDayPrefix = Get-RptTimeOfDayPrefix $_
				if ($null -ne $rptTimeOfDayPrefix) {
					if ($null -eq $currentRptDate) {
						$currentRptDate = $fileLastWriteTime.Date
						if ($rptTimeOfDayPrefix -gt $fileLastWriteTime.TimeOfDay.Add([timespan]::FromHours(1))) {
							$currentRptDate = $currentRptDate.AddDays(-1)
						}
					} elseif ($null -ne $lastRptTimeOfDay -and $rptTimeOfDayPrefix -lt $lastRptTimeOfDay.Subtract([timespan]::FromHours(1))) {
						$currentRptDate = $currentRptDate.AddDays(1)
					}

					$lastRptTimeOfDay = $rptTimeOfDayPrefix
					$rptTimestamp = $currentRptDate.Add($rptTimeOfDayPrefix).ToString("yyyy-MM-dd HH:mm:ss")
					$rptTimestampSource = "rpt_time_prefix_file_date_estimate"
				}
			}

			$row = ConvertFrom-PerformanceAuditLine -Line $_ -SourceFile $file.FullName -SourceFileLastWriteTime $fileLastWriteText -LineNumber $lineNumber -Index $index -RptTimestamp $rptTimestamp -RptTimestampSource $rptTimestampSource
			if ($null -ne $row) {
				$isSessionStart = ($row.script -eq "session" -and ([string]$row.extra) -like "state:start*")
				if (![string]::IsNullOrWhiteSpace($row.sid)) {
					if (!$sidIndexes.ContainsKey($row.sid)) {
						$nextSidIndex++
						$sidIndexes[$row.sid] = $nextSidIndex
					}
					$row.session_index = $sidIndexes[$row.sid]
					$row.session_key = $row.sid
					$lastRowWasSessionStart = $false
				} else {
					if ($isSessionStart -and !$lastRowWasSessionStart) {
						$legacySessionIndex++
					}
					if ($legacySessionIndex -eq 0) { $legacySessionIndex = 1 }
					$row.session_index = $legacySessionIndex
					$row.session_key = "LEGACY_{0:000}" -f $legacySessionIndex
					$lastRowWasSessionStart = $isSessionStart
				}

				$anchorSessionStart = Get-AuditAnchorSessionStart $row
				if ($null -ne $anchorSessionStart -and $row.rpt_timestamp_source -ne "rpt_datetime_prefix") {
					$sessionStarts[$row.session_key] = $anchorSessionStart
				}

				if (!$sessionStarts.ContainsKey($row.session_key)) {
					$sessionStart = $row.rpt_timestamp
					$sessionStartSource = $row.rpt_timestamp_source
					if ([string]::IsNullOrWhiteSpace($sessionStart)) {
						$sessionStart = $fileLastWriteText
						$sessionStartSource = "source_file_last_write_fallback"
					}

					$sessionStarts[$row.session_key] = [pscustomobject]@{
						session_start = $sessionStart
						session_start_source = $sessionStartSource
					}
				}

				$row.session_start = $sessionStarts[$row.session_key].session_start
				$row.session_start_source = $sessionStarts[$row.session_key].session_start_source

				$rows.Add($row)
			}
		}
	}
}

$allRows = @($rows.ToArray())
if ($allRows.Count -eq 0) {
	Write-Warning "No [Performance Audit] lines were found."
	return
}

foreach ($row in $allRows) {
	if ($sessionStarts.ContainsKey($row.session_key)) {
		$row.session_start = $sessionStarts[$row.session_key].session_start
		$row.session_start_source = $sessionStarts[$row.session_key].session_start_source
	}
}

$timeline = @(New-Timeline $allRows)
$scriptSummary = @(New-ScriptSummary $allRows)
$spikes = @(New-SpikeTable $allRows $SpikeThresholdMs)
$fpsContext = @(New-FpsContext $timeline)
$playerSummary = @(New-PlayerSummary $timeline)
$mapSummary = @(New-MapSummary $timeline)
$extraKeys = @(
	"type","side","global","trackInf","init","leaderPlayer","isMan","unitGlobalForwarded",
	"templates","infantry","vehicles","crews","skipped",
	"town","groups","teams","units","cycleMs",
	"markerType","refresh","sideMatch","aar","groupPlayer","blinkingEH",
	"trackedKind","trackedType","trackDeath","activeMarkers",
	"activeAAR","visible","textUpdates","upgrade","radarInRange",
	"delegators","delegated","fallbackGroups","fallbackVehicles","headless",
	"defenses","spawned","removed","mode","changed","focus","alive",
	"towns","groupUnits","textWrites","distanceChecks","map","gps","watched","recovered",
	"scanned","deleted","weaponholders","mines","mineE","small","long","tracked","restored",
	"bounty","locked","special","isAir","isTank","isCar"
)
$expandedRows = @(New-ExpandedAuditRows $allRows $extraKeys)

Export-AuditCsv $allRows (Join-Path $outputDirectory.FullName "performance_raw.csv") $delimiter
Export-AuditCsv $expandedRows (Join-Path $outputDirectory.FullName "performance_pivot_ready.csv") $delimiter
Export-AuditCsv $expandedRows (Join-Path $outputDirectory.FullName "performance_extra_fields.csv") $delimiter
Export-AuditCsv $timeline (Join-Path $outputDirectory.FullName "performance_timeline.csv") $delimiter
Export-AuditCsv $scriptSummary (Join-Path $outputDirectory.FullName "performance_by_script.csv") $delimiter
Export-AuditCsv $spikes (Join-Path $outputDirectory.FullName "performance_spikes.csv") $delimiter
Export-AuditCsv $fpsContext (Join-Path $outputDirectory.FullName "performance_fps_context.csv") $delimiter
Export-AuditCsv $playerSummary (Join-Path $outputDirectory.FullName "performance_by_player.csv") $delimiter
Export-AuditCsv $mapSummary (Join-Path $outputDirectory.FullName "performance_by_map.csv") $delimiter
Export-AuditCsv $mapSummary (Join-Path $outputDirectory.FullName "performance_by_session.csv") $delimiter

Write-MarkdownReport `
	-Path (Join-Path $outputDirectory.FullName "performance_report.md") `
	-Rows $allRows `
	-TimelineRows $timeline `
	-ScriptSummary $scriptSummary `
	-Spikes $spikes `
	-FpsContext $fpsContext `
	-PlayerSummary $playerSummary `
	-MapSummary $mapSummary

$htmlReportPath = Join-Path $outputDirectory.FullName "performance_report.html"
$interpretationGuidePath = Join-Path $outputDirectory.FullName "performance_interpretation.html"
Write-HtmlReport `
	-Path $htmlReportPath `
	-Rows $allRows `
	-TimelineRows $timeline `
	-ScriptSummary $scriptSummary `
	-Spikes $spikes `
	-PlayerSummary $playerSummary `
	-MapSummary $mapSummary

Write-InterpretationGuide -Path $interpretationGuidePath

Copy-Item -LiteralPath $htmlReportPath -Destination (Join-Path $outputDirectory.FullName "performance_report_word.doc") -Force

Write-Host "Done."
Write-Host "Output: $($outputDirectory.FullName)"
Write-Host "Rows: $($allRows.Count)"
Write-Host "Spikes >= $SpikeThresholdMs ms: $($spikes.Count)"
