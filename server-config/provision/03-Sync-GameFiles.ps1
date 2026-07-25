# 03-Sync-GameFiles.ps1 - pull game install + C:\WASP from the old box over scp
# PowerShell 5.1 compatible. Requires Windows OpenSSH client (in-box on Server 2019+).
# The old box must run sshd and the given user must read the source paths.
# Resumable at directory granularity: re-run and finished trees are skipped by size check.
Param(
    [Parameter(Mandatory = $true)][String]$SourceHost,
    [Parameter(Mandatory = $true)][String]$SourceUser,
    [String]$SourceGameDir = 'C:/Program Files (x86)/Steam/steamapps/common/Arma 2 Operation Arrowhead',
    [String]$SourceA2Dir   = 'C:/Program Files (x86)/Steam/steamapps/common/Arma 2',
    [String]$SourceWaspDir = 'C:/WASP',
    [String]$DestGameDir   = 'C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead',
    [String]$DestA2Dir     = 'C:\Program Files (x86)\Steam\steamapps\common\Arma 2',
    [String]$DestWaspDir   = 'C:\WASP'
)
$ErrorActionPreference = 'Stop'

$scp = Get-Command scp -ErrorAction SilentlyContinue
if ($null -eq $scp) { throw 'scp not found - install the OpenSSH client Windows capability first.' }

function Get-RemoteTreeSize {
    Param([String]$RemotePath)
    # Windows-target ssh: remote default shell may be cmd, so invoke powershell explicitly.
    $psCmd = "powershell -NoProfile -Command `"(Get-ChildItem -LiteralPath '$RemotePath' -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum`""
    $out = & ssh ("{0}@{1}" -f $SourceUser, $SourceHost) $psCmd 2>$null
    if ($LASTEXITCODE -ne 0) { return -1 }
    $n = 0L
    if ([Int64]::TryParse((($out | Select-Object -Last 1) -replace '\s', ''), [ref]$n)) { return $n }
    return -1
}

function Sync-Tree {
    Param([String]$Src, [String]$Dst, [String]$Label)
    Write-Host ("== Sync {0} ==" -f $Label)
    # Real completeness check: compare local vs remote tree size (>=98% = done).
    # A magic-number threshold would silently accept an interrupted transfer.
    if (Test-Path $Dst) {
        $localSize = (Get-ChildItem -LiteralPath $Dst -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        if ($null -eq $localSize) { $localSize = 0 }
        $remoteSize = Get-RemoteTreeSize -RemotePath $Src
        if ($remoteSize -gt 0 -and $localSize -ge ($remoteSize * 0.98)) {
            Write-Host ("SKIP: {0} complete ({1:N1} GB local vs {2:N1} GB remote)." -f $Dst, ($localSize / 1GB), ($remoteSize / 1GB))
            return
        }
        if ($remoteSize -lt 0) { Write-Warning 'Remote size query failed - re-syncing to be safe (scp re-copies the whole tree).' }
        else { Write-Host ("INCOMPLETE: {0:N1} GB local vs {1:N1} GB remote - re-syncing." -f ($localSize / 1GB), ($remoteSize / 1GB)) }
    }
    $parent = Split-Path $Dst -Parent
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Force $parent | Out-Null }
    # scp -r creates/fills the top folder under the destination parent. No embedded
    # quote characters: PowerShell auto-quotes the single argument (spaces included),
    # matching the proven Windows-to-Windows scp pattern used elsewhere in this repo.
    & scp -r ("{0}@{1}:{2}" -f $SourceUser, $SourceHost, $Src) $parent
    if ($LASTEXITCODE -ne 0) { throw ("scp failed for {0} (exit {1})" -f $Label, $LASTEXITCODE) }
    Write-Host ("OK: {0}" -f $Label)
}

# Order: WASP dir first (small, config), then game trees (large)
Sync-Tree -Src $SourceWaspDir -Dst $DestWaspDir -Label 'C:\WASP (configs, profiles, missions, launchers)'
Sync-Tree -Src $SourceA2Dir   -Dst $DestA2Dir   -Label 'Arma 2 (base game content)'
Sync-Tree -Src $SourceGameDir -Dst $DestGameDir -Label 'Arma 2 Operation Arrowhead (incl. Dll\ allocators + @mods)'

Write-Host '== Post-sync checks =='
$checks = @(
    @{ P = (Join-Path $DestGameDir 'arma2oaserver.exe');            L = 'dedicated server exe' },
    @{ P = (Join-Path $DestGameDir 'Dll');                          L = 'Dll folder (mimalloc/tbb4malloc_bi)' },
    @{ P = (Join-Path $DestGameDir '@CBA_CO');                      L = '@CBA_CO' },
    @{ P = (Join-Path $DestGameDir '@adwasp');                      L = '@adwasp (ASR AI bundle)' },
    @{ P = (Join-Path $DestGameDir '@admkswf');                     L = '@admkswf' },
    @{ P = (Join-Path $DestWaspDir 'profiles-pr8\server-pr8.cfg');  L = 'server-pr8.cfg' },
    @{ P = (Join-Path $DestWaspDir 'profiles-pr8\basic.cfg');       L = 'basic.cfg' },
    @{ P = (Join-Path $DestWaspDir 'hc-profile\hc-video.cfg');      L = 'hc-video.cfg' }
)
$fail = 0
foreach ($c in $checks) {
    if (Test-Path $c.P) { Write-Host ("OK: {0}" -f $c.L) }
    else { Write-Warning ("MISSING: {0} ({1})" -f $c.L, $c.P); $fail++ }
}
Write-Host 'REMINDER: overwrite C:\WASP config/launchers with the repo server-config/ versions'
Write-Host '(4-HC config from PR #1456) and re-set passwordAdmin on the box copy by hand.'
if ($fail -eq 0) { Write-Host 'DONE 03-Sync-GameFiles' } else { Write-Warning ("03-Sync-GameFiles finished with {0} missing item(s)." -f $fail) }
