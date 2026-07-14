#requires -Version 5.1
<#
.SYNOPSIS
    Local fixture tests for the staged service-health activation contract.

.DESCRIPTION
    These tests never start a service or contact a host. Each fixture is an
    executable adapter file, and the module must invoke that exact hash-pinned
    file through the structured request contract.
#>
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

function New-Fixture([int]$HeadlessClients=2,[string]$ProfileName='hc-2') {
    $root = Join-Path $env:TEMP ('hetzner-service-health-test-' + [guid]::NewGuid().ToString('N'))
    $source = Join-Path $root 'source'
    $fence = Join-Path $root 'staging'
    $install = Join-Path $fence 'offline-install'
    New-Item -ItemType Directory -Path (Join-Path $source 'server-config') -Force | Out-Null
    New-Item -ItemType Directory -Path $fence -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $source 'server-config\basic.cfg'), 'MaxSizeGuaranteed = 512;')
    [System.IO.File]::WriteAllText((Join-Path $source 'server-config\server-pr8.cfg'), 'passwordAdmin = "__REDACTED_SET_ON_HOST__";')
    $pbo = Join-Path $source 'candidate.chernarus.pbo'
    [System.IO.File]::WriteAllBytes($pbo, [byte[]](0x50, 0x42, 0x4F, 0x01, 0x02, 0x03, 0x04))
    $runtime=Join-Path $root 'runtime';New-Item -ItemType Directory -Path $runtime -Force|Out-Null
    $serverRpt=Join-Path $runtime 'server\ArmA2OA.RPT';New-Item -ItemType Directory -Path (Split-Path -Parent $serverRpt) -Force|Out-Null;[System.IO.File]::WriteAllText($serverRpt,'server-rpt')
    $hcs=@()
    for($index=1;$index-le$HeadlessClients;$index++){
        $sandbox=Join-Path $runtime "sandbox-$index";$profile=Join-Path $runtime "profile-$index";$rpt=Join-Path $profile 'ArmA2OA.RPT';New-Item -ItemType Directory -Path $sandbox,$profile -Force|Out-Null;[System.IO.File]::WriteAllText($rpt,"hc$index-rpt");(Get-Item -LiteralPath $rpt).LastWriteTimeUtc=[DateTime]::UtcNow.AddMinutes(-1)
        $launchFingerprint=if($index-eq 1){'d'*64}else{'e'*64}
        $hcs += [pscustomobject][ordered]@{Name="HC-AI-Control-$index";RptIdentity="$ProfileName/HC-AI-Control-$index";SandboxRoot=$sandbox;ProfileRoot=$profile;RptPath=$rpt;CommandLineFingerprint=$launchFingerprint;LaunchTaskName="Fixture-HC$index";ProcessName='ArmA2OA_BE.exe'}
    }
    $configPath=Join-Path $fence 'fixture-adapter-config.json';$config=[pscustomobject][ordered]@{SchemaVersion=1;ConfigType='windows-service-adapter-v1';EnvironmentId='MIKSUUS-TEST';ServiceName='Arma2OA-PR8';ServerRptPath=$serverRpt;MissionPboPath=(Join-Path $install 'mpmissions\candidate.chernarus.pbo');HeadlessClients=$hcs};[System.IO.File]::WriteAllText($configPath,($config|ConvertTo-Json -Depth 8),(New-Object System.Text.UTF8Encoding($false)))
    return [pscustomobject]@{ Root = $root; Source = $source; Fence = $fence; Install = $install; Pbo = $pbo;AdapterConfig=$configPath }
}

function Get-AdapterCalls($Adapter) {
    if (-not (Test-Path -LiteralPath $Adapter.LogPath -PathType Leaf)) { return @() }
    return @(Get-Content -LiteralPath $Adapter.LogPath)
}

function Test-AdapterRestored($Adapter) { return (Test-Path -LiteralPath $Adapter.RestoreMarker -PathType Leaf) }

function New-IsolationAdapter([string]$Mode,[string]$Root,[string]$TamperPath='') {
    $id=[guid]::NewGuid().ToString('N');$path=Join-Path $Root "fixture-isolation-$id.ps1";$log=Join-Path $Root "fixture-isolation-$id.log";$marker=Join-Path $Root "fixture-isolation-$id.restored"
    $content=@'
param([Parameter(Mandatory)]$Request)
$mode='__MODE__';$log='__LOG__';$marker='__MARKER__';$tamperPath='__TAMPER__'
[System.IO.File]::AppendAllText($log,([string]$Request.Action)+[Environment]::NewLine)
        $hcs = @()
        foreach ($identity in @($Request.LauncherIdentities)) {
            $index = $hcs.Count + 1
            $expected=@($Request.ExpectedIsolation|Where-Object{$_.Name -eq $identity.Name -and $_.RptIdentity -eq $identity.RptIdentity})[0]
            if($mode -eq 'UnchangedRpt'){(Get-Item -LiteralPath ([string]$expected.RptPath)).LastWriteTimeUtc=[datetime]::UtcNow.AddMinutes(-10)}
            $rptWrite=(Get-Item -LiteralPath ([string]$expected.RptPath)).LastWriteTimeUtc
            $hcs += [pscustomobject]@{
                Name = [string]$identity.Name
                RptIdentity = [string]$identity.RptIdentity
                ProcessId = 2000 + $index
                InstanceId = "fixture-instance-$index"
                SandboxRoot = [string]$expected.SandboxRoot
                ProfileRoot = [string]$expected.ProfileRoot
                RptPath = [string]$expected.RptPath
                RptLastWriteUtc=$rptWrite.ToString('o')
                StartUtc = $rptWrite.AddMinutes(-1).ToString('o')
                CommandLineFingerprint = [string]$expected.CommandLineFingerprint
            }
        }
        if ($mode -eq 'DuplicateSandbox' -and $hcs.Count -gt 1) { $hcs[1].SandboxRoot = $hcs[0].SandboxRoot }
        if ($mode -eq 'WrongProfile' -and $hcs.Count -gt 0) { $hcs[0].ProfileRoot = $hcs[0].ProfileRoot + '-wrong' }
        if ($mode -eq 'StaleRpt' -and $hcs.Count -gt 0) { $hcs[0].RptLastWriteUtc = ([datetime]$hcs[0].RptLastWriteUtc).AddMinutes(-10).ToString('o') }
        if ($mode -eq 'TamperJournal' -and [string]$Request.Action -eq 'ObserveIsolation') { $journal=Get-Content -LiteralPath $tamperPath -Raw|ConvertFrom-Json;$journal.PlanFingerprint=('0'*64);[System.IO.File]::WriteAllText($tamperPath,($journal|ConvertTo-Json -Depth 20)) }
        switch ([string]$Request.Action) {
            'CaptureIsolationBaseline' {
                if($mode -eq 'SelfTamper'){[System.IO.File]::WriteAllText($MyInvocation.MyCommand.Path,'# replaced during invocation')}
                return [pscustomobject]@{ AdapterId = $Request.AdapterId; ProfileName = $Request.ProfileName; BaselineFingerprint = ('a' * 64); ActiveInstanceIds = @('baseline-instance') }
            }
            'ApplyIsolation' { return [pscustomobject]@{ AdapterId = $Request.AdapterId; Applied = $true } }
            'ObserveIsolation' {
                if($mode-notin@('StaleRpt','UnchangedRpt')){foreach($hc in $hcs){(Get-Item -LiteralPath ([string]$hc.RptPath)).LastWriteTimeUtc=[datetime]::UtcNow;$hc.RptLastWriteUtc=(Get-Item -LiteralPath ([string]$hc.RptPath)).LastWriteTimeUtc.ToString('o')}}
                return [pscustomobject]@{
                    AdapterId = $Request.AdapterId
                    ProfileName = $Request.ProfileName
                    ObservationWindowSeconds = 60
                    FatalLineCount = if ($mode -eq 'Fatal') { 1 } else { 0 }
                    HeadlessClients = @($hcs)
                }
            }
            'RestoreIsolationBaseline' { [System.IO.File]::WriteAllText($marker,'restored'); return [pscustomobject]@{ AdapterId = $Request.AdapterId; Restored = $true } }
            'ObserveIsolationBaseline' {
                return [pscustomobject]@{ AdapterId = $Request.AdapterId; ProfileName = $Request.ProfileName; BaselineFingerprint = ('a' * 64); ActiveInstanceIds = @('baseline-instance') }
            }
            default { throw "Unexpected fixture isolation action: $($Request.Action)" }
        }
'@
    $content=$content.Replace('__MODE__',$Mode).Replace('__LOG__',$log.Replace("'","''")).Replace('__MARKER__',$marker.Replace("'","''")).Replace('__TAMPER__',$TamperPath.Replace("'","''"))
    [System.IO.File]::WriteAllText($path,$content,(New-Object System.Text.UTF8Encoding($false)))
    return [pscustomobject]@{Path=$path;LogPath=$log;RestoreMarker=$marker;Mode=$Mode}
}

function New-ServiceHealthAdapter([string]$Mode,[string]$Root,[string]$TamperPath='') {
    $id=[guid]::NewGuid().ToString('N');$path=Join-Path $Root "fixture-service-$id.ps1";$log=Join-Path $Root "fixture-service-$id.log";$marker=Join-Path $Root "fixture-service-$id.restored"
    $content=@'
param([Parameter(Mandatory)]$Request)
$mode='__MODE__';$log='__LOG__';$marker='__MARKER__';$tamperPath='__TAMPER__';$config=$Request.AdapterConfiguration;$baselineTime=(Get-Item -LiteralPath ([string]$config.ServerRptPath)).LastWriteTimeUtc;$healthyTime=$baselineTime
[System.IO.File]::AppendAllText($log,([string]$Request.Action)+[Environment]::NewLine)
        $baselineMissionLeaf = [string]$Request.MissionPboLeaf
        $baselineMissionHash = [string]$Request.MissionPboSha256
        if($mode-eq'BaselineMissionMismatch'){$baselineMissionLeaf='baseline-wrong.chernarus.pbo';$baselineMissionHash=('b'*64)}
        $healthMissionLeaf = [string]$Request.MissionPboLeaf
        $healthMissionHash = [string]$Request.MissionPboSha256
        $healthTime = $healthyTime
        $healthHcs = @()
        foreach ($identity in @($Request.LauncherIdentities)) {
            $attested=$null
            if($null-ne$Request.IsolationAttestation){$attested = @($Request.IsolationAttestation.Attestation.HeadlessClients | Where-Object { $_.Name -eq $identity.Name -and $_.RptIdentity -eq $identity.RptIdentity })[0]}
            if($null-eq$attested){$expected=@($Request.ExpectedIsolation|Where-Object{$_.Name -eq $identity.Name -and $_.RptIdentity -eq $identity.RptIdentity})[0];$attested=[pscustomobject]@{ProcessId=2000+$healthHcs.Count+1;InstanceId="fallback-instance-$($healthHcs.Count+1)";SandboxRoot=[string]$expected.SandboxRoot;ProfileRoot=[string]$expected.ProfileRoot;RptPath=[string]$expected.RptPath;StartUtc='2026-07-14T06:01:00Z';CommandLineFingerprint=[string]$expected.CommandLineFingerprint}}
            $healthHcs += [pscustomobject]@{
                Name = [string]$identity.Name
                RptIdentity = [string]$identity.RptIdentity
                ProcessId = if ($mode -eq 'ProcessMismatch') { [int]$attested.ProcessId + 1 } else { [int]$attested.ProcessId }
                InstanceId = [string]$attested.InstanceId
                SandboxRoot = [string]$attested.SandboxRoot
                ProfileRoot = [string]$attested.ProfileRoot
                RptPath = [string]$attested.RptPath
                RptLastWriteUtc = (Get-Item -LiteralPath ([string]$attested.RptPath)).LastWriteTimeUtc.ToString('o')
                StartUtc = if ($mode -eq 'StartMismatch') { '2026-07-14T06:03:00Z' } else { [string]$attested.StartUtc }
                CommandLineFingerprint = [string]$attested.CommandLineFingerprint
            }
        }
        if ($mode -eq 'MissionMismatch') { $healthMissionLeaf = 'wrong-mission.pbo' }
        if ($mode -eq 'ServerNotAdvanced') { $healthTime = $baselineTime }
        switch ([string]$Request.Action) {
            'CaptureBaseline' {
                return [pscustomobject]@{
                    AdapterId = $Request.AdapterId
                    ServiceName = $Request.ServiceName
                    ServiceStatus = 'Running'
                    MissionPboLeaf = $baselineMissionLeaf
                    MissionPboSha256 = $baselineMissionHash
                    ConfigurationFingerprint = ('c' * 64)
                    ServerRpt = [pscustomobject]@{ Identity = [string]$config.ServerRptPath; LastWriteUtc = $baselineTime.ToString('o') }
                    HeadlessClients = @($healthHcs)
                }
            }
            'ApplyActivation' { return [pscustomobject]@{ AdapterId = $Request.AdapterId; Applied = $true } }
            'ObserveHealth' {
                if ($mode -eq 'TamperJournal') { $journal=Get-Content -LiteralPath $tamperPath -Raw|ConvertFrom-Json;$journal.PlanFingerprint=('0'*64);[System.IO.File]::WriteAllText($tamperPath,($journal|ConvertTo-Json -Depth 20)) }
                if($mode-ne'ServerNotAdvanced'){(Get-Item -LiteralPath ([string]$config.ServerRptPath)).LastWriteTimeUtc=[datetime]::UtcNow;$healthTime=(Get-Item -LiteralPath ([string]$config.ServerRptPath)).LastWriteTimeUtc}
                foreach($hc in $healthHcs){(Get-Item -LiteralPath ([string]$hc.RptPath)).LastWriteTimeUtc=[datetime]::UtcNow;$hc.RptLastWriteUtc=(Get-Item -LiteralPath ([string]$hc.RptPath)).LastWriteTimeUtc.ToString('o')}
                if ($mode -eq 'DuplicateHc' -and $healthHcs.Count -gt 0) { $healthHcs += $healthHcs[0] }
                return [pscustomobject]@{
                    AdapterId = $Request.AdapterId
                    ServiceName = $Request.ServiceName
                    ServiceStatus = 'Running'
                    MissionPboLeaf = $healthMissionLeaf
                    MissionPboSha256 = $healthMissionHash
                    ConfigurationFingerprint = ('d' * 64)
                    ServerRpt = [pscustomobject]@{ Identity = [string]$config.ServerRptPath; LastWriteUtc = $healthTime.ToString('o') }
                    HeadlessClients = @($healthHcs)
                    ObservationWindowSeconds = 60
                    FatalLineCount = if ($mode -eq 'Fatal') { 1 } else { 0 }
                }
            }
            'RestoreBaseline' { [System.IO.File]::WriteAllText($marker,'restored'); return [pscustomobject]@{ AdapterId = $Request.AdapterId; Restored = $true } }
            'ObserveBaseline' {
                return [pscustomobject]@{
                    AdapterId = $Request.AdapterId
                    ServiceName = $Request.ServiceName
                    ServiceStatus = 'Running'
                    MissionPboLeaf = $baselineMissionLeaf
                    MissionPboSha256 = $baselineMissionHash
                    ConfigurationFingerprint = ('c' * 64)
                    ServerRpt = [pscustomobject]@{ Identity = [string]$config.ServerRptPath; LastWriteUtc = (Get-Item -LiteralPath ([string]$config.ServerRptPath)).LastWriteTimeUtc.ToString('o') }
                    HeadlessClients = @($healthHcs)
                }
            }
            default { throw "Unexpected fixture adapter action: $($Request.Action)" }
        }
'@
    $content=$content.Replace('__MODE__',$Mode).Replace('__LOG__',$log.Replace("'","''")).Replace('__MARKER__',$marker.Replace("'","''")).Replace('__TAMPER__',$TamperPath.Replace("'","''"))
    [System.IO.File]::WriteAllText($path,$content,(New-Object System.Text.UTF8Encoding($false)))
    return [pscustomobject]@{Path=$path;LogPath=$log;RestoreMarker=$marker;Mode=$Mode}
}

$fixture = New-Fixture
try {
    $installPlan = New-HetznerPlan -SourceRoot $fixture.Source -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-2' -MissionPboPath $fixture.Pbo
    Invoke-HetznerPlan -Plan $installPlan -Apply | Out-Null

    Write-Host 'TEST T16a: two-HC activation needs a hash-pinned isolation attestation before service health can begin'
    $isolation = New-IsolationAdapter -Mode 'Healthy' -Root $fixture.Fence
    $isolationPlan = New-HetznerHCIsolationAttestationPlan -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-2' -MissionPboPath $fixture.Pbo -IsolationAdapterPath $isolation.Path -AdapterConfigPath $fixture.AdapterConfig -AdapterId 'fixture-isolation-v1' -MinimumObservationSeconds 60
    $isolationDryRun = Invoke-HetznerHCIsolationAttestationPlan -Plan $isolationPlan
    Assert (-not $isolationDryRun.Applied -and -not $isolationDryRun.AdapterInvoked -and @(Get-AdapterCalls $isolation).Count -eq 0) 'T16a dry run does not invoke the isolation adapter'
    $isolationResult = Invoke-HetznerHCIsolationAttestationPlan -Plan $isolationPlan -Apply
    Assert ($isolationResult.Applied -and (Test-Path -LiteralPath $isolationPlan.AttestationReceiptPath) -and ((@(Get-AdapterCalls $isolation) -join ',') -eq 'CaptureIsolationBaseline,ApplyIsolation,ObserveIsolation')) 'T16a two-HC isolation receipt commits after unique runtime attestation'

    Write-Host 'TEST T16b: fatal isolation evidence is rejected and restores its captured baseline'
    $fatalIsolation = New-IsolationAdapter -Mode 'Fatal' -Root $fixture.Fence
    $fatalIsolationPlan = New-HetznerHCIsolationAttestationPlan -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-2' -MissionPboPath $fixture.Pbo -IsolationAdapterPath $fatalIsolation.Path -AdapterConfigPath $fixture.AdapterConfig -AdapterId 'fixture-isolation-fatal-v1' -MinimumObservationSeconds 60
    Assert-Throws { Invoke-HetznerHCIsolationAttestationPlan -Plan $fatalIsolationPlan -Apply } 'T16b fatal isolation evidence is rejected' 'fatal|isolation'
    Assert ((Test-AdapterRestored $fatalIsolation) -and ((@(Get-AdapterCalls $fatalIsolation) -join ',') -eq 'CaptureIsolationBaseline,ApplyIsolation,ObserveIsolation,RestoreIsolationBaseline,ObserveIsolationBaseline')) 'T16b fatal isolation restores and re-observes its baseline'
    Assert (-not (Test-Path -LiteralPath $fatalIsolationPlan.AttestationReceiptPath)) 'T16b fatal isolation evidence writes no receipt'

    Write-Host 'TEST T16c: duplicate sandbox identities are rejected before any attestation receipt commits'
    $duplicateIsolation = New-IsolationAdapter -Mode 'DuplicateSandbox' -Root $fixture.Fence
    $duplicatePlan = New-HetznerHCIsolationAttestationPlan -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-2' -MissionPboPath $fixture.Pbo -IsolationAdapterPath $duplicateIsolation.Path -AdapterConfigPath $fixture.AdapterConfig -AdapterId 'fixture-isolation-duplicate-v1' -MinimumObservationSeconds 60
    Assert-Throws { Invoke-HetznerHCIsolationAttestationPlan -Plan $duplicatePlan -Apply } 'T16c duplicate sandbox identity is rejected' 'sandbox|unique|isolation'
    Assert ((Test-AdapterRestored $duplicateIsolation) -and ((@(Get-AdapterCalls $duplicateIsolation) -join ',') -eq 'CaptureIsolationBaseline,ApplyIsolation,ObserveIsolation,RestoreIsolationBaseline,ObserveIsolationBaseline')) 'T16c failed attestation restores and re-observes its baseline'
    Assert (-not (Test-Path -LiteralPath $duplicatePlan.AttestationReceiptPath)) 'T16c rejected isolation evidence writes no receipt'

    Write-Host 'TEST T16d: canonical path and RPT freshness drift are rejected'
    foreach($mode in @('WrongProfile','StaleRpt','UnchangedRpt')){
        $drift=New-IsolationAdapter -Mode $mode -Root $fixture.Fence
        $driftPlan=New-HetznerHCIsolationAttestationPlan -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-2' -MissionPboPath $fixture.Pbo -IsolationAdapterPath $drift.Path -AdapterConfigPath $fixture.AdapterConfig -AdapterId ("fixture-isolation-$mode") -MinimumObservationSeconds 60
        Assert-Throws{Invoke-HetznerHCIsolationAttestationPlan -Plan $driftPlan -Apply|Out-Null} "T16d $mode is rejected" 'sealed|configuration|RPT|freshness|profile'
        Assert((Test-AdapterRestored $drift)-and-not(Test-Path -LiteralPath $driftPlan.AttestationReceiptPath)) "T16d $mode restores and writes no receipt"
    }

    Write-Host 'TEST T16e: the T14 lock and post-callback contract revalidation fence every adapter action'
    $lockedIsolation=New-IsolationAdapter -Mode 'Healthy' -Root $fixture.Fence
    $lockedIsolationPlan=New-HetznerHCIsolationAttestationPlan -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-2' -MissionPboPath $fixture.Pbo -IsolationAdapterPath $lockedIsolation.Path -AdapterConfigPath $fixture.AdapterConfig -AdapterId 'fixture-isolation-locked' -MinimumObservationSeconds 60
    $tx=Get-HetznerTransactionStatus -InstallRoot $fixture.Install -FenceRoot $fixture.Fence;$held=New-Object System.IO.FileStream($tx.LockPath,[System.IO.FileMode]::CreateNew,[System.IO.FileAccess]::ReadWrite,[System.IO.FileShare]::None,4096,[System.IO.FileOptions]::DeleteOnClose)
    try{Assert-Throws{Invoke-HetznerHCIsolationAttestationPlan -Plan $lockedIsolationPlan -Apply|Out-Null} 'T16e held T14 lock rejects isolation Apply' 'exclusive|transaction|active'}finally{$held.Dispose()}
    Assert(@(Get-AdapterCalls $lockedIsolation).Count-eq 0) 'T16e lock refusal invokes no adapter action'
    $journalRaw=[System.IO.File]::ReadAllText($tx.JournalPath);$tamperIsolation=New-IsolationAdapter -Mode 'TamperJournal' -Root $fixture.Fence -TamperPath $tx.JournalPath
    $tamperIsolationPlan=New-HetznerHCIsolationAttestationPlan -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-2' -MissionPboPath $fixture.Pbo -IsolationAdapterPath $tamperIsolation.Path -AdapterConfigPath $fixture.AdapterConfig -AdapterId 'fixture-isolation-revalidate' -MinimumObservationSeconds 60
    Assert-Throws{Invoke-HetznerHCIsolationAttestationPlan -Plan $tamperIsolationPlan -Apply|Out-Null} 'T16e changed T14 contract cannot commit an isolation receipt' 'journal|fingerprint|contract|changed'
    [System.IO.File]::WriteAllText($tx.JournalPath,$journalRaw,(New-Object System.Text.UTF8Encoding($false)))
    Assert((Test-AdapterRestored $tamperIsolation)-and-not(Test-Path -LiteralPath $tamperIsolationPlan.AttestationReceiptPath)) 'T16e post-callback revalidation restores and writes no receipt'

    Write-Host 'TEST T16f: adapter bytes are immutable for the full execution window'
    $selfTamper=New-IsolationAdapter -Mode 'SelfTamper' -Root $fixture.Fence
    $selfTamperPlan=New-HetznerHCIsolationAttestationPlan -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-2' -MissionPboPath $fixture.Pbo -IsolationAdapterPath $selfTamper.Path -AdapterConfigPath $fixture.AdapterConfig -AdapterId 'fixture-isolation-self-tamper' -MinimumObservationSeconds 60
    $selfTamperHash=(Get-FileHash -LiteralPath $selfTamper.Path -Algorithm SHA256).Hash
    Assert-Throws{Invoke-HetznerHCIsolationAttestationPlan -Plan $selfTamperPlan -Apply|Out-Null} 'T16f executing adapter cannot replace its own reviewed bytes' 'adapter|used by another process|access|denied|execution'
    Assert((Get-FileHash -LiteralPath $selfTamper.Path -Algorithm SHA256).Hash-ceq$selfTamperHash-and-not(Test-Path -LiteralPath $selfTamperPlan.AttestationReceiptPath)) 'T16f adapter file stays hash-identical and writes no receipt'

    Write-Host 'TEST T16g: runtime configuration is restricted to the reviewed MIKSUUS-TEST identity'
    $wrongEnvironment=Get-Content -LiteralPath $fixture.AdapterConfig -Raw|ConvertFrom-Json;$wrongEnvironment.EnvironmentId='PRODUCTION'
    $wrongEnvironmentPath=Join-Path $fixture.Fence 'wrong-environment.json';[System.IO.File]::WriteAllText($wrongEnvironmentPath,($wrongEnvironment|ConvertTo-Json -Depth 10),(New-Object System.Text.UTF8Encoding($false)))
    $environmentAdapter=New-IsolationAdapter -Mode 'Healthy' -Root $fixture.Fence
    Assert-Throws{New-HetznerHCIsolationAttestationPlan -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName hc-2 -MissionPboPath $fixture.Pbo -IsolationAdapterPath $environmentAdapter.Path -AdapterConfigPath $wrongEnvironmentPath -AdapterId 'fixture-wrong-environment'|Out-Null} 'T16g non-test environment is rejected before adapter execution' 'MIKSUUS-TEST|permitted environment'
    Assert(@(Get-AdapterCalls $environmentAdapter).Count-eq 0) 'T16g rejected environment invokes no adapter'
    $wrongService=Get-Content -LiteralPath $fixture.AdapterConfig -Raw|ConvertFrom-Json;$wrongService.ServiceName='Different-Service'
    $wrongServicePath=Join-Path $fixture.Fence 'wrong-service.json';[System.IO.File]::WriteAllText($wrongServicePath,($wrongService|ConvertTo-Json -Depth 10),(New-Object System.Text.UTF8Encoding($false)))
    $serviceIdentityAdapter=New-ServiceHealthAdapter -Mode 'Healthy' -Root $fixture.Fence
    Assert-Throws{New-HetznerServiceActivationPlan -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName hc-2 -MissionPboPath $fixture.Pbo -ServiceName 'Arma2OA-PR8' -ServiceAdapterPath $serviceIdentityAdapter.Path -AdapterConfigPath $wrongServicePath -IsolationAttestationPath $isolationPlan.AttestationReceiptPath -AdapterId 'fixture-wrong-service'|Out-Null} 'T16g service identity must equal the sealed test binding' 'service name|MIKSUUS-TEST'
    Assert(@(Get-AdapterCalls $serviceIdentityAdapter).Count-eq 0) 'T16g rejected service identity invokes no adapter'

    Write-Host 'TEST T15a: dry run validates the sealed two-HC install but never invokes the service adapter'
    $healthy = New-ServiceHealthAdapter -Mode 'Healthy' -Root $fixture.Fence
    Assert-Throws { New-HetznerServiceActivationPlan -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-2' -MissionPboPath $fixture.Pbo -ServiceName 'Arma2OA-PR8' -ServiceAdapterPath $healthy.Path -AdapterConfigPath $fixture.AdapterConfig -AdapterId 'fixture-service-no-isolation-v1' -MinimumObservationSeconds 60 } 'T15a two-HC service activation refuses missing isolation proof' 'isolation|attestation'
    $plan = New-HetznerServiceActivationPlan -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-2' -MissionPboPath $fixture.Pbo -ServiceName 'Arma2OA-PR8' -ServiceAdapterPath $healthy.Path -AdapterConfigPath $fixture.AdapterConfig -IsolationAttestationPath $isolationPlan.AttestationReceiptPath -AdapterId 'fixture-service-v1' -MinimumObservationSeconds 60
    $dryRun = Invoke-HetznerServiceActivationPlan -Plan $plan
    Assert (-not $dryRun.Applied -and -not $dryRun.AdapterInvoked -and $dryRun.CommitState -eq 'DryRun') 'T15a dry run is non-mutating and adapter-free'
    Assert (@(Get-AdapterCalls $healthy).Count -eq 0) 'T15a dry run made zero adapter calls'
    Assert (-not (Test-Path -LiteralPath $plan.ActivationReceiptPath)) 'T15a dry run writes no activation receipt'
    $baselineMismatch=New-ServiceHealthAdapter -Mode 'BaselineMissionMismatch' -Root $fixture.Fence
    $baselineMismatchPlan=New-HetznerServiceActivationPlan -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName hc-2 -MissionPboPath $fixture.Pbo -ServiceName 'Arma2OA-PR8' -ServiceAdapterPath $baselineMismatch.Path -AdapterConfigPath $fixture.AdapterConfig -IsolationAttestationPath $isolationPlan.AttestationReceiptPath -AdapterId 'fixture-service-baseline-mismatch' -MinimumObservationSeconds 60
    Assert-Throws{Invoke-HetznerServiceActivationPlan -Plan $baselineMismatchPlan -Apply|Out-Null} 'T15a captured wrong mission is rejected before activation' 'baseline|mission|release|identity'
    Assert((@(Get-AdapterCalls $baselineMismatch)-join',')-ceq'CaptureBaseline'-and-not(Test-Path -LiteralPath $baselineMismatchPlan.ActivationReceiptPath)) 'T15a baseline mismatch makes zero mutation or restore calls and writes no receipt'

    Write-Host 'TEST T15b: only a healthy mission, service, advanced RPT, and unique HC set can commit'
    $result = Invoke-HetznerServiceActivationPlan -Plan $plan -Apply
    Assert ($result.Applied -and $result.CommitState -eq 'CommittedAfterHealth') 'T15b activation commits after validated health'
    Assert ((@(Get-AdapterCalls $healthy) -join ',') -eq 'CaptureBaseline,ApplyActivation,ObserveHealth') 'T15b adapter call order captures, applies, then observes'
    Assert ((Test-Path -LiteralPath $plan.ActivationReceiptPath) -and $result.Receipt.MissionPboSha256 -eq $plan.MissionPboSha256) 'T15b committed receipt binds the intended mission hash'

    Write-Host 'TEST T15c: health failure restores and independently re-verifies the captured baseline'
    $fatal = New-ServiceHealthAdapter -Mode 'Fatal' -Root $fixture.Fence
    $fatalPlan = New-HetznerServiceActivationPlan -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-2' -MissionPboPath $fixture.Pbo -ServiceName 'Arma2OA-PR8' -ServiceAdapterPath $fatal.Path -AdapterConfigPath $fixture.AdapterConfig -IsolationAttestationPath $isolationPlan.AttestationReceiptPath -AdapterId 'fixture-service-fatal-v1' -MinimumObservationSeconds 60
    Assert-Throws { Invoke-HetznerServiceActivationPlan -Plan $fatalPlan -Apply } 'T15c fatal-free window is mandatory' 'fatal|health'
    Assert ((Test-AdapterRestored $fatal) -and ((@(Get-AdapterCalls $fatal) -join ',') -eq 'CaptureBaseline,ApplyActivation,ObserveHealth,RestoreBaseline,ObserveBaseline')) 'T15c failed health restores and re-observes baseline'
    Assert (-not (Test-Path -LiteralPath $fatalPlan.ActivationReceiptPath)) 'T15c failed health writes no activation receipt'

    Write-Host 'TEST T15d: mission, RPT, and HC identity regressions roll back before commit'
    foreach ($mode in @('MissionMismatch','ServerNotAdvanced','DuplicateHc','ProcessMismatch','StartMismatch')) {
        $broken = New-ServiceHealthAdapter -Mode $mode -Root $fixture.Fence
        $brokenPlan = New-HetznerServiceActivationPlan -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-2' -MissionPboPath $fixture.Pbo -ServiceName 'Arma2OA-PR8' -ServiceAdapterPath $broken.Path -AdapterConfigPath $fixture.AdapterConfig -IsolationAttestationPath $isolationPlan.AttestationReceiptPath -AdapterId ("fixture-service-$mode") -MinimumObservationSeconds 60
        Assert-Throws { Invoke-HetznerServiceActivationPlan -Plan $brokenPlan -Apply } "T15d $mode is rejected" 'mission|RPT|HC|health|identity'
        Assert (Test-AdapterRestored $broken) "T15d $mode restores baseline"
        Assert (-not (Test-Path -LiteralPath $brokenPlan.ActivationReceiptPath)) "T15d $mode does not commit"
    }

    Write-Host 'TEST T15e: adapter drift is rejected before any callback'
    $tampered = New-ServiceHealthAdapter -Mode 'Healthy' -Root $fixture.Fence
    $tamperedPlan = New-HetznerServiceActivationPlan -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-2' -MissionPboPath $fixture.Pbo -ServiceName 'Arma2OA-PR8' -ServiceAdapterPath $tampered.Path -AdapterConfigPath $fixture.AdapterConfig -IsolationAttestationPath $isolationPlan.AttestationReceiptPath -AdapterId 'fixture-service-tamper-v1' -MinimumObservationSeconds 60
    [System.IO.File]::WriteAllText($tampered.Path, '# changed after service plan sealing')
    Assert-Throws { Invoke-HetznerServiceActivationPlan -Plan $tamperedPlan -Apply } 'T15e adapter hash drift is rejected before invocation' 'adapter|hash|changed'
    Assert (@(Get-AdapterCalls $tampered).Count -eq 0) 'T15e adapter drift made zero calls'

    Write-Host 'TEST T15f: the T14 lock and post-health contract revalidation fence receipt commit'
    $lockedService=New-ServiceHealthAdapter -Mode 'Healthy' -Root $fixture.Fence
    $lockedServicePlan=New-HetznerServiceActivationPlan -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-2' -MissionPboPath $fixture.Pbo -ServiceName 'Arma2OA-PR8' -ServiceAdapterPath $lockedService.Path -AdapterConfigPath $fixture.AdapterConfig -IsolationAttestationPath $isolationPlan.AttestationReceiptPath -AdapterId 'fixture-service-locked' -MinimumObservationSeconds 60
    $tx=Get-HetznerTransactionStatus -InstallRoot $fixture.Install -FenceRoot $fixture.Fence;$held=New-Object System.IO.FileStream($tx.LockPath,[System.IO.FileMode]::CreateNew,[System.IO.FileAccess]::ReadWrite,[System.IO.FileShare]::None,4096,[System.IO.FileOptions]::DeleteOnClose)
    try{Assert-Throws{Invoke-HetznerServiceActivationPlan -Plan $lockedServicePlan -Apply|Out-Null} 'T15f held T14 lock rejects service Apply' 'exclusive|transaction|active'}finally{$held.Dispose()}
    Assert(@(Get-AdapterCalls $lockedService).Count-eq 0) 'T15f lock refusal invokes no service action'
    $journalRaw=[System.IO.File]::ReadAllText($tx.JournalPath);$tamperService=New-ServiceHealthAdapter -Mode 'TamperJournal' -Root $fixture.Fence -TamperPath $tx.JournalPath
    $tamperServicePlan=New-HetznerServiceActivationPlan -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName 'hc-2' -MissionPboPath $fixture.Pbo -ServiceName 'Arma2OA-PR8' -ServiceAdapterPath $tamperService.Path -AdapterConfigPath $fixture.AdapterConfig -IsolationAttestationPath $isolationPlan.AttestationReceiptPath -AdapterId 'fixture-service-revalidate' -MinimumObservationSeconds 60
    Assert-Throws{Invoke-HetznerServiceActivationPlan -Plan $tamperServicePlan -Apply|Out-Null} 'T15f changed T14 contract cannot commit a health receipt' 'journal|fingerprint|contract|changed'
    [System.IO.File]::WriteAllText($tx.JournalPath,$journalRaw,(New-Object System.Text.UTF8Encoding($false)))
    Assert((Test-AdapterRestored $tamperService)-and-not(Test-Path -LiteralPath $tamperServicePlan.ActivationReceiptPath)) 'T15f post-health revalidation restores and writes no receipt'

    Write-Host 'TEST T15g: zero/one-HC fallbacks are accepted while three-HC remains experimental'
    foreach($fallbackProfile in @('hc-0','hc-1')){
        $count=if($fallbackProfile-eq'hc-0'){0}else{1};$fallback=New-Fixture -HeadlessClients $count -ProfileName $fallbackProfile
        try{
            $fallbackInstall=New-HetznerPlan -SourceRoot $fallback.Source -InstallRoot $fallback.Install -FenceRoot $fallback.Fence -ProfileName $fallbackProfile -MissionPboPath $fallback.Pbo;Invoke-HetznerPlan -Plan $fallbackInstall -Apply|Out-Null
            $fallbackAdapter=New-ServiceHealthAdapter -Mode 'Healthy' -Root $fallback.Fence
            $fallbackPlan=New-HetznerServiceActivationPlan -InstallRoot $fallback.Install -FenceRoot $fallback.Fence -ProfileName $fallbackProfile -MissionPboPath $fallback.Pbo -ServiceName 'Arma2OA-PR8' -ServiceAdapterPath $fallbackAdapter.Path -AdapterConfigPath $fallback.AdapterConfig -AdapterId ("fixture-service-$fallbackProfile") -MinimumObservationSeconds 60
            $fallbackResult=Invoke-HetznerServiceActivationPlan -Plan $fallbackPlan -Apply
            Assert($fallbackResult.Applied-and@($fallbackResult.Receipt.Health.HeadlessClients).Count-eq$count) "T15g $fallbackProfile health matches its exact fallback topology"
        }finally{if($fallback-and(Test-Path -LiteralPath $fallback.Root)){Remove-Item -LiteralPath $fallback.Root -Recurse -Force}}
    }
    $stretch=New-Fixture -HeadlessClients 3 -ProfileName 'hc-3'
    try{
        $stretchInstall=New-HetznerPlan -SourceRoot $stretch.Source -InstallRoot $stretch.Install -FenceRoot $stretch.Fence -ProfileName hc-3 -MissionPboPath $stretch.Pbo;Invoke-HetznerPlan -Plan $stretchInstall -Apply|Out-Null
        $stretchAdapter=New-ServiceHealthAdapter -Mode 'Healthy' -Root $stretch.Fence
        Assert-Throws{New-HetznerServiceActivationPlan -InstallRoot $stretch.Install -FenceRoot $stretch.Fence -ProfileName hc-3 -MissionPboPath $stretch.Pbo -ServiceName 'Arma2OA-PR8' -ServiceAdapterPath $stretchAdapter.Path -AdapterConfigPath $stretch.AdapterConfig -AdapterId 'fixture-service-hc-3' -MinimumObservationSeconds 60|Out-Null} 'T15g hc-3 activation stays experimental and fail-closed' 'experimental|three-HC'
        $stretchIsolation=New-IsolationAdapter -Mode 'Healthy' -Root $stretch.Fence
        $stretchIsolationPlan=New-HetznerHCIsolationAttestationPlan -InstallRoot $stretch.Install -FenceRoot $stretch.Fence -ProfileName hc-3 -MissionPboPath $stretch.Pbo -IsolationAdapterPath $stretchIsolation.Path -AdapterConfigPath $stretch.AdapterConfig -AdapterId 'fixture-isolation-hc-3' -MinimumObservationSeconds 60
        $stretchPreview=Invoke-HetznerHCIsolationAttestationPlan -Plan $stretchIsolationPlan
        Assert(-not$stretchPreview.Applied-and@($stretchIsolationPlan.ExpectedIsolation).Count-eq 3) 'T15g hc-3 retains a three-identity experimental dry-run surface'
    }finally{if($stretch-and(Test-Path -LiteralPath $stretch.Root)){Remove-Item -LiteralPath $stretch.Root -Recurse -Force}}

    Write-Host 'TEST T15h: public wrapper exposes adapter-free isolation and service dry runs'
    $wrapper=Join-Path $PSScriptRoot 'Invoke-HetznerInstaller.ps1'
    $wrapperIsolation=New-IsolationAdapter -Mode 'Healthy' -Root $fixture.Fence
    $wrapperIsolationResult=& $wrapper -Action IsolationPlan -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName hc-2 -MissionPboPath $fixture.Pbo -AdapterPath $wrapperIsolation.Path -AdapterConfigPath $fixture.AdapterConfig -AdapterId 'fixture-wrapper-isolation' -MinimumObservationSeconds 60
    Assert(-not$wrapperIsolationResult.Applied-and-not$wrapperIsolationResult.AdapterInvoked-and@(Get-AdapterCalls $wrapperIsolation).Count-eq 0) 'T15h wrapper isolation dry run invokes no adapter'
    $wrapperService=New-ServiceHealthAdapter -Mode 'Healthy' -Root $fixture.Fence
    $wrapperServiceResult=& $wrapper -Action ServiceActivationPlan -InstallRoot $fixture.Install -FenceRoot $fixture.Fence -ProfileName hc-2 -MissionPboPath $fixture.Pbo -AdapterPath $wrapperService.Path -AdapterConfigPath $fixture.AdapterConfig -AdapterId 'fixture-wrapper-service' -ServiceName 'Arma2OA-PR8' -IsolationAttestationPath $isolationPlan.AttestationReceiptPath -MinimumObservationSeconds 60
    Assert(-not$wrapperServiceResult.Applied-and-not$wrapperServiceResult.AdapterInvoked-and@(Get-AdapterCalls $wrapperService).Count-eq 0) 'T15h wrapper service dry run invokes no adapter'
}
finally {
    if ($fixture -and (Test-Path -LiteralPath $fixture.Root)) { Remove-Item -LiteralPath $fixture.Root -Recurse -Force }
}

Write-Host ''
if ($script:fails -eq 0) { Write-Host 'T15 SERVICE HEALTH TESTS PASSED' -ForegroundColor Green; exit 0 }
Write-Host "$($script:fails) TEST(S) FAILED" -ForegroundColor Red
exit 1
