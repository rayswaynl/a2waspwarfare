# Update-PublicStats.ps1 - builds C:\WASP\web\stats.json for the public stats page.
# Runs every 5 min via scheduled task WaspStatsUpdate. Global/aggregate data only:
# no player names, no UIDs. All-time totals accumulate across rounds/restarts in
# alltime.json (fold-in on mission-window change, keyed by RPT creation + MISSINIT line).

param(
    [string]$RptPath    = 'C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT',
    [string]$WebDir     = 'C:\WASP\web',
    [string]$MonitorLog = 'C:\WASP\monitor\monitor.log',
    [string]$DeployLog  = 'C:\WASP\deploy-tonight.log',
    [string]$EvalDir    = 'C:\WASP\aicom-eval',
    [string]$MissionLabel = 'WASP'   # 'WASP' (live mission) or 'NEXT' (V2 rebuild) - tags benchmarks so the two are never confused
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $WebDir)) { New-Item -ItemType Directory -Force -Path $WebDir | Out-Null }

# Atomic, BOM-free JSON writes: temp + rename so the HTTP server never sees a
# partial file, and Set-Content sharing violations can't abort the run.
function Write-AtomicUtf8([string]$path, [string]$text) {
    $tmp = "$path.tmp"
    [IO.File]::WriteAllText($tmp, $text, (New-Object Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $tmp -Destination $path -Force
}

# JSON-roundtrip helpers: ConvertFrom-Json yields PSCustomObjects; rebuild as
# hashtables so fold-in arithmetic and re-serialization stay clean.
function ConvertTo-CountHash($obj) {
    $h = @{}
    if ($null -ne $obj) {
        foreach ($p in @($obj.PSObject.Properties)) {
            $v = 0
            if ([int]::TryParse([string]$p.Value, [ref]$v)) { $h[[string]$p.Name] = $v }
        }
    }
    return $h
}
function Merge-CountHash([hashtable]$a, [hashtable]$b) {
    $m = @{}
    foreach ($k in @($a.Keys)) { $m[$k] = [int]$a[$k] }
    foreach ($k in @($b.Keys)) {
        if ($m.ContainsKey($k)) { $m[$k] = $m[$k] + [int]$b[$k] } else { $m[$k] = [int]$b[$k] }
    }
    return $m
}
function Get-TopN([hashtable]$h, [int]$n, [string]$keyName, [string]$valName) {
    $out = @()
    foreach ($e in @($h.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First $n)) {
        $out += [ordered]@{ $keyName = [string]$e.Key; $valName = [int]$e.Value }
    }
    return $out
}

# Fold one all-time BUCKET (global, or one per-map bucket) given its persisted state and the
# current window. Mirrors the original single-pool fold exactly, factored so the per-map buckets
# reuse the identical math (no Chernarus/Takistan cross-contamination). $persisted is the parsed
# JSON object for this bucket (or $null for a brand-new map). Returns a hashtable with:
#   baseOut    - the new persisted { <counters>, x } object (base only, pre-current-window)
#   alltime    - live all-time counters (base + current window)  [ordered]
#   x          - live all-time extras (cards/weapons/towns/hardware/rounds/longest/ttft)
#   bestTtft   - rolling best first-capture minute for this bucket
# $curCounts/$winExtras/$cardCounts/$weaponCounts/$townCounts/$hwCounts/$roundsDetail/$longDist/
# $longWeapon/$ttftWindow/$windowId are passed in so the function is pure (no script-scope reads).
function Invoke-AllTimeFold {
    param(
        [object]   $persisted,      # parsed bucket JSON (.base/.windowId/.window/.windowX/.bestTtft) or $null
        [string]   $windowId,
        [System.Collections.Specialized.OrderedDictionary] $curCounts,
        [hashtable]$cardCounts, [hashtable]$weaponCounts, [hashtable]$townCounts, [hashtable]$hwCounts,
        [object[]] $roundsDetail,
        [int]      $longDist, [string]$longWeapon,
        $ttftWindow,                # int or $null
        $winTtftWest, $winTtftEast  # int or $null
    )
    $base = $null; $prevWindowId = ''; $prevWindow = $null; $prevX = $null; $bestTtft = $null
    if ($null -ne $persisted) {
        if ($persisted.PSObject.Properties['base'])     { $base = $persisted.base }
        if ($persisted.PSObject.Properties['windowId']) { $prevWindowId = [string]$persisted.windowId }
        if ($persisted.PSObject.Properties['window'])   { $prevWindow = $persisted.window }
        if ($persisted.PSObject.Properties['windowX'])  { $prevX = $persisted.windowX }
        if ($persisted.PSObject.Properties['bestTtft'] -and $null -ne $persisted.bestTtft) { $bestTtft = [int]$persisted.bestTtft }
    }
    $baseH = [ordered]@{}
    foreach ($k in $curCounts.Keys) {
        $v = 0
        if ($null -ne $base -and $base.PSObject.Properties[$k]) { $v = [int]$base.$k }
        $baseH[$k] = $v
    }
    $baseX = [ordered]@{
        cards = @{}; weapons = @{}; towns = @{}; hardware = @{}; rounds = @()
        longDist = 0; longWeapon = ''; ttftWest = $null; ttftEast = $null
    }
    if ($null -ne $base -and $base.PSObject.Properties['x']) {
        $bx = $base.x
        $baseX.cards = ConvertTo-CountHash $bx.cards
        $baseX.weapons = ConvertTo-CountHash $bx.weapons
        $baseX.towns = ConvertTo-CountHash $bx.towns
        if ($bx.PSObject.Properties['hardware']) { $baseX.hardware = ConvertTo-CountHash $bx.hardware }
        if ($bx.PSObject.Properties['rounds'] -and $null -ne $bx.rounds) {
            foreach ($rr in @($bx.rounds)) { $baseX.rounds += [ordered]@{ winner = [string]$rr.winner; durationMin = [int]$rr.durationMin } }
        }
        if ($bx.PSObject.Properties['longDist'] -and $null -ne $bx.longDist) { $baseX.longDist = [int]$bx.longDist; $baseX.longWeapon = [string]$bx.longWeapon }
        if ($bx.PSObject.Properties['ttftWest'] -and $null -ne $bx.ttftWest) { $baseX.ttftWest = [int]$bx.ttftWest }
        if ($bx.PSObject.Properties['ttftEast'] -and $null -ne $bx.ttftEast) { $baseX.ttftEast = [int]$bx.ttftEast }
    }
    if ($prevWindowId -ne $windowId -and $null -ne $prevWindow) {
        foreach ($k in $curCounts.Keys) {
            if ($prevWindow.PSObject.Properties[$k]) { $baseH[$k] = $baseH[$k] + [int]$prevWindow.$k }
        }
        if ($null -ne $prevX) {
            $baseX.cards = Merge-CountHash $baseX.cards (ConvertTo-CountHash $prevX.cards)
            $baseX.weapons = Merge-CountHash $baseX.weapons (ConvertTo-CountHash $prevX.weapons)
            $baseX.towns = Merge-CountHash $baseX.towns (ConvertTo-CountHash $prevX.towns)
            if ($prevX.PSObject.Properties['hardware']) { $baseX.hardware = Merge-CountHash $baseX.hardware (ConvertTo-CountHash $prevX.hardware) }
            if ($prevX.PSObject.Properties['rounds'] -and $null -ne $prevX.rounds) {
                foreach ($rr in @($prevX.rounds)) { $baseX.rounds += [ordered]@{ winner = [string]$rr.winner; durationMin = [int]$rr.durationMin } }
            }
            if ($baseX.rounds.Count -gt 10) { $baseX.rounds = @($baseX.rounds[($baseX.rounds.Count - 10)..($baseX.rounds.Count - 1)]) }
            if ($prevX.PSObject.Properties['longDist'] -and [int]$prevX.longDist -gt $baseX.longDist) {
                $baseX.longDist = [int]$prevX.longDist; $baseX.longWeapon = [string]$prevX.longWeapon
            }
            foreach ($tk in @('ttftWest', 'ttftEast')) {
                if ($prevX.PSObject.Properties[$tk] -and $null -ne $prevX.$tk) {
                    if ($null -eq $baseX[$tk] -or [int]$prevX.$tk -lt $baseX[$tk]) { $baseX[$tk] = [int]$prevX.$tk }
                }
            }
        }
    }
    if ($null -ne $ttftWindow -and ($null -eq $bestTtft -or [int]$ttftWindow -lt $bestTtft)) { $bestTtft = [int]$ttftWindow }

    $allTime = [ordered]@{}
    foreach ($k in $curCounts.Keys) { $allTime[$k] = $baseH[$k] + [int]$curCounts[$k] }
    $atCards = Merge-CountHash $baseX.cards $cardCounts
    $atWeapons = Merge-CountHash $baseX.weapons $weaponCounts
    $atTowns = Merge-CountHash $baseX.towns $townCounts
    $atHardware = Merge-CountHash $baseX.hardware $hwCounts
    $atRounds = @($baseX.rounds) + @($roundsDetail)
    if ($atRounds.Count -gt 5) { $atRounds = @($atRounds[($atRounds.Count - 5)..($atRounds.Count - 1)]) }
    $atLongDist = $baseX.longDist; $atLongWeapon = $baseX.longWeapon
    if ($longDist -gt $atLongDist) { $atLongDist = $longDist; $atLongWeapon = $longWeapon }
    $atTtftWest = $baseX.ttftWest; $atTtftEast = $baseX.ttftEast
    if ($null -ne $winTtftWest -and ($null -eq $atTtftWest -or [int]$winTtftWest -lt $atTtftWest)) { $atTtftWest = [int]$winTtftWest }
    if ($null -ne $winTtftEast -and ($null -eq $atTtftEast -or [int]$winTtftEast -lt $atTtftEast)) { $atTtftEast = [int]$winTtftEast }

    $baseOut = [ordered]@{}
    foreach ($k in $baseH.Keys) { $baseOut[$k] = $baseH[$k] }
    $baseOut['x'] = $baseX

    $liveX = [ordered]@{
        cards = $atCards; weapons = $atWeapons; towns = $atTowns; hardware = $atHardware
        rounds = @($atRounds); longDist = $atLongDist; longWeapon = $atLongWeapon
        ttftWest = $atTtftWest; ttftEast = $atTtftEast
    }
    return @{ baseOut = $baseOut; alltime = $allTime; x = $liveX; bestTtft = $bestTtft }
}

# Build the published allTime block (stats.json shape) from a fold result. Identical shape to the
# legacy inline $out.allTime so the per-map buckets and the live current-map block share one builder.
function Build-AllTimeBlock($fold) {
    $a = $fold.alltime; $x = $fold.x
    return [ordered]@{
        kills = $a.kills; infantryKills = $a.infKills; vehicleKills = $a.vehKills; aircraftKills = $a.airKills
        hardwareDestroyed = $x.hardware
        killsByWest = $a.killsWest; killsByEast = $a.killsEast
        townsCaptured = $a.captures; roundsCompleted = $a.rounds
        winsWest = $a.winsWest; winsEast = $a.winsEast
        wildcardsDrawn = $a.wildcards; fastestFirstTownMin = $fold.bestTtft
        fastestFirstTownWest = $x.ttftWest; fastestFirstTownEast = $x.ttftEast
        longestKill = [ordered]@{ meters = $x.longDist; weapon = $x.longWeapon }
        topWeapons = @(Get-TopN $x.weapons 5 'name' 'kills')
        contestedTowns = @(Get-TopN $x.towns 5 'name' 'captures')
        wildcardGallery = $x.cards
        recentRounds = @($x.rounds)
    }
}

# ---- 1. Windowed RPT read (ReadWrite share, lines since last MISSINIT) ----
$all = @()
$rptCreation = 0
if (Test-Path -LiteralPath $RptPath) {
    $rptCreation = (Get-Item -LiteralPath $RptPath).CreationTime.Ticks
    $fs = New-Object IO.FileStream($RptPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try {
        # BOUNDED READ (claude-gaming 2026-06-13): only read the last ~10MB so a bloated RPT
        # (network-message spam) can never hang the generator - it froze tonight on a 33MB file.
        # The current-round window lives near the tail; all-time totals persist separately.
        if ($fs.Length -gt 10MB) { [void]$fs.Seek(-10MB, [IO.SeekOrigin]::End) }
        # Arma 2 writes the RPT in the system ANSI codepage, not UTF-8.
        $sr = New-Object IO.StreamReader($fs, [Text.Encoding]::Default)
        $content = $sr.ReadToEnd()
        $sr.Dispose()
    } finally { $fs.Dispose() }
    $all = $content -split "`r?`n"
}

$missIdx = -1
for ($i = $all.Count - 1; $i -ge 0; $i--) {
    if ($all[$i] -match 'MISSINIT') { $missIdx = $i; break }
}
$win = @()
if ($missIdx -ge 0) { $win = $all[$missIdx..($all.Count - 1)] }
$windowId = "$rptCreation`:$missIdx"
if ($rptCreation -eq 0) { $windowId = 'none' }

# ---- 1b. MAP DETECTION (map-aware dashboard) -------------------------------
# The dashboard must follow whatever terrain the server is actually running, not a
# hardcoded one. Detect the engine worldName from the MISSINIT line (it carries
# `worldName=<id>`); fall back to the missionName terrain hint, then to a default.
# Map the lowercase engine world id to a friendly display label. New worlds fall
# through to a Title-Cased form of the id so an unknown map is still labelled, not
# mislabelled. Detect, don't hardcode -- a switch back to Chernarus relabels itself.
$worldName = $null
$missionName = $null
$missLine = if ($missIdx -ge 0) { [string]$all[$missIdx] } else { '' }
if ($missLine -match 'worldName=([A-Za-z0-9_]+)') { $worldName = $Matches[1].ToLowerInvariant() }
if ($missLine -match 'missionName=([^,]+)') { $missionName = $Matches[1].Trim() }
# Secondary source: WFBE GLOBALGAMESTATS / Performance-Audit lines carry the world id too.
# Inlined (no Get-LastMatch dependency: that helper is defined just below this block).
if (-not $worldName) {
    for ($gi = $all.Count - 1; $gi -ge 0; $gi--) {
        if ($all[$gi] -match 'GLOBALGAMESTATS:\s*\d+\s*\|\s*\d+\s*\|\s*([A-Za-z0-9_]+)\s*\|') { $worldName = $Matches[1].ToLowerInvariant(); break }
        if ($all[$gi] -match 'Performance Audit\].*\bMAP=([A-Za-z0-9_]+)') { $worldName = $Matches[1].ToLowerInvariant(); break }
    }
}
# Friendly labels for the worlds we actually run. Unknown ids -> Title-Cased id.
$mapLabels = @{
    'chernarus'  = 'Chernarus'
    'takistan'   = 'Takistan'
    'zargabad'   = 'Zargabad'
    'fallujah'   = 'Fallujah'
    'utes'       = 'Utes'
    'shapur_baf' = 'Shapur'
    'proving_grounds_pmc' = 'Proving Grounds'
}
$mapLabel = 'Chernarus'   # default if nothing parses (legacy behaviour preserved)
if ($worldName) {
    if ($mapLabels.ContainsKey($worldName)) { $mapLabel = $mapLabels[$worldName] }
    else { $mapLabel = (Get-Culture).TextInfo.ToTitleCase(($worldName -replace '_', ' ')) }
} elseif ($missionName -match '\.([A-Za-z0-9_]+)$') {
    # Mission name sometimes ends in `.<world>` (e.g. ...co.takistan); use it as a hint.
    $w = $Matches[1].ToLowerInvariant()
    if ($mapLabels.ContainsKey($w)) { $mapLabel = $mapLabels[$w] }
    else { $mapLabel = (Get-Culture).TextInfo.ToTitleCase(($w -replace '_', ' ')) }
}
# Stable per-map id used to BUCKET all-time records/history (per-map separation). Prefer the
# engine worldName; else derive from the friendly label so an unparsed world still buckets
# consistently (never mixes Chernarus + Takistan into one pool). Lowercase, no spaces.
$mapId = if ($worldName) { $worldName } else { ($mapLabel -replace '\s+', '_').ToLowerInvariant() }
if ([string]::IsNullOrWhiteSpace($mapId)) { $mapId = 'unknown' }

# ---- 2. Parse current window ----
function Get-LastMatch([object[]]$lines, [string]$pattern) {
    $hits = @($lines | Where-Object { $_ -match $pattern })
    if ($hits.Count -gt 0) { return $hits[$hits.Count - 1] }
    return $null
}

$kills      = @($win | Where-Object { $_ -match '\|KILL\|' })
# KILL fields: 0 WASPSTAT 1 v1 2 seq 3 KILL 4 kUID 5 vUID 6 kSide 7 vSide 8 weapon 9 dist 10 cat [11 hw=X]
# Parse cat positionally (cat is no longer the last field since the b18 hw= suffix) and
# tally the hardware bucket. Works for both old (no hw) and new lines.
$infKills = 0; $vehKills = 0; $airKills = 0
$hwCounts = @{}
foreach ($k in $kills) {
    $kp = ($k -replace '^.*WASPSTAT\|', 'WASPSTAT|') -split '\|'
    if ($kp.Count -lt 11) { continue }
    $cat = ($kp[10] -replace '"', '').Trim()
    switch ($cat) { 'INF' { $infKills++ } 'VEH' { $vehKills++ } 'AIR' { $airKills++ } }
    if ($kp.Count -ge 12 -and $kp[11] -match 'hw=([A-Z]+)') {
        $hwb = $Matches[1]
        if ($hwb -ne '' -and $hwb -ne 'OTHER') {
            if ($hwCounts.ContainsKey($hwb)) { $hwCounts[$hwb] = $hwCounts[$hwb] + 1 } else { $hwCounts[$hwb] = 1 }
        }
    }
}
$killsWest  = @($kills | Where-Object { $_ -match '\|KILL\|[^|]*\|[^|]*\|WEST\|' }).Count
$killsEast  = @($kills | Where-Object { $_ -match '\|KILL\|[^|]*\|[^|]*\|EAST\|' }).Count

$capLines = @($win | Where-Object { $_ -match '\|CAPTURE\|' })
$capNames = @()
foreach ($c in $capLines) { if ($c -match '\|CAPTURE\|([^|]+)\|') { $capNames += $Matches[1] } }

$roundEnds = @($win | Where-Object { $_ -match '\|ROUNDEND\|' })
$winsWest = @($roundEnds | Where-Object { $_ -match '\|ROUNDEND\|WEST\|' }).Count
$winsEast = @($roundEnds | Where-Object { $_ -match '\|ROUNDEND\|EAST\|' }).Count

$wildLines = @($win | Where-Object { $_ -match 'AICOMSTAT\|v2\|EVENT\|[^|]+\|\d+\|WILDCARD_W\d+\|applied' })
$lastWild = ''
$lw = Get-LastMatch $win 'AICOMSTAT\|v2\|EVENT\|[^|]+\|\d+\|WILDCARD_(W\d+)\|applied'
if ($lw -and $lw -match 'EVENT\|([^|]+)\|\d+\|WILDCARD_(W\d+)\|') { $lastWild = "$($Matches[2]) ($($Matches[1]))" }

# Last TICK per side: AICOMSTAT|v1|TICK|SIDE|elMin|towns|supply|funds|fT|eT|upgCsv|units=N
$sides = @{}
foreach ($s in @('WEST', 'EAST')) {
    $t = Get-LastMatch $win ("AICOMSTAT\|v1\|TICK\|$s\|")
    if ($t -and $t -match "TICK\|$s\|(\d+)\|(\d+)\|(\d+)\|(\d+)\|") {
        # Capture before the units match below clobbers $Matches.
        $elMin = [int]$Matches[1]
        $towns = [int]$Matches[2]
        $supply = [int]$Matches[3]
        $funds = [int]$Matches[4]
        $units = 0
        if ($t -match 'units=(\d+)') { $units = [int]$Matches[1] }
        # Research points: sum of the upgrade-level CSV (field 10).
        $research = 0
        $tp = ($t -replace '^.*AICOMSTAT\|', 'AICOMSTAT|') -split '\|'
        if ($tp.Count -ge 11 -and $tp[10] -match '^[\d:]+$') {
            foreach ($u in ($tp[10] -split ':')) { $ui = 0; if ([int]::TryParse($u, [ref]$ui)) { $research += $ui } }
        }
        $sides[$s] = [ordered]@{ elapsedMin = $elMin; towns = $towns; units = $units; research = $research; funds = $funds; supply = $supply }
    }
}

# Per-side doctrine (HF=Heavy Force, LF=Light Force) from latest AssignTypes line.
$doctrine = @{}
foreach ($s in @('WEST', 'EAST')) {
    $dl = Get-LastMatch $win ("AssignTypes.sqf: \[$s\].*doctrine (LF|HF)")
    if ($dl -and $dl -match "\[$s\].*doctrine (LF|HF)") {
        $doctrine[$s] = if ($Matches[1] -eq 'HF') { 'Heavy Force' } else { 'Light Force' }
    }
}
# Fallback: latest END line per side carries final doctrine (use last, not first,
# since the window can span multiple rounds).
foreach ($s in @('WEST', 'EAST')) {
    if (-not $doctrine.ContainsKey($s)) {
        $el = Get-LastMatch $win "AICOMSTAT\|v1\|END\|$s\|"
        if ($el -and $el -match 'END\|([^|]+)\|\d+\|[^|]*\|(LF|HF)\|') {
            $doctrine[$s] = if ($Matches[2] -eq 'HF') { 'Heavy Force' } else { 'Light Force' }
        }
    }
}

# TOWN CONTROL (front line) from the latest TOWNSTAT line (b18+).
$townControl = $null
$tc = Get-LastMatch $win 'TOWNSTAT\|v1\|'
if ($tc -and $tc -match 'west=(\d+)\|east=(\d+)\|guer=(\d+)\|total=(\d+)') {
    $townControl = [ordered]@{ west = [int]$Matches[1]; east = [int]$Matches[2]; guer = [int]$Matches[3]; total = [int]$Matches[4] }
}

# ORDER OF BATTLE from the latest ORBATSTAT line per side (b18+).
$orbat = @{}
foreach ($s in @('WEST', 'EAST')) {
    $ob = Get-LastMatch $win "ORBATSTAT\|v1\|$s\|"
    if ($ob -and $ob -match "ORBATSTAT\|v1\|$s\|armor=(\d+)\|car=(\d+)\|heli=(\d+)\|jet=(\d+)\|personnel=(\d+)") {
        $orbat[$s] = [ordered]@{ armor = [int]$Matches[1]; car = [int]$Matches[2]; heli = [int]$Matches[3]; jet = [int]$Matches[4]; personnel = [int]$Matches[5] }
    }
}

# CHART SERIES (time-series for page charts). Coarse, delayed, no positions/tech.
# Town control over the round (stacked-area "tide of war").
$tcSeries = @()
foreach ($l in @($win | Where-Object { $_ -match 'TOWNSTAT\|v1\|' })) {
    if ($l -match 'west=(\d+)\|east=(\d+)\|guer=(\d+)\|total=(\d+)\|t=(\d+)') {
        $tcSeries += [ordered]@{ t = [int]$Matches[5]; west = [int]$Matches[1]; east = [int]$Matches[2]; guer = [int]$Matches[3] }
    }
}
# Army size + war chest per side over time, from TICK lines.
# TICK|side|elMin|towns|supply|funds|... ; capture all before the units match clobbers $Matches.
$armyW = @(); $armyE = @(); $fundsW = @(); $fundsE = @()
foreach ($l in @($win | Where-Object { $_ -match 'AICOMSTAT\|v1\|TICK\|(WEST|EAST)\|' })) {
    if ($l -match 'TICK\|(WEST|EAST)\|(\d+)\|(\d+)\|(\d+)\|(\d+)\|') {
        $sd = $Matches[1]; $tm = [int]$Matches[2]; $fn = [int]$Matches[5]
        $un = 0; if ($l -match 'units=(\d+)') { $un = [int]$Matches[1] }
        if ($sd -eq 'WEST') { $armyW += [ordered]@{ t = $tm; v = $un }; $fundsW += [ordered]@{ t = $tm; v = $fn } }
        else { $armyE += [ordered]@{ t = $tm; v = $un }; $fundsE += [ordered]@{ t = $tm; v = $fn } }
    }
}
# Cap each series to the last 60 points (bounds JSON size; charts stay readable).
function Last-N($arr, $n) { if ($arr.Count -gt $n) { return @($arr[($arr.Count - $n)..($arr.Count - 1)]) } else { return @($arr) } }
$charts = [ordered]@{
    townControl = @(Last-N $tcSeries 60)
    army = [ordered]@{ west = @(Last-N $armyW 60); east = @(Last-N $armyE 60) }
    economy = [ordered]@{ west = @(Last-N $fundsW 60); east = @(Last-N $fundsE 60) }
}

# WAR LOG: human-readable narration of AI-commander actions, parsed from existing
# AICOMSTAT EVENT + WASPSTAT CAPTURE lines (zero added in-game cost). Newest first.
# Single ordered pass tracks the last-seen round minute so CAPTURE lines (which carry
# no minute) get a stable approximate timestamp instead of clustering at "now".
# Side IDs: WEST=0, EAST=1, RESISTANCE=2 (Init_CommonConstants).
$warEvents = @()
$lastMin = 0
$wlIdx = 0
function Clean-Field([string]$s) { return ($s -replace '"', '').Trim() }
function Add-War([int]$m, [int]$seq, [string]$side, [string]$icon, [string]$text) {
    $script:warEvents += [ordered]@{ min = $m; seq = $seq; side = $side; icon = $icon; text = $text }
}
# Pre-pass: keys of first-town captures, to dedupe the matching generic CAPTURE line
# (FIRST_TOWN narrates it with a real minute; a later re-capture of the same town still shows).
$firstTownKeys = @{}
foreach ($l in @($win | Where-Object { $_ -match '\|FIRST_TOWN\|' })) {
    if ($l -match 'EVENT\|([^|]+)\|\d+\|FIRST_TOWN\|([^|"]+)') {
        $firstTownKeys[((Clean-Field $Matches[1]) + '|' + (($Matches[2] -split '-t')[0]))] = $true
    }
}
foreach ($l in $win) {
    $wlIdx++
    if ($l -match 'AICOMSTAT\|v[12]\|(?:TICK|EVENT|END)\|[^|]+\|(\d+)') { $lastMin = [int]$Matches[1] }
    if ($l -match 'AICOMSTAT\|v[12]\|EVENT\|') {
        $ep = ($l -replace '^.*AICOMSTAT\|', 'AICOMSTAT|') -split '\|'
        if ($ep.Count -lt 6) { continue }
        $eSide = Clean-Field $ep[3]; $eMin = 0; $null = [int]::TryParse($ep[4], [ref]$eMin); $eType = Clean-Field $ep[5]
        $f6 = if ($ep.Count -gt 6) { Clean-Field $ep[6] } else { '' }
        $f7 = if ($ep.Count -gt 7) { Clean-Field $ep[7] } else { '' }
        switch -Wildcard ($eType) {
            'FIRST_TOWN'        { Add-War $eMin $wlIdx $eSide 'flag' "$eSide captured its first town - $(($f6 -split '-t')[0])" }
            'TEAM_FOUNDED'      { Add-War $eMin $wlIdx $eSide 'army' "$eSide raised a fresh combat company" }
            'WEALTH_CONVERSION' { Add-War $eMin $wlIdx $eSide 'cash' "$eSide poured its war chest into new armies" }
            'HQ_STRIKE'         { Add-War $eMin $wlIdx $eSide 'strike' "$eSide launched a strike on the enemy HQ" }
            'FIRE_MISSION'      { Add-War $eMin $wlIdx $eSide 'arty' "$eSide called in an artillery fire mission" }
            'RELIEF'            { Add-War $eMin $wlIdx $eSide 'relief' "$eSide mounted a relief operation at $f6" }
            'STRUCTURE_BUILT'   { Add-War $eMin $wlIdx $eSide 'build' "$eSide built a $f6" }
            'ARTY_THREAT_ARMED' { Add-War $eMin $wlIdx $eSide 'warn' "$eSide detected an incoming artillery threat" }
            'UPRISING_DONE'     { Add-War $eMin $wlIdx $eSide 'fire' "A resistance uprising was put down" }
            'DONATION'          { Add-War $eMin $wlIdx $eSide 'cash' "$eSide received a donation of $f7 funds" }
            'UPGRADE_RESEARCHED'{ Add-War $eMin $wlIdx $eSide 'tech' "$eSide completed a tech upgrade" }
            'WILDCARD_W*'       {
                if ($eType -match 'WILDCARD_(W\d+)') {
                    $cn = $Matches[1]
                    $nm = switch ($cn) {
                        'W1' {'War Chest'} 'W2' {'Supply Drop'} 'W3' {'Bonus Patrol'} 'W4' {'Airborne Assault'}
                        'W6' {'Fortification Grant'} 'W7' {'Veteran Company'} 'W8' {'Motor Pool Delivery'}
                        'W9' {'Uprising'} 'W10' {'Lucky Salvage'} 'W11' {'Field Hospital'} 'W12' {'Spoils of War'}
                        default {$cn}
                    }
                    Add-War $eMin $wlIdx $eSide 'card' "$eSide drew a wildcard - $nm"
                }
            }
            default { }
        }
    } elseif ($l -match '\|CAPTURE\|([^|]+)\|(\d+)\|(\d+)') {
        $tn = Clean-Field $Matches[1]; $newSid = [int]$Matches[3]
        $cs = switch ($newSid) { 0 { 'WEST' } 1 { 'EAST' } 2 { 'RESISTANCE' } default { 'Someone' } }
        # Strip any -t suffix to match the pre-pass key form (CAPTURE names are already
        # bare, but stay robust if a suffixed name ever appears here).
        $ck = "$cs|$(($tn -split '-t')[0])"
        if ($firstTownKeys.ContainsKey($ck)) {
            # First capture of this town already narrated by FIRST_TOWN; consume the key
            # so a later re-capture of the same town will still appear.
            $firstTownKeys.Remove($ck)
        } else {
            Add-War $lastMin $wlIdx $cs 'flag' "$cs captured $tn"
        }
    }
}
# DE-SPAM: collapse repetitive economy/tactical events per side into one counted line;
# keep milestone events (captures, HQ strikes, relief, structures, wildcards, uprisings,
# donations) individual. Stops the feed flooding with "raised a company" x5 etc.
$noisyIcons = @('army', 'cash', 'arty', 'warn', 'tech')
$notable = @($warEvents | Where-Object { $noisyIcons -notcontains $_.icon })
$noisy = @($warEvents | Where-Object { $noisyIcons -contains $_.icon })
$agg = @{}
foreach ($e in $noisy) {
    $key = "$($e.side)|$($e.icon)"
    if ($agg.ContainsKey($key)) {
        $agg[$key].count = $agg[$key].count + 1
        if ($e.seq -gt $agg[$key].seq) { $agg[$key].min = $e.min; $agg[$key].seq = $e.seq }
    } else {
        $agg[$key] = @{ side = $e.side; icon = $e.icon; min = $e.min; seq = $e.seq; count = 1 }
    }
}
$aggEvents = @()
foreach ($k in $agg.Keys) {
    $a = $agg[$k]; $n = $a.count; $sd = $a.side
    $txt = switch ($a.icon) {
        'army' { if ($n -gt 1) { "$sd raised $n combat companies" } else { "$sd raised a combat company" } }
        'cash' { if ($n -gt 1) { "$sd funnelled its war chest into armies (x$n)" } else { "$sd funnelled its war chest into new armies" } }
        'arty' { if ($n -gt 1) { "$sd ran $n artillery fire missions" } else { "$sd ran an artillery fire mission" } }
        'warn' { if ($n -gt 1) { "$sd weathered $n artillery threats" } else { "$sd detected an artillery threat" } }
        'tech' { if ($n -gt 1) { "$sd completed $n tech upgrades" } else { "$sd completed a tech upgrade" } }
        default { "$sd activity (x$n)" }
    }
    $aggEvents += [ordered]@{ min = $a.min; seq = $a.seq; side = $sd; icon = $a.icon; text = $txt }
}
# Newest first: by minute, then by file order (seq) for same-minute ties.
$warLog = @(($notable + $aggEvents) | Sort-Object @{Expression={$_.min}; Descending=$true}, @{Expression={$_.seq}; Descending=$true} | Select-Object -First 14)

# Event counts this round (per side) - all from existing EVENT lines.
function Count-Ev([string]$type, [string]$side) {
    @($win | Where-Object { $_ -match "EVENT\|$side\|\d+\|$type" }).Count
}
$battleCounts = [ordered]@{
    armiesWest = (Count-Ev 'TEAM_FOUNDED' 'WEST'); armiesEast = (Count-Ev 'TEAM_FOUNDED' 'EAST')
    structuresWest = (Count-Ev 'STRUCTURE_BUILT' 'WEST'); structuresEast = (Count-Ev 'STRUCTURE_BUILT' 'EAST')
    fireMissions = @($win | Where-Object { $_ -match 'EVENT\|[^|]+\|\d+\|FIRE_MISSION' }).Count
    hqStrikes = @($win | Where-Object { $_ -match 'EVENT\|[^|]+\|\d+\|HQ_STRIKE' }).Count
}

# First-capture time per side this round + window-wide fastest.
$ttftWindow = $null
$ttftSides = @{}
foreach ($f in @($win | Where-Object { $_ -match '\|FIRST_TOWN\|' })) {
    if ($f -match 'EVENT\|([^|]+)\|(\d+)\|FIRST_TOWN\|') {
        $fSide = $Matches[1]; $v = [int]$Matches[2]
        if ($null -eq $ttftWindow -or $v -lt $ttftWindow) { $ttftWindow = $v }
        if (-not $ttftSides.ContainsKey($fSide) -or $v -lt $ttftSides[$fSide]) { $ttftSides[$fSide] = $v }
    }
}

# Per-card wildcard counts (gallery).
$cardCounts = @{}
foreach ($wl in $wildLines) {
    if ($wl -match 'WILDCARD_(W\d+)\|applied') {
        $cid = $Matches[1]
        if ($cardCounts.ContainsKey($cid)) { $cardCounts[$cid] = $cardCounts[$cid] + 1 } else { $cardCounts[$cid] = 1 }
    }
}

# Weapon leaderboard + longest kill (global, classnames only - no player data).
# KILL split: 0 WASPSTAT|1 v1|2 seq|3 KILL|4 kUID|5 vUID|6 kSide|7 vSide|8 weapon|9 dist|10 cat
$weaponCounts = @{}
$longDist = 0; $longWeapon = ''
foreach ($k in $kills) {
    $kp = ($k -replace '^.*WASPSTAT\|', 'WASPSTAT|') -split '\|'
    if ($kp.Count -ge 10) {
        $wep = [string]$kp[8]
        if ($wep -ne '' -and $wep -ne 'unknown' -and $wep -notmatch '"') {
            if ($weaponCounts.ContainsKey($wep)) { $weaponCounts[$wep] = $weaponCounts[$wep] + 1 } else { $weaponCounts[$wep] = 1 }
        }
        $dd = 0.0
        if ([double]::TryParse(($kp[9] -replace '"', ''), [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$dd)) {
            # Keep as double until the <6000 sanity gate: a freak distance (e.g. 1e10 from a
            # position glitch) overflows Int32 and would otherwise abort the whole generator.
            $di = [Math]::Round($dd)
            if ($di -gt $longDist -and $di -lt 6000) { $longDist = [int]$di; $longWeapon = $wep }
        }
    }
}

# BALANCE: kills aggregated per killing-platform class, CROSS-SIDE only (killerSide !=
# victimSide), for US-vs-RU weapon/vehicle balancing. Coarse aggregate, no positions/UIDs -
# safe through the delayed snapshot. Tracks per-class side, victim-category breakdown
# (inf/veh/air from cat) and an "ai" flag (set when EVERY killer of that class had an empty
# killer UID, i.e. all AI-fired). Top 30 by kills desc.
$balanceAgg = @{}
# DEATHS per VICTIM class (field vc=<victimClass>), CROSS-SIDE only - same filter as kills.
# vc= is appended by the b-next mission build; until that deploys the field is absent and
# $deathAgg stays empty (every row gets deaths=0/kd=null). The regex stops at the trailing
# quote diag_log wraps the line in, so we never capture the closing ".
$deathAgg = @{}
foreach ($k in $kills) {
    $kp = ($k -replace '^.*WASPSTAT\|', 'WASPSTAT|') -split '\|'
    if ($kp.Count -lt 11) { continue }
    $kUID = [string]$kp[4]
    $vUID = [string]$kp[5]
    $kSide = [string]$kp[6]; $vSide = [string]$kp[7]
    if ($kSide -eq $vSide) { continue }   # cross-side only
    # Death tally: key by victim class (vc=). Absent on old lines -> no increment, no crash.
    if ($k -match 'vc=([A-Za-z0-9_]+)') {
        $vc = $Matches[1]
        if ($deathAgg.ContainsKey($vc)) { $deathAgg[$vc] = $deathAgg[$vc] + 1 } else { $deathAgg[$vc] = 1 }
    }
    $wep = [string]$kp[8]
    if ($wep -eq '' -or $wep -eq 'unknown' -or $wep -match '"') { continue }
    $cat = ($kp[10] -replace '"', '').Trim()
    if (-not $balanceAgg.ContainsKey($wep)) {
        $balanceAgg[$wep] = @{ class = $wep; side = $kSide; kills = 0; inf = 0; veh = 0; air = 0; pvp = 0; pve = 0; allAi = $true }
    }
    $b = $balanceAgg[$wep]
    $b.kills = $b.kills + 1
    switch ($cat) { 'INF' { $b.inf = $b.inf + 1 } 'VEH' { $b.veh = $b.veh + 1 } 'AIR' { $b.air = $b.air + 1 } }
    if ($vUID -ne '') { $b.pvp = $b.pvp + 1 } else { $b.pve = $b.pve + 1 }   # PvP = human victim (vc uid present), PvE = AI
    if ($kUID -ne '') { $b.allAi = $false }
}
$balanceRound = @()
foreach ($b in @($balanceAgg.Values | Sort-Object -Property @{Expression={$_.kills}; Descending=$true} | Select-Object -First 30)) {
    $rowClass = [string]$b.class; $rowKills = [int]$b.kills
    $rowDeaths = $(if ($deathAgg.ContainsKey($rowClass)) { [int]$deathAgg[$rowClass] } else { 0 })
    $rowKd = $(if ($rowDeaths -gt 0) { [math]::Round($rowKills / $rowDeaths, 2) } else { $null })
    $balanceRound += [ordered]@{
        class = $rowClass; side = [string]$b.side; kills = $rowKills
        deaths = $rowDeaths; kd = $rowKd
        inf = [int]$b.inf; veh = [int]$b.veh; air = [int]$b.air
        pvp = [int]$b.pvp; pve = [int]$b.pve
        ai = $(if ($b.allAi) { 1 } else { 0 })
    }
}
# Per-class window rows (keyed by class) for the ALL-TIME balance fold (Update-BalanceWindow below).
# Includes every class (not just top 30) so the accumulated all-time picture is complete.
$balanceWin = @{}
foreach ($bc in $balanceAgg.Keys) {
    $bw = $balanceAgg[$bc]
    $bd = $(if ($deathAgg.ContainsKey($bc)) { [int]$deathAgg[$bc] } else { 0 })
    $balanceWin[$bc] = @{ side = [string]$bw.side; kills = [int]$bw.kills; deaths = $bd; inf = [int]$bw.inf; veh = [int]$bw.veh; air = [int]$bw.air; pvp = [int]$bw.pvp; pve = [int]$bw.pve; allAi = [bool]$bw.allAi }
}

# Most contested towns (capture counts per town).
$townCounts = @{}
foreach ($n in $capNames) {
    if ($townCounts.ContainsKey($n)) { $townCounts[$n] = $townCounts[$n] + 1 } else { $townCounts[$n] = 1 }
}

# Round results in this window: WASPSTAT|v1|seq|ROUNDEND|winner|secs|world
$roundsDetail = @()
foreach ($re in $roundEnds) {
    $rp = ($re -replace '^.*WASPSTAT\|', 'WASPSTAT|') -split '\|'
    if ($rp.Count -ge 6) {
        $secs = 0; $null = [int]::TryParse(($rp[5] -replace '"', ''), [ref]$secs)
        $roundsDetail += [ordered]@{ winner = [string]$rp[4]; durationMin = [int][Math]::Floor($secs / 60) }
    }
}

# Resistance pressure: GUER unit count from the latest group audit.
$guerUnits = $null
$gl = Get-LastMatch $win 'group audit \[GUER\].*units=(\d+)'
if ($gl -and $gl -match 'group audit \[GUER\].*units=(\d+)') { $guerUnits = [int]$Matches[1] }

# Performance: srvFps trend, active towns, HC telemetry, delegation
$fpsVals = @()
$activeTownsLast = 0; $activeTownsMax = 0
foreach ($l in @($win | Where-Object { $_ -match 'srvFps=\d+' })) {
    if ($l -match 'srvFps=(\d+)') { $fpsVals += [int]$Matches[1] }
    if ($l -match 'activeTowns=(\d+)') {
        $activeTownsLast = [int]$Matches[1]
        if ($activeTownsLast -gt $activeTownsMax) { $activeTownsMax = $activeTownsLast }
    }
}
$srvFps = [ordered]@{ last = $null; avg = $null; min = $null }
if ($fpsVals.Count -gt 0) {
    $m = $fpsVals | Measure-Object -Minimum -Average
    $srvFps = [ordered]@{ last = $fpsVals[$fpsVals.Count - 1]; avg = [int]$m.Average; min = [int]$m.Minimum }
}
# SRVPERF series: server-load trend (fps over the round) + latest unit/group/vehicle detail
# B74.2: carry units/groups/veh on each series row too (not just the latest $srvDetail), so the
# Performance tab can chart server-side units/groups/vehicles over the round. Render reads {t,v,towns}
# today; the extra keys are additive (older consumers ignore them).
$perfSeries = @(); $srvDetail = $null
foreach ($l in @($win | Where-Object { $_ -match 'SRVPERF\|v1' })) {
    if ($l -match 'SRVPERF\|v1\|(\d+)\|fps=(\d+)\|units=(\d+)\|groups=(\d+)\|veh=(\d+)\|dead=(\d+)\|activeTowns=(\d+)') {
        $perfSeries += [ordered]@{ t = [int]$Matches[1]; v = [int]$Matches[2]; towns = [int]$Matches[7]; units = [int]$Matches[3]; groups = [int]$Matches[4]; veh = [int]$Matches[5] }
        $srvDetail = [ordered]@{ units = [int]$Matches[3]; groups = [int]$Matches[4]; veh = [int]$Matches[5]; dead = [int]$Matches[6] }
    }
}
$charts['perf'] = @($perfSeries)

# POP TIER (B74.2): the AI population cap scales by a discrete tier as the war matures.
# The mission logs the latest tier + the human count that drives it on a single line:
#   [POPTIER] humans=<N> tier=<T>
# We surface { tier, humans, west:{ai,cap}, east:{ai,cap} } so the AI Commander tab renders it.
# ai = the per-side live AI count, reused from the AICOMSTAT TICK units= already parsed into $sides.
# cap = a hardcoded by-tier ceiling indexed by tier; this array MIRRORS the mission constant
#   WFBE_C_TOTAL_AI_MAX_BY_TIER (tier 0..3). Keep in sync if the mission const changes.
$popTier = $null
$tierCap = @(140, 130, 100, 80)   # mirrors mission WFBE_C_TOTAL_AI_MAX_BY_TIER (index = tier 0..3)
# Resolve tier + humans most-authoritative first: (1) the on-CHANGE [POPTIER] publisher line, else
# (2) the founding-skipped gate line "(tier <T>, pc <P>)" (logged whenever a side hits the tier cap).
# [POPTIER] only logs when the tier CHANGES, so on a steady round it is absent; the quiet-round
# fallback (derive from the A2S human count) runs further below, once $humans is known.
$ptTier = $null; $ptHumans = $null
$ptLine = Get-LastMatch $win '\[POPTIER\]\s+humans=\d+\s+tier=\d+'
if ($ptLine -and $ptLine -match '\[POPTIER\]\s+humans=(\d+)\s+tier=(\d+)') {
    $ptHumans = [int]$Matches[1]; $ptTier = [int]$Matches[2]
} else {
    $fsLine = Get-LastMatch $win '\(tier \d+, pc \d+\)'
    if ($fsLine -and $fsLine -match '\(tier (\d+), pc (\d+)\)') { $ptTier = [int]$Matches[1]; $ptHumans = [int]$Matches[2] }
}
if ($null -ne $ptTier) {
    # Cap lookup is tier-indexed; clamp to the array so an out-of-range tier never throws.
    $ptCap = if ($ptTier -ge 0 -and $ptTier -lt $tierCap.Count) { $tierCap[$ptTier] } else { $tierCap[$tierCap.Count - 1] }
    $ptWestAi = if ($sides.ContainsKey('WEST')) { [int]$sides['WEST'].units } else { 0 }
    $ptEastAi = if ($sides.ContainsKey('EAST')) { [int]$sides['EAST'].units } else { 0 }
    $popTier = [ordered]@{
        tier = $ptTier; humans = $ptHumans
        west = [ordered]@{ ai = $ptWestAi; cap = $ptCap }
        east = [ordered]@{ ai = $ptEastAi; cap = $ptCap }
    }
}

# MHQ RELOCATIONS (B74.2): the AI commander teleports a stuck Mobile HQ. The mission logs an
# MHQRELOC event line per relocation; surface a running count + the latest one for the round.
# Parsed defensively (the field/shape may vary by build); count = matches, last = the tail line text.
$mhq = $null
$mhqLines = @($win | Where-Object { $_ -match 'MHQRELOC' })
if ($mhqLines.Count -gt 0) {
    $mhqLast = [string]$mhqLines[$mhqLines.Count - 1]
    # Trim to the MHQRELOC token onward so the published "last" is the event payload, not the RPT prefix.
    $mhqLastTrim = if ($mhqLast -match '(MHQRELOC.*)$') { ($Matches[1] -replace '"', '').Trim() } else { $mhqLast.Trim() }
    $mhq = [ordered]@{ count = $mhqLines.Count; last = $mhqLastTrim }
}

$hcs = @{}
foreach ($l in @($win | Where-Object { $_ -match 'HCSTAT\|v1\|' })) {
    if ($l -match 'HCSTAT\|v1\|([^|]+)\|fps=(\d+)\|units=(\d+)\|groups=(\d+)') {
        $hcs[$Matches[1]] = [ordered]@{ fps = [int]$Matches[2]; units = [int]$Matches[3] }
    }
}
$hcList = @()
$hcNo = 0
foreach ($k in @($hcs.Keys | Sort-Object)) {
    $hcNo = $hcNo + 1
    $hcList += [ordered]@{ name = "HC$hcNo"; fps = $hcs[$k].fps; units = $hcs[$k].units }
}

$delegPct = $null
$dl = Get-LastMatch $win 'DELEGSTAT\|v1\|'
if ($dl -and $dl -match 'remotePct=(\d+)') { $delegPct = [int]$Matches[1] }

$townsMax = $null
$st = Get-LastMatch $win 'SELFTEST\|v1\|'
if ($st -and $st -match 'townsMax=(-?\d+)') { $townsMax = [int]$Matches[1] }

# GROUP HEALTH (claude-gaming 2026-06-15): per-side 144-group cap utilisation + the GC leak signal,
# surfaced publicly so the Arma-2 144-groups/side cap saturation + the HC defender-group leak are visible.
# Primary source = GCSTAT|v1| (emitted every 60s: per-side counts + reaped + emptyFound). The throttled
# "group audit [SIDE] N/144" line (~25 min) adds the real cap + (on instrumented builds) per-side
# empty=/dgEmpty=; GRPEMPTY| (newer builds) adds per-side empty + defender-gunner leak. Degrades per build.
$groupHealth  = $null
$ghCap        = 144
$ghReaped     = $null
$ghEmptyFound = $null
$ghSides      = [ordered]@{}
# 1) GCSTAT: freshest per-side group counts + round-level GC activity (reaped / empties found).
$gcs = Get-LastMatch $win 'GCSTAT\|v1\|'
if ($gcs -and $gcs -match 'reaped=(\d+)\|emptyFound=(\d+)\|west=(\d+)\|east=(\d+)\|guer=(\d+)') {
    $ghReaped = [int]$Matches[1]; $ghEmptyFound = [int]$Matches[2]
    $ghSides['west'] = [ordered]@{ groups = [int]$Matches[3]; cap = $ghCap; empty = $null; dgEmpty = $null; untagged = $null }
    $ghSides['east'] = [ordered]@{ groups = [int]$Matches[4]; cap = $ghCap; empty = $null; dgEmpty = $null; untagged = $null }
    $ghSides['guer'] = [ordered]@{ groups = [int]$Matches[5]; cap = $ghCap; empty = $null; dgEmpty = $null; untagged = $null }
    # Per-side untagged count (groups with no wfbe_group_src) - emitted on the same 60s GCSTAT line so the
    # dashboard untagged gauge is responsive (the full per-source breakdown only ships every ~25 min).
    if ($gcs -match '\|untW=(\d+)\|untE=(\d+)\|untG=(\d+)') {
        $ghSides['west'].untagged = [int]$Matches[1]
        $ghSides['east'].untagged = [int]$Matches[2]
        $ghSides['guer'].untagged = [int]$Matches[3]
    }
}
# 2) group audit [SIDE] N/144: the real cap + (instrumented builds) per-side empty=/dgEmpty=.
foreach ($pair in @(@('west', 'WEST'), @('east', 'EAST'), @('guer', 'GUER'))) {
    $key = $pair[0]; $tag = $pair[1]
    $ga = Get-LastMatch $win "group audit \[$tag\]\s+\d+/\d+"
    if ($ga -and $ga -match "group audit \[$tag\]\s+(\d+)/(\d+)") {
        $g = [int]$Matches[1]; $cap = [int]$Matches[2]
        if ($cap -gt 0) { $ghCap = $cap }
        if (-not $ghSides.Contains($key)) { $ghSides[$key] = [ordered]@{ groups = $g; cap = $cap; empty = $null; dgEmpty = $null; untagged = $null } }
        else { $ghSides[$key].cap = $cap }   # keep GCSTAT's fresher group count; take the authoritative cap here
        if ($ga -match '\bempty=(\d+)')  { $ghSides[$key].empty   = [int]$Matches[1] }   # \b avoids the 'empty' in dgEmpty=
        if ($ga -match 'dgEmpty=(\d+)')  { $ghSides[$key].dgEmpty = [int]$Matches[1] }
        # Per-source breakdown (wfbe_group_src tags) from the "N/144: <src=count ...> srvFps=" segment -
        # powers the dashboard per-faction fold-out (X static defenders, X town garrisons, X patrols ...).
        if ($ga -match "group audit \[$tag\]\s+\d+/\d+:\s*(.*?)\s+srvFps=") {
            $srcStr = $Matches[1]; $srcMap = [ordered]@{}
            foreach ($tok in ($srcStr -split '\s+')) {
                if ($tok -match '^([A-Za-z][A-Za-z0-9_-]*)=(\d+)$') { $srcMap[$Matches[1]] = [int]$Matches[2] }
            }
            if ($srcMap.Count -gt 0) { $ghSides[$key].sources = $srcMap }
            # Fallback for builds that don't emit the 60s GCSTAT untW=/untE=/untG= fields: take the
            # untagged count from this audit breakdown so the dashboard untagged gauge still populates.
            if ($null -eq $ghSides[$key].untagged -and $srcMap.Contains('untagged')) { $ghSides[$key].untagged = [int]$srcMap['untagged'] }
        }
    }
}
# 3) EMPTYGRP|v1| (Ray's tracking, ~5-min audit): per-side empty group count + persistent-empty split
#    (persW/E/G = editor player-slots etc. the GC deliberately never reaps). FIX 2026-06-15: the live
#    build emits EMPTYGRP, but this block previously parsed a 'GRPEMPTY' name that is NEVER emitted -
#    so per-side empty counts silently read null. Corrected to EMPTYGRP + the persW/E/G schema.
$ge = Get-LastMatch $win 'EMPTYGRP\|v1\|'
if ($ge) {
    foreach ($pair in @(@('west', 'west', 'persW'), @('east', 'east', 'persE'), @('guer', 'guer', 'persG'))) {
        $key = $pair[0]
        if (-not $ghSides.Contains($key)) { $ghSides[$key] = [ordered]@{ groups = $null; cap = $ghCap; empty = $null; dgEmpty = $null; untagged = $null } }
        if ($null -eq $ghSides[$key].empty -and $ge -match ('\|' + $pair[1] + '=(\d+)')) { $ghSides[$key].empty = [int]$Matches[1] }
        if ($ge -match ('\|' + $pair[2] + '=(\d+)')) { $ghSides[$key].persEmpty = [int]$Matches[1] }
    }
}
# 4) GUERCAP|v1| (GUER soft-cap monitor, 60s, deploy build): GUER group count vs the WFBE_C_GUER_GROUPS_MAX
#    soft cap. GUER's real ceiling is this soft cap (=80); at it, server_town_ai defers town garrisons.
$guerCapObj = $null
$gcp = Get-LastMatch $win 'GUERCAP\|v1\|'
if ($gcp -and $gcp -match 'count=(\d+)\|max=(\d+)\|pct=(\d+)') {
    $guerCapObj = [ordered]@{ count = [int]$Matches[1]; max = [int]$Matches[2]; pct = [int]$Matches[3] }
}
# 5) UNTAGLEAK|v1| (untagged-leak diagnostic, ~5-min audit, deploy build): non-empty wrapper-bypassed
#    groups per side. Should sit at 0; a sustained non-zero is a real dynamic-group leak.
$leakObj = $null
$ul = Get-LastMatch $win 'UNTAGLEAK\|v1\|'
if ($ul -and $ul -match 'west=(\d+)\|east=(\d+)\|guer=(\d+)\|samples=(.*?)\|t=') {
    $leakObj = [ordered]@{ west = [int]$Matches[1]; east = [int]$Matches[2]; guer = [int]$Matches[3]; samples = $Matches[4].Trim() }
}
if ($ghSides.Count -gt 0 -or $guerCapObj -or $leakObj) {
    $groupHealth = [ordered]@{ cap = $ghCap; reaped = $ghReaped; emptyFound = $ghEmptyFound; sides = $ghSides }
    if ($guerCapObj) { $groupHealth.guerCap = $guerCapObj }
    if ($leakObj)    { $groupHealth.leak    = $leakObj }
}

# CLIENT FPS (claude-gaming 2026-06-15): aggregate the per-player FPSREPORT|v1| samples by HC count
# (0/1/2) and by day/night, so the planned 0/1/2-HC main-server test reads at a glance. Dormant
# (samples=0) until a mission build carrying the client-FPS telemetry runs with the lobby param on.
$clientFps = $null
$fpsRows = @($win | Where-Object { $_ -match 'FPSREPORT\|v1\|' })
if ($fpsRows.Count -gt 0) {
    $byHc = @{}
    $dn   = @{ day = @{ sum = 0; min = $null; n = 0 }; night = @{ sum = 0; min = $null; n = 0 } }
    foreach ($l in $fpsRows) {
        if (-not ($l -match '\|fps=(\d+)\|')) { continue }
        $fps = [int]$Matches[1]
        $fmin = $fps; if ($l -match '\|fpsMin=(\d+)\|') { $fmin = [int]$Matches[1] }
        $hc = -1;    if ($l -match '\|hc=(\d+)\|')     { $hc = [int]$Matches[1] }
        $isNight = $false
        if ($l -match '\|daytime=([0-9.]+)\|') { $dtv = [double]$Matches[1]; $isNight = ($dtv -lt 6 -or $dtv -ge 19) }
        if (-not $byHc.ContainsKey($hc)) { $byHc[$hc] = @{ sum = 0; min = $fmin; n = 0 } }
        $byHc[$hc].sum += $fps; $byHc[$hc].n++
        if ($fmin -lt $byHc[$hc].min) { $byHc[$hc].min = $fmin }
        $bk = if ($isNight) { 'night' } else { 'day' }
        $dn[$bk].sum += $fps; $dn[$bk].n++
        if ($null -eq $dn[$bk].min -or $fmin -lt $dn[$bk].min) { $dn[$bk].min = $fmin }
    }
    $byHcArr = @()
    foreach ($k in @($byHc.Keys | Sort-Object)) {
        $byHcArr += [ordered]@{ hc = $k; avg = [int]($byHc[$k].sum / $byHc[$k].n); min = $byHc[$k].min; n = $byHc[$k].n }
    }
    $dnOut = [ordered]@{}
    foreach ($bk in @('day', 'night')) {
        if ($dn[$bk].n -gt 0) { $dnOut[$bk] = [ordered]@{ avg = [int]($dn[$bk].sum / $dn[$bk].n); min = $dn[$bk].min; n = $dn[$bk].n } }
    }
    $clientFps = [ordered]@{ samples = $fpsRows.Count; byHc = $byHcArr; dayNight = $dnOut }
}

# A/B arm (NEXT vs LEGACY) from the SELFTEST arm= field
$arm = $null
if ($st -and $st -match 'arm=([A-Za-z0-9\-]+)') { $arm = $(if ($Matches[1] -match 'LEGACY') { 'LEGACY' } else { 'NEXT' }) }
# Authoritative: the explicit per-server -MissionLabel wins over the mission's self-reported arm=.
# The live WASP build stamps a stale "arm=NEXT" in its SELFTEST line; never badge the production
# server as NEXT (that put an orange experimental-NEXT badge on the live dashboard).
if ($MissionLabel -ne 'NEXT' -and $arm -eq 'NEXT') { $arm = 'WASP' }

# Commander Intel: latest spearhead plan per side from AICOMDBG (town + supply + distance-to-front)
$commanderIntel = [ordered]@{}
$dbgAll = @($win | Where-Object { $_ -match 'AICOMDBG\|v1\|SPEARHEAD\|' })
foreach ($sd in @('WEST', 'EAST')) {
    $sdLines = @($dbgAll | Where-Object { $_ -match "SPEARHEAD\|$sd\|" })
    if ($sdLines.Count -gt 0) {
        $latestMin = -1
        foreach ($ln in $sdLines) { if ($ln -match "SPEARHEAD\|$sd\|(\d+)\|") { $mm = [int]$Matches[1]; if ($mm -gt $latestMin) { $latestMin = $mm } } }
        $tgts = @()
        foreach ($ln in $sdLines) {
            if ($ln -match "SPEARHEAD\|$sd\|$latestMin\|town=([^|]+)\|supply=([0-9.\-]+)\|distFront=([0-9.eE+\-]+)") {
                $dfRaw = [double]$Matches[3]
                $dfOut = if ($dfRaw -gt 50000) { $null } else { [int]$dfRaw }   # >50km = the 1e9 "no front yet" fallback
                $tgts += [ordered]@{ town = ($Matches[1].Trim()); supply = [int][double]$Matches[2]; distFront = $dfOut }
            }
        }
        if ($tgts.Count -gt 0) { $commanderIntel[$sd] = @($tgts) }
    }
}

# GUER DIRECTOR LEDGER: latest town-strength/funding snapshot from the GUER economic director.
# AICOMSTAT|v3|DIRECTOR|GUER|<tick>|GDIR_LEDGER towns=.. totalStr=.. totalBase=.. transit=.. funded=.. regenDebt=..
# Single GUER-side entity (no per-side loop). AGGREGATE ONLY (no per-town names, no UIDs) -> safe on the public feed.
$directorLedger = $null
$gdlLine = Get-LastMatch $win 'AICOMSTAT\|v3\|DIRECTOR\|GUER\|\d+\|GDIR_LEDGER\s+towns=\d+'
if ($gdlLine -and $gdlLine -match 'GDIR_LEDGER\s+towns=(\d+)\s+totalStr=([0-9.eE+\-]+)\s+totalBase=([0-9.eE+\-]+)\s+transit=([0-9.eE+\-]+)\s+funded=([0-9.eE+\-]+)\s+regenDebt=([0-9.eE+\-]+)') {
    $gdInv = [Globalization.CultureInfo]::InvariantCulture
    $gdFlt = [Globalization.NumberStyles]::Float
    $gdTotalStr = 0.0; [void][double]::TryParse($Matches[2], $gdFlt, $gdInv, [ref]$gdTotalStr)
    $gdTotalBase = 0.0; [void][double]::TryParse($Matches[3], $gdFlt, $gdInv, [ref]$gdTotalBase)
    $gdTransit = 0.0; [void][double]::TryParse($Matches[4], $gdFlt, $gdInv, [ref]$gdTransit)
    $gdFunded = 0.0; [void][double]::TryParse($Matches[5], $gdFlt, $gdInv, [ref]$gdFunded)
    $gdRegenDebt = 0.0; [void][double]::TryParse($Matches[6], $gdFlt, $gdInv, [ref]$gdRegenDebt)
    $directorLedger = [ordered]@{
        towns     = [int]$Matches[1]
        totalStr  = $gdTotalStr
        totalBase = $gdTotalBase
        transit   = $gdTransit
        funded    = $gdFunded
        regenDebt = $gdRegenDebt
    }
}

# BENCHMARK: per-version performance scorecard. Coarse aggregate (fps/groups/teams/error
# counts) with no positions/precise-tech - safe through the delayed snapshot path. All from
# telemetry already in $win; guard every line (emit nulls/empties when absent).
# Latest GRPBUDGET: groups budget per side. GRPBUDGET|v1|<t>|west=<n>|east=<n>|guer=<n>|cap=<n>
$grpWest = $null; $grpEast = $null; $grpGuer = $null; $grpTotal = $null
$gb = Get-LastMatch $win 'GRPBUDGET\|v1\|'
if ($gb -and $gb -match 'GRPBUDGET\|v1\|\d+\|west=(\d+)\|east=(\d+)\|guer=(\d+)\|cap=(\d+)') {
    $grpWest = [int]$Matches[1]; $grpEast = [int]$Matches[2]; $grpGuer = [int]$Matches[3]
    $grpTotal = $grpWest + $grpEast + $grpGuer
}
# Latest CMDRSTAT per side: foundedTeams + unitsPerTeam + remnants.
# CMDRSTAT|v1|<SIDE>|<t>|srvTeams=<n>|hcTeams=<n>|foundedTeams=<n>|unitsPerTeam=<float>|remnants=<n>
$teamsBench = @{}; $uptBench = @{}; $remBench = @{}
foreach ($s in @('WEST', 'EAST')) {
    $teamsBench[$s] = $null; $uptBench[$s] = $null; $remBench[$s] = $null
    $cl = Get-LastMatch $win "CMDRSTAT\|v1\|$s\|"
    if ($cl) {
        if ($cl -match 'foundedTeams=(\d+)') { $teamsBench[$s] = [int]$Matches[1] }
        if ($cl -match 'unitsPerTeam=([0-9]+(?:\.[0-9]+)?)') { $uptBench[$s] = [double]$Matches[1] }
        if ($cl -match 'remnants=(\d+)') { $remBench[$s] = [int]$Matches[1] }
    }
}
# Plain-substring counts (not pipe-delimited telemetry).
$captureDismountCount = @($win | Where-Object { $_ -match 'begin capture-dismount' }).Count
$errorExprCount = @($win | Where-Object { $_ -match 'Error in expression' }).Count

# ---- 2b. WASP-NEXT (V2) telemetry [WFN] -------------------------------------
# Additive: NEXT emits `[WFN][LEVEL] ...` lines (space-delimited key=value), NOT the
# legacy pipe-delimited WASPSTAT|/SRVPERF|/AICOMSTAT| stream. When NEXT lines are present
# in the window we parse the five dashboard-relevant shapes and populate the SAME
# intermediate variables the legacy path fills, so every downstream consumer (charts,
# checkpoints, benchCurrent, $curCounts/$winExtras fold-in, benchmarks UPSERT, $out) works
# unchanged. We only fill a field if the legacy path left it empty, so a legacy WASP run is
# never disturbed; the two are kept apart by the -MissionLabel tag (WASP vs NEXT) already
# threaded through benchmarks.json + stats.json.benchmark.mission.
# Source line shapes (verified in mission-src):
#   [WFN][PERF] flush: t=<sec> fps=<n> players=<n> ai=<n> units=<n> vehicles=<n> sid=<id>
#   [WFN][PERF] metric: <name>=<value>           (cumulative; town.capture.transition_applied / economy.ledger.team_income)
#   [WFN][SMOKE] round-progress: t=<sec> | west hq=<s> anchors=<n> towns=<n> | east hq=<s> anchors=<n> towns=<n> | structures=<n> factories=<n> towns_res=<n>
#   [WFN][AICOMSTAT] aicomstat: t=<sec> | west grps=<n> funds=<n> sv=<n> towns=<n> ai=<0|1> | east grps=<n> funds=<n> sv=<n> towns=<n> ai=<0|1> | structures=<n> grp_total=<n>
#   [WFN][VICTORY] Log_MatchWin: key=<OWNER>_WIN_<TERRAIN> ... reason=<...>
# GAP (no NEXT equivalent): per-kill data, so kills/weapons/longestKill/hardware stay blank
# on NEXT runs; doctrine, wildcards, war-log EVENT narration, HC/delegation likewise absent.
$nextLines = @($win | Where-Object { $_ -match '\[WFN\]' })
$isNext = $nextLines.Count -gt 0
$nextPlayers = $null          # last [WFN][PERF] flush players= (applied after the A2S section)
$nextCaptureCount = $null     # town.capture.transition_applied metric (cumulative town flips)
if ($isNext) {
    # ---- PERF flush: server FPS history + players online. t is in SECONDS -> minutes. ----
    $nextFlush = @($win | Where-Object { $_ -match '\[WFN\]\[PERF\]\s*flush:' })
    foreach ($l in $nextFlush) {
        if ($l -match '\bfps=(-?\d+)') {
            $fv = [int]$Matches[1]
            if ($fv -ge 0) { $fpsVals += $fv }   # fps=-1 means ServerFps unset; skip
        }
    }
    if ($fpsVals.Count -gt 0) {
        $m = $fpsVals | Measure-Object -Minimum -Average
        $srvFps = [ordered]@{ last = $fpsVals[$fpsVals.Count - 1]; avg = [int]$m.Average; min = [int]$m.Minimum }
    }
    # players online (server liveness) from the last flush. Captured here but APPLIED after
    # the A2S section below (which re-inits $humans); used only if the UDP query finds nothing.
    $lf = $null
    foreach ($l in $nextFlush) { $lf = $l }
    if ($lf -and $lf -match '\bplayers=(\d+)') { $nextPlayers = [int]$Matches[1] }

    # ---- PERF metric: cumulative counters. Take MAX per key across the window. ----
    function Get-NextMetricMax([object[]]$lines, [string]$key) {
        $max = $null
        $rx = '\[WFN\]\[PERF\]\s*metric:\s*' + [regex]::Escape($key) + '\s*=\s*(-?\d+(?:\.\d+)?)'
        foreach ($l in $lines) {
            if ($l -match $rx) {
                $v = [double]$Matches[1]
                if ($null -eq $max -or $v -gt $max) { $max = $v }
            }
        }
        return $max
    }
    # Captures: town.capture.transition_applied is THE town-flip counter (cumulative).
    $nextCaptureCount = Get-NextMetricMax $nextLines 'town.capture.transition_applied'

    # ---- SMOKE round-progress timeline: per-side towns + structures + resistance towns. ----
    # t in SECONDS -> minutes for chart/checkpoint parity with the legacy series.
    foreach ($l in @($win | Where-Object { $_ -match '\[WFN\]\[SMOKE\]\s*round-progress:' })) {
        if ($l -match 'round-progress:\s*t=(\d+)\s*\|\s*west\s+hq=\S+\s+anchors=\d+\s+towns=(\d+)\s*\|\s*east\s+hq=\S+\s+anchors=\d+\s+towns=(\d+)\s*\|\s*structures=(\d+)\s+factories=\d+\s+towns_res=(\d+)') {
            $tMin = [int][Math]::Round([int]$Matches[1] / 60)
            $wTowns = [int]$Matches[2]; $eTowns = [int]$Matches[3]
            $resTowns = [int]$Matches[5]   # towns_res -> guer "control" (no per-side guer towns in NEXT)
            $tcSeries += [ordered]@{ t = $tMin; west = $wTowns; east = $eTowns; guer = $resTowns }
            # active-town count = west + east towns (NEXT has no single activeTowns= token).
            $atCount = $wTowns + $eTowns
            $activeTownsLast = $atCount
            if ($atCount -gt $activeTownsMax) { $activeTownsMax = $atCount }
            # Feed the perf/SRVPERF-style series (fps comes from the nearest flush; default 0).
            # B74.2: keep the units/groups/veh keys present (0 on NEXT - the SMOKE line has no
            # server-side unit detail) so the perf series shape matches the legacy SRVPERF path.
            $perfSeries += [ordered]@{ t = $tMin; v = 0; towns = $atCount; units = 0; groups = 0; veh = 0 }
        }
    }
    # Latest town control (front line) from the last round-progress sample.
    if ($null -eq $townControl -and $tcSeries.Count -gt 0) {
        $tcl = $tcSeries[$tcSeries.Count - 1]
        $townControl = [ordered]@{ west = [int]$tcl.west; east = [int]$tcl.east; guer = [int]$tcl.guer; total = ([int]$tcl.west + [int]$tcl.east + [int]$tcl.guer) }
    }

    # ---- AICOMSTAT health line: per-side funds (economy) + groups (army) over time. ----
    foreach ($l in @($win | Where-Object { $_ -match '\[WFN\]\[AICOMSTAT\]\s*aicomstat:' })) {
        if ($l -match 'aicomstat:\s*t=(\d+)\s*\|\s*west\s+grps=(\d+)\s+funds=(-?\d+)\s+sv=-?\d+\s+towns=(\d+)\s+ai=[01]\s*\|\s*east\s+grps=(\d+)\s+funds=(-?\d+)\s+sv=-?\d+\s+towns=(\d+)\s+ai=[01]') {
            $tMin = [int][Math]::Round([int]$Matches[1] / 60)
            $wGrp = [int]$Matches[2]; $wFunds = [int]$Matches[3]; $wTwn = [int]$Matches[4]
            $eGrp = [int]$Matches[5]; $eFunds = [int]$Matches[6]; $eTwn = [int]$Matches[7]
            $armyW += [ordered]@{ t = $tMin; v = $wGrp }; $fundsW += [ordered]@{ t = $tMin; v = $wFunds }
            $armyE += [ordered]@{ t = $tMin; v = $eGrp }; $fundsE += [ordered]@{ t = $tMin; v = $eFunds }
            # Latest per-side scorecard (mirrors the legacy TICK -> $sides fill).
            $sides['WEST'] = [ordered]@{ elapsedMin = $tMin; towns = $wTwn; units = $wGrp; research = 0; funds = $wFunds; supply = 0 }
            $sides['EAST'] = [ordered]@{ elapsedMin = $tMin; towns = $eTwn; units = $eGrp; research = 0; funds = $eFunds; supply = 0 }
        }
    }
    # GRPBUDGET-equivalent (groups per side) from the last AICOMSTAT line, for the benchmark scorecard.
    $lastAicom = Get-LastMatch $win '\[WFN\]\[AICOMSTAT\]\s*aicomstat:'
    if ($lastAicom -and $lastAicom -match 'west\s+grps=(\d+).*east\s+grps=(\d+).*grp_total=(\d+)') {
        if ($null -eq $grpWest) { $grpWest = [int]$Matches[1] }
        if ($null -eq $grpEast) { $grpEast = [int]$Matches[2] }
        if ($null -eq $grpTotal) { $grpTotal = [int]$Matches[3] }
    }

    # ---- VICTORY Log_MatchWin: round winner -> wins West/East + round count. ----
    # key=<OWNER>_WIN_<TERRAIN>; OWNER token is WEST/EAST/RESISTANCE. Duration/map absent.
    foreach ($l in @($win | Where-Object { $_ -match '\[WFN\]\[VICTORY\]\s*Log_MatchWin:' })) {
        if ($l -match 'key=(WEST|EAST|RESISTANCE)_WIN_') {
            $w = $Matches[1]
            if ($w -eq 'WEST') { $winsWest++ } elseif ($w -eq 'EAST') { $winsEast++ }
            $roundsDetail += [ordered]@{ winner = $w; durationMin = 0 }
        }
    }

    # Rebuild the chart container so the NEXT-populated series are published.
    $charts = [ordered]@{
        townControl = @(Last-N $tcSeries 60)
        army = [ordered]@{ west = @(Last-N $armyW 60); east = @(Last-N $armyE 60) }
        economy = [ordered]@{ west = @(Last-N $fundsW 60); east = @(Last-N $fundsE 60) }
        perf = @($perfSeries)
    }

    # A/B arm: NEXT runs are the V2 'NEXT' build by definition when -MissionLabel is NEXT.
    if ($null -eq $arm) { $arm = $(if ($MissionLabel -eq 'NEXT') { 'NEXT' } else { 'LEGACY' }) }
}

# ---- back to shared composition ----
# Capture total: legacy counts WASPSTAT|CAPTURE lines; NEXT has no per-town names, only the
# cumulative town.capture.transition_applied metric. Use whichever is populated (NEXT metric
# wins only when there are no legacy CAPTURE lines, so a legacy WASP run is untouched).
$capturesTotal = $capLines.Count
if ($isNext -and $capLines.Count -eq 0 -and $null -ne $nextCaptureCount) { $capturesTotal = [int]$nextCaptureCount }
# Latest round minute from the perf series (or null when no SRVPERF yet).
$benchTLast = $null
if ($perfSeries.Count -gt 0) { $benchTLast = [int]$perfSeries[$perfSeries.Count - 1].t }
# Checkpoints: the $perfSeries row nearest each of 10/30/60/90 min that exists (fewer than 4 OK).
$benchCheckpoints = @()
if ($perfSeries.Count -gt 0) {
    foreach ($target in @(10, 30, 60, 90)) {
        $best = $null; $bestDelta = $null
        foreach ($row in $perfSeries) {
            $d = [Math]::Abs([int]$row.t - $target)
            if ($null -eq $bestDelta -or $d -lt $bestDelta) { $bestDelta = $d; $best = $row }
        }
        if ($null -ne $best) {
            $benchCheckpoints += [ordered]@{ t = [int]$best.t; fps = [int]$best.v; towns = [int]$best.towns }
        }
    }
}
# Current scorecard (build + history filled in after $changelog/persistence below).
$benchCurrent = [ordered]@{
    t = $benchTLast; towns = [int]$activeTownsLast; townsPeak = [int]$activeTownsMax
    fps = $srvFps
    groups = [ordered]@{ west = $grpWest; east = $grpEast; guer = $grpGuer; total = $grpTotal }
    teams = [ordered]@{ west = $teamsBench['WEST']; east = $teamsBench['EAST'] }
    unitsPerTeam = [ordered]@{ west = $uptBench['WEST']; east = $uptBench['EAST'] }
    remnants = [ordered]@{ west = $remBench['WEST']; east = $remBench['EAST'] }
    captures = $capturesTotal; captureDismount = $captureDismountCount
    errors = $errorExprCount; delegationPct = $delegPct
}

# ---- 3. Server liveness: procs, uptime, humans online (A2S minus HC procs) ----
$srvProcs = @(Get-Process arma2oaserver -ErrorAction SilentlyContinue)
$hcProcs  = @(Get-Process ArmA2OA -ErrorAction SilentlyContinue)
$serverUp = ($srvProcs.Count -ge 1)
$uptimeMin = $null
if ($serverUp) { $uptimeMin = [int]((Get-Date) - $srvProcs[0].StartTime).TotalMinutes }

$humans = $null
if ($serverUp) {
    try {
        $udp = New-Object System.Net.Sockets.UdpClient
        $udp.Client.ReceiveTimeout = 3000
        $udp.Connect('127.0.0.1', 2303)
        [byte[]]$rq = @(0xFF, 0xFF, 0xFF, 0xFF, 0x54) + [System.Text.Encoding]::ASCII.GetBytes('Source Engine Query') + @(0x00)
        $null = $udp.Send($rq, $rq.Length)
        $ep = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
        $rs = $udp.Receive([ref]$ep)
        $udp.Close()
        $ix = 6
        for ($s = 0; $s -lt 4; $s++) { while ($ix -lt $rs.Length -and $rs[$ix] -ne 0) { $ix++ }; $ix++ }
        $ix += 2
        $h = [int]$rs[$ix] - $hcProcs.Count
        if ($h -lt 0) { $h = 0 }
        $humans = $h
    } catch {}
}
# NEXT fallback: if the A2S query yielded nothing, use the last [WFN][PERF] flush players= count.
if ($null -eq $humans -and $null -ne $nextPlayers) { $humans = [int]$nextPlayers }

# B74.2 pop-tier quiet-round fallback: if neither a [POPTIER] nor a founding-skipped line was logged
# (the tier never changed from its init AND no side hit the cap), derive the tier from the live human
# count using the mission's own thresholds (AI_Commander_Teams.sqf:82 -> <=2:0 <=5:1 <=9:2 else:3).
if ($null -eq $popTier) {
    $fbH = if ($null -ne $humans) { [int]$humans } else { 0 }
    $fbTier = if ($fbH -le 2) { 0 } elseif ($fbH -le 5) { 1 } elseif ($fbH -le 9) { 2 } else { 3 }
    $fbCap = $tierCap[$fbTier]
    $fbWestAi = if ($sides.ContainsKey('WEST')) { [int]$sides['WEST'].units } else { 0 }
    $fbEastAi = if ($sides.ContainsKey('EAST')) { [int]$sides['EAST'].units } else { 0 }
    $popTier = [ordered]@{
        tier = $fbTier; humans = $fbH
        west = [ordered]@{ ai = $fbWestAi; cap = $fbCap }
        east = [ordered]@{ ai = $fbEastAi; cap = $fbCap }
    }
}

# ---- 4. All-time accumulation ----
$curCounts = [ordered]@{
    kills = $kills.Count; infKills = $infKills; vehKills = $vehKills; airKills = $airKills
    killsWest = $killsWest; killsEast = $killsEast
    captures = $capturesTotal; wildcards = $wildLines.Count
    rounds = $(if ($isNext) { $roundsDetail.Count } else { $roundEnds.Count }); winsWest = $winsWest; winsEast = $winsEast
}

# Window extras (dicts/lists/records) tracked alongside the plain counters.
$winExtras = [ordered]@{
    cards = $cardCounts; weapons = $weaponCounts; towns = $townCounts; hardware = $hwCounts
    rounds = $roundsDetail
    longDist = $longDist; longWeapon = $longWeapon
    ttftWest = $null; ttftEast = $null
}
if ($ttftSides.ContainsKey('WEST')) { $winExtras.ttftWest = [int]$ttftSides['WEST'] }
if ($ttftSides.ContainsKey('EAST')) { $winExtras.ttftEast = [int]$ttftSides['EAST'] }

$atFile = Join-Path $WebDir 'alltime.json'
$base = $null; $prevWindowId = ''; $prevWindow = $null; $prevX = $null; $bestTtft = $null
if (Test-Path $atFile) {
    try {
        $at = Get-Content $atFile -Raw | ConvertFrom-Json
        $base = $at.base; $prevWindowId = [string]$at.windowId; $prevWindow = $at.window
        if ($at.PSObject.Properties['windowX']) { $prevX = $at.windowX }
        if ($at.PSObject.Properties['bestTtft'] -and $null -ne $at.bestTtft) { $bestTtft = [int]$at.bestTtft }
    } catch {
        # Never silently zero the all-time totals: preserve the corrupt file for recovery.
        Write-Warning "alltime.json unreadable - preserving copy as .corrupt: $_"
        try { Copy-Item $atFile "$atFile.corrupt" -Force } catch {}
    }
}
$baseH = [ordered]@{}
foreach ($k in $curCounts.Keys) {
    $v = 0
    if ($null -ne $base -and $base.PSObject.Properties[$k]) { $v = [int]$base.$k }
    $baseH[$k] = $v
}
# Rebuild baseX (dicts/lists/records) from JSON.
$baseX = [ordered]@{
    cards = @{}; weapons = @{}; towns = @{}; hardware = @{}; rounds = @()
    longDist = 0; longWeapon = ''; ttftWest = $null; ttftEast = $null
}
if ($null -ne $base -and $base.PSObject.Properties['x']) {
    $bx = $base.x
    $baseX.cards = ConvertTo-CountHash $bx.cards
    $baseX.weapons = ConvertTo-CountHash $bx.weapons
    $baseX.towns = ConvertTo-CountHash $bx.towns
    if ($bx.PSObject.Properties['hardware']) { $baseX.hardware = ConvertTo-CountHash $bx.hardware }
    if ($bx.PSObject.Properties['rounds'] -and $null -ne $bx.rounds) {
        foreach ($rr in @($bx.rounds)) { $baseX.rounds += [ordered]@{ winner = [string]$rr.winner; durationMin = [int]$rr.durationMin } }
    }
    if ($bx.PSObject.Properties['longDist'] -and $null -ne $bx.longDist) { $baseX.longDist = [int]$bx.longDist; $baseX.longWeapon = [string]$bx.longWeapon }
    if ($bx.PSObject.Properties['ttftWest'] -and $null -ne $bx.ttftWest) { $baseX.ttftWest = [int]$bx.ttftWest }
    if ($bx.PSObject.Properties['ttftEast'] -and $null -ne $bx.ttftEast) { $baseX.ttftEast = [int]$bx.ttftEast }
}

if ($prevWindowId -ne $windowId -and $null -ne $prevWindow) {
    # Mission window changed: fold the previous window's final counts into base.
    foreach ($k in $curCounts.Keys) {
        if ($prevWindow.PSObject.Properties[$k]) { $baseH[$k] = $baseH[$k] + [int]$prevWindow.$k }
    }
    if ($null -ne $prevX) {
        $baseX.cards = Merge-CountHash $baseX.cards (ConvertTo-CountHash $prevX.cards)
        $baseX.weapons = Merge-CountHash $baseX.weapons (ConvertTo-CountHash $prevX.weapons)
        $baseX.towns = Merge-CountHash $baseX.towns (ConvertTo-CountHash $prevX.towns)
        if ($prevX.PSObject.Properties['hardware']) { $baseX.hardware = Merge-CountHash $baseX.hardware (ConvertTo-CountHash $prevX.hardware) }
        if ($prevX.PSObject.Properties['rounds'] -and $null -ne $prevX.rounds) {
            foreach ($rr in @($prevX.rounds)) { $baseX.rounds += [ordered]@{ winner = [string]$rr.winner; durationMin = [int]$rr.durationMin } }
        }
        if ($baseX.rounds.Count -gt 10) { $baseX.rounds = @($baseX.rounds[($baseX.rounds.Count - 10)..($baseX.rounds.Count - 1)]) }
        if ($prevX.PSObject.Properties['longDist'] -and [int]$prevX.longDist -gt $baseX.longDist) {
            $baseX.longDist = [int]$prevX.longDist; $baseX.longWeapon = [string]$prevX.longWeapon
        }
        foreach ($tk in @('ttftWest', 'ttftEast')) {
            if ($prevX.PSObject.Properties[$tk] -and $null -ne $prevX.$tk) {
                if ($null -eq $baseX[$tk] -or [int]$prevX.$tk -lt $baseX[$tk]) { $baseX[$tk] = [int]$prevX.$tk }
            }
        }
    }
}
if ($null -ne $ttftWindow -and ($null -eq $bestTtft -or $ttftWindow -lt $bestTtft)) { $bestTtft = $ttftWindow }

$allTime = [ordered]@{}
foreach ($k in $curCounts.Keys) { $allTime[$k] = $baseH[$k] + [int]$curCounts[$k] }

# Live all-time extras = base + current window.
$atCards = Merge-CountHash $baseX.cards $cardCounts
$atWeapons = Merge-CountHash $baseX.weapons $weaponCounts
$atTowns = Merge-CountHash $baseX.towns $townCounts
$atHardware = Merge-CountHash $baseX.hardware $hwCounts
$atRounds = @($baseX.rounds) + @($roundsDetail)
if ($atRounds.Count -gt 5) { $atRounds = @($atRounds[($atRounds.Count - 5)..($atRounds.Count - 1)]) }
$atLongDist = $baseX.longDist; $atLongWeapon = $baseX.longWeapon
if ($longDist -gt $atLongDist) { $atLongDist = $longDist; $atLongWeapon = $longWeapon }
$atTtftWest = $baseX.ttftWest; $atTtftEast = $baseX.ttftEast
if ($null -ne $winExtras.ttftWest -and ($null -eq $atTtftWest -or $winExtras.ttftWest -lt $atTtftWest)) { $atTtftWest = $winExtras.ttftWest }
if ($null -ne $winExtras.ttftEast -and ($null -eq $atTtftEast -or $winExtras.ttftEast -lt $atTtftEast)) { $atTtftEast = $winExtras.ttftEast }

# Serialized here, written AFTER stats.json succeeds (crash leaves prior consistent state).
$baseOut = [ordered]@{}
foreach ($k in $baseH.Keys) { $baseOut[$k] = $baseH[$k] }
$baseOut['x'] = $baseX
$alltimeJson = [ordered]@{ base = $baseOut; windowId = $windowId; window = $curCounts; windowX = $winExtras; bestTtft = $bestTtft } |
    ConvertTo-Json -Depth 8

# ---- 4a. PER-MAP all-time separation -----------------------------------------
# The server rotates terrains (Chernarus <-> Takistan ...). The legacy alltime.json above keeps
# ONE combined pool (preserved for our own analysis + backward-compat). For the public dashboard
# we additionally bucket all-time records/history BY MAP in alltime-bymap.json so Takistan records
# never overwrite Chernarus ones (and vice-versa). Each bucket has the SAME shape as the legacy
# file ({ base, windowId, window, windowX, bestTtft }); the current window folds only into the
# CURRENT map's bucket via the shared Invoke-AllTimeFold (identical math, no cross-contamination).
$atMapFile = Join-Path $WebDir 'alltime-bymap.json'
$mapStore = $null
if (Test-Path $atMapFile) {
    try { $mapStore = Get-Content $atMapFile -Raw -Encoding UTF8 | ConvertFrom-Json }
    catch {
        Write-Warning "alltime-bymap.json unreadable - preserving copy as .corrupt: $_"
        try { Copy-Item $atMapFile "$atMapFile.corrupt" -Force } catch {}
        $mapStore = $null
    }
}
# The on-disk shape is { maps: { <mapId>: <bucket>, ... } }; the buckets live UNDER .maps. Read that
# inner object so we never mistake the wrapper key "maps" for a map id (that produced a phantom
# bucket literally named "maps"). Tolerate an older/loose file that stored buckets at top level.
$mapsObj = $null
if ($null -ne $mapStore) {
    if ($mapStore.PSObject.Properties['maps']) { $mapsObj = $mapStore.maps } else { $mapsObj = $mapStore }
}
# Seed the current map's bucket from the legacy combined pool ONCE, so the very first per-map run
# isn't empty: the live map inherits the historical combined totals; the other map starts clean and
# diverges from here. Detected by the absence of any persisted bucket for this map AND a non-empty
# legacy base. (towns are the only field that truly can't be un-mixed retroactively; everything
# else is a reasonable starting credit for the currently-running map.)
$bucketPersisted = $null
if ($null -ne $mapsObj -and $mapsObj.PSObject.Properties[$mapId]) {
    $bucketPersisted = $mapsObj.$mapId
} elseif ($null -ne $base) {
    # First sighting of this map: inherit the legacy combined pool as this map's starting base.
    $bucketPersisted = [pscustomobject]@{ base = $base; windowId = ''; window = $null; windowX = $null; bestTtft = $bestTtft }
}

# Per-map fold for the CURRENT map (its window == the same current window we just parsed).
$mapFold = Invoke-AllTimeFold -persisted $bucketPersisted -windowId $windowId -curCounts $curCounts `
    -cardCounts $cardCounts -weaponCounts $weaponCounts -townCounts $townCounts -hwCounts $hwCounts `
    -roundsDetail $roundsDetail -longDist $longDist -longWeapon $longWeapon `
    -ttftWindow $ttftWindow -winTtftWest $winExtras.ttftWest -winTtftEast $winExtras.ttftEast

# Rebuild the persisted by-map store: keep every other map's bucket untouched, replace the current
# map's bucket with its freshly-folded base + in-progress window.
$mapStoreOut = [ordered]@{}
if ($null -ne $mapsObj) {
    foreach ($p in @($mapsObj.PSObject.Properties)) {
        # Skip the current map (re-added below) and any stray non-bucket wrapper key.
        if ([string]$p.Name -ne $mapId -and [string]$p.Name -ne 'maps') { $mapStoreOut[[string]$p.Name] = $p.Value }
    }
}
$mapStoreOut[$mapId] = [ordered]@{
    base = $mapFold.baseOut; windowId = $windowId; window = $curCounts; windowX = $winExtras
    bestTtft = $mapFold.bestTtft; label = $mapLabel
}
$alltimeMapJson = ([ordered]@{ maps = $mapStoreOut } | ConvertTo-Json -Depth 9)

# Build the published per-map all-time blocks (one per known bucket). Other maps publish from their
# frozen base only (their window isn't the current one, so it shows that map's totals as last seen).
$allTimeByMap = [ordered]@{}
$mapLabelsOut = [ordered]@{}
foreach ($mk in @($mapStoreOut.Keys)) {
    $bucket = $mapStoreOut[$mk]
    if ($mk -eq $mapId) {
        # Current map: live block (base + current window), already computed.
        $allTimeByMap[$mk] = Build-AllTimeBlock $mapFold
    } else {
        # Other map: fold with an EMPTY current window so we just surface its persisted base totals.
        $emptyCounts = [ordered]@{}
        foreach ($ck in $curCounts.Keys) { $emptyCounts[$ck] = 0 }
        $otherFold = Invoke-AllTimeFold -persisted $bucket -windowId ([string]$bucket.windowId) -curCounts $emptyCounts `
            -cardCounts @{} -weaponCounts @{} -townCounts @{} -hwCounts @{} `
            -roundsDetail @() -longDist 0 -longWeapon '' -ttftWindow $null -winTtftWest $null -winTtftEast $null
        $allTimeByMap[$mk] = Build-AllTimeBlock $otherFold
    }
    $lbl = $mapId
    if ($bucket -is [System.Collections.IDictionary] -and $bucket.Contains('label')) { $lbl = [string]$bucket['label'] }
    elseif ($bucket.PSObject.Properties['label']) { $lbl = [string]$bucket.label }
    if ($mk -eq $mapId) { $lbl = $mapLabel }
    $mapLabelsOut[$mk] = $lbl
}

# ---- 4a2. TOP PLAYERS leaderboard (alltime / weekly / monthly) ------------------------------
# The live mission now emits one PLAYERSTAT row per connected human player every ~60s:
#   PLAYERSTAT|v1|<seq>|<name>|<uid>|<side>|<score>|<kills>|<deaths>|t=<roundMin>
# PLAYERSTAT carries the display NAME + engine score (cumulative within a round, only grows),
# so the LAST row per UID in the window = that UID's round-total score. Kills/deaths are emitted
# as 0 by the mission and are folded HERE from the existing WASPSTAT|...|KILL stream (a KILL with
# a non-empty killer UID = a player kill; non-empty victim UID = a player death).
#
# Accumulation mirrors alltime.json: each per-player file stores a per-UID `base` (sum of all
# COMPLETED rounds) plus the in-progress `window` (keyed by $windowId). When $windowId changes,
# the previous window's per-UID totals fold into base. Weekly/monthly additionally carry a
# bucketKey (ISO-week / year-month); when the bucket rolls over, base is reset to empty so the
# window starts a fresh period - the alltime file never resets.

# Parse the latest PLAYERSTAT snapshot per UID in this window (name/side/score; score = round total).
$psWin = @{}   # uid -> @{ name; side; score }
foreach ($l in @($win | Where-Object { $_ -match 'PLAYERSTAT\|v1\|' })) {
    $pp = ($l -replace '^.*PLAYERSTAT\|', 'PLAYERSTAT|') -split '\|'
    # 0 PLAYERSTAT 1 v1 2 seq 3 name 4 uid 5 side 6 score 7 kills 8 deaths 9 t=...
    if ($pp.Count -lt 7) { continue }
    $uid = ([string]$pp[4]).Trim()
    if ($uid -eq '') { continue }
    $nm = [string]$pp[3]
    $sd = 0; [void][int]::TryParse(([string]$pp[5]).Trim(), [ref]$sd)
    $sc = 0; [void][int]::TryParse(([string]$pp[6]).Trim(), [ref]$sc)
    # Last row wins (score only grows within a round); keep newest name+side too.
    $psWin[$uid] = [ordered]@{ name = $nm; side = $sd; score = $sc }
}

# Fold the KILL stream into per-UID kills/deaths for THIS window (player UIDs only).
$pKills = @{}   # uid -> kills (any victim)
$pDeaths = @{}  # uid -> deaths (killed by anyone)
# PvP-ONLY tally: a kill counts as player-vs-player ONLY when BOTH the killer UID and the
# victim UID are non-empty real player UIDs (i.e. a human killed another human; AI victims -
# which log an EMPTY victim UID - are excluded). Same KILL stream, stricter both-UID gate.
$pvpKills  = @{}   # killer uid -> pvp kills
$pvpDeaths = @{}   # victim uid -> pvp deaths
$pvpSeenUid = @{}  # uid -> $true (every UID that appeared on either end of a PvP kill)
foreach ($k in $kills) {
    $kp = ($k -replace '^.*WASPSTAT\|', 'WASPSTAT|') -split '\|'
    # 0 WASPSTAT 1 v1 2 seq 3 KILL 4 kUID 5 vUID ...
    if ($kp.Count -lt 6) { continue }
    $kU = ([string]$kp[4]).Trim()
    $vU = ([string]$kp[5]).Trim()
    if ($kU -ne '') { if ($pKills.ContainsKey($kU)) { $pKills[$kU]++ } else { $pKills[$kU] = 1 } }
    if ($vU -ne '') { if ($pDeaths.ContainsKey($vU)) { $pDeaths[$vU]++ } else { $pDeaths[$vU] = 1 } }
    # PvP gate: BOTH ends are real players (and not a self-kill artifact).
    if ($kU -ne '' -and $vU -ne '' -and $kU -ne $vU) {
        if ($pvpKills.ContainsKey($kU))  { $pvpKills[$kU]++ }  else { $pvpKills[$kU] = 1 }
        if ($pvpDeaths.ContainsKey($vU)) { $pvpDeaths[$vU]++ } else { $pvpDeaths[$vU] = 1 }
        $pvpSeenUid[$kU] = $true; $pvpSeenUid[$vU] = $true
    }
}

# Per-UID PvP rows for THIS window: carry name/side from the PLAYERSTAT snapshot when present
# (so the leaderboard shows display names, not UID tails), plus pvpKills/pvpDeaths.
$winPvp = @{}   # uid -> @{ name; side; pvpKills; pvpDeaths }
$pvpUids = @{}
foreach ($u in $pvpSeenUid.Keys) { $pvpUids[$u] = $true }
foreach ($u in @($pvpUids.Keys)) {
    $nm = ''; $sd = 0
    if ($psWin.ContainsKey($u)) { $nm = [string]$psWin[$u].name; $sd = [int]$psWin[$u].side }
    $pk = 0; if ($pvpKills.ContainsKey($u))  { $pk = [int]$pvpKills[$u] }
    $pd = 0; if ($pvpDeaths.ContainsKey($u)) { $pd = [int]$pvpDeaths[$u] }
    $winPvp[$u] = [ordered]@{ name = $nm; side = $sd; pvpKills = $pk; pvpDeaths = $pd }
}

# Current-window per-UID rows: union of UIDs seen in PLAYERSTAT (for name/score) and KILL (for k/d).
$winPlayers = @{}   # uid -> @{ name; side; score; kills; deaths }
$allUids = @{}
foreach ($u in $psWin.Keys)   { $allUids[$u] = $true }
foreach ($u in $pKills.Keys)  { $allUids[$u] = $true }
foreach ($u in $pDeaths.Keys) { $allUids[$u] = $true }
foreach ($u in @($allUids.Keys)) {
    $nm = ''; $sd = 0; $sc = 0
    if ($psWin.ContainsKey($u)) { $nm = [string]$psWin[$u].name; $sd = [int]$psWin[$u].side; $sc = [int]$psWin[$u].score }
    $kk = 0; if ($pKills.ContainsKey($u))  { $kk = [int]$pKills[$u] }
    $dd = 0; if ($pDeaths.ContainsKey($u)) { $dd = [int]$pDeaths[$u] }
    $winPlayers[$u] = [ordered]@{ name = $nm; side = $sd; score = $sc; kills = $kk; deaths = $dd }
}

# Bucket keys for the rolling windows (current ISO week / current month, UTC).
# ISO-8601 week is computed by hand: System.Globalization.ISOWeek is .NET Core 3.0+ only
# (absent in the Windows PowerShell 5.1 / .NET Framework runtime the scheduled task uses).
$nowUtc = (Get-Date).ToUniversalTime()
function Get-IsoWeekKey([datetime]$dt) {
    # Shift to the Thursday of this week; the ISO year+week derive from that Thursday.
    $cal = [System.Globalization.CultureInfo]::InvariantCulture.Calendar
    $day = [int]$dt.DayOfWeek                     # Sunday=0..Saturday=6
    if ($day -eq 0) { $day = 7 }                  # -> ISO Monday=1..Sunday=7
    $thursday = $dt.Date.AddDays(4 - $day)
    $isoYear = $thursday.Year
    $week = $cal.GetWeekOfYear($thursday, [System.Globalization.CalendarWeekRule]::FirstFourDayWeek, [System.DayOfWeek]::Monday)
    return ('{0:D4}-W{1:D2}' -f $isoYear, $week)
}
$weekKey  = Get-IsoWeekKey $nowUtc
$monthKey = '{0:D4}-{1:D2}'  -f $nowUtc.Year, $nowUtc.Month

# Reads a per-player leaderboard file, folds the previous window on windowId change, resets base
# on bucket rollover, then returns the merged rows (base + current window) for publishing.
function Update-PlayerWindow {
    param([string]$path, [hashtable]$winRows, [string]$curWindowId, [string]$bucketKey)
    $base = @{}            # uid -> @{ name; side; score; kills; deaths }  (completed rounds)
    $storedWindowId = ''
    $storedBucket = $bucketKey
    $storedWin = $null
    if (Test-Path $path) {
        try {
            $j = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($j.PSObject.Properties['bucketKey']) { $storedBucket = [string]$j.bucketKey }
            if ($j.PSObject.Properties['windowId'])  { $storedWindowId = [string]$j.windowId }
            if ($j.PSObject.Properties['base'] -and $null -ne $j.base) {
                foreach ($p in @($j.base.PSObject.Properties)) {
                    $r = $p.Value
                    $base[[string]$p.Name] = @{
                        name = [string]$r.name; side = [int]$r.side
                        score = [int]$r.score; kills = [int]$r.kills; deaths = [int]$r.deaths
                    }
                }
            }
            if ($j.PSObject.Properties['window'] -and $null -ne $j.window) { $storedWin = $j.window }
        } catch {
            Write-Warning "$([IO.Path]::GetFileName($path)) unreadable - preserving copy as .corrupt: $_"
            try { Copy-Item $path "$path.corrupt" -Force } catch {}
            $base = @{}; $storedWindowId = ''; $storedBucket = $bucketKey; $storedWin = $null
        }
    }

    # Bucket rollover (weekly/monthly only - alltime always passes a constant bucketKey): start fresh.
    if ($bucketKey -ne $storedBucket) {
        $base = @{}; $storedWindowId = ''; $storedWin = $null
    }

    # Window changed: fold the PREVIOUS window's per-UID totals into base (one-time, like alltime.json).
    if ($storedWindowId -ne $curWindowId -and $null -ne $storedWin) {
        foreach ($p in @($storedWin.PSObject.Properties)) {
            $u = [string]$p.Name; $r = $p.Value
            if (-not $base.ContainsKey($u)) { $base[$u] = @{ name = ''; side = 0; score = 0; kills = 0; deaths = 0 } }
            $base[$u].score  += [int]$r.score
            $base[$u].kills  += [int]$r.kills
            $base[$u].deaths += [int]$r.deaths
            if ([string]$r.name -ne '') { $base[$u].name = [string]$r.name }   # keep latest non-empty name
            if ([int]$r.side -ne 0)     { $base[$u].side = [int]$r.side }
        }
    }

    # Persisted shape: base (folded) + current window (in-progress, replaces each run).
    $windowOut = [ordered]@{}
    foreach ($u in @($winRows.Keys | Sort-Object)) {
        $windowOut[$u] = [ordered]@{
            name = [string]$winRows[$u].name; side = [int]$winRows[$u].side
            score = [int]$winRows[$u].score; kills = [int]$winRows[$u].kills; deaths = [int]$winRows[$u].deaths
        }
    }
    $baseOut2 = [ordered]@{}
    foreach ($u in @($base.Keys | Sort-Object)) {
        $baseOut2[$u] = [ordered]@{
            name = [string]$base[$u].name; side = [int]$base[$u].side
            score = [int]$base[$u].score; kills = [int]$base[$u].kills; deaths = [int]$base[$u].deaths
        }
    }
    $fileObj = [ordered]@{ bucketKey = $bucketKey; windowId = $curWindowId; base = $baseOut2; window = $windowOut }
    Write-AtomicUtf8 $path (ConvertTo-Json $fileObj -Depth 6)

    # Merged rows for publishing = base + current window, per UID.
    $merged = @{}
    foreach ($u in $base.Keys) {
        $merged[$u] = @{ name = [string]$base[$u].name; side = [int]$base[$u].side; score = [int]$base[$u].score; kills = [int]$base[$u].kills; deaths = [int]$base[$u].deaths }
    }
    foreach ($u in $winRows.Keys) {
        if (-not $merged.ContainsKey($u)) { $merged[$u] = @{ name = ''; side = 0; score = 0; kills = 0; deaths = 0 } }
        $merged[$u].score  += [int]$winRows[$u].score
        $merged[$u].kills  += [int]$winRows[$u].kills
        $merged[$u].deaths += [int]$winRows[$u].deaths
        if ([string]$winRows[$u].name -ne '') { $merged[$u].name = [string]$winRows[$u].name }
        if ([int]$winRows[$u].side -ne 0)     { $merged[$u].side = [int]$winRows[$u].side }
    }

    # Emit top rows by score (descending), capped to 50. Drop empties (no name AND no score AND no kills).
    $rows = @()
    foreach ($u in $merged.Keys) {
        $m = $merged[$u]
        # Drop non-players + noise from the leaderboard: headless clients (named HC1/HC2/..) and any
        # entry with zero activity (no score, no kills, no deaths). Without this, the bot "HC2" and
        # idle "joined-but-did-nothing" slots ranked above real players.
        if ([string]$m.name -match '^HC\d*$') { continue }
        if ([int]$m.score -eq 0 -and [int]$m.kills -eq 0 -and [int]$m.deaths -eq 0) { continue }
        $sideLabel = switch ([int]$m.side) { 1 { 'WEST' } 2 { 'EAST' } default { 'OTHER' } }
        $nameOut = [string]$m.name
        if ($nameOut -eq '') { $nameOut = 'Player ' + ($u.Substring([Math]::Max(0, $u.Length - 4))) }  # UID-tail fallback if a kill arrived before any snapshot
        $kd = if ([int]$m.deaths -gt 0) { [Math]::Round([double]$m.kills / [double]$m.deaths, 2) } else { $null }
        $rows += [ordered]@{ name = $nameOut; side = $sideLabel; score = [int]$m.score; kills = [int]$m.kills; deaths = [int]$m.deaths; kd = $kd }
    }
    $rows = @($rows | Sort-Object -Property @{ Expression = { [int]$_.score }; Descending = $true }, @{ Expression = { [int]$_.kills }; Descending = $true } | Select-Object -First 50)
    return $rows
}

$plAllFile   = Join-Path $WebDir 'players-alltime.json'
$plWeekFile  = Join-Path $WebDir 'players-weekly.json'
$plMonthFile = Join-Path $WebDir 'players-monthly.json'
$topAlltime = @(Update-PlayerWindow $plAllFile   $winPlayers $windowId 'ALL')
$topWeekly  = @(Update-PlayerWindow $plWeekFile  $winPlayers $windowId $weekKey)
$topMonthly = @(Update-PlayerWindow $plMonthFile $winPlayers $windowId $monthKey)

# ---- 4a3. TOP PvP PLAYERS leaderboard (player-vs-player kills only) -------------------------
# Same accumulation model as Update-PlayerWindow (per-UID base of completed rounds + in-progress
# window keyed by windowId; weekly/monthly reset on bucket rollover) but the carried metrics are
# pvpKills / pvpDeaths only - kills where BOTH ends are real player UIDs (see $winPvp above).
function Update-PvpWindow {
    param([string]$path, [hashtable]$winRows, [string]$curWindowId, [string]$bucketKey)
    $base = @{}            # uid -> @{ name; side; pvpKills; pvpDeaths }
    $storedWindowId = ''
    $storedBucket = $bucketKey
    $storedWin = $null
    if (Test-Path $path) {
        try {
            $j = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($j.PSObject.Properties['bucketKey']) { $storedBucket = [string]$j.bucketKey }
            if ($j.PSObject.Properties['windowId'])  { $storedWindowId = [string]$j.windowId }
            if ($j.PSObject.Properties['base'] -and $null -ne $j.base) {
                foreach ($p in @($j.base.PSObject.Properties)) {
                    $r = $p.Value
                    $base[[string]$p.Name] = @{
                        name = [string]$r.name; side = [int]$r.side
                        pvpKills = [int]$r.pvpKills; pvpDeaths = [int]$r.pvpDeaths
                    }
                }
            }
            if ($j.PSObject.Properties['window'] -and $null -ne $j.window) { $storedWin = $j.window }
        } catch {
            Write-Warning "$([IO.Path]::GetFileName($path)) unreadable - preserving copy as .corrupt: $_"
            try { Copy-Item $path "$path.corrupt" -Force } catch {}
            $base = @{}; $storedWindowId = ''; $storedBucket = $bucketKey; $storedWin = $null
        }
    }
    # Bucket rollover (weekly/monthly): start fresh.
    if ($bucketKey -ne $storedBucket) { $base = @{}; $storedWindowId = ''; $storedWin = $null }
    # Window changed: fold the PREVIOUS window's per-UID totals into base (one-time).
    if ($storedWindowId -ne $curWindowId -and $null -ne $storedWin) {
        foreach ($p in @($storedWin.PSObject.Properties)) {
            $u = [string]$p.Name; $r = $p.Value
            if (-not $base.ContainsKey($u)) { $base[$u] = @{ name = ''; side = 0; pvpKills = 0; pvpDeaths = 0 } }
            $base[$u].pvpKills  += [int]$r.pvpKills
            $base[$u].pvpDeaths += [int]$r.pvpDeaths
            if ([string]$r.name -ne '') { $base[$u].name = [string]$r.name }
            if ([int]$r.side -ne 0)     { $base[$u].side = [int]$r.side }
        }
    }
    # Persisted shape: base (folded) + current window (in-progress).
    $windowOut = [ordered]@{}
    foreach ($u in @($winRows.Keys | Sort-Object)) {
        $windowOut[$u] = [ordered]@{
            name = [string]$winRows[$u].name; side = [int]$winRows[$u].side
            pvpKills = [int]$winRows[$u].pvpKills; pvpDeaths = [int]$winRows[$u].pvpDeaths
        }
    }
    $baseOut2 = [ordered]@{}
    foreach ($u in @($base.Keys | Sort-Object)) {
        $baseOut2[$u] = [ordered]@{
            name = [string]$base[$u].name; side = [int]$base[$u].side
            pvpKills = [int]$base[$u].pvpKills; pvpDeaths = [int]$base[$u].pvpDeaths
        }
    }
    $fileObj = [ordered]@{ bucketKey = $bucketKey; windowId = $curWindowId; base = $baseOut2; window = $windowOut }
    Write-AtomicUtf8 $path (ConvertTo-Json $fileObj -Depth 6)
    # Merged rows = base + current window, per UID.
    $merged = @{}
    foreach ($u in $base.Keys) {
        $merged[$u] = @{ name = [string]$base[$u].name; side = [int]$base[$u].side; pvpKills = [int]$base[$u].pvpKills; pvpDeaths = [int]$base[$u].pvpDeaths }
    }
    foreach ($u in $winRows.Keys) {
        if (-not $merged.ContainsKey($u)) { $merged[$u] = @{ name = ''; side = 0; pvpKills = 0; pvpDeaths = 0 } }
        $merged[$u].pvpKills  += [int]$winRows[$u].pvpKills
        $merged[$u].pvpDeaths += [int]$winRows[$u].pvpDeaths
        if ([string]$winRows[$u].name -ne '') { $merged[$u].name = [string]$winRows[$u].name }
        if ([int]$winRows[$u].side -ne 0)     { $merged[$u].side = [int]$winRows[$u].side }
    }
    # Emit top rows by pvpKills desc (then fewest pvpDeaths). Drop HCs and zero-activity entries.
    $rows = @()
    foreach ($u in $merged.Keys) {
        $m = $merged[$u]
        if ([string]$m.name -match '^HC\d*$') { continue }
        if ([int]$m.pvpKills -eq 0 -and [int]$m.pvpDeaths -eq 0) { continue }
        $sideLabel = switch ([int]$m.side) { 1 { 'WEST' } 2 { 'EAST' } default { 'OTHER' } }
        $nameOut = [string]$m.name
        if ($nameOut -eq '') { $nameOut = 'Player ' + ($u.Substring([Math]::Max(0, $u.Length - 4))) }
        $kd = if ([int]$m.pvpDeaths -gt 0) { [Math]::Round([double]$m.pvpKills / [double]$m.pvpDeaths, 2) } else { $null }
        $rows += [ordered]@{ name = $nameOut; side = $sideLabel; pvpKills = [int]$m.pvpKills; pvpDeaths = [int]$m.pvpDeaths; kd = $kd }
    }
    $rows = @($rows | Sort-Object -Property @{ Expression = { [int]$_.pvpKills }; Descending = $true }, @{ Expression = { [int]$_.pvpDeaths }; Descending = $false } | Select-Object -First 50)
    return $rows
}

$pvpAllFile   = Join-Path $WebDir 'pvp-alltime.json'
$pvpWeekFile  = Join-Path $WebDir 'pvp-weekly.json'
$pvpMonthFile = Join-Path $WebDir 'pvp-monthly.json'
$pvpAlltime = @(Update-PvpWindow $pvpAllFile   $winPvp $windowId 'ALL')
$pvpWeekly  = @(Update-PvpWindow $pvpWeekFile  $winPvp $windowId $weekKey)
$pvpMonthly = @(Update-PvpWindow $pvpMonthFile $winPvp $windowId $monthKey)

# ---- 4a4. BASE BUILDING KILLS leaderboard (per-player enemy-base structures destroyed) ------
# Tracks how many ENEMY BASE BUILDINGS (HQ, Barracks, Light/Heavy/Aircraft factory, UAV terminal,
# Service point, AA/Counter-Battery radar, Bank/Federal Reserve, Command Center, ...) each PLAYER
# destroys. Same windowId/bucket accumulation model as the other leaderboards.
#
# TELEMETRY SOURCE (as of 2026-06-15): the live mission does NOT yet emit a per-player base-building
# kill line. Base buildings are destroyed via Server\Functions\Server_BuildingKilled.sqf, which
# deleteVehicle's the structure OUTSIDE the unit-killed PVF (RequestOnUnitKilled.sqf), so they never
# reach the WASPSTAT|...|KILL stream - verified: zero KILL|...|HQ and zero KILL|...|STRUCT lines in
# the RPT, only INF/VEH/STATIC/AIR. So this board is EMPTY until the mission adds the line below.
#
# This parser accepts a forward-looking, KILL-style token so the board auto-populates the moment the
# mission starts emitting it (NO pipeline redeploy needed). Recommended mission line (gate on
# WFBE_C_STATLOG == 1, emit from Server_BuildingKilled.sqf for a non-teamkill player killer):
#   WASPSTAT|v1|<seq>|BUILDINGKILL|<killerUID>|<killerSide>|<victimSide>|<structClass>|<structType>
# where <structType> is the friendly label (HQ / LightFactory / Bank / AntiAirRadar / ...). Only
# rows with a non-empty killerUID (a real player destroyed an enemy base building) are counted.
$bkWin = @{}   # uid -> @{ name; side; buildings }   (this window)
foreach ($l in @($win | Where-Object { $_ -match 'BUILDINGKILL\|' })) {
    $bp = ($l -replace '^.*WASPSTAT\|', 'WASPSTAT|') -split '\|'
    # 0 WASPSTAT 1 v1 2 seq 3 BUILDINGKILL 4 killerUID 5 killerSide 6 victimSide 7 structClass 8 structType
    if ($bp.Count -lt 5) { continue }
    $kU = ([string]$bp[4]).Trim()
    if ($kU -eq '') { continue }   # only real-player base-building kills
    # Side from the snapshot if available; else map the logged killer side word -> our 1/2/0 code.
    $sd = 0
    if ($psWin.ContainsKey($kU)) { $sd = [int]$psWin[$kU].side }
    elseif ($bp.Count -ge 6) { switch (([string]$bp[5]).Trim().ToUpper()) { 'WEST' { $sd = 1 } 'EAST' { $sd = 2 } 'GUER' { $sd = 3 } 'RESISTANCE' { $sd = 3 } } }
    $nm = ''; if ($psWin.ContainsKey($kU)) { $nm = [string]$psWin[$kU].name }
    if (-not $bkWin.ContainsKey($kU)) { $bkWin[$kU] = [ordered]@{ name = $nm; side = $sd; buildings = 0 } }
    $bkWin[$kU].buildings++
    if ($nm -ne '') { $bkWin[$kU].name = $nm }
    if ($sd -ne 0) { $bkWin[$kU].side = $sd }
}

# Reads a base-building-kill leaderboard file, folds previous window on windowId change, resets base
# on bucket rollover, returns merged rows for publishing. Mirrors Update-PvpWindow exactly; the only
# carried metric is `buildings` (enemy base structures destroyed).
function Update-BkWindow {
    param([string]$path, [hashtable]$winRows, [string]$curWindowId, [string]$bucketKey)
    $base = @{}            # uid -> @{ name; side; buildings }
    $storedWindowId = ''
    $storedBucket = $bucketKey
    $storedWin = $null
    if (Test-Path $path) {
        try {
            $j = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($j.PSObject.Properties['bucketKey']) { $storedBucket = [string]$j.bucketKey }
            if ($j.PSObject.Properties['windowId'])  { $storedWindowId = [string]$j.windowId }
            if ($j.PSObject.Properties['base'] -and $null -ne $j.base) {
                foreach ($p in @($j.base.PSObject.Properties)) {
                    $r = $p.Value
                    $base[[string]$p.Name] = @{ name = [string]$r.name; side = [int]$r.side; buildings = [int]$r.buildings }
                }
            }
            if ($j.PSObject.Properties['window'] -and $null -ne $j.window) { $storedWin = $j.window }
        } catch {
            Write-Warning "$([IO.Path]::GetFileName($path)) unreadable - preserving copy as .corrupt: $_"
            try { Copy-Item $path "$path.corrupt" -Force } catch {}
            $base = @{}; $storedWindowId = ''; $storedBucket = $bucketKey; $storedWin = $null
        }
    }
    if ($bucketKey -ne $storedBucket) { $base = @{}; $storedWindowId = ''; $storedWin = $null }
    if ($storedWindowId -ne $curWindowId -and $null -ne $storedWin) {
        foreach ($p in @($storedWin.PSObject.Properties)) {
            $u = [string]$p.Name; $r = $p.Value
            if (-not $base.ContainsKey($u)) { $base[$u] = @{ name = ''; side = 0; buildings = 0 } }
            $base[$u].buildings += [int]$r.buildings
            if ([string]$r.name -ne '') { $base[$u].name = [string]$r.name }
            if ([int]$r.side -ne 0)     { $base[$u].side = [int]$r.side }
        }
    }
    $windowOut = [ordered]@{}
    foreach ($u in @($winRows.Keys | Sort-Object)) {
        $windowOut[$u] = [ordered]@{ name = [string]$winRows[$u].name; side = [int]$winRows[$u].side; buildings = [int]$winRows[$u].buildings }
    }
    $baseOut2 = [ordered]@{}
    foreach ($u in @($base.Keys | Sort-Object)) {
        $baseOut2[$u] = [ordered]@{ name = [string]$base[$u].name; side = [int]$base[$u].side; buildings = [int]$base[$u].buildings }
    }
    $fileObj = [ordered]@{ bucketKey = $bucketKey; windowId = $curWindowId; base = $baseOut2; window = $windowOut }
    Write-AtomicUtf8 $path (ConvertTo-Json $fileObj -Depth 6)
    $merged = @{}
    foreach ($u in $base.Keys) { $merged[$u] = @{ name = [string]$base[$u].name; side = [int]$base[$u].side; buildings = [int]$base[$u].buildings } }
    foreach ($u in $winRows.Keys) {
        if (-not $merged.ContainsKey($u)) { $merged[$u] = @{ name = ''; side = 0; buildings = 0 } }
        $merged[$u].buildings += [int]$winRows[$u].buildings
        if ([string]$winRows[$u].name -ne '') { $merged[$u].name = [string]$winRows[$u].name }
        if ([int]$winRows[$u].side -ne 0)     { $merged[$u].side = [int]$winRows[$u].side }
    }
    $rows = @()
    foreach ($u in $merged.Keys) {
        $m = $merged[$u]
        if ([string]$m.name -match '^HC\d*$') { continue }
        if ([int]$m.buildings -eq 0) { continue }
        $sideLabel = switch ([int]$m.side) { 1 { 'WEST' } 2 { 'EAST' } 3 { 'GUER' } default { 'OTHER' } }
        $nameOut = [string]$m.name
        if ($nameOut -eq '') { $nameOut = 'Player ' + ($u.Substring([Math]::Max(0, $u.Length - 4))) }
        $rows += [ordered]@{ name = $nameOut; side = $sideLabel; buildings = [int]$m.buildings }
    }
    $rows = @($rows | Sort-Object -Property @{ Expression = { [int]$_.buildings }; Descending = $true } | Select-Object -First 50)
    return $rows
}
$bkAllFile   = Join-Path $WebDir 'bk-alltime.json'
$bkWeekFile  = Join-Path $WebDir 'bk-weekly.json'
$bkMonthFile = Join-Path $WebDir 'bk-monthly.json'
$bkAlltime = @(Update-BkWindow $bkAllFile   $bkWin $windowId 'ALL')
$bkWeekly  = @(Update-BkWindow $bkWeekFile  $bkWin $windowId $weekKey)
$bkMonthly = @(Update-BkWindow $bkMonthFile $bkWin $windowId $monthKey)

# ---- ALL-TIME UNIT BALANCE (per killing-platform class, cross-side) -------------------------------
# Same base+window fold as the leaderboards, but keyed by weapon/vehicle CLASS (not UID) and carrying
# combat metrics: kills / deaths (from vc= victim class) / kd, the inf/veh/air victim split, and the
# pvp/pve split (human vs AI victim). One ALL bucket that never resets, so US-vs-RU balance accrues
# across every round. Additive: writes a NEW backing file (balance-alltime.json); nothing else reads it.
function Update-BalanceWindow {
    param([string]$path, [hashtable]$winRows, [string]$curWindowId, [string]$bucketKey)
    $base = @{}   # class -> @{ side; kills; deaths; inf; veh; air; pvp; pve; allAi }
    $storedWindowId = ''; $storedBucket = $bucketKey; $storedWin = $null
    if (Test-Path $path) {
        try {
            $j = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($j.PSObject.Properties['bucketKey']) { $storedBucket = [string]$j.bucketKey }
            if ($j.PSObject.Properties['windowId'])  { $storedWindowId = [string]$j.windowId }
            if ($j.PSObject.Properties['base'] -and $null -ne $j.base) {
                foreach ($p in @($j.base.PSObject.Properties)) {
                    $r = $p.Value
                    $base[[string]$p.Name] = @{ side = [string]$r.side; kills = [int]$r.kills; deaths = [int]$r.deaths; inf = [int]$r.inf; veh = [int]$r.veh; air = [int]$r.air; pvp = [int]$r.pvp; pve = [int]$r.pve; allAi = [bool]$r.allAi }
                }
            }
            if ($j.PSObject.Properties['window'] -and $null -ne $j.window) { $storedWin = $j.window }
        } catch {
            Write-Warning "$([IO.Path]::GetFileName($path)) unreadable - preserving copy as .corrupt: $_"
            try { Copy-Item $path "$path.corrupt" -Force } catch {}
            $base = @{}; $storedWindowId = ''; $storedBucket = $bucketKey; $storedWin = $null
        }
    }
    if ($bucketKey -ne $storedBucket) { $base = @{}; $storedWindowId = ''; $storedWin = $null }
    # fold the PREVIOUS window into base once the round (windowId) changes
    if ($storedWindowId -ne $curWindowId -and $null -ne $storedWin) {
        foreach ($p in @($storedWin.PSObject.Properties)) {
            $c = [string]$p.Name; $r = $p.Value
            if (-not $base.ContainsKey($c)) { $base[$c] = @{ side = ''; kills = 0; deaths = 0; inf = 0; veh = 0; air = 0; pvp = 0; pve = 0; allAi = $true } }
            $base[$c].kills += [int]$r.kills; $base[$c].deaths += [int]$r.deaths
            $base[$c].inf += [int]$r.inf; $base[$c].veh += [int]$r.veh; $base[$c].air += [int]$r.air
            $base[$c].pvp += [int]$r.pvp; $base[$c].pve += [int]$r.pve
            if ([string]$r.side -ne '') { $base[$c].side = [string]$r.side }
            if (-not [bool]$r.allAi) { $base[$c].allAi = $false }
        }
    }
    # persist base + current in-progress window
    $windowOut = [ordered]@{}
    foreach ($c in @($winRows.Keys | Sort-Object)) {
        $w = $winRows[$c]
        $windowOut[$c] = [ordered]@{ side = [string]$w.side; kills = [int]$w.kills; deaths = [int]$w.deaths; inf = [int]$w.inf; veh = [int]$w.veh; air = [int]$w.air; pvp = [int]$w.pvp; pve = [int]$w.pve; allAi = [bool]$w.allAi }
    }
    $baseOut2 = [ordered]@{}
    foreach ($c in @($base.Keys | Sort-Object)) {
        $b0 = $base[$c]
        $baseOut2[$c] = [ordered]@{ side = [string]$b0.side; kills = [int]$b0.kills; deaths = [int]$b0.deaths; inf = [int]$b0.inf; veh = [int]$b0.veh; air = [int]$b0.air; pvp = [int]$b0.pvp; pve = [int]$b0.pve; allAi = [bool]$b0.allAi }
    }
    Write-AtomicUtf8 $path (ConvertTo-Json ([ordered]@{ bucketKey = $bucketKey; windowId = $curWindowId; base = $baseOut2; window = $windowOut }) -Depth 6)
    # merged = base + current window (the published all-time view)
    $merged = @{}
    foreach ($c in $base.Keys) { $b0=$base[$c]; $merged[$c] = @{ side=[string]$b0.side; kills=[int]$b0.kills; deaths=[int]$b0.deaths; inf=[int]$b0.inf; veh=[int]$b0.veh; air=[int]$b0.air; pvp=[int]$b0.pvp; pve=[int]$b0.pve; allAi=[bool]$b0.allAi } }
    foreach ($c in $winRows.Keys) {
        $w=$winRows[$c]
        if (-not $merged.ContainsKey($c)) { $merged[$c] = @{ side=''; kills=0; deaths=0; inf=0; veh=0; air=0; pvp=0; pve=0; allAi=$true } }
        $merged[$c].kills += [int]$w.kills; $merged[$c].deaths += [int]$w.deaths
        $merged[$c].inf += [int]$w.inf; $merged[$c].veh += [int]$w.veh; $merged[$c].air += [int]$w.air
        $merged[$c].pvp += [int]$w.pvp; $merged[$c].pve += [int]$w.pve
        if ([string]$w.side -ne '') { $merged[$c].side = [string]$w.side }
        if (-not [bool]$w.allAi) { $merged[$c].allAi = $false }
    }
    $rows = @()
    foreach ($c in $merged.Keys) {
        $m = $merged[$c]
        if ([int]$m.kills -eq 0) { continue }
        $rkd = $(if ([int]$m.deaths -gt 0) { [math]::Round([double]$m.kills / [double]$m.deaths, 2) } else { $null })
        $rows += [ordered]@{ class=[string]$c; side=[string]$m.side; kills=[int]$m.kills; deaths=[int]$m.deaths; kd=$rkd; inf=[int]$m.inf; veh=[int]$m.veh; air=[int]$m.air; pvp=[int]$m.pvp; pve=[int]$m.pve; ai=$(if($m.allAi){1}else{0}) }
    }
    return @($rows | Sort-Object -Property @{ Expression = { [int]$_.kills }; Descending = $true } | Select-Object -First 40)
}
$balAllFile = Join-Path $WebDir 'balance-alltime.json'
$balanceAllTime = @(Update-BalanceWindow $balAllFile $balanceWin $windowId 'ALL')

# ---- 4a5. GUER "INSURGENTS" leaderboard (forward-looking; playable GUER is a FUTURE update) -----
# A playable GUER (resistance) faction is NOT live yet - today only AI-GUER exists, so this board is
# EMPTY. It auto-populates the moment GUER-player kills start logging: their KILL lines already carry
# killerSide=GUER (verified in the RPT), so once a human plays GUER the existing WASPSTAT|KILL stream
# folds straight in. We gate purely on the LOGGED killer side word in the KILL line (field 7), which
# is independent of the PLAYERSTAT side code (whose GUER value we can't yet observe).
#
# Columns: kills, deaths, K/D (LIVE once GUER players log) + survivalSec, droneStrikes, townsDenied
# (all 0 / PENDING - require NEW mission telemetry; see the report. They are scaffolded so the board
# and JSON shape are final and only need the mission to start emitting the extra fields).
$guerWin = @{}   # uid -> @{ name; kills; deaths; survivalSec; drones; townsDenied }
# Player kills/deaths where the GUER side is involved, keyed by player UID. A GUER-player KILL has a
# non-empty killer UID AND killerSide=GUER; a GUER-player death has a non-empty victim UID AND
# victimSide=GUER. (AI-GUER kills have empty UIDs and are correctly ignored.)
foreach ($k in $kills) {
    $kp = ($k -replace '^.*WASPSTAT\|', 'WASPSTAT|') -split '\|'
    # 0 WASPSTAT 1 v1 2 seq 3 KILL 4 kUID 5 vUID 6 kSide 7 vSide ...
    if ($kp.Count -lt 8) { continue }
    $kU = ([string]$kp[4]).Trim(); $vU = ([string]$kp[5]).Trim()
    $kS = ([string]$kp[6]).Trim().ToUpper(); $vS = ([string]$kp[7]).Trim().ToUpper()
    if ($kU -ne '' -and ($kS -eq 'GUER' -or $kS -eq 'RESISTANCE')) {
        if (-not $guerWin.ContainsKey($kU)) { $guerWin[$kU] = [ordered]@{ name = ''; kills = 0; deaths = 0; survivalSec = 0; drones = 0; townsDenied = 0 } }
        $guerWin[$kU].kills++
        if ($psWin.ContainsKey($kU) -and [string]$psWin[$kU].name -ne '') { $guerWin[$kU].name = [string]$psWin[$kU].name }
    }
    if ($vU -ne '' -and ($vS -eq 'GUER' -or $vS -eq 'RESISTANCE')) {
        if (-not $guerWin.ContainsKey($vU)) { $guerWin[$vU] = [ordered]@{ name = ''; kills = 0; deaths = 0; survivalSec = 0; drones = 0; townsDenied = 0 } }
        $guerWin[$vU].deaths++
        if ($psWin.ContainsKey($vU) -and [string]$psWin[$vU].name -ne '') { $guerWin[$vU].name = [string]$psWin[$vU].name }
    }
}
# Fold a GUER-insurgent leaderboard file (windowId fold + bucket reset), return merged rows.
function Update-GuerWindow {
    param([string]$path, [hashtable]$winRows, [string]$curWindowId, [string]$bucketKey)
    $cols = @('kills','deaths','survivalSec','drones','townsDenied')
    $base = @{}            # uid -> @{ name; <cols> }
    $storedWindowId = ''
    $storedBucket = $bucketKey
    $storedWin = $null
    if (Test-Path $path) {
        try {
            $j = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($j.PSObject.Properties['bucketKey']) { $storedBucket = [string]$j.bucketKey }
            if ($j.PSObject.Properties['windowId'])  { $storedWindowId = [string]$j.windowId }
            if ($j.PSObject.Properties['base'] -and $null -ne $j.base) {
                foreach ($p in @($j.base.PSObject.Properties)) {
                    $r = $p.Value
                    $row = @{ name = [string]$r.name }
                    foreach ($c in $cols) { $row[$c] = if ($r.PSObject.Properties[$c]) { [int]$r.$c } else { 0 } }
                    $base[[string]$p.Name] = $row
                }
            }
            if ($j.PSObject.Properties['window'] -and $null -ne $j.window) { $storedWin = $j.window }
        } catch {
            Write-Warning "$([IO.Path]::GetFileName($path)) unreadable - preserving copy as .corrupt: $_"
            try { Copy-Item $path "$path.corrupt" -Force } catch {}
            $base = @{}; $storedWindowId = ''; $storedBucket = $bucketKey; $storedWin = $null
        }
    }
    if ($bucketKey -ne $storedBucket) { $base = @{}; $storedWindowId = ''; $storedWin = $null }
    if ($storedWindowId -ne $curWindowId -and $null -ne $storedWin) {
        foreach ($p in @($storedWin.PSObject.Properties)) {
            $u = [string]$p.Name; $r = $p.Value
            if (-not $base.ContainsKey($u)) { $base[$u] = @{ name = '' }; foreach ($c in $cols) { $base[$u][$c] = 0 } }
            foreach ($c in $cols) { if ($r.PSObject.Properties[$c]) { $base[$u][$c] += [int]$r.$c } }
            if ([string]$r.name -ne '') { $base[$u].name = [string]$r.name }
        }
    }
    $windowOut = [ordered]@{}
    foreach ($u in @($winRows.Keys | Sort-Object)) {
        $o = [ordered]@{ name = [string]$winRows[$u].name }
        foreach ($c in $cols) { $o[$c] = [int]$winRows[$u].$c }
        $windowOut[$u] = $o
    }
    $baseOut2 = [ordered]@{}
    foreach ($u in @($base.Keys | Sort-Object)) {
        $o = [ordered]@{ name = [string]$base[$u].name }
        foreach ($c in $cols) { $o[$c] = [int]$base[$u][$c] }
        $baseOut2[$u] = $o
    }
    $fileObj = [ordered]@{ bucketKey = $bucketKey; windowId = $curWindowId; base = $baseOut2; window = $windowOut }
    Write-AtomicUtf8 $path (ConvertTo-Json $fileObj -Depth 6)
    $merged = @{}
    foreach ($u in $base.Keys) { $m = @{ name = [string]$base[$u].name }; foreach ($c in $cols) { $m[$c] = [int]$base[$u][$c] }; $merged[$u] = $m }
    foreach ($u in $winRows.Keys) {
        if (-not $merged.ContainsKey($u)) { $merged[$u] = @{ name = '' }; foreach ($c in $cols) { $merged[$u][$c] = 0 } }
        foreach ($c in $cols) { $merged[$u][$c] += [int]$winRows[$u].$c }
        if ([string]$winRows[$u].name -ne '') { $merged[$u].name = [string]$winRows[$u].name }
    }
    $rows = @()
    foreach ($u in $merged.Keys) {
        $m = $merged[$u]
        if ([string]$m.name -match '^HC\d*$') { continue }
        if ([int]$m.kills -eq 0 -and [int]$m.deaths -eq 0) { continue }
        $nameOut = [string]$m.name
        if ($nameOut -eq '') { $nameOut = 'Player ' + ($u.Substring([Math]::Max(0, $u.Length - 4))) }
        $kd = if ([int]$m.deaths -gt 0) { [Math]::Round([double]$m.kills / [double]$m.deaths, 2) } else { $null }
        $rows += [ordered]@{ name = $nameOut; side = 'GUER'; kills = [int]$m.kills; deaths = [int]$m.deaths; kd = $kd
            survivalSec = [int]$m.survivalSec; drones = [int]$m.drones; townsDenied = [int]$m.townsDenied }
    }
    $rows = @($rows | Sort-Object -Property @{ Expression = { [int]$_.kills }; Descending = $true }, @{ Expression = { [int]$_.deaths }; Descending = $false } | Select-Object -First 50)
    return $rows
}
$guerAllFile   = Join-Path $WebDir 'guer-alltime.json'
$guerWeekFile  = Join-Path $WebDir 'guer-weekly.json'
$guerMonthFile = Join-Path $WebDir 'guer-monthly.json'
$guerAlltime = @(Update-GuerWindow $guerAllFile   $guerWin $windowId 'ALL')
$guerWeekly  = @(Update-GuerWindow $guerWeekFile  $guerWin $windowId $weekKey)
$guerMonthly = @(Update-GuerWindow $guerMonthFile $guerWin $windowId $monthKey)

# ---- 4c. Daily briefs: latest digests, whitelisted sections only (no chat, no error sigs) ----
$briefs = @()
$briefWhitelist = @('## Mission', '## AICOMSTAT Round Summary', '## Server Performance', '## HC / Delegation Health', '## WASPSTAT Kill/Capture Summary')
foreach ($df in @(Get-ChildItem (Join-Path $EvalDir 'digest-*.md') -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 2)) {
    try {
        $raw = Get-Content $df.FullName -Raw
        # Files are append-mode: take the LAST digest block in the file.
        $blocks = $raw -split '(?m)^# Window Digest'
        $block = $blocks[$blocks.Count - 1]
        $lines = $block -split "`r?`n"
        $keep = New-Object System.Collections.Generic.List[string]
        $inSection = $false
        foreach ($ln in $lines) {
            if ($ln -match '^## ') {
                $inSection = $false
                foreach ($w in $briefWhitelist) { if ($ln.StartsWith($w)) { $inSection = $true } }
            }
            if ($inSection) { $keep.Add($ln) }
        }
        $label = $df.BaseName -replace 'digest-', ''
        $briefs += [ordered]@{ label = $label; body = ($keep -join "`n").Trim() }
    } catch {}
}

# ---- 4d. Changelog passthrough (rebuild as plain hashtables: PS5.1 re-serializes
#      a ConvertFrom-Json array as {value,Count} otherwise) ----
$changelog = @()
$clFile = Join-Path $WebDir 'changelog.json'
if (Test-Path $clFile) {
    try {
        # NOTE: PS5.1 ConvertFrom-Json emits a JSON array as ONE pipeline object; foreach
        # over the result enumerates it correctly - do NOT wrap it in @() first.
        $clParsed = Get-Content $clFile -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($c in $clParsed) {
            $changelog += [ordered]@{ build = [string]$c.build; date = [string]$c.date; title = [string]$c.title; items = @($c.items | ForEach-Object { [string]$_ }); details = [string]$c.details }
        }
    } catch {}
}

# ---- 4e. Benchmarks history: one finalized row per round/version, UPSERTED by windowId.
# Mirrors the alltime.json pattern (Write-AtomicUtf8, full fidelity, NOT subject to the
# publish delay - the file itself is written immediately). The current round's row keeps
# updating until $windowId changes, at which point it freezes and a new row begins -> exactly
# one finalized benchmark per round/version with no boundary detection. Capped to last 50.
$benchBuild = ''
if ($changelog.Count -gt 0 -and $changelog[0].build) { $benchBuild = [string]$changelog[0].build }
# Winner of this window's round (if any ROUNDEND seen; use the latest in $roundsDetail).
$benchWinner = ''
if ($roundsDetail.Count -gt 0) { $benchWinner = [string]$roundsDetail[$roundsDetail.Count - 1].winner }
$benchRow = [ordered]@{
    windowId = [string]$windowId; mission = $MissionLabel; build = $benchBuild; arm = $arm
    map = $mapLabel   # friendly terrain label (Chernarus/Takistan/...) derived from the RPT this run
    updatedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    t = $(if ($null -ne $benchTLast) { [int]$benchTLast } else { 0 })
    townsPeak = [int]$activeTownsMax
    fpsAvg = $srvFps.avg; fpsMin = $srvFps.min
    groupsTotal = $grpTotal
    teamsWest = $teamsBench['WEST']; teamsEast = $teamsBench['EAST']
    captures = $capturesTotal; captureDismount = $captureDismountCount
    errors = $errorExprCount; winner = $benchWinner
}
# Persist OUTSIDE the served web dir: this row updates live (not on the 2-min delay),
# so keep it off any public URL. The dashboard still gets history via the delayed
# stats.json.benchmark.history embed below - benchmarks.json is server-side only.
$benchFile = Join-Path (Split-Path $WebDir -Parent) 'benchmarks.json'
$benchRows = @()
if (Test-Path $benchFile) {
    try {
        # PS5.1 ConvertFrom-Json emits a JSON array as ONE pipeline object; foreach enumerates
        # it correctly - rebuild each row as a plain ordered hashtable so re-serialization stays
        # clean (no {value,Count} wrapper) and arithmetic/replacement works.
        $bParsed = Get-Content $benchFile -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($r in $bParsed) {
            $benchRows += [ordered]@{
                windowId = [string]$r.windowId; build = [string]$r.build
                arm = $(if ($null -ne $r.arm) { [string]$r.arm } else { $null })
                map = $(if ($null -ne $r.map -and [string]$r.map -ne '') { [string]$r.map } else { $null })
                mission = $(if ($null -ne $r.mission -and [string]$r.mission -ne '') { [string]$r.mission } else { $null })
                updatedAt = [string]$r.updatedAt
                t = [int]$r.t; townsPeak = [int]$r.townsPeak
                fpsAvg = $(if ($null -ne $r.fpsAvg) { [int]$r.fpsAvg } else { $null })
                fpsMin = $(if ($null -ne $r.fpsMin) { [int]$r.fpsMin } else { $null })
                groupsTotal = $(if ($null -ne $r.groupsTotal) { [int]$r.groupsTotal } else { $null })
                teamsWest = $(if ($null -ne $r.teamsWest) { [int]$r.teamsWest } else { $null })
                teamsEast = $(if ($null -ne $r.teamsEast) { [int]$r.teamsEast } else { $null })
                captures = [int]$r.captures; captureDismount = [int]$r.captureDismount
                errors = [int]$r.errors; winner = [string]$r.winner
            }
        }
    } catch {
        # Never silently drop history: preserve the corrupt file and start fresh (alltime.json pattern).
        Write-Warning "benchmarks.json unreadable - preserving copy as .corrupt: $_"
        try { Copy-Item $benchFile "$benchFile.corrupt" -Force } catch {}
        $benchRows = @()
    }
}
# UPSERT by windowId: replace the matching row in place, else append.
$benchUpdated = @(); $benchFound = $false
foreach ($r in $benchRows) {
    if ([string]$r.windowId -eq [string]$windowId) { $benchUpdated += $benchRow; $benchFound = $true }
    else { $benchUpdated += $r }
}
if (-not $benchFound) { $benchUpdated += $benchRow }

# ---- CLEAN UP invalid / test-junk benchmark rows -------------------------------------------
# Drop rows that carry no usable signal: MISSINIT-only stubs (windowId ends in ':-1' or is
# 'none'), and empty rows where the round never produced perf data (t=0 AND townsPeak=0 AND no
# FPS AND no captures). These are the "zeros/malformed" entries. The CURRENT windowId row is
# ALWAYS kept (it legitimately starts empty early in a round and fills in over time), so live
# data is never discarded. Idempotent: junk that was already filtered simply isn't present.
$benchUpdated = @($benchUpdated | Where-Object {
    $wid = [string]$_.windowId
    if ($wid -eq [string]$windowId) { return $true }                 # keep the live row
    if ($wid -eq 'none' -or $wid -match ':-1$') { return $false }     # MISSINIT-less stub
    $noData = ([int]$_.t -le 0) -and ([int]$_.townsPeak -le 0) -and `
              ($null -eq $_.fpsAvg) -and ([int]$_.captures -le 0)
    -not $noData
})

# Cap to the last 50 rows.
if ($benchUpdated.Count -gt 50) { $benchUpdated = @($benchUpdated[($benchUpdated.Count - 50)..($benchUpdated.Count - 1)]) }
# Write immediately (full fidelity, like alltime.json - not delayed).
Write-AtomicUtf8 $benchFile (ConvertTo-Json @($benchUpdated) -Depth 8)
# History for the dashboard: last 20 rows, NEWEST FIRST.
$benchHistory = @()
$histStart = $benchUpdated.Count - 20
if ($histStart -lt 0) { $histStart = 0 }
for ($i = $benchUpdated.Count - 1; $i -ge $histStart; $i--) { $benchHistory += $benchUpdated[$i] }

# ---- 5. Compose stats.json ----
$recentCaps = @()
if ($capNames.Count -gt 0) {
    $start = $capNames.Count - 5
    if ($start -lt 0) { $start = 0 }
    $recentCaps = @($capNames[$start..($capNames.Count - 1)])
}

# HEADLESS-CLIENT COUNT (robustness): the box runs two HC processes (-name=HC and a sandboxed
# -name=HC2). The headline number is the MAX of the live ArmA2OA process count and the number of
# distinct HCs that reported telemetry this window ($hcList). Either source alone can momentarily
# under-count right after a map rotation/restart (a process mid-spawn, or an HC that hasn't emitted
# its first HCSTAT yet) - and the 2-min publish delay would then freeze "1 HC" onto the public page
# until the next regen. Taking the max means the count never dips below what we can actually see.
$hcCount = [Math]::Max([int]$hcProcs.Count, [int]$hcList.Count)

# ---- 4b2. AI Unstuck Recovery (assault-team stall escalation) over the post-MISSINIT window ----
$usStrikes=0; $usFired=0; $usTier=@{'1'=0;'2'=0;'3'=0}; $usStranded=@{}; $usArrived=@{}
foreach ($l in $win) {
  if ($l -match 'UNSTUCK_STRIKE\|team=([^|]+)\|tier=(\d+)') { $usStrikes++ }
  elseif ($l -match 'UNSTUCK_FIRED\|team=([^|]+)\|tier=(\d+)') { $usFired++; $tk=[string]$Matches[2]; if ($usTier.ContainsKey($tk)) { $usTier[$tk]++ } }
  elseif ($l -match 'ASSAULT_STRANDED\|team=([^|]+)\|') { $usStranded[[string]$Matches[1]]=$true }
  elseif ($l -match 'ASSAULT_ARRIVED\|team=([^|]+)\|')   { $usArrived[[string]$Matches[1]]=$true }
}
$usStrandedN=$usStranded.Count
$usRecovered=@($usStranded.Keys | Where-Object { $usArrived.ContainsKey($_) }).Count
$usPct = $(if ($usStrandedN -gt 0) { [int][math]::Round(100*$usRecovered/$usStrandedN) } else { 0 })
$unstuck = [ordered]@{ strikes=$usStrikes; fired=$usFired; firedByTier=[ordered]@{ '1'=$usTier['1']; '2'=$usTier['2']; '3'=$usTier['3'] }; stranded=$usStrandedN; recovered=$usRecovered; recoveryPct=$usPct }

# ---- 4b3. Battlefield Maintenance: debris cleaner + salvage lottery (B38/B39, Ray's "track this") ----
# The droppeditems cleaner records a PerformanceAudit entry per cycle; the 60s flush emits one line
# per name: NAME=cleaner_droppeditems ... CALLS=<cycles> AVG_MS=<active ms> MAX_MS=<max ms>
# EXTRA=scanned:..;deleted:..;weaponholders:..;mines:..;mineE:..;cap:..;cycleMs:..;lotteryWinner:..;lotteryAmount:..
# Take the LAST line for the "last sweep" snapshot; aggregate cycles + lottery payouts over the window.
$mtSweeps=0; $mtTotalDeleted=0; $mtLast=$null
foreach ($l in @($win | Where-Object { $_ -match 'NAME=cleaner_droppeditems\b' })) {
  # Tolerant of the B40 EXTRA (no mineE, no lottery) AND the older B38/B39 EXTRA (mineE + lottery suffix, ignored).
  if ($l -match 'CALLS=(\d+)\s+AVG_MS=([0-9.]+)\s+MAX_MS=([0-9.]+)\s+EXTRA=scanned:(\d+);deleted:(\d+);weaponholders:(\d+);mines:(\d+);(?:mineE:\d+;)?cap:(\d+);cycleMs:(\d+)') {
    $mtSweeps = $mtSweeps + [int]$Matches[1]
    $mtTotalDeleted = $mtTotalDeleted + [int]$Matches[5]
    $mtLast = [ordered]@{
      activeMs=[double]$Matches[2]; maxMs=[double]$Matches[3]; scanned=[int]$Matches[4]; deleted=[int]$Matches[5]
      weaponholders=[int]$Matches[6]; mines=[int]$Matches[7]; cap=[int]$Matches[8]; cycleMs=[int]$Matches[9]
    }
  }
}
$maintenance = [ordered]@{ lastSweep=$mtLast; sweeps=$mtSweeps; totalDeleted=$mtTotalDeleted }

# ---- 4b4. SIDESCORE honest side-activity (wasp-score-dashboard-build-20260722) ----
# Additive dual-field public battle score. SCORE|v1 uses engine scoreSide (player-driven only), so an
# AI-only side reads 0 despite real combat. The mission's flag-gated SIDESCORE|v1 line (flag WFBE_C_SIDESCORE)
# carries per-side engine playerScore PLUS AI-inclusive kill/capture running counters. Parse the LAST
# SIDESCORE line in the post-MISSINIT window (cumulative snapshot). All three fields stay $null when the
# flag is off / no line present, in which case the web normalizer already leaves the score tile empty.
$ssScore = $null; $ssPlayer = $null; $ssActivity = $null
$ssLine = @($win | Where-Object { $_ -match 'SIDESCORE\|v1\|' }) | Select-Object -Last 1
if ($ssLine -and $ssLine -match 'SIDESCORE\|v1\|playerWest=(-?\d+)\|playerEast=(-?\d+)\|killWest=(\d+)\|killEast=(\d+)\|killGuer=(\d+)\|capWest=(\d+)\|capEast=(\d+)\|capGuer=(\d+)\|') {
    $ssPW=[int]$Matches[1]; $ssPE=[int]$Matches[2]
    $ssKW=[int]$Matches[3]; $ssKE=[int]$Matches[4]; $ssKG=[int]$Matches[5]
    $ssCW=[int]$Matches[6]; $ssCE=[int]$Matches[7]; $ssCG=[int]$Matches[8]
    # Honest public battle score = AI-inclusive side kills (blueprint Option A). Engine scoreboard kept
    # separately as playerScore; sideActivity exposes raw kills/captures per side for honest UI labels.
    $ssScore    = [ordered]@{ west = $ssKW; east = $ssKE }
    $ssPlayer   = [ordered]@{ west = $ssPW; east = $ssPE }
    $ssActivity = [ordered]@{
        west = [ordered]@{ kills = $ssKW; captures = $ssCW }
        east = [ordered]@{ kills = $ssKE; captures = $ssCE }
        guer = [ordered]@{ kills = $ssKG; captures = $ssCG }
    }
}

$out = [ordered]@{
    generatedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    server = [ordered]@{
        online = $serverUp; uptimeMin = $uptimeMin; playersOnline = $humans
        headlessClients = $hcCount; map = $mapLabel; mapId = $mapId; arm = $arm
    }
    currentRound = [ordered]@{
        elapsedMin = $null; sides = $sides; doctrine = $doctrine
        captures = $capturesTotal; recentCaptures = $recentCaps
        kills = $kills.Count; wildcardsDrawn = $wildLines.Count; lastWildcard = $lastWild
        # SIDESCORE honest dual-field (wasp-score-dashboard-build-20260722): score = AI-inclusive side kills
        # (fixes the AI-only side reading 0 that engine scoreSide causes); playerScore = engine scoreSide;
        # sideActivity = raw kills/captures per side. All $null until the mission emits SIDESCORE|v1 (flag on).
        score = $ssScore; playerScore = $ssPlayer; sideActivity = $ssActivity
        battle = $battleCounts; townControl = $townControl; orbat = $orbat
        commanderIntel = $commanderIntel
        # B74.2: AI population tier (renderAicom reads currentRound.popTier) + MHQ relocations.
        # Both stay $null until the mission emits [POPTIER]/MHQRELOC lines (render keeps its pending note).
        popTier = $popTier; mhq = $mhq
    }
    charts = $charts
    warLog = $warLog
    performance = [ordered]@{
        serverFps = $srvFps; activeTowns = $activeTownsLast; activeTownsPeak = $activeTownsMax
        activeTownsBudget = $townsMax; headless = $hcList; delegationPct = $delegPct
        groupHealth = $groupHealth
        clientFps = $clientFps
        fpsHistory = @($fpsVals | Select-Object -Last 40); srvDetail = $srvDetail
    }
    unstuck = $unstuck
    maintenance = $maintenance
    changelog = $changelog
    briefs = $briefs
    allTime = [ordered]@{
        kills = $allTime.kills; infantryKills = $allTime.infKills; vehicleKills = $allTime.vehKills; aircraftKills = $allTime.airKills
        hardwareDestroyed = $atHardware
        killsByWest = $allTime.killsWest; killsByEast = $allTime.killsEast
        townsCaptured = $allTime.captures; roundsCompleted = $allTime.rounds
        winsWest = $allTime.winsWest; winsEast = $allTime.winsEast
        wildcardsDrawn = $allTime.wildcards; fastestFirstTownMin = $bestTtft
        fastestFirstTownWest = $atTtftWest; fastestFirstTownEast = $atTtftEast
        longestKill = [ordered]@{ meters = $atLongDist; weapon = $atLongWeapon }
        topWeapons = @(Get-TopN $atWeapons 5 'name' 'kills')
        contestedTowns = @(Get-TopN $atTowns 5 'name' 'captures')
        wildcardGallery = $atCards
        recentRounds = $atRounds
    }
    # PER-MAP all-time records (map-separated). `allTime` above stays the CURRENT map's set (live
    # single-map view unchanged); `allTimeByMap` carries every map's own pool keyed by world id, and
    # `mapLabels` maps id -> friendly name. The page defaults to the current map and offers a toggle.
    allTimeByMap = $allTimeByMap
    mapLabels = $mapLabelsOut
    warRoom = [ordered]@{
        guerUnits = $guerUnits
        ttftThisRound = [ordered]@{ west = $winExtras.ttftWest; east = $winExtras.ttftEast }
    }
    directorLedger = $directorLedger
    balance = [ordered]@{
        round = @($balanceRound)
        allTime = @($balanceAllTime)
        note = 'kills per killing platform, cross-side only (US-vs-RU balancing). round = this match; allTime = accumulated across all rounds. pvp/pve split = human vs AI victim.'
    }
    topPlayers = [ordered]@{
        alltime = @($topAlltime)
        weekly  = @($topWeekly)
        monthly = @($topMonthly)
        weekKey = $weekKey
        monthKey = $monthKey
        note = 'ranked by engine score; kills/deaths folded from the KILL stream by UID'
    }
    topPvp = [ordered]@{
        alltime = @($pvpAlltime)
        weekly  = @($pvpWeekly)
        monthly = @($pvpMonthly)
        weekKey = $weekKey
        monthKey = $monthKey
        note = 'player-vs-player kills only (both killer and victim are real player UIDs; AI victims excluded)'
    }
    topBuilding = [ordered]@{
        alltime = @($bkAlltime)
        weekly  = @($bkWeekly)
        monthly = @($bkMonthly)
        weekKey = $weekKey
        monthKey = $monthKey
        # telemetryReady flips to $true automatically once any BUILDINGKILL line has been folded.
        telemetryReady = ([bool](@($bkAlltime).Count + @($bkWeekly).Count + @($bkMonthly).Count))
        note = 'enemy base buildings destroyed per player (HQ, factories, radars, bank, ...). Pending mission BUILDINGKILL telemetry - empty until the mission emits it.'
    }
    topInsurgents = [ordered]@{
        alltime = @($guerAlltime)
        weekly  = @($guerWeekly)
        monthly = @($guerMonthly)
        weekKey = $weekKey
        monthKey = $monthKey
        # GUER kills/deaths/KD are LIVE-ready (fold from the existing KILL stream once a human plays
        # GUER); survivalSec/drones/townsDenied need NEW mission telemetry and stay 0 until then.
        playableGuerLive = ([bool](@($guerAlltime).Count + @($guerWeekly).Count + @($guerMonthly).Count))
        pending = @('survivalSec', 'drones', 'townsDenied')
        note = 'GUER (Insurgents) per-player board. Playable GUER is a future update: kills/deaths/KD auto-fill from the GUER-side KILL stream; survival time, Ka-137 drone strikes and towns-denied await mission telemetry.'
    }
    benchmark = [ordered]@{
        mission = $MissionLabel; build = $benchBuild; arm = $arm; windowId = [string]$windowId
        map = $mapLabel
        current = $benchCurrent
        checkpoints = @($benchCheckpoints)
        history = @($benchHistory)
    }
}
$elv = @()
foreach ($s in $sides.Keys) { $elv += [int]$sides[$s].elapsedMin }
if ($elv.Count -gt 0) { $out.currentRound.elapsedMin = ($elv | Measure-Object -Maximum).Maximum }

# All-time accumulation is updated LIVE (full fidelity) for our own analysis.
Write-AtomicUtf8 $atFile $alltimeJson
# Per-map all-time store (separate file; legacy alltime.json schema untouched). Written LIVE too.
Write-AtomicUtf8 $atMapFile $alltimeMapJson

# ---- 6. ANTI-INFLUENCE: scrub gameplay-sensitive intel, then publish on a 2-min delay ----
# Public viewers (incl. a live commander) must not gain an edge. Two protections:
#   (a) scrub precise tech/research (no "what tech"); positions/base locations are never
#       collected at all. Aggregate scores (town control, order of battle, economy,
#       doctrine) are kept - they are coarse, on-map-public, and delayed.
#   (b) publish a snapshot that is at least DELAY_SECONDS old, so nothing is real-time.
foreach ($s in @($out.currentRound.sides.Keys)) {
    if ($out.currentRound.sides[$s] -is [System.Collections.IDictionary]) {
        # Remove the key entirely (not just null it) so no "what tech" trace remains.
        if ($out.currentRound.sides[$s].Contains('research')) { $out.currentRound.sides[$s].Remove('research') }
    }
}
$out['dataDelaySeconds'] = 120
$pubJson = $out | ConvertTo-Json -Depth 8

$DELAY_SECONDS = 120
$histDir = Join-Path $WebDir 'history'
if (-not (Test-Path $histDir)) { New-Item -ItemType Directory -Force -Path $histDir | Out-Null }
$nowE = [int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
Write-AtomicUtf8 (Join-Path $histDir "snap-$nowE.json") $pubJson

$snaps = @(Get-ChildItem (Join-Path $histDir 'snap-*.json') -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.Name -match 'snap-(\d+)\.json') { [pscustomobject]@{ epoch = [int]$Matches[1]; path = $_.FullName } }
} | Sort-Object epoch)
$pub = @($snaps | Where-Object { $_.epoch -le ($nowE - $DELAY_SECONDS) } | Select-Object -Last 1)
$pubPath = Join-Path $WebDir 'stats.json'
if ($pub.Count -gt 0) {
    Write-AtomicUtf8 $pubPath ([IO.File]::ReadAllText($pub[0].path))
    Write-Output "published snapshot from $($nowE - $pub[0].epoch)s ago (2-min delay) $(Get-Date -Format 'HH:mm:ss')"
} elseif (-not (Test-Path $pubPath)) {
    # First ~2 min after a fresh deploy: nothing old enough yet. Publish a warming-up
    # placeholder so the page renders rather than 404s; real data appears once aged.
    $warm = [ordered]@{ generatedAt = $out.generatedAt; dataDelaySeconds = 120; warmingUp = $true; server = $out.server } | ConvertTo-Json -Depth 4
    Write-AtomicUtf8 $pubPath $warm
    Write-Output "warming up - no snapshot >= ${DELAY_SECONDS}s old yet $(Get-Date -Format 'HH:mm:ss')"
} else {
    Write-Output "no fresh-enough snapshot; left existing stats.json in place $(Get-Date -Format 'HH:mm:ss')"
}
# Prune snapshots older than 15 min.
foreach ($old in @($snaps | Where-Object { $_.epoch -lt ($nowE - 900) })) { Remove-Item -LiteralPath $old.path -Force -ErrorAction SilentlyContinue }
