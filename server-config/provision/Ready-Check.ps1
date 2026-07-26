Param(
    [ValidateRange(1, 4)][Int]$HcCount = 4
)
$oa = 'C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead'
$script:pass = 0
$script:fail = 0
function C {
    Param([bool]$Ok, [string]$Label)
    if ($Ok) { Write-Output "OK   $Label"; $script:pass++ }
    else { Write-Output "MISS $Label"; $script:fail++ }
}
# Mission filenames contain [ and ], which Test-Path treats as WILDCARDS - a plain
# Test-Path reports a present PBO as missing. Always -LiteralPath for these.
function TP { Param([string]$Path) return (Test-Path -LiteralPath $Path) }

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
