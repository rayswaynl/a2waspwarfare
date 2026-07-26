# 02-Install-Apps.ps1 - install Steam + Sandboxie-Plus (idempotent)
# PowerShell 5.1 compatible. Run elevated.
$ErrorActionPreference = 'Stop'

$steamExe = 'C:\Program Files (x86)\Steam\steam.exe'
$sbieExe  = 'C:\Program Files\Sandboxie-Plus\Start.exe'

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Install-ViaWinget {
    Param([String]$PkgId, [String]$Name)
    # Windows Server 2022 ships WITHOUT winget - the direct-download path below is the
    # normal route here, not an exotic fallback.
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($null -eq $winget) { return $false }
    Write-Host ("Installing {0} via winget..." -f $Name)
    winget install --id $PkgId --exact --accept-package-agreements --accept-source-agreements --silent
    if ($LASTEXITCODE -ne 0) { Write-Warning ("winget exited {0} for {1}." -f $LASTEXITCODE, $Name); return $false }
    return $true
}

function Install-FromUrl {
    Param([String]$Url, [String]$FileName, [String]$SilentArgs, [String]$Name)
    $dl = Join-Path $env:TEMP $FileName
    Write-Host ("Downloading {0} from {1}" -f $Name, $Url)
    Invoke-WebRequest -Uri $Url -OutFile $dl -UseBasicParsing
    if (-not (Test-Path $dl)) { throw ("download failed: {0}" -f $Name) }
    Write-Host ("Installing {0} silently ({1})..." -f $Name, $SilentArgs)
    $p = Start-Process -FilePath $dl -ArgumentList $SilentArgs -Wait -PassThru
    Write-Host ("{0} installer exit code: {1}" -f $Name, $p.ExitCode)
    Remove-Item $dl -ErrorAction SilentlyContinue
}

if (Test-Path $steamExe) {
    Write-Host 'OK: Steam already installed.'
} else {
    if (-not (Install-ViaWinget -PkgId 'Valve.Steam' -Name 'Steam')) {
        # Official Valve CDN installer, NSIS silent switch.
        Install-FromUrl -Url 'https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe' `
            -FileName 'SteamSetup.exe' -SilentArgs '/S' -Name 'Steam'
    }
}

if (Test-Path $sbieExe) {
    Write-Host 'OK: Sandboxie-Plus already installed.'
} else {
    if (-not (Install-ViaWinget -PkgId 'Sandboxie.Plus' -Name 'Sandboxie-Plus')) {
        # Resolve the current x64 installer from the official project's release feed
        # rather than pinning a version that goes stale.
        $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/sandboxie-plus/Sandboxie/releases/latest' `
            -UseBasicParsing -Headers @{ 'User-Agent' = 'wasp-provision' }
        $asset = $rel.assets | Where-Object { $_.name -match '^Sandboxie-Plus-x64-v.*\.exe$' } | Select-Object -First 1
        if ($null -eq $asset) { throw 'no Sandboxie-Plus x64 installer asset found in the latest release' }
        # Inno Setup installer, NOT NSIS: '/S' is silently ignored and the GUI wizard opens.
        # Under a service/SSH session nothing can dismiss it and the process hangs forever.
        Install-FromUrl -Url $asset.browser_download_url -FileName $asset.name `
            -SilentArgs '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART' -Name ('Sandboxie-Plus ' + $rel.tag_name)
    }
}

# Post-check (PATH may lag after winget - check files, not commands)
$ok = $true
if (-not (Test-Path $steamExe)) { Write-Warning 'Steam not found at expected path yet.'; $ok = $false }
if (-not (Test-Path $sbieExe))  { Write-Warning 'Sandboxie-Plus Start.exe not found at expected path yet.'; $ok = $false }
if ($ok) { Write-Host 'DONE 02-Install-Apps' } else { Write-Warning '02-Install-Apps finished with warnings - resolve before step 4.' }
