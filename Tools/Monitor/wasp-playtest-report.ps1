#requires -Version 5.1
<#!
.SYNOPSIS
  Peach+ playtest digest, alert, and post-test summary reporter.

.DESCRIPTION
  Start/Tick/Stop is intentionally one-shot so Task Scheduler can invoke Tick every
  5-10 minutes without a resident process. State is kept on the operator host. Production
  ticks call the box collector over the existing SSH path; -LocalSourceDirectory and
  -NoSend make dry-runs deterministic and safe.
#>
param(
    [ValidateSet('Start','Tick','Stop')][string]$Action = 'Tick',
    [string]$StatePath = $(Join-Path $env:ProgramData 'Wasp\playtest-state.json'),
    [string]$OutputDirectory = $(Join-Path $env:ProgramData 'Wasp\playtest'),
    [string]$BoxHost = 'livehost',
    [string]$RemoteCollector = 'C:\WASP\monitor\wasp-playtest-box.ps1',
    [string]$LocalCollector = '',
    [string]$LocalSourceDirectory = '',
    [string]$PeachSenderPath = '',
    [int]$FpsFloor = 12,
    [int]$ErrorSpikeThreshold = 5,
    [int]$AlertCooldownMinutes = 10,
    [switch]$NoSend
)
$ErrorActionPreference = 'Stop'
$script:Version = 'playtest-report-v1'
if (-not (Test-Path -LiteralPath $OutputDirectory)) { New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null }

function New-Map { return @{} }
function ConvertTo-Map($Object) {
    $map = @{}
    if ($null -ne $Object) { foreach ($p in $Object.PSObject.Properties) { $map[$p.Name] = $p.Value } }
    return $map
}
function Get-ErrorMap($State) {
    $map=@{}
    foreach($entry in @($State.errorCounts)) {
        if($null -ne $entry -and $entry.signature) { $map[[string]$entry.signature]=[int]$entry.count }
    }
    return $map
}
function Set-ErrorCounts([hashtable]$Map) {
    if($Map.Count -eq 0) { return [pscustomobject]@{} }
    return @($Map.GetEnumerator() | Sort-Object Name | ForEach-Object {
        [pscustomobject]@{signature=[string]$_.Key;count=[int]$_.Value}
    })
}
function Read-State {
    if (Test-Path -LiteralPath $StatePath) { return (Get-Content -Raw -LiteralPath $StatePath | ConvertFrom-Json) }
    return $null
}
function Save-State($State) {
    $tmp = "$StatePath.tmp-$PID"
    $State | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $tmp -Encoding UTF8
    Move-Item -LiteralPath $tmp -Destination $StatePath -Force
}
function Get-Fact([hashtable]$Facts, [string]$Name, $Default = $null) {
    if ($Facts.ContainsKey($Name)) { return $Facts[$Name] }
    return $Default
}
function Invoke-Collector($State) {
    $args = @('-SrvFrom',[string]([long]$State.marks.srv),'-Hc1From',[string]([long]$State.marks.hc1),'-Hc2From',[string]([long]$State.marks.hc2))
    if ($LocalSourceDirectory) {
        $collector = $LocalCollector
        if (-not $collector) { $collector = Join-Path $PSScriptRoot 'wasp-playtest-box.ps1' }
        $args += @('-SrvRpt',(Join-Path $LocalSourceDirectory 'arma2oaserver.RPT'),'-Hc1Rpt',(Join-Path $LocalSourceDirectory 'hc1-ArmA2OA.RPT'),'-Hc2Rpt',(Join-Path $LocalSourceDirectory 'hc2-ArmA2OA.RPT'))
        return @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $collector @args 2>&1 | ForEach-Object { $_.ToString() })
    }
    return @(& ssh.exe -o BatchMode=yes -o ConnectTimeout=10 $BoxHost powershell.exe -NoProfile -ExecutionPolicy Bypass -File $RemoteCollector @args 2>&1 | ForEach-Object { $_.ToString() })
}
function Parse-Collector($Lines) {
    $facts = @{}; $new = New-Object System.Collections.Generic.List[object]
    foreach ($raw in $Lines) {
        $line = $raw.Trim()
        if ($line -match '^K\|') {
            foreach ($part in ($line.Substring(2) -split '\|')) {
                $kv = $part -split '=',2
                if ($kv.Count -eq 2) { $facts[$kv[0]] = $kv[1] }
            }
        } elseif ($line -match '^NEW\|([^|]+)\|([^|]+)\|(.*)$') {
            $new.Add([pscustomobject]@{ tag=$Matches[1]; kind=$Matches[2]; line=$Matches[3] })
        }
    }
    if ((Get-Fact $facts 'collectorStatus') -ne 'ok') { throw "collector did not return collectorStatus=ok" }
    return [pscustomobject]@{ facts=$facts; new=$new.ToArray() }
}
function To-Int($Value, [int]$Default = -1) { $n=0; if ([int]::TryParse([string]$Value,[ref]$n)) { return $n }; return $Default }
function To-Long($Value, [long]$Default = -1) { $n=0L; if ([long]::TryParse([string]$Value,[ref]$n)) { return $n }; return $Default }
function Get-Signature([string]$Line) {
    $clean = ($Line -replace '^\s*"','' -replace '"\s*$','').Trim()
    if ($clean -notmatch '\.sqf,\s*line\s*\d+' -and $clean -match 'Error in expression|Error position|Undefined variable|Error Undefined|Error Zero divisor|Error Type') {
        return ''
    }
    if ($clean -match 'File\s+(.+?\.sqf),\s*line\s*(\d+)') {
        $src = ($Matches[1] -replace '\s+',' ' -replace '\\','/').Trim()
        $message = ($clean -replace '.*?Error in expression:\s*','' -replace '.*?Error\s+','').Trim()
        if ($message.Length -gt 100) { $message = $message.Substring(0,100) }
        return "${src}:$($Matches[2]) :: $message"
    }
    $sig = ($clean -replace '^.*?Warning Message:\s*','warning: ' -replace '\s+',' ').Trim()
    if ($sig.Length -gt 140) { $sig = $sig.Substring(0,140) }
    return $sig
}
function New-Payload([string]$Title, [string]$Content) {
    return @{ content=$Content; embed=@{ title=$Title; description=$Content } }
}
function Send-Peach([string]$Title, [string]$Content) {
    $payloadPath = Join-Path $OutputDirectory ("payload-{0}.json" -f ([guid]::NewGuid().ToString('N')))
    (New-Payload $Title $Content) | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $payloadPath -Encoding UTF8
    try {
        if ($NoSend) { Write-Output ("DRY-RUN SEND: {0}`n{1}" -f $Title,$Content); return }
        if (-not $PeachSenderPath) { throw 'PeachSenderPath is required for a real send; use -NoSend for dry-runs' }
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $PeachSenderPath -PayloadPath $payloadPath
        if ($LASTEXITCODE -ne 0) { throw "send-peach-dm exited $LASTEXITCODE" }
    } finally { Remove-Item -LiteralPath $payloadPath -Force -ErrorAction SilentlyContinue }
}
function Format-Current([hashtable]$F) {
    $fps=Get-Fact $F 'scale_fps'; if ($null -eq $fps -or $fps -eq '') { $fps=Get-Fact $F 'snap_FPS' '?' }
    $ai=Get-Fact $F 'scale_AI_TOT'; if ($null -eq $ai -or $ai -eq '') { $ai=Get-Fact $F 'snap_AI' '?' }
    $units=Get-Fact $F 'snap_UNITS' '?'
    $total=Get-Fact $F 'roster_total' '?'; $hc=Get-Fact $F 'roster_hc' '?'; $hum=Get-Fact $F 'roster_humans' '?'
    $tw=Get-Fact $F 'scale_townsW' '?'; $te=Get-Fact $F 'scale_townsE' '?'; $tg=Get-Fact $F 'scale_townsG' '?'
    return "FPS $fps | AI $ai units $units | players $hum human + $hc HC = $total | towns W/E/G $tw/$te/$tg"
}
function Get-TopErrors([hashtable]$Delta) {
    if ($Delta.Count -eq 0) { return 'none' }
    return (($Delta.GetEnumerator() | Sort-Object {[int]$_.Value} -Descending | Select-Object -First 3 | ForEach-Object { "[$($_.Value)x] $($_.Key)" }) -join '; ')
}
function Invoke-Tick($State, [bool]$IsStart) {
    $result = Parse-Collector (Invoke-Collector $State)
    $facts = $result.facts; $new = $result.new
    $errors = Get-ErrorMap $State; $delta=@{}; $events=New-Object System.Collections.Generic.List[string]
    foreach ($record in $new) {
        if ($record.kind -eq 'error') {
            $sig=Get-Signature $record.line
            if ($sig) {
                if (-not $delta.ContainsKey($sig)){$delta[$sig]=0};$delta[$sig]++
                if (-not $errors.ContainsKey($sig)){$errors[$sig]=0};$errors[$sig]=[int]$errors[$sig]+1
            }
        } elseif ($record.kind -eq 'event') { $events.Add(('{0}: {1}' -f $record.tag,$record.line.Trim())) }
    }
    $fps=To-Int (Get-Fact $facts 'scale_fps' (Get-Fact $facts 'snap_FPS' -1)); $hum=To-Int (Get-Fact $facts 'roster_humans' -1); $total=To-Int (Get-Fact $facts 'roster_total' -1)
    $nowUtc=[DateTime]::UtcNow.ToString('o'); $sample=[pscustomobject]@{atUtc=$nowUtc;fps=$fps;players=$hum;totalClients=$total;ai=(To-Int (Get-Fact $facts 'scale_AI_TOT' (Get-Fact $facts 'snap_AI' -1)));units=(To-Int (Get-Fact $facts 'snap_UNITS' -1));townsW=(To-Int (Get-Fact $facts 'scale_townsW' -1));townsE=(To-Int (Get-Fact $facts 'scale_townsE' -1));townsG=(To-Int (Get-Fact $facts 'scale_townsG' -1))}
    $samples=@($State.samples)+@($sample); if($samples.Count -gt 10000){$samples=$samples[($samples.Count-10000)..($samples.Count-1)]}
    $allEvents=@($State.events)+@($events); if($allEvents.Count -gt 100){$allEvents=$allEvents[($allEvents.Count-100)..($allEvents.Count-1)]}
    $State.marks.srv=To-Long (Get-Fact $facts 'srvMark' $State.marks.srv) $State.marks.srv; $State.marks.hc1=To-Long (Get-Fact $facts 'hc1Mark' $State.marks.hc1) $State.marks.hc1; $State.marks.hc2=To-Long (Get-Fact $facts 'hc2Mark' $State.marks.hc2) $State.marks.hc2
    $State.errorCounts=Set-ErrorCounts $errors; $State.samples=$samples; $State.events=$allEvents; $State.peakPlayers=[Math]::Max([int]$State.peakPlayers,$hum); $State.lastFacts=$facts; $State.lastTickUtc=$nowUtc
    $alertParts=New-Object System.Collections.Generic.List[string]; $lastHum=To-Int $State.lastHumanPlayers -1
    if (-not $IsStart -and $fps -ge 0 -and $fps -lt $FpsFloor -and -not [bool]$State.conditions.fpsLow) { $alertParts.Add("FPS floor breach: $fps < $FpsFloor") ; $State.conditions.fpsLow=$true }
    if ($fps -ge $FpsFloor) { $State.conditions.fpsLow=$false }
    if ($delta.Count -ge $ErrorSpikeThreshold) { $alertParts.Add("script-error spike: $($delta.Count) new signatures") }
    if ($events.Count -gt 0) { $alertParts.Add((($events | Select-Object -First 2) -join ' | ')) }
    if (-not $IsStart -and $lastHum -gt 0 -and $hum -eq 0) { $alertParts.Add('human player count dropped to 0 mid-test') }
    $State.lastHumanPlayers=$hum
    $digest="PLAYTEST DIGEST [$($facts['boxNowUtc']) UTC]`n$(Format-Current $facts)`nNew errors: $(Get-TopErrors $delta)"
    $alertDue=$true
    if ($State.lastAlertUtc) { $alertDue=(([DateTime]::UtcNow-[DateTime]::Parse($State.lastAlertUtc).ToUniversalTime()).TotalMinutes -ge $AlertCooldownMinutes) }
    if ($alertParts.Count -gt 0 -and $alertDue) { Send-Peach 'WASP playtest ALERT' (("ALERT`n" + ($alertParts -join "`n") + "`n`n" + $digest)); $State.lastAlertUtc=$nowUtc } else { Send-Peach 'WASP playtest digest' $digest }
    Save-State $State
}
function New-State {
    return [pscustomobject]@{version=$script:Version;active=$true;startedAtUtc=[DateTime]::UtcNow.ToString('o');lastTickUtc='';lastAlertUtc='';lastHumanPlayers=-1;peakPlayers=0;marks=[pscustomobject]@{srv=-1;hc1=-1;hc2=-1};conditions=[pscustomobject]@{fpsLow=$false};errorCounts=[pscustomobject]@{};samples=@();events=@();lastFacts=@{}}
}

if ($Action -eq 'Start') {
    $state=New-State; Save-State $state; Invoke-Tick $state $true; exit 0
}
$state=Read-State; if ($null -eq $state -or -not $state.active) { throw 'No active playtest state. Run with -Action Start first.' }
if ($Action -eq 'Tick') { Invoke-Tick $state $false; exit 0 }
if ($Action -eq 'Stop') {
    $state.active=$false; $start=[DateTime]::Parse($state.startedAtUtc).ToUniversalTime(); $end=[DateTime]::UtcNow; $duration=($end-$start).TotalMinutes
    $valid=@($state.samples | Where-Object {$_.fps -ge 0}); $min='n/a';$avg='n/a';if($valid.Count){$min=($valid|Measure-Object fps -Minimum).Minimum;$avg=[Math]::Round(($valid|Measure-Object fps -Average).Average,1)}
    $errorMap=Get-ErrorMap $state; $ranked=$errorMap.GetEnumerator()|Sort-Object {[int]$_.Value} -Descending|Select-Object -First 10|ForEach-Object {"[$($_.Value)x] $($_.Key)"}; if(-not $ranked){$ranked='none'}
    $notable=if(@($state.events).Count){(@($state.events)|Select-Object -Last 5)-join '; '}else{'none'}
    $summary="PLAYTEST SUMMARY`nDuration $([Math]::Round($duration,1)) min | peak humans $($state.peakPlayers) | FPS min/avg $min/$avg`nUnique error signatures $($errorMap.Count)`nTop errors: $($ranked -join '; ')`nNotable events: $notable"
    $summaryPath=Join-Path $OutputDirectory 'playtest-summary.md'; "# Wasp playtest summary`n`n$summary`n`nStarted UTC: $($state.startedAtUtc)`nEnded UTC: $($end.ToString('o'))"|Set-Content -LiteralPath $summaryPath -Encoding UTF8
    Send-Peach 'WASP playtest summary' $summary; Save-State $state; Write-Output "SUMMARY=$summaryPath"; exit 0
}
