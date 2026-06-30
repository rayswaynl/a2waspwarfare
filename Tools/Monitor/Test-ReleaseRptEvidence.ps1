# Test-ReleaseRptEvidence.ps1 - release RPT evidence scanner for July 2026.
#
# Scans one or more Arma 2 OA RPT files using the shared current-mission window
# helper, then summarizes stop-condition errors and release evidence markers.
# Use after the exact release candidate has been launched with SERVER_DEBUG.
#
# Examples:
#   .\Test-ReleaseRptEvidence.ps1 -RptPath C:\WASP\rpt\server.RPT -RequireServerDebug -RequirePr122Markers -RequireAicomTelemetry
#   .\Test-ReleaseRptEvidence.ps1 -RptPath @($server,$hc1,$hc2,$client) -OutputJson C:\WASP\rpt\evidence.json

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string[]] $RptPath,
    [string] $WindowMarker = 'MISSINIT|## (Mission Name|Build|LOG CONTENT)',
    [int] $MaxMatchesPerPattern = 20,
    [switch] $RequireServerDebug,
    [switch] $RequirePr122Markers,
    [switch] $RequireAicomTelemetry,
    [string] $OutputJson
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'Get-WindowedRpt.ps1')

$stopPatterns = @(
    'Error in expression',
    'Undefined variable',
    'No entry',
    'Missing ;',
    'Generic error',
    'Error position',
    'Unknown command',
    'Cannot load texture',
    'Cannot open object'
)

$markerPatterns = @(
    @{ Name = 'startup_mission_name'; Pattern = '## Mission Name' },
    @{ Name = 'startup_build'; Pattern = '## Build' },
    @{ Name = 'log_content'; Pattern = '## LOG CONTENT' },
    @{ Name = 'log_content_not_activated'; Pattern = '## LOG CONTENT : \[NOT ACTIVATED\]' },
    @{ Name = 'pr122_editor_slot_audit'; Pattern = 'editor-slot audit tagged' },
    @{ Name = 'pr122_disconnect_retry'; Pattern = 'WFBE_CONNECT_RETRY' },
    @{ Name = 'pr122_clientupgrade_guard'; Pattern = 'CLIENTUPGRADE\|SKIP' },
    @{ Name = 'pr122_heli_guard_on'; Pattern = 'server_heli_terrain_guard\.sqf: AI-heli terrain guard ON' },
    @{ Name = 'aicom_tick'; Pattern = 'AICOMSTAT\|v1\|TICK' },
    @{ Name = 'aicom_event'; Pattern = 'AICOMSTAT\|v2\|EVENT' },
    @{ Name = 'commander_status'; Pattern = 'CMDRSTAT\|v1' },
    @{ Name = 'combat_status'; Pattern = 'COMBATSTAT' },
    @{ Name = 'team_founded'; Pattern = 'TEAM_FOUNDED' },
    @{ Name = 'assault_dispatch'; Pattern = 'ASSAULT_DISPATCH' },
    @{ Name = 'hc_control'; Pattern = 'HC-AI-Control|HCDELEG|HCDISPATCH|Init_HC\.sqf' },
    @{ Name = 'client_init'; Pattern = 'Init_Client\.sqf: Client initialization (begins|ended)' },
    @{ Name = 'jip_client_health'; Pattern = 'CLIENTTEAMS|CLIENTROSTER|\[WFBE\]\[B56 JIP-FIX\]' },
    @{ Name = 'wasp_stats'; Pattern = 'WASPSTAT\|v1' }
)

function Find-PatternMatches {
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string[]] $Lines,
        [Parameter(Mandatory)] [string] $Pattern,
        [int] $Limit = 20
    )

    $hits = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match $Pattern) {
            [void]$hits.Add((New-Object psobject -Property @{
                line = $i + 1
                text = $Lines[$i].Trim()
            }))
            if ($Limit -gt 0 -and $hits.Count -ge $Limit) { break }
        }
    }
    return @($hits)
}

$fileReports = New-Object System.Collections.ArrayList
$totalStopMatches = 0
$aggregateMarkers = [ordered]@{}
foreach ($marker in $markerPatterns) { $aggregateMarkers[$marker['Name']] = 0 }

foreach ($path in $RptPath) {
    $exists = Test-Path -LiteralPath $path
    if ($exists) {
        $windowLines = @(Get-WindowedRpt -RptPath $path -WindowMarker $WindowMarker)
    } else {
        $windowLines = @()
    }

    $stopReports = New-Object System.Collections.ArrayList
    foreach ($pattern in $stopPatterns) {
        $hits = @(Find-PatternMatches -Lines $windowLines -Pattern ([regex]::Escape($pattern)) -Limit $MaxMatchesPerPattern)
        if ($hits.Count -gt 0) {
            $totalStopMatches += $hits.Count
            [void]$stopReports.Add((New-Object psobject -Property @{
                pattern = $pattern
                count = $hits.Count
                matches = $hits
            }))
        }
    }

    $markerReports = New-Object System.Collections.ArrayList
    foreach ($marker in $markerPatterns) {
        $hits = @(Find-PatternMatches -Lines $windowLines -Pattern $marker['Pattern'] -Limit $MaxMatchesPerPattern)
        $aggregateMarkers[$marker['Name']] += $hits.Count
        [void]$markerReports.Add((New-Object psobject -Property @{
            name = $marker['Name']
            pattern = $marker['Pattern']
            count = $hits.Count
            matches = $hits
        }))
    }

    [void]$fileReports.Add((New-Object psobject -Property @{
        path = $path
        exists = $exists
        window_marker = $WindowMarker
        window_line_count = $windowLines.Count
        has_startup_banner = (@($markerReports | Where-Object { $_.name -eq 'startup_mission_name' -and $_.count -gt 0 }).Count -gt 0)
        log_content_not_activated = (@($markerReports | Where-Object { $_.name -eq 'log_content_not_activated' -and $_.count -gt 0 }).Count -gt 0)
        stop_match_count = ($stopReports | ForEach-Object { $_.count } | Measure-Object -Sum).Sum
        stop_matches = @($stopReports)
        markers = @($markerReports)
    }))
}

$missingFiles = @($fileReports | Where-Object { -not $_.exists }).Count
$filesWithoutStartup = @($fileReports | Where-Object { $_.exists -and -not $_.has_startup_banner }).Count
$filesWithoutLines = @($fileReports | Where-Object { $_.exists -and $_.window_line_count -eq 0 }).Count
$logContentNotActivated = @($fileReports | Where-Object { $_.log_content_not_activated }).Count

$requirements = New-Object System.Collections.ArrayList
[void]$requirements.Add((New-Object psobject -Property @{
    name = 'no_stop_condition_matches'
    required = $true
    passed = ($totalStopMatches -eq 0)
    detail = "$totalStopMatches stop-condition matches"
}))
[void]$requirements.Add((New-Object psobject -Property @{
    name = 'all_files_exist'
    required = $true
    passed = ($missingFiles -eq 0)
    detail = "$missingFiles missing files"
}))
[void]$requirements.Add((New-Object psobject -Property @{
    name = 'all_files_have_window_lines'
    required = $true
    passed = ($filesWithoutLines -eq 0)
    detail = "$filesWithoutLines files with empty current-mission windows"
}))
[void]$requirements.Add((New-Object psobject -Property @{
    name = 'server_debug_content_logging'
    required = [bool]$RequireServerDebug
    passed = (-not $RequireServerDebug -or ($logContentNotActivated -eq 0 -and $aggregateMarkers['log_content'] -gt 0))
    detail = "$logContentNotActivated files report LOG CONTENT not activated"
}))
[void]$requirements.Add((New-Object psobject -Property @{
    name = 'pr122_guard_markers'
    required = [bool]$RequirePr122Markers
    passed = (-not $RequirePr122Markers -or ($aggregateMarkers['pr122_editor_slot_audit'] -gt 0 -and $aggregateMarkers['pr122_disconnect_retry'] -gt 0))
    detail = "editor_slot=$($aggregateMarkers['pr122_editor_slot_audit']); disconnect_retry=$($aggregateMarkers['pr122_disconnect_retry']); clientupgrade_guard=$($aggregateMarkers['pr122_clientupgrade_guard'])"
}))
[void]$requirements.Add((New-Object psobject -Property @{
    name = 'aicom_telemetry'
    required = [bool]$RequireAicomTelemetry
    passed = (-not $RequireAicomTelemetry -or ($aggregateMarkers['aicom_event'] -gt 0 -and $aggregateMarkers['commander_status'] -gt 0))
    detail = "aicom_event=$($aggregateMarkers['aicom_event']); commander_status=$($aggregateMarkers['commander_status']); team_founded=$($aggregateMarkers['team_founded'])"
}))

$requiredFailures = @($requirements | Where-Object { $_.required -and -not $_.passed })
$verdict = if ($requiredFailures.Count -eq 0) { 'PASS' } else { 'FAIL' }

$aggregateMarkerObject = New-Object psobject
foreach ($key in $aggregateMarkers.Keys) {
    Add-Member -InputObject $aggregateMarkerObject -MemberType NoteProperty -Name $key -Value $aggregateMarkers[$key]
}

$report = New-Object psobject -Property @{
    generated_at = (Get-Date).ToString('s')
    verdict = $verdict
    window_marker = $WindowMarker
    total_files = $fileReports.Count
    missing_files = $missingFiles
    files_without_startup_banner = $filesWithoutStartup
    stop_match_count = $totalStopMatches
    aggregate_markers = $aggregateMarkerObject
    requirements = @($requirements)
    files = @($fileReports)
}

if ($OutputJson) {
    $json = $report | ConvertTo-Json -Depth 8
    Set-Content -LiteralPath $OutputJson -Value $json -Encoding UTF8
}

$report | ConvertTo-Json -Depth 8

if ($verdict -ne 'PASS') { exit 2 }
