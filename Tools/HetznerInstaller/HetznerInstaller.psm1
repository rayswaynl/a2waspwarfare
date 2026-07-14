#requires -Version 5.1
Set-StrictMode -Version 2.0

$script:SchemaVersion = 2
$script:TransactionVersion = 3
$script:TransactionType = 'apply-v3'
$script:ProfilesPath = Join-Path $PSScriptRoot 'profiles.json'

function Get-HetznerAbsolutePath {
    param([Parameter(Mandatory)][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { throw 'Path cannot be empty.' }
    if (-not [System.IO.Path]::IsPathRooted($Path)) { throw "Path must be absolute: $Path" }
    try {
        $full = [System.IO.Path]::GetFullPath($Path)
        $root = [System.IO.Path]::GetPathRoot($full)
        if ($full.Length -gt $root.Length) { $full = $full.TrimEnd('\') }
        return $full
    } catch { throw "Path is invalid: $Path" }
}

function Test-HetznerContainedPath {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Root
    )
    $pathFull = (Get-HetznerAbsolutePath $Path).ToLowerInvariant()
    $rootFull = (Get-HetznerAbsolutePath $Root).ToLowerInvariant()
    if ($pathFull -eq $rootFull) { return $false }
    return $pathFull.StartsWith($rootFull + '\', [System.StringComparison]::Ordinal)
}

function Test-HetznerReparsePoint {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    return (([int]$item.Attributes -band [int][System.IO.FileAttributes]::ReparsePoint) -ne 0)
}

function Assert-HetznerNoReparsePoints {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$FenceRoot
    )
    $full = Get-HetznerAbsolutePath $Path
    $fence = Get-HetznerAbsolutePath $FenceRoot
    if (-not (Test-Path -LiteralPath $fence -PathType Container)) { throw "Fence root not found: $fence" }
    if (-not (Test-HetznerContainedPath -Path $full -Root $fence)) { throw "Path is outside the fence: $full" }
    $current = $full
    while ($true) {
        if (Test-HetznerReparsePoint -Path $current) { throw "Reparse point or junction is forbidden in mutation path: $current" }
        if ($current -eq $fence) { break }
        $parent = Split-Path -Parent $current
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $current) { throw "Could not walk path to fence: $full" }
        $current = Get-HetznerAbsolutePath $parent
    }
    return $full
}

function Assert-HetznerNoReparseTree {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$FenceRoot
    )
    $rootFull = Assert-HetznerNoReparsePoints -Path $Root -FenceRoot $FenceRoot
    if (-not (Test-Path -LiteralPath $rootFull -PathType Container)) { throw "Directory not found: $rootFull" }
    $pending = New-Object 'System.Collections.Generic.Stack[string]'
    $pending.Push($rootFull)
    while ($pending.Count -gt 0) {
        $current = $pending.Pop()
        foreach ($item in @(Get-ChildItem -LiteralPath $current -Force)) {
            Assert-HetznerNoReparsePoints -Path $item.FullName -FenceRoot $FenceRoot | Out-Null
            if ($item.PSIsContainer) { $pending.Push($item.FullName) }
        }
    }
}

function Test-HetznerInstallPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$FenceRoot
    )
    $full = Get-HetznerAbsolutePath $Path
    $fence = Get-HetznerAbsolutePath $FenceRoot
    if ($full -match '^[\\]{2}' -or $fence -match '^[\\]{2}') { throw 'UNC paths are not allowed by the offline installer fence.' }
    if ($full -match '^(?i:[a-z]:\\WASP)(?:\\|$)') { throw "Host runtime path is forbidden: $full" }
    if ($full -match '(?i)(?:^|\\)(?:Windows|Program Files|Program Files \(x86\)|System32)(?:\\|$)') { throw "Protected Windows path is forbidden: $full" }
    $reservedTransactionRoot = Get-HetznerAbsolutePath (Join-Path $fence '.hetzner-installer-transactions')
    if ($full -eq $reservedTransactionRoot -or (Test-HetznerContainedPath -Path $full -Root $reservedTransactionRoot)) { throw 'Install or backup root overlaps the reserved transaction namespace.' }
    Assert-HetznerNoReparsePoints -Path $full -FenceRoot $fence | Out-Null
    return $full
}

function Assert-HetznerPathsDisjoint {
    param(
        [Parameter(Mandatory)][string]$InstallRoot,
        [Parameter(Mandatory)][string]$BackupRoot
    )
    $install = Get-HetznerAbsolutePath $InstallRoot
    $backup = Get-HetznerAbsolutePath $BackupRoot
    if ($install -eq $backup -or (Test-HetznerContainedPath -Path $backup -Root $install) -or (Test-HetznerContainedPath -Path $install -Root $backup)) {
        throw 'Install and backup roots must be fully disjoint; equal, child, and ancestor paths are refused.'
    }
}

function Assert-HetznerSafeProfileString {
    param([Parameter(Mandatory)][string]$Field, [AllowEmptyString()][string]$Value)
    if ($null -eq $Value) { return }
    if ($Value -match '[&|<>^()%!"\r\n]') { throw "Unsafe batch metacharacter in profile field '$Field'." }
}

function Get-HetznerInstallerProfiles {
    [CmdletBinding()]
    param([string]$ProfilesPath = $script:ProfilesPath)
    $path = Get-HetznerAbsolutePath $ProfilesPath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Profiles file not found: $path" }
    $document = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    if ([int]$document.schemaVersion -ne $script:SchemaVersion) { throw 'Unsupported installer profile schema.' }
    $profiles = @($document.profiles)
    if ($profiles.Count -ne 4) { throw 'Installer profile set must contain exactly four profiles.' }
    $seenNames = @{}
    foreach ($profile in $profiles) {
        foreach ($required in @('name','profileId','headlessClients','hcExecutable','hcPortBase','hcModLine','hcAllocator','hcNamePrefix','rptIdentityPrefix','topology','operational')) {
            if (-not ($profile.PSObject.Properties.Name -contains $required)) { throw "Profile field missing: $required" }
        }
        $name = [string]$profile.name
        $profileId = [string]$profile.profileId
        $count = [int]$profile.headlessClients
        if ($seenNames.ContainsKey($name) -or $seenNames.ContainsKey($profileId)) { throw 'Profile names and profile identities must be unique.' }
        $seenNames[$name] = $true
        $seenNames[$profileId] = $true
        if ($name -ne "hc-$count" -or $profileId -ne $name -or $count -lt 0 -or $count -gt 3) { throw "Invalid profile identity or HC count: $name" }
        if ([int]$profile.hcPortBase -ne 2302) { throw "All HC profiles must use server port 2302: $name" }
        foreach ($field in @('name','profileId','hcExecutable','hcModLine','hcAllocator','hcNamePrefix','rptIdentityPrefix','topology')) {
            Assert-HetznerSafeProfileString -Field $field -Value ([string]$profile.$field)
        }
        if ($profile.PSObject.Properties.Name -contains 'steamIsolationAdapter') {
            Assert-HetznerSafeProfileString -Field 'steamIsolationAdapter' -Value ([string]$profile.steamIsolationAdapter)
        }
        if ($count -ge 2 -and [bool]$profile.operational -and [string]::IsNullOrWhiteSpace([string]$profile.steamIsolationAdapter)) {
            throw "HC2/HC3 cannot be operational without an explicit Steam/Sandbox isolation adapter: $name"
        }
    }
    return $profiles
}

function Get-HetznerInstallerProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('hc-0','hc-1','hc-2','hc-3')][string]$Name,
        [string]$ProfilesPath = $script:ProfilesPath
    )
    $profile = @(Get-HetznerInstallerProfiles -ProfilesPath $ProfilesPath | Where-Object { $_.name -eq $Name })
    if ($profile.Count -ne 1) { throw "Installer profile not found: $Name" }
    return $profile[0]
}

function Get-HetznerMissionPboInfo {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$MissionPboPath)
    $path = Get-HetznerAbsolutePath $MissionPboPath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Mission PBO not found: $path" }
    $leaf = [System.IO.Path]::GetFileName($path)
    if ([string]::IsNullOrWhiteSpace($leaf) -or [System.IO.Path]::GetExtension($leaf) -cne '.pbo') { throw "Mission PBO path must be a .pbo leaf: $path" }
    return [pscustomobject]@{
        Path = $path
        Leaf = $leaf
        Sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        Bytes = ([int64](Get-Item -LiteralPath $path).Length)
    }
}

function Test-HetznerPreflight {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SourceRoot,
        [Parameter(Mandatory)][ValidateSet('hc-0','hc-1','hc-2','hc-3')][string]$ProfileName,
        [AllowEmptyString()][string]$MissionPboPath = '',
        [string]$ProfilesPath = $script:ProfilesPath
    )
    $source = Get-HetznerAbsolutePath $SourceRoot
    if (-not (Test-Path -LiteralPath $source -PathType Container)) { throw "Source root not found: $source" }
    $profile = Get-HetznerInstallerProfile -Name $ProfileName -ProfilesPath $ProfilesPath
    $required = @('server-config\basic.cfg', 'server-config\server-pr8.cfg')
    $missing = @($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $source $_) -PathType Leaf) })
    if ($missing.Count -gt 0) { throw "Preflight failed; required source files not found: $($missing -join ', ')" }
    $pbo = $null
    if (-not [string]::IsNullOrWhiteSpace($MissionPboPath)) { $pbo = Get-HetznerMissionPboInfo -MissionPboPath $MissionPboPath }
    return [pscustomobject]@{
        SchemaVersion = $script:SchemaVersion
        SourceRoot = $source
        ProfileName = $ProfileName
        HeadlessClients = [int]$profile.headlessClients
        Operational = [bool]$profile.operational
        Topology = [string]$profile.topology
        SteamIsolationAdapter = [string]$profile.steamIsolationAdapter
        RequiredFiles = $required
        MissionPboPath = if ($pbo) { $pbo.Path } else { '' }
        MissionPboLeaf = if ($pbo) { $pbo.Leaf } else { '' }
        MissionPboSha256 = if ($pbo) { $pbo.Sha256 } else { '' }
        Ready = $true
    }
}

function Get-HetznerExpectedLauncherIdentities {
    param([Parameter(Mandatory)]$Profile, [Parameter(Mandatory)][string]$ProfileName)
    $items = @()
    for ($i = 1; $i -le [int]$Profile.headlessClients; $i++) {
        $name = "HC-AI-Control-$i"
        $items += [pscustomobject]@{ Name = $name; ProfileId = $ProfileName; RptIdentity = "$ProfileName/$name"; Port = 2302 }
    }
    $names = @($items | ForEach-Object { $_.Name })
    $rpt = @($items | ForEach-Object { $_.RptIdentity })
    if (@($names | Select-Object -Unique).Count -ne $names.Count -or @($rpt | Select-Object -Unique).Count -ne $rpt.Count) { throw 'HC name and RPT identity values must be unique.' }
    return @($items)
}

function Get-HetznerExpectedManagedPaths {
    param([Parameter(Mandatory)]$Profile, [Parameter(Mandatory)][string]$MissionPboLeaf)
    $paths = @('profiles-pr8\basic.cfg','profiles-pr8\server-pr8.cfg',("mpmissions\$MissionPboLeaf"))
    for ($i = 1; $i -le [int]$Profile.headlessClients; $i++) { $paths += "hc${i}_launch.cmd" }
    return @($paths)
}

function New-HetznerLauncherContent {
    param(
        [Parameter(Mandatory)]$Profile,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ProfileName,
        [Parameter(Mandatory)][int]$ClientNumber
    )
    $name = "HC-AI-Control-$ClientNumber"
    $rptIdentity = "$ProfileName/$name"
    $adapter = [string]$Profile.steamIsolationAdapter
    if ([string]::IsNullOrWhiteSpace($adapter)) { $adapter = 'REQUIRED-BEFORE-OPERATION' }
    return @"
@echo off
setlocal
rem offline staging foundation; profile=$ProfileName rptIdentity=$rptIdentity topology=$($Profile.topology) isolationAdapter=$adapter operational=$([bool]$Profile.operational)
if not defined ARMA2OA_ROOT (
  echo ARMA2OA_ROOT must be supplied by the target host.
  exit /b 2
)
if not defined WASP_HC_PASSWORD (
  echo WASP_HC_PASSWORD must be supplied by the host secret surface.
  exit /b 3
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& { `$exe = Join-Path `$env:ARMA2OA_ROOT '$($Profile.hcExecutable)'; if (-not (Test-Path -LiteralPath `$exe -PathType Leaf)) { Write-Error 'ARMA2OA_ROOT does not contain the configured executable.'; exit 2 }; `$arguments = @('-client','-connect=127.0.0.1','-port=2302','-name=$name',('-password=' + `$env:WASP_HC_PASSWORD),'-mod=$($Profile.hcModLine)','-malloc=$($Profile.hcAllocator)'); & `$exe @arguments; exit `$LASTEXITCODE }"
exit /b %ERRORLEVEL%
"@
}

function Get-HetznerStringSha256 {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)
    $encoding = New-Object System.Text.UTF8Encoding($false)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return -join ($sha.ComputeHash($encoding.GetBytes($Value)) | ForEach-Object { $_.ToString('x2') })
    } finally {
        $sha.Dispose()
    }
}

function ConvertTo-HetznerUtcTimestamp {
    param([Parameter(Mandatory)]$Value)
    if ($Value -is [datetime]) { return $Value.ToUniversalTime() }
    if ($Value -is [datetimeoffset]) { return $Value.UtcDateTime }
    return [datetime]::Parse([string]$Value, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()
}

function Get-HetznerSourceFileRecords {
    param([Parameter(Mandatory)][string]$SourceRoot)
    $source = Get-HetznerAbsolutePath $SourceRoot
    $records = @()
    foreach ($relative in @('server-config\basic.cfg','server-config\server-pr8.cfg')) {
        $path = Get-HetznerAbsolutePath (Join-Path $source $relative)
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Canonical source config not found: $path" }
        $records += [pscustomobject][ordered]@{
            RelativePath = $relative
            SourcePath = $path
            Sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
            Bytes = [int64](Get-Item -LiteralPath $path).Length
        }
    }
    return @($records)
}

function New-HetznerCanonicalOperations {
    param(
        [Parameter(Mandatory)][string]$SourceRoot,
        [Parameter(Mandatory)][string]$InstallRoot,
        [Parameter(Mandatory)]$Profile,
        [Parameter(Mandatory)][string]$ProfileName,
        [Parameter(Mandatory)]$Pbo
    )
    $source = Get-HetznerAbsolutePath $SourceRoot
    $install = Get-HetznerAbsolutePath $InstallRoot
    $expected = Get-HetznerExpectedManagedPaths -Profile $Profile -MissionPboLeaf $Pbo.Leaf
    $operations = @(
        [pscustomobject]@{ Kind = 'EnsureDirectory'; RelativePath = 'profiles-pr8'; SourcePath = ''; TargetPath = (Join-Path $install 'profiles-pr8') },
        [pscustomobject]@{ Kind = 'EnsureDirectory'; RelativePath = 'mpmissions'; SourcePath = ''; TargetPath = (Join-Path $install 'mpmissions') },
        [pscustomobject]@{ Kind = 'EnsureDirectory'; RelativePath = '.hetzner-installer'; SourcePath = ''; TargetPath = (Join-Path $install '.hetzner-installer') }
    )
    for ($i = 1; $i -le 3; $i++) {
        $launcher = "hc${i}_launch.cmd"
        if ($expected -notcontains $launcher) { $operations += [pscustomobject]@{ Kind = 'DeleteStaleLauncher'; RelativePath = $launcher; SourcePath = ''; TargetPath = (Join-Path $install $launcher) } }
    }
    $operations += [pscustomobject]@{ Kind = 'CopyFile'; RelativePath = 'profiles-pr8\basic.cfg'; SourcePath = (Join-Path $source 'server-config\basic.cfg'); TargetPath = (Join-Path $install 'profiles-pr8\basic.cfg') }
    $operations += [pscustomobject]@{ Kind = 'CopyFile'; RelativePath = 'profiles-pr8\server-pr8.cfg'; SourcePath = (Join-Path $source 'server-config\server-pr8.cfg'); TargetPath = (Join-Path $install 'profiles-pr8\server-pr8.cfg') }
    $operations += [pscustomobject]@{ Kind = 'CopyMissionPbo'; RelativePath = "mpmissions\$($Pbo.Leaf)"; SourcePath = $Pbo.Path; TargetPath = (Join-Path $install "mpmissions\$($Pbo.Leaf)") }
    for ($i = 1; $i -le [int]$Profile.headlessClients; $i++) {
        $name = "hc${i}_launch.cmd"
        $operations += [pscustomobject]@{ Kind = 'GenerateLauncher'; RelativePath = $name; SourcePath = ''; TargetPath = (Join-Path $install $name); Content = (New-HetznerLauncherContent -Profile $Profile -ProfileName $ProfileName -ClientNumber $i) }
    }
    return @($operations)
}

function Get-HetznerOperationDescriptors {
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Operations)
    $descriptors = @()
    $index = 0
    foreach ($operation in @($Operations)) {
        $hasContent = $operation.PSObject.Properties.Name -contains 'Content'
        $content = if ($hasContent) { [string]$operation.Content } else { '' }
        $descriptors += [pscustomobject][ordered]@{
            Index = $index
            Kind = [string]$operation.Kind
            RelativePath = [string]$operation.RelativePath
            SourcePath = [string]$operation.SourcePath
            TargetPath = [string]$operation.TargetPath
            HasContent = $hasContent
            ContentSha256 = if ($hasContent) { Get-HetznerStringSha256 -Value $content } else { '' }
        }
        $index++
    }
    return @($descriptors)
}

function Get-HetznerPlanFingerprint {
    param(
        [Parameter(Mandatory)][string]$SourceRoot,
        [Parameter(Mandatory)][string]$InstallRoot,
        [Parameter(Mandatory)][string]$FenceRoot,
        [Parameter(Mandatory)][string]$ProfileName,
        [Parameter(Mandatory)][string]$MissionPboPath,
        [Parameter(Mandatory)][string]$MissionPboSha256,
        [Parameter(Mandatory)][object[]]$SourceFiles,
        [Parameter(Mandatory)][object[]]$CanonicalOperationDescriptors,
        [AllowEmptyCollection()][object[]]$AdoptionPolicy = @()
    )
    $payload = [ordered]@{
        SchemaVersion = $script:SchemaVersion
        SourceRoot = Get-HetznerAbsolutePath $SourceRoot
        InstallRoot = Get-HetznerAbsolutePath $InstallRoot
        FenceRoot = Get-HetznerAbsolutePath $FenceRoot
        ProfileName = $ProfileName
        MissionPboPath = Get-HetznerAbsolutePath $MissionPboPath
        MissionPboSha256 = $MissionPboSha256
        SourceFiles = @($SourceFiles)
        CanonicalOperationDescriptors = @($CanonicalOperationDescriptors)
        AdoptionPolicy = @($AdoptionPolicy)
    }
    return Get-HetznerStringSha256 -Value ($payload | ConvertTo-Json -Depth 12 -Compress)
}

function Get-HetznerDesiredOperationIdentity {
    param([Parameter(Mandatory)]$Operation)
    if ([string]$Operation.Kind -in @('CopyFile','CopyMissionPbo')) {
        $path = Get-HetznerAbsolutePath ([string]$Operation.SourcePath)
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Adoption source is missing: $($Operation.RelativePath)" }
        return [pscustomobject]@{ Kind='File'; Sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant(); Bytes=[int64](Get-Item -LiteralPath $path).Length }
    }
    if ([string]$Operation.Kind -eq 'GenerateLauncher') {
        $content = [string]$Operation.Content
        $encoding = New-Object System.Text.UTF8Encoding($false)
        return [pscustomobject]@{ Kind='File'; Sha256=(Get-HetznerStringSha256 -Value $content); Bytes=[int64]$encoding.GetByteCount($content) }
    }
    if ([string]$Operation.Kind -eq 'DeleteStaleLauncher') { return [pscustomobject]@{ Kind='Missing'; Sha256=''; Bytes=[int64]0 } }
    throw "Operation does not support per-path adoption: $($Operation.RelativePath)"
}

function Get-HetznerCanonicalAdoptionPolicy {
    param(
        [AllowEmptyCollection()][object[]]$AdoptionPolicy = @(),
        [Parameter(Mandatory)][object[]]$Operations,
        [Parameter(Mandatory)][string]$InstallRoot,
        [Parameter(Mandatory)][string]$FenceRoot
    )
    $records = @(); $seen = @{}
    foreach ($requested in @($AdoptionPolicy)) {
        if ($null -eq $requested -or $requested.PSObject.Properties.Name -notcontains 'Path' -or $requested.PSObject.Properties.Name -notcontains 'Disposition') { throw 'Adoption policy records require Path and Disposition.' }
        $relative = [string]$requested.Path
        $disposition = [string]$requested.Disposition
        if ($disposition -notin @('AdoptUnchanged','PreserveHost','ReplaceWithBackup')) { throw "Adoption disposition is not implemented in this T12 slice: $disposition" }
        $target = Assert-HetznerSafeRelativePath -RelativePath $relative -InstallRoot $InstallRoot
        $key = $target.ToLowerInvariant()
        if ($seen.ContainsKey($key)) { throw "Duplicate adoption policy path: $relative" }
        $seen[$key] = $true
        $matches = @($Operations | Where-Object { [string]$_.RelativePath -ceq $relative -and [string]$_.Kind -in @('CopyFile','CopyMissionPbo','GenerateLauncher','DeleteStaleLauncher') })
        if ($matches.Count -ne 1) { throw "Adoption policy path is not one canonical managed-file operation: $relative" }
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw "Adoption policy target must already be a file: $relative" }
        Assert-HetznerNoReparsePoints -Path $target -FenceRoot $FenceRoot | Out-Null
        $preHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
        $preBytes = [int64](Get-Item -LiteralPath $target).Length
        $desired = Get-HetznerDesiredOperationIdentity -Operation $matches[0]
        if($disposition -eq 'AdoptUnchanged') {
            if ([string]$desired.Kind -cne 'File' -or $preHash -cne [string]$desired.Sha256 -or $preBytes -ne [int64]$desired.Bytes) { throw "AdoptUnchanged requires the host file to equal the exact desired postimage: $relative" }
            $records += [pscustomobject][ordered]@{Path=$relative;Disposition='AdoptUnchanged';PreSha256=$preHash;PreBytes=$preBytes;PostSha256=[string]$desired.Sha256;PostBytes=[int64]$desired.Bytes;Owner='HostAdopted';RollbackDisposition='PreserveHost';UninstallDisposition='PreserveHost'}
        } elseif($disposition -eq 'PreserveHost') {
            if([string]$matches[0].Kind -cne 'DeleteStaleLauncher'){throw "PreserveHost is currently limited to stale launcher deletion operations: $relative"}
            $records += [pscustomobject][ordered]@{Path=$relative;Disposition='PreserveHost';PreSha256=$preHash;PreBytes=$preBytes;PostSha256=$preHash;PostBytes=$preBytes;Owner='Host';RollbackDisposition='PreserveHost';UninstallDisposition='PreserveHost'}
        } else {
            if([string]$desired.Kind -cne 'File' -or [string]$matches[0].Kind -notin @('CopyFile','CopyMissionPbo','GenerateLauncher')){throw "ReplaceWithBackup requires a canonical file-producing operation: $relative"}
            if($preHash -ceq [string]$desired.Sha256 -and $preBytes -eq [int64]$desired.Bytes){throw "ReplaceWithBackup requires a differing host preimage; use AdoptUnchanged: $relative"}
            $records += [pscustomobject][ordered]@{Path=$relative;Disposition='ReplaceWithBackup';PreSha256=$preHash;PreBytes=$preBytes;PostSha256=[string]$desired.Sha256;PostBytes=[int64]$desired.Bytes;Owner='InstallerReplacingHost';RollbackDisposition='RestoreBackup';UninstallDisposition='RestoreBackup'}
        }
    }
    return @($records | Sort-Object Path)
}

function New-HetznerPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SourceRoot,
        [Parameter(Mandatory)][string]$InstallRoot,
        [Parameter(Mandatory)][string]$FenceRoot,
        [Parameter(Mandatory)][ValidateSet('hc-0','hc-1','hc-2','hc-3')][string]$ProfileName,
        [Parameter(Mandatory)][string]$MissionPboPath,
        [string]$ProfilesPath = $script:ProfilesPath,
        [AllowEmptyCollection()][object[]]$AdoptionPolicy = @()
    )
    $preflight = Test-HetznerPreflight -SourceRoot $SourceRoot -ProfileName $ProfileName -MissionPboPath $MissionPboPath -ProfilesPath $ProfilesPath
    $source = $preflight.SourceRoot
    $install = Test-HetznerInstallPath -Path $InstallRoot -FenceRoot $FenceRoot
    $profile = Get-HetznerInstallerProfile -Name $ProfileName -ProfilesPath $ProfilesPath
    $pbo = Get-HetznerMissionPboInfo -MissionPboPath $MissionPboPath
    $expected = Get-HetznerExpectedManagedPaths -Profile $profile -MissionPboLeaf $pbo.Leaf
    $identities = Get-HetznerExpectedLauncherIdentities -Profile $profile -ProfileName $ProfileName
    $operations = @(New-HetznerCanonicalOperations -SourceRoot $source -InstallRoot $install -Profile $profile -ProfileName $ProfileName -Pbo $pbo)
    $sourceFiles = @(Get-HetznerSourceFileRecords -SourceRoot $source)
    $canonicalDescriptors = @(Get-HetznerOperationDescriptors -Operations $operations)
    $canonicalAdoptionPolicy = @(Get-HetznerCanonicalAdoptionPolicy -AdoptionPolicy $AdoptionPolicy -Operations $operations -InstallRoot $install -FenceRoot $FenceRoot)
    $fingerprint = Get-HetznerPlanFingerprint -SourceRoot $source -InstallRoot $install -FenceRoot $FenceRoot -ProfileName $ProfileName -MissionPboPath $pbo.Path -MissionPboSha256 $pbo.Sha256 -SourceFiles $sourceFiles -CanonicalOperationDescriptors $canonicalDescriptors -AdoptionPolicy $canonicalAdoptionPolicy
    return [pscustomobject]@{
        SchemaVersion = $script:SchemaVersion
        Action = 'ApplyPlan'
        SourceRoot = $source
        InstallRoot = $install
        FenceRoot = (Get-HetznerAbsolutePath $FenceRoot)
        ProfileName = $ProfileName
        HeadlessClients = [int]$profile.headlessClients
        Operational = [bool]$profile.operational
        Topology = [string]$profile.topology
        SteamIsolationAdapter = [string]$profile.steamIsolationAdapter
        MissionPboPath = $pbo.Path
        MissionPboLeaf = $pbo.Leaf
        MissionPboSha256 = $pbo.Sha256
        ExpectedManagedPaths = $expected
        LauncherIdentities = $identities
        SourceFiles = $sourceFiles
        CanonicalOperationDescriptors = $canonicalDescriptors
        AdoptionPolicy = $canonicalAdoptionPolicy
        PlanFingerprint = $fingerprint
        Operations = @($operations)
        ApplyRequired = $true
    }
}

function Assert-HetznerExactPathSet {
    param([Parameter(Mandatory)][object[]]$Actual, [Parameter(Mandatory)][string[]]$Expected, [Parameter(Mandatory)][string]$Label)
    $a = @($Actual | Sort-Object)
    $e = @($Expected | Sort-Object)
    if (($a -join "`n") -ne ($e -join "`n")) { throw "$Label does not match the exact expected managed-file set." }
}

function Assert-HetznerLauncherIdentitySet {
    param(
        [AllowNull()][AllowEmptyCollection()]$Actual,
        [AllowNull()][AllowEmptyCollection()]$Expected,
        [Parameter(Mandatory)][string]$Label
    )
    $actualKeys = @()
    foreach ($entry in @($Actual)) {
        if ($null -ne $entry) {
            $properties = @($entry.PSObject.Properties)
            $nameProperty = @($properties | Where-Object { $_.Name -eq 'Name' })[0]
            $profileProperty = @($properties | Where-Object { $_.Name -eq 'ProfileId' })[0]
            $rptProperty = @($properties | Where-Object { $_.Name -eq 'RptIdentity' })[0]
            $portProperty = @($properties | Where-Object { $_.Name -eq 'Port' })[0]
            if ($null -ne $nameProperty -and $null -ne $profileProperty -and $null -ne $rptProperty -and $null -ne $portProperty) {
                $actualKeys += ("{0}|{1}|{2}|{3}" -f $nameProperty.Value,$profileProperty.Value,$rptProperty.Value,$portProperty.Value)
            } else { $actualKeys += '<invalid-identity-record>' }
        }
    }
    $expectedKeys = @()
    foreach ($entry in @($Expected)) {
        if ($null -ne $entry) {
            $properties = @($entry.PSObject.Properties)
            $nameProperty = @($properties | Where-Object { $_.Name -eq 'Name' })[0]
            $profileProperty = @($properties | Where-Object { $_.Name -eq 'ProfileId' })[0]
            $rptProperty = @($properties | Where-Object { $_.Name -eq 'RptIdentity' })[0]
            $portProperty = @($properties | Where-Object { $_.Name -eq 'Port' })[0]
            if ($null -ne $nameProperty -and $null -ne $profileProperty -and $null -ne $rptProperty -and $null -ne $portProperty) {
                $expectedKeys += ("{0}|{1}|{2}|{3}" -f $nameProperty.Value,$profileProperty.Value,$rptProperty.Value,$portProperty.Value)
            } else { $expectedKeys += '<invalid-identity-record>' }
        }
    }
    $actualKeys = @($actualKeys | Sort-Object)
    $expectedKeys = @($expectedKeys | Sort-Object)
    if (($actualKeys -join "`n") -ne ($expectedKeys -join "`n")) { throw "$Label launcher identity set mismatch." }
}

function Assert-HetznerSafeRelativePath {
    param([Parameter(Mandatory)][string]$RelativePath, [Parameter(Mandatory)][string]$InstallRoot)
    if ([System.IO.Path]::IsPathRooted($RelativePath) -or $RelativePath -match '(^|[\\/])\.\.([\\/]|$)') { throw "Unsafe manifest traversal path: $RelativePath" }
    $target = Get-HetznerAbsolutePath (Join-Path $InstallRoot $RelativePath)
    if (-not (Test-HetznerContainedPath -Path $target -Root $InstallRoot)) { throw "Manifest target is outside the install root: $RelativePath" }
    return $target
}

function Get-HetznerManagedFileRecords {
    param([Parameter(Mandatory)][object[]]$Operations)
    $records = @()
    foreach ($operation in @($Operations | Where-Object { $_.Kind -in @('CopyFile','CopyMissionPbo','GenerateLauncher') })) {
        if (-not (Test-Path -LiteralPath $operation.TargetPath -PathType Leaf)) { throw "Managed file was not created: $($operation.RelativePath)" }
        $hash = (Get-FileHash -LiteralPath $operation.TargetPath -Algorithm SHA256).Hash.ToLowerInvariant()
        $records += [pscustomobject]@{ Path = $operation.RelativePath; Sha256 = $hash; Bytes = ([int64](Get-Item -LiteralPath $operation.TargetPath).Length) }
    }
    return @($records)
}

function Write-HetznerJson {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)]$Value)
    $json = $Value | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($false)))
}

function Write-HetznerAtomicJson {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)]$Value)
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $temporary = Join-Path $parent ('.journal-' + [guid]::NewGuid().ToString('N') + '.tmp')
    $backup = Join-Path $parent ('.journal-' + [guid]::NewGuid().ToString('N') + '.bak')
    $bytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes(($Value | ConvertTo-Json -Depth 16) + "`n")
    $stream = $null
    try {
        $stream = New-Object System.IO.FileStream($temporary,[System.IO.FileMode]::CreateNew,[System.IO.FileAccess]::Write,[System.IO.FileShare]::None,4096,[System.IO.FileOptions]::WriteThrough)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
        $stream.Dispose(); $stream = $null
        if (Test-Path -LiteralPath $Path -PathType Leaf) { [System.IO.File]::Replace($temporary, $Path, $backup); Remove-Item -LiteralPath $backup -Force }
        else { [System.IO.File]::Move($temporary, $Path) }
    } finally {
        if ($null -ne $stream) { $stream.Dispose() }
        if (Test-Path -LiteralPath $temporary -PathType Leaf) { Remove-Item -LiteralPath $temporary -Force }
        if (Test-Path -LiteralPath $backup -PathType Leaf) { Remove-Item -LiteralPath $backup -Force }
    }
}

function Copy-HetznerFileAtomicVerified {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][string]$ExpectedSha256,
        [Parameter(Mandatory)][int64]$ExpectedBytes,
        [ValidateSet('snapshot','preimage','apply','recover')][string]$Purpose = 'apply',
        [switch]$FailBeforePromotion
    )
    $sourcePath = Get-HetznerAbsolutePath $Source
    $destinationPath = Get-HetznerAbsolutePath $Destination
    if ($ExpectedSha256 -cnotmatch '^[0-9a-f]{64}$' -or $ExpectedBytes -lt 0) { throw 'Verified copy expected identity is invalid.' }
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "Verified copy source is missing: $sourcePath" }
    if (Test-HetznerReparsePoint -Path $sourcePath) { throw "Verified copy source cannot be a reparse point: $sourcePath" }
    if (Test-Path -LiteralPath $destinationPath -PathType Container) { throw "Verified copy destination is a directory: $destinationPath" }
    if ((Test-Path -LiteralPath $destinationPath) -and (Test-HetznerReparsePoint -Path $destinationPath)) { throw "Verified copy destination cannot be a reparse point: $destinationPath" }

    $parent = Split-Path -Parent $destinationPath
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    if (Test-HetznerReparsePoint -Path $parent) { throw "Verified copy destination parent cannot be a reparse point: $parent" }
    $temporary = Join-Path $parent ('.' + $Purpose + '-' + [guid]::NewGuid().ToString('N') + '.tmp')
    $backup = Join-Path $parent ('.' + $Purpose + '-' + [guid]::NewGuid().ToString('N') + '.bak')
    $input = $null
    $output = $null
    $promotionVerified = $false
    try {
        $input = New-Object System.IO.FileStream($sourcePath,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,[System.IO.FileShare]::Read,65536,[System.IO.FileOptions]::SequentialScan)
        $output = New-Object System.IO.FileStream($temporary,[System.IO.FileMode]::CreateNew,[System.IO.FileAccess]::Write,[System.IO.FileShare]::None,65536,[System.IO.FileOptions]::WriteThrough)
        $input.CopyTo($output,65536)
        $output.Flush($true)
        $output.Dispose(); $output = $null
        $input.Dispose(); $input = $null

        $temporaryHash = (Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash.ToLowerInvariant()
        $temporaryBytes = [int64](Get-Item -LiteralPath $temporary).Length
        if ($temporaryHash -cne $ExpectedSha256 -or $temporaryBytes -ne $ExpectedBytes) { throw "Verified $Purpose copy does not match its expected source identity." }
        if ($FailBeforePromotion) { throw 'Injected interruption failpoint: BeforeFirstCopyPromotion' }
        if (Test-Path -LiteralPath $destinationPath -PathType Leaf) {
            [System.IO.File]::Replace($temporary,$destinationPath,$backup)
        } else {
            [System.IO.File]::Move($temporary,$destinationPath)
        }
        if ((Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $ExpectedSha256 -or [int64](Get-Item -LiteralPath $destinationPath).Length -ne $ExpectedBytes) {
            throw "Promoted $Purpose copy does not match its expected identity."
        }
        $promotionVerified = $true
        if (Test-Path -LiteralPath $backup -PathType Leaf) { Remove-Item -LiteralPath $backup -Force }
    } finally {
        if ($null -ne $output) { $output.Dispose() }
        if ($null -ne $input) { $input.Dispose() }
        if (Test-Path -LiteralPath $temporary -PathType Leaf) { Remove-Item -LiteralPath $temporary -Force }
        if ($promotionVerified -and (Test-Path -LiteralPath $backup -PathType Leaf)) { Remove-Item -LiteralPath $backup -Force }
    }
}

function Get-HetznerTransactionPaths {
    param([Parameter(Mandatory)][string]$InstallRoot, [Parameter(Mandatory)][string]$FenceRoot)
    $install = Test-HetznerInstallPath -Path $InstallRoot -FenceRoot $FenceRoot
    $fence = Get-HetznerAbsolutePath $FenceRoot
    $reservedRoot = Get-HetznerAbsolutePath (Join-Path $fence '.hetzner-installer-transactions')
    if ($install -eq $reservedRoot -or (Test-HetznerContainedPath -Path $install -Root $reservedRoot)) {
        throw 'Install root overlaps the reserved transaction namespace.'
    }
    $key = Get-HetznerStringSha256 -Value $install.ToLowerInvariant()
    $root = Join-Path $reservedRoot $key
    if ($install -eq $root -or (Test-HetznerContainedPath -Path $install -Root $root) -or (Test-HetznerContainedPath -Path $root -Root $install)) {
        throw 'Derived transaction root must remain disjoint from the install root.'
    }
    [pscustomobject]@{
        InstallRoot = $install; FenceRoot = $fence; TransactionRoot = $root
        JournalPath = (Join-Path $root 'journal.json'); LockPath = (Join-Path $root 'transaction.lock')
        PreimageRoot = (Join-Path $root 'preimages'); SourceSnapshotRoot = (Join-Path $root 'source-snapshot')
    }
}

function Get-HetznerSourceSnapshotFingerprint {
    param([Parameter(Mandatory)][object[]]$SourceSnapshot)
    $records = @()
    foreach ($record in @($SourceSnapshot)) {
        $records += [pscustomobject][ordered]@{
            Index = [int]$record.Index
            Kind = [string]$record.Kind
            RelativePath = [string]$record.RelativePath
            OriginalPath = [string]$record.OriginalPath
            SnapshotPath = [string]$record.SnapshotPath
            Sha256 = [string]$record.Sha256
            Bytes = [int64]$record.Bytes
        }
    }
    return Get-HetznerStringSha256 -Value (ConvertTo-Json -InputObject @($records) -Depth 8 -Compress)
}

function Assert-HetznerSourceSnapshotContract {
    param([Parameter(Mandatory)]$Journal, [Parameter(Mandatory)]$Paths, [switch]$VerifyFiles)
    if ($Journal.PSObject.Properties.Name -notcontains 'SourceSnapshot' -or $Journal.PSObject.Properties.Name -notcontains 'SourceSnapshotFingerprint') { throw 'Transaction source snapshot identity is missing.' }
    $records = @($Journal.SourceSnapshot)
    if ($records.Count -ne 3) { throw 'Transaction source snapshot must contain exactly two configs and one mission PBO.' }
    $expectedKinds = @('Config','Config','MissionPbo')
    $seenOriginals = @{}
    for ($index = 0; $index -lt $records.Count; $index++) {
        $record = $records[$index]
        if ([int]$record.Index -ne $index -or [string]$record.Kind -cne $expectedKinds[$index]) { throw 'Transaction source snapshot order or kind is invalid.' }
        if ([string]::IsNullOrWhiteSpace([string]$record.RelativePath)) { throw 'Transaction source snapshot relative identity is missing.' }
        $original = Get-HetznerAbsolutePath ([string]$record.OriginalPath)
        $snapshot = Get-HetznerAbsolutePath ([string]$record.SnapshotPath)
        $expectedSnapshot = Get-HetznerAbsolutePath (Join-Path $Paths.SourceSnapshotRoot ('{0:d4}.bin' -f $index))
        if ($snapshot -cne $expectedSnapshot -or -not (Test-HetznerContainedPath -Path $snapshot -Root $Paths.SourceSnapshotRoot)) { throw 'Transaction source snapshot path escaped or changed identity.' }
        if ($original -eq $Paths.TransactionRoot -or (Test-HetznerContainedPath -Path $original -Root $Paths.TransactionRoot)) { throw 'Transaction source snapshot original path overlaps transaction storage.' }
        $originalKey = $original.ToLowerInvariant()
        if ($seenOriginals.ContainsKey($originalKey)) { throw 'Transaction source snapshot contains a duplicate original path.' }
        $seenOriginals[$originalKey] = $true
        if ([string]$record.Sha256 -cnotmatch '^[0-9a-f]{64}$' -or [int64]$record.Bytes -lt 0) { throw 'Transaction source snapshot hash or byte identity is invalid.' }
        if ($VerifyFiles) {
            if (-not (Test-Path -LiteralPath $snapshot -PathType Leaf)) { throw 'Transaction source snapshot artifact is missing.' }
            Assert-HetznerNoReparsePoints -Path $snapshot -FenceRoot $Paths.FenceRoot | Out-Null
            if ((Get-FileHash -LiteralPath $snapshot -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$record.Sha256 -or [int64](Get-Item -LiteralPath $snapshot).Length -ne [int64]$record.Bytes) { throw 'Transaction source snapshot artifact hash or byte count changed.' }
        }
    }
    $fingerprint = Get-HetznerSourceSnapshotFingerprint -SourceSnapshot $records
    if ([string]$Journal.SourceSnapshotFingerprint -cne $fingerprint) { throw 'Transaction source snapshot fingerprint mismatch.' }
}

function New-HetznerSourceSnapshot {
    param([Parameter(Mandatory)]$Plan, [Parameter(Mandatory)]$Paths)
    if (Test-Path -LiteralPath $Paths.SourceSnapshotRoot) {
        if (-not (Test-HetznerContainedPath -Path $Paths.SourceSnapshotRoot -Root $Paths.TransactionRoot)) { throw 'Transaction source snapshot cleanup escaped its transaction root.' }
        Assert-HetznerNoReparsePoints -Path $Paths.SourceSnapshotRoot -FenceRoot $Paths.FenceRoot | Out-Null
        Remove-Item -LiteralPath $Paths.SourceSnapshotRoot -Recurse -Force
    }
    New-Item -ItemType Directory -Path $Paths.SourceSnapshotRoot -Force | Out-Null
    Assert-HetznerNoReparsePoints -Path $Paths.SourceSnapshotRoot -FenceRoot $Paths.FenceRoot | Out-Null

    $inputs = @()
    foreach ($sourceFile in @($Plan.SourceFiles)) {
        $inputs += [pscustomobject][ordered]@{ Kind='Config'; RelativePath=[string]$sourceFile.RelativePath; OriginalPath=[string]$sourceFile.SourcePath; Sha256=[string]$sourceFile.Sha256; Bytes=[int64]$sourceFile.Bytes }
    }
    $pbo = Get-HetznerMissionPboInfo -MissionPboPath $Plan.MissionPboPath
    if ([string]$pbo.Sha256 -cne [string]$Plan.MissionPboSha256) { throw 'Mission PBO changed before source snapshot creation.' }
    $inputs += [pscustomobject][ordered]@{ Kind='MissionPbo'; RelativePath=[string]$Plan.MissionPboLeaf; OriginalPath=[string]$pbo.Path; Sha256=[string]$pbo.Sha256; Bytes=[int64]$pbo.Bytes }
    if ($inputs.Count -ne 3) { throw 'Source snapshot input set is not the exact two configs plus mission PBO.' }

    $records = @()
    for ($index = 0; $index -lt $inputs.Count; $index++) {
        $inputRecord = $inputs[$index]
        $snapshotPath = Join-Path $Paths.SourceSnapshotRoot ('{0:d4}.bin' -f $index)
        Copy-HetznerFileAtomicVerified -Source $inputRecord.OriginalPath -Destination $snapshotPath -ExpectedSha256 $inputRecord.Sha256 -ExpectedBytes $inputRecord.Bytes -Purpose snapshot
        $records += [pscustomobject][ordered]@{
            Index=$index; Kind=[string]$inputRecord.Kind; RelativePath=[string]$inputRecord.RelativePath
            OriginalPath=(Get-HetznerAbsolutePath ([string]$inputRecord.OriginalPath)); SnapshotPath=(Get-HetznerAbsolutePath $snapshotPath)
            Sha256=[string]$inputRecord.Sha256; Bytes=[int64]$inputRecord.Bytes
        }
    }
    return @($records)
}

function Get-HetznerSnapshotBackedOperations {
    param([Parameter(Mandatory)][object[]]$Operations, [Parameter(Mandatory)][object[]]$SourceSnapshot)
    $result = @()
    foreach ($operation in @($Operations)) {
        $sourcePath = [string]$operation.SourcePath
        if ([string]$operation.Kind -in @('CopyFile','CopyMissionPbo')) {
            $matches = @($SourceSnapshot | Where-Object { (Get-HetznerAbsolutePath ([string]$_.OriginalPath)) -eq (Get-HetznerAbsolutePath $sourcePath) })
            if ($matches.Count -ne 1) { throw "Copy operation has no unique sealed source snapshot: $($operation.RelativePath)" }
            $sourcePath = [string]$matches[0].SnapshotPath
        }
        $copy = [ordered]@{ Kind=[string]$operation.Kind; RelativePath=[string]$operation.RelativePath; SourcePath=$sourcePath; TargetPath=[string]$operation.TargetPath }
        if ($operation.PSObject.Properties.Name -contains 'Content') { $copy.Content = [string]$operation.Content }
        $result += [pscustomobject]$copy
    }
    return @($result)
}

function Get-HetznerTransactionJournalFingerprint {
    param([Parameter(Mandatory)]$Journal)
    $entries = @()
    foreach ($entry in @($Journal.Entries)) {
        $entries += [pscustomobject][ordered]@{
            Index = [int]$entry.Index
            Path = [string]$entry.Path
            Label = [string]$entry.Label
            PreKind = [string]$entry.PreKind
            PreSha256 = [string]$entry.PreSha256
            PreBytes = [int64]$entry.PreBytes
            Preimage = [string]$entry.Preimage
        }
    }
    $immutable = [pscustomobject][ordered]@{
        SchemaVersion = [int]$Journal.SchemaVersion
        TransactionVersion = [int]$Journal.TransactionVersion
        TransactionType = [string]$Journal.TransactionType
        TransactionId = [string]$Journal.TransactionId
        InstallRoot = [string]$Journal.InstallRoot
        FenceRoot = [string]$Journal.FenceRoot
        PlanFingerprint = [string]$Journal.PlanFingerprint
        SourceSnapshotFingerprint = [string]$Journal.SourceSnapshotFingerprint
        SourceSnapshot = @($Journal.SourceSnapshot)
        Entries = @($entries)
    }
    if ($Journal.PSObject.Properties.Name -contains 'RollbackContract') {
        $immutable | Add-Member -NotePropertyName RollbackContract -NotePropertyValue $Journal.RollbackContract
    }
    if ($Journal.PSObject.Properties.Name -contains 'UninstallContract') {
        $immutable | Add-Member -NotePropertyName UninstallContract -NotePropertyValue $Journal.UninstallContract
    }
    if ($Journal.PSObject.Properties.Name -contains 'CommitContract') {
        $immutable | Add-Member -NotePropertyName CommitContract -NotePropertyValue $Journal.CommitContract
    }
    return Get-HetznerStringSha256 -Value (ConvertTo-Json -InputObject $immutable -Depth 16 -Compress)
}

function New-HetznerCommitContract {
    param([Parameter(Mandatory)][string]$InstallRoot)
    $records=@()
    foreach($relative in @('.hetzner-installer\manifest.json','.hetzner-installer\receipt.json','.hetzner-installer\ownership-seal.json')){
        $path=Join-Path $InstallRoot $relative
        if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Committed metadata is missing before commit: $relative"}
        $records += [pscustomobject][ordered]@{Path=$relative;Sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant();Bytes=[int64](Get-Item -LiteralPath $path).Length}
    }
    return [pscustomobject][ordered]@{CommitVersion=1;CommitType='metadata-poststate-v1';MetadataFiles=$records}
}

function Assert-HetznerCommitContract {
    param([Parameter(Mandatory)]$Journal,[Parameter(Mandatory)]$Paths,[switch]$VerifyCurrent)
    if($Journal.PSObject.Properties.Name -notcontains 'CommitContract'){throw 'Committed transaction journal metadata anchor is missing.'}
    $contract=$Journal.CommitContract
    if([int]$contract.CommitVersion -ne 1 -or [string]$contract.CommitType -ne 'metadata-poststate-v1'){throw 'Committed transaction journal metadata anchor identity is invalid.'}
    $records=@($contract.MetadataFiles);$expected=@('.hetzner-installer\manifest.json','.hetzner-installer\receipt.json','.hetzner-installer\ownership-seal.json')
    Assert-HetznerExactPathSet -Actual @($records|ForEach-Object{[string]$_.Path}) -Expected $expected -Label 'Committed metadata anchor'
    foreach($record in $records){
        $path=Assert-HetznerSafeRelativePath -RelativePath ([string]$record.Path) -InstallRoot $Paths.InstallRoot
        if([string]$record.Sha256 -cnotmatch '^[0-9a-f]{64}$' -or [int64]$record.Bytes -lt 0){throw 'Committed transaction journal metadata anchor hash or bytes are invalid.'}
        if($VerifyCurrent){
            if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Committed journal metadata anchor target is missing: $($record.Path)"}
            Assert-HetznerNoReparsePoints -Path $path -FenceRoot $Paths.FenceRoot|Out-Null
            if((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$record.Sha256 -or [int64](Get-Item -LiteralPath $path).Length -ne [int64]$record.Bytes){throw "Committed journal metadata anchor hash or bytes changed: $($record.Path)"}
        }
    }
    return $contract
}

function Assert-HetznerTransactionJournal {
    param([Parameter(Mandatory)]$Journal, [Parameter(Mandatory)]$Paths, [switch]$VerifyPreimages)
    if ([int]$Journal.SchemaVersion -ne $script:SchemaVersion -or [int]$Journal.TransactionVersion -ne $script:TransactionVersion -or [string]$Journal.TransactionType -ne $script:TransactionType) { throw 'Transaction journal schema or identity mismatch.' }
    if ((Get-HetznerAbsolutePath ([string]$Journal.InstallRoot)) -ne $Paths.InstallRoot -or (Get-HetznerAbsolutePath ([string]$Journal.FenceRoot)) -ne $Paths.FenceRoot) { throw 'Transaction journal path identity mismatch.' }
    if ([string]$Journal.State -notin @('Prepared','Applying','Recovering','Recovered','Committed','RollingBack','RolledBack','Uninstalling','Uninstalled')) { throw 'Transaction journal state is invalid.' }
    if ($Journal.PSObject.Properties.Name -notcontains 'Entries') { throw 'Transaction journal pre-state entries are missing.' }
    Assert-HetznerSourceSnapshotContract -Journal $Journal -Paths $Paths
    if ($Journal.PSObject.Properties.Name -notcontains 'JournalFingerprint' -or [string]::IsNullOrWhiteSpace([string]$Journal.JournalFingerprint)) { throw 'Transaction journal immutable fingerprint is missing.' }
    $actualFingerprint = Get-HetznerTransactionJournalFingerprint -Journal $Journal
    if ([string]$Journal.JournalFingerprint -cne $actualFingerprint) { throw 'Transaction journal immutable fingerprint mismatch; journal tampering or corruption detected.' }
    if($Journal.PSObject.Properties.Name -contains 'CommitContract'){Assert-HetznerCommitContract -Journal $Journal -Paths $Paths|Out-Null}
    elseif([string]$Journal.State -in @('Committed','RollingBack','RolledBack','Uninstalling','Uninstalled')){throw 'Committed transaction journal metadata anchor is missing.'}
    $entries = @($Journal.Entries)
    if ($entries.Count -eq 0) { throw 'Transaction journal must contain its install-root pre-state entry.' }
    $seenPaths = @{}
    $expectedIndex = 0
    foreach ($entry in $entries) {
        if ([int]$entry.Index -ne $expectedIndex) { throw 'Transaction journal entry indexes or order are invalid.' }
        $target = Get-HetznerAbsolutePath ([string]$entry.Path)
        if ($target -ne $Paths.InstallRoot -and -not (Test-HetznerContainedPath -Path $target -Root $Paths.InstallRoot)) { throw 'Transaction journal entry escaped the install root.' }
        $targetKey = $target.ToLowerInvariant()
        if ($seenPaths.ContainsKey($targetKey)) { throw 'Transaction journal contains a duplicate target path.' }
        $seenPaths[$targetKey] = $true
        if ($expectedIndex -eq 0 -and ($target -ne $Paths.InstallRoot -or [string]$entry.Label -cne 'install-root')) { throw 'Transaction journal first entry must identify the install root.' }
        $kind = [string]$entry.PreKind
        if ($kind -eq 'File') {
            if ([string]$entry.PreSha256 -cnotmatch '^[0-9a-f]{64}$' -or [int64]$entry.PreBytes -lt 0 -or [string]::IsNullOrWhiteSpace([string]$entry.Preimage)) { throw 'Transaction journal file pre-state metadata is invalid.' }
            $expectedPreimage = 'preimages\{0:d4}.bin' -f $expectedIndex
            if ([string]$entry.Preimage -cne $expectedPreimage) { throw 'Transaction journal preimage identity is invalid.' }
            $source = Get-HetznerAbsolutePath (Join-Path $Paths.TransactionRoot ([string]$entry.Preimage))
            if (-not (Test-HetznerContainedPath -Path $source -Root $Paths.PreimageRoot)) { throw 'Transaction journal preimage escaped its root.' }
            if ($VerifyPreimages) {
                if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw 'Transaction journal preimage is missing.' }
                Assert-HetznerNoReparsePoints -Path $source -FenceRoot $Paths.FenceRoot | Out-Null
                if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$entry.PreSha256 -or [int64](Get-Item -LiteralPath $source).Length -ne [int64]$entry.PreBytes) { throw 'Transaction journal preimage hash or byte count changed.' }
            }
        } elseif ($kind -in @('Missing','Directory')) {
            if (-not [string]::IsNullOrEmpty([string]$entry.PreSha256) -or [int64]$entry.PreBytes -ne 0 -or -not [string]::IsNullOrEmpty([string]$entry.Preimage)) { throw 'Transaction journal non-file pre-state metadata is invalid.' }
        } else { throw 'Transaction journal pre-state kind is invalid.' }
        $expectedIndex++
    }
    if ($Journal.PSObject.Properties.Name -contains 'UninstallContract') {
        Assert-HetznerUninstallContract -Contract $Journal.UninstallContract -Paths $Paths -Journal $Journal
        if([string]$Journal.State-in@('Uninstalling','Uninstalled')){
            if($Journal.PSObject.Properties.Name-notcontains'PendingOperationIndex'){throw 'Uninstall transaction journal has no write-ahead pending-operation marker.'}
            $pending=[int]$Journal.PendingOperationIndex;$completed=[int]$Journal.OperationIndex;$final=@($Journal.UninstallContract.Actions).Count-1
            if($completed-lt-1 -or $completed-gt$final -or $pending-lt-1 -or $pending-gt$final -or ($pending-ge 0 -and $pending-ne($completed+1))){throw 'Uninstall write-ahead progress markers are inconsistent.'}
            if([string]$Journal.State-eq'Uninstalled' -and ($pending-ne-1 -or $completed-ne$final)){throw 'Uninstalled transaction has nonterminal write-ahead progress.'}
        }
    } elseif ([string]$Journal.State -in @('Uninstalling','Uninstalled')) {
        throw 'Uninstall transaction journal lost its sealed uninstall contract.'
    }
}

function Get-HetznerTransactionStatus {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$InstallRoot, [Parameter(Mandatory)][string]$FenceRoot)
    $paths = Get-HetznerTransactionPaths -InstallRoot $InstallRoot -FenceRoot $FenceRoot
    if (Test-Path -LiteralPath $paths.TransactionRoot) { Assert-HetznerNoReparsePoints -Path $paths.TransactionRoot -FenceRoot $paths.FenceRoot | Out-Null }
    if (-not (Test-Path -LiteralPath $paths.JournalPath -PathType Leaf)) {
        return [pscustomobject]@{ State='None'; OperationIndex=-1; TransactionId=''; JournalPath=$paths.JournalPath; LockPath=$paths.LockPath; TransactionRoot=$paths.TransactionRoot }
    }
    $journal = Get-Content -LiteralPath $paths.JournalPath -Raw | ConvertFrom-Json
    Assert-HetznerTransactionJournal -Journal $journal -Paths $paths -VerifyPreimages
    return [pscustomobject]@{
        State=[string]$journal.State; OperationIndex=[int]$journal.OperationIndex; TransactionId=[string]$journal.TransactionId
        JournalPath=$paths.JournalPath; LockPath=$paths.LockPath; TransactionRoot=$paths.TransactionRoot; Journal=$journal
    }
}

function Enter-HetznerTransactionLock {
    param([Parameter(Mandatory)]$Paths)
    New-Item -ItemType Directory -Path $Paths.TransactionRoot -Force | Out-Null
    Assert-HetznerNoReparsePoints -Path $Paths.TransactionRoot -FenceRoot $Paths.FenceRoot | Out-Null
    try {
        $stream = New-Object System.IO.FileStream($Paths.LockPath,[System.IO.FileMode]::CreateNew,[System.IO.FileAccess]::ReadWrite,[System.IO.FileShare]::None,4096,[System.IO.FileOptions]::DeleteOnClose)
        $token = (New-Object System.Text.UTF8Encoding($false)).GetBytes(([guid]::NewGuid().ToString('N')) + "`n")
        $stream.Write($token,0,$token.Length); $stream.Flush($true)
        return $stream
    } catch { throw 'Another exclusive installer transaction is active for this install root.' }
}

function Invoke-HetznerInjectedFailpoint {
    param([string]$Requested, [Parameter(Mandatory)][string]$Checkpoint)
    if (-not [string]::IsNullOrWhiteSpace($Requested) -and $Requested -eq $Checkpoint) { throw "Injected interruption failpoint: $Checkpoint" }
}

function Get-HetznerTransactionCandidates {
    param([Parameter(Mandatory)]$Plan, [Parameter(Mandatory)][object[]]$Operations)
    $items = @([pscustomobject]@{ Path=$Plan.InstallRoot; Label='install-root' })
    foreach ($operation in $Operations) { $items += [pscustomobject]@{ Path=[string]$operation.TargetPath; Label=[string]$operation.RelativePath } }
    foreach ($relative in @('.hetzner-installer\manifest.json','.hetzner-installer\receipt.json','.hetzner-installer\ownership-seal.json')) {
        $items += [pscustomobject]@{ Path=(Join-Path $Plan.InstallRoot $relative); Label=$relative }
    }
    $seen = @{}; $result = @()
    foreach ($item in $items) {
        $path = Get-HetznerAbsolutePath $item.Path; $key = $path.ToLowerInvariant()
        if (-not $seen.ContainsKey($key)) { $seen[$key]=$true; $result += [pscustomobject]@{ Path=$path; Label=$item.Label } }
    }
    return @($result)
}

function New-HetznerTransactionJournal {
    param([Parameter(Mandatory)]$Plan, [Parameter(Mandatory)][object[]]$Operations, [Parameter(Mandatory)]$Paths, [Parameter(Mandatory)][object[]]$SourceSnapshot)
    if (Test-Path -LiteralPath $Paths.PreimageRoot) {
        if (-not (Test-HetznerContainedPath -Path $Paths.PreimageRoot -Root $Paths.TransactionRoot)) { throw 'Transaction preimage cleanup escaped its transaction root.' }
        Remove-Item -LiteralPath $Paths.PreimageRoot -Recurse -Force
    }
    New-Item -ItemType Directory -Path $Paths.PreimageRoot -Force | Out-Null
    $entries=@(); $index=0
    foreach ($candidate in @(Get-HetznerTransactionCandidates -Plan $Plan -Operations $Operations)) {
        $kind='Missing'; $hash=''; $bytes=[int64]0; $preimage=''
        if (Test-Path -LiteralPath $candidate.Path -PathType Leaf) {
            $kind='File'; $hash=(Get-FileHash -LiteralPath $candidate.Path -Algorithm SHA256).Hash.ToLowerInvariant(); $bytes=[int64](Get-Item -LiteralPath $candidate.Path).Length
            $preimage=('preimages\{0:d4}.bin' -f $index); $destination=Join-Path $Paths.TransactionRoot $preimage
            Copy-HetznerFileAtomicVerified -Source $candidate.Path -Destination $destination -ExpectedSha256 $hash -ExpectedBytes $bytes -Purpose preimage
        } elseif (Test-Path -LiteralPath $candidate.Path -PathType Container) { $kind='Directory' }
        $entries += [pscustomobject][ordered]@{ Index=$index; Path=$candidate.Path; Label=$candidate.Label; PreKind=$kind; PreSha256=$hash; PreBytes=$bytes; Preimage=$preimage }
        $index++
    }
    $journal = [pscustomobject][ordered]@{
        SchemaVersion=$script:SchemaVersion; TransactionVersion=$script:TransactionVersion; TransactionType=$script:TransactionType; TransactionId=[guid]::NewGuid().ToString('N')
        InstallRoot=$Paths.InstallRoot; FenceRoot=$Paths.FenceRoot; PlanFingerprint=[string]$Plan.PlanFingerprint
        SourceSnapshot=@($SourceSnapshot); SourceSnapshotFingerprint=(Get-HetznerSourceSnapshotFingerprint -SourceSnapshot $SourceSnapshot)
        State='Prepared'; Phase='Prepared'; OperationIndex=-1; Entries=$entries; JournalFingerprint=''
    }
    $journal.JournalFingerprint = Get-HetznerTransactionJournalFingerprint -Journal $journal
    return $journal
}

function Save-HetznerTransactionJournal {
    param([Parameter(Mandatory)]$Journal, [Parameter(Mandatory)]$Paths)
    Assert-HetznerTransactionJournal -Journal $Journal -Paths $Paths
    Write-HetznerAtomicJson -Path $Paths.JournalPath -Value $Journal
}

function Copy-HetznerPreimageToTarget {
    param([Parameter(Mandatory)][string]$Source, [Parameter(Mandatory)][string]$Target, [Parameter(Mandatory)][string]$ExpectedSha256, [Parameter(Mandatory)][int64]$ExpectedBytes)
    Copy-HetznerFileAtomicVerified -Source $Source -Destination $Target -ExpectedSha256 $ExpectedSha256 -ExpectedBytes $ExpectedBytes -Purpose recover
}

function Assert-HetznerRecoveryPreflight {
    param([Parameter(Mandatory)]$Journal, [Parameter(Mandatory)]$Paths)
    $missingTargets = @{}
    foreach ($entry in @($Journal.Entries)) {
        if ([string]$entry.PreKind -eq 'Missing') {
            $missingTargets[(Get-HetznerAbsolutePath ([string]$entry.Path)).ToLowerInvariant()] = $true
        }
    }
    if (Test-Path -LiteralPath $Paths.InstallRoot -PathType Container) {
        Assert-HetznerNoReparseTree -Root $Paths.InstallRoot -FenceRoot $Paths.FenceRoot
    } elseif (Test-Path -LiteralPath $Paths.InstallRoot -PathType Leaf) {
        Assert-HetznerNoReparsePoints -Path $Paths.InstallRoot -FenceRoot $Paths.FenceRoot | Out-Null
    }
    foreach ($entry in @($Journal.Entries)) {
        $target = Get-HetznerAbsolutePath ([string]$entry.Path)
        $kind = [string]$entry.PreKind
        if (Test-Path -LiteralPath $target) { Assert-HetznerNoReparsePoints -Path $target -FenceRoot $Paths.FenceRoot | Out-Null }
        if ($kind -eq 'File' -and (Test-Path -LiteralPath $target -PathType Container)) { throw "Recovery target changed from file to directory during preflight: $target" }
        if ($kind -eq 'Directory' -and (Test-Path -LiteralPath $target -PathType Leaf)) { throw "Recovery target changed from directory to file during preflight: $target" }
        if ($kind -eq 'Missing' -and (Test-Path -LiteralPath $target -PathType Container)) {
            foreach ($item in @(Get-ChildItem -LiteralPath $target -Force -Recurse -ErrorAction Stop)) {
                $itemKey = (Get-HetznerAbsolutePath $item.FullName).ToLowerInvariant()
                if (-not $missingTargets.ContainsKey($itemKey)) { throw "Recovery preflight found unexpected content in a previously absent path: $($item.FullName)" }
            }
        }
    }
}

function Remove-HetznerOwnedPromotionOrphans {
    param([Parameter(Mandatory)]$Journal, [Parameter(Mandatory)]$Paths)
    if (-not (Test-Path -LiteralPath $Paths.InstallRoot -PathType Container)) { return }
    Assert-HetznerNoReparseTree -Root $Paths.InstallRoot -FenceRoot $Paths.FenceRoot
    $pattern = '^\.(apply|recover)-[0-9a-f]{32}\.(tmp|bak)$'
    foreach ($item in @(Get-ChildItem -LiteralPath $Paths.InstallRoot -File -Force -Recurse -ErrorAction Stop)) {
        if ($item.Name -cnotmatch $pattern) { continue }
        $path = Get-HetznerAbsolutePath $item.FullName
        if (-not (Test-HetznerContainedPath -Path $path -Root $Paths.InstallRoot)) { throw 'Installer promotion orphan escaped the install root.' }
        Assert-HetznerNoReparsePoints -Path $path -FenceRoot $Paths.FenceRoot | Out-Null
        Remove-Item -LiteralPath $path -Force
    }
}

function Invoke-HetznerRecoverPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$InstallRoot,
        [Parameter(Mandatory)][string]$FenceRoot,
        [int]$FailAfterOperationIndex = -1
    )
    $paths=Get-HetznerTransactionPaths -InstallRoot $InstallRoot -FenceRoot $FenceRoot
    $lock=$null
    try {
        $lock=Enter-HetznerTransactionLock -Paths $paths
        $status=Get-HetznerTransactionStatus -InstallRoot $InstallRoot -FenceRoot $FenceRoot
        if($status.State -eq 'None'){throw 'No installer transaction journal exists for recovery.'}
        $journal=$status.Journal
        if($journal.State -in @('Committed','Recovered')){return [pscustomobject]@{State=[string]$journal.State;OperationIndex=[int]$journal.OperationIndex;InstallRoot=$paths.InstallRoot}}
        if($journal.State -in @('RollingBack','RolledBack')){throw 'Rollback transaction state must be resumed through RollbackPlan, not RecoverPlan.'}
        Remove-HetznerOwnedPromotionOrphans -Journal $journal -Paths $paths
        Assert-HetznerRecoveryPreflight -Journal $journal -Paths $paths
        $journal.State='Recovering'; $journal.Phase='Recovering'; Save-HetznerTransactionJournal -Journal $journal -Paths $paths
        $restoreIndex=0
        foreach($entry in @($journal.Entries)){
            $target=Get-HetznerAbsolutePath ([string]$entry.Path)
            if($target -ne $paths.InstallRoot -and -not(Test-HetznerContainedPath -Path $target -Root $paths.InstallRoot)){throw 'Transaction recovery entry escaped the install root.'}
            if([string]$entry.PreKind -eq 'File'){
                $source=Get-HetznerAbsolutePath (Join-Path $paths.TransactionRoot ([string]$entry.Preimage))
                if(-not(Test-HetznerContainedPath -Path $source -Root $paths.TransactionRoot) -or -not(Test-Path -LiteralPath $source -PathType Leaf)){throw 'Transaction recovery preimage is missing or escaped its root.'}
                Copy-HetznerPreimageToTarget -Source $source -Target $target -ExpectedSha256 ([string]$entry.PreSha256) -ExpectedBytes ([int64]$entry.PreBytes)
            } elseif([string]$entry.PreKind -eq 'Missing'){
                if(Test-Path -LiteralPath $target -PathType Leaf){Remove-Item -LiteralPath $target -Force}
            } elseif([string]$entry.PreKind -eq 'Directory'){
                if(Test-Path -LiteralPath $target -PathType Leaf){throw "Recovery target changed from directory to file: $target"}
                if(-not(Test-Path -LiteralPath $target -PathType Container)){New-Item -ItemType Directory -Path $target -Force|Out-Null}
            } else { throw 'Transaction recovery pre-state kind is invalid.' }
            $journal.OperationIndex=$restoreIndex; Save-HetznerTransactionJournal -Journal $journal -Paths $paths
            if($FailAfterOperationIndex -eq $restoreIndex){throw "Injected interruption failpoint: recovery operation $restoreIndex"}
            $restoreIndex++
        }
        $missingDirectories=@($journal.Entries | Where-Object { [string]$_.PreKind -eq 'Missing' -and (Test-Path -LiteralPath ([string]$_.Path) -PathType Container) } | Sort-Object { ([string]$_.Path).Length } -Descending)
        foreach($entry in $missingDirectories){
            $target=[string]$entry.Path
            if(@(Get-ChildItem -LiteralPath $target -Force).Count -ne 0){throw "Recovery preserved unexpected content in a previously absent path: $target"}
            Remove-Item -LiteralPath $target -Force
        }
        foreach($entry in @($journal.Entries)){
            $target=[string]$entry.Path
            if([string]$entry.PreKind -eq 'Missing' -and (Test-Path -LiteralPath $target)){throw "Recovery did not restore absent pre-state: $target"}
            if([string]$entry.PreKind -eq 'Directory' -and -not(Test-Path -LiteralPath $target -PathType Container)){throw "Recovery did not restore directory pre-state: $target"}
            if([string]$entry.PreKind -eq 'File'){
                if(-not(Test-Path -LiteralPath $target -PathType Leaf) -or (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant() -ne [string]$entry.PreSha256 -or [int64](Get-Item -LiteralPath $target).Length -ne [int64]$entry.PreBytes){throw "Recovery did not restore file pre-state: $target"}
            }
        }
        $journal.State='Recovered'; $journal.Phase='Recovered'; Save-HetznerTransactionJournal -Journal $journal -Paths $paths
        return [pscustomobject]@{State='Recovered';OperationIndex=[int]$journal.OperationIndex;InstallRoot=$paths.InstallRoot}
    } finally { if($null -ne $lock){$lock.Dispose()} }
}

function Write-HetznerOwnershipSeal {
    param([Parameter(Mandatory)][string]$InstallRoot)
    $meta = Join-Path $InstallRoot '.hetzner-installer'
    $manifestPath = Join-Path $meta 'manifest.json'; $receiptPath = Join-Path $meta 'receipt.json'
    $seal = [pscustomobject][ordered]@{
        SchemaVersion = $script:SchemaVersion; SealType = 'manifest-receipt-external-anchor-v1'
        ManifestSha256 = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant(); ManifestBytes = [int64](Get-Item -LiteralPath $manifestPath).Length
        ReceiptSha256 = (Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash.ToLowerInvariant(); ReceiptBytes = [int64](Get-Item -LiteralPath $receiptPath).Length
    }
    Write-HetznerJson -Path (Join-Path $meta 'ownership-seal.json') -Value $seal
}

function Assert-HetznerOwnershipSeal {
    param([Parameter(Mandatory)][string]$InstallRoot)
    $meta = Join-Path $InstallRoot '.hetzner-installer'; $sealPath = Join-Path $meta 'ownership-seal.json'
    $manifestPath = Join-Path $meta 'manifest.json'; $receiptPath = Join-Path $meta 'receipt.json'
    if (-not (Test-Path -LiteralPath $sealPath -PathType Leaf)) { throw 'External ownership metadata seal is required.' }
    $seal = Get-Content -LiteralPath $sealPath -Raw | ConvertFrom-Json
    if ([int]$seal.SchemaVersion -ne $script:SchemaVersion -or [string]$seal.SealType -ne 'manifest-receipt-external-anchor-v1') { throw 'External ownership metadata seal identity mismatch.' }
    $manifestHash = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant(); $receiptHash = (Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $manifestBytes = [int64](Get-Item -LiteralPath $manifestPath).Length; $receiptBytes = [int64](Get-Item -LiteralPath $receiptPath).Length
    if ([string]$seal.ManifestSha256 -ne $manifestHash -or [int64]$seal.ManifestBytes -ne $manifestBytes -or [string]$seal.ReceiptSha256 -ne $receiptHash -or [int64]$seal.ReceiptBytes -ne $receiptBytes) { throw 'Manifest/receipt managed metadata joint rewrite rejected by external ownership seal.' }
    return [pscustomobject][ordered]@{ Path = '.hetzner-installer\ownership-seal.json'; Sha256 = (Get-FileHash -LiteralPath $sealPath -Algorithm SHA256).Hash.ToLowerInvariant(); Bytes = [int64](Get-Item -LiteralPath $sealPath).Length }
}

function Assert-HetznerPlanOperationFence {
    param([Parameter(Mandatory)]$Plan)
    $install = Get-HetznerAbsolutePath $Plan.InstallRoot
    $source = Get-HetznerAbsolutePath $Plan.SourceRoot
    foreach ($operation in @($Plan.Operations)) {
        if ([string]::IsNullOrWhiteSpace([string]$operation.TargetPath) -or -not (Test-HetznerContainedPath -Path $operation.TargetPath -Root $install)) { throw "Managed operation target must remain below the install root: $($operation.RelativePath)" }
        $relativeTarget = Assert-HetznerSafeRelativePath -RelativePath ([string]$operation.RelativePath) -InstallRoot $install
        if ((Get-HetznerAbsolutePath $operation.TargetPath) -ne $relativeTarget) { throw "Managed operation target does not match its safe relative path: $($operation.RelativePath)" }
        if ($operation.Kind -in @('CopyFile')) {
            if ([string]::IsNullOrWhiteSpace([string]$operation.SourcePath) -or -not (Test-HetznerContainedPath -Path $operation.SourcePath -Root $source)) { throw "Managed source path must remain below the source root: $($operation.RelativePath)" }
        } elseif ($operation.Kind -eq 'CopyMissionPbo' -and (Get-HetznerAbsolutePath $operation.SourcePath) -ne (Get-HetznerAbsolutePath $Plan.MissionPboPath)) {
            throw 'Mission PBO source path was tampered.'
        }
    }
}

function Assert-HetznerCanonicalApplyPlan {
    param(
        [Parameter(Mandatory)]$Plan,
        [Parameter(Mandatory)]$Profile,
        [Parameter(Mandatory)]$Pbo
    )
    if ($Plan.PSObject.Properties.Name -notcontains 'AdoptionPolicy') { throw 'Apply plan adoption policy is missing.' }
    $recordedFingerprint = Get-HetznerPlanFingerprint -SourceRoot $Plan.SourceRoot -InstallRoot $Plan.InstallRoot -FenceRoot $Plan.FenceRoot -ProfileName $Plan.ProfileName -MissionPboPath $Plan.MissionPboPath -MissionPboSha256 $Plan.MissionPboSha256 -SourceFiles @($Plan.SourceFiles) -CanonicalOperationDescriptors @($Plan.CanonicalOperationDescriptors) -AdoptionPolicy @($Plan.AdoptionPolicy)
    if ([string]$Plan.PlanFingerprint -cne $recordedFingerprint) { throw 'Apply plan fingerprint or canonical descriptors were tampered.' }

    $currentSourceFiles = @(Get-HetznerSourceFileRecords -SourceRoot $Plan.SourceRoot)
    $recordedSourceJson = @($Plan.SourceFiles) | ConvertTo-Json -Depth 8 -Compress
    $currentSourceJson = $currentSourceFiles | ConvertTo-Json -Depth 8 -Compress
    if ($recordedSourceJson -cne $currentSourceJson) { throw 'Source config hash drift detected after planning; create a fresh plan.' }

    $canonicalOperations = @(New-HetznerCanonicalOperations -SourceRoot $Plan.SourceRoot -InstallRoot $Plan.InstallRoot -Profile $Profile -ProfileName $Plan.ProfileName -Pbo $Pbo)
    $canonicalDescriptors = @(Get-HetznerOperationDescriptors -Operations $canonicalOperations)
    $recordedDescriptorJson = @($Plan.CanonicalOperationDescriptors) | ConvertTo-Json -Depth 8 -Compress
    $canonicalDescriptorJson = $canonicalDescriptors | ConvertTo-Json -Depth 8 -Compress
    if ($recordedDescriptorJson -cne $canonicalDescriptorJson) { throw 'Recorded canonical operation descriptors no longer match the re-derived plan.' }

    $actualDescriptors = @(Get-HetznerOperationDescriptors -Operations @($Plan.Operations))
    $actualDescriptorJson = $actualDescriptors | ConvertTo-Json -Depth 8 -Compress
    if ($actualDescriptorJson -cne $canonicalDescriptorJson) { throw 'Apply operation kind, order, target, source, or content drifted from the canonical plan.' }

    $requestedPolicy = @($Plan.AdoptionPolicy | ForEach-Object { [pscustomobject][ordered]@{ Path=[string]$_.Path; Disposition=[string]$_.Disposition } })
    $currentPolicy = @(Get-HetznerCanonicalAdoptionPolicy -AdoptionPolicy $requestedPolicy -Operations $canonicalOperations -InstallRoot $Plan.InstallRoot -FenceRoot $Plan.FenceRoot)
    if ((ConvertTo-Json -InputObject @($Plan.AdoptionPolicy) -Depth 10 -Compress) -cne (ConvertTo-Json -InputObject @($currentPolicy) -Depth 10 -Compress)) { throw 'Apply plan adoption policy or host preimage drifted after planning.' }
}

function Assert-HetznerApplyPlanState {
    param([Parameter(Mandatory)]$Plan)
    if ([int]$Plan.SchemaVersion -ne $script:SchemaVersion -or [string]$Plan.Action -ne 'ApplyPlan') { throw 'Apply plan action or schema was tampered.' }
    $install = Test-HetznerInstallPath -Path $Plan.InstallRoot -FenceRoot $Plan.FenceRoot
    $profile = Get-HetznerInstallerProfile -Name $Plan.ProfileName
    $pbo = Get-HetznerMissionPboInfo -MissionPboPath $Plan.MissionPboPath
    if ($pbo.Leaf -ne $Plan.MissionPboLeaf -or $pbo.Sha256 -ne $Plan.MissionPboSha256) { throw 'Mission PBO changed after planning; create a fresh plan.' }
    $expected = Get-HetznerExpectedManagedPaths -Profile $profile -MissionPboLeaf $pbo.Leaf
    Assert-HetznerExactPathSet -Actual $Plan.ExpectedManagedPaths -Expected $expected -Label 'Apply plan managed set'
    if ([int]$Plan.HeadlessClients -ne [int]$profile.headlessClients -or [bool]$Plan.Operational -ne [bool]$profile.operational -or [string]$Plan.Topology -ne [string]$profile.topology -or [string]$Plan.SteamIsolationAdapter -ne [string]$profile.steamIsolationAdapter) { throw 'Apply plan profile topology was tampered.' }
    $expectedIdentities = Get-HetznerExpectedLauncherIdentities -Profile $profile -ProfileName $Plan.ProfileName
    if ([int]$profile.headlessClients -gt 0) { Assert-HetznerLauncherIdentitySet -Actual $Plan.LauncherIdentities -Expected $expectedIdentities -Label 'Apply plan' }
    Assert-HetznerCanonicalApplyPlan -Plan $Plan -Profile $profile -Pbo $pbo
    Assert-HetznerPlanOperationFence -Plan $Plan
    Assert-HetznerNoReparsePoints -Path $install -FenceRoot $Plan.FenceRoot | Out-Null
}

function Get-HetznerPriorManagedRecords {
    param([Parameter(Mandatory)][string]$InstallRoot, [Parameter(Mandatory)][string]$FenceRoot, [switch]$AllowUnowned)
    if (-not (Test-Path -LiteralPath $InstallRoot -PathType Container)) { return @() }
    $manifestPath = Join-Path $InstallRoot '.hetzner-installer\manifest.json'
    $receiptPath = Join-Path $InstallRoot '.hetzner-installer\receipt.json'
    $sealPath = Join-Path $InstallRoot '.hetzner-installer\ownership-seal.json'
    $manifestExists = Test-Path -LiteralPath $manifestPath -PathType Leaf
    $receiptExists = Test-Path -LiteralPath $receiptPath -PathType Leaf
    $sealExists = Test-Path -LiteralPath $sealPath -PathType Leaf
    if (-not $manifestExists -and -not $receiptExists -and -not $sealExists) {
        if (@(Get-ChildItem -LiteralPath $InstallRoot -Force).Count -eq 0) { return @() }
        if ($AllowUnowned) { return @() }
        throw 'Non-empty existing install has no complete installer ownership metadata; adoption is not implemented.'
    }
    if (-not $manifestExists -or -not $receiptExists -or -not $sealExists) { throw 'Existing installer metadata is incomplete; refusing stale-file cleanup.' }
    Assert-HetznerOwnershipSeal -InstallRoot $InstallRoot | Out-Null
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
    if ([string]$receipt.ReceiptType -ne 'offline-staging-foundation') { throw 'Existing receipt type does not prove installer ownership.' }
    $priorPbo = [pscustomobject]@{ Leaf = [string]$manifest.MissionPboLeaf; Sha256 = [string]$manifest.MissionPboSha256 }
    $records = @(Assert-HetznerManifestContract -Manifest $manifest -Receipt $receipt -InstallRoot $InstallRoot -ProfileName ([string]$manifest.ProfileName) -Pbo $priorPbo -FenceRoot $FenceRoot)
    $pboRelativePath = "mpmissions\$($priorPbo.Leaf)"
    $pboRecord = @($records | Where-Object { [string]$_.Path -eq $pboRelativePath })[0]
    if ($null -eq $pboRecord -or [string]$pboRecord.Sha256 -ne $priorPbo.Sha256) { throw 'Existing manifest PBO record does not prove installer ownership.' }
    foreach ($record in $records) {
        $path = Assert-HetznerSafeRelativePath -RelativePath ([string]$record.Path) -InstallRoot $InstallRoot
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Existing installer-owned file is missing; adoption is not implemented: $($record.Path)" }
        $actualHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -ne ([string]$record.Sha256).ToLowerInvariant()) { throw "Existing installer-owned file was modified; adoption is not implemented: $($record.Path)" }
    }
    return @($records)
}

function Get-HetznerPriorOwnershipDecisions {
    param([Parameter(Mandatory)][string]$InstallRoot)
    $manifestPath = Join-Path $InstallRoot '.hetzner-installer\manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { return @() }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ($manifest.PSObject.Properties.Name -notcontains 'OwnershipDecisions') { throw 'Existing manifest ownership decisions are missing.' }
    return @($manifest.OwnershipDecisions)
}

function New-HetznerResolvedOwnershipDecisions {
    param([Parameter(Mandatory)]$Plan,[Parameter(Mandatory)]$Journal,[Parameter(Mandatory)]$Paths)
    $resolved=@()
    foreach($decision in @($Plan.AdoptionPolicy)){
        $record=[ordered]@{Path=[string]$decision.Path;Disposition=[string]$decision.Disposition;PreSha256=[string]$decision.PreSha256;PreBytes=[int64]$decision.PreBytes;PostSha256=[string]$decision.PostSha256;PostBytes=[int64]$decision.PostBytes;Owner=[string]$decision.Owner;RollbackDisposition=[string]$decision.RollbackDisposition;UninstallDisposition=[string]$decision.UninstallDisposition;BackupPath='';BackupSha256='';BackupBytes=[int64]0}
        if([string]$decision.Disposition -eq 'ReplaceWithBackup'){
            $target=Assert-HetznerSafeRelativePath -RelativePath ([string]$decision.Path) -InstallRoot $Paths.InstallRoot
            $entry=@($Journal.Entries|Where-Object{(Get-HetznerAbsolutePath ([string]$_.Path)) -eq $target})
            if($entry.Count-ne 1 -or [string]$entry[0].PreKind -ne 'File' -or [string]$entry[0].PreSha256 -cne [string]$decision.PreSha256 -or [int64]$entry[0].PreBytes -ne [int64]$decision.PreBytes){throw "ReplaceWithBackup transaction preimage identity mismatch: $($decision.Path)"}
            $source=Get-HetznerAbsolutePath (Join-Path $Paths.TransactionRoot ([string]$entry[0].Preimage))
            $backupRoot=Join-Path $Paths.TransactionRoot 'a'
            $backupPath=Join-Path $backupRoot ('{0:d4}.bin' -f [int]$entry[0].Index)
            if(-not(Test-HetznerContainedPath -Path $backupPath -Root $backupRoot)){throw 'Adoption backup path escaped its external transaction root.'}
            Copy-HetznerFileAtomicVerified -Source $source -Destination $backupPath -ExpectedSha256 ([string]$decision.PreSha256) -ExpectedBytes ([int64]$decision.PreBytes) -Purpose preimage
            $record.BackupPath=Get-HetznerAbsolutePath $backupPath;$record.BackupSha256=[string]$decision.PreSha256;$record.BackupBytes=[int64]$decision.PreBytes
        }
        $resolved += [pscustomobject]$record
    }
    return @($resolved|Sort-Object Path)
}

function Invoke-HetznerPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Plan,
        [switch]$Apply,
        [string]$FailAfterCheckpoint = '',
        [int]$FailAfterOperationIndex = -1
    )
    $allowedCheckpoints=@('AfterPrepared','BeforeFirstCopyPromotion','AfterManagedOperations','AfterManifest','AfterReceipt','AfterSeal','BeforeCommit','AfterCommit')
    if(-not[string]::IsNullOrWhiteSpace($FailAfterCheckpoint) -and $FailAfterCheckpoint -notin $allowedCheckpoints){throw 'Unknown installer transaction failpoint.'}
    Assert-HetznerApplyPlanState -Plan $Plan
    if (-not $Apply) { return [pscustomobject]@{ Applied = $false; Action = $Plan.Action; InstallRoot = $Plan.InstallRoot; Operations = @($Plan.Operations | Select-Object Kind,RelativePath); Operational = $Plan.Operational; Topology = $Plan.Topology } }
    Assert-HetznerApplyPlanState -Plan $Plan
    $canonicalProfile = Get-HetznerInstallerProfile -Name $Plan.ProfileName
    $canonicalPbo = Get-HetznerMissionPboInfo -MissionPboPath $Plan.MissionPboPath
    $canonicalOperations = @(New-HetznerCanonicalOperations -SourceRoot $Plan.SourceRoot -InstallRoot $Plan.InstallRoot -Profile $canonicalProfile -ProfileName $Plan.ProfileName -Pbo $canonicalPbo)
    $paths=Get-HetznerTransactionPaths -InstallRoot $Plan.InstallRoot -FenceRoot $Plan.FenceRoot
    $lock=$null
    try {
        $lock=Enter-HetznerTransactionLock -Paths $paths
        $status=Get-HetznerTransactionStatus -InstallRoot $Plan.InstallRoot -FenceRoot $Plan.FenceRoot
        if($status.State -notin @('None','Committed','Recovered','RolledBack','Uninstalled')){throw "A nonterminal installer transaction requires recovery before Apply: $($status.State)"}
        if($status.State -eq 'RolledBack'){
            $rolledBackJournal=$status.Journal
            if($rolledBackJournal.PSObject.Properties.Name -notcontains 'RollbackContract'){throw 'Rolled-back transaction journal lost its sealed rollback contract.'}
            $rolledBackContract=$rolledBackJournal.RollbackContract
            $finalRollbackIndex=@($rolledBackContract.Actions).Count-1
            if([string]$rolledBackJournal.Phase -cne 'RolledBack' -or [int]$rolledBackJournal.OperationIndex -ne $finalRollbackIndex){throw 'Rolled-back transaction progress marker is inconsistent.'}
            Assert-HetznerRollbackProgressPreflight -Contract $rolledBackContract -Journal $rolledBackJournal -Paths $paths -CompletedOperationIndex $finalRollbackIndex
        }
        if($status.State -eq 'Uninstalled'){
            $uninstalledJournal=$status.Journal
            if($uninstalledJournal.PSObject.Properties.Name -notcontains 'UninstallContract'){throw 'Uninstalled transaction journal lost its sealed uninstall contract.'}
            $uninstalledContract=$uninstalledJournal.UninstallContract
            $finalUninstallIndex=@($uninstalledContract.Actions).Count-1
            if([string]$uninstalledJournal.Phase -cne 'Uninstalled' -or [int]$uninstalledJournal.OperationIndex -ne $finalUninstallIndex){throw 'Uninstalled transaction progress marker is inconsistent.'}
            Assert-HetznerUninstallProgressPreflight -Contract $uninstalledContract -Paths $paths -CompletedOperationIndex $finalUninstallIndex
        }
        if (Test-Path -LiteralPath $Plan.InstallRoot -PathType Container) { Assert-HetznerNoReparseTree -Root $Plan.InstallRoot -FenceRoot $Plan.FenceRoot }
        $prior = @(Get-HetznerPriorManagedRecords -InstallRoot $Plan.InstallRoot -FenceRoot $Plan.FenceRoot -AllowUnowned)
        $priorOwnership = @(Get-HetznerPriorOwnershipDecisions -InstallRoot $Plan.InstallRoot)
        foreach ($decision in $priorOwnership) {
            if([string]$decision.Disposition -eq 'ReplaceWithBackup'){throw "A committed host replacement must be restored or uninstalled before another Apply: $($decision.Path)"}
            if (@($Plan.AdoptionPolicy | Where-Object { [string]$_.Path -ceq [string]$decision.Path }).Count -ne 1) { throw "Existing host-adopted path requires an explicit policy on every Apply: $($decision.Path)" }
        }
        foreach ($operation in @($canonicalOperations | Where-Object { $_.Kind -in @('CopyFile','CopyMissionPbo','GenerateLauncher') })) {
            if (-not (Test-Path -LiteralPath $operation.TargetPath -PathType Leaf)) { continue }
            $old = @($prior | Where-Object { [string]$_.Path -ceq [string]$operation.RelativePath })[0]
            if ($null -eq $old -and @($Plan.AdoptionPolicy | Where-Object { [string]$_.Path -ceq [string]$operation.RelativePath }).Count -ne 1) {
                throw "Existing host path requires explicit per-path adoption policy before mutation: $($operation.RelativePath)"
            }
        }
        foreach ($operation in @($canonicalOperations | Where-Object { $_.Kind -eq 'DeleteStaleLauncher' })) {
            if (Test-Path -LiteralPath $operation.TargetPath -PathType Leaf) {
                $preservePolicy = @($Plan.AdoptionPolicy | Where-Object { [string]$_.Path -ceq [string]$operation.RelativePath -and [string]$_.Disposition -ceq 'PreserveHost' })
                if ($preservePolicy.Count -eq 1) { continue }
                $old = @($prior | Where-Object { $_.Path -eq $operation.RelativePath })[0]
                if ($null -eq $old -or (Get-FileHash -LiteralPath $operation.TargetPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne ([string]$old.Sha256).ToLowerInvariant()) {
                    throw "Apply refused before mutation because a stale launcher is not proven installer-owned: $($operation.RelativePath)"
                }
            }
        }
        $sourceSnapshot = @(New-HetznerSourceSnapshot -Plan $Plan -Paths $paths)
        $executionOperations = @(Get-HetznerSnapshotBackedOperations -Operations $canonicalOperations -SourceSnapshot $sourceSnapshot)
        $journal=New-HetznerTransactionJournal -Plan $Plan -Operations $executionOperations -Paths $paths -SourceSnapshot $sourceSnapshot
        Save-HetznerTransactionJournal -Journal $journal -Paths $paths
        Invoke-HetznerInjectedFailpoint -Requested $FailAfterCheckpoint -Checkpoint 'AfterPrepared'
        Assert-HetznerSourceSnapshotContract -Journal $journal -Paths $paths -VerifyFiles
        $resolvedOwnershipDecisions=@(New-HetznerResolvedOwnershipDecisions -Plan $Plan -Journal $journal -Paths $paths)
        $journal.State='Applying'; $journal.Phase='ManagedOperations'; Save-HetznerTransactionJournal -Journal $journal -Paths $paths
        $preservedStale = @(); $operationIndex=0; $copyPromotionSeen=$false
        foreach ($operation in $executionOperations) {
            Assert-HetznerNoReparsePoints -Path $operation.TargetPath -FenceRoot $Plan.FenceRoot | Out-Null
            if ($operation.Kind -eq 'EnsureDirectory') {
                New-Item -ItemType Directory -Path $operation.TargetPath -Force | Out-Null
            } elseif ($operation.Kind -eq 'DeleteStaleLauncher') {
                if (Test-Path -LiteralPath $operation.TargetPath -PathType Leaf) {
                    $preservePolicy = @($Plan.AdoptionPolicy | Where-Object { [string]$_.Path -ceq [string]$operation.RelativePath -and [string]$_.Disposition -ceq 'PreserveHost' })
                    if ($preservePolicy.Count -eq 1) { $preservedStale += $operation.RelativePath }
                    else {
                        $old = @($prior | Where-Object { $_.Path -eq $operation.RelativePath })[0]
                        if ($old -and (Get-FileHash -LiteralPath $operation.TargetPath -Algorithm SHA256).Hash.ToLowerInvariant() -eq ([string]$old.Sha256).ToLowerInvariant()) {
                            Remove-Item -LiteralPath $operation.TargetPath -Force
                        } else { $preservedStale += $operation.RelativePath }
                    }
                }
            } elseif ($operation.Kind -in @('CopyFile','CopyMissionPbo')) {
                if (-not (Test-Path -LiteralPath $operation.TargetPath -PathType Leaf) -or ((Get-FileHash -LiteralPath $operation.SourcePath -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $operation.TargetPath -Algorithm SHA256).Hash)) {
                    $snapshotRecord = @($journal.SourceSnapshot | Where-Object { (Get-HetznerAbsolutePath ([string]$_.SnapshotPath)) -eq (Get-HetznerAbsolutePath ([string]$operation.SourcePath)) })
                    if ($snapshotRecord.Count -ne 1) { throw "Managed copy has no unique journal-bound snapshot identity: $($operation.RelativePath)" }
                    $failBeforePromotion = -not $copyPromotionSeen -and $FailAfterCheckpoint -eq 'BeforeFirstCopyPromotion'
                    $copyPromotionSeen = $true
                    Copy-HetznerFileAtomicVerified -Source $operation.SourcePath -Destination $operation.TargetPath -ExpectedSha256 ([string]$snapshotRecord[0].Sha256) -ExpectedBytes ([int64]$snapshotRecord[0].Bytes) -Purpose apply -FailBeforePromotion:$failBeforePromotion
                }
            } elseif ($operation.Kind -eq 'GenerateLauncher') {
                $write = $true
                if (Test-Path -LiteralPath $operation.TargetPath -PathType Leaf) { $write = ([System.IO.File]::ReadAllText($operation.TargetPath) -ne $operation.Content) }
                if ($write) { [System.IO.File]::WriteAllText($operation.TargetPath, $operation.Content, (New-Object System.Text.UTF8Encoding($false))) }
            }
            $journal.OperationIndex=$operationIndex; Save-HetznerTransactionJournal -Journal $journal -Paths $paths
            if($FailAfterOperationIndex -eq $operationIndex){throw "Injected interruption failpoint: apply operation $operationIndex"}
            $operationIndex++
        }
        Invoke-HetznerInjectedFailpoint -Requested $FailAfterCheckpoint -Checkpoint 'AfterManagedOperations'
        $records = Get-HetznerManagedFileRecords -Operations $executionOperations
        $manifest = [pscustomobject]@{
            SchemaVersion = $script:SchemaVersion; ProfileName = $Plan.ProfileName; HeadlessClients = $Plan.HeadlessClients
            Operational = $Plan.Operational; Topology = $Plan.Topology; SteamIsolationAdapter = $Plan.SteamIsolationAdapter
            MissionPboLeaf = $Plan.MissionPboLeaf; MissionPboSha256 = $Plan.MissionPboSha256
            LauncherIdentities = $Plan.LauncherIdentities; ManagedFiles = $records; OwnershipDecisions = $resolvedOwnershipDecisions
        }
        $meta = Join-Path $Plan.InstallRoot '.hetzner-installer'
        Write-HetznerJson -Path (Join-Path $meta 'manifest.json') -Value $manifest
        $journal.Phase='Manifest'; $journal.OperationIndex=$operationIndex; Save-HetznerTransactionJournal -Journal $journal -Paths $paths
        Invoke-HetznerInjectedFailpoint -Requested $FailAfterCheckpoint -Checkpoint 'AfterManifest'
        $receipt = [pscustomobject]@{
            SchemaVersion = $script:SchemaVersion; ReceiptType = 'offline-staging-foundation'; ProfileName = $Plan.ProfileName
            HeadlessClients = $Plan.HeadlessClients; Operational = $Plan.Operational; Topology = $Plan.Topology
            SteamIsolationAdapter = $Plan.SteamIsolationAdapter; MissionPboLeaf = $Plan.MissionPboLeaf
            MissionPboSha256 = $Plan.MissionPboSha256; LauncherIdentities = $Plan.LauncherIdentities; ManagedFiles = $records; OwnershipDecisions = $resolvedOwnershipDecisions
        }
        Write-HetznerJson -Path (Join-Path $meta 'receipt.json') -Value $receipt
        $journal.Phase='Receipt'; $journal.OperationIndex=$operationIndex+1; Save-HetznerTransactionJournal -Journal $journal -Paths $paths
        Invoke-HetznerInjectedFailpoint -Requested $FailAfterCheckpoint -Checkpoint 'AfterReceipt'
        Write-HetznerOwnershipSeal -InstallRoot $Plan.InstallRoot
        $journal|Add-Member -NotePropertyName CommitContract -NotePropertyValue (New-HetznerCommitContract -InstallRoot $Plan.InstallRoot) -Force
        $journal.JournalFingerprint=Get-HetznerTransactionJournalFingerprint -Journal $journal
        $journal.Phase='Seal'; $journal.OperationIndex=$operationIndex+2; Save-HetznerTransactionJournal -Journal $journal -Paths $paths
        Invoke-HetznerInjectedFailpoint -Requested $FailAfterCheckpoint -Checkpoint 'AfterSeal'
        $journal.Phase='BeforeCommit'; Save-HetznerTransactionJournal -Journal $journal -Paths $paths
        Invoke-HetznerInjectedFailpoint -Requested $FailAfterCheckpoint -Checkpoint 'BeforeCommit'
        $journal.State='Committed'; $journal.Phase='Committed'; Save-HetznerTransactionJournal -Journal $journal -Paths $paths
        Invoke-HetznerInjectedFailpoint -Requested $FailAfterCheckpoint -Checkpoint 'AfterCommit'
        return [pscustomobject]@{ Applied = $true; Action = $Plan.Action; InstallRoot = $Plan.InstallRoot; ManagedFiles = $records; OwnershipDecisions=$resolvedOwnershipDecisions; PreservedStale = $preservedStale; Operational = $Plan.Operational; Topology = $Plan.Topology; TransactionState='Committed' }
    } finally { if($null -ne $lock){$lock.Dispose()} }
}

function Get-HetznerOwnershipDecisionProjection {
    param(
        [AllowEmptyCollection()][object[]]$Decisions = @(),
        [Parameter(Mandatory)][string]$InstallRoot,
        [Parameter(Mandatory)][string[]]$ExpectedManagedPaths,
        [string]$FenceRoot = ''
    )
    $result=@(); $seen=@{}
    foreach($decision in @($Decisions)) {
        foreach($required in @('Path','Disposition','PreSha256','PreBytes','PostSha256','PostBytes','Owner','RollbackDisposition','UninstallDisposition','BackupPath','BackupSha256','BackupBytes')) {
            if($null -eq $decision -or $decision.PSObject.Properties.Name -notcontains $required){throw "Ownership decision is missing required field $required."}
        }
        $path=[string]$decision.Path; Assert-HetznerSafeRelativePath -RelativePath $path -InstallRoot $InstallRoot | Out-Null
        $isManaged=$ExpectedManagedPaths -ccontains $path
        $isStaleLauncher=$path -in @('hc1_launch.cmd','hc2_launch.cmd','hc3_launch.cmd') -and -not $isManaged
        if(-not $isManaged -and -not $isStaleLauncher){throw "Ownership decision path is not in the canonical managed or stale-launcher set: $path"}
        $key=$path.ToLowerInvariant(); if($seen.ContainsKey($key)){throw "Duplicate ownership decision path: $path"};$seen[$key]=$true
        if([string]$decision.PreSha256 -cnotmatch '^[0-9a-f]{64}$' -or [string]$decision.PostSha256 -cnotmatch '^[0-9a-f]{64}$' -or [int64]$decision.PreBytes -lt 0 -or [int64]$decision.PostBytes -lt 0){throw "Ownership decision hash or byte identity is invalid: $path"}
        $backupPath='';$backupHash='';$backupBytes=[int64]0
        if([string]$decision.Disposition -ceq 'ReplaceWithBackup'){
            if(-not$isManaged -or [string]$decision.Owner -cne 'InstallerReplacingHost' -or [string]$decision.RollbackDisposition -cne 'RestoreBackup' -or [string]$decision.UninstallDisposition -cne 'RestoreBackup'){throw "ReplaceWithBackup ownership semantics are invalid: $path"}
            if([string]$decision.PreSha256 -ceq [string]$decision.PostSha256 -and [int64]$decision.PreBytes -eq [int64]$decision.PostBytes){throw "ReplaceWithBackup did not change its postimage: $path"}
            $backupPath=Get-HetznerAbsolutePath ([string]$decision.BackupPath);$backupHash=[string]$decision.BackupSha256;$backupBytes=[int64]$decision.BackupBytes
            $fence=if([string]::IsNullOrWhiteSpace($FenceRoot)){Split-Path -Parent (Get-HetznerAbsolutePath $InstallRoot)}else{Get-HetznerAbsolutePath $FenceRoot};$paths=Get-HetznerTransactionPaths -InstallRoot $InstallRoot -FenceRoot $fence;$backupRoot=Join-Path $paths.TransactionRoot 'a'
            if(-not(Test-HetznerContainedPath -Path $backupPath -Root $backupRoot) -or $backupHash -cne [string]$decision.PreSha256 -or $backupBytes -ne [int64]$decision.PreBytes){throw "ReplaceWithBackup external preimage identity is invalid: $path"}
            if(-not(Test-Path -LiteralPath $backupPath -PathType Leaf)){throw "ReplaceWithBackup external preimage is missing: $path"}
            Assert-HetznerNoReparsePoints -Path $backupPath -FenceRoot $paths.FenceRoot|Out-Null
            if((Get-FileHash -LiteralPath $backupPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $backupHash -or [int64](Get-Item -LiteralPath $backupPath).Length -ne $backupBytes){throw "ReplaceWithBackup external preimage hash or bytes changed: $path"}
            $owner='InstallerReplacingHost';$rollback='RestoreBackup';$uninstall='RestoreBackup'
        }else{
            if([string]$decision.PreSha256 -cne [string]$decision.PostSha256 -or [int64]$decision.PreBytes -ne [int64]$decision.PostBytes){throw "Host-preserving ownership decision changed its postimage: $path"}
            if([string]$decision.RollbackDisposition -cne 'PreserveHost' -or [string]$decision.UninstallDisposition -cne 'PreserveHost' -or -not[string]::IsNullOrEmpty([string]$decision.BackupPath) -or -not[string]::IsNullOrEmpty([string]$decision.BackupSha256) -or [int64]$decision.BackupBytes -ne 0){throw "Ownership decision preserve dispositions or backup fields are invalid: $path"}
            if([string]$decision.Disposition -ceq 'AdoptUnchanged' -and $isManaged -and [string]$decision.Owner -ceq 'HostAdopted'){$owner='HostAdopted'}
            elseif([string]$decision.Disposition -ceq 'PreserveHost' -and $isStaleLauncher -and [string]$decision.Owner -ceq 'Host'){$owner='Host'}
            else{throw "Ownership decision semantics are invalid: $path"}
            $rollback='PreserveHost';$uninstall='PreserveHost'
        }
        $result += [pscustomobject][ordered]@{Path=$path;Disposition=[string]$decision.Disposition;PreSha256=[string]$decision.PreSha256;PreBytes=[int64]$decision.PreBytes;PostSha256=[string]$decision.PostSha256;PostBytes=[int64]$decision.PostBytes;Owner=$owner;RollbackDisposition=$rollback;UninstallDisposition=$uninstall;BackupPath=$backupPath;BackupSha256=$backupHash;BackupBytes=$backupBytes}
    }
    return @($result|Sort-Object Path)
}

function Assert-HetznerManifestContract {
    param(
        [Parameter(Mandatory)]$Manifest,
        [Parameter(Mandatory)]$Receipt,
        [Parameter(Mandatory)][string]$InstallRoot,
        [Parameter(Mandatory)][string]$ProfileName,
        [Parameter(Mandatory)]$Pbo,
        [string]$FenceRoot = ''
    )
    $profile = Get-HetznerInstallerProfile -Name $ProfileName
    $expected = Get-HetznerExpectedManagedPaths -Profile $profile -MissionPboLeaf $Pbo.Leaf
    $m = @($Manifest.ManagedFiles)
    $r = @($Receipt.ManagedFiles)
    if ([string]$Receipt.ReceiptType -ne 'offline-staging-foundation') { throw 'Receipt type does not prove installer ownership.' }
    if($Manifest.PSObject.Properties.Name -notcontains 'OwnershipDecisions' -or $Receipt.PSObject.Properties.Name -notcontains 'OwnershipDecisions'){throw 'Manifest and receipt ownership decisions are required.'}
    Assert-HetznerExactPathSet -Actual @($m | ForEach-Object { [string]$_.Path }) -Expected $expected -Label 'Manifest managed set'
    Assert-HetznerExactPathSet -Actual @($r | ForEach-Object { [string]$_.Path }) -Expected $expected -Label 'Receipt managed set'
    if ([string]$Manifest.ProfileName -ne $ProfileName -or [string]$Receipt.ProfileName -ne $ProfileName) { throw 'Manifest profile identity mismatch.' }
    if ([int]$Manifest.SchemaVersion -ne $script:SchemaVersion -or [int]$Receipt.SchemaVersion -ne $script:SchemaVersion) { throw 'Manifest or receipt schema mismatch.' }
    if ([string]$Manifest.MissionPboLeaf -ne $Pbo.Leaf -or [string]$Manifest.MissionPboSha256 -ne $Pbo.Sha256 -or [string]$Receipt.MissionPboLeaf -ne $Pbo.Leaf -or [string]$Receipt.MissionPboSha256 -ne $Pbo.Sha256) { throw 'Manifest or receipt PBO identity mismatch.' }
    if ([int]$Manifest.HeadlessClients -ne [int]$profile.headlessClients -or [int]$Receipt.HeadlessClients -ne [int]$profile.headlessClients -or [bool]$Manifest.Operational -ne [bool]$profile.operational -or [bool]$Receipt.Operational -ne [bool]$profile.operational -or [string]$Manifest.Topology -ne [string]$profile.topology -or [string]$Receipt.Topology -ne [string]$profile.topology -or [string]$Manifest.SteamIsolationAdapter -ne [string]$profile.steamIsolationAdapter -or [string]$Receipt.SteamIsolationAdapter -ne [string]$profile.steamIsolationAdapter) { throw 'Manifest or receipt profile topology mismatch.' }
    $manifestOwnership=@(Get-HetznerOwnershipDecisionProjection -Decisions @($Manifest.OwnershipDecisions) -InstallRoot $InstallRoot -ExpectedManagedPaths $expected -FenceRoot $FenceRoot)
    $receiptOwnership=@(Get-HetznerOwnershipDecisionProjection -Decisions @($Receipt.OwnershipDecisions) -InstallRoot $InstallRoot -ExpectedManagedPaths $expected -FenceRoot $FenceRoot)
    if((ConvertTo-Json -InputObject @($manifestOwnership) -Depth 8 -Compress) -cne (ConvertTo-Json -InputObject @($receiptOwnership) -Depth 8 -Compress)){throw 'Manifest and receipt ownership decisions mismatch.'}
    foreach ($record in $m) {
        Assert-HetznerSafeRelativePath -RelativePath ([string]$record.Path) -InstallRoot $InstallRoot | Out-Null
        if ([string]$record.Sha256 -notmatch '^[0-9a-fA-F]{64}$') { throw "Invalid managed-file hash: $($record.Path)" }
        if ($record.PSObject.Properties.Name -notcontains 'Bytes' -or [int64]$record.Bytes -lt 0) { throw "Invalid managed-file bytes record: $($record.Path)" }
        $same = @($r | Where-Object { $_.Path -eq $record.Path })[0]
        if ([string]$same.Sha256 -ne [string]$record.Sha256) { throw "Manifest and receipt hash mismatch: $($record.Path)" }
        if ($same.PSObject.Properties.Name -notcontains 'Bytes' -or [int64]$same.Bytes -ne [int64]$record.Bytes) { throw "Manifest and receipt bytes mismatch: $($record.Path)" }
        $ownedPath = Assert-HetznerSafeRelativePath -RelativePath ([string]$record.Path) -InstallRoot $InstallRoot
        if ((Test-Path -LiteralPath $ownedPath -PathType Leaf) -and [int64](Get-Item -LiteralPath $ownedPath).Length -ne [int64]$record.Bytes) { throw "Managed-file bytes mismatch; file is modified or adopted: $($record.Path)" }
    }
    $expectedIdentities = Get-HetznerExpectedLauncherIdentities -Profile $profile -ProfileName $ProfileName
    if ($null -eq $expectedIdentities) { $expectedIdentities = @() }
    if ([int]$profile.headlessClients -gt 0) {
        Assert-HetznerLauncherIdentitySet -Actual @($Manifest.LauncherIdentities) -Expected $expectedIdentities -Label 'Manifest'
        Assert-HetznerLauncherIdentitySet -Actual @($Receipt.LauncherIdentities) -Expected $expectedIdentities -Label 'Receipt'
    }
    return @($m)
}

function Test-HetznerInstallation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$InstallRoot,
        [Parameter(Mandatory)][ValidateSet('hc-0','hc-1','hc-2','hc-3')][string]$ProfileName,
        [Parameter(Mandatory)][string]$MissionPboPath,
        [string]$ProfilesPath = $script:ProfilesPath,
        [string]$FenceRoot = ''
    )
    $fence=if([string]::IsNullOrWhiteSpace($FenceRoot)){Split-Path -Parent (Get-HetznerAbsolutePath $InstallRoot)}else{Get-HetznerAbsolutePath $FenceRoot}
    $install = Test-HetznerInstallPath -Path $InstallRoot -FenceRoot $fence
    Assert-HetznerNoReparseTree -Root $install -FenceRoot $fence
    $manifestPath = Join-Path $install '.hetzner-installer\manifest.json'
    $receiptPath = Join-Path $install '.hetzner-installer\receipt.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf) -or -not (Test-Path -LiteralPath $receiptPath -PathType Leaf)) { throw 'Manifest and receipt are both required for verification.' }
    Assert-HetznerOwnershipSeal -InstallRoot $install | Out-Null
    $pbo = Get-HetznerMissionPboInfo -MissionPboPath $MissionPboPath
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
    $records = Assert-HetznerManifestContract -Manifest $manifest -Receipt $receipt -InstallRoot $install -ProfileName $ProfileName -Pbo $pbo -FenceRoot $fence
    foreach ($record in $records) {
        $path = Assert-HetznerSafeRelativePath -RelativePath ([string]$record.Path) -InstallRoot $install
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Managed file missing: $($record.Path)" }
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne ([string]$record.Sha256).ToLowerInvariant()) { throw "Managed file hash mismatch: $($record.Path)" }
    }
    $profile = Get-HetznerInstallerProfile -Name $ProfileName -ProfilesPath $ProfilesPath
    $expected = Get-HetznerExpectedManagedPaths -Profile $profile -MissionPboLeaf $pbo.Leaf
    for ($i = 1; $i -le 3; $i++) {
        $stale = "hc${i}_launch.cmd"
        if ($expected -notcontains $stale -and (Test-Path -LiteralPath (Join-Path $install $stale))) {
            $decision=@($manifest.OwnershipDecisions|Where-Object{[string]$_.Path -ceq $stale -and [string]$_.Disposition -ceq 'PreserveHost'})
            if($decision.Count -ne 1){throw "Stale installer-managed launcher remains without explicit PreserveHost ownership: $stale"}
            $stalePath=Join-Path $install $stale
            if((Get-FileHash -LiteralPath $stalePath -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$decision[0].PostSha256 -or [int64](Get-Item -LiteralPath $stalePath).Length -ne [int64]$decision[0].PostBytes){throw "Preserved host launcher drifted after Apply: $stale"}
        }
    }
    return $true
}

function Open-HetznerReadLockedFileIdentity {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$FenceRoot
    )
    $adapter = Get-HetznerAbsolutePath $Path
    $fence = Get-HetznerAbsolutePath $FenceRoot
    if (-not (Test-HetznerContainedPath -Path $adapter -Root $fence) -or $adapter -eq $fence) { throw 'Service adapter must be a leaf strictly inside the installer fence.' }
    if (-not (Test-Path -LiteralPath $adapter -PathType Leaf)) { throw "Service adapter is not a file: $adapter" }
    Assert-HetznerNoReparsePoints -Path $adapter -FenceRoot $fence | Out-Null
    $handle=$null;$sha=$null
    try{
        $handle=New-Object System.IO.FileStream($adapter,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,[System.IO.FileShare]::Read,4096,[System.IO.FileOptions]::SequentialScan)
        Assert-HetznerNoReparsePoints -Path $adapter -FenceRoot $fence | Out-Null
        $sha=[System.Security.Cryptography.SHA256]::Create();$hash=([System.BitConverter]::ToString($sha.ComputeHash($handle))).Replace('-','').ToLowerInvariant();$handle.Position=0
        return [pscustomobject][ordered]@{Path=$adapter;Sha256=$hash;Bytes=[int64]$handle.Length;Handle=$handle}
    }catch{if($null-ne$handle){$handle.Dispose()};throw "Cannot hold reviewed adapter/config bytes immutable: $($_.Exception.Message)"}
    finally{if($null-ne$sha){$sha.Dispose()}}
}

function Get-HetznerServiceAdapterIdentity {
    param(
        [Parameter(Mandatory)][string]$ServiceAdapterPath,
        [Parameter(Mandatory)][string]$FenceRoot
    )
    $locked=Open-HetznerReadLockedFileIdentity -Path $ServiceAdapterPath -FenceRoot $FenceRoot
    try{
        return [pscustomobject][ordered]@{Path=[string]$locked.Path;Sha256=[string]$locked.Sha256;Bytes=[int64]$locked.Bytes}
    }finally{
        $locked.Handle.Dispose()
    }
}

function Invoke-HetznerBoundAdapter {
    param([Parameter(Mandatory)]$Adapter,[Parameter(Mandatory)][string]$FenceRoot,[Parameter(Mandatory)]$Request)
    $actual=Open-HetznerReadLockedFileIdentity -Path ([string]$Adapter.Path) -FenceRoot $FenceRoot
    try{
        if([string]$actual.Path-ne[string]$Adapter.Path -or [string]$actual.Sha256-ne[string]$Adapter.Sha256 -or [int64]$actual.Bytes-ne[int64]$Adapter.Bytes){throw 'Bound adapter hash or size changed before execution.'}
        try{$result=& $actual.Path -Request $Request}catch{throw "Bound adapter action $($Request.Action) failed: $($_.Exception.Message)"}
        if($null-eq$result){throw "Bound adapter action $($Request.Action) returned no evidence."}
        return $result
    }finally{
        $actual.Handle.Dispose()
    }
}

function Get-HetznerAdapterConfigurationIdentity {
    param([Parameter(Mandatory)][string]$AdapterConfigPath,[Parameter(Mandatory)][string]$FenceRoot,[Parameter(Mandatory)][AllowEmptyCollection()][object[]]$LauncherIdentities)
    $identity=Open-HetznerReadLockedFileIdentity -Path $AdapterConfigPath -FenceRoot $FenceRoot
    try{
        $reader=New-Object System.IO.StreamReader($identity.Handle,(New-Object System.Text.UTF8Encoding($false,$true)),$true,4096,$true)
        try{$raw=$reader.ReadToEnd()}finally{$reader.Dispose()}
        try{$config=$raw|ConvertFrom-Json}catch{throw "Adapter configuration is not valid JSON: $($_.Exception.Message)"}
    }finally{$identity.Handle.Dispose()}
    if([int]$config.SchemaVersion-ne 1 -or [string]$config.ConfigType-cne'windows-service-adapter-v1'){throw 'Adapter configuration schema or type is invalid.'}
    foreach($field in @('EnvironmentId','ServiceName','ServerRptPath','MissionPboPath','HeadlessClients')){if($config.PSObject.Properties.Name-notcontains$field){throw "Adapter configuration is missing field: $field"}}
    if([string]$config.EnvironmentId-cne'MIKSUUS-TEST'){throw 'Adapter configuration is not bound to the only permitted environment: MIKSUUS-TEST.'}
    foreach($pathField in @('ServerRptPath','MissionPboPath')){if(-not[System.IO.Path]::IsPathRooted([string]$config.$pathField)){throw "Adapter configuration $pathField must be an absolute path."}}
    $expected=@($LauncherIdentities);$actual=@($config.HeadlessClients)
    if($actual.Count-ne$expected.Count){throw 'Adapter configuration HC count does not match the selected profile.'}
    $normalized=@();$seenSandbox=@{};$seenProfile=@{};$seenRpt=@{};$seenTask=@{}
    foreach($launcher in $expected){
        $matches=@($actual|Where-Object{[string]$_.Name-ceq[string]$launcher.Name -and [string]$_.RptIdentity-ceq[string]$launcher.RptIdentity})
        if($matches.Count-ne 1){throw "Adapter configuration must contain exactly one launcher identity: $($launcher.RptIdentity)"};$hc=$matches[0]
        foreach($field in @('SandboxRoot','ProfileRoot','RptPath','CommandLineFingerprint','LaunchTaskName','ProcessName')){if($hc.PSObject.Properties.Name-notcontains$field -or [string]::IsNullOrWhiteSpace([string]$hc.$field)){throw "Adapter configuration is missing $field for $($launcher.RptIdentity)"}}
        foreach($pathField in @('SandboxRoot','ProfileRoot','RptPath')){if(-not[System.IO.Path]::IsPathRooted([string]$hc.$pathField)){throw "Adapter configuration $pathField must be absolute for $($launcher.RptIdentity)"}}
        if([string]$hc.CommandLineFingerprint-cnotmatch'^[0-9a-fA-F]{64}$'){throw "Adapter configuration launch fingerprint is invalid for $($launcher.RptIdentity)"}
        $sandbox=Get-HetznerAbsolutePath ([string]$hc.SandboxRoot);$profile=Get-HetznerAbsolutePath ([string]$hc.ProfileRoot);$rpt=Get-HetznerAbsolutePath ([string]$hc.RptPath);$task=[string]$hc.LaunchTaskName
        foreach($entry in @(@{Table=$seenSandbox;Value=$sandbox;Label='sandbox root'},@{Table=$seenProfile;Value=$profile;Label='profile root'},@{Table=$seenRpt;Value=$rpt;Label='RPT path'},@{Table=$seenTask;Value=$task;Label='launch task'})){if($entry.Table.ContainsKey($entry.Value)){throw "Adapter configuration $($entry.Label) is not unique: $($entry.Value)"};$entry.Table[$entry.Value]=$true}
        $normalized += [pscustomobject][ordered]@{Name=[string]$launcher.Name;ProfileId=[string]$launcher.ProfileId;RptIdentity=[string]$launcher.RptIdentity;Port=[int]$launcher.Port;SandboxRoot=$sandbox;ProfileRoot=$profile;RptPath=$rpt;CommandLineFingerprint=([string]$hc.CommandLineFingerprint).ToLowerInvariant();LaunchTaskName=$task;ProcessName=[string]$hc.ProcessName}
    }
    $configuration=[pscustomobject][ordered]@{SchemaVersion=1;ConfigType='windows-service-adapter-v1';EnvironmentId='MIKSUUS-TEST';ServiceName=[string]$config.ServiceName;ServerRptPath=(Get-HetznerAbsolutePath ([string]$config.ServerRptPath));MissionPboPath=(Get-HetznerAbsolutePath ([string]$config.MissionPboPath));HeadlessClients=@($normalized|Sort-Object RptIdentity)}
    return [pscustomobject][ordered]@{Path=$identity.Path;Sha256=$identity.Sha256;Bytes=$identity.Bytes;Configuration=$configuration;ExpectedIsolation=@($normalized|Sort-Object RptIdentity)}
}

function Assert-HetznerMiksuusTestServiceBinding {
    param([Parameter(Mandatory)]$AdapterConfiguration,[Parameter(Mandatory)][string]$ServiceName,[Parameter(Mandatory)]$MissionPbo)
    $config=$AdapterConfiguration.Configuration
    if([string]$config.EnvironmentId-cne'MIKSUUS-TEST' -or [string]$config.ServiceName-cne$ServiceName){throw 'Service binding is not the sealed MIKSUUS-TEST service identity.'}
    if(-not(Test-Path -LiteralPath ([string]$config.ServerRptPath) -PathType Leaf)){throw 'MIKSUUS-TEST server RPT binding is missing.'}
    if(-not(Test-Path -LiteralPath ([string]$config.MissionPboPath) -PathType Leaf)){throw 'MIKSUUS-TEST mission PBO binding is missing.'}
    if([System.IO.Path]::GetFileName([string]$config.MissionPboPath)-cne[string]$MissionPbo.Leaf -or (Get-FileHash -LiteralPath ([string]$config.MissionPboPath) -Algorithm SHA256).Hash.ToLowerInvariant()-cne([string]$MissionPbo.Sha256).ToLowerInvariant()){throw 'MIKSUUS-TEST mission PBO binding differs from the sealed release.'}
}

function Get-HetznerServiceActivationPlanFingerprint {
    param(
        [Parameter(Mandatory)][string]$InstallRoot,
        [Parameter(Mandatory)][string]$FenceRoot,
        [Parameter(Mandatory)][string]$ProfileName,
        [Parameter(Mandatory)][string]$MissionPboPath,
        [Parameter(Mandatory)]$MissionPbo,
        [Parameter(Mandatory)][string]$ServiceName,
        [Parameter(Mandatory)][string]$AdapterId,
        [Parameter(Mandatory)]$ServiceAdapter,
        [Parameter(Mandatory)]$AdapterConfiguration,
        $IsolationAttestation,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$LauncherIdentities,
        [Parameter(Mandatory)][int]$MinimumObservationSeconds
    )
    $identities = @()
    foreach ($identity in @($LauncherIdentities | Sort-Object RptIdentity)) {
        $identities += [pscustomobject][ordered]@{
            Name = [string]$identity.Name
            ProfileId = [string]$identity.ProfileId
            RptIdentity = [string]$identity.RptIdentity
            Port = [int]$identity.Port
        }
    }
    $isolationPayload=if($null-eq$IsolationAttestation){[ordered]@{Path='';Sha256='';Bytes=[int64]0;PlanFingerprint=''}}else{[ordered]@{ Path = [string]$IsolationAttestation.Path; Sha256 = [string]$IsolationAttestation.Sha256; Bytes = [int64]$IsolationAttestation.Bytes; PlanFingerprint = [string]$IsolationAttestation.PlanFingerprint }}
    $payload = [ordered]@{
        SchemaVersion = $script:SchemaVersion
        Action = 'ServiceActivationPlan'
        InstallRoot = Get-HetznerAbsolutePath $InstallRoot
        FenceRoot = Get-HetznerAbsolutePath $FenceRoot
        ProfileName = $ProfileName
        MissionPboPath = Get-HetznerAbsolutePath $MissionPboPath
        MissionPboLeaf = [string]$MissionPbo.Leaf
        MissionPboSha256 = [string]$MissionPbo.Sha256
        ServiceName = $ServiceName
        AdapterId = $AdapterId
        ServiceAdapter = [ordered]@{ Path = [string]$ServiceAdapter.Path; Sha256 = [string]$ServiceAdapter.Sha256; Bytes = [int64]$ServiceAdapter.Bytes }
        AdapterConfiguration=[ordered]@{Path=[string]$AdapterConfiguration.Path;Sha256=[string]$AdapterConfiguration.Sha256;Bytes=[int64]$AdapterConfiguration.Bytes;Configuration=$AdapterConfiguration.Configuration;ExpectedIsolation=@($AdapterConfiguration.ExpectedIsolation)}
        IsolationAttestation = $isolationPayload
        LauncherIdentities = @($identities)
        MinimumObservationSeconds = $MinimumObservationSeconds
    }
    return Get-HetznerStringSha256 -Value ($payload | ConvertTo-Json -Depth 10 -Compress)
}

function Get-HetznerServiceActivationReceiptPath {
    param([Parameter(Mandatory)][string]$InstallRoot, [Parameter(Mandatory)][string]$FenceRoot, [Parameter(Mandatory)][string]$PlanFingerprint)
    $paths = Get-HetznerTransactionPaths -InstallRoot $InstallRoot -FenceRoot $FenceRoot
    return Join-Path (Join-Path $paths.TransactionRoot 'service-activation') ($PlanFingerprint + '.json')
}

function Get-HetznerHCIsolationAttestationPlanFingerprint {
    param(
        [Parameter(Mandatory)][string]$InstallRoot,
        [Parameter(Mandatory)][string]$FenceRoot,
        [Parameter(Mandatory)][string]$ProfileName,
        [Parameter(Mandatory)][string]$MissionPboPath,
        [Parameter(Mandatory)]$MissionPbo,
        [Parameter(Mandatory)][string]$AdapterId,
        [Parameter(Mandatory)]$IsolationAdapter,
        [Parameter(Mandatory)]$AdapterConfiguration,
        [Parameter(Mandatory)]$CommitIdentity,
        [Parameter(Mandatory)][object[]]$LauncherIdentities,
        [Parameter(Mandatory)][int]$MinimumObservationSeconds
    )
    $identities = @()
    foreach ($identity in @($LauncherIdentities | Sort-Object RptIdentity)) {
        $identities += [pscustomobject][ordered]@{ Name = [string]$identity.Name; ProfileId = [string]$identity.ProfileId; RptIdentity = [string]$identity.RptIdentity; Port = [int]$identity.Port }
    }
    $payload = [ordered]@{
        SchemaVersion = $script:SchemaVersion
        Action = 'HCIsolationAttestationPlan'
        InstallRoot = Get-HetznerAbsolutePath $InstallRoot
        FenceRoot = Get-HetznerAbsolutePath $FenceRoot
        ProfileName = $ProfileName
        MissionPboPath = Get-HetznerAbsolutePath $MissionPboPath
        MissionPboLeaf = [string]$MissionPbo.Leaf
        MissionPboSha256 = [string]$MissionPbo.Sha256
        AdapterId = $AdapterId
        IsolationAdapter = [ordered]@{ Path = [string]$IsolationAdapter.Path; Sha256 = [string]$IsolationAdapter.Sha256; Bytes = [int64]$IsolationAdapter.Bytes }
        AdapterConfiguration = [ordered]@{ Path=[string]$AdapterConfiguration.Path;Sha256=[string]$AdapterConfiguration.Sha256;Bytes=[int64]$AdapterConfiguration.Bytes;Configuration=$AdapterConfiguration.Configuration;ExpectedIsolation=@($AdapterConfiguration.ExpectedIsolation) }
        CommitIdentity = [ordered]@{ JournalFingerprint = [string]$CommitIdentity.JournalFingerprint; CommitContractFingerprint = [string]$CommitIdentity.CommitContractFingerprint }
        LauncherIdentities = @($identities)
        MinimumObservationSeconds = $MinimumObservationSeconds
    }
    return Get-HetznerStringSha256 -Value ($payload | ConvertTo-Json -Depth 10 -Compress)
}

function Get-HetznerHCIsolationAttestationReceiptPath {
    param([Parameter(Mandatory)][string]$InstallRoot, [Parameter(Mandatory)][string]$FenceRoot, [Parameter(Mandatory)][string]$PlanFingerprint)
    $paths = Get-HetznerTransactionPaths -InstallRoot $InstallRoot -FenceRoot $FenceRoot
    return Join-Path (Join-Path $paths.TransactionRoot 'hc-isolation') ($PlanFingerprint + '.json')
}

function Get-HetznerCommittedInstallIdentity {
    param([Parameter(Mandatory)][string]$InstallRoot, [Parameter(Mandatory)][string]$FenceRoot)
    $paths = Get-HetznerTransactionPaths -InstallRoot $InstallRoot -FenceRoot $FenceRoot
    $status = Get-HetznerTransactionStatus -InstallRoot $paths.InstallRoot -FenceRoot $paths.FenceRoot
    if ([string]$status.State -ne 'Committed') { throw 'HC isolation attestation requires a committed T14 installer transaction.' }
    $contract = Assert-HetznerCommitContract -Journal $status.Journal -Paths $paths -VerifyCurrent
    return [pscustomobject][ordered]@{
        JournalFingerprint = [string]$status.Journal.JournalFingerprint
        CommitContractFingerprint = (Get-HetznerStringSha256 -Value ($contract | ConvertTo-Json -Depth 10 -Compress))
    }
}

function New-HetznerHCIsolationAttestationPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$InstallRoot,
        [Parameter(Mandatory)][string]$FenceRoot,
        [Parameter(Mandatory)][ValidateSet('hc-2','hc-3')][string]$ProfileName,
        [Parameter(Mandatory)][string]$MissionPboPath,
        [Parameter(Mandatory)][string]$IsolationAdapterPath,
        [Parameter(Mandatory)][string]$AdapterConfigPath,
        [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$')][string]$AdapterId,
        [ValidateRange(1,3600)][int]$MinimumObservationSeconds = 60
    )
    $install = Test-HetznerInstallPath -Path $InstallRoot -FenceRoot $FenceRoot
    $fence = Get-HetznerAbsolutePath $FenceRoot
    $profile = Get-HetznerInstallerProfile -Name $ProfileName
    if ([int]$profile.headlessClients -lt 2) { throw 'HC isolation attestation requires two or more headless clients.' }
    $pbo = Get-HetznerMissionPboInfo -MissionPboPath $MissionPboPath
    Test-HetznerInstallation -InstallRoot $install -FenceRoot $fence -ProfileName $ProfileName -MissionPboPath $pbo.Path | Out-Null
    $identities = @(Get-HetznerExpectedLauncherIdentities -Profile $profile -ProfileName $ProfileName)
    $adapter = Get-HetznerServiceAdapterIdentity -ServiceAdapterPath $IsolationAdapterPath -FenceRoot $fence
    $adapterConfiguration=Get-HetznerAdapterConfigurationIdentity -AdapterConfigPath $AdapterConfigPath -FenceRoot $fence -LauncherIdentities $identities
    $commitIdentity = Get-HetznerCommittedInstallIdentity -InstallRoot $install -FenceRoot $fence
    $fingerprint = Get-HetznerHCIsolationAttestationPlanFingerprint -InstallRoot $install -FenceRoot $fence -ProfileName $ProfileName -MissionPboPath $pbo.Path -MissionPbo $pbo -AdapterId $AdapterId -IsolationAdapter $adapter -AdapterConfiguration $adapterConfiguration -CommitIdentity $commitIdentity -LauncherIdentities $identities -MinimumObservationSeconds $MinimumObservationSeconds
    return [pscustomobject][ordered]@{
        SchemaVersion = $script:SchemaVersion
        Action = 'HCIsolationAttestationPlan'
        InstallRoot = $install
        FenceRoot = $fence
        ProfileName = $ProfileName
        MissionPboPath = $pbo.Path
        MissionPboLeaf = $pbo.Leaf
        MissionPboSha256 = $pbo.Sha256
        AdapterId = $AdapterId
        IsolationAdapter = $adapter
        AdapterConfiguration=$adapterConfiguration
        ExpectedIsolation=@($adapterConfiguration.ExpectedIsolation)
        CommitIdentity = $commitIdentity
        LauncherIdentities = $identities
        MinimumObservationSeconds = $MinimumObservationSeconds
        PlanFingerprint = $fingerprint
        AttestationReceiptPath = (Get-HetznerHCIsolationAttestationReceiptPath -InstallRoot $install -FenceRoot $fence -PlanFingerprint $fingerprint)
    }
}

function Assert-HetznerHCIsolationAttestationPlan {
    param([Parameter(Mandatory)]$Plan)
    foreach ($field in @('SchemaVersion','Action','InstallRoot','FenceRoot','ProfileName','MissionPboPath','MissionPboLeaf','MissionPboSha256','AdapterId','IsolationAdapter','AdapterConfiguration','ExpectedIsolation','CommitIdentity','LauncherIdentities','MinimumObservationSeconds','PlanFingerprint','AttestationReceiptPath')) {
        if ($Plan.PSObject.Properties.Name -notcontains $field) { throw "HC isolation plan is missing field: $field" }
    }
    if ([int]$Plan.SchemaVersion -ne $script:SchemaVersion -or [string]$Plan.Action -ne 'HCIsolationAttestationPlan') { throw 'HC isolation plan action or schema was tampered.' }
    $install = Test-HetznerInstallPath -Path ([string]$Plan.InstallRoot) -FenceRoot ([string]$Plan.FenceRoot)
    $fence = Get-HetznerAbsolutePath ([string]$Plan.FenceRoot)
    $profile = Get-HetznerInstallerProfile -Name ([string]$Plan.ProfileName)
    if ([int]$profile.headlessClients -lt 2) { throw 'HC isolation plan profile is not a multi-HC topology.' }
    $pbo = Get-HetznerMissionPboInfo -MissionPboPath ([string]$Plan.MissionPboPath)
    if ([string]$Plan.MissionPboLeaf -ne [string]$pbo.Leaf -or [string]$Plan.MissionPboSha256 -ne [string]$pbo.Sha256) { throw 'HC isolation mission identity changed after planning.' }
    Test-HetznerInstallation -InstallRoot $install -FenceRoot $fence -ProfileName ([string]$Plan.ProfileName) -MissionPboPath $pbo.Path | Out-Null
    $adapter = Get-HetznerServiceAdapterIdentity -ServiceAdapterPath ([string]$Plan.IsolationAdapter.Path) -FenceRoot $fence
    if ([string]$adapter.Path -ne [string]$Plan.IsolationAdapter.Path -or [string]$adapter.Sha256 -ne [string]$Plan.IsolationAdapter.Sha256 -or [int64]$adapter.Bytes -ne [int64]$Plan.IsolationAdapter.Bytes) { throw 'HC isolation adapter hash or size changed after planning.' }
    $commitIdentity = Get-HetznerCommittedInstallIdentity -InstallRoot $install -FenceRoot $fence
    if ([string]$commitIdentity.JournalFingerprint -ne [string]$Plan.CommitIdentity.JournalFingerprint -or [string]$commitIdentity.CommitContractFingerprint -ne [string]$Plan.CommitIdentity.CommitContractFingerprint) { throw 'Committed T14 installer contract changed after HC isolation planning.' }
    $identities = @(Get-HetznerExpectedLauncherIdentities -Profile $profile -ProfileName ([string]$Plan.ProfileName))
    Assert-HetznerLauncherIdentitySet -Actual @($Plan.LauncherIdentities) -Expected $identities -Label 'HC isolation plan'
    $adapterConfiguration=Get-HetznerAdapterConfigurationIdentity -AdapterConfigPath ([string]$Plan.AdapterConfiguration.Path) -FenceRoot $fence -LauncherIdentities $identities
    if([string]$adapterConfiguration.Sha256-ne[string]$Plan.AdapterConfiguration.Sha256 -or [int64]$adapterConfiguration.Bytes-ne[int64]$Plan.AdapterConfiguration.Bytes -or (ConvertTo-Json $adapterConfiguration.Configuration -Depth 10 -Compress)-cne(ConvertTo-Json $Plan.AdapterConfiguration.Configuration -Depth 10 -Compress) -or (ConvertTo-Json @($adapterConfiguration.ExpectedIsolation) -Depth 10 -Compress)-cne(ConvertTo-Json @($Plan.ExpectedIsolation) -Depth 10 -Compress)){throw 'Adapter configuration changed after HC isolation planning.'}
    $fingerprint = Get-HetznerHCIsolationAttestationPlanFingerprint -InstallRoot $install -FenceRoot $fence -ProfileName ([string]$Plan.ProfileName) -MissionPboPath $pbo.Path -MissionPbo $pbo -AdapterId ([string]$Plan.AdapterId) -IsolationAdapter $adapter -AdapterConfiguration $adapterConfiguration -CommitIdentity $commitIdentity -LauncherIdentities $identities -MinimumObservationSeconds ([int]$Plan.MinimumObservationSeconds)
    if ([string]$Plan.PlanFingerprint -ne $fingerprint) { throw 'HC isolation plan fingerprint does not match the canonical contract.' }
    if ([string]$Plan.AttestationReceiptPath -ne (Get-HetznerHCIsolationAttestationReceiptPath -InstallRoot $install -FenceRoot $fence -PlanFingerprint $fingerprint)) { throw 'HC isolation attestation receipt path was tampered.' }
}

function Get-HetznerHCIsolationEvidenceProjection {
    param([Parameter(Mandatory)]$Evidence, [Parameter(Mandatory)]$Plan, [Parameter(Mandatory)][datetime]$ObservationStartedUtc,[switch]$HistoricalReceipt)
    foreach ($field in @('AdapterId','ProfileName','ObservationWindowSeconds','FatalLineCount','HeadlessClients')) {
        if ($Evidence.PSObject.Properties.Name -notcontains $field) { throw "HC isolation evidence is missing field: $field" }
    }
    if ([string]$Evidence.AdapterId -ne [string]$Plan.AdapterId -or [string]$Evidence.ProfileName -ne [string]$Plan.ProfileName) { throw 'HC isolation evidence identity does not match the sealed plan.' }
    if ([int]$Evidence.ObservationWindowSeconds -lt [int]$Plan.MinimumObservationSeconds) { throw 'HC isolation observation window is shorter than the sealed minimum.' }
    if ([int]$Evidence.FatalLineCount -ne 0) { throw 'HC isolation fatal-free window contains fatal lines.' }
    $actual = @($Evidence.HeadlessClients)
    $expected = @($Plan.LauncherIdentities)
    if ($actual.Count -ne $expected.Count) { throw 'HC isolation evidence count does not match the selected profile.' }
    $projection = @(); $uniqueInstances = @{}; $uniqueSandboxes = @{}; $uniqueProfiles = @{}; $uniqueRpts = @{}; $uniqueProcesses = @{}
    foreach ($identity in $expected) {
        $matches = @($actual | Where-Object { [string]$_.Name -eq [string]$identity.Name -and [string]$_.RptIdentity -eq [string]$identity.RptIdentity })
        if ($matches.Count -ne 1) { throw "HC isolation requires exactly one expected RPT identity: $($identity.RptIdentity)" }
        $match = $matches[0]
        foreach ($field in @('ProcessId','InstanceId','SandboxRoot','ProfileRoot','RptPath','RptLastWriteUtc','StartUtc','CommandLineFingerprint')) {
            if ($match.PSObject.Properties.Name -notcontains $field -or [string]::IsNullOrWhiteSpace([string]$match.$field)) { throw "HC isolation evidence is missing $field for $($identity.RptIdentity)" }
        }
        if ([int]$match.ProcessId -lt 1) { throw "HC isolation process identity is invalid: $($identity.RptIdentity)" }
        try { $startUtc=ConvertTo-HetznerUtcTimestamp -Value $match.StartUtc;$rptWriteUtc=ConvertTo-HetznerUtcTimestamp -Value $match.RptLastWriteUtc } catch { throw "HC isolation start or RPT timestamp is invalid: $($identity.RptIdentity)" }
        if ([string]$match.CommandLineFingerprint -notmatch '^[0-9a-fA-F]{64}$') { throw "HC isolation command-line fingerprint is invalid: $($identity.RptIdentity)" }
        $sealed=@($Plan.ExpectedIsolation|Where-Object{[string]$_.Name-ceq[string]$identity.Name -and [string]$_.RptIdentity-ceq[string]$identity.RptIdentity})
        if($sealed.Count-ne 1){throw "HC isolation has no unique sealed expected identity: $($identity.RptIdentity)"};$sealed=$sealed[0]
        foreach($field in @('SandboxRoot','ProfileRoot','RptPath','CommandLineFingerprint')){if([string]$match.$field-cne[string]$sealed.$field){throw "HC isolation measured $field differs from the sealed adapter configuration: $($identity.RptIdentity)"}}
        $rptPath=Get-HetznerAbsolutePath ([string]$match.RptPath);if(-not(Test-Path -LiteralPath $rptPath -PathType Leaf)){throw "HC isolation measured RPT file is missing: $($identity.RptIdentity)"};$measuredWrite=(Get-Item -LiteralPath $rptPath).LastWriteTimeUtc
        $fileTimeInvalid=if($HistoricalReceipt){$measuredWrite-lt$rptWriteUtc}else{[Math]::Abs(($measuredWrite-$rptWriteUtc).TotalSeconds)-gt 1}
        if($fileTimeInvalid -or $rptWriteUtc-lt$startUtc -or $rptWriteUtc-lt$ObservationStartedUtc.AddSeconds(-2) -or $rptWriteUtc-gt[datetime]::UtcNow.AddSeconds(2)){throw "HC isolation RPT freshness does not match the measured observation window: $($identity.RptIdentity)"}
        foreach ($entry in @(@{ Table = $uniqueInstances; Value = [string]$match.InstanceId; Label = 'instance identity' },@{ Table = $uniqueSandboxes; Value = [string]$match.SandboxRoot; Label = 'sandbox root' },@{ Table = $uniqueProfiles; Value = [string]$match.ProfileRoot; Label = 'profile root' },@{ Table = $uniqueRpts; Value = [string]$match.RptPath; Label = 'RPT path' },@{ Table = $uniqueProcesses; Value = [string]$match.ProcessId; Label = 'process identity' })) {
            if ($entry.Table.ContainsKey($entry.Value)) { throw "HC isolation $($entry.Label) is not unique: $($entry.Value)" }
            $entry.Table[$entry.Value] = $true
        }
        $projection += [pscustomobject][ordered]@{ Name = [string]$match.Name; RptIdentity = [string]$match.RptIdentity; ProcessId = [int]$match.ProcessId; InstanceId = [string]$match.InstanceId; SandboxRoot = [string]$match.SandboxRoot; ProfileRoot = [string]$match.ProfileRoot; RptPath = [string]$match.RptPath; RptLastWriteUtc=$rptWriteUtc.ToString('o');StartUtc = $startUtc.ToString('o'); CommandLineFingerprint = [string]$match.CommandLineFingerprint.ToLowerInvariant() }
    }
    return [pscustomobject][ordered]@{ AdapterId = [string]$Evidence.AdapterId; ProfileName = [string]$Evidence.ProfileName; ObservationWindowSeconds = [int]$Evidence.ObservationWindowSeconds; FatalLineCount = [int]$Evidence.FatalLineCount; HeadlessClients = @($projection | Sort-Object RptIdentity) }
}

function Get-HetznerHCIsolationBaselineProjection {
    param([Parameter(Mandatory)]$Evidence, [Parameter(Mandatory)]$Plan)
    foreach ($field in @('AdapterId','ProfileName','BaselineFingerprint','ActiveInstanceIds')) {
        if ($Evidence.PSObject.Properties.Name -notcontains $field) { throw "HC isolation baseline is missing field: $field" }
    }
    if ([string]$Evidence.AdapterId -ne [string]$Plan.AdapterId -or [string]$Evidence.ProfileName -ne [string]$Plan.ProfileName) { throw 'HC isolation baseline identity does not match the sealed plan.' }
    if ([string]$Evidence.BaselineFingerprint -notmatch '^[0-9a-fA-F]{64}$') { throw 'HC isolation baseline fingerprint is invalid.' }
    $instances = @($Evidence.ActiveInstanceIds | ForEach-Object { [string]$_ } | Sort-Object)
    if (@($instances | Select-Object -Unique).Count -ne $instances.Count) { throw 'HC isolation baseline instance identities are not unique.' }
    return [pscustomobject][ordered]@{ AdapterId = [string]$Evidence.AdapterId; ProfileName = [string]$Evidence.ProfileName; BaselineFingerprint = [string]$Evidence.BaselineFingerprint.ToLowerInvariant(); ActiveInstanceIds = @($instances) }
}

function New-HetznerHCIsolationAdapterRequest {
    param([Parameter(Mandatory)]$Plan, [Parameter(Mandatory)][ValidateSet('CaptureIsolationBaseline','ApplyIsolation','ObserveIsolation','RestoreIsolationBaseline','ObserveIsolationBaseline')][string]$Action, $Baseline = $null)
    return [pscustomobject][ordered]@{ Action = $Action; AdapterId = [string]$Plan.AdapterId; ProfileName = [string]$Plan.ProfileName; MissionPboLeaf = [string]$Plan.MissionPboLeaf; MissionPboSha256 = [string]$Plan.MissionPboSha256; LauncherIdentities = @($Plan.LauncherIdentities);ExpectedIsolation=@($Plan.ExpectedIsolation);AdapterConfiguration=$Plan.AdapterConfiguration.Configuration; MinimumObservationSeconds = [int]$Plan.MinimumObservationSeconds; Baseline = $Baseline }
}

function Invoke-HetznerHCIsolationAttestationPlan {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Plan, [switch]$Apply)
    Assert-HetznerHCIsolationAttestationPlan -Plan $Plan
    if (-not $Apply) { return [pscustomobject]@{ Applied = $false; AdapterInvoked = $false; CommitState = 'DryRun'; AttestationReceiptPath = $Plan.AttestationReceiptPath } }
    $baseline = $null;$lock=$null
    try {
        $paths=Get-HetznerTransactionPaths -InstallRoot ([string]$Plan.InstallRoot) -FenceRoot ([string]$Plan.FenceRoot)
        $lock=Enter-HetznerTransactionLock -Paths $paths
        Assert-HetznerHCIsolationAttestationPlan -Plan $Plan
        $captureRequest = New-HetznerHCIsolationAdapterRequest -Plan $Plan -Action 'CaptureIsolationBaseline'
        $baselineEvidence = Invoke-HetznerBoundAdapter -Adapter $Plan.IsolationAdapter -FenceRoot $Plan.FenceRoot -Request $captureRequest
        if ($null -eq $baselineEvidence) { throw 'HC isolation adapter returned no baseline evidence.' }
        $baseline = Get-HetznerHCIsolationBaselineProjection -Evidence $baselineEvidence -Plan $Plan
        $applyRequest = New-HetznerHCIsolationAdapterRequest -Plan $Plan -Action 'ApplyIsolation' -Baseline $baseline
        $applyEvidence = Invoke-HetznerBoundAdapter -Adapter $Plan.IsolationAdapter -FenceRoot $Plan.FenceRoot -Request $applyRequest
        if ($null -eq $applyEvidence -or $applyEvidence.PSObject.Properties.Name -notcontains 'AdapterId' -or [string]$applyEvidence.AdapterId -ne [string]$Plan.AdapterId -or $applyEvidence.PSObject.Properties.Name -notcontains 'Applied' -or -not [bool]$applyEvidence.Applied) { throw 'HC isolation adapter did not confirm isolated launch application.' }
        $observationStartedUtc=[datetime]::UtcNow
        $observeRequest = New-HetznerHCIsolationAdapterRequest -Plan $Plan -Action 'ObserveIsolation' -Baseline $baseline
        $evidence = Invoke-HetznerBoundAdapter -Adapter $Plan.IsolationAdapter -FenceRoot $Plan.FenceRoot -Request $observeRequest
        if ($null -eq $evidence) { throw 'HC isolation adapter returned no attestation evidence.' }
        $attestation = Get-HetznerHCIsolationEvidenceProjection -Evidence $evidence -Plan $Plan -ObservationStartedUtc $observationStartedUtc
        $receipt = [pscustomobject][ordered]@{
            SchemaVersion = $script:SchemaVersion
            ReceiptType = 'hc-isolation-attestation-v1'
            PlanFingerprint = [string]$Plan.PlanFingerprint
            Adapter = [pscustomobject][ordered]@{ Id = [string]$Plan.AdapterId; Path = [string]$Plan.IsolationAdapter.Path; Sha256 = [string]$Plan.IsolationAdapter.Sha256; Bytes = [int64]$Plan.IsolationAdapter.Bytes }
            AdapterConfiguration=$Plan.AdapterConfiguration
            CommitIdentity = $Plan.CommitIdentity
            ProfileName = [string]$Plan.ProfileName
            MissionPboLeaf = [string]$Plan.MissionPboLeaf
            MissionPboSha256 = [string]$Plan.MissionPboSha256
            MinimumObservationSeconds = [int]$Plan.MinimumObservationSeconds
            ObservationStartedUtc = $observationStartedUtc.ToString('o')
            AttestedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
            Baseline = $baseline
            Attestation = $attestation
        }
        Assert-HetznerHCIsolationAttestationPlan -Plan $Plan
        Write-HetznerAtomicJson -Path ([string]$Plan.AttestationReceiptPath) -Value $receipt
        if (-not (Test-Path -LiteralPath $Plan.AttestationReceiptPath -PathType Leaf)) { throw 'HC isolation attestation receipt was not committed.' }
        return [pscustomobject]@{ Applied = $true; AdapterInvoked = $true; CommitState = 'CommittedAfterIsolationAttestation'; AttestationReceiptPath = $Plan.AttestationReceiptPath; Receipt = $receipt }
    } catch {
        $failure = $_.Exception.Message
        if ($null -eq $baseline) { throw }
        try {
            $restoreRequest = New-HetznerHCIsolationAdapterRequest -Plan $Plan -Action 'RestoreIsolationBaseline' -Baseline $baseline
            $restoreEvidence = Invoke-HetznerBoundAdapter -Adapter $Plan.IsolationAdapter -FenceRoot $Plan.FenceRoot -Request $restoreRequest
            if ($null -eq $restoreEvidence -or $restoreEvidence.PSObject.Properties.Name -notcontains 'AdapterId' -or [string]$restoreEvidence.AdapterId -ne [string]$Plan.AdapterId -or $restoreEvidence.PSObject.Properties.Name -notcontains 'Restored' -or -not [bool]$restoreEvidence.Restored) { throw 'HC isolation adapter did not confirm baseline restore.' }
            $observeBaselineRequest = New-HetznerHCIsolationAdapterRequest -Plan $Plan -Action 'ObserveIsolationBaseline' -Baseline $baseline
            $restoredEvidence = Invoke-HetznerBoundAdapter -Adapter $Plan.IsolationAdapter -FenceRoot $Plan.FenceRoot -Request $observeBaselineRequest
            $restored = Get-HetznerHCIsolationBaselineProjection -Evidence $restoredEvidence -Plan $Plan
            if ((ConvertTo-Json -InputObject $restored -Depth 8 -Compress) -ne (ConvertTo-Json -InputObject $baseline -Depth 8 -Compress)) { throw 'HC isolation baseline re-observation does not match the captured baseline.' }
        } catch { throw "HC isolation attestation failed: $failure; baseline recovery failed: $($_.Exception.Message)" }
        throw "HC isolation attestation failed and baseline was restored: $failure"
    }finally{if($null-ne$lock){$lock.Dispose()}}
}

function Get-HetznerHCIsolationAttestationIdentity {
    param([Parameter(Mandatory)][string]$AttestationReceiptPath, [Parameter(Mandatory)][string]$InstallRoot, [Parameter(Mandatory)][string]$FenceRoot, [Parameter(Mandatory)][string]$ProfileName, [Parameter(Mandatory)]$Pbo)
    $paths = Get-HetznerTransactionPaths -InstallRoot $InstallRoot -FenceRoot $FenceRoot
    $root = Join-Path $paths.TransactionRoot 'hc-isolation'
    $path = Get-HetznerAbsolutePath $AttestationReceiptPath
    if (-not (Test-HetznerContainedPath -Path $path -Root $root) -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Required HC isolation attestation receipt is missing or outside its transaction namespace.' }
    Assert-HetznerNoReparsePoints -Path $path -FenceRoot $FenceRoot | Out-Null
    $receipt = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    foreach ($field in @('SchemaVersion','ReceiptType','PlanFingerprint','Adapter','CommitIdentity','ProfileName','MissionPboLeaf','MissionPboSha256','MinimumObservationSeconds','ObservationStartedUtc','AttestedAtUtc','Baseline','Attestation')) {
        if ($receipt.PSObject.Properties.Name -notcontains $field) { throw "HC isolation attestation receipt is missing field: $field" }
    }
    if ([int]$receipt.SchemaVersion -ne $script:SchemaVersion -or [string]$receipt.ReceiptType -ne 'hc-isolation-attestation-v1') { throw 'HC isolation attestation receipt has an invalid schema or type.' }
    if ([string]$receipt.ProfileName -ne $ProfileName -or [string]$receipt.MissionPboLeaf -ne [string]$Pbo.Leaf -or [string]$receipt.MissionPboSha256 -ne [string]$Pbo.Sha256) { throw 'HC isolation attestation does not match the selected profile and mission identity.' }
    try { $attestedAt = ConvertTo-HetznerUtcTimestamp -Value $receipt.AttestedAtUtc } catch { throw 'HC isolation attestation timestamp is invalid.' }
    if ($attestedAt -gt (Get-Date).ToUniversalTime() -or (((Get-Date).ToUniversalTime() - $attestedAt).TotalSeconds -gt 300)) { throw 'HC isolation attestation is stale or from the future.' }
    $profile = Get-HetznerInstallerProfile -Name $ProfileName
    $expected = @(Get-HetznerExpectedLauncherIdentities -Profile $profile -ProfileName $ProfileName)
    $commitIdentity = Get-HetznerCommittedInstallIdentity -InstallRoot $InstallRoot -FenceRoot $FenceRoot
    if ([string]$receipt.CommitIdentity.JournalFingerprint -ne [string]$commitIdentity.JournalFingerprint -or [string]$receipt.CommitIdentity.CommitContractFingerprint -ne [string]$commitIdentity.CommitContractFingerprint) { throw 'HC isolation attestation no longer matches the committed T14 installer contract.' }
    $adapter = Get-HetznerServiceAdapterIdentity -ServiceAdapterPath ([string]$receipt.Adapter.Path) -FenceRoot $FenceRoot
    if ([string]$adapter.Sha256 -ne [string]$receipt.Adapter.Sha256 -or [int64]$adapter.Bytes -ne [int64]$receipt.Adapter.Bytes) { throw 'HC isolation adapter changed after attestation.' }
    if($receipt.PSObject.Properties.Name-notcontains'AdapterConfiguration'){throw 'HC isolation attestation has no sealed adapter configuration.'}
    $adapterConfiguration=Get-HetznerAdapterConfigurationIdentity -AdapterConfigPath ([string]$receipt.AdapterConfiguration.Path) -FenceRoot $FenceRoot -LauncherIdentities $expected
    if([string]$adapterConfiguration.Sha256-ne[string]$receipt.AdapterConfiguration.Sha256 -or [int64]$adapterConfiguration.Bytes-ne[int64]$receipt.AdapterConfiguration.Bytes){throw 'HC isolation adapter configuration changed after attestation.'}
    $proofPlan = [pscustomobject]@{ AdapterId = [string]$receipt.Adapter.Id; ProfileName = $ProfileName; LauncherIdentities = $expected;ExpectedIsolation=@($adapterConfiguration.ExpectedIsolation); MinimumObservationSeconds = [int]$receipt.MinimumObservationSeconds }
    $baseline = Get-HetznerHCIsolationBaselineProjection -Evidence $receipt.Baseline -Plan $proofPlan
    try{$observationStartedUtc=ConvertTo-HetznerUtcTimestamp -Value $receipt.ObservationStartedUtc}catch{throw 'HC isolation receipt observation start is invalid.'}
    $attestation = Get-HetznerHCIsolationEvidenceProjection -Evidence $receipt.Attestation -Plan $proofPlan -ObservationStartedUtc $observationStartedUtc -HistoricalReceipt
    return [pscustomobject][ordered]@{ Path = $path; Sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant(); Bytes = [int64](Get-Item -LiteralPath $path).Length; PlanFingerprint = [string]$receipt.PlanFingerprint; Adapter = $adapter;AdapterConfiguration=$adapterConfiguration; CommitIdentity = $commitIdentity; AttestedAtUtc = $attestedAt.ToString('o'); Baseline = $baseline; Attestation = $attestation }
}

function New-HetznerServiceActivationPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$InstallRoot,
        [Parameter(Mandatory)][string]$FenceRoot,
        [Parameter(Mandatory)][ValidateSet('hc-0','hc-1','hc-2','hc-3')][string]$ProfileName,
        [Parameter(Mandatory)][string]$MissionPboPath,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ServiceName,
        [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$')][string]$AdapterId,
        [Parameter(Mandatory)][string]$ServiceAdapterPath,
        [Parameter(Mandatory)][string]$AdapterConfigPath,
        [string]$IsolationAttestationPath='',
        [ValidateRange(1,3600)][int]$MinimumObservationSeconds = 60
    )
    $install = Test-HetznerInstallPath -Path $InstallRoot -FenceRoot $FenceRoot
    $fence = Get-HetznerAbsolutePath $FenceRoot
    $profile = Get-HetznerInstallerProfile -Name $ProfileName
    if ([int]$profile.headlessClients -gt 2) { throw 'Three-HC service activation remains experimental and fail-closed pending measured runtime approval.' }
    $pbo = Get-HetznerMissionPboInfo -MissionPboPath $MissionPboPath
    Test-HetznerInstallation -InstallRoot $install -FenceRoot $fence -ProfileName $ProfileName -MissionPboPath $pbo.Path | Out-Null
    $adapter = Get-HetznerServiceAdapterIdentity -ServiceAdapterPath $ServiceAdapterPath -FenceRoot $fence
    $identities = @(Get-HetznerExpectedLauncherIdentities -Profile $profile -ProfileName $ProfileName)
    $adapterConfiguration=Get-HetznerAdapterConfigurationIdentity -AdapterConfigPath $AdapterConfigPath -FenceRoot $fence -LauncherIdentities $identities
    Assert-HetznerMiksuusTestServiceBinding -AdapterConfiguration $adapterConfiguration -ServiceName $ServiceName -MissionPbo $pbo
    $isolation=$null
    if([int]$profile.headlessClients-ge 2){if([string]::IsNullOrWhiteSpace($IsolationAttestationPath)){throw 'Primary two-HC service activation requires a sealed isolation attestation.'};$isolation=Get-HetznerHCIsolationAttestationIdentity -AttestationReceiptPath $IsolationAttestationPath -InstallRoot $install -FenceRoot $fence -ProfileName $ProfileName -Pbo $pbo;if([string]$isolation.AdapterConfiguration.Sha256-cne[string]$adapterConfiguration.Sha256){throw 'Service and isolation plans use different adapter configurations.'}}
    elseif(-not[string]::IsNullOrWhiteSpace($IsolationAttestationPath)){throw 'Fallback zero/one-HC service activation must not consume a multi-HC isolation attestation.'}
    $fingerprint = Get-HetznerServiceActivationPlanFingerprint -InstallRoot $install -FenceRoot $fence -ProfileName $ProfileName -MissionPboPath $pbo.Path -MissionPbo $pbo -ServiceName $ServiceName -AdapterId $AdapterId -ServiceAdapter $adapter -AdapterConfiguration $adapterConfiguration -IsolationAttestation $isolation -LauncherIdentities $identities -MinimumObservationSeconds $MinimumObservationSeconds
    return [pscustomobject][ordered]@{
        SchemaVersion = $script:SchemaVersion
        Action = 'ServiceActivationPlan'
        InstallRoot = $install
        FenceRoot = $fence
        ProfileName = $ProfileName
        MissionPboPath = $pbo.Path
        MissionPboLeaf = $pbo.Leaf
        MissionPboSha256 = $pbo.Sha256
        ServiceName = $ServiceName
        AdapterId = $AdapterId
        ServiceAdapter = $adapter
        AdapterConfiguration=$adapterConfiguration
        ExpectedIsolation=@($adapterConfiguration.ExpectedIsolation)
        IsolationAttestation = $isolation
        LauncherIdentities = $identities
        MinimumObservationSeconds = $MinimumObservationSeconds
        PlanFingerprint = $fingerprint
        ActivationReceiptPath = (Get-HetznerServiceActivationReceiptPath -InstallRoot $install -FenceRoot $fence -PlanFingerprint $fingerprint)
    }
}

function Assert-HetznerServiceActivationPlan {
    param([Parameter(Mandatory)]$Plan)
    foreach ($field in @('SchemaVersion','Action','InstallRoot','FenceRoot','ProfileName','MissionPboPath','MissionPboLeaf','MissionPboSha256','ServiceName','AdapterId','ServiceAdapter','AdapterConfiguration','ExpectedIsolation','IsolationAttestation','LauncherIdentities','MinimumObservationSeconds','PlanFingerprint','ActivationReceiptPath')) {
        if ($Plan.PSObject.Properties.Name -notcontains $field) { throw "Service activation plan is missing field: $field" }
    }
    if ([int]$Plan.SchemaVersion -ne $script:SchemaVersion -or [string]$Plan.Action -ne 'ServiceActivationPlan') { throw 'Service activation plan action or schema was tampered.' }
    $install = Test-HetznerInstallPath -Path ([string]$Plan.InstallRoot) -FenceRoot ([string]$Plan.FenceRoot)
    $fence = Get-HetznerAbsolutePath ([string]$Plan.FenceRoot)
    $profile = Get-HetznerInstallerProfile -Name ([string]$Plan.ProfileName)
    if ([int]$profile.headlessClients -gt 2) { throw 'Three-HC service activation remains experimental and fail-closed.' }
    $pbo = Get-HetznerMissionPboInfo -MissionPboPath ([string]$Plan.MissionPboPath)
    if ([string]$Plan.MissionPboLeaf -ne [string]$pbo.Leaf -or [string]$Plan.MissionPboSha256 -ne [string]$pbo.Sha256) { throw 'Service activation mission identity changed after planning.' }
    Test-HetznerInstallation -InstallRoot $install -FenceRoot $fence -ProfileName ([string]$Plan.ProfileName) -MissionPboPath $pbo.Path | Out-Null
    $adapter = Get-HetznerServiceAdapterIdentity -ServiceAdapterPath ([string]$Plan.ServiceAdapter.Path) -FenceRoot $fence
    if ([string]$adapter.Path -ne [string]$Plan.ServiceAdapter.Path -or [string]$adapter.Sha256 -ne [string]$Plan.ServiceAdapter.Sha256 -or [int64]$adapter.Bytes -ne [int64]$Plan.ServiceAdapter.Bytes) { throw 'Service adapter hash or size changed after planning.' }
    $expectedIdentities = @(Get-HetznerExpectedLauncherIdentities -Profile $profile -ProfileName ([string]$Plan.ProfileName))
    Assert-HetznerLauncherIdentitySet -Actual @($Plan.LauncherIdentities) -Expected $expectedIdentities -Label 'Service activation plan'
    $adapterConfiguration=Get-HetznerAdapterConfigurationIdentity -AdapterConfigPath ([string]$Plan.AdapterConfiguration.Path) -FenceRoot $fence -LauncherIdentities $expectedIdentities
    Assert-HetznerMiksuusTestServiceBinding -AdapterConfiguration $adapterConfiguration -ServiceName ([string]$Plan.ServiceName) -MissionPbo $pbo
    if([string]$adapterConfiguration.Sha256-cne[string]$Plan.AdapterConfiguration.Sha256 -or [int64]$adapterConfiguration.Bytes-ne[int64]$Plan.AdapterConfiguration.Bytes){throw 'Service adapter configuration changed after planning.'}
    $isolation=$null
    if([int]$profile.headlessClients-ge 2){$isolation=Get-HetznerHCIsolationAttestationIdentity -AttestationReceiptPath ([string]$Plan.IsolationAttestation.Path) -InstallRoot $install -FenceRoot $fence -ProfileName ([string]$Plan.ProfileName) -Pbo $pbo;if([string]$isolation.Path-ne[string]$Plan.IsolationAttestation.Path -or [string]$isolation.Sha256-ne[string]$Plan.IsolationAttestation.Sha256 -or [int64]$isolation.Bytes-ne[int64]$Plan.IsolationAttestation.Bytes -or [string]$isolation.PlanFingerprint-ne[string]$Plan.IsolationAttestation.PlanFingerprint -or [string]$isolation.AdapterConfiguration.Sha256-cne[string]$adapterConfiguration.Sha256){throw 'HC isolation attestation changed after service activation planning.'}}
    elseif($null-ne$Plan.IsolationAttestation){throw 'Fallback service activation plan contains an unexpected isolation attestation.'}
    $expectedFingerprint = Get-HetznerServiceActivationPlanFingerprint -InstallRoot $install -FenceRoot $fence -ProfileName ([string]$Plan.ProfileName) -MissionPboPath $pbo.Path -MissionPbo $pbo -ServiceName ([string]$Plan.ServiceName) -AdapterId ([string]$Plan.AdapterId) -ServiceAdapter $adapter -AdapterConfiguration $adapterConfiguration -IsolationAttestation $isolation -LauncherIdentities $expectedIdentities -MinimumObservationSeconds ([int]$Plan.MinimumObservationSeconds)
    if ([string]$Plan.PlanFingerprint -ne $expectedFingerprint) { throw 'Service activation plan fingerprint does not match the canonical contract.' }
    $expectedReceiptPath = Get-HetznerServiceActivationReceiptPath -InstallRoot $install -FenceRoot $fence -PlanFingerprint $expectedFingerprint
    if ([string]$Plan.ActivationReceiptPath -ne $expectedReceiptPath) { throw 'Service activation receipt path was tampered.' }
}

function Get-HetznerServiceEvidenceProjection {
    param([Parameter(Mandatory)]$Evidence, [Parameter(Mandatory)]$Plan)
    foreach ($field in @('AdapterId','ServiceName','ServiceStatus','MissionPboLeaf','MissionPboSha256','ConfigurationFingerprint','ServerRpt','HeadlessClients')) {
        if ($Evidence.PSObject.Properties.Name -notcontains $field) { throw "Service evidence is missing field: $field" }
    }
    if ([string]$Evidence.AdapterId -ne [string]$Plan.AdapterId) { throw 'Service evidence adapter identity mismatch.' }
    if ([string]$Evidence.ServiceName -ne [string]$Plan.ServiceName) { throw 'Service evidence service identity mismatch.' }
    if ([string]$Evidence.ServiceStatus -ne 'Running') { throw 'Service health requires the expected service to be Running.' }
    if ([string]$Evidence.MissionPboLeaf -notmatch '\.pbo$' -or [string]$Evidence.MissionPboSha256 -notmatch '^[0-9a-fA-F]{64}$') { throw 'Service evidence mission identity is invalid.' }
    if ([string]$Evidence.ConfigurationFingerprint -notmatch '^[0-9a-fA-F]{64}$') { throw 'Service evidence configuration fingerprint is invalid.' }
    $serverRpt = $Evidence.ServerRpt
    foreach ($field in @('Identity','LastWriteUtc')) {
        if ($serverRpt.PSObject.Properties.Name -notcontains $field) { throw "Service evidence server RPT is missing field: $field" }
    }
    if ([string]::IsNullOrWhiteSpace([string]$serverRpt.Identity)) { throw 'Service evidence server RPT identity is empty.' }
    try { $serverWrite = ConvertTo-HetznerUtcTimestamp -Value $serverRpt.LastWriteUtc } catch { throw 'Service evidence server RPT timestamp is invalid.' }
    $actualHcs = @($Evidence.HeadlessClients)
    $expectedHcs = @($Plan.LauncherIdentities)
    if ($actualHcs.Count -ne $expectedHcs.Count) { throw 'Service health HC evidence count does not match the selected profile.' }
    $hcProjection = @()
    foreach ($expected in $expectedHcs) {
        $matches = @($actualHcs | Where-Object { [string]$_.Name -eq [string]$expected.Name -and [string]$_.RptIdentity -eq [string]$expected.RptIdentity })
        if ($matches.Count -ne 1) { throw "Service health requires exactly one expected HC RPT identity: $($expected.RptIdentity)" }
        $match = $matches[0]
        if ($match.PSObject.Properties.Name -notcontains 'ProcessId' -or [int]$match.ProcessId -lt 1) { throw "Service health HC process identity is invalid: $($expected.RptIdentity)" }
        $hcProjection += [pscustomobject][ordered]@{ Name = [string]$match.Name; RptIdentity = [string]$match.RptIdentity; ProcessId = [int]$match.ProcessId }
    }
    return [pscustomobject][ordered]@{
        AdapterId = [string]$Evidence.AdapterId
        ServiceName = [string]$Evidence.ServiceName
        ServiceStatus = [string]$Evidence.ServiceStatus
        MissionPboLeaf = [string]$Evidence.MissionPboLeaf
        MissionPboSha256 = [string]$Evidence.MissionPboSha256
        ConfigurationFingerprint = [string]$Evidence.ConfigurationFingerprint
        ServerRptIdentity = [string]$serverRpt.Identity
        ServerRptLastWriteUtc = $serverWrite.ToString('o')
        HeadlessClients = @($hcProjection | Sort-Object RptIdentity)
    }
}

function Assert-HetznerServiceHealthEvidence {
    param([Parameter(Mandatory)]$Evidence, [Parameter(Mandatory)]$Baseline, [Parameter(Mandatory)]$Plan, [Parameter(Mandatory)][datetime]$ObservationStartedUtc)
    foreach ($field in @('ObservationWindowSeconds','FatalLineCount')) {
        if ($Evidence.PSObject.Properties.Name -notcontains $field) { throw "Service health evidence is missing field: $field" }
    }
    $projection = Get-HetznerServiceEvidenceProjection -Evidence $Evidence -Plan $Plan
    if ([string]$projection.MissionPboLeaf -ne [string]$Plan.MissionPboLeaf -or [string]$projection.MissionPboSha256 -ne [string]$Plan.MissionPboSha256) { throw 'Service health mission/release identity does not match the sealed activation plan.' }
    if ([int]$Evidence.ObservationWindowSeconds -lt [int]$Plan.MinimumObservationSeconds) { throw 'Service health observation window is shorter than the sealed minimum.' }
    if ([int]$Evidence.FatalLineCount -ne 0) { throw 'Service health fatal-free window contains fatal lines.' }
    try { $baselineWrite = ConvertTo-HetznerUtcTimestamp -Value $Baseline.ServerRptLastWriteUtc; $healthWrite = ConvertTo-HetznerUtcTimestamp -Value $projection.ServerRptLastWriteUtc } catch { throw 'Service health RPT timing evidence is invalid.' }
    if ($healthWrite -le $baselineWrite) { throw 'Service health server RPT did not advance after activation.' }
    $config=$Plan.AdapterConfiguration.Configuration
    if([string]$projection.ServerRptIdentity-cne[string]$config.ServerRptPath){throw 'Service health server RPT path differs from the sealed MIKSUUS-TEST configuration.'}
    if(-not(Test-Path -LiteralPath ([string]$config.ServerRptPath) -PathType Leaf)){throw 'Configured service RPT file is missing.'};$serverMeasured=(Get-Item -LiteralPath ([string]$config.ServerRptPath)).LastWriteTimeUtc
    if([Math]::Abs(($serverMeasured-$healthWrite).TotalSeconds)-gt 1 -or $healthWrite-lt$ObservationStartedUtc.AddSeconds(-2)){throw 'Service health server RPT did not advance in the measured observation window.'}
    if(-not(Test-Path -LiteralPath ([string]$config.MissionPboPath) -PathType Leaf)){throw 'Configured service mission PBO is missing.'}
    if([System.IO.Path]::GetFileName([string]$config.MissionPboPath)-cne[string]$Plan.MissionPboLeaf -or (Get-FileHash -LiteralPath ([string]$config.MissionPboPath) -Algorithm SHA256).Hash.ToLowerInvariant()-cne([string]$Plan.MissionPboSha256).ToLowerInvariant()){throw 'Configured service mission PBO differs from the sealed activation release.'}
    foreach($expected in @($Plan.ExpectedIsolation)){
        $matches=@($Evidence.HeadlessClients|Where-Object{[string]$_.Name-eq[string]$expected.Name -and [string]$_.RptIdentity-eq[string]$expected.RptIdentity})
        if($matches.Count-ne 1){throw "Service health does not contain the configured HC identity: $($expected.RptIdentity)"}
        foreach($field in @('SandboxRoot','ProfileRoot','RptPath','CommandLineFingerprint')){if([string]$matches[0].$field-cne[string]$expected.$field){throw "Service health differs from the sealed adapter configuration for $($expected.RptIdentity): $field"}}
        if($matches[0].PSObject.Properties.Name-notcontains'RptLastWriteUtc'){throw "Service health has no measured HC RPT timestamp: $($expected.RptIdentity)"};try{$reported=ConvertTo-HetznerUtcTimestamp -Value $matches[0].RptLastWriteUtc}catch{throw "Service health HC RPT timestamp is invalid: $($expected.RptIdentity)"}
        if(-not(Test-Path -LiteralPath ([string]$expected.RptPath) -PathType Leaf)){throw "Configured service HC RPT is missing: $($expected.RptIdentity)"};$actual=(Get-Item -LiteralPath ([string]$expected.RptPath)).LastWriteTimeUtc
        if([Math]::Abs(($actual-$reported).TotalSeconds)-gt 1 -or $reported-lt$ObservationStartedUtc.AddSeconds(-2)){throw "Service health HC RPT did not advance in the measured observation window: $($expected.RptIdentity)"}
    }
    $attestedClients=if($null-eq$Plan.IsolationAttestation){@()}else{@($Plan.IsolationAttestation.Attestation.HeadlessClients)}
    foreach ($attested in $attestedClients) {
        $matches = @($Evidence.HeadlessClients | Where-Object { [string]$_.Name -eq [string]$attested.Name -and [string]$_.RptIdentity -eq [string]$attested.RptIdentity })
        if ($matches.Count -ne 1) { throw "Service health does not contain the attested HC identity: $($attested.RptIdentity)" }
        foreach ($field in @('ProcessId','InstanceId','SandboxRoot','ProfileRoot','RptPath','CommandLineFingerprint')) {
            if ($matches[0].PSObject.Properties.Name -notcontains $field -or [string]$matches[0].$field -ne [string]$attested.$field) { throw "Service health no longer matches the sealed isolation attestation for $($attested.RptIdentity): $field" }
        }
        if ($matches[0].PSObject.Properties.Name -notcontains 'StartUtc') { throw "Service health no longer matches the sealed isolation attestation for $($attested.RptIdentity): StartUtc" }
        try {
            $healthStartUtc = ConvertTo-HetznerUtcTimestamp -Value $matches[0].StartUtc
            $attestedStartUtc = ConvertTo-HetznerUtcTimestamp -Value $attested.StartUtc
        } catch { throw "Service health contains an invalid HC start timestamp for $($attested.RptIdentity)." }
        if ($healthStartUtc -ne $attestedStartUtc) { throw "Service health no longer matches the sealed isolation attestation for $($attested.RptIdentity): StartUtc" }
    }
    return $projection
}

function Assert-HetznerBaselineRestored {
    param([Parameter(Mandatory)]$Baseline, [Parameter(Mandatory)]$RestoredEvidence, [Parameter(Mandatory)]$Plan)
    $restored = Get-HetznerServiceEvidenceProjection -Evidence $RestoredEvidence -Plan $Plan
    foreach ($field in @('ServiceName','ServiceStatus','MissionPboLeaf','MissionPboSha256','ConfigurationFingerprint','ServerRptIdentity')) {
        if ([string]$restored.$field -ne [string]$Baseline.$field) { throw "Restored baseline $field does not match the captured baseline." }
    }
    $baselineHcs = @($Baseline.HeadlessClients | ConvertTo-Json -Depth 8 -Compress)
    $restoredHcs = @($restored.HeadlessClients | ConvertTo-Json -Depth 8 -Compress)
    if (($baselineHcs -join '') -ne ($restoredHcs -join '')) { throw 'Restored baseline HC identities do not match the captured baseline.' }
}

function New-HetznerServiceAdapterRequest {
    param([Parameter(Mandatory)]$Plan, [Parameter(Mandatory)][ValidateSet('CaptureBaseline','ApplyActivation','ObserveHealth','RestoreBaseline','ObserveBaseline')][string]$Action, $Baseline = $null)
    return [pscustomobject][ordered]@{
        Action = $Action
        AdapterId = [string]$Plan.AdapterId
        ServiceName = [string]$Plan.ServiceName
        ProfileName = [string]$Plan.ProfileName
        MissionPboLeaf = [string]$Plan.MissionPboLeaf
        MissionPboSha256 = [string]$Plan.MissionPboSha256
        LauncherIdentities = @($Plan.LauncherIdentities)
        IsolationAttestation = $Plan.IsolationAttestation
        ExpectedIsolation=@($Plan.ExpectedIsolation)
        AdapterConfiguration=$Plan.AdapterConfiguration.Configuration
        MinimumObservationSeconds = [int]$Plan.MinimumObservationSeconds
        Baseline = $Baseline
    }
}

function Invoke-HetznerServiceAdapter {
    param([Parameter(Mandatory)]$Plan, [Parameter(Mandatory)][string]$Action, $Baseline = $null)
    $request = New-HetznerServiceAdapterRequest -Plan $Plan -Action $Action -Baseline $Baseline
    $result=Invoke-HetznerBoundAdapter -Adapter $Plan.ServiceAdapter -FenceRoot $Plan.FenceRoot -Request $request
    if ($null -eq $result) { throw "Service adapter action $Action returned no evidence." }
    if ($result.PSObject.Properties.Name -notcontains 'AdapterId' -or [string]$result.AdapterId -ne [string]$Plan.AdapterId) { throw "Service adapter action $Action has an unexpected adapter identity." }
    return $result
}

function Invoke-HetznerServiceActivationPlan {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Plan, [switch]$Apply)
    Assert-HetznerServiceActivationPlan -Plan $Plan
    if (-not $Apply) { return [pscustomobject]@{ Applied = $false; AdapterInvoked = $false; CommitState = 'DryRun'; ActivationReceiptPath = $Plan.ActivationReceiptPath } }
    $baseline = $null;$lock=$null;$activationAttempted=$false
    try {
        $paths=Get-HetznerTransactionPaths -InstallRoot ([string]$Plan.InstallRoot) -FenceRoot ([string]$Plan.FenceRoot)
        $lock=Enter-HetznerTransactionLock -Paths $paths
        Assert-HetznerServiceActivationPlan -Plan $Plan
        $baselineEvidence = Invoke-HetznerServiceAdapter -Plan $Plan -Action 'CaptureBaseline'
        $baseline = Get-HetznerServiceEvidenceProjection -Evidence $baselineEvidence -Plan $Plan
        Assert-HetznerServiceActivationPlan -Plan $Plan
        if([string]$baseline.MissionPboLeaf-cne[string]$Plan.MissionPboLeaf -or [string]$baseline.MissionPboSha256-cne[string]$Plan.MissionPboSha256){throw 'Captured service baseline mission identity differs from the sealed release; activation was not attempted.'}
        $activationAttempted=$true
        $applyEvidence = Invoke-HetznerServiceAdapter -Plan $Plan -Action 'ApplyActivation' -Baseline $baseline
        if ($applyEvidence.PSObject.Properties.Name -notcontains 'Applied' -or -not [bool]$applyEvidence.Applied) { throw 'Service adapter did not confirm activation was applied.' }
        $observationStartedUtc=[datetime]::UtcNow
        $healthEvidence = Invoke-HetznerServiceAdapter -Plan $Plan -Action 'ObserveHealth' -Baseline $baseline
        $health = Assert-HetznerServiceHealthEvidence -Evidence $healthEvidence -Baseline $baseline -Plan $Plan -ObservationStartedUtc $observationStartedUtc
        $receipt = [pscustomobject][ordered]@{
            SchemaVersion = $script:SchemaVersion
            ReceiptType = 'service-activation-v1'
            PlanFingerprint = [string]$Plan.PlanFingerprint
            Adapter = [pscustomobject][ordered]@{ Id = [string]$Plan.AdapterId; Path = [string]$Plan.ServiceAdapter.Path; Sha256 = [string]$Plan.ServiceAdapter.Sha256; Bytes = [int64]$Plan.ServiceAdapter.Bytes }
            MissionPboLeaf = [string]$Plan.MissionPboLeaf
            MissionPboSha256 = [string]$Plan.MissionPboSha256
            ObservationStartedUtc = $observationStartedUtc.ToString('o')
            Baseline = $baseline
            Health = $health
        }
        Assert-HetznerServiceActivationPlan -Plan $Plan
        Write-HetznerAtomicJson -Path ([string]$Plan.ActivationReceiptPath) -Value $receipt
        if (-not (Test-Path -LiteralPath $Plan.ActivationReceiptPath -PathType Leaf)) { throw 'Service activation receipt was not committed.' }
        return [pscustomobject]@{ Applied = $true; AdapterInvoked = $true; CommitState = 'CommittedAfterHealth'; ActivationReceiptPath = $Plan.ActivationReceiptPath; Receipt = $receipt }
    } catch {
        $failure = $_.Exception.Message
        if ($null -eq $baseline -or -not$activationAttempted) { throw }
        try {
            $restoreEvidence = Invoke-HetznerServiceAdapter -Plan $Plan -Action 'RestoreBaseline' -Baseline $baseline
            if ($restoreEvidence.PSObject.Properties.Name -notcontains 'Restored' -or -not [bool]$restoreEvidence.Restored) { throw 'Service adapter did not confirm baseline restore.' }
            $restoredEvidence = Invoke-HetznerServiceAdapter -Plan $Plan -Action 'ObserveBaseline' -Baseline $baseline
            Assert-HetznerBaselineRestored -Baseline $baseline -RestoredEvidence $restoredEvidence -Plan $Plan
        } catch { throw "Service activation failed: $failure; baseline recovery failed: $($_.Exception.Message)" }
        throw "Service activation health failed and baseline was restored: $failure"
    }finally{if($null-ne$lock){$lock.Dispose()}}
}

function Get-HetznerFreshBackupRoot {
    param([Parameter(Mandatory)][string]$FenceRoot)
    $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ')
    return Join-Path (Join-Path (Get-HetznerAbsolutePath $FenceRoot) 'backups') ("run-$stamp-" + [guid]::NewGuid().ToString('N'))
}

function New-HetznerBackupPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$InstallRoot,
        [AllowEmptyString()][string]$BackupRoot = '',
        [Parameter(Mandatory)][string]$FenceRoot
    )
    $install = Test-HetznerInstallPath -Path $InstallRoot -FenceRoot $FenceRoot
    $backup = if ([string]::IsNullOrWhiteSpace($BackupRoot)) { Get-HetznerFreshBackupRoot -FenceRoot $FenceRoot } else { Get-HetznerAbsolutePath $BackupRoot }
    Test-HetznerInstallPath -Path $backup -FenceRoot $FenceRoot | Out-Null
    Assert-HetznerPathsDisjoint -InstallRoot $install -BackupRoot $backup
    if (Test-Path -LiteralPath $backup) { throw "Backup root already exists; use a fresh immutable run-specific path: $backup" }
    return [pscustomobject]@{ SchemaVersion = $script:SchemaVersion; Action = 'Backup'; InstallRoot = $install; BackupRoot = $backup; FenceRoot = (Get-HetznerAbsolutePath $FenceRoot); ApplyRequired = $true }
}

function Assert-HetznerBackupRollbackState {
    param([Parameter(Mandatory)]$Plan, [Parameter(Mandatory)][ValidateSet('Backup','RollbackPlan')][string]$ExpectedAction)
    if ([int]$Plan.SchemaVersion -ne $script:SchemaVersion -or [string]$Plan.Action -ne $ExpectedAction) { throw "$ExpectedAction plan action or schema was tampered." }
    $install = Test-HetznerInstallPath -Path $Plan.InstallRoot -FenceRoot $Plan.FenceRoot
    $backup = Test-HetznerInstallPath -Path $Plan.BackupRoot -FenceRoot $Plan.FenceRoot
    Assert-HetznerPathsDisjoint -InstallRoot $install -BackupRoot $backup
    Assert-HetznerNoReparsePoints -Path $install -FenceRoot $Plan.FenceRoot | Out-Null
    Assert-HetznerNoReparsePoints -Path $backup -FenceRoot $Plan.FenceRoot | Out-Null
}

function Invoke-HetznerBackupPlan {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Plan, [switch]$Apply)
    Assert-HetznerBackupRollbackState -Plan $Plan -ExpectedAction Backup
    if (-not $Apply) { return [pscustomobject]@{ Applied = $false; Action = $Plan.Action; BackupRoot = $Plan.BackupRoot } }
    Assert-HetznerBackupRollbackState -Plan $Plan -ExpectedAction Backup
    if (Test-Path -LiteralPath $Plan.BackupRoot) { throw "Backup root already exists; refusing to replace it: $($Plan.BackupRoot)" }
    if (-not (Test-Path -LiteralPath $Plan.InstallRoot -PathType Container)) { throw "Install root not found: $($Plan.InstallRoot)" }
    Assert-HetznerNoReparseTree -Root $Plan.InstallRoot -FenceRoot $Plan.FenceRoot
    $items = @(Get-ChildItem -LiteralPath $Plan.InstallRoot -Force)
    foreach ($item in $items) { Assert-HetznerNoReparsePoints -Path $item.FullName -FenceRoot $Plan.FenceRoot | Out-Null; Assert-HetznerNoReparsePoints -Path (Join-Path $Plan.BackupRoot $item.Name) -FenceRoot $Plan.FenceRoot | Out-Null }
    New-Item -ItemType Directory -Path $Plan.BackupRoot -Force | Out-Null
    foreach ($item in $items) {
        Assert-HetznerNoReparsePoints -Path (Join-Path $Plan.BackupRoot $item.Name) -FenceRoot $Plan.FenceRoot | Out-Null
        Copy-Item -LiteralPath $item.FullName -Destination $Plan.BackupRoot -Recurse -Force
    }
    return [pscustomobject]@{ Applied = $true; Action = $Plan.Action; BackupRoot = $Plan.BackupRoot }
}

function Get-HetznerRollbackContractFingerprint {
    param([Parameter(Mandatory)]$Contract)
    $payload = [pscustomobject][ordered]@{
        SchemaVersion=[int]$Contract.SchemaVersion; ContractVersion=[int]$Contract.ContractVersion
        ContractType=[string]$Contract.ContractType; TransactionId=[string]$Contract.TransactionId
        InstallRoot=[string]$Contract.InstallRoot; FenceRoot=[string]$Contract.FenceRoot
        ApplyPlanFingerprint=[string]$Contract.ApplyPlanFingerprint; ProfileName=[string]$Contract.ProfileName
        MissionPboLeaf=[string]$Contract.MissionPboLeaf; MissionPboSha256=[string]$Contract.MissionPboSha256
        OwnershipSeal=$Contract.OwnershipSeal; ManagedFiles=@($Contract.ManagedFiles)
        OwnershipDecisions=@($Contract.OwnershipDecisions); Actions=@($Contract.Actions)
    }
    return Get-HetznerStringSha256 -Value (ConvertTo-Json -InputObject $payload -Depth 16 -Compress)
}

function New-HetznerSealedRollbackContract {
    param([Parameter(Mandatory)]$Journal, [Parameter(Mandatory)]$Paths)
    if ([string]$Journal.State -ne 'Committed') { throw 'A new sealed rollback contract requires a committed Apply transaction.' }
    Assert-HetznerTransactionJournal -Journal $Journal -Paths $Paths -VerifyPreimages
    Assert-HetznerCommitContract -Journal $Journal -Paths $Paths -VerifyCurrent | Out-Null
    $meta = Join-Path $Paths.InstallRoot '.hetzner-installer'
    $manifestPath = Join-Path $meta 'manifest.json'; $receiptPath = Join-Path $meta 'receipt.json'; $sealPath = Join-Path $meta 'ownership-seal.json'
    foreach ($path in @($manifestPath,$receiptPath,$sealPath)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Committed rollback metadata is incomplete.' }
        Assert-HetznerNoReparsePoints -Path $path -FenceRoot $Paths.FenceRoot | Out-Null
    }
    $ownershipSeal = Assert-HetznerOwnershipSeal -InstallRoot $Paths.InstallRoot
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
    $pbo = [pscustomobject]@{ Leaf=[string]$manifest.MissionPboLeaf; Sha256=[string]$manifest.MissionPboSha256 }
    $managed = @(Assert-HetznerManifestContract -Manifest $manifest -Receipt $receipt -InstallRoot $Paths.InstallRoot -ProfileName ([string]$manifest.ProfileName) -Pbo $pbo -FenceRoot $Paths.FenceRoot)
    $expectedManaged = @($managed | ForEach-Object { [string]$_.Path })
    $ownership = @(Get-HetznerOwnershipDecisionProjection -Decisions @($manifest.OwnershipDecisions) -InstallRoot $Paths.InstallRoot -ExpectedManagedPaths $expectedManaged -FenceRoot $Paths.FenceRoot)

    $managedByPath = @{}
    foreach ($record in $managed) {
        $path = Assert-HetznerSafeRelativePath -RelativePath ([string]$record.Path) -InstallRoot $Paths.InstallRoot
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Committed managed postimage is missing: $($record.Path)" }
        $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant(); $bytes = [int64](Get-Item -LiteralPath $path).Length
        if ($hash -cne ([string]$record.Sha256).ToLowerInvariant() -or $bytes -ne [int64]$record.Bytes) { throw "Committed managed postimage drift detected: $($record.Path)" }
        $managedByPath[[string]$record.Path] = [pscustomobject]@{ Kind='File'; Sha256=$hash; Bytes=$bytes }
    }
    $ownershipByPath = @{}
    foreach ($decision in $ownership) { $ownershipByPath[[string]$decision.Path] = $decision }
    $metadataByPath = @{}
    foreach ($relative in @('.hetzner-installer\manifest.json','.hetzner-installer\receipt.json','.hetzner-installer\ownership-seal.json')) {
        $path = Join-Path $Paths.InstallRoot $relative
        $metadataByPath[$relative] = [pscustomobject]@{ Kind='File'; Sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant(); Bytes=[int64](Get-Item -LiteralPath $path).Length }
    }

    $ordinary = @(); $directoryDeletes = @(); $directoryPreserves = @()
    foreach ($entry in @($Journal.Entries)) {
        $path = Get-HetznerAbsolutePath ([string]$entry.Path); $label = [string]$entry.Label
        $postKind='Missing'; $postHash=''; $postBytes=[int64]0
        if ($path -eq $Paths.InstallRoot -or $label -in @('profiles-pr8','mpmissions','.hetzner-installer')) {
            $postKind='Directory'
        } elseif ($managedByPath.ContainsKey($label)) {
            $postKind='File'; $postHash=[string]$managedByPath[$label].Sha256; $postBytes=[int64]$managedByPath[$label].Bytes
        } elseif ($metadataByPath.ContainsKey($label)) {
            $postKind='File'; $postHash=[string]$metadataByPath[$label].Sha256; $postBytes=[int64]$metadataByPath[$label].Bytes
        } elseif ($ownershipByPath.ContainsKey($label) -and [string]$ownershipByPath[$label].RollbackDisposition -ceq 'PreserveHost') {
            $postKind='File'; $postHash=[string]$ownershipByPath[$label].PostSha256; $postBytes=[int64]$ownershipByPath[$label].PostBytes
        }

        $mode='PreserveMissing'; $sourcePath=''
        if ($ownershipByPath.ContainsKey($label) -and [string]$ownershipByPath[$label].RollbackDisposition -ceq 'PreserveHost') {
            if ([string]$entry.PreKind -cne 'File' -or $postKind -cne 'File' -or [string]$entry.PreSha256 -cne $postHash -or [int64]$entry.PreBytes -ne $postBytes) { throw "Host-preserving rollback identity changed: $label" }
            $mode='PreserveHost'
        } elseif ([string]$entry.PreKind -eq 'File') {
            $mode='RestoreFile'
            if ($ownershipByPath.ContainsKey($label) -and [string]$ownershipByPath[$label].Disposition -ceq 'ReplaceWithBackup') {
                $decision=$ownershipByPath[$label]
                if ([string]$decision.PreSha256 -cne [string]$entry.PreSha256 -or [int64]$decision.PreBytes -ne [int64]$entry.PreBytes) { throw "Replacement backup and transaction preimage disagree: $label" }
                $sourcePath=Get-HetznerAbsolutePath ([string]$decision.BackupPath)
            } else {
                $sourcePath=Get-HetznerAbsolutePath (Join-Path $Paths.TransactionRoot ([string]$entry.Preimage))
            }
        } elseif ([string]$entry.PreKind -eq 'Directory') {
            if ($postKind -cne 'Directory') { throw "Rollback directory postimage changed kind: $label" }
            $mode='PreserveDirectory'
        } elseif ([string]$entry.PreKind -eq 'Missing') {
            if ($postKind -eq 'File') { $mode='DeleteFile' }
            elseif ($postKind -eq 'Directory') { $mode='DeleteDirectory' }
            elseif ($postKind -ne 'Missing') { throw "Rollback postimage kind is unsupported: $label" }
        } else { throw "Rollback preimage kind is unsupported: $label" }

        $action = [pscustomobject][ordered]@{
            ActionIndex=-1; EntryIndex=[int]$entry.Index; Path=$path; Label=$label; Mode=$mode
            PreKind=[string]$entry.PreKind; PreSha256=[string]$entry.PreSha256; PreBytes=[int64]$entry.PreBytes
            PostKind=$postKind; PostSha256=$postHash; PostBytes=$postBytes; SourcePath=$sourcePath
        }
        if ($mode -eq 'DeleteDirectory') { $directoryDeletes += $action }
        elseif ($mode -eq 'PreserveDirectory') { $directoryPreserves += $action }
        else { $ordinary += $action }
    }
    $ordered = @($ordinary | Sort-Object EntryIndex)
    $ordered += @($directoryDeletes | Sort-Object @{Expression={([string]$_.Path).Length};Descending=$true},EntryIndex)
    $ordered += @($directoryPreserves | Sort-Object EntryIndex)
    for ($index=0; $index -lt $ordered.Count; $index++) { $ordered[$index].ActionIndex=$index }

    $contract = [pscustomobject][ordered]@{
        SchemaVersion=$script:SchemaVersion; ContractVersion=1; ContractType='sealed-transaction-rollback-v1'
        TransactionId=[string]$Journal.TransactionId; InstallRoot=$Paths.InstallRoot; FenceRoot=$Paths.FenceRoot
        ApplyPlanFingerprint=[string]$Journal.PlanFingerprint; ProfileName=[string]$manifest.ProfileName
        MissionPboLeaf=[string]$manifest.MissionPboLeaf; MissionPboSha256=[string]$manifest.MissionPboSha256
        OwnershipSeal=$ownershipSeal; ManagedFiles=$managed; OwnershipDecisions=$ownership; Actions=$ordered; ContractFingerprint=''
    }
    $contract.ContractFingerprint = Get-HetznerRollbackContractFingerprint -Contract $contract
    return $contract
}

function Assert-HetznerSealedRollbackContract {
    param([Parameter(Mandatory)]$Contract, [Parameter(Mandatory)]$Journal, [Parameter(Mandatory)]$Paths)
    if ([int]$Contract.SchemaVersion -ne $script:SchemaVersion -or [int]$Contract.ContractVersion -ne 1 -or [string]$Contract.ContractType -ne 'sealed-transaction-rollback-v1') { throw 'Sealed rollback contract identity is invalid.' }
    if ([string]$Contract.TransactionId -cne [string]$Journal.TransactionId -or [string]$Contract.ApplyPlanFingerprint -cne [string]$Journal.PlanFingerprint) { throw 'Sealed rollback contract transaction identity changed.' }
    if ((Get-HetznerAbsolutePath ([string]$Contract.InstallRoot)) -ne $Paths.InstallRoot -or (Get-HetznerAbsolutePath ([string]$Contract.FenceRoot)) -ne $Paths.FenceRoot) { throw 'Sealed rollback contract path identity changed.' }
    if ([string]$Contract.ContractFingerprint -cne (Get-HetznerRollbackContractFingerprint -Contract $Contract)) { throw 'Sealed rollback contract fingerprint mismatch.' }
    $actions=@($Contract.Actions); $seen=@{}
    if ($actions.Count -ne @($Journal.Entries).Count) { throw 'Sealed rollback contract action set is incomplete.' }
    for ($index=0; $index -lt $actions.Count; $index++) {
        $action=$actions[$index]
        if ([int]$action.ActionIndex -ne $index -or [string]$action.Mode -notin @('RestoreFile','DeleteFile','DeleteDirectory','PreserveHost','PreserveDirectory','PreserveMissing')) { throw 'Sealed rollback action order or mode is invalid.' }
        $path=Get-HetznerAbsolutePath ([string]$action.Path)
        if ($path -ne $Paths.InstallRoot -and -not(Test-HetznerContainedPath -Path $path -Root $Paths.InstallRoot)) { throw 'Sealed rollback action escaped the install root.' }
        $key=$path.ToLowerInvariant(); if($seen.ContainsKey($key)){throw 'Sealed rollback contains a duplicate target.'};$seen[$key]=$true
        if ([string]$action.PreKind -notin @('File','Directory','Missing') -or [string]$action.PostKind -notin @('File','Directory','Missing')) { throw 'Sealed rollback path kind is invalid.' }
        if ([string]$action.Mode -eq 'RestoreFile') {
            $source=Get-HetznerAbsolutePath ([string]$action.SourcePath)
            if (-not(Test-HetznerContainedPath -Path $source -Root $Paths.TransactionRoot) -or -not(Test-Path -LiteralPath $source -PathType Leaf)) { throw 'Rollback backup or preimage is missing or escaped transaction storage.' }
            if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$action.PreSha256 -or [int64](Get-Item -LiteralPath $source).Length -ne [int64]$action.PreBytes) { throw 'Rollback backup or preimage hash or bytes are corrupt.' }
        }
    }
}

function Assert-HetznerRollbackPathIdentity {
    param([Parameter(Mandatory)]$Action, [Parameter(Mandatory)][ValidateSet('Pre','Post')][string]$Side)
    $path=[string]$Action.Path; $kind=[string]$Action.("${Side}Kind"); $hash=[string]$Action.("${Side}Sha256"); $bytes=[int64]$Action.("${Side}Bytes")
    if ($kind -eq 'Missing') { if (Test-Path -LiteralPath $path) { throw "Rollback $($Side.ToLowerInvariant())image drift: expected missing path $path" }; return }
    if ($kind -eq 'Directory') { if (-not(Test-Path -LiteralPath $path -PathType Container)) { throw "Rollback $($Side.ToLowerInvariant())image drift: expected directory $path" }; return }
    if (-not(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Rollback $($Side.ToLowerInvariant())image drift: expected file $path" }
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $hash -or [int64](Get-Item -LiteralPath $path).Length -ne $bytes) { throw "Rollback $($Side.ToLowerInvariant())image hash or bytes drift: $path" }
}

function Assert-HetznerRollbackProgressPreflight {
    param([Parameter(Mandatory)]$Contract, [Parameter(Mandatory)]$Journal, [Parameter(Mandatory)]$Paths, [Parameter(Mandatory)][int]$CompletedOperationIndex)
    Assert-HetznerSealedRollbackContract -Contract $Contract -Journal $Journal -Paths $Paths
    if (Test-Path -LiteralPath $Paths.InstallRoot -PathType Container) { Assert-HetznerNoReparseTree -Root $Paths.InstallRoot -FenceRoot $Paths.FenceRoot }
    $allowed=@{}; foreach($action in @($Contract.Actions)){$allowed[(Get-HetznerAbsolutePath ([string]$action.Path)).ToLowerInvariant()]=$true}
    foreach($directoryAction in @($Contract.Actions | Where-Object { [string]$_.Mode -eq 'DeleteDirectory' })) {
        $directory=[string]$directoryAction.Path
        if (-not(Test-Path -LiteralPath $directory -PathType Container)) { continue }
        foreach($item in @(Get-ChildItem -LiteralPath $directory -Force -Recurse -ErrorAction Stop)) {
            $key=(Get-HetznerAbsolutePath $item.FullName).ToLowerInvariant()
            if(-not$allowed.ContainsKey($key)){throw "Rollback preflight found unexpected host content in an installer-created directory: $($item.FullName)"}
        }
    }
    foreach($action in @($Contract.Actions)) {
        if ([int]$action.ActionIndex -le $CompletedOperationIndex) { Assert-HetznerRollbackPathIdentity -Action $action -Side Pre }
        else { Assert-HetznerRollbackPathIdentity -Action $action -Side Post }
    }
}

function Get-HetznerRollbackPlanFingerprint {
    param([Parameter(Mandatory)]$Contract)
    $value=[pscustomobject][ordered]@{SchemaVersion=$script:SchemaVersion;Action='RollbackPlan';RollbackMode='SealedTransaction';TransactionId=[string]$Contract.TransactionId;InstallRoot=[string]$Contract.InstallRoot;FenceRoot=[string]$Contract.FenceRoot;ContractFingerprint=[string]$Contract.ContractFingerprint}
    return Get-HetznerStringSha256 -Value ($value|ConvertTo-Json -Compress)
}

function New-HetznerRollbackPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$InstallRoot,
        [string]$BackupRoot = '',
        [Parameter(Mandatory)][string]$FenceRoot
    )
    $install = Test-HetznerInstallPath -Path $InstallRoot -FenceRoot $FenceRoot
    $fence = Get-HetznerAbsolutePath $FenceRoot
    if (-not [string]::IsNullOrWhiteSpace($BackupRoot)) {
        $backup = Test-HetznerInstallPath -Path $BackupRoot -FenceRoot $FenceRoot
        Assert-HetznerPathsDisjoint -InstallRoot $install -BackupRoot $backup
        if (-not (Test-Path -LiteralPath $backup -PathType Container)) { throw "Backup root not found: $backup" }
        return [pscustomobject]@{ SchemaVersion=$script:SchemaVersion; Action='RollbackPlan'; RollbackMode='LegacyBackup'; InstallRoot=$install; BackupRoot=$backup; FenceRoot=$fence; ApplyRequired=$false; ApplySupported=$false; Limitation='Unsealed whole-tree backup restore remains disabled; use the committed transaction journal.' }
    }
    $paths=Get-HetznerTransactionPaths -InstallRoot $install -FenceRoot $fence
    $status=Get-HetznerTransactionStatus -InstallRoot $install -FenceRoot $fence
    if($status.State -notin @('Committed','RollingBack','RolledBack')){throw "Sealed rollback requires a committed or in-progress rollback transaction; current state: $($status.State)"}
    $contract=if($status.State -eq 'Committed'){New-HetznerSealedRollbackContract -Journal $status.Journal -Paths $paths}else{
        if($status.Journal.PSObject.Properties.Name -notcontains 'RollbackContract'){throw 'In-progress rollback journal has no sealed rollback contract.'}
        $status.Journal.RollbackContract
    }
    Assert-HetznerSealedRollbackContract -Contract $contract -Journal $status.Journal -Paths $paths
    return [pscustomobject]@{
        SchemaVersion=$script:SchemaVersion; Action='RollbackPlan'; RollbackMode='SealedTransaction'; InstallRoot=$install; FenceRoot=$fence
        TransactionId=[string]$contract.TransactionId; Contract=$contract; ContractFingerprint=[string]$contract.ContractFingerprint
        PlanFingerprint=(Get-HetznerRollbackPlanFingerprint -Contract $contract); ApplyRequired=($status.State -ne 'RolledBack'); ApplySupported=$true; State=[string]$status.State
    }
}

function Assert-HetznerSealedRollbackPlanState {
    param([Parameter(Mandatory)]$Plan)
    if([int]$Plan.SchemaVersion -ne $script:SchemaVersion -or [string]$Plan.Action -ne 'RollbackPlan' -or [string]$Plan.RollbackMode -ne 'SealedTransaction'){throw 'Sealed rollback plan action, mode, or schema was tampered.'}
    $paths=Get-HetznerTransactionPaths -InstallRoot ([string]$Plan.InstallRoot) -FenceRoot ([string]$Plan.FenceRoot)
    $embeddedFingerprint=Get-HetznerRollbackContractFingerprint -Contract $Plan.Contract
    if([string]$Plan.ContractFingerprint -cne [string]$Plan.Contract.ContractFingerprint -or [string]$Plan.ContractFingerprint -cne $embeddedFingerprint -or [string]$Plan.PlanFingerprint -cne (Get-HetznerRollbackPlanFingerprint -Contract $Plan.Contract)){throw 'Sealed rollback plan fingerprint was tampered.'}
    return $paths
}

function Invoke-HetznerRollbackPlan {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Plan, [switch]$Apply, [int]$FailAfterOperationIndex = -1)
    if([string]$Plan.RollbackMode -eq 'LegacyBackup'){
        Assert-HetznerBackupRollbackState -Plan $Plan -ExpectedAction RollbackPlan
        if(-not$Apply){return [pscustomobject]@{Applied=$false;ApplySupported=$false;Action=$Plan.Action;RollbackMode=$Plan.RollbackMode;InstallRoot=$Plan.InstallRoot;BackupRoot=$Plan.BackupRoot;Limitation=$Plan.Limitation}}
        throw 'Rollback Apply is disabled for unsealed whole-tree backups; use the committed transaction journal.'
    }
    $paths=Assert-HetznerSealedRollbackPlanState -Plan $Plan
    if(-not$Apply){return [pscustomobject]@{Applied=$false;ApplySupported=$true;Action=$Plan.Action;RollbackMode=$Plan.RollbackMode;InstallRoot=$Plan.InstallRoot;State=$Plan.State;Actions=@($Plan.Contract.Actions|Select-Object ActionIndex,Mode,Label)}}
    $lock=$null
    try{
        $lock=Enter-HetznerTransactionLock -Paths $paths
        $status=Get-HetznerTransactionStatus -InstallRoot $paths.InstallRoot -FenceRoot $paths.FenceRoot
        $journal=$status.Journal
        if([string]$journal.TransactionId -cne [string]$Plan.TransactionId){throw 'Rollback plan transaction identity changed.'}
        if($status.State -eq 'RolledBack'){
            if($journal.PSObject.Properties.Name -notcontains 'RollbackContract'){throw 'Rolled-back transaction journal lost its sealed rollback contract.'}
            $contract=$journal.RollbackContract
            if([string]$contract.ContractFingerprint -cne [string]$Plan.ContractFingerprint){throw 'Rolled-back rollback contract differs from the plan.'}
            $finalOperationIndex=@($contract.Actions).Count-1
            if([string]$journal.Phase -cne 'RolledBack' -or [int]$journal.OperationIndex -ne $finalOperationIndex){throw 'Rolled-back transaction progress marker is inconsistent.'}
            Assert-HetznerRollbackProgressPreflight -Contract $contract -Journal $journal -Paths $paths -CompletedOperationIndex $finalOperationIndex
            return [pscustomobject]@{Applied=$true;Action=$Plan.Action;State='RolledBack';InstallRoot=$paths.InstallRoot;OperationIndex=[int]$journal.OperationIndex}
        }
        if($status.State -eq 'Committed'){
            $contract=New-HetznerSealedRollbackContract -Journal $journal -Paths $paths
            if([string]$contract.ContractFingerprint -cne [string]$Plan.ContractFingerprint){throw 'Committed rollback contract changed after planning.'}
            Assert-HetznerRollbackProgressPreflight -Contract $contract -Journal $journal -Paths $paths -CompletedOperationIndex -1
            $journal|Add-Member -NotePropertyName RollbackContract -NotePropertyValue $contract -Force
            $journal.JournalFingerprint=Get-HetznerTransactionJournalFingerprint -Journal $journal
            $journal.State='RollingBack';$journal.Phase='Rollback';$journal.OperationIndex=-1
            Save-HetznerTransactionJournal -Journal $journal -Paths $paths
        }elseif($status.State -eq 'RollingBack'){
            if($journal.PSObject.Properties.Name -notcontains 'RollbackContract'){throw 'Rolling rollback journal lost its sealed contract.'}
            $contract=$journal.RollbackContract
            if([string]$contract.ContractFingerprint -cne [string]$Plan.ContractFingerprint){throw 'Rolling rollback contract differs from the plan.'}
            Assert-HetznerRollbackProgressPreflight -Contract $contract -Journal $journal -Paths $paths -CompletedOperationIndex ([int]$journal.OperationIndex)
        }else{throw "Rollback Apply cannot run from transaction state: $($status.State)"}

        foreach($action in @($contract.Actions|Where-Object{[int]$_.ActionIndex -gt [int]$journal.OperationIndex}|Sort-Object ActionIndex)){
            $path=[string]$action.Path
            switch([string]$action.Mode){
                'RestoreFile'{Copy-HetznerFileAtomicVerified -Source ([string]$action.SourcePath) -Destination $path -ExpectedSha256 ([string]$action.PreSha256) -ExpectedBytes ([int64]$action.PreBytes) -Purpose recover}
                'DeleteFile'{if(Test-Path -LiteralPath $path -PathType Leaf){Remove-Item -LiteralPath $path -Force}}
                'DeleteDirectory'{if(Test-Path -LiteralPath $path -PathType Container){if(@(Get-ChildItem -LiteralPath $path -Force).Count-ne 0){throw "Rollback directory is not empty after child restoration: $path"};Remove-Item -LiteralPath $path -Force}}
                'PreserveHost'{}
                'PreserveDirectory'{}
                'PreserveMissing'{}
                default{throw 'Unknown sealed rollback action mode.'}
            }
            $journal.OperationIndex=[int]$action.ActionIndex;Save-HetznerTransactionJournal -Journal $journal -Paths $paths
            if($FailAfterOperationIndex -eq [int]$action.ActionIndex){throw "Injected interruption failpoint: rollback operation $($action.ActionIndex)"}
        }
        foreach($action in @($contract.Actions)){Assert-HetznerRollbackPathIdentity -Action $action -Side Pre}
        $journal.State='RolledBack';$journal.Phase='RolledBack';Save-HetznerTransactionJournal -Journal $journal -Paths $paths
        return [pscustomobject]@{Applied=$true;Action=$Plan.Action;State='RolledBack';InstallRoot=$paths.InstallRoot;OperationIndex=[int]$journal.OperationIndex}
    }finally{if($null-ne$lock){$lock.Dispose()}}
}

function Get-HetznerUninstallContractFingerprint {
    param([Parameter(Mandatory)]$Contract)
    $value=[pscustomobject][ordered]@{
        SchemaVersion=[int]$Contract.SchemaVersion;ContractVersion=[int]$Contract.ContractVersion;ContractType=[string]$Contract.ContractType
        TransactionId=[string]$Contract.TransactionId;InstallRoot=[string]$Contract.InstallRoot;FenceRoot=[string]$Contract.FenceRoot
        ApplyPlanFingerprint=[string]$Contract.ApplyPlanFingerprint;ProfileName=[string]$Contract.ProfileName
        MissionPboLeaf=[string]$Contract.MissionPboLeaf;MissionPboSha256=[string]$Contract.MissionPboSha256
        ManagedFiles=@($Contract.ManagedFiles);OwnershipDecisions=@($Contract.OwnershipDecisions);Actions=@($Contract.Actions)
    }
    return Get-HetznerStringSha256 -Value ($value|ConvertTo-Json -Depth 16 -Compress)
}

function Assert-HetznerUninstallDispositionContract {
    param([Parameter(Mandatory)]$Contract)
    $actions=@($Contract.Actions)
    foreach($decision in @($Contract.OwnershipDecisions)){
        $relative=[string]$decision.Path;$matches=@($actions|Where-Object{[string]$_.Label -ceq $relative})
        if($matches.Count-ne 1){throw "Uninstall disposition has no unique sealed action: $relative"};$action=$matches[0]
        if([string]$decision.UninstallDisposition -ceq 'PreserveHost'){
            if([string]$action.Mode -cne 'PreserveHost' -or [string]$action.PreKind -cne 'File' -or [string]$action.PostKind -cne 'File' -or [string]$action.PreSha256 -cne [string]$action.PostSha256 -or [int64]$action.PreBytes-ne[int64]$action.PostBytes){throw "PreserveHost uninstall disposition does not map to an exact host-preserving action: $relative"}
        }elseif([string]$decision.UninstallDisposition -ceq 'RestoreBackup'){
            $backup=Get-HetznerAbsolutePath ([string]$decision.BackupPath)
            if([string]$action.Mode -cne 'RestoreFile' -or (Get-HetznerAbsolutePath ([string]$action.SourcePath))-ne$backup -or [string]$action.PreSha256 -cne [string]$decision.BackupSha256 -or [int64]$action.PreBytes-ne[int64]$decision.BackupBytes){throw "RestoreBackup uninstall disposition does not map to its sealed backup: $relative"}
        }else{throw "Unknown uninstall disposition in sealed ownership contract: $relative"}
    }
}

function Assert-HetznerUninstallContract {
    param([Parameter(Mandatory)]$Contract,[Parameter(Mandatory)]$Paths,[AllowNull()]$Journal=$null)
    if([int]$Contract.SchemaVersion-ne$script:SchemaVersion -or [int]$Contract.ContractVersion-ne 1 -or [string]$Contract.ContractType-cne'sealed-transaction-uninstall-v1'){throw 'Sealed uninstall contract identity is invalid.'}
    if((Get-HetznerAbsolutePath ([string]$Contract.InstallRoot))-ne$Paths.InstallRoot -or (Get-HetznerAbsolutePath ([string]$Contract.FenceRoot))-ne$Paths.FenceRoot){throw 'Sealed uninstall contract path identity changed.'}
    if($null-ne$Journal -and ([string]$Contract.TransactionId-cne[string]$Journal.TransactionId -or [string]$Contract.ApplyPlanFingerprint-cne[string]$Journal.PlanFingerprint)){throw 'Sealed uninstall contract transaction identity changed.'}
    if([string]$Contract.ContractFingerprint-cne(Get-HetznerUninstallContractFingerprint -Contract $Contract)){throw 'Sealed uninstall contract fingerprint mismatch.'}
    $actions=@($Contract.Actions);if($actions.Count-lt 4){throw 'Sealed uninstall contract action set is incomplete.'};$seen=@{}
    for($index=0;$index-lt$actions.Count;$index++){
        $action=$actions[$index]
        if([int]$action.ActionIndex-ne$index -or [string]$action.Mode-notin@('RestoreFile','DeleteFile','DeleteDirectory','PreserveHost')){throw 'Sealed uninstall action order or mode is invalid.'}
        $path=Get-HetznerAbsolutePath ([string]$action.Path);if($path-ne$Paths.InstallRoot -and -not(Test-HetznerContainedPath -Path $path -Root $Paths.InstallRoot)){throw 'Sealed uninstall action escaped the install root.'}
        $key=$path.ToLowerInvariant();if($seen.ContainsKey($key)){throw 'Sealed uninstall contract contains a duplicate target.'};$seen[$key]=$true
        if([string]$action.PreKind-notin@('File','Directory','Missing') -or [string]$action.PostKind-notin@('File','Directory','Missing')){throw 'Sealed uninstall path kind is invalid.'}
        if([string]$action.Mode-eq'RestoreFile'){
            $source=Get-HetznerAbsolutePath ([string]$action.SourcePath)
            if(-not(Test-HetznerContainedPath -Path $source -Root $Paths.TransactionRoot) -or -not(Test-Path -LiteralPath $source -PathType Leaf)){throw 'Uninstall backup is missing or escaped transaction storage.'}
            if((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()-cne[string]$action.PreSha256 -or [int64](Get-Item -LiteralPath $source).Length-ne[int64]$action.PreBytes){throw 'Uninstall backup hash or bytes are corrupt.'}
        }
    }
    Assert-HetznerUninstallDispositionContract -Contract $Contract
}

function New-HetznerSealedUninstallContract {
    param([Parameter(Mandatory)]$Journal,[Parameter(Mandatory)]$Paths)
    if([string]$Journal.State-cne'Committed'){throw 'A new uninstall contract requires a committed Apply transaction.'}
    Assert-HetznerTransactionJournal -Journal $Journal -Paths $Paths -VerifyPreimages
    Assert-HetznerCommitContract -Journal $Journal -Paths $Paths -VerifyCurrent|Out-Null
    $meta=Join-Path $Paths.InstallRoot '.hetzner-installer';$manifestPath=Join-Path $meta 'manifest.json';$receiptPath=Join-Path $meta 'receipt.json';$sealPath=Join-Path $meta 'ownership-seal.json'
    $ownershipSeal=Assert-HetznerOwnershipSeal -InstallRoot $Paths.InstallRoot
    $manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json;$receipt=Get-Content -LiteralPath $receiptPath -Raw|ConvertFrom-Json
    $pbo=[pscustomobject]@{Leaf=[string]$manifest.MissionPboLeaf;Sha256=[string]$manifest.MissionPboSha256}
    $managed=@(Assert-HetznerManifestContract -Manifest $manifest -Receipt $receipt -InstallRoot $Paths.InstallRoot -ProfileName ([string]$manifest.ProfileName) -Pbo $pbo -FenceRoot $Paths.FenceRoot)
    $expected=@($managed|ForEach-Object{[string]$_.Path});$ownership=@(Get-HetznerOwnershipDecisionProjection -Decisions @($manifest.OwnershipDecisions) -InstallRoot $Paths.InstallRoot -ExpectedManagedPaths $expected -FenceRoot $Paths.FenceRoot)
    $decisionByPath=@{};foreach($decision in $ownership){$decisionByPath[[string]$decision.Path]=$decision}
    $actions=@()
    foreach($record in $managed){
        $relative=[string]$record.Path;$path=Assert-HetznerSafeRelativePath -RelativePath $relative -InstallRoot $Paths.InstallRoot
        if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Managed uninstall postimage is missing: $relative"}
        $postHash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant();$postBytes=[int64](Get-Item -LiteralPath $path).Length
        if($postHash-cne([string]$record.Sha256).ToLowerInvariant() -or $postBytes-ne[int64]$record.Bytes){throw "Managed uninstall postimage drift detected: $relative"}
        $mode='DeleteFile';$preKind='Missing';$preHash='';$preBytes=[int64]0;$source=''
        if($decisionByPath.ContainsKey($relative)){
            $decision=$decisionByPath[$relative]
            if([string]$decision.UninstallDisposition-ceq'PreserveHost'){$mode='PreserveHost';$preKind='File';$preHash=[string]$decision.PreSha256;$preBytes=[int64]$decision.PreBytes}
            elseif([string]$decision.UninstallDisposition-ceq'RestoreBackup'){$mode='RestoreFile';$preKind='File';$preHash=[string]$decision.BackupSha256;$preBytes=[int64]$decision.BackupBytes;$source=Get-HetznerAbsolutePath ([string]$decision.BackupPath)}
        }
        $actions += [pscustomobject][ordered]@{ActionIndex=-1;Path=$path;Label=$relative;Mode=$mode;PreKind=$preKind;PreSha256=$preHash;PreBytes=$preBytes;PostKind='File';PostSha256=$postHash;PostBytes=$postBytes;SourcePath=$source}
    }
    foreach($decision in @($ownership|Where-Object{-not($expected-ccontains[string]$_.Path)})){
        $path=Assert-HetznerSafeRelativePath -RelativePath ([string]$decision.Path) -InstallRoot $Paths.InstallRoot
        if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Preserved host uninstall path is missing: $($decision.Path)"}
        $actions += [pscustomobject][ordered]@{ActionIndex=-1;Path=$path;Label=[string]$decision.Path;Mode='PreserveHost';PreKind='File';PreSha256=[string]$decision.PreSha256;PreBytes=[int64]$decision.PreBytes;PostKind='File';PostSha256=[string]$decision.PostSha256;PostBytes=[int64]$decision.PostBytes;SourcePath=''}
    }
    foreach($metadata in @([pscustomobject]@{Path=$manifestPath;Label='.hetzner-installer\manifest.json'},[pscustomobject]@{Path=$receiptPath;Label='.hetzner-installer\receipt.json'},[pscustomobject]@{Path=$sealPath;Label='.hetzner-installer\ownership-seal.json'})){
        $actions += [pscustomobject][ordered]@{ActionIndex=-1;Path=[string]$metadata.Path;Label=[string]$metadata.Label;Mode='DeleteFile';PreKind='Missing';PreSha256='';PreBytes=[int64]0;PostKind='File';PostSha256=(Get-FileHash -LiteralPath $metadata.Path -Algorithm SHA256).Hash.ToLowerInvariant();PostBytes=[int64](Get-Item -LiteralPath $metadata.Path).Length;SourcePath=''}
    }
    $actions += [pscustomobject][ordered]@{ActionIndex=-1;Path=$meta;Label='.hetzner-installer';Mode='DeleteDirectory';PreKind='Missing';PreSha256='';PreBytes=[int64]0;PostKind='Directory';PostSha256='';PostBytes=[int64]0;SourcePath=''}
    $ordinary=@($actions|Where-Object{[string]$_.Mode-ne'DeleteDirectory'}|Sort-Object Label);$directories=@($actions|Where-Object{[string]$_.Mode-eq'DeleteDirectory'}|Sort-Object @{Expression={([string]$_.Path).Length};Descending=$true});$ordered=@($ordinary)+@($directories)
    for($index=0;$index-lt$ordered.Count;$index++){$ordered[$index].ActionIndex=$index}
    $contract=[pscustomobject][ordered]@{SchemaVersion=$script:SchemaVersion;ContractVersion=1;ContractType='sealed-transaction-uninstall-v1';TransactionId=[string]$Journal.TransactionId;InstallRoot=$Paths.InstallRoot;FenceRoot=$Paths.FenceRoot;ApplyPlanFingerprint=[string]$Journal.PlanFingerprint;ProfileName=[string]$manifest.ProfileName;MissionPboLeaf=[string]$manifest.MissionPboLeaf;MissionPboSha256=[string]$manifest.MissionPboSha256;ManagedFiles=$managed;OwnershipDecisions=$ownership;Actions=$ordered;ContractFingerprint=''}
    $contract.ContractFingerprint=Get-HetznerUninstallContractFingerprint -Contract $contract
    Assert-HetznerUninstallContract -Contract $contract -Paths $Paths -Journal $Journal
    return $contract
}

function Assert-HetznerUninstallProgressPreflight {
    param([Parameter(Mandatory)]$Contract,[Parameter(Mandatory)]$Paths,[Parameter(Mandatory)][int]$CompletedOperationIndex,[int]$PendingOperationIndex=-1)
    Assert-HetznerUninstallContract -Contract $Contract -Paths $Paths
    $allowed=@{};foreach($action in @($Contract.Actions)){$allowed[(Get-HetznerAbsolutePath ([string]$action.Path)).ToLowerInvariant()]=$true}
    foreach($directoryAction in @($Contract.Actions|Where-Object{[string]$_.Mode-eq'DeleteDirectory'})){
        $directory=[string]$directoryAction.Path;if(-not(Test-Path -LiteralPath $directory -PathType Container)){continue}
        foreach($item in @(Get-ChildItem -LiteralPath $directory -Force -Recurse -ErrorAction Stop)){if(-not$allowed.ContainsKey((Get-HetznerAbsolutePath $item.FullName).ToLowerInvariant())){throw "Uninstall preflight found unexpected host content in an installer-owned directory: $($item.FullName)"}}
    }
    foreach($action in @($Contract.Actions)){
        $index=[int]$action.ActionIndex
        if($index-le$CompletedOperationIndex){Assert-HetznerRollbackPathIdentity -Action $action -Side Pre}
        elseif($index-eq$PendingOperationIndex){
            try{Assert-HetznerRollbackPathIdentity -Action $action -Side Post}catch{try{Assert-HetznerRollbackPathIdentity -Action $action -Side Pre}catch{throw "Pending uninstall action is neither sealed pre-state nor post-state: $($action.Label)"}}
        }else{Assert-HetznerRollbackPathIdentity -Action $action -Side Post}
    }
}

function Get-HetznerUninstallPlanFingerprint {
    param([Parameter(Mandatory)]$Contract)
    $value=[pscustomobject][ordered]@{SchemaVersion=$script:SchemaVersion;Action='UninstallPlan';UninstallMode='SealedTransaction';TransactionId=[string]$Contract.TransactionId;InstallRoot=[string]$Contract.InstallRoot;FenceRoot=[string]$Contract.FenceRoot;ProfileName=[string]$Contract.ProfileName;MissionPboLeaf=[string]$Contract.MissionPboLeaf;MissionPboSha256=[string]$Contract.MissionPboSha256;ContractFingerprint=[string]$Contract.ContractFingerprint}
    return Get-HetznerStringSha256 -Value ($value|ConvertTo-Json -Compress)
}

function New-HetznerUninstallPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$InstallRoot,
        [Parameter(Mandatory)][string]$FenceRoot,
        [Parameter(Mandatory)][ValidateSet('hc-0','hc-1','hc-2','hc-3')][string]$ProfileName,
        [Parameter(Mandatory)][string]$MissionPboPath
    )
    $install = Test-HetznerInstallPath -Path $InstallRoot -FenceRoot $FenceRoot
    $pbo = Get-HetznerMissionPboInfo -MissionPboPath $MissionPboPath
    $paths=Get-HetznerTransactionPaths -InstallRoot $install -FenceRoot $FenceRoot;$status=Get-HetznerTransactionStatus -InstallRoot $install -FenceRoot $FenceRoot
    if($status.State-notin@('Committed','Uninstalling','Uninstalled')){throw "Uninstall requires a committed or in-progress uninstall transaction; current state: $($status.State)"}
    $contract=if($status.State-eq'Committed'){New-HetznerSealedUninstallContract -Journal $status.Journal -Paths $paths}else{if($status.Journal.PSObject.Properties.Name-notcontains'UninstallContract'){throw 'In-progress uninstall journal has no sealed uninstall contract.'};$status.Journal.UninstallContract}
    Assert-HetznerUninstallContract -Contract $contract -Paths $paths -Journal $status.Journal
    if ([string]$contract.ProfileName -cne $ProfileName) { throw 'Uninstall profile identity differs from the sealed transaction.' }
    if ([string]$contract.MissionPboLeaf -cne [string]$pbo.Leaf -or [string]$contract.MissionPboSha256 -cne [string]$pbo.Sha256) { throw 'Uninstall PBO identity differs from the sealed transaction.' }
    Assert-HetznerUninstallDispositionContract -Contract $contract
    return [pscustomobject]@{
        SchemaVersion=$script:SchemaVersion; Action='UninstallPlan'; UninstallMode='SealedTransaction'
        InstallRoot=$install; FenceRoot=(Get-HetznerAbsolutePath $FenceRoot); ProfileName=$ProfileName
        MissionPboLeaf=[string]$contract.MissionPboLeaf; MissionPboSha256=[string]$contract.MissionPboSha256
        ExpectedManagedPaths=@($contract.ManagedFiles | ForEach-Object { [string]$_.Path })
        TransactionId=[string]$contract.TransactionId; Contract=$contract; ContractFingerprint=[string]$contract.ContractFingerprint
        PlanFingerprint=(Get-HetznerUninstallPlanFingerprint -Contract $contract)
        ApplyRequired=($status.State-ne'Uninstalled');ApplySupported=$true;State=[string]$status.State
    }
}

function Assert-HetznerUninstallPlanState {
    param([Parameter(Mandatory)]$Plan)
    if ([int]$Plan.SchemaVersion -ne $script:SchemaVersion -or [string]$Plan.Action -ne 'UninstallPlan' -or [string]$Plan.UninstallMode -ne 'SealedTransaction') { throw 'Uninstall plan action, mode, or schema was tampered.' }
    $install = Test-HetznerInstallPath -Path ([string]$Plan.InstallRoot) -FenceRoot ([string]$Plan.FenceRoot)
    if ([string]$Plan.Contract.ProfileName -cne [string]$Plan.ProfileName -or [string]$Plan.Contract.MissionPboLeaf -cne [string]$Plan.MissionPboLeaf -or [string]$Plan.Contract.MissionPboSha256 -cne [string]$Plan.MissionPboSha256) { throw 'Uninstall profile or PBO identity was tampered.' }
    Assert-HetznerExactPathSet -Actual @($Plan.ExpectedManagedPaths) -Expected @($Plan.Contract.ManagedFiles | ForEach-Object { [string]$_.Path }) -Label 'Uninstall plan managed set'
    foreach ($relative in @($Plan.ExpectedManagedPaths)) { Assert-HetznerSafeRelativePath -RelativePath ([string]$relative) -InstallRoot $install | Out-Null }
    $paths=Get-HetznerTransactionPaths -InstallRoot $install -FenceRoot ([string]$Plan.FenceRoot)
    if([string]$Plan.ContractFingerprint-cne[string]$Plan.Contract.ContractFingerprint -or [string]$Plan.ContractFingerprint-cne(Get-HetznerUninstallContractFingerprint -Contract $Plan.Contract) -or [string]$Plan.PlanFingerprint-cne(Get-HetznerUninstallPlanFingerprint -Contract $Plan.Contract)){throw 'Uninstall plan fingerprint was tampered.'}
    Assert-HetznerUninstallContract -Contract $Plan.Contract -Paths $paths
    return $paths
}

function Invoke-HetznerUninstallPlan {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Plan, [switch]$Apply, [int]$FailAfterIntentIndex=-1, [int]$FailAfterMutationIndex=-1, [int]$FailAfterOperationIndex = -1)
    $paths=Assert-HetznerUninstallPlanState -Plan $Plan
    if (-not $Apply) { return [pscustomobject]@{ Applied=$false; ApplySupported=$true; Action='UninstallPlan'; UninstallMode='SealedTransaction'; InstallRoot=$Plan.InstallRoot; State=$Plan.State; Actions=@($Plan.Contract.Actions | Select-Object ActionIndex,Mode,Label) } }
    $lock=$null
    try{
        $lock=Enter-HetznerTransactionLock -Paths $paths;$status=Get-HetznerTransactionStatus -InstallRoot $paths.InstallRoot -FenceRoot $paths.FenceRoot;$journal=$status.Journal
        if([string]$journal.TransactionId-cne[string]$Plan.TransactionId){throw 'Uninstall plan transaction identity changed.'}
        if($status.State-eq'Uninstalled'){
            if($journal.PSObject.Properties.Name-notcontains'UninstallContract'){throw 'Uninstalled transaction lost its sealed contract.'};$contract=$journal.UninstallContract
            if([string]$contract.ContractFingerprint-cne[string]$Plan.ContractFingerprint){throw 'Uninstalled contract differs from the plan.'};$final=@($contract.Actions).Count-1
            if([string]$journal.Phase-cne'Uninstalled' -or [int]$journal.OperationIndex-ne$final -or [int]$journal.PendingOperationIndex-ne-1){throw 'Uninstalled progress marker is inconsistent.'};Assert-HetznerUninstallProgressPreflight -Contract $contract -Paths $paths -CompletedOperationIndex $final
            return [pscustomobject]@{Applied=$true;ApplySupported=$true;Action='UninstallPlan';UninstallMode='SealedTransaction';UninstallState='Uninstalled';State='Uninstalled';InstallRoot=$paths.InstallRoot;OperationIndex=[int]$journal.OperationIndex}
        }
        if($status.State-eq'Committed'){
            $contract=New-HetznerSealedUninstallContract -Journal $journal -Paths $paths
            if([string]$contract.ContractFingerprint-cne[string]$Plan.ContractFingerprint){throw 'Committed uninstall contract changed after planning.'}
            Assert-HetznerUninstallProgressPreflight -Contract $contract -Paths $paths -CompletedOperationIndex -1
            $journal|Add-Member -NotePropertyName UninstallContract -NotePropertyValue $contract -Force;$journal|Add-Member -NotePropertyName PendingOperationIndex -NotePropertyValue (-1) -Force;$journal.JournalFingerprint=Get-HetznerTransactionJournalFingerprint -Journal $journal;$journal.State='Uninstalling';$journal.Phase='Uninstall';$journal.OperationIndex=-1;Save-HetznerTransactionJournal -Journal $journal -Paths $paths
        }elseif($status.State-eq'Uninstalling'){
            if($journal.PSObject.Properties.Name-notcontains'UninstallContract'){throw 'Uninstalling journal lost its sealed contract.'};$contract=$journal.UninstallContract
            if([string]$contract.ContractFingerprint-cne[string]$Plan.ContractFingerprint){throw 'Uninstalling contract differs from the plan.'};Assert-HetznerUninstallProgressPreflight -Contract $contract -Paths $paths -CompletedOperationIndex ([int]$journal.OperationIndex) -PendingOperationIndex ([int]$journal.PendingOperationIndex)
        }else{throw "Uninstall Apply cannot run from transaction state: $($status.State)"}
        foreach($action in @($contract.Actions|Where-Object{[int]$_.ActionIndex-gt[int]$journal.OperationIndex}|Sort-Object ActionIndex)){
            $path=[string]$action.Path
            if([int]$journal.PendingOperationIndex-ne[int]$action.ActionIndex){if([int]$journal.PendingOperationIndex-ne-1){throw 'Uninstall journal has a different pending action than the next sealed action.'};$journal.PendingOperationIndex=[int]$action.ActionIndex;Save-HetznerTransactionJournal -Journal $journal -Paths $paths}
            if($FailAfterIntentIndex-eq[int]$action.ActionIndex){throw "Injected interruption failpoint: uninstall intent $($action.ActionIndex)"}
            switch([string]$action.Mode){'RestoreFile'{Copy-HetznerFileAtomicVerified -Source ([string]$action.SourcePath) -Destination $path -ExpectedSha256 ([string]$action.PreSha256) -ExpectedBytes ([int64]$action.PreBytes) -Purpose recover};'DeleteFile'{if(Test-Path -LiteralPath $path -PathType Leaf){Remove-Item -LiteralPath $path -Force}};'DeleteDirectory'{if(Test-Path -LiteralPath $path -PathType Container){if(@(Get-ChildItem -LiteralPath $path -Force).Count-ne 0){throw "Uninstall directory is not empty after child removal: $path"};Remove-Item -LiteralPath $path -Force}};'PreserveHost'{};default{throw 'Unknown sealed uninstall action mode.'}}
            if($FailAfterMutationIndex-eq[int]$action.ActionIndex){throw "Injected interruption failpoint: uninstall mutation $($action.ActionIndex)"}
            $journal.OperationIndex=[int]$action.ActionIndex;$journal.PendingOperationIndex=-1;Save-HetznerTransactionJournal -Journal $journal -Paths $paths;if($FailAfterOperationIndex-eq[int]$action.ActionIndex){throw "Injected interruption failpoint: uninstall operation $($action.ActionIndex)"}
        }
        foreach($action in @($contract.Actions)){Assert-HetznerRollbackPathIdentity -Action $action -Side Pre};$journal.PendingOperationIndex=-1;$journal.State='Uninstalled';$journal.Phase='Uninstalled';Save-HetznerTransactionJournal -Journal $journal -Paths $paths
        return [pscustomobject]@{Applied=$true;ApplySupported=$true;Action='UninstallPlan';UninstallMode='SealedTransaction';UninstallState='Uninstalled';State='Uninstalled';InstallRoot=$paths.InstallRoot;OperationIndex=[int]$journal.OperationIndex}
    }finally{if($null-ne$lock){$lock.Dispose()}}
}

Export-ModuleMember -Function @(
    'Get-HetznerInstallerProfiles','Get-HetznerInstallerProfile','Test-HetznerInstallPath','Test-HetznerPreflight',
    'Get-HetznerMissionPboInfo','New-HetznerPlan','Invoke-HetznerPlan','Test-HetznerInstallation',
    'Get-HetznerTransactionStatus','Invoke-HetznerRecoverPlan',
    'New-HetznerHCIsolationAttestationPlan','Invoke-HetznerHCIsolationAttestationPlan',
    'New-HetznerServiceActivationPlan','Invoke-HetznerServiceActivationPlan',
    'New-HetznerBackupPlan','Invoke-HetznerBackupPlan','New-HetznerRollbackPlan','Invoke-HetznerRollbackPlan',
    'New-HetznerUninstallPlan','Invoke-HetznerUninstallPlan'
)
