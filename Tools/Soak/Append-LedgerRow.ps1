<#
.SYNOPSIS
  Append one row to the append-only WASP soak ledger (soak-ledger.jsonl).

.DESCRIPTION
  Implements the frozen v1 contract in docs/design/v2/SPEC-SOAK-LEDGER-CONTRACT.md and the
  JSON Schema in Tools/Soak/run_result.schema.json. Callers pass a deploy stamp + optional
  analyzer/lens JSON (as produced by analyze_soak.py); this helper generates the rowId,
  enforces stampId de-duplication, maps analyzer output into the curated v1 row, and appends
  one complete JSON object per line.

  Design rules (do not relax):
    * Null means unknown / not-applicable and is NEVER omitted. 0 is a real zero.
    * rowId = YYYYMMDD-NNNN, NNNN one-based and scoped to the UTC date of this append.
    * A duplicate stampId is rejected (throws, appends nothing) unless the row is a SKIP_*
      status AND -AllowDuplicateSkip is set.
    * Serialization is version-branched: pwsh 7 uses ConvertTo-Json; Windows PowerShell 5.1
      uses JavaScriptSerializer, because 5.1's ConvertTo-Json collapses single-element arrays.

.OUTPUTS
  Writes the generated rowId to the pipeline on success. Throws on validation failure or a
  rejected duplicate (nothing is appended in that case).

.NOTES
  Guide rev: GR-2026-07-03a. A2-OA-1.64 project tooling; no mission code touched.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string]   $LedgerPath,
    [Parameter(Mandatory = $true)] [ValidateSet(
        'POSTED','POSTED_LEDGER_ONLY','DRY_RUN',
        'SKIP_NO_STAMP','SKIP_BAD_STAMP','SKIP_DUPLICATE','SKIP_VERSION_MISMATCH',
        'SKIP_TOO_SHORT','SKIP_BOX_DOWN','FAIL_ANALYZER','FAIL_LENS','FAIL_LEDGER'
    )] [string] $Status,
    [string]   $StampPath,
    [string]   $AnalyzeJsonPath,
    [string]   $LensJsonPath,
    [string]   $ServerRptPath,
    [string]   $HcRptPath,
    [string]   $DiscordGuildId,
    [string]   $DiscordChannelId,
    [string]   $DiscordMessageId,
    [string[]] $Note = @(),
    [switch]   $AllowDuplicateSkip
)

$ErrorActionPreference = 'Stop'

$HEADER = '# a2wasp-soak-ledger-v1 jsonl; skip lines beginning with ''#'''
$isSkip = $Status -like 'SKIP_*'

# ---- helpers ---------------------------------------------------------------

function Read-JsonFile([string]$path) {
    if ([string]::IsNullOrWhiteSpace($path)) { return $null }
    if (-not (Test-Path -LiteralPath $path)) { throw "File not found: $path" }
    $raw = [System.IO.File]::ReadAllText($path)
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    return ($raw | ConvertFrom-Json)
}

# First non-null property value among a list of candidate names. Null-safe on a null object.
function Get-First($obj, [string[]]$names) {
    if ($null -eq $obj) { return $null }
    foreach ($n in $names) {
        $p = $obj.PSObject.Properties[$n]
        if ($p -and $null -ne $p.Value) { return $p.Value }
    }
    return $null
}

function Get-Median($values) {
    $nums = @(); foreach ($v in @($values)) { if ($null -ne $v) { $nums += [double]$v } }
    if ($nums.Count -eq 0) { return $null }
    $sorted = $nums | Sort-Object
    $n = $sorted.Count
    if ($n % 2 -eq 1) { return [double]$sorted[[int](($n - 1) / 2)] }
    return (([double]$sorted[$n/2 - 1] + [double]$sorted[$n/2]) / 2.0)
}
function Get-Min($values) {
    $nums = @(); foreach ($v in @($values)) { if ($null -ne $v) { $nums += [double]$v } }
    if ($nums.Count -eq 0) { return $null }
    return ($nums | Measure-Object -Minimum).Minimum
}
function Get-Max($values) {
    $nums = @(); foreach ($v in @($values)) { if ($null -ne $v) { $nums += [double]$v } }
    if ($nums.Count -eq 0) { return $null }
    return ($nums | Measure-Object -Maximum).Maximum
}
function Round1($x)   { if ($null -eq $x) { return $null } return [math]::Round([double]$x, 1) }
function IntOrNull($x){ if ($null -eq $x) { return $null } return [int]$x }
function NullIfBlank([string]$s) { if ([string]::IsNullOrWhiteSpace($s)) { return $null } return $s }

# Sum the values of a JSON object ({}) ; $null when the block itself is absent, 0 for {}.
function Sum-ObjValues($obj) {
    if ($null -eq $obj) { return $null }
    $sum = 0
    foreach ($p in $obj.PSObject.Properties) { if ($null -ne $p.Value) { $sum += [double]$p.Value } }
    return [int]$sum
}

# A single lens verdict: mapped value if a lens file was given, SKIP for a skip row, else null.
function LensVal($lens, [string]$name, [bool]$skip) {
    if ($null -ne $lens) { return (Get-First $lens @($name)) }
    if ($skip) { return 'SKIP' }
    return $null
}

# Cross-version compact JSON. 5.1 ConvertTo-Json collapses single-element arrays -> use
# JavaScriptSerializer there; pwsh 7's ConvertTo-Json is correct and available.
function ConvertTo-LedgerLine($obj) {
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        return ($obj | ConvertTo-Json -Depth 30 -Compress)
    }
    Add-Type -AssemblyName System.Web.Extensions -ErrorAction Stop
    $ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    $ser.MaxJsonLength = [int]::MaxValue
    return $ser.Serialize($obj)
}

function Append-Line([string]$path, [string]$line) {
    $enc = New-Object System.Text.UTF8Encoding($false)   # BOM-free
    if (-not (Test-Path -LiteralPath $path)) {
        $dir = Split-Path -Parent $path
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
        [System.IO.File]::WriteAllText($path, $HEADER + "`n", $enc)
    }
    [System.IO.File]::AppendAllText($path, $line + "`n", $enc)
}

# ---- read existing rows (for rowId + dedup) --------------------------------

$existing = @()
if (Test-Path -LiteralPath $LedgerPath) {
    foreach ($ln in [System.IO.File]::ReadAllLines($LedgerPath)) {
        $t = $ln.Trim()
        if ($t.Length -eq 0 -or $t.StartsWith('#')) { continue }
        try { $existing += ($t | ConvertFrom-Json) } catch { }   # tolerate a torn line
    }
}

# ---- identity from the deploy stamp ----------------------------------------

if (-not $isSkip -and [string]::IsNullOrWhiteSpace($StampPath)) {
    throw "StampPath is required for non-skip status '$Status'."
}
$stamp = $null
if (-not [string]::IsNullOrWhiteSpace($StampPath)) { $stamp = Read-JsonFile $StampPath }

$stampId = Get-First $stamp @('stampId','stamp_id','id')
$identity = [ordered]@{
    stampId       = $stampId
    candidate     = Get-First $stamp @('candidate','build')
    terrain       = Get-First $stamp @('terrain','map')
    role          = Get-First $stamp @('role')
    git           = Get-First $stamp @('git','gitSha','git_sha')
    archiveSha256 = Get-First $stamp @('archiveSha256','archive_sha256','sha256')
    pboName       = Get-First $stamp @('pboName','pbo_name','pbo')
    operator      = Get-First $stamp @('operator')
}

# ---- duplicate stampId guard -----------------------------------------------

if ($null -ne $stampId) {
    $dupe = $existing | Where-Object { $_.identity -and $_.identity.stampId -eq $stampId }
    if ($dupe) {
        if (-not ($isSkip -and $AllowDuplicateSkip)) {
            throw "SKIP_DUPLICATE: stampId '$stampId' already present in ledger; nothing appended."
        }
    }
}

# ---- analyzer block (accessors are null-safe; precompute the true conditionals) ----

$a = $null
if (-not [string]::IsNullOrWhiteSpace($AnalyzeJsonPath)) { $a = Read-JsonFile $AnalyzeJsonPath }

$aHours = $null
if ($null -ne $a -and $null -ne $a.hours) { $aHours = [math]::Round([double]$a.hours, 3) }
$ws = $null
if ($null -ne $a) { $ws = $a.war_state_ext }

$analyzer = [ordered]@{
    build    = $a.build
    map      = $a.map
    hours    = $aHours
    roundend = $a.roundend
    arrival = [ordered]@{
        dispatches                 = $a.arrival.dispatches
        arrivals                   = $a.arrival.arrivals
        arrivalPct                 = $a.arrival.arrival_pct
        medianDispatchToArrivalMin = $a.arrival.median_dispatch_to_arrival_min
    }
    zombies = [ordered]@{
        minDispatch = $a.zombies.min_dispatch
        count       = $a.zombies.count
    }
    armyVsArmy = [ordered]@{
        totalKills = $a.army_vs_army.total_kills
        weKills    = $a.army_vs_army.we_kills
        weSharePct = $a.army_vs_army.we_share_pct
    }
    churn = [ordered]@{
        frontChangesWest   = $a.churn.front_changes.WEST
        frontChangesEast   = $a.churn.front_changes.EAST
        reissueCount       = $a.churn.reissue_count
        targetAbandonTotal = Sum-ObjValues $a.churn.target_abandon
    }
    hold = [ordered]@{
        captures     = $a.hold.captures
        maxTownsWest = $a.hold.max_towns.WEST
        maxTownsEast = $a.hold.max_towns.EAST
        hcCaptured   = $a.hold.hc_captured
    }
    perf = [ordered]@{
        serverFpsMin       = Get-Min $a.perf.fps
        serverFpsMedian    = Round1 (Get-Median $a.perf.fps)
        serverFpsMax       = Get-Max $a.perf.fps
        serverFpsMinWindow = Get-Min $a.perf.fpsmin
        hcFpsMin           = Get-Min $a.perf.hc_fps
        hcFpsMedian        = Round1 (Get-Median $a.perf.hc_fps)
        hc2FpsMedian       = Round1 (Get-Median $a.perf.hc2fps)
        aiTotPeak          = IntOrNull (Get-Max $a.perf.ai_tot)
        guerPeak           = IntOrNull (Get-Max $a.perf.guer)
        samples            = $a.perf.samples
    }
    warStateExt = [ordered]@{
        present        = [bool]$ws.present
        arrivalRatePct = Get-First $ws @('arrival_rate_pct','arrivalRatePct')
        townsW         = Get-First $ws @('towns_w','townsW')
        townsE         = Get-First $ws @('towns_e','townsE')
        terr           = Get-First $ws @('terr','terrControl')
    }
}

# ---- lens block ------------------------------------------------------------

$lens = $null
if (-not [string]::IsNullOrWhiteSpace($LensJsonPath)) { $lens = Read-JsonFile $LensJsonPath }
$lenses = [ordered]@{
    overall   = LensVal $lens 'overall'  $isSkip
    worstLens = Get-First $lens @('worstLens','worst_lens')
    release   = LensVal $lens 'release'  $isSkip
    errors    = LensVal $lens 'errors'   $isSkip
    war       = LensVal $lens 'war'      $isSkip
    perf      = LensVal $lens 'perf'     $isSkip
    summary   = Get-First $lens @('summary')
}

# ---- discord block ---------------------------------------------------------

$dChannel = NullIfBlank $DiscordChannelId
$dMessage = NullIfBlank $DiscordMessageId
$dStatus  = 'skipped'
if ($null -ne $dMessage) { $dStatus = 'posted' } elseif ($null -ne $dChannel) { $dStatus = 'pending' }
$discord = [ordered]@{
    enabled     = [bool]($null -ne $dChannel)
    status      = $dStatus
    guildId     = NullIfBlank $DiscordGuildId
    channelId   = $dChannel
    messageId   = $dMessage
    postedAtUtc = $null
    error       = $null
}

# ---- assemble + append -----------------------------------------------------

$nowUtc    = (Get-Date).ToUniversalTime()
$dayKey    = $nowUtc.ToString('yyyyMMdd')
$createdAt = $nowUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')

$maxN = 0
foreach ($r in $existing) {
    if ($r.rowId -and $r.rowId -match ('^' + $dayKey + '-(\d{4})$')) {
        $nn = [int]$Matches[1]; if ($nn -gt $maxN) { $maxN = $nn }
    }
}
$rowId = '{0}-{1:D4}' -f $dayKey, ($maxN + 1)

$row = [ordered]@{
    schema       = 'a2wasp-soak-ledger-row-v1'
    rowId        = $rowId
    createdAtUtc  = $createdAt
    status       = $Status
    identity     = $identity
    provenance   = [ordered]@{
        serverRptPath   = NullIfBlank $ServerRptPath
        hcRptPath       = NullIfBlank $HcRptPath
        analyzeJsonPath = NullIfBlank $AnalyzeJsonPath
        lensJsonPath    = NullIfBlank $LensJsonPath
        serverRptSha256 = $null
        hcRptSha256     = $null
    }
    analyzer     = $analyzer
    lenses       = $lenses
    discord      = $discord
    notes        = @($Note)
}

$line = ConvertTo-LedgerLine $row
# Safety net: the line MUST be a single-line, parseable JSON object.
if ($line -match "`n") { throw "FAIL_LEDGER: serialized row contains a newline." }
$null = ($line | ConvertFrom-Json)   # throws if we produced invalid JSON

Append-Line $LedgerPath $line
Write-Output $rowId
