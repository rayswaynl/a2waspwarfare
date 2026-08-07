#requires -Version 5.1
<#
.SYNOPSIS
    Validates WF_MAXPLAYERS against human-capacity mission.sqm slots.

.DESCRIPTION
    The mission folder prefix and version.sqf.template define are easy to drift
    away from the actual playable lobby slots. This read-only check compares
    WF_MAXPLAYERS in each maintained template against player declarations in the
    matching mission.sqm. The census separates reserved headless-client and
    caster seats from the human capacity.

    WF_MAXPLAYERS reaches the engine as Rsc/Header.hpp `maxPlayers`, i.e. the
    mission's HUMAN capacity: it is what the server browser advertises and what
    Server/Init/Init_Server.sqf reads back into the MATCH|v1|START|missionSlots=
    telemetry field. Slots carrying `forceHeadlessClient=1` are reserved for
    headless clients and are not human capacity, so they are counted separately
    and excluded from the comparison. CIV caster seats are also authored player
    declarations, but their `wfbe_caster_slot` marker (or `description="Caster
    ..."`) reserves them for the caster flow rather than the human capacity.
    The mission-folder prefix convention ("[55-2hc]") makes the HC split.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot
)

$ErrorActionPreference = "Stop"
$script:fails = 0
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $scriptPath = $MyInvocation.MyCommand.Path
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $scriptPath))
}

function Read-RequiredText {
    param([Parameter(Mandatory)] [string]$Path)

    if (!(Test-Path -LiteralPath $Path)) {
        throw "Required file not found: $Path"
    }

    return Get-Content -LiteralPath $Path -Raw
}

function Get-WfMaxPlayers {
    param([Parameter(Mandatory)] [string]$TemplatePath)

    $text = Read-RequiredText $TemplatePath
    $match = [regex]::Match($text, '(?m)^\s*#define\s+WF_MAXPLAYERS\s+([0-9]+)\s*$')
    if (!$match.Success) {
        throw "WF_MAXPLAYERS define not found: $TemplatePath"
    }

    return [int]$match.Groups[1].Value
}

function Remove-LineComments {
    param([Parameter(Mandatory)] [string]$Text)

    $lines = $Text -split "\r?\n"
    return (($lines | ForEach-Object { $_ -replace '//.*$', '' }) -join "`n")
}

function Hide-QuotedStrings {
    param([Parameter(Mandatory)] [string]$Text)

    # Blank the CONTENT of every double-quoted literal while preserving length and
    # offsets, so brace scanning below cannot be derailed by braces inside an
    # init="..." SQF snippet. The quote characters themselves are kept.
    $chars = $Text.ToCharArray()
    $inString = $false
    for ($i = 0; $i -lt $chars.Length; $i++) {
        if ($chars[$i] -eq '"') { $inString = -not $inString; continue }
        if ($inString -and $chars[$i] -ne "`n" -and $chars[$i] -ne "`r") { $chars[$i] = ' ' }
    }
    return (-join $chars)
}

function Get-InnermostBlock {
    param(
        [Parameter(Mandatory)] [string]$Text,
        [Parameter(Mandatory)] [string]$MaskedText,
        [Parameter(Mandatory)] [int]$Index
    )

    # Walk the quote-masked text back to the innermost '{' enclosing $Index, then
    # forward to its match. Return the same range from the original text so
    # reserved-seat markers inside init="..." remain visible to the caster test.
    $depth = 0
    $open = -1
    for ($i = $Index; $i -ge 0; $i--) {
        $c = $MaskedText[$i]
        if ($c -eq '}') { $depth++ }
        elseif ($c -eq '{') {
            if ($depth -eq 0) { $open = $i; break }
            $depth--
        }
    }
    if ($open -lt 0) { return "" }

    $depth = 1
    for ($i = $open + 1; $i -lt $Text.Length; $i++) {
        $c = $MaskedText[$i]
        if ($c -eq '{') { $depth++ }
        elseif ($c -eq '}') {
            $depth--
            if ($depth -eq 0) { return $Text.Substring($open, $i - $open + 1) }
        }
    }
    return $Text.Substring($open)
}

function Get-SlotCensus {
    param([Parameter(Mandatory)] [string]$MissionSqmPath)

    $rawText = Remove-LineComments (Read-RequiredText $MissionSqmPath)
    $text = Hide-QuotedStrings $rawText
    # NOT $matches: that is a PowerShell automatic variable, and the -match below
    # would silently overwrite it mid-loop.
    $slotMatches = [regex]::Matches($text, '(?m)^\s*player\s*=\s*"[^"]*"\s*;')
    $hcPattern = [regex]'(?m)^\s*forceHeadlessClient\s*=\s*[1-9][0-9]*\s*;'
    $casterPattern = [regex]'(?im)^\s*description\s*=\s*"Caster\b|\bwfbe_caster_slot\b'

    $headless = 0
    $caster = 0
    foreach ($m in $slotMatches) {
        $structuralBlock = Get-InnermostBlock -Text $text -MaskedText $text -Index $m.Index
        $visibleBlock = Get-InnermostBlock -Text $rawText -MaskedText $text -Index $m.Index
        if ($hcPattern.IsMatch($structuralBlock)) { $headless++ }
        if ($casterPattern.IsMatch($visibleBlock)) { $caster++ }
    }

    return [pscustomobject]@{
        Total    = $slotMatches.Count
        Headless = $headless
        Caster   = $caster
        Human    = $slotMatches.Count - $headless - $caster
    }
}

$terrains = @(
    [pscustomobject]@{
        Name = "Chernarus"
        MissionRoot = "Missions\[55-2hc]warfarev2_073v48co.chernarus"
    },
    [pscustomobject]@{
        Name = "Takistan"
        MissionRoot = "Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan"
    },
    [pscustomobject]@{
        Name = "Zargabad"
        MissionRoot = "Missions_Vanilla\[61-2hc]warfarev2_073v48co.zargabad"
    }
)

$resolvedRoot = [System.IO.Path]::GetFullPath($RepoRoot)

foreach ($terrain in $terrains) {
    $missionRoot = Join-Path $resolvedRoot $terrain.MissionRoot
    $templatePath = Join-Path $missionRoot "version.sqf.template"
    $missionSqmPath = Join-Path $missionRoot "mission.sqm"

    $maxPlayers = Get-WfMaxPlayers $templatePath
    $census = Get-SlotCensus $missionSqmPath

    $reserved = @()
    if ($census.Headless -gt 0) {
        $reserved += "{0} headless-client slot(s)" -f $census.Headless
    }
    if ($census.Caster -gt 0) {
        $reserved += "{0} caster slot(s)" -f $census.Caster
    }
    $suffix = ""
    if ($reserved.Count -gt 0) {
        $suffix = " ({0} declared - {1})" -f $census.Total, ($reserved -join " - ")
    }

    if ($maxPlayers -eq $census.Human) {
        Write-Host ("  PASS  {0}: WF_MAXPLAYERS={1}, playable slots={2}{3}" -f $terrain.Name, $maxPlayers, $census.Human, $suffix)
    } else {
        Write-Host ("  FAIL  {0}: WF_MAXPLAYERS={1}, playable slots={2}{3}" -f $terrain.Name, $maxPlayers, $census.Human, $suffix) -ForegroundColor Red
        $script:fails++
    }
}

Write-Host ""
if ($script:fails -eq 0) {
    Write-Host "Test-WaspSlotCountConsistency: PASS" -ForegroundColor Green
    exit 0
}

Write-Host ("Test-WaspSlotCountConsistency: {0} mismatch(es)" -f $script:fails) -ForegroundColor Red
exit 1
