#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('T11a','T11b','T11c','All')][string]$Group = 'All')

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
        $message = $_.Exception.Message
        if ($message -match $Pattern) { Write-Host "  PASS  $Name" }
        else { $script:fails++; Write-Host "  FAIL  $Name (unexpected: $message)" -ForegroundColor Red }
    }
}

function New-Review3Fixture {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ('hetzner-review3-' + [guid]::NewGuid().ToString('N'))
    $source = Join-Path $root 'source'; $fence = Join-Path $root 'staging'; $install = Join-Path $fence 'install'
    New-Item -ItemType Directory -Path (Join-Path $source 'server-config') -Force | Out-Null
    New-Item -ItemType Directory -Path $fence -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $source 'server-config\basic.cfg'), 'MaxSizeGuaranteed = 512;')
    [System.IO.File]::WriteAllText((Join-Path $source 'server-config\server-pr8.cfg'), 'passwordAdmin = "__REDACTED_SET_ON_HOST__";')
    $pbo = Join-Path $source 'candidate.chernarus.pbo'
    [System.IO.File]::WriteAllBytes($pbo, [byte[]](0x50,0x42,0x4F,0x01,0x02,0x03,0x04))
    [pscustomobject]@{ Root=$root; Source=$source; Fence=$fence; Install=$install; Pbo=$pbo }
}

function Invoke-T11a {
    Write-Host 'TEST 11a: uninstall re-derives the exact metadata seal and record contract'
    $f = New-Review3Fixture
    try {
        $apply = New-HetznerPlan -SourceRoot $f.Source -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-0 -MissionPboPath $f.Pbo
        Invoke-HetznerPlan -Plan $apply -Apply | Out-Null
        $plan = New-HetznerUninstallPlan -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-0 -MissionPboPath $f.Pbo
        $plan.ExpectedManagedPaths = @()
        Assert-Throws { Invoke-HetznerUninstallPlan -Plan $plan -Apply | Out-Null } 'T11a caller cannot omit the sealed managed contract' 'managed|seal|fingerprint|tamper|exact|empty|argument'
        Assert (Test-Path -LiteralPath (Join-Path $f.Install 'profiles-pr8\basic.cfg')) 'T11a rejected plan performs zero deletion'

        if (Test-Path -LiteralPath $f.Install) { Remove-Item -LiteralPath $f.Install -Recurse -Force }
        Invoke-HetznerPlan -Plan $apply -Apply | Out-Null
        $receiptPath = Join-Path $f.Install '.hetzner-installer\receipt.json'
        $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
        $receipt.ReceiptType = 'forged'
        [System.IO.File]::WriteAllText($receiptPath, ($receipt | ConvertTo-Json -Depth 8))
        Assert-Throws { New-HetznerUninstallPlan -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-0 -MissionPboPath $f.Pbo | Out-Null } 'T11a ReceiptType is mandatory ownership evidence' 'receipt type|ownership|anchor|metadata'

        if (Test-Path -LiteralPath $f.Install) { Remove-Item -LiteralPath $f.Install -Recurse -Force }
        Invoke-HetznerPlan -Plan $apply -Apply | Out-Null
        $manifestPath = Join-Path $f.Install '.hetzner-installer\manifest.json'; $receiptPath = Join-Path $f.Install '.hetzner-installer\receipt.json'
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
        $manifest.ManagedFiles[0].Bytes = [int64]$manifest.ManagedFiles[0].Bytes + 1
        $receipt.ManagedFiles[0].Bytes = [int64]$receipt.ManagedFiles[0].Bytes + 1
        [System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 8))
        [System.IO.File]::WriteAllText($receiptPath, ($receipt | ConvertTo-Json -Depth 8))
        Assert-Throws { New-HetznerUninstallPlan -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-0 -MissionPboPath $f.Pbo | Out-Null } 'T11a jointly forged byte records fail ownership validation' 'bytes|length|record|ownership'

        if (Test-Path -LiteralPath $f.Install) { Remove-Item -LiteralPath $f.Install -Recurse -Force }
        Invoke-HetznerPlan -Plan $apply -Apply | Out-Null
        $managedPath = Join-Path $f.Install 'profiles-pr8\basic.cfg'
        [System.IO.File]::WriteAllText($managedPath, 'jointly-forged-managed-content')
        $forgedHash = (Get-FileHash -LiteralPath $managedPath -Algorithm SHA256).Hash.ToLowerInvariant()
        $forgedBytes = [int64](Get-Item -LiteralPath $managedPath).Length
        $manifestPath = Join-Path $f.Install '.hetzner-installer\manifest.json'; $receiptPath = Join-Path $f.Install '.hetzner-installer\receipt.json'
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
        foreach ($metadata in @($manifest,$receipt)) {
            $record = @($metadata.ManagedFiles | Where-Object { $_.Path -eq 'profiles-pr8\basic.cfg' })[0]
            $record.Sha256 = $forgedHash; $record.Bytes = $forgedBytes
        }
        [System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 8))
        [System.IO.File]::WriteAllText($receiptPath, ($receipt | ConvertTo-Json -Depth 8))
        Assert-Throws { New-HetznerUninstallPlan -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-0 -MissionPboPath $f.Pbo | Out-Null } 'T11a joint managed-file and dual-metadata rewrite is rejected by external seal' 'seal|joint|metadata|ownership'
        Assert ((Test-Path -LiteralPath $managedPath) -and [System.IO.File]::ReadAllText($managedPath) -eq 'jointly-forged-managed-content') 'T11a joint-forgery rejection performs zero deletion'
    } finally { if (Test-Path -LiteralPath $f.Root) { Remove-Item -LiteralPath $f.Root -Recurse -Force } }
}

function Invoke-T11b {
    Write-Host 'TEST 11b: launcher preserves host root and passes secrets through a structured adapter'
    $f = New-Review3Fixture
    try {
        $plan = New-HetznerPlan -SourceRoot $f.Source -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-1 -MissionPboPath $f.Pbo
        $launcher = @($plan.Operations | Where-Object { $_.Kind -eq 'GenerateLauncher' })[0].Content
        Assert ($launcher -notmatch 'ARMA2OA_ROOT=__SET_ON_HOST__') 'T11b launcher never overwrites host-provided ARMA2OA_ROOT'
        Assert ($launcher -match 'if not defined ARMA2OA_ROOT') 'T11b launcher requires the host root without replacing it'
        Assert ($launcher -notmatch '%WASP_HC_PASSWORD%') 'T11b batch layer never expands password metacharacters'
        Assert ($launcher -match '\$env:WASP_HC_PASSWORD' -and $launcher -match '\$arguments\s*=\s*@\(') 'T11b PowerShell adapter passes an argument array from the environment'
    } finally { if (Test-Path -LiteralPath $f.Root) { Remove-Item -LiteralPath $f.Root -Recurse -Force } }
}

function Invoke-T11c {
    Write-Host 'TEST 11c: preserved stale launchers are ownership-aware before Apply mutation'
    $f = New-Review3Fixture
    try {
        $hc0 = New-HetznerPlan -SourceRoot $f.Source -InstallRoot $f.Install -FenceRoot $f.Fence -ProfileName hc-0 -MissionPboPath $f.Pbo
        Invoke-HetznerPlan -Plan $hc0 -Apply | Out-Null
        $stale = Join-Path $f.Install 'hc1_launch.cmd'; [System.IO.File]::WriteAllText($stale, 'host-owned-stale-launcher')
        $manifestPath = Join-Path $f.Install '.hetzner-installer\manifest.json'; $manifestBefore = [System.IO.File]::ReadAllText($manifestPath)
        Assert-Throws { Invoke-HetznerPlan -Plan $hc0 -Apply | Out-Null } 'T11c Apply refuses an unowned stale launcher before mutation' 'stale|ownership|preserv|refus'
        Assert ([System.IO.File]::ReadAllText($stale) -eq 'host-owned-stale-launcher') 'T11c refused Apply preserves the host launcher'
        Assert ([System.IO.File]::ReadAllText($manifestPath) -eq $manifestBefore) 'T11c refused Apply preserves prior ownership metadata'
    } finally { if (Test-Path -LiteralPath $f.Root) { Remove-Item -LiteralPath $f.Root -Recurse -Force } }
}

if ($Group -in @('T11a','All')) { Invoke-T11a }
if ($Group -in @('T11b','All')) { Invoke-T11b }
if ($Group -in @('T11c','All')) { Invoke-T11c }

if ($script:fails -eq 0) { Write-Host 'REVIEW 3 TESTS PASSED' -ForegroundColor Green; exit 0 }
Write-Host "$($script:fails) REVIEW 3 TEST(S) FAILED" -ForegroundColor Red
exit 1
