param(
    [string[]]$Roots = @("Missions", "Missions_Vanilla", "Modded_Missions"),
    [string]$OutputPath = "docs/analysis/dead-code-reference-scan.json"
)

$ErrorActionPreference = "Stop"

function Get-MissionRoot {
    param([System.IO.FileInfo]$File)

    $parts = $File.FullName -split '[\\/]'
    for ($i = 0; $i -lt $parts.Length; $i++) {
        if ($parts[$i] -in @("Missions", "Missions_Vanilla", "Modded_Missions")) {
            if ($i + 1 -lt $parts.Length) {
                return ($parts[0..($i + 1)] -join [IO.Path]::DirectorySeparatorChar)
            }
        }
    }

    return $null
}

function Resolve-MissionReference {
    param(
        [string]$MissionRoot,
        [string]$Reference
    )

    $clean = $Reference -replace '/', [IO.Path]::DirectorySeparatorChar
    $clean = $clean -replace '\\', [IO.Path]::DirectorySeparatorChar
    return Join-Path $MissionRoot $clean
}

function Get-RelativeLiteralPath {
    param([string]$Path)

    $resolved = (Resolve-Path -LiteralPath $Path).Path
    $base = (Get-Location).Path
    if ($resolved.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)) {
        return "." + $resolved.Substring($base.Length)
    }

    return $resolved
}

$textExtensions = @(".sqf", ".hpp", ".ext", ".sqm", ".fsm", ".cpp", ".h")
$refRegexes = @(
    '#include\s+"([^"]+)"',
    'preprocessFile(?:LineNumbers)?\s+"([^"]+)"',
    'preprocessFile(?:LineNumbers)?\s+""([^""]+)""',
    'execVM\s+"([^"]+)"',
    'ExecVM\s+""([^""]+)""',
    'loadFile\s+"([^"]+)"'
)

$files = foreach ($root in $Roots) {
    if (Test-Path $root) {
        Get-ChildItem -Path $root -Recurse -File | Where-Object { $textExtensions -contains $_.Extension }
    }
}

$missingReferences = New-Object System.Collections.Generic.List[object]
$referenceCount = 0

foreach ($file in $files) {
    $missionRoot = Get-MissionRoot -File $file
    if (-not $missionRoot) { continue }

    $lines = Get-Content -LiteralPath $file.FullName
    for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
        $line = $lines[$lineIndex]
        foreach ($regex in $refRegexes) {
            foreach ($match in [regex]::Matches($line, $regex, [Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
                $reference = $match.Groups[1].Value
                if ([string]::IsNullOrWhiteSpace($reference)) { continue }
                if ($reference.StartsWith("\") -or $reference.StartsWith("/") -or $reference -match '^[A-Za-z]:') { continue }
                if ($reference -match '\$|%1|format|Format|\+') { continue }

                $referenceCount++
                $resolved = Resolve-MissionReference -MissionRoot $missionRoot -Reference $reference
                if (-not (Test-Path -LiteralPath $resolved)) {
                    $missingReferences.Add([PSCustomObject]@{
                        source = Get-RelativeLiteralPath -Path $file.FullName
                        line = $lineIndex + 1
                        reference = $reference
                        resolved = $resolved
                    })
                }
            }
        }
    }
}

$conflictMarkerFiles = foreach ($root in $Roots) {
    if (Test-Path $root) {
        Get-ChildItem -Path $root -Recurse -File | Where-Object { $textExtensions -contains $_.Extension } | Where-Object {
            Select-String -LiteralPath $_.FullName -Pattern '^\s*(<{7,}|>{7,}|={7,})' -Quiet
        } | ForEach-Object { Get-RelativeLiteralPath -Path $_.FullName }
    }
}

$result = [PSCustomObject]@{
    generatedAt = (Get-Date).ToString("o")
    roots = $Roots
    scannedFiles = @($files).Count
    quotedReferenceCount = $referenceCount
    missingReferenceCount = $missingReferences.Count
    missingReferences = $missingReferences
    conflictMarkerFileCount = @($conflictMarkerFiles).Count
    conflictMarkerFiles = @($conflictMarkerFiles)
}

$outDir = Split-Path -Parent $OutputPath
if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

$result | ConvertTo-Json -Depth 6 | Set-Content -Path $OutputPath -Encoding UTF8
$result
