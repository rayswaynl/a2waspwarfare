#Requires -Version 5
<#
.SYNOPSIS
  Build-AGNOSTIC WASP boot-smoke + regression gate. READ-ONLY.

.DESCRIPTION
  Windows a server RPT to the last MISSINIT (via Get-WindowedRpt.ps1) and asserts the
  invariants the mission emits for free on every boot -- catching the "fixed-in-source but
  shipped-un-deployed / booted-wrong" failure class before it reaches live. Unlike the
  per-release brief2_verify.ps1, this asserts nothing build-specific.

  Checks (each PASS / FAIL / SKIP; SKIP = token not present yet, e.g. a fresh boot):
    MISSINIT        - mission actually initialised (>=1 MISSINIT in the window)
    SELFTEST        - SELFTEST|v1 config echo present (init ran); optional value match
    SIMGATING       - every ROUNDSTAT|v1 has simGating=0 (owner-rejected gating stayed off)
    DELEGATION      - DELEGSTAT|v1 shows teams delegated to the HCs (remote>0, remotePct>=min);
                      no DELEGATION-DEAD tripwire  [catches the "founded 0 teams" regression]
    HCSEAT          - HCSIDE|v1|reseat sideNow=CIV for >= ExpectHcCount HCs, and NO HC seated
                      into a player side (the "lobby seat magnet")  [HC-slotting check]
    WASPSTAT_SEQ    - WASPSTAT|v1|<seq> sequence is gap-free (no dropped stat events)
    ERRORS          - error lines in the window under MaxErrors

  Exit 0 = all REQUIRED checks PASS (SKIP is not a failure). Exit 1 = any required FAIL.

.PARAMETER ServerRpt   Path to the server RPT (arma2oaserver.RPT).
.PARAMETER HcRpt       Optional HC RPT (reserved for behavioural checks; not required here).
.PARAMETER ConfigPath  Optional JSON overriding the default config (see $DefaultConfig).
.PARAMETER SelfTest    Run the bundled fixture self-test instead of grading a live RPT.
.PARAMETER Json        Emit the result object as JSON (for CI / soak-farm consumption).

.EXAMPLE
  pwsh -File Test-WaspBootSmoke.ps1 -ServerRpt C:\WASP\arma2oaserver.RPT
.EXAMPLE
  pwsh -File Test-WaspBootSmoke.ps1 -SelfTest        # CI: prove the gate itself works
#>
[CmdletBinding()]
param(
    [string] $ServerRpt,
    [string] $HcRpt,
    [string] $ConfigPath,
    [switch] $SelfTest,
    [switch] $Json,
    [switch] $Quiet
)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$DefaultConfig = [ordered]@{
    RequireMissinit  = $true
    RequireSelftest  = $true
    SelftestMatch    = ''      # optional regex the SELFTEST line must match (e.g. expected townsMax)
    RequireSimGating = $true   # ROUNDSTAT present -> simGating must be 0 (else SKIP if no round yet)
    RequireDelegation= $true
    MinRemotePct     = 50
    RequireHcSeat    = $true
    ExpectHcCount    = 2
    HcSeatSide       = 'CIV'
    RequireWaspSeq   = $true
    MaxErrors        = 40
}

# ---------------------------------------------------------------------------
# PURE CHECK CORE: operates on an array of server-RPT lines + a config hashtable.
# No file / IO here, so -SelfTest can feed it fixture and mutated-fixture lines.
# ---------------------------------------------------------------------------
function Invoke-BootSmokeChecks {
    param([string[]] $Lines, $Cfg)
    $R = New-Object System.Collections.ArrayList
    function Add-Res($name, $status, $detail) { [void]$R.Add([pscustomobject]@{ check = $name; status = $status; detail = $detail }) }
    $L = @($Lines)

    # MISSINIT
    $mi = @($L | Where-Object { $_ -match 'MISSINIT' })
    if ($Cfg.RequireMissinit) {
        if ($mi.Count -ge 1) { Add-Res 'MISSINIT' 'PASS' "$($mi.Count) marker(s)" }
        else { Add-Res 'MISSINIT' 'FAIL' 'no MISSINIT in window - mission did not initialise' }
    }

    # SELFTEST config echo
    $st = @($L | Where-Object { $_ -match 'SELFTEST\|v1\|' })
    if ($Cfg.RequireSelftest) {
        if ($st.Count -lt 1) { Add-Res 'SELFTEST' 'FAIL' 'no SELFTEST|v1 config echo - init did not complete' }
        elseif ($Cfg.SelftestMatch -and -not ($st | Where-Object { $_ -match $Cfg.SelftestMatch })) {
            Add-Res 'SELFTEST' 'FAIL' "SELFTEST present but did not match /$($Cfg.SelftestMatch)/"
        } else { Add-Res 'SELFTEST' 'PASS' ($st[-1] -replace '^.*SELFTEST', 'SELFTEST') }
    }

    # SIMGATING: every ROUNDSTAT must report simGating=0
    if ($Cfg.RequireSimGating) {
        $rs = @($L | Where-Object { $_ -match 'ROUNDSTAT\|v1\|' })
        if ($rs.Count -lt 1) { Add-Res 'SIMGATING' 'SKIP' 'no ROUNDSTAT yet (no round ended)' }
        else {
            $bad = @($rs | Where-Object { $_ -match 'simGating=(\d+)' -and [int]$Matches[1] -ne 0 })
            if ($bad.Count -eq 0) { Add-Res 'SIMGATING' 'PASS' "$($rs.Count) ROUNDSTAT, simGating=0" }
            else { Add-Res 'SIMGATING' 'FAIL' "simGating!=0 in $($bad.Count) ROUNDSTAT line(s) - owner-rejected gating active" }
        }
    }

    # DELEGATION: teams delegated to the HCs
    if ($Cfg.RequireDelegation) {
        $dead = @($L | Where-Object { $_ -match 'DELEGATION[- ]?DEAD' })
        $ds = @($L | Where-Object { $_ -match 'DELEGSTAT\|v1\|total=(\d+)\|srvLocal=(\d+)\|remote=(\d+)' })
        if ($dead.Count -gt 0) { Add-Res 'DELEGATION' 'FAIL' 'DELEGATION-DEAD tripwire fired' }
        elseif ($ds.Count -lt 1) { Add-Res 'DELEGATION' 'SKIP' 'no DELEGSTAT yet' }
        else {
            $null = $ds[-1] -match 'total=(\d+)\|srvLocal=(\d+)\|remote=(\d+)'
            $tot = [int]$Matches[1]; $rem = [int]$Matches[3]
            $pct = if ($tot -gt 0) { [int](100 * $rem / $tot) } else { 0 }
            if ($rem -le 0) { Add-Res 'DELEGATION' 'FAIL' "remote=0 of total=$tot - AI teams NOT delegated to HCs (founded-0-teams class)" }
            elseif ($pct -lt $Cfg.MinRemotePct) { Add-Res 'DELEGATION' 'FAIL' "remotePct=$pct% < min $($Cfg.MinRemotePct)% (total=$tot remote=$rem)" }
            else { Add-Res 'DELEGATION' 'PASS' "remotePct=$pct% (total=$tot remote=$rem)" }
        }
    }

    # HCSEAT: both HCs seated to CIV, none grabbed a player side
    if ($Cfg.RequireHcSeat) {
        $seat = @($L | Where-Object { $_ -match 'HCSIDE\|v1\|reseat\|.*sideNow=' })
        if ($seat.Count -lt 1) { Add-Res 'HCSEAT' 'SKIP' 'no HCSIDE reseat lines yet' }
        else {
            $good = @($seat | Where-Object { $_ -match "sideNow=$($Cfg.HcSeatSide)\b" })
            $magnet = @($seat | Where-Object { $_ -notmatch "sideNow=$($Cfg.HcSeatSide)\b" })
            if ($magnet.Count -gt 0) {
                $sides = ($magnet | ForEach-Object { if ($_ -match 'sideNow=(\w+)') { $Matches[1] } }) -join ','
                Add-Res 'HCSEAT' 'FAIL' "HC seated into a player side ($sides) - lobby seat-magnet"
            }
            elseif ($good.Count -lt $Cfg.ExpectHcCount) {
                Add-Res 'HCSEAT' 'FAIL' "only $($good.Count)/$($Cfg.ExpectHcCount) HC(s) seated to $($Cfg.HcSeatSide)"
            }
            else { Add-Res 'HCSEAT' 'PASS' "$($good.Count) HC(s) seated to $($Cfg.HcSeatSide)" }
        }
    }

    # WASPSTAT sequence gap-free
    if ($Cfg.RequireWaspSeq) {
        $seqs = @($L | ForEach-Object { if ($_ -match 'WASPSTAT\|v1\|(\d+)\|') { [int]$Matches[1] } })
        if ($seqs.Count -lt 2) { Add-Res 'WASPSTAT_SEQ' 'SKIP' "only $($seqs.Count) WASPSTAT line(s)" }
        else {
            $u = @($seqs | Sort-Object -Unique)
            $span = ($u[-1] - $u[0] + 1)
            if ($span -eq $u.Count) { Add-Res 'WASPSTAT_SEQ' 'PASS' "seq $($u[0])..$($u[-1]) contiguous ($($u.Count))" }
            else { Add-Res 'WASPSTAT_SEQ' 'FAIL' "seq gap: span=$span but $($u.Count) distinct ($($u[0])..$($u[-1]))" }
        }
    }

    # ERRORS
    $errs = @($L | Where-Object { $_ -match 'Error in expression|Generic error|Error position|Undefined variable|Suspending not allowed' })
    if ($errs.Count -le $Cfg.MaxErrors) { Add-Res 'ERRORS' 'PASS' "$($errs.Count) error line(s) (<= $($Cfg.MaxErrors))" }
    else { Add-Res 'ERRORS' 'FAIL' "$($errs.Count) error line(s) > max $($Cfg.MaxErrors)" }

    return $R.ToArray()
}

function Get-Config {
    $c = [ordered]@{}; foreach ($k in $DefaultConfig.Keys) { $c[$k] = $DefaultConfig[$k] }
    if ($ConfigPath) {
        if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Config not found: $ConfigPath" }
        $o = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
        foreach ($p in $o.PSObject.Properties) { $c[$p.Name] = $p.Value }
    }
    return $c
}

function Write-Scorecard($results, $verdict) {
    if ($Quiet) { return }
    Write-Host "=================================================================="
    Write-Host " WASP boot-smoke gate  |  verdict: $verdict"
    Write-Host "=================================================================="
    foreach ($r in $results) {
        $c = switch ($r.status) { 'PASS' { 'Green' } 'FAIL' { 'Red' } default { 'Yellow' } }
        Write-Host ("  {0,-13} {1,-4}  {2}" -f $r.check, $r.status, $r.detail) -ForegroundColor $c
    }
}

# ---------------------------------------------------------------------------
# SELF-TEST: prove the gate returns the right verdicts on fixtures.
# ---------------------------------------------------------------------------
function Invoke-SelfTest {
    $cfg = Get-Config
    $fx = Join-Path $here 'fixtures\boot_pass.server.rpt'
    if (-not (Test-Path -LiteralPath $fx)) { throw "PASS fixture missing: $fx" }
    $pass = Get-Content -LiteralPath $fx
    $fails = 0
    function Expect($label, $cond) {
        if ($cond) { Write-Host "  [ok]   $label" -ForegroundColor Green }
        else { Write-Host "  [FAIL] $label" -ForegroundColor Red; $script:__stFail++ }
    }
    $script:__stFail = 0
    Write-Host "--- boot-smoke gate self-test ---"

    # 1) PASS fixture: no required FAILs
    $r = Invoke-BootSmokeChecks -Lines $pass -Cfg $cfg
    Expect "PASS fixture -> no FAIL checks" (@($r | Where-Object { $_.status -eq 'FAIL' }).Count -eq 0)
    Expect "PASS fixture -> HCSEAT PASS"    ((($r | Where-Object { $_.check -eq 'HCSEAT' }).status) -eq 'PASS')
    Expect "PASS fixture -> DELEGATION PASS" ((($r | Where-Object { $_.check -eq 'DELEGATION' }).status) -eq 'PASS')

    # 2) each FAIL mutation trips exactly its own check
    $mut = @(
        @{ n='SIMGATING';    f={ $pass -replace 'simGating=0','simGating=1' } },
        @{ n='DELEGATION';   f={ $pass -replace 'remote=12','remote=0' } },
        @{ n='HCSEAT';       f={ $pass -replace 'sideNow=CIV','sideNow=WEST' } },
        @{ n='WASPSTAT_SEQ'; f={ $pass -replace 'WASPSTAT\|v1\|2\|','WASPSTAT|v1|4|' } },
        @{ n='SELFTEST';     f={ @($pass | Where-Object { $_ -notmatch 'SELFTEST' }) } },
        @{ n='MISSINIT';     f={ @($pass | Where-Object { $_ -notmatch 'MISSINIT' }) } }
    )
    foreach ($m in $mut) {
        $lines = & $m.f
        $rr = Invoke-BootSmokeChecks -Lines $lines -Cfg $cfg
        $got = ($rr | Where-Object { $_.check -eq $m.n }).status
        Expect "mutate -> $($m.n) FAIL" ($got -eq 'FAIL')
    }

    # 3) DELEGATION-DEAD tripwire
    $rr = Invoke-BootSmokeChecks -Lines (@($pass) + 'x DELEGATION-DEAD x') -Cfg $cfg
    Expect "DELEGATION-DEAD tripwire -> FAIL" ((($rr | Where-Object { $_.check -eq 'DELEGATION' }).status) -eq 'FAIL')

    if ($script:__stFail -eq 0) { Write-Host "SELFTEST: PASS" -ForegroundColor Green; return 0 }
    else { Write-Host "SELFTEST: FAIL ($script:__stFail)" -ForegroundColor Red; return 1 }
}

# ---------------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------------
if ($SelfTest) { exit (Invoke-SelfTest) }

if (-not $ServerRpt) { throw "Provide -ServerRpt <path> (or -SelfTest)." }
. (Join-Path $here '..\Monitor\Get-WindowedRpt.ps1')
$cfg = Get-Config
$srv = Get-WindowedRpt -RptPath $ServerRpt
$results = Invoke-BootSmokeChecks -Lines $srv -Cfg $cfg
$verdict = if (@($results | Where-Object { $_.status -eq 'FAIL' }).Count -gt 0) { 'FAIL' } else { 'PASS' }
Write-Scorecard $results $verdict
if ($Json) { [pscustomobject]@{ verdict = $verdict; windowLines = $srv.Count; checks = $results } | ConvertTo-Json -Depth 5 }
exit ([int]($verdict -eq 'FAIL'))
