$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$outputPath = Join-Path $repoRoot "docs\analysis\dead-code-asset-reference-scan.json"

$missionContainers = @("Missions", "Missions_Vanilla", "Modded_Missions")
$textExtensions = @(".sqf", ".fsm", ".hpp", ".ext", ".cpp", ".sqm", ".xml", ".html", ".txt", ".csv")
$assetExtensions = @(".paa", ".jpg", ".jpeg", ".png", ".ogg", ".wss", ".wav", ".bik", ".rvmat", ".html", ".xml", ".csv", ".txt")
$includeExtensions = @(".sqf", ".fsm", ".hpp", ".ext", ".cpp")
$referenceExtensions = $assetExtensions + $includeExtensions

function Get-RelativePath {
    param([string]$Path)
    $rootWithSlash = $repoRoot
    if (-not $rootWithSlash.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $rootWithSlash = $rootWithSlash + [System.IO.Path]::DirectorySeparatorChar
    }
    $rootUri = New-Object System.Uri($rootWithSlash)
    $pathUri = New-Object System.Uri([System.IO.Path]::GetFullPath($Path))
    return [System.Uri]::UnescapeDataString($rootUri.MakeRelativeUri($pathUri).ToString()).Replace('/', '\')
}

function Normalize-RepoPath {
    param([string]$Path)
    return ($Path -replace '/', '\').Trim()
}

function Get-CommentState {
    param(
        [string]$Line,
        [bool]$InBlockComment
    )

    $trimmed = $Line.TrimStart()
    $commentOnly = $InBlockComment -or $trimmed.StartsWith("//") -or $trimmed.StartsWith("*") -or $trimmed.StartsWith("#")
    $nextInBlock = $InBlockComment

    if ($Line -match '/\*') {
        $before = $Line.Substring(0, $Line.IndexOf("/*"))
        if ($before.Trim().Length -eq 0) { $commentOnly = $true }
        $nextInBlock = $true
    }
    if ($Line -match '\*/') {
        $nextInBlock = $false
    }

    return [pscustomobject]@{
        CommentOnly = $commentOnly
        NextInBlock = $nextInBlock
    }
}

function Get-MissionContext {
    param([string]$RelativePath)

    $parts = $RelativePath -split '[\\/]'
    if ($parts.Count -lt 2) { return $null }
    if ($missionContainers -notcontains $parts[0]) { return $null }

    $missionRoot = Join-Path $repoRoot (Join-Path $parts[0] $parts[1])
    return [pscustomobject]@{
        Container = $parts[0]
        Mission = $parts[1]
        Root = $missionRoot
        RelativeRoot = "$($parts[0])\$($parts[1])"
        InModded = ($parts[0] -eq "Modded_Missions")
    }
}

function Test-ExternalReference {
    param([string]$Reference)

    $normalized = (Normalize-RepoPath $Reference).TrimStart('\')
    return (
        $normalized -match '^(ca|z|x|a2|a3|dbo|ibr|ibr_plants|ibr_hangars|mbg|brg_africa|smd|ffaa|pja|panthera|lingor|dingor|isladuala|tavi|napf)\\' -or
        $normalized -match '^[A-Za-z0-9_]+\\addons\\'
    )
}

function Resolve-Reference {
    param(
        [string]$Reference,
        [string]$SourcePath,
        [object]$MissionContext
    )

    $normalized = Normalize-RepoPath $Reference
    $trimmed = $normalized.Trim('"', "'", " ")
    $trimmedNoRootSlash = $trimmed.TrimStart('\')

    if ($trimmedNoRootSlash.Length -eq 0) {
        return [pscustomobject]@{ Status = "empty"; Match = $null; Candidates = @() }
    }
    if ($trimmedNoRootSlash -match '[%$<>]' -or $trimmedNoRootSlash -match '\bformat\b') {
        return [pscustomobject]@{ Status = "dynamic"; Match = $null; Candidates = @() }
    }
    if (Test-ExternalReference $trimmed) {
        return [pscustomobject]@{ Status = "external-addon"; Match = $null; Candidates = @() }
    }

    $candidates = New-Object System.Collections.Generic.List[string]
    $sourceDir = Split-Path -Parent $SourcePath

    if ($MissionContext -ne $null) {
        [void]$candidates.Add((Join-Path $sourceDir $trimmedNoRootSlash))
        [void]$candidates.Add((Join-Path $MissionContext.Root $trimmedNoRootSlash))
    }
    [void]$candidates.Add((Join-Path $repoRoot $trimmedNoRootSlash))

    $deduped = $candidates |
        ForEach-Object { [System.IO.Path]::GetFullPath($_) } |
        Select-Object -Unique

    foreach ($candidate in $deduped) {
        if (Test-Path -LiteralPath $candidate) {
            return [pscustomobject]@{
                Status = "resolved"
                Match = (Get-RelativePath $candidate)
                Candidates = @($deduped | ForEach-Object { Get-RelativePath $_ })
            }
        }
    }

    return [pscustomobject]@{
        Status = "missing"
        Match = $null
        Candidates = @($deduped | ForEach-Object { Get-RelativePath $_ })
    }
}

$missionDirs = foreach ($container in $missionContainers) {
    $containerPath = Join-Path $repoRoot $container
    if (Test-Path -LiteralPath $containerPath) {
        Get-ChildItem -LiteralPath $containerPath -Directory
    }
}

$bootstrapRows = foreach ($missionDir in $missionDirs) {
    $relativeMission = Get-RelativePath $missionDir.FullName
    $required = @("description.ext", "mission.sqm", "initJIPCompatible.sqf")
    $optionalGenerated = @("version.sqf")

    foreach ($name in $required) {
        $path = Join-Path $missionDir.FullName $name
        [pscustomobject]@{
            mission = $relativeMission
            file = $name
            exists = (Test-Path -LiteralPath $path)
            classification = "required-bootstrap"
        }
    }
    foreach ($name in $optionalGenerated) {
        $path = Join-Path $missionDir.FullName $name
        [pscustomobject]@{
            mission = $relativeMission
            file = $name
            exists = (Test-Path -LiteralPath $path)
            classification = "generated-or-release-bootstrap"
        }
    }
}

$textFiles = foreach ($container in $missionContainers) {
    $root = Join-Path $repoRoot $container
    if (Test-Path -LiteralPath $root) {
        Get-ChildItem -LiteralPath $root -Recurse -File |
            Where-Object { $textExtensions -contains $_.Extension.ToLowerInvariant() }
    }
}

$records = New-Object System.Collections.Generic.List[object]
$literalRegex = [regex]'["'']([^"'']+\.(?:paa|jpg|jpeg|png|ogg|wss|wav|bik|rvmat|html|xml|csv|txt|sqf|fsm|hpp|ext|cpp))["'']'
$includeRegex = [regex]'^\s*#include\s+[<"''`]([^>"''`]+)[>"''`]'

foreach ($file in $textFiles) {
    $relative = Get-RelativePath $file.FullName
    $missionContext = Get-MissionContext $relative
    $lines = Get-Content -LiteralPath $file.FullName
    $inBlock = $false

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $comment = Get-CommentState -Line $line -InBlockComment $inBlock
        $inBlock = $comment.NextInBlock

        $lineRefs = New-Object System.Collections.Generic.List[object]

        foreach ($match in $literalRegex.Matches($line)) {
            [void]$lineRefs.Add([pscustomobject]@{
                kind = "quoted-path"
                reference = $match.Groups[1].Value
            })
        }

        $includeMatch = $includeRegex.Match($line)
        if ($includeMatch.Success) {
            [void]$lineRefs.Add([pscustomobject]@{
                kind = "include"
                reference = $includeMatch.Groups[1].Value
            })
        }

        foreach ($lineRef in $lineRefs) {
            $extension = [System.IO.Path]::GetExtension($lineRef.reference).ToLowerInvariant()
            if ($referenceExtensions -notcontains $extension) { continue }

            if ($lineRef.kind -eq "quoted-path" -and $line -match '\+') {
                $resolved = [pscustomobject]@{ Status = "dynamic-fragment"; Match = $null; Candidates = @() }
            } else {
                $resolved = Resolve-Reference -Reference $lineRef.reference -SourcePath $file.FullName -MissionContext $missionContext
            }

            [void]$records.Add([pscustomobject]@{
                source = $relative
                line = $i + 1
                kind = $lineRef.kind
                reference = (Normalize-RepoPath $lineRef.reference)
                extension = $extension
                commentOnly = $comment.CommentOnly
                mission = if ($missionContext) { $missionContext.RelativeRoot } else { $null }
                inModdedMission = if ($missionContext) { $missionContext.InModded } else { $false }
                status = $resolved.Status
                resolvedPath = $resolved.Match
                candidates = $resolved.Candidates
            })
        }
    }
}

$recordArray = @($records.ToArray())
$activeRecords = @($recordArray | Where-Object { -not $_.commentOnly })
$activeMissing = @($activeRecords | Where-Object { $_.status -eq "missing" })
$activeMissingMaintained = @($activeMissing | Where-Object { -not $_.inModdedMission })
$activeMissingModded = @($activeMissing | Where-Object { $_.inModdedMission })
$commentOnlyMissing = @($recordArray | Where-Object { $_.commentOnly -and $_.status -eq "missing" })
$externalAddon = @($recordArray | Where-Object { $_.status -eq "external-addon" })
$resolvedAssets = @($recordArray | Where-Object { $_.status -eq "resolved" -and ($assetExtensions -contains $_.extension) })

$missingByReference = @($activeMissing |
    Group-Object reference |
    Sort-Object Count -Descending |
    Select-Object -First 80 |
    ForEach-Object {
        [pscustomobject]@{
            reference = $_.Name
            count = $_.Count
            maintainedCount = @($_.Group | Where-Object { -not $_.inModdedMission }).Count
            moddedCount = @($_.Group | Where-Object { $_.inModdedMission }).Count
            examples = @($_.Group | Select-Object -First 8 source, line, status, mission)
        }
    })

$bootstrapMissing = @($bootstrapRows | Where-Object { -not $_.exists })

$summary = [pscustomobject]@{
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    rootsScanned = $missionContainers
    missionRootCount = @($missionDirs).Count
    textFileCount = @($textFiles).Count
    referenceRecordCount = @($recordArray).Count
    activeReferenceCount = @($activeRecords).Count
    resolvedReferenceCount = @($recordArray | Where-Object { $_.status -eq "resolved" }).Count
    externalAddonReferenceCount = @($externalAddon).Count
    activeMissingReferenceCount = @($activeMissing).Count
    activeMissingMaintainedReferenceCount = @($activeMissingMaintained).Count
    activeMissingModdedReferenceCount = @($activeMissingModded).Count
    commentOnlyMissingReferenceCount = @($commentOnlyMissing).Count
    resolvedAssetReferenceCount = @($resolvedAssets).Count
    missingBootstrapCount = @($bootstrapMissing).Count
}

$output = [pscustomobject]@{
    summary = $summary
    bootstrapRows = @($bootstrapRows)
    missingBootstrap = @($bootstrapMissing)
    missingByReference = @($missingByReference)
    records = @($recordArray)
}

$output | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outputPath -Encoding UTF8
Write-Host "Wrote $outputPath"
Write-Host ($summary | ConvertTo-Json -Compress)
