#requires -Version 5.1
<##
.SYNOPSIS
    Dependency-free contract tests for the offline Hetzner installer.

.DESCRIPTION
    These tests deliberately use a temporary staging root. They never connect to a
    host, start a process, or mutate the repository checkout.
##>
$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot 'HetznerInstaller.psm1'
Import-Module -Force -Name $modulePath

$script:fails = 0

function Assert([bool]$Condition, [string]$Name) {
    if ($Condition) { Write-Host "  PASS  $Name" }
    else { Write-Host "  FAIL  $Name" -ForegroundColor Red; $script:fails++ }
}

function Assert-Throws([scriptblock]$Body, [string]$Name, [string]$MessagePattern = '') {
    $threw = $false
    $message = ''
    try { & $Body } catch { $threw = $true; $message = $_.Exception.Message }
    Assert $threw $Name
    if ($MessagePattern) { Assert ($message -match $MessagePattern) "$Name (message)" }
}

function New-Fixture {
    $root = Join-Path $env:TEMP ('hetzner-installer-test-' + [guid]::NewGuid().ToString('N'))
    $source = Join-Path $root 'source'
    $fence = Join-Path $root 'staging'
    $install = Join-Path $fence 'offline-install'
    New-Item -ItemType Directory -Path (Join-Path $source 'server-config') -Force | Out-Null
    New-Item -ItemType Directory -Path $fence -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $source 'server-config\basic.cfg'), 'MaxSizeGuaranteed = 512;')
    [System.IO.File]::WriteAllText((Join-Path $source 'server-config\server-pr8.cfg'), 'passwordAdmin = "__REDACTED_SET_ON_HOST__";')
    $pbo = Join-Path $source 'candidate.chernarus.pbo'
    [System.IO.File]::WriteAllBytes($pbo, [byte[]](0x50, 0x42, 0x4F, 0x01, 0x02, 0x03, 0x04))
    return [pscustomobject]@{ Root = $root; Source = $source; Fence = $fence; Install = $install; Pbo = $pbo }
}

function Remove-Fixture($Fixture) {
    if ($script:testJunctions) {
        foreach ($junction in @($script:testJunctions)) {
            if (Test-Path -LiteralPath $junction) {
                try { [System.IO.Directory]::Delete($junction, $false) } catch { }
                try { Remove-Item -LiteralPath $junction -Force -Recurse -ErrorAction SilentlyContinue } catch { }
            }
        }
    }
    if ($Fixture -and (Test-Path -LiteralPath $Fixture.Root)) {
        Remove-Item -LiteralPath $Fixture.Root -Recurse -Force
    }
}

$fixture = New-Fixture
try {
    Write-Host 'TEST 1: profiles cover server-only through three headless clients'
    $profiles = Get-HetznerInstallerProfiles
    Assert ($profiles.Count -eq 4) 'T1 four profiles are available'
    Assert ((Get-HetznerInstallerProfile -Name 'hc-3').HeadlessClients -eq 3) 'T1 hc-3 has three clients'
    Assert (-not (Get-HetznerInstallerProfile -Name 'hc-2').Operational -and -not (Get-HetznerInstallerProfile -Name 'hc-3').Operational) 'T1 HC2/HC3 remain non-operational without isolation adapter'
    Assert ((Get-HetznerInstallerProfile -Name 'hc-3').steamIsolationAdapter -eq 'windows-service-adapter-v1' -and (Get-HetznerInstallerProfile -Name 'hc-3').topology -eq 'experimental-three-hc-bound-adapter-required') 'T1 HC3 records explicit experimental isolation requirement'
    Write-Host 'TEST 1b: wrapper resolves its repository source root when omitted'
    $wrapper = Join-Path $PSScriptRoot 'Invoke-HetznerInstaller.ps1'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $wrapper -Action Preflight -ProfileName hc-0 -Json | Out-Null
    Assert ($LASTEXITCODE -eq 0) 'T1b wrapper default SourceRoot works'

    Write-Host 'TEST 1c: every HC uses port 2302 and has a unique stable control name'
    $launcherPlan = New-HetznerPlan -SourceRoot $fixture.Source -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-3' -MissionPboPath $fixture.Pbo
    $launchers = @($launcherPlan.Operations | Where-Object { $_.Kind -eq 'GenerateLauncher' })
    Assert (($launchers | Where-Object { $_.Content -notmatch '-port=2302' }).Count -eq 0) 'T1c all HC launchers use port 2302'
    Assert (($launchers | Where-Object { $_.Content -match '-name=HC-AI-Control-[1-3]' }).Count -eq 3) 'T1c HC launchers have unique control names'
    Assert (($launchers | Where-Object { $_.Content -match '\$env:WASP_HC_PASSWORD' }).Count -eq 3) 'T1c launchers consume host-provided password variable through the adapter'
    Assert (($launchers | Where-Object { $_.Content -match '%WASP_HC_PASSWORD%' }).Count -eq 0) 'T1c batch layer does not expand a password value'

    Write-Host 'TEST 1d: profile strings reject batch metacharacters and duplicate identities'
    $unsafeProfilePath = Join-Path $fixture.Root 'unsafe-profiles.json'
    $unsafeProfiles = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'profiles.json') -Raw | ConvertFrom-Json
    $unsafeProfiles.profiles[0].hcModLine = '@good&bad'
    [System.IO.File]::WriteAllText($unsafeProfilePath, ($unsafeProfiles | ConvertTo-Json -Depth 8))
    Assert-Throws { Get-HetznerInstallerProfiles -ProfilesPath $unsafeProfilePath } 'T1d batch metacharacter rejected' 'metachar|unsafe|batch'
    $duplicateProfilePath = Join-Path $fixture.Root 'duplicate-profiles.json'
    $duplicateProfiles = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'profiles.json') -Raw | ConvertFrom-Json
    $duplicateProfiles.profiles[1].name = $duplicateProfiles.profiles[0].name
    [System.IO.File]::WriteAllText($duplicateProfilePath, ($duplicateProfiles | ConvertTo-Json -Depth 8))
    Assert-Throws { Get-HetznerInstallerProfiles -ProfilesPath $duplicateProfilePath } 'T1d duplicate profile identity rejected' 'unique|duplicate'

    Write-Host 'TEST 2: preflight rejects incomplete source inputs'
    $missingSource = Join-Path $fixture.Root 'missing-source'
    Assert-Throws { Test-HetznerPreflight -SourceRoot $missingSource -ProfileName 'hc-0' } 'T2 missing source rejected' 'server-config|not found'
    Write-Host 'TEST 2b: preflight reports a valid PBO and rejects missing/non-PBO inputs'
    $preflightWithPbo = Test-HetznerPreflight -SourceRoot $fixture.Source -ProfileName 'hc-0' -MissionPboPath $fixture.Pbo
    Assert ($preflightWithPbo.MissionPboLeaf -eq 'candidate.chernarus.pbo') 'T2b preflight reports PBO leaf'
    Assert ([string]::IsNullOrWhiteSpace($preflightWithPbo.MissionPboSha256) -eq $false) 'T2b preflight reports PBO hash'
    Assert-Throws { Test-HetznerPreflight -SourceRoot $fixture.Source -ProfileName 'hc-0' -MissionPboPath (Join-Path $fixture.Root 'missing.pbo') } 'T2b missing PBO rejected' 'pbo|not found'
    $notPbo = Join-Path $fixture.Root 'candidate.txt'
    Set-Content -LiteralPath $notPbo -Value 'not a pbo'
    Assert-Throws { Test-HetznerPreflight -SourceRoot $fixture.Source -ProfileName 'hc-0' -MissionPboPath $notPbo } 'T2b non-PBO rejected' 'pbo|extension'
    Assert-Throws { New-HetznerPlan -SourceRoot $fixture.Source -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-0' } 'T2b plan requires MissionPboPath' 'MissionPboPath|pbo'

    Write-Host 'TEST 3: path fence rejects host-shaped and out-of-fence install roots'
    Assert-Throws { New-HetznerPlan -SourceRoot $fixture.Source -InstallRoot (Join-Path $fixture.Root 'outside') -FenceRoot $fixture.Fence -ProfileName 'hc-0' -MissionPboPath $fixture.Pbo } 'T3 out-of-fence path rejected' 'fence|within'
    Assert-Throws { Test-HetznerInstallPath -Path 'C:\WASP\profiles-pr8' -FenceRoot $fixture.Fence } 'T3 host path rejected' 'host|WASP|fence'
    Assert-Throws { New-HetznerBackupPlan -InstallRoot $fixture.Install -BackupRoot $fixture.Fence -FenceRoot $fixture.Fence } 'T3 backup parent of install rejected' 'disjoint|inside|outside'
    Assert-Throws { New-HetznerBackupPlan -InstallRoot $fixture.Install -BackupRoot $fixture.Install -FenceRoot $fixture.Fence } 'T3 backup equal to install rejected' 'disjoint|inside'
    Write-Host 'TEST 3b: reparse points are rejected from the fence through mutation targets'
    $reparseTarget = Join-Path $fixture.Root 'reparse-target'
    $reparseLink = Join-Path $fixture.Fence 'reparse-link'
    New-Item -ItemType Directory -Path $reparseTarget -Force | Out-Null
    New-Item -ItemType Junction -Path $reparseLink -Target $reparseTarget -Force | Out-Null
    $script:testJunctions = @($reparseLink)
    Assert-Throws { Test-HetznerInstallPath -Path (Join-Path $reparseLink 'install') -FenceRoot $fixture.Fence } 'T3b reparse point in target path rejected' 'reparse|junction|link'
    $reparseInstall = Join-Path $fixture.Fence 'reparse-install'
    $reparseInstallTarget = Join-Path $fixture.Root 'reparse-install-target'
    New-Item -ItemType Directory -Path $reparseInstallTarget -Force | Out-Null
    $reparsePlan = New-HetznerPlan -SourceRoot $fixture.Source -InstallRoot (Join-Path $fixture.Fence 'reparse-install') -FenceRoot $fixture.Fence -ProfileName 'hc-0' -MissionPboPath $fixture.Pbo
    New-Item -ItemType Junction -Path $reparseInstall -Target $reparseInstallTarget -Force | Out-Null
    $script:testJunctions += $reparseInstall
    Assert-Throws { Invoke-HetznerPlan -Plan $reparsePlan -Apply } 'T3b reparse point created after planning rejected' 'reparse|junction|link'

    Write-Host 'TEST 4: dry-run plan is complete and writes nothing'
    $plan = New-HetznerPlan -SourceRoot $fixture.Source -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-3' -MissionPboPath $fixture.Pbo
    Assert ($plan.HeadlessClients -eq 3) 'T4 plan records three clients'
    Assert (@($plan.Operations | Where-Object { $_.Kind -eq 'GenerateLauncher' }).Count -eq 3) 'T4 plan contains three launcher operations'
    $hasCanonicalDescriptors = $plan.PSObject.Properties.Name -contains 'CanonicalOperationDescriptors'
    Assert ($hasCanonicalDescriptors -and @($plan.CanonicalOperationDescriptors).Count -eq @($plan.Operations).Count) 'T4 plan records canonical operation descriptors'
    $hasSourceFiles = $plan.PSObject.Properties.Name -contains 'SourceFiles'
    Assert ($hasSourceFiles -and @($plan.SourceFiles).Count -eq 2 -and (@($plan.SourceFiles | Where-Object { $_.Sha256 -match '^[0-9a-f]{64}$' }).Count -eq 2)) 'T4 plan records source config hashes'
    Assert (-not (Test-Path -LiteralPath $fixture.Install)) 'T4 plan does not create install root'

    Write-Host 'TEST 5: mutation requires explicit -Apply'
    $result = Invoke-HetznerPlan -Plan $plan
    Assert (-not $result.Applied) 'T5 no Apply means no mutation'
    Assert (-not (Test-Path -LiteralPath $fixture.Install)) 'T5 no Apply leaves filesystem unchanged'
    Write-Host 'TEST 5b: Apply rejects a tampered operation path outside the install root'
    $unsafePlan = New-HetznerPlan -SourceRoot $fixture.Source -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-0' -MissionPboPath $fixture.Pbo
    $unsafePlan.Operations[2].TargetPath = Join-Path $fixture.Fence 'escaped.cfg'
    Assert-Throws { Invoke-HetznerPlan -Plan $unsafePlan -Apply } 'T5b operation target escape rejected' 'install root|fence|managed path|canonical|operation|drift'
    $unsafeRelativePlan = New-HetznerPlan -SourceRoot $fixture.Source -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-0' -MissionPboPath $fixture.Pbo
    ($unsafeRelativePlan.Operations | Where-Object { $_.Kind -eq 'CopyFile' } | Select-Object -First 1).RelativePath = '..\escape.cfg'
    Assert-Throws { Invoke-HetznerPlan -Plan $unsafeRelativePlan -Apply } 'T5b operation relative traversal rejected' 'traversal|unsafe|relative|canonical|operation|drift'
    try { & powershell -NoProfile -ExecutionPolicy Bypass -File $wrapper -Action DryRun -SourceRoot $fixture.Source -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName hc-0 2>&1 | Out-Null } catch { }
    Assert ($LASTEXITCODE -ne 0) 'T5b wrapper DryRun requires MissionPboPath'

    Write-Host 'TEST 5c: Apply re-derives the exact canonical operation sequence and source hashes'
    $contentPlan = New-HetznerPlan -SourceRoot $fixture.Source -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-1' -MissionPboPath $fixture.Pbo
    ($contentPlan.Operations | Where-Object { $_.Kind -eq 'GenerateLauncher' } | Select-Object -First 1).Content += "`r`necho injected"
    Assert-Throws { Invoke-HetznerPlan -Plan $contentPlan -Apply } 'T5c launcher content drift rejected' 'canonical|operation|content|drift'
    if (Test-Path -LiteralPath $fixture.Install) { Remove-Item -LiteralPath $fixture.Install -Recurse -Force }
    $kindPlan = New-HetznerPlan -SourceRoot $fixture.Source -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-1' -MissionPboPath $fixture.Pbo
    ($kindPlan.Operations | Where-Object { $_.Kind -eq 'CopyFile' } | Select-Object -First 1).Kind = 'GenerateLauncher'
    Assert-Throws { Invoke-HetznerPlan -Plan $kindPlan -Apply } 'T5c operation kind drift rejected' 'canonical|operation|kind|drift'
    if (Test-Path -LiteralPath $fixture.Install) { Remove-Item -LiteralPath $fixture.Install -Recurse -Force }
    $extraPlan = New-HetznerPlan -SourceRoot $fixture.Source -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-1' -MissionPboPath $fixture.Pbo
    $extraPlan.Operations += [pscustomobject]@{ Kind = 'GenerateLauncher'; RelativePath = 'extra.cmd'; SourcePath = ''; TargetPath = (Join-Path $fixture.Install 'extra.cmd'); Content = '@echo off' }
    Assert-Throws { Invoke-HetznerPlan -Plan $extraPlan -Apply } 'T5c extra in-fence operation rejected' 'canonical|operation|count|drift'
    if (Test-Path -LiteralPath $fixture.Install) { Remove-Item -LiteralPath $fixture.Install -Recurse -Force }
    $orderPlan = New-HetznerPlan -SourceRoot $fixture.Source -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-1' -MissionPboPath $fixture.Pbo
    $firstOperation = $orderPlan.Operations[0]
    $orderPlan.Operations[0] = $orderPlan.Operations[1]
    $orderPlan.Operations[1] = $firstOperation
    Assert-Throws { Invoke-HetznerPlan -Plan $orderPlan -Apply } 'T5c operation order drift rejected' 'canonical|operation|order|drift'
    if (Test-Path -LiteralPath $fixture.Install) { Remove-Item -LiteralPath $fixture.Install -Recurse -Force }
    $sourceDriftPlan = New-HetznerPlan -SourceRoot $fixture.Source -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-1' -MissionPboPath $fixture.Pbo
    $basicSourcePath = Join-Path $fixture.Source 'server-config\basic.cfg'
    $originalBasicSource = [System.IO.File]::ReadAllText($basicSourcePath)
    [System.IO.File]::WriteAllText($basicSourcePath, 'MaxSizeGuaranteed = 999;')
    Assert-Throws { Invoke-HetznerPlan -Plan $sourceDriftPlan -Apply } 'T5c source config hash drift rejected' 'source|hash|changed|drift'
    [System.IO.File]::WriteAllText($basicSourcePath, $originalBasicSource)
    if (Test-Path -LiteralPath $fixture.Install) { Remove-Item -LiteralPath $fixture.Install -Recurse -Force }

    Write-Host 'TEST 5d: non-empty roots without complete installer ownership metadata fail closed'
    $unownedInstall = Join-Path $fixture.Fence 'preexisting-unowned'
    New-Item -ItemType Directory -Path (Join-Path $unownedInstall 'profiles-pr8') -Force | Out-Null
    $unownedBasicPath = Join-Path $unownedInstall 'profiles-pr8\basic.cfg'
    [System.IO.File]::WriteAllText($unownedBasicPath, 'host-owned-content')
    $unownedPlan = New-HetznerPlan -SourceRoot $fixture.Source -InstallRoot $unownedInstall -FenceRoot $fixture.Fence -ProfileName 'hc-0' -MissionPboPath $fixture.Pbo
    Assert-Throws { Invoke-HetznerPlan -Plan $unownedPlan -Apply } 'T5d unowned non-empty install rejected before overwrite' 'metadata|ownership|adoption|non-empty'
    Assert ([System.IO.File]::ReadAllText($unownedBasicPath) -eq 'host-owned-content') 'T5d pre-existing target remains unchanged'

    Write-Host 'TEST 6: explicit local apply creates configs, three launchers, and a safe receipt'
    $result = Invoke-HetznerPlan -Plan $plan -Apply
    Assert $result.Applied 'T6 Apply reports applied'
    Assert (Test-Path -LiteralPath (Join-Path $fixture.Install 'profiles-pr8\basic.cfg')) 'T6 basic.cfg installed'
    Assert (Test-Path -LiteralPath (Join-Path $fixture.Install 'hc3_launch.cmd')) 'T6 HC3 launcher installed'
    Assert (Test-Path -LiteralPath (Join-Path $fixture.Install 'mpmissions\candidate.chernarus.pbo')) 'T6 mission PBO installed under mpmissions'
    Assert (Test-Path -LiteralPath (Join-Path $fixture.Install '.hetzner-installer\receipt.json')) 'T6 receipt installed'
    $manifestForPbo = Get-Content -LiteralPath (Join-Path $fixture.Install '.hetzner-installer\manifest.json') -Raw | ConvertFrom-Json
    Assert ($manifestForPbo.MissionPboLeaf -eq 'candidate.chernarus.pbo' -and $manifestForPbo.MissionPboSha256 -eq (Get-FileHash -LiteralPath $fixture.Pbo -Algorithm SHA256).Hash.ToLowerInvariant()) 'T6 manifest records mission PBO hash'
    $receiptText = Get-Content -LiteralPath (Join-Path $fixture.Install '.hetzner-installer\receipt.json') -Raw
    Assert ($receiptText -notmatch '(?i)password|secret|token|private.?key') 'T6 receipt contains no secret-shaped fields'

    Write-Host 'TEST 7: repeated apply is idempotent and verify detects tampering'
    $manifestBefore = Get-Content -LiteralPath (Join-Path $fixture.Install '.hetzner-installer\manifest.json') -Raw
    $second = Invoke-HetznerPlan -Plan $plan -Apply
    $manifestAfter = Get-Content -LiteralPath (Join-Path $fixture.Install '.hetzner-installer\manifest.json') -Raw
    Assert $second.Applied 'T7 repeated Apply remains successful'
    Assert ($manifestBefore -eq $manifestAfter) 'T7 repeated Apply preserves manifest'
    Assert (Test-HetznerInstallation -InstallRoot $fixture.Install -ProfileName 'hc-3' -MissionPboPath $fixture.Pbo) 'T7 verify passes before tamper'
    $manifestMissingEntry = Get-Content -LiteralPath (Join-Path $fixture.Install '.hetzner-installer\manifest.json') -Raw | ConvertFrom-Json
    $manifestMissingEntry.ManagedFiles = @($manifestMissingEntry.ManagedFiles | Where-Object { $_.Path -ne 'hc1_launch.cmd' })
    [System.IO.File]::WriteAllText((Join-Path $fixture.Install '.hetzner-installer\manifest.json'), ($manifestMissingEntry | ConvertTo-Json -Depth 8))
    Assert-Throws { Test-HetznerInstallation -InstallRoot $fixture.Install -ProfileName 'hc-3' -MissionPboPath $fixture.Pbo } 'T7 verify rejects a manifest with missing managed entry' 'exact|managed set|manifest'
    Remove-Item -LiteralPath $fixture.Install -Recurse -Force
    Invoke-HetznerPlan -Plan $plan -Apply | Out-Null
    Add-Content -LiteralPath (Join-Path $fixture.Install 'hc1_launch.cmd') -Value 'tampered'
    Assert-Throws { Test-HetznerInstallation -InstallRoot $fixture.Install -ProfileName 'hc-3' -MissionPboPath $fixture.Pbo } 'T7 verify rejects tampered file' 'hash|drift|mismatch'
    Remove-Item -LiteralPath $fixture.Install -Recurse -Force
    Invoke-HetznerPlan -Plan $plan -Apply | Out-Null
    [byte[]]$originalPboBytes = [System.IO.File]::ReadAllBytes($fixture.Pbo)
    [System.IO.File]::WriteAllBytes($fixture.Pbo, [byte[]](0x50,0x42,0x4F,0x09))
    Assert-Throws { Invoke-HetznerPlan -Plan $plan -Apply } 'T7 apply rejects changed mission PBO' 'PBO|changed|hash'
    Assert-Throws { Test-HetznerInstallation -InstallRoot $fixture.Install -ProfileName 'hc-3' -MissionPboPath $fixture.Pbo } 'T7 verify rejects changed source PBO' 'PBO|identity|hash'
    [System.IO.File]::WriteAllBytes($fixture.Pbo, $originalPboBytes)
    Invoke-HetznerPlan -Plan $plan -Apply | Out-Null
    Add-Content -LiteralPath (Join-Path $fixture.Install 'mpmissions\candidate.chernarus.pbo') -Value 'tampered'
    Assert-Throws { Test-HetznerInstallation -InstallRoot $fixture.Install -ProfileName 'hc-3' -MissionPboPath $fixture.Pbo } 'T7 verify rejects tampered installed PBO' 'hash|mismatch'
    Remove-Item -LiteralPath $fixture.Install -Recurse -Force
    Invoke-HetznerPlan -Plan $plan -Apply | Out-Null

    Write-Host 'TEST 8: backup requires Apply and stays outside the install root'
    $backup = Join-Path $fixture.Fence 'backups\before-change'
    $backupPlan = New-HetznerBackupPlan -InstallRoot $fixture.Install -BackupRoot $backup -FenceRoot $fixture.Fence
    $backupResult = Invoke-HetznerBackupPlan -Plan $backupPlan
    Assert (-not $backupResult.Applied) 'T8 backup dry-run does not mutate'
    Assert (-not (Test-Path -LiteralPath $backup)) 'T8 dry-run creates no backup'
    $backupResult = Invoke-HetznerBackupPlan -Plan $backupPlan -Apply
    Assert $backupResult.Applied 'T8 backup Apply reports applied'
    Assert (Test-Path -LiteralPath (Join-Path $backup 'hc1_launch.cmd')) 'T8 backup contains managed files'
    Set-Content -LiteralPath (Join-Path $backup 'sentinel.txt') -Value 'immutable-backup'
    Assert-Throws { Invoke-HetznerBackupPlan -Plan $backupPlan -Apply } 'T8 existing backup root is refused' 'exists|fresh|immutable'
    $sentinelPreserved = (Test-Path -LiteralPath (Join-Path $backup 'sentinel.txt')) -and ((Get-Content -LiteralPath (Join-Path $backup 'sentinel.txt') -Raw) -eq "immutable-backup`r`n")
    Assert $sentinelPreserved 'T8 refused backup preserves existing root'

    Write-Host 'TEST 8b: backup Apply revalidates action and all roots immediately before mutation'
    $badBackupAction = New-HetznerBackupPlan -InstallRoot $fixture.Install -BackupRoot (Join-Path $fixture.Fence 'backups\bad-action') -FenceRoot $fixture.Fence
    $badBackupAction.Action = 'NotBackup'
    Assert-Throws { Invoke-HetznerBackupPlan -Plan $badBackupAction -Apply } 'T8b backup action is revalidated' 'action'
    $badBackupRoot = New-HetznerBackupPlan -InstallRoot $fixture.Install -BackupRoot (Join-Path $fixture.Fence 'backups\bad-root') -FenceRoot $fixture.Fence
    $badBackupRoot.BackupRoot = Join-Path $fixture.Root 'outside-backup'
    Assert-Throws { Invoke-HetznerBackupPlan -Plan $badBackupRoot -Apply } 'T8b backup root is revalidated' 'fence|staging'

    Write-Host 'TEST 9: rollback and uninstall remain plan-only without Apply'
    $rollbackPlan = New-HetznerRollbackPlan -InstallRoot $fixture.Install -BackupRoot $backup -FenceRoot $fixture.Fence
    $rollbackResult = Invoke-HetznerRollbackPlan -Plan $rollbackPlan
    Assert (-not $rollbackResult.Applied) 'T9 rollback plan does not mutate by default'
    $badRollbackAction = New-HetznerRollbackPlan -InstallRoot $fixture.Install -BackupRoot $backup -FenceRoot $fixture.Fence
    $badRollbackAction.Action = 'NotRollbackPlan'
    Assert-Throws { Invoke-HetznerRollbackPlan -Plan $badRollbackAction -Apply } 'T9 rollback action is revalidated' 'action'
    $badRollbackRoot = New-HetznerRollbackPlan -InstallRoot $fixture.Install -BackupRoot $backup -FenceRoot $fixture.Fence
    $badRollbackRoot.InstallRoot = Join-Path $fixture.Root 'outside-install'
    Assert-Throws { Invoke-HetznerRollbackPlan -Plan $badRollbackRoot -Apply } 'T9 rollback install root is revalidated' 'fence|staging'
    $uninstallPlan = New-HetznerUninstallPlan -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-3' -MissionPboPath $fixture.Pbo
    $uninstallResult = Invoke-HetznerUninstallPlan -Plan $uninstallPlan
    Assert (-not $uninstallResult.Applied) 'T9 uninstall plan does not mutate by default'
    Assert (Test-Path -LiteralPath $fixture.Install) 'T9 install remains after plan-only actions'

    Write-Host 'TEST 9b: uninstall rejects tampered plan and malicious manifest traversal'
    $escape = Join-Path $fixture.Fence 'escape.txt'
    Set-Content -LiteralPath $escape -Value 'must-survive'
    $badUninstallPlan = New-HetznerUninstallPlan -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-3' -MissionPboPath $fixture.Pbo
    $badUninstallPlan.ExpectedManagedPaths = @('..\escape.txt')
    Assert-Throws { Invoke-HetznerUninstallPlan -Plan $badUninstallPlan -Apply } 'T9b uninstall target traversal rejected' 'outside|traversal|install root|exact|managed'
    Assert (Test-Path -LiteralPath $escape) 'T9b tampered uninstall leaves outside file'
    $badUninstallAction = New-HetznerUninstallPlan -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-3' -MissionPboPath $fixture.Pbo
    $badUninstallAction.Action = 'NotUninstall'
    Assert-Throws { Invoke-HetznerUninstallPlan -Plan $badUninstallAction -Apply } 'T9b uninstall action is revalidated' 'action'
    $badUninstallFence = New-HetznerUninstallPlan -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-3' -MissionPboPath $fixture.Pbo
    $badUninstallFence.FenceRoot = Join-Path $fixture.Root 'outside-fence'
    Assert-Throws { Invoke-HetznerUninstallPlan -Plan $badUninstallFence -Apply } 'T9b uninstall fence is revalidated' 'fence|outside'
    $receiptPathForTamper = Join-Path $fixture.Install '.hetzner-installer\receipt.json'
    $tamperedReceipt = Get-Content -LiteralPath $receiptPathForTamper -Raw | ConvertFrom-Json
    $tamperedReceipt.MissionPboSha256 = ('0' * 64)
    [System.IO.File]::WriteAllText($receiptPathForTamper, ($tamperedReceipt | ConvertTo-Json -Depth 8))
    Assert-Throws { New-HetznerUninstallPlan -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-3' -MissionPboPath $fixture.Pbo } 'T9b tampered receipt fails closed' 'PBO|identity|receipt'
    Remove-Item -LiteralPath $fixture.Install -Recurse -Force
    Invoke-HetznerPlan -Plan $plan -Apply | Out-Null
    $manifestPath = Join-Path $fixture.Install '.hetzner-installer\manifest.json'
    $maliciousManifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $maliciousManifest.ManagedFiles[0].Path = '..\escape.txt'
    [System.IO.File]::WriteAllText($manifestPath, ($maliciousManifest | ConvertTo-Json -Depth 8))
    Assert-Throws { New-HetznerUninstallPlan -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-3' -MissionPboPath $fixture.Pbo } 'T9b malicious manifest traversal rejected' 'outside|traversal|install root|exact|managed|anchor|metadata'
    Remove-Item -LiteralPath $fixture.Install -Recurse -Force
    Invoke-HetznerPlan -Plan $plan -Apply | Out-Null
    Remove-Item -LiteralPath (Join-Path $fixture.Install '.hetzner-installer\manifest.json') -Force
    Assert-Throws { New-HetznerUninstallPlan -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-3' -MissionPboPath $fixture.Pbo } 'T9b missing manifest fails closed' 'manifest|receipt|fallback'
    Remove-Item -LiteralPath $fixture.Install -Recurse -Force
    Invoke-HetznerPlan -Plan $plan -Apply | Out-Null
    $uninstallPlan = New-HetznerUninstallPlan -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-3' -MissionPboPath $fixture.Pbo

    Write-Host 'TEST 9c: profile transition removes stale installer-managed launchers and verify enforces exact set'
    $hc0Plan = New-HetznerPlan -SourceRoot $fixture.Source -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-0' -MissionPboPath $fixture.Pbo
    Invoke-HetznerPlan -Plan $hc0Plan -Apply | Out-Null
    Assert ((@('hc1_launch.cmd','hc2_launch.cmd','hc3_launch.cmd') | Where-Object { Test-Path -LiteralPath (Join-Path $fixture.Install $_) }).Count -eq 0) 'T9c hc-3 to hc-0 removes stale launchers'
    Assert (Test-HetznerInstallation -InstallRoot $fixture.Install -ProfileName 'hc-0' -MissionPboPath $fixture.Pbo) 'T9c hc-0 exact managed set verifies'

    Write-Host 'TEST 10: rollback Apply is disabled and uninstall preserves adopted files'
    $rollbackSafetyInstall = Join-Path $fixture.Fence 'rollback-safety-install'
    New-Item -ItemType Directory -Path $rollbackSafetyInstall -Force | Out-Null
    $postBackupFile = Join-Path $rollbackSafetyInstall 'post-backup-adopted.txt'
    [System.IO.File]::WriteAllText($postBackupFile, 'must-survive-disabled-rollback')
    $rollbackSafetyPlan = New-HetznerRollbackPlan -InstallRoot $rollbackSafetyInstall -BackupRoot $backup -FenceRoot $fixture.Fence
    Assert-Throws { Invoke-HetznerRollbackPlan -Plan $rollbackSafetyPlan -Apply } 'T10 rollback Apply fails closed' 'not implemented|transactional|disabled|restore'
    Assert ((Test-Path -LiteralPath $postBackupFile) -and [System.IO.File]::ReadAllText($postBackupFile) -eq 'must-survive-disabled-rollback') 'T10 disabled rollback preserves post-backup file'
    Remove-Item -LiteralPath $rollbackSafetyInstall -Recurse -Force
    $adoptedFile = Join-Path $fixture.Install 'post-backup-adopted.txt'
    [System.IO.File]::WriteAllText($adoptedFile, 'adopted-host-file')
    $modifiedUninstallPlan = New-HetznerUninstallPlan -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-0' -MissionPboPath $fixture.Pbo
    [System.IO.File]::WriteAllText((Join-Path $fixture.Install 'profiles-pr8\basic.cfg'), 'host-modified')
    Assert-Throws { Invoke-HetznerUninstallPlan -Plan $modifiedUninstallPlan -Apply } 'T10 uninstall preserves a modified managed file' 'modified|adopted|preserved'
    Assert ([System.IO.File]::ReadAllText((Join-Path $fixture.Install 'profiles-pr8\basic.cfg')) -eq 'host-modified') 'T10 modified config remains after refused uninstall'
    Copy-Item -LiteralPath (Join-Path $fixture.Source 'server-config\basic.cfg') -Destination (Join-Path $fixture.Install 'profiles-pr8\basic.cfg') -Force
    $hc0UninstallPlan = New-HetznerUninstallPlan -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-0' -MissionPboPath $fixture.Pbo
    $uninstallResult = Invoke-HetznerUninstallPlan -Plan $hc0UninstallPlan -Apply
    Assert $uninstallResult.Applied 'T10 uninstall Apply reports applied'
    Assert (-not (Test-Path -LiteralPath (Join-Path $fixture.Install 'profiles-pr8\basic.cfg'))) 'T10 uninstall removes installer-owned config'
    Assert ((Test-Path -LiteralPath $adoptedFile) -and [System.IO.File]::ReadAllText($adoptedFile) -eq 'adopted-host-file') 'T10 uninstall preserves adopted host file'
}
finally {
    Remove-Fixture $fixture
}

Write-Host ''
if ($script:fails -eq 0) { Write-Host 'ALL TESTS PASSED' -ForegroundColor Green; exit 0 }
Write-Host "$($script:fails) TEST(S) FAILED" -ForegroundColor Red
exit 1
