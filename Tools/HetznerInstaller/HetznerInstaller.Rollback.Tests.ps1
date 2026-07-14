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

function New-RollbackFixture {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ('hetzner-rollback-' + [guid]::NewGuid().ToString('N'))
    $source = Join-Path $root 'source'; $fence = Join-Path $root 'staging'; $install = Join-Path $fence 'nested\install'
    New-Item -ItemType Directory -Path (Join-Path $source 'server-config') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $install 'profiles-pr8') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $source 'server-config\basic.cfg'),'MaxSizeGuaranteed = 512;')
    [System.IO.File]::WriteAllText((Join-Path $source 'server-config\server-pr8.cfg'),'passwordAdmin = "__REDACTED_SET_ON_HOST__";')
    $pbo = Join-Path $source 'candidate.chernarus.pbo'
    [System.IO.File]::WriteAllBytes($pbo,[byte[]](0x50,0x42,0x4f,0x01,0x02,0x03,0x04))
    [System.IO.File]::WriteAllText((Join-Path $install 'profiles-pr8\basic.cfg'),'host-specific-basic')
    [System.IO.File]::Copy((Join-Path $source 'server-config\server-pr8.cfg'),(Join-Path $install 'profiles-pr8\server-pr8.cfg'))
    [System.IO.File]::WriteAllText((Join-Path $install 'hc1_launch.cmd'),'host-owned-stale-launcher')
    [System.IO.File]::WriteAllText((Join-Path $install 'host-note.txt'),'must-survive')
    $policy = @(
        [pscustomobject][ordered]@{Path='profiles-pr8\basic.cfg';Disposition='ReplaceWithBackup'},
        [pscustomobject][ordered]@{Path='profiles-pr8\server-pr8.cfg';Disposition='AdoptUnchanged'},
        [pscustomobject][ordered]@{Path='hc1_launch.cmd';Disposition='PreserveHost'}
    )
    $plan = New-HetznerPlan -SourceRoot $source -InstallRoot $install -FenceRoot $fence -ProfileName hc-0 -MissionPboPath $pbo -AdoptionPolicy $policy
    $apply = Invoke-HetznerPlan -Plan $plan -Apply
    [pscustomobject]@{Root=$root;Source=$source;Fence=$fence;Install=$install;Pbo=$pbo;Plan=$plan;Apply=$apply}
}

function Remove-RollbackFixture($Fixture) {
    if ($Fixture -and (Test-Path -LiteralPath $Fixture.Root)) { Remove-Item -LiteralPath $Fixture.Root -Recurse -Force }
}

Write-Host 'TEST T11a: sealed transaction rollback restores pre-state and preserves host-owned files'
$f = New-RollbackFixture
try {
    $target = Join-Path $f.Install 'profiles-pr8\basic.cfg'
    $adopted = Join-Path $f.Install 'profiles-pr8\server-pr8.cfg'
    $stale = Join-Path $f.Install 'hc1_launch.cmd'
    $adoptedWrite = (Get-Item -LiteralPath $adopted).LastWriteTimeUtc
    $staleWrite = (Get-Item -LiteralPath $stale).LastWriteTimeUtc
    $postHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
    Assert (Test-HetznerInstallation -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-0 -MissionPboPath $f.Pbo) 'T11a nested install verifies with its explicit transaction fence'
    $rollback = New-HetznerRollbackPlan -InstallRoot $f.Install -FenceRoot $f.Fence
    Assert ($rollback.ApplySupported -and [string]$rollback.RollbackMode -ceq 'SealedTransaction') 'T11a committed journal produces an executable sealed rollback plan'
    $wrapper = Join-Path $PSScriptRoot 'Invoke-HetznerInstaller.ps1'
    $wrapperPlan = (& powershell -NoProfile -ExecutionPolicy Bypass -File $wrapper -Action RollbackPlan -InstallRoot $f.Install -FenceRoot $f.Fence -Json | ConvertFrom-Json)
    Assert ($LASTEXITCODE -eq 0 -and $wrapperPlan.ApplySupported -and [string]$wrapperPlan.RollbackMode -ceq 'SealedTransaction') 'T11a wrapper selects sealed rollback without a legacy BackupRoot'
    $preview = Invoke-HetznerRollbackPlan -Plan $rollback
    Assert (-not $preview.Applied -and (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $postHash) 'T11a plan-only rollback performs zero mutation'
    $result = Invoke-HetznerRollbackPlan -Plan $rollback -Apply
    Assert ($result.Applied -and [string]$result.State -ceq 'RolledBack') 'T11a rollback Apply reaches RolledBack'
    Assert ([System.IO.File]::ReadAllText($target) -ceq 'host-specific-basic') 'T11a replaced config is restored from its sealed backup'
    Assert ([System.IO.File]::ReadAllText($adopted) -ceq 'passwordAdmin = "__REDACTED_SET_ON_HOST__";' -and (Get-Item -LiteralPath $adopted).LastWriteTimeUtc -eq $adoptedWrite) 'T11a AdoptUnchanged file is preserved without rewrite'
    Assert ([System.IO.File]::ReadAllText($stale) -ceq 'host-owned-stale-launcher' -and (Get-Item -LiteralPath $stale).LastWriteTimeUtc -eq $staleWrite) 'T11a PreserveHost stale launcher is preserved without rewrite'
    Assert ([System.IO.File]::ReadAllText((Join-Path $f.Install 'host-note.txt')) -ceq 'must-survive') 'T11a unrelated host file survives rollback'
    Assert (-not (Test-Path -LiteralPath (Join-Path $f.Install 'mpmissions')) -and -not (Test-Path -LiteralPath (Join-Path $f.Install '.hetzner-installer'))) 'T11a installer-created files, metadata, and directories return to absent pre-state'
    Assert ((Test-Path -LiteralPath $f.Install -PathType Container) -and (Test-Path -LiteralPath (Join-Path $f.Install 'profiles-pr8') -PathType Container)) 'T11a pre-existing install and profile directories remain'
    $again = Invoke-HetznerRollbackPlan -Plan (New-HetznerRollbackPlan -InstallRoot $f.Install -FenceRoot $f.Fence) -Apply
    Assert ($again.Applied -and [string]$again.State -ceq 'RolledBack') 'T11a completed rollback is idempotent'
    $reapply = Invoke-HetznerPlan -Plan $f.Plan -Apply
    Assert ($reapply.Applied -and [string]$reapply.TransactionState -ceq 'Committed' -and (Test-HetznerInstallation -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-0 -MissionPboPath $f.Pbo)) 'T11a same sealed plan can reapply after RolledBack'
    $secondRollback = Invoke-HetznerRollbackPlan -Plan (New-HetznerRollbackPlan -InstallRoot $f.Install -FenceRoot $f.Fence) -Apply
    Assert ($secondRollback.Applied -and [System.IO.File]::ReadAllText($target) -ceq 'host-specific-basic' -and [System.IO.File]::ReadAllText((Join-Path $f.Install 'host-note.txt')) -ceq 'must-survive') 'T11a repeated Apply/rollback cycle returns to the same host pre-state'
} finally { Remove-RollbackFixture $f }

Write-Host 'TEST T11b: corrupt replacement backup and installed postimage drift fail before mutation'
$f = New-RollbackFixture
try {
    $rollback = New-HetznerRollbackPlan -InstallRoot $f.Install -FenceRoot $f.Fence
    $decision = @($f.Apply.OwnershipDecisions | Where-Object { [string]$_.Disposition -ceq 'ReplaceWithBackup' })[0]
    [System.IO.File]::WriteAllText([string]$decision.BackupPath,'corrupt-backup')
    $pboPath = Join-Path $f.Install 'mpmissions\candidate.chernarus.pbo'
    Assert-Throws { Invoke-HetznerRollbackPlan -Plan $rollback -Apply | Out-Null } 'T11b corrupt host backup is rejected' 'backup|preimage|hash|bytes|corrupt'
    Assert ((Test-Path -LiteralPath $pboPath -PathType Leaf) -and (Test-Path -LiteralPath (Join-Path $f.Install '.hetzner-installer\manifest.json') -PathType Leaf)) 'T11b corrupt-backup refusal performs zero partial rollback'
} finally { Remove-RollbackFixture $f }

$f = New-RollbackFixture
try {
    $rollback = New-HetznerRollbackPlan -InstallRoot $f.Install -FenceRoot $f.Fence
    $target = Join-Path $f.Install 'profiles-pr8\basic.cfg'
    [System.IO.File]::WriteAllText($target,'post-install-host-drift')
    Assert-Throws { Invoke-HetznerRollbackPlan -Plan $rollback -Apply | Out-Null } 'T11b current postimage drift is rejected before restore' 'postimage|drift|hash|bytes'
    Assert ([System.IO.File]::ReadAllText($target) -ceq 'post-install-host-drift' -and (Test-Path -LiteralPath (Join-Path $f.Install 'mpmissions\candidate.chernarus.pbo'))) 'T11b drift refusal preserves every current path'
} finally { Remove-RollbackFixture $f }

Write-Host 'TEST T11c: interrupted rollback resumes deterministically from the sealed journal'
$f = New-RollbackFixture
try {
    $rollback = New-HetznerRollbackPlan -InstallRoot $f.Install -FenceRoot $f.Fence
    Assert-Throws { Invoke-HetznerRollbackPlan -Plan $rollback -Apply -FailAfterOperationIndex 0 | Out-Null } 'T11c injected rollback interruption is observable' 'interruption|rollback operation'
    $status = Get-HetznerTransactionStatus -InstallRoot $f.Install -FenceRoot $f.Fence
    Assert ([string]$status.State -ceq 'RollingBack' -and [int]$status.OperationIndex -eq 0) 'T11c interrupted state and operation index are durable'
    Assert-Throws { Invoke-HetznerRecoverPlan -InstallRoot $f.Install -FenceRoot $f.Fence | Out-Null } 'T11c Apply recovery cannot take over a rolling-back journal' 'rollback|RollbackPlan|state'
    $resumedPlan = New-HetznerRollbackPlan -InstallRoot $f.Install -FenceRoot $f.Fence
    $result = Invoke-HetznerRollbackPlan -Plan $resumedPlan -Apply
    Assert ($result.Applied -and [string]$result.State -ceq 'RolledBack' -and [System.IO.File]::ReadAllText((Join-Path $f.Install 'profiles-pr8\basic.cfg')) -ceq 'host-specific-basic') 'T11c resumed rollback completes the exact pre-state'
} finally { Remove-RollbackFixture $f }

Write-Host 'TEST T11c4: mixed-state resume rejects later postimage drift before another action'
$f = New-RollbackFixture
try {
    $rollback = New-HetznerRollbackPlan -InstallRoot $f.Install -FenceRoot $f.Fence
    $restore = @($rollback.Contract.Actions | Where-Object { [string]$_.Mode -ceq 'RestoreFile' } | Sort-Object ActionIndex)[0]
    $later = @($rollback.Contract.Actions | Where-Object { [int]$_.ActionIndex -gt [int]$restore.ActionIndex -and [string]$_.Mode -ceq 'DeleteFile' } | Sort-Object ActionIndex)[0]
    Assert-Throws { Invoke-HetznerRollbackPlan -Plan $rollback -Apply -FailAfterOperationIndex ([int]$restore.ActionIndex) | Out-Null } 'T11c4 stop after one real restore action' 'interruption|rollback operation'
    [System.IO.File]::WriteAllText([string]$later.Path,'later-postimage-drift')
    $resumedPlan = New-HetznerRollbackPlan -InstallRoot $f.Install -FenceRoot $f.Fence
    Assert-Throws { Invoke-HetznerRollbackPlan -Plan $resumedPlan -Apply | Out-Null } 'T11c4 resume rejects drift in a remaining postimage' 'postimage|drift|hash|bytes'
    Assert ([System.IO.File]::ReadAllText((Join-Path $f.Install 'profiles-pr8\basic.cfg')) -ceq 'host-specific-basic') 'T11c4 completed restore remains exact after refused resume'
    Assert ([System.IO.File]::ReadAllText([string]$later.Path) -ceq 'later-postimage-drift' -and (Test-Path -LiteralPath (Join-Path $f.Install '.hetzner-installer\manifest.json'))) 'T11c4 refused resume preserves drift and performs no later action'
} finally { Remove-RollbackFixture $f }

Write-Host 'TEST T11c5: forged terminal rollback state cannot report success over a mixed install'
$f = New-RollbackFixture
try {
    $rollback = New-HetznerRollbackPlan -InstallRoot $f.Install -FenceRoot $f.Fence
    $restore = @($rollback.Contract.Actions | Where-Object { [string]$_.Mode -ceq 'RestoreFile' } | Sort-Object ActionIndex)[0]
    $remaining = @($rollback.Contract.Actions | Where-Object { [int]$_.ActionIndex -gt [int]$restore.ActionIndex -and [string]$_.Mode -ceq 'DeleteFile' } | Sort-Object ActionIndex)[0]
    Assert-Throws { Invoke-HetznerRollbackPlan -Plan $rollback -Apply -FailAfterOperationIndex ([int]$restore.ActionIndex) | Out-Null } 'T11c5 stop after one real rollback action' 'interruption|rollback operation'
    $status = Get-HetznerTransactionStatus -InstallRoot $f.Install -FenceRoot $f.Fence
    $journal = Get-Content -LiteralPath $status.JournalPath -Raw | ConvertFrom-Json
    $journal.State = 'RolledBack'
    $journal.Phase = 'RolledBack'
    $journal.OperationIndex = @($journal.RollbackContract.Actions).Count - 1
    [System.IO.File]::WriteAllText($status.JournalPath,($journal | ConvertTo-Json -Depth 24),(New-Object System.Text.UTF8Encoding($false)))
    $forgedPlan = New-HetznerRollbackPlan -InstallRoot $f.Install -FenceRoot $f.Fence
    Assert-Throws { Invoke-HetznerRollbackPlan -Plan $forgedPlan -Apply | Out-Null } 'T11c5 forged RolledBack marker is rejected against mixed path state' 'preimage|drift|state|index|rollback'
    Assert ([System.IO.File]::ReadAllText((Join-Path $f.Install 'profiles-pr8\basic.cfg')) -ceq 'host-specific-basic') 'T11c5 completed restore remains exact after forged-state refusal'
    Assert ((Test-Path -LiteralPath ([string]$remaining.Path) -PathType Leaf) -and (Get-FileHash -LiteralPath ([string]$remaining.Path) -Algorithm SHA256).Hash.ToLowerInvariant() -ceq [string]$remaining.PostSha256) 'T11c5 forged-state refusal does not perform a later action'
} finally { Remove-RollbackFixture $f }

Write-Host 'TEST T11c6: normal Apply cannot replace a forged terminal rollback journal'
$f = New-RollbackFixture
try {
    $rollback = New-HetznerRollbackPlan -InstallRoot $f.Install -FenceRoot $f.Fence
    $metadataDirectory = @($rollback.Contract.Actions | Where-Object { [string]$_.Mode -ceq 'DeleteDirectory' -and [string]$_.Label -ceq '.hetzner-installer' })[0]
    $remainingDirectory = @($rollback.Contract.Actions | Where-Object { [string]$_.Mode -ceq 'DeleteDirectory' -and [string]$_.Label -ceq 'mpmissions' })[0]
    Assert-Throws { Invoke-HetznerRollbackPlan -Plan $rollback -Apply -FailAfterOperationIndex ([int]$metadataDirectory.ActionIndex) | Out-Null } 'T11c6 stop after metadata removal but before final directory cleanup' 'interruption|rollback operation'
    Assert ((Test-Path -LiteralPath ([string]$remainingDirectory.Path) -PathType Container) -and @(Get-ChildItem -LiteralPath ([string]$remainingDirectory.Path) -Force).Count -eq 0) 'T11c6 interrupted rollback leaves the known empty installer-created directory'
    $status = Get-HetznerTransactionStatus -InstallRoot $f.Install -FenceRoot $f.Fence
    $originalTransactionId = [string]$status.TransactionId
    $journal = Get-Content -LiteralPath $status.JournalPath -Raw | ConvertFrom-Json
    $journal.State = 'RolledBack'
    $journal.Phase = 'RolledBack'
    $journal.OperationIndex = @($journal.RollbackContract.Actions).Count - 1
    [System.IO.File]::WriteAllText($status.JournalPath,($journal | ConvertTo-Json -Depth 24),(New-Object System.Text.UTF8Encoding($false)))
    Assert-Throws { Invoke-HetznerPlan -Plan $f.Plan -Apply | Out-Null } 'T11c6 Apply rejects a forged terminal journal before starting a replacement transaction' 'preimage|drift|terminal|rolled.?back|rollback'
    $after = Get-HetznerTransactionStatus -InstallRoot $f.Install -FenceRoot $f.Fence
    Assert ([string]$after.TransactionId -ceq $originalTransactionId -and [System.IO.File]::ReadAllText((Join-Path $f.Install 'profiles-pr8\basic.cfg')) -ceq 'host-specific-basic') 'T11c6 rejected Apply preserves the rollback journal and restored host config'
    Assert ((Test-Path -LiteralPath ([string]$remainingDirectory.Path) -PathType Container) -and @(Get-ChildItem -LiteralPath ([string]$remainingDirectory.Path) -Force).Count -eq 0) 'T11c6 rejected Apply does not adopt or refill the unfinished directory'
} finally { Remove-RollbackFixture $f }

Write-Host 'TEST T11c2: every sealed rollback action checkpoint resumes to the same pre-state'
$probe = New-RollbackFixture
try { $actionCount = @((New-HetznerRollbackPlan -InstallRoot $probe.Install -FenceRoot $probe.Fence).Contract.Actions).Count }
finally { Remove-RollbackFixture $probe }
$allResumed = $true
for ($failIndex=0; $failIndex -lt $actionCount; $failIndex++) {
    $f = New-RollbackFixture
    try {
        $rollback = New-HetznerRollbackPlan -InstallRoot $f.Install -FenceRoot $f.Fence
        $threw = $false
        try { Invoke-HetznerRollbackPlan -Plan $rollback -Apply -FailAfterOperationIndex $failIndex | Out-Null } catch { $threw = $_.Exception.Message -match 'rollback operation' }
        if (-not $threw) { $allResumed=$false; continue }
        $resumed = Invoke-HetznerRollbackPlan -Plan (New-HetznerRollbackPlan -InstallRoot $f.Install -FenceRoot $f.Fence) -Apply
        if (-not $resumed.Applied -or [string]$resumed.State -cne 'RolledBack' -or [System.IO.File]::ReadAllText((Join-Path $f.Install 'profiles-pr8\basic.cfg')) -cne 'host-specific-basic' -or [System.IO.File]::ReadAllText((Join-Path $f.Install 'host-note.txt')) -cne 'must-survive') { $allResumed=$false }
    } finally { Remove-RollbackFixture $f }
}
Assert ($actionCount -gt 0 -and $allResumed) "T11c2 all $actionCount action checkpoints resume deterministically"

Write-Host 'TEST T11c3: rollback plan tampering fails before mutation'
$f = New-RollbackFixture
try {
    $rollback = New-HetznerRollbackPlan -InstallRoot $f.Install -FenceRoot $f.Fence
    $rollback.Contract.Actions[0].Path = Join-Path $f.Fence 'escaped.txt'
    Assert-Throws { Invoke-HetznerRollbackPlan -Plan $rollback -Apply | Out-Null } 'T11c3 tampered action is rejected' 'fingerprint|tamper|contract|escaped'
    Assert (Test-Path -LiteralPath (Join-Path $f.Install '.hetzner-installer\manifest.json')) 'T11c3 plan-tamper refusal preserves committed install'
} finally { Remove-RollbackFixture $f }

Write-Host 'TEST T11d: unexpected host content in an installer-created directory stops before rollback mutation'
$f = New-RollbackFixture
try {
    $rollback = New-HetznerRollbackPlan -InstallRoot $f.Install -FenceRoot $f.Fence
    [System.IO.File]::WriteAllText((Join-Path $f.Install 'mpmissions\host-added.txt'),'preserve-me')
    Assert-Throws { Invoke-HetznerRollbackPlan -Plan $rollback -Apply | Out-Null } 'T11d unexpected content blocks directory removal' 'unexpected|host|content|preflight'
    Assert ([System.IO.File]::ReadAllText((Join-Path $f.Install 'mpmissions\host-added.txt')) -ceq 'preserve-me' -and (Test-Path -LiteralPath (Join-Path $f.Install '.hetzner-installer\manifest.json'))) 'T11d refusal preserves host addition and metadata'
} finally { Remove-RollbackFixture $f }

Write-Host 'TEST T11e: committed journal anchors final metadata bytes against a consistent rewrite'
$f = New-RollbackFixture
try {
    $meta = Join-Path $f.Install '.hetzner-installer'
    $manifestPath = Join-Path $meta 'manifest.json'; $receiptPath = Join-Path $meta 'receipt.json'; $sealPath = Join-Path $meta 'ownership-seal.json'
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
    [System.IO.File]::WriteAllText($manifestPath,($manifest | ConvertTo-Json -Depth 16 -Compress),(New-Object System.Text.UTF8Encoding($false)))
    [System.IO.File]::WriteAllText($receiptPath,($receipt | ConvertTo-Json -Depth 16 -Compress),(New-Object System.Text.UTF8Encoding($false)))
    $seal = [pscustomobject][ordered]@{
        SchemaVersion=2; SealType='manifest-receipt-external-anchor-v1'
        ManifestSha256=(Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant(); ManifestBytes=[int64](Get-Item -LiteralPath $manifestPath).Length
        ReceiptSha256=(Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash.ToLowerInvariant(); ReceiptBytes=[int64](Get-Item -LiteralPath $receiptPath).Length
    }
    [System.IO.File]::WriteAllText($sealPath,($seal | ConvertTo-Json -Depth 8 -Compress),(New-Object System.Text.UTF8Encoding($false)))
    Assert-Throws { New-HetznerRollbackPlan -InstallRoot $f.Install -FenceRoot $f.Fence | Out-Null } 'T11e semantic-equivalent metadata rewrite is rejected by committed journal anchor' 'commit|journal|anchor|metadata|hash|bytes'
    Assert (Test-Path -LiteralPath (Join-Path $f.Install 'mpmissions\candidate.chernarus.pbo')) 'T11e metadata-anchor refusal performs zero install rollback'
} finally { Remove-RollbackFixture $f }

if ($script:fails -eq 0) { Write-Host 'T11 ROLLBACK TESTS PASSED' -ForegroundColor Green; exit 0 }
Write-Host "$($script:fails) T11 ROLLBACK TEST(S) FAILED" -ForegroundColor Red
exit 1
