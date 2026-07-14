[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$OutputPath,
    [Parameter(Mandatory)][string]$RootPath,
    [string]$TaskId,
    [string[]]$ArtifactPath,
    [string]$TestSummary,
    [switch]$Verify,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-CleanReceiptText {
    param([Parameter(Mandatory)][string]$Value, [Parameter(Mandatory)][string]$Field)
    if ($Value -match '[\x00-\x08\x0B\x0C\x0E-\x1F]') { throw "$Field contains a control character." }
    if ($Value -match '\$[A-Za-z_][A-Za-z0-9_]*') { throw "$Field contains an unresolved variable placeholder." }
}

function Get-CanonicalReceiptRoot {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { throw "Receipt root does not exist: $Path" }
    $canonical = [System.IO.Path]::GetFullPath((Get-Item -LiteralPath $Path -Force).FullName)
    return $canonical.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
}

function Resolve-ReceiptArtifact {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$CanonicalRoot)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Receipt artifact does not exist: $Path" }
    $fullPath = [System.IO.Path]::GetFullPath((Get-Item -LiteralPath $Path -Force).FullName)
    if (-not $fullPath.StartsWith($CanonicalRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Receipt artifact escapes the declared root: $Path"
    }
    $relativePath = $fullPath.Substring($CanonicalRoot.Length).Replace([System.IO.Path]::DirectorySeparatorChar, '/')
    if ([string]::IsNullOrWhiteSpace($relativePath) -or $relativePath -match '(^|/)\.\.(/|$)') { throw "Receipt artifact path is malformed: $Path" }
    return [pscustomobject]@{
        FullPath = $fullPath
        RelativePath = $relativePath
    }
}

$canonicalRoot = Get-CanonicalReceiptRoot -Path $RootPath
$canonicalOutput = [System.IO.Path]::GetFullPath($OutputPath)

if ($Verify) {
    if (-not (Test-Path -LiteralPath $canonicalOutput -PathType Leaf)) { throw "Receipt does not exist: $canonicalOutput" }
    $raw = [System.IO.File]::ReadAllText($canonicalOutput)
    Assert-CleanReceiptText -Value $raw -Field 'Receipt'
    try { $receipt = $raw | ConvertFrom-Json } catch { throw "Receipt is malformed JSON: $($_.Exception.Message)" }
    if ($null -eq $receipt -or [string]$receipt.ReceiptType -ne 'HetznerInstallerReviewReceipt') { throw 'Receipt is malformed: invalid receipt type.' }
    if ([int]$receipt.SchemaVersion -ne 1) { throw 'Receipt is malformed: unsupported schema version.' }
    Assert-CleanReceiptText -Value ([string]$receipt.TaskId) -Field 'TaskId'
    if ([string]$receipt.TaskId -notmatch '^[a-z0-9][a-z0-9-]{2,127}$') { throw 'Receipt is malformed: invalid task identity.' }
    Assert-CleanReceiptText -Value ([string]$receipt.TestSummary) -Field 'TestSummary'

    $timestamp = [datetime]::MinValue
    $timestampParsed = $false
    if ($receipt.GeneratedAtUtc -is [datetime]) {
        $timestamp = [datetime]$receipt.GeneratedAtUtc
        $timestampParsed = $true
    } else {
        $timestampParsed = [datetime]::TryParse([string]$receipt.GeneratedAtUtc, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$timestamp)
    }
    if (-not $timestampParsed -or $timestamp.Kind -ne [DateTimeKind]::Utc) {
        throw 'Receipt is malformed: GeneratedAtUtc must be a concrete UTC timestamp.'
    }

    $records = @($receipt.Artifacts)
    if ($records.Count -lt 1) { throw 'Receipt is malformed: at least one artifact is required.' }
    $seen = @{}
    foreach ($record in $records) {
        $relativePath = [string]$record.RelativePath
        Assert-CleanReceiptText -Value $relativePath -Field 'Artifact RelativePath'
        if ([string]::IsNullOrWhiteSpace($relativePath) -or [System.IO.Path]::IsPathRooted($relativePath) -or $relativePath -match '(^|[\\/])\.\.([\\/]|$)') {
            throw "Receipt is malformed: unsafe artifact path $relativePath"
        }
        $key = $relativePath.ToLowerInvariant()
        if ($seen.ContainsKey($key)) { throw "Receipt is malformed: duplicate artifact $relativePath" }
        $seen[$key] = $true
        $artifact = Resolve-ReceiptArtifact -Path (Join-Path $canonicalRoot $relativePath) -CanonicalRoot $canonicalRoot
        $actualHash = (Get-FileHash -LiteralPath $artifact.FullPath -Algorithm SHA256).Hash
        $actualBytes = (Get-Item -LiteralPath $artifact.FullPath -Force).Length
        if ([string]$record.Sha256 -notmatch '^[0-9A-Fa-f]{64}$') { throw "Receipt is malformed: invalid hash for $relativePath" }
        if ($actualHash -ne [string]$record.Sha256) { throw "Receipt artifact hash changed: $relativePath" }
        if ([int64]$record.Bytes -ne [int64]$actualBytes) { throw "Receipt artifact byte count changed: $relativePath" }
    }
    return [pscustomobject]@{
        Verified = $true
        ReceiptPath = $canonicalOutput
        TaskId = [string]$receipt.TaskId
        ArtifactCount = $records.Count
        GeneratedAtUtc = [string]$receipt.GeneratedAtUtc
    }
}

if ([string]::IsNullOrWhiteSpace($TaskId) -or $TaskId -notmatch '^[a-z0-9][a-z0-9-]{2,127}$') { throw 'TaskId must be a lowercase hyphenated identity.' }
Assert-CleanReceiptText -Value $TaskId -Field 'TaskId'
if ([string]::IsNullOrWhiteSpace($TestSummary)) { throw 'TestSummary is required.' }
Assert-CleanReceiptText -Value $TestSummary -Field 'TestSummary'
if ($null -eq $ArtifactPath -or @($ArtifactPath).Count -lt 1) { throw 'At least one ArtifactPath is required.' }
if ((Test-Path -LiteralPath $canonicalOutput) -and -not $Force) { throw "Receipt already exists: $canonicalOutput" }

$records = @()
$seen = @{}
foreach ($path in @($ArtifactPath)) {
    $artifact = Resolve-ReceiptArtifact -Path $path -CanonicalRoot $canonicalRoot
    $key = $artifact.RelativePath.ToLowerInvariant()
    if ($seen.ContainsKey($key)) { throw "Duplicate receipt artifact: $($artifact.RelativePath)" }
    $seen[$key] = $true
    $records += [pscustomobject]@{
        RelativePath = $artifact.RelativePath
        Sha256 = (Get-FileHash -LiteralPath $artifact.FullPath -Algorithm SHA256).Hash
        Bytes = [int64](Get-Item -LiteralPath $artifact.FullPath -Force).Length
    }
}

$payload = [pscustomobject]@{
    ReceiptType = 'HetznerInstallerReviewReceipt'
    SchemaVersion = 1
    TaskId = $TaskId
    GeneratedAtUtc = [DateTime]::UtcNow.ToString('o', [System.Globalization.CultureInfo]::InvariantCulture)
    TestSummary = $TestSummary
    Artifacts = @($records)
}
$json = $payload | ConvertTo-Json -Depth 6
Assert-CleanReceiptText -Value $json -Field 'Generated receipt'

$outputParent = Split-Path -Parent $canonicalOutput
if ([string]::IsNullOrWhiteSpace($outputParent)) { throw 'OutputPath must have a parent directory.' }
if (-not (Test-Path -LiteralPath $outputParent -PathType Container)) { New-Item -ItemType Directory -Path $outputParent -Force | Out-Null }
$tempPath = Join-Path $outputParent (".{0}.tmp.{1}" -f [System.IO.Path]::GetFileName($canonicalOutput), [guid]::NewGuid().ToString('N'))
try {
    [System.IO.File]::WriteAllText($tempPath, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
    if ($Force -and (Test-Path -LiteralPath $canonicalOutput -PathType Leaf)) { Remove-Item -LiteralPath $canonicalOutput -Force }
    Move-Item -LiteralPath $tempPath -Destination $canonicalOutput -Force:$Force
} finally {
    if (Test-Path -LiteralPath $tempPath) { Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue }
}

return [pscustomobject]@{
    Written = $true
    ReceiptPath = $canonicalOutput
    TaskId = $TaskId
    ArtifactCount = $records.Count
    GeneratedAtUtc = $payload.GeneratedAtUtc
}
