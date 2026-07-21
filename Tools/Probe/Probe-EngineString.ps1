#Requires -Version 5
<#
.SYNOPSIS
  Offline A2 OA engine-token probe. READ-ONLY. Answers "does this build's parser know
  <token>?" without booting a server.

.DESCRIPTION
  Rung 4 of the a2oa-verify-command ladder, static variant. Most SQF/mission documentation
  online is Arma 3 and will happily describe an attribute this engine never reads, so an
  in-source comment or a wiki page is a lead, not proof. A mission.sqm attribute name (or a
  scripting command name) must exist as a literal string inside the binary that parses it;
  if a token is absent from every engine binary, it cannot be read and is silently ignored.

  Controls are mandatory and built in: tokens we KNOW this engine honours must come back
  PRESENT, and an Arma-3-only token must come back ABSENT. Without them a PRESENT result on
  a 13 MB file proves nothing.

  This settles EXISTENCE only. Runtime behaviour (does the engine act on it, and when) still
  needs a boot -- for forceHeadlessClient specifically, see
  docs/design/HC-CIV-SLOT-VERIFICATION-20260721.md section 2, which grades it from the
  HCSIDE|v1|preseat telemetry the mission already emits.

.PARAMETER GameRoot
  Arma 2 OA install directory. Auto-detected from the Bohemia Interactive registry keys when
  omitted, so no machine-specific path is committed.

.PARAMETER Token
  Extra token(s) to probe, on top of the built-in target and controls.

.PARAMETER Context
  Also dump the NUL-delimited string neighbourhood around each hit. The neighbourhood is the
  real evidence: it shows WHICH parse table a token lives in.

.EXAMPLE
  pwsh -File Tools\Probe\Probe-EngineString.ps1
.EXAMPLE
  pwsh -File Tools\Probe\Probe-EngineString.ps1 -Token 'forceInServer','presenceCondition' -Context
#>
[CmdletBinding()]
param(
    [string]   $GameRoot,
    [string[]] $Token = @(),
    [switch]   $Context
)
$ErrorActionPreference = 'Stop'

function Resolve-GameRoot {
    if ($GameRoot) {
        if (-not (Test-Path -LiteralPath $GameRoot)) { throw "GameRoot not found: $GameRoot" }
        return $GameRoot
    }
    foreach ($key in @('HKLM:\SOFTWARE\WOW6432Node\Bohemia Interactive\ArmA 2 OA',
                       'HKLM:\SOFTWARE\Bohemia Interactive\ArmA 2 OA',
                       'HKLM:\SOFTWARE\WOW6432Node\Bohemia Interactive Studio\ArmA 2 OA',
                       'HKLM:\SOFTWARE\WOW6432Node\Bohemia Interactive\arma 2 baf')) {
        try {
            $v = (Get-ItemProperty -LiteralPath $key -ErrorAction Stop).main
            if ($v -and (Test-Path -LiteralPath $v)) { return $v }
        } catch { }
    }
    throw "Could not auto-detect the Arma 2 OA install. Pass -GameRoot <path>."
}

# Built-in probe set. Controls are not optional -- they are what makes a verdict meaningful.
$targets = @(
    [pscustomobject]@{ Name = 'forceHeadlessClient'; Role = 'target ' }
    [pscustomobject]@{ Name = 'disabledAI';          Role = 'control+' }   # mission.sqm attr this engine honours
    [pscustomobject]@{ Name = 'synchronizations';    Role = 'control+' }   # mission.sqm attr this engine honours
    [pscustomobject]@{ Name = 'descriptionShort';    Role = 'control+' }   # mission.sqm attr this engine honours
    [pscustomobject]@{ Name = 'isPlayable';          Role = 'control-' }   # Arma 3 only: MUST be ABSENT
    [pscustomobject]@{ Name = 'headlessClient';      Role = 'related ' }
)
foreach ($t in $Token) { $targets += [pscustomobject]@{ Name = $t; Role = 'extra  ' } }

$root = Resolve-GameRoot
$exes = @('ArmA2OA.exe', 'arma2oaserver.exe') |
    ForEach-Object { Join-Path $root $_ } |
    Where-Object { Test-Path -LiteralPath $_ }
if ($exes.Count -eq 0) { throw "No A2 OA executables under: $root" }

$controlsOk = $true
foreach ($exe in $exes) {
    $bytes = [System.IO.File]::ReadAllBytes($exe)
    # Latin1 is a 1:1 byte<->char map, so ASCII literals survive and offsets stay true.
    $text = [System.Text.Encoding]::GetEncoding(28591).GetString($bytes)
    $ver = (Get-Item -LiteralPath $exe).VersionInfo.ProductVersion

    Write-Host ""
    Write-Host ("=== {0}  (ProductVersion {1}, {2:N0} bytes) ===" -f (Split-Path -Leaf $exe), $ver, $bytes.Length)

    foreach ($t in $targets) {
        $first = $text.IndexOf($t.Name, [System.StringComparison]::Ordinal)
        $hits = 0
        $i = $first
        while ($i -ge 0 -and $hits -lt 50) {
            $hits++
            $i = $text.IndexOf($t.Name, $i + $t.Name.Length, [System.StringComparison]::Ordinal)
        }
        $verdict = if ($hits -gt 0) { 'PRESENT' } else { 'ABSENT ' }

        if ($t.Role -eq 'control+' -and $hits -eq 0) { $controlsOk = $false }
        if ($t.Role -eq 'control-' -and $hits -gt 0) { $controlsOk = $false }

        if ($first -ge 0) {
            Write-Host ("XWT|enginestr|{0}|{1}|{2}|hits={3}|firstOffset=0x{4:X}" -f $verdict, $t.Role.Trim(), $t.Name, $hits, $first)
        } else {
            Write-Host ("XWT|enginestr|{0}|{1}|{2}|hits=0" -f $verdict, $t.Role.Trim(), $t.Name)
        }

        if ($Context -and $first -ge 0) {
            $start = [Math]::Max(0, $first - 300)
            $len = [Math]::Min(620, $text.Length - $start)
            $toks = $text.Substring($start, $len).Split([char]0) |
                Where-Object { $_.Length -ge 4 -and $_ -cmatch '^[\x20-\x7E]+$' }
            Write-Host ("    neighbourhood: " + ($toks -join '  |  '))
        }
    }
}

Write-Host ""
if ($controlsOk) {
    Write-Host "CONTROLS OK - PRESENT/ABSENT verdicts above are meaningful." -ForegroundColor Green
    exit 0
}
Write-Host "CONTROLS FAILED - the scan did not discriminate; treat every verdict above as void." -ForegroundColor Red
exit 1
