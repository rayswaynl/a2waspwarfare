$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "FAIL  $Message" }
    Write-Output "  PASS  $Message"
}

function Assert-Throws {
    param([scriptblock]$Action, [string]$Message, [string]$Pattern)
    try {
        & $Action
    } catch {
        if ($_.Exception.Message -notmatch $Pattern) {
            throw "FAIL  $Message (unexpected error: $($_.Exception.Message))"
        }
        Write-Output "  PASS  $Message"
        return
    }
    throw "FAIL  $Message (no error)"
}

$scriptPath = Join-Path $PSScriptRoot 'New-HetznerInstallerReceipt.ps1'
$sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("hetzner-receipt-{0}" -f [guid]::NewGuid().ToString('N'))
$artifactRoot = Join-Path $sandbox 'artifacts'
$receiptPath = Join-Path $sandbox 'receipt.json'

try {
    New-Item -ItemType Directory -Path $artifactRoot -Force | Out-Null
    $modulePath = Join-Path $artifactRoot 'module.psm1'
    $testPath = Join-Path $artifactRoot 'suite.tests.ps1'
    [System.IO.File]::WriteAllText($modulePath, 'module-bytes', [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($testPath, 'test-bytes', [System.Text.UTF8Encoding]::new($false))

    Write-Output 'TEST R1: receipt generation emits only concrete, hash-complete evidence'
    $written = & $scriptPath -OutputPath $receiptPath -TaskId 'arma2-perf-hetzner-72h-installer-controller-20260713' -RootPath $artifactRoot -ArtifactPath @($modulePath, $testPath) -TestSummary 'PS5 suites PASS; PS7 service and receipt PASS'
    Assert-True ($written.Written -eq $true) 'R1 generator reports a durable write'
    Assert-True (Test-Path -LiteralPath $receiptPath -PathType Leaf) 'R1 receipt is created'

    $raw = [System.IO.File]::ReadAllText($receiptPath)
    Assert-True ($raw -notmatch '[\x00-\x08\x0B\x0C\x0E-\x1F]') 'R1 receipt contains no control characters'
    Assert-True ($raw -notmatch '\$[A-Za-z_][A-Za-z0-9_]*') 'R1 receipt contains no unresolved variables'

    $receipt = $raw | ConvertFrom-Json
    Assert-True ($receipt.ReceiptType -eq 'HetznerInstallerReviewReceipt') 'R1 receipt type is explicit'
    Assert-True ($receipt.TaskId -eq 'arma2-perf-hetzner-72h-installer-controller-20260713') 'R1 task identity is exact'
    $parsedTimestamp = [datetime]::MinValue
    $timestampParsed = $false
    if ($receipt.GeneratedAtUtc -is [datetime]) {
        $parsedTimestamp = [datetime]$receipt.GeneratedAtUtc
        $timestampParsed = $true
    } else {
        $timestampParsed = [datetime]::TryParse([string]$receipt.GeneratedAtUtc, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$parsedTimestamp)
    }
    Assert-True ($timestampParsed -and $parsedTimestamp.Kind -eq [DateTimeKind]::Utc) 'R1 timestamp is concrete UTC'
    Assert-True (@($receipt.Artifacts).Count -eq 2) 'R1 every requested artifact is listed'
    foreach ($artifact in @($receipt.Artifacts)) {
        $fullPath = Join-Path $artifactRoot ([string]$artifact.RelativePath)
        $expectedHash = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash
        $expectedBytes = (Get-Item -LiteralPath $fullPath).Length
        Assert-True ([string]$artifact.Sha256 -eq $expectedHash) "R1 hash matches $($artifact.RelativePath)"
        Assert-True ([int64]$artifact.Bytes -eq $expectedBytes) "R1 byte count matches $($artifact.RelativePath)"
    }

    $verified = & $scriptPath -OutputPath $receiptPath -RootPath $artifactRoot -Verify
    Assert-True ($verified.Verified -eq $true) 'R1 fresh receipt verifies against current artifacts'

    Write-Output 'TEST R2: verifier rejects artifact drift and malformed evidence'
    [System.IO.File]::AppendAllText($modulePath, '-tampered')
    Assert-Throws { & $scriptPath -OutputPath $receiptPath -RootPath $artifactRoot -Verify } 'R2 artifact drift is rejected' 'hash|byte|changed'

    $malformedPath = Join-Path $sandbox 'malformed.json'
    [System.IO.File]::WriteAllText($malformedPath, '{"ReceiptType":"HetznerInstallerReviewReceipt","GeneratedAtUtc":"$stamp"}', [System.Text.UTF8Encoding]::new($false))
    Assert-Throws { & $scriptPath -OutputPath $malformedPath -RootPath $artifactRoot -Verify } 'R2 unresolved placeholder is rejected' 'placeholder|variable|malformed'

    $controlPath = Join-Path $sandbox 'control.json'
    [System.IO.File]::WriteAllText($controlPath, "{`"TaskId`":`"bad$([char]7)task`"}", [System.Text.UTF8Encoding]::new($false))
    Assert-Throws { & $scriptPath -OutputPath $controlPath -RootPath $artifactRoot -Verify } 'R2 control character is rejected' 'control|malformed'

    Write-Output 'RECEIPT TESTS PASSED'
} finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}
