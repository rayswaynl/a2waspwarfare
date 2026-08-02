Param(
    [ValidateRange(1, 4)][Int]$HcCount = 4,
    [switch]$SelfTest
)
$oa = 'C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead'
$script:pass = 0
$script:fail = 0
function C {
    Param([bool]$Ok, [string]$Label, [string]$Detail = '')
    if ($Ok) { Write-Output "OK   $Label"; $script:pass++ }
    else { Write-Output ("MISS {0} {1}" -f $Label, $Detail); $script:fail++ }
}
# Mission filenames contain [ and ], which Test-Path treats as WILDCARDS - a plain
# Test-Path reports a present PBO as missing. Always -LiteralPath for these.
function TP { Param([string]$Path) return (Test-Path -LiteralPath $Path) }

# A DLL being installed does not prove that the launcher selected it. Keep the
# parser separate so the self-test exercises the same token contract used by
# the readiness checks below.
function Get-MallocTokenFromText {
    Param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return '' }
    # Parse active command text only: REM/::/# lines are comments, and a
    # quoted note/argument is not an allocator switch for cmd.exe to execute.
    $activeLines = @($Text -split "`r?`n" | Where-Object { $_ -notmatch '^\s*(?:REM\b|::|#)' })
    $unquotedLines = @($activeLines | ForEach-Object { [regex]::Replace($_, '"(?:[^"]|"")*"', ' ') })
    $activeText = $unquotedLines -join "`n"
    $hits = [regex]::Matches($activeText, '(?im)(?:^|\s)-malloc=([^\s"\r\n]+)(?=\s|$)')
    if ($hits.Count -ne 1) { return '' }
    return $hits[0].Groups[1].Value
}
function Get-MallocToken {
    Param([string]$Path)
    if (-not (TP $Path)) { return '' }
    try { return Get-MallocTokenFromText (Get-Content -LiteralPath $Path -Raw) } catch { return '' }
}
function Check-Malloc {
    Param([string]$Path, [string]$Expected, [string]$Label)
    $actual = Get-MallocToken $Path
    $detail = if ([string]::IsNullOrEmpty($actual)) { '(missing or ambiguous -malloc= token)' } else { "(found -malloc=$actual)" }
    C ($actual -eq $Expected) $Label $detail
}

if ($SelfTest) {
    $cases = @(
        @{ Text = 'server -malloc=mimalloc'; Expected = 'mimalloc'; Label = 'server allocator' },
        @{ Text = 'hc -malloc=tbb4malloc_bi -maxMem=2047'; Expected = 'tbb4malloc_bi'; Label = 'HC allocator' },
        @{ Text = 'server -malloc=system'; Expected = 'system'; Label = 'system allocator' },
        @{ Text = 'server command line'; Expected = ''; Label = 'missing allocator' },
        @{ Text = 'server -malloc=system -malloc=mimalloc'; Expected = ''; Label = 'ambiguous allocator' },
        @{ Text = 'REM -malloc=system'; Expected = ''; Label = 'REM comment' },
        @{ Text = 'server "-note=foo -malloc=system" -malloc=mimalloc'; Expected = 'mimalloc'; Label = 'quoted text' }
    )
    foreach ($case in $cases) {
        $actual = Get-MallocTokenFromText $case.Text
        C ($actual -eq $case.Expected) ("allocator parser: {0}" -f $case.Label) ("expected '{0}', found '{1}'" -f $case.Expected, $actual)
    }
    if ($script:fail -gt 0) { Write-Output ("SELFTEST: FAIL ({0})" -f $script:fail); exit 1 }
    Write-Output 'SELFTEST: PASS'
    exit 0
}

C (Test-Path (Join-Path $oa 'arma2oaserver.exe')) 'dedicated server exe'
C (Test-Path (Join-Path $oa 'Dll\mimalloc.dll')) 'mimalloc (server allocator)'
C (Test-Path (Join-Path $oa 'Dll\tbb4malloc_bi.dll')) 'tbb4malloc_bi (HC allocator)'
foreach ($m in @('@CBA_CO', '@adwasp', '@admkswf')) { C (Test-Path (Join-Path $oa $m)) "mod $m" }
C (TP (Join-Path $oa 'MPMissions\[61-2hc]warfarev2_073v48co_wave0725c4hc.zargabad.pbo')) 'soak mission PBO (zargabad 4hc)'
C (Test-Path 'C:\WASP\profiles-pr8\server-pr8.cfg') 'server config'
C (Test-Path 'C:\WASP\profiles-pr8\basic.cfg') 'basic.cfg (network tuning)'
C (Test-Path 'C:\WASP\hc-profile\hc-video.cfg') 'hc-video.cfg'
# Only the launchers for the configured HC count are required (HC1 = hc_launch.cmd).
$launchers = @('server_launch.cmd', 'hc_launch.cmd')
foreach ($n in 2..4) { if ($n -le $HcCount) { $launchers += ('hc{0}_launch.cmd' -f $n) } }
foreach ($l in $launchers) {
    C (Test-Path (Join-Path 'C:\WASP' $l)) "launcher $l"
}
$serverLauncher = Join-Path 'C:\WASP' 'server_launch.cmd'
Check-Malloc $serverLauncher 'mimalloc' 'server launcher allocator'
for ($i = 1; $i -lt $launchers.Count; $i++) {
    Check-Malloc (Join-Path 'C:\WASP' $launchers[$i]) 'tbb4malloc_bi' ("HC launcher {0} allocator" -f $launchers[$i])
}
C (Test-Path 'C:\Program Files (x86)\Steam\steam.exe') 'Steam'
# Sandboxie (and the HC2..HCN boxes) are only needed when more than one HC runs.
if ($HcCount -ge 2) {
    C (Test-Path 'C:\Program Files\Sandboxie-Plus\Start.exe') 'Sandboxie-Plus'
    foreach ($n in 2..$HcCount) {
        $b = ('HC{0}' -f $n)
        C ([bool](Select-String -LiteralPath 'C:\Windows\Sandboxie.ini' -Pattern ("^\[" + $b + "\]") -Quiet)) "sandbox [$b]"
    }
}
C (Test-Path 'C:\WASP\provision\Login-Steams.cmd') 'Login-Steams.cmd (your step)'

$mg = Select-String -LiteralPath 'C:\WASP\profiles-pr8\basic.cfg' -Pattern 'MaxSizeGuaranteed'
if ($mg) { Write-Output ("JIP fix line: " + $mg.Line.Trim()) } else { Write-Output 'JIP fix line: MISSING (MaxSizeGuaranteed)' }
Write-Output ''
Write-Output ("READY: {0} ok, {1} missing" -f $script:pass, $script:fail)
