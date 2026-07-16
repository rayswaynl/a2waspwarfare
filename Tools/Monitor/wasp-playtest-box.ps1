#requires -Version 5.1
<#!
.SYNOPSIS
  Bounded, read-only collector for the live Wasp server and two HC RPTs.

.DESCRIPTION
  This script runs on the game box. RPTs are held open by Arma, so every read uses
  FileShare.ReadWrite. It returns compact K/NEW records for the Game-PC reporter;
  it never emits a whole RPT and never writes to the server or its profiles.

  -1 watermarks establish a baseline (current length only). A rotated/shrunk RPT is
  scanned from its bounded tail and marked Reset=1 so the caller can explain the gap.
#>
param(
    [long]$SrvFrom = -1,
    [long]$Hc1From = -1,
    [long]$Hc2From = -1,
    [string]$SrvRpt = '',
    [string]$Hc1Rpt = 'C:\WASP\hc1-profile\ArmA2OA.RPT',
    [string]$Hc2Rpt = '',
    [int]$TailBytes = 4MB,
    [int]$MaxReadBytes = 8MB
)
$ErrorActionPreference = 'Continue'
$Encoding1252 = [System.Text.Encoding]::GetEncoding(1252)
if (-not $SrvRpt) { $userRoot = Join-Path $env:SystemDrive 'Users'; $SrvRpt = (Get-ChildItem -Path (Join-Path $userRoot '*\AppData\Local\ArmA 2 OA\arma2oaserver.RPT') -File -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName) }
if (-not $Hc1Rpt) { $Hc1Rpt = 'C:\WASP\hc1-profile\ArmA2OA.RPT' }
if (-not $Hc2Rpt) { $Hc2Rpt = (Get-ChildItem -Path 'C:\Sandbox\*\HC2\drive\C\WASP\hc2-profile\ArmA2OA.RPT' -File -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName) }

function Read-RptRange {
    param([string]$Path, [long]$From, [int]$MaxBytes)
    if (-not (Test-Path -LiteralPath $Path)) {
        return @{ text = ''; from = -1; nextMark = -1; truncated = 0; reset = 0 }
    }
    $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        $length = $fs.Length
        $reset = 0
        if ($From -lt 0) {
            return @{ text = ''; from = $length; nextMark = $length; truncated = 0; reset = 0 }
        }
        if ($From -gt $length) {
            $From = [Math]::Max(0, $length - $MaxBytes)
            $reset = 1
        }
        $want = [Math]::Min($MaxBytes, $length - $From)
        $truncated = [Math]::Max(0, ($length - $From) - $want)
        if ($want -le 0) {
            return @{ text = ''; from = $From; nextMark = $length; truncated = $truncated; reset = $reset }
        }
        [void]$fs.Seek($From, [System.IO.SeekOrigin]::Begin)
        $buffer = New-Object byte[] ([int]$want)
        $read = 0
        while ($read -lt $want) {
            $n = $fs.Read($buffer, $read, $want - $read)
            if ($n -le 0) { break }
            $read += $n
        }
        $lastNl = -1
        for ($i = $read - 1; $i -ge 0; $i--) {
            if ($buffer[$i] -eq 10) { $lastNl = $i; break }
        }
        if ($lastNl -lt 0) {
            return @{ text = ''; from = $From; nextMark = $From; truncated = $truncated; reset = $reset }
        }
        return @{ text = $Encoding1252.GetString($buffer, 0, $lastNl + 1); from = $From;
            nextMark = $From + $lastNl + 1; truncated = $truncated; reset = $reset }
    } finally { $fs.Dispose() }
}

function Get-RptMeta([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        return @{ exists = 0; len = -1; lastWriteUtc = ''; ageSec = -1 }
    }
    $item = Get-Item -LiteralPath $Path
    return @{ exists = 1; len = [long]$item.Length; lastWriteUtc = $item.LastWriteTimeUtc.ToString('o');
        ageSec = [int]([DateTime]::UtcNow - $item.LastWriteTimeUtc).TotalSeconds }
}

function Get-Key([string]$Line, [string]$Key) {
    $m = [regex]::Match($Line, '(?<![A-Za-z0-9_])' + [regex]::Escape($Key) + '=([^|"\r\n]*)')
    if ($m.Success) { return $m.Groups[1].Value.Trim() }
    return ''
}

function Emit-Current([string]$Path, [hashtable]$Meta) {
    if ($Meta.exists -ne 1) { return @('K|current=0') }
    $r = Read-RptRange -Path $Path -From ([Math]::Max(0, $Meta.len - $TailBytes)) -MaxBytes $TailBytes
    $lines = @($r.text -split "`r?`n" | Where-Object { $_ })
    $scale = ''; $snap = ''; $roster = ''
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        if (-not $scale -and $lines[$i] -match 'WASPSCALE\|v2\|') { $scale = $lines[$i] }
        if (-not $snap -and $lines[$i] -match 'NAME=snapshot\s+FPS=') { $snap = $lines[$i] }
        if (-not $roster -and $lines[$i] -match 'WASPSTAT\|v1\|\d+\|.*~') { $roster = $lines[$i] }
        if ($scale -and $snap -and $roster) { break }
    }
    $out = New-Object System.Collections.Generic.List[string]
    $out.Add('K|current=1')
    if ($scale) {
        $out.Add('K|scale=1')
        foreach ($k in @('players','AI_W','AI_E','AI_GUER','AI_TOT','groups','fps','hc_fps','hc2fps','townsW','townsE','townsG')) {
            $v = Get-Key $scale $k
            if ($v) { $out.Add(('K|scale_{0}={1}' -f $k, $v)) }
        }
        $build = Get-Key $scale 'build'; if ($build) { $out.Add("K|scale_build=$build") }
        $map = Get-Key $scale 'map'; if ($map) { $out.Add("K|scale_map=$map") }
    } else { $out.Add('K|scale=0') }
    if ($snap) {
        $out.Add('K|snap=1')
        foreach ($k in @('FPS','PLAYERS','AI','UNITS','VEHICLES','TOWNS_ACTIVE')) {
            $m = [regex]::Match($snap, '(?<![A-Za-z_])' + $k + '=(-?\d+)')
            if ($m.Success) { $out.Add(('K|snap_{0}={1}' -f $k, $m.Groups[1].Value)) }
        }
    } else { $out.Add('K|snap=0') }
    if ($roster) {
        $names = New-Object System.Collections.Generic.List[string]
        foreach ($m in [regex]::Matches($roster, '\d{6,}:[^|~]+~"?([^"|~]+)"?')) {
            $name = ($m.Groups[1].Value.Trim() -replace '[|;]', ' ')
            if ($name) { $names.Add($name) }
        }
        $hc = @($names | Where-Object { $_ -match '^HC(-AI)?-?AI-Control-[12]$|^HC-AI-Control-[12]$' })
        $total = Get-Key $scale 'players'
        if (-not $total -and $snap) { $m = [regex]::Match($snap, '\bPLAYERS=(\d+)'); if ($m.Success) { $total = $m.Groups[1].Value } }
        if (-not $total) { $total = $names.Count }
        $human = [Math]::Max(0, ([int]$total - $hc.Count))
        $out.Add(('K|roster_total={0}|roster_hc={1}|roster_humans={2}|roster_names={3}' -f $total, $hc.Count, $human, (($names -join ';'))))
    } else { $out.Add('K|roster_total=-1|roster_hc=-1|roster_humans=-1|roster_names=') }
    return $out.ToArray()
}

$srv = Get-RptMeta $SrvRpt; $hc1 = Get-RptMeta $Hc1Rpt; $hc2 = Get-RptMeta $Hc2Rpt
$tz = ''; try { $tz = [TimeZoneInfo]::Local.Id } catch {}
"K|collector=wasp-playtest-box|boxNowUtc=$([DateTime]::UtcNow.ToString('o'))|boxTz=$tz"
foreach ($pair in @(@('srv',$srv),@('hc1',$hc1),@('hc2',$hc2))) {
    "K|{0}Exists={1}|{0}Len={2}|{0}LastWriteUtc={3}|{0}AgeSec={4}" -f $pair[0],$pair[1].exists,$pair[1].len,$pair[1].lastWriteUtc,$pair[1].ageSec
}
Emit-Current $SrvRpt $srv

$errorPattern = 'Error in expression|Error position|Undefined variable|Error Undefined|Error Zero divisor|Error Type|\.sqf, line|elements provided|Error select|Warning Message:|is not a valid class|No entry|listed twice|does not support serialization'
$eventPattern = 'Critical:|Application terminated|Shutdown normally|Shutdown|desync|desynchron|No message received|Session lost|Connection.*lost|Player without identity|EXE version|MISSINIT:|ROUNDEND|BASE_OVERRUN'
function Emit-New([string]$Tag, [string]$Path, [long]$From, [hashtable]$Meta) {
    if ($Meta.exists -ne 1) { "K|${Tag}Mark=-1|${Tag}NewLines=0|${Tag}Reset=0"; return }
    if ($From -lt 0) { "K|${Tag}Mark=$($Meta.len)|${Tag}NewLines=0|${Tag}Reset=0|${Tag}Baseline=1"; return }
    $r = Read-RptRange -Path $Path -From $From -MaxBytes $MaxReadBytes
    $lines = @($r.text -split "`r?`n" | Where-Object { $_ })
    $errors = 0; $events = 0; $series = 0; $dropped = 0; $cap = if ($Tag -eq 'srv') { 500 } else { 250 }
    foreach ($line in $lines) {
        if ($line -match $errorPattern) {
            $errors++
            if ($errors -le $cap) { "NEW|$Tag|error|$line" } else { $dropped++ }
        } elseif ($line -match $eventPattern) {
            $events++
            if ($events -le 100) { "NEW|$Tag|event|$line" } else { $dropped++ }
        } elseif ($line -match 'WASPSCALE\|v2\||NAME=snapshot|AICOMSTAT\||AICOM2\|') {
            $series++
            if ($series -le 300) { "NEW|$Tag|series|$line" } else { $dropped++ }
        }
    }
    "K|${Tag}Mark=$($r.nextMark)|${Tag}NewLines=$($lines.Count)|${Tag}NewErrors=$errors|${Tag}NewEvents=$events|${Tag}NewSeries=$series|${Tag}Dropped=$dropped|${Tag}GapBytes=$($r.truncated)|${Tag}Reset=$($r.reset)"
}
Emit-New 'srv' $SrvRpt $SrvFrom $srv
Emit-New 'hc1' $Hc1Rpt $Hc1From $hc1
Emit-New 'hc2' $Hc2Rpt $Hc2From $hc2
'K|collectorStatus=ok'
