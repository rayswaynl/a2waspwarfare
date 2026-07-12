<#
.SYNOPSIS
  Turn A/B findings into a SURFACE-ONLY flag recommendation deck. Never opens a PR, never deploys.

.DESCRIPTION
  Owner ruling 2026-07-07: for testing and recommending, EVERYTHING is allowed to be surfaced. So this
  does NOT gate on an allowlist -- it surfaces every evidence-based recommendation and LABELS its context
  (guer-affecting / side-affecting / owner-rejected / shelved-topic / needs-soak) so the owner has full
  context. The single hard line is enforced structurally: this script only ever writes a recommendation
  record (recommendations.jsonl) + prints a deck. It has no code path that opens a PR, edits mission
  files, or deploys. The owner is the gate for anything that ships.

  For each finding with a decisive verdict (BETTER/WORSE) whose experiment maps to a flag (via
  topExperiments.json), it reads the flag's live default from the Chernarus Init_CommonConstants.sqf and
  emits: {flag, currentDefault, verdict, delta, suggestion, contextLabels[], disposition=SURFACE}.

.NOTES
  A2-OA-1.64 project tooling; reads mission SQF read-only, edits nothing. Guide rev GR-2026-07-03a.
#>
[CmdletBinding()]
param(
    [string] $FindingsPath,
    [string] $ExperimentsPath,
    [string] $ConstantsPath,
    [string] $OutPath,
    [switch] $Json
)
$ErrorActionPreference = 'Stop'
$soakDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($FindingsPath))    { $FindingsPath    = Join-Path $soakDir 'findings.jsonl' }
if ([string]::IsNullOrWhiteSpace($ExperimentsPath)) { $ExperimentsPath = Join-Path $soakDir 'topExperiments.json' }
if ([string]::IsNullOrWhiteSpace($OutPath))         { $OutPath         = Join-Path $soakDir 'recommendations.jsonl' }
if ([string]::IsNullOrWhiteSpace($ConstantsPath)) {
    $repo = Split-Path (Split-Path $soakDir -Parent) -Parent
    $cand = Get-ChildItem -Path (Join-Path $repo 'Missions') -Recurse -Filter 'Init_CommonConstants.sqf' -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -like '*chernarus*' } | Select-Object -First 1
    if ($cand) { $ConstantsPath = $cand.FullName }
}
$HEADER = "# a2wasp-recommendations-v1 jsonl; skip lines beginning with '#'"

function Read-Jsonl([string]$p) {
    $rows = @()
    if (Test-Path -LiteralPath $p) {
        foreach ($ln in [System.IO.File]::ReadAllLines($p)) {
            $t = $ln.Trim(); if ($t.Length -eq 0 -or $t.StartsWith('#')) { continue }
            try { $rows += ($t | ConvertFrom-Json) } catch {}
        }
    }
    return $rows
}

# live default for a flag, parsed from Init_CommonConstants.sqf ( ["WFBE_C_X", <num>] ). null if absent.
function Get-FlagDefault([string]$flag) {
    if ([string]::IsNullOrWhiteSpace($ConstantsPath) -or -not (Test-Path -LiteralPath $ConstantsPath)) { return $null }
    $rx = [regex]('"' + [regex]::Escape($flag) + '"\s*,\s*(-?\d+(?:\.\d+)?)')
    foreach ($ln in [System.IO.File]::ReadAllLines($ConstantsPath)) {
        $m = $rx.Match($ln)
        if ($m.Success) { return $m.Groups[1].Value }
    }
    return $null
}

# informational context labels (NOT gates -- everything is surfaced per owner ruling)
function Get-ContextLabels([string]$flag) {
    $u = $flag.ToUpper(); $labels = @()
    if ($u -like '*GUER*') { $labels += 'guer-affecting' }
    if ($u -match 'WEST|EAST|DEFENDER|ATTACKER') { $labels += 'side-affecting' }
    if ($u -like '*SIM_GATING*') { $labels += 'owner-rejected(sim-gating)' }
    foreach ($t in @('TPWCAS','SUPPLY_TRUCK','SATCHEL','SCUD','ICBM','EMP','DECOY','WARHEAD','DOCTRINE','ANTISTACK','ACR')) {
        if ($u -like "*$t*") { $labels += 'shelved-topic'; break }
    }
    foreach ($t in @('SEC_HARDENING','EGRESS','AICOM','ICBM')) {
        if ($u -like "*$t*") { $labels += 'needs-soak'; break }
    }
    if ($labels.Count -eq 0) { $labels += 'neutral' }
    return ($labels | Select-Object -Unique)
}

# ---- build experiment -> flag map ----
$exps = @{}
if (Test-Path -LiteralPath $ExperimentsPath) {
    $cat = [System.IO.File]::ReadAllText($ExperimentsPath) | ConvertFrom-Json
    foreach ($e in @($cat.experiments)) {
        if ($e.PSObject.Properties['flag'] -and -not [string]::IsNullOrWhiteSpace($e.flag)) { $exps[$e.id] = $e.flag }
    }
}

$findings = Read-Jsonl $FindingsPath
$existing = Read-Jsonl $OutPath
$seen = @{}; foreach ($r in $existing) { if ($r.findingId) { $seen[$r.findingId] = $true } }

$nowUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$day = (Get-Date).ToUniversalTime().ToString('yyyyMMdd')
$seq = 0
foreach ($r in $existing) { if ($r.recId -and $r.recId -match ('^' + $day + '-(\d{4})$')) { $n = [int]$Matches[1]; if ($n -gt $seq) { $seq = $n } } }

$recs = @()
foreach ($f in $findings) {
    if ($f.verdict -notin @('BETTER', 'WORSE')) { continue }
    $flag = $exps[$f.experiment]
    if ([string]::IsNullOrWhiteSpace($flag)) { continue }        # no flag mapped -> no flag recommendation
    if ($seen[$f.findingId]) { continue }                        # already recommended
    $ev = $f.evidence
    $dir = $ev.direction
    $cur = Get-FlagDefault $flag
    $suggestion = if ($f.verdict -eq 'BETTER' -and $dir -eq 'better') {
        "the flag-on arm improved $($f.metric) by $($ev.pctDelta)% -> consider enabling $flag (currently default $cur)"
    } elseif ($f.verdict -eq 'WORSE') {
        "the flag-on arm regressed $($f.metric) by $($ev.pctDelta)% -> keep $flag disabled (currently default $cur)"
    } else {
        "$flag changed $($f.metric) by $($ev.pctDelta)% ($($f.verdict)); review"
    }
    $seq++
    $recs += [ordered]@{
        schema          = 'a2wasp-recommendation-v1'
        recId           = ('{0}-{1:D4}' -f $day, $seq)
        createdAtUtc    = $nowUtc
        findingId       = $f.findingId
        experiment      = $f.experiment
        flag            = $flag
        currentDefault  = $cur
        metric          = $f.metric
        verdict         = $f.verdict
        pctDelta        = $ev.pctDelta
        contextLabels   = @(Get-ContextLabels $flag)
        suggestion      = $suggestion
        evidenceRowIds  = @(@($ev.armA.rowIds) + @($ev.armB.rowIds))
        disposition     = 'SURFACE'          # ALWAYS surface-only; owner decides what ships
        ownerActionRequired = $true
        autoApplied     = $false             # this tool never applies/deploys/opens a PR
    }
}

# append (surface-only artifact)
if ($recs.Count -gt 0) {
    $enc = New-Object System.Text.UTF8Encoding($false)
    if (-not (Test-Path -LiteralPath $OutPath)) { [System.IO.File]::WriteAllText($OutPath, $HEADER + "`n", $enc) }
    foreach ($rec in $recs) {
        $line = if ($PSVersionTable.PSVersion.Major -ge 6) { $rec | ConvertTo-Json -Depth 12 -Compress }
                else { Add-Type -AssemblyName System.Web.Extensions; (New-Object System.Web.Script.Serialization.JavaScriptSerializer).Serialize($rec) }
        [System.IO.File]::AppendAllText($OutPath, $line + "`n", $enc)
    }
}

Write-Host "Recommendations (SURFACE-ONLY -- owner decides; nothing auto-applied):"
if ($recs.Count -eq 0) { Write-Host "  (none -- no decisive flag findings)" }
foreach ($rec in $recs) {
    Write-Host ("  [{0}] {1}  {2}" -f $rec.recId, $rec.flag, ($rec.contextLabels -join ','))
    Write-Host ("        {0}" -f $rec.suggestion)
}
if ($Json) { return $recs }
return
