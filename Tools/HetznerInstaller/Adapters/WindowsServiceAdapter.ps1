#requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)]$Request)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest

function Get-AdapterSha256([string]$Value){
    $sha=[System.Security.Cryptography.SHA256]::Create()
    try{return ([System.BitConverter]::ToString($sha.ComputeHash((New-Object System.Text.UTF8Encoding($false)).GetBytes($Value)))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
}

function Get-AdapterConfiguration {
    $config=if($Request.PSObject.Properties.Name-contains'AdapterConfiguration'){$Request.AdapterConfiguration}elseif($Request.PSObject.Properties.Name-contains'IsolationAttestation'){$Request.IsolationAttestation.AdapterConfiguration.Configuration}else{$null}
    if($null-eq$config){throw 'The bound request has no adapter configuration.'}
    if([int]$config.SchemaVersion-ne 1 -or [string]$config.ConfigType-cne'windows-service-adapter-v1' -or [string]$config.EnvironmentId-cne'MIKSUUS-TEST'){throw 'The bound adapter configuration is not a valid MIKSUUS-TEST identity.'}
    return $config
}

function Get-ExpectedIsolation {
    if($Request.PSObject.Properties.Name-notcontains'ExpectedIsolation'){return @($Request.IsolationAttestation.AdapterConfiguration.ExpectedIsolation)}
    return @($Request.ExpectedIsolation)
}

function Get-ConfiguredProcessMatches([Parameter(Mandatory)]$Expected){
    $candidates=@(Get-CimInstance Win32_Process -Filter ("Name='{0}'" -f ([string]$Expected.ProcessName).Replace("'","''"))|Where-Object{
        $command=[string]$_.CommandLine
        -not[string]::IsNullOrWhiteSpace($command) -and $command.IndexOf([string]$Expected.Name,[System.StringComparison]::OrdinalIgnoreCase)-ge 0 -and $command.IndexOf([string]$Expected.ProfileRoot,[System.StringComparison]::OrdinalIgnoreCase)-ge 0 -and $command.IndexOf([string]$Expected.SandboxRoot,[System.StringComparison]::OrdinalIgnoreCase)-ge 0
    })
    foreach($candidate in $candidates){if((Get-AdapterSha256 ([string]$candidate.CommandLine))-cne[string]$Expected.CommandLineFingerprint){throw "Configured HC command fingerprint drifted: $($Expected.RptIdentity)"}}
    return $candidates
}

function Get-ConfiguredProcess([Parameter(Mandatory)]$Expected){
    $matches=@(Get-ConfiguredProcessMatches -Expected $Expected)
    if($matches.Count-ne 1){throw "Expected exactly one configured HC process for $($Expected.RptIdentity); measured $($matches.Count)."}
    return $matches[0]
}

function Get-AdapterFatalLineCount([Parameter(Mandatory)][string[]]$RptPaths){
    $count=0
    foreach($rpt in @($RptPaths|Sort-Object -Unique)){
        if(-not(Test-Path -LiteralPath $rpt -PathType Leaf)){throw "Configured observation RPT is missing: $rpt"}
        $count += @(Get-Content -LiteralPath $rpt -Tail 400 -ErrorAction Stop|Where-Object{$_-match'(?i)(fatal|exception|no entry|cannot load)'}).Count
    }
    return $count
}

function Get-HcEvidence {
    $result=@()
    foreach($expected in Get-ExpectedIsolation){
        $process=Get-ConfiguredProcess -Expected $expected;$rpt=[string]$expected.RptPath
        if(-not(Test-Path -LiteralPath $rpt -PathType Leaf)){throw "Configured HC RPT is missing: $($expected.RptIdentity)"}
        $command=[string]$process.CommandLine;$fingerprint=Get-AdapterSha256 $command
        if($fingerprint-cne[string]$expected.CommandLineFingerprint){throw "Measured HC launch fingerprint differs from the sealed configuration: $($expected.RptIdentity)"}
        $created=if($process.CreationDate-is[datetime]){([datetime]$process.CreationDate).ToUniversalTime()}else{[System.Management.ManagementDateTimeConverter]::ToDateTime([string]$process.CreationDate).ToUniversalTime()}
        $result += [pscustomobject][ordered]@{Name=[string]$expected.Name;RptIdentity=[string]$expected.RptIdentity;ProcessId=[int]$process.ProcessId;InstanceId=("{0}:{1}:{2}" -f $env:COMPUTERNAME,[int]$process.ProcessId,$created.Ticks);SandboxRoot=[string]$expected.SandboxRoot;ProfileRoot=[string]$expected.ProfileRoot;RptPath=$rpt;RptLastWriteUtc=(Get-Item -LiteralPath $rpt).LastWriteTimeUtc.ToString('o');StartUtc=$created.ToString('o');CommandLineFingerprint=$fingerprint}
    }
    return @($result|Sort-Object RptIdentity)
}

function Get-Baseline {
    $instances=@()
    foreach($expected in Get-ExpectedIsolation){
        $matches=@(Get-ConfiguredProcessMatches -Expected $expected)
        if($matches.Count-gt 1){throw "Baseline contains duplicate configured HC processes: $($expected.RptIdentity)"}
        if($matches.Count-eq 1){$instances += ("{0}:{1}" -f $env:COMPUTERNAME,[int]$matches[0].ProcessId)}
    }
    $instances=@($instances|Sort-Object)
    return [pscustomobject][ordered]@{AdapterId=[string]$Request.AdapterId;ProfileName=[string]$Request.ProfileName;BaselineFingerprint=(Get-AdapterSha256 ($instances|ConvertTo-Json -Compress));ActiveInstanceIds=$instances}
}

function Start-ConfiguredHeadlessClients {
    foreach($expected in Get-ExpectedIsolation){
        $matches=@(Get-ConfiguredProcessMatches -Expected $expected)
        if($matches.Count-gt 1){throw "Refusing to expand duplicate configured HC processes: $($expected.RptIdentity)"}
        if($matches.Count-eq 0){Start-ScheduledTask -TaskName ([string]$expected.LaunchTaskName)}
    }
}

function Stop-ConfiguredHeadlessClients([int[]]$PreserveProcessIds=@()) {
    foreach($expected in Get-ExpectedIsolation){
        $processes=@(Get-ConfiguredProcessMatches -Expected $expected)
        $removable=@($processes|Where-Object{$PreserveProcessIds-notcontains[int]$_.ProcessId})
        if($removable.Count-gt 0){Stop-ScheduledTask -TaskName ([string]$expected.LaunchTaskName) -ErrorAction SilentlyContinue}
        foreach($process in $removable){Stop-Process -Id ([int]$process.ProcessId) -Force -ErrorAction Stop}
    }
}

function Get-ServiceEvidence([switch]$IncludeWindow){
    $config=Get-AdapterConfiguration;$service=Get-Service -Name ([string]$Request.ServiceName) -ErrorAction Stop
    $mission=[string]$config.MissionPboPath;$serverRpt=[string]$config.ServerRptPath
    if(-not(Test-Path -LiteralPath $mission -PathType Leaf)){throw 'Configured mission PBO is missing.'};if(-not(Test-Path -LiteralPath $serverRpt -PathType Leaf)){throw 'Configured server RPT is missing.'}
    $hcs=Get-HcEvidence;$result=[ordered]@{AdapterId=[string]$Request.AdapterId;ServiceName=[string]$Request.ServiceName;ServiceStatus=[string]$service.Status;MissionPboLeaf=[System.IO.Path]::GetFileName($mission);MissionPboSha256=(Get-FileHash -LiteralPath $mission -Algorithm SHA256).Hash.ToLowerInvariant();ConfigurationFingerprint=(Get-AdapterSha256 ($config|ConvertTo-Json -Depth 10 -Compress));ServerRpt=[pscustomobject]@{Identity=$serverRpt;LastWriteUtc=(Get-Item -LiteralPath $serverRpt).LastWriteTimeUtc.ToString('o')};HeadlessClients=$hcs}
    if($IncludeWindow){$fatalCount=Get-AdapterFatalLineCount -RptPaths (@($serverRpt)+@($hcs|ForEach-Object{[string]$_.RptPath}));$result.ObservationWindowSeconds=[int]$Request.MinimumObservationSeconds;$result.FatalLineCount=$fatalCount}
    return [pscustomobject]$result
}

$config=Get-AdapterConfiguration
if($Request.PSObject.Properties.Name-contains'ServiceName' -and -not[string]::IsNullOrWhiteSpace([string]$Request.ServiceName) -and [string]$Request.ServiceName-cne[string]$config.ServiceName){throw 'Requested service name differs from the sealed adapter configuration.'}

switch([string]$Request.Action){
    'CaptureIsolationBaseline'{return Get-Baseline}
    'ApplyIsolation'{Start-ConfiguredHeadlessClients;return [pscustomobject]@{AdapterId=[string]$Request.AdapterId;Applied=$true}}
    'ObserveIsolation'{Start-Sleep -Seconds ([int]$Request.MinimumObservationSeconds);$hcs=Get-HcEvidence;$fatal=Get-AdapterFatalLineCount -RptPaths @($hcs|ForEach-Object{[string]$_.RptPath});return [pscustomobject]@{AdapterId=[string]$Request.AdapterId;ProfileName=[string]$Request.ProfileName;ObservationWindowSeconds=[int]$Request.MinimumObservationSeconds;FatalLineCount=$fatal;HeadlessClients=$hcs}}
    'RestoreIsolationBaseline'{$preserve=@($Request.Baseline.ActiveInstanceIds|ForEach-Object{[int](([string]$_).Split(':')[-1])});Stop-ConfiguredHeadlessClients -PreserveProcessIds $preserve;return [pscustomobject]@{AdapterId=[string]$Request.AdapterId;Restored=$true}}
    'ObserveIsolationBaseline'{return Get-Baseline}
    'CaptureBaseline'{return Get-ServiceEvidence}
    'ApplyActivation'{Restart-Service -Name ([string]$Request.ServiceName) -Force -ErrorAction Stop;Start-ConfiguredHeadlessClients;return [pscustomobject]@{AdapterId=[string]$Request.AdapterId;Applied=$true}}
    'ObserveHealth'{Start-Sleep -Seconds ([int]$Request.MinimumObservationSeconds);return Get-ServiceEvidence -IncludeWindow}
    'RestoreBaseline'{$preserve=@($Request.Baseline.HeadlessClients|ForEach-Object{[int]$_.ProcessId});Stop-ConfiguredHeadlessClients -PreserveProcessIds $preserve;if([string]$Request.Baseline.ServiceStatus-eq'Running'){Start-Service -Name ([string]$Request.ServiceName)}else{Stop-Service -Name ([string]$Request.ServiceName) -Force};return [pscustomobject]@{AdapterId=[string]$Request.AdapterId;Restored=$true}}
    'ObserveBaseline'{return Get-ServiceEvidence}
    default{throw "Unsupported bound adapter action: $($Request.Action)"}
}
