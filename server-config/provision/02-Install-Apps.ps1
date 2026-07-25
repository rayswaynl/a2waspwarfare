# 02-Install-Apps.ps1 - install Steam + Sandboxie-Plus (idempotent)
# PowerShell 5.1 compatible. Run elevated.
$ErrorActionPreference = 'Stop'

$steamExe = 'C:\Program Files (x86)\Steam\steam.exe'
$sbieExe  = 'C:\Program Files\Sandboxie-Plus\Start.exe'

function Install-ViaWinget {
    Param([String]$PkgId, [String]$Name)
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($null -eq $winget) {
        Write-Warning ("winget not available - install {0} manually:" -f $Name)
        if ($Name -eq 'Steam') { Write-Host '  https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe' }
        if ($Name -eq 'Sandboxie-Plus') { Write-Host '  https://github.com/sandboxie-plus/Sandboxie/releases (Sandboxie-Plus x64 installer)' }
        return $false
    }
    Write-Host ("Installing {0} via winget..." -f $Name)
    winget install --id $PkgId --exact --accept-package-agreements --accept-source-agreements --silent
    if ($LASTEXITCODE -ne 0) { Write-Warning ("winget exited {0} for {1} - verify manually." -f $LASTEXITCODE, $Name) }
    return $true
}

if (Test-Path $steamExe) { Write-Host 'OK: Steam already installed.' }
else { Install-ViaWinget -PkgId 'Valve.Steam' -Name 'Steam' | Out-Null }

if (Test-Path $sbieExe) { Write-Host 'OK: Sandboxie-Plus already installed.' }
else { Install-ViaWinget -PkgId 'Sandboxie.Plus' -Name 'Sandboxie-Plus' | Out-Null }

# Post-check (PATH may lag after winget - check files, not commands)
$ok = $true
if (-not (Test-Path $steamExe)) { Write-Warning 'Steam not found at expected path yet.'; $ok = $false }
if (-not (Test-Path $sbieExe))  { Write-Warning 'Sandboxie-Plus Start.exe not found at expected path yet.'; $ok = $false }
if ($ok) { Write-Host 'DONE 02-Install-Apps' } else { Write-Warning '02-Install-Apps finished with warnings - resolve before step 4.' }
