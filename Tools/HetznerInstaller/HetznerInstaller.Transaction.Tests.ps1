#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('Checkpoints','Recovery','Integrity','Fence','SourceSnapshot','AtomicPromotion','Lock','Wrapper','All')][string]$Group = 'All')

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

foreach ($requiredCommand in @('Get-HetznerTransactionStatus','Invoke-HetznerRecoverPlan')) {
    Assert ($null -ne (Get-Command -Name $requiredCommand -ErrorAction SilentlyContinue)) "T14 API exists: $requiredCommand"
}
if ($script:fails -gt 0) {
    Write-Host "$($script:fails) T14 TRANSACTION TEST(S) FAILED" -ForegroundColor Red
    exit 1
}

function New-TransactionFixture {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ('hetzner-transaction-' + [guid]::NewGuid().ToString('N'))
    $source = Join-Path $root 'source'; $fence = Join-Path $root 'staging'; $install = Join-Path $fence 'install'
    New-Item -ItemType Directory -Path (Join-Path $source 'server-config') -Force | Out-Null
    New-Item -ItemType Directory -Path $fence -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $source 'server-config\basic.cfg'), 'MaxSizeGuaranteed = 512;')
    [System.IO.File]::WriteAllText((Join-Path $source 'server-config\server-pr8.cfg'), 'passwordAdmin = "__REDACTED_SET_ON_HOST__";')
    $pbo = Join-Path $source 'candidate.chernarus.pbo'
    [System.IO.File]::WriteAllBytes($pbo, [byte[]](0x50,0x42,0x4f,0x01,0x02,0x03,0x04))
    [pscustomobject]@{ Root=$root; Source=$source; Fence=$fence; Install=$install; Pbo=$pbo }
}

function Remove-TransactionFixture($Fixture) {
    if ($Fixture -and (Test-Path -LiteralPath $Fixture.Root)) { Remove-Item -LiteralPath $Fixture.Root -Recurse -Force }
}

function Assert-InstallAbsent($Fixture, [string]$Name) {
    Assert (-not (Test-Path -LiteralPath $Fixture.Install)) $Name
}

function Get-InstallTreeFingerprint([string]$Root) {
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return '<absent>' }
    $records = @(Get-ChildItem -LiteralPath $Root -File -Recurse | Sort-Object FullName | ForEach-Object {
        [pscustomobject][ordered]@{
            RelativePath = $_.FullName.Substring($Root.Length).TrimStart('\')
            Sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            Bytes = [int64]$_.Length
        }
    })
    $json = ConvertTo-Json -InputObject @($records) -Depth 8 -Compress
    $bytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes($json)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return -join ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) }
    finally { $sha.Dispose() }
}

function Invoke-CheckpointTests {
    Write-Host 'TEST T14a: every Apply checkpoint recovers to exact absent pre-state or committed post-state'
    $named = @('AfterPrepared','AfterManagedOperations','AfterManifest','AfterReceipt','AfterSeal','BeforeCommit','AfterCommit')
    foreach ($checkpoint in $named) {
        $f = New-TransactionFixture
        try {
            $plan = New-HetznerPlan -SourceRoot $f.Source -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-1 -MissionPboPath $f.Pbo
            Assert-Throws { Invoke-HetznerPlan -Plan $plan -Apply -FailAfterCheckpoint $checkpoint | Out-Null } "T14a injected $checkpoint" 'injected|failpoint|interruption'
            $status = Get-HetznerTransactionStatus -InstallRoot $f.Install -FenceRoot $f.Fence
            if ($checkpoint -eq 'AfterCommit') {
                Assert ($status.State -eq 'Committed') 'T14a commit marker wins after AfterCommit interruption'
                $recovered = Invoke-HetznerRecoverPlan -InstallRoot $f.Install -FenceRoot $f.Fence
                Assert ($recovered.State -eq 'Committed') 'T14a committed recovery is idempotent'
                Assert (Test-HetznerInstallation -InstallRoot $f.Install -ProfileName hc-1 -MissionPboPath $f.Pbo) 'T14a committed post-state verifies'
            } else {
                Assert ($status.State -notin @('None','Committed','Recovered')) "T14a $checkpoint leaves a recoverable nonterminal journal"
                Invoke-HetznerRecoverPlan -InstallRoot $f.Install -FenceRoot $f.Fence | Out-Null
                Assert-InstallAbsent $f "T14a $checkpoint recovery restores exact absent pre-state"
            }
        } finally { Remove-TransactionFixture $f }
    }

    $probe = New-TransactionFixture
    try {
        $probePlan = New-HetznerPlan -SourceRoot $probe.Source -InstallRoot $probe.Install -FenceRoot $probe.Fence -ProfileName hc-1 -MissionPboPath $probe.Pbo
        $operationCount = @($probePlan.Operations).Count
    } finally { Remove-TransactionFixture $probe }
    for ($index = 0; $index -lt $operationCount; $index++) {
        $f = New-TransactionFixture
        try {
            $plan = New-HetznerPlan -SourceRoot $f.Source -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-1 -MissionPboPath $f.Pbo
            Assert-Throws { Invoke-HetznerPlan -Plan $plan -Apply -FailAfterOperationIndex $index | Out-Null } "T14a injected operation $index" 'injected|failpoint|interruption'
            Invoke-HetznerRecoverPlan -InstallRoot $f.Install -FenceRoot $f.Fence | Out-Null
            Assert-InstallAbsent $f "T14a operation $index recovery restores exact absent pre-state"
        } finally { Remove-TransactionFixture $f }
    }
}

function Invoke-RecoveryTests {
    Write-Host 'TEST T14b: recovery itself is interruption-safe and idempotent'
    $f = New-TransactionFixture
    try {
        $plan = New-HetznerPlan -SourceRoot $f.Source -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-1 -MissionPboPath $f.Pbo
        Assert-Throws { Invoke-HetznerPlan -Plan $plan -Apply -FailAfterCheckpoint AfterReceipt | Out-Null } 'T14b create interrupted transaction' 'injected|failpoint|interruption'
        Assert-Throws { Invoke-HetznerRecoverPlan -InstallRoot $f.Install -FenceRoot $f.Fence -FailAfterOperationIndex 0 | Out-Null } 'T14b interrupt recovery after first restore' 'injected|failpoint|interruption'
        $status = Get-HetznerTransactionStatus -InstallRoot $f.Install -FenceRoot $f.Fence
        Assert ($status.State -eq 'Recovering') 'T14b interrupted recovery remains explicitly recoverable'
        $result = Invoke-HetznerRecoverPlan -InstallRoot $f.Install -FenceRoot $f.Fence
        Assert ($result.State -eq 'Recovered') 'T14b second recovery completes'
        Assert-InstallAbsent $f 'T14b repeated recovery restores exact absent pre-state'
        $again = Invoke-HetznerRecoverPlan -InstallRoot $f.Install -FenceRoot $f.Fence
        Assert ($again.State -eq 'Recovered') 'T14b terminal recovery is idempotent'
    } finally { Remove-TransactionFixture $f }
}

function Invoke-IntegrityTests {
    Write-Host 'TEST T14e: immutable transaction pre-state rejects journal entry tampering before recovery mutation'
    $f = New-TransactionFixture
    try {
        $plan = New-HetznerPlan -SourceRoot $f.Source -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-1 -MissionPboPath $f.Pbo
        Assert-Throws { Invoke-HetznerPlan -Plan $plan -Apply -FailAfterCheckpoint AfterReceipt | Out-Null } 'T14e create interrupted transaction' 'injected|failpoint|interruption'
        $status = Get-HetznerTransactionStatus -InstallRoot $f.Install -FenceRoot $f.Fence
        $before = Get-InstallTreeFingerprint -Root $f.Install
        $journal = Get-Content -LiteralPath $status.JournalPath -Raw | ConvertFrom-Json
        $journal.Entries = @($journal.Entries | Select-Object -Skip 1)
        [System.IO.File]::WriteAllText($status.JournalPath, (($journal | ConvertTo-Json -Depth 16) + "`n"), (New-Object System.Text.UTF8Encoding($false)))
        Assert-Throws { Invoke-HetznerRecoverPlan -InstallRoot $f.Install -FenceRoot $f.Fence | Out-Null } 'T14e removed journal entry is rejected' 'fingerprint|integrity|tamper'
        $after = Get-InstallTreeFingerprint -Root $f.Install
        Assert ($before -eq $after) 'T14e rejected journal performs no install-tree mutation'
    } finally { Remove-TransactionFixture $f }

    $f = New-TransactionFixture
    try {
        $initialPlan = New-HetznerPlan -SourceRoot $f.Source -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-1 -MissionPboPath $f.Pbo
        Invoke-HetznerPlan -Plan $initialPlan -Apply | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $f.Source 'server-config\basic.cfg'), 'MaxSizeGuaranteed = 1024;')
        [System.IO.File]::WriteAllText((Join-Path $f.Source 'server-config\server-pr8.cfg'), 'passwordAdmin = "__REDACTED_ROTATED_ON_HOST__";')
        $updatedPlan = New-HetznerPlan -SourceRoot $f.Source -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-1 -MissionPboPath $f.Pbo
        Assert-Throws { Invoke-HetznerPlan -Plan $updatedPlan -Apply -FailAfterCheckpoint AfterReceipt | Out-Null } 'T14e create interrupted update transaction' 'injected|failpoint|interruption'
        $status = Get-HetznerTransactionStatus -InstallRoot $f.Install -FenceRoot $f.Fence
        $fileEntries = @($status.Journal.Entries | Where-Object { [string]$_.PreKind -eq 'File' })
        Assert ($fileEntries.Count -ge 2) 'T14e update transaction captured multiple file preimages'
        $tamperedEntry = $fileEntries[$fileEntries.Count - 1]
        $tamperedPreimage = Join-Path $status.TransactionRoot ([string]$tamperedEntry.Preimage)
        [System.IO.File]::AppendAllText($tamperedPreimage, 'tampered')
        $before = Get-InstallTreeFingerprint -Root $f.Install
        Assert-Throws { Invoke-HetznerRecoverPlan -InstallRoot $f.Install -FenceRoot $f.Fence | Out-Null } 'T14e corrupted preimage is rejected before recovery' 'preimage|hash|integrity|tamper'
        $after = Get-InstallTreeFingerprint -Root $f.Install
        Assert ($before -eq $after) 'T14e corrupted preimage performs no partial install-tree restoration'
    } finally { Remove-TransactionFixture $f }

    $f = New-TransactionFixture
    try {
        $initialPlan = New-HetznerPlan -SourceRoot $f.Source -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-1 -MissionPboPath $f.Pbo
        Invoke-HetznerPlan -Plan $initialPlan -Apply | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $f.Source 'server-config\basic.cfg'), 'MaxSizeGuaranteed = 2048;')
        [System.IO.File]::WriteAllText((Join-Path $f.Source 'server-config\server-pr8.cfg'), 'passwordAdmin = "__REDACTED_SECOND_ROTATION__";')
        $updatedPlan = New-HetznerPlan -SourceRoot $f.Source -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-1 -MissionPboPath $f.Pbo
        Assert-Throws { Invoke-HetznerPlan -Plan $updatedPlan -Apply -FailAfterCheckpoint AfterReceipt | Out-Null } 'T14e create target-type interrupted update' 'injected|failpoint|interruption'
        $status = Get-HetznerTransactionStatus -InstallRoot $f.Install -FenceRoot $f.Fence
        $fileEntries = @($status.Journal.Entries | Where-Object { [string]$_.PreKind -eq 'File' })
        Assert ($fileEntries.Count -ge 2) 'T14e target-type transaction captured multiple file preimages'
        $laterTarget = [string]$fileEntries[$fileEntries.Count - 1].Path
        Remove-Item -LiteralPath $laterTarget -Force
        New-Item -ItemType Directory -Path $laterTarget | Out-Null
        $before = Get-InstallTreeFingerprint -Root $f.Install
        Assert-Throws { Invoke-HetznerRecoverPlan -InstallRoot $f.Install -FenceRoot $f.Fence | Out-Null } 'T14e later file-to-directory drift is rejected' 'changed from file to directory|target type|preflight'
        $after = Get-InstallTreeFingerprint -Root $f.Install
        Assert ($before -eq $after) 'T14e later target-type failure performs no partial install-tree restoration'
    } finally { Remove-TransactionFixture $f }

    $f = New-TransactionFixture
    try {
        $plan = New-HetznerPlan -SourceRoot $f.Source -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-1 -MissionPboPath $f.Pbo
        Assert-Throws { Invoke-HetznerPlan -Plan $plan -Apply -FailAfterCheckpoint AfterReceipt | Out-Null } 'T14e create unexpected-content interrupted transaction' 'injected|failpoint|interruption'
        [System.IO.File]::WriteAllText((Join-Path $f.Install 'owner-unexpected.txt'), 'preserve-me')
        $before = Get-InstallTreeFingerprint -Root $f.Install
        Assert-Throws { Invoke-HetznerRecoverPlan -InstallRoot $f.Install -FenceRoot $f.Fence | Out-Null } 'T14e unexpected content in absent pre-state is rejected' 'unexpected content|preflight'
        $after = Get-InstallTreeFingerprint -Root $f.Install
        Assert ($before -eq $after) 'T14e unexpected-content failure performs no partial install-tree restoration'
    } finally { Remove-TransactionFixture $f }
}

function Invoke-FenceTests {
    Write-Host 'TEST T14f: install roots cannot occupy the reserved transaction namespace'
    $f = New-TransactionFixture
    try {
        $reservedRoot = Join-Path $f.Fence '.hetzner-installer-transactions'
        $reservedInstall = Join-Path $reservedRoot 'evil-install'
        Assert-Throws { New-HetznerPlan -SourceRoot $f.Source -InstallRoot $reservedInstall -FenceRoot $f.Fence -ProfileName hc-1 -MissionPboPath $f.Pbo | Out-Null } 'T14f planning rejects install below reserved transaction namespace' 'reserved|transaction namespace|overlap'
        Assert (-not (Test-Path -LiteralPath $reservedRoot)) 'T14f rejection creates no reserved transaction directory'
        Assert-Throws { Get-HetznerTransactionStatus -InstallRoot $reservedInstall -FenceRoot $f.Fence | Out-Null } 'T14f status rejects install below reserved transaction namespace' 'reserved|transaction namespace|overlap'
        Assert-Throws { New-HetznerPlan -SourceRoot $f.Source -InstallRoot $reservedRoot -FenceRoot $f.Fence -ProfileName hc-1 -MissionPboPath $f.Pbo | Out-Null } 'T14f planning rejects install equal to reserved transaction namespace' 'reserved|transaction namespace|overlap'
        $caseVariant = Join-Path $f.Fence '.HETZNER-INSTALLER-TRANSACTIONS\case-variant'
        Assert-Throws { New-HetznerPlan -SourceRoot $f.Source -InstallRoot $caseVariant -FenceRoot $f.Fence -ProfileName hc-1 -MissionPboPath $f.Pbo | Out-Null } 'T14f reserved namespace rejection is case-insensitive' 'reserved|transaction namespace|overlap'
    } finally { Remove-TransactionFixture $f }
}

function Invoke-SourceSnapshotTests {
    Write-Host 'TEST T13a: prepared transaction seals immutable source configs and PBO outside the install root'
    $f = New-TransactionFixture
    try {
        $plan = New-HetznerPlan -SourceRoot $f.Source -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-1 -MissionPboPath $f.Pbo
        Assert-Throws { Invoke-HetznerPlan -Plan $plan -Apply -FailAfterCheckpoint AfterPrepared | Out-Null } 'T13a stop after durable source snapshot and prepared journal' 'injected|failpoint|interruption'
        $status = Get-HetznerTransactionStatus -InstallRoot $f.Install -FenceRoot $f.Fence
        $hasSnapshot = $status.Journal.PSObject.Properties.Name -contains 'SourceSnapshot'
        $hasFingerprint = $status.Journal.PSObject.Properties.Name -contains 'SourceSnapshotFingerprint'
        Assert ($hasSnapshot -and $hasFingerprint) 'T13a prepared journal records a sealed source snapshot identity'
        if ($hasSnapshot -and $hasFingerprint) {
            $records = @($status.Journal.SourceSnapshot)
            Assert ($records.Count -eq 3) 'T13a snapshot contains two configs and one mission PBO'
            $allVerified = $true
            foreach ($record in $records) {
                $snapshotPath = [System.IO.Path]::GetFullPath([string]$record.SnapshotPath)
                $transactionRoot = [System.IO.Path]::GetFullPath([string]$status.TransactionRoot).TrimEnd('\') + '\'
                $installRoot = [System.IO.Path]::GetFullPath([string]$f.Install).TrimEnd('\') + '\'
                if (-not $snapshotPath.StartsWith($transactionRoot,[System.StringComparison]::OrdinalIgnoreCase) -or $snapshotPath.StartsWith($installRoot,[System.StringComparison]::OrdinalIgnoreCase)) { $allVerified = $false; continue }
                if (-not (Test-Path -LiteralPath $snapshotPath -PathType Leaf)) { $allVerified = $false; continue }
                if ((Get-FileHash -LiteralPath $snapshotPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$record.Sha256 -or [int64](Get-Item -LiteralPath $snapshotPath).Length -ne [int64]$record.Bytes) { $allVerified = $false }
            }
            Assert $allVerified 'T13a every snapshot artifact is transaction-contained and hash/size verified'
            $snapshotHashesBefore = @($records | ForEach-Object { (Get-FileHash -LiteralPath ([string]$_.SnapshotPath) -Algorithm SHA256).Hash.ToLowerInvariant() })
            [System.IO.File]::WriteAllText((Join-Path $f.Source 'server-config\basic.cfg'), 'MaxSizeGuaranteed = 4096;')
            Remove-Item -LiteralPath (Join-Path $f.Source 'server-config\server-pr8.cfg') -Force
            [System.IO.File]::WriteAllBytes($f.Pbo, [byte[]](0x50,0x42,0x4f,0x44,0x52,0x49,0x46,0x54))
            $snapshotHashesAfter = @($records | ForEach-Object { (Get-FileHash -LiteralPath ([string]$_.SnapshotPath) -Algorithm SHA256).Hash.ToLowerInvariant() })
            Assert (($snapshotHashesBefore -join '|') -ceq ($snapshotHashesAfter -join '|')) 'T13a later source mutation or deletion cannot change sealed snapshot bytes'
            [System.IO.File]::WriteAllText([string]$records[0].SnapshotPath,'corrupted snapshot')
            $module = Get-Module HetznerInstaller
            Assert-Throws { & $module { param($journal,$install,$fence) $paths=Get-HetznerTransactionPaths -InstallRoot $install -FenceRoot $fence; Assert-HetznerSourceSnapshotContract -Journal $journal -Paths $paths -VerifyFiles } $status.Journal $f.Install $f.Fence } 'T13a corrupted snapshot is rejected by the pre-mutation verification gate' 'snapshot.*(hash|byte)|hash or byte'
        }
        Invoke-HetznerRecoverPlan -InstallRoot $f.Install -FenceRoot $f.Fence | Out-Null
        Assert-InstallAbsent $f 'T13a recovery remains independent of corrupted snapshot bytes and restores absent pre-state'
    } finally { Remove-TransactionFixture $f }
}

function Invoke-AtomicPromotionTests {
    Write-Host 'TEST T13b: verified copy interruption cannot expose a torn destination or orphan its temp file'
    $f = New-TransactionFixture
    try {
        $baselinePlan = New-HetznerPlan -SourceRoot $f.Source -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-1 -MissionPboPath $f.Pbo
        Invoke-HetznerPlan -Plan $baselinePlan -Apply | Out-Null
        $target = Join-Path $f.Install 'profiles-pr8\basic.cfg'
        $baselineHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()

        [System.IO.File]::WriteAllText((Join-Path $f.Source 'server-config\basic.cfg'), 'MaxSizeGuaranteed = 4096;')
        $updatePlan = New-HetznerPlan -SourceRoot $f.Source -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-1 -MissionPboPath $f.Pbo
        Assert-Throws { Invoke-HetznerPlan -Plan $updatePlan -Apply -FailAfterCheckpoint BeforeFirstCopyPromotion | Out-Null } 'T13b interrupt after verified temp write but before first destination promotion' 'BeforeFirstCopyPromotion'
        $status = Get-HetznerTransactionStatus -InstallRoot $f.Install -FenceRoot $f.Fence
        Assert ($status.State -eq 'Applying') 'T13b promotion failpoint leaves an explicitly recoverable transaction'
        Assert ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $baselineHash) 'T13b destination remains the complete prior version before atomic promotion'
        $orphans = @(Get-ChildItem -LiteralPath $f.Install -File -Force -Recurse | Where-Object { $_.Name -cmatch '^\.apply-[0-9a-f]{32}\.(tmp|bak)$' })
        Assert ($orphans.Count -eq 0) 'T13b in-process interruption cleans only its exact apply temp artifacts'
        Invoke-HetznerRecoverPlan -InstallRoot $f.Install -FenceRoot $f.Fence | Out-Null
        Assert ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $baselineHash) 'T13b recovery preserves the exact baseline destination'
    } finally { Remove-TransactionFixture $f }

    Write-Host 'TEST T13c: recovery sweeps only exact installer-owned promotion orphans under its lock'
    $f = New-TransactionFixture
    try {
        $plan = New-HetznerPlan -SourceRoot $f.Source -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-1 -MissionPboPath $f.Pbo
        Assert-Throws { Invoke-HetznerPlan -Plan $plan -Apply -FailAfterCheckpoint AfterManifest | Out-Null } 'T13c create interrupted transaction with managed destination parents' 'AfterManifest'
        $orphan = Join-Path $f.Install ('profiles-pr8\.recover-' + [guid]::NewGuid().ToString('N') + '.tmp')
        [System.IO.File]::WriteAllText($orphan,'verified-but-not-promoted')
        $recoveryError = ''
        try { Invoke-HetznerRecoverPlan -InstallRoot $f.Install -FenceRoot $f.Fence | Out-Null }
        catch { $recoveryError = $_.Exception.Message }
        Assert ([string]::IsNullOrEmpty($recoveryError)) 'T13c exact recover-temp orphan is swept before whole-target recovery preflight'
        if ([string]::IsNullOrEmpty($recoveryError)) {
            Assert (-not (Test-Path -LiteralPath $orphan)) 'T13c swept recover-temp orphan is absent after recovery'
            Assert-InstallAbsent $f 'T13c orphan-safe recovery restores exact absent pre-state'
        }
    } finally { Remove-TransactionFixture $f }

    Write-Host 'TEST T13d: lookalike temp files are preserved and fail whole-target recovery closed'
    $f = New-TransactionFixture
    try {
        $plan = New-HetznerPlan -SourceRoot $f.Source -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-1 -MissionPboPath $f.Pbo
        Assert-Throws { Invoke-HetznerPlan -Plan $plan -Apply -FailAfterCheckpoint AfterManifest | Out-Null } 'T13d create interrupted transaction for negative orphan test' 'AfterManifest'
        $lookalike = Join-Path $f.Install 'profiles-pr8\.recover-not-a-guid.tmp'
        [System.IO.File]::WriteAllText($lookalike,'host-owned-lookalike')
        $before = Get-InstallTreeFingerprint $f.Install
        Assert-Throws { Invoke-HetznerRecoverPlan -InstallRoot $f.Install -FenceRoot $f.Fence | Out-Null } 'T13d non-owned lookalike is not swept' 'unexpected content|preflight'
        Assert ((Get-InstallTreeFingerprint $f.Install) -ceq $before) 'T13d refused recovery performs no partial install-tree mutation'
        Assert (Test-Path -LiteralPath $lookalike -PathType Leaf) 'T13d refused recovery preserves the lookalike file'
    } finally { Remove-TransactionFixture $f }
}

function Invoke-LockTests {
    Write-Host 'TEST T14c: one exclusive transaction owns an install at a time'
    $f = New-TransactionFixture
    try {
        $plan = New-HetznerPlan -SourceRoot $f.Source -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-1 -MissionPboPath $f.Pbo
        Assert-Throws { Invoke-HetznerPlan -Plan $plan -Apply -FailAfterCheckpoint AfterPrepared | Out-Null } 'T14c create recoverable transaction' 'injected|failpoint|interruption'
        $status = Get-HetznerTransactionStatus -InstallRoot $f.Install -FenceRoot $f.Fence
        $lock = New-Object System.IO.FileStream($status.LockPath,[System.IO.FileMode]::CreateNew,[System.IO.FileAccess]::ReadWrite,[System.IO.FileShare]::None,1,[System.IO.FileOptions]::DeleteOnClose)
        try { Assert-Throws { Invoke-HetznerRecoverPlan -InstallRoot $f.Install -FenceRoot $f.Fence | Out-Null } 'T14c concurrent owner is refused' 'exclusive|lock|transaction|active' }
        finally { $lock.Dispose() }
        Invoke-HetznerRecoverPlan -InstallRoot $f.Install -FenceRoot $f.Fence | Out-Null
        Assert-InstallAbsent $f 'T14c refused concurrent recovery performs no install mutation'
    } finally { Remove-TransactionFixture $f }
}

function Invoke-WrapperTests {
    Write-Host 'TEST T14d: wrapper exposes status and explicit-Apply recovery'
    $f = New-TransactionFixture
    try {
        $plan = New-HetznerPlan -SourceRoot $f.Source -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-1 -MissionPboPath $f.Pbo
        Assert-Throws { Invoke-HetznerPlan -Plan $plan -Apply -FailAfterCheckpoint AfterReceipt | Out-Null } 'T14d create interrupted transaction' 'injected|failpoint|interruption'
        $wrapper = Join-Path $PSScriptRoot 'Invoke-HetznerInstaller.ps1'
        $status = (& powershell -NoProfile -ExecutionPolicy Bypass -File $wrapper -Action TransactionStatus -InstallRoot $f.Install -FenceRoot $f.Fence -Json | ConvertFrom-Json)
        Assert ($LASTEXITCODE -eq 0 -and $status.State -eq 'Applying') 'T14d wrapper reports nonterminal transaction status'
        $planOnly = (& powershell -NoProfile -ExecutionPolicy Bypass -File $wrapper -Action RecoverPlan -InstallRoot $f.Install -FenceRoot $f.Fence -Json | ConvertFrom-Json)
        Assert ($LASTEXITCODE -eq 0 -and $planOnly.Applied -eq $false -and $planOnly.State -eq 'Applying') 'T14d wrapper recovery is plan-only without Apply'
        Assert (Test-Path -LiteralPath $f.Install) 'T14d plan-only recovery performs zero mutation'
        $recovered = (& powershell -NoProfile -ExecutionPolicy Bypass -File $wrapper -Action RecoverPlan -InstallRoot $f.Install -FenceRoot $f.Fence -Apply -Json | ConvertFrom-Json)
        Assert ($LASTEXITCODE -eq 0 -and $recovered.State -eq 'Recovered') 'T14d wrapper Apply performs recovery'
        Assert-InstallAbsent $f 'T14d wrapper recovery restores exact absent pre-state'
    } finally { Remove-TransactionFixture $f }
}

if ($Group -in @('Checkpoints','All')) { Invoke-CheckpointTests }
if ($Group -in @('Recovery','All')) { Invoke-RecoveryTests }
if ($Group -in @('Integrity','All')) { Invoke-IntegrityTests }
if ($Group -in @('Fence','All')) { Invoke-FenceTests }
if ($Group -in @('SourceSnapshot','All')) { Invoke-SourceSnapshotTests }
if ($Group -in @('AtomicPromotion','All')) { Invoke-AtomicPromotionTests }
if ($Group -in @('Lock','All')) { Invoke-LockTests }
if ($Group -in @('Wrapper','All')) { Invoke-WrapperTests }

if ($script:fails -eq 0) { Write-Host 'T14 TRANSACTION TESTS PASSED' -ForegroundColor Green; exit 0 }
Write-Host "$($script:fails) T14 TRANSACTION TEST(S) FAILED" -ForegroundColor Red
exit 1
