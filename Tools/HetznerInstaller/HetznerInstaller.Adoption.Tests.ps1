#requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'HetznerInstaller.psm1') -Force
$script:fails = 0

function Assert([bool]$Condition, [string]$Name) {
    if ($Condition) { Write-Host "  PASS  $Name"; return }
    $script:fails++; Write-Host "  FAIL  $Name" -ForegroundColor Red
}

function Assert-Throws([scriptblock]$Action, [string]$Name, [string]$Pattern) {
    try { & $Action; $script:fails++; Write-Host "  FAIL  $Name (no exception)" -ForegroundColor Red }
    catch {
        if ($_.Exception.Message -match $Pattern) { Write-Host "  PASS  $Name" }
        else { $script:fails++; Write-Host "  FAIL  $Name (unexpected: $($_.Exception.Message))" -ForegroundColor Red }
    }
}

function New-AdoptionFixture {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ('hetzner-adoption-' + [guid]::NewGuid().ToString('N'))
    $source = Join-Path $root 'source'; $fence = Join-Path $root 'staging'; $install = Join-Path $fence 'install'
    New-Item -ItemType Directory -Path (Join-Path $source 'server-config') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $install 'profiles-pr8') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $source 'server-config\basic.cfg'),'MaxSizeGuaranteed = 512;')
    [System.IO.File]::WriteAllText((Join-Path $source 'server-config\server-pr8.cfg'),'passwordAdmin = "__REDACTED_SET_ON_HOST__";')
    $pbo = Join-Path $source 'candidate.chernarus.pbo'
    [System.IO.File]::WriteAllBytes($pbo,[byte[]](0x50,0x42,0x4f,0x01,0x02,0x03,0x04))
    [System.IO.File]::Copy((Join-Path $source 'server-config\basic.cfg'),(Join-Path $install 'profiles-pr8\basic.cfg'))
    [System.IO.File]::WriteAllText((Join-Path $install 'host-note.txt'),'must-survive')
    [pscustomobject]@{Root=$root;Source=$source;Fence=$fence;Install=$install;Pbo=$pbo}
}

function Remove-AdoptionFixture($Fixture) {
    if ($Fixture -and (Test-Path -LiteralPath $Fixture.Root)) { Remove-Item -LiteralPath $Fixture.Root -Recurse -Force }
}

Write-Host 'TEST T12a: AdoptUnchanged is explicit, fingerprinted, and preserves host ownership'
$f = New-AdoptionFixture
try {
    $implicitPlan = New-HetznerPlan -SourceRoot $f.Source -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-0 -MissionPboPath $f.Pbo
    Assert-Throws { Invoke-HetznerPlan -Plan $implicitPlan -Apply | Out-Null } 'T12a existing host target cannot become managed without explicit policy' 'adoption|ownership|non-empty|policy'
    Assert ([System.IO.File]::ReadAllText((Join-Path $f.Install 'host-note.txt')) -ceq 'must-survive') 'T12a implicit-adoption refusal preserves unrelated host content'

    $policy = @([pscustomobject][ordered]@{Path='profiles-pr8\basic.cfg';Disposition='AdoptUnchanged'})
    $plan = $null; $planError = ''
    try { $plan = New-HetznerPlan -SourceRoot $f.Source -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-0 -MissionPboPath $f.Pbo -AdoptionPolicy $policy }
    catch { $planError = $_.Exception.Message }
    Assert ($null -ne $plan -and [string]::IsNullOrEmpty($planError)) 'T12a plan accepts one explicit AdoptUnchanged record'
    if ($null -ne $plan) {
        $preHash = (Get-FileHash -LiteralPath (Join-Path $f.Install 'profiles-pr8\basic.cfg') -Algorithm SHA256).Hash.ToLowerInvariant()
        $result = Invoke-HetznerPlan -Plan $plan -Apply
        Assert $result.Applied 'T12a explicit adoption Apply succeeds'
        $postHash = (Get-FileHash -LiteralPath (Join-Path $f.Install 'profiles-pr8\basic.cfg') -Algorithm SHA256).Hash.ToLowerInvariant()
        Assert ($postHash -ceq $preHash) 'T12a adopted host file remains byte-identical'
        Assert ([System.IO.File]::ReadAllText((Join-Path $f.Install 'host-note.txt')) -ceq 'must-survive') 'T12a unrelated host content remains untouched'

        $manifest = Get-Content -LiteralPath (Join-Path $f.Install '.hetzner-installer\manifest.json') -Raw | ConvertFrom-Json
        $receipt = Get-Content -LiteralPath (Join-Path $f.Install '.hetzner-installer\receipt.json') -Raw | ConvertFrom-Json
        $m = @($manifest.OwnershipDecisions); $r = @($receipt.OwnershipDecisions)
        Assert ($m.Count -eq 1 -and $r.Count -eq 1) 'T12a manifest and receipt contain the exact adoption decision'
        if ($m.Count -eq 1) {
            $decision = $m[0]
            Assert ([string]$decision.Path -ceq 'profiles-pr8\basic.cfg' -and [string]$decision.Disposition -ceq 'AdoptUnchanged') 'T12a decision binds path and disposition'
            Assert ([string]$decision.PreSha256 -ceq $preHash -and [string]$decision.PostSha256 -ceq $preHash) 'T12a decision records exact prehash and posthash'
            Assert ([string]$decision.Owner -ceq 'HostAdopted' -and [string]$decision.RollbackDisposition -ceq 'PreserveHost' -and [string]$decision.UninstallDisposition -ceq 'PreserveHost') 'T12a decision records owner, rollback, and uninstall disposition'
        }
        $uninstallPlan = New-HetznerUninstallPlan -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-0 -MissionPboPath $f.Pbo
        $preview = Invoke-HetznerUninstallPlan -Plan $uninstallPlan
        Assert (-not $preview.Applied -and $preview.ApplySupported) 'T12a adoption-aware uninstall is plan-only by default'
        $uninstall = Invoke-HetznerUninstallPlan -Plan $uninstallPlan -Apply
        Assert ($uninstall.Applied -and $uninstall.UninstallState -ceq 'Uninstalled') 'T12a adoption-aware uninstall applies through the sealed transaction'
        Assert ((Test-Path -LiteralPath (Join-Path $f.Install 'profiles-pr8\basic.cfg') -PathType Leaf) -and [System.IO.File]::ReadAllText((Join-Path $f.Install 'profiles-pr8\basic.cfg')) -ceq 'MaxSizeGuaranteed = 512;') 'T12a uninstall preserves the adopted host file byte-identically'
        Assert ([System.IO.File]::ReadAllText((Join-Path $f.Install 'host-note.txt')) -ceq 'must-survive') 'T12a uninstall preserves unrelated host content'
        Assert (-not (Test-Path -LiteralPath (Join-Path $f.Install '.hetzner-installer\manifest.json'))) 'T12a uninstall removes installer metadata'
    }
} finally { Remove-AdoptionFixture $f }

Write-Host 'TEST T12b: PreserveHost explicitly exempts only a stale host launcher from deletion'
$f = New-AdoptionFixture
try {
    $stale = Join-Path $f.Install 'hc1_launch.cmd'
    [System.IO.File]::WriteAllText($stale,'host-owned-stale-launcher')
    $policy = @(
        [pscustomobject][ordered]@{Path='profiles-pr8\basic.cfg';Disposition='AdoptUnchanged'},
        [pscustomobject][ordered]@{Path='hc1_launch.cmd';Disposition='PreserveHost'}
    )
    $plan = $null; $planError=''
    try { $plan=New-HetznerPlan -SourceRoot $f.Source -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-0 -MissionPboPath $f.Pbo -AdoptionPolicy $policy }
    catch { $planError=$_.Exception.Message }
    Assert ($null -ne $plan -and [string]::IsNullOrEmpty($planError)) 'T12b plan accepts explicit PreserveHost for a stale launcher'
    if($null -ne $plan){
        $result=Invoke-HetznerPlan -Plan $plan -Apply
        Assert $result.Applied 'T12b PreserveHost Apply succeeds'
        Assert ([System.IO.File]::ReadAllText($stale) -ceq 'host-owned-stale-launcher') 'T12b preserved stale launcher remains byte-identical'
        Assert (@($result.PreservedStale) -ccontains 'hc1_launch.cmd') 'T12b result reports the explicitly preserved stale launcher'
        $manifest=Get-Content -LiteralPath (Join-Path $f.Install '.hetzner-installer\manifest.json') -Raw|ConvertFrom-Json
        $decision=@($manifest.OwnershipDecisions|Where-Object{[string]$_.Path -ceq 'hc1_launch.cmd'})[0]
        Assert ($null -ne $decision -and [string]$decision.Disposition -ceq 'PreserveHost' -and [string]$decision.Owner -ceq 'Host') 'T12b sealed metadata records host ownership and PreserveHost disposition'
        Assert (Test-HetznerInstallation -InstallRoot $f.Install -ProfileName hc-0 -MissionPboPath $f.Pbo) 'T12b verifier accepts only the explicitly preserved stale launcher'
        $uninstallPlan=New-HetznerUninstallPlan -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-0 -MissionPboPath $f.Pbo
        $uninstall=Invoke-HetznerUninstallPlan -Plan $uninstallPlan -Apply
        Assert($uninstall.Applied-and[System.IO.File]::ReadAllText($stale)-ceq'host-owned-stale-launcher') 'T12b uninstall preserves the explicit host launcher'
    }
} finally { Remove-AdoptionFixture $f }

Write-Host 'TEST T12c: ReplaceWithBackup seals an external host preimage before replacement'
$f = New-AdoptionFixture
try {
    $target=Join-Path $f.Install 'profiles-pr8\basic.cfg'
    [System.IO.File]::WriteAllText($target,'host-specific-basic')
    $preHash=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
    $policy=@([pscustomobject][ordered]@{Path='profiles-pr8\basic.cfg';Disposition='ReplaceWithBackup'})
    $plan=$null;$planError=''
    try{$plan=New-HetznerPlan -SourceRoot $f.Source -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-0 -MissionPboPath $f.Pbo -AdoptionPolicy $policy}catch{$planError=$_.Exception.Message}
    Assert($null-ne$plan-and[string]::IsNullOrEmpty($planError)) 'T12c plan accepts explicit ReplaceWithBackup for a differing required target'
    if($null-ne$plan){
        $result=Invoke-HetznerPlan -Plan $plan -Apply
        $postHash=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
        $desiredHash=(Get-FileHash -LiteralPath (Join-Path $f.Source 'server-config\basic.cfg') -Algorithm SHA256).Hash.ToLowerInvariant()
        Assert($result.Applied-and$postHash-ceq$desiredHash-and$postHash-cne$preHash) 'T12c Apply installs the desired postimage only after explicit replacement policy'
        $decision=@($result.OwnershipDecisions|Where-Object{[string]$_.Path-ceq'profiles-pr8\basic.cfg'})[0]
        Assert($null-ne$decision-and[string]$decision.Disposition-ceq'ReplaceWithBackup'-and[string]$decision.Owner-ceq'InstallerReplacingHost') 'T12c result records replacement ownership'
        if($null-ne$decision){
            $backup=[System.IO.Path]::GetFullPath([string]$decision.BackupPath)
            $installPrefix=[System.IO.Path]::GetFullPath($f.Install).TrimEnd('\')+'\'
            Assert((Test-Path -LiteralPath $backup -PathType Leaf)-and-not$backup.StartsWith($installPrefix,[System.StringComparison]::OrdinalIgnoreCase)) 'T12c verified preimage backup is outside the install root'
            Assert((Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash.ToLowerInvariant()-ceq$preHash-and[string]$decision.BackupSha256-ceq$preHash) 'T12c backup bytes and sealed backup hash equal the host preimage'
            Assert([string]$decision.RollbackDisposition-ceq'RestoreBackup'-and[string]$decision.UninstallDisposition-ceq'RestoreBackup') 'T12c replacement records rollback and uninstall restore dispositions'
        }
        $uninstallPlan=New-HetznerUninstallPlan -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-0 -MissionPboPath $f.Pbo
        $uninstall=Invoke-HetznerUninstallPlan -Plan $uninstallPlan -Apply
        Assert($uninstall.Applied-and[System.IO.File]::ReadAllText($target)-ceq'host-specific-basic') 'T12c uninstall restores the sealed host backup exactly'
        $repeatPlan=New-HetznerUninstallPlan -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-0 -MissionPboPath $f.Pbo
        $repeat=Invoke-HetznerUninstallPlan -Plan $repeatPlan -Apply
        Assert($repeat.Applied-and$repeat.UninstallState-ceq'Uninstalled'-and[System.IO.File]::ReadAllText($target)-ceq'host-specific-basic') 'T12c repeated uninstall is idempotent'
    }
}finally{Remove-AdoptionFixture $f}

Write-Host 'TEST T12d: every adoption-aware uninstall action resumes to the same exact host state'
$actionCount=1
for($failIndex=0;$failIndex-lt$actionCount;$failIndex++){
    $f=New-AdoptionFixture
    try{
        $target=Join-Path $f.Install 'profiles-pr8\basic.cfg'
        [System.IO.File]::WriteAllText($target,'host-specific-basic')
        $policy=@([pscustomobject][ordered]@{Path='profiles-pr8\basic.cfg';Disposition='ReplaceWithBackup'})
        $plan=New-HetznerPlan -SourceRoot $f.Source -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-0 -MissionPboPath $f.Pbo -AdoptionPolicy $policy
        Invoke-HetznerPlan -Plan $plan -Apply|Out-Null
        $uninstallPlan=New-HetznerUninstallPlan -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-0 -MissionPboPath $f.Pbo
        $actionCount=@($uninstallPlan.Contract.Actions).Count
        Assert-Throws{Invoke-HetznerUninstallPlan -Plan $uninstallPlan -Apply -FailAfterOperationIndex $failIndex|Out-Null} "T12d interruption at action $failIndex is observable" 'interruption|failpoint'
        $status=Get-HetznerTransactionStatus -InstallRoot $f.Install -FenceRoot $f.Fence
        Assert([string]$status.State-ceq'Uninstalling'-and[int]$status.OperationIndex-eq$failIndex) "T12d action $failIndex leaves durable uninstall progress"
        $resumePlan=New-HetznerUninstallPlan -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-0 -MissionPboPath $f.Pbo
        $resumed=Invoke-HetznerUninstallPlan -Plan $resumePlan -Apply
        Assert($resumed.Applied-and[System.IO.File]::ReadAllText($target)-ceq'host-specific-basic'-and-not(Test-Path -LiteralPath (Join-Path $f.Install '.hetzner-installer\manifest.json'))) "T12d action $failIndex resumes to exact host state"
    }finally{Remove-AdoptionFixture $f}
}

Write-Host 'TEST T12e: a crash after mutation but before completion journaling is recoverable'
$actionCount=1
for($failIndex=0;$failIndex-lt$actionCount;$failIndex++){
    $f=New-AdoptionFixture
    try{
        $target=Join-Path $f.Install 'profiles-pr8\basic.cfg'
        [System.IO.File]::WriteAllText($target,'host-specific-basic')
        $policy=@([pscustomobject][ordered]@{Path='profiles-pr8\basic.cfg';Disposition='ReplaceWithBackup'})
        $plan=New-HetznerPlan -SourceRoot $f.Source -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-0 -MissionPboPath $f.Pbo -AdoptionPolicy $policy
        Invoke-HetznerPlan -Plan $plan -Apply|Out-Null
        $uninstallPlan=New-HetznerUninstallPlan -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-0 -MissionPboPath $f.Pbo
        $actionCount=@($uninstallPlan.Contract.Actions).Count
        Assert-Throws{Invoke-HetznerUninstallPlan -Plan $uninstallPlan -Apply -FailAfterMutationIndex $failIndex|Out-Null} "T12e crash window at action $failIndex is observable" 'interruption|failpoint'
        $status=Get-HetznerTransactionStatus -InstallRoot $f.Install -FenceRoot $f.Fence
        Assert([string]$status.State-ceq'Uninstalling'-and[int]$status.OperationIndex-eq($failIndex-1)-and[int]$status.Journal.PendingOperationIndex-eq$failIndex) "T12e action $failIndex leaves write-ahead pending intent"
        $resumePlan=New-HetznerUninstallPlan -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-0 -MissionPboPath $f.Pbo
        $resumed=Invoke-HetznerUninstallPlan -Plan $resumePlan -Apply
        Assert($resumed.Applied-and[System.IO.File]::ReadAllText($target)-ceq'host-specific-basic'-and-not(Test-Path -LiteralPath (Join-Path $f.Install '.hetzner-installer\manifest.json'))) "T12e action $failIndex replays idempotently to exact host state"
    }finally{Remove-AdoptionFixture $f}
}

if ($script:fails -eq 0) { Write-Host 'T12 ADOPTION TESTS PASSED' -ForegroundColor Green; exit 0 }
Write-Host "$($script:fails) T12 ADOPTION TEST(S) FAILED" -ForegroundColor Red
exit 1
