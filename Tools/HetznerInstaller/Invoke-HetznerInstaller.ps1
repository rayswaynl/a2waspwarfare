#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Preflight','DryRun','ApplyPlan','Backup','Verify','TransactionStatus','RecoverPlan','RollbackPlan','UninstallPlan','IsolationPlan','ServiceActivationPlan')]
    [string]$Action = 'Preflight',
    [string]$SourceRoot,
    [string]$InstallRoot,
    [string]$FenceRoot,
    [string]$BackupRoot,
    [string]$MissionPboPath,
    [string]$AdapterPath,
    [string]$AdapterConfigPath,
    [string]$AdapterId,
    [string]$ServiceName,
    [string]$IsolationAttestationPath,
    [ValidateRange(1,3600)][int]$MinimumObservationSeconds=60,
    [ValidateSet('hc-0','hc-1','hc-2','hc-3')]
    [string]$ProfileName = 'hc-0',
    [switch]$Apply,
    [switch]$Json
)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
    $SourceRoot = Split-Path -Parent (Split-Path -Parent $scriptRoot)
}
Import-Module -Force (Join-Path $PSScriptRoot 'HetznerInstaller.psm1')

function Require-InstallerPath([string]$Name, [string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { throw "-$Name is required for -Action $Action." }
}

switch ($Action) {
    'Preflight' { $output = Test-HetznerPreflight -SourceRoot $SourceRoot -ProfileName $ProfileName -MissionPboPath $MissionPboPath }
    'DryRun' {
        Require-InstallerPath 'InstallRoot' $InstallRoot
        Require-InstallerPath 'FenceRoot' $FenceRoot
        Require-InstallerPath 'MissionPboPath' $MissionPboPath
        $output = New-HetznerPlan -SourceRoot $SourceRoot -InstallRoot $InstallRoot -FenceRoot $FenceRoot -ProfileName $ProfileName -MissionPboPath $MissionPboPath
    }
    'ApplyPlan' {
        Require-InstallerPath 'InstallRoot' $InstallRoot
        Require-InstallerPath 'FenceRoot' $FenceRoot
        Require-InstallerPath 'MissionPboPath' $MissionPboPath
        $plan = New-HetznerPlan -SourceRoot $SourceRoot -InstallRoot $InstallRoot -FenceRoot $FenceRoot -ProfileName $ProfileName -MissionPboPath $MissionPboPath
        $output = Invoke-HetznerPlan -Plan $plan -Apply:$Apply
    }
    'Verify' {
        Require-InstallerPath 'InstallRoot' $InstallRoot
        Require-InstallerPath 'MissionPboPath' $MissionPboPath
        $verifyArguments = @{ InstallRoot=$InstallRoot; ProfileName=$ProfileName; MissionPboPath=$MissionPboPath }
        if (-not [string]::IsNullOrWhiteSpace($FenceRoot)) { $verifyArguments.FenceRoot=$FenceRoot }
        $output = [pscustomobject]@{ Verified = (Test-HetznerInstallation @verifyArguments); InstallRoot = $InstallRoot; ProfileName = $ProfileName }
    }
    'Backup' {
        Require-InstallerPath 'InstallRoot' $InstallRoot
        Require-InstallerPath 'FenceRoot' $FenceRoot
        $plan = New-HetznerBackupPlan -InstallRoot $InstallRoot -BackupRoot $BackupRoot -FenceRoot $FenceRoot
        $output = Invoke-HetznerBackupPlan -Plan $plan -Apply:$Apply
    }
    'TransactionStatus' {
        Require-InstallerPath 'InstallRoot' $InstallRoot
        Require-InstallerPath 'FenceRoot' $FenceRoot
        $output = Get-HetznerTransactionStatus -InstallRoot $InstallRoot -FenceRoot $FenceRoot
    }
    'RecoverPlan' {
        Require-InstallerPath 'InstallRoot' $InstallRoot
        Require-InstallerPath 'FenceRoot' $FenceRoot
        if ($Apply) { $output = Invoke-HetznerRecoverPlan -InstallRoot $InstallRoot -FenceRoot $FenceRoot }
        else {
            $status = Get-HetznerTransactionStatus -InstallRoot $InstallRoot -FenceRoot $FenceRoot
            $output = [pscustomobject]@{ Applied = $false; State = $status.State; OperationIndex = $status.OperationIndex; InstallRoot = $InstallRoot; JournalPath = $status.JournalPath }
        }
    }
    'RollbackPlan' {
        Require-InstallerPath 'InstallRoot' $InstallRoot
        Require-InstallerPath 'FenceRoot' $FenceRoot
        $rollbackArguments = @{ InstallRoot=$InstallRoot; FenceRoot=$FenceRoot }
        if (-not [string]::IsNullOrWhiteSpace($BackupRoot)) { $rollbackArguments.BackupRoot=$BackupRoot }
        $plan = New-HetznerRollbackPlan @rollbackArguments
        $output = Invoke-HetznerRollbackPlan -Plan $plan -Apply:$Apply
    }
    'UninstallPlan' {
        Require-InstallerPath 'InstallRoot' $InstallRoot
        Require-InstallerPath 'FenceRoot' $FenceRoot
        Require-InstallerPath 'MissionPboPath' $MissionPboPath
        $plan = New-HetznerUninstallPlan -InstallRoot $InstallRoot -FenceRoot $FenceRoot -ProfileName $ProfileName -MissionPboPath $MissionPboPath
        $output = Invoke-HetznerUninstallPlan -Plan $plan -Apply:$Apply
    }
    'IsolationPlan' {
        Require-InstallerPath 'InstallRoot' $InstallRoot
        Require-InstallerPath 'FenceRoot' $FenceRoot
        Require-InstallerPath 'MissionPboPath' $MissionPboPath
        Require-InstallerPath 'AdapterPath' $AdapterPath
        Require-InstallerPath 'AdapterConfigPath' $AdapterConfigPath
        Require-InstallerPath 'AdapterId' $AdapterId
        if($ProfileName-notin@('hc-2','hc-3')){throw '-Action IsolationPlan requires -ProfileName hc-2 or hc-3.'}
        $plan=New-HetznerHCIsolationAttestationPlan -InstallRoot $InstallRoot -FenceRoot $FenceRoot -ProfileName $ProfileName -MissionPboPath $MissionPboPath -IsolationAdapterPath $AdapterPath -AdapterConfigPath $AdapterConfigPath -AdapterId $AdapterId -MinimumObservationSeconds $MinimumObservationSeconds
        $output=Invoke-HetznerHCIsolationAttestationPlan -Plan $plan -Apply:$Apply
    }
    'ServiceActivationPlan' {
        Require-InstallerPath 'InstallRoot' $InstallRoot
        Require-InstallerPath 'FenceRoot' $FenceRoot
        Require-InstallerPath 'MissionPboPath' $MissionPboPath
        Require-InstallerPath 'AdapterPath' $AdapterPath
        Require-InstallerPath 'AdapterConfigPath' $AdapterConfigPath
        Require-InstallerPath 'AdapterId' $AdapterId
        Require-InstallerPath 'ServiceName' $ServiceName
        $arguments=@{InstallRoot=$InstallRoot;FenceRoot=$FenceRoot;ProfileName=$ProfileName;MissionPboPath=$MissionPboPath;ServiceName=$ServiceName;ServiceAdapterPath=$AdapterPath;AdapterConfigPath=$AdapterConfigPath;AdapterId=$AdapterId;MinimumObservationSeconds=$MinimumObservationSeconds}
        if(-not[string]::IsNullOrWhiteSpace($IsolationAttestationPath)){$arguments.IsolationAttestationPath=$IsolationAttestationPath}
        $plan=New-HetznerServiceActivationPlan @arguments
        $output=Invoke-HetznerServiceActivationPlan -Plan $plan -Apply:$Apply
    }
}

if ($Json) { $output | ConvertTo-Json -Depth 8 } else { $output }
