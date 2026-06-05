Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")
$wikiRoot = Join-Path $repoRoot "docs\wiki"

if (!(Test-Path -LiteralPath $wikiRoot)) {
    throw "docs/wiki not found at $wikiRoot"
}

$errors = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

function Add-DocError {
    param([string]$Message)
    $script:errors.Add($Message) | Out-Null
}

function Add-DocWarning {
    param([string]$Message)
    $script:warnings.Add($Message) | Out-Null
}

function Test-JsonFile {
    param([string]$Path)
    try {
        Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json | Out-Null
    } catch {
        Add-DocError "JSON parse failed: $Path :: $($_.Exception.Message)"
    }
}

function Test-JsonLinesFile {
    param([string]$Path)
    $lineNumber = 0
    $recordCount = 0
    $missingSchema = 0
    $legacyTimestamp = 0
    $legacyState = 0
    Get-Content -LiteralPath $Path | ForEach-Object {
        $lineNumber++
        if ([string]::IsNullOrWhiteSpace($_)) {
            return
        }
        $recordCount++
        try {
            $record = $_ | ConvertFrom-Json
            $fields = @($record.PSObject.Properties.Name)
            if ($fields -notcontains "schema") {
                $missingSchema++
            }
            if (($fields -contains "timestamp") -and ($fields -notcontains "ts")) {
                $legacyTimestamp++
            }
            if (($fields -contains "state") -and ($fields -notcontains "status")) {
                $legacyState++
            }
        } catch {
            Add-DocError "JSONL parse failed: $Path line $lineNumber :: $($_.Exception.Message)"
        }
    }

    if ($recordCount -gt 0 -and ($missingSchema -gt 0 -or $legacyTimestamp -gt 0 -or $legacyState -gt 0)) {
        Add-DocWarning "JSONL legacy envelope tolerated: $([IO.Path]::GetFileName($Path)) records=$recordCount missingSchema=$missingSchema timestampWithoutTs=$legacyTimestamp stateWithoutStatus=$legacyState"
    }
}

function Resolve-WikiLinkTarget {
    param([string]$Link)

    $target = ($Link -split '#')[0]
    if ([string]::IsNullOrWhiteSpace($target)) {
        return $null
    }
    if ($target -match '^(https?:|mailto:|plugin:|app:)') {
        return $null
    }

    $decoded = [Uri]::UnescapeDataString($target)
    if ($decoded -match '\.(md|json|jsonl|txt|schema\.json)$') {
        return Join-Path $wikiRoot $decoded
    }

    return Join-Path $wikiRoot ($decoded + ".md")
}

Get-ChildItem -LiteralPath $wikiRoot -File -Filter "*.json" | ForEach-Object {
    Test-JsonFile -Path $_.FullName
}

Get-ChildItem -LiteralPath $wikiRoot -File -Filter "*.jsonl" | ForEach-Object {
    Test-JsonLinesFile -Path $_.FullName
}

$markdownFiles = Get-ChildItem -LiteralPath $wikiRoot -File | Where-Object {
    $_.Extension -in @(".md", ".txt")
}
$linkPattern = [regex]'\[[^\]]+\]\(([^)]+)\)'
foreach ($file in $markdownFiles) {
    $text = Get-Content -LiteralPath $file.FullName -Raw
    foreach ($match in $linkPattern.Matches($text)) {
        $link = $match.Groups[1].Value
        $targetPath = Resolve-WikiLinkTarget -Link $link
        if ($null -eq $targetPath) {
            continue
        }
        if (!(Test-Path -LiteralPath $targetPath)) {
            Add-DocError "Broken local link: $($file.Name) -> $link"
        }
    }
}

$stalePatterns = @(
    'source/Vanilla patched',
    'Source/Vanilla patched',
    'source-vanilla-patched',
    'Source Chernarus and generated Vanilla',
    'source Chernarus and generated Vanilla',
    'generated Vanilla Takistan now',
    'generated Vanilla Takistan are patched',
    'LoadoutManager reached',
    'WASP marker wait cleanup.*patched'
)

$allTextFiles = Get-ChildItem -LiteralPath $wikiRoot -File | Where-Object {
    $_.Extension -in @(".md", ".txt", ".json", ".jsonl")
}
foreach ($file in $allTextFiles) {
    $text = Get-Content -LiteralPath $file.FullName -Raw
    foreach ($pattern in $stalePatterns) {
        if ($text -match $pattern) {
            Add-DocError "Stale optimistic status phrase: $($file.Name) matches '$pattern'"
        }
    }
}

if ($errors.Count -gt 0) {
    $errors | Sort-Object -Unique | ForEach-Object { Write-Error $_ }
    throw "Docs validation failed with $($errors.Count) issue(s)."
}

if ($warnings.Count -gt 0) {
    $warnings | Sort-Object -Unique | ForEach-Object { Write-Warning $_ }
}

Write-Host "docs/wiki validation passed."
